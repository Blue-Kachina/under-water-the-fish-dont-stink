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

# Rocket League air roll, from RocketSim (RLConst.h): angular acceleration =
# (CAR_AIR_CONTROL_TORQUE.roll * input - CAR_AIR_CONTROL_DAMPING.roll * roll rate)
# * CAR_TORQUE_SCALE, with total spin clamped to CAR_MAX_ANG_SPEED, at 120 Hz.
const RL_TORQUE_SCALE := TAU / 65536.0 * 1000.0
const RL_ROLL_TORQUE := 400.0 * RL_TORQUE_SCALE
const RL_ROLL_DAMPING := 50.0 * RL_TORQUE_SCALE
const RL_MAX_ANGULAR_SPEED := 5.5
# Rocket League air control for the other axes (used around dodges).
const RL_PITCH_TORQUE := 130.0 * RL_TORQUE_SCALE
const RL_PITCH_DAMPING := 30.0 * RL_TORQUE_SCALE
const RL_YAW_TORQUE := 95.0 * RL_TORQUE_SCALE
const RL_YAW_DAMPING := 20.0 * RL_TORQUE_SCALE
# Rocket League dodge flip, from RocketSim (RLConst.h, Car.cpp). The flip torque
# is an angular acceleration (rad/s²) applied for FLIP_TORQUE_TIME with no air
# control or damping; then pitch input stays locked for FLIP_PITCHLOCK_EXTRA_TIME
# while normal air damping slows the remaining spin.
const RL_FLIP_TORQUE_SIDE := 260.0  # FLIP_TORQUE_X, about the roll axis
const RL_FLIP_TORQUE_FORWARD := 224.0  # FLIP_TORQUE_Y, about the pitch axis
const RL_FLIP_TORQUE_TIME := 0.65
const RL_FLIP_PITCHLOCK_EXTRA_TIME := 0.3
# Flip Z-damp (RocketSim _UpdateDoubleJumpOrFlip): during the flip torque phase,
# from FLIP_Z_DAMP_START, vertical velocity is multiplied by (1 - FLIP_Z_DAMP_120)
# each 120 Hz tick: always until FLIP_Z_DAMP_END, then only while moving down.
const RL_FLIP_Z_DAMP_120 := 0.35
const RL_FLIP_Z_DAMP_START := 0.15
const RL_FLIP_Z_DAMP_END := 0.21
## How quickly a direction lock pulls the nose back onto the locked direction.
const LOCK_ALIGN_RATE := 12.0
# Rocket League jump (RocketSim RLConst.h, Car::_UpdateJump): an instant push,
# then extra push while jump is held, for at least JUMP_MIN_TIME even on a tap.
const RL_JUMP_MIN_HOLD := 0.025
# Rocket League driving (RocketSim RLConst.h), speeds doubled. Throttle torque
# fades from full at a standstill to 10% just under max driving speed (1400 of
# 1410 uu/s), then to nothing. Steering angle shrinks with speed; the turn rate
# is speed * tan(angle) / wheelbase (the Octane's 0.85 m, doubled with speed so
# turn rates match RL's).
const RL_THROTTLE_FADE_AT := 1400.0 / 1410.0
const RL_STEER_ANGLE_CURVE := [Vector2(0.0, 0.53356), Vector2(500.0, 0.31930), Vector2(1000.0, 0.18203),
		Vector2(1500.0, 0.10570), Vector2(1750.0, 0.08507), Vector2(3000.0, 0.03454)]  # uu/s -> rad
const UU_PER_SPEED := 50.0  # our m/s -> RL uu/s (halve, then x100)
const GROUND_WHEELBASE := 1.7
const GROUND_STEER_RESPONSE := 20.0
## A contact counts as a surface under the fish when its normal is within ~45° of the fish's up.
const SURFACE_MIN_DOT := 0.7
## After a jump, surfaces are ignored this long so the fish leaves cleanly.
const SURFACE_JUMP_GRACE := 0.1
## An uncompleted flip counts as over once its spin has wound down below this (rad/s).
const FLIP_SPIN_OUT_MIN_RATE := 0.2
## Tolerance for comparing summed tick times to RL durations (78 ticks of 1/120 s
## add up to a hair over 0.65 in floating point).
const TIME_EPSILON := 0.0001

@export_group("Thrust")
@export_range(0.0, 60.0, 0.5) var forward_accel := 12.5
@export_range(0.0, 60.0, 0.5) var reverse_accel := 20.0
## Deceleration when holding reverse while still swimming forward.
@export_range(0.0, 120.0, 1.0) var brake_accel := 31.0
## Keep below max_boost_speed so boosting raises top speed. Throttle alone can
## never pass forward_accel / linear_drag (drag balances thrust there).
@export_range(0.0, 60.0, 0.5) var max_speed := 35.0
@export_range(0.0, 30.0, 0.5) var max_reverse_speed := 6.0

@export_group("Boost")
@export_range(0.0, 60.0, 0.5) var boost_accel := 10.0
## Absolute speed cap, also applied to jumps and dodges.
@export_range(0.0, 120.0, 0.5) var max_boost_speed := 75.0
@export var boost_unlimited := false
## Percent of the tank used per second (Rocket League: 33.3).
@export_range(0.0, 100.0, 0.5) var boost_drain := 50.0
@export_range(0.0, 100.0, 0.5) var boost_regen := 25.0

