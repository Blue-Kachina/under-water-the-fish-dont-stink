class_name DirectorCamera
extends Camera3D
## The replay's director: picks who to watch and frames the play like a
## broadcast, with no input needed (like RL's Director mode in replays).
##
## Who: a replay knows what happens next, so the director watches whoever
## touches the ball next (looking up to LOOKAHEAD ahead; during a kickoff
## countdown, the kickoff taker), or else the car that would reach the ball
## first. Someone who just touched it stays the pick a moment longer. It only
## switches to them if they aren't already in shot, and holds a player at least
## MIN_HOLD, unless its car is gone or play restarts. After a goal, the
## scorer, with the goal in view.
##
## How: from behind the player, on the far side from the ball, a little above,
## looking at a point between them, so both are in view. The camera rides along
## with a smoothed copy of the player, which keeps up with them however fast
## they go but spreads a sudden jolt (a dodge, a bump, a landing) over a moment.
## Its place around them moves on critically damped springs (no jerks),
## swinging round at a limited speed when the ball goes past. A new player nearby is glided to; one far off or out of view is
## cut to, as is any jump in the replay.
##
## With the viewer's Target on a player, it frames them and never switches.
## Its picks also steer the car cam when the Target is Auto and the Camera is
## Player, switching to the next toucher even when they're in shot. With the Target on Free, this camera stays where it is: turning to
## follow the ball (Camera: Director) or holding still (Camera: Player).

## Seconds ahead to look for the next touch.
const LOOKAHEAD := 2.5
## Seconds a player who just touched the ball stays the pick.
const AFTER_TOUCH := 0.6
## The least time on one player before switching (replay seconds).
const MIN_HOLD := 4.0
## Shot: distance behind the player and height above (m), and how far toward
## the ball the camera aims (0 = at the player, 1 = at the ball).
const DISTANCE := 7.5
const HEIGHT := 2.4
const BALL_WEIGHT := 0.4
## Cut, don't glide, to a new player further than this (m) from the last one,
## or out of view. Also, for tests: a camera move this far in a frame is a cut.
const CUT_DISTANCE := 10.0
## Spring frequencies (1/s) for the camera's place around the player and its
## aim, and the most their speeds may change (m/s^2), so moves start gently.
const EYE_RATE := 3.0
const AIM_RATE := 4.0
const EYE_ACCEL := 35.0
const AIM_ACCEL := 60.0
## Riding along with the player: spring frequency (1/s) and the most the
## camera's speed may change (m/s^2), smoothing out their car's jolts. A jump
## further than SUBJECT_JUMP (m) in a frame is a teleport: cut.
const RIDE_RATE := 6.0
const RIDE_ACCEL := 80.0
const SUBJECT_JUMP := 3.0
## Swinging round the player as the ball moves: spring frequency (1/s) and the
## most its turning speed may change (rad/s^2).
const ORBIT_RATE := 2.5
const ORBIT_ACCEL := 8.0
## The camera keeps clear of the arena's walls, floor and ceiling: within
## WALL_MARGIN (m) of them it's eased away, the push growing smoothly over
## WALL_SOFTNESS (m), so it slides along a wall rather than stopping dead.
## It never gets closer than WALL_MARGIN - WALL_SOFTNESS / 2.
const WALL_MARGIN := 2.2
const WALL_SOFTNESS := 2.5
## How gradually the arena's walls blend into each other at corners (m).
const FIELD_SOFTNESS := 1.0
## Within this distance (m) of a wall or the ceiling, "above" a player turns
## to point away from it.
const SURFACE_REACH := 3.0
## A player on screen and nearer than this (m) counts as in shot: no need to switch to them.
const IN_SHOT_DISTANCE := 30.0
const FIELD_OF_VIEW := 95.0
## The free camera turning to follow the ball: spring frequency (1/s) and the
## most its aim's speed may change (m/s^2).
const FREE_AIM_RATE := 3.0
const FREE_AIM_ACCEL := 120.0

