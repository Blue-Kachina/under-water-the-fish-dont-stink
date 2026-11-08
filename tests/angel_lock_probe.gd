## Two-stage attacks, phase 3 (two-stage-attack.md 4c, section 7 Lock): the Fallen Angel's lock style.
## Plays a real What Stinks? match with the local fish as the Angel and checks: the gate (a press with nothing in range, behind
## or off to the side is denied: no hold, no cooldown, the denied sound), the target is the nearest fish at the press and stays
## the target, the Angel matches a moving target's pace, holds the stand-off and keeps facing it, the stick orbits it, the lock
## snaps (target too far, eaten) with the lost sound and a small cooldown, the count (the school ahead of the target beats the
## school behind the Angel, the camera's lock-on bite stacks on top: D8), a release takes the target and its schoolmates, the
## lash's crunches are delayed by distance, the net report (net_extra / net_catch_rule), the bot's plan.
##   Godot_console.exe --headless --path . res://tests/angel_lock_probe.tscn
extends Node

var main: Node
var fish: FishController
var game: WhatStinksMatch
var bite: HunterBite
var attack: LockAttack
var input := FishInput.new()
var checks := 0
var failures := 0
var tps := 120
var sounds: Array = []
var bitten: Array = []
## Prey the probe moves by hand: prey -> its velocity (set every tick).
var drive := {}
## Schools a section has used (each section takes a fresh one, the most room round it).
var used: Array[School] = []


func _ready() -> void:
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
		_drive()


func _drive() -> void:
	for prey: FishController in drive:
		if is_instance_valid(prey):
			prey.linear_velocity = drive[prey]


func _until(done: Callable, ticks: int) -> bool:
	for i in ticks:
		if done.call():
			return true
		await get_tree().physics_frame
		_drive()
	return done.call()


