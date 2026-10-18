extends Node
## Unnatural's survivor cam modes (FollowCamera.free_cam, UNNATURAL > Camera):
## the follow cam turns with the fish, but holds its direction while accelerate
## or reverse is held; the ball cam button swaps to the free cam, which the
## fish's turning leaves alone, the right stick turns (within its pitch limit),
## and stays where it's put; the panel's camera_mode sets the mode again.
##   Godot_console.exe --headless --path . res://tests/survivor_cam_probe.tscn

var main: Node
var fish: FishController
const FollowCamera := preload("res://scripts/follow_camera.gd")

var camera: FollowCamera
var settings := UnnaturalSettings.shared()
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	settings.spawning = false
	settings.stage_events = false
	settings.chest_count = 0
	settings.camera_mode = 0
	settings.camera_hold_on_throttle = true
	settings.free_cam_follow = 0.0
	settings.free_cam_invert_y = false
	main.set_mode(main.UNNATURAL)
	await _seconds(0.1)
	main._match_card.play_requested.emit()
	await _seconds(0.2)
	camera = main._camera
	var hud: UnnaturalHud = main._unnatural_hud
	check(camera.steady_heading and not camera.free_cam, "Unnatural starts in the follow cam")
	check(hud.player_camera == camera, "the HUD knows its camera")

	print("follow cam:")
	fish.freeze = true
	_face(0.0)
	await _seconds(1.5)
	var start := _flat(camera._heading)
	check(start.dot(_flat(-fish.global_basis.z)) > 0.95, "it settles behind the fish")
	Input.action_press("thrust_forward")
	_face(PI / 2.0)
	await _seconds(1.5)
	check(_flat(camera._heading).dot(start) > 0.99, "holding accelerate, the fish's turn doesn't turn it")
	Input.action_release("thrust_forward")
	Input.action_press("thrust_reverse")
	await _seconds(0.8)
	check(_flat(camera._heading).dot(start) > 0.99, "nor holding reverse")
	Input.action_release("thrust_reverse")
	Input.action_press("boost")
	await _seconds(0.8)
	check(_flat(camera._heading).dot(start) > 0.99, "nor holding boost (D9)")
	Input.action_release("boost")
	await _seconds(2.5)
	check(_flat(camera._heading).dot(_flat(-fish.global_basis.z)) > 0.95, "let go, it turns round behind the fish")
	check(_flat(-camera.global_basis.z).dot(_flat(-fish.global_basis.z)) > 0.9, "and the view goes with it")
	# Its heading by itself: the nose, not the drift; from dead behind, the way the fish turns.
	for spin: float in [2.0, -2.0]:
		camera._heading = Vector3.FORWARD
		var subject := {"angular_velocity": Vector3(0, spin, 0), "linear_velocity": Vector3(12, 0, 0)}
		camera._turn_behind(subject, Vector3.BACK, settings.camera_swing_rate, 0.05)
		var went := Vector3.FORWARD.signed_angle_to(_flat(camera._heading), Vector3.UP)
		check(signf(went) == signf(spin), "dead behind, turning %s: it swings %s" % ["left" if spin > 0 else "right", "left" if went > 0 else "right"])
	camera._heading = Vector3.FORWARD
	for i in 60:
		camera._turn_behind({"linear_velocity": Vector3(12, 0, 0)}, Vector3.LEFT, settings.camera_swing_rate, 1.0 / 60.0)
	check(_flat(camera._heading).dot(Vector3.LEFT) > 0.95, "coasting sideways, it settles behind the nose, not the drift")
	settings.camera_hold_on_throttle = false
	Input.action_press("thrust_forward")
	_face(0.0)
	await _seconds(2.5)
	Input.action_release("thrust_forward")
	check(_flat(camera._heading).dot(_flat(-fish.global_basis.z)) > 0.95, "with hold_on_throttle off, it turns while accelerating")
	settings.camera_hold_on_throttle = true

	print("swap:")
	var swaps: Array[bool] = []
	camera.survivor_cam_swapped.connect(func(free: bool) -> void: swaps.append(free))
	await _tap("ball_cam")
	check(camera.free_cam and swaps == [true], "the ball cam button swaps to the free cam")
	check(hud._cam_note.text.begins_with("FREE CAM") and hud._cam_note.modulate.a > 0.5, "and the HUD says so")
	await _seconds(0.3)
	check(camera.free_cam, "the panel's live update doesn't undo the swap")

	print("free cam:")
	var put := _flat(camera._heading)
	_face(PI)
	await _seconds(1.5)
	check(_flat(camera._heading).dot(put) > 0.99, "the fish turning round leaves it be")
	Input.action_press("camera_right")
	await _seconds(0.5)
	Input.action_release("camera_right")
	var turned := rad_to_deg(put.signed_angle_to(_flat(camera._heading), Vector3.UP))
	check(turned < -30.0 and turned > -110.0, "the right stick turns it right (%.0f deg in 0.5 s)" % turned)
	var after := _flat(camera._heading)
	await _seconds(1.5)
	check(_flat(camera._heading).dot(after) > 0.999, "and it stays where it's put")
	check(_flat(-camera.global_basis.z).dot(after) > 0.9, "the view faces it")
	Input.action_press("camera_down")
	await _seconds(3.0)
	Input.action_release("camera_down")
	var pitch := asin(clampf(camera._heading.y, -1.0, 1.0))
	check(pitch < -0.5 and pitch >= -deg_to_rad(settings.free_cam_pitch) - 0.01, "down on the stick looks down, within the limit (%.0f deg)" % rad_to_deg(pitch))
	Input.action_press("camera_up")
	await _seconds(3.0)
	Input.action_release("camera_up")
	pitch = asin(clampf(camera._heading.y, -1.0, 1.0))
	check(pitch > 0.5 and pitch <= deg_to_rad(settings.free_cam_pitch) + 0.01, "and up looks up (%.0f deg)" % rad_to_deg(pitch))
	settings.free_cam_invert_y = true
	await _seconds(0.1)
	Input.action_press("camera_down")
	await _seconds(1.0)
	Input.action_release("camera_down")
	check(asin(clampf(camera._heading.y, -1.0, 1.0)) >= pitch - 0.01, "free_cam_invert_y on: down on the stick looks up (D11)")
	Input.action_press("camera_up")
	await _seconds(3.0)
	Input.action_release("camera_up")
	check(asin(clampf(camera._heading.y, -1.0, 1.0)) < -0.5, "and up looks down")
	settings.free_cam_follow = 3.0
	await _seconds(2.5)
	check(_flat(camera._heading).dot(_flat(-fish.global_basis.z)) > 0.95, "free_cam_follow drifts it behind the fish")
	settings.free_cam_follow = 0.0

	print("back again:")
	await _tap("ball_cam")
	check(not camera.free_cam and swaps == [true, false], "the button swaps back to the follow cam")
	settings.camera_mode = 1
	await _seconds(0.1)
	check(camera.free_cam, "setting camera_mode to Free on the panel puts the free cam on")
	settings.camera_mode = 0
	await _seconds(0.1)
	check(not camera.free_cam, "and Follow, the follow cam")
	settings.steady_camera = false
	await _seconds(0.1)
	await _tap("ball_cam")
	check(not camera.steady_heading and camera.ball_cam, "steady_camera off: the usual chase cam, its button ball cam again")
	settings.steady_camera = true
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## Points the (frozen) fish `yaw` round from the spawn's facing.
func _face(yaw: float) -> void:
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	fish.global_basis = Basis(Vector3.UP, yaw)
	fish.reset_physics_interpolation()


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


## Presses at a frame's start, before the camera's _process: pressed from a
## timer (which runs after it), it's no longer "just pressed" by the next frame.
func _tap(action: StringName) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
