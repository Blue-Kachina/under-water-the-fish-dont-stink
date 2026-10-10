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
signal stroked(quality: float)

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
## Momentum above max_speed (from dodges, swim strokes or boost) fades at this
## rate while you keep swimming (throttle, boost or a stroke rhythm), like
## holding throttle above top speed in Rocket League. Applies to the extra speed
## only: 0.5 halves it in about 1.4 s. Coasting uses linear_drag as normal.
@export_range(0.0, 3.0, 0.01) var overspeed_drag := 0.5
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

@export_group("Steering")
## Car-style steering: the stick picks a turning circle, so the fish only turns
## while it's moving (and steers backwards in reverse, like a car). Off = turn
## on the spot with the torque/damping values above, like a Rocket League aerial.
@export var car_steering := true
## Steer pitch (nose up/down) the same way. Off = pitch still works at a standstill.
@export var car_steering_pitch := true
## Turning circle at a crawl and at top boost speed. Tighter when slow, like Rocket League cars.
@export_range(0.5, 20.0, 0.1) var min_turn_radius := 2.5
@export_range(1.0, 60.0, 0.5) var max_turn_radius := 15.0
## How quickly the turn rate follows the stick.
@export_range(1.0, 40.0, 0.5) var steer_response := 12.0

@export_group("Swim Strokes")
## Sweep the stick side to side (or up and down) in a steady rhythm to swim
## faster, like a fish's tail or a dolphin's kick.
@export var swim_strokes := true
## Speed added along the nose by a perfectly timed stroke.
@export_range(0.0, 10.0, 0.1) var stroke_impulse := 2.5
## Strokes stop adding speed here. Above max_speed, so good rhythm beats plain throttle.
@export_range(0.0, 80.0, 0.5) var stroke_max_speed := 40.0
## How far the stick must reach on each side for a stroke to count.
@export_range(0.1, 1.0, 0.05) var stroke_threshold := 0.6
## Strokes closer together than this are mashing and give nothing.
@export_range(0.05, 1.0, 0.01) var stroke_min_interval := 0.15
## A longer pause than this ends the rhythm.
@export_range(0.1, 2.0, 0.05) var stroke_max_interval := 0.7
## How much a beat may differ from the previous one (as a fraction) and still
## count as on rhythm. Smaller = stricter timing.
@export_range(0.05, 1.0, 0.05) var rhythm_tolerance := 0.3
## Strength of an off-rhythm stroke (and the first strokes of a rhythm), as a
## fraction of a perfectly timed one.
@export_range(0.0, 1.0, 0.05) var offbeat_strength := 0.3
## While in a rhythm, how much the stroking axis still steers (1 = fully). Low
## keeps the fish swimming straight instead of zigzagging with every stroke.
@export_range(0.0, 1.0, 0.05) var stroke_steering := 0.25

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
## Strokes in the current rhythm, and how well the last one was timed (0..1).
var stroke_chain := 0
var stroke_quality := 0.0

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
var _steer_speed := 0.0
var _flip_time_left := 0.0
var _flip_axis := Vector3.ZERO
var _reset_queued := false
var _spawn_transform: Transform3D
var _swim_phase := 0.0

var _stroke_clock := 0.0
var _stroke_side := Vector2i.ZERO  # last side each stick axis reached: -1, 0 or 1
var _stroke_axis := -1  # axis the current rhythm is on (0 = side to side, 1 = up and down)
var _last_stroke_time := -INF
var _last_stroke_interval := 0.0
var _queued_stroke := 0.0

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


## Move the reset point (e.g. when switching environments) and go there.
func set_spawn(spawn: Transform3D) -> void:
	_spawn_transform = spawn
	request_reset()


func _physics_process(delta: float) -> void:
	input_forward = Input.get_action_strength("thrust_forward")
	input_reverse = Input.get_action_strength("thrust_reverse")
	input_stick = Input.get_vector("stick_left", "stick_right", "stick_up", "stick_down")
	input_roll = Input.get_action_strength("roll_right") - Input.get_action_strength("roll_left")
	air_roll_held = Input.is_action_pressed("air_roll")
	boost_held = Input.is_action_pressed("boost")
	powerslide_held = Input.is_action_pressed("powerslide")
	if Input.is_action_just_pressed("jump"):
		_jump_queued = true
	_detect_strokes(delta)


## A stroke is the stick swinging from one side to the opposite side.
func _detect_strokes(delta: float) -> void:
	_stroke_clock += delta
	if _stroke_clock - _last_stroke_time > stroke_max_interval:
		stroke_chain = 0
	if not swim_strokes or is_dodging:
		return
	for axis in 2:
		var value := input_stick[axis]
		var side := 0
		if value > stroke_threshold:
			side = 1
		elif value < -stroke_threshold:
			side = -1
		if side == 0:
			continue
		if side == -_stroke_side[axis]:
			_register_stroke(axis)
		_stroke_side[axis] = side


