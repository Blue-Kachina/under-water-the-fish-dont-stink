## Drives up the side wall, steers back down onto the floor, drives on and
## parks, and measures
## how much the fish and the chase camera shake: the fish's spin reversals
## (wobble) and the camera's frame-to-frame turn changing direction (jitter).
## Run headless: Godot_console.exe --headless --path . res://tests/wall_jitter_probe.tscn
extends Node

var main: Node
var fish: FishController
var camera: Camera3D
var t := 0.0
var phase := ""
var stats := {}
var last_spin := Vector3.ZERO
var last_cam: Basis
var last_cam_turn := Vector3.ZERO
var last_surface := false
var boost := false

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Aquarium Arena")
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	boost = "--boost" in OS.get_cmdline_user_args()
	if "--noroll" in OS.get_cmdline_user_args():
		camera.roll_with_surface = false
	start()

func start() -> void:
	fish.set_spawn(Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(22.0, 0.4, 0.0)))
	Input.action_press("thrust_forward")
	if boost:
		Input.action_press("boost")

func stat(key: String) -> Dictionary:
	if not stats.has(phase):
		stats[phase] = {"ticks": 0, "frames": 0, "spin_flips": 0, "surface_flips": 0, "cam_flips": 0, "cam_max_turn": 0.0, "max_spin": 0.0, "wheels": {}}
	return stats[phase]

func _physics_process(delta: float) -> void:
	t += delta
	var new_phase := "1 approach" if t < 1.2 else "2 up the wall" if t < 2.4 else "3 steering back down" if t < 4.5 else "4 driving on the floor" if t < 7.0 else "5 parked"
	if new_phase != phase:
		phase = new_phase
		if phase == "3 steering back down":
			Input.action_release("boost")
			Input.action_press("stick_right")
		elif phase == "4 driving on the floor":
			Input.action_release("stick_right")
		elif phase == "5 parked":
			Input.action_release("thrust_forward")
	if t > 10.0:
		report()
		return
	var s := stat(phase)
	s.ticks += 1
	var spin := fish.global_basis.transposed() * fish.angular_velocity
	for i in 3:
		if absf(spin[i]) > 0.3 and absf(last_spin[i]) > 0.3 and signf(spin[i]) != signf(last_spin[i]):
			s.spin_flips += 1
	s.max_spin = maxf(s.max_spin, Vector2(spin.x, spin.z).length())  # pitch/roll only
	last_spin = spin
	if fish.on_surface != last_surface:
		s.surface_flips += 1
	last_surface = fish.on_surface
	s.wheels[fish.wheels_touching] = s.wheels.get(fish.wheels_touching, 0) + 1

func _process(_delta: float) -> void:
	if phase == "" or t > 10.0:
		return
	var s := stat(phase)
	s.frames += 1
	var cam := camera.global_basis.orthonormalized()
	if last_cam != Basis():
		var d := (last_cam.inverse() * cam).get_euler()
		var turn := Vector3(rad_to_deg(d.x), rad_to_deg(d.y), rad_to_deg(d.z))
		for i in 3:
			if absf(turn[i]) > 0.05 and absf(last_cam_turn[i]) > 0.05 and signf(turn[i]) != signf(last_cam_turn[i]):
				s.cam_flips += 1
		s.cam_max_turn = maxf(s.cam_max_turn, turn.length())
		last_cam_turn = turn
	last_cam = cam

var reported := false
func report() -> void:
	if reported:
		return
	reported = true
	print("wall jitter (boost %s):" % boost)
	for p in stats:
		var s: Dictionary = stats[p]
		print("  %-30s ticks %4d  spin reversals %3d  max pitch/roll spin %.2f rad/s  on_surface toggles %3d  wheels %s | frames %4d  camera direction reversals %3d  biggest camera turn/frame %.2f deg" % [p, s.ticks, s.spin_flips, s.max_spin, s.surface_flips, s.wheels, s.frames, s.cam_flips, s.cam_max_turn])
	print("  end: fish at %s, up %s" % [fish.global_position, fish.global_basis.y])
	# A steady camera turns smoothly; one shaking reverses direction every frame or two.
	var worst := 0
	for p in stats:
		worst = maxi(worst, stats[p].cam_flips)
	print("%s camera steady (most direction reversals in a phase: %d, allowed 5)" % ["PASS" if worst <= 5 else "FAIL", worst])
	get_tree().quit()