var player: ReplayPlayer
## The player index being watched (-1 before the first pick).
var focus := -1

var _held := 0.0
var _eye := Vector3.ZERO
## Where the camera would be without the wall cushion (see _clear_of_walls).
var _eye_free := Vector3.ZERO
var _eye_speed := Vector3.ZERO
var _aim := Vector3.ZERO
var _aim_speed := Vector3.ZERO
var _cut := true
var _sample := ReplayData.Sample.new()
## Where the watched player is (kept while their car is briefly gone), and the
## smoothed copy the camera rides along with, with its velocity.
var _subject := Vector3.ZERO
var _ride := Vector3.ZERO
var _ride_speed := Vector3.ZERO
## The player the offsets below are relative to.
var _framed := -1
## The camera's and aim's offsets from the player, and how fast they're changing.
var _eye_offset := Vector3.ZERO
var _eye_offset_speed := Vector3.ZERO
var _aim_offset := Vector3.ZERO
var _aim_offset_speed := Vector3.ZERO
## Which way from the player the camera sits (level, unit), and how fast that's turning (rad/s).
var _orbit := Vector3.BACK
var _orbit_speed := 0.0


func setup(replay_player: ReplayPlayer) -> void:
	player = replay_player
	name = "DirectorCamera"


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	keep_aspect = Camera3D.KEEP_WIDTH  # fov is horizontal, like the follow camera's
	fov = FIELD_OF_VIEW
	player.cut.connect(func() -> void: _cut = true)


## The next frame jumps straight to its shot.
func cut() -> void:
	_cut = true


## Stand where `camera` is now, looking the same way (the free camera).
func hold(camera: Camera3D) -> void:
	if camera != null and camera != self:
		global_transform = camera.global_transform
		fov = camera.fov
	_eye = global_position
	var ball := player.ball.global_position
	_aim = _eye - global_basis.z * maxf(_eye.distance_to(ball), 1.0)
	_aim_speed = Vector3.ZERO
	_cut = false


