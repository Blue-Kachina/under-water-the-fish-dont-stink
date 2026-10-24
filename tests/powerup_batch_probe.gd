extends Node
## Unnatural's first batch of new powerups (planning_unnatural.md §7b, D14):
## the stat commons put their stats on the player (and off again); Remora
## Buddy nips; Bubble Wrap takes a hit once it's ready; Pufferfish Spines
## answer a touch and burst; Jellyfish Halo's jellies orbit and sting;
## Electric Eel's battery ring (with its cooldown); Depth Charges drop and
## blow; Anglerfish Lure's decoy draws the horde, then bursts; Tsunami Heart's
## wave sweeps what's ahead and not what's beside. Every powerup is in the
## chest pool with a testing override.
##   Godot_console.exe --headless --path . res://tests/powerup_batch_probe.tscn

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

	print("the pool:")
	var tiers := {}
	var made_all := true
	for id in Powerup.ids():
		tiers[Powerup.tier(id)] = tiers.get(Powerup.tier(id), 0) + 1
		var made := Powerup.create(id)
		# The fish attacks held as weapons (AttackWeapon) level from cards: no stacks override.
		made_all = made_all and made.get_script() != Powerup and (powers.STACKS.has(id) or Weapons.ATTACK_WEAPONS.has(id))
	check(Powerup.ids().size() == 52 and made_all, "52 powerups (6 of them fish attacks as weapons), each its own kind with a testing override")
	check(tiers.get(Rarity.Tier.COMMON, 0) == 20 and tiers.get(Rarity.Tier.UNCOMMON, 0) == 12 and tiers.get(Rarity.Tier.RARE, 0) == 9
			and tiers.get(Rarity.Tier.LEGENDARY, 0) == 5 and tiers.get(Rarity.Tier.BOSS, 0) == 1 and tiers.get(Rarity.Tier.CURSED, 0) == 5,
			"tiers: 20 common (Bow Grow Bow among them, D15; the 6 attack weapons, unused), 12 uncommon, 9 rare, 5 legendary, 1 boss, 5 cursed (%s)" % [tiers])

	print("stat commons:")
	var block := run.block_of(fish)
	var health := run.health_of(fish)
	var attack := run.attack_of(fish)
	var hp_0 := health.max_hp
	var armour_0 := block.value("armour")
	var speed_0 := fish.speed_scale
	var attack_0 := attack.attack_speed
	powers.barnacle_stacks = 2
	powers.hermit_stacks = 2
	powers.soda_stacks = 1
	powers.seahorse_stacks = 1
	await _ticks(2)
	check(is_equal_approx(block.value("armour"), armour_0 + powers.barnacle_armour * 2), "Barnacle Plating x2: +%.0f armour" % (block.value("armour") - armour_0))
	check(is_equal_approx(health.max_hp, hp_0 + powers.hermit_hp * 2), "Hermit Shell x2: max hp %.0f -> %.0f" % [hp_0, health.max_hp])
	check(is_equal_approx(attack.attack_speed, attack_0 + powers.soda_attack_speed), "Fizzy Soda: attack speed x%.2f" % attack.attack_speed)
	check(is_equal_approx(fish.speed_scale, speed_0 * (1.0 + powers.seahorse_speed) / (1.0 + 0.0)), "Speedy Seahorse: swim x%.2f" % fish.speed_scale)
	var worn := true
	for part: String in ["Barnacles", "HermitShell", "Fizz", "Seahorse"]:
		worn = worn and fish.find_child(part, false, false) != null
	check(worn, "all four worn on the fish")
	powers.barnacle_stacks = 0
	powers.hermit_stacks = 0
	powers.soda_stacks = 0
	powers.seahorse_stacks = 0
	await _ticks(2)
	check(is_equal_approx(block.value("armour"), armour_0) and is_equal_approx(health.max_hp, hp_0) and is_equal_approx(attack.attack_speed, attack_0)
			and is_equal_approx(fish.speed_scale, speed_0) and fish.find_child("Barnacles", false, false) == null, "without them, all back")

	print("remora buddy:")
	powers.remora_stacks = 1
	horde.clear()
	await _ticks(2)
	var remora := run.powerups_of(fish).weapon("attack_remora_buddy") as RemoraBuddy
	horde.spawn(2, fish.global_position + Vector3(2, 0, -4))
	await _seconds(2.0)
	check(remora.nips >= 1 and _dealt("remora_buddy") > 0.0, "it nips the zombie near (%d nips)" % remora.nips)
	check(remora.lunges >= 1, "and you see a remora dart out to do it (%d lunges)" % remora.lunges)
	powers.remora_stacks = 3
	await _ticks(2)
	check(remora.count() == powers.remora_count + remora.facet_count("count") and remora.count() >= 2 and fish.find_child("Remoras", false, false).get_child_count() == remora.count(),
			"Lv 3: its count facet adds remoras, all worn (%d)" % remora.count())
	powers.remora_stacks = 0

	print("bubble wrap:")
	powers.bubble_stacks = 1
	powers.bubble_ready = 0.5
	powers.bubble_ready_min = 0.1
	horde.clear()
	await _ticks(2)
	var bubble: BubbleWrap = run.powerups_of(fish).held["bubble_wrap"]
	check(not bubble.is_ready(), "it isn't ready at once")
	await _seconds(0.7)
	health.hp = health.max_hp
	health.iframes_left = 0.0
	check(bubble.is_ready() and fish.find_child("Bubble", false, false).visible, "untouched a while, the bubble shows")
	var blocked := run.hurt(fish, 20.0)
	check(not blocked and bubble.blocked == 1 and is_equal_approx(health.hp, health.max_hp), "it takes the next hit for the fish")
	health.iframes_left = 0.0
	check(run.hurt(fish, 20.0) and health.hp < health.max_hp, "and then it's gone: the one after hurts")
	powers.bubble_ready = 8.0
	powers.bubble_ready_min = 2.0
	powers.bubble_stacks = 3
	await _ticks(2)
	check(is_equal_approx(bubble.ready_time(), 8.0 - 2.0 * powers.bubble_ready_per_stack), "stacks: ready sooner (%.1f s)" % bubble.ready_time())
	powers.bubble_stacks = 0
	health.hp = health.max_hp

	print("pufferfish spines:")
	powers.spine_stacks = 1
	horde.clear()
	await _ticks(2)
	var spines: PufferfishSpines = run.powerups_of(fish).held["pufferfish_spines"]
	var toucher := horde.spawn(2, fish.global_position + Vector3(0, 0, -1.0))
	var bystander := horde.spawn(2, fish.global_position + Vector3(2.5, 0, 0))
	var outside := horde.spawn(2, fish.global_position + Vector3(0, 0, 12.0))
	await _ticks(8)  # in the horde's grid
	var hp_t := horde.enemy_hp(toucher)
	var hp_b := horde.enemy_hp(bystander)
	var hp_o := horde.enemy_hp(outside)
	health.iframes_left = 0.0
	run.hurt(fish, 20.0, toucher)
	check(spines.bursts == 1, "hurt: the spines burst")
	check(hp_t - horde.enemy_hp(toucher) >= spines.burst() + 0.5 * spines.reflect() * 10.0, "the toucher gets it back and the burst (%.0f damage)" % (hp_t - horde.enemy_hp(toucher)))
	check(horde.enemy_hp(bystander) < hp_b and is_equal_approx(horde.enemy_hp(outside), hp_o), "the burst hits what's near, not what's far")
	powers.spine_stacks = 0
	health.hp = health.max_hp

	print("jellyfish halo:")
	powers.jelly_count = 1  # one to start, so two at x2
	powers.jelly_stacks = 2
	horde.clear()
	await _ticks(2)
	var halo := run.powerups_of(fish).weapon("attack_jellyfish_halo") as JellyfishHalo
	var halo_node := run.find_child("JellyHalo", false, false)
	check(halo.count() == 2 and halo_node != null and halo_node.get_child_count() == 2, "x2: two jellies orbiting")
	var before := halo.jelly_position(0)
	await _seconds(0.3)
	check(halo.jelly_position(0).distance_to(before) > 0.3, "they go round")
	for n in 12:
		var a := n * TAU / 12.0
		horde.spawn(1, fish.global_position + Vector3(cos(a), 0.0, sin(a)) * powers.halo_radius)
	await _seconds(2.5)
	check(halo.stings > 0 and _dealt("jellyfish_halo") > 0.0, "and sting zombies they touch (%d stings)" % halo.stings)
	powers.jelly_stacks = 0
	await _ticks(2)
	check(run.find_child("JellyHalo", false, false) == null, "without it, the jellies go")

	print("electric eel:")
	powers.eel_stacks = 1
	horde.clear()
	await _ticks(2)
	var eel: ElectricEel = run.powerups_of(fish).held["electric_eel"]
	var near := horde.spawn(2, fish.global_position + Vector3(3, 0, 0))
	var far := horde.spawn(2, fish.global_position + Vector3(eel.radius() + 4.0, 0, 0))
	await _ticks(8)
	var hp_n := horde.enemy_hp(near)
	var hp_f := horde.enemy_hp(far)
	eel.on_battery(-1)
	eel.on_battery(-1)
	check(eel.rings == 1, "a battery sends one ring (the next waits for its cooldown)")
	check(horde.enemy_hp(near) < hp_n and is_equal_approx(horde.enemy_hp(far), hp_f), "it shocks the zombie in reach, not the one outside")
	await _seconds(powers.eel_cooldown + 0.1)
	eel.on_battery(-1)
	check(eel.rings == 2, "after the cooldown, another")
	powers.eel_stacks = 0

	print("depth charges:")
	var charge_interval := powers.charge_interval
	powers.charge_stacks = 1
	powers.charge_interval = 0.5
	horde.clear()
	await _ticks(2)
	var charges := run.powerups_of(fish).weapon("attack_depth_charges") as DepthCharges
	await _seconds(0.7)
	check(charges.dropped >= 1 and charges.mines.size() >= 1, "mines drop behind the fish (%d)" % charges.dropped)
	var behind := (charges.mines[0].global_position - fish.global_position).dot(fish.global_basis.z) > 0.0 if not charges.mines.is_empty() else false
	check(behind, "behind it")
	powers.charge_interval = 100.0
	await _seconds(powers.charge_arm)
	var mine_at := charges.mines[0].global_position if not charges.mines.is_empty() else fish.global_position
	var victim := horde.spawn(2, mine_at + Vector3(1.0, 0, 0))
	var hp_v := horde.enemy_hp(victim)
	await _ticks(4)
	check(charges.blown >= 1 and horde.enemy_hp(victim) < hp_v, "a zombie near an armed one sets it off, and it's hurt")
	# A drop lobs a mine at a zombie near the tail, and it can't go off mid-air.
	charges.on_removed()  # no mines left from above to set it off
	horde.clear()
	await _ticks(2)
	var tail := fish.global_position + fish.global_basis.z * (fish.hitbox_length * 0.6)
	var target_at := tail + fish.global_basis.z * 4.0
	var target := horde.spawn(2, target_at)
	var hp_target := horde.enemy_hp(target)
	await _ticks(2)  # in the horde's lookups
	target_at = horde.enemy_position(target)
	var blown_before := charges.blown
	charges.drop()
	var lobbed: DepthCharges.Mine = charges.mines[-1]
	await _ticks(2)
	check(is_instance_valid(lobbed) and lobbed.flight_left > 0.0 and charges.blown == blown_before, "a lobbed mine is in the air, not blown")
	var landed_at := lobbed.to if is_instance_valid(lobbed) else Vector3.INF
	check(landed_at.distance_to(target_at) < 1.0, "it's lobbed at the zombie behind the fish (%.1f m off)" % landed_at.distance_to(target_at))
	await _seconds(powers.charge_lob_time + powers.charge_arm + 0.2)
	check(charges.blown > blown_before and horde.enemy_hp(target) < hp_target, "it lands, arms and blows on the zombie")
	# More mines per drop: the mines facet and Quantity.
	horde.clear()
	await _ticks(2)
	check(FishAttack.kind_uses_stat(FishAttack.Kind.CHARGES, "quantity"), "Depth Charges use Quantity (Tome of Schools)")
	check(Weapons.facets("attack_depth_charges", FishAttack.Kind.BITE).any(func(entry: Array) -> bool: return entry[1] == "Mines per drop"),
			"its facet is Mines per drop")
	charges.extra_projectiles = 2
	var dropped_before := charges.dropped
	charges.drop()
	check(charges.dropped - dropped_before == 3 and charges.per_drop() == 3, "+2 Quantity: three mines a drop (%d)" % (charges.dropped - dropped_before))
	var spread := charges.mines[-1].to.distance_to(charges.mines[-3].to)
	check(spread > 0.5, "with no zombies near, they fan out behind (%.1f m apart)" % spread)
	charges.extra_projectiles = 0
	var dropped_mines := charges.mines.duplicate()
	powers.charge_stacks = 0
	powers.charge_interval = charge_interval
	await _ticks(2)
	check(dropped_mines.all(func(mine: Variant) -> bool: return not is_instance_valid(mine)), "without it, the mines go")

	print("anglerfish lure:")
	powers.lure_stacks = 1
	powers.lure_interval = 100.0
	powers.lure_life = 3.0
	settings.enemy_speed_scale = 1.0
	horde.clear()
	await _ticks(2)
	var lure: AnglerfishLure = run.powerups_of(fish).held["anglerfish_lure"]
	await _seconds(1.2)  # the first comes about a second after it's got
	check(lure.dropped == 1 and run.decoys.size() == 1, "it drops a decoy")
	var lure_at := run.decoys[0].global_position if not run.decoys.is_empty() else Vector3.ZERO
	await _park(lure_at + Vector3(0, 0, -20.0), Vector3.FORWARD)
	# 10 m from the fish and 14 m from the lure: the lure's pull wins.
	var drawn := horde.spawn(1, lure_at + Vector3(10.0, 0, -10.0))
	var start_gap := horde.enemy_position(drawn).distance_to(lure_at)
	await _seconds(1.5)
	check(horde.enemy_target(drawn) == 1 and horde.enemy_position(drawn).distance_to(lure_at) < start_gap - 2.0, "a zombie as near the fish swims to the lure instead (%.1f -> %.1f m)"
			% [start_gap, horde.enemy_position(drawn).distance_to(lure_at)])
	await _seconds(2.0)
	check(lure.burst == 1 and run.decoys.is_empty(), "then it bursts, and the horde forgets it")
	settings.enemy_speed_scale = 0.0
	# Tome of Ages stretches a decoy's life; Tides drop it sooner; the Reef widens the blast.
	block = run.block_of(fish)
	block.reset()  # (a level-up on the way may have grown its signature stat)
	check(is_equal_approx(lure.life(), powers.lure_life) and is_equal_approx(lure.blast(), powers.lure_blast) and is_equal_approx(lure.interval(), powers.lure_interval),
			"no tomes: its life, blast and interval are the base ones")
	block.add("duration", 0.5)
	block.add("attack_speed", 0.25)
	block.add("size", 0.5)
	check(is_equal_approx(lure.life(), powers.lure_life * 1.5), "Tome of Ages: a decoy lasts 50%% longer (%.1f s)" % lure.life())
	check(is_equal_approx(lure.interval(), powers.lure_interval / 1.25), "Tome of Tides: it's dropped sooner (%.1f s)" % lure.interval())
	check(is_equal_approx(lure.blast(), powers.lure_blast * 1.5), "Tome of the Reef: the burst is wider (%.1f m)" % lure.blast())
	block.reset()
	powers.lure_stacks = 0
	powers.lure_interval = 10.0
	powers.lure_life = 5.0

	print("tsunami heart:")
	powers.tsunami_stacks = 1
	horde.clear()
	await _park(Vector3(0, 0, 60), Vector3.FORWARD)
	var heart: TsunamiHeart = run.powerups_of(fish).held["tsunami_heart"]
	var ahead: Array[int] = []
	for n in 4:
		ahead.append(horde.spawn(2, fish.global_position + Vector3(0, 0, -5.0 - n * 5.0)))
	var aside := horde.spawn(2, fish.global_position + Vector3(heart.width() + 6.0, 0, -10.0))
	await _ticks(8)
	var hp_a := horde.enemy_hp(aside)
	heart.on_battery(-1)
	heart.on_battery(-1)
	check(heart.waves == 1, "a battery sends one wave (then its cooldown)")
	await _seconds(powers.tsunami_length / powers.tsunami_speed + 0.3)
	var all_hit := true
	for i in ahead:
		all_hit = all_hit and horde.enemy_hp(i) < horde.enemy_kind(i).hp
	check(all_hit and heart.swept == ahead.size(), "it sweeps all %d ahead, each once (%d)" % [ahead.size(), heart.swept])
	check(is_equal_approx(horde.enemy_hp(aside), hp_a), "not the one beside its path")
	check(run.find_children("*", "Node3D", false, false).filter(func(n: Node) -> bool: return n is TsunamiHeart.Wave).is_empty(), "and the wave's gone at its end")
	powers.tsunami_stacks = 0

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _dealt(source: String) -> float:
	return run.stats_of(fish).by_source.get(source, 0.0)


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