@export_group("Water")
## Fraction of speed lost per second.
@export_range(0.0, 3.0, 0.01) var linear_drag := 0.29
## Momentum above max_speed (from dodges, swim strokes or boost) fades at this
## rate while you keep swimming (throttle, boost or a stroke rhythm), like
## holding throttle above top speed in Rocket League. Applies to the extra speed
## only: 0.5 halves it in about 1.4 s. Coasting uses linear_drag as normal.
@export_range(0.0, 3.0, 0.01) var overspeed_drag := 0.5
## Extra drag on sideways/vertical slip. 0 = free drift, high = carves like it's on rails.
@export_range(0.0, 10.0, 0.05) var lateral_drag := 1.0
@export_range(0.0, 5.0, 0.05) var angular_drag := 1.0
## Upward acceleration. 0 = neutral buoyancy, negative sinks.
@export_range(-10.0, 10.0, 0.1) var buoyancy := -7.5
@export_range(0.0, 1.0, 0.05) var wall_bounce := 0.2:
	set(value):
		wall_bounce = value
		_apply_physics_material()
@export_range(0.0, 1.0, 0.05) var wall_friction := 0.2:
	set(value):
		wall_friction = value
		_apply_physics_material()

@export_group("Rotation")
## Roll with Rocket League's exact air-roll physics (RocketSim's constants), so a
## full roll takes the same time as in RL. Ignores roll_torque, roll_damping and
## angular_drag for roll, and caps total spin at RL's 5.5 rad/s.
@export var rl_roll_timing := true
@export_range(0.0, 60.0, 0.1) var pitch_torque := 12.15
@export_range(0.0, 60.0, 0.1) var yaw_torque := 8.8
@export_range(0.0, 80.0, 0.1) var roll_torque := 80.0
@export_range(0.0, 20.0, 0.05) var pitch_damping := 2.75
@export_range(0.0, 20.0, 0.05) var yaw_damping := 1.85
@export_range(0.0, 20.0, 0.05) var roll_damping := 4.05
@export_range(0.0, 15.0, 0.1) var max_angular_speed := 5.4
@export var invert_pitch := false

@export_group("Steering")
## Off a surface, turn with Rocket League's exact air control (RocketSim's
## torques and damping): turns on the spot, air roll, 5.5 rad/s cap. Off = the
## car steering / torque settings.
@export var rl_air_control := true
## Car-style steering: the stick picks a turning circle, so the fish only turns
## while it's moving (and steers backwards in reverse, like a car). Off = turn
## on the spot with the torque/damping values above, like a Rocket League aerial.
@export var car_steering := true
## Steer pitch (nose up/down) the same way. Off = pitch still works at a standstill.
@export var car_steering_pitch := true
## Turning circle at a crawl and at top boost speed. Tighter when slow, like Rocket League cars.
@export_range(0.5, 20.0, 0.1) var min_turn_radius := 2.6
@export_range(1.0, 60.0, 0.5) var max_turn_radius := 15.0
## How quickly the turn rate follows the stick.
@export_range(1.0, 40.0, 0.5) var steer_response := 5.0

@export_group("Swim Strokes")
## Sweep the stick side to side (or up and down) in a steady rhythm to swim
## faster, like a fish's tail or a dolphin's kick. The sweeps also steer, so the
## fish wiggles as it swims (gentler with a low steer_response). The first two
## beats set the tempo; every on-tempo beat after that adds speed.
@export var swim_strokes := true
## Strokes only count while the direction lock is held. Off = they always count.
@export var strokes_need_lock := false
## Speed added by each on-tempo beat (from the 3rd beat on).
@export_range(0.0, 10.0, 0.1) var stroke_impulse := 3.5
## Strokes stop adding speed here. Above max_speed, so good rhythm beats plain throttle.
@export_range(0.0, 80.0, 0.5) var stroke_max_speed := 40.0
## How far the stick must reach on each side for a stroke to count.
@export_range(0.1, 1.0, 0.05) var stroke_threshold := 0.6
## Strokes closer together than this are mashing and give nothing.
@export_range(0.05, 1.0, 0.01) var stroke_min_interval := 0.15
## A longer pause than this ends the rhythm.
@export_range(0.1, 2.0, 0.05) var stroke_max_interval := 0.7
## How much a beat may differ from the previous one (as a fraction) and still
## count as on tempo. Smaller = stricter timing. A beat outside it breaks the rhythm.
@export_range(0.05, 1.0, 0.05) var rhythm_tolerance := 0.3

