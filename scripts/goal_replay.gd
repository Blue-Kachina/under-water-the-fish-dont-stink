class_name GoalReplay
extends Node3D
## Plays a goal back on replay ghosts (a GoalRecorder clip), shot like a
## broadcast replay, then emits finished. skip() (or the jump button) ends it.
##
## Two shots: a low chase camera off the scorer's shoulder as the play builds
## (on the ball, for an own goal), then a cut to a camera tucked in the back
## corner of the net as the ball comes in. Playback eases into slow motion for
## the finish, holds it through the goal explosion, and speeds back up.

signal finished

## Slowest playback, at the goal.
const SLOW_MOTION := 0.3
## Playback eases down to SLOW_MOTION over this long before the goal (clip s).
const SLOW_LEAD := 0.7
## And stays there this long after it, then eases back to full speed.
const SLOW_HOLD := 0.45
const SPEED_UP := 0.4
## The cut to the net camera comes this long before the goal (clip s).
const NET_SHOT_LEAD := 1.3
## The chase camera: behind the subject (away from the ball), above, and off to the side (m).
const CHASE_DISTANCE := 6.5
const CHASE_HEIGHT := 1.8
const CHASE_SIDE := 2.2
const CHASE_FOV := 62.0
## How much of the way from the subject to the ball the chase camera aims.
const CHASE_AIM := 0.55
## The net camera zooms in from this field of view to the next over its shot.
const NET_FOV_START := 78.0
const NET_FOV_END := 46.0
## How quickly the camera eases toward its shot (1/s).
const EYE_RATE := 5.0
const AIM_RATE := 7.0

## The goal as a replay (time 0 = its start).
var data: ReplayData
## When in the clip the ball crossed the line.
var goal_time := 0.0
## The scorer's player index in `data`, or -1 (an own goal).
var scorer := -1
## The net the ball went into.
var goal: Goal
## The scoring team's colour (the explosion's).
var color := Color.WHITE
var ball_radius := ReplayBall.RADIUS
## Clip time now.
var time := 0.0
## "chase" or "net".
var shot := ""

var _ball: ReplayBall
var _cars: Array[ReplayCar] = []
var _camera := Camera3D.new()
var _previous_camera: Camera3D
var _sample := ReplayData.Sample.new()
var _ball_position := Vector3.ZERO
var _aim := Vector3.ZERO
var _net_spot := Vector3.ZERO
var _exploded := false
var _done := false


func setup(clip: ReplayData, goal_at: float, scorer_index: int, net: Goal, team_color: Color, radius: float) -> void:
	data = clip
	goal_time = goal_at
	scorer = scorer_index
	goal = net
	color = team_color
	ball_radius = radius


func _ready() -> void:
	_ball = ReplayBall.new()
	_ball.name = "ReplayBall"
	add_child(_ball)
	_ball.scale = Vector3.ONE * ball_radius / ReplayBall.RADIUS
	for player in data.players:
		var car := ReplayCar.new()
		car.setup(player)
		add_child(car)
		_cars.append(car)
	_camera.name = "ReplayCamera"
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_camera.near = 0.05
	add_child(_camera)
	_previous_camera = get_viewport().get_camera_3d()
	_camera.make_current()
	_net_spot = _net_camera_spot()
	_show(0.0)
	_frame(0.0)


## Ends the replay now.
func skip() -> void:
	_finish()


## Back to the camera that was showing before (also done on finishing).
func restore_camera() -> void:
	if _camera.current and is_instance_valid(_previous_camera):
		_previous_camera.make_current()


func _exit_tree() -> void:
	restore_camera()


func _process(delta: float) -> void:
	if _done:
		return
	if Input.is_action_just_pressed("jump"):
		skip()
		return
	time += delta * playback_rate(time)
	if time >= data.duration:
		_finish()
		return
	_show(time)
	if not _exploded and time >= goal_time:
		_exploded = true
		Explosion.spawn(self, _ball_position, color, AquariumArena.GOAL_EXPLOSION_RADIUS)  # no blast: just the show
	_frame(delta)


## Playback speed at clip time `t`: full speed, slowing into the goal.
func playback_rate(t: float) -> float:
	var to_goal := goal_time - t
	if to_goal > SLOW_LEAD:
		return 1.0
	if to_goal > 0.0:
		return lerpf(SLOW_MOTION, 1.0, smoothstep(0.0, 1.0, to_goal / SLOW_LEAD))
	return lerpf(SLOW_MOTION, 1.0, smoothstep(0.0, 1.0, (-to_goal - SLOW_HOLD) / SPEED_UP))


func _finish() -> void:
	if _done:
		return
	_done = true
	restore_camera()
	finished.emit()


func _show(t: float) -> void:
	_ball.apply(data.sample_ball(t, _sample))
	if _sample.present:
		_ball_position = _sample.position  # after the goal: where it went in
	for i in _cars.size():
		_cars[i].apply(data.sample_car(i, t, _sample))


## Places the camera for this moment's shot; `delta` 0 jumps straight to it.
func _frame(delta: float) -> void:
	var wanted := "net" if time >= goal_time - NET_SHOT_LEAD else "chase"
	var cut := wanted != shot or delta <= 0.0
	shot = wanted
	var eye: Vector3
	var aim: Vector3
	var fov: float
	if shot == "chase":
		var subject := _ball_position
		var subject_velocity := _ball.linear_velocity
		if scorer >= 0 and _cars[scorer].visible:
			subject = _cars[scorer].global_position
			subject_velocity = _cars[scorer].linear_velocity
		var away := subject - _ball_position
		away.y = 0.0
		if away.length() < 1.0:  # on the ball (or watching the ball itself): behind its travel
			away = -Vector3(subject_velocity.x, 0.0, subject_velocity.z)
		if away.length() < 0.1:
			away = Vector3(0.0, 0.0, 1.0)
		away = away.normalized()
		var side := away.cross(Vector3.UP)
		eye = subject + away * CHASE_DISTANCE + Vector3.UP * CHASE_HEIGHT + side * CHASE_SIDE
		eye = DirectorCamera._clear_of_walls(eye)
		aim = subject.lerp(_ball_position, CHASE_AIM)
		fov = CHASE_FOV
	else:
		eye = _net_spot
		aim = _ball_position
		var progress := clampf((time - (goal_time - NET_SHOT_LEAD)) / (NET_SHOT_LEAD + SLOW_HOLD), 0.0, 1.0)
		fov = lerpf(NET_FOV_START, NET_FOV_END, smoothstep(0.0, 1.0, progress))
	if cut:
		_camera.global_position = eye
		_aim = aim
	else:
		_camera.global_position = _camera.global_position.lerp(eye, 1.0 - exp(-EYE_RATE * delta))
		_aim = _aim.lerp(aim, 1.0 - exp(-AIM_RATE * delta))
	_camera.fov = fov
	if _camera.global_position.distance_to(_aim) > 0.01:
		_camera.look_at(_aim, Vector3.UP)


## Low in the back corner of the net, on the far side from where the ball
## comes in, so it crosses the frame toward the camera.
func _net_camera_spot() -> Vector3:
	if goal == null:
		return Vector3(0.0, 3.0, 0.0)
	var entry := goal.to_local(data.sample_ball(maxf(goal_time - 0.05, 0.0), _sample).position)
	var across := -signf(entry.x) if absf(entry.x) > 0.5 else 1.0
	return goal.to_global(Vector3(across * (goal.width / 2.0 - 1.5), -goal.height / 2.0 + 1.7, goal.depth - 3.0))
