extends Node
## What Stinks? Phase 4 (what_stinks.md sections 1, 1b, 6): Upset Stomach. Plays
## the real mode through Main with the variant on STOMACH: the satiation bar (the
## start, hunger's decay, a school fish's worth by its size), a prey player in the
## bite spat out (not eaten: still live, flung, dazed with no boost and no join,
## the Hunter's satiation down, queasy up, its bite on cooldown, the prey's spit
## points), a joined prey spat from its place, the Hunter hurling on a full queasy
## bar (the round over, the prey win), a full belly winning for the Hunter, the
## clock running out hungry, the schools' steady respawn (regrow and replace), Sweep
## unchanged (no respawn), the Hunter bot avoiding a prey it can read and prey bots
## waiting near the Hunter's start, and the HUD's lines and bars.
##   Godot_console.exe --headless --path . res://tests/stomach_probe.tscn

var main: Node
var game: WhatStinksMatch
var fish: FishController
var failures := 0
var checks := 0
var bite_events: Array = []
var fed_total := 0.0


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


func _until(done: Callable, seconds: float) -> bool:
	var ticks := int(seconds * Engine.physics_ticks_per_second)
	for i in ticks:
		if done.call():
			return true
		await get_tree().physics_frame
	return done.call()


func _live() -> bool:
	return await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, 4.0)


## The next round of the same Hunter (index 0), live, with the prey bots held still.
func _restart(index := 0) -> bool:
	game.start_round(index)
	await _frames(3)
	var ok := await _live()
	_stop_bots()
	return ok


