extends Node
## Online co-op over ENet on this machine (NetSession, CoopSession): run as a
## host and guests, each its own Godot process (tests/coop_net.sh starts them):
##   Godot_console.exe --headless --path . res://tests/coop_net_peer.tscn -- --role=host --port=N
##   ... -- --role=guest --port=N --lag=60 --jitter=20 --loss=0.02
##   ... -- --role=late --port=N        (joins later)
## The host directs (_phase, a probe RPC: this node is /root/Probe everywhere);
## each process checks what it can see and prints its own results.
## - Joining: the guest's run follows the host's world (same schools, same
##   seeds), each has a puppet of the other, the host's tuning reaches the
##   guest and locks its panel.
## - Motion: the guest shows the host's fish where it was (smoothly, a little
##   behind), and swims the host's schools close to where the host has them.
## - Batteries: a guest's battery counts for them on both machines; the host
##   battering the lone fish shows on the guest; both on one fish at once share
##   it; a pearl goes to one of them only.
## - A late joiner gets the world as it is (fish battered, counts).
## - The host restarting restarts everyone; a guest leaving goes from the
##   host's run; the host leaving sends a guest back to Nature on its own.

const MOTION_LIMIT := 0.35
const SCHOOL_LIMIT := 1.2

var role := "host"
var port := NetSession.DEFAULT_PORT
var main: Node
var fish: FishController
var failures := 0
## The host's fish's truth (guest): [host time, position], oldest first.
var _truth: Array = []
## The host's school's fish (guest): [host time, id, positions].
var _school_truth: Array = []
var _phase_name := ""
var _done := {}
var _circle := false
var _circle_time := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.get_slice("=", 1)
		elif arg.begins_with("--port="):
			port = arg.get_slice("=", 1).to_int()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  [%s] %s  %s" % [role, "PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _finish() -> void:
	print("coop_net_peer [%s]: %s" % [role, "all checks passed" if failures == 0 else "%d FAILED" % failures])
	get_tree().quit(1 if failures else 0)


func _run() -> void:
	main.set_mode(main.NATURE)
	await _ticks(10)
	if role == "host":
		await _host()
	else:
		await _guest()
	_finish()


# --- Host ------------------------------------------------------------------

func _host() -> void:
	print("host: hosting on %d" % port)
	NetSession.host_enet(port)
	await _ticks(5)
	var run: NatureRun = main.nature_run
	check(NetSession.is_host() and run != null and run.authority, "hosting: our run, the world ours")
	var coop: CoopSession = NetSession.coop
	if not await _wait(func() -> bool: return coop.roster.size() >= 2, 20.0):
		check(false, "a guest joined")
		return
	check(true, "a guest joined (%d playing)" % coop.roster.size())
	await _seconds(1.0)
	var guest_pid := _other_pid(coop)
	var guest_fish := coop.fish_of(guest_pid)
	check(guest_fish != null and guest_fish.puppet and guest_fish in run.players, "the guest's fish is a puppet in our run")

	print("host: tuning")
	fish.max_speed = 27.25
	NatureSettings.shared().spread = 2.9
	main._panel.tuning_changed.emit()
	await _seconds(0.5)
	await _phase("tuning", {"max_speed": 27.25, "spread": 2.9})

	print("host: motion")
	_circle = true
	await _seconds(1.0)
	await _phase("motion", {})
	_circle = false
	fish.linear_velocity = Vector3.ZERO

	print("host: batteries")
	run = main.nature_run
	var before := run.battered_fish
	var guest_had := run.rules.battered_by(guest_fish)
	await _phase("guest_rams", {})
	await _seconds(0.6)
	check(run.battered_fish >= before + 1 and run.rules.battered_by(guest_fish) >= guest_had + 1,
			"the guest's battery counts here, for them (%d)" % run.rules.battered_by(guest_fish))
	var awards := [0]
	run.awarded.connect(func(event: Dictionary) -> void:
		if event.get("by") == guest_fish:
			awards[0] += 1)
	await _phase("guest_rams", {})
	await _seconds(0.6)
	check(awards[0] >= 1, "their points show in our feed (%d)" % awards[0])
	await _ram_target(run)
	check(run.target.battered, "we batter the lone fish")
	await _phase("target_gone", {"count": run.battered_fish})

	print("host: together")
	var school := _school_with_fish(run)
	var index := _alive_index(school)
	var shared_before := run.rules.shared_batteries
	await _phase("ram_now", {"school": school.id, "index": index}, false)
	await _seconds(0.02)
	await _ram_school_fish(school, index)
	await _seconds(1.0)
	check(run.rules.shared_batteries == shared_before + 1, "both on one fish at once: shared (%d)" % run.rules.shared_batteries)
	await _phase("shared", {"shared": run.rules.shared_batteries, "count": run.battered_fish})

	print("host: pearls")
	NatureSettings.shared().pearl_chance = 1.0
	main._panel.tuning_changed.emit()
	await _seconds(0.6)
	var pearls_before := run.pearls
	await _phase("guest_rams", {})
	await _seconds(0.6)
	check(run.pearls > pearls_before or not run.pearls_out.is_empty(), "the guest's battery dropped a pearl (%d collected, %d out)"
			% [run.pearls - pearls_before, run.pearls_out.size()])
	# One pearl, both of us on it at once: it counts once.
	for old in run.pearls_out.duplicate():
		old.queue_free()
	await _seconds(0.2)
	pearls_before = run.pearls
	var spot := fish.global_position + Vector3(0, 30, 0)
	var pearl_id: int = run._next_pearl_id
	run._next_pearl_id += 1
	run.drop_pearl(pearl_id, spot)  # as a battery would, without one
	await _phase("pearl_race", {"id": pearl_id, "at": spot}, false)
	fish.linear_velocity = Vector3.ZERO
	fish.global_position = spot + Vector3(0.4, 0, 0)
	await _seconds(1.0)
	check(run.pearls == pearls_before + 1, "two of us on one pearl: counted once (%d)" % (run.pearls - pearls_before))
	await _phase("pearl_count", {"count": run.pearls})
	NatureSettings.shared().pearl_chance = 0.2
	main._panel.tuning_changed.emit()

	print("host: late joiner")
	if await _wait(func() -> bool: return coop.roster.size() >= 3, 60.0):
		await _seconds(1.5)
		var late_school := run.schools[0]
		await _phase("late_check", {"school": late_school.id, "alive": late_school.alive_count(), "count": run.battered_fish,
				"pearls": run.pearls}, false, "late")
		await _wait_done("late_check", 10.0)
		await _phase("late_leave", {}, false, "late")
		await _wait(func() -> bool: return coop.roster.size() <= 2, 10.0)
		await _seconds(0.5)
		check(coop.roster.size() == 2 and run.players.size() == 2, "the late joiner left: gone from our run")
	else:
		check(false, "the late joiner joined")

	print("host: restart")
	main.reset_play()
	await _seconds(1.0)
	run = main.nature_run
	var ids := run.schools.map(func(s: School) -> int: return s.id)
	await _phase("restarted", {"ids": ids})

	print("host: leaving")
	await _phase("host_leaving", {}, false)
	await _seconds(0.3)
	NetSession.leave()
	await _seconds(0.5)


