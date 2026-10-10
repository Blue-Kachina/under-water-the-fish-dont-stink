## Scripted movement probe: feeds fixed inputs to the fish and prints speed,
## spin and orientation at set times, so tuning changes can be compared with numbers.
## Run headless: Godot_console.exe --headless --path . res://tests/movement_probe.tscn
extends Node

var fish: FishController
var arena: Arena
var camera: Camera3D
var t := 0.0
var events := {}

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	arena = main.get_node("Arena")
	camera = main.get_node("FollowCamera")

func once(key: String, at: float) -> bool:
	if t >= at and not events.has(key):
		events[key] = true
		return true
	return false

func log_turn(label: String) -> void:
	var fwd := -fish.global_basis.z
	print("%-26s t=%5.2f speed=%5.2f heading=%5.1f° drift=%4.1f° sliding=%s" % [label, t, fish.speed, rad_to_deg(atan2(fwd.x, -fwd.z)), fish.drift_angle, fish.is_powersliding])

func log_state(label: String) -> void:
	var fwd := -fish.global_basis.z
	print("%-26s t=%5.2f speed=%5.2f fwd_speed=%5.2f spin=%4.2f fwd=(%.2f,%.2f,%.2f) pos=(%.1f,%.1f,%.1f) jump=%d" % [label, t, fish.speed, fish.forward_speed, fish.angular_speed, fwd.x, fwd.y, fwd.z, fish.global_position.x, fish.global_position.y, fish.global_position.z, fish.jump_state])

func log_camera(label: String) -> void:
	var cam_fwd := -camera.global_basis.z
	var fish_up := fish.global_basis.y
	print("%-26s t=%5.2f dodging=%s camera_fwd=(%.2f,%.2f,%.2f) fish_up=(%.2f,%.2f,%.2f)" % [label, t, fish.is_dodging, cam_fwd.x, cam_fwd.y, cam_fwd.z, fish_up.x, fish_up.y, fish_up.z])

func _physics_process(delta: float) -> void:
	t += delta
	# Speed caps
	if once("throttle", 0.0): Input.action_press("thrust_forward")
	if once("t2", 2.0): log_state("throttle 2s"); Input.action_press("boost")
	if once("b1", 3.5): log_state("+ boost 1.5s (cap 45)"); Input.action_release("boost"); Input.action_release("thrust_forward")
	if once("reset1", 4.5): fish.request_reset()
	# Jump, then a neutral second press = double jump
	if once("jump", 5.0): Input.action_press("jump")
	if once("jump_up", 5.05): Input.action_release("jump"); log_state("after jump")
	if once("dj", 5.3): Input.action_press("jump")
	if once("dj_up", 5.35): Input.action_release("jump"); log_state("after double jump")
	# Jump, then stick + second press = dodge; camera must hold during the flip
	if once("jump2", 6.5): Input.action_press("jump")
	if once("jump2_up", 6.55): Input.action_release("jump")
	if once("dodge", 6.8): log_camera("camera before dodge"); Input.action_press("stick_right"); Input.action_press("jump")
	if once("dodge_up", 6.85): Input.action_release("jump"); log_state("side dodge start")
	if once("dodge_q", 6.95): log_camera("camera quarter-flip")
	if once("dodge_h", 7.05): log_camera("camera half-flip")
	if once("dodge_mid_log", 7.1): log_state("side dodge +0.25s")
	if once("dodge_end", 7.4): Input.action_release("stick_right"); log_state("side dodge done"); log_camera("camera after dodge")
	# Hoop course start
	if once("reset2", 8.0): fish.request_reset()
	if once("hoop_setup", 8.5):
		fish.global_position = Vector3(0, 12, 58)
		fish.linear_velocity = Vector3(0, 0, -10)
	if once("hoop_check", 9.1):
		print("course: running=%s next_hoop=%d time=%.2f" % [arena.running, arena.next_hoop, arena.course_time])

	# Same half-second hard turn, without and with powerslide
	if once("reset3", 10.0): fish.request_reset(); Input.action_press("thrust_forward")
	if once("move_a", 10.05): fish.global_position = Vector3(0, 32, 70)
	if once("turn_a", 11.5): Input.action_press("stick_right")
	if once("turn_a_log", 12.0): log_turn("turn 0.5s, no slide"); Input.action_release("stick_right"); Input.action_release("thrust_forward")
	if once("reset4", 12.5): fish.request_reset(); Input.action_press("thrust_forward")
	if once("move_b", 12.55): fish.global_position = Vector3(0, 32, 70)
	if once("turn_b", 14.0): Input.action_press("stick_right"); Input.action_press("powerslide")
	if once("turn_b_log", 14.5): log_turn("turn 0.5s, powerslide"); Input.action_release("stick_right")
	if once("turn_b_after", 15.0): log_turn("0.5s later, still sliding"); Input.action_release("powerslide"); Input.action_release("thrust_forward")

	# Air roll through 360°+: the camera's roll must change smoothly (no flip)
	if once("reset5", 15.2): fish.request_reset()
	if once("move_c", 15.25): fish.global_position = Vector3(0, 32, 70)
	if once("roll", 15.5): Input.action_press("air_roll"); Input.action_press("stick_right")
	if t > 15.5 and t < 18.0: track_camera_roll()
	if once("roll_end", 17.5):
		Input.action_release("air_roll"); Input.action_release("stick_right")
		print("air roll: fish rolled %.0f°, camera roll range %.0f°..%.0f°, biggest camera change in one tick %.1f°" % [rad_to_deg(fish_roll_total), rad_to_deg(cam_roll_min), rad_to_deg(cam_roll_max), rad_to_deg(max_cam_step)])
	if once("quit", 18.0): get_tree().quit()


var prev_cam_roll := 0.0
var prev_fish_up := Vector3.UP
var fish_roll_total := 0.0
var cam_roll_min := 0.0
var cam_roll_max := 0.0
var max_cam_step := 0.0

func track_camera_roll() -> void:
	var cam_fwd := -camera.global_basis.z
	var level := (Vector3.UP - cam_fwd * cam_fwd.dot(Vector3.UP)).normalized()
	var cam_roll := level.signed_angle_to(camera.global_basis.y, cam_fwd)
	max_cam_step = maxf(max_cam_step, absf(wrapf(cam_roll - prev_cam_roll, -PI, PI)))
	cam_roll_min = minf(cam_roll_min, cam_roll)
	cam_roll_max = maxf(cam_roll_max, cam_roll)
	prev_cam_roll = cam_roll
	fish_roll_total += prev_fish_up.angle_to(fish.global_basis.y)
	prev_fish_up = fish.global_basis.y
