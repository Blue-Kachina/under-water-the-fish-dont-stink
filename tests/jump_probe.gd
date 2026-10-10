## Rocket League-style variable jump: a tap, part and full holds, the jump with
## variable_jump off, and a double jump after a full hold. Also checks the
## tuning panel hides fish/camera settings that don't apply.
## Run headless: Godot_console.exe --headless --path . res://tests/jump_probe.tscn
extends Node

## name, seconds jump is held (0 = a single tick), variable_jump
const SCENARIOS := [
	["tap", 0.0, true],
	["hold 0.1 s", 0.1, true],
	["full hold (0.5 s)", 0.5, true],
	["full hold, variable_jump off", 0.5, false],
]
const SETTLE := 0.3

var main: Node
var fish: FishController
var panel: Node
var scenario := -1
var clock := 0.0
var pressed_at := -1.0

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean", false)
	fish = main.get_node("Fish")
	panel = main.get_node("DebugPanel")
	fish.buoyancy = 0.0  # measure the jump alone
	fish.linear_drag = 0.0
	fish.lateral_drag = 0.0  # a jump is sideways to the nose; with post_jump_drag_time 0 lateral drag eats it
	print("jump_impulse %.1f, jump_hold_accel %.1f, jump_hold_time %.2f (expect tap %.2f, full hold %.2f)" % [fish.jump_impulse, fish.jump_hold_accel, fish.jump_hold_time, fish.jump_impulse + fish.jump_hold_accel * 0.025, fish.jump_impulse + fish.jump_hold_accel * fish.jump_hold_time])
	_check_panel()
	_next()

func _shows(key: String) -> bool:
	panel._refresh_visibility()
	return panel._rows[key].visible

func _check_panel() -> void:
	print("panel defaults: roll_torque %s, pitch_torque %s, yaw_torque %s, angular_drag %s, steer_response %s, boost_drain %s, dodge_flip_duration %s, jump_hold_accel %s, roll_follow %s" % [
		_shows("fish/roll_torque"), _shows("fish/pitch_torque"), _shows("fish/yaw_torque"), _shows("fish/angular_drag"),
		_shows("fish/steer_response"), _shows("fish/boost_drain"), _shows("fish/dodge_flip_duration"), _shows("fish/jump_hold_accel"), _shows("camera/roll_follow")])
	fish.rl_roll_timing = false; fish.car_steering = false; fish.boost_unlimited = true; fish.rl_dodge_timing = false
	main.get_node("FollowCamera").lock_roll_to_fish = true
	print("panel toggled: roll_torque %s, pitch_torque %s, yaw_torque %s, angular_drag %s, steer_response %s, boost_drain %s, dodge_flip_duration %s, complete_flips %s, roll_follow %s" % [
		_shows("fish/roll_torque"), _shows("fish/pitch_torque"), _shows("fish/yaw_torque"), _shows("fish/angular_drag"),
		_shows("fish/steer_response"), _shows("fish/boost_drain"), _shows("fish/dodge_flip_duration"), _shows("fish/complete_flips"), _shows("camera/roll_follow")])
	fish.rl_roll_timing = true; fish.car_steering = true; fish.boost_unlimited = false; fish.rl_dodge_timing = true
	main.get_node("FollowCamera").lock_roll_to_fish = false

func _next() -> void:
	Input.action_release("jump")
	scenario += 1
	if scenario == SCENARIOS.size():
		_double_jump_check()
		return
	fish.variable_jump = SCENARIOS[scenario][2]
	fish.set_spawn(Transform3D.IDENTITY)
	clock = 0.0
	pressed_at = -1.0

func _double_jump_check() -> void:
	fish.variable_jump = true
	fish.set_spawn(Transform3D.IDENTITY)
	clock = 0.0
	pressed_at = -1.0

func _physics_process(delta: float) -> void:
	clock += delta
	if scenario < SCENARIOS.size():
		var s: Array = SCENARIOS[scenario]
		if pressed_at < 0.0 and clock >= SETTLE:
			Input.action_press("jump")
			pressed_at = clock
		elif pressed_at >= 0.0 and clock - pressed_at >= s[1]:
			Input.action_release("jump")
		if pressed_at >= 0.0 and clock - pressed_at >= 0.6:
			print("%-30s vertical speed %5.2f m/s" % [s[0], fish.linear_velocity.y])
			_next()
	else:
		# Full hold, release, then a double jump 1.3 s after the press: past the
		# 1.2 s window from the press, but inside it counted from the hold's end.
		if pressed_at < 0.0 and clock >= SETTLE:
			Input.action_press("jump")
			pressed_at = clock
		var since := clock - pressed_at if pressed_at >= 0.0 else -1.0
		if since >= 0.5 and since < 0.5 + delta:
			Input.action_release("jump")
		if since >= 1.3 and since < 1.3 + delta:
			Input.action_press("jump")
		if since >= 1.4:
			print("double jump 1.3 s after a full-hold press: state %s (2 = cooldown means it fired), vertical %.2f m/s" % [fish.jump_state, fish.linear_velocity.y])
			Input.action_release("jump")
			get_tree().quit()