@export_group("Jump & Dodge")
## Instant push along the fish's up axis on pressing jump. A double jump is this alone.
@export_range(0.0, 40.0, 0.1) var jump_impulse := 10.2
## Holding jump pushes higher, as in Rocket League: the first jump keeps
## accelerating while held, up to jump_hold_time. Off = every jump is a tap.
@export var variable_jump := true
## Push while held. RL's full hold adds as much again as the instant push
## (jump_impulse / jump_hold_time), so a full hold is twice a tap.
@export_range(0.0, 150.0, 0.5) var jump_hold_accel := 51.0
## Longest the hold keeps pushing. RL: 0.2 s.
@export_range(0.05, 1.0, 0.01) var jump_hold_time := 0.2
@export_range(0.0, 60.0, 0.1) var dodge_impulse := 7.0
## Time after the first jump during which a second press double-jumps or dodges.
@export_range(0.0, 3.0, 0.05) var double_jump_window := 1.2
## Wait after the second jump (or an unused window) before jumping again.
@export_range(0.0, 5.0, 0.05) var jump_cooldown := 0.0
## Stick deflection needed for a dodge; below it the second press is a double jump.
@export_range(0.0, 1.0, 0.05) var dodge_deadzone := 0.5
## Flip with Rocket League's exact dodge rotation (RocketSim's constants):
## same spin-up, 0.65 s of flip torque, pitch lock and flip cancel (pull the
## stick against the flip). Off = the simple scripted flip below.
@export var rl_dodge_timing := true
## Flips finish a full turn in the same time as in Rocket League when you keep
## holding the flip direction: after the flip torque, RL's own air control runs
## as if the stick (front/back flips) or air roll (side flips) were held, pitch
## lock included, and the fish stops square at one turn. A cancelled flip
## doesn't complete. Off = RL with no input: a flip stops short (~311°).
@export var complete_flips := false
## RL's flip Z-damp: early in a flip most vertical (world up/down) speed is
## removed, so dodges stay flat instead of drifting up with the jump.
@export var rl_flip_z_damp := true
## Scripted flip (only when RL Dodge Timing is off): full rotations and duration.
@export_range(0.0, 2.0, 0.05) var dodge_flip_turns := 1.0
@export_range(0.1, 2.0, 0.05) var dodge_flip_duration := 0.1
## Touching a surface refreshes the jumps, like landing in Rocket League.
@export var contact_refreshes_jump := true
## Lateral drag right after a jump or dodge, so the impulse carries instead of
## being eaten by carving drag. Eases back to lateral_drag over the time below.
@export_range(0.0, 10.0, 0.05) var post_jump_lateral_drag := 0.0
@export_range(0.0, 3.0, 0.05) var post_jump_drag_time := 0.0

@export_group("Powerslide")
## Lateral drag while powersliding: low = the fish keeps sliding the old way while it turns.
@export_range(0.0, 10.0, 0.05) var powerslide_lateral_drag := 0.35
## Multiplies pitch/yaw torque and the spin cap while powersliding.
@export_range(1.0, 4.0, 0.05) var powerslide_turn_multiplier := 1.35
## Forward thrust kept while powersliding (1 = full thrust).
@export_range(0.0, 1.0, 0.05) var powerslide_thrust_scale := 0.7

@export_group("Surface")
## While the fish's underside touches a surface (floor, walls, ceiling, the
## ball), drive like a Rocket League car: ground throttle, steering, grip and
## sticky force, sitting flat on the surface. Off = swim everywhere.
## Defaults are RocketSim's values with speeds doubled, like the rest of the game.
@export var rl_surface_mechanics := true
## Top driving speed. RL: 1410 uu/s.
@export_range(5.0, 80.0, 0.1) var ground_max_speed := 28.2
## Throttle acceleration from a standstill, fading to nothing at
## ground_max_speed on RL's curve. RL: 1600 uu/s².
@export_range(0.0, 100.0, 0.5) var ground_accel := 32.0
## Throttle against the direction of travel. RL: 3500 uu/s².
@export_range(0.0, 150.0, 0.5) var ground_brake := 70.0
## Slowing with no throttle. RL: 525 uu/s².
@export_range(0.0, 50.0, 0.5) var ground_coast_decel := 10.5
## RL: 991.7 uu/s² on the ground.
@export_range(0.0, 80.0, 0.1) var ground_boost_accel := 19.8
## Top speed with boost. RL: 2300 uu/s.
@export_range(5.0, 120.0, 0.5) var ground_max_boost_speed := 46.0
## Tyre grip: how quickly sliding sideways is stopped (per second).
## Powersliding uses powerslide_lateral_drag instead.
@export_range(0.0, 40.0, 0.5) var ground_grip := 15.0
## Push into the surface, like RL's sticky force: half of this at rest, and
## while driving up to 1.5x on a wall. RL: its gravity, 650 uu/s².
@export_range(0.0, 40.0, 0.5) var surface_stick := 13.0
## How quickly the fish turns to sit flat on the surface it's on.
@export_range(1.0, 40.0, 0.5) var surface_align_rate := 15.0

@export_group("Hitbox")
## A box, like Rocket League's car hitboxes: flat on the floor, flat on top to
## carry the ball. Defaults keep the Octane's length-to-width ratio
## (118 x 84 uu) and are tall enough to cover the fish's body.
@export_range(0.5, 4.0, 0.01) var hitbox_length := 1.5:
	set(value):
		hitbox_length = value
		_apply_hitbox()
@export_range(0.3, 3.0, 0.01) var hitbox_width := 1.07:
	set(value):
		hitbox_width = value
		_apply_hitbox()
@export_range(0.2, 2.0, 0.01) var hitbox_height := 0.7:
	set(value):
		hitbox_height = value
		_apply_hitbox()
## Draw the hitbox as a see-through box.
@export var show_hitbox := false:
	set(value):
		show_hitbox = value
		_apply_hitbox()
# Telemetry, read by the HUD.
var speed := 0.0
var forward_speed := 0.0
var drift_angle := 0.0
var angular_speed := 0.0
var boost_amount := 100.0
var is_boosting := false
var jump_state := JumpState.READY
## True while a dodge flip is rotating the fish (thrust paused, camera held).
var is_dodging := false
var is_powersliding := false
## Driving on a surface (see rl_surface_mechanics), and that surface's normal.
var on_surface := false
var surface_normal := Vector3.UP
## Strokes in the current rhythm, and how well the last one was timed (0..1).
var stroke_chain := 0
var stroke_quality := 0.0

