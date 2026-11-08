## Two-stage attacks, phase 4 (two-stage-attack.md 4e): the King of Herrings' coil-whip (attacks/coil_attack.gd, king_rig.gd).
## The King wears the coil style. The press starts the coil and the hold tightens it (the rig's body curls and the head is
## cocked aside, more with the charge); the catch is a flat sector round a pivot behind the mouth, as wide as the coil was
## tight (coil_arc_min to coil_arc_max), with the capacity lifted by coil_capacity_mult and the reach left alone; the head
## sweeps through the middle of the arc on the contact tick; a real match: a held release eats within the held capacity and
## a tap within the plain one; a guest's release is judged on the host as the same sector; the bot's plan.
##   Godot_console.exe --headless --path . res://tests/coil_whip_probe.tscn
extends Node

const KEY := "king_of_herrings"

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var tps := 120


func _ready() -> void:
	WhatStinksSettings.shared().bite_mode = WhatStinksSettings.BiteMode.HOLD
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame  # the body is posed in _process


func _until(done: Callable, ticks: int) -> bool:
	for i in ticks:
		if done.call():
			return true
		await get_tree().physics_frame
	return done.call()


func _run() -> void:
	await _frames(5)
	tps = int(Engine.physics_ticks_per_second)
	main.set_environment("Ocean")
	await _frames(5)
	await _alone()
	await _in_match()
	print("coil_whip_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# --- The King on a plain controller ---------------------------------------------------------

func _alone() -> void:
	var form := HunterForm.sheet(KEY)
	var size := HunterSize.shared()
	size.size_mult = 1.0
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	size.apply(fish, form)
	HunterForms.dress(fish, KEY)
	await _frames(3)
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 25.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	await _frames(5)
	var settings := WhatStinksSettings.shared()
	var bite := HunterBite.new()
	bite.name = "HunterBite"  # as the match names it (KingRig finds it by name)
	fish.add_child(bite)
	bite.setup(fish, form)
	var attack := bite.attack as CoilAttack
	_check(attack != null and attack.key == "coil" and str(form["attack"]) == "coil", "style: the King's sheet names the coil and the bite wears it")
	var rig_node := fish._visual.get_node("KingRig")
	var rig: SpineRig = rig_node.get("rig")
	await _frames(2)

	print("      numbers")
	_check(is_equal_approx(bite.reach_at(1.0), bite.reach_at(0.0)), "reach: holding does not lengthen it (%.2f m)" % bite.reach_at(1.0))
	_check(bite.capacity_at(1.0) == maxi(1, roundi(bite.capacity_at(0.0) * settings.coil_capacity_mult)) and bite.capacity_at(1.0) > bite.capacity_at(0.0),
			"capacity: %d at no charge, %d at full (x%.1f)" % [bite.capacity_at(0.0), bite.capacity_at(1.0), settings.coil_capacity_mult])
	_check(is_equal_approx(rad_to_deg(attack.half_at(bite, 0.0)) * 2.0, settings.coil_arc_min) and is_equal_approx(rad_to_deg(attack.half_at(bite, 1.0)) * 2.0, settings.coil_arc_max),
			"arc: %.0f degrees at no charge, %.0f at full" % [settings.coil_arc_min, settings.coil_arc_max])

	print("      the sector")
	var mouth := bite.mouth_point()
	var forward := -fish.global_basis.z.normalized()
	var up := fish.global_basis.y.normalized()
	var reach := bite.size.bite_reach(fish, form)
	var back := reach * settings.coil_pivot
	var narrow: Callable = attack.sector_rule(bite, mouth, forward, up, 0.0)["inside"]
	var wide: Callable = attack.sector_rule(bite, mouth, forward, up, 1.0)["inside"]
	var apex := mouth - forward * back
	var right := forward.cross(up).normalized()
	var dist := (back + reach) * 0.8
	_check(narrow.call(mouth + forward * reach * 0.9) and wide.call(mouth + forward * reach * 0.9), "ahead at the reach: in the narrow arc and the wide")
	var side_pt := apex + (forward * cos(deg_to_rad(65.0)) + right * sin(deg_to_rad(65.0))) * dist
	_check(not narrow.call(side_pt) and wide.call(side_pt), "65 degrees off the nose: out of the narrow arc, in the wide (the charge widens it)")
	var edge_pt := apex + (forward * cos(deg_to_rad(95.0)) + right * sin(deg_to_rad(95.0))) * dist
	_check(not wide.call(edge_pt), "95 degrees off the nose: out of even the wide arc")
	_check(wide.call(apex + (forward * cos(deg_to_rad(-60.0)) + right * sin(deg_to_rad(-60.0))) * dist), "the arc is the same to the other side")
	_check(not wide.call(mouth + forward * (reach * 1.05 + 0.2)), "beyond the mouth's reach it ends (no longer than the cone)")
	_check(not wide.call(mouth + up * reach * (settings.coil_thick + 0.3) + forward * reach * 0.5), "flat: a fish well above the plane is out")
	_check(wide.call(mouth + up * reach * (settings.coil_thick - 0.1) + forward * reach * 0.5), "...and one within the thickness is in")
	_check(not wide.call(apex - forward * 2.0), "behind the pivot: out")
	var cone := bite.radius() * 0.9
	_check(not HunterBite.in_frustum(mouth, forward, reach, bite.radius(), side_pt) and wide.call(side_pt), "the plain cone would not take that side fish (%.1f m out); the arc does" % cone)
	var rule := attack.catch_rule(bite)
	_check(not bool(rule["frustum"]) and int(rule["capacity"]) == bite.capacity_at(0.0), "catch rule: not the frustum, capacity %d at no charge" % int(rule["capacity"]))

	print("      press, hold, release")
	_check(attack.sweep_at(bite) == 0.0 and attack.coil_target(bite) == 0.0, "idle: no sweep, no coil")
	var coil0: float = rig_node.get("_coil")
	var head0 := rig.points[0] - fish.global_position
	var chord0 := rig.points[0].distance_to(rig.points[rig.points.size() - 1])
	_check(bite.try_open(), "the press opens")
	await _frames(tps / 4)
	var target_early := attack.coil_target(bite)
	_check(target_early >= 0.25 and target_early < 0.6, "the coil starts at the press (%.2f)" % target_early)
	var sweep_early := attack.sweep_at(bite)
	await _frames(int(tps * 1.5))
	_check(bite.charge() >= 0.999 and attack.coil_target(bite) >= 0.999, "held to full charge, the coil is fully tight")
	var sweep_full := attack.sweep_at(bite)
	_check(sweep_early > 0.0 and sweep_full > sweep_early and absf(sweep_full - attack.half_at(bite, 1.0)) < 0.02,
			"the head is cocked aside and further as it tightens (%.0f then %.0f degrees, the arc's half is %.0f)" % [rad_to_deg(sweep_early), rad_to_deg(sweep_full), rad_to_deg(attack.half_at(bite, 1.0))])
	var coiled: float = rig_node.get("_coil")
	var chord := rig.points[0].distance_to(rig.points[rig.points.size() - 1])
	_check(coil0 == 0.0 and coiled > 0.95, "the body is coiled (%.2f)" % coiled)
	_check(chord < chord0 * 0.85, "its chord shortens (%.1f of %.1f m)" % [chord, chord0])
	var off := (rig.points[0] - fish.global_position).distance_to(head0)
	_check(off > 0.5, "and the head has swung off the nose line (%.1f m)" % off)
	var skin: ShaderMaterial = rig_node.get("skin")
	var warn_seen := 0.0
	for i in tps / 4:
		await get_tree().physics_frame
		await get_tree().process_frame
		warn_seen = maxf(warn_seen, float(skin.get_shader_parameter("warn")))
	_check(warn_seen > 0.3, "the skin burns as it tightens (%.2f)" % warn_seen)
	var held_for := bite.held_for
	_check(held_for > 1.5, "no max hold: still open after %.1f s" % held_for)
	var landed: Array = []
	var middle: Array = []
	bite.chomped.connect(func(_m: Vector3, _r: float, _d: float, _c: int) -> void:
		landed.append(bite.strike_charge())
		middle.append(attack.sweep_at(bite)))
	var sweeps: Array[float] = []
	_check(bite.try_close(), "the release")
	await get_tree().physics_frame  # (the release is made between ticks here; the signal comes before the tick it starts)
	await get_tree().physics_frame
	var settle := await _until(func() -> bool:
		sweeps.append(attack.sweep_at(bite))
		return not landed.is_empty(), tps)
	_check(settle and absf(float(landed[0]) - 1.0) < 0.01, "contact lands, at full charge")
	var half_full := attack.half_at(bite, 1.0)
	_check(absf(float(middle[0])) < half_full * 0.12, "the head crosses the arc's middle on the contact tick (%.1f degrees off the nose, half arc %.0f)" % [rad_to_deg(float(middle[0])), rad_to_deg(half_full)])
	var first := sweeps[0] if not sweeps.is_empty() else 0.0
	_check(first > half_full * 0.6, "the whip begins from the cocked side (%.0f degrees)" % rad_to_deg(first))
	var lowest := 0.0
	for i in tps / 2:
		await get_tree().physics_frame
		lowest = minf(lowest, attack.sweep_at(bite))
	_check(lowest < -half_full * 0.3, "it sweeps through to the far side (%.0f degrees)" % rad_to_deg(lowest))
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	await _frames(tps)
	_check(attack.sweep_at(bite) == 0.0 and attack.coil_target(bite) == 0.0, "and is home and uncoiled after")
	_check(float(rig_node.get("_coil")) < 0.05, "the body has unwound (%.2f)" % float(rig_node.get("_coil")))
	off = (rig.points[0] - fish.global_position).distance_to(head0)
	_check(off < 1.5, "the head is back on the nose line (%.2f m)" % off)

	print("      a tap")
	bite.cooldown = 0.0
	landed.clear()
	middle.clear()
	bite.try_open()
	await _frames(3)
	bite.try_close()
	await _until(func() -> bool: return not landed.is_empty(), tps)
	_check(not landed.is_empty() and float(landed[0]) < 0.1, "a tap lands at almost no charge (%.2f)" % (float(landed[0]) if not landed.is_empty() else -1.0))
	_check(not middle.is_empty() and absf(float(middle[0])) < attack.half_at(bite, 0.0) * 0.5 + 0.02, "and its head crosses its middle too")
	await _until(func() -> bool: return not bite.busy(), tps * 3)

	print("      the tap mode is the old bite")
	settings.bite_mode = WhatStinksSettings.BiteMode.TAP
	bite.cooldown = 0.0
	landed.clear()
	bite.try_bite()
	await _until(func() -> bool: return not landed.is_empty(), tps)
	_check(landed.size() == 1, "tap mode: a one-press bite still lands")
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD

	print("      the bot")
	var bot := WhatStinksBot.new()
	bite.cooldown = 0.0
	bot.target_ahead = 0.9
	bot.target_gap = reach * (settings.hunter_bot_open_gap + 1.0)
	bot.target_prev_gap = bot.target_gap
	_check(not bool(attack.bot_plan(bot, bite)["press"]), "bot: a fish far off is not worth opening for")
	bot.target_gap = reach * settings.hunter_bot_open_gap * 0.9
	_check(bool(attack.bot_plan(bot, bite)["press"]), "bot: a fish in range gets a press")
	bot.stinker_blocks = true
	_check(not bool(attack.bot_plan(bot, bite)["press"]), "bot: not with a stinker about (Upset Stomach)")
	bot.stinker_blocks = false
	bite.try_open()
	await _frames(int(tps * (settings.hunter_bot_charge * float(form["charge_s"]) + 0.3)))
	mouth = bite.mouth_point()
	forward = -fish.global_basis.z.normalized()
	apex = mouth - forward * back
	right = forward.cross(fish.global_basis.y.normalized()).normalized()
	bot.target_at = mouth + forward * reach * 0.6
	bot.target_gap = reach * 0.6
	bot.target_prev_gap = bot.target_gap + 0.5
	_check(bool(attack.bot_plan(bot, bite)["hold"]) == false, "bot: a charged mouth with a fish dead ahead in the arc: let go")
	var half_now := rad_to_deg(attack.half_at(bite, bite.charge()))
	var inside_deg := half_now - 8.0
	var outside_deg := half_now + 25.0
	bot.target_at = apex + (forward * cos(deg_to_rad(inside_deg)) + right * sin(deg_to_rad(inside_deg))) * dist
	bot.target_gap = reach * 0.9
	bot.target_prev_gap = bot.target_gap + 0.5
	_check(not bool(attack.bot_plan(bot, bite)["hold"]), "bot: a fish %.0f degrees off, inside the arc as widened now (half %.0f): let go" % [inside_deg, half_now])
	bot.target_at = apex + (forward * cos(deg_to_rad(outside_deg)) + right * sin(deg_to_rad(outside_deg))) * dist
	bot.target_gap = reach * 0.9
	bot.target_prev_gap = bot.target_gap + 0.3
	_check(bool(attack.bot_plan(bot, bite)["hold"]), "bot: a fish %.0f degrees off, outside the arc and not escaping: keep holding" % outside_deg)
	bot.free()
	bite.abort()
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	bite.queue_free()
	await _frames(2)


# --- A match ----------------------------------------------------------------------------

func _in_match() -> void:
	fish.puppet = false
	fish.freeze = false
	var settings := WhatStinksSettings.shared()
	settings.form = KEY
	settings.hide_time = 1.0
	settings.round_time = 300.0
	settings.arena_radius = 90.0
	settings.school_count = 4
	settings.school_min = 30
	settings.school_max = 30
	settings.min_players = 5
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	settings.variant = WhatStinksSettings.Variant.SWEEP
	settings.lock_bite = false
	settings.hold_cooldown_per_s = 0.0
	settings.hold_alarm_mult = 1.0
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	settings.satiation_max = 1000.0
	HunterSize.shared().size_mult = 1.0
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	main.play_match()
	await _frames(5)
	var game: WhatStinksMatch = main.what_stinks
	_check(game != null and game.is_hunter(fish) and game.bites.has(fish), "match: the local fish is the Hunter with a bite")
	if game == null:
		return
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 4)
	var bite: HunterBite = game.bites[fish]
	var attack := bite.attack as CoilAttack
	_check(attack != null and str(bite.form["key"]) == KEY and bite.world == game, "match: the Hunter wears the King: the coil style")
	if attack == null:
		return
	var input := FishInput.new()
	fish.controls = input
	var bitten: Array = []
	game.bitten.connect(func(hunter: FishController, school_fish: int, prey: Array) -> void:
		if hunter == fish:
			bitten.append([school_fish, prey.size()]))

	print("      A: a held release")
	var school := _fullest(game)
	await _aim_at(bite, school.middle())
	bite.cooldown = 0.0
	var cap_held := bite.capacity_at(1.0)
	input.jump = true
	await _until(func() -> bool: return bite.holding() and bite.charge() >= 0.999, tps * 3)
	_check(bite.holding() and bite.charge() >= 0.999 and attack.coil_target(bite) >= 0.999, "held: full charge, the coil tight")
	var strays := bitten.size()
	input.jump = false
	await _until(func() -> bool: return bitten.size() > strays, tps * 2)
	var ate_held := int(bitten[-1][0]) if bitten.size() > strays else -1
	_check(ate_held >= 1 and ate_held <= cap_held, "held: the whip ate %d of a capacity of %d" % [ate_held, cap_held])
	await _until(func() -> bool: return not bite.busy(), tps * 3)

	print("      B: a tap")
	school = _fullest(game)
	await _aim_at(bite, school.middle())
	bite.cooldown = 0.0
	var cap_tap := bite.capacity_at(0.0)
	input.jump = true
	await _frames(4)
	input.jump = false
	strays = bitten.size()
	await _until(func() -> bool: return bitten.size() > strays, tps * 2)
	var ate_tap := int(bitten[-1][0]) if bitten.size() > strays else -1
	_check(ate_tap >= 1 and ate_tap <= cap_tap, "tap: ate %d of a capacity of %d" % [ate_tap, cap_tap])
	await _until(func() -> bool: return not bite.busy(), tps * 3)

	print("      C: prey off to the side (outside the cone, inside the wide arc)")
	var prey: Array[FishController] = []
	for other in game.players:
		if other != fish and game.is_live_prey(other):
			prey.append(other)
	_check(prey.size() >= 2, "prey: the match has prey to test with (%d)" % prey.size())
	if prey.size() >= 2:
		for p in prey:
			for s: School in game.field.schools:
				s.release_claim(p)
			p.controls = null
		var tapped := prey[0]
		var wide_one := prey[1]
		school = _fullest(game)
		await _aim_at(bite, school.middle() + Vector3(0.0, 60.0, 0.0))  # away from any school: only the players are near
		bite.cooldown = 0.0
		# A tap: the narrow arc, the prey 65 degrees off is out of it.
		_put_side(bite, tapped, 65.0)
		var kills := game.eaten.size()
		input.jump = true
		await _frames(4)
		input.jump = false
		await _until(func() -> bool: return not bite.busy(), tps * 2)
		_check(game.eaten.size() == kills and not game.eaten.has(tapped), "tap: a player 65 degrees off the nose is missed (the arc is narrow without a charge)")
		# A held release: the wide arc takes it.
		await _aim_at(bite, school.middle() + Vector3(0.0, 60.0, 0.0))
		bite.cooldown = 0.0
		input.jump = true
		await _until(func() -> bool: return bite.holding() and bite.charge() >= 0.999, tps * 3)
		_put_side(bite, wide_one, 55.0)  # the lunge carries the pivot on, so a side point swings wider by the contact: leave margin
		_check(not HunterBite.in_frustum(bite.mouth_point(), -fish.global_basis.z, bite.reach(), bite.radius(), wide_one.global_position), "held: that player is outside the plain cone")
		# Free prey drift in the current (3 m up in a second), so keep it in the sector until the landing.
		var pinned := true
		var pin := func() -> void:
			if pinned and is_instance_valid(wide_one):
				_put_side(bite, wide_one, 55.0)
		get_tree().physics_frame.connect(pin)
		input.jump = false
		await _until(func() -> bool: return game.eaten.has(wide_one), tps)
		pinned = false
		get_tree().physics_frame.disconnect(pin)
		_check(game.eaten.has(wide_one), "held: the same place is inside the arc the full coil whips: eaten")
		await _until(func() -> bool: return not bite.busy(), tps * 3)

		print("      D: a guest's King (the host judges the same sector)")
		await _aim_at(bite, school.middle() + Vector3(0.0, 60.0, 0.0))
		bite.cooldown = 0.0
		fish.controls = null
		fish.make_puppet()
		bite.net_open()
		await _frames(tps)
		var seen := bite.charge()
		bite.net_close(1.0)
		_check(bite.net_cap > 0.0 and bite.net_cap <= minf(1.0, seen + 0.3), "net: the host caps the guest's charge to what it saw (%.2f of %.2f)" % [bite.net_cap, seen])
		await _until(func() -> bool: return not bite.busy(), tps * 2)
		var cap := bite.net_cap
		_put_side(bite, tapped, 65.0)
		game.judge_net_bite(fish, bite.mouth_point(), -fish.global_basis.z, 0.0, {})
		_check(not game.eaten.has(tapped), "net: a landing at no charge keeps the narrow arc: the player 65 degrees off is missed")
		# (that report spent the bite; the next must clear the host's min gap between landings)
		game._net_bite_at.clear()
		bite.net_cap = cap
		_put_side(bite, tapped, 65.0)
		game.judge_net_bite(fish, bite.mouth_point(), -fish.global_basis.z, 1.0, {})
		_check(game.eaten.has(tapped), "net: at the capped charge the host's sector takes the player 65 degrees off")
		fish.puppet = false
		fish.freeze = false
		bite.release_fish()


