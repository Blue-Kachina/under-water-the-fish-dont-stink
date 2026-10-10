class_name FishController
extends RigidBody3D
## Arcade swimming controller with Rocket League-style aerial handling.
##
## Motion is applied by editing the body's velocities in _integrate_forces, so
## every value here is an acceleration (m/s²), speed (m/s) or rate (rad/s),
## independent of mass. Each @export_range / bool property appears
## automatically in the in-game tuning panel.
##
## Rotation defaults come from community measurements of Rocket League's aerial
## physics (RLBot wiki): torque per axis, input-scaled damping on pitch and yaw,
## constant damping on roll, and a 5.5 rad/s spin cap.

signal jumped
signal double_jumped
signal dodged(direction: Vector3)

## READY: on the first jump. SECOND_JUMP: a second press within double_jump_window
## gives a double jump (stick neutral) or a dodge (stick pushed). COOLDOWN: both used.
enum JumpState { READY, SECOND_JUMP, COOLDOWN }

@export_group("Thrust")
@export_range(0.0, 60.0, 0.5) var forward_accel := 14.0
@export_range(0.0, 60.0, 0.5) var reverse_accel := 8.0
## Deceleration when holding reverse while still swimming forward.
@export_range(0.0, 120.0, 1.0) var brake_accel := 31.0
## Keep below max_boost_speed so boosting raises top speed. Throttle alone can
## never pass forward_accel / linear_drag (drag balances thrust there).
@export_range(0.0, 60.0, 0.5) var max_speed := 32.0
@export_range(0.0, 30.0, 0.5) var max_reverse_speed := 6.0

@export_group("Boost")
@export_range(0.0, 60.0, 0.5) var boost_accel := 18.5
## Absolute speed cap, also applied to jumps and dodges.
@export_range(0.0, 80.0, 0.5) var max_boost_speed := 45.0
@export var boost_unlimited := true
## Percent of the tank used per second (Rocket League: 33.3).
@export_range(0.0, 100.0, 0.5) var boost_drain := 33.0
@export_range(0.0, 100.0, 0.5) var boost_regen := 10.0

@export_group("Water")
## Fraction of speed lost per second.
@export_range(0.0, 3.0, 0.01) var linear_drag := 0.4
## Extra drag on sideways/vertical slip. 0 = free drift, high = carves like it's on rails.
@export_range(0.0, 10.0, 0.05) var lateral_drag := 3.9
@export_range(0.0, 5.0, 0.05) var angular_drag := 2.45
## Upward acceleration. 0 = neutral buoyancy, negative sinks.
@export_range(-10.0, 10.0, 0.1) var buoyancy := 0.0
@export_range(0.0, 1.0, 0.05) var wall_bounce := 0.2:
	set(value):
		wall_bounce = value
		_apply_physics_material()
@export_range(0.0, 1.0, 0.05) var wall_friction := 0.2:
	set(value):
		wall_friction = value
		_apply_physics_material()

@export_group("Rotation")
@export_range(0.0, 60.0, 0.1) var pitch_torque := 12.15
@export_range(0.0, 60.0, 0.1) var yaw_torque := 8.8
@export_range(0.0, 80.0, 0.1) var roll_torque := 36.2
@export_range(0.0, 20.0, 0.05) var pitch_damping := 2.8
@export_range(0.0, 20.0, 0.05) var yaw_damping := 1.85
@export_range(0.0, 20.0, 0.05) var roll_damping := 4.47
@export_range(0.0, 15.0, 0.1) var max_angular_speed := 5.5
@export var invert_pitch := false

@export_group("Jump & Dodge")
## Impulse along the fish's up axis, for both the first jump and a double jump.
@export_range(0.0, 40.0, 0.1) var jump_impulse := 20.0
@export_range(0.0, 60.0, 0.1) var dodge_impulse := 30.0
## Time after the first jump during which a second press double-jumps or dodges.
@export_range(0.0, 3.0, 0.05) var double_jump_window := 1.25
## Wait after the second jump (or an unused window) before jumping again.
@export_range(0.0, 5.0, 0.05) var jump_cooldown := 1.0
## Stick deflection needed for a dodge; below it the second press is a double jump.
@export_range(0.0, 1.0, 0.05) var dodge_deadzone := 0.5
## Full rotations performed during a dodge (0 = no flip).
@export_range(0.0, 2.0, 0.05) var dodge_flip_turns := 1.0
@export_range(0.1, 2.0, 0.05) var dodge_flip_duration := 0.5
## Touching a surface refreshes the jumps, like landing in Rocket League.
@export var contact_refreshes_jump := true
## Lateral drag right after a jump or dodge, so the impulse carries instead of
## being eaten by carving drag. Eases back to lateral_drag over the time below.
@export_range(0.0, 10.0, 0.05) var post_jump_lateral_drag := 0.3
@export_range(0.0, 3.0, 0.05) var post_jump_drag_time := 1.0