# Latest input, sampled every physics tick.
var input_forward := 0.0
var input_reverse := 0.0
var input_stick := Vector2.ZERO
var input_roll := 0.0
var air_roll_held := false
var jump_held := false
var boost_held := false
var powerslide_held := false
## Direction lock: holds the current heading, and turns stick sweeps into swim strokes.
var direction_lock_held := false

var _jump_queued := false
var _jump_was_held := false
var _jump_timer := 0.0
## Time since the first jump began while its hold push is running; -1 when it isn't.
var _jump_hold_elapsed := -1.0
var _post_jump_time_left := 0.0
var _steer_speed := 0.0
var _lock_direction := Vector3.FORWARD
var _lock_local := Vector3.FORWARD  # _lock_direction in the fish's own frame
var _was_locked := false
## Seconds since the current RL-style dodge started; negative when not flipping.
var _flip_time := -1.0
## Dodge angular acceleration in the fish's frame (x = pitch, z = roll, rad/s²).
var _flip_torque := Vector3.ZERO
## Rotation so far about the flip's axis, and whether the flip was cancelled.
var _flip_angle := 0.0
var _flip_cancelled := false
## A flip that ended short of a full turn while the fish is still turning the
## same way (e.g. stick held); the camera keeps holding until it's round.
var _flip_spin_out := false
## Normalized dodge direction (x = forward, y = right), as in RocketSim's dodgeDir.
var _flip_direction := Vector2.ZERO
var _flip_time_left := 0.0
var _flip_axis := Vector3.ZERO
var _reset_queued := false
var _surface_grace := 0.0
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
@onready var _collision: CollisionShape3D = $Collision
var _hitbox_view := MeshInstance3D.new()


func _ready() -> void:
	_spawn_transform = global_transform
	physics_material_override = PhysicsMaterial.new()
	_apply_physics_material()
	_collision.shape = _collision.shape.duplicate()  # sized per fish
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 1.0, 0.5, 0.25)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_hitbox_view.mesh = BoxMesh.new()
	_hitbox_view.material_override = material
	_hitbox_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hitbox_view)
	_apply_hitbox()


func _apply_hitbox() -> void:
	if _collision == null:  # set before _ready; applied there
		return
	var size := Vector3(hitbox_width, hitbox_height, hitbox_length)
	(_collision.shape as BoxShape3D).size = size
	(_hitbox_view.mesh as BoxMesh).size = size
	_hitbox_view.visible = show_hitbox


func request_reset() -> void:
	_reset_queued = true


## True from a dodge until its flip is fully over, including a cancelled flip's
## wind-down (unlike is_dodging, which a cancel clears straight away) and an
## uncompleted flip that's still turning round on its own.
func is_flipping() -> bool:
	return is_dodging or _flip_time >= 0.0 or _flip_spin_out


## Whether a setting does anything with the current toggles; the tuning panel hides the rest.
func is_option_active(property: String) -> bool:
	match property:
		"roll_torque", "roll_damping", "max_angular_speed":
			return not rl_roll_timing
		"pitch_torque", "pitch_damping":
			return not rl_air_control and not (car_steering and car_steering_pitch)
		"yaw_torque", "yaw_damping":
			return not rl_air_control and not car_steering
		"angular_drag":  # water damping on whichever rotations use torque (a Water ball can still inherit it)
			if rl_air_control:
				return not rl_roll_timing  # only roll under a direction lock
			return not (car_steering and car_steering_pitch and rl_roll_timing)
		"car_steering":
			return not rl_air_control
		"car_steering_pitch", "min_turn_radius", "max_turn_radius", "steer_response":
			return car_steering and not rl_air_control
		"ground_max_speed", "ground_accel", "ground_brake", "ground_coast_decel", "ground_boost_accel", \
				"ground_max_boost_speed", "ground_grip", "surface_stick", "surface_align_rate":
			return rl_surface_mechanics
		"boost_drain", "boost_regen":
			return not boost_unlimited
		"strokes_need_lock", "stroke_impulse", "stroke_max_speed", "stroke_threshold", \
				"stroke_min_interval", "stroke_max_interval", "rhythm_tolerance":
			return swim_strokes
		"jump_hold_accel", "jump_hold_time":
			return variable_jump
		"complete_flips", "rl_flip_z_damp":
			return rl_dodge_timing
		"dodge_flip_turns", "dodge_flip_duration":
			return not rl_dodge_timing
	return true


## Move the reset point (e.g. when switching environments) and go there.
func set_spawn(spawn: Transform3D) -> void:
	_spawn_transform = spawn
	request_reset()


## Called at the start of each physics tick from _integrate_forces. Godot runs
## that callback before _physics_process, so sampling input there would apply
## it a tick (8.3 ms) late.
func _sample_input(delta: float) -> void:
	input_forward = Input.get_action_strength("thrust_forward")
	input_reverse = Input.get_action_strength("thrust_reverse")
	input_stick = Input.get_vector("stick_left", "stick_right", "stick_up", "stick_down")
	input_roll = Input.get_action_strength("roll_right") - Input.get_action_strength("roll_left")
	air_roll_held = Input.is_action_pressed("air_roll")
	boost_held = Input.is_action_pressed("boost")
	powerslide_held = Input.is_action_pressed("powerslide")
	direction_lock_held = Input.is_action_pressed("direction_lock")
	# Detect the press ourselves: "just pressed" is tracked per frame and isn't
	# reliable this early in the physics tick.
	jump_held = Input.is_action_pressed("jump")
	if jump_held and not _jump_was_held:
		_jump_queued = true
	_jump_was_held = jump_held
	_detect_strokes(delta)


