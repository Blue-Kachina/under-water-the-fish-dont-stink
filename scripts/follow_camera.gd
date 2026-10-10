extends Camera3D
## Third-person chase camera. Follows the fish's facing (not its velocity), with
## limited roll and a right-stick look-around that springs back when released.
## Camera input never affects where the fish swims.

@export var fish: FishController

@export_group("Follow")
@export_range(1.0, 20.0, 0.1) var distance := 2.9
@export_range(-5.0, 10.0, 0.1) var height := 1.1
## Height above the fish's centre that the camera aims at.
@export_range(-3.0, 5.0, 0.1) var look_height := 1.2
## How quickly the camera swings around to match the fish's rotation.
@export_range(0.5, 40.0, 0.5) var rotation_stiffness := 9.0
## How much the camera leans with the fish's roll. 0 = horizon stays level.
## The lean peaks when the fish is on its side and eases back to level as it
## goes fully inverted, so an air roll never flips the view.
@export_range(0.0, 1.0, 0.05) var roll_follow := 0.5
## Roll exactly with the fish instead (ignores roll_follow).
@export var lock_roll_to_fish := false
## How quickly the camera's roll catches up to its target.
@export_range(1.0, 40.0, 0.5) var roll_stiffness := 10.0
## Off (Rocket League style): the camera holds its orientation while a dodge
## flips the fish, and only follows its position.
@export var follow_dodge_spin := false
@export_range(60.0, 120.0, 1.0) var field_of_view := 95.0:
	set(value):
		field_of_view = value
		fov = value

@export_group("Look Around")
@export_range(0.0, 3.2, 0.05) var look_yaw_range := PI
@export_range(0.0, 1.5, 0.05) var look_pitch_range := 0.9
@export_range(1.0, 30.0, 0.5) var look_stiffness := 12.0

@export_group("Collision")
@export_range(0.0, 1.0, 0.05) var collision_margin := 0.3

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


func _process(delta: float) -> void:
	if fish == null:
		return

	var fish_xform := fish.get_global_transform_interpolated()
	if follow_dodge_spin or not fish.is_dodging:
		var target_rotation := fish_xform.basis.get_rotation_quaternion()
		_rotation = _rotation.slerp(target_rotation, 1.0 - exp(-rotation_stiffness * delta))
	var follow := Basis(_rotation)
	var forward := -follow.z

	# Carry last frame's up onto the new view plane, then turn it toward the target.
	var up := _up - forward * _up.dot(forward)
	up = follow.y if up.length_squared() < 0.0001 else up.normalized()
	var target_up := _target_up(forward, follow.y)
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

	# Pull in toward the fish if a wall is in the way.
	var query := PhysicsRayQueryParameters3D.create(anchor, eye)
	query.exclude = [fish.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		eye = hit.position + hit.normal * collision_margin

	global_transform = Transform3D(Basis.looking_at(anchor - eye, view.y), eye)


## The up direction the camera's roll eases toward.
func _target_up(forward: Vector3, fish_up: Vector3) -> Vector3:
	if lock_roll_to_fish:
		return fish_up
	var level := Vector3.UP - forward * forward.dot(Vector3.UP)
	if level.length_squared() < 0.04:
		return fish_up  # nose (nearly) straight up or down: there's no horizon to level against
	level = level.normalized()
	# Follow the roll up to sideways, then ease back to level toward inverted.
	# Unlike blending the two up vectors, this never has a point where it flips.
	var fish_roll := level.signed_angle_to(fish_up, forward)
	var lean := fish_roll if absf(fish_roll) <= PI / 2.0 else signf(fish_roll) * (PI - absf(fish_roll))
	return level.rotated(forward, lean * roll_follow)
