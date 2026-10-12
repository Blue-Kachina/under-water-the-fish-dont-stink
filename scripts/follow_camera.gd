extends Camera3D
## Third-person chase camera. Follows the fish's facing (not its velocity), with
## limited roll and a right-stick look-around that springs back when released.
## Camera input never affects where the fish swims. In the air it holds its
## direction and only follows the fish's position, as in Rocket League.
##
## Ball cam (toggled with the ball_cam action, like Rocket League) swings the
## camera behind the fish on the line from the ball, so the ball stays in view,
## with a level horizon. It falls back to the normal view while there's no ball.
## On the obstacle course the same toggle is ring cam: it aims at the next hoop.

## Clearance kept between walls and the point the camera aims at.
const ANCHOR_CLEARANCE := 0.1
## How far behind the camera falls per m/s at stiffness 0 (s). RL doesn't
## publish its formula; this gives about a metre at top speed at stiffness 0.45.
const MAX_LAG_TIME := 0.08
const LAG_RATE := 6.0
## Right-stick look-around rate per unit of swivel speed (1/s).
const SWIVEL_RATE := 2.0
## Seconds a ball cam toggle takes at transition speed 1 (approximate).
const TRANSITION_TIME := 0.5
## The camera's turning (and roll) never speeds up or slows down faster than
## this (rad/s^2), so a big swing, like turning round after a half flip, starts
## and ends gently instead of with a lurch.
const MAX_TURN_ACCEL := 40.0

@export var fish: FishController
## Followed instead of the fish while set, e.g. a replay's ghost (ReplayCar),
## which offers the fish's fields the camera reads: on_surface,
## linear_velocity and is_flipping().
var target: Node3D
## Set by the environment; null when there's no ball.
var ball: Node3D
## Set by the environment; null away from the obstacle course. Ring cam aims
## at its next hoop.
var course: Arena
## Ball cam, or ring cam on the course.
var ball_cam := false

@export_group("Follow")
## Rocket League's camera settings, with the same meanings (RL's uu are cm).
## Defaults: pro player BeastMode's camera (presets/beast_mode.cfg has the same).
@export_range(1.0, 20.0, 0.01) var distance := 2.7
@export_range(-5.0, 10.0, 0.01) var height := 0.9
## Camera tilt in degrees; negative looks down. RL: Angle.
@export_range(-15.0, 15.0, 0.1) var angle := -4.0
## How firmly the camera keeps its distance as the fish speeds up: 1 = fixed,
## lower falls further behind at speed. RL: Stiffness (approximate).
@export_range(0.0, 1.0, 0.01) var stiffness := 0.45
## How quickly the camera swings around to match the fish's rotation.
@export_range(0.5, 40.0, 0.5) var rotation_stiffness := 9.0
## On (Rocket League style): while the fish drives on a wall or the ceiling,
## the camera rolls with it so the surface shows as the floor, and eases back
## to the level horizon once it leaves.
@export var roll_with_surface := true
## How much the camera leans with the fish's roll in the air. 0 = horizon
## stays level. The lean peaks when the fish is on its side and eases back to
## level as it goes fully inverted, so an air roll never flips the view.
@export_range(0.0, 1.0, 0.05) var roll_follow := 0.0
## Roll exactly with the fish instead (ignores roll_follow).
@export var lock_roll_to_fish := false
## How quickly the camera's roll catches up to its target.
@export_range(1.0, 40.0, 0.5) var roll_stiffness := 10.0
## How quickly the camera rolls back to level after leaving a surface.
@export_range(0.5, 40.0, 0.5) var level_return_rate := 3.0
## Off (Rocket League style): the camera holds its orientation while a dodge
## flips the fish, and only follows its position.
@export var follow_dodge_spin := false
## Off (Rocket League style): in the air the camera holds the direction it had
## at takeoff and only follows the fish's position; it turns to match the fish
## again once it lands. (Ball cam keeps tracking the ball either way.)
@export var follow_air_rotation := false
## Horizontal, as in Rocket League (16:9). RL: FOV.
@export_range(60.0, 130.0, 1.0) var field_of_view := 109.0:
	set(value):
		field_of_view = value
		fov = value
## How quickly a ball cam toggle swings the view. RL: Transition Speed (approximate).
@export_range(0.5, 3.0, 0.05) var transition_speed := 1.2

@export_group("Look Around")
@export_range(0.0, 3.2, 0.05) var look_yaw_range := PI
@export_range(0.0, 1.5, 0.05) var look_pitch_range := 0.9
## How quickly the right stick turns the view. RL: Swivel Speed (approximate).
@export_range(1.0, 10.0, 0.1) var swivel_speed := 7.0

