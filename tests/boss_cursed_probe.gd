extends Node
## Unnatural's Boss and Cursed powerups (planning_unnatural.md §7b, D13):
## buried chests may be cursed (blood red) and offer only cursed powerups; the
## Drowned Shark drops a boss chest offering its Drowned Fin; each curse's
## upside and catch (Blood Moon Shard, Glass Coral, Siren's Song, Abyssal
## Hunger, Sunken Idol's extra pick and its toll); Drowned Fin's dash;
## Leviathan's Coil's trail.
##   Godot_console.exe --headless --path . res://tests/boss_cursed_probe.tscn

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
	settings.stage_events = false
	settings.chest_count = 4
	settings.chest_interval = 0.0
	settings.cursed_chest_chance = 1.0
	settings.fish_attack = FishAttack.Kind.BITE
	settings.twists = false
	settings.card_choices = 0
	settings.enemy_speed_scale = 0.0
	settings.bite_damage = 0.0
	settings.enemy_damage_scale = 0.0
	settings.difficulty_per_minute = 0.0
	settings.heart_chance = 0.0
	settings.magnet_chance = 0.0
	settings.hourglass_chance = 0.0
	settings.chest_drop_chance = 0.0
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde
	var offers := []
	run.cards_offered.connect(func(_f: FishController, cards: Array, heading: String, _line: String) -> void: offers.append([cards, heading]))
	await _park(Vector3(0, 0, 60), Vector3.FORWARD)

	print("cursed chests:")
	var all_cursed := run.chests.size() == 4
	for chest in run.chests:
		all_cursed = all_cursed and chest.kind == TreasureChest.Kind.CURSED and chest.tint() == TreasureChest.BLOOD
	check(all_cursed, "at cursed_chest_chance 1, every buried chest is cursed, and blood red")
	run.open_chest(run.chests[0], fish)
	await _frames(2)
	var cards: Array = offers[-1][0] if not offers.is_empty() else []
	var only_cursed := cards.size() == settings.chest_choices
	for card: Dictionary in cards:
		only_cursed = only_cursed and Powerup.tier(card.powerup) == Rarity.Tier.CURSED
	check(only_cursed and offers[-1][1] == "CURSED TREASURE", "opening one offers cursed powerups alone (%s)" % [cards.map(func(c: Dictionary) -> String: return c.powerup)])
	run.pick(fish, 0)
	await _frames(2)
	check(run.powerups_of(fish).list().size() == 1 and Powerup.tier(run.powerups_of(fish).list()[0][0]) == Rarity.Tier.CURSED, "and picking one gives it")
	main.reset_play()
	await _ticks(3)
	settings.cursed_chest_chance = 0.0
	main.reset_play()
	await _ticks(3)
	var none_cursed := true
	for chest in run.chests:
		none_cursed = none_cursed and chest.kind == TreasureChest.Kind.TREASURE
	check(none_cursed, "at 0, none is")

	print("boss chest:")
	offers.clear()
	var shark := DrownedShark.new()
	run._add_boss(shark, fish.global_position + Vector3(0, 0, -12), 10.0)
	await _ticks(4)
	shark.take(1000.0, fish, "probe")
	await _seconds(2.0)
	var boss_chest: TreasureChest = null
	for chest in run.chests:
		if is_instance_valid(chest) and chest.kind == TreasureChest.Kind.BOSS:
			boss_chest = chest
	check(boss_chest != null and boss_chest.item == "" and boss_chest.tint() == TreasureChest.STEEL,
			"the Drowned Shark beaten drops a steel-blue boss chest")
	if boss_chest:
		run.open_chest(boss_chest, fish)
		await _frames(2)
		var boss_cards: Array = offers[-1][0] if not offers.is_empty() else []
		check(boss_cards.size() >= 1 and Powerup.tier(boss_cards[0].powerup) == Rarity.Tier.LEGENDARY and offers[-1][1] == "BOSS TREASURE!", "opening it offers a legendary pick")
		run.pick(fish, 0)
		await _frames(2)
		check(run.powerups_of(fish).stacks(boss_cards[0].powerup) == 1, "and it's yours")
	main.reset_play()
	await _ticks(3)
	await _park(Vector3(0, 0, 60), Vector3.FORWARD)

	print("blood moon shard:")
	var block := run.block_of(fish)
	var health := run.health_of(fish)
	var damage_0 := block.value("damage")
	powers.shard_stacks = 1
	await _ticks(2)
	check(is_equal_approx(block.value("damage"), damage_0 + powers.shard_damage), "+%.0f%% damage" % (powers.shard_damage * 100.0))
	health.hp = health.max_hp
	health.iframes_left = 0.0
	run.hurt(fish, 20.0)
	check(is_equal_approx(health.max_hp - health.hp, 20.0 * (1.0 + powers.shard_taken) - block.value("armour")),
			"and a 20 hit takes %.0f" % (health.max_hp - health.hp))
	powers.shard_stacks = 0
	await _ticks(2)
	health.hp = health.max_hp

	print("glass coral:")
	var hp_0 := health.max_hp
	powers.coral_stacks = 1
	await _ticks(2)
	check(is_equal_approx(block.value("damage"), damage_0 + powers.coral_damage) and is_equal_approx(health.max_hp, hp_0 * powers.coral_hp),
			"+100%% damage, max hp %.0f -> %.0f" % [hp_0, health.max_hp])
	powers.coral_stacks = 0
	await _ticks(2)
	check(is_equal_approx(health.max_hp, hp_0), "without it, max hp's back")
	health.hp = health.max_hp

	print("siren's song:")
	var xp_0 := block.value("xp_gain")
	powers.siren_stacks = 1
	await _ticks(2)
	check(is_equal_approx(block.value("xp_gain"), xp_0 + powers.siren_xp) and is_equal_approx(run.horde_scale(), 1.0 + powers.siren_horde),
			"double XP, and the director calls x%.1f the zombies" % run.horde_scale())
	settings.stage_events = false
	await _ticks(2)
	check(is_equal_approx(run.director.escalation, 1.0 + powers.siren_horde), "the director's target escalates with it")
	powers.siren_stacks = 0
	await _ticks(2)

	print("abyssal hunger:")
	powers.hunger_stacks = 1
	await _ticks(2)
	health.hp = health.max_hp
	await _seconds(1.0)
	var drained := health.max_hp - health.hp
	check(absf(drained - health.max_hp * powers.hunger_drain) < health.max_hp * 0.005, "it drains %.1f hp a second" % drained)
	health.hp = health.max_hp * 0.5
	var before := health.hp
	var victim := horde.spawn(1, fish.global_position + Vector3(0, 0, -6))
	await _ticks(2)
	run.hit(victim, 1e6, fish, "probe")
	check(health.hp - before >= health.max_hp * powers.hunger_heal - 0.5, "a kill heals %.1f" % (health.hp - before))
	health.hp = 1.0
	await _seconds(0.5)
	check(health.hp >= 1.0 and not health.down, "the drain stops at 1 hp (hunger_can_kill off)")
	powers.hunger_stacks = 0
	await _ticks(2)
	health.hp = health.max_hp

	print("sunken idol:")
	powers.idol_stacks = 1
	await _ticks(2)
	offers.clear()
	var chest := run.add_chest(fish.global_position + Vector3(0, -1, -3), 0.0)
	run.open_chest(chest, fish)
	await _frames(2)
	var first: Array = offers[-1][0] if not offers.is_empty() else []
	var first_pick: String = first[0].powerup if not first.is_empty() else ""
	run.pick(fish, 0)
	await _frames(2)
	var second: Array = offers[-1][0] if offers.size() >= 2 else []
	check(offers.size() == 2 and second.size() == first.size() - 1 and second.all(func(c: Dictionary) -> bool: return c.powerup != first_pick),
			"one chest, a second pick from what's left")
	var second_pick: String = second[0].powerup if not second.is_empty() else ""
	run.pick(fish, 0)
	await _frames(2)
	var powerups := run.powerups_of(fish)
	check(powerups.stacks(first_pick) == 1 and powerups.stacks(second_pick) == 1 and run.offer_of(fish).is_empty(), "both are yours, and play goes on")
	var lost := []
	run.powerup_lost.connect(func(_f: FishController, id: String) -> void: lost.append(id))
	run._start_event("ring")
	await _ticks(2)
	check(lost.size() == 1 and lost[0] in [first_pick, second_pick] and powerups.stacks(lost[0]) == 0,
			"a stage event: the idol takes one of them (%s)" % [lost])
	check(powerups.stacks("sunken_idol") == 1, "never itself")
	powers.idol_stacks = 0
	main.reset_play()
	await _ticks(3)


	print("leviathan's coil:")
	powers.coil_stacks = 1
	horde.clear()
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), Vector3(0, 0, 60)))
	await _ticks(2)
	var coil := run.powerups_of(fish).weapon("attack_leviathans_coil") as LeviathansCoil
	for t in 240:
		fish.linear_velocity = Vector3.FORWARD * 8.0
		await get_tree().physics_frame
	check(coil.trail.size() == coil.count() + 1, "%d coils trail the fish" % (coil.trail.size() - 1))
	var spaced := true
	for k in range(1, coil.trail.size()):
		spaced = spaced and absf(coil.trail[k - 1].distance_to(coil.trail[k]) - powers.coil_spacing) < 0.25
	check(spaced, "coil_spacing apart")
	fish.linear_velocity = Vector3.ZERO
	fish.freeze = true
	horde.spawn(1, coil.trail[3])
	await _seconds(1.0)
	check(coil.hits > 0 and run.stats_of(fish).by_source.get("leviathans_coil", 0.0) > 0.0, "and hurt what they touch (%d hits)" % coil.hits)
	powers.coil_stacks = 0
	await _ticks(2)
	check(run.find_child("Coils", false, false) == null, "without it, the coils go")

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


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


func _seconds(s: float) -> void:
	await _ticks(roundi(s * 120.0))
