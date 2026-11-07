extends Node
## Online What Stinks? (WhatStinksNet, CoopSession's wsm) over ENet on this
## machine: a host with bots and two guests, each its own Godot process
## (tests/what_stinks_net.sh starts them):
##   Godot_console.exe --headless --path . res://tests/what_stinks_net_peer.tscn -- --role=host --port=N
##   ... -- --role=a --port=N --lag=60 --jitter=20 --loss=0.02
##   ... -- --role=b --port=N --lag=30
## The host directs (_phase_rpc: this node is /root/Probe everywhere); each
## process checks what it can see and prints its own results.
## - Joining: each guest's match is a guest's in the host's ocean (no bots of
##   its own, puppets of the host's), the schools the host's (ids, seeds, fish
##   alive), the late joiner too.
## - A round: guest a hunts (held through the count), the rest are prey, the
##   same schools and ocean seed on every machine.
## - Privacy: a Hunter's view packet holds exposures of the live prey and no
##   points; a prey's holds only its own exposure; the exposure a guest Hunter
##   sees is the host's.
## - Joining a school (guest b): the host assigns the place, b is in lockstep
##   with it on both machines; guest a, the Hunter, is never told who joined.
## - Spook (guest b) is the host's call and b's own charges drop.
## - Click and Sniff of a guest Hunter: the host's, shown on the guest.
## - A bite (guest a, on the host's judgement): the school fish go on every
##   machine by the same indices, b (joined, in the bite) is eaten everywhere
##   and out of the round, the alive masks agree.
## - ROUND_OVER: every machine has the host's totals and the reason.
## - Upset Stomach: a bite on b (a loner) spits it out (flung and dazed on b's
##   machine), the Hunter's satiation and queasy bars reach a, a school the host
##   adds and a school's regrowth appear on the guests.
## - The host leaving sends the guests back to What Stinks? of their own.

var role := "host"
var port := NetSession.DEFAULT_PORT
var main: Node
var fish: FishController
var ws := WhatStinksSettings.shared()
var failures := 0
var _phase_name := ""
var _phase_data := {}
var _done := {}
## Where a guest Hunter holds itself for a bite (zero: not holding).
var _lock := Transform3D.IDENTITY
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
	print("what_stinks_net_peer [%s]: %s" % [role, "all checks passed" if failures == 0 else "%d FAILED" % failures])
	get_tree().quit(1 if failures else 0)


## The settings every machine plays by (the guests set the same locally: the host's tuning arrives only on joining).
func _configure() -> void:
	ws.hide_time = 3.0
	ws.round_time = 600.0
	ws.round_over_time = 900.0
	ws.match_over_time = 900.0
	ws.arena_radius = 150.0
	ws.school_count = 5
	ws.school_speed = 0.3
	ws.school_min = 18
	ws.school_max = 24
	ws.min_players = 5
	ws.bot_hunter_rounds = 0
	ws.start_as = WhatStinksSettings.StartAs.HUNTER
	ws.variant = WhatStinksSettings.Variant.SWEEP
	ws.bots_join = false
	ws.join_any_class = true
	ws.join_radius = 8.0
	ws.join_ease = 0.2
	ws.click_auto = false
	ws.shadow_count = 3
	ws.spook_charges = 1
	HunterSize.shared().size_mult = 3.0


func _run() -> void:
	_configure()
	main.set_mode(main.WHAT_STINKS)
	await _ticks(10)
	if role == "host":
		await _host()
	else:
		await _guest()
	_finish()


## Alive fish per school id, as "id:count" so two machines can be compared in one line.
func _alive_of(game: WhatStinksMatch) -> Dictionary:
	var out := {}
	for school in game.field.schools:
		out[school.id] = school.alive_count()
	return out


