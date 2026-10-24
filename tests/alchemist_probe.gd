extends Node
## The Alchemists (big_changes.md §5, Phase 3) in the real game: the class and
## its three Sea Hare species; Purple Haze, its own (bombs lobbed at the
## densest pack in any direction, led by its drift; clouds that burst on
## landing, hurt, haze and slow; the cap; Opaline; merging; death clouds;
## creeping); "bombs that did damage" while it swims away from a chasing pack
## (the case Depth Charges failed; target 90%); Unpalatable (touching zombies
## are coated: slowed, and Purple Haze hurts them more); Flutter (three flaps
## up and forward, a cloud where it took off); the flap gait; the signature
## stats (Regen for the Alchemists, a fractional Quantity for the Drifters).
##   Godot_console.exe --headless --path . res://tests/alchemist_probe.tscn

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var powers := PowerupSettings.shared()
var run: UnnaturalRun
var horde: Horde
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	print("the class:")
	var alchemist := FishCharacter.FishClass.ALCHEMIST
	check(alchemist == 10 and FishCharacter.from_key("alchemist") == alchemist and FishCharacter.from_key("sea_hare") == alchemist,
			"ALCHEMIST is added at the end (10); its key and alias resolve")
	check(FishCharacter.species_count(alchemist) == 3 and FishCharacter.species_name(alchemist, 2) == "Ragged Sea Hare", "three Sea Hare species")
	check(FishCharacter.rl_hitbox(alchemist) == "merc", "on the Merc hitbox")
	check(StatBlock.signature(alchemist) == "regen" and StatBlock.signature(FishCharacter.FishClass.DRIFTER) == "quantity",
			"signatures: Regen (Alchemists), Quantity (Drifters)")
	check(is_equal_approx(StatBlock.signature_amount(FishCharacter.FishClass.DRIFTER, 1.0, settings), settings.signature_quantity),
			"the Drifters' Quantity grows %.2f a level" % settings.signature_quantity)
	check(StatBlock.shown("quantity", 0.99) == 0.0 and StatBlock.shown("quantity", 1.0) == 1.0, "Quantity shows its floor")
	check(Traversal.title(alchemist) == "Unpalatable" and Traversal.skill_title(alchemist) == "Flutter", "Unpalatable and Flutter")
	check("attack_purple_haze" in Weapons.card_pool(FishAttack.Kind.BITE) and "attack_purple_haze" not in Weapons.card_pool(FishAttack.Kind.HAZE)
			and "attack_depth_charges" not in Weapons.POWERUPS, "Purple Haze is a second weapon for others; Depth Charges are gone")
	for species in 3:
		var model := FishModel.build(alchemist, species)
		check(model.tail != null and model.fin_left != null and model.fin_left.get_child_count() > 0, "%s has a model with flaps on its fin pivots"
				% FishCharacter.species_name(alchemist, species))
		model.free()

	settings.spawning = false
	settings.card_choices = 0
	settings.enemy_speed_scale = 0.0
	settings.enemy_hp_scale = 100.0
	settings.difficulty_per_minute = 0.0
	settings.enemy_damage_scale = 0.0
	settings.chest_count = 0
	settings.twists = false
	fish.character = alchemist
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde

	print("purple haze:")
	var haze := await _use()
	check(haze is PurpleHaze, "the Sea Hare's own attack is Purple Haze")
	# A pack behind and above: any direction counts.
	var pack_at := fish.global_position + Vector3(0, 3, 8)
	var pack: Array[int] = []
	for n in 5:
		pack.append(horde.spawn(1, pack_at + Vector3(n * 0.4, 0, 0)))
	var lone := horde.spawn(1, fish.global_position + Vector3(-9, 0, 0))
	await _seconds(0.1)  # the horde steps at its own sim_rate: then it's in the lookups
	var spots := haze.spots(1)
	check(spots[0].distance_to(pack_at) < 2.0, "it aims at the densest pack (behind and above), not the lone zombie (%.1f m off)" % spots[0].distance_to(pack_at))
	haze.scatter()
	await _seconds(powers.haze_scatter_time + powers.haze_lob_time + 0.15)
	check(haze.burst == 3 and _hurt(pack[0]) and horde.slow_share(pack[0]) > 0.0, "three bombs burst; the pack is hurt and hazed")
	check(_hurt(lone), "the next bomb goes to the next pack apart from it (the lone one)")
	# Led by the pack's drift.
	horde.clear()
	settings.enemy_speed_scale = 1.0
	await _ticks(2)
	var mover := horde.spawn(1, fish.global_position + Vector3(6, 0, 0))
	await _seconds(0.5)
	var velocity := horde.enemy_velocity(mover)
	var aim := haze.spots(1)[0]
	var lead := horde.enemy_position(mover) + velocity * powers.haze_lob_time
	check(velocity.length() > 0.5 and aim.distance_to(lead) < 0.6, "it leads a moving pack by its velocity over the lob (%.2f m off)" % aim.distance_to(lead))
	settings.enemy_speed_scale = 0.0

	print("milestones:")
	haze = await _use()
	_set_level(haze, 20)
	var a := haze.open_cloud(fish.global_position + Vector3(0, 0, 10), 3.0, 10.0)
	var b := haze.open_cloud(fish.global_position + Vector3(0, 0, 14), 3.0, 10.0)
	await _ticks(3)
	check(haze.merges >= 1 and (not is_instance_valid(a) or a.fading or not is_instance_valid(b) or b.fading), "touching clouds merge (Lv 10)")
	horde.clear()
	await _ticks(2)
	var film := horde.spawn(1, fish.global_position + Vector3(0, 0, -20))
	var film_cloud := haze.open_cloud(horde.enemy_position(film), 2.0, 0.6)
	await _seconds(0.9)
	check(not is_instance_valid(film_cloud) or film_cloud.fading, "the cloud's gone")
	check(horde.slow_share(film) >= powers.haze_film_slow - 0.01, "Opaline: still slowed after leaving it (Lv 5)")
	var deaths_before := haze.death_clouds
	haze.open_cloud(horde.enemy_position(film), 2.0, 5.0)
	await _ticks(2)
	horde.kill(film, "purple_haze", fish)
	await _ticks(2)
	check(haze.death_clouds > deaths_before, "a zombie that dies hazed bursts into a cloud (Lv 15)")
	horde.clear()
	await _ticks(2)
	var prey := horde.spawn(1, fish.global_position + Vector3(10, 0, 30))
	var creeper := haze.open_cloud(fish.global_position + Vector3(0, 0, 30), 1.0, 10.0)
	var gap := creeper.global_position.distance_to(horde.enemy_position(prey))
	await _seconds(1.0)
	check(creeper.global_position.distance_to(horde.enemy_position(prey)) < gap - 0.5, "clouds creep toward the nearest zombie (Lv 20)")
	_set_level(haze, 1)

	print("swimming away (the case Depth Charges failed):")
	haze = await _use()
	settings.enemy_speed_scale = 1.0
	fish.freeze = false
	var paid_before := haze.paid
	var burst_before := haze.burst
	# A chasing horde behind; the fish flees ahead the whole time.
	for n in 24:
		horde.spawn(n % 2, fish.global_position + Vector3(randf_range(-6, 6), randf_range(-2, 2), randf_range(6, 14)))
	haze._next = 0.0
	for n in Engine.physics_ticks_per_second * 14:
		fish.linear_velocity = Vector3(0, 0, -6.0)
		await get_tree().physics_frame
	settings.enemy_speed_scale = 0.0
	var share := float(haze.paid - paid_before) / maxf(haze.burst - burst_before, 1.0)
	check(haze.burst - burst_before >= 6 and share >= 0.9, "bombs that did damage: %d of %d (%.0f%%; target 90%%)" % [haze.paid - paid_before, haze.burst - burst_before, share * 100.0])
	print("    zombie-seconds hazed: %.1f" % haze.hazed_seconds)

	print("unpalatable and flutter:")
	settings.twists = true
	haze = await _use()
	var twist := run.twist_of(fish)
	var toucher := horde.spawn(1, fish.global_position + Vector3(0.4, 0, 0))
	await _seconds(0.1)
	check(twist.coats >= 1 and twist.is_coated(toucher) and horde.slow_share(toucher) >= settings.coat_slow - 0.01, "a zombie that touches it is coated and slowed")
	var far := horde.spawn(1, fish.global_position + Vector3(0, 0, 20))
	var far2 := horde.spawn(1, fish.global_position + Vector3(0, 0, 40))
	await _ticks(2)
	twist._coated[far] = twist._clock + 10.0
	var hp_far := horde.enemy_hp(far)
	var hp_far2 := horde.enemy_hp(far2)
	haze.open_cloud(horde.enemy_position(far), 1.0, 0.3)
	haze.open_cloud(horde.enemy_position(far2), 1.0, 0.3)
	await _ticks(3)
	var coated_took := hp_far - horde.enemy_hp(far)
	var plain_took := hp_far2 - horde.enemy_hp(far2)
	check(plain_took > 0.0 and absf(coated_took / plain_took - (1.0 + settings.coat_bonus)) < 0.05,
			"Purple Haze hurts a coated zombie %d%% more (%.1f vs %.1f)" % [roundi(settings.coat_bonus * 100.0), coated_took, plain_took])
	horde.clear()
	await _ticks(2)
	fish.freeze = false
	fish.linear_velocity = Vector3.ZERO
	var start := fish.global_position
	var bursts := haze.burst
	check(twist.mobility(), "Flutter goes off")
	check(haze.burst == bursts + 1 and haze.clouds[-1].global_position.distance_to(start) < 0.5, "a cloud bursts where it took off")
	await _seconds(settings.flutter_gap * settings.flutter_flaps + 0.3)
	var moved := fish.global_position - start
	check(twist.flaps == settings.flutter_flaps, "%d flaps" % twist.flaps)
	check(moved.y > 1.5 and moved.dot(-fish.global_basis.z) > 1.0, "it rose (%.1f m) and went forward (%.1f m)" % [moved.y, moved.dot(-fish.global_basis.z)])
	check(not twist.mobility(), "then it cools down")
	settings.twists = false

	print("the flap gait:")
	var gait := fish.gait
	check(gait.stroke_axis == Gait.StrokeAxis.FLAP and gait.visual == Gait.Visual.FLAP, "the Sea Hare holds the flap gait")
	var push := fish.swishy.push_direction(Basis.IDENTITY)
	check(push.y > 0.05 and push.z < -0.9, "a stride pushes along the nose and lifts (%s)" % push)

	print("alchemist_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


## The fish's own haze, parked at the middle facing forward, the horde cleared.
func _use() -> PurpleHaze:
	horde.clear()
	fish.character = FishCharacter.FishClass.ALCHEMIST
	run.block_of(fish).reset()
	var attack := run.attack_of(fish)
	if attack:
		attack.on_removed()
	var twist := run.twist_of(fish)
	if twist:
		twist.reset()
	await _park(Vector3(0, 0, 0), Vector3.FORWARD)
	await _ticks(2)
	run._apply_stats(fish)
	var haze := run.attack_of(fish) as PurpleHaze
	if haze:
		_set_level(haze, 1)
		haze._next = 1000.0  # it scatters when the probe says
		haze.burst = 0
		haze.paid = 0
		haze.lobbed = 0
	return haze


func _set_level(attack: FishAttack, level: int) -> void:
	attack.level = level
	attack.milestones = settings.milestones_at(level)


func _hurt(index: int) -> bool:
	return horde.is_alive(index) and horde.enemy_hp(index) < horde.enemy_max_hp(index) - 0.01


func _park(at: Vector3, facing: Vector3) -> void:
	fish.freeze = false
	var spawn: Transform3D = run.ocean.spawn_transform()
	fish.revive(Transform3D(Basis.looking_at(facing), spawn.origin + at))
	await _ticks(2)
	fish.freeze = true


func _seconds(s: float) -> void:
	await _ticks(roundi(s * Engine.physics_ticks_per_second))


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