func _process(delta: float) -> void:
	if player == null or player.cars.is_empty():
		return
	# The shot follows the replay's own clock, so playback speed doesn't loosen it.
	var dt := delta * (player.speed if player.playing else 1.0)
	_held += dt if player.playing else 0.0
	if player.watch == ReplayPlayer.AUTO:
		_choose_focus()
	elif player.watch >= 0:
		focus = player.watch
	if player.watch == ReplayPlayer.FREE:
		_free_look(dt)
		return
	fov = FIELD_OF_VIEW
	if focus < 0 or not current:
		return
	var car := player.cars[focus]
	if car.visible:
		if focus == _framed and car.global_position.distance_to(_subject) > SUBJECT_JUMP:
			_cut = true  # teleported
		_subject = car.global_position
	elif _framed < 0:
		return  # nothing to show yet
	var subject_speed: Vector3 = car.linear_velocity if car.visible else Vector3.ZERO

	# A new player: glide over if they're near and in view; otherwise cut.
	var switched := focus != _framed
	if switched and (_ride.distance_to(_subject) > CUT_DISTANCE or not is_position_in_frustum(_subject)):
		_cut = true
	_framed = focus

	# The smoothed player: a spring that also knows their velocity, so it keeps
	# up exactly with steady motion and smooths out sudden changes.
	if _cut:
		_ride = _subject
		_ride_speed = subject_speed
	else:
		var pull := (_subject - _ride) * RIDE_RATE * RIDE_RATE + (subject_speed - _ride_speed) * 2.0 * RIDE_RATE
		if pull.length() > RIDE_ACCEL:
			pull = pull.normalized() * RIDE_ACCEL
		_ride_speed += pull * dt
		_ride += _ride_speed * dt
	var subject := _ride
	var target := player.ball.global_position if player.ball.visible else _goal_ball(subject)
	if switched and not _cut:
		# Gliding: the view stays put for now, and eases over from here.
		_eye_offset = _eye_free - subject
		_aim_offset = _aim - subject
		var flat := Vector3(_eye_offset.x, 0.0, _eye_offset.z)
		_orbit = flat.normalized() if flat.length_squared() > 0.01 else _orbit

	# "Above" the player: away from the surface they're on or near (a wall, the
	# ceiling), blending to straight up away from them.
	var field := _arena_field(subject)
	var near_surface := clampf(1.0 - (-(field[0] as float)) / SURFACE_REACH, 0.0, 1.0)
	var above := Vector3.UP.lerp(-(field[1] as Vector3), near_surface).normalized()

	# The camera's side: away from the ball, swinging round as it moves, and
	# round to the side in good time when that spot is up against a wall.
	var across := Vector3(target.x - subject.x, 0.0, target.z - subject.z)
	var want_orbit := _clear_side(subject, above, -across.normalized() if across.length() > 1.0 else _orbit)
	if _cut:
		_orbit = want_orbit
		_orbit_speed = 0.0
	else:
		var angle := _orbit.signed_angle_to(want_orbit, Vector3.UP)
		var turned := _spring(-angle, _orbit_speed, ORBIT_RATE, dt, ORBIT_ACCEL)
		_orbit_speed = turned.y
		_orbit = _orbit.rotated(Vector3.UP, turned.x + angle).normalized()

	var eye_offset := _orbit * DISTANCE + above * HEIGHT
	# Aim between player and ball, nearer the player when the ball is far off.
	var weight := BALL_WEIGHT * clampf(25.0 / maxf(subject.distance_to(target), 0.1), 0.3, 1.0)
	var aim_offset := (target - subject) * weight
	if _cut:
		_eye_offset = eye_offset
		_aim_offset = aim_offset
		_eye_offset_speed = Vector3.ZERO
		_aim_offset_speed = Vector3.ZERO
		_cut = false
	else:
		var eye_step := _spring_3d(_eye_offset - eye_offset, _eye_offset_speed, EYE_RATE, dt, EYE_ACCEL)
		_eye_offset = eye_offset + eye_step[0]
		_eye_offset_speed = eye_step[1]
		var aim_step := _spring_3d(_aim_offset - aim_offset, _aim_offset_speed, AIM_RATE, dt, AIM_ACCEL)
		_aim_offset = aim_offset + aim_step[0]
		_aim_offset_speed = aim_step[1]

	_eye_free = subject + _eye_offset
	_eye = _clear_of_walls(_eye_free)
	_aim = subject + _aim_offset

	var forward := _aim - _eye
	if forward.length_squared() < 0.0001:
		return
	# Level, except looking nearly straight up or down, where the last frame's up holds.
	var up := Vector3.UP if absf(forward.normalized().y) < 0.98 else global_basis.y
	global_transform = Transform3D(Basis.looking_at(forward, up), _eye)


## The free camera: stays put, turning to follow the ball smoothly with the
## Camera on Director (its aim rides a spring that knows the ball's velocity),
## or holding still with it on Player.
func _free_look(dt: float) -> void:
	if player.view != ReplayPlayer.View.DIRECTOR or not player.ball.visible:
		_aim_speed = Vector3.ZERO
		return
	var ball := player.ball.global_position
	if _cut:
		_aim = ball
		_aim_speed = player.ball.linear_velocity
		_cut = false
	else:
		var pull := (ball - _aim) * FREE_AIM_RATE * FREE_AIM_RATE + (player.ball.linear_velocity - _aim_speed) * 2.0 * FREE_AIM_RATE
		if pull.length() > FREE_AIM_ACCEL:
			pull = pull.normalized() * FREE_AIM_ACCEL
		_aim_speed += pull * dt
		_aim += _aim_speed * dt
	var forward := _aim - global_position
	if forward.length_squared() < 0.01:
		return
	var up := Vector3.UP if absf(forward.normalized().y) < 0.98 else global_basis.y
	global_basis = Basis.looking_at(forward, up)


