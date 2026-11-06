extends Node
## Online Marco Polo (MarcoPoloNet, CoopSession's mpm) over ENet on this
## machine: a host and two guests, each its own Godot process, plus the host's
## bots (tests/marco_polo_net.sh starts them):
##   Godot_console.exe --headless --path . res://tests/marco_polo_net_peer.tscn -- --role=host --port=N
##   ... -- --role=a --port=N --lag=60 --jitter=20 --loss=0.02
##   ... -- --role=b --port=N --lag=30
## The host directs (_phase_rpc: this node is /root/Probe everywhere); each
## process checks what it can see and prints its own results.
## - Joining: each guest's match is in the host's arena, a guest (no world of
##   its own), with puppets of the host, the other guest and the host's bots.
## - A round: guest a seeks (held through the count), the rest hide, on every machine.
## - Privacy: each guest's view packets carry only what its player may know: a
##   hider its own exposure and tally, a seeker the hiders' exposures and no
##   points; nobody gets another player's round tally until ROUND_OVER.
## - A guest's hider's burst makes noise on the host; a guest seeker's
##   "Marco!" is called on the host, answered with Polo! pings on its scope.
## - A guest's Fake Fish is thrown on the host.
## - A porthole: the host hides in one, the guests hear it (is_hidden), the
##   host's camera looks out of it; out again.
## - A tag on the host eliminates the guest everywhere.
## - ROUND_OVER: every machine has the host's totals.
## - The host leaving sends the guests back to Marco Polo of their own.

var role := "host"
var port := NetSession.DEFAULT_PORT
var main: Node
var fish: FishController
var mp := MarcoPoloSettings.shared()
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
	print("marco_polo_net_peer [%s]: %s" % [role, "all checks passed" if failures == 0 else "%d FAILED" % failures])
	get_tree().quit(1 if failures else 0)


func _run() -> void:
	mp.arena = "Sunken Temple" if main.ENVIRONMENTS.has("Sunken Temple") else "Ocean"
	main.set_mode(main.MARCO_POLO)
	await _ticks(10)
	if role == "host":
		await _host()
	else:
		await _guest()
	_finish()


# --- Host ------------------------------------------------------------------

