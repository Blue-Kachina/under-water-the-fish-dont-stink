extends Node
## The second batch of chest items (planning_unnatural.md 7b): Kelp Wrap, Sea
## Salt, Coral Knuckles, Diver's Goggles and Lucky Sand Dollar put their stats
## on the player (and off again); Lamprey heals on a kill; Clam Shield takes a
## hit once ready, on its own clock; Momentum Fin lifts hit damage with speed;
## Treasure Map lifts chest drops and the ping range.
##   Godot_console.exe --headless --path . res://tests/items_batch_probe.tscn

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	UnnaturalSettings.shared().limits = false  # the items' own numbers, in a line (limits_probe has P4's curves)
	settings.spawning = false
	settings.stage_events = false
	settings.chest_count = 0
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
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde
	await _park(Vector3(0, 0, 60), Vector3.FORWARD)

	print("stat items:")
	var block := run.block_of(fish)
	var regen_0 := block.value("regen")
	var crit_0 := block.value("crit_chance")
	var battery_0 := block.value("battery_damage")
	var pickup_0 := block.value("pickup_range")
	var luck_0 := block.value("luck")
	powers.kelp_stacks = 2
	powers.salt_stacks = 2
	powers.knuckles_stacks = 1
	powers.goggles_stacks = 2
	powers.dollar_stacks = 3
	await _ticks(2)
	check(is_equal_approx(block.value("regen"), regen_0 + powers.kelp_regen * 2), "Kelp Wrap x2: +%.1f hp/s" % (block.value("regen") - regen_0))
	check(is_equal_approx(block.value("crit_chance"), crit_0 + powers.salt_crit * 2), "Sea Salt x2: +%.0f%% crit" % ((block.value("crit_chance") - crit_0) * 100.0))
	check(is_equal_approx(block.value("battery_damage"), battery_0 + powers.knuckles_battery), "Coral Knuckles: +%.0f%% battery damage" % ((block.value("battery_damage") - battery_0) * 100.0))
	check(is_equal_approx(block.value("pickup_range"), pickup_0 + powers.goggles_range * 2), "Diver's Goggles x2: +%.0f%% pickup range" % ((block.value("pickup_range") - pickup_0) * 100.0))
	check(is_equal_approx(block.value("luck"), luck_0 + powers.dollar_luck * 3), "Lucky Sand Dollar x3: +%.1f luck" % (block.value("luck") - luck_0))
	check(fish.find_child("Trinket", false, false) != null, "they're worn")
	powers.kelp_stacks = 0
	powers.salt_stacks = 0
	powers.knuckles_stacks = 0
	powers.goggles_stacks = 0
	powers.dollar_stacks = 0
	await _ticks(2)
	check(is_equal_approx(block.value("regen"), regen_0) and is_equal_approx(block.value("crit_chance"), crit_0) and is_equal_approx(block.value("luck"), luck_0)
			and is_equal_approx(block.value("pickup_range"), pickup_0) and is_equal_approx(block.value("battery_damage"), battery_0), "without them, all back")

	print("lamprey:")
	var health := run.health_of(fish)
	powers.lamprey_stacks = 3
	await _ticks(2)
	var lamprey: Lamprey = run.powerups_of(fish).held["lamprey"]
	health.hp = 50.0
	run.powerups_of(fish).on_kill(fish.global_position, "bite")
	check(is_equal_approx(health.hp, 50.0 + powers.lamprey_heal * 3), "a kill heals %.0f hp x3 stacks (%.0f)" % [powers.lamprey_heal, health.hp])
	var hp_after := health.hp
	run.powerups_of(fish).on_kill(fish.global_position, "bite")
	check(is_equal_approx(health.hp, hp_after), "a second kill at once doesn't (lamprey_gap)")
	powers.lamprey_stacks = 0
	await _ticks(2)
	check(lamprey.healed > 0.0 and not run.powerups_of(fish).held.has("lamprey"), "gone with its stacks")

	print("clam shield:")
	powers.clam_stacks = 1
	await _ticks(2)
	var clam: ClamShield = run.powerups_of(fish).held["clam_shield"]
	check(not clam.blocks_hit(10.0), "shut at first: no block")
	await _seconds(powers.clam_ready + 0.5)
	check(clam.is_ready(), "ready after %.0f s (even unhurt)" % powers.clam_ready)
	check(clam.blocks_hit(10.0) and clam.blocked == 1, "it takes the hit")
	check(not clam.is_ready() and not clam.blocks_hit(10.0), "then it's shut again")
	powers.clam_stacks = 0
	await _ticks(2)

	print("momentum fin:")
	horde.clear()
	await _ticks(2)
	powers.momentum_stacks = 2
	await _ticks(2)
	var fin: MomentumFin = run.powerups_of(fish).held["momentum_fin"]
	fish.freeze = false
	fish.linear_velocity = Vector3.ZERO
	await _ticks(1)
	check(fin.damage_factor() < 1.05, "at rest: no bonus (x%.2f)" % fin.damage_factor())
	fish.linear_velocity = -fish.global_basis.z * powers.momentum_speed
	await _ticks(1)
	var fast := fin.damage_factor()
	check(fast > 1.0 + powers.momentum_damage * 2.0 * 0.8, "at %.0f m/s: x%.2f damage" % [fish.speed, fast])
	horde.spawn(2, fish.global_position + Vector3(0, 0, -30))
	await _ticks(3)
	var index := horde.nearest_in_cone(fish.global_position, Vector3.FORWARD, 60.0, -1.0)
	var boosted := _hit_damage(index, 10.0)
	fish.linear_velocity = Vector3.ZERO
	await _ticks(1)
	var calm := _hit_damage(index, 10.0)
	check(index >= 0 and boosted > calm * 1.1, "a hit lands harder at speed (%.1f at rest, %.1f fast)" % [calm, boosted])
	powers.momentum_stacks = 0
	fish.freeze = true
	await _ticks(2)

	print("treasure map:")
	var chance_0 := _chest_rate()
	powers.map_stacks = 2
	await _ticks(2)
	var chance_1 := _chest_rate()
	check(chance_0 > 0.0 and chance_1 > chance_0 * 1.3, "2 maps: more chest drops (%.4f -> %.4f)" % [chance_0, chance_1])
	check(is_equal_approx(run.chest_ping_bonus_of(fish), powers.treasure_ping * 2.0), "chests pinged %.0f m further" % run.chest_ping_bonus_of(fish))
	powers.map_stacks = 0
	await _ticks(2)
	check(is_equal_approx(run.chest_ping_bonus_of(fish), 0.0), "without them, back")

	print("every item is offered in a chest:")
	var found := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for tier in [Rarity.Tier.COMMON, Rarity.Tier.UNCOMMON]:
		for n in 200:
			for id in Powerup.pick_from_tier(rng, tier, 3):
				found[id] = true
	var all := true
	for id in ["kelp_wrap", "sea_salt", "coral_knuckles", "divers_goggles", "lucky_sand_dollar", "lamprey", "clam_shield", "momentum_fin", "treasure_map"]:
		all = all and found.has(id)
	check(all, "the nine new ones come up")

	print("items_batch_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## The damage `amount` becomes through run.hit() on zombie `index`, per the stats.
func _hit_damage(index: int, amount: float) -> float:
	var before: float = run.stats_of(fish).damage
	run.hit(index, amount, fish, "bite", Vector3.ZERO, 0.0)
	return run.stats_of(fish).damage - before


## Their chance a kill drops a chest, sampled.
func _chest_rate() -> float:
	var saved := settings.chest_drop_chance
	settings.chest_drop_chance = 0.05
	var hits := 0
	for n in 4000:
		hits += 1 if run._rolls_chest(fish, false) else 0
	settings.chest_drop_chance = saved
	return hits / 4000.0


func _park(at: Vector3, facing: Vector3) -> void:
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(facing), at))
	await _ticks(2)
	fish.freeze = true


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _ticks(roundi(s * 120.0))
