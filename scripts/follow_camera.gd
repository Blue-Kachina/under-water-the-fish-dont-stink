extends Camera3D
## Third-person chase camera. Follows the fish's facing (not its velocity), with
## limited roll and a right-stick look-around that springs back when released.
## Camera input never affects where the fish swims.
##
## Ball cam (toggled with the ball_cam action, like Rocket League) swings the
## camera behind the fish on the line from the ball, so the ball stays in view,
## with a level horizon. It falls back to the normal view while there's no ball.

## Clearance kept between walls and the point the camera aims at.
const ANCHOR_CLEARANCE := 0.1

@export var fish: FishController
## Set by the environment; null when there's no ball.
var ball: Node3D
var ball_cam := false

@export_group("Follow")
## Defaults are Rocket League's default camera: 270 uu back, 100 up, FOV 110,
## tilted 3 degrees down.
@export_range(1.0, 20.0, 0.1) var distance := 2.7
@export_range(-5.0, 10.0, 0.1) var height := 1.0
## Height above the fish's centre that the camera aims at.
@export_range(-3.0, 5.0, 0.01) var look_height := 0.86
## How quickly the camera swings around to match the fish's rotation.
@export_range(0.5, 40.0, 0.5) var rotation_stiffness := 9.0
## How much the camera leans with the fish's roll. 0 = horizon stays level.
## The lean peaks when the fish is on its side and eases back to level as it
## goes fully inverted, so an air roll never flips the view.
@export_range(0.0, 1.0, 0.05) var roll_follow := 0.0
## Roll exactly with the fish instead (ignores roll_follow).
@export var lock_roll_to_fish := false
## How quickly the camera's roll catches up to its target.
@export_range(1.0, 40.0, 0.5) var roll_stiffness := 10.0
## Off (Rocket League style): the camera holds its orientation while a dodge
## flips the fish, and only follows its position.
@export var follow_dodge_spin := false
@export_range(60.0, 120.0, 1.0) var field_of_view := 110.0:
	set(value):
		field_of_view = value
		fov = value

@export_group("Look Around")
@export_range(0.0, 3.2, 0.05) var look_yaw_range := PI
@export_range(0.0, 1.5, 0.05) var look_pitch_range := 0.9
@export_range(1.0, 30.0, 0.5) var look_stiffness := 12.0

@export_group("Collision")
@export_range(0.0, 1.0, 0.05) var collision_margin := 0.5

var _rotation := Quaternion.IDENTITY
## Camera up, carried from frame to frame so its roll can only turn, never jump.
var _up := Vector3.UP
var _look_yaw := 0.0
var _look_pitch := 0.0


func _ready() -> void:
	# Moved every rendered frame from the fish's interpolated transform, so the
	# camera itself must not be physics-interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = field_of_view
	if fish:
		_rotation = fish.global_basis.get_rotation_quaternion()
		_up = fish.global_basis.y


## Whether a setting does anything with the current toggles; the tuning panel hides the rest.
func is_option_active(property: String) -> bool:
	return property != "roll_follow" or not lock_roll_to_fish


func _process(delta: float) -> void:
	if fish == null:
		return

	if Input.is_action_just_pressed("ball_cam"):
		ball_cam = not ball_cam

	var fish_xform := fish.get_global_transform_interpolated()
	var fish_up := fish_xform.basis.y
	var to_ball := Vector3.ZERO
	if ball_cam and is_instance_valid(ball) and ball.visible:
		to_ball = ball.get_global_transform_interpolated().origin - fish_xform.origin
	var tracking_ball := to_ball.length_squared() > 0.01
	# Hold still for the whole flip, cancelled or not: the fish is still spinning.
	# Ball cam keeps tracking the ball through flips, as in Rocket League.
	if tracking_ball or follow_dodge_spin or not fish.is_flipping():
		# Aim where the fish faces, but with the camera's own (levelled) up
		# rather than the fish's full orientation. Turning to face backwards
		# after a half flip is then a level swing around, not a tumble over the
		# top, which would flip the view as it passed straight up.
		var target_forward := to_ball.normalized() if tracking_ball else -fish_xform.basis.z
		var target_frame := Basis.looking_at(target_forward, _target_up(target_forward, fish_up, tracking_ball))
		_rotation = _rotation.slerp(target_frame.get_rotation_quaternion(), 1.0 - exp(-rotation_stiffness * delta))
	var follow := Basis(_rotation)
	var forward := -follow.z

	# Carry last frame's up onto the new view plane, then turn it toward the target.
	var up := _up - forward * _up.dot(forward)
	up = follow.y if up.length_squared() < 0.0001 else up.normalized()
	var target_up := _target_up(forward, fish_up, tracking_ball)
	up = up.rotated(forward, up.signed_angle_to(target_up, forward) * (1.0 - exp(-roll_stiffness * delta)))
	_up = up

	var look_input := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	var look_blend := 1.0 - exp(-look_stiffness * delta)
	_look_yaw = lerpf(_look_yaw, -look_input.x * look_yaw_range, look_blend)
	_look_pitch = lerpf(_look_pitch, -look_input.y * look_pitch_range, look_blend)

	var view := Basis.looking_at(forward, up) \
			* Basis(Vector3.UP, _look_yaw) \
			* Basis(Vector3.RIGHT, _look_pitch)
	var anchor := fish_xform.origin + view.y * look_height
	var eye := fish_xform.origin + view * Vector3(0.0, height, distance)
	var look := anchor - eye

	# Keep clear of walls: sweep a sphere from the fish up to the anchor (which
	# can be inside a wall or ceiling the fish is up against), then from there
	# back to the eye, and stop each short of anything solid. A sphere rather
	# than a ray, so the wide view can't poke through a wall the camera runs
	# alongside. The look direction stays the same while pulled in.
	anchor = _sweep(fish_xform.origin, anchor, ANCHOR_CLEARANCE)
	eye = _sweep(anchor, eye, collision_margin)

	global_transform = Transform3D(Basis.looking_at(look, view.y), eye)


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
	var exclude: Array[RID] = [fish.get_rid()]
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


## The up direction the camera's roll eases toward. `level_only` keeps the horizon level (ball cam).
func _target_up(forward: Vector3, fish_up: Vector3, level_only: bool) -> Vector3:
	if lock_roll_to_fish and not level_only:
		return fish_up
	var level := Vector3.UP - forward * forward.dot(Vector3.UP)
	if level.length_squared() < 0.04:
		return fish_up  # nose (nearly) straight up or down: there's no horizon to level against
	level = level.normalized()
	# Follow the roll up to sideways, then ease back to level toward inverted.
	# Unlike blending the two up vectors, this never has a point where it flips.
	var fish_roll := level.signed_angle_to(fish_up, forward)
	var lean := fish_roll if absf(fish_roll) <= PI / 2.0 else signf(fish_roll) * (PI - absf(fish_roll))
	return level if level_only else level.rotated(forward, lean * roll_follow)
