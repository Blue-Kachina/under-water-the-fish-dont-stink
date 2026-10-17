extends Node
## Online co-op in Unnatural (UnnaturalNet, CoopSession's urun) over ENet on
## this machine: run as a host and guests, each its own Godot process
## (tests/unnatural_net.sh starts them):
##   Godot_console.exe --headless --path . res://tests/unnatural_net_peer.tscn -- --role=host --port=N
##   ... -- --role=guest --port=N --lag=60 --jitter=20 --loss=0.02
##   ... -- --role=late --port=N        (joins later)
## The host directs (_phase, a probe RPC: this node is /root/Probe everywhere);
## each process checks what it can see and prints its own results.
## - Joining: the guest's run is in the host's world (its chests), each has a
##   puppet of the other, and the host's Unnatural tuning is the guest's.
## - Zombies: the host's spawns reach the guest; a guest's hit kills on the
##   host (its own copy waits for the host's word); corrections keep the
##   guest's copies close to where the host has them while they swim.
## - Pearls: a guest's pickup gives the team XP once; both on one at once, once.
## - Chests: a guest opens one on the host, the host's open shows on the guest,
##   a newly buried one turns up there.
## - A boss: the guest gets a puppet of it, its body where the host has it, and
##   its defeat (the Drowned Shark's chest too).
## - Down and revive: a guest going down shows on the host; the host's fish
##   beside them revives them.
## - A late joiner gets the run as it is (zombies, chests, level, kills).
## - The host restarting restarts everyone; the host leaving sends a guest back
##   to Unnatural on its own.

## How far (m) a guest's copy of a moving zombie may be from the host's, on average.
const SWIM_LIMIT := 2.0

var role := "host"
var port := NetSession.DEFAULT_PORT
var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var failures := 0
var _phase_name := ""
var _phase_data := {}
var _done := {}


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
	print("unnatural_net_peer [%s]: %s" % [role, "all checks passed" if failures == 0 else "%d FAILED" % failures])
	get_tree().quit(1 if failures else 0)


func _run() -> void:
	main.set_mode(main.UNNATURAL)
	await _ticks(10)
	if role == "host":
		await _host()
	else:
		await _guest()
	_finish()


# --- Host ------------------------------------------------------------------

