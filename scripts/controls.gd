extends Node
## Registers the playground's input actions (autoloaded as "Controls"), swaps
## controller button profiles at runtime, and keeps the player's rebinds.
##
## Sticks, triggers and keyboard keys are the same in every profile; a profile
## only decides which controller buttons trigger which actions. The chosen
## profile is remembered per machine in user://controls.cfg, so testers start
## on DEFAULT_PROFILE unless they pick something else.
##
## Rebinds (the settings' Controls section, REBINDABLE): each action's keyboard
## and mouse binding and its controller binding can be swapped for one key,
## mouse button, controller button or stick / trigger push. They're saved in
## the same file ([bindings]) and go back on over the profile whenever it's
## applied.

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

## The actions players can rebind (the settings' Controls section), in the
## order they're listed: [action, title, group]. The menus' own buttons
## (ui_*) stay as they are, so a rebind can never lock anyone out of them.
const REBINDABLE := [
	["thrust_forward", "Throttle", "Swimming"],
	["thrust_reverse", "Reverse / brake", "Swimming"],
	["stick_left", "Steer left", "Swimming"],
	["stick_right", "Steer right", "Swimming"],
	["stick_up", "Pitch down", "Swimming"],
	["stick_down", "Pitch up", "Swimming"],
	["jump", "Jump", "Moves"],
	["boost", "Boost", "Moves"],
	["powerslide", "Powerslide", "Moves"],
	["air_roll", "Air roll", "Moves"],
	["roll_left", "Air roll left", "Moves"],
	["roll_right", "Air roll right", "Moves"],
	["direction_lock", "Direction lock", "Moves"],
	["camera_left", "Look left", "Camera"],
	["camera_right", "Look right", "Camera"],
	["camera_up", "Look up", "Camera"],
	["camera_down", "Look down", "Camera"],
	["ball_cam", "Ball cam / swap cam", "Camera"],
	["pause", "Pause", "Game"],
	["reset", "Reset", "Game"],
	["show_scoreboard", "Scoreboard (hold)", "Game"],
]

const _PAD_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_MISC1: "Share",
	JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓", JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →",
	JOY_BUTTON_PADDLE1: "Paddle 1", JOY_BUTTON_PADDLE2: "Paddle 2", JOY_BUTTON_PADDLE3: "Paddle 3", JOY_BUTTON_PADDLE4: "Paddle 4",
}
const _MOUSE_BUTTONS := {
	MOUSE_BUTTON_LEFT: "Mouse left", MOUSE_BUTTON_RIGHT: "Mouse right", MOUSE_BUTTON_MIDDLE: "Mouse middle",
	MOUSE_BUTTON_WHEEL_UP: "Wheel up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel down", MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}

## A rebind was made or undone (anything showing bindings can refresh).
signal bindings_changed

var current_profile := DEFAULT_PROFILE
## "kb/<action>" or "pad/<action>" -> the events the player picked instead of
## the defaults (saved in SETTINGS_PATH's [bindings]).
var _overrides := {}
## The same keys -> the default events (the profile's, before overrides).
var _defaults := {}


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
	_add_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	# The menus' shoulder and face buttons (HomeScreen, ModePicker, the settings):
	# LB / RB step through pages (the fish, the settings' sections), X shows a
	# mode's rules, Y puts a setting back to its default.
	_button("ui_page_previous", JOY_BUTTON_LEFT_SHOULDER, [KEY_PAGEUP])
	_button("ui_page_next", JOY_BUTTON_RIGHT_SHOULDER, [KEY_PAGEDOWN])
	_button("ui_rules", JOY_BUTTON_X, [KEY_TAB])
	_button("ui_reset", JOY_BUTTON_Y, [KEY_BACKSPACE])
	# The settings: LB / RB step through a section's tabs, LT / RT whole sections.
	_axis("ui_section_previous", JOY_AXIS_TRIGGER_LEFT, 1.0, [KEY_HOME], DEADZONE_BUTTON)
	_axis("ui_section_next", JOY_AXIS_TRIGGER_RIGHT, 1.0, [KEY_END], DEADZONE_BUTTON)
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
		if settings.has_section("bindings"):
			for key: String in settings.get_section_keys("bindings"):
				var events: Array[InputEvent] = []
				for text: String in settings.get_value("bindings", key, []):
					var event := _from_text(text)
					if event:
						events.append(event)
				if not events.is_empty():
					_overrides[key.replace("__", "/")] = events
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
	_apply_bindings(BUTTON_KEYS.keys())

	if remember:
		var settings := ConfigFile.new()
		settings.load(SETTINGS_PATH)
		settings.set_value("controls", "profile", profile)
		settings.save(SETTINGS_PATH)
	profile_changed.emit(profile)


