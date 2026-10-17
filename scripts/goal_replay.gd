class_name GoalReplay
extends Node3D
## Plays a goal back on replay ghosts (a GoalRecorder clip), shot like a
## broadcast replay, then emits finished. skip() (or the jump button) ends it.
##
## Two shots: a low chase camera off the scorer's shoulder as the play builds
## (on the ball, for an own goal), then a cut to a camera tucked in the back
## corner of the net as the ball comes in. Playback eases into slow motion for
## the finish, holds it through the goal explosion, and speeds back up.
##
## A battery replays the same way (Hunt): set `victim` and leave the net
## out. The victim stands in for the ball (the chase camera rides with the
## attacker toward it), the second shot is a camera off to the side of where
## they meet, and the explosion is a battery's. In open water (in_arena
## off) the cameras aren't kept inside the aquarium's walls. Both fish
## battered at once (a Fish Fry, `fish_fry`): the scorer stands for one, the
## victim the other, and both explode.
##
## `arcade` (Hunt) shoots it like an arcade fighter's finisher: a vignette
## that closes in with the attacker's flow, speed streaks, a hit-stop freeze
## at the impact with a flash, a punch-in and a shake. The fish show what they
## did live (their stride tails, bow waves and bubbles: ReplayCar), slowed
## with the playback.

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
## Arcade: the hit-stop at the impact, real seconds at FREEZE_RATE.
const IMPACT_FREEZE := 0.35
const FREEZE_RATE := 0.03
## Arcade: the impact's shake (m at its peak) and punch-in (share of the field
## of view), dying away at IMPACT_DECAY per real second.
const SHAKE := 0.35
const PUNCH := 0.22
const IMPACT_DECAY := 2.5
const VIGNETTE := preload("res://shaders/arcade_vignette.gdshader")

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
## A battery replay: the victim's player index in `data` (-1 for a goal).
var victim := -1
## The explosion's size at the goal (or battery).
var explosion_radius := AquariumArena.GOAL_EXPLOSION_RADIUS
## Keep the cameras inside the aquarium (off in open water).
var in_arena := true
## A Fish Fry: the scorer was battered too (explodes in scorer_color).
var fish_fry := false
var scorer_color := Color.WHITE
## Shot like an arcade finisher (see the class description).
var arcade := false
## Clip time now.
var time := 0.0
## "chase" or "net".
var shot := ""

var _ball: ReplayBall
## The ghosts, in the clip's player order.
var cars: Array[ReplayCar] = []
var _camera := Camera3D.new()
var _previous_camera: Camera3D
var _sample := ReplayData.Sample.new()
var _ball_position := Vector3.ZERO
var _aim := Vector3.ZERO
var _net_spot := Vector3.ZERO
var _scorer_position := Vector3.ZERO
var _exploded := false
var _done := false
var _freeze_left := 0.0
var _impact := 0.0  # 1 at the impact, dying away
var _flow_level := 0.0
var _vignette_layer := CanvasLayer.new()
var _vignette := ColorRect.new()
var _vignette_material := ShaderMaterial.new()


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
		cars.append(car)
	_camera.name = "ReplayCamera"
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_camera.near = 0.05
	add_child(_camera)
	_previous_camera = get_viewport().get_camera_3d()
	_camera.make_current()
	_net_spot = _net_camera_spot()
	if arcade:
		_vignette_layer.layer = 0  # under the HUD's replay card
		_vignette_material.shader = VIGNETTE
		_vignette.material = _vignette_material
		_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vignette_layer.add_child(_vignette)
		add_child(_vignette_layer)
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
	var rate := playback_rate(time)
	if _freeze_left > 0.0:
		_freeze_left -= delta
		rate = FREEZE_RATE
	time += delta * rate
	if time >= data.duration:
		_finish()
		return
	for car in cars:
		car.time_scale = rate
	_show(time)
	if not _exploded and time >= goal_time:
		_exploded = true
		Explosion.spawn(self, _ball_position, color, explosion_radius)  # no blast: just the show
		if fish_fry:
			Explosion.spawn(self, _scorer_position, scorer_color, explosion_radius)
		if arcade:
			_freeze_left = IMPACT_FREEZE
			_impact = 1.0
	_impact = maxf(_impact - IMPACT_DECAY * delta, 0.0)
	_frame(delta)
	if arcade:
		_update_vignette(delta)


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
	if _sample.present and victim < 0:
		_ball_position = _sample.position  # after the goal: where it went in
	for i in cars.size():
		cars[i].apply(data.sample_car(i, t, _sample))
		if i == victim and _sample.present:
			_ball_position = _sample.position  # after the battery: where it was hit
		if i == scorer and _sample.present:
			_scorer_position = _sample.position


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
		if scorer >= 0 and cars[scorer].visible:
			subject = cars[scorer].global_position
			subject_velocity = cars[scorer].linear_velocity
		var away := subject - _ball_position
		away.y = 0.0
		if away.length() < 1.0:  # on the ball (or watching the ball itself): behind its travel
			away = -Vector3(subject_velocity.x, 0.0, subject_velocity.z)
		if away.length() < 0.1:
			away = Vector3(0.0, 0.0, 1.0)
		away = away.normalized()
		var side := away.cross(Vector3.UP)
		eye = subject + away * CHASE_DISTANCE + Vector3.UP * CHASE_HEIGHT + side * CHASE_SIDE
		if in_arena:
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
	_camera.fov = fov * (1.0 - PUNCH * _impact)
	if _camera.global_position.distance_to(_aim) > 0.01:
		_camera.look_at(_aim, Vector3.UP)
	if _impact > 0.0:
		var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * SHAKE * _impact * _impact
		_camera.global_position += _camera.global_basis * shake


