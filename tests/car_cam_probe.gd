## Car cam smoothness through dodges on the Aquarium floor (RL physics): front,
## side, diagonal and back flips, and a half flip. Reports how sharply the
## camera's turning changes speed, and how sharply the fish's place in view
## (its position in the camera's frame) does: a jerk shows as a spike in either.
## (A smooth swing round the fish moves neither suddenly.) Prints the worst of each per scenario, and when it happened
## relative to the dodge's end.
## Run headless at a fixed 120 fps (one rendered frame per physics tick):
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/car_cam_probe.tscn
extends Node

const ACTIONS := ["thrust_forward", "thrust_reverse", "stick_left", "stick_right", "stick_up", "stick_down",
		"roll_left", "roll_right", "jump", "boost", "powerslide", "air_roll"]
## name, stick actions for the dodge, then [tick, action, press] extras after it.
const SCENARIOS := [
	["front flip", ["stick_up"], []],
	["side flip", ["stick_right"], []],
	["diagonal flip", ["stick_up", "stick_left"], []],
	["back flip", ["stick_down"], []],
	["half flip", ["stick_down"], [[16, "stick_up", true], [70, "stick_up", false], [70, "roll_right", true], [140, "roll_right", false]]],
]
const DODGE_TICK := 150
const WINDOW := 300  # ticks measured from the dodge
## Limits: the camera's turn rate may change by at most this much in a frame
## (deg/s per frame; the camera's own cap, MAX_TURN_ACCEL, is 19), and the
## fish's place in view by this much (m/s per frame).
const MAX_TURN_STEP := 25.0
const MAX_OFFSET_STEP := 0.5

var main: Node
var fish: FishController
var camera: Camera3D
var scenario := -1
var tick := 0
var failures := 0
var prev_rotation := Quaternion.IDENTITY
var prev_turn_rate := 0.0
var prev_offset := Vector3.ZERO
var prev_offset_speed := Vector3.ZERO
var worst_turn := 0.0
var worst_turn_tick := 0
var worst_offset := 0.0
var worst_offset_tick := 0
var flip_end_tick := -1
var started := false


func _ready() -> void:
	process_priority = 100  # after the camera
	if not is_equal_approx(Engine.get_physics_ticks_per_second(), 120) or Engine.max_fps not in [0, 120]:
		push_warning("run with --fixed-fps 120 for one rendered frame per physics tick")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	main.set_environment("Aquarium Arena", false)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	camera.ball_cam = false
	fish.swim_strokes = false  # no stick rhythm here, but be sure
	(main._environment as AquariumArena).ball.pop()  # out of the way
	(main._environment as AquariumArena).set_physics_process(false)
	_next()


func _next() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)
	if scenario >= 0:
		_report()
	scenario += 1
	if scenario >= SCENARIOS.size():
		print("car_cam_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
		get_tree().quit(1 if failures else 0)
		return
	fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 40.0)))
	tick = 0
	started = false
	worst_turn = 0.0
	worst_offset = 0.0
	flip_end_tick = -1


func _physics_process(delta: float) -> void:
	if scenario >= SCENARIOS.size():
		return
	tick += 1
	var s: Array = SCENARIOS[scenario]
	var since := tick - DODGE_TICK
	match tick:
		5: Input.action_press("thrust_forward")
		DODGE_TICK - 20:
			Input.action_press("jump")  # first jump
		DODGE_TICK - 18:
			Input.action_release("jump")
		DODGE_TICK:
			for action: String in s[1]:
				Input.action_press(action)
			Input.action_press("jump")
		DODGE_TICK + 2:
			Input.action_release("jump")
		DODGE_TICK + 6:
			for action: String in s[1]:
				Input.action_release(action)
	for extra: Array in s[2]:
		if since == extra[0]:
			if extra[2]:
				Input.action_press(extra[1])
			else:
				Input.action_release(extra[1])

	if since > 0 and flip_end_tick < 0 and not fish.is_flipping():
		flip_end_tick = since
	if since >= WINDOW:
		_next()


## Measured each rendered frame after the camera has moved (this node's process
## priority puts it after the camera), against the fish as drawn in the same frame.
func _process(delta: float) -> void:
	if scenario >= SCENARIOS.size() or tick == 0:
		return
	var since := tick - DODGE_TICK
	var rotation_now := camera.global_basis.get_rotation_quaternion()
	var offset := camera.global_basis.inverse() * (fish.get_global_transform_interpolated().origin - camera.global_position)
	if since >= -30:
		var turn_rate := rad_to_deg(prev_rotation.angle_to(rotation_now)) / delta
		var offset_speed := (offset - prev_offset) / delta
		if started:
			var turn_step := absf(turn_rate - prev_turn_rate)
			var offset_step := (offset_speed - prev_offset_speed).length()
			if turn_step > worst_turn:
				worst_turn = turn_step
				worst_turn_tick = since
			if offset_step > worst_offset:
				worst_offset = offset_step
				worst_offset_tick = since
		started = true
		prev_turn_rate = turn_rate
		prev_offset_speed = offset_speed
	prev_rotation = rotation_now
	prev_offset = offset


func _report() -> void:
	var s: Array = SCENARIOS[scenario]
	var ok := worst_turn <= MAX_TURN_STEP and worst_offset <= MAX_OFFSET_STEP
	if not ok:
		failures += 1
	print("  %s  %-14s dodge ends at %+.2f s; biggest change of turn rate %5.1f deg/s in a frame (at %+.2f s), of the fish's speed in view %.2f m/s (at %+.2f s)" % [
		"PASS" if ok else "FAIL", s[0], flip_end_tick / 120.0, worst_turn, worst_turn_tick / 120.0, worst_offset, worst_offset_tick / 120.0])