func _run() -> void:
	await _frames(5)
	tps = int(Engine.physics_ticks_per_second)
	var settings := WhatStinksSettings.shared()
	settings.form = "fallen_angel"
	settings.hide_time = 1.0
	settings.round_time = 600.0
	settings.arena_radius = 90.0
	settings.school_count = 4
	settings.school_min = 40
	settings.school_max = 40
	settings.min_players = 5
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	settings.variant = WhatStinksSettings.Variant.SWEEP
	settings.lock_bite = false
	settings.hold_cooldown_per_s = 0.0
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	settings.satiation_max = 1000.0
	settings.bite_takes_players = true
	settings.hitstop_ms = 0.0
	HunterSize.shared().size_mult = 1.0
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	main.play_match()
	await _frames(5)
	game = main.what_stinks
	_check(game != null and game.is_hunter(fish) and game.bites.has(fish), "match: the local fish is the Hunter with a bite")
	if game == null:
		get_tree().quit(1)
		return
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 4)
	bite = game.bites[fish]
	attack = bite.attack as LockAttack
	_check(attack != null and str(bite.form["key"]) == "fallen_angel" and bite.world == game, "match: the Angel's style is the lock")
	if attack == null:
		get_tree().quit(1)
		return
	fish.controls = input
	bite.lunge_gain = 0.0
	bite.fx().sound_log = func(beat: String, _id: String) -> void: sounds.append(beat)
	game.bitten.connect(func(_h: FishController, school_fish: int, prey: Array) -> void: bitten.append([school_fish, prey.size()]))
	for school: School in game.field.schools:
		school.set_physics_process(false)
	var prey: Array[FishController] = []
	for other in game.players:
		if other != fish and game.is_live_prey(other):
			prey.append(other)
	_check(prey.size() >= 3, "match: prey to test with (%d)" % prey.size())
	for p in prey:
		for s: School in game.field.schools:
			s.release_claim(p)
		p.controls = null
		p.freeze = true
	var reach := bite.size.bite_reach(fish, bite.form)
	var centre := (game.field.schools[0] as School).middle()
	var far := centre + Vector3(0.0, 70.0, 0.0)
	var park := far + Vector3(0.0, 0.0, 400.0)
	for p in prey:
		p.global_position = park

	await _gate(settings, prey, far, reach)
	await _target(settings, prey, far, reach)
	await _breaking(settings, prey, far, reach)
	await _school(settings, far, reach)
	await _stack(settings)
	await _net()
	await _sizes_and_taps(settings, prey, far)
	print("angel_lock_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## The Angel at `at` facing `basis`' nose, nothing held, off cooldown.
func _place(at: Vector3, basis := Basis.IDENTITY) -> void:
	input.jump = false
	await _until(func() -> bool: return not bite.busy(), tps * 4)
	fish.controls_locked = false
	fish.global_transform = Transform3D(basis, at)
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	bite.cooldown = 0.0
	await _frames(3)


func _stage(prey: FishController, at: Vector3, velocity := Vector3.ZERO) -> void:
	prey.freeze = false
	prey.controls_locked = true
	prey.global_position = at
	prey.linear_velocity = velocity
	drive[prey] = velocity


func _park(prey: Array[FishController], park: Vector3) -> void:
	for p in prey:
		drive.erase(p)
		p.freeze = true
		p.global_position = park


func _press_open() -> void:
	input.jump = true
	await _until(func() -> bool: return bite.holding() or attack.denied_age < 0.2, tps)
	await _frames(2)


func _gate(settings: WhatStinksSettings, prey: Array[FishController], far: Vector3, reach: float) -> void:
	print("      A: the gate")
	await _place(far)
	var forward := -fish.global_basis.z
	var side := fish.global_basis.x
	var mouth := bite.mouth_point()
	var cases := {
		"nothing about": park_of(far),
		"a fish behind it": mouth - forward * reach * 0.8,
		"a fish off to the side": mouth + side * reach * 0.8,
		"a fish ahead but out of range": mouth + forward * reach * (settings.angel_lock_range + 1.0),
	}
	for label: String in cases:
		sounds.clear()
		_stage(prey[0], cases[label])
		await _frames(2)
		await _press_open()
		_check(not bite.holding() and not bite.busy() and bite.cooldown == 0.0, "gate: %s: the press is refused, no hold, no cooldown" % label)
		_check(attack.denied_age < 0.3 and sounds.has("denied"), "gate: %s: the denied beat (sound %s)" % [label, str(sounds.has("denied"))])
		input.jump = false
		await _frames(3)
	_check(not attack.active(), "gate: nothing was locked")
	# A fish ahead in range and in the cone passes.
	_stage(prey[0], mouth + forward * reach * 1.2)
	await _frames(2)
	sounds.clear()
	await _press_open()
	_check(bite.holding() and attack.active(), "gate: a fish ahead within range and the cone: the press takes")
	_check(sounds.has("open") and not sounds.has("denied"), "gate: and plays the cones' open, not the denied")
	input.jump = false
	bite.abort()  # (let go without eating the fish: the next section needs it)
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	_park(prey, far + Vector3(0.0, 0.0, 400.0))


func park_of(far: Vector3) -> Vector3:
	return far + Vector3(0.0, 0.0, 400.0)


func _target(settings: WhatStinksSettings, prey: Array[FishController], far: Vector3, reach: float) -> void:
	print("      B: the target, the pace, the facing, the orbit")
	await _place(far)
	var forward := -fish.global_basis.z
	var mouth := bite.mouth_point()
	var first := prey[0]
	var second := prey[1]
	var drift := Vector3(4.0, 0.0, 0.0)
	_stage(first, mouth + forward * reach * 1.0, drift)
	_stage(second, mouth + forward * reach * 1.5 + Vector3(0.0, 1.0, 0.0))
	await _frames(2)
	await _press_open()
	_check(bite.holding() and attack.active(), "lock: the press takes")
	_check(attack._prey == first, "lock: the target is the nearest fish at the press")
	# The other fish drifts closer than the target: the target stays.
	_stage(second, first.global_position + Vector3(0.0, 0.0, 1.5))
	await _frames(tps)
	_check(attack._prey == first, "lock: it keeps the target for the whole hold")
	await _frames(tps)
	var velocity_gap := (fish.linear_velocity - first.swim_velocity()).length()
	_check(velocity_gap < 2.5, "lock: it matches the target's pace (%.2f m/s off a %.1f m/s target)" % [velocity_gap, drift.length()])
	var line := first.global_position - fish.global_position
	var nose := -fish.global_basis.z
	var off := rad_to_deg(nose.angle_to(line))
	_check(off < 8.0, "lock: it keeps facing the target (%.1f deg off)" % off)
	var stand := settings.angel_standoff * reach
	_check(absf(line.length() - stand) < stand * 0.3, "lock: it holds the stand-off (%.1f m of %.1f)" % [line.length(), stand])
	# The stick orbits it.
	var before := atan2(-line.x, -line.z)
	input.stick = Vector2(1.0, 0.0)
	await _frames(tps)
	input.stick = Vector2.ZERO
	await _frames(tps / 4)
	line = first.global_position - fish.global_position
	var swept := absf(wrapf(atan2(-line.x, -line.z) - before, -PI, PI))
	_check(swept > 1.0, "lock: the stick orbits it round the target (%.2f rad in a second)" % swept)
	_check(absf(line.length() - stand) < stand * 0.3, "lock: at the stand-off still (%.1f m)" % line.length())
	nose = -fish.global_basis.z
	_check(rad_to_deg(nose.angle_to(line)) < 10.0, "lock: and still facing it (%.1f deg)" % rad_to_deg(nose.angle_to(line)))
	_check(attack.ring_count(bite) == attack.count_now and attack.count_now >= 1, "lock: the HUD ring shows what a release would take (x%d)" % attack.count_now)
	# The release takes the target.
	var taken := bitten.size()
	var gone := game.eaten.size()
	input.jump = false
	await _until(func() -> bool: return bitten.size() > taken, tps * 2)
	_check(game.eaten.has(first) and game.eaten.size() == gone + 1, "lock: the release eats the target")
	_check(not attack.active(), "lock: and lets the lock go")
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	_park(prey, park_of(far))


func _breaking(settings: WhatStinksSettings, prey: Array[FishController], far: Vector3, reach: float) -> void:
	print("      C: breaking")
	var forward := Vector3.FORWARD
	# Too far.
	var eaten_before := game.eaten.size()
	await _place(far)
	var victim := prey[2]
	victim.global_position = park_of(far)
	_stage(victim, bite.mouth_point() + forward * reach * 1.0)
	await _frames(2)
	sounds.clear()
	var aborts := [0]
	var counter := func() -> void: aborts[0] += 1
	bite.aborted.connect(counter)
	await _press_open()
	_check(bite.holding() and attack.active(), "break: locked")
	await _frames(tps / 2)
	victim.global_position += Vector3(0.0, 0.0, -settings.angel_break_range * reach - 10.0)
	await _frames(3)
	_check(not bite.holding() and not attack.active() and aborts[0] == 1, "break: the target past angel_break_range snaps the lock")
	_check(sounds.has("lost") and attack.lost_age < 0.2, "break: with the lock_lost sound")
	_check(bite.cooldown >= settings.angel_break_cooldown - 0.1 and not bite.busy(), "break: the crown closes empty with a small cooldown (%.2f s)" % bite.cooldown)
	input.jump = false
	bite.aborted.disconnect(counter)
	await _frames(5)
	_check(game.eaten.size() == eaten_before, "break: nothing was eaten")
	_park(prey, park_of(far))
	# The target eaten by someone else.
	await _place(far)
	_stage(victim, bite.mouth_point() + forward * reach * 1.0)
	await _frames(2)
	sounds.clear()
	await _press_open()
	_check(bite.holding() and attack.active(), "break: locked again")
	game.eaten[victim] = true
	await _frames(3)
	_check(not bite.holding() and not attack.active() and sounds.has("lost"), "break: a target eaten by someone else snaps it")
	game.eaten.erase(victim)
	input.jump = false
	_park(prey, park_of(far))


func _loneliest(skip: Array[School]) -> School:
	## The school whose middle fish has the most room to the other schools' fish (the press then locks on its own).
	var best: School
	var best_room := -1.0
	for school: School in game.field.schools:
		if skip.has(school) or school.alive_count() < 3:
			continue
		var at := school.middle()
		var room := INF
		for other: School in game.field.schools:
			if other == school:
				continue
			for i in other.fish_count():
				if other.is_alive(i):
					room = minf(room, other.fish_position(i).distance_to(at))
		if room > best_room:
			best_room = room
			best = school
	if best == null and not skip.is_empty():
		return _loneliest([])
	return best


func _school(settings: WhatStinksSettings, _far: Vector3, reach: float) -> void:
	print("      D: the count and the lash")
	var counts := {}
	for which in ["school ahead of the target", "school behind the Angel"]:
		var school: School = _loneliest(used)
		used.append(school)
		var middle := school.middle()
		# An outer school fish is the target (the Angel's stand-off then keeps the school clear to one side of it).
		var best := -1
		for i in school.fish_count():
			if school.is_alive(i) and (best < 0 or school.fish_position(i).distance_to(middle) > school.fish_position(best).distance_to(middle)):
				best = i
		var at := school.fish_position(best)
		await _place(at + Vector3(0.0, 0.0, reach * 1.6))
		sounds.clear()
		await _press_open()
		_check(bite.holding() and attack.active() and attack._school == school, "count (%s): locked on a fish of the school" % which)
		if not attack.active():
			input.jump = false
			continue
		var count := _line_up(school, which == "school ahead of the target")
		await _frames(1)
		var alive := school.alive_count()
		_check(count >= 1, "count (%s): the ring shows x%d" % [which, count])
		counts[which] = count
		var taken := bitten.size()
		input.jump = false
		await _until(func() -> bool: return bitten.size() > taken, tps * 2)
		var ate := int(bitten[-1][0]) if bitten.size() > taken else 0
		_check(ate >= 1 and ate <= count + 2 and school.alive_count() == alive - ate, "count (%s): the release took %d of x%d, all from the school" % [which, ate, count])
		_check(school.is_alive(attack._index) == false or attack._index == -1, "count (%s): (the target went too)" % which)
		counts[which + "_ate"] = ate
		if which == "school ahead of the target":
			_check(attack.gaps.size() == ate and attack.gaps == _sorted(attack.gaps), "lash: the catch's distances are listed nearest first (%d)" % attack.gaps.size())
			var delays: Array[float] = []
			for i in ate:
				delays.append(attack.crunch_delay(bite, i))
			var rising := true
			for i in range(1, delays.size()):
				rising = rising and delays[i] >= delays[i - 1]
			_check(delays[0] == 0.0 and rising and (ate < 2 or delays[-1] > 0.0), "lash: each crunch is delayed by its distance, the first on the contact tick (last %.3f s)" % (delays[-1] if not delays.is_empty() else 0.0))
			_check(sounds.has("chomp") and sounds.has("crunch"), "lash: the lash sound and a crunch played on contact")
		await _until(func() -> bool: return not bite.busy(), tps * 3)
	_check(int(counts.get("school ahead of the target", 0)) > int(counts.get("school behind the Angel", 99)), "count: the school ahead of the target earns more than the school behind the Angel (x%d > x%d)" % [int(counts.get("school ahead of the target", 0)), int(counts.get("school behind the Angel", 0))])
	_check(int(counts.get("school behind the Angel_ate", 0)) >= 1, "count: striking from the wrong side still takes the target")


## Puts the Angel at the stand-off from its target on the far side from the school's middle (the school lies ahead beyond the
## target) or on the school's side (the school lies behind the Angel), facing the target, and returns what a release would take
## there. Done in one tick, so the answer is the geometry's alone (the sea floor can keep it from getting there for real).
func _line_up(school: School, far_side: bool) -> int:
	var at := attack.target_at()
	var out := at - school.middle()
	out = out.normalized() if out.length_squared() > 0.0001 else Vector3.UP
	var stand := bite.settings.angel_standoff * bite.size.bite_reach(fish, bite.form)
	var where := at + (out if far_side else -out) * stand
	var look := (at - where).normalized()
	var up := Vector3.UP if absf(look.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	fish.global_transform = Transform3D(Basis.looking_at(look, up), where)
	fish.linear_velocity = Vector3.ZERO
	attack._dir = (where - at).normalized()
	attack._dist = stand
	attack._update_preview(bite)
	return attack.count_now


func _sorted(list: Array[float]) -> Array[float]:
	var copy := list.duplicate()
	copy.sort()
	return copy


func _stack(settings: WhatStinksSettings) -> void:
	print("      E: stacking with the camera's lock-on (D8)")
	var school: School = _loneliest(used)
	used.append(school)
	var middle := school.middle()
	var best := -1
	for i in school.fish_count():
		if school.is_alive(i) and (best < 0 or school.fish_position(i).distance_to(middle) < school.fish_position(best).distance_to(middle)):
			best = i
	var at := school.fish_position(best)
	var reach := bite.size.bite_reach(fish, bite.form)
	await _place(at + Vector3(0.0, 0.0, reach * 1.6))
	await _press_open()
	_check(bite.holding() and attack.active(), "stack: locked")
	_line_up(school, true)
	var plain := attack._count(bite, school, null, bite.mouth_point(), -fish.global_basis.z, bite.charge())
	settings.lock_bite = true
	settings.lock_bite_mult = 4.0
	game.lock_cam.set_focus(school.centre)
	var mult := game.lock_stack_mult(fish, bite, school)
	var stacked := attack._count(bite, school, null, bite.mouth_point(), -fish.global_basis.z, bite.charge())
	_check(mult > 1.0 and stacked > plain, "stack: the lock-on bite on the same school multiplies the count (x%.2f: %d -> %d)" % [mult, plain, stacked])
	game.lock_cam.set_focus((used[0] as School).centre)
	_check(game.lock_stack_mult(fish, bite, school) == 1.0, "stack: the lock-on on another school adds nothing")
	settings.lock_bite = false
	_check(game.lock_stack_mult(fish, bite, school) == 1.0, "stack: lock_bite off adds nothing")
	input.jump = false
	await _until(func() -> bool: return not bite.busy(), tps * 3)


func _net() -> void:
	print("      F: net report and the bot")
	var school: School = _loneliest(used)
	used.append(school)
	var reach := bite.size.bite_reach(fish, bite.form)
	var middle := school.middle()
	var best := -1
	for i in school.fish_count():
		if school.is_alive(i) and (best < 0 or school.fish_position(i).distance_to(middle) > school.fish_position(best).distance_to(middle)):  # an outer fish: the school lies one way from it, so a line-up is clear
			best = i
	await _place(school.fish_position(best) + Vector3(0.0, 0.0, reach * 1.6))
	await _press_open()
	_check(bite.holding() and attack.active(), "net: locked")
	var extra := attack.net_extra(bite)
	_check(extra.has("school") and int(extra["school"]) == school.id and int(extra["index"]) == attack._index, "net: the landing reports the target's school and index")
	var mouth := bite.mouth_point()
	var forward := -fish.global_basis.z.normalized()
	var rule := attack.net_catch_rule(bite, mouth, forward, 0.5, extra)
	_check(not bool(rule["frustum"]) and int(rule["capacity"]) >= 1 and rule["only"] == school, "net: the host builds the rule from the report (%d fish)" % int(rule["capacity"]))
	var fall_back := attack.net_catch_rule(bite, mouth, forward, 0.5, {"school": school.id, "index": 9999})
	_check(bool(fall_back["frustum"]), "net: a report it cannot match falls back to the plain cone")
	var far_mouth := mouth + Vector3(0.0, 500.0, 0.0)
	_check(bool(attack.net_catch_rule(bite, far_mouth, forward, 0.5, extra)["frustum"]), "net: a target far from the reported mouth falls back to the cone")
	# The bot: let go once lined up.
	var bot := WhatStinksBot.new()
	var settings := WhatStinksSettings.shared()
	_line_up(school, true)
	# (The share is measured from the mouth, so a target near a small school's middle can read low even lined up: the bot's call
	# is checked against the share itself, and the clear case is the school behind it, below.)
	var lined := attack._share(bite, school, bite.mouth_point(), -fish.global_basis.z, bite.charge()) >= settings.hunter_bot_lock_align
	_check(bool(attack.bot_plan(bot, bite)["hold"]) == (not lined), "bot: it lets go exactly when the line-up is past hunter_bot_lock_align (%.2f, lined up: %s)" % [settings.hunter_bot_lock_align, str(lined)])
	_line_up(school, false)
	_check(bool(attack.bot_plan(bot, bite)["hold"]), "bot: school behind it: it holds on and swings round")
	input.jump = false
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	await _place(Vector3(0.0, 400.0, 0.0))
	bot.stinker_blocks = false
	_check(not bool(attack.bot_plan(bot, bite)["press"]), "bot: nothing in the gate: no press")
	await _place(school.fish_position(best) + Vector3(0.0, 0.0, reach * 1.6))
	var near := school.alive_count() > 0 and not attack._pick(bite).is_empty()
	_check(near == bool(attack.bot_plan(bot, bite)["press"]), "bot: presses only when the gate passes")
	bot.free()


## Review additions: the lock at the sizes a match is played at (0.5 is the default, 2.0 the far end), a quick tap
## (press and release inside the opening) still takes the target, and tap mode (try_bite) is the plain frustum bite.
func _sizes_and_taps(settings: WhatStinksSettings, prey: Array[FishController], far: Vector3) -> void:
	print("      G: sizes, a quick tap, tap mode")
	var victim := prey[0]
	game.eaten.erase(victim)  # (section B ate it)
	for mult: float in [0.5, 2.0]:
		fish.set_meta("size_mult", mult)
		HunterSize.shared().apply(fish, bite.form)
		await _frames(3)
		var reach := bite.size.bite_reach(fish, bite.form)
		await _place(far)
		var forward := -fish.global_basis.z
		var gone := game.eaten.size()
		_stage(victim, bite.mouth_point() + forward * reach * 1.2)
		await _frames(2)
		await _press_open()
		_check(bite.holding() and attack._prey == victim, "size %.1f: the gate takes and locks the fish ahead" % mult)
		await _frames(tps * 2)  # (the close speed is not scaled with size: a big Angel takes a moment to close in)
		var line := victim.global_position - fish.global_position
		var stand := settings.angel_standoff * reach
		_check(absf(line.length() - stand) < maxf(stand * 0.4, 0.5), "size %.1f: it holds the stand-off (%.2f m of %.2f)" % [mult, line.length(), stand])
		_check(rad_to_deg((-fish.global_basis.z).angle_to(line)) < 10.0, "size %.1f: and keeps facing it" % mult)
		input.jump = false
		await _until(func() -> bool: return game.eaten.size() > gone, tps * 2)
		_check(game.eaten.has(victim), "size %.1f: the release eats the target" % mult)
		await _until(func() -> bool: return not bite.busy(), tps * 3)
		game.eaten.erase(victim)
		_park(prey, park_of(far))
	fish.set_meta("size_mult", 1.0)
	HunterSize.shared().apply(fish, bite.form)
	await _frames(3)
	var reach_1 := bite.size.bite_reach(fish, bite.form)
	# A quick tap: the press and the release a couple of ticks apart.
	await _place(far)
	var gone_tap := game.eaten.size()
	_stage(victim, bite.mouth_point() + (-fish.global_basis.z) * reach_1 * 1.2)
	await _frames(2)
	input.jump = true
	await _frames(2)
	input.jump = false
	await _until(func() -> bool: return game.eaten.size() > gone_tap, tps * 3)
	_check(game.eaten.has(victim), "tap: a quick press and release still takes the target")
	_check(not attack.active(), "tap: and leaves no lock behind")
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	game.eaten.erase(victim)
	_park(prey, park_of(far))
	# Tap mode: today's snap, no gate, no lock; whatever is in the frustum.
	settings.bite_mode = WhatStinksSettings.BiteMode.TAP
	await _place(far)
	var gone_mode := game.eaten.size()
	_stage(victim, bite.mouth_point() + (-fish.global_basis.z) * reach_1 * 0.8)
	await _frames(2)
	input.jump = true
	await _frames(3)
	_check(not attack.active(), "tap mode: no lock is taken")
	input.jump = false
	await _until(func() -> bool: return game.eaten.size() > gone_mode, tps * 3)
	_check(game.eaten.has(victim), "tap mode: the snap eats what is in the frustum")
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	game.eaten.erase(victim)
	_park(prey, park_of(far))
