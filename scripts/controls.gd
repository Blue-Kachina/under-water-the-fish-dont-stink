extends Node
## Registers the playground's input actions (autoloaded as "Controls") and
## swaps controller button profiles at runtime.
##
## Sticks, triggers and keyboard keys are the same in every profile; a profile
## only decides which controller buttons trigger which actions. The chosen
## profile is remembered per machine in user://controls.cfg, so testers start
## on DEFAULT_PROFILE unless they pick something else. (The panel's profile
## picker is hidden for now; apply_profile() still switches.)

signal profile_changed(profile: String)

const DEADZONE_STICK := 0.15
const DEADZONE_TRIGGER := 0.05
const DEADZONE_BUTTON := 0.5
const SETTINGS_PATH := "user://controls.cfg"
const DEFAULT_PROFILE := "Personal"

## Profile name -> { action: controller button }. Actions a profile leaves out
## have no controller button in it (they still work from the keyboard).
const PROFILES := {
	# Directional air roll on face buttons, boost on RB, and LB as RL's shared
	# "Powerslide / Air Roll": powerslide on a surface, free air roll off it.
	"Personal": {
		"jump": JOY_BUTTON_A,
		"roll_right": JOY_BUTTON_B,
		"roll_left": JOY_BUTTON_X,
		"powerslide": JOY_BUTTON_LEFT_SHOULDER,
		"air_roll": JOY_BUTTON_LEFT_SHOULDER,
		"boost": JOY_BUTTON_RIGHT_SHOULDER,
		"ball_cam": JOY_BUTTON_Y,
	},
}

## Keyboard keys for every button action, identical across profiles.
const BUTTON_KEYS := {
	"jump": [KEY_SPACE],
	"boost": [KEY_SHIFT],
	"air_roll": [KEY_C],
	"powerslide": [KEY_CTRL],
	"roll_left": [KEY_Q],
	"roll_right": [KEY_E],
	"direction_lock": [KEY_F],
	"ball_cam": [KEY_Y],
}

var current_profile := DEFAULT_PROFILE


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

	_keys("reset", [KEY_R])  # on a controller: the pause menu's reset option
	# The pause menu (PauseMenu), where the tuning panel is.
	_button("pause", JOY_BUTTON_START, [KEY_ESCAPE, KEY_F1])
	# Godot's ui_ actions are keyboard-only: the controller for menus (the pause
	# menu, the match card's Play).
	_add_button("ui_accept", JOY_BUTTON_A)
	_add_button("ui_cancel", JOY_BUTTON_B)
	_add_button("ui_up", JOY_BUTTON_DPAD_UP)
	_add_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	# Held: the 1v1's scoreboard (RL's is on Tab, which the panel has).
	_button("show_scoreboard", JOY_BUTTON_DPAD_UP, [KEY_B])

	# Replay playback (only while a replay plays; the jump button also plays and
	# pauses, and boost switches the Camera between Player and Director).
	_keys("replay_play_pause", [KEY_P])
	_button("replay_back", JOY_BUTTON_DPAD_LEFT, [KEY_COMMA])
	_button("replay_forward", JOY_BUTTON_DPAD_RIGHT, [KEY_PERIOD])
	_button("replay_next_target", JOY_BUTTON_DPAD_UP, [KEY_T])
	_button("replay_previous_target", JOY_BUTTON_DPAD_DOWN, [KEY_G])
	_keys("replay_previous_goal", [KEY_BRACKETLEFT])
	_keys("replay_next_goal", [KEY_BRACKETRIGHT])
	_keys("replay_slower", [KEY_MINUS])
	_keys("replay_faster", [KEY_EQUAL])
	_keys("replay_hitboxes", [KEY_H])
	_keys("replay_camera", [KEY_V])

	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		current_profile = settings.get_value("controls", "profile", current_profile)
	apply_profile(current_profile, false)


func profile_names() -> Array:
	return PROFILES.keys()


func apply_profile(profile: String, remember := true) -> void:
	if not PROFILES.has(profile):
		profile = DEFAULT_PROFILE
	current_profile = profile
	var buttons: Dictionary = PROFILES[profile]
	for action: String in BUTTON_KEYS:
		_reset_action(action, DEADZONE_BUTTON)
		if buttons.has(action):
			var event := InputEventJoypadButton.new()
			event.device = -1
			event.button_index = buttons[action]
			InputMap.action_add_event(action, event)
		_add_keys(action, BUTTON_KEYS[action])

	if remember:
		var settings := ConfigFile.new()
		settings.set_value("controls", "profile", profile)
		settings.save(SETTINGS_PATH)
	profile_changed.emit(profile)


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


## Adds `button` to an existing action, keeping its other events.
func _add_button(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	InputMap.action_add_event(action, event)


func _keys(action: StringName, keys: Array) -> void:
	_reset_action(action, DEADZONE_BUTTON)
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