@export_group("Collision")
@export_range(0.0, 1.0, 0.05) var collision_margin := 0.5

## The camera's own orientation, and how fast it's turning (world-space angular
## velocity). It turns on a critically damped spring toward where it wants to
## look, so its turning never jumps from one frame to the next: not when a
## dodge ends, a ball cam toggle finishes or the fish lands.
var _rotation := Quaternion.IDENTITY
var _spin := Vector3.ZERO
## Camera up, carried from frame to frame so its roll can only turn, never jump.
var _up := Vector3.UP
var _look_yaw := 0.0
var _look_pitch := 0.0
## How far the camera has fallen behind (see stiffness).
var _lag := Vector3.ZERO
var _lag_speed := Vector3.ZERO
var _roll_speed := 0.0
var _transition_left := 0.0
## Still rolling back to level after leaving a surface (see roll_with_surface).
var _leaving_surface := false


func _ready() -> void:
	# Moved every rendered frame from the fish's interpolated transform, so the
	# camera itself must not be physics-interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	keep_aspect = Camera3D.KEEP_WIDTH  # fov is horizontal, like RL's
	fov = field_of_view
	if fish:
		_rotation = fish.global_basis.get_rotation_quaternion()
		_up = fish.global_basis.y


## Whether a setting does anything with the current toggles; the tuning panel hides the rest.
func is_option_active(property: String) -> bool:
	return property != "roll_follow" or not lock_roll_to_fish


## Jump straight to the view behind the target, with no easing (after a cut).
func snap() -> void:
	var subject: Variant = _subject()
	if subject == null:
		return
	var xform: Transform3D = subject.global_transform
	_up = xform.basis.y if subject.on_surface else Vector3.UP
	var forward := -xform.basis.z
	if absf(forward.dot(_up)) > 0.99:
		_up = xform.basis.y
	_rotation = Basis.looking_at(forward, _up).get_rotation_quaternion()
	_spin = Vector3.ZERO
	_lag = Vector3.ZERO
	_lag_speed = Vector3.ZERO
	_roll_speed = 0.0
	_leaving_surface = false


## What the camera follows: the target if set, otherwise the fish. Untyped:
## the target only has to look like the fish.
func _subject() -> Variant:
	return target if is_instance_valid(target) else fish


