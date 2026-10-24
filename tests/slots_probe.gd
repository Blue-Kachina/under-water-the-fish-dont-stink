extends Node
## Unnatural's weapons and tomes (planning_unnatural.md, Playability pass P1):
## the level-up cards' pools follow the slots (new weapons and tomes only while
## a slot is free; capped ones gone; fallback cards when nothing's left);
## facet rolls match the rarity table over 10,000 rolls; tome cards add their
## StatBlock steps; milestones switch on at Lv 5, 10, 15 and 20 (on chest weapons and
## the fish's attack); chests offer items only; a boss weapon with full slots
## asks which weapon to swap; level overrides lift a weapon for testing.
##   Godot_console.exe --headless --path . res://tests/slots_probe.tscn

var failures := 0
var main: Node
var fish: FishController


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the cards pause the game
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	var powers := PowerupSettings.shared()

	print("facet rolls:")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var table_ok := true
	var sizes_ok := true
	for tier in 5:
		for n in 2000:
			var gains := Weapons.roll(rng, "attack_greek_fire", FishAttack.Kind.BITE, tier, settings, powers)
			table_ok = table_ok and gains.size() == settings.facets_for(tier)
			for facet: String in gains:
				var entry := Weapons.facet_def("attack_greek_fire", facet)
				sizes_ok = sizes_ok and is_equal_approx(gains[facet], Weapons.step_amount(entry, settings.facet_size_for(tier), powers))
	check(table_ok, "10,000 rolls: each rarity raises its number of facets (1, 1, 2, 2, 3), all different")
	check(sizes_ok, "each by its rarity's size of a step (x1, x1.5, x1.5, x2, x2.5)")
	var count_entry := Weapons.facet_def("attack_jellyfish_halo", "count")
	check(Weapons.step_amount(count_entry, 1.5, powers) == 2.0 and Weapons.step_amount(count_entry, 1.0, powers) == 1.0,
			"a count facet stays whole (x1: +1 jelly, x1.5: +2)")

	print("chests:")
	var weapon_from_chest := false
	for n in 3000:
		for id in Powerup.pick_for_chest(rng, rng.randi_range(0, Rarity.Tier.LEGENDARY), 3):
			weapon_from_chest = weapon_from_chest or Powerup.is_weapon(id)
	check(not weapon_from_chest, "3,000 chests never offer a weapon")

	print("in the game:")
	settings.spawning = false
	settings.fish_attack = FishAttack.Kind.BITE
	settings.twists = false
	settings.enemy_speed_scale = 0.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	fish.character = FishCharacter.FishClass.HUNTER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	var loadout := run.loadout_of(fish)
	check(loadout.weapons == ([Weapons.ATTACK] as Array[String]) and loadout.tomes.is_empty(), "a run starts with the fish's attack alone")

	var kinds := _kinds_over(run, 300)
	check(kinds.has("new_weapon") and kinds.has("new_tome") and kinds.has("weapon"), "with slots free: new weapons, new tomes, attack upgrades (%s)" % [kinds.keys()])
	check(not kinds.has("tome"), "no tome upgrades before a tome is held")

	# Fill the slots: one more weapon, two tomes.
	run.take_card(fish, {"kind": "new_weapon", "weapon": "attack_greek_fire", "tier": 0, "level": 1, "gains": {}})
	var block := run.block_of(fish)
	var damage_before := block.value("damage")
	var teeth := Tomes.gives("teeth", Rarity.multiplier(settings, Rarity.Tier.RARE), settings)
	run.take_card(fish, {"kind": "new_tome", "tome": "teeth", "tier": Rarity.Tier.RARE, "level": 1, "gives": teeth})
	check(is_equal_approx(block.value("damage"), damage_before + StatBlock.amount("damage", Rarity.multiplier(settings, Rarity.Tier.RARE))),
			"a rare Tome of Teeth adds 2 steps of Damage (%.2f)" % (block.value("damage") - damage_before))
	var shell := Tomes.gives("shell", 1.0, settings)
	run.take_card(fish, {"kind": "new_tome", "tome": "shell", "tier": 0, "level": 1, "gives": shell})
	check(shell.size() == 3 and is_equal_approx(shell.armour, StatBlock.amount("armour", settings.tome_multi_share)),
			"a three-stat tome gives each tome_multi_share of a step (%s)" % [shell])
	check(run.powerups_of(fish).stacks("attack_greek_fire") == 1, "a new weapon is held at Lv 1 (as a powerup)")
	kinds = _kinds_over(run, 300)
	check(not kinds.has("new_weapon") and not kinds.has("new_tome"), "slots full: only upgrades (%s)" % [kinds.keys()])
	check(kinds.has("weapon") and kinds.has("tome"), "weapon and tome upgrades both come")

	print("caps and fallbacks:")
	loadout._levels["attack_greek_fire"] = settings.weapon_max_level
	var offered_capped := false
	for n in 200:
		for card: Dictionary in CardDeck.deal(run, fish, 3):
			offered_capped = offered_capped or card.get("weapon", "") == "attack_greek_fire"
	check(not offered_capped, "a weapon at weapon_max_level isn't offered")
	loadout._levels[Weapons.ATTACK] = settings.weapon_max_level
	loadout._tome_levels["teeth"] = settings.tome_max_level
	loadout._tome_levels["shell"] = settings.tome_max_level
	var cards := CardDeck.deal(run, fish, 3)
	check(cards.size() == 2 and cards.all(func(c: Dictionary) -> bool: return c.kind == "fallback"),
			"everything capped: the fallback cards (%s)" % [cards.map(func(c: Dictionary) -> String: return c.get("what", c.kind))])
	var purse := run.purse_of(fish)
	run.take_card(fish, cards[0])
	check(run.purse_of(fish) == purse + cards[0].amount, "the pearl purse pays out (+%d)" % cards[0].amount)

	print("upgrades and milestones:")
	loadout._levels["attack_greek_fire"] = 3
	var fire := run.powerups_of(fish).weapon("attack_greek_fire") as GreekFire
	var life_before := fire.life()
	run.take_card(fish, {"kind": "weapon", "weapon": "attack_greek_fire", "tier": 0, "level": 4, "gains": {"life": 1.0}})
	check(loadout.earned_level("attack_greek_fire") == 4 and is_equal_approx(fire.life(), life_before + 1.0), "an upgrade raises its level and its facet")
	check(not fire.milestone(1), "no milestone at Lv 4")
	run.take_card(fish, {"kind": "weapon", "weapon": "attack_greek_fire", "tier": 0, "level": 5, "gains": {"burn": 0.25}})
	run.powerups_of(fish).refresh()
	check(fire.level == 5 and fire.milestone(1) and not fire.milestone(2), "the first milestone at Lv 5")
	loadout._levels["attack_greek_fire"] = 10
	run.powerups_of(fish).refresh()
	check(fire.milestone(2), "the second at Lv 10")
	loadout._levels["attack_greek_fire"] = 15
	run.powerups_of(fish).refresh()
	check(fire.milestone(3) and not fire.milestone(4), "the third at Lv 15")
	loadout._levels["attack_greek_fire"] = 20
	run.powerups_of(fish).refresh()
	check(fire.milestone(4), "the fourth at Lv 20")
	loadout._levels["attack_greek_fire"] = 10
	run.powerups_of(fish).refresh()
	var lined := true
	for key: Variant in Weapons.MILESTONES:
		lined = lined and (Weapons.MILESTONES[key] as Array).size() == 4
	check(lined, "every weapon has four milestone lines")
	var bite := run.bite_of(fish)
	loadout._levels[Weapons.ATTACK] = 15
	run._apply_stats(fish)
	check(bite.milestones == 3, "the bite's third at Lv 15")
	loadout._levels[Weapons.ATTACK] = 20
	run._apply_stats(fish)
	check(bite.milestones == 4, "the bite's fourth at Lv 20")
	loadout._levels[Weapons.ATTACK] = 4
	run._apply_stats(fish)
	check(bite.milestones == 0, "the bite: none at Lv 4")
	loadout._levels[Weapons.ATTACK] = 5
	run._apply_stats(fish)
	check(bite.milestones == 1, "the bite's first at Lv 5")
	var damage_scale := bite.damage_scale
	loadout.upgrade_weapon(Weapons.ATTACK, {"damage": 0.2})
	run._apply_stats(fish)
	check(is_equal_approx(bite.damage_scale, damage_scale + 0.2), "the attack's damage facet scales its hits (%.2f -> %.2f)" % [damage_scale, bite.damage_scale])

	print("boss weapons:")
	var offers := []
	run.cards_offered.connect(func(_f: FishController, offer: Array, _h: String, _l: String) -> void: offers.append(offer))
	run._offers[fish] = [{"powerup": "attack_leviathans_coil", "stacks": 1, "tier": Rarity.Tier.BOSS}]
	run._offer_kind[fish] = "chest"
	run.pick(fish, 0)
	await _frames(1)
	check(not offers.is_empty() and offers[-1].any(func(c: Dictionary) -> bool: return c.kind == "swap" and c.weapon == "attack_greek_fire"),
			"slots full: the Coil asks which weapon to swap")
	check(offers[-1].any(func(c: Dictionary) -> bool: return c.kind == "keep"), "or to keep yours")
	run.pick(fish, 0)
	await _frames(1)
	check(loadout.has_weapon("attack_leviathans_coil") and not loadout.has_weapon("attack_greek_fire"), "the swap replaces Greek Fire")
	check(loadout.earned_level("attack_leviathans_coil") == powers.coil_arrive_level, "the Coil arrives at Lv %d" % powers.coil_arrive_level)
	check(not run.powerups_of(fish).held.has("attack_greek_fire") and run.powerups_of(fish).held.has("attack_leviathans_coil"), "and the powerups follow")

	print("testing overrides:")
	powers.jelly_stacks = 4
	run.powerups_of(fish).refresh()
	var halo := run.powerups_of(fish).weapon("attack_jellyfish_halo") as JellyfishHalo
	check(halo != null and halo.level == 4, "a level override puts a weapon on at that level, slots or not")
	var spread := 0.0
	for facet: String in loadout.facets_of("attack_jellyfish_halo"):
		spread += 1.0 if loadout.facet("attack_jellyfish_halo", facet) > 0.0 else 0.0
	check(spread == 3.0, "its 3 upgrades spread over 3 facets")
	powers.jelly_stacks = 0
	run.powerups_of(fish).refresh()
	check(not run.powerups_of(fish).held.has("attack_jellyfish_halo"), "and it's gone when the override is")

	print("restart:")
	main.reset_play()
	await _ticks(3)
	check(loadout.weapons == ([Weapons.ATTACK] as Array[String]) and loadout.tomes.is_empty() and run.purse_of(fish) == 0,
			"a restart clears the slots and the purse")

	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## Which card kinds `deals` deals of 3 cards turned up.
func _kinds_over(run: UnnaturalRun, deals: int) -> Dictionary:
	var kinds := {}
	for n in deals:
		for card: Dictionary in CardDeck.deal(run, fish, 3):
			kinds[card.kind] = true
	return kinds


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