func _run() -> void:
	await _frames(5)
	var settings := WhatStinksSettings.shared()
	settings.hide_time = 1.0
	settings.round_time = 900.0
	settings.round_over_time = 600.0
	settings.match_over_time = 900.0
	settings.arena_radius = 90.0
	settings.respawn_school_gap = 30.0  # the arena is small: the default 80 m gap cannot be kept
	settings.school_count = 4
	settings.school_min = 12
	settings.school_max = 16
	settings.min_players = 4
	settings.bot_hunter_rounds = 1
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	settings.variant = WhatStinksSettings.Variant.STOMACH
	settings.bots_join = false
	settings.join_any_class = true
	settings.join_radius = 8.0
	settings.join_ease = 0.2
	settings.hunter_blind = true
	settings.satiation_decay = 0.0
	settings.queasy_decay = 0.0
	settings.respawn_every = 0.0
	settings.spit_daze = 1.5
	settings.spit_cooldown = 1.0
	HunterSize.shared().size_mult = 1.0

	print("starting:")
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	main.play_match()
	await _frames(5)
	game = main.what_stinks
	check(game != null, "Play starts a match")
	if game == null:
		get_tree().quit(1)
		return
	game.bitten.connect(func(hunter: FishController, school_fish: int, prey: Array) -> void: bite_events.append([hunter, school_fish, prey]))
	game.fed.connect(func(_h: FishController, gain: float) -> void: fed_total += gain)
	check(game.stomach() and game.field.steady, "Upset Stomach: the variant is on and the schools respawn")
	check(is_equal_approx(float(game.satiation[fish]), settings.satiation_max * settings.satiation_start) and float(game.queasy[fish]) == 0.0, "the belly starts at its start share, calm (%.1f)" % float(game.satiation[fish]))
	check(await _live(), "the countdown ends")
	_stop_bots()

	print("hunger:")
	settings.satiation_decay = 5.0
	var before := float(game.satiation[fish])
	await _frames(120)
	settings.satiation_decay = 0.0
	var drained := before - float(game.satiation[fish])
	check(drained > 3.5 and drained < 6.5, "the belly drains with the clock (%.2f in ~1 s at 5/s)" % drained)

	print("a fish's worth:")
	var by_length := FishCharacter.pickable_classes().duplicate()
	by_length.sort_custom(func(a: int, b: int) -> bool: return FishCharacter.hitbox_size(a).z < FishCharacter.hitbox_size(b).z)
	var small: School = game.field.add_school(game.center + Vector3(0, 500, 0), Vector3.FORWARD, by_length[0], 10, 1)
	var large: School = game.field.add_school(game.center + Vector3(0, 520, 0), Vector3.FORWARD, by_length[by_length.size() - 1], 10, 2)
	var ratio := game.field.fish_mass(large) / game.field.fish_mass(small)
	var want := pow(FishCharacter.hitbox_size(by_length[by_length.size() - 1]).z / FishCharacter.hitbox_size(by_length[0]).z, settings.satiation_size_exp)
	check(ratio > 1.0 and absf(ratio - want) < 0.01, "a bigger fish is worth more (x%.2f, by length ^ %.1f)" % [ratio, settings.satiation_size_exp])
	settings.satiation_size_exp = 0.0
	check(is_equal_approx(game.field.fish_mass(large), game.field.fish_mass(small)), "size exponent 0 makes every fish worth the same")
	settings.satiation_size_exp = 1.0
	game.field.schools.erase(small)
	game.field.schools.erase(large)
	small.queue_free()
	large.queue_free()

	print("the bite on a school:")
	var school: School = game.field.schools[0]
	school.set_physics_process(false)
	var target := school.fish_position(0)
	var school_before := school.alive_count()
	_aim_hunter_at(target)
	await _frames(3)
	var bite: HunterBite = game.bites[fish]
	bite.lunge_gain = 0.0
	before = float(game.satiation[fish])
	fed_total = 0.0
	check(bite.try_bite(), "the bite starts")
	check(await _until(func() -> bool: return not bite_events.is_empty(), 3.0), "the jaws shut")
	var ate: int = bite_events[0][1]
	var worth := ate * game.field.fish_mass(school) * settings.satiation_per_fish
	check(ate >= 1 and school.alive_count() == school_before - ate, "it ate %d school fish" % ate)
	check(absf(float(game.satiation[fish]) - before - worth) < 0.2 and absf(fed_total - worth) < 0.2, "the belly rose by their worth (%.2f of %.2f)" % [float(game.satiation[fish]) - before, worth])
	check(game.own_round_tally(fish) >= worth * settings.satiation_points - 0.2, "and the Hunter's points follow it (%.1f)" % game.own_round_tally(fish))
	check(game.round_eaten == 0 and game.live_prey().size() == 3, "nobody was eaten")

	print("the bite on a prey player:")
	var victim: FishController = game.live_prey()[0]
	victim.freeze = true
	await _until(func() -> bool: return not bite.busy() and bite.cooldown <= 0.0, 6.0)
	var spot := bite.mouth_point() + (-fish.global_basis.z) * bite.reach() * 0.5
	victim.global_position = spot
	victim.linear_velocity = Vector3.ZERO
	await _frames(2)
	bite_events.clear()
	var boost_was := victim.boost_enabled
	var satiation_then := float(game.satiation[fish])
	fed_total = 0.0
	check(bite.try_bite(), "the next bite starts")
	check(await _until(func() -> bool: return not bite_events.is_empty(), 3.0), "and lands")
	check(not game.eaten.has(victim) and game.is_live_prey(victim) and victim.visible, "the prey is not eaten: still live, still in the water")
	check(game.round_spat == 1 and bite_events[0][2].has(victim), "it was spat out (spat %d)" % game.round_spat)
	check(absf(float(game.satiation[fish]) - (satiation_then + fed_total - settings.spit_satiation_loss)) < 0.2, "the belly lost spit_satiation_loss (%.1f -> %.1f)" % [satiation_then, float(game.satiation[fish])])
	check(is_equal_approx(float(game.queasy[fish]), settings.queasy_per_spit), "the Hunter is queasy (%.1f)" % float(game.queasy[fish]))
	check(bite.cooldown > settings.spit_cooldown * 0.5, "its bite is on cooldown (%.2f s)" % bite.cooldown)
	check(not victim.freeze and victim.linear_velocity.length() > settings.spit_speed * 0.5, "the prey is flung (%.1f m/s)" % victim.linear_velocity.length())
	check(game.is_dazed(victim) and not victim.boost_enabled, "dazed: no boost")
	check(float(game.join.cooldown.get(victim, 0.0)) >= settings.spit_daze * 0.9 and not game.join.can_join(victim), "and it can't join a school")
	check(game.own_round_tally(victim) >= settings.spit_points, "the prey scored for the upset (%.0f)" % game.own_round_tally(victim))
	await _frames(int(settings.spit_daze * 120.0) + 30)
	check(not game.is_dazed(victim) and victim.boost_enabled == boost_was, "the daze wears off and the boost is back")

	print("a joined prey is spat from its place:")
	var school2: School = game.field.schools[1]
	school2.set_physics_process(false)
	var joiner: FishController = game.live_prey()[1]
	joiner.freeze = true
	joiner.global_position = school2.fish_position(5) + Vector3(0, 0, 1.0)
	game.join.cooldown.clear()
	var joined := game.join.join(joiner, school2, 5)
	check(joined and game.join.is_joined(joiner), "a prey joins a school")
	await _frames(40)
	_aim_hunter_at(school2.fish_position(5))
	await _frames(3)
	bite = game.bites[fish]
	bite.lunge_gain = 0.0
	bite_events.clear()
	check(bite.try_bite(), "a bite at its place starts")
	check(await _until(func() -> bool: return not bite_events.is_empty(), 3.0), "and lands")
	check(game.round_spat == 2 and not game.eaten.has(joiner), "the joined prey is spat out, not eaten (spat %d)" % game.round_spat)
	check(not game.join.is_joined(joiner) and not joiner.freeze, "it's out of the school and free")
	check(not school2.is_alive(5), "its place in the school went")

	print("hurling:")
	var third: FishController = game.live_prey()[2]
	var mouth := bite.mouth_point()
	game._spit(third, fish, mouth)
	check(float(game.queasy[fish]) >= settings.queasy_max and game.hurled_out.has(fish), "the third spit maxes the queasy bar: it hurls")
	check(game.phase == WhatStinksMatch.Phase.ROUND_OVER, "the round is over")
	check(not bool(game.last_results["hunters_won"]) and game.last_results["reason"] == "hurled" and int(game.last_results["spat"]) == 3, "the prey won (hurled, 3 spat)")
	check(fish.controls_locked, "the Hunter is held")
	check(float(game.last_results["points"][victim]) >= settings.spit_points + settings.survivor_bonus, "a spat prey has its spit points and the survivor bonus (%.0f)" % float(game.last_results["points"][victim]))

	print("a full belly:")
	check(await _restart(), "round 0 again")
	check(is_equal_approx(float(game.satiation[fish]), settings.satiation_max * settings.satiation_start) and game.hurled_out.is_empty() and game.round_spat == 0, "bars reset, nobody hurled")
	check(not fish.controls_locked, "the Hunter is free")
	game._feed(fish, 1000.0)
	check(await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.ROUND_OVER, 2.0), "a full belly ends the round")
	check(bool(game.last_results["hunters_won"]) and game.last_results["reason"] == "full", "the Hunter won (full)")
	var expect := settings.satiation_max * (1.0 - settings.satiation_start) * settings.satiation_points
	check(float(game.last_results["points"][fish]) >= expect - 0.5, "its points are the satiation earned plus the early bonus (%.0f)" % float(game.last_results["points"][fish]))

	print("the clock out, still hungry:")
	check(await _restart(), "round 0 again")
	game.time_left = 0.05
	check(await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.ROUND_OVER, 2.0), "the round ends")
	check(not bool(game.last_results["hunters_won"]) and game.last_results["reason"] == "hungry", "the prey won (hungry)")
	check(float(game.last_results["points"][game.live_prey()[0]]) >= settings.survivor_bonus, "a prey has the survivor bonus")

	print("schools come back:")
	check(await _restart(), "round 0 again")
	settings.respawn_every = 1.0
	settings.respawn_batch = 2
	settings.respawn_school_delay = 1.0
	var kept: School = game.field.schools[0]
	var full := int(kept.get_meta("ws_full"))
	var gone: Array = [0, 1, 2, 3]
	kept.eat(gone)
	var low := kept.alive_count()
	check(low == full - 4, "four fish of a school eaten (%d of %d)" % [low, full])
	check(await _until(func() -> bool: return kept.alive_count() >= full, 8.0), "the school regrows to its first size (%d of %d)" % [kept.alive_count(), full])
	var doomed: School = game.field.schools[1]
	var all: Array = []
	for i in doomed.fish_count():
		all.append(i)
	doomed.eat(all)
	check(doomed.alive_count() == 0, "a school is wiped out")
	var doomed_id := doomed.get_instance_id()
	check(await _until(func() -> bool: return not game.field.schools.any(func(s: School) -> bool: return s.get_instance_id() == doomed_id), 3.0), "it is cleared away")
	check(await _until(func() -> bool: return game.field.schools.size() == 4, 4.0), "and a new school takes its place (%d schools)" % game.field.schools.size())
	var newest: School = game.field.schools[game.field.schools.size() - 1]
	var nearest := INF
	for hunter in game.hunters:
		nearest = minf(nearest, hunter.global_position.distance_to(newest.middle()))
	check(newest.alive_count() > 0 and nearest >= minf(settings.respawn_school_gap, settings.arena_radius * 0.5), "away from the Hunter (%.0f m)" % nearest)

	print("Sweep is unchanged:")
	settings.variant = WhatStinksSettings.Variant.SWEEP
	check(await _restart(), "a Sweep round")
	check(not game.stomach() and not game.field.steady, "no stomach, no respawn")
	var sweep_school: School = game.field.schools[0]
	sweep_school.eat([0, 1, 2])
	await _frames(240)
	check(sweep_school.alive_count() == int(sweep_school.get_meta("ws_full")) - 3, "a Sweep school does not regrow")
	settings.variant = WhatStinksSettings.Variant.STOMACH

	print("the bots:")
	game.start_round(1)
	await _frames(3)
	var homes: Array[Vector3] = []
	for s in game.field.schools:
		homes.append(s.middle())
	var from := game._hunter_start().origin
	homes.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(from) < b.distance_squared_to(from))
	var near_third := homes.slice(0, ceili(homes.size() / 3.0))
	var waiters := 0
	var baited := 0
	for other in game.players:
		var node: Variant = game.bots.get(other)
		if node is WanderBot:
			waiters += 1
			if near_third.has((node as WanderBot).home):
				baited += 1
	check(waiters >= 2 and baited == waiters, "prey bots wait at the schools nearest the Hunter's start (%d of %d)" % [baited, waiters])
	check(await _live(), "round 1 is live")
	_stop_bots()
	var robot: FishController = game.hunters[0]
	check(game.bots.get(robot) is WhatStinksBot, "a bot hunts")
	var hunter_bot: WhatStinksBot = game.bots[robot]
	var robot_bite: HunterBite = game.bites[robot]
	var lure: FishController = game.live_prey()[0]
	var mouth_at := robot_bite.mouth_point() + (-robot.global_basis.z) * robot_bite.reach() * 0.5
	lure.global_position = mouth_at
	game.echo.forced[lure] = 0.9
	var seen: Dictionary = hunter_bot._nearest_target(robot_bite.mouth_point())
	check(hunter_bot._is_stinker(lure) and (seen["at"] as Vector3).distance_to(lure.global_position) > 0.5, "a prey it can read is not a target")
	check(hunter_bot._stinker_in_bite(robot_bite), "and it holds the bite while one is in the frustum")
	game.echo.forced[lure] = 0.0
	check(not hunter_bot._is_stinker(lure) and not hunter_bot._stinker_in_bite(robot_bite), "a prey it can't read is just a fish")
	game.echo.forced[lure] = 0.9
	settings.variant = WhatStinksSettings.Variant.SWEEP
	check(not hunter_bot._is_stinker(lure), "Sweep: the bot does not read stinkers")
	settings.variant = WhatStinksSettings.Variant.STOMACH
	game.echo.forced.clear()

	print("the HUD:")
	var hud: WhatStinksHud = game._hud
	check(hud.headline().begins_with("Prey spat out") and hud.bars_hunter() == robot, "the headline counts the spat and the bars show the Hunter's")
	check("mistaken for food" in hud.role_line() or game.is_spectating(), "the prey's role line says what to do (%s)" % hud.role_line())
	await _frames(10)
	check(true, "it drew without a script error")

	print("stomach_probe: %d checks, %d failed" % [checks, failures])
	main.set_mode(main.FREE_PLAY)
	await _frames(5)
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
	fish.global_position += (target + Vector3(0.0, 0.0, 1.5)) - bite.mouth_point()
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	bite.cooldown = 0.0
