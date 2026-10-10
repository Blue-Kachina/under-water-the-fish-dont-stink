## Checks the chase camera through a half flip (back flip, cancel, air roll
## upright, swim away): it must never flip upside down or snap, and should end
## up behind the fish facing the new direction.
## Run headless: Godot_console.exe --headless --path . res://tests/camera_probe.tscn
## (camera moves in _process, so this samples once per physics tick)
extends Node

var main: Node
var fish: FishController
var camera: Camera3D
var tick := 0
var prev_basis := Basis.IDENTITY
var max_step := 0.0
var min_up := 1.0
var max_pitch := 0.0

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean", false)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")

func _physics_process(_delta: float) -> void:
	tick += 1
	match tick:
		10: Input.action_press("thrust_forward")
		120: Input.action_press("jump")
		122: Input.action_release("jump")
		150:
			Input.action_press("stick_down")  # back flip
			Input.action_press("jump")
			prev_basis = camera.global_basis
		152:
			Input.action_release("stick_down")
			Input.action_release("jump")
		166: Input.action_press("stick_up")  # cancel ~0.13 s in
		215:
			Input.action_release("stick_up")
			Input.action_press("roll_right")  # air roll back upright
		283: Input.action_release("roll_right")
		500:
			var facing := rad_to_deg((-camera.global_basis.z).angle_to(-fish.global_basis.z))
			print("Half flip: camera's biggest turn in one frame %.1f°, lowest camera-up·world-up %.2f (negative = upside down), steepest camera pitch %.0f°, camera ends %.1f° from the fish's facing" % [max_step, min_up, max_pitch, facing])
			get_tree().quit()
	if tick > 150:
		var b := camera.global_basis
		max_step = maxf(max_step, rad_to_deg(prev_basis.get_rotation_quaternion().angle_to(b.get_rotation_quaternion())))
		prev_basis = b
		min_up = minf(min_up, b.y.dot(Vector3.UP))
		max_pitch = maxf(max_pitch, rad_to_deg(asin(clampf(absf((-b.z).y), 0.0, 1.0))))