## A stroke is the stick swinging from one side to the opposite side.
func _detect_strokes(delta: float) -> void:
	_stroke_clock += delta
	if _stroke_clock - _last_stroke_time > stroke_max_interval:
		stroke_chain = 0
	if not swim_strokes or is_dodging or (strokes_need_lock and not direction_lock_held):
		# Letting go of the lock ends the rhythm; the next one starts fresh.
		stroke_chain = 0
		_last_stroke_interval = 0.0
		_stroke_side = Vector2i.ZERO
		return
	for axis in 2:
		var value := input_stick[axis]
		if absf(value) < stroke_threshold:
			continue
		var side := 1 if value > 0.0 else -1
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
	var continues := stroke_chain > 0 and interval <= stroke_max_interval and axis == _stroke_axis
	_stroke_axis = axis
	stroke_quality = 0.0
	if not continues:
		_start_rhythm()  # this stroke is beat 1 of a new rhythm
		return
	stroke_chain += 1
	if _last_stroke_interval <= 0.0:
		_last_stroke_interval = interval  # beat 2 sets the tempo
		return

	var drift := absf(interval - _last_stroke_interval) / _last_stroke_interval
	if drift > rhythm_tolerance:
		_start_rhythm()  # off tempo: the rhythm breaks and restarts from this beat
		return
	# On tempo: a small push. Following the latest interval lets the tempo drift
	# gradually faster or slower without breaking the rhythm.
	stroke_quality = 1.0 - drift / rhythm_tolerance
	_last_stroke_interval = interval
	_queued_stroke += 1.0
	stroked.emit(stroke_quality)


func _start_rhythm() -> void:
	stroke_chain = 1
	_last_stroke_interval = 0.0


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dt := state.step
	_sample_input(dt)
	if _reset_queued:
		_apply_reset(state)
		return

	var body_basis := state.transform.basis.orthonormalized()
	var forward := -body_basis.z
	var velocity := state.linear_velocity
	is_powersliding = powerslide_held and not is_dodging

	# Direction lock: the nose stays pointed where it faced when the lock was
	# pressed (no turning left/right/up/down), while roll stays free.
	if direction_lock_held and not _was_locked:
		_lock_direction = forward
	_was_locked = direction_lock_held
	_lock_local = body_basis.transposed() * _lock_direction

	_detect_surface(state, body_basis, dt)
	if on_surface:
		velocity = _apply_ground(velocity, body_basis, dt)
	else:
		velocity = _apply_thrust(velocity, forward, dt)
		velocity = _apply_strokes(velocity, forward)
		velocity = _apply_water(velocity, forward, dt)
	velocity = _apply_jump(velocity, body_basis, state.get_contact_count() > 0, dt)
	velocity = _apply_flip_z_damp(velocity, dt)
	velocity = velocity.limit_length(max_boost_speed)

	# Steering uses the full speed (so a sliding fish can still steer), signed
	# negative when swimming backwards so steering flips like a reversing car.
	# Only while reverse is held: judging by velocity alone, turning away from a
	# drift (e.g. pitching up while sinking) would flip the steering part-way
	# round and stall the turn.
	var reversing := input_reverse > 0.0 and velocity.dot(forward) < -0.5
	_steer_speed = -velocity.length() if reversing else velocity.length()

	# Work on angular velocity in the fish's own frame: x = pitch, y = yaw, z = roll.
	var local_spin := body_basis.transposed() * state.angular_velocity
	if on_surface:
		local_spin = _apply_ground_rotation(local_spin, body_basis, velocity, dt)
	else:
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
	# Mid-flip the nose spins through every direction, so swim throttle would
	# brake the dodge; it pauses until the flip is over. Boost never pauses: it
	# always pushes the way the fish is facing, as in Rocket League.
	if not is_dodging:
		if input_forward > 0.0 and along < max_speed:
			var thrust_scale := powerslide_thrust_scale if is_powersliding else 1.0
			accel += forward_accel * input_forward * thrust_scale
		if input_reverse > 0.0:
			if along > 0.5:
				accel -= brake_accel * input_reverse
			elif -along < max_reverse_speed:
				accel -= reverse_accel * input_reverse

	_update_boost(dt)
	if is_boosting and along < max_boost_speed:
		accel += boost_accel

	return velocity + forward * accel * dt


func _update_boost(dt: float) -> void:
	is_boosting = boost_held and (boost_unlimited or boost_amount > 0.0)
	if boost_unlimited:
		return
	if is_boosting:
		boost_amount = maxf(boost_amount - boost_drain * dt, 0.0)
	else:
		boost_amount = minf(boost_amount + boost_regen * dt, 100.0)


