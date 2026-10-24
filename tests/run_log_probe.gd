extends Node
## Unnatural's run logs and the Test Tank presets (planning_unnatural.md,
## "Playability pass" P2): a run samples every minute (damage per second, time
## to kill, kills, level, drops), logs each card picked, knows what put the
## player down, saves to user://run_logs/ when it ends (with run_logs on) and
## keeps only run_logs_keep files; tank_preset fills every slot at its level
## and Off clears it.
##   Godot_console.exe --headless --path . res://tests/run_log_probe.tscn

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
	settings.spawning = false
	settings.stage_events = false
	settings.fish_attack = FishAttack.Kind.BITE
	settings.twists = false
	settings.enemy_speed_scale = 0.0
	settings.card_choices = 3
	settings.cards_pause = false
	settings.chest_count = 0
	settings.chest_interval = 0.0
	settings.heart_chance = 0.0
	settings.magnet_chance = 0.0
	settings.hourglass_chance = 0.0
	settings.lightning_chance = 0.0
	settings.run_logs = true
	settings.run_logs_keep = 3
	RunLog.dir = "user://run_logs_probe"  # never the real logs (this prunes to 3)
	RunLog.save_anywhere = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	fish.character = FishCharacter.FishClass.HUNTER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main.play_match()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	var log_of := run.run_log
	check(log_of != null and log_of.samples.is_empty() and log_of.ending.is_empty(), "a run has a fresh log")
	var far := run.centre + Vector3(0, 0, -120)

	print("samples:")
	settings.pearl_drop_chance = 1.0
	settings.chest_drop_chance = 1.0
	for n in 5:
		var zombie := run.horde.spawn(1, far + Vector3(n * 3.0, 0, 0))
		run.hit(zombie, run.horde.enemy_hp(zombie), fish, "test")
	await _ticks(2)
	settings.pearl_drop_chance = 0.0
	settings.chest_drop_chance = 0.0
	var survivor := run.horde.spawn(1, far + Vector3(0, 0, 40))
	run.elapsed = 60.0
	await _ticks(2)
	check(log_of.samples.size() == 1, "a sample at a minute (%d)" % log_of.samples.size())
	var sample: Dictionary = log_of.samples[0] if not log_of.samples.is_empty() else {}
	check(int(sample.get("kills", 0)) == 5 and int(sample.get("pearls_dropped", 0)) == 5 and int(sample.get("chests_dropped", 0)) == 5,
			"it counts the minute's kills, pearls and chests dropped (%s, %s, %s)" % [sample.get("kills"), sample.get("pearls_dropped"), sample.get("chests_dropped")])
	var expected_dps := float(run.stats_of(fish).damage) / 60.0
	check(absf(float(sample.get("dps", 0.0)) - expected_dps) < 0.2, "dps is the minute's damage / 60 (%.1f)" % float(sample.get("dps", 0.0)))
	var hp := run.horde.enemy_max_hp(survivor)
	check(absf(float(sample.get("ttk", 0.0)) - hp / expected_dps) < 0.01, "ttk is the zombies' average hp / dps (%.3f s)" % float(sample.get("ttk", 0.0)))
	check((sample.get("builds", []) as Array).size() == 1 and (sample.builds[0].weapons as Dictionary).has("attack:BITE"), "and each player's build")
	check(log_of.saved_path != "" and JSON.parse_string(FileAccess.get_file_as_string(log_of.saved_path)).get("in_progress", false),
			"a sample saves the log as it goes (in progress)")

	print("picks:")
	var levels_before := log_of.picks.size()
	run.levels.add(run.levels.xp_to_next() + 1.0)
	await _ticks(2)
	var offer := run.offer_of(fish)
	check(not offer.is_empty(), "a level's cards are up")
	run.pick(fish, 0)
	await _ticks(1)
	check(log_of.picks.size() == levels_before + 1 and str(log_of.picks[-1].card) != "", "the pick is logged (%s)" % (log_of.picks[-1].card if not log_of.picks.is_empty() else "-"))
	while not run.offer_of(fish).is_empty():
		run.pick(fish, 0)
		await _ticks(1)

	print("the end:")
	var biter := run.horde.spawn(1, far + Vector3(0, 0, 20), Vector3.ZERO, true)
	var health := run.health_of(fish)
	health.iframes_left = 0.0
	health.hp = 1.0
	run.hurt(fish, 1000.0, biter)
	await _ticks(2)
	check(log_of.ending.get("outcome", "") == "down", "going down ends the log (%s)" % log_of.ending.get("outcome", "-"))
	check(str(log_of.ending.get("cause", "")).begins_with("elite "), "with what did it (%s)" % log_of.ending.get("cause", "-"))
	check(log_of.saved_path != "" and FileAccess.file_exists(log_of.saved_path), "saved to %s" % log_of.saved_path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(log_of.saved_path)) if log_of.saved_path != "" else null
	check(parsed is Dictionary and (parsed.samples as Array).size() >= 1 and parsed.ending.outcome == "down", "the file holds the samples and the ending")
	# Pruning: make more old files than run_logs_keep, then save again.
	for n in 4:
		var stale := FileAccess.open("%s/run_0000-00-0%d_00-00-00.json" % [RunLog.dir, n], FileAccess.WRITE)
		stale.store_string("{}")
		stale.close()
	log_of.save()
	var left := Array(DirAccess.get_files_at(RunLog.dir)).filter(func(f: String) -> bool: return f.begins_with("run_") and f.ends_with(".json"))
	check(left.size() == settings.run_logs_keep and log_of.saved_path.get_file() in left, "only the newest %d stay (%d)" % [settings.run_logs_keep, left.size()])
	run.start()
	await _ticks(2)
	check(run.run_log.samples.is_empty() and run.run_log.ending.is_empty(), "a restart starts a fresh log")

	print("tank presets:")
	main.set_mode(main.TEST_TANK)
	await _ticks(3)
	main.play_match()
	await _ticks(5)
	var tank_run: UnnaturalRun = main.unnatural_run
	check(tank_run.run_log == null, "the Test Tank keeps no log")
	var powerups := PowerupSettings.shared()
	settings.weapon_slots = 3
	settings.tome_slots = 2
	settings.tank_preset = 2  # Full slots Lv 10
	await _ticks(3)
	var loadout := tank_run.loadout_of(fish)
	check(powerups.attack_level == 10 and powerups.fire_stacks == 10 and powerups.jelly_stacks == 10 and powerups.charge_stacks == 0,
			"weapon slots full at Lv 10 (attack, Greek Fire, Halo)")
	check(loadout.level(Weapons.ATTACK) == 10 and tank_run.powerups_of(fish).stacks("attack_greek_fire") > 0, "and the run has them")
	var damage := StatBlock.amount("damage", 10.0)
	check(is_equal_approx(settings.tank_damage, damage) and settings.tank_attack_speed > 0.0 and settings.tank_size == 0.0,
			"tome slots full: Teeth and Tides at 10 cards (+%.0f%% damage)" % (damage * 100.0))
	check(is_equal_approx(tank_run.block_of(fish).value("damage"), damage), "on the player's stats")
	settings.tank_preset = 0
	await _ticks(3)
	check(powerups.attack_level == 0 and powerups.fire_stacks == 0 and settings.tank_damage == 0.0, "Off clears it")
	settings.weapon_slots = 2

	settings.run_logs_keep = 50
	RunLog.dir = RunLog.DIR
	RunLog.save_anywhere = false
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