@export_group("Powerslide")
## Lateral drag while powersliding: low = the fish keeps sliding the old way while it turns.
@export_range(0.0, 10.0, 0.05) var powerslide_lateral_drag := 0.15
## Multiplies pitch/yaw torque and the spin cap while powersliding.
@export_range(1.0, 4.0, 0.05) var powerslide_turn_multiplier := 1.6
## Forward thrust kept while powersliding (1 = full thrust).
@export_range(0.0, 1.0, 0.05) var powerslide_thrust_scale := 0.6

# Telemetry, read by the HUD.
var speed := 0.0
var forward_speed := 0.0
var drift_angle := 0.0
var angular_speed := 0.0
var boost_amount := 100.0
var is_boosting := false
var jump_state := JumpState.READY
## True while the dodge flip animation is spinning the fish.
var is_dodging := false
var is_powersliding := false

# Latest input, sampled every physics tick.
var input_forward := 0.0
var input_reverse := 0.0
var input_stick := Vector2.ZERO
var input_roll := 0.0
var air_roll_held := false
var boost_held := false
var powerslide_held := false

var _jump_queued := false
var _jump_timer := 0.0
var _post_jump_time_left := 0.0
var _flip_time_left := 0.0
var _flip_axis := Vector3.ZERO
var _reset_queued := false
var _spawn_transform: Transform3D
var _swim_phase := 0.0

@onready var _tail: Node3D = $Visual/TailPivot
@onready var _fin_left: Node3D = $Visual/FinLeftPivot
@onready var _fin_right: Node3D = $Visual/FinRightPivot
@onready var _bubbles: CPUParticles3D = $Bubbles


func _ready() -> void:
	_spawn_transform = global_transform
	physics_material_override = PhysicsMaterial.new()
	_apply_physics_material()


func request_reset() -> void:
	_reset_queued = true


func _physics_process(_delta: float) -> void:
	input_forward = Input.get_action_strength("thrust_forward")
	input_reverse = Input.get_action_strength("thrust_reverse")
	input_stick = Input.get_vector("stick_left", "stick_right", "stick_up", "stick_down")
	input_roll = Input.get_action_strength("roll_right") - Input.get_action_strength("roll_left")
	air_roll_held = Input.is_action_pressed("air_roll")
	boost_held = Input.is_action_pressed("boost")
	powerslide_held = Input.is_action_pressed("powerslide")
	if Input.is_action_just_pressed("jump"):
		_jump_queued = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_queued:
		_apply_reset(state)
		return

	var dt := state.step
	var body_basis := state.transform.basis.orthonormalized()
	var forward := -body_basis.z
	var velocity := state.linear_velocity
	is_powersliding = powerslide_held and not is_dodging

	velocity = _apply_thrust(velocity, forward, dt)
	velocity = _apply_water(velocity, forward, dt)
	velocity = _apply_jump(velocity, body_basis, state.get_contact_count() > 0, dt)
	velocity = velocity.limit_length(max_boost_speed)

	# Work on angular velocity in the fish's own frame: x = pitch, y = yaw, z = roll.
	var local_spin := body_basis.transposed() * state.angular_velocity
	local_spin = _apply_rotation(local_spin, dt)

	state.linear_velocity = velocity
	state.angular_velocity = body_basis * local_spin

	speed = velocity.length()
	forward_speed = velocity.dot(forward)
	drift_angle = rad_to_deg(forward.angle_to(velocity)) if speed > 0.5 else 0.0
	angular_speed = local_spin.length()


func _apply_thrust(velocity: Vector3, forward: Vector3, dt: float) -> Vector3:
	var along := velocity.dot(forward)
	var accel := 0.0
	if input_forward > 0.0 and along < max_speed:
		var thrust_scale := powerslide_thrust_scale if is_powersliding else 1.0
		accel += forward_accel * input_forward * thrust_scale
	if input_reverse > 0.0:
		if along > 0.5:
			accel -= brake_accel * input_reverse
		elif -along < max_reverse_speed:
			accel -= reverse_accel * input_reverse

	is_boosting = boost_held and (boost_unlimited or boost_amount > 0.0)
	if is_boosting:
		if along < max_boost_speed:
			accel += boost_accel
		if not boost_unlimited:
			boost_amount = maxf(boost_amount - boost_drain * dt, 0.0)
	elif not boost_unlimited:
		boost_amount = minf(boost_amount + boost_regen * dt, 100.0)

	return velocity + forward * accel * dt


func _apply_water(velocity: Vector3, forward: Vector3, dt: float) -> Vector3:
	velocity *= exp(-linear_drag * dt)
	var slip := velocity - forward * velocity.dot(forward)
	velocity -= slip * (1.0 - exp(-_effective_lateral_drag(dt) * dt))
	velocity.y += buoyancy * dt
	return velocity


## Lateral drag, lowered while powersliding and just after a jump or dodge.
func _effective_lateral_drag(dt: float) -> float:
	var drag := lateral_drag
	if is_powersliding:
		drag = minf(drag, powerslide_lateral_drag)
	if _post_jump_time_left > 0.0:
		_post_jump_time_left -= dt
		# Hold post_jump_lateral_drag, then ease back up to normal near the end.
		var t := clampf(_post_jump_time_left / maxf(post_jump_drag_time, 0.001), 0.0, 1.0)
		drag = minf(drag, lerpf(lateral_drag, post_jump_lateral_drag, 1.0 - (1.0 - t) * (1.0 - t)))
	return drag