## On a surface when a contact under the fish (normal within ~45° of its up)
## touches anything: floor, wall, ceiling, the ball. Not mid-flip, nor just
## after a jump.
func _detect_surface(state: PhysicsDirectBodyState3D, body_basis: Basis, dt: float) -> void:
	_surface_grace -= dt
	var normal_sum := Vector3.ZERO
	if rl_surface_mechanics and _surface_grace <= 0.0 and _flip_time < 0.0 and not is_dodging:
		for i in state.get_contact_count():
			var normal := state.get_contact_local_normal(i)
			if normal.dot(body_basis.y) > SURFACE_MIN_DOT:
				normal_sum += normal
	var was_on_surface := on_surface
	on_surface = normal_sum != Vector3.ZERO
	if on_surface != was_on_surface:
		_apply_physics_material()
	if on_surface:
		surface_normal = normal_sum.normalized()
		_flip_spin_out = false


## Rocket League driving on whatever surface the fish is on (RocketSim
## Car::_UpdateWheels, simplified to the whole body): throttle on RL's torque
## curve, braking, coasting, boost, tyre grip across the nose, and the sticky
## push into the surface. Water drag doesn't apply; buoyancy still does.
func _apply_ground(velocity: Vector3, body_basis: Basis, dt: float) -> Vector3:
	var forward := -body_basis.z
	var along := velocity.dot(forward)
	_update_boost(dt)
	var throttle := 1.0 if is_boosting else input_forward - input_reverse  # RL: boost implies full throttle
	var accel := 0.0
	if throttle != 0.0:
		if along * throttle < -0.5:
			accel = ground_brake * signf(throttle)  # pushing against the motion brakes
		else:
			accel = throttle * ground_accel * _ground_torque_factor(absf(along))
	else:
		accel = -signf(along) * minf(ground_coast_decel, absf(along) / dt)
	if is_boosting and along < ground_max_boost_speed:
		accel += ground_boost_accel
	velocity += forward * accel * dt

	var side := body_basis.x * velocity.dot(body_basis.x)
	var grip := powerslide_lateral_drag if is_powersliding else ground_grip
	velocity -= side * (1.0 - exp(-grip * dt))

	# RL sticky force: half strength always, plus up to full strength more the
	# further the surface is from level while driving, so walls hold.
	var driving := throttle != 0.0 or absf(along) > 0.5
	var stick := 0.5 + (1.0 - absf(body_basis.y.y) if driving else 0.0)
	velocity -= surface_normal * surface_stick * stick * dt
	velocity.y += buoyancy * dt
	return velocity


## RL's throttle torque factor: full at a standstill, 10% just under
## ground_max_speed, nothing at it.
func _ground_torque_factor(ground_speed: float) -> float:
	var t := ground_speed / maxf(ground_max_speed, 0.01)
	if t < RL_THROTTLE_FADE_AT:
		return lerpf(1.0, 0.1, t / RL_THROTTLE_FADE_AT)
	return maxf(lerpf(0.1, 0.0, (t - RL_THROTTLE_FADE_AT) / (1.0 - RL_THROTTLE_FADE_AT)), 0.0)


## Steering on a surface: RL's speed-dependent steering angle, no pitch or roll
## control, and the fish turning to sit flat on the surface.
func _apply_ground_rotation(local_spin: Vector3, body_basis: Basis, velocity: Vector3, dt: float) -> Vector3:
	var along := velocity.dot(-body_basis.z)
	var turn := powerslide_turn_multiplier if is_powersliding else 1.0
	# Signed by the direction of travel, so reversing steers like a car.
	var target := input_stick.x * turn * along * tan(_rl_steer_angle(absf(along))) / GROUND_WHEELBASE
	var yaw_rate := lerpf(-local_spin.y, target, 1.0 - exp(-GROUND_STEER_RESPONSE * dt))
	var align := body_basis.transposed() * (body_basis.y.cross(surface_normal) * surface_align_rate)
	return Vector3(align.x, -yaw_rate, align.z)


func _rl_steer_angle(ground_speed: float) -> float:
	var uu := ground_speed * UU_PER_SPEED
	for i in range(1, RL_STEER_ANGLE_CURVE.size()):
		var a: Vector2 = RL_STEER_ANGLE_CURVE[i - 1]
		var b: Vector2 = RL_STEER_ANGLE_CURVE[i]
		if uu <= b.x:
			return lerpf(a.y, b.y, (uu - a.x) / (b.x - a.x))
	return RL_STEER_ANGLE_CURVE[-1].y


func _apply_strokes(velocity: Vector3, direction: Vector3) -> Vector3:
	var strength := _queued_stroke
	_queued_stroke = 0.0
	var room := stroke_max_speed - velocity.dot(direction)
	if strength <= 0.0 or room <= 0.0:
		return velocity
	return velocity + direction * minf(stroke_impulse * strength, room)


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


func _apply_flip_z_damp(velocity: Vector3, dt: float) -> Vector3:
	if not rl_flip_z_damp or _flip_time < 0.0:
		return velocity
	var t := _flip_time + dt  # the flip clock for this tick (advanced in _apply_rl_flip)
	var in_window := t >= RL_FLIP_Z_DAMP_START - TIME_EPSILON and t <= RL_FLIP_TORQUE_TIME + TIME_EPSILON
	if in_window and (velocity.y < 0.0 or t < RL_FLIP_Z_DAMP_END - TIME_EPSILON):
		velocity.y *= pow(1.0 - RL_FLIP_Z_DAMP_120, dt * 120.0)
	return velocity


