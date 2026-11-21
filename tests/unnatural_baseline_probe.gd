extends Node
## Unnatural as a migrating mode (planning_core_roadmap.md 3.3, item 3), step H0: a scripted,
## seeded run through the real game that records coarse snapshots of the mode's seams
## (card, Play, run state, survivor cam, HUD attach, tuning, Test Tank, leaving) to
## tests/fixtures/unnatural_baseline.json. Every migration step must keep it matching.
## Spawning is off and the director quiet so the rows don't depend on a frame landing a tick
## either side; counts, flags and tuning only.
##   Godot_console.exe --headless --path . res://tests/unnatural_baseline_probe.tscn
##   ... -- --record    rewrite the fixture

const BASELINE := "res://tests/fixtures/unnatural_baseline.json"

var main: Node
var fish: FishController
var camera: Node
var failures := 0
var snaps: Array[Dictionary] = []
var record := false


func _ready() -> void:
	seed(20261121)
	record = "--record" in OS.get_cmdline_args() or "--record" in OS.get_cmdline_user_args()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	settings.spawning = false
	settings.card_choices = 0
	settings.twists = true
	fish.character = FishCharacter.FishClass.HUNTER
	print("card:")
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	var max_speed_before := fish.max_speed
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	check(main.current_environment == "Ocean", "Unnatural plays in the Ocean")
	check(main._match_card != null and main.unnatural_run == null and not fish.visible, "waits on its card, fish sitting out")
	_snap("card")

	print("run:")
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	check(run != null and main._match_card == null and fish.visible, "Play starts the run, fish back")
	check(run.authority and not run.test_tank and run.players == [fish], "the world's run, one player, not the tank")
	check(main._playing_mode() == main.UNNATURAL and main._reset_label() == "Restart run", "playing mode and reset label")
	check(is_equal_approx(main.get_node("Ocean").boundary_radius, settings.arena_radius), "the ocean's edge is the arena's")
	check(bool(camera.get("steady_heading")) == settings.steady_camera and not camera.ball_cam and camera.ball == null, "survivor cam on, no ball cam")
	_snap("run_start")

	print("hurt:")
	var health := run.health_of(fish)
	var hp_before := health.hp
	check(run.hurt(fish, 10.0, -1, "probe") and is_equal_approx(health.hp, hp_before - 10.0), "a hit takes 10 hp")
	_snap("hurt")
	health.iframes_left = 0.0
	run.hurt(fish, 9999.0, -1, "probe")
	await _ticks(3)
	check(run.is_over or health.down, "no hp left: down or over")
	_snap("down")

	print("restart:")
	main.reset_play()
	await _ticks(5)
	check(not run.is_over and not health.down and is_equal_approx(health.hp, health.max_hp), "R starts the run again at full hp")
	_snap("restarted")

	print("test tank:")
	main.set_mode(main.TEST_TANK)
	await _ticks(3)
	if main._match_card != null:
		main._match_card.play_requested.emit()
		await _ticks(5)
	var tank_run: UnnaturalRun = main.unnatural_run
	check(tank_run != null and tank_run.test_tank, "the Test Tank is a test_tank run")
	check(main._playing_mode() == main.TEST_TANK and main._reset_label() == "Reset the tank", "Test Tank's mode id and reset label")
	_snap("tank")

	print("leaving:")
	main.set_mode(main.FREE_SWIM)
	await _ticks(5)
	check(main.unnatural_run == null, "leaving ends the run")
	check(not bool(camera.get("steady_heading")), "the survivor cam comes off")
	check(is_equal_approx(fish.max_speed, max_speed_before), "the tuning from before is back")
	check(is_equal_approx(fish.speed_scale, 1.0) and not fish.controls_locked and fish.visible, "the fish is the player's again")
	_snap("left")

	_finish_baseline()
	print("unnatural_baseline_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


func _snap(label: String) -> void:
	var run: UnnaturalRun = main.unnatural_run
	var slot0: PlayerSlot = main._local.slots[0]
	var row := {
		"at": label,
		"mode": main.current_mode,
		"playing_mode": main._playing_mode(),
		"run": run != null,
		"card": main._match_card != null,
		"fish_visible": fish.visible,
		"swim_style": FishController.SwimStyle.keys()[fish.swim_style],
		"boost_enabled": fish.boost_enabled,
		"locked": fish.controls_locked,
		"camera_steady": bool(camera.get("steady_heading")),
		"camera_ball": camera.ball != null,
		"camera_ball_cam": camera.ball_cam,
		"hud_survivor_cam": main._hud.survivor_cam,
		"slot0_mode_hud": slot0.mode_hud != null and is_instance_valid(slot0.mode_hud),
		"reset_label": main._reset_label(),
		"split_players": main._local.slots.size(),
		"local_run": main._local.run != null and is_instance_valid(main._local.run),
		"boundary": snappedf(main.get_node("Ocean").boundary_radius, 0.01),
	}
	if label == "card":
		# The host's mode lists and the picker's tile order: registering the mode must not move them.
		row["modes"] = Array(main.MODES)
		row["match_modes"] = Array(main.MATCH_MODES)
		row["nature_modes"] = Array(main.NATURE_MODES)
		row["tile_order"] = Array(main.MODE_TILES.keys())
		row["tile_title"] = main.MODE_TILES[main.UNNATURAL].title
		row["tank_title"] = main.MODE_TILES[main.TEST_TANK].title
		row["environment"] = main.mode_environment(main.UNNATURAL)
		row["card_text"] = main._match_card_text(main.UNNATURAL).left(40)
	if run != null:
		var health := run.health_of(fish)
		row["test_tank"] = run.test_tank
		row["authority"] = run.authority
		row["players"] = run.players.size()
		row["stage"] = run.stage
		row["level"] = run.levels.level
		row["hp"] = snappedf(health.hp, 0.01)
		row["max_hp"] = snappedf(health.max_hp, 0.01)
		row["down"] = health.down
		row["is_over"] = run.is_over
		row["kills"] = run.kills
		row["horde"] = run.horde != null
		row["seabed"] = run.seabed != null and run.seabed.get_child_count() > 0
		row["moon"] = run.blood_moon != null
		row["attack"] = run.attack_of(fish) != null
		row["twist"] = run.twist_of(fish) != null
		row["hud_run"] = slot0.mode_hud != null and slot0.mode_hud.get("run") == run
	snaps.append(row)


func _finish_baseline() -> void:
	var path := ProjectSettings.globalize_path(BASELINE)
	if record:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var out := FileAccess.open(path, FileAccess.WRITE)
		out.store_string(JSON.stringify({"snaps": snaps}, "\t", true))
		out.close()
		print("  baseline recorded: %s (%d snapshots)" % [path, snaps.size()])
		return
	if not FileAccess.file_exists(BASELINE):
		check(false, "no baseline at %s (run with --record)" % BASELINE)
		return
	var want: Array = JSON.parse_string(FileAccess.get_file_as_string(BASELINE)).snaps
	var got: Array = JSON.parse_string(JSON.stringify({"snaps": snaps})).snaps
	var bad := 0
	for i in maxi(want.size(), got.size()):
		var a: Variant = want[i] if i < want.size() else null
		var b: Variant = got[i] if i < got.size() else null
		if a != b:
			bad += 1
			print("    baseline differs: want %s got %s" % [a, b])
	check(bad == 0, "matches unnatural_baseline.json (%d snapshots)" % snaps.size())
