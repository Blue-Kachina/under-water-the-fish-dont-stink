extends Node
## Unnatural's chests and powerups (planning_unnatural.md §7, phase 5): chests
## are buried round the arena and open by holding still beside one (the fish
## untouchable and unseen meanwhile) or by battering it, offering three
## different powerups; picking one gives a stack, the same again stacks;
## stacking scales each powerup; Greek Fire burns what's in its trail; Chain
## Lightning jumps its number of times; torpedoes seek and blow up; Bow Grow
## Bow widens the battery (and the bite with it) and batters slower from its
## stacks threshold; proc coefficients and chains stop runaway loops.
##   Godot_console.exe --headless --path . res://tests/powerup_probe.tscn

var failures := 0
var main: Node
var fish: FishController
var run: UnnaturalRun
var horde: Horde
var settings := UnnaturalSettings.shared()
var powers := PowerupSettings.shared()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # chest picks pause the game
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	settings.spawning = false
	settings.chest_cost = false  # chests are free here (pearl_currency_probe has prices)
	settings.fish_attack = FishAttack.Kind.BITE  # these checks are the bite's (attack_probe has the rest)
	settings.twists = false  # and no fish's twist skews them
	settings.card_choices = 0
	settings.enemy_speed_scale = 0.0
	settings.bite_damage = 0.0
	settings.enemy_damage_scale = 0.0
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde
	var offers := []
	run.cards_offered.connect(func(f: FishController, cards: Array, heading: String, line: String) -> void: offers.append([cards, heading]))

	print("chests:")
	check(run.shut_chests().size() == settings.chest_count, "%d chests buried" % run.shut_chests().size())
	var inside := true
	for chest in run.chests:
		var flat := Vector2(chest.global_position.x, chest.global_position.z).length()
		inside = inside and flat <= settings.arena_radius and absf(chest.global_position.y - settings.arena_floor) < 1.0
		inside = inside and chest.get_parent() == run
	check(inside, "all in the arena, in the seabed")
	var chest: TreasureChest = run.chests[0]
	await _park(chest.global_position + Vector3(0, 1.5, 2.0), Vector3.FORWARD)
	var seen_picking := false
	for t in roundi(settings.chest_open_time * 120.0) + 60:
		await get_tree().physics_frame
		if run.is_picking(fish) and not offers.size():
			seen_picking = seen_picking or horde.chaseable[0] == 0
	check(seen_picking, "holding still beside one: untouchable and unseen while it opens")
	check(chest.is_unlocked_for(fish) and not chest.is_open_for(fish), "after chest_open_time it unlocks, and waits for Jump")
	run.open_unlocked(fish)
	check(chest.is_open_for(fish) and offers.size() == 1 and (offers[0][1] as String).contains("TREASURE"), "Jump then opens it, offering powerups (%s)" % offers[0][1] if offers.size() else "")
	var cards: Array = offers[0][0]
	var ids := cards.map(func(c: Dictionary) -> String: return c.powerup)
	check(cards.size() == 3 and ids.size() == {ids[0]: 0, ids[1]: 0, ids[2]: 0}.size(), "three different powerups (%s)" % [ids])
	check(get_tree().paused, "solo, picking pauses the game")
	run.pick(fish, 0)
	await _frames(2)
	check(run.powerups_of(fish).stacks(ids[0]) == 1 and not get_tree().paused, "picking one gives a stack, and play goes on")
	var second: TreasureChest = run.chests[1]
	offers.clear()
	fish.freeze = false
	var start := second.global_position + Vector3(0, 0.6, 10.0)
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), start))
	await _ticks(2)
	for t in 120:
		fish.linear_velocity = (second.global_position + Vector3.UP * 0.5 - fish.global_position).normalized() * (fish.nature_batter_speed + 4.0)
		await get_tree().physics_frame
		if second.is_open_for(fish):
			break
	check(second.is_open_for(fish) and offers.size() == 1, "battering one opens it at once")
	var same := -1
	for i in (offers[0][0] as Array).size():
		if offers[0][0][i].powerup == ids[0]:
			same = i
	if same >= 0:
		check(offers[0][0][same].stacks == 2, "the same powerup again is offered as stack 2")
		run.pick(fish, same)
		await _frames(2)
		check(run.powerups_of(fish).stacks(ids[0]) == 2, "and stacks")
	else:
		run.pick(fish, 0)
		await _frames(2)
	fish.linear_velocity = Vector3.ZERO
	main.reset_play()
	await _ticks(3)
	check(run.powerups_of(fish).list().is_empty() and run.shut_chests().size() == settings.chest_count, "R: powerups gone, chests buried again")

	print("chain lightning:")
	powers.lightning_stacks = 1
	powers.lightning_chance = 1.0
	await _ticks(2)
	var lightning: ChainLightning = run.powerups_of(fish).held["chain_lightning"]
	await _park(Vector3(0, 0, 60), Vector3.FORWARD)
	horde.clear()
	for n in 10:
		horde.spawn(1, Vector3(0, 0, 40 - n * 3.0))
	await _ticks(6)
	run.hit(horde.alive[0], 1.0, fish, "test")
	check(lightning.jumps_made == lightning.jumps(), "one hit, lightning jumps %d times (%d)" % [lightning.jumps(), lightning.jumps_made])
	var jumps_1 := lightning.jumps()
	var chance_1 := lightning.chance()
	powers.lightning_stacks = 3
	powers.lightning_chance = 0.15
	await _ticks(2)
	check(lightning.jumps() == jumps_1 + 2 * powers.lightning_jumps_per_stack and lightning.chance() > 0.15, "stacks add jumps and chance (%d jumps, %.0f%%)" % [lightning.jumps(), lightning.chance() * 100.0])
	powers.lightning_stacks = 0
	await _ticks(2)

	print("torpedoes:")
	powers.torpedo_stacks = 1
	await _ticks(2)
	var launcher: TorpedoLauncher = run.powerups_of(fish).held["torpedo"]
	horde.clear()
	var far := horde.spawn(2, fish.global_position + Vector3(6, 2, -15))
	await _ticks(4)
	var hp := horde.enemy_hp(far)
	launcher.launch([])
	for t in 240:
		await get_tree().physics_frame
		if launcher.blasts > 0:
			break
	check(launcher.fired == 1 and launcher.blasts == 1, "a torpedo is fired and blows up")
	check(horde.enemy_hp(far) < hp, "it sought out the boxfish 16 m off and hurt it (%.0f -> %.0f hp)" % [hp, horde.enemy_hp(far)])
	var count_1 := launcher.count()
	var blast_1 := launcher.blast()
	powers.torpedo_stacks = 3
	await _ticks(2)
	check(launcher.count() > count_1 and launcher.blast() > blast_1 and launcher.chance() > powers.torpedo_chance, "stacks: more torpedoes (%d), a bigger blast (%.1f m), more chance" % [launcher.count(), launcher.blast()])
	powers.torpedo_stacks = 0
	await _ticks(2)

	print("proc loops:")
	powers.lightning_stacks = 2
	powers.torpedo_stacks = 2
	powers.lightning_chance = 1.0
	powers.torpedo_chance = 1.0
	await _ticks(2)
	horde.clear()
	for n in 30:
		horde.spawn(2, fish.global_position + Vector3((n % 6) * 2.5 - 6.0, 0, -8.0 - (n / 6) * 2.5))
	await _ticks(4)
	var damage_before: float = run.stats_of(fish).damage
	run.hit(horde.alive[0], 1.0, fish, "test")
	for t in 360:
		await get_tree().physics_frame
	var by: Dictionary = run.stats_of(fish).by_source
	check(by.get("chain_lightning", 0.0) > 0.0 and by.get("torpedo", 0.0) > 0.0, "one hit at 100% chances sets off lightning and torpedoes")
	var torpedoes_flying := (run.powerups_of(fish).held["torpedo"] as TorpedoLauncher).in_flight()
	check(torpedoes_flying == 0, "and it all settles (no torpedoes still flying after 3 s)")
	check(run.stats_of(fish).damage - damage_before < 5000.0, "bounded: %.0f damage, not a runaway loop" % (run.stats_of(fish).damage - damage_before))
	powers.lightning_stacks = 0
	powers.torpedo_stacks = 0
	powers.lightning_chance = 0.15
	powers.torpedo_chance = 0.08
	await _ticks(2)

	print("greek fire:")
	powers.fire_stacks = 1
	horde.clear()
	await _ticks(2)
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), Vector3(0, 0, 60)))
	await _ticks(2)
	for n in 6:
		horde.spawn(1, Vector3(0, 0, 54.0 - n * 3.0))
	await _ticks(2)
	var swim_start: float = run.stats_of(fish).by_source.get("greek_fire", 0.0)
	for t in 120 * 3:
		fish.linear_velocity = Vector3.FORWARD * 6.0
		await get_tree().physics_frame
	fish.linear_velocity = Vector3.ZERO
	var fire := run.powerups_of(fish).weapon("attack_greek_fire") as GreekFire
	check(fire.patches.size() > 3, "swimming leaves a trail of fire (%d patches)" % fire.patches.size())
	var lit := fire.patches.duplicate()
	var burnt: float = run.stats_of(fish).by_source.get("greek_fire", 0.0) - swim_start
	check(burnt > 0.0, "zombies in it burn (%.0f damage)" % burnt)
	powers.fire_stacks = 0
	await _ticks(2)
	check(lit.all(func(patch: Variant) -> bool: return not is_instance_valid(patch)), "losing it puts the fires out")

	print("bow grow bow:")
	horde.clear()
	await _park(Vector3(0, 0, 60), Vector3.FORWARD)
	var bite := run.bite_of(fish)
	var reach_0 := bite.reach()
	var bow_0 := GhostBite.bow_reach(fish)
	powers.bow_stacks = 2
	await _ticks(2)
	check(is_equal_approx(fish.bow_scale, 1.0 + powers.bow_growth * 2.0), "the bow wave grows (x%.1f)" % fish.bow_scale)
	check(GhostBite.bow_reach(fish) > bow_0 * 1.5 and bite.reach() >= GhostBite.bow_reach(fish) * settings.bite_over_bow - 0.01,
			"the bite still out-reaches it (%.1f m > %.1f m)" % [bite.reach(), GhostBite.bow_reach(fish)])
	check(fish.find_child("Bow", false, false) != null, "the fish wears the bow")
	var wide_slow := await _ram_beside(30.0, 3.0)
	powers.bow_stacks = 0
	await _ticks(2)
	var narrow := await _ram_beside(30.0, 3.0)
	check(wide_slow and not narrow, "a boxfish 3 m beside the path is battered with the bow, not without (at 30 m/s)")
	powers.bow_stacks = powers.bow_low_speed_stacks
	await _ticks(2)
	var low := await _ram_beside(fish.nature_batter_speed * 0.75, 0.0)
	powers.bow_stacks = 0
	await _ticks(2)
	var low_without := await _ram_beside(fish.nature_batter_speed * 0.75, 0.0)
	check(low and not low_without, "at %d stacks it batters under the battering speed" % powers.bow_low_speed_stacks)
	check(is_equal_approx(fish.bow_scale, 1.0) and fish.find_child("Bow", false, false) == null and is_equal_approx(bite.reach(), reach_0), "without it: the bow off, all back")

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## Rams past a boxfish `side` m off the path at `speed`; returns whether it was battered.
func _ram_beside(speed: float, side: float) -> bool:
	horde.clear()
	fish.freeze = false
	var start := Vector3(0, 0, 60)
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), start))
	await _ticks(2)
	horde.spawn(2, start + Vector3(side, 0, -14))
	await _ticks(2)
	var before: float = run.stats_of(fish).by_source.get("battery", 0.0)
	for t in 120 * 2:
		fish.linear_velocity = Vector3.FORWARD * speed
		await get_tree().physics_frame
		if fish.global_position.z < start.z - 18.0:
			break
	fish.linear_velocity = Vector3.ZERO
	return run.stats_of(fish).by_source.get("battery", 0.0) > before


func _park(at: Vector3, facing: Vector3) -> void:
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(facing), at))
	await _ticks(2)
	fish.freeze = true


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