# --- Guest -----------------------------------------------------------------

func _guest() -> void:
	await _seconds(0.5)
	print("%s: joining" % role)
	NetSession.join_enet("127.0.0.1", port)
	var coop: CoopSession = NetSession.coop
	if not await _wait(func() -> bool: return coop._welcomed and main.nature_run != null, 20.0):
		check(false, "welcomed into the host's run")
		return
	await _seconds(1.0)
	var run: NatureRun = main.nature_run
	check(not run.authority and coop.roster.size() >= 2, "welcomed: a run of ours in the host's world")
	_claimed(run)  # start counting our claims
	var host_fish := coop.fish_of(100)
	check(host_fish != null and host_fish.puppet and host_fish in run.players and host_fish.visible, "the host's fish is a puppet here")
	check(run.schools.size() == NatureSettings.shared().school_count and run.schools.all(func(s: School) -> bool: return s.follower),
			"the host's schools are here, following it (%d)" % run.schools.size())
	if role == "late":
		await _late()
		return
	while true:
		await _wait(func() -> bool: return _phase_name != "", 60.0)
		var phase := _phase_name
		var data: Dictionary = _phase_data
		_phase_name = ""
		match phase:
			"":
				check(false, "the host carried on")
				return
			"tuning":
				check(is_equal_approx(fish.max_speed, data.max_speed) and is_equal_approx(NatureSettings.shared().spread, data.spread),
						"the host's tuning is ours (max_speed %.2f, spread %.2f)" % [fish.max_speed, NatureSettings.shared().spread])
				var editor: Control = main._panel._editors.get("fish/max_speed")
				check(editor is Range and not (editor as Range).editable, "our panel's fish tuning is locked")
				check((main._panel._editors.get("camera/distance") as Range).editable, "our camera's still ours")
			"motion":
				await _check_motion(coop)
				await _check_schools(coop)
			"guest_rams":
				run = main.nature_run
				var school := _school_with_fish(run)
				var index := _alive_index(school)
				var had := run.rules.battered_by(fish)
				await _ram_school_fish(school, index)
				check(not school.is_alive(index), "our ram batters it here at once")
				await _seconds(0.5)
				check(run.rules.battered_by(fish) >= had + 1 and run.rules.battered_by(fish) == _claimed(run), "the host confirmed it: ours (%d)" % run.rules.battered_by(fish))
			"target_gone":
				check(run.target.battered or not run.target.visible, "the host battered the lone fish: gone here too")
				check(run.battered_fish == data.count, "the same count as the host (%d)" % run.battered_fish)
			"ram_now":
				var school: School = run.school_by_id(data.school)
				if school:
					await _ram_school_fish(school, data.index)
			"shared":
				check(run.rules.shared_batteries == data.shared and run.battered_fish == data.count,
						"shared here too, same count (%d shared, %d fish)" % [run.rules.shared_batteries, run.battered_fish])
			"pearl_race":
				main.nature_run.drop_pearl(data.id, data.at)  # the host dropped it without a battery: here too
				fish.linear_velocity = Vector3.ZERO
				fish.global_position = data.at + Vector3(-0.4, 0, 0)
			"pearl_count":
				await _seconds(0.3)
				check(run.pearls == data.count, "the same pearl count as the host (%d)" % run.pearls)
			"restarted":
				run = main.nature_run
				await _seconds(0.3)
				var ids: Array = run.schools.map(func(s: School) -> int: return s.id)
				ids.sort()
				var theirs: Array = data.ids.duplicate()
				theirs.sort()
				check(ids == theirs and run.battered_fish == 0, "the host restarted: so did we (schools %s)" % str(ids))
			"host_leaving":
				await _wait(func() -> bool: return not NetSession.is_online(), 10.0)
				await _seconds(0.5)
				check(not NetSession.is_online() and main.nature_run != null and main.nature_run.authority,
						"the host left: Nature on our own again")
				check((main._panel._editors.get("fish/max_speed") as Range).editable, "our tuning's ours again")
				return
		_send_done(phase)