## The player's rebinds over the defaults. `fresh`: actions whose events were
## just rebuilt (their defaults are taken again); any action not seen yet has
## its defaults taken too.
func _apply_bindings(fresh: Array) -> void:
	for entry: Array in REBINDABLE:
		var action: String = entry[0]
		for pad: bool in [false, true]:
			var key := _key(action, pad)
			if action in fresh or not _defaults.has(key):
				_defaults[key] = _events(action, pad)
			if _overrides.has(key):
				_set_events(action, pad, _overrides[key])


## `action`'s events of one kind: the controller's (`pad`) or the keyboard
## and mouse's.
func _events(action: String, pad: bool) -> Array[InputEvent]:
	var found: Array[InputEvent] = []
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if _is_pad(event) == pad:
				found.append(event)
	return found


## Replaces `action`'s events of one kind with `events`, keeping the other kind.
func _set_events(action: String, pad: bool, events: Array) -> void:
	for event in _events(action, pad):
		InputMap.action_erase_event(action, event)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _is_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


static func _key(action: String, pad: bool) -> String:
	return ("pad/" if pad else "kb/") + action


## What `action` is bound to on the controller (`pad`) or the keyboard and
## mouse, as the settings show it ("Space", "A", "Left stick ←", "RT").
func binding_text(action: String, pad: bool) -> String:
	var names := PackedStringArray()
	for event in _events(action, pad):
		names.append(event_name(event))
	return " / ".join(names) if not names.is_empty() else "Unbound"


## The default binding, as binding_text() says it.
func default_text(action: String, pad: bool) -> String:
	var names := PackedStringArray()
	for event: InputEvent in _defaults.get(_key(action, pad), []):
		names.append(event_name(event))
	return " / ".join(names) if not names.is_empty() else "Unbound"


func is_rebound(action: String, pad: bool) -> bool:
	return _overrides.has(_key(action, pad))


## Binds `action` to `event` alone (of its kind: a key or mouse button
## replaces the keyboard and mouse binding, a controller button or stick the
## controller's), and remembers it on this PC.
func rebind(action: String, event: InputEvent) -> void:
	var pad := _is_pad(event)
	var bound := _clean(event)
	if bound == null:
		return
	var events: Array[InputEvent] = [bound]
	_overrides[_key(action, pad)] = events
	_set_events(action, pad, events)
	_save_bindings()
	bindings_changed.emit()


## Back to the default binding of one kind.
func reset_binding(action: String, pad: bool) -> void:
	var key := _key(action, pad)
	if not _overrides.has(key):
		return
	_overrides.erase(key)
	_set_events(action, pad, _defaults.get(key, []))
	_save_bindings()
	bindings_changed.emit()


## Every binding of one kind back to its default.
func reset_all_bindings(pad: bool) -> void:
	for entry: Array in REBINDABLE:
		var key := _key(entry[0], pad)
		if _overrides.has(key):
			_overrides.erase(key)
			_set_events(entry[0], pad, _defaults.get(key, []))
	_save_bindings()
	bindings_changed.emit()


