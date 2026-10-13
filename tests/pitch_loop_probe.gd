## Holds the stick to pitch the fish round, from a drift (sinking with negative
## buoyancy) and while swimming, and reports how far it turned. With car
## steering, pitching away from the drift used to stall part-way round as the
## steering flipped to "reversing".
## Run headless: Godot_console.exe --headless --path . res://tests/pitch_loop_probe.tscn
extends Node

## name, stick action, throttle held
const SCENARIOS := [
	["drifting, pitch back (nose up)", "stick_down", false],
	["drifting, pitch forward (nose down)", "stick_up", false],
	["swimming, pitch back", "stick_down", true],
	["reversing, steer right (car-style reverse)", "stick_right", false, true],
]
const SETTLE := 2.0
const HOLD := 4.0

var fish: FishController
var scenario := -1
var clock := 0.0
var turned := 0.0

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean")
	fish = main.get_node("Fish")
	print("buoyancy %.1f, lateral_drag %.2f, car_steering_pitch %s" % [fish.buoyancy, fish.lateral_drag, fish.car_steering_pitch])
	_next()

func _next() -> void:
	for action in ["stick_down", "stick_up", "stick_right", "thrust_forward", "thrust_reverse"]:
		Input.action_release(action)
	scenario += 1
	if scenario >= SCENARIOS.size():
		get_tree().quit()
		return
	fish.set_spawn(Transform3D.IDENTITY)
	clock = 0.0
	turned = 0.0

func _physics_process(delta: float) -> void:
	if scenario >= SCENARIOS.size():
		return
	var s: Array = SCENARIOS[scenario]
	var reversing: bool = s.size() > 3 and s[3]
	clock += delta
	if clock < SETTLE:
		if reversing:
			Input.action_press("thrust_reverse")
		return
	if clock - delta < SETTLE:
		Input.action_press(s[1])
		if s[2]:
			Input.action_press("thrust_forward")
	var local_spin := fish.global_basis.orthonormalized().transposed() * fish.angular_velocity
	turned += (local_spin.y if reversing else local_spin.x) * delta
	if clock >= SETTLE + HOLD:
		print("%-44s turned %+6.0f deg in %.0f s, speed %.1f m/s" % [s[0], rad_to_deg(turned), HOLD, fish.speed])
		_next()
