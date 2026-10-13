## Front flips without complete_flips: the flip ends (0.95 s) before a full
## turn and the fish spins the rest of the way itself. The chase camera must not
## lurch when that happens. Logs the camera through the flip.
## Run headless: Godot_console.exe --headless --path . res://tests/flip_camera_probe.tscn
## (camera moves in _process, so this samples once per physics tick)
extends Node

## name, keep holding the stick forward after the dodge
const SCENARIOS := [["front flip, stick released", false], ["front flip, stick held", true]]

var main: Node
var fish: FishController
var camera: Camera3D
var scenario := -1
var tick := 0
var flip_tick := -1
var prev_basis := Basis.IDENTITY
var max_step := 0.0
var max_pitch := 0.0
var pitch_turned := 0.0
var prev_forward := Vector3.FORWARD
var verbose := true

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean")
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	print("complete_flips %s" % fish.complete_flips)
	_next()

func _next() -> void:
	for a in ["thrust_forward", "jump", "stick_up"]:
		Input.action_release(a)
	scenario += 1
	if scenario >= SCENARIOS.size():
		get_tree().quit()
		return
	fish.set_spawn(Transform3D.IDENTITY)
	tick = 0
	flip_tick = -1
	max_step = 0.0
	max_pitch = 0.0
	pitch_turned = 0.0

func _physics_process(delta: float) -> void:
	if scenario >= SCENARIOS.size():
		return
	var s: Array = SCENARIOS[scenario]
	tick += 1
	match tick:
		10: Input.action_press("thrust_forward")
		120: Input.action_press("jump")
		122: Input.action_release("jump")
		150:
			Input.action_press("stick_up")  # front flip
			Input.action_press("jump")
			flip_tick = tick
			prev_basis = camera.global_basis
			prev_forward = -fish.global_basis.z
		152:
			Input.action_release("jump")
			if not s[1]:
				Input.action_release("stick_up")
	if flip_tick < 0:
		return
	var since := tick - flip_tick
	var forward := -fish.global_basis.z
	pitch_turned += rad_to_deg(prev_forward.angle_to(forward))  # the nose only turns one way in a flip
	prev_forward = forward
	var b := camera.global_basis
	var step := rad_to_deg(prev_basis.get_rotation_quaternion().angle_to(b.get_rotation_quaternion()))
	prev_basis = b
	var cam_pitch := rad_to_deg(asin(clampf((-b.z).y, -1.0, 1.0)))
	max_step = maxf(max_step, step)
	max_pitch = maxf(max_pitch, absf(cam_pitch))
	if verbose and since % 6 == 0 and since >= 90 and since <= 216:
		print("  %s t=%.2fs flip %5.0f deg  flipping=%s  camera pitch %+5.0f deg  turn this tick %4.1f deg" % [s[0], since / 120.0, pitch_turned, fish.is_flipping(), cam_pitch, step])
	if since == 360:
		print("%s: fish turned %.0f deg; camera's biggest turn in one tick %.1f deg, steepest camera pitch %.0f deg, ends %.1f deg from the fish's facing" % [
			s[0], pitch_turned, max_step, max_pitch, rad_to_deg((-b.z).angle_to(-fish.global_basis.z))])
		_next()