func _late() -> void:
	var coop: CoopSession = NetSession.coop
	await _wait(func() -> bool: return _phase_name == "late_check", 30.0)
	var data: Dictionary = _phase_data
	_phase_name = ""
	var run: NatureRun = main.nature_run
	var school := run.school_by_id(data.school)
	check(school != null and school.alive_count() == data.alive, "joining late: the school's battered fish are gone here too (%d left)" % (school.alive_count() if school else -1))
	check(run.battered_fish == data.count and run.pearls == data.pearls, "...and the counts are the host's (%d fish, %d pearls)" % [run.battered_fish, run.pearls])
	check(coop.fish_of(100) != null, "the host's fish is here")
	_send_done("late_check")
	await _wait(func() -> bool: return _phase_name == "late_leave", 30.0)
	NetSession.leave()
	await _seconds(0.3)


## The host's fish, as shown here, against where it really was then.
func _check_motion(coop: CoopSession) -> void:
	var net: NetFish = coop._remote.get(100)
	var errors := PackedFloat32Array()
	for i in 120:
		await get_tree().physics_frame
		var at: Variant = _truth_at(net.render_time())
		if at != null:
			errors.append(net.fish.global_position.distance_to(at))
	var mean := 0.0
	var worst := 0.0
	for e in errors:
		mean += e
		worst = maxf(worst, e)
	mean /= maxf(errors.size(), 1.0)
	check(errors.size() > 60 and mean < MOTION_LIMIT, "the host's fish shows where it was (mean %.2f m, worst %.2f m over %d ticks)" % [mean, worst, errors.size()])
	var behind := net.sender_now() - net.render_time()
	check(behind < 0.2, "a little behind it (%d ms)" % roundi(behind * 1000.0))


## Our copy of the host's school, fish for fish.
func _check_schools(coop: CoopSession) -> void:
	await _seconds(1.0)
	var run: NatureRun = main.nature_run
	var gaps := PackedFloat32Array()
	for entry: Array in _school_truth:
		var school := run.school_by_id(entry[1])
		if school == null:
			continue
		var age: float = coop._host_clock.sender_now() - entry[0]
		var positions: PackedVector3Array = entry[2]
		for i in mini(positions.size(), school.fish_count()):
			if school.is_alive(i):
				gaps.append((school.fish_position(i) - school.fish_velocity(i) * age).distance_to(positions[i]))
		break  # the latest
	var mean := 0.0
	for g in gaps:
		mean += g
	mean /= maxf(gaps.size(), 1.0)
	check(gaps.size() > 10 and mean < SCHOOL_LIMIT, "the host's school swims here as it does there (mean %.2f m over %d fish)" % [mean, gaps.size()])


