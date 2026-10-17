class_name PlayerInput
extends RefCounted
## Where one player's controls come from: the game's input actions (Controls),
## read for one controller and/or the keyboard. Each local player in co-op
## (PlayerSlot) has their own, so two controllers swim two fish; the fish
## (FishController.input_source), its camera (FollowCamera.input) and the school
## wheel (TargetWheel) all read through it.
##
## everyone() reads exactly as Input itself does: every controller and the
## keyboard, which is how a single player plays. A PlayerInput for one
## controller reads the same actions (and deadzones) from the InputMap, but only
## that controller's buttons and sticks, plus the keyboard if `keyboard` is on.

## Any controller (only everyone() reads them all).
const ANY := -1

## The controller (joypad id) this player holds, or ANY (or below that: none,
## the keyboard only).
var device := ANY
## The keyboard counts too (player 1's, in co-op).
var keyboard := true

static var _everyone: PlayerInput

## action (and frame kind) -> [frame, pressed the frame before, pressed now], for just_pressed().
var _held := {}


static func everyone() -> PlayerInput:
	if _everyone == null:
		_everyone = PlayerInput.new()
	return _everyone


static func for_device(pad: int, with_keyboard := false) -> PlayerInput:
	var input := PlayerInput.new()
	input.device = pad
	input.keyboard = with_keyboard
	return input


## Reads like Input (every controller and the keyboard).
func is_everyone() -> bool:
	return device == ANY and keyboard


## How far `action` is pushed (0..1), past its deadzone, as Input.get_action_strength.
func strength(action: StringName) -> float:
	if is_everyone():
		return Input.get_action_strength(action)
	return _strength(action, false)


## As strength(), but without the deadzone (Input.get_action_raw_strength).
func raw_strength(action: StringName) -> float:
	if is_everyone():
		return Input.get_action_raw_strength(action)
	return _strength(action, true)


func pressed(action: StringName) -> bool:
	if is_everyone():
		return Input.is_action_pressed(action)
	return _strength(action, false) > 0.0


## Pressed this frame (physics or rendered, whichever is running) and not the last.
func just_pressed(action: StringName) -> bool:
	if is_everyone():
		return Input.is_action_just_pressed(action)
	var physics := Engine.is_in_physics_frame()
	var frame := Engine.get_physics_frames() if physics else Engine.get_process_frames()
	var key := "%s:%s" % [action, "p" if physics else "f"]
	var now := pressed(action)
	var state: Array = _held.get(key, [])
	if state.is_empty():
		_held[key] = [frame, now, now]
		return false
	if state[0] != frame:
		state[0] = frame
		state[1] = state[2]
		state[2] = now
	return state[2] and not state[1]


## A stick from four actions, as Input.get_vector: the actions' deadzone
## (their average) applied to the whole vector, which is at most 1 long.
func vector(negative_x: StringName, positive_x: StringName, negative_y: StringName, positive_y: StringName) -> Vector2:
	if is_everyone():
		return Input.get_vector(negative_x, positive_x, negative_y, positive_y)
	var raw := Vector2(raw_strength(positive_x) - raw_strength(negative_x), raw_strength(positive_y) - raw_strength(negative_y))
	var deadzone := 0.25 * (InputMap.action_get_deadzone(negative_x) + InputMap.action_get_deadzone(positive_x)
			+ InputMap.action_get_deadzone(negative_y) + InputMap.action_get_deadzone(positive_y))
	var length := raw.length()
	if length <= deadzone:
		return Vector2.ZERO
	if length > 1.0:
		return raw / length
	return raw * (inverse_lerp(deadzone, 1.0, length) / length)


## Whether `event` came from this player's controller or keyboard.
func owns_event(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventMouse:
		return keyboard
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return device == ANY or event.device == device
	return false


## The strongest of `action`'s events on this player's controller and keyboard.
func _strength(action: StringName, raw: bool) -> float:
	if not InputMap.has_action(action):
		return 0.0
	var deadzone := InputMap.action_get_deadzone(action)
	var best := 0.0
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			if keyboard and Input.is_physical_key_pressed((event as InputEventKey).physical_keycode):
				return 1.0
		elif event is InputEventJoypadButton:
			if _pad_ok(event.device) and Input.is_joy_button_pressed(_pad(event.device), (event as InputEventJoypadButton).button_index):
				return 1.0
		elif event is InputEventJoypadMotion:
			if not _pad_ok(event.device):
				continue
			var motion := event as InputEventJoypadMotion
			var value := Input.get_joy_axis(_pad(event.device), motion.axis) * signf(motion.axis_value)
			if value <= 0.0:
				continue
			if raw:
				best = maxf(best, minf(value, 1.0))
			elif value >= deadzone:
				best = maxf(best, clampf(inverse_lerp(deadzone, 1.0, value), 0.0, 1.0))
	return best


## A binding for `bound` (an event's device: -1 is any) applies to this player's controller.
func _pad_ok(bound: int) -> bool:
	return device >= 0 and (bound == -1 or bound == device)


func _pad(bound: int) -> int:
	return device if bound == -1 else bound