## Other rebindable actions already on `event` (the settings warn, as some
## share a button on purpose: LB is powerslide and air roll).
func actions_on(event: InputEvent, except: String) -> Array[String]:
	var found: Array[String] = []
	var bound := _clean(event)
	if bound == null:
		return found
	for entry: Array in REBINDABLE:
		if entry[0] == except:
			continue
		for existing in _events(entry[0], _is_pad(bound)):
			if event_name(existing) == event_name(bound):
				found.append(entry[1])
	return found


## A clean copy of a pressed key, mouse button, controller button or stick
## push, for binding (any controller; the key by its place on the keyboard).
static func _clean(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := InputEventKey.new()
		var source := event as InputEventKey
		key.physical_keycode = source.physical_keycode if source.physical_keycode != KEY_NONE else source.keycode
		return key
	if event is InputEventMouseButton:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = (event as InputEventMouseButton).button_index
		return mouse
	if event is InputEventJoypadButton:
		var button := InputEventJoypadButton.new()
		button.device = -1
		button.button_index = (event as InputEventJoypadButton).button_index
		return button
	if event is InputEventJoypadMotion:
		var motion := InputEventJoypadMotion.new()
		motion.device = -1
		motion.axis = (event as InputEventJoypadMotion).axis
		motion.axis_value = signf((event as InputEventJoypadMotion).axis_value)
		return motion
	return null


## How a binding reads: "Space", "Mouse right", "A", "D-pad ↑", "Left stick ←", "RT".
static func event_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var physical := (event as InputEventKey).physical_keycode
		var shown := physical
		if DisplayServer.get_name() != "headless":
			shown = DisplayServer.keyboard_get_keycode_from_physical(physical)
		var text := OS.get_keycode_string(shown if shown != KEY_NONE else physical)
		return {"Left": "←", "Right": "→", "Up": "↑", "Down": "↓"}.get(text, text)
	if event is InputEventMouseButton:
		var index := (event as InputEventMouseButton).button_index
		return _MOUSE_BUTTONS.get(index, "Mouse %d" % index)
	if event is InputEventJoypadButton:
		var button := (event as InputEventJoypadButton).button_index
		return _PAD_BUTTONS.get(button, "Button %d" % button)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var negative := motion.axis_value < 0.0
		match motion.axis:
			JOY_AXIS_LEFT_X:
				return "Left stick ←" if negative else "Left stick →"
			JOY_AXIS_LEFT_Y:
				return "Left stick ↑" if negative else "Left stick ↓"
			JOY_AXIS_RIGHT_X:
				return "Right stick ←" if negative else "Right stick →"
			JOY_AXIS_RIGHT_Y:
				return "Right stick ↑" if negative else "Right stick ↓"
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
		return "Axis %d %s" % [motion.axis, "-" if negative else "+"]
	return "?"


## A binding as saved: "key:32", "mouse:2", "button:0", "axis:5:1".
static func _to_text(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % (event as InputEventKey).physical_keycode
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "button:%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		return "axis:%d:%d" % [(event as InputEventJoypadMotion).axis, signi(roundi((event as InputEventJoypadMotion).axis_value))]
	return ""


static func _from_text(text: String) -> InputEvent:
	var parts := text.split(":")
	match parts[0]:
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = parts[1].to_int() as Key
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = parts[1].to_int() as MouseButton
			return mouse
		"button":
			var button := InputEventJoypadButton.new()
			button.device = -1
			button.button_index = parts[1].to_int() as JoyButton
			return button
		"axis":
			if parts.size() < 3:
				return null
			var motion := InputEventJoypadMotion.new()
			motion.device = -1
			motion.axis = parts[1].to_int() as JoyAxis
			motion.axis_value = float(parts[2].to_int())
			return motion
	return null


func _save_bindings() -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	if settings.has_section("bindings"):
		settings.erase_section("bindings")
	for key: String in _overrides:
		var texts := PackedStringArray()
		for event: InputEvent in _overrides[key]:
			texts.append(_to_text(event))
		settings.set_value("bindings", key.replace("/", "__"), texts)
	settings.save(SETTINGS_PATH)


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
