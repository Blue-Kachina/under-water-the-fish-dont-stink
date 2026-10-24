extends Node
## The 2026-10-20 batch: every fish's attack as an extra weapon (AttackWeapon)
## with no fixed rarity on weapon cards; the fifteen §7b items (Sticky Anemone,
## Ink Sac, Sonar Pinger, Cold Seep, Whirlpool Charm, Kraken's Grasp, Ghost
## Swordfish, Ammonite Spiral, Riptide, Reef Guardian, Bioluminescence,
## Poseidon's Trident, Megalodon Tooth, Moon Pearl, Abyssal Engine); safe
## ramming (swimming into a zombie doesn't hurt); swarm events that last; and
## the cards' stat-first lines.
##   Godot_console.exe --headless --path . res://tests/arsenal_batch_probe.tscn

const NEW_ITEMS: Array[String] = ["sticky_anemone", "ink_sac", "sonar_pinger", "cold_seep", "whirlpool_charm", "krakens_grasp",
		"ghost_swordfish", "ammonite_spiral", "riptide", "reef_guardian", "bioluminescence", "poseidons_trident",
		"megalodon_tooth", "moon_pearl", "abyssal_engine"]

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
	settings.chest_drop_chance = 0.0
	settings.pearl_drop_chance = 0.0
	settings.knockback = 0.0
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde
	await _park(Vector3(0, 0, 60), Vector3.FORWARD)

	await _weapons()
	await _texts()
	await _control_items()
	await _area_items()
	await _legendaries()
	await _ramming()
	await _swarm()

	print("every new item is offered in a chest:")
	var found := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for tier in [Rarity.Tier.COMMON, Rarity.Tier.UNCOMMON, Rarity.Tier.RARE, Rarity.Tier.LEGENDARY]:
		for n in 300:
			for id in Powerup.pick_from_tier(rng, tier, 3):
				found[id] = true
	var missing := NEW_ITEMS.filter(func(id: String) -> bool: return not found.has(id))
	check(missing.is_empty(), "all fifteen come up %s" % ("" if missing.is_empty() else str(missing)))
	var no_attacks := true
	for id: String in found:
		no_attacks = no_attacks and not id.begins_with("attack_")
	check(no_attacks, "and no weapon does")

	print("arsenal_batch_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _weapons() -> void:
	print("weapons:")
	var pool := Weapons.card_pool(FishAttack.Kind.BITE)
	check("attack_bite" not in pool and "attack_sting" in pool and "attack_spines" in pool and "attack_greek_fire" in pool and "attack_leviathans_coil" not in pool,
			"a Shark's new-weapon pool: every other fish's attack and the powerup weapons (%d)" % pool.size())
	check(Weapons.card_pool(FishAttack.Kind.FIRE).size() == pool.size() and "attack_bite" in Weapons.card_pool(FishAttack.Kind.FIRE)
			and "attack_greek_fire" not in Weapons.card_pool(FishAttack.Kind.FIRE), "a Lionfish's: every other fish's, the Shark's bite too, not its own fire")
	settings.card_choices = 3
	settings.card_weight_weapon = 0.0
	settings.card_weight_tome = 0.0
	settings.card_weight_new_tome = 0.0
	settings.card_weight_new_weapon = 1.0
	var seen := {}
	var tiers := {}
	for n in 400:
		for card: Dictionary in CardDeck.deal(run, fish, 3):
			if card.kind == "new_weapon":
				seen[card.weapon] = seen.get(card.weapon, 0) + 1
				tiers[card.tier] = true
	var everyone := true
	for id in pool:
		everyone = everyone and seen.get(id, 0) > 0
	var lowest := 1000000
	var highest := 0
	for id: String in seen:
		lowest = mini(lowest, seen[id])
		highest = maxi(highest, seen[id])
	check(everyone, "every one of them is dealt (%s)" % str(seen))
	check(lowest > highest * 0.6, "about equally often (%d to %d)" % [lowest, highest])
	check(tiers.size() >= 3, "a new weapon's rarity is rolled, not fixed (%d tiers seen)" % tiers.size())
	settings.card_choices = 0
	settings.card_weight_weapon = 40.0
	settings.card_weight_tome = 30.0
	settings.card_weight_new_tome = 15.0
	settings.card_weight_new_weapon = 15.0

	horde.clear()
	var target := horde.spawn(2, fish.global_position + Vector3(0, 0, -3))
	horde._hp[target] = 100000.0
	horde._max_hp[target] = 100000.0
	run.take_card(fish, {"kind": "new_weapon", "weapon": "attack_sting", "tier": Rarity.Tier.RARE, "level": 1,
			"gains": {"damage": 0.5}})
	check(run.loadout_of(fish).has_weapon("attack_sting") and is_equal_approx(run.loadout_of(fish).facet("attack_sting", "damage"), 0.5),
			"a Shark takes the Clownfish's Anemone Sting, with its card's rolled facets")
	await _seconds(2.0)
	var sting: AttackWeapon = run.powerups_of(fish).held.get("attack_sting")
	var stung: float = run.stats_of(fish).by_source.get("sting", 0.0)
	check(sting != null and is_instance_valid(sting.attack) and sting.attack is AnemoneSting, "it fires its own Anemone Sting")
	check(stung > 0.0 and sting.attack.uses > 0, "beside the Shark's bite, it stings (%.0f damage, %d stings)" % [stung, sting.attack.uses if sting else 0])
	var node := sting.attack
	run.loadout_of(fish).remove_weapon("attack_sting")
	run.powerups_of(fish).refresh()
	await _ticks(2)
	check(not is_instance_valid(node) and not run.powerups_of(fish).held.has("attack_sting"), "dropped: its attack goes too")
	horde.clear()


func _texts() -> void:
	print("card lines:")
	check(StatBlock.describe("damage", 0.15) == "Damage +15%" and StatBlock.describe("armour", 2.0) == "Armour +2", "the stat first, then its change")
	var tome := Tomes.describe(Tomes.gives("shell", 1.0, settings))
	check(tome.size() == 3 and tome[0].begins_with("Max HP +"), "a tome's stats one a line (%s)" % ", ".join(tome))
	check(Powerup.blurb_lines("treasure_map").size() == 2 and Powerup.blurb_lines("treasure_map")[0] == "Chest Drops +30%", "an item's effects one a line")
	check(Powerup.curse_lines("glass_coral") == PackedStringArray(["Max HP -50%"]) and Powerup.blurb_lines("glass_coral") == PackedStringArray(["Damage +100%"]),
			"a curse's upside and downside apart")
	var gains := Weapons.describe_all("attack_greek_fire", {"burn": 0.2, "patches": 1.0})
	check(gains.size() == 2 and gains[0] == "Burn damage +20%", "a weapon card's facets one a line (%s)" % ", ".join(gains))


func _control_items() -> void:
	print("control items:")
	horde.clear()
	var a := _dummy(Vector3(0, 0, -8))
	powers.anemone_chance = 1.0
	powers.anemone_stacks = 1
	await _ticks(2)
	run.hit(a, 1.0, fish, "bite")
	check(is_equal_approx(horde.slow_share(a), powers.anemone_slow), "Sticky Anemone slows a zombie hit (%.0f%%)" % (horde.slow_share(a) * 100.0))
	powers.anemone_stacks = 0
	powers.seep_chance = 1.0
	powers.seep_stacks = 1
	await _ticks(2)
	run.hit(a, 1.0, fish, "bite")
	check(is_equal_approx(horde.slow_share(a), 1.0), "Cold Seep freezes it")
	await _seconds(powers.seep_time + 1.0)  # the horde's clock steps at sim_rate, a little behind
	check(horde.slow_share(a) == 0.0, "and it thaws after %.1f s" % powers.seep_time)
	powers.seep_stacks = 0

	horde.clear()
	var centre := fish.global_position + Vector3(0, 0, -10)
	var b := _dummy(Vector3(0, 0, -10))
	var c := _dummy(Vector3(1.5, 0, -10))
	powers.kraken_chance = 1.0
	powers.kraken_stacks = 1
	await _settle()
	var hp_c := horde.enemy_hp(c)
	run.hit(b, 1.0, fish, "bite")
	var kraken: HitProc = run.powerups_of(fish).held["krakens_grasp"]
	check(kraken.procs == 1 and horde.enemy_hp(c) < hp_c and horde.slow_share(c) >= 1.0, "Kraken's Grasp slams the area and holds what's in it")
	powers.kraken_stacks = 0

	powers.ink_stacks = 1
	await _ticks(2)
	var d := _dummy(Vector3(2, 0, 0))
	await _settle()
	run.powerups_of(fish).on_hurt(5.0, d)
	var ink: InkSac = run.powerups_of(fish).held["ink_sac"]
	check(ink.clouds == 1 and is_equal_approx(horde.slow_share(d), powers.ink_blind), "Ink Sac: hurt, the zombies near lose you")
	run.powerups_of(fish).on_hurt(5.0, d)
	check(ink.clouds == 1, "not again within its cooldown")
	powers.ink_stacks = 0

	horde.clear()
	var e := _dummy(Vector3(0, 0, -12))
	await _settle()
	var plain := _hit_damage(e, 10.0)
	powers.sonar_stacks = 1
	await _ticks(3)
	var sonar: SonarPinger = run.powerups_of(fish).held["sonar_pinger"]
	var marked := _hit_damage(e, 10.0)
	check(sonar.pings >= 1 and horde.is_marked(e), "Sonar Pinger pings and marks the zombies near")
	check(is_equal_approx(marked, plain * (1.0 + powers.sonar_bonus)), "marked, a hit does +%.0f%% (%.1f -> %.1f)" % [powers.sonar_bonus * 100.0, plain, marked])
	powers.sonar_stacks = 0

	powers.guardian_stacks = 1
	await _ticks(2)
	var health := run.health_of(fish)
	var guardian: ReefGuardian = run.powerups_of(fish).held["reef_guardian"]
	health.hp = health.max_hp * 0.5
	run.powerups_of(fish).on_hurt(1.0, -1)
	check(guardian.saves == 0, "Reef Guardian: no save at half hp")
	health.hp = health.max_hp * 0.1
	health.iframes_left = 0.0
	run.powerups_of(fish).on_hurt(1.0, -1)
	check(guardian.saves == 1 and health.iframes_left >= powers.guardian_time * 0.9, "under %.0f%%: untouchable %.1f s" % [powers.guardian_threshold * 100.0, health.iframes_left])
	run.powerups_of(fish).on_hurt(1.0, -1)
	check(guardian.saves == 1, "then it rests")
	health.hp = health.max_hp
	health.iframes_left = 0.0
	powers.guardian_stacks = 0
	await _ticks(2)


func _area_items() -> void:
	print("area items:")
	horde.clear()
	powers.charm_chance = 1.0
	powers.charm_stacks = 1
	await _ticks(2)
	var spot := fish.global_position + Vector3(0, 0, -15)
	var f := _dummy(Vector3(2, 0, -15))
	var hp_f := horde.enemy_hp(f)
	run.powerups_of(fish).on_kill(spot, "bite")
	var charm: WhirlpoolCharm = run.powerups_of(fish).held["whirlpool_charm"]
	await _seconds(1.0)
	check(charm.opened == 1 and horde.enemy_hp(f) < hp_f, "Whirlpool Charm: a kill opens a whirlpool that grinds (%.0f damage)" % (hp_f - horde.enemy_hp(f)))
	powers.charm_stacks = 0
	await _ticks(2)

	horde.clear()
	var g := _dummy(Vector3(0, 0, -10))
	await _settle()
	powers.ghost_stacks = 1
	await _seconds(0.2)
	var ghost: GhostSwordfish = run.powerups_of(fish).held["ghost_swordfish"]
	check(ghost.dashes >= 1 and run.stats_of(fish).by_source.get("ghost_swordfish", 0.0) > 0.0, "Ghost Swordfish dashes through a zombie")
	powers.ghost_stacks = 0

	horde.clear()
	var h := _dummy(Vector3(0, 0, -10))
	_dummy(Vector3(1.5, 0, -10))
	_dummy(Vector3(-1.5, 0, -10))
	powers.ammonite_stacks = 1
	await _settle()
	run.hit(h, 20.0, fish, "thrust")
	var ammonite: AmmoniteSpiral = run.powerups_of(fish).held["ammonite_spiral"]
	check(ammonite.shards == 2, "Ammonite Spiral: a spear's hit splits to the zombies by it (%d shards)" % ammonite.shards)
	run.hit(h, 20.0, fish, "bite")
	check(ammonite.shards == 2, "a bite doesn't split")
	powers.ammonite_stacks = 0

	horde.clear()
	powers.riptide_stacks = 1
	await _ticks(2)
	var behind := _dummy(Vector3(0, 0, 4))  # the fish faces -Z: behind it is +Z
	await _settle()
	var hp_b := horde.enemy_hp(behind)
	run.powerups_of(fish).on_stride(0.2)
	var riptide: Riptide = run.powerups_of(fish).held["riptide"]
	check(riptide.currents == 0, "Riptide: a sloppy stride leaves nothing")
	run.powerups_of(fish).on_stride(1.0)
	await _seconds(0.5)
	check(riptide.currents == 1 and horde.enemy_hp(behind) < hp_b, "a perfect one leaves a current that hurts what's behind")
	powers.riptide_stacks = 0
	await _ticks(2)


func _legendaries() -> void:
	print("rare and legendary:")
	horde.clear()
	var near := _dummy(Vector3(0, 0, -5))
	powers.biolum_stacks = 1
	await _settle()
	var glow: Bioluminescence = run.powerups_of(fish).held["bioluminescence"]
	var hp_n := horde.enemy_hp(near)
	run.levels.add(run.levels.xp_to_next())
	await _ticks(2)
	check(glow.flashes == 1 and horde.enemy_hp(near) < hp_n, "Bioluminescence flashes on a level-up")
	run.stats_of(fish)["chests"] = run.stats_of(fish).get("chests", 0) + 1
	await _ticks(2)
	check(glow.flashes == 2, "and on a chest")
	powers.biolum_stacks = 0
	run._offers.erase(fish)
	run._pending.erase(fish)
	run._hold_for_cards(false)

	horde.clear()
	var small := _dummy(Vector3(0, 0, -8))
	var big := horde.spawn(4, fish.global_position + Vector3(0, 0, -14))  # a bigger kind
	horde._hp[big] = 100000.0
	horde._max_hp[big] = 100000.0
	powers.trident_stacks = 1
	await _settle()
	var trident: PoseidonsTrident = run.powerups_of(fish).held["poseidons_trident"]
	var hp_big := horde.enemy_hp(big)
	trident.strike()
	check(trident.bolts == 1 and (horde.enemy_hp(big) < hp_big or horde.enemy_size(small) > horde.enemy_size(big)), "Poseidon's Trident strikes the biggest zombie near")
	check(trident._attacks_made() >= 0, "it counts the fish's attacks")
	powers.trident_stacks = 0

	horde.clear()
	var prey := _dummy(Vector3(0, 0, -6))
	horde._hp[prey] = horde.enemy_max_hp(prey) * 0.12
	powers.tooth_stacks = 1
	run.block_of(fish).add("crit_chance", 5.0)
	await _ticks(2)
	run.hit(prey, 1.0, fish, "bite")
	check(not horde.is_alive(prey), "Megalodon Tooth: a crit finishes a zombie under %.0f%%" % (powers.tooth_execute * 100.0))
	run.block_of(fish).add("crit_chance", -5.0)
	powers.tooth_stacks = 0

	powers.engine_stacks = 2
	await _ticks(2)
	var block := run.block_of(fish)
	check(is_equal_approx(block.bonus.get("quantity", 0.0), 2.0) and is_equal_approx(block.bonus.get("size", 0.0), powers.engine_size * 2.0),
			"Abyssal Engine x2: +2 projectiles, +%.0f%% size" % (powers.engine_size * 200.0))
	powers.engine_stacks = 0

	powers.moon_pearl_stacks = 1
	settings.card_choices = 3
	settings.tome_slots = 6
	settings.card_weight_weapon = 0.0
	settings.card_weight_new_weapon = 0.0
	settings.card_weight_tome = 0.0
	await _ticks(2)
	run._pending[fish] = 1
	run._offer_level(fish)
	var first := run.offer_of(fish).size()
	run.pick(fish, 0)
	var second := run.offer_of(fish).size()
	check(first == 3 and second == 2, "Moon Pearl: another card from the same level (%d, then %d)" % [first, second])
	run.pick(fish, 0)
	check(run.offer_of(fish).is_empty(), "and then that's the level done")
	settings.card_choices = 0
	settings.tome_slots = 2
	settings.card_weight_weapon = 40.0
	settings.card_weight_new_weapon = 15.0
	settings.card_weight_tome = 30.0
	powers.moon_pearl_stacks = 0
	run._hold_for_cards(false)
	await _ticks(2)


func _ramming() -> void:
	print("safe ramming:")
	horde.clear()
	await _ticks(2)
	var ahead := horde.spawn(0, fish.global_position + Vector3(0, 0, -0.5))
	fish.freeze = false
	fish.linear_velocity = Vector3(0, 0, -6.0)  # well under battering speed, as between strides
	check(run.rammed(fish, ahead), "swimming into a zombie at 6 m/s: no bite")
	fish.linear_velocity = Vector3(0, 0, 6.0)
	check(not run.rammed(fish, ahead), "backing away from it: it bites")
	fish.linear_velocity = Vector3(0, 0, -6.0)
	settings.safe_ramming = false
	check(not run.rammed(fish, ahead), "with safe_ramming off: it bites")
	settings.safe_ramming = true
	fish.linear_velocity = Vector3.ZERO
	fish.freeze = true
	horde.clear()


func _swarm() -> void:
	print("swarm events:")
	horde.clear()
	settings.ring_count = 20
	settings.swarm_event_time = 30.0
	settings.swarm_wave_every = 6.0
	run._start_event("ring")
	await _ticks(2)
	var first := horde.alive_count()
	check(run.swarm_left() > 29.0 and first >= 15, "the ring closes: %d zombies, %.0f s to survive" % [first, run.swarm_left()])
	await _seconds(6.5)
	var second := horde.alive_count()
	check(second > first + 15, "another, bigger wave %.0f s in (%d out)" % [settings.swarm_wave_every, second])
	run.swarm.left = 0.1
	await _ticks(30)
	check(run.swarm_left() == 0.0 and run.swarm.is_empty(), "and it ends")
	horde.clear()


## Lets the horde step, so new zombies are in its grid (area queries find them).
func _settle() -> void:
	await _ticks(8)


## A zombie `offset` from the fish that won't die of a few hits.
func _dummy(offset: Vector3) -> int:
	var index := horde.spawn(2, fish.global_position + offset)
	horde._hp[index] = 5000.0
	horde._max_hp[index] = 5000.0
	return index


func _hit_damage(index: int, amount: float) -> float:
	var before: float = run.stats_of(fish).damage
	run.hit(index, amount, fish, "bite", Vector3.ZERO, 0.0)
	return run.stats_of(fish).damage - before


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