func _host() -> void:
	mp.min_players = 5
	mp.rounds = 0
	mp.bot_seeker_rounds = 0
	mp.seekers = 1
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	mp.hide_time = 3.0
	mp.round_time = 120.0
	mp.round_over_time = 3.0
	main._match_card.play_requested.emit()
	await _ticks(5)
	var game: MarcoPoloMatch = main.marco_polo
	check(game != null and game.authority and game.bots.size() == 4, "our match, four bots to fill it (%s)" % mp.arena)
	print("host: hosting on %d" % port)
	NetSession.host_enet(port)
	await _ticks(5)
	var coop: CoopSession = NetSession.coop
	check(NetSession.is_host() and coop.mpm == game, "hosting: the session has our match")
	if not await _wait(func() -> bool: return _pids.has("a") and _pids.has("b"), 30.0):
		check(false, "both guests joined")
		return
	await _seconds(1.0)
	var fa := coop.fish_of(int(_pids.a))
	var fb := coop.fish_of(int(_pids.b))
	check(fa != null and fb != null and fa.puppet and fb.puppet and fa in game.players and fb in game.players, "both guests' fish are puppets in our match")
	await _phase("joined", {"players": game.players.size(), "bots": game.bots.size()})

	print("host: a round, guest a seeking")
	var order := game.seeker_order()
	var index := order.find(fa)
	check(index >= 0, "guest a takes a turn seeking")
	game.start_round(maxi(index, 0))
	await _ticks(5)
	check(game.seekers() == [fa] and game.bots.size() == 2, "a seeks; two bots left now people fill the seats (%d)" % game.bots.size())
	await _phase("round", {"seeker": int(_pids.a), "players": game.players.size()})
	if not await _wait(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, 10.0):
		check(false, "LIVE")
		return
	await _phase("live", {})

	print("host: privacy")
	game._tally[fb] = 7.0
	game.set_exposure(fb, 0.5)
	await _seconds(0.5)
	var to_a: Array = coop.marco_polo_net.sent_views.get(int(_pids.a) / 100, [])
	var to_b: Array = coop.marco_polo_net.sent_views.get(int(_pids.b) / 100, [])
	check(not to_b.is_empty() and (to_b[0] as Dictionary).keys() == [int(_pids.b)] and float(to_b[1]) >= 7.0,
			"b's view: only its own exposure and its own tally (%s)" % [to_b])
	var hider_ids := []
	for h in game.live_hiders():
		hider_ids.append(coop.marco_polo_net.id_of(h))
	var a_keys: Array = (to_a[0] as Dictionary).keys() if not to_a.is_empty() else [-999]
	check(not to_a.is_empty() and is_zero_approx(float(to_a[1])) and a_keys.all(func(id: Variant) -> bool: return int(id) in hider_ids),
			"a's view (the seeker): hiders' exposures, no points (%s)" % [to_a])
	await _phase("privacy", {"b": int(_pids.b)})

	print("host: noise from a guest")
	var before := game.noise(fb)
	await _phase("burst", {}, true, "b")
	await _seconds(0.3)
	check(game.noise(fb) > before + 0.3, "b's burst made noise here (%.2f -> %.2f)" % [before, game.noise(fb)])

	print("host: Marco! from a guest")
	var called := []
	game.marco_called.connect(func(s: FishController) -> void: called.append(s))
	await _phase("marco", {}, true, "a")
	await _wait(func() -> bool: return not called.is_empty(), 3.0)
	check(called == [fa] and game.marco_ready(fa) < 1.0, "a's Marco! was called here, on its cooldown")
	await _seconds(0.5)
	await _phase("pinged", {}, true, "a")

	print("host: a Fake Fish from a guest")
	var charges := game.fake_charges(fb)
	await _phase("fake", {}, true, "b")
	await _wait(func() -> bool: return not game.decoys().is_empty(), 3.0)
	check(not game.decoys().is_empty() and game.decoy_owner(game.decoys()[0]) == fb and game.fake_charges(fb) == charges - 1,
			"b's Fake Fish was thrown here (%d left)" % game.fake_charges(fb))

	print("host: a porthole")
	var holes: Array = game.porthole_system.call("portholes") if game.porthole_system else []
	if holes.is_empty():
		print("  [host] (no portholes in %s: skipped)" % mp.arena)
	else:
		game.porthole_system.call("_enter", fish, holes[0])
		await _ticks(3)
		var pose: Variant = main._camera.get("pose_override").call(fish)
		check(game.is_hidden(fish) and pose is Transform3D, "we're in a porthole, the camera looking out of it")
		await _phase("hidden", {"pid": coop.pid_of(fish), "hidden": true}, true, "all")
		game.porthole_system.call("request_exit", fish)
		await _wait(func() -> bool: return not game.is_hidden(fish), 2.0)
		check(not game.is_hidden(fish), "out again")
		await _phase("hidden", {"pid": coop.pid_of(fish), "hidden": false}, true, "all")

	if holes.size() >= 2:
		print("host: a guest in a porthole")
		var holes_of: PortholeSystem = game.porthole_system
		await _phase("b_porthole", {"k": 1}, true, "b")
		check(holes_of.is_hidden(fb) and holes_of.porthole_of(fb) == holes_of.porthole_at(1), "b swam into porthole 1: it's theirs here")
		game.set_exposure(fb, 0.95)  # showing all over: only the porthole hides its plate
		await _seconds(0.3)
		await _phase("a_plate", {"b": int(_pids.b), "hidden": true}, true, "a")
		await _phase("b_exit", {}, true, "b")
		await _wait(func() -> bool: return not holes_of.is_hidden(fb), 2.0)
		check(not holes_of.is_hidden(fb) and holes_of.porthole_at(1).occupant == null, "b jumped out: out here too")
		print("host: a taken porthole")
		holes_of.call("_enter", fish, holes_of.porthole_at(0))
		await _ticks(3)
		await _phase("b_denied", {"j": 0, "host": coop.pid_of(fish)}, true, "b")
		check(holes_of.porthole_of(fish) == holes_of.porthole_at(0) and not holes_of.is_hidden(fb), "porthole 0 stays ours; b isn't in it")
		holes_of.request_exit(fish)
		await _wait(func() -> bool: return not holes_of.is_hidden(fish), 2.0)
	elif not holes.is_empty():
		print("  [host] (one porthole in %s: the guest porthole checks skipped)" % mp.arena)

	print("host: a tag")
	game.tag(fa, fb)
	await _ticks(3)
	check(game.eliminated.has(fb), "a tagged b: eliminated")
	await _phase("tagged", {"b": int(_pids.b)}, true, "all")

	print("host: ROUND_OVER")
	game.time_left = 0.01
	await _wait(func() -> bool: return game.phase == MarcoPoloMatch.Phase.ROUND_OVER, 3.0)
	check(game.phase == MarcoPoloMatch.Phase.ROUND_OVER, "the round's over")
	var totals := {}
	for f: FishController in game.match_totals:
		totals[coop.marco_polo_net.id_of(f)] = float(game.match_totals[f])
	await _seconds(0.5)
	await _phase("round_over", {"totals": totals}, true, "all")

	print("host: leaving")
	await _phase("leaving", {}, false, "all")
	await _seconds(0.5)
	NetSession.leave()
	await _seconds(2.0)


