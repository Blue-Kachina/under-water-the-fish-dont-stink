extends Node
## Nature's ball cam button and school wheel (FollowCamera.hold_opens_wheel,
## TargetWheel): a tap toggles ball cam (and looks at the nearest thing ahead
## as it goes on), a hold opens the wheel instead; the stick toward a school
## and letting go looks at it; with the stick left alone it stays put; a
## target wiped out moves ball cam on; swimming into a school, ball cam looks
## ahead rather than whipping round to its middle; outside Nature a press
## toggles as before.
##   Godot_console.exe --headless --path . res://tests/target_wheel_probe.tscn

var main: Node
var fish: FishController
var camera: Node
var settings := NatureSettings.shared()
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	main.set_mode(main.NATURE)
	await _ticks(3)
	settings.lone_target = false
	settings.school_speed = 0.0
	main._match_card.play_requested.emit()
	await _ticks(10)
	var run: NatureRun = main.nature_run
	var wheel: TargetWheel = main._target_wheel
	fish.freeze = true

	print("tap:")
	check(camera.hold_opens_wheel and wheel != null, "Nature: holding ball cam opens the wheel")
	var was: bool = camera.ball_cam
	await _press(0.1)
	check(camera.ball_cam != was and not camera.wheel_open, "a tap toggles ball cam (%s -> %s)" % [was, camera.ball_cam])
	await _press(0.1)
	check(camera.ball_cam == was, "and back")

	print("hold:")
	var focus_before: Node3D = run.focus
	Input.action_press("ball_cam")
	await _seconds(settings.wheel_hold_time + 0.15)
	check(camera.wheel_open and wheel.is_open and camera.ball_cam == was, "holding opens the wheel, ball cam left as it was")
	check(run.targets().size() == run.schools.size(), "a slice per school (%d)" % run.targets().size())
	# The stick toward a school that isn't the focus.
	var other: Array = []
	for entry: Array in run.targets():
		if entry[0] != run.focus:
			other = entry
	var toward: Vector2 = wheel._direction_of(other[0])
	_stick(toward)
	await _frames(4)
	check(wheel.picked[0] == other[0], "the stick toward %s picks it" % other[1])
	_stick(Vector2.ZERO)
	await _frames(2)
	Input.action_release("ball_cam")
	await _frames(4)
	check(not camera.wheel_open and run.focus == other[0] and camera.ball == other[0] and camera.ball_cam, "letting go looks at it, ball cam on")
	check(run.focus != focus_before, "a different school than before")

	print("stick alone:")
	Input.action_press("ball_cam")
	await _seconds(settings.wheel_hold_time + 0.15)
	Input.action_release("ball_cam")
	await _frames(4)
	check(run.focus == other[0], "opening and closing without the stick stays put")

	print("wiped out:")
	var school: School = other[0].get_parent()
	school._alive.fill(0)
	await _ticks(3)
	check(run.focus != other[0] and run.focus != null and camera.ball == run.focus, "the target wiped out: ball cam moves on")

	print("inside a school:")
	var into: School = run.focus.get_parent()
	var middle := into.middle()
	var line := Vector3(1, 0, 0.2).normalized()
	fish.freeze = false
	fish.global_transform = Transform3D(Basis.looking_at(line, Vector3.UP), middle - line * 25.0)
	camera.snap()
	# Settle on the approach first, then measure how fast the view turns over
	# each 0.05 s of the swim through (25 m in, 25 m out at 15 m/s).
	for i in 30:
		fish.linear_velocity = line * 15.0
		await get_tree().physics_frame
	var worst_turn := 0.0
	var last_forward: Vector3 = -camera.global_basis.z
	var window := 0.0
	var least_ahead := 1.0
	for i in 600:
		fish.linear_velocity = line * 15.0
		await get_tree().physics_frame
		window += 1.0 / 120.0
		var forward: Vector3 = -camera.global_basis.z
		var along := (fish.global_position - middle).dot(line)
		if along > -3.0 and along < 6.0:
			least_ahead = minf(least_ahead, forward.dot(line))
		if window >= 0.05:
			worst_turn = maxf(worst_turn, rad_to_deg(forward.angle_to(last_forward)) / window)
			last_forward = forward
			window = 0.0
	check(least_ahead > 0.7, "through the middle of the school and just out, ball cam looks ahead (dot %.2f at worst)" % least_ahead)
	check((-camera.global_basis.z).dot(line) < 0.0, "well past it, it turns round to the school again")
	check(worst_turn < 400.0, "no whip-around (fastest turn %.0f degrees/s)" % worst_turn)
	fish.linear_velocity = Vector3.ZERO

	print("elsewhere:")
	settings.lone_target = true
	settings.school_speed = 5.5
	main.set_mode(main.FREE_PLAY)
	await _ticks(10)
	check(not camera.hold_opens_wheel and main._target_wheel == null, "outside Nature: no wheel")
	was = camera.ball_cam
	Input.action_press("ball_cam")
	await _frames(3)
	check(camera.ball_cam != was, "a press toggles at once, as before")
	Input.action_release("ball_cam")
	await _frames(3)

	print("target_wheel_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## The right stick (camera_* actions) pushed toward `direction` (screen space, y down).
func _stick(direction: Vector2) -> void:
	for action in ["camera_left", "camera_right", "camera_up", "camera_down"]:
		Input.action_release(action)
	if direction.x > 0.0:
		Input.action_press("camera_right", direction.x)
	elif direction.x < 0.0:
		Input.action_press("camera_left", -direction.x)
	if direction.y > 0.0:
		Input.action_press("camera_down", direction.y)
	elif direction.y < 0.0:
		Input.action_press("camera_up", -direction.y)


func _press(seconds: float) -> void:
	Input.action_press("ball_cam")
	await _seconds(seconds)
	Input.action_release("ball_cam")
	await _frames(3)


func _seconds(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
