## The replay director: it's the camera when a replay opens, has whoever
## touches the ball on screen, keeps the watched player and the ball in view, stays inside the
## arena and moves smoothly between cuts. Then the viewer's choices: a Target
## player stays watched, Camera: Player hands over to the follow camera (which
## Auto still steers), and Free stands still (turning to the ball on Director).
## Run headless at a fixed 120 fps (one rendered frame per physics tick):
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/director_probe.tscn [-- REAL.rlreplay.json [START_S SECONDS]]
## Without a file it uses the converter's fixture.
extends Node

const FIXTURE := "res://tests/fixtures/replay_fixture.rlreplay.json"
## Between cuts, a frame where the camera's velocity changes by more than
## JOLT_EYE (m/s; its springs allow about 1) or its turning by more than
## JOLT_TURN (deg/s) is a jolt. Allowed: a few (JOLT_SHARE of frames; brief
## bumps where the camera's squeezed against a wall or crowded close to the
## play), none worse than MAX_EYE_STEP / MAX_TURN_STEP. These record what's
## achieved now (2026-10-11: 0.2-0.5% of frames, worst 7 m/s and 45 deg/s), so
## they catch regressions like the snaps of hundreds fixed on the way.
const JOLT_EYE := 1.2
const JOLT_TURN := 15.0
const JOLT_SHARE := 0.01
const MAX_EYE_STEP := 10.0
const MAX_TURN_STEP := 90.0
## Of all frames, the watched player and the ball must both be in view in this share.
const IN_VIEW_SHARE := 0.85

var main: Node
var replay: ReplayPlayer
var director: DirectorCamera
var failures := 0
var stage := "loading"
var start := 0.0
var seconds := 0.0
var frames := 0
var cuts := 0
var touches_seen := 0
var touches_watched := 0
var in_view := 0
var outside := 0
var worst_eye := 0.0
var worst_turn := 0.0
var switches := 0
var last_focus := -1
var prev_eye := Vector3.ZERO
var prev_eye_speed := Vector3.ZERO
var prev_forward := Vector3.FORWARD
var prev_turn := 0.0
var just_cut := 2
var worst_turn_note := ""
var worst_eye_note := ""
var prev_focus := -1
## The last few frames' camera state, printed with the worst moment.
var recent: Array[String] = []
var worst_recent := ""
var jolts := 0


