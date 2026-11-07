extends Node
## What Stinks? Phase 1 (what_stinks.md): the match with no hiding. Plays
## the real mode through Main: the card's Play starts a WhatStinksMatch in the
## Ocean with bots; checks the roles (the local fish is the Hunter in round 0,
## wearing the monster form and a bite, prey are their own class), the countdown
## hold, the placed schools, a bite eating school fish (and no more than its
## capacity), a bite eating a prey player (hidden, out of the round, the eaten
## spectate), the round's end both ways (every prey eaten, the clock out) with
## its points, the next round's role swap (a bot Hunter that bites by itself, the
## local fish back to its own class and values), the match's end, and end().
##   Godot_console.exe --headless --path . res://tests/what_stinks_probe.tscn

var main: Node
var game: WhatStinksMatch
var fish: FishController
var failures := 0
var checks := 0
var bite_events: Array = []


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Waits (game time) until `done` is true, at most `seconds`. Returns whether it was.
func _until(done: Callable, seconds: float) -> bool:
	var ticks := int(seconds * Engine.physics_ticks_per_second)
	for i in ticks:
		if done.call():
			return true
		await get_tree().physics_frame
	return done.call()


func _run() -> void:
	await _frames(5)
	var settings := WhatStinksSettings.shared()
	settings.hide_time = 1.0
	settings.round_time = 60.0
	settings.round_over_time = 0.5
	settings.match_over_time = 600.0
	settings.arena_radius = 90.0
	settings.school_count = 4
	settings.school_min = 12
	settings.school_max = 16
	settings.min_players = 4
	settings.bot_hunter_rounds = 1
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	settings.variant = WhatStinksSettings.Variant.SWEEP
	HunterSize.shared().size_mult = 1.0
	var base_class := fish.character
	var base_scale := fish.body_scale

	print("starting:")
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	check(main.current_mode == main.WHAT_STINKS and main.current_environment == "Ocean", "the mode plays in the Ocean")
	check(main._match_card != null, "it waits on a card")
	main.play_match()
	await _frames(5)
	game = main.what_stinks
	check(game != null, "Play starts a match")
	if game == null:
		get_tree().quit(1)
		return
	game.bitten.connect(func(hunter: FishController, school_fish: int, prey: Array) -> void: bite_events.append([hunter, school_fish, prey]))
	check(game.players.size() == 4 and game.bots.size() == 3, "four fish, three of them bots (%d, %d)" % [game.players.size(), game.bots.size()])
	check(game.phase == WhatStinksMatch.Phase.COUNTDOWN, "the round starts counting down")
	check(game.hunters == [fish] and game.is_hunter(fish), "the local fish is the Hunter in round 0")
	check(game.live_prey().size() == 3, "three prey")
	check(fish.character == FishCharacter.FishClass.MONSTER, "the Hunter wears the monster form")
	check(game.bites.has(fish) and is_instance_valid(game.bites[fish]), "it has a bite")
	check(fish.controls_locked, "the Hunter is held while the prey scatter")
	check(game.field.schools.size() == 4, "the schools are placed (%d)" % game.field.schools.size())
	var min_fish := 99
	for school in game.field.schools:
		min_fish = mini(min_fish, school.fish_count())
	check(min_fish >= 12, "each has its own size (smallest %d)" % min_fish)
	for other in game.players:
		if other != fish:
			check(not game.is_hunter(other) and other.character != FishCharacter.FishClass.MONSTER and not game.bites.has(other), "%s is plain prey" % other.display_name)
	var far := 0.0
	for other in game.live_prey():
		far = maxf(far, other.global_position.distance_to(game.center))
	check(far > 0.1 * settings.arena_radius and far < settings.arena_radius, "prey scattered inside the arena (%.0f m of %.0f)" % [far, settings.arena_radius])
	check((main._environment as Ocean).boundary_radius == settings.arena_radius, "the murk wall is at the arena radius")

	print("live:")
	check(await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, 3.0), "the countdown ends")
	check(not fish.controls_locked, "the Hunter is released")
	_stop_bots()

	print("the bite on a school:")
	var school: School = game.field.schools[0]
	school.set_physics_process(false)  # pinned: the fish stay where the bite is aimed
	var target := school.fish_position(0)
	var before := school.alive_count()
	var fields_before: int = game.field.alive_total()
	_aim_hunter_at(target)
	await _frames(3)
	var bite: HunterBite = game.bites[fish]
	bite.lunge_gain = 0.0  # no recoil or lunge: the probe aims the bite where it lands
	check(bite.try_bite(), "the bite starts")
	check(await _until(func() -> bool: return not bite_events.is_empty(), 3.0), "the jaws shut and a bite lands")
	var ate: int = bite_events[0][1] if not bite_events.is_empty() else 0
	check(ate >= 1 and ate <= bite.capacity(), "it ate %d school fish (capacity %d)" % [ate, bite.capacity()])
	check(school.alive_count() == before - ate and game.field.alive_total() == fields_before - ate, "the school lost exactly those fish")
	check(game.live_prey().size() == 3, "no prey player was in it")
	check(school.alarm > 0.9, "the school panicked (alarm %.2f)" % school.alarm)

	print("the bite on a prey player:")
	var victim: FishController = game.live_prey()[0]
	victim.freeze = true
	await _until(func() -> bool: return not bite.busy() and bite.cooldown <= 0.0, 6.0)
	var spot := bite.mouth_point() + (-fish.global_basis.z) * bite.reach() * 0.5
	victim.global_position = spot
	victim.linear_velocity = Vector3.ZERO
	await _frames(2)
	bite_events.clear()
	check(bite.try_bite(), "the second bite starts")
	check(await _until(func() -> bool: return not bite_events.is_empty(), 3.0), "and lands")
	check(game.eaten.has(victim), "the prey player is eaten")
	check(not victim.visible, "and gone from the water")
	check(not game.is_live_prey(victim) and game.live_prey().size() == 2, "two prey left")
	check(game.round_eaten == 1 and game.match_eaten.get(fish, 0) == 1, "the Hunter's count is one")
	check(game.own_round_tally(fish) >= settings.tag_points, "and its points rose by tag_points (%.0f)" % game.own_round_tally(fish))

	print("snap chomp vs wind-up:")
	await _until(func() -> bool: return not bite.busy() and bite.cooldown <= 0.0, 6.0)
	var heading := -fish.global_basis.z
	var land_at := [-1.0]
	var landed_cb := func(_m: Vector3, _r: float, _d: float, _c: int) -> void: land_at[0] = Time.get_ticks_msec() / 1000.0
	bite.chomped.connect(landed_cb)
	bite.lunge_gain = 0.35
	for snap_on: bool in [true, false]:
		await _until(func() -> bool: return not bite.busy() and bite.cooldown <= 0.0, 6.0)
		fish.linear_velocity = Vector3.ZERO
		await _frames(2)
		bite.snap = snap_on
		land_at[0] = -1.0
		var from := fish.global_position
		var pressed := Time.get_ticks_msec() / 1000.0
		check(bite.try_bite(), "snap %s: the bite starts" % snap_on)
		var travelled := 0.0
		var t_end := pressed + float(bite.form["bite_wind"]) + 1.0
		while Time.get_ticks_msec() / 1000.0 < t_end and (land_at[0] < 0.0 or Time.get_ticks_msec() / 1000.0 < land_at[0] + 0.3):
			await get_tree().physics_frame
			travelled = maxf(travelled, (fish.global_position - from).dot(heading))
		var delay: float = land_at[0] - pressed
		if snap_on:
			check(land_at[0] >= 0.0 and delay < 0.2, "snap: it chomps at once (%.3f s after the press)" % delay)
			check(travelled < 0.05, "snap: no lunge forward (%.2f m)" % travelled)
		else:
			check(land_at[0] >= 0.0 and delay >= float(bite.form["bite_wind"]) * 0.8, "wind-up: it lands later (%.2f s, bite_wind %.2f)" % [delay, float(bite.form["bite_wind"])])
			check(travelled > 0.05, "wind-up: it lunges forward (%.2f m)" % travelled)
	bite.chomped.disconnect(landed_cb)
	bite.snap = true
	bite.lunge_gain = 0.0

	print("every prey eaten:")
	for other in game.live_prey():
		game._eat(other, fish)
	check(game.phase == WhatStinksMatch.Phase.ROUND_OVER, "the round is over")
	check(bool(game.last_results["hunters_won"]) and int(game.last_results["eaten"]) == 3, "the Hunter won, three eaten")
	var points: float = game.last_results["points"][fish]
	check(points >= 3.0 * settings.tag_points, "its points include 3 x tag_points (%.0f)" % points)
	check(float(game.match_totals[fish]) == points, "they're in the match totals")

	print("round 2: a bot hunts:")
	check(await _until(func() -> bool: return game.round_index == 1 and game.phase != WhatStinksMatch.Phase.ROUND_OVER, 5.0), "the next round starts")
	check(game.eaten.is_empty(), "everyone is back in")
	check(not game.is_hunter(fish) and fish.character == base_class, "the local fish is prey in its own class again (%s)" % fish.character)
	check(is_equal_approx(fish.body_scale, base_scale) and not game.bites.has(fish), "its body is back to normal")
	check(fish.visible and not fish.freeze, "and it's in the water")
	var hunter: FishController = game.hunters[0]
	check(game.bots.has(hunter) and hunter.character == FishCharacter.FishClass.MONSTER and game.bites.has(hunter), "a bot is the Hunter now")
	check(game.bots[hunter] is WhatStinksBot, "driven by the Hunter bot")
	check(await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, 3.0), "live")
	var bites_before := bite_events.size()
	check(await _until(func() -> bool: return bite_events.size() > bites_before, 150.0), "the bot Hunter swims at the fish and bites by itself")
	if bite_events.size() > bites_before:
		var last: Array = bite_events[-1]
		print("      its first bite took %d school fish and %d prey" % [last[1], last[2].size()])

	print("eaten spectates:")
	var eater: FishController = game.hunters[0]
	eater.controls_locked = true
	game._eat(fish, eater)
	check(game.is_spectating() and game.eaten.has(fish), "the local player is eaten and spectating")
	check(game.spectate_target() != null and game.spectate_target() != fish, "watching someone else")
	var camera: Node = main.get_node("FollowCamera")
	check(camera.get("target") == game.spectate_target(), "the camera follows them")
	game.cycle_spectate(1)
	check(game.spectate_target() != null, "left / right switches the watched fish")
	game.eaten.erase(fish)  # back in, for the clock test
	fish.visible = true
	fish.freeze = false

	print("the clock runs out:")
	game.time_left = 0.05
	check(await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.ROUND_OVER or game.phase == WhatStinksMatch.Phase.OVER, 3.0), "the round ends")
	check(not bool(game.last_results.get("hunters_won", true)), "the prey won")
	check(float(game.last_results["points"].get(fish, 0.0)) >= settings.survivor_bonus, "a survivor has its bonus")
	check(await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.OVER, 5.0), "the match is over after the last round")
	check(game.winner != null, "with a winner (%s)" % (game.winner.display_name if game.winner else "none"))

	print("ending:")
	main.set_mode(main.FREE_PLAY)
	await _frames(5)
	check(main.what_stinks == null, "leaving the mode ends the match")
	check(fish.character == base_class and is_equal_approx(fish.body_scale, base_scale) and fish.visible and not fish.freeze and not fish.controls_locked, "the fish is handed back as it was")
	print("what_stinks_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## Everyone but the Hunter held still, so the probe is the only thing moving.
func _stop_bots() -> void:
	for other in game.players:
		if other != fish and not game.is_hunter(other):
			other.freeze = true


## The Hunter placed facing along -z with its mouth 1.5 m short of `target`.
func _aim_hunter_at(target: Vector3) -> void:
	var bite: HunterBite = game.bites[fish]
	fish.global_transform = Transform3D(Basis.IDENTITY, target + Vector3(0.0, 0.0, fish.hitbox_length * 0.45 + 1.5))
	fish.global_position += (target + Vector3(0.0, 0.0, 1.5)) - bite.mouth_point()  # the mouth 1.5 m short of the fish, whatever its head hangs at
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	bite.cooldown = 0.0