## The way round the player nearest to `side` (level) whose camera spot is
## clear of the walls (WALL_MARGIN plus WALL_SOFTNESS), or `side` itself if
## none is.
func _clear_side(subject: Vector3, above: Vector3, side: Vector3) -> Vector3:
	for degrees: float in [0.0, 25.0, -25.0, 50.0, -50.0, 75.0, -75.0, 100.0, -100.0]:
		var turned := side.rotated(Vector3.UP, deg_to_rad(degrees))
		var spot := subject + turned * DISTANCE + above * HEIGHT
		if (_arena_field(spot)[0] as float) < -(WALL_MARGIN + WALL_SOFTNESS):
			return turned
	return side


## Who to watch now (see the class description).
func _choose_focus() -> void:
	var data := player.data
	var t := player.time
	var state := data.state_at(t)
	var pick := -1
	if state == ReplayData.GAME_POST_GOAL:
		var goal := _last_event("goal", t)
		if not goal.is_empty() and goal.get("player") != null:
			pick = goal.player
	if pick < 0:
		var horizon := 1e9 if state == ReplayData.GAME_COUNTDOWN else LOOKAHEAD
		var touch := _touch_near(t, horizon)
		if not touch.is_empty():
			pick = touch.player
	if pick < 0 or not _present(pick, t):
		pick = _first_to_ball(t)
	if pick < 0:
		return
	var restarted := state != ReplayData.GAME_LIVE and data.state_at(maxf(t - 0.1, 0.0)) == ReplayData.GAME_LIVE
	var must_switch := focus < 0 or not _present(focus, t) or restarted
	# No need to move while the pick is already well in shot (on the director's
	# framing; on the car cam, ride with whoever's playing the ball).
	if not must_switch and player.view == ReplayPlayer.View.DIRECTOR and _in_shot(pick):
		return
	if pick != focus and (must_switch or _held >= MIN_HOLD):
		focus = pick
		_held = 0.0
		player.set_target(focus)


## The touch that decides the pick: one just made (within AFTER_TOUCH), or else
## the next one within `horizon` seconds.
func _touch_near(t: float, horizon: float) -> Dictionary:
	var upcoming := {}
	for event in player.data.events:
		if event.type != "touch" or event.get("player") == null:
			continue
		if event.time > t - AFTER_TOUCH and event.time <= t:
			upcoming = event  # the latest one just made
		elif event.time > t:
			if upcoming.is_empty() and event.time <= t + horizon:
				return event
			break
	return upcoming


func _last_event(type: String, t: float) -> Dictionary:
	var found := {}
	for event in player.data.events:
		if event.time > t:
			break
		if event.type == type:
			found = event
	return found


## The present car that would get to the ball soonest, going by distance and
## how fast it's already heading there.
func _first_to_ball(t: float) -> int:
	var data := player.data
	data.sample_ball(t, _sample)
	var ball := _sample.position
	var best := -1
	var best_time := INF
	for i in data.cars.size():
		data.sample_car(i, t, _sample)
		if not _sample.present:
			continue
		var to_ball := ball - _sample.position
		var closing := maxf(_sample.velocity.dot(to_ball.normalized()), 0.0)
		var eta := to_ball.length() / maxf(closing, 5.0)
		if eta < best_time:
			best_time = eta
			best = i
	return best


## Whether player `index` is on screen now (on whichever camera is showing),
## not too far off to make out.
func _in_shot(index: int) -> bool:
	var car := player.cars[index]
	var camera := get_viewport().get_camera_3d()
	return car.visible and camera != null and camera.is_position_in_frustum(car.global_position) \
			and camera.global_position.distance_to(car.global_position) < IN_SHOT_DISTANCE


func _present(index: int, t: float) -> bool:
	return index >= 0 and index < player.cars.size() and player.data.sample_car(index, t, _sample).present


