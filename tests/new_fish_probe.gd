extends Node
## The later playable fish (Lionfish, Moon Jelly, Mantis Shrimp, Manta): each
## starts with a powerup weapon in the slot a fish's own attack takes (and
## can't swap it away), builds a model, shows its details, and has a twist:
## Wake, Drift, Recoil Dash and Escort.
##   Godot_console.exe --headless --path . res://tests/new_fish_probe.tscn

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
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
	settings.spawning = false
	settings.card_choices = 0
	settings.enemy_speed_scale = 0.0
	settings.enemy_hp_scale = 100.0
	settings.difficulty_per_minute = 0.0
	settings.enemy_damage_scale = 0.0
	settings.chest_count = 0
	settings.twists = true
	fish.character = FishCharacter.FishClass.SCORCHER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde

	print("starting weapons:")
	var expected := {FishCharacter.FishClass.SCORCHER: FishAttack.Kind.FIRE, FishCharacter.FishClass.DRIFTER: FishAttack.Kind.HALO,
			FishCharacter.FishClass.BRAWLER: FishAttack.Kind.PUNCH, FishCharacter.FishClass.BREACHER: FishAttack.Kind.REMORA,
			FishCharacter.FishClass.ALCHEMIST: FishAttack.Kind.HAZE}
	for fish_class: FishCharacter.FishClass in expected:
		await _be(fish_class)
		var name: String = FishCharacter.display_name(fish_class)
		var loadout := run.loadout_of(fish)
		check(run.attack_of(fish).kind == expected[fish_class], "%s's own attack is its %s (a FishAttack)" % [name, FishAttack.title(expected[fish_class])])
		check(loadout.weapons == [Weapons.ATTACK] and run.powerups_of(fish).list().is_empty(),
				"%s starts with its attack alone (%s)" % [name, loadout.weapons])
		check(loadout.weapons.size() < settings.weapon_slots, "%s has a free weapon slot" % name)
		var model := FishModel.build(fish_class)
		check(model.tail != null and model.fin_left != null and model.fin_right != null and model.get_child_count() > 3, "%s has a model with swim pivots" % name)
		model.free()
		check(FishDetails.sections(fish_class).size() == 5 and Traversal.title(fish_class) != "" and (FishDetails.twist_text(fish_class, settings) as String) != "", "%s has details and a twist" % name)
		var was := loadout.earned_level(Weapons.ATTACK)
		run.take_card(fish, {"kind": "weapon", "weapon": Weapons.ATTACK, "gains": {}})
		check(loadout.earned_level(Weapons.ATTACK) == was + 1 and run.attack_of(fish).level == was + 1, "its card upgrades the weapon")
		var as_second := FishAttack.weapon_id_of(expected[fish_class])
		check(as_second in Weapons.card_pool(FishAttack.Kind.BITE) and as_second not in Weapons.card_pool(expected[fish_class]),
				"other fish can take it as a second weapon; it can't")
	await _be(FishCharacter.FishClass.GLIDER)
	check(run.loadout_of(fish).weapons == [Weapons.ATTACK] and run.attack_of(fish).kind == FishAttack.Kind.LASH, "another fish: its own attack")

	print("passives and skills:")
	await _be(FishCharacter.FishClass.SCORCHER)
	var twist := run.twist_of(fish)
	fish.linear_velocity = Vector3.ZERO
	check(is_equal_approx(twist.damage_factor("greek_fire"), 1.0) and twist.damage_factor("bite") == 1.0, "Lionfish, Wake: no bonus at rest, none for other weapons")
	fish.linear_velocity = Vector3.FORWARD * fish.nature_batter_speed
	await _ticks(2)
	check(fish.speed > 1.0 and twist.damage_factor("greek_fire") > 1.2, "Wake: fire burns x%.2f at speed %.0f" % [twist.damage_factor("greek_fire"), fish.speed])
	var victim := horde.spawn(1, Vector3(0, 0, -2))
	await _ticks(4)
	fish.freeze = false
	check(twist.mobility() and twist.flares == 1, "Lionfish, Flare Dash goes off")
	await _ticks(30)
	check(run.stats_of(fish).by_source.get("flare", 0.0) > 0.0, "and burns what it passes")

	await _be(FishCharacter.FishClass.DRIFTER)
	var halo := run.attack_of(fish) as JellyfishHalo
	check(halo.count() == settings_jellies() + settings.arms_extra, "Moon Jelly, Many Arms: %d jellies" % halo.count())
	twist = run.twist_of(fish)
	horde.spawn(1, Vector3(2, 0, 0))
	await _ticks(90)
	check(halo.stings > 0, "the Halo stings a zombie near it (%d)" % halo.stings)
	check(not run.is_quiet(fish) and twist.mobility() and run.is_quiet(fish), "Go Quiet: the stink goes off")
	await _ticks(2)
	check(horde.chaseable[0] == 0, "zombies can't find it")
	var nips := halo.stings
	await _ticks(30)
	check(halo.stings == nips, "and nothing fires")
	run.hurt(fish, 5.0)
	check(not run.is_quiet(fish), "a hit ends it")

	await _be(FishCharacter.FishClass.BRAWLER)
	fish.freeze = false
	var target := horde.spawn(1, Vector3(0, 0, -4))
	await _ticks(4)
	var recoil := run.twist_of(fish)
	check(recoil.mobility() and recoil.recoils == 1, "Mantis Shrimp, Recoil Dash goes off")
	await _ticks(20)
	check(run.stats_of(fish).by_source.get("punch", 0.0) > 0.0 and horde.enemy_hp(target) < horde.enemy_kind(target).hp * settings.enemy_hp_scale - 0.01,
			"and punches the zombie ahead")
	check(not recoil.mobility(), "then a cooldown")

	await _be(FishCharacter.FishClass.BREACHER)
	fish.freeze = false
	var gulped := horde.spawn(1, Vector3(0, 0, -6))
	await _ticks(4)
	var shark := run.twist_of(fish)
	var before_gap := horde.enemy_position(gulped).distance_to(fish.global_position)
	check(shark.mobility() and shark.gulps == 1, "Baby Whale Shark, Gulp goes off")
	await _ticks(20)
	check(run.stats_of(fish).by_source.get("gulp", 0.0) > 0.0, "and hurts the zombie ahead")
	var health := run.health_of(fish)
	health.hp = health.max_hp * 0.5
	var before := health.hp
	fish.linear_velocity = Vector3.ZERO
	await _ticks(60)
	check(health.hp > before + settings.escort_regen * 0.3, "Escort: holding still heals (%.1f -> %.1f)" % [before, health.hp])

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func settings_jellies() -> int:
	return PowerupSettings.shared().jelly_count


func _be(fish_class: FishCharacter.FishClass) -> void:
	horde.clear()
	fish.character = fish_class
	run.twist_of(fish).reset()
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), Vector3.ZERO))
	await _ticks(5)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
