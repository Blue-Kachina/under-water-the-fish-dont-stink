extends Node
## Online Fin-ish Line (RaceNet, CoopSession's mgame) over ENet on this machine: a host and two guests, each its own
## Godot process, plus the host's bots (tests/race_net.sh starts them):
##   Godot_console.exe --headless --path . res://tests/race_net_peer.tscn -- --role=host --port=N
##   ... -- --role=a --port=N --lag=60 --jitter=20 --loss=0.02
##   ... -- --role=b --port=N --lag=30
## The host directs (_phase_rpc: this node is /root/Probe everywhere); each process checks what it can see.
## - Joining: each guest's match is a guest (no world of its own, no bots), with puppets of the host, the other guest
##   and the host's bots; the field stays full (guests take bots' seats).
## - The countdown and GO reach everyone.
## - Positions agree: each person swims a different number of gates; every machine ranks the racers the same way
##   (the host's standings), progress within a few metres.
## - A rescue on the host moves a guest's own fish on the guest's machine, and everyone sees the fade.
## - Laps and finishes: a guest's finish is the host's call, and everyone has the same places and results.
## - The host leaving sends the guests back to a race of their own.

var role := "host"
var port := NetSession.DEFAULT_PORT
var main: Node
var fish: FishController
var failures := 0
var _phase_name := ""
var _phase_data := {}
var _done := {}
## Host: role -> its player's id.
var _pids := {}


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
	print("race_net_peer [%s]: %s" % [role, "all checks passed" if failures == 0 else "%d FAILED" % failures])
	get_tree().quit(1 if failures else 0)


func _run() -> void:
	var rs := RaceSettings.shared()
	rs.laps = 1
	rs.field_size = 5
	rs.countdown = 3.0
	rs.finish_clock = 30.0
	rs.bot_difficulty = RaceSettings.Bots.EASY
	main.set_mode(RaceMatch.ID)
	await _ticks(10)
	if role == "host":
		await _host()
	else:
		await _guest()
	_finish()


func _net(coop: CoopSession) -> RaceNet:
	return coop.net_of(RaceSettings.KEY) as RaceNet


## The checkpoint indices a person swims through for `count` gates: the line (starts the lap), then 1.. and the line again.
func _gate_order(game: RaceMatch, count: int) -> Array:
	var order := [0]
	for i in range(1, game.track.checkpoints.size()):
		order.append(i)
	order.append(0)
	return order.slice(0, count)


## Teleports our fish across `count` gates in order (a tick each side of the gate plane), `wait` seconds a side.
func _swim_gates(game: RaceMatch, who: FishController, count: int, wait: float) -> void:
	var coop: CoopSession = NetSession.coop
	for index: int in _gate_order(game, count):
		var cp: Dictionary = game.track.checkpoints[index]
		var forward: Vector3 = cp["forward"]
		var basis := Basis.looking_at(forward)
		for side: float in [-2.0, 2.0]:
			who.global_transform = Transform3D(basis, (cp["pos"] as Vector3) + forward * side)
			who.linear_velocity = forward * 8.0
			coop.note_teleport(who)
			await _seconds(wait)


# --- Host ------------------------------------------------------------------