func _ready() -> void:
	process_priority = 100  # after the director camera has moved
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var args := OS.get_cmdline_user_args()
	var path := ProjectSettings.globalize_path(FIXTURE) if args.is_empty() else args[0]
	start = float(args[1]) if args.size() > 1 else 0.0
	seconds = float(args[2]) if args.size() > 2 else 1e9
	print("director on %s:" % path.get_file())
	main.load_replay(path)


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _process(delta: float) -> void:
	match stage:
		"loading":
			if main.replay == null:
				return
			replay = main.replay
			director = replay.director_camera
			check(replay.watch == ReplayPlayer.AUTO and replay.view == ReplayPlayer.View.DIRECTOR and director.current,
					"the director is the camera when a replay opens (Target Auto, Camera Director)")
			replay.cut.connect(func() -> void: just_cut = 2)
			replay.seek(start)
			seconds = minf(seconds, replay.data.duration - start - 0.1)
			stage = "watching"
		"watching":
			_watch(delta)
			if replay.time >= start + seconds or not replay.playing:
				_report()
				_check_choices()
				print("director_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
				stage = "done"
				get_tree().quit(1 if failures else 0)


func _watch(delta: float) -> void:
	frames += 1
	var t := replay.time
	var eye := director.global_position
	var forward := -director.global_basis.z
	if director.focus != last_focus:
		if last_focus >= 0:
			switches += 1
		last_focus = director.focus
	recent.append("      %.3f s focus %d eye %s ride %s player %s offset %s" % [t, director.focus, eye, director._ride, director._subject, director._eye_offset])
	if recent.size() > 4:
		recent.pop_front()
	# A cut: the director jumped to a far shot (or the replay did).
	if eye.distance_to(prev_eye) > 2.0:
		just_cut = 2
		cuts += 1
	var eye_speed := (eye - prev_eye) / delta
	var turn := rad_to_deg(prev_forward.angle_to(forward)) / delta
	if just_cut > 0:
		just_cut -= 1
	else:
		var eye_step := (eye_speed - prev_eye_speed).length() / replay.speed
		var turn_step := absf(turn - prev_turn) / replay.speed
		var note := "at %.2f s (focus %d -> %d, aim %.1f m away, ball %s, car %s)" % [t, prev_focus, director.focus,
				director._aim.distance_to(eye), "shown" if replay.ball.visible else "hidden",
				"shown" if replay.target and replay.target.visible else "hidden"]
		if eye_step > JOLT_EYE or turn_step > JOLT_TURN:
			jolts += 1
		if eye_step > worst_eye:
			worst_eye = eye_step
			worst_eye_note = note
			worst_recent = "\n".join(recent)
		if turn_step > worst_turn:
			worst_turn = turn_step
			worst_turn_note = note
	prev_focus = director.focus
	prev_eye = eye
	prev_eye_speed = eye_speed
	prev_forward = forward
	prev_turn = turn

	if AquariumArena.distance_outside(eye) > 0.0:
		outside += 1
	var car := replay.target
	var both := car != null and car.visible and director.is_position_in_frustum(car.global_position)
	if replay.ball.visible:
		both = both and director.is_position_in_frustum(replay.ball.global_position)
	if both:
		in_view += 1
	# At each touch: is the director watching the toucher?
	for event in replay.data.events:
		if event.type == "touch" and event.get("player") != null and event.time > t - delta and event.time <= t:
			touches_seen += 1
			var toucher := replay.cars[event.player]
			if toucher.visible and director.is_position_in_frustum(toucher.global_position):
				touches_watched += 1


func _report() -> void:
	print("  watched %.0f s of play, %d frames, %d players" % [seconds, frames, replay.cars.size()])
	check(touches_seen == 0 or touches_watched >= 0.75 * touches_seen,
			"the toucher on screen at %d of %d touches" % [touches_watched, touches_seen])
	check(in_view >= IN_VIEW_SHARE * frames, "watched player and ball both in view %.0f%% of the time" % [100.0 * in_view / frames])
	check(outside == 0, "camera inside the arena (outside %d frames)" % outside)
	check(worst_eye <= MAX_EYE_STEP and worst_turn <= MAX_TURN_STEP and jolts <= JOLT_SHARE * frames,
			"smooth between cuts (%d jolting frames): velocity changes at most %.2f m/s %s; turning %.1f deg/s in a frame %s" % [jolts, worst_eye, worst_eye_note, worst_turn, worst_turn_note])
	if worst_eye > MAX_EYE_STEP or jolts > JOLT_SHARE * frames:
		print(worst_recent)
	var minutes := seconds / 60.0
	check(cuts / maxf(minutes, 0.2) <= 18.0, "%d cuts and %d changes of player (%.1f / %.1f a minute)" % [cuts, switches, cuts / minutes, switches / minutes])


func _check_choices() -> void:
	var follow_camera: Variant = main.get_node("FollowCamera")  # FollowCamera (no class_name)
	var touches: Array[Dictionary] = []
	for event in replay.data.events:
		if event.type == "touch" and event.get("player") != null:
			touches.append(event)
	replay.playing = false

	# Target a player: the director frames them and never switches, whoever touches the ball.
	var locked: int = touches[0].player
	replay.set_watch(locked)
	var stayed := true
	var others := 0
	for event in touches:
		replay.seek(event.time - 1.0)
		_settle()
		stayed = stayed and director.focus == locked and replay.follow == locked
		others += 1 if event.player != locked else 0
	check(stayed and director.current, "Target on a player: the director stays on them through %d touches by others" % others)

	# Camera: Player on that player: the car cam.
	replay.view = ReplayPlayer.View.PLAYER
	check(follow_camera.current and follow_camera.target == replay.cars[locked], "Camera Player: the car cam follows them")

	# Target Auto with Camera Player: the director's picks steer the car cam.
	replay.set_watch(ReplayPlayer.AUTO)
	var steered := 0
	var agreed := true
	for event in touches:
		replay.seek(event.time - 0.5)
		director._held = DirectorCamera.MIN_HOLD  # as if played this far (paused, it doesn't count)
		_settle()
		agreed = agreed and follow_camera.current and replay.follow == director.focus 				and follow_camera.target == replay.cars[replay.follow]
		steered += 1 if replay.follow == event.player else 0
	check(agreed and steered >= 0.7 * touches.size(),
			"Auto + Player: the car cam follows the director's pick (the next toucher at %d of %d touches)" % [steered, touches.size()])

	# Free: stands where the view was. On Player it holds still; on Director it turns to the ball.
	replay.seek(touches[0].time)
	_settle()
	var shot: Transform3D = follow_camera.global_transform
	replay.set_watch(ReplayPlayer.FREE)
	check(director.current and director.global_transform.is_equal_approx(shot), "Free: stays where the view was")
	replay.seek(touches[touches.size() / 2].time)
	_settle()
	check(director.global_transform.is_equal_approx(shot), "Free + Player: holds still while the play moves on")
	replay.view = ReplayPlayer.View.DIRECTOR
	var off_before := _angle_to_ball()
	_settle(120)
	check(director.global_position.is_equal_approx(shot.origin) and _angle_to_ball() < minf(off_before, 10.0),
			"Free + Director: stays put and turns to the ball (%.0f deg off, from %.0f)" % [_angle_to_ball(), off_before])

	# Back from Free to a player.
	replay.set_watch(locked)
	_settle()
	check(director.current and director.focus == locked, "and back to a player")
	main.stop_replay()
	check(follow_camera.current, "closing the replay restores the follow camera")


## Runs the director (paused, so the replay holds still) for `steps` frames.
func _settle(steps := 1) -> void:
	for i in steps:
		director._process(1.0 / 120.0)


func _angle_to_ball() -> float:
	return rad_to_deg((-director.global_basis.z).angle_to(replay.ball.global_position - director.global_position))
