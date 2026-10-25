extends Node
## The console (Console): ` opens it, ` or Esc closes it; while it's open the
## InputMap's bindings are off (and given back after) and the game's paused;
## typing echoes an unknown command; the Konami code from the D-pad, the left
## stick or the arrow keys sets UISettings.konami_entered. Then the mode
## picker's hidden modes (Fish Sticks, the Test Tank: SELECT once the code's
## in) and the Obstacle Course on Unnatural's tuning and survivor cam.
## Puts the player's own konami_entered / show_hidden_modes back after.
##   Godot_console.exe --headless --path . res://tests/console_probe.tscn

var main: Node
var failures := 0
var _saved := {}


func _ready() -> void:
	for key: String in ["konami_entered", "show_hidden_modes"]:
		_saved[key] = UISettings.get(key)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _key(keycode: Key, unicode := 0) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.unicode = unicode
		event.pressed = pressed
		get_viewport().push_input(event)


func _pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		get_viewport().push_input(event)


func _stick(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	get_viewport().push_input(event)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	await _frames(3)
	UISettings.set_value("konami_entered", false)
	UISettings.set_value("show_hidden_modes", false)
	var bindings := InputMap.action_get_events("thrust_forward").size()

	print("console:")
	check(not Console.is_open(), "closed to begin with")
	_key(KEY_QUOTELEFT)
	await _frames(2)
	check(Console.is_open(), "` opens it")
	check(InputMap.action_get_events("thrust_forward").is_empty() and InputMap.action_get_events("ui_accept").is_empty(),
			"while it's open the actions have no bindings")
	check(get_tree().paused, "and the game's paused")
	check(Console.get_parent().get_child(-1) == Console, "it's the root's last child: first to see input")
	for c in "hi":
		_key(KEY_H if c == "h" else KEY_I, c.unicode_at(0))
	_key(KEY_ENTER)
	check(Console._log.text.contains("> hi") and Console._log.text.contains("Unknown command: hi"), "typing echoes an unknown command")
	check(Console._typed == "", "and clears the line")
	_key(KEY_ESCAPE)
	await _frames(1)
	check(not Console.is_open(), "Esc closes it")
	check(InputMap.action_get_events("thrust_forward").size() == bindings and bindings > 0, "the bindings are back")
	check(not get_tree().paused, "and the game's unpaused")
	_key(KEY_QUOTELEFT)
	_key(KEY_QUOTELEFT)
	check(not Console.is_open(), "` again closes it too")

	print("konami code:")
	_key(KEY_QUOTELEFT)
	for button: JoyButton in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN,
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A]:
		_pad(button)
	check(Console._konami.progress() == 9 and not UISettings.konami_entered, "the D-pad and B (the bottom face button) count: nine in")
	check(Console.is_open(), "its press did nothing else (no ui_accept while it's open)")
	_pad(JOY_BUTTON_B)
	check(UISettings.konami_entered, "A (the right face button) finishes it: konami_entered")
	UISettings.set_value("konami_entered", false)
	for pair: Array in [[JOY_AXIS_LEFT_Y, -1.0], [JOY_AXIS_LEFT_Y, 1.0], [JOY_AXIS_LEFT_Y, 1.0], [JOY_AXIS_LEFT_X, -1.0],
			[JOY_AXIS_LEFT_X, 1.0], [JOY_AXIS_LEFT_X, -1.0], [JOY_AXIS_LEFT_X, 1.0]]:
		_stick(pair[0], pair[1])
		_stick(pair[0], 0.0)
	check(Console._konami.progress() == 0, "the stick: a held-wrong sequence (one Up) doesn't count")
	_stick(JOY_AXIS_LEFT_Y, -0.9)
	_stick(JOY_AXIS_LEFT_Y, -1.0)  # still pushed: not a second Up
	_stick(JOY_AXIS_LEFT_Y, 0.0)
	_stick(JOY_AXIS_LEFT_Y, -1.0)
	_stick(JOY_AXIS_LEFT_Y, 0.0)
	for pair: Array in [[JOY_AXIS_LEFT_Y, 1.0], [JOY_AXIS_LEFT_Y, 1.0], [JOY_AXIS_LEFT_X, -1.0], [JOY_AXIS_LEFT_X, 1.0],
			[JOY_AXIS_LEFT_X, -1.0], [JOY_AXIS_LEFT_X, 1.0]]:
		_stick(pair[0], pair[1])
		_stick(pair[0], 0.0)
	check(Console._konami.progress() == 8, "the left stick counts once per push")
	_key(KEY_B, "b".unicode_at(0))
	_key(KEY_A, "a".unicode_at(0))
	check(UISettings.konami_entered, "and B A on the keyboard finish it")
	UISettings.set_value("konami_entered", false)
	Console._typed = ""
	for keycode: Key in [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT]:
		_key(keycode)
	_key(KEY_B, "b".unicode_at(0))
	_key(KEY_A, "a".unicode_at(0))
	check(UISettings.konami_entered, "the arrow keys count too")
	_key(KEY_ESCAPE)
	await _frames(1)

	print("hidden modes:")
	var layer := CanvasLayer.new()
	add_child(layer)
	var picker := ModePicker.new()
	layer.add_child(picker)
	await _frames(1)
	UISettings.set_value("konami_entered", false)
	picker.open(main.MODE_TILES, main.TEST_TANK, Callable())
	await _frames(1)
	var modes := func() -> Array:
		var shown := []
		for tile: ModePicker.Tile in [picker._featured] + picker._grid + picker._more:
			if tile.visible and tile.mode:
				shown.append(tile.mode)
		return shown
	var shown: Array = modes.call()
	check(not shown.has("Fish Sticks") and not shown.has(main.TEST_TANK), "hidden by default: no Fish Sticks, no Test Tank (%s)" % [shown])
	check(picker._featured.mode == "Unnatural", "the Test Tank last played: Unnatural's featured instead")
	check(not picker._grid[3].visible and picker._grid[2].size.x > picker._grid[1].size.x * 1.5, "three singles: the bottom one takes the row")
	check(not picker._more_label.visible, "no MORE row")
	_pad(JOY_BUTTON_BACK)
	await _frames(1)
	check(not modes.call().has(main.TEST_TANK) and not UISettings.show_hidden_modes, "SELECT does nothing before the Konami code")
	UISettings.set_value("konami_entered", true)
	picker.open(main.MODE_TILES, "Hunt", Callable())
	await _frames(1)
	_pad(JOY_BUTTON_BACK)
	await _frames(1)
	shown = modes.call()
	check(UISettings.show_hidden_modes and shown.has("Fish Sticks") and shown.has(main.TEST_TANK), "after it, SELECT shows them (%s)" % [shown])
	check(picker._grid[3].visible and picker._more_label.visible, "the full wall and the MORE row back")
	_pad(JOY_BUTTON_BACK)
	await _frames(1)
	check(not UISettings.show_hidden_modes and not modes.call().has("Fish Sticks"), "and SELECT again hides them")
	layer.queue_free()

	print("obstacle course:")
	var camera: Node = main.get_node("FollowCamera")
	var fish: FishController = main.get_node("Fish")
	main.set_mode(main.OBSTACLE_COURSE, false)
	await _frames(3)
	check(camera.steady_heading, "the survivor cam (steady heading)")
	check(camera.extra_distance == UnnaturalSettings.shared().camera_distance, "at Unnatural's camera distance")
	check(not fish.boost_enabled and fish.swim_strokes, "Unnatural's tuning: strides, no boost")
	main.set_mode(main.FREE_PLAY, false)
	await _frames(3)
	check(not camera.steady_heading and fish.boost_enabled, "Free Play: the usual camera and tuning back")

	for key: String in _saved:
		UISettings.set_value(key, _saved[key])
	print("failures: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)