func _process(delta: float) -> void:
	var subject: Variant = _subject()
	if subject == null:
		return

	if Input.is_action_just_pressed("ball_cam"):
		ball_cam = not ball_cam
		_transition_left = TRANSITION_TIME / transition_speed
	_transition_left = maxf(_transition_left - delta, 0.0)

	var fish_xform: Transform3D = subject.get_global_transform_interpolated()
	var fish_up := fish_xform.basis.y
	var to_ball := Vector3.ZERO
	var focus := _focus() if ball_cam else null
	if focus:
		to_ball = focus.get_global_transform_interpolated().origin - fish_xform.origin
	var tracking_ball := to_ball.length_squared() > 0.01
	# On a wall or the ceiling the fish's up is the camera's up (RL style),
	# and always well defined there, even driving straight up a wall.
	var surface_roll: bool = roll_with_surface and not lock_roll_to_fish and subject.on_surface
	# Hold still for the whole flip, cancelled or not: the fish is still spinning.
	# Ball cam keeps tracking the ball through flips, as in Rocket League.
	# (Holding, the camera's own turning eases to a stop.)
	var target_rotation := _rotation
	var rate := rotation_stiffness
	if tracking_ball or (_follows_rotation(subject) and (follow_dodge_spin or not subject.is_flipping())):
		# Aim where the fish faces, but with the camera's own (levelled) up
		# rather than the fish's full orientation. Turning to face backwards
		# after a half flip is then a level swing around, not a tumble over the
		# top, which would flip the view as it passed straight up.
		var target_forward := to_ball.normalized() if tracking_ball else -fish_xform.basis.z
		var frame_up := fish_up if surface_roll and absf(target_forward.dot(fish_up)) < 0.95 else _target_up(target_forward, fish_up, tracking_ball, _up)
		target_rotation = Basis.looking_at(target_forward, frame_up).get_rotation_quaternion()
		# A ball cam toggle swings over at the transition speed instead.
		if _transition_left > 0.0:
			rate = 3.0 / (TRANSITION_TIME / transition_speed)
	_turn_toward(target_rotation, rate, delta)
	var follow := Basis(_rotation)
	var forward := -follow.z

	# Carry last frame's up onto the new view plane, then turn it toward the target.
	var up := _up - forward * _up.dot(forward)
	up = follow.y if up.length_squared() < 0.0001 else up.normalized()
	var target_up := _target_up(forward, fish_up, tracking_ball, up)
	var roll_rate := roll_stiffness
	if roll_with_surface and not lock_roll_to_fish:
		if surface_roll and absf(forward.dot(fish_up)) < 0.95:
			target_up = fish_up
			_leaving_surface = true
		elif _leaving_surface:
			# Off a wall: ease back to level, slower than an air lean.
			roll_rate = minf(roll_stiffness, level_return_rate)
			_leaving_surface = absf(_roll_to(up, target_up, forward)) > 0.03
	# Roll on a spring too (see _rotation), in the angle between up and its target.
	var roll_error := -_roll_to(up, target_up, forward)
	var rolled := _spring_step(roll_error, _roll_speed, 2.0 * roll_rate, delta, MAX_TURN_ACCEL)
	_roll_speed = rolled.y
	up = up.rotated(forward, rolled.x - roll_error)
	_up = up

	var look_input := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	var look_blend := 1.0 - exp(-swivel_speed * SWIVEL_RATE * delta)
	_look_yaw = lerpf(_look_yaw, -look_input.x * look_yaw_range, look_blend)
	_look_pitch = lerpf(_look_pitch, -look_input.y * look_pitch_range, look_blend)

	var view := Basis.looking_at(forward, up) \
			* Basis(Vector3.UP, _look_yaw) \
			* Basis(Vector3.RIGHT, _look_pitch)
	# Falls behind at speed, by how loose the stiffness is.
	var lag_target: Vector3 = -subject.linear_velocity * MAX_LAG_TIME * (1.0 - stiffness)
	var lag_error := _lag - lag_target
	for axis in 3:
		var lagged := _spring_step(lag_error[axis], _lag_speed[axis], 2.0 * LAG_RATE, delta)
		_lag[axis] = lag_target[axis] + lagged.x
		_lag_speed[axis] = lagged.y
	var anchor := fish_xform.origin + view.y * height
	var eye := fish_xform.origin + view * Vector3(0.0, height, distance) + _lag
	var look_basis := view * Basis(Vector3.RIGHT, deg_to_rad(angle))

	# Keep clear of walls: sweep a sphere from the fish up to the anchor (which
	# can be inside a wall or ceiling the fish is up against), then from there
	# back to the eye, and stop each short of anything solid. A sphere rather
	# than a ray, so the wide view can't poke through a wall the camera runs
	# alongside. The look direction stays the same while pulled in.
	anchor = _sweep(fish_xform.origin, anchor, ANCHOR_CLEARANCE)
	eye = _sweep(anchor, eye, collision_margin)

	global_transform = Transform3D(look_basis.orthonormalized(), eye)


## What ball cam aims at: the ball, or on the course its next hoop (ring cam).
## Null while there's nothing to aim at.
func _focus() -> Node3D:
	if is_instance_valid(ball) and ball.visible:
		return ball
	if is_instance_valid(course) and course.next_hoop < course.hoops.size():
		return course.hoops[course.next_hoop]
	return null


## Whether the camera turns with the fish this frame (see follow_air_rotation).
## Without RL surface mechanics the fish is never on a surface, so it always does.
## (A replay's ghost has no such setting: it's always RL physics.)
func _follows_rotation(subject: Variant) -> bool:
	if follow_air_rotation or subject.on_surface:
		return true
	var mechanics: Variant = subject.get("rl_surface_mechanics")
	return mechanics == false


## Turns the camera toward `target` on a critically damped spring. `rate` is the
## old first-order follow rate (1/s): the spring runs at twice it, which lags a
## steady turn by the same amount (2 / omega = 1 / rate) but never jumps.
func _turn_toward(target: Quaternion, rate: float, delta: float) -> void:
	var error := _rotation_vector(_rotation * target.inverse())  # where it is, relative to the target
	var turned := Vector3.ZERO
	var spin := Vector3.ZERO
	var speed := error.length() + _spin.length()
	if speed < 1e-9:
		_spin = Vector3.ZERO
		return
	# The spring acts along the error, with the spin split along and across it.
	var along := error.normalized() if error.length_squared() > 1e-12 else _spin.normalized()
	var spin_along := _spin.dot(along)
	var stepped := _spring_step(error.length() if error.length_squared() > 1e-12 else 0.0, spin_along, 2.0 * rate, delta, MAX_TURN_ACCEL)
	var across := _spin - along * spin_along
	var across_step := _spring_step(0.0, across.length(), 2.0 * rate, delta, MAX_TURN_ACCEL)
	turned = along * stepped.x + (across.normalized() * across_step.x if across.length_squared() > 1e-12 else Vector3.ZERO)
	spin = along * stepped.y + (across.normalized() * across_step.y if across.length_squared() > 1e-12 else Vector3.ZERO)
	_spin = spin
	_rotation = (_quaternion_from(turned) * target).normalized()


