extends Node
## Every weapon at Lv 20 (all four milestones: 5, 10, 15, 20) in the real Test
## Tank, for a few seconds each among its dummies and a chasing horde: each
## weapon and each of the six fish attacks deals damage with no script errors,
## and the third and fourth milestones' own effects happen (Greek Fire's
## flares and creep, the Halo's outer ring and jumps, Depth Charges'
## aftershocks, the Remoras' tears, the Coil's tail lash and double length,
## the Bite's five echo jaws and double snap, the Sting's third pulse, the
## Lash's extra arcs).
##   Godot_console.exe --headless --path . res://tests/milestones_probe.tscn

const SECONDS_EACH := 5.0

var failures := 0
var main: Node
var fish: FishController


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	settings.twists = false
	settings.weapon_slots = 6
	settings.tome_slots = 0
	settings.tank_horde = 120
	settings.tank_contact = false
	settings.tank_slow_walkers = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	fish.character = FishCharacter.Family.DOMINUS
	settings.fish_attack = FishAttack.Kind.BITE
	main.set_mode(main.TEST_TANK)
	await _ticks(3)
	main.play_match()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	settings.tank_preset = 3  # Full slots Lv 20
	await _ticks(5)
	var spawn: Transform3D = run.ocean.spawn_transform()
	var middle := spawn.origin - spawn.basis.z * TestTank.CLUSTER_AHEAD
	var held := run.powerups_of(fish).held
	print("the weapons at Lv 20:")
	for id: String in TestTank.PRESET_WEAPONS:
		check(held.has(id) and (held[id] as Powerup).stacks == 20 and (held[id] as Powerup).milestone(4), "%s on, with all four milestones" % id)
	var fire: GreekFire = held.get("greek_fire")
	var halo: JellyfishHalo = held.get("jellyfish_halo")
	var charges: DepthCharges = held.get("depth_charges")
	var remora: RemoraBuddy = held.get("remora_buddy")
	var coil: LeviathansCoil = held.get("leviathans_coil")

	var kinds := [FishAttack.Kind.STING, FishAttack.Kind.BITE, FishAttack.Kind.LASH, FishAttack.Kind.THRUST,
			FishAttack.Kind.BUBBLES, FishAttack.Kind.SPINES]
	var damage_by := {}
	for kind: int in kinds:
		settings.fish_attack = kind
		await _ticks(3)
		var attack := run.attack_of(fish)
		check(attack.kind == kind and attack.milestones == 4, "%s at Lv 20: four milestones" % FishAttack.title(kind))
		if fire:
			for n in 3:
				fire._drop(middle + Vector3(n * 2.0 - 2.0, 0, 0))
		var turn := 0.0
		for n in roundi(SECONDS_EACH * 120.0):
			# Round the cluster, close, so the trail and the attacks have zombies.
			turn += 1.2 / 120.0
			fish.global_position = middle + Vector3(cos(turn), 0.0, sin(turn)) * 5.0
			fish.linear_velocity = Vector3.ZERO
			await get_tree().physics_frame
			if kind == FishAttack.Kind.STING and n == 200:
				var sting := attack as AnemoneSting
				check(is_instance_valid(sting._echo) and is_instance_valid(sting._echo._echo) and sting._echo._echo.echo_depth == 2,
						"the Sting's echo has an echo of its own (the third pulse)")
			if kind == FishAttack.Kind.BITE and n == 200:
				var bite := attack as GhostBite
				check(bite._echoes.size() == 5, "the Bite's echo jaws: behind, both sides, above and below (%d)" % bite._echoes.size())
		if kind == FishAttack.Kind.BITE:
			var bite := attack as GhostBite
			check(bite.snapped_again >= bite.uses - 1 and bite.snapped_again > 0, "every bite snaps twice (%d bites, %d second snaps)" % [bite.uses, bite.snapped_again])
		if kind == FishAttack.Kind.STING:
			check(run.tank.sources().all(func(row: Dictionary) -> bool: return row.source != "bite"), "the Sting's echoes count as the sting, not the bite")
		if kind == FishAttack.Kind.LASH:
			var lash := attack as ShockLash
			check(lash.arcs() == settings.lash_arcs + lash.extra_projectiles + ShockLash.MORE_ARCS, "the Lash arcs on to %d more" % ShockLash.MORE_ARCS)
		for row: Dictionary in run.tank.sources():
			damage_by[row.source] = maxf(damage_by.get(row.source, 0.0), float(row.damage))
		var source := FishAttack.source_of(kind)
		check(float(damage_by.get(source, 0.0)) > 0.0, "%s deals damage (%.0f)" % [FishAttack.title(kind), float(damage_by.get(source, 0.0))])

	print("the powerup weapons' third and fourth milestones:")
	for id: String in TestTank.PRESET_WEAPONS:
		check(float(damage_by.get(id, 0.0)) > 0.0, "%s deals damage (%.0f)" % [id, float(damage_by.get(id, 0.0))])
	check(fire and fire.flares > 0, "Greek Fire's patches flare (%d)" % (fire.flares if fire else 0))
	check(halo and halo.jumps > 0, "the Halo's stings jump on (%d)" % (halo.jumps if halo else 0))
	check(halo and is_instance_valid(halo._halo) and halo._halo.get_child_count() == halo.count() * 3, "and it has its outer ring")
	check(charges and charges.aftershocks > 0, "Depth Charges' blasts go off again (%d)" % (charges.aftershocks if charges else 0))
	check(remora and remora.tears > 0, "the Remoras tear into the zombies round their bites (%d)" % (remora.tears if remora else 0))
	check(coil and coil.lashes > 0, "the Coil's tail lashes (%d)" % (coil.lashes if coil else 0))
	check(coil and coil.count() == (coil.settings.coil_segments + coil.facet_count("count")) * LeviathansCoil.LONG_SCALE, "and it's twice as long")

	settings.tank_preset = 0
	await _ticks(3)
	settings.weapon_slots = 2
	settings.tome_slots = 2
	settings.tank_horde = 0
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