func _counts_match(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for id: Variant in a:
		if int(b.get(int(id), -1)) != int(a[id]):
			return false
	return true


# --- Host ------------------------------------------------------------------

func _host() -> void:
	main.play_match()
	await _ticks(5)
	var game: WhatStinksMatch = main.what_stinks
	check(game != null and game.authority and game.bots.size() == 4, "our match, four bots to fill it")
	game.bite_result.connect(func(h: FishController, t: Dictionary, p: Array) -> void: print("    host: bite by %s took %s and %d players" % [h.name, t, p.size()]))
	print("host: hosting on %d" % port)
	NetSession.host_enet(port)
	await _ticks(5)
	var coop: CoopSession = NetSession.coop
	var net: WhatStinksNet = coop.what_stinks_net
	check(NetSession.is_host() and coop.wsm == game, "hosting: the session has our match")
	if not await _wait(func() -> bool: return _pids.has("a") and _pids.has("b"), 30.0):
		check(false, "both guests joined")
		return
	await _seconds(1.0)
	var fa := coop.fish_of(int(_pids.a))
	var fb := coop.fish_of(int(_pids.b))
	check(fa != null and fb != null and fa.puppet and fb.puppet and fa in game.players and fb in game.players, "both guests' fish are puppets in our match")
	await _phase("joined", {"players": game.players.size(), "alive": _alive_of(game), "bots": game.bots.size()})

	print("host: a round, guest a hunting")
	var order := game.hunter_order()
	var index := order.find(fa)
	check(index >= 0, "guest a takes a turn hunting")
	game.start_round(maxi(index, 0))
	await _ticks(5)
	check(game.hunters == [fa] and game.bites.has(fa), "a hunts here too (a Hunter's body and bite on its puppet)")
	await _phase("round", {"hunter": int(_pids.a), "schools": _alive_of(game), "seed": game.last_seed, "players": game.players.size()})
	if not await _wait(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, 10.0):
		check(false, "LIVE")
		return
	await _phase("live", {})

	print("host: privacy")
	game.echo.forced[fb] = 0.6
	await _seconds(0.6)
	var to_a: Array = net.sent_views.get(int(_pids.a) / 100, [])
	var to_b: Array = net.sent_views.get(int(_pids.b) / 100, [])
	check(not to_b.is_empty() and (to_b[0] as Dictionary).keys() == [int(_pids.b)] and is_equal_approx(float((to_b[0] as Dictionary)[int(_pids.b)]), 0.6),
			"b's view: only its own exposure (%s)" % [to_b])
	var prey_ids := []
	for p in game.live_prey():
		prey_ids.append(net.id_of(p))
	check(not to_a.is_empty() and (to_a[0] as Dictionary).has(int(_pids.b)) and (to_a[0] as Dictionary).keys().all(func(id: Variant) -> bool: return int(id) in prey_ids),
			"a's view (the Hunter): exposures of live prey only (%s)" % [to_a.slice(0, 1)])
	await _phase("privacy", {"b": int(_pids.b)})
	game.echo.forced.erase(fb)

	print("host: b joins a school")
	var school: School = game.field.schools[0]
	await _phase("join", {"school": school.id}, true, "b")
	await _wait(func() -> bool: return game.join.is_joined(fb), 5.0)
	check(game.join.is_joined(fb) and game.join.school_of(fb) == school, "b joined school %d here" % school.id)
	var place := school.claim_of(fb)
	await _seconds(1.0)
	check(place >= 0 and fb.global_position.distance_to(school.fish_position(place)) < 1.5, "b is in lockstep with its place here (%.2f m)" % fb.global_position.distance_to(school.fish_position(place)))
	await _phase("join_seen", {"b": int(_pids.b), "school": school.id, "place": place})

	print("host: b spooks")
	var charges := int(game.join.charges.get(fb, 0))
	await _phase("spook", {}, true, "b")
	await _wait(func() -> bool: return int(game.join.charges.get(fb, 0)) == charges - 1, 3.0)
	check(int(game.join.charges.get(fb, 0)) == charges - 1, "b's Spook was judged here (%d left)" % int(game.join.charges.get(fb, 0)))
	await _phase("spooked", {"charges": charges - 1}, true, "b")
	check(game.join.is_joined(fb), "b is still in its school after the Spook")
	await _phase("startled", {"school": school.id}, true, "a")

	print("host: a Click and Sniff")
	game.echo.click(fa, true)
	await _phase("click", {}, true, "a")
	await _phase("sniff", {}, false, "a")
	await _wait(func() -> bool: return game.echo.is_sniffing(fa), 3.0)
	check(game.echo.is_sniffing(fa), "a's Sniff button reached us: the cone narrows")
	await _phase("sniff_seen", {}, true, "a")
	await _phase("sniff_off", {}, false, "a")
	await _wait(func() -> bool: return not game.echo.is_sniffing(fa), 3.0)
	check(not game.echo.is_sniffing(fa), "and its release too")
	await _phase("sniff_off_seen", {}, true, "a")

	print("host: a bites b's school")
	check(game.join.is_joined(fb), "b is still joined before the bite")
	var before := game.field.alive_total()
	await _phase("bite", {"b": int(_pids.b), "school": school.id, "place": place}, true, "a")
	await _wait(func() -> bool: return game.eaten.has(fb), 6.0)
	check(game.eaten.has(fb), "a's bite ate b here (its place was in it)")
	check(game.field.alive_total() < before, "and school fish with it (%d -> %d)" % [before, game.field.alive_total()])
	await _seconds(1.2)
	await _phase("eaten", {"b": int(_pids.b), "alive": _alive_of(game)})
	check(not game.join.is_joined(fb), "b is out of its school")

	print("host: ROUND_OVER")
	game.time_left = 0.01
	await _wait(func() -> bool: return game.phase == WhatStinksMatch.Phase.ROUND_OVER, 3.0)
	check(game.phase == WhatStinksMatch.Phase.ROUND_OVER, "the round's over (the clock)")
	var totals := {}
	for f: FishController in game.match_totals:
		totals[net.id_of(f)] = float(game.match_totals[f])
	await _seconds(0.6)
	await _phase("round_over", {"totals": totals, "reason": game.last_results.reason})

	await _host_stomach(game, coop, net, fa, fb)

	print("host: leaving")
	await _phase("leaving", {}, false, "all")
	await _seconds(0.5)
	NetSession.leave()
	await _seconds(2.0)


## Upset Stomach: a spit, the bars, a school replaced and one regrown.
func _host_stomach(game: WhatStinksMatch, coop: CoopSession, net: WhatStinksNet, fa: FishController, fb: FishController) -> void:
	print("host: Upset Stomach")
	ws.variant = WhatStinksSettings.Variant.STOMACH
	await _phase("stomach_on", {})
	game.start_round(maxi(game.hunter_order().find(fa), 0))
	await _ticks(5)
	await _phase("stomach_round", {"hunter": int(_pids.a), "stomach": game.stomach()})
	if not await _wait(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, 10.0):
		check(false, "LIVE (stomach)")
		return
	await _phase("stomach_live", {})
	var before := float(game.satiation.get(fa, 0.0))
	await _phase("spit", {"b": int(_pids.b)}, true, "a")
	await _wait(func() -> bool: return game.spat_total.get(fa, 0) > 0, 6.0)
	check(int(game.spat_total.get(fa, 0)) >= 1 and not game.eaten.has(fb), "a's bite spat b out here: not eaten")
	check(game.is_dazed(fb) and float(game.queasy.get(fa, 0.0)) > 0.0, "b is dazed, a is queasy (%.1f)" % float(game.queasy.get(fa, 0.0)))
	await _seconds(0.8)
	await _phase("spat", {"b": int(_pids.b), "queasy": float(game.queasy.get(fa, 0.0)), "satiation": float(game.satiation.get(fa, 0.0)), "before": before})

	print("host: schools come and grow")
	var count_before := game.field.schools.size()
	game.field._replace_school()
	var grown: School = game.field.schools[0]
	grown.settings.fish_per_school = grown.fish_count() + 3
	await _seconds(1.6)
	await _phase("schools", {"count": game.field.schools.size(), "was": count_before, "grown_id": grown.id, "grown_count": grown.fish_count(), "alive": _alive_of(game)})


# --- Guests ----------------------------------------------------------------

func _guest() -> void:
	await _seconds(0.5 if role == "a" else 2.5)
	print("%s: joining" % role)
	NetSession.join_enet("127.0.0.1", port)
	var coop: CoopSession = NetSession.coop
	if not await _wait(func() -> bool: return coop._welcomed and main.what_stinks != null and not main.what_stinks.authority, 20.0):
		check(false, "welcomed into the host's What Stinks?")
		return
	await _seconds(0.5)
	var game: WhatStinksMatch = main.what_stinks
	check(coop.wsm == game and game.bots.is_empty(), "welcomed: a guest's match (no bots of its own)")
	_hello_rpc.rpc_id(1, role, coop.pid_of(fish))
	while true:
		await _wait(func() -> bool: return _phase_name != "", 90.0)
		var phase := _phase_name
		var data: Dictionary = _phase_data
		_phase_name = ""
		game = main.what_stinks
		match phase:
			"":
				check(false, "the host carried on")
				return
			"joined":
				await _wait(func() -> bool: return game.players.size() == int(data.players), 5.0)
				check(game.players.size() == int(data.players) and game.bots.is_empty(), "everyone's here (%d of %d), the bots puppets" % [game.players.size(), data.players])
				check(_counts_match(data.alive, _alive_of(game)), "the schools are the host's: ids and fish alive (%s)" % [_alive_of(game)])
				var host_fish := coop.fish_of(100)
				check(host_fish != null and host_fish.puppet and host_fish in game.players, "the host's fish is a puppet here")
			"round":
				await _wait(func() -> bool: return game.players.size() == int(data.players) and game.round_index >= 0 and not game.hunters.is_empty(), 3.0)
				var hunter := coop.what_stinks_net.fish_by_id(int(data.hunter))
				check(hunter != null and game.hunters == [hunter], "the host's round: a hunts here too")
				check(game.phase == WhatStinksMatch.Phase.COUNTDOWN and game.last_seed == int(data.seed), "counting down, the host's ocean seed")
				check(_counts_match(data.schools, _alive_of(game)), "the same schools (%d)" % game.field.schools.size())
				if role == "a":
					check(game.role_of(fish) == WhatStinksMatch.Role.HUNTER and fish.controls_locked and fish.character == FishCharacter.FishClass.MONSTER,
							"we hunt: held through the count, in the monster's body (%.1f m)" % fish.hitbox_length)
				else:
					check(game.role_of(fish) == WhatStinksMatch.Role.PREY and not fish.controls_locked, "we're prey: free")
			"live":
				await _wait(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, 3.0)
				check(game.phase == WhatStinksMatch.Phase.LIVE, "LIVE here too")
				if role == "a":
					check(not fish.controls_locked, "the Hunter's let go")
			"privacy":
				await _seconds(0.3)
				var fb := coop.fish_of(int(data.b))
				if role == "b":
					check(game.echo.net_view.keys() == [fish] and is_equal_approx(game.max_exposure(fish), 0.6), "we know our own exposure (%.2f), nobody else's" % game.max_exposure(fish))
				else:
					check(is_equal_approx(game.local_exposure(fb), 0.6), "we see b at the host's exposure (%.2f)" % game.local_exposure(fb))
					check(is_zero_approx(game.own_round_tally(fb)), "and no points of anyone's")
			"join":
				var school := game.field.school_by_id(int(data.school))
				var slot := school.nearest_free(school.middle())
				fish.freeze = true
				fish.global_position = school.fish_position(slot) + Vector3(0.6, 0.0, 0.0)
				await _seconds(0.4)
				await _tap(&"jump")
				await _wait(func() -> bool: return game.join.is_joined(fish), 4.0)
				check(game.join.is_joined(fish) and game.join.school_of(fish) == school, "our Join press: the host put us in school %d" % school.id)
			"join_seen":
				var school := game.field.school_by_id(int(data.school))
				await _wait(func() -> bool: return role == "a" or game.join.is_joined(fish), 3.0)
				if role == "b":
					var place := school.claim_of(fish)
					check(place == int(data.place), "our place is the host's (%d)" % place)
					check(fish.global_position.distance_to(school.fish_position(place)) < 0.5, "in lockstep with it (%.2f m)" % fish.global_position.distance_to(school.fish_position(place)))
				else:
					check(game.join.schools.is_empty(), "the Hunter was never told who joined")
			"spook":
				await _tap(&"powerslide")
			"startled":
				var bolted := game.field.school_by_id(int(data.school))
				check(bolted != null and bolted._scatter_left > 0.0, "the Hunter saw the school bolt too (no name with it, the same scatter)")
			"spooked":
				await _wait(func() -> bool: return int(game.join.charges.get(fish, 99)) == int(data.charges), 3.0)
				check(int(game.join.charges.get(fish, 99)) == int(data.charges), "our Spook went (%d left)" % int(game.join.charges.get(fish, 99)))
			"click":
				await _wait(func() -> bool: return game.echo.click_ready_in(fish) > 0.0, 3.0)
				check(game.echo.click_ready_in(fish) > 0.0 and int(game.echo.clicks.get(fish, 0)) >= 1, "the host's Click of ours: on its cooldown here (%.1f s)" % game.echo.click_ready_in(fish))
			"sniff":
				Input.action_press("powerslide")
			"sniff_seen":
				await _wait(func() -> bool: return game.echo.is_sniffing(fish), 2.0)
				var slowed := fish.speed_scale < 1.0
				check(game.echo.is_sniffing(fish) and slowed, "sniffing: slower here (speed x%.2f)" % fish.speed_scale)
			"sniff_off":
				Input.action_release("powerslide")
			"sniff_off_seen":
				await _wait(func() -> bool: return not game.echo.is_sniffing(fish), 2.0)
				check(not game.echo.is_sniffing(fish) and is_equal_approx(fish.speed_scale, 1.0), "sniff off, speed back (x%.2f)" % fish.speed_scale)
			"bite":
				await _bite(game, coop, int(data.b), true)
			"eaten":
				var fb := coop.fish_of(int(data.b))
				await _wait(func() -> bool: return game.eaten.has(fb), 4.0)
				check(game.eaten.has(fb), "b is eaten here too")
				await _seconds(0.8)
				check(_counts_match(data.alive, _alive_of(game)), "the schools' fish agree with the host's (%s)" % [_alive_of(game)])
				if role == "b":
					check(fish.controls_locked and not game.join.is_joined(fish), "we're out: spectating, not in the school")
			"round_over":
				await _wait(func() -> bool: return game.phase == WhatStinksMatch.Phase.ROUND_OVER, 3.0)
				var mine := {}
				for f: FishController in game.match_totals:
					mine[coop.what_stinks_net.id_of(f)] = float(game.match_totals[f])
				var same := true
				for id: Variant in data.totals:
					same = same and absf(float(mine.get(int(id), -1.0)) - float(data.totals[id])) < 0.01
				check(game.phase == WhatStinksMatch.Phase.ROUND_OVER and same and str(game.last_results.get("reason", "")) == str(data.reason),
						"ROUND_OVER with the host's totals and reason (%s)" % str(game.last_results.get("reason", "")))
			"stomach_on":
				ws.variant = WhatStinksSettings.Variant.STOMACH
			"stomach_round":
				await _wait(func() -> bool: return game.stomach() == bool(data.stomach) and game.phase == WhatStinksMatch.Phase.COUNTDOWN and not game.hunters.is_empty(), 4.0)
				var hunter := coop.what_stinks_net.fish_by_id(int(data.hunter))
				check(game.stomach() and game.hunters == [hunter], "Upset Stomach here too, a hunting")
				fish.freeze = false
			"stomach_live":
				await _wait(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, 3.0)
				if role == "b":
					fish.controls_locked = true
					fish.freeze = true
			"spit":
				await _bite(game, coop, int(data.b), false)
			"spat":
				if role == "b":
					await _wait(func() -> bool: return game.is_dazed(fish), 3.0)
					check(game.is_dazed(fish) and not game.eaten.has(fish) and not fish.boost_enabled, "we were spat out: dazed, no boost, still in")
					check(not fish.freeze, "and let go of the hold: flung (%.1f m/s now)" % fish.linear_velocity.length())
				else:
					await _wait(func() -> bool: return game.queasy_share(fish) > 0.0, 3.0)
					check(game.queasy_share(fish) > 0.0 and absf(float(game.queasy.get(fish, 0.0)) - float(data.queasy)) < 3.0,
							"our bars: queasy %.1f (the host's %.1f), satiation %.1f" % [float(game.queasy.get(fish, 0.0)), float(data.queasy), float(game.satiation.get(fish, 0.0))])
			"schools":
				await _wait(func() -> bool: return game.field.schools.size() == int(data.count), 3.0)
				check(game.field.schools.size() == int(data.count) and int(data.count) == int(data.was) + 1,
						"the school the host added is here (%d schools)" % game.field.schools.size())
				var grown := game.field.school_by_id(int(data.grown_id))
				await _wait(func() -> bool: return grown != null and grown.fish_count() == int(data.grown_count), 3.0)
				check(grown != null and grown.fish_count() == int(data.grown_count), "the regrown school has its new fish (%d)" % (grown.fish_count() if grown else -1))
			"leaving":
				_send_done(phase)
				await _wait(func() -> bool: return main.what_stinks != null and main.what_stinks.authority, 10.0)
				check(main.what_stinks != null and main.what_stinks.authority and not main.what_stinks.bots.is_empty(), "the host left: What Stinks? of our own, with bots")
				return
		_send_done(phase)


## Our Hunter's bite on `b`: placed so its bite point is on the prey (a puppet here), then the jump button.
func _bite(game: WhatStinksMatch, coop: CoopSession, b_pid: int, _joined: bool) -> void:
	var prey := coop.fish_of(b_pid)
	var bite: HunterBite = game.bites.get(fish)
	if prey == null or bite == null:
		check(false, "a bite to make")
		return
	bite.lunge_gain = 0.0
	var target := prey.global_position
	var direction := Vector3(0.3, 0.0, 1.0).normalized()
	fish.freeze = false
	fish.global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP), target - direction * 12.0)
	_lock = fish.global_transform
	await _seconds(0.3)
	_lock.origin += (target - direction * bite.reach() * 0.5) - bite.mouth_point()
	await _seconds(1.0)  # held there: the host's puppet of us gets there
	var bites := bite.bites
	print("    [%s] bite setup: fish %s mouth %s prey %s facing %s" % [role, fish.global_position, bite.mouth_point(), prey.global_position, -fish.global_basis.z])
	Input.action_press("jump")
	await _wait(func() -> bool: return bite.bites > bites, 4.0)
	Input.action_release("jump")
	_lock = Transform3D.IDENTITY
	check(bite.bites > bites, "our bite landed (the jaws shut at %.1f m from b)" % bite.mouth_point().distance_to(prey.global_position))


# --- Helpers ---------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if role != "host" and _lock != Transform3D.IDENTITY and is_instance_valid(fish):
		fish.global_transform = _lock
		fish.linear_velocity = Vector3.ZERO
		fish.angular_velocity = Vector3.ZERO


func _tap(action: StringName) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


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
		if not await _wait(func() -> bool: return _done.has(key), 25.0):
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