## One frame of a critically damped spring (exact): `x` is the distance from the
## target, `v` its rate of change, `omega` the spring's frequency. Returns the
## new (x, v). With `max_accel`, the rate changes no faster than that.
static func _spring_step(x: float, v: float, omega: float, dt: float, max_accel := INF) -> Vector2:
	var decay := exp(-omega * dt)
	var c := v + omega * x
	var new_v := (v - omega * c * dt) * decay
	if absf(new_v - v) > max_accel * dt:
		new_v = v + signf(new_v - v) * max_accel * dt
		return Vector2(x + (v + new_v) * 0.5 * dt, new_v)
	return Vector2((x + c * dt) * decay, new_v)


## A rotation as a vector: its axis, times its angle (the shorter way round).
static func _rotation_vector(q: Quaternion) -> Vector3:
	if q.w < 0.0:
		q = -q
	var s := Vector3(q.x, q.y, q.z)
	var half := atan2(s.length(), q.w)
	if s.length_squared() < 1e-14:
		return s * 2.0
	return s.normalized() * half * 2.0


static func _quaternion_from(rotation_vector: Vector3) -> Quaternion:
	var angle := rotation_vector.length()
	if angle < 1e-9:
		return Quaternion.IDENTITY
	return Quaternion(rotation_vector / angle, angle)


## How far a sphere of `radius` gets from `from` toward `to` before touching
## anything solid (the fish and ball don't count). A ray along the same line
## backs it up: a sphere that starts out already touching a surface can be
## reported as free to move straight through it.
func _sweep(from: Vector3, to: Vector3, radius: float) -> Vector3:
	var motion := to - from
	var length := motion.length()
	if length < 0.0001:
		return from
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for body: Variant in [fish, target]:
		if is_instance_valid(body) and body is CollisionObject3D:
			exclude.append((body as CollisionObject3D).get_rid())
	if is_instance_valid(ball) and ball is CollisionObject3D:
		exclude.append((ball as CollisionObject3D).get_rid())

	var allowed := 1.0
	var ray := PhysicsRayQueryParameters3D.create(from, to)
	ray.exclude = exclude
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		allowed = maxf((hit.position - from).length() - radius, 0.0) / length

	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = motion
	query.exclude = exclude
	var result := space.cast_motion(query)
	if result[0] > 0.0 or result[1] > 0.0:  # [0, 0]: started overlapping; the ray decides
		allowed = minf(allowed, result[0])
	return from + motion * allowed


## The up direction the camera's roll eases toward. `level_only` keeps the
## horizon level (ball cam). Looking (nearly) straight up or down there's no
## horizon to level against, so it fades to holding `current_up`, the
## camera's own roll: the horizon's direction there swings wildly with the
## slightest wobble of the aim.
func _target_up(forward: Vector3, fish_up: Vector3, level_only: bool, current_up: Vector3) -> Vector3:
	if lock_roll_to_fish and not level_only:
		return fish_up
	var hold := current_up - forward * current_up.dot(forward)
	if hold.length_squared() < 0.0001:
		hold = fish_up - forward * fish_up.dot(forward)
	hold = hold.normalized()
	var level := Vector3.UP - forward * forward.dot(Vector3.UP)
	var horizon := clampf((level.length() - 0.1) / 0.25, 0.0, 1.0)  # 0 within ~6 deg of vertical, 1 beyond ~21
	if horizon == 0.0:
		return hold
	level = level.normalized()
	# Follow the roll up to sideways, then ease back to level toward inverted.
	# Unlike blending the two up vectors, this never has a point where it flips.
	var fish_roll := _roll_to(level, fish_up, forward)
	var lean := fish_roll if absf(fish_roll) <= PI / 2.0 else signf(fish_roll) * (PI - absf(fish_roll))
	var target := level if level_only else level.rotated(forward, lean * roll_follow)
	return hold.rotated(forward, _roll_to(hold, target, forward) * horizon)


## The roll about `axis` that turns `from` to `to`, both seen in the plane
## across `axis`. (Vector3.signed_angle_to measures the full 3D angle, which
## never reaches zero for a `to` leaning along the axis, so easing toward it
## overshoots back and forth every frame.)
func _roll_to(from: Vector3, to: Vector3, axis: Vector3) -> float:
	var a := from - axis * from.dot(axis)
	var b := to - axis * to.dot(axis)
	if a.length_squared() < 1e-8 or b.length_squared() < 1e-8:
		return 0.0
	return a.signed_angle_to(b, axis)