## Puts `victim` `degrees` off the Hunter's nose on its flat plane, three quarters of the sector's radius out from the pivot.
func _put_side(bite: HunterBite, victim: FishController, degrees: float) -> void:
	var settings := WhatStinksSettings.shared()
	var reach := bite.size.bite_reach(fish, bite.form)
	var back := reach * settings.coil_pivot
	var forward := -fish.global_basis.z.normalized()
	var up := fish.global_basis.y.normalized()
	var right := forward.cross(up).normalized()
	var apex := bite.mouth_point() - forward * back
	victim.global_position = apex + (forward * cos(deg_to_rad(degrees)) + right * sin(deg_to_rad(degrees))) * (back + reach) * 0.75
	victim.linear_velocity = Vector3.ZERO
	victim.angular_velocity = Vector3.ZERO


## Puts the Hunter facing -Z with its mouth at `point` (a little behind it, so the school is just ahead).
func _aim_at(bite: HunterBite, point: Vector3) -> void:
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	fish.controls_locked = false
	fish.global_transform = Transform3D(Basis.IDENTITY, point)
	fish.global_position += point - bite.mouth_point() + Vector3(0.0, 0.0, float(bite.size.bite_reach(fish, bite.form)) * 0.3)
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	await _frames(3)


## The school with the most fish left (the earlier sections thin the others out and scare them).
func _fullest(game: WhatStinksMatch) -> School:
	var best: School = game.field.schools[0]
	for other: School in game.field.schools:
		if other.alive_count() > best.alive_count():
			best = other
	return best