# --- Guests ----------------------------------------------------------------

func _guest() -> void:
	await _seconds(0.5 if role == "a" else 2.5)
	print("%s: joining" % role)
	NetSession.join_enet("127.0.0.1", port)
	var coop: CoopSession = NetSession.coop
	if not await _wait(func() -> bool: return coop._welcomed and main.marco_polo != null and not main.marco_polo.authority, 20.0):
		check(false, "welcomed into the host's Marco Polo")
		return
	await _seconds(0.5)
	var game: MarcoPoloMatch = main.marco_polo
	check(main.current_environment == mp.arena and coop.mpm == game, "welcomed: a guest's match in the host's arena (%s)" % main.current_environment)
	_hello_rpc.rpc_id(1, role, coop.pid_of(fish))
	while true:
		await _wait(func() -> bool: return _phase_name != "", 60.0)
		var phase := _phase_name
		var data: Dictionary = _phase_data
		_phase_name = ""
		game = main.marco_polo
		match phase:
			"":
				check(false, "the host carried on")
				return
			"joined":
				var host_fish := coop.fish_of(100)
				check(host_fish != null and host_fish.puppet and host_fish in game.players, "the host's fish is a puppet here")
				await _wait(func() -> bool: return game.players.size() == int(data.players), 3.0)
				check(game.players.size() == int(data.players) and game.bots.is_empty(), "everyone's here (%d of %d), the bots puppets (none run here)" % [game.players.size(), data.players])
			"round":
				await _wait(func() -> bool: return game.players.size() == int(data.players), 3.0)
				var seeker := coop.marco_polo_net.fish_by_id(int(data.seeker))
				check(seeker != null and game.seekers() == [seeker], "the host's round: a seeks here too")
				check(game.phase == MarcoPoloMatch.Phase.COUNTDOWN, "counting down")
				if role == "a":
					check(game.role_of(fish) == MarcoPoloMatch.Role.SEEKER and fish.controls_locked and fish.boost_enabled, "we seek: held through the count, with boost")
				else:
					check(game.role_of(fish) == MarcoPoloMatch.Role.HIDER and not fish.controls_locked and not fish.boost_enabled, "we hide: free, no boost")
			"live":
				check(game.phase == MarcoPoloMatch.Phase.LIVE, "LIVE here too")
				if role == "a":
					check(not fish.controls_locked, "the seeker's let go")
			"privacy":
				var fb := coop.marco_polo_net.fish_by_id(int(data.b))
				if role == "b":
					check(game._net_exposure.keys() == [fish] and game.max_exposure(fish) > 0.2, "we know our own exposure (%.2f), nobody else's" % game.max_exposure(fish))
					check(game.own_round_tally(fish) >= 7.0, "and our own round tally (%.1f)" % game.own_round_tally(fish))
				else:
					check(is_zero_approx(game.round_tally(fb)) and is_zero_approx(game.own_round_tally(fb)), "b's points aren't here")
					check(game._net_exposure.has(fb), "but its exposure to us is (%.2f)" % float(game._net_exposure.get(fb, 0.0)))
			"burst":
				game.noise_meter(fish).add(0.8)
			"marco":
				check(game.marco(fish), "Marco! (to the host)")
			"pinged":
				check(not game.recent_pings(fish).is_empty() and game.marco_ready(fish) < 1.0, "Polo! answers on our scope (%d pings), the call on its cooldown" % game.recent_pings(fish).size())
			"fake":
				check(game.throw_fake(fish), "a Fake Fish (to the host)")
			"hidden":
				var host_fish := coop.fish_of(int(data.pid))
				await _wait(func() -> bool: return game.is_hidden(host_fish) == bool(data.hidden), 3.0)
				check(game.is_hidden(host_fish) == bool(data.hidden), "the host's %s a porthole here" % ("in" if data.hidden else "out of"))
			"b_porthole":
				var holes_of: PortholeSystem = game.porthole_system
				var p := holes_of.porthole_at(int(data.k))
				await _drive_in(holes_of, p)
				await _wait(func() -> bool: return game.is_hidden(fish), 2.0)
				check(game.is_hidden(fish) and holes_of.porthole_of(fish) == p, "into porthole %d, and the host says we're hidden" % data.k)
				var pose: Variant = main._camera.get("pose_override").call(fish)
				check(pose is Transform3D and (pose as Transform3D).origin.is_equal_approx(holes_of.camera_transform(fish).origin),
						"the camera looks out of it")
			"b_exit":
				var holes_of: PortholeSystem = game.porthole_system
				holes_of.request_exit(fish)
				await _wait(func() -> bool: return holes_of.porthole_of(fish) == null, 1.0)
				var speed := fish.linear_velocity.length()
				check(holes_of.porthole_of(fish) == null and speed > mp.porthole_exit_speed * 0.5,
						"jumped out (%.1f m/s, exit speed %.1f)" % [speed, mp.porthole_exit_speed])
				await _wait(func() -> bool: return not game.is_hidden(fish), 2.0)
				check(not game.is_hidden(fish), "and the host says we're out")
			"b_denied":
				var holes_of: PortholeSystem = game.porthole_system
				var p := holes_of.porthole_at(int(data.j))
				var host_fish := coop.fish_of(int(data.host))
				await _wait(func() -> bool: return p.occupant == host_fish, 2.0)
				await _drive_in(holes_of, p)
				await _seconds(1.0)
				check(not game.is_hidden(fish) and holes_of.porthole_of(fish) == null and p.occupant == host_fish,
						"porthole %d is the host's: we're not in it" % data.j)
			"a_plate":
				var fb := coop.marco_polo_net.fish_by_id(int(data.b))
				check(game.is_hidden(fb) and not game.shows_plate(fb), "b in a porthole: no name plate for us (exposure %.2f)" % game.local_exposure(fb))
			"tagged":
				var fb := coop.marco_polo_net.fish_by_id(int(data.b))
				await _wait(func() -> bool: return game.eliminated.has(fb), 3.0)
				check(game.eliminated.has(fb), "b's eliminated here")
				if role == "b":
					check(fish.controls_locked, "we're out: spectating")
			"round_over":
				var mine := {}
				for f: FishController in game.match_totals:
					mine[coop.marco_polo_net.id_of(f)] = float(game.match_totals[f])
				var same := true
				for id: Variant in data.totals:
					same = same and absf(float(mine.get(int(id), -1.0)) - float(data.totals[id])) < 0.01
				check(game.phase == MarcoPoloMatch.Phase.ROUND_OVER and same, "ROUND_OVER with the host's totals (%s)" % [mine])
			"leaving":
				_send_done(phase)
				await _wait(func() -> bool: return main.marco_polo != null and main.marco_polo.authority, 10.0)
				check(main.marco_polo != null and main.marco_polo.authority and not main.marco_polo.bots.is_empty(), "the host left: Marco Polo of our own, with bots")
				return
		_send_done(phase)


# --- Helpers ---------------------------------------------------------------

## Our fish 3 m out on `p`'s axis, facing in, swimming in at 2 m/s until it's
## in (here) or 1.5 s pass.
func _drive_in(holes_of: PortholeSystem, p: Porthole) -> void:
	var axis := p.axis().normalized()
	fish.global_transform = Transform3D(Basis.looking_at(-axis), p.mouth() + axis * 3.0)
	var left := 1.5
	while left > 0.0 and holes_of.porthole_of(fish) == null:
		fish.linear_velocity = -axis * 2.0
		fish.angular_velocity = Vector3.ZERO
		await get_tree().physics_frame
		left -= 1.0 / 120.0


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
		if not await _wait(func() -> bool: return _done.has(key), 15.0):
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
