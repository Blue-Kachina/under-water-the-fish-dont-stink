## Two-stage attacks, phase 4 (two-stage-attack.md 4f): the Lamprey Queen's drill (attacks/drill_attack.gd, lamprey_rig.gd).
## The Queen wears the drill style. The hold winds her body back and speeds the rasp (the rig); a tap (under drill_min_charge)
## is the plain bite and the old latch roll; a held release is a corkscrew dash (drill_dash x her top speed x the charge for
## drill_time, the top speed lifted for it and given back, rolling at lamprey_spin) that takes the fish the disc passes through
## up to capacity x the charge, in a real match; a prey player met at full charge latches her (the dash ends, she rolls on it), at
## less than full it does not; the host runs a guest's dash on its puppet's position; drill_dash 0 switches the dash off.
##   Godot_console.exe --headless --path . res://tests/drill_probe.tscn
extends Node

const KEY := "lamprey_queen"

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
	print("drill_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# --- The Queen on a plain controller --------------------------------------------------------

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
	bite.name = "HunterBite"  # as the match names it (LampreyRig finds it by name)
	fish.add_child(bite)
	bite.setup(fish, form)
	var attack := bite.attack as DrillAttack
	_check(attack != null and attack.key == "drill" and str(form["attack"]) == "drill", "style: the Queen's sheet names the drill and the bite wears it")
	var rig_node := fish._visual.get_node("LampreyRig")
	await _frames(2)

	print("      numbers")
	_check(is_equal_approx(bite.reach_at(1.0), bite.reach_at(0.0)), "reach: holding does not lengthen it (%.2f m)" % bite.reach_at(1.0))
	_check(bite.capacity_at(0.0) == 1 and bite.capacity_at(1.0) == roundi(float(form["capacity"]) * settings.drill_capacity_mult),
			"capacity: %d at no charge, %d at full (x%.1f)" % [bite.capacity_at(0.0), bite.capacity_at(1.0), settings.drill_capacity_mult])
	_check(bite.capacity_at(0.5) > bite.capacity_at(0.0) and bite.capacity_at(0.5) < bite.capacity_at(1.0), "capacity: it grows with the charge (%d at half)" % bite.capacity_at(0.5))

	print("      a tap")
	var landed: Array = []
	bite.chomped.connect(func(_m: Vector3, _r: float, _d: float, _c: int) -> void: landed.append(bite.strike_charge()))
	bite.try_open()
	await _frames(3)
	bite.try_close()
	var dashed := false
	await _until(func() -> bool:
		dashed = dashed or attack.active()
		return not landed.is_empty(), tps)
	await _frames(3)
	_check(not landed.is_empty() and float(landed[0]) < settings.drill_min_charge and not dashed, "a tap lands at almost no charge (%.2f) and does not dash" % (float(landed[0]) if not landed.is_empty() else -1.0))
	_check(float(rig_node.get("latch_left")) > 0.0 or absf(float(rig_node.get("spin"))) > 0.1, "and it is the plain bite: she latches and rolls (latch %.2f s left)" % float(rig_node.get("latch_left")))
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	await _frames(tps * 2)

	print("      the hold")
	var top0 := fish.top_speed_scale
	bite.cooldown = 0.0
	landed.clear()
	_check(bite.try_open(), "the press opens")
	await _frames(int(tps * 1.5))
	_check(bite.charge() >= 0.999, "held to full charge")
	var wind: float = rig_node.get("_wind")
	var twist := (rig_node.get("rig") as SpineRig).twist
	var spin_now: float = rig_node.get("spin")
	_check(wind > 0.95 and twist < spin_now - 0.5, "the body is wound back against the roll (wind %.2f, twist %.2f rad against a spin of %.2f)" % [wind, twist, spin_now])
	_check(not attack.active() and is_equal_approx(fish.top_speed_scale, top0 * settings.hold_speed_mult), "no dash while held (top speed x%.2f of the hold cost)" % (fish.top_speed_scale / top0))

	print("      the dash")
	var top_base := fish.top_speed_scale / settings.hold_speed_mult
	fish.linear_velocity = Vector3.ZERO
	var start := fish.global_position
	var forward := -fish.global_basis.z.normalized()
	var spin0: float = rig_node.get("spin")
	bite.try_close()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(attack.active(), "the release starts the dash")
	var speed_cap := fish.max_boost_speed * top_base * settings.drill_dash * DrillAttack.lunge_impulse(settings)
	_check(is_equal_approx(attack.speed, speed_cap), "its speed: %.1f m/s (%.1f x her top speed)" % [attack.speed, settings.drill_dash])
	_check(is_equal_approx(fish.top_speed_scale, top_base * maxf(settings.drill_dash * DrillAttack.lunge_impulse(settings), 1.0)), "the integrator's cap is lifted for it (x%.2f)" % (fish.top_speed_scale / top_base))
	var peak := 0.0
	var spin_peak := 0.0
	var ticks := 0
	while attack.active() and ticks < tps * 3:
		await get_tree().physics_frame
		await get_tree().process_frame
		peak = maxf(peak, fish.linear_velocity.dot(forward))
		spin_peak = maxf(spin_peak, float(rig_node.get("spin")) - spin0)
		ticks += 1
	var lasted := float(ticks) / tps
	_check(peak > attack.speed * 0.9, "she drives forward (%.1f m/s of %.1f)" % [peak, attack.speed])
	_check(absf(lasted - settings.drill_time) < 0.15, "for drill_time (%.2f s of %.2f)" % [lasted, settings.drill_time])
	var gone := (fish.global_position - start).dot(forward)
	_check(gone > attack.speed * settings.drill_time * 0.5, "and gets somewhere (%.1f m)" % gone)
	_check(spin_peak > UnnaturalSettings.shared().lamprey_spin * settings.drill_time * 0.6, "rolling at lamprey_spin (%.1f rad through the dash)" % spin_peak)
	_check(is_equal_approx(fish.top_speed_scale, top_base), "the top speed is given back (x%.3f)" % (fish.top_speed_scale / top_base))
	_check(float(rig_node.get("latch_left")) <= 0.0, "no latch without prey")
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	await _frames(tps)

	print("      switches")
	settings.drill_dash = 0.0
	bite.cooldown = 0.0
	bite.try_open()
	await _frames(int(tps * 1.5))
	bite.try_close()
	dashed = false
	await _until(func() -> bool:
		dashed = dashed or attack.active()
		return not bite.busy(), tps * 2)
	_check(not dashed, "drill_dash 0: a full hold does not dash")
	settings.drill_dash = 2.0
	await _frames(tps * 2)
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
	var attack := bite.attack as DrillAttack
	_check(attack != null and str(bite.form["key"]) == KEY and bite.world == game, "match: the Hunter wears the Queen: the drill style")
	if attack == null:
		return
	var rig_node := fish._visual.get_node("LampreyRig")
	var input := FishInput.new()
	fish.controls = input
	var bitten: Array = []
	game.bitten.connect(func(hunter: FishController, school_fish: int, prey: Array) -> void:
		if hunter == fish:
			bitten.append([school_fish, prey.size()]))
	var top_base := fish.top_speed_scale

	print("      A: through a school")
	var school := _fullest(game)
	await _aim_at(bite, school.middle() + Vector3(0.0, 0.0, 14.0))  # her nose well short of it: the contact cone takes nothing
	bite.cooldown = 0.0
	var cap := bite.capacity_at(1.0)
	var alive0 := school.alive_count()
	input.jump = true
	await _until(func() -> bool: return bite.holding() and bite.charge() >= 0.999, tps * 3)
	fish.global_position += (school.middle() + Vector3(0.0, 0.0, 14.0)) - bite.mouth_point()  # (the school flees while she holds: line her up on it again)
	var strays := bitten.size()
	input.jump = false
	await _until(func() -> bool: return attack.active(), tps)
	_check(attack.active() and attack.budget == cap, "the release dashes with a budget of %d fish" % cap)
	await _until(func() -> bool: return not attack.active(), tps * 2)
	await _frames(5)
	var total := 0
	var events := 0
	for i in range(strays, bitten.size()):
		total += int(bitten[i][0]) + int(bitten[i][1])
		events += 1
	_check(total >= 2 and total <= cap, "the disc took %d fish on the run, within the budget of %d (%d judgments)" % [total, cap, events])
	_check(school.alive_count() == alive0 - total or _scattered(game, school, alive0), "and they are gone from the school (%d of %d left)" % [school.alive_count(), alive0])
	_check(attack.budget == cap - total, "the budget is what is left (%d)" % attack.budget)
	_check(is_equal_approx(fish.top_speed_scale, top_base), "top speed given back")
	_check(bite.cooldown >= settings.chew_delay * 0.9, "one chew delay on the cooldown (%.2f s)" % bite.cooldown)
	await _until(func() -> bool: return not bite.busy(), tps * 3)

	print("      B: a plain tap")
	school = _fullest(game)
	await _aim_at(bite, school.middle())
	bite.cooldown = 0.0
	strays = bitten.size()
	input.jump = true
	await _frames(4)
	input.jump = false
	var dashed := false
	await _until(func() -> bool:
		dashed = dashed or attack.active()
		return bitten.size() > strays, tps * 2)
	var tap_ate := int(bitten[-1][0]) + int(bitten[-1][1]) if bitten.size() > strays else -1
	_check(not dashed and tap_ate >= 0 and tap_ate <= bite.capacity_at(0.0), "a tap does not dash and takes the plain bite's one (%d)" % tap_ate)
	await _until(func() -> bool: return not bite.busy(), tps * 3)

	print("      C: prey in the path")
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
		var away := school.middle() + Vector3(0.0, 60.0, 0.0)  # clear of every school: only the players are near
		# At half charge: eaten, but no latch and the dash runs its time.
		await _aim_at(bite, away)
		bite.cooldown = 0.0
		var one := prey[0]
		input.jump = true
		await _until(func() -> bool: return bite.holding() and bite.charge() >= 0.5, tps * 3)
		input.jump = false
		_put_ahead(bite, one, bite.size.bite_reach(fish, bite.form) * 3.0)
		var run := 0
		await _until(func() -> bool: return attack.active(), tps)
		while attack.active() and run < tps * 3:
			await get_tree().physics_frame
			run += 1
			if not game.eaten.has(one):
				_put_ahead(bite, one, 0.8)  # keeps it in her path (a free prey drifts off in the current)
		await _frames(2)
		_check(game.eaten.has(one), "half charge: a player three reaches ahead is drilled")
		_check(float(run) / tps > settings.drill_time * 0.8 and float(rig_node.get("latch_left")) <= 0.0, "half charge: no latch, the dash runs its time (%.2f s)" % (float(run) / tps))
		await _until(func() -> bool: return not bite.busy(), tps * 3)
		# At full charge: the first prey the disc meets latches her.
		await _aim_at(bite, away)
		bite.cooldown = 0.0
		var two := prey[1]
		input.jump = true
		await _until(func() -> bool: return bite.holding() and bite.charge() >= 0.999, tps * 3)
		input.jump = false
		_put_ahead(bite, two, bite.size.bite_reach(fish, bite.form) * 3.0)
		run = 0
		await _until(func() -> bool: return attack.active(), tps)
		while attack.active() and run < tps * 3:
			await get_tree().physics_frame
			run += 1
			if not game.eaten.has(two):
				_put_ahead(bite, two, 0.8)  # keeps it in her path (a free prey drifts off in the current)
		await _frames(2)
		_check(game.eaten.has(two), "full charge: the player is drilled")
		_check(float(run) / tps < settings.drill_time * 0.8, "and the dash ends on it (%.2f s of %.2f)" % [float(run) / tps, settings.drill_time])
		await _frames(2)
		_check(float(rig_node.get("latch_left")) > 0.0, "and she latches: the roll goes on (%.2f s left)" % float(rig_node.get("latch_left")))
		_check(is_equal_approx(fish.top_speed_scale, top_base), "top speed given back after a latch")
		await _until(func() -> bool: return not bite.busy(), tps * 3)

	print("      D: a guest's Queen (the host runs the dash on the puppet)")
	school = _fullest(game)
	await _aim_at(bite, school.middle() + Vector3(0.0, 0.0, 14.0))
	bite.cooldown = 0.0
	fish.controls = null
	fish.make_puppet()
	bite.net_open()
	await _frames(tps)
	fish.global_position += (school.middle() + Vector3(0.0, 0.0, 14.0)) - bite.mouth_point()  # (the school flees while the mouth is open)
	bite.net_close(1.0)
	strays = bitten.size()
	var forward := -fish.global_basis.z.normalized()
	for i in int(tps * 1.0):
		await get_tree().physics_frame
		if attack.active():
			fish.global_position += forward * (attack.speed / tps)  # what the guest's position updates would do
	await _frames(3)
	var net_total := 0
	for i in range(strays, bitten.size()):
		net_total += int(bitten[i][0]) + int(bitten[i][1])
	_check(attack.budget < bite.capacity_at(bite.net_cap) and net_total >= 1, "net: the host drilled %d fish along the puppet's path" % net_total)
	_check(not attack.active() and is_equal_approx(fish.top_speed_scale, top_base), "net: the puppet's top speed was never lifted")
	fish.puppet = false
	fish.freeze = false
	bite.release_fish()


## Whether the school's survivors scattered into others (the school splits when eaten: the count held is then another one's).
func _scattered(_game: WhatStinksMatch, school: School, before: int) -> bool:
	return school.alive_count() < before


## Puts `victim` `distance` m ahead of the Hunter's mouth, level with it.
func _put_ahead(bite: HunterBite, victim: FishController, distance: float) -> void:
	victim.global_position = bite.mouth_point() + (-fish.global_basis.z.normalized()) * distance
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
