extends Node
## What Stinks?: the locked bite (a Hunter locked on a school takes fish from it alone,
## as many as its line-up earns). Plays the real mode through Main with the local
## fish as Hunter and a school pinned in front of it; checks that a locked bite
## takes only the locked school's fish, that a square, close line-up takes more than a
## poor one (facing away), that a locked bite on a school out of reach falls back to the
## plain cone bite, and that lock_bite off does the same.
##   Godot_console.exe --headless --path . res://tests/what_stinks_lock_bite_probe.tscn

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
	settings.round_time = 120.0
	settings.arena_radius = 90.0
	settings.school_count = 4
	settings.school_min = 40
	settings.school_max = 40
	settings.min_players = 4
	settings.bot_hunter_rounds = 1
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	settings.variant = WhatStinksSettings.Variant.SWEEP
	settings.bite_takes_players = false
	HunterSize.shared().size_mult = 1.0
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	main.play_match()
	await _frames(5)
	game = main.what_stinks
	if game == null:
		check(false, "Play starts a match")
		get_tree().quit(1)
		return
	game.bitten.connect(func(hunter: FishController, school_fish: int, prey: Array) -> void: bite_events.append([hunter, school_fish, prey]))
	check(await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, 3.0), "the round is live")
	for other in game.players:
		if other != fish:
			other.freeze = true
	var bite: HunterBite = game.bites[fish]
	bite.lunge_gain = 0.0
	var capacity := bite.capacity()
	settings.lock_bite_mult = 8.0 / float(capacity)  # a full line-up takes about 8 fish
	print("capacity %d, reach %.1f m, mult %.2f" % [capacity, bite.reach(), settings.lock_bite_mult])

	var school: School = game.field.schools[0]
	var other_school: School = game.field.schools[1]
	for each in game.field.schools:
		each.set_physics_process(false)
	var target := school.fish_position(0)

	print("settings:")
	check(settings.lock_bite and settings.lock_bite_mult > 0.0, "the locked bite is on by default")

	print("a square, close bite:")
	game.lock_cam.set_focus(school.centre)
	check(game.lock_cam.focus_of(fish) == school.centre, "locked on the school")
	var good := await _bite_from(Vector3(0.0, 0.0, 1.5), false, target, bite)
	var total_after: int = game.field.alive_total()
	check(good >= 1, "it took %d fish" % good)
	check(school.alive_count() == 40 - good, "all of them from the locked school (%d left of 40)" % school.alive_count())
	check(other_school.alive_count() == 40, "none from another school")
	check(good <= roundi(capacity * settings.lock_bite_mult) + 1, "within what the line-up earns (%d)" % roundi(capacity * settings.lock_bite_mult))
	print("      alive total now %d" % total_after)

	print("a poor line-up (facing away):")
	game.lock_cam.set_focus(school.centre)
	var poor := await _bite_from(Vector3(0.0, 0.0, 3.0), true, school.centre.global_position, bite)
	check(poor >= 1, "it still took %d (at least one)" % poor)
	# The same spot, facing the school then away: the line-up alone sets the count (fish positions vary run to run).
	await _until(func() -> bool: return not bite.busy(), 4.0)
	game.lock_cam.set_focus(school.centre)
	settings.lock_bite_mult = 40.0 / float(capacity)
	var spot := school.fish_position(_alive_fish(school)) + Vector3(0.0, 0.0, 1.0)
	var middle := Vector3.ZERO
	var alive := 0
	for i in school.fish_count():
		if school.is_alive(i) and not school.is_claimed(i):
			middle += school.fish_position(i)
			alive += 1
	middle /= maxf(alive, 1.0)
	var face := Basis.looking_at((middle - spot).normalized() if middle.distance_to(spot) > 0.1 else Vector3.FORWARD)
	fish.global_transform = Transform3D(face, spot)
	var weights := [settings.lock_w_close, settings.lock_w_speed]
	settings.lock_w_close = 0.0
	settings.lock_w_speed = 0.0
	var toward: Dictionary = game._locked_bite(fish, bite, capacity, bite.reach())
	fish.global_transform = Transform3D(face.rotated(Vector3.UP, PI), spot)
	var away_d: Dictionary = game._locked_bite(fish, bite, capacity, bite.reach())
	check(not toward.is_empty() and not away_d.is_empty() and int(toward["capacity"]) > int(away_d["capacity"]), "facing the school earns more than facing away (%d > %d)" % [int(toward.get("capacity", 0)), int(away_d.get("capacity", 0))])
	settings.lock_w_close = weights[0]
	settings.lock_w_speed = weights[1]
	settings.lock_bite_mult = 8.0 / float(capacity)

	print("lock_bite off, or too far: the plain bite:")
	settings.lock_bite = false
	game.lock_cam.set_focus(other_school.centre)
	var plain := await _bite_from(Vector3(0.0, 0.0, 1.5), false, school.fish_position(0) if school.is_alive(0) else target, bite)
	check(plain <= capacity, "a plain bite takes at most capacity (%d of %d)" % [plain, capacity])
	check(other_school.alive_count() == 40, "the locked school was not eaten from")
	settings.lock_bite = true
	game.lock_cam.set_focus(other_school.centre)
	var far_bites := bite_events.size()
	await _bite_from(Vector3(0.0, 0.0, 1.5), false, school.fish_position(0) if school.is_alive(0) else target, bite)
	check(other_school.alive_count() == 40 and bite_events.size() > far_bites, "locked on a school out of reach: it falls back to the cone bite")

	print("ramming:")
	var victims := game.field.schools[2] as School
	var count_before := victims.alive_count()
	var ram_speed := settings.ram_speed * pow(game.size.size_of(fish), game.size.speed_exp)
	var ram_target := victims.fish_position(_alive_fish(victims))
	await _until(func() -> bool: return not bite.busy() and bite.cooldown <= 0.0, 8.0)
	fish.global_transform = Transform3D(Basis.IDENTITY, ram_target + Vector3(0.0, 0.0, 6.0))
	var slow_before := game.rammed_total
	for i in 6:  # too slow: nothing
		fish.linear_velocity = Vector3(0.0, 0.0, -ram_speed * 0.3)
		await get_tree().physics_frame
	check(game.rammed_total == slow_before, "below ram speed it takes nothing")
	fish.global_transform = Transform3D(Basis.IDENTITY, ram_target + Vector3(0.0, 0.0, 9.0))
	for i in 90:
		fish.linear_velocity = Vector3(0.0, 0.0, -ram_speed * 1.5)
		await get_tree().physics_frame
		if game.rammed_total > slow_before:
			break
	check(game.rammed_total > slow_before, "at ram speed its body takes fish (%d)" % (game.rammed_total - slow_before))
	check(victims.alive_count() < count_before, "they left the school (%d of %d)" % [victims.alive_count(), count_before])
	settings.ram = false
	var off_before := game.rammed_total
	fish.global_transform = Transform3D(Basis.IDENTITY, game.field.schools[3].centre.global_position + Vector3(0.0, 0.0, 9.0))
	for i in 40:
		fish.linear_velocity = Vector3(0.0, 0.0, -ram_speed * 1.5)
		await get_tree().physics_frame
	check(game.rammed_total == off_before, "ram off: nothing")
	settings.ram = true

	print("callouts:")
	var seen: Array = []
	game.callout.connect(func(hunter: FishController, event: Dictionary) -> void: seen.append([hunter, event]))
	await _until(func() -> bool: return not bite.busy() and bite.cooldown <= 0.0, 8.0)
	game.combos.clear()
	settings.lock_bite = false
	var solo := await _bite_from(Vector3(0.0, 0.0, 1.5), false, game.field.schools[3].fish_position(_alive_fish(game.field.schools[3])), bite)
	check(not seen.is_empty() and seen[0][0] == fish, "a bite that took fish calls it out (%d fish)" % solo)
	if not seen.is_empty():
		var first: Dictionary = seen[0][1]
		check(int(first["count"]) == solo and first["source"] == "bite", "with its count and source (%s x%d)" % [first["title"], int(first["count"])])
		if solo >= 2:
			check(int(first["chain"]) >= 2 and first["title"] != "CHOMP", "several at once is a multi (%s)" % first["title"])
	seen.clear()
	var ram_from := game.rammed_total
	fish.global_transform = Transform3D(Basis.IDENTITY, game.field.schools[1].fish_position(_alive_fish(game.field.schools[1])) + Vector3(0.0, 0.0, 9.0))
	for i in 90:
		fish.linear_velocity = Vector3(0.0, 0.0, -ram_speed * 1.5)
		await get_tree().physics_frame
		if game.rammed_total > ram_from:
			break
	print("      ram dbg: total %d from %d seen %d alive_s1 %d speed %.1f need %.1f" % [game.rammed_total, ram_from, seen.size(), game.field.schools[1].alive_count(), fish.speed, ram_speed])
	check(game.rammed_total > ram_from and not seen.is_empty() and seen[-1][1]["source"] == "ram", "a ram calls itself out too")
	settings.lock_bite = true

	print("what_stinks_lock_bite_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## Places the Hunter `gap` m behind `target` (facing away when `away`), bites, and returns the school fish it took.
func _bite_from(gap: Vector3, away: bool, target: Vector3, bite: HunterBite) -> int:
	await _until(func() -> bool: return not bite.busy() and bite.cooldown <= 0.0, 8.0)
	var basis := Basis(Vector3.UP, PI) if away else Basis.IDENTITY
	fish.global_transform = Transform3D(basis, target + gap + Vector3(0.0, 0.0, fish.hitbox_length * 0.45))
	fish.global_position += (target + gap) - bite.mouth_point()
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	bite.cooldown = 0.0
	await _frames(3)
	var before := bite_events.size()
	if not bite.try_bite():
		return -1
	await _until(func() -> bool: return bite_events.size() > before, 3.0)
	return int(bite_events[-1][1]) if bite_events.size() > before else 0


func _alive_fish(school: School) -> int:
	for i in school.fish_count():
		if school.is_alive(i) and not school.is_claimed(i):
			return i
	return 0
