extends Node
## What Stinks?'s cameras (WhatStinksCam): the follow cam is the default and
## really follows (and turns with) the Hunter; while a round is live the ball
## cam button locks on a school the way Nature's does (TargetWheel,
## FollowCamera.hold_opens_wheel): a tap toggles it and looks at the nearest
## school ahead, a hold opens the wheel, the stick and letting go lock on the
## chosen school, the stick alone leaves it, a wiped-out school moves it on;
## the lock-on keeps the Hunter's body and the school in frame at several sizes
## and forms; prey get the same; it all goes on round end, eaten and end().
## Also measures, for the record, how the old view (no follow cam settings)
## behaved when the Hunter turned.
##   Godot_console.exe --headless --path . res://tests/what_stinks_camera_probe.tscn

var main: Node
var game: WhatStinksMatch
var fish: FishController
var camera: Node
var settings := WhatStinksSettings.shared()
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
	await _ticks(5)
	settings.hide_time = 0.5
	settings.round_time = 600.0
	settings.round_over_time = 0.4
	settings.match_over_time = 600.0
	settings.arena_radius = 160.0
	settings.school_count = 2
	settings.school_min = 14
	settings.school_max = 16
	settings.school_speed = 0.0
	settings.min_players = 3
	settings.bot_hunter_rounds = 1
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	settings.variant = WhatStinksSettings.Variant.SWEEP
	settings.hunter_blind = false
	settings.form = "drowned_shark"
	HunterSize.shared().size_mult = 1.0
	main.set_mode(main.WHAT_STINKS)
	await _ticks(5)
	main.play_match()
	await _ticks(5)
	game = main.what_stinks

	print("countdown:")
	check(game.phase == WhatStinksMatch.Phase.COUNTDOWN and game.is_hunter(fish), "round 0 counting down, the local fish the Hunter")
	check(not camera.hold_opens_wheel and game.lock_cam.wheel == null, "no wheel before the round is live")
	await _frames(3)
	check(camera.steady_heading and camera.follow_style == camera.FOLLOW_SETTLE, "the follow cam (Settle style) is on from the start")
	while game.phase != WhatStinksMatch.Phase.LIVE:
		await _ticks(1)
	await _ticks(4)

	print("follow cam:")
	check(game.lock_cam.active and camera.hold_opens_wheel and game.lock_cam.wheel != null, "live: lock-on is on offer, the ball cam button holds a wheel")
	check(not camera.ball_cam, "the view is the follow cam by default (no lock-on)")
	var schools := game.field.schools
	var a: School = schools[0]
	var b: School = schools[1]
	fish.freeze = false
	var turned := await _turn_test()
	check(turned[0] > 40.0, "the follow cam turns when the Hunter does (view turned %.0f of 90 degrees)" % turned[0])
	check(turned[1] < 40.0, "and ends up behind it again (%.0f degrees off its heading)" % turned[1])
	# The old view, for the record: no follow cam settings.
	game.lock_cam.set_process(false)
	UnnaturalRun.steady_camera(camera, false, UnnaturalSettings.shared())
	var old := await _turn_test()
	print("  (old view, no follow cam settings: turned %.0f degrees, %.0f off its heading)" % [old[0], old[1]])
	UnnaturalRun.steady_camera(camera, true, UnnaturalSettings.shared())
	game.lock_cam.set_process(true)
	await _ticks(3)

	print("tap:")
	# The Hunter off the line between the schools, A ahead, B behind and nearer.
	var middle_a := a.centre.global_position
	var middle_b := b.centre.global_position
	var along := (middle_a - middle_b).normalized()
	var side := along.cross(Vector3.UP).normalized()
	var place := middle_b.lerp(middle_a, 0.4) + side * 25.0
	_place(place, middle_a - place)
	fish.freeze = true
	await _ticks(3)
	var cam := game.lock_cam
	check(cam.targets().size() == 2, "the wheel lists a slice per live school (%d)" % cam.targets().size())
	check(place.distance_to(middle_b) < place.distance_to(middle_a), "(B is the nearer school, A the one ahead)")
	await _press(0.1)
	check(camera.ball_cam and not camera.wheel_open, "a tap turns lock-on on")
	check(cam.focus_of(fish) == a.centre and camera.ball == a.centre, "and looks at the school ahead, not the nearer one behind")
	await _ticks(60)
	check((-camera.global_basis.z).dot((a.centre.global_position - camera.global_position).normalized()) > 0.9, "the view faces the school")
	await _press(0.1)
	check(not camera.ball_cam, "a second tap turns it off")

	print("hold:")
	Input.action_press("ball_cam")
	await _seconds(settings.wheel_hold_time + 0.15)
	var wheel: TargetWheel = cam.wheel
	check(camera.wheel_open and wheel.is_open and not camera.ball_cam, "holding opens the wheel, lock-on left as it was")
	var entries := cam.targets()
	var names_ok := true
	for entry: Array in entries:
		names_ok = names_ok and str(entry[1]) != "" and int(entry[2]) > 0
	check(names_ok, "each slice has a name and fish left")
	var want: Node3D = b.centre
	var toward: Vector2 = wheel._direction_of(want)
	var other: Vector2 = wheel._direction_of(a.centre)
	check(absf(angle_difference(toward.angle(), other.angle())) > 0.3, "(the two slices point different ways)")
	_stick(toward)
	await _ticks(4)
	check(wheel.picked[0] == want, "the stick toward B picks it")
	_stick(Vector2.ZERO)
	await _ticks(2)
	Input.action_release("ball_cam")
	await _ticks(4)
	check(not camera.wheel_open and cam.focus_of(fish) == want and camera.ball == want and camera.ball_cam, "letting go locks on B, lock-on on")

	print("stick alone:")
	Input.action_press("ball_cam")
	await _seconds(settings.wheel_hold_time + 0.15)
	Input.action_release("ball_cam")
	await _ticks(4)
	check(cam.focus_of(fish) == want and camera.ball_cam, "opening and closing without the stick stays on B")

	print("wiped out:")
	b._alive.fill(0)
	await _ticks(4)
	check(cam.focus_of(fish) == a.centre and camera.ball == a.centre, "B wiped out: the lock moves on to A")
	check(cam.targets().size() == 1, "the wheel lists only the live school")
	a._alive.fill(0)
	await _ticks(4)
	check(cam.focus_of(fish) == null and camera.ball == null and cam.targets().is_empty(), "no school left: nothing locked, the view stays a follow cam")

	print("round end:")
	game.field.build(game.center, 7)  # schools again for the next round
	await _ticks(3)
	await _press(0.1)
	Input.action_press("ball_cam")
	await _seconds(settings.wheel_hold_time + 0.15)
	check(camera.wheel_open and wheel.is_open, "(wheel open again)")
	game._end_round(false)
	await _ticks(4)
	check(not cam.active and not camera.hold_opens_wheel and not camera.ball_cam and camera.ball == null, "round over: lock-on off, no button hold, ball cam off")
	check(not is_instance_valid(wheel) or wheel.is_queued_for_deletion(), "the wheel is gone")
	check(not camera.wheel_open, "and the camera's wheel flag is clear")
	Input.action_release("ball_cam")
	await _ticks(4)
	check(not camera.ball_cam and camera.steady_heading, "letting go changes nothing; the follow cam stays")

	print("next round (the Hunter is a bot, the local fish is prey):")
	while game.phase != WhatStinksMatch.Phase.LIVE or game.round_index != 1:
		await _ticks(1)
	await _ticks(4)
	check(not game.is_hunter(fish) and cam.active and camera.hold_opens_wheel and cam.wheel != null, "prey get lock-on and the wheel too")
	await _press(0.1)
	check(camera.ball_cam and cam.focus_of(fish) != null, "a prey's tap locks on a school")
	settings.lock_on_prey = false
	await _ticks(3)
	check(not cam.active and not camera.hold_opens_wheel and not camera.ball_cam, "lock_on_prey off: prey have the follow cam only")
	settings.lock_on_prey = true
	await _ticks(3)
	check(cam.active, "and back on")

	print("eaten:")
	var hunter: FishController = game.hunters[0]
	game._eat(fish, hunter)
	await _ticks(4)
	check(game.is_spectating() and not cam.active and cam.wheel == null and not camera.hold_opens_wheel and not camera.ball_cam, "eaten: no lock-on, no wheel, spectating")
	check(camera.target != null, "the spectate cycling still has the camera on a fish")
	var watching: Variant = camera.target
	game.cycle_spectate(1)
	check(camera.target != null, "cycling spectate works (%s)" % ("same" if camera.target == watching else "switched"))

	print("framing:")
	game.start_match()  # the local fish is the Hunter in round 0 again
	await _ticks(3)
	while game.phase != WhatStinksMatch.Phase.LIVE or not game.is_hunter(fish):
		await _ticks(1)
	await _ticks(4)
	for form: String in ["drowned_shark", "king_of_herrings", "gulper_mother"]:
		for size in [0.5, 1.0, 3.0, 10.0]:
			await _frame_test(form, size)

	print("mode exit:")
	var lock := game.lock_cam
	main.set_mode(main.FREE_PLAY)
	await _ticks(10)
	check(main.what_stinks == null and not camera.hold_opens_wheel and not camera.ball_cam and not camera.steady_heading, "leaving the mode hands the camera back")
	check(camera.body_follow == 1.0 and camera.extra_distance == 0.0, "body_follow and the extra distance reset")
	var wheels := 0
	for child in camera.get_parent().get_children():
		if child is TargetWheel:
			wheels += 1
	check(wheels == 0, "no wheel left in the scene (%d)" % wheels)
	check(not is_instance_valid(lock), "the lock-on node is freed with the match")

	print("what_stinks_camera_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## Swims the Hunter at 8 m/s, then turns it 90 degrees to the right and keeps going. Returns [degrees the view turned, degrees it is off the fish's heading at the end].
func _turn_test() -> Array:
	var start := game.center + Vector3(0, 0, 0)
	var first := Vector3(0, 0, -1)
	_place(start, first)
	fish.freeze = false
	camera.snap()
	for i in 90:
		fish.linear_velocity = first * 8.0
		await get_tree().physics_frame
	var before: Vector3 = -camera.global_basis.z
	var second := Vector3(1, 0, 0)
	fish.global_transform = Transform3D(Basis.looking_at(second, Vector3.UP), fish.global_position)
	for i in 300:
		fish.linear_velocity = second * 8.0
		await get_tree().physics_frame
	var after: Vector3 = -camera.global_basis.z
	fish.linear_velocity = Vector3.ZERO
	return [rad_to_deg(before.angle_to(after)), rad_to_deg(after.angle_to(second))]


## A form at a size, locked on a school 70 m ahead: the Hunter's whole body and the school's middle are on screen.
func _frame_test(form: String, size: float) -> void:
	settings.form = form
	HunterSize.shared().size_mult = size
	game._become_hunter(fish)
	await _ticks(3)
	var a: School = game.field.schools[0]
	var ahead := Vector3(0.6, 0.0, -0.8)
	var spot := a.centre.global_position - ahead * 70.0
	_place(spot, ahead)
	fish.freeze = true
	camera.set("ball_cam", true)
	game.lock_cam.set_focus(a.centre, fish)
	camera.snap()
	await _ticks(90)
	var rect: Rect2 = camera.get_viewport().get_visible_rect()
	var forward := -fish.global_basis.z
	var half := fish.hitbox_length * 0.5
	var body_ok := true
	for point: Vector3 in [fish.global_position, fish.global_position + forward * half, fish.global_position - forward * half]:
		if camera.is_position_behind(point) or not rect.grow(8.0).has_point(camera.unproject_position(point)):
			body_ok = false
	var school_at: Vector3 = a.centre.global_position
	var school_ok: bool = not camera.is_position_behind(school_at) and rect.has_point(camera.unproject_position(school_at))
	check(body_ok and school_ok, "%s at %.1fx: the body (%.1f m) and the school are in frame (body %s, school %s, camera %.1f m back)" % [form, size, fish.hitbox_length, body_ok, school_ok, camera.global_position.distance_to(fish.global_position)])


func _place(at: Vector3, facing: Vector3) -> void:
	fish.global_transform = Transform3D(Basis.looking_at(facing.normalized(), Vector3.UP), at)
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


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
