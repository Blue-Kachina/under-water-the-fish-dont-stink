extends Node
## Registers the playground's input actions at startup (autoloaded as "Controls").
##
## Bindings live here rather than in Project Settings so that swappable
## Rocket League-style binding profiles can be added in one place later.
## Xbox defaults mirror Rocket League: RT/LT throttle, A jump, B boost, X air roll.

const DEADZONE_STICK := 0.15
const DEADZONE_TRIGGER := 0.05
const DEADZONE_BUTTON := 0.5


func _enter_tree() -> void:
	_axis("thrust_forward", JOY_AXIS_TRIGGER_RIGHT, 1.0, [KEY_W], DEADZONE_TRIGGER)
	_axis("thrust_reverse", JOY_AXIS_TRIGGER_LEFT, 1.0, [KEY_S], DEADZONE_TRIGGER)

	_axis("stick_left", JOY_AXIS_LEFT_X, -1.0, [KEY_A, KEY_LEFT])
	_axis("stick_right", JOY_AXIS_LEFT_X, 1.0, [KEY_D, KEY_RIGHT])
	_axis("stick_up", JOY_AXIS_LEFT_Y, -1.0, [KEY_UP])
	_axis("stick_down", JOY_AXIS_LEFT_Y, 1.0, [KEY_DOWN])

	_axis("camera_left", JOY_AXIS_RIGHT_X, -1.0, [KEY_J])
	_axis("camera_right", JOY_AXIS_RIGHT_X, 1.0, [KEY_L])
	_axis("camera_up", JOY_AXIS_RIGHT_Y, -1.0, [KEY_I])
	_axis("camera_down", JOY_AXIS_RIGHT_Y, 1.0, [KEY_K])

	_button("jump", JOY_BUTTON_A, [KEY_SPACE])
	_button("boost", JOY_BUTTON_B, [KEY_SHIFT])
	_button("air_roll", JOY_BUTTON_X, [KEY_C])
	# Rocket League shares powerslide with air roll; underwater there's no ground
	# to tell them apart, so it gets its own button (Y is ball cam in RL).
	_button("powerslide", JOY_BUTTON_Y, [KEY_CTRL])
	_button("roll_left", JOY_BUTTON_LEFT_SHOULDER, [KEY_Q])
	_button("roll_right", JOY_BUTTON_RIGHT_SHOULDER, [KEY_E])

	_button("reset", JOY_BUTTON_START, [KEY_R])
	_button("toggle_panel", JOY_BUTTON_BACK, [KEY_F1, KEY_TAB])


func _axis(action: StringName, axis: JoyAxis, direction: float, keys: Array, deadzone := DEADZONE_STICK) -> void:
	_reset_action(action, deadzone)
	var event := InputEventJoypadMotion.new()
	event.device = -1  # any controller
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)
	_add_keys(action, keys)


func _button(action: StringName, button: JoyButton, keys: Array) -> void:
	_reset_action(action, DEADZONE_BUTTON)
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	InputMap.action_add_event(action, event)
	_add_keys(action, keys)


func _add_keys(action: StringName, keys: Array) -> void:
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _reset_action(action: StringName, deadzone: float) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, deadzone)