func _host() -> void:
	main._match_card.play_requested.emit()
	await _ticks(5)
	var game := main.active_mode() as RaceMatch
	check(game != null and game.authority and game.racers.size() == 5, "our race, five racers to fill the field")
	print("host: hosting on %d" % port)
	NetSession.host_enet(port)
	await _ticks(5)
	var coop: CoopSession = NetSession.coop
	check(NetSession.is_host() and coop.mgame == game, "hosting: the session has our race")
	if not await _wait(func() -> bool: return _pids.has("a") and _pids.has("b"), 30.0):
		check(false, "both guests joined")
		return
	await _seconds(1.0)
	var net := _net(coop)
	var fa := coop.fish_of(int(_pids.a))
	var fb := coop.fish_of(int(_pids.b))
	check(fa != null and fb != null and fa.puppet and fb.puppet and game.racer_of(fa) != null and game.racer_of(fb) != null,
			"both guests' fish are puppets, racing here")
	var bots := game.racers.filter(func(r: RaceMatch.Racer) -> bool: return not r.human)
	check(game.racers.size() == 5 and bots.size() == 2, "the field stays five: two bots left (%d)" % bots.size())
	await _phase("joined", {"racers": game.racers.size(), "bots": bots.size()})

	print("host: countdown and GO")
	game.restart()
	await _ticks(5)
	await _phase("countdown", {})
	if not await _wait(func() -> bool: return game.phase == RaceMatch.Phase.RACING, 10.0):
		check(false, "GO")
		return
	await _phase("go", {})

	print("host: positions")
	var order := {"host": 10, "a": 6, "b": 3}
	_swim_gates(game, fish, order.host, 0.15)
	await _phase("swim", {"count": order.a}, false, "a")
	await _phase("swim", {"count": order.b}, false, "b")
	await _wait(func() -> bool: return game.racer_of(fb).passes >= order.b and game.racer_of(fa).passes >= order.a, 40.0)
	await _seconds(1.0)
	check(game.racer_of(fish).passes >= order.host and game.racer_of(fa).passes >= order.a and game.racer_of(fb).passes >= order.b,
			"the host saw every gate (%d / %d / %d)" % [game.racer_of(fish).passes, game.racer_of(fa).passes, game.racer_of(fb).passes])
	check(game.position_of(fish) < game.position_of(fa) and game.position_of(fa) < game.position_of(fb), "host first, then a, then b: %d %d %d" % [
			game.position_of(fish), game.position_of(fa), game.position_of(fb)])
	await _phase("positions", {"table": _places(game, net)})

	print("host: a rescue")
	var gate := game.racer_of(fa).next_cp
	game.rescue(fa, "stuck")
	await _seconds(0.3)
	await _phase("rescue_fade", {"a": int(_pids.a)}, true, "b")
	await _seconds(game.settings.rescue_fade * 2.0 + 0.5)
	await _phase("rescued", {"gate": gate}, true, "a")

	print("host: finishing")
	var finished := []
	game.racer_finished.connect(func(f: FishController, place: int, _t: float) -> void: finished.append([f, place]))
	await _phase("finish", {"count": 100}, false, "a")
	await _wait(func() -> bool: return not finished.is_empty(), 90.0)
	check(not finished.is_empty() and finished[0][0] == fa, "a finished first here (the host's call)")
	await _swim_gates(game, fish, 100, 0.1)
	await _phase("finish", {"count": 100}, false, "b")
	await _wait(func() -> bool: return game.phase == RaceMatch.Phase.OVER, 90.0)
	check(game.phase == RaceMatch.Phase.OVER and game.results.size() == 5, "every person finished: the race is over (%d results)" % game.results.size())
	await _seconds(1.0)
	var results := []
	for row: Dictionary in game.results:
		results.append([net.id_of(row.fish), int(row.place), bool(row.finished)])
	await _phase("results", {"rows": results})

	print("host: leaving")
	await _phase("leaving", {}, false, "all")
	await _seconds(0.5)
	NetSession.leave()
	await _seconds(2.0)


## id -> [place, progress] for every racer, as this machine ranks them.
func _places(game: RaceMatch, net: RaceNet) -> Dictionary:
	var out := {}
	for r in game.racers:
		out[net.id_of(r.fish)] = [game.position_of(r.fish), snappedf(game.progress_of(r.fish), 0.1)]
	return out


# --- Guests ----------------------------------------------------------------