func _host() -> void:
	# The host's tuning becomes the guests' as they join.
	settings.spawning = false
	settings.stage_events = false
	settings.chest_count = 3
	settings.chest_interval = 0.0
	settings.chest_open_time = 999.0  # nobody opens one by idling beside it
	settings.enemy_speed_scale = 0.0
	settings.god_mode = true
	settings.revive_time = 0.5
	# Only the probe's hits kill: every fish's bite does nothing, and so do batteries.
	settings.fish_attack = 2
	settings.bite_damage = 0.0
	settings.battery_damage = 0.0
	settings.twists = false
	main._match_card.play_requested.emit()
	await _ticks(5)
	print("host: hosting on %d" % port)
	NetSession.host_enet(port)
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	check(NetSession.is_host() and run != null and run.authority, "hosting: our Unnatural run, the world ours")
	var coop: CoopSession = NetSession.coop
	check(coop.urun == run, "the session has our run")
	if not await _wait(func() -> bool: return coop.roster.size() >= 2, 20.0):
		check(false, "a guest joined")
		return
	check(true, "a guest joined (%d playing)" % coop.roster.size())
	await _seconds(1.0)
	var guest_pid := _other_pid(coop)
	var guest_fish := coop.fish_of(guest_pid)
	check(guest_fish != null and guest_fish.puppet and guest_fish in run.players, "the guest's fish is a puppet in our run")
	await _phase("joined", {"chests": run.chests.size(), "chest_at": run.chests[0].position if not run.chests.is_empty() else Vector3.ZERO})

	print("host: zombies")
	var at := fish.global_position + Vector3(0, 0, -25)
	run.horde.spawn_pack(0, 20, at, 4.0)
	await _seconds(0.5)
	await _phase("spawns", {"zombies": _zombies(run)})

	var target := _zombie_ids(run)[0]
	var kills_before := run.kills
	var guest_kills: int = run.stats_of(guest_fish).kills
	await _phase("guest_hits", {"id": target})
	check(run.horde.index_of_net(target) < 0 and run.kills == kills_before + 1, "the guest's hit killed it here")
	check(run.stats_of(guest_fish).kills == guest_kills + 1, "...for them (%d kills)" % run.stats_of(guest_fish).kills)

	print("host: pearls")
	var xp_before := run.levels.total_xp
	var guest_pearls: int = run.stats_of(guest_fish).pearls
	await _phase("guest_pearl", {"id": target})
	await _seconds(0.5)
	check(run.pearl_by_id(target) == null and run.stats_of(guest_fish).pearls == guest_pearls + 1, "the guest's pearl counted here, for them")
	check(run.levels.total_xp > xp_before, "the team's XP went up (%.1f)" % (run.levels.total_xp - xp_before))
	# One pearl, both of us on it at once: it counts once.
	var race := _zombie_ids(run)[0]
	var race_at := run.horde.enemy_position(run.horde.index_of_net(race))
	var pearls_before := _pearls(run, [fish, guest_fish])
	run.hit(run.horde.index_of_net(race), 1e6, fish, "probe")
	await _phase("pearl_race", {"at": race_at}, false)
	_hold_at(race_at + Vector3(0.4, 0, 0), 1.2)
	await _seconds(1.2)
	check(_pearls(run, [fish, guest_fish]) == pearls_before + 1, "two of us on one pearl: counted once (%d)" % (_pearls(run, [fish, guest_fish]) - pearls_before))
	await _phase("pearl_count", {"level": run.levels.level, "xp": run.levels.xp})

	print("host: swimming")
	settings.enemy_speed_scale = 1.0
	main._panel.tuning_changed.emit()
	await _seconds(1.5)
	await _phase("swimming", {})
	settings.enemy_speed_scale = 0.0
	main._panel.tuning_changed.emit()

	print("host: chests")
	var guest_chests: int = run.stats_of(guest_fish).get("chests", 0)
	await _phase("guest_chest", {})
	await _seconds(0.5)
	check(run.chests[0].opened and run.stats_of(guest_fish).get("chests", 0) == guest_chests + 1, "the guest opened chest 0: open here, theirs")
	run.open_chest(run.chests[1], fish)
	run._bury_chest()
	await _seconds(0.5)
	await _phase("host_chest", {"count": run.chests.size(), "last": run.chests[-1].position})

	print("host: boss")
	run._start_event("miniboss")
	await _seconds(1.5)
	var boss := run.current_boss()
	check(boss is DrownedShark, "the Drowned Shark came")
	if boss:
		await _phase("boss", {"id": boss.boss_id, "at": boss.global_position, "hp": boss.hp})
		boss.take(boss.hp + 1.0, fish, "probe")
		await _seconds(2.0)
		check(run.current_boss() == null, "we beat it")
		await _phase("boss_down", {"chests": run.chests.size()})

	print("host: down and revive")
	await _phase("go_down", {})
	await _seconds(0.5)
	var guest_health := run.health_of(guest_fish)
	check(guest_health.down and not run.is_over, "the guest went down: down here too, the run goes on")
	_hold_at(guest_fish.global_position + Vector3(1.5, 0, 0), 2.0)
	await _seconds(2.0)
	check(not guest_health.down, "we stayed beside them: they're up again here")
	await _phase("revived", {})

	print("host: late joiner")
	if await _wait(func() -> bool: return coop.roster.size() >= 3, 60.0):
		await _seconds(2.0)
		var opened := []
		for chest in run.chests:
			opened.append(chest.opened)
		await _phase("late_check", {"zombies": _zombie_ids(run).size(), "opened": opened, "level": run.levels.level, "kills": run.kills},
				false, "late")
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
	run = main.unnatural_run
	check(run.horde.alive_count() == 0 and run.levels.level == 1, "restarted here")
	await _phase("restarted", {"chests": run.chests.size(), "level": run.levels.level})

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
	if not await _wait(func() -> bool: return coop._welcomed and main.unnatural_run != null and not main.unnatural_run.authority, 20.0):
		check(false, "welcomed into the host's Unnatural run")
		return
	await _seconds(1.0)
	var run: UnnaturalRun = main.unnatural_run
	check(not run.authority and coop.urun == run and coop.roster.size() >= 2, "welcomed: an Unnatural run of ours in the host's world")
	var host_fish := coop.fish_of(100)
	check(host_fish != null and host_fish.puppet and host_fish in run.players, "the host's fish is a puppet here")
	check(settings.god_mode and settings.chest_open_time > 100.0, "the host's Unnatural tuning is ours")
	if role == "late":
		await _late()
		return
	while true:
		await _wait(func() -> bool: return _phase_name != "", 60.0)
		var phase := _phase_name
		var data: Dictionary = _phase_data
		_phase_name = ""
		run = main.unnatural_run
		match phase:
			"":
				check(false, "the host carried on")
				return
			"joined":
				check(run.chests.size() == data.chests and (run.chests.is_empty() or run.chests[0].position.is_equal_approx(data.chest_at)),
						"the host's chests are here (%d)" % run.chests.size())
			"spawns":
				var missing := 0
				var worst := 0.0
				for entry: Array in data.zombies:
					var index := run.horde.index_of_net(entry[0])
					if index < 0:
						missing += 1
					else:
						worst = maxf(worst, run.horde.enemy_position(index).distance_to(entry[1]))
				check(missing == 0 and worst < 0.5, "the host's %d zombies are here, where it has them (%d missing, worst %.2f m)" % [data.zombies.size(), missing, worst])
			"guest_hits":
				var index := run.horde.index_of_net(data.id)
				run.hit(index, 1e6, fish, "probe")
				await _ticks(2)
				check(run.horde.is_alive(index), "our hit: our copy waits for the host's word")
				await _wait(func() -> bool: return run.horde.index_of_net(data.id) < 0, 3.0)
				check(run.horde.index_of_net(data.id) < 0, "the host said: dead here too")
			"guest_pearl":
				var pearl := run.pearl_by_id(data.id)
				check(pearl != null, "its pearl dropped here, the same id")
				if pearl:
					_hold_at(pearl.global_position, 1.0)
					await _seconds(1.0)
				check(run.pearl_by_id(data.id) == null, "we took it")
			"pearl_race":
				_hold_at(data.at + Vector3(-0.4, 0, 0), 1.2)
			"pearl_count":
				await _seconds(0.5)
				check(run.levels.level == data.level and is_equal_approx(run.levels.xp, data.xp),
						"the team's level and XP are the host's (level %d, %.1f xp)" % [run.levels.level, run.levels.xp])
			"swimming":
				await _check_swimming(coop)
			"guest_chest":
				run.open_chest(run.chests[0], fish)
				await _seconds(0.3)
			"host_chest":
				check(run.chests[1].opened, "the host opened chest 1: open here too")
				check(run.chests.size() == data.count and run.chests[-1].position.is_equal_approx(data.last), "a new chest buried there turned up here")
			"boss":
				var boss := run.boss_by_id(data.id)
				check(boss is DrownedShark and boss.puppet, "a puppet of the host's Drowned Shark is here")
				if boss:
					check(boss.global_position.distance_to(data.at) < 4.0 and is_equal_approx(boss.hp, data.hp),
							"where the host has it (%.1f m off), its health the host's" % boss.global_position.distance_to(data.at))
			"boss_down":
				await _wait(func() -> bool: return run.current_boss() == null, 3.0)
				check(run.current_boss() == null, "the host beat it: gone here too")
				check(run.chests.size() == data.chests, "its chest is here too (%d chests)" % run.chests.size())
			"go_down":
				settings.god_mode = false
				var health := run.health_of(fish)
				health.iframes_left = 0.0
				run.hurt(fish, health.hp + 10.0)
				settings.god_mode = true
				check(health.down, "we're down")
				fish.freeze = true  # still, for the host to come beside us
			"revived":
				await _wait(func() -> bool: return not run.health_of(fish).down, 2.0)
				check(not run.health_of(fish).down and not fish.controls_locked, "the host's fish beside us revived us")
				fish.freeze = false
			"restarted":
				await _seconds(0.5)
				run = main.unnatural_run
				check(run.horde.alive_count() == 0 and run.current_boss() == null and run.levels.level == data.level and run.kills == 0,
						"the host restarted: so did we")
				check(run.chests.size() == data.chests, "with the host's new chests (%d)" % run.chests.size())
			"host_leaving":
				await _wait(func() -> bool: return not NetSession.is_online(), 10.0)
				await _seconds(0.5)
				check(not NetSession.is_online() and main.unnatural_run != null and main.unnatural_run.authority,
						"the host left: Unnatural on our own again")
				return
		_send_done(phase)