## Where the ball went in, for the shot after a goal (the ball's gone).
func _goal_ball(fallback: Vector3) -> Vector3:
	var goal := _last_event("goal", player.time)
	if goal.is_empty():
		return fallback
	var at := player.data.frame_at(goal.time)
	for i in range(at, -1, -1):
		if player.data.ball.present[i]:
			return player.data.ball.pos[i]
	return fallback


## `point`, eased away from the nearest wall, floor or ceiling (see
## WALL_MARGIN). The push is smooth in the point's position (it grows as the
## square of how far into the margin it is, then linearly), so a camera moving
## smoothly toward a wall moves smoothly along it, corners included.
static func _clear_of_walls(point: Vector3) -> Vector3:
	for _step in 3:  # pushing off one wall can press into another, in a corner
		var field := _arena_field(point)
		var into: float = field[0] + WALL_MARGIN
		if into <= 0.0:
			break
		var push := into * into / (2.0 * WALL_SOFTNESS) if into < WALL_SOFTNESS else into - WALL_SOFTNESS / 2.0
		point -= (field[1] as Vector3) * minf(push, into)
	return point


## How far `point` is outside the arena (negative inside), and the direction
## out, as a smooth blend of the walls, the 45-degree corners, the floor and
## the ceiling (a soft maximum of their planes). Unlike
## AquariumArena.distance_outside, its direction turns gradually round corners,
## so a camera sliding into one isn't kicked sideways.
static func _arena_field(point: Vector3) -> Array:
	var half := AquariumArena.SIZE / 2.0
	var c := AquariumArena.CORNER_PLANE
	var r := sqrt(0.5)
	var planes := [
		[Vector3.RIGHT, point.x - half.x], [Vector3.LEFT, -point.x - half.x],
		[Vector3.BACK, point.z - half.z], [Vector3.FORWARD, -point.z - half.z],
		[Vector3(r, 0, r), (point.x + point.z - c) * r], [Vector3(r, 0, -r), (point.x - point.z - c) * r],
		[Vector3(-r, 0, r), (-point.x + point.z - c) * r], [Vector3(-r, 0, -r), (-point.x - point.z - c) * r],
		[Vector3.DOWN, -point.y], [Vector3.UP, point.y - AquariumArena.SIZE.y],
	]
	var top := -INF
	for plane: Array in planes:
		top = maxf(top, plane[1])
	var total := 0.0
	var direction := Vector3.ZERO
	for plane: Array in planes:
		var w := exp((plane[1] - top) / FIELD_SOFTNESS)
		total += w
		direction += (plane[0] as Vector3) * w
	var distance := top + FIELD_SOFTNESS * log(total)
	return [distance, direction.normalized() if direction.length_squared() > 1e-12 else Vector3.UP]


## One step of a critically damped spring (exact): `x` is the distance from the
## target and `v` its rate of change, which changes by no more than `max_accel`
## * dt. Returns the new (x, v).
static func _spring(x: float, v: float, omega: float, dt: float, max_accel: float) -> Vector2:
	var decay := exp(-omega * dt)
	var c := v + omega * x
	var new_v := (v - omega * c * dt) * decay
	if absf(new_v - v) > max_accel * dt:
		new_v = v + signf(new_v - v) * max_accel * dt
		return Vector2(x + (v + new_v) * 0.5 * dt, new_v)
	return Vector2((x + c * dt) * decay, new_v)


## One step of a critically damped spring (exact), in 3D: `x` is the offset from
## the target and `v` its velocity. The velocity changes by no more than
## `max_accel` * dt. Returns [new x, new v].
static func _spring_3d(x: Vector3, v: Vector3, omega: float, dt: float, max_accel: float) -> Array:
	var decay := exp(-omega * dt)
	var c := v + omega * x
	var new_v := (v - omega * c * dt) * decay
	var change := new_v - v
	if change.length() > max_accel * dt:
		new_v = v + change.normalized() * max_accel * dt
		return [x + (v + new_v) * 0.5 * dt, new_v]
	return [(x + c * dt) * decay, new_v]