## Lateral drag, lowered while powersliding and just after a jump or dodge.
func _effective_lateral_drag(dt: float) -> float:
	var drag := lateral_drag
	if is_powersliding:
		drag = minf(drag, powerslide_lateral_drag)
	if _flip_time >= 0.0:
		# Mid-flip the nose points every which way; don't let that bleed speed.
		return minf(drag, post_jump_lateral_drag)
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
				_jump_hold_elapsed = 0.0 if variable_jump else -1.0
				_surface_grace = SURFACE_JUMP_GRACE
				_post_jump_time_left = post_jump_drag_time
				jumped.emit()
		JumpState.SECOND_JUMP:
			if _jump_hold_elapsed >= 0.0:
				# Holding the first jump keeps pushing; the double jump window
				# only starts counting once the hold is over, as in RL.
				_jump_hold_elapsed += dt
				var holding := jump_held or _jump_hold_elapsed <= RL_JUMP_MIN_HOLD + TIME_EPSILON
				if holding and not pressed and _jump_hold_elapsed <= jump_hold_time + TIME_EPSILON:
					velocity += body_basis.y * jump_hold_accel * dt
					_jump_timer = double_jump_window
				else:
					_jump_hold_elapsed = -1.0
			if pressed:
				velocity = _second_jump(velocity, body_basis)
				_surface_grace = SURFACE_JUMP_GRACE
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
	if rl_dodge_timing:
		_start_rl_flip()
	elif dodge_flip_turns > 0.0:
		# Spin so the nose dips toward the dodge direction (front flip, side flip...).
		_flip_axis = Vector3.UP.cross(local_dir).normalized()
		_flip_time_left = dodge_flip_duration
		is_dodging = true
	dodged.emit(world_dir)
	return velocity + world_dir * dodge_impulse


## Rocket League's dodge direction: forward/back from pitch, sideways from yaw
## plus roll, normalized, with tiny components ignored (RocketSim Car.cpp).
func _start_rl_flip() -> void:
	var forward_amount := -input_stick.y  # stick up = front flip
	var side_amount := input_stick.x + input_roll
	var dodge_dir := Vector2(forward_amount, side_amount)
	if absf(side_amount) < 0.1 and absf(forward_amount) < 0.1:
		dodge_dir = Vector2.ZERO  # a "stall": no flip torque
	else:
		dodge_dir = dodge_dir.normalized()
	# Front flip dips the nose (negative pitch); a right flip rolls right.
	# Roll rate is stored negated in the fish's frame (see _apply_rotation).
	_flip_torque = Vector3(-RL_FLIP_TORQUE_FORWARD * dodge_dir.x, 0.0, -RL_FLIP_TORQUE_SIDE * dodge_dir.y)
	_flip_time = 0.0
	_flip_angle = 0.0
	_flip_cancelled = false
	_flip_spin_out = false
	_flip_direction = dodge_dir
	is_dodging = true


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

	if _flip_time >= 0.0:
		return _apply_rl_flip(local_spin, yaw_in, roll_in, dt)

	if _flip_spin_out and direction_lock_held:
		_flip_spin_out = false
	if _flip_spin_out:
		# An uncompleted flip winds down under RL air control, as it would in
		# RL, instead of car steering stopping it dead.
		var out_spin := _rl_air_control(local_spin, pitch_in, yaw_in, roll_in, dt)
		var rate := out_spin.dot(_flip_torque.normalized())
		_flip_angle += rate * dt
		if _flip_angle >= TAU or rate < FLIP_SPIN_OUT_MIN_RATE:
			_flip_spin_out = false
		return out_spin

	if rl_air_control and not direction_lock_held:
		return _rl_air_control(local_spin, pitch_in, yaw_in, roll_in, dt)

	# Signed so positive = pitch up, yaw right, roll right.
	var pitch_rate := local_spin.x
	var yaw_rate := -local_spin.y
	var roll_rate := -local_spin.z
	var turn := powerslide_turn_multiplier if is_powersliding else 1.0
	var water := exp(-angular_drag * dt)
	if direction_lock_held:
		# Locked: no turning; just hold the nose on the locked direction
		# (rotating about nose x target brings it back if anything knocked it off).
		var correction := Vector3.FORWARD.cross(_lock_local) * LOCK_ALIGN_RATE
		pitch_rate = correction.x
		yaw_rate = -correction.y
	else:
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
	if rl_roll_timing:
		roll_rate += (RL_ROLL_TORQUE * roll_in - RL_ROLL_DAMPING * roll_rate) * dt
		roll_rate = clampf(roll_rate, -RL_MAX_ANGULAR_SPEED, RL_MAX_ANGULAR_SPEED)
	else:
		roll_rate += (roll_torque * roll_in - roll_damping * roll_rate) * dt
		roll_rate *= water

	var spin := Vector3(pitch_rate, -yaw_rate, -roll_rate)
	# RL clamps total spin to 5.5 rad/s; a powerslide still allows extra turning.
	var cap := RL_MAX_ANGULAR_SPEED if rl_roll_timing else max_angular_speed
	return spin.limit_length(cap * turn)


