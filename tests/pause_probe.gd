extends Node
## The pause menu: Start pauses (the fish holds still) and shows Resume, the
## mode's reset and Settings; the settings only show from Settings, B steps
## back out of them to the menu, and they hide on resuming. Main menu goes to
## the home screen (B back to the game, or a mode picked starts it). Start again, B (on release) or Resume (on release, so the
## A press is over) carries on; Esc pauses without its release resuming. View
## (Select) no longer does anything. The reset option follows the mode (none on
## the match card or in Replays) and resets the fish.
##   Godot_console.exe --headless --path . res://tests/pause_probe.tscn

var main: Node
var menu: PauseMenu
var panel: Node
var fish: FishController
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	panel = main.get_node("DebugPanel")
	menu = main.get_node("PauseMenu")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	main.set_mode(main.FREE_PLAY)
	await _frames(10)
	print("start:")
	check(not panel.is_open() and not get_tree().paused, "panel hidden and game running at the start")
	await _button(JOY_BUTTON_BACK)
	check(not panel.is_open() and not get_tree().paused, "View/Select does nothing")

	await _button(JOY_BUTTON_START)
	check(get_tree().paused and menu.is_open(), "Start pauses and shows the menu")
	check(not panel.is_open(), "settings panel not shown until Settings")
	check(menu._resume.has_focus(), "Resume picked")
	check(menu._reset.visible and menu._reset.text == "Reset", "Free Play's reset: %s" % menu._reset.text)
	await _button(JOY_BUTTON_DPAD_DOWN)
	check(menu._reset.has_focus(), "D-pad down moves to the reset")
	await _button(JOY_BUTTON_DPAD_UP)
	check(menu._resume.has_focus(), "D-pad up back to Resume")
	var held := fish.global_position
	await _frames(20)
	check(fish.global_position.is_equal_approx(held), "fish holds still while paused")

	menu._settings.pressed.emit()
	await _frames(2)
	check(panel.is_open() and not menu._menu.visible, "Settings shows the settings (the menu steps aside)")
	check(panel.process_mode == Node.PROCESS_MODE_ALWAYS, "settings run while paused")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	check(panel.get_viewport().gui_get_focus_owner() == panel._rows["game/player_name"], "right: into the Game section's options")
	await _button(JOY_BUTTON_B)
	check(panel.is_open() and menu.is_open() and panel.get_viewport().gui_get_focus_owner() == panel._section_buttons["game"],
			"B in the settings: back a column, not out of the pause")
	await _button(JOY_BUTTON_B)
	await _frames(2)
	check(not panel.is_open() and menu.is_open() and menu._menu.visible and menu._settings.has_focus() and get_tree().paused,
			"B again closes the settings: back on the menu's Settings, still paused")
	menu._settings.pressed.emit()
	await _frames(2)
	await _button(JOY_BUTTON_START)
	check(not get_tree().paused and not menu.is_open() and not panel.is_open(), "Start resumes from the settings and hides them")

	print("cancel and accept:")
	await _key(KEY_ESCAPE)
	check(get_tree().paused and menu.is_open(), "Esc pauses, and letting go doesn't resume")
	await _press(JOY_BUTTON_B, true)
	check(menu.is_open(), "B pressed: still paused")
	await _press(JOY_BUTTON_B, false)
	check(not get_tree().paused and not menu.is_open(), "B let go: resumed")

	await _button(JOY_BUTTON_START)
	await _press(JOY_BUTTON_A, true)
	check(menu.is_open(), "A pressed on Resume: still paused")
	await _press(JOY_BUTTON_A, false)
	check(not get_tree().paused and not menu.is_open(), "A let go: resumed")

	print("reset:")
	await _frames(10)
	var spawn: Transform3D = main._environment.spawn_transform()
	fish.global_position = spawn.origin + Vector3(20.0, 6.0, 15.0)
	await _frames(3)
	await _button(JOY_BUTTON_START)
	menu._reset.pressed.emit()
	await _frames(3)
	check(not get_tree().paused and not menu.is_open(), "reset resumes")
	check(fish.global_position.distance_to(spawn.origin) < 3.0, "reset puts the fish back (%.2f from spawn)" % fish.global_position.distance_to(spawn.origin))

	print("modes:")
	main.set_mode(main.ONE_V_ONE)
	await _frames(3)
	await _button(JOY_BUTTON_START)
	check(menu.is_open() and not menu._reset.visible, "match card: no reset option")
	await _button(JOY_BUTTON_START)
	main._match_card.play_requested.emit()
	await _frames(3)
	await _button(JOY_BUTTON_START)
	check(menu._reset.visible and menu._reset.text == "Restart kickoff", "1v1: %s" % menu._reset.text)
	await _button(JOY_BUTTON_START)
	main.set_mode(main.REPLAYS)
	await _frames(3)
	await _button(JOY_BUTTON_START)
	check(menu.is_open() and not menu._reset.visible, "Replays: pauses, no reset option")

	print("main menu:")
	var home: HomeScreen = main._home
	menu._main_menu.pressed.emit()
	await _frames(3)
	check(home.is_open() and not menu.is_open() and get_tree().paused, "Main menu: the home screen, the game held behind it")
	await _button(JOY_BUTTON_START)
	check(not menu.is_open(), "Start doesn't open the pause menu over the home screen")
	await _button(JOY_BUTTON_B)
	check(not home.is_open() and not get_tree().paused, "B on the home screen (from the pause menu): back to the game")
	await _button(JOY_BUTTON_START)
	menu._main_menu.pressed.emit()
	await _frames(3)
	home.mode_chosen.emit(main.FREE_PLAY)  # picked in the mode picker
	await _frames(3)
	check(main.current_mode == main.FREE_PLAY and not home.is_open() and not get_tree().paused, "a mode picked: it's on, the game running")
	await _button(JOY_BUTTON_START)
	check(menu._reset.visible, "reset option back")
	await _button(JOY_BUTTON_START)
	check(not get_tree().paused, "resumed")

	print("pause_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## A controller button pressed then let go.
func _button(button: JoyButton) -> void:
	await _press(button, true)
	await _press(button, false)


func _press(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	await _frames(2)


func _key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
