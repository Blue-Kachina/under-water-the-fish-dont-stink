extends Node
## Unnatural's limiters (planning_unnatural.md, Playability pass P4): stacking
## curves flatten later stacks and switch off with `limits`; chances never pass
## their caps; the cooldown floor and Size's soft cap hold; caps show on the
## cards; Greek Fire's burn has no proc; chests get rarer as the stage goes on;
## weapon cards fade as weapons level; rerolls, skips and banishes start at 0,
## and given some they work (a banished weapon, tome or item never shows again).
##   Godot_console.exe --headless --path . res://tests/limits_probe.tscn

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var powers := PowerupSettings.shared()
var run: UnnaturalRun
var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the cards pause the game
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	print("curves:")
	check(is_equal_approx(Limits.stack_value(1, 0.67), 1.0), "the first stack counts in full")
	var second := Limits.stack_value(2, 0.67) - 1.0
	var third := Limits.stack_value(3, 0.67) - Limits.stack_value(2, 0.67)
	check(absf(second - 0.6) < 0.01 and absf(third - 0.43) < 0.01, "later ones add less: %.2f, %.2f" % [second, third])
	check(is_equal_approx(Limits.stack_value(5, 0.0), 5.0), "falloff 0 is a straight line")
	var capped := true
	for k in 200:
		var raw := k * 0.05
		var bent := Limits.chance(raw, 2.0)
		capped = capped and bent < 1.0 and bent <= raw + 0.0001
	check(capped, "a chance never reaches 100% (raw up to 1000%)")
	check(absf(Limits.chance(0.05, 2.0) - 0.05) < 0.001, "a small chance stays as it is")
	check(is_equal_approx(Limits.soft_cap(3.0, 1.0, 0.5), 2.0) and is_equal_approx(Limits.soft_cap(0.5, 1.0, 0.5), 0.5), "Size past +100% grows at half rate")

	settings.card_choices = 3
	settings.chest_count = 0
	settings.spawning = false
	settings.stage_events = false
	settings.twists = false
	settings.base_hp = 100000.0
	settings.shrine_count = 0
	fish.character = FishCharacter.Family.DOMINUS
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run

	print("items:")
	var salt := Powerup.create("sea_salt")
	salt.run = run
	salt.fish = fish
	salt.settings = powers
	salt.stacks = 10
	var with_curve: float = salt.stat_bonus().crit_chance
	settings.limits = false
	var straight: float = salt.stat_bonus().crit_chance
	settings.limits = true
	check(with_curve < straight and is_equal_approx(straight, powers.salt_crit * 10), "Sea Salt x10: %.2f with the curve, %.2f without" % [with_curve, straight])
	var torpedo := Powerup.create("torpedo") as TorpedoLauncher
	torpedo.run = run
	torpedo.fish = fish
	torpedo.settings = powers
	torpedo.stacks = 20
	check(torpedo.chance() < 1.0, "a 20-stack launcher's chance stays under 100%% (%.2f)" % torpedo.chance())
	var shard := Powerup.create("blood_moon_shard")
	shard.run = run
	shard.fish = fish
	shard.settings = powers
	shard.stacks = 3
	check(is_equal_approx(shard.eff(), 3.0), "cursed items stay in a line")
	run.block_of(fish).add("crit_chance", 2.0)
	check(run.block_of(fish).value("crit_chance") < 1.0 and run.block_of(fish).raw("crit_chance") >= 2.0, "Crit Chance +200%% plays as %.2f" % run.block_of(fish).value("crit_chance"))
	run.block_of(fish).add("size", 3.0)
	check(is_equal_approx(run.block_of(fish).value("size"), 2.0), "Size +300%% plays as +%d%%" % roundi(run.block_of(fish).value("size") * 100.0))
	check(Powerup.blurb_lines("torpedo")[-1].begins_with("At most"), "the launcher's card shows its cap")
	check(powers.fire_proc == 0.0, "Greek Fire's burn has no proc")

	print("cooldown floor:")
	settings.enemy_hp_scale = 100000.0  # dummies the bite can't kill
	for n in 4:
		run.horde.spawn(0, fish.global_position - fish.global_basis.z * (3.0 + n), fish.global_basis.z)
	await _ticks(4)
	var attack := run.attack_of(fish)
	attack.attack_speed = 100.0
	attack.cooldown_left = 0.0
	var fired_at := []
	attack.fired.connect(func() -> void: fired_at.append(Time.get_ticks_msec()))
	for n in 120:
		attack.update(1.0 / 120.0, true)
	check(fired_at.size() <= ceili(1.0 / settings.min_cooldown) + 1, "x100 attack speed fires at most every min_cooldown (%d in 1 s)" % fired_at.size())

	print("chests and cards:")
	settings.chest_drop_chance = 1.0
	settings.elite_chest_scale = 1.0
	run.elapsed = 0.0
	run.stage_started = 0.0
	var early := 0
	for n in 2000:
		early += 1 if run._rolls_chest(fish, false) else 0
	settings.chest_drop_chance = 0.5
	early = 0
	for n in 4000:
		early += 1 if run._rolls_chest(fish, false) else 0
	run.elapsed = 600.0
	var late := 0
	for n in 4000:
		late += 1 if run._rolls_chest(fish, false) else 0
	check(late < early * 0.75, "chests drop rarer at 10 min (%d vs %d)" % [late, early])
	run.elapsed = 0.0
	var loadout := run.loadout_of(fish)
	check(is_equal_approx(CardDeck.weapon_fade(run, fish), 1.0), "Lv 1 weapons: no fade")
	for n in 9:
		loadout.upgrade_weapon(Weapons.ATTACK, {})
	check(CardDeck.weapon_fade(run, fish) > 1.3, "Lv 10 weapon: upgrade cards fade (x1/%.2f)" % CardDeck.weapon_fade(run, fish))

	print("choices:")
	check(run.choices_of(fish, "rerolls") == 0 and run.choices_of(fish, "skips") == 0 and run.choices_of(fish, "banishes") == 0,
			"rerolls, skips and banishes start at 0")
	run.levels.add(run.levels.xp_to_next())
	await _ticks(2)
	check(not run.offer_of(fish).is_empty() and not run.can_choose(fish, "rerolls"), "a level's cards up; no reroll with none")
	run.add_choices(fish, "rerolls", 1)
	run.add_choices(fish, "skips", 1)
	run.add_choices(fish, "banishes", 3)
	var before: Array = run.offer_of(fish).duplicate(true)
	run.reroll(fish)
	check(run.choices_of(fish, "rerolls") == 0 and run.offer_of(fish).size() == before.size(), "a reroll deals again and spends one")
	var card: Dictionary = run.offer_of(fish)[0]
	var id := UnnaturalRun._card_id(card)
	run.banish(fish, 0)
	check(id in run.banished_of(fish) and run.choices_of(fish, "banishes") == 2, "banished %s" % id)
	var shows := false
	for n in 30:
		for other: Dictionary in CardDeck.deal(run, fish, 3):
			shows = shows or UnnaturalRun._card_id(other) == id
	check(not shows, "a banished one never comes up again (30 deals)")
	var level_before := run.loadout_of(fish).weapons.size() + run.loadout_of(fish).tomes.size()
	run.skip(fish)
	await _ticks(2)
	check(run.offer_of(fish).is_empty() and run.choices_of(fish, "skips") == 0 and
			run.loadout_of(fish).weapons.size() + run.loadout_of(fish).tomes.size() == level_before, "a skip takes nothing")
	run.banished_of(fish).append("sea_salt")
	var salty := false
	var rng := RandomNumberGenerator.new()
	for n in 300:
		salty = salty or "sea_salt" in Powerup.pick_for_chest(rng, Rarity.Tier.COMMON, 3, run.banished_of(fish))
	check(not salty, "a banished item never comes from a chest")
	_finish()


func _finish() -> void:
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