## Arcade: the vignette closes in with the attacker's flow (as recorded), with
## speed streaks as it flies, and flashes at the impact.
func _update_vignette(delta: float) -> void:
	var flow := 0.0
	var fast := 0.0
	if scorer >= 0 and cars[scorer].visible:
		var fx := cars[scorer].fx
		if fx.size() == ReplayData.FX_SIZE:
			flow = fx[ReplayData.FX_FLOW]
		fast = cars[scorer].speed
	# A little in even without flow: it's a replay, after all.
	_flow_level = move_toward(_flow_level, maxf(flow, 0.35), ArcadeFx.RESPONSE * delta)
	var size := _vignette.get_viewport_rect().size
	_vignette_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_vignette_material.set_shader_parameter("strength", _flow_level)
	_vignette_material.set_shader_parameter("heat", maxf(smoothstep(0.5, 1.0, _flow_level), _impact))
	_vignette_material.set_shader_parameter("streaks", smoothstep(0.3, 1.0, clampf(fast / 35.0, 0.0, 1.0)) * maxf(_flow_level, 0.5))
	_vignette_material.set_shader_parameter("flash", _impact)


## Low in the back corner of the net, on the far side from where the ball
## comes in, so it crosses the frame toward the camera.
func _net_camera_spot() -> Vector3:
	if goal == null and victim >= 0:
		return _impact_camera_spot()
	if goal == null:
		return Vector3(0.0, 3.0, 0.0)
	var entry := goal.to_local(data.sample_ball(maxf(goal_time - 0.05, 0.0), _sample).position)
	var across := -signf(entry.x) if absf(entry.x) > 0.5 else 1.0
	return goal.to_global(Vector3(across * (goal.width / 2.0 - 1.5), -goal.height / 2.0 + 1.7, goal.depth - 3.0))


## For a battery: off to the side of where the attacker meets the victim,
## a little above and a little past it, so the attacker crosses the frame into it.
func _impact_camera_spot() -> Vector3:
	var at := maxf(goal_time - 0.05, 0.0)
	var hit := data.sample_car(victim, at, _sample).position
	var approach := Vector3.FORWARD
	if scorer >= 0:
		var attacker := data.sample_car(scorer, at, _sample)
		if attacker.velocity.length() > 0.5:
			approach = attacker.velocity.normalized()
	var side := approach.cross(Vector3.UP)
	if side.length() < 0.1:
		side = approach.cross(Vector3.RIGHT)
	return hit + side.normalized() * 8.0 + approach * 1.5 + Vector3.UP * 2.0
