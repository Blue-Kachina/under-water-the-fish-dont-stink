extends Node
## Registers the playground's input actions (autoloaded as "Controls") and
## swaps controller button profiles at runtime.
##
## Sticks, triggers and keyboard keys are the same in every profile; a profile
## only decides which controller buttons trigger which actions. The chosen
## profile is remembered per machine in user://controls.cfg, so testers start
## on "Default" unless they pick something else.

signal profile_changed(profile: String)

const DEADZONE_STICK := 0.15
const DEADZONE_TRIGGER := 0.05
const DEADZONE_BUTTON := 0.5
const SETTINGS_PATH := "user://controls.cfg"

## Profile name -> { action: controller button }. Actions a profile leaves out
## have no controller button in it (they still work from the keyboard).
const PROFILES := {
	# Rocket League defaults. Powerslide gets its own button because RL's shared
	# powerslide/air-roll button depends on being on the ground.
	"Default": {
		"jump": JOY_BUTTON_A,
		"boost": JOY_BUTTON_B,
		"air_roll": JOY_BUTTON_X,
		"ball_cam": JOY_BUTTON_Y,
		"powerslide": JOY_BUTTON_LEFT_STICK,  # Y is ball cam, as in RL
		"roll_left": JOY_BUTTON_LEFT_SHOULDER,
		"roll_right": JOY_BUTTON_RIGHT_SHOULDER,
		"direction_lock": JOY_BUTTON_RIGHT_STICK,  # every face/shoulder button is taken
	},
	# Pro player BeastMode's binds (PlayStation layout: Cross = A, Circle = B,
	# Square = X, Triangle = Y): one button for powerslide and air roll, as RL's
	# shared "Powerslide / Air Roll", and directional air roll left only.
	"BeastMode": {
		"jump": JOY_BUTTON_A,
		"boost": JOY_BUTTON_B,
		"powerslide": JOY_BUTTON_X,
		"air_roll": JOY_BUTTON_X,
		"ball_cam": JOY_BUTTON_Y,
		"roll_left": JOY_BUTTON_LEFT_SHOULDER,
	},
	# Directional air roll on face buttons, powerslide on LB, boost on RB.
	"Personal": {
		"jump": JOY_BUTTON_A,
		"roll_right": JOY_BUTTON_B,
		"roll_left": JOY_BUTTON_X,
		"powerslide": JOY_BUTTON_LEFT_SHOULDER,
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

var current_profile := "Default"


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

	_button("reset", JOY_BUTTON_START, [KEY_R])
	_button("toggle_panel", JOY_BUTTON_BACK, [KEY_F1, KEY_TAB])

	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		current_profile = settings.get_value("controls", "profile", current_profile)
	apply_profile(current_profile, false)


func profile_names() -> Array:
	return PROFILES.keys()


func apply_profile(profile: String, remember := true) -> void:
	if not PROFILES.has(profile):
		profile = "Default"
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


func _add_keys(action: StringName, keys: Array) -> void:
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _reset_action(action: StringName, deadzone: float) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, deadzone)
