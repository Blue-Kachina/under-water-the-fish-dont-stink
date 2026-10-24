extends Node
## Modes and presets: each mode builds its environment (and 1v1 its match);
## the mode picker's start_mode starts a match with no card (afresh when
## picked again); Replays sets the live fish aside and shows the replay bar
## with nothing loaded, loads a replay, and closing goes back to the mode
## before. Then Save/Load of a preset file (defaults under a partial preset),
## the shipped Water preset copied to the presets folder, and the settings'
## sections and Game, Display and Controls options.
##   Godot_console.exe --headless --path . res://tests/modes_probe.tscn

const FIXTURE := "res://tests/fixtures/replay_fixture.rlreplay.json"

var main: Node
var panel: Node
var fish: FishController
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	panel = main.get_node("DebugPanel")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	print("modes:")
	var tiled: Array = main.MODES.filter(func(mode: String) -> bool: return main.MODE_TILES.has(mode))
	check(tiled.size() == main.MODES.size() - 1 and not main.MODE_TILES.has(main.REPLAYS), "every mode but Replays has a picker tile")
	for mode: String in [main.FREE_SWIM, main.OBSTACLE_COURSE, main.ONE_V_ONE, main.FREE_PLAY]:
		main.set_mode(mode)
		await _frames(3)
		check(main.current_environment == main.MODE_ENVIRONMENTS[mode], "%s plays in %s" % [mode, main.current_environment])
		check(main.match_1v1 == null, "%s: no match yet" % mode)
		check((main._match_card != null) == (mode == main.ONE_V_ONE), "%s: match card only in 1v1" % mode)
		check(fish.visible == (mode != main.ONE_V_ONE), "%s: fish sits out only on the match card" % mode)

	print("start_mode (the mode picker):")
	main.start_mode(main.ONE_V_ONE)
	await _frames(3)
	check(main._match_card == null and main.match_1v1 != null and fish.visible, "a match mode starts straight away, no card")
	var first: Match1v1 = main.match_1v1
	main.start_mode(main.ONE_V_ONE)
	await _frames(3)
	check(main.match_1v1 != null and main.match_1v1 != first and main._match_card == null, "picking it again starts it afresh")
	main.start_mode(main.FREE_PLAY)
	await _frames(3)
	check(main.match_1v1 == null and main.current_mode == main.FREE_PLAY and fish.visible, "Free Play from a match: just playing")

	print("match card:")
	main.set_mode(main.ONE_V_ONE)
	await _frames(3)
	check(main._match_card != null and main.match_1v1 == null and not fish.visible, "1v1 waits on its card, fish sitting out")
	main._match_card.play_requested.emit()
	await _frames(3)
	check(main._match_card == null and main.match_1v1 != null and fish.visible, "Play starts the match, fish back")
	main.set_mode(main.FREE_PLAY)
	await _frames(3)
	main.set_mode(main.ONE_V_ONE)
	await _frames(3)
	main.set_mode(main.FREE_SWIM)  # off the card into another environment
	await _frames(3)
	check(main._match_card == null and main.match_1v1 == null and fish.visible and main.current_environment == "Ocean",
			"leaving from the card: card gone, fish back, in the Ocean")
	main.set_mode(main.ONE_V_ONE)
	await _frames(3)
	main.set_mode(main.REPLAYS)
	await _frames(3)
	check(main._match_card == null and not fish.visible and main._replay_controls != null, "card to Replays: card gone, fish still out")
	main.set_mode(main.ONE_V_ONE)
	await _frames(3)
	check(main._match_card != null and main.match_1v1 == null and not fish.visible, "Replays back to 1v1: on the card again")
	main.set_mode(main.FREE_PLAY)
	await _frames(3)

	print("replays:")
	main.set_mode(main.OBSTACLE_COURSE)
	await _frames(3)
	main.set_mode(main.REPLAYS)
	await _frames(3)
	var bar: ReplayControls = main._replay_controls
	check(main.current_environment == "Aquarium Arena", "Replays is in the Aquarium")
	check(not fish.visible and fish.process_mode == Node.PROCESS_MODE_DISABLED, "live fish set aside")
	check(bar != null and bar.player == null and bar._message != null, "replay bar shown, empty, with a hint")
	main.load_replay(ProjectSettings.globalize_path(FIXTURE))
	for i in 600:
		if main.replay:
			break
		await get_tree().process_frame
	check(main.replay != null and main._replay_controls.player == main.replay, "a replay loads into the bar")
	main._replay_controls.close_requested.emit()
	await _frames(3)
	check(main.current_mode == main.OBSTACLE_COURSE and main.current_environment == "Obstacle Course", "Close goes back to the mode before")
	check(main.replay == null and main._replay_controls == null and fish.visible, "replay and bar gone, fish back")
	main.load_replay(ProjectSettings.globalize_path(FIXTURE))
	check(main.current_mode == main.REPLAYS, "loading a replay from another mode switches to Replays")
	for i in 600:
		if main.replay:
			break
		await get_tree().process_frame
	main.set_mode(main.FREE_PLAY)
	await _frames(3)
	check(main.replay == null and main._replay_controls == null and fish.visible and main.current_mode == main.FREE_PLAY,
			"picking another mode leaves Replays")

	print("presets:")
	var water := ProjectSettings.globalize_path(panel.PRESET_DIR.path_join("water.cfg"))
	check(FileAccess.file_exists(water), "Water preset exported to %s" % water)
	var settings := ConfigFile.new()
	settings.load(panel.SETTINGS_PATH)
	var remembered: String = settings.get_value("tuning", "preset", "")
	var path := ProjectSettings.globalize_path("user://modes_probe_preset.cfg")
	fish.max_speed = 33.0
	panel._save_preset(path)
	panel._restore_defaults()
	check(fish.max_speed != 33.0, "Default puts max_speed back (%.2f)" % fish.max_speed)
	panel._load_preset(path)
	check(is_equal_approx(fish.max_speed, 33.0), "a saved preset loads back (%.2f)" % fish.max_speed)
	var default_fov: float = panel._defaults["camera"]["field_of_view"]
	main.get_node("FollowCamera").field_of_view = 60.0
	panel._load_preset(water)
	check(is_equal_approx(fish.max_speed, 35.0), "Water applies its values (%.2f)" % fish.max_speed)
	check(is_equal_approx(main.get_node("FollowCamera").field_of_view, 125.0), "Water's camera")
	settings.clear()
	settings.load(panel.SETTINGS_PATH)
	check(settings.get_value("tuning", "preset", "") == water, "the last preset loaded is remembered")
	settings.set_value("tuning", "preset", remembered)
	settings.save(panel.SETTINGS_PATH)  # don't leave the probe's pick behind
	DirAccess.remove_absolute(path)
	panel._restore_defaults()
	check(is_equal_approx(main.get_node("FollowCamera").field_of_view, default_fov), "Default camera back")

	print("game section:")
	var sections: Array = panel._section_buttons.keys()
	check(sections == ["game", "display", "audio", "controls", "camera", "fish", "gaits", "ball", "nature", "unnatural", "powerups"],
			"the settings' sections: %s" % [sections])
	for key: String in ["game/player_name", "game/character", "game/goal_replays", "game/preset_save", "display/fullscreen",
			"display/show_stats", "display/show_input_overlay", "controls/profile"]:
		check(panel._rows.has(key), "%s has a row" % key)

	print("modes_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