# --- Both ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if role != "host" or not NetSession.is_online():
		return
	if _circle:
		_circle_time += delta
		var radius := 12.0
		var speed := 14.0
		var angle := _circle_time * speed / radius
		var centre := Vector3(0, 20, -40)
		var tangent := Vector3(-sin(angle), 0, cos(angle))
		fish.global_transform = Transform3D(Basis.looking_at(tangent, Vector3.UP), centre + Vector3(cos(angle), 0, sin(angle)) * radius)
		fish.linear_velocity = tangent * speed
	if Engine.get_physics_frames() % 4 == 0:
		_truth_rpc.rpc(Time.get_ticks_usec() / 1e6, fish.global_position)
	if Engine.get_physics_frames() % 30 == 0 and main.nature_run and not main.nature_run.schools.is_empty():
		var school: School = main.nature_run.schools[0]
		var positions := PackedVector3Array()
		for i in school.fish_count():
			positions.append(school.fish_position(i))
		_school_rpc.rpc(Time.get_ticks_usec() / 1e6, school.id, positions)


@rpc("authority", "call_remote", "unreliable")
func _truth_rpc(time: float, position: Vector3) -> void:
	_truth.append([time, position])
	while _truth.size() > 200:
		_truth.pop_front()


@rpc("authority", "call_remote", "unreliable")
func _school_rpc(time: float, id: int, positions: PackedVector3Array) -> void:
	_school_truth.push_front([time, id, positions])
	_school_truth.resize(mini(_school_truth.size(), 4))


func _truth_at(time: float) -> Variant:
	for i in range(_truth.size() - 1, 0, -1):
		var a: Array = _truth[i - 1]
		var b: Array = _truth[i]
		if time >= a[0] and time <= b[0]:
			return (a[1] as Vector3).lerp(b[1], (time - a[0]) / maxf(b[0] - a[0], 0.0001))
	return null


var _phase_data := {}


## The host tells the guests (or one role) what's next, and (by default) waits for them.
func _phase(phase: String, data: Dictionary, wait := true, only := "guest") -> void:
	_done.erase(phase)
	_phase_rpc.rpc(phase, data, only)
	if wait:
		await _wait_done(phase, 15.0)


func _wait_done(phase: String, seconds: float) -> void:
	if not await _wait(func() -> bool: return _done.has(phase), seconds):
		check(false, "the guest finished '%s'" % phase)


@rpc("authority", "call_remote", "reliable")
func _phase_rpc(phase: String, data: Dictionary, only: String) -> void:
	if only != role:
		return
	_phase_data = data
	_phase_name = phase


func _send_done(phase: String) -> void:
	_done_rpc.rpc_id(1, phase)


@rpc("any_peer", "call_remote", "reliable")
func _done_rpc(phase: String) -> void:
	_done[phase] = true


func _other_pid(coop: CoopSession) -> int:
	for pid: int in coop.roster:
		if pid / 100 != 1:
			return pid
	return -1


func _school_with_fish(run: NatureRun) -> School:
	var best: School = null
	for school in run.schools:
		if school.alive_count() > 0 and (best == null or school.alive_count() > best.alive_count()):
			best = school
	return best


func _alive_index(school: School) -> int:
	for i in school.fish_count():
		if school.is_alive(i):
			return i
	return -1


## Our fish right behind school fish `index`, nose on and fast, until it's battered.
func _ram_school_fish(school: School, index: int) -> void:
	for i in 40:
		if not is_instance_valid(school) or index < 0 or not school.is_alive(index):
			break
		var heading := Vector3(1, 0, 0.2).normalized()
		fish.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), school.fish_position(index) - heading * 0.9)
		fish.linear_velocity = heading * (fish.nature_batter_speed + 6.0)
		fish.angular_velocity = Vector3.ZERO
		await get_tree().physics_frame
	fish.linear_velocity = Vector3.ZERO


## Our fish 2.5 m behind the lone fish, nose on and fast, then let it close in.
func _ram_target(run: NatureRun) -> void:
	var heading := -run.target.global_basis.z
	fish.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), run.target.global_position - heading * 2.5)
	fish.linear_velocity = heading * (fish.nature_batter_speed + 6.0)
	fish.angular_velocity = Vector3.ZERO
	for i in 40:
		if run.target.battered:
			break
		await get_tree().physics_frame
	fish.linear_velocity = Vector3.ZERO


func _wait(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while not condition.call():
		if left <= 0.0:
			return false
		await get_tree().physics_frame
		left -= 1.0 / 120.0
	return true


func _seconds(seconds: float) -> void:
	await _ticks(roundi(seconds * 120.0))


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## How many batteries we've claimed in `run` (a guest's: each goes to the host).
func _claimed(run: NatureRun) -> int:
	if not run.has_meta("probe_claims"):
		run.set_meta("probe_claims", 0)
		run.battery_claimed.connect(func(_key: String, attacker: FishController, _chain: int) -> void:
			if attacker == fish:
				run.set_meta("probe_claims", run.get_meta("probe_claims") + 1))
	return run.get_meta("probe_claims")