func _late() -> void:
	await _wait(func() -> bool: return _phase_name == "late_check", 30.0)
	var data: Dictionary = _phase_data
	_phase_name = ""
	var run: UnnaturalRun = main.unnatural_run
	var opened := []
	for chest in run.chests:
		opened.append(chest.opened)
	check(_zombie_ids(run).size() == data.zombies, "joining late: the host's zombies are here (%d of %d)" % [_zombie_ids(run).size(), data.zombies])
	check(opened == data.opened, "...its chests, open and shut (%s)" % str(opened))
	check(run.levels.level == data.level and run.kills == data.kills, "...and its level and kills (%d, %d)" % [run.levels.level, run.kills])
	_send_done("late_check")
	await _wait(func() -> bool: return _phase_name == "late_leave", 30.0)
	NetSession.leave()
	await _seconds(0.3)


## Our copies of the host's zombies while they swim, against where the host has
## them (sent with its clock, moved on by their velocity to now).
func _check_swimming(coop: CoopSession) -> void:
	_swim_truth.clear()
	await _seconds(2.0)
	var run: UnnaturalRun = main.unnatural_run
	var gaps := PackedFloat32Array()
	var moving := 0
	var age := 0.0
	var speeds := Vector2.ZERO  # theirs, ours (summed)
	if not _swim_truth.is_empty():
		var entry: Array = _swim_truth[0]
		# Since it arrived, plus its trip (the session's host clock only learns
		# from Nature's snapshots, so it isn't set in Unnatural).
		age = Time.get_ticks_usec() / 1e6 - entry[0] + coop.rtt / 2.0
		for n in (entry[1] as PackedInt32Array).size():
			var index := run.horde.index_of_net(entry[1][n])
			if index < 0:
				continue
			var velocity: Vector3 = entry[3][n]
			if velocity.length() > 0.5:
				moving += 1
			speeds += Vector2(velocity.length(), run.horde.enemy_velocity(index).length())
			gaps.append((entry[2][n] + velocity * age).distance_to(run.horde.enemy_position(index)))
	print("  [%s] swim: snapshot %.3f s old, mean speed %.2f there, %.2f here" % [role, age,
			speeds.x / maxf(gaps.size(), 1.0), speeds.y / maxf(gaps.size(), 1.0)])
	var mean := 0.0
	for g in gaps:
		mean += g
	mean /= maxf(gaps.size(), 1.0)
	check(gaps.size() >= 10 and moving >= 5 and mean < SWIM_LIMIT,
			"the host's zombies swim here as they do there (mean %.2f m over %d, %d moving)" % [mean, gaps.size(), moving])