func _register_stroke(axis: int) -> void:
	var interval := _stroke_clock - _last_stroke_time
	_last_stroke_time = _stroke_clock
	if interval < stroke_min_interval:
		# Mashing: no push, and the rhythm starts over.
		stroke_chain = 0
		stroke_quality = 0.0
		_last_stroke_interval = 0.0
		return

	# Switching between side-to-side and up-and-down (e.g. spinning the stick)
	# breaks the rhythm, so circles don't count as steady strokes.
	var continues := interval <= stroke_max_interval and axis == _stroke_axis
	var quality := offbeat_strength
	if continues and _last_stroke_interval > 0.0:
		var drift := absf(interval - _last_stroke_interval) / _last_stroke_interval
		quality = lerpf(offbeat_strength, 1.0, clampf(1.0 - drift / rhythm_tolerance, 0.0, 1.0))
	stroke_chain = stroke_chain + 1 if continues else 1
	# The first beat of a rhythm sets the tempo; later beats are judged against it.
	_last_stroke_interval = interval if continues else 0.0
	_stroke_axis = axis
	stroke_quality = quality
	_queued_stroke += quality
	stroked.emit(quality)


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
	velocity = _apply_strokes(velocity, forward)
	velocity = _apply_water(velocity, forward, dt)
	velocity = _apply_jump(velocity, body_basis, state.get_contact_count() > 0, dt)
	velocity = velocity.limit_length(max_boost_speed)

	# Steering uses the full speed (so a sliding fish can still steer), signed
	# negative when swimming backwards so steering flips like a reversing car.
	_steer_speed = -velocity.length() if velocity.dot(forward) < -0.5 else velocity.length()

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
	if is_dodging:
		# The nose spins through every direction mid-flip; thrusting along it
		# would brake the dodge, so the flip coasts on its own momentum.
		is_boosting = false
		return velocity
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


func _apply_strokes(velocity: Vector3, forward: Vector3) -> Vector3:
	var strength := _queued_stroke
	_queued_stroke = 0.0
	var room := stroke_max_speed - velocity.dot(forward)
	if strength <= 0.0 or room <= 0.0:
		return velocity
	return velocity + forward * minf(stroke_impulse * strength, room)


func _apply_water(velocity: Vector3, forward: Vector3, dt: float) -> Vector3:
	var current := velocity.length()
	var swimming := input_forward > 0.0 or is_boosting or stroke_chain >= 2
	if swimming and current > max_speed:
		# Only the speed earned above cruise fades; cruise itself is held.
		velocity *= (max_speed + (current - max_speed) * exp(-overspeed_drag * dt)) / current
	else:
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
	if stroke_chain >= 2:
		# In a swim rhythm the sweeps drive the tail, not the steering.
		if _stroke_axis == 0:
			yaw_in *= stroke_steering
		else:
			pitch_in *= stroke_steering

	# Signed so positive = pitch up, yaw right, roll right.
	var pitch_rate := local_spin.x
	var yaw_rate := -local_spin.y
	var roll_rate := -local_spin.z
	var turn := powerslide_turn_multiplier if is_powersliding else 1.0
	var water := exp(-angular_drag * dt)
	if car_steering and car_steering_pitch:
		pitch_rate = _steer(pitch_rate, pitch_in * turn, dt)
	else:
		pitch_rate += (pitch_torque * turn * pitch_in - pitch_damping * (1.0 - absf(pitch_in)) * pitch_rate) * dt
		pitch_rate *= water
	if car_steering:
		yaw_rate = _steer(yaw_rate, yaw_in * turn, dt)
	else:
		yaw_rate += (yaw_torque * turn * yaw_in - yaw_damping * (1.0 - absf(yaw_in)) * yaw_rate) * dt
		yaw_rate *= water
	roll_rate += (roll_torque * roll_in - roll_damping * roll_rate) * dt
	roll_rate *= water

	var spin := Vector3(pitch_rate, -yaw_rate, -roll_rate)
	return spin.limit_length(max_angular_speed * turn)


## Car-style steering: ease the turn rate toward speed / turning radius.
## Standing still gives a target of zero, so the fish doesn't turn on the spot.
func _steer(rate: float, steer_in: float, dt: float) -> float:
	var speed_fraction := clampf(absf(_steer_speed) / maxf(max_boost_speed, 0.001), 0.0, 1.0)
	var radius := lerpf(min_turn_radius, max_turn_radius, speed_fraction)
	var target := steer_in * _steer_speed / radius
	return lerpf(rate, target, 1.0 - exp(-steer_response * dt))


func _apply_reset(state: PhysicsDirectBodyState3D) -> void:
	_reset_queued = false
	state.transform = _spawn_transform
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	_flip_time_left = 0.0
	_post_jump_time_left = 0.0
	_queued_stroke = 0.0
	stroke_chain = 0
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
	# Swim strokes: the tail sweeps with the stick (side to side, or up and down like a dolphin).
	var stroking := 1.0 if stroke_chain > 0 else 0.0
	_tail.rotation.y = sin(_swim_phase) * lerpf(0.15, 0.45, effort) + tail_kick - input_stick.x * 0.5 * stroking
	_tail.rotation.x = input_stick.y * 0.5 * stroking
	_fin_left.rotation.y = lerpf(_fin_left.rotation.y, 0.9 * slide, 1.0 - exp(-15.0 * delta))
	_fin_right.rotation.y = -_fin_left.rotation.y

	# Reverse swimming: frantic pectoral flutter.
	var flutter := sin(Time.get_ticks_msec() * 0.05) * 0.7 * input_reverse
	_fin_left.rotation.z = flutter
	_fin_right.rotation.z = -flutter
	_bubbles.emitting = is_boosting