func _apply_jump(velocity: Vector3, body_basis: Basis, touching: bool, dt: float) -> Vector3:
	var pressed := _jump_queued
	_jump_queued = false
	_jump_timer -= dt

	match jump_state:
		JumpState.READY:
			if pressed:
				velocity += body_basis.y * jump_impulse
				jump_state = JumpState.SECOND_JUMP
				_jump_timer = double_jump_window
				_post_jump_time_left = post_jump_drag_time
				jumped.emit()
		JumpState.SECOND_JUMP:
			if pressed:
				velocity = _second_jump(velocity, body_basis)
				_post_jump_time_left = post_jump_drag_time
				_start_cooldown()
			elif _jump_timer <= 0.0:
				_start_cooldown()
		JumpState.COOLDOWN:
			if _jump_timer <= 0.0 or (touching and contact_refreshes_jump):
				jump_state = JumpState.READY
	return velocity


## Dodge in the stick's direction when it's pushed, otherwise a straight double jump.
func _second_jump(velocity: Vector3, body_basis: Basis) -> Vector3:
	if input_stick.length() < dodge_deadzone:
		double_jumped.emit()
		return velocity + body_basis.y * jump_impulse

	# Stick up = dodge forward (local -Z), stick right = dodge right (local +X).
	var local_dir := Vector3(input_stick.x, 0.0, input_stick.y).normalized()
	var world_dir := body_basis * local_dir
	if dodge_flip_turns > 0.0:
		# Spin so the nose dips toward the dodge direction (front flip, side flip...).
		_flip_axis = Vector3.UP.cross(local_dir).normalized()
		_flip_time_left = dodge_flip_duration
		is_dodging = true
	dodged.emit(world_dir)
	return velocity + world_dir * dodge_impulse


func _start_cooldown() -> void:
	jump_state = JumpState.COOLDOWN
	_jump_timer = jump_cooldown


func _apply_rotation(local_spin: Vector3, dt: float) -> Vector3:
	if _flip_time_left > 0.0:
		_flip_time_left -= dt
		if _flip_time_left <= 0.0:
			is_dodging = false
			return Vector3.ZERO  # finish the flip cleanly instead of over-rotating
		return _flip_axis * (dodge_flip_turns * TAU / dodge_flip_duration)

	# Rocket League convention: stick forward pitches the nose down.
	var pitch_in := -input_stick.y if invert_pitch else input_stick.y
	var yaw_in := input_stick.x
	var roll_in := input_roll
	if air_roll_held:
		roll_in += yaw_in
		yaw_in = 0.0
	roll_in = clampf(roll_in, -1.0, 1.0)

	# Signed so positive = pitch up, yaw right, roll right.
	var pitch_rate := local_spin.x
	var yaw_rate := -local_spin.y
	var roll_rate := -local_spin.z
	var turn := powerslide_turn_multiplier if is_powersliding else 1.0
	pitch_rate += (pitch_torque * turn * pitch_in - pitch_damping * (1.0 - absf(pitch_in)) * pitch_rate) * dt
	yaw_rate += (yaw_torque * turn * yaw_in - yaw_damping * (1.0 - absf(yaw_in)) * yaw_rate) * dt
	roll_rate += (roll_torque * roll_in - roll_damping * roll_rate) * dt

	var spin := Vector3(pitch_rate, -yaw_rate, -roll_rate) * exp(-angular_drag * dt)
	return spin.limit_length(max_angular_speed * turn)


func _apply_reset(state: PhysicsDirectBodyState3D) -> void:
	_reset_queued = false
	state.transform = _spawn_transform
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	_flip_time_left = 0.0
	_post_jump_time_left = 0.0
	is_dodging = false
	jump_state = JumpState.READY
	boost_amount = 100.0
	reset_physics_interpolation.call_deferred()


func _apply_physics_material() -> void:
	if physics_material_override == null:
		return
	physics_material_override.bounce = wall_bounce
	physics_material_override.friction = wall_friction


## Placeholder animation: driven by movement state, never the other way round.
func _process(delta: float) -> void:
	var effort := maxf(input_forward, 1.0 if is_boosting else 0.0)
	_swim_phase += delta * lerpf(4.0, 18.0, effort)
	# Powerslide: tail kicks out toward the turn, fins flare like air brakes.
	var slide := 1.0 if is_powersliding else 0.0
	var tail_kick := -input_stick.x * 0.6 * slide
	_tail.rotation.y = sin(_swim_phase) * lerpf(0.15, 0.45, effort) + tail_kick
	_fin_left.rotation.y = lerpf(_fin_left.rotation.y, 0.9 * slide, 1.0 - exp(-15.0 * delta))
	_fin_right.rotation.y = -_fin_left.rotation.y

	# Reverse swimming: frantic pectoral flutter.
	var flutter := sin(Time.get_ticks_msec() * 0.05) * 0.7 * input_reverse
	_fin_left.rotation.z = flutter
	_fin_right.rotation.z = -flutter
	_bubbles.emitting = is_boosting
