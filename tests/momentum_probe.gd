## Compares swim-stroke patterns against plain throttle, and how much speed a
## forward dodge leaves you with afterwards.
## Run headless: Godot_console.exe --headless --path . res://tests/momentum_probe.tscn
extends Node

const START := Vector3(-40, 35, 75)
const RUN_TIME := 3.0

## name, throttle held, stick axis ("x"/"y"/""), beat intervals (cycled)
const SCENARIOS := [
	["throttle only", true, "", []],
	["steady side strokes (0.30s)", false, "x", [0.30]],
	["steady up/down strokes (0.30s)", false, "y", [0.30]],
	["irregular strokes (0.2/0.5s)", false, "x", [0.2, 0.5]],
	["mashing (0.08s)", false, "x", [0.08]],
	["throttle + steady strokes", true, "x", [0.30]],
]

var fish: FishController
var scenario := -1
var clock := 0.0
var next_beat := 0.0
var beat_index := 0
var side := 1
var phase := "setup"
var peak := 0.0

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_next()

func _next() -> void:
	_release_all()
	scenario += 1
	clock = 0.0
	peak = 0.0
	phase = "setup"
	fish.request_reset()

func _release_all() -> void:
	for action in ["thrust_forward", "stick_left", "stick_right", "stick_up", "stick_down", "jump"]:
		Input.action_release(action)

func _physics_process(delta: float) -> void:
	clock += delta
	if phase == "setup":
		if clock < 0.05:
			return
		fish.global_position = START
		phase = "run"
		clock = 0.0
		next_beat = 0.0
		beat_index = 0
		side = 1
		return

	if scenario < SCENARIOS.size():
		_run_stroke_scenario(SCENARIOS[scenario])
	elif scenario == SCENARIOS.size():
		_run_dodge(true)
	elif scenario == SCENARIOS.size() + 1:
		_run_dodge(false)
	else:
		get_tree().quit()

func _run_stroke_scenario(s: Array) -> void:
	if s[1]:
		Input.action_press("thrust_forward")
	var beats: Array = s[3]
	if s[2] != "" and clock >= next_beat:
		var actions := ["stick_left", "stick_right"] if s[2] == "x" else ["stick_up", "stick_down"]
		Input.action_release(actions[0]); Input.action_release(actions[1])
		Input.action_press(actions[0] if side < 0 else actions[1])
		side = -side
		next_beat += beats[beat_index % beats.size()]
		beat_index += 1
	peak = maxf(peak, fish.speed)
	if clock >= RUN_TIME:
		print("%-32s speed after %.0fs: %5.1f m/s (peak %5.1f)  chain=%d" % [s[0], RUN_TIME, fish.speed, peak, fish.stroke_chain])
		_next()

## Cruise at full throttle, then (optionally) jump + forward dodge and keep cruising.
func _run_dodge(do_dodge: bool) -> void:
	Input.action_press("thrust_forward")
	if do_dodge:
		if is_equal_approx(snappedf(clock, 1.0 / 120.0), 2.5): Input.action_press("jump")
		if is_equal_approx(snappedf(clock, 1.0 / 120.0), 2.55): Input.action_release("jump")
		if is_equal_approx(snappedf(clock, 1.0 / 120.0), 2.7): Input.action_press("stick_up"); Input.action_press("jump")
		if is_equal_approx(snappedf(clock, 1.0 / 120.0), 2.75): Input.action_release("jump"); Input.action_release("stick_up")
	for mark in [2.6, 3.3, 3.7, 4.2, 5.2]:  # forward speed along the starting heading (ignores the jump's upward motion)
		if is_equal_approx(snappedf(clock, 1.0 / 120.0), mark):
			print("%-32s t=%.1fs  forward %5.1f m/s" % ["cruise + forward dodge at 2.7s" if do_dodge else "cruise, no dodge", mark, -fish.linear_velocity.z])
	if clock >= 5.3:
		_next()
