extends Node
## Unnatural's levels (planning_unnatural.md §6, phase 3): the XP curve;
## rarity rolls over 10,000 match the weights, and luck shifts them up as the
## formula says; in the real game a level-up pauses a solo run and offers
## three cards, each a different weapon or tome (CardDeck; slots_probe has
## the pools), picked with the controls; the pick does what it says, the
## stats do what they say (damage, attack speed, size, swim speed, armour,
## max hp), each level gives the fish's signature stat,
## several levels at once queue their picks, and leaving the mode puts the
## fish's swimming back.
##   Godot_console.exe --headless --path . res://tests/levels_probe.tscn

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

	print("xp curve:")
	var levels := Levels.new(settings)
	var curve_ok := true
	for n in [1, 2, 5, 10, 20]:
		curve_ok = curve_ok and is_equal_approx(levels.xp_to_next(n), ceilf(settings.xp_base * pow(float(n), settings.xp_curve)))
	check(curve_ok, "xp to next = xp_base * level ^ xp_curve (rounded up)")
	check(levels.xp_to_next(10) > levels.xp_to_next(5) * 2.0, "it climbs steeply (%.0f at 5, %.0f at 10)" % [levels.xp_to_next(5), levels.xp_to_next(10)])

	print("rarity:")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var base := Rarity.weights(settings, 0.0)
	var counts := _roll(rng, settings, 0.0)
	var matches := true
	for tier in 5:
		matches = matches and absf(counts[tier] / 10000.0 - base[tier]) < 0.012
	check(matches, "10,000 rolls at luck 0 match 60/25/10/4/1 (%s)" % [counts])
	var lucky := Rarity.weights(settings, 0.5)
	var lucky_counts := _roll(rng, settings, 0.5)
	matches = true
	for tier in 5:
		matches = matches and absf(lucky_counts[tier] / 10000.0 - lucky[tier]) < 0.012
	check(matches, "at luck 0.5 they match the formula (%s)" % [lucky_counts])
	var epic_lift := (lucky[3] / lucky[0]) / (base[3] / base[0])
	var legendary_lift := (lucky[4] / lucky[0]) / (base[4] / base[0])
	check(absf(epic_lift - pow(1.5, 3)) < 0.01 and absf(legendary_lift - pow(1.5, 4)) < 0.01,
			"luck 0.5 against common: epic x%.1f, legendary x%.1f ((1 + luck) ^ tier)" % [epic_lift, legendary_lift])
	check(is_equal_approx(StatBlock.amount("damage", Rarity.multiplier(settings, Rarity.Tier.LEGENDARY)), 0.5), "a legendary Damage card is 5 steps (+50%)")

	print("in the game:")
	settings.spawning = false
	settings.fish_attack = FishAttack.Kind.BITE  # these checks are the bite's (attack_probe has the rest)
	settings.twists = false  # and no fish's twist skews them
	settings.enemy_speed_scale = 0.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	fish.character = FishCharacter.Family.DOMINUS
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	var offers := []
	run.cards_offered.connect(func(f: FishController, cards: Array, heading: String, line: String) -> void: offers.append([cards, heading, line]))
	var block := run.block_of(fish)
	var bite := run.bite_of(fish)
	var reach_before := bite.reach()
	run.levels.add(run.levels.xp_to_next())
	await _ticks(2)
	check(run.levels.level == 2 and offers.size() == 1, "a level-up offers cards")
	check(get_tree().paused, "solo, the game pauses while they're up")
	var cards: Array = offers[0][0]
	var targets := cards.map(func(c: Dictionary) -> String: return "%s:%s" % [c.kind, c.get("weapon", c.get("tome", ""))])
	var distinct := {}
	for t: String in targets:
		distinct[t] = true
	check(cards.size() == 3 and distinct.size() == 3, "three cards, each a different weapon or tome (%s)" % [targets])
	check(offers[0][2].contains("WEAPONS 1/2") and offers[0][2].contains("TOMES 0/2"), "the line under says the slots (%s)" % offers[0][2])
	check(is_equal_approx(block.value("damage"), StatBlock.amount("damage")), "the Shark's signature: +1 step of Damage (%.2f)" % block.value("damage"))
	check(run.is_picking(fish) and not run.horde.chaseable.is_empty() and run.horde.chaseable[0] == 0, "the picker can't be chased")
	var hud: UnnaturalHud = main._unnatural_hud
	check(hud._cards.is_open(), "the cards show on the player's HUD")
	# Pick with the controls: right once, then A.
	await _wait(LevelUpCards.ARM_TIME + 0.1)
	Input.action_press("stick_right")
	Input.flush_buffered_events()
	await _frames(3)
	Input.action_release("stick_right")
	Input.flush_buffered_events()
	await _frames(2)
	check(hud._cards.selected == 1, "the stick moves the choice")
	var chosen: Dictionary = cards[1]
	var loadout := run.loadout_of(fish)
	var before := _state(run, fish, chosen)
	Input.action_press("ui_accept")
	Input.flush_buffered_events()
	await _frames(3)
	Input.action_release("ui_accept")
	Input.flush_buffered_events()
	await _frames(2)
	check(not run.is_picking(fish) and not get_tree().paused, "A picks it and the game goes on")
	check(_took(run, fish, chosen, before), "the %s card did what it said (%s)" % [chosen.kind, chosen])
	check(loadout.weapons[0] == Weapons.ATTACK, "the fish's own attack is the first weapon")

	print("what stats do:")
	block.add("attack_speed", 0.5)
	block.add("size", 0.5)
	block.add("swim_speed", 0.2)
	block.add("max_hp", 25.0)
	run._apply_stats(fish)
	check(is_equal_approx(bite.attack_speed, 1.0 + block.value("attack_speed")), "attack speed speeds up the bite")
	check(bite.reach() > reach_before * 1.4, "size grows the jaws (%.1f -> %.1f m)" % [reach_before, bite.reach()])
	check(is_equal_approx(fish.speed_scale, 1.0 + block.value("swim_speed")), "swim speed scales the fish's swimming")
	check(is_equal_approx(run.health_of(fish).max_hp, run.max_hp() + block.value("max_hp")), "max hp cards add to max hp")
	var health := run.health_of(fish)
	health.reset(health.max_hp)
	block.add("armour", 4.0 - block.value("armour"))
	run.hurt(fish, 10.0)
	check(is_equal_approx(health.hp, health.max_hp - 6.0), "armour 4 takes 4 off a hit of 10")
	health.reset(health.max_hp)
	run.hurt(fish, 3.0)
	check(is_equal_approx(health.hp, health.max_hp - 1.0), "but a hit always does at least 1")
	var target := run.horde.spawn(1, Vector3(0, 0, -200))
	var damage_before: float = run.stats_of(fish).damage
	block.values["crit_chance"] = 0.0
	run.hit(target, 10.0, fish, "test")
	var dealt: float = run.stats_of(fish).damage - damage_before
	check(is_equal_approx(dealt, 10.0 * (1.0 + block.value("damage"))), "damage scales every hit (10 -> %.1f)" % dealt)
	run.horde.remove(target)

	print("several levels at once:")
	offers.clear()
	run.levels.add(run.levels.xp_to_next() + run.levels.xp_to_next(run.levels.level + 1) + 0.5)
	await _ticks(2)
	check(offers.size() == 1 and run._pending.get(fish, 0) == 2, "two levels: one pick up, another waiting")
	run.pick(fish, 0)
	await _frames(2)
	check(offers.size() == 2 and run.is_picking(fish) and get_tree().paused, "after the first pick, the second comes")
	check(offers[1][1] == "LEVEL %d" % run.levels.level, "for the later level (%s)" % offers[1][1])
	run.pick(fish, 2)
	await _frames(2)
	check(not run.is_picking(fish) and not get_tree().paused, "then play goes on")

	print("no cards:")
	settings.card_choices = 0
	offers.clear()
	run.levels.add(run.levels.xp_to_next())
	await _ticks(2)
	check(offers.is_empty() and not get_tree().paused, "card_choices 0: no cards, no pause")
	settings.card_choices = 3

	print("restart and leaving:")
	main.reset_play()
	await _ticks(3)
	check(block.value("damage") == 0.0 and is_equal_approx(fish.speed_scale, 1.0) and run.levels.level == 1, "a restart clears the stats")
	block.add("swim_speed", 0.3)
	run._apply_stats(fish)
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	check(is_equal_approx(fish.speed_scale, 1.0) and is_equal_approx(fish.stride_scale, 1.0), "leaving the mode puts the fish's swimming back")

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## What `card` would change, before it's taken.
func _state(run: UnnaturalRun, who: FishController, card: Dictionary) -> Dictionary:
	var loadout := run.loadout_of(who)
	var stats := {}
	for stat: String in StatBlock.STATS:
		stats[stat] = run.block_of(who).value(stat)
	return {"level": loadout.earned_level(card.get("weapon", "")), "tome": loadout.tome_level(card.get("tome", "")), "stats": stats,
			"purse": run.purse_of(who)}


## Whether `card` was taken: its weapon or tome a level up (its stats on the
## block), or its fallback paid out.
func _took(run: UnnaturalRun, who: FishController, card: Dictionary, before: Dictionary) -> bool:
	var loadout := run.loadout_of(who)
	match card.kind:
		"weapon", "new_weapon":
			return loadout.earned_level(card.weapon) == before.level + 1
		"tome", "new_tome":
			var ok: bool = loadout.tome_level(card.tome) == before.tome + 1
			for stat: String in card.gives:
				ok = ok and is_equal_approx(run.block_of(who).value(stat), before.stats[stat] + card.gives[stat])
			return ok
		"fallback":
			return card.what != "pearls" or run.purse_of(who) == before.purse + card.amount
	return false


func _roll(rng: RandomNumberGenerator, settings: UnnaturalSettings, luck: float) -> Array:
	var counts := [0, 0, 0, 0, 0]
	for n in 10000:
		counts[Rarity.roll(rng, settings, luck)] += 1
	return counts


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