func _guest() -> void:
	await _seconds(0.5 if role == "a" else 2.5)
	print("%s: joining" % role)
	NetSession.join_enet("127.0.0.1", port)
	var coop: CoopSession = NetSession.coop
	if not await _wait(func() -> bool: return coop._welcomed and main.active_mode() is RaceMatch and not (main.active_mode() as RaceMatch).authority, 20.0):
		check(false, "welcomed into the host's race")
		return
	await _seconds(0.5)
	var game := main.active_mode() as RaceMatch
	var net := _net(coop)
	check(coop.mgame == game and net != null and not net.is_host(), "welcomed: a guest's race")
	_hello_rpc.rpc_id(1, role, coop.pid_of(fish))
	while true:
		await _wait(func() -> bool: return _phase_name != "", 120.0)
		var phase := _phase_name
		var data: Dictionary = _phase_data
		_phase_name = ""
		game = main.active_mode() as RaceMatch
		match phase:
			"":
				check(false, "the host carried on")
				return
			"joined":
				await _wait(func() -> bool: return game.racers.size() == int(data.racers), 5.0)
				var bots := game.racers.filter(func(r: RaceMatch.Racer) -> bool: return not r.human)
				check(game.racers.size() == int(data.racers) and bots.size() == int(data.bots), "everyone's here (%d racers, %d bot puppets)" % [game.racers.size(), bots.size()])
				check(bots.all(func(r: RaceMatch.Racer) -> bool: return r.bot == null and r.fish.puppet), "the bots are puppets: none run here")
				var host_fish := coop.fish_of(100)
				check(host_fish != null and host_fish.puppet and game.racer_of(host_fish) != null, "the host's fish is a puppet racer here")
			"countdown":
				await _wait(func() -> bool: return game.phase == RaceMatch.Phase.COUNTDOWN and game.count_left > 0.0, 3.0)
				check(game.phase == RaceMatch.Phase.COUNTDOWN and game.count_left > 0.0, "counting down here too (%.1f s)" % game.count_left)
			"go":
				await _wait(func() -> bool: return game.phase == RaceMatch.Phase.RACING, 3.0)
				check(game.phase == RaceMatch.Phase.RACING, "GO here too")
			"swim":
				_swim_gates(game, fish, int(data.count), 0.3)
			"positions":
				var table: Dictionary = data.table
				var same := false
				var mine := {}
				for step in 360:
					mine = _places(game, net)
					same = true
					for id: Variant in table:
						var theirs: Array = table[id]
						var ours: Array = mine.get(int(id), [-1, -1.0])
						if int(ours[0]) != int(theirs[0]) or absf(float(ours[1]) - float(theirs[1])) > 3.0:
							same = false
					if same:
						break
					await get_tree().physics_frame
				check(same, "the host's positions are ours (%s vs %s)" % [mine, table])
			"rescue_fade":
				var fa := net.fish_by_id(int(data.a))
				await _wait(func() -> bool: return game.racer_of(fa).rescue_stage != 0 or game.fade_of(fa) > 0.0, 3.0)
				check(game.racer_of(fa).rescue_stage != 0 or game.fade_of(fa) > 0.0, "a's rescue shows here (stage %d)" % game.racer_of(fa).rescue_stage)
			"rescued":
				var count: int = game.track.checkpoints.size()
				var cp: Dictionary = game.track.checkpoints[(int(data.gate) - 1 + count) % count]
				await _wait(func() -> bool: return fish.global_position.distance_to(cp["pos"] as Vector3) < 20.0, 3.0)
				check(fish.global_position.distance_to(cp["pos"] as Vector3) < 20.0, "we were put back at our last gate (%.1f m away)" % fish.global_position.distance_to(cp["pos"] as Vector3))
			"finish":
				await _swim_gates(game, fish, int(data.count), 0.3)
				await _wait(func() -> bool: return game.racer_of(fish).finished, 10.0)
				check(game.racer_of(fish).finished, "the host says we finished (place %d)" % game.racer_of(fish).place)
			"results":
				await _wait(func() -> bool: return game.phase == RaceMatch.Phase.OVER and game.results.size() == 5, 5.0)
				var same := game.results.size() == (data.rows as Array).size()
				for row: Array in data.rows:
					var f := net.fish_by_id(int(row[0]))
					var r := game.racer_of(f) if f else null
					same = same and r != null and r.place == int(row[1]) and r.finished == bool(row[2])
				check(same, "the host's results are ours (%d rows)" % game.results.size())
			"leaving":
				_send_done(phase)
				await _wait(func() -> bool: return main.active_mode() is RaceMatch and (main.active_mode() as RaceMatch).authority, 10.0)
				check(main.active_mode() is RaceMatch and (main.active_mode() as RaceMatch).authority, "the host left: a race of our own")
				return
		_send_done(phase)


# --- Helpers ---------------------------------------------------------------

## The host tells the guests (or one role, or "all") what's next, and (by default) waits for them.
func _phase(phase: String, data: Dictionary, wait := true, only := "all") -> void:
	var waiting: Array = ["a", "b"] if only == "all" else [only]
	for who: String in waiting:
		_done.erase("%s:%s" % [phase, who])
	_phase_rpc.rpc(phase, data, only)
	if not wait:
		return
	for who: String in waiting:
		var key := "%s:%s" % [phase, who]
		if not await _wait(func() -> bool: return _done.has(key), 60.0):
			check(false, "guest %s finished '%s'" % [who, phase])


@rpc("authority", "call_remote", "reliable")
func _phase_rpc(phase: String, data: Dictionary, only: String) -> void:
	if only != role and only != "all":
		return
	_phase_data = data
	_phase_name = phase


func _send_done(phase: String) -> void:
	_done_rpc.rpc_id(1, phase, role)


@rpc("any_peer", "call_remote", "reliable")
func _done_rpc(phase: String, who: String) -> void:
	_done["%s:%s" % [phase, who]] = true


@rpc("any_peer", "call_remote", "reliable")
func _hello_rpc(who: String, pid: int) -> void:
	_pids[who] = pid


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