# --- Both ------------------------------------------------------------------

## The host's zombies (guest): [arrival time, net ids, positions, velocities], newest first.
var _swim_truth: Array = []
var _hold := Vector3.INF
var _hold_left := 0.0


func _physics_process(delta: float) -> void:
	if _hold_left > 0.0:
		_hold_left -= delta
		fish.global_position = _hold
		fish.linear_velocity = Vector3.ZERO
	if role != "host" or not NetSession.is_online() or main.unnatural_run == null:
		return
	if Engine.get_physics_frames() % 12 == 0:
		var run: UnnaturalRun = main.unnatural_run
		var ids := PackedInt32Array()
		var positions := PackedVector3Array()
		var velocities := PackedVector3Array()
		for i in run.horde.alive:
			if not run.horde.is_proxy(i):
				ids.append(run.horde.net_id_of(i))
				positions.append(run.horde.enemy_position(i))
				velocities.append(run.horde.enemy_velocity(i))
		_swim_rpc.rpc(Time.get_ticks_usec() / 1e6, ids, positions, velocities)


@rpc("authority", "call_remote", "unreliable")
func _swim_rpc(_time: float, ids: PackedInt32Array, positions: PackedVector3Array, velocities: PackedVector3Array) -> void:
	_swim_truth.push_front([Time.get_ticks_usec() / 1e6, ids, positions, velocities])  # when it arrived, our clock
	_swim_truth.resize(mini(_swim_truth.size(), 4))


## Keeps our fish at `at` for `seconds`.
func _hold_at(at: Vector3, seconds: float) -> void:
	_hold = at
	_hold_left = seconds
	fish.global_position = at
	fish.linear_velocity = Vector3.ZERO


func _zombie_ids(run: UnnaturalRun) -> Array[int]:
	var ids: Array[int] = []
	for i in run.horde.alive:
		if not run.horde.is_proxy(i):
			ids.append(run.horde.net_id_of(i))
	return ids


func _zombies(run: UnnaturalRun) -> Array:
	var list := []
	for i in run.horde.alive:
		if not run.horde.is_proxy(i):
			list.append([run.horde.net_id_of(i), run.horde.enemy_position(i)])
	return list


func _pearls(run: UnnaturalRun, of: Array) -> int:
	var total := 0
	for f: FishController in of:
		total += run.stats_of(f).pearls
	return total


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