## One tick of Rocket League's air control (RocketSim Car::_UpdateAirTorque):
## torque from the inputs, damping on pitch and yaw that eases off as their
## input is held, constant damping on roll, total spin capped at 5.5 rad/s.
## Spin is in the fish's frame (x = pitch, y = yaw, z = roll) as elsewhere.
func _rl_air_control(spin: Vector3, pitch_in: float, yaw_in: float, roll_in: float, dt: float) -> Vector3:
	var pitch_rate := spin.x
	var yaw_rate := -spin.y
	var roll_rate := -spin.z
	pitch_rate += (RL_PITCH_TORQUE * pitch_in - RL_PITCH_DAMPING * (1.0 - absf(pitch_in)) * pitch_rate) * dt
	yaw_rate += (RL_YAW_TORQUE * yaw_in - RL_YAW_DAMPING * (1.0 - absf(yaw_in)) * yaw_rate) * dt
	roll_rate += (RL_ROLL_TORQUE * roll_in - RL_ROLL_DAMPING * roll_rate) * dt
	return Vector3(pitch_rate, -yaw_rate, -roll_rate).limit_length(RL_MAX_ANGULAR_SPEED)


## One tick of a Rocket League dodge flip (RocketSim Car::_UpdateAirTorque),
## optionally carried on to a full turn afterwards (complete_flips).
func _apply_rl_flip(spin: Vector3, yaw_in: float, roll_in: float, dt: float) -> Vector3:
	_flip_time += dt
	var axis := _flip_torque.normalized()
	var air_control := true
	if _flip_time <= RL_FLIP_TORQUE_TIME + TIME_EPSILON:
		var torque := _flip_torque
		# Flip cancel, checked every tick: pitching against the flip (stick back
		# during a front flip, forward during a back flip) scales the flip's
		# pitch torque by 1 - |pitch| and re-enables air control. Not latched:
		# letting go of the stick lets the flip torque resume.
		var rl_pitch := input_stick.y  # RL pitch input: positive = stick back
		var cancelling := torque.x != 0.0 and rl_pitch != 0.0 and signf(rl_pitch) == -signf(torque.x)
		if cancelling:
			torque.x *= 1.0 - minf(absf(rl_pitch), 1.0)
			_flip_cancelled = true
			# A cancel drops you straight back into normal air play, as in RL:
			# throttle, boost, strokes and camera follow return right away, while
			# RL's air rules (pitch locked until 0.95 s) wind the spin down.
			is_dodging = false
		# A normal flip has no air control or damping; a cancel or a stall does.
		air_control = cancelling or _flip_torque == Vector3.ZERO
		spin += torque * dt
	elif complete_flips and not _flip_cancelled and _flip_torque != Vector3.ZERO:
		return _complete_flip(spin, axis, dt)

	if air_control:
		spin = _rl_air_control(spin, 0.0, yaw_in, roll_in, dt)  # pitch locked: no pitch input, full damping

	spin = spin.limit_length(RL_MAX_ANGULAR_SPEED)
	_flip_angle += spin.dot(axis) * dt
	if _flip_time >= RL_FLIP_TORQUE_TIME + RL_FLIP_PITCHLOCK_EXTRA_TIME - TIME_EPSILON:
		_end_flip()  # pitch lock over (RL-exact path): normal steering resumes
	return spin


## After the flip torque: Rocket League's air control as if the player keeps
## holding the flip direction (pitch for front/back flips, air roll for side
## flips), so the flip finishes when it would in RL. Pitch input stays locked
## for FLIP_PITCHLOCK_EXTRA_TIME, exactly as in RL. Stops square at one turn.
func _complete_flip(spin: Vector3, axis: Vector3, dt: float) -> Vector3:
	var remaining := TAU - _flip_angle
	if remaining <= TIME_EPSILON:
		_end_flip()
		return Vector3.ZERO

	var held_pitch := -_flip_direction.x  # front flip: nose down
	var held_roll := _flip_direction.y  # right flip: roll right
	var pitch_lock := _flip_time <= RL_FLIP_TORQUE_TIME + RL_FLIP_PITCHLOCK_EXTRA_TIME + TIME_EPSILON
	var pitch_scale := 0.0 if pitch_lock else 1.0
	spin = _rl_air_control(spin, held_pitch * pitch_scale, 0.0, held_roll, dt)

	# Land exactly on one full turn instead of overshooting on the last tick.
	var step_angle := spin.dot(axis) * dt
	if step_angle > remaining:
		spin *= remaining / step_angle
		step_angle = remaining
	_flip_angle += step_angle
	return spin


## The whole flip counts as dodging (no thrust, held camera); the low
## post-jump drag starts once it's over.
func _end_flip() -> void:
	_flip_spin_out = not _flip_cancelled and _flip_torque != Vector3.ZERO and _flip_angle < TAU - TIME_EPSILON
	_flip_time = -1.0
	is_dodging = false
	_post_jump_time_left = post_jump_drag_time


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
	_flip_time = -1.0
	_flip_spin_out = false
	on_surface = false
	_surface_grace = 0.0
	_post_jump_time_left = 0.0
	_queued_stroke = 0.0
	stroke_chain = 0
	is_dodging = false
	jump_state = JumpState.READY
	_jump_hold_elapsed = -1.0
	boost_amount = 100.0
	reset_physics_interpolation.call_deferred()


func _apply_physics_material() -> void:
	if physics_material_override == null:
		return
	physics_material_override.bounce = wall_bounce
	# Driving, the body doesn't scrape: an RL car rides on its wheels, and the
	# ground model already handles grip. (The ball grips a fish it rests on itself.)
	physics_material_override.friction = 0.0 if on_surface else wall_friction


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
