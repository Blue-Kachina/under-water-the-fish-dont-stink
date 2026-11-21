class_name SwimState
extends RefCounted
## What a fish's body is doing right now, the one thing its animation reads
## (planning_core_roadmap.md M5 and section 2.2): FishController fills it at the
## end of every physics tick from the physics itself; puppets, replays and
## school fish synthesise the kinematic half from their velocity history
## (advance_from_velocity, from_velocity_history), so one model animates any
## fish. Reused, never reallocated. Rigs and models read it and never read
## inputs or the clock.
##
## Frames: "body" is the fish's own, x right, y up, -z forward. Angles of motion
## are radians except `drift_angle` (degrees, as FishController has it).

## How long (s) `accel` smooths over: physics ticks are 1/120 s and a render
## frame doesn't line up with them.
const ACCEL_TIME := 0.06
## Past this the previous velocity isn't trusted (a teleport, a respawn).
const MAX_STEP := 0.5

# Motion, from the velocity (every fish).
var velocity := Vector3.ZERO  # world, m/s
var speed := 0.0
## speed over the class's cruise speed (the throttle's cap), 0..1.
var speed_frac := 0.0
## How hard the fish is working, 0..1. Fish with a controller: the throttle, a
## boost or a stride's power, whichever is greatest. Synthesised ones don't
## know their inputs: their stride power or how fast they go (speed_frac).
var effort := 0.0
var forward_speed := 0.0  # + along the nose
var accel := Vector3.ZERO  # body frame, m/s squared, smoothed over ACCEL_TIME
var spin := Vector3.ZERO  # body frame pitch, yaw, roll rates (x, y, z), rad/s
## The velocity less its part along the nose, body frame (z is 0): the side and
## up-down drift of a fish whose heading and travel have parted.
var slip := Vector3.ZERO
var drift_angle := 0.0  # nose to velocity, degrees

# Stride (Extra Swishy). `striding` is whether that gait is on at all; the rest
# are idle values (-1 phase, 0 power) between strides or when it's off.
var striding := false
var stride_phase := -1.0  # s since the stride began
var stride_power := 0.0  # its envelope, 0..1
var stride_dir := Vector2.ZERO  # the tail's swing: x across, y up and down (SwishySwim.tail_swing)
var stride_fluke := 0.0  # the flukes' beat, -1..1 (SwishySwim.fluke_swing)
var stride_peak := 0.3  # s to the peak
var stride_fade := 0.5  # s from the peak to nothing
var stride_timing := -1.0  # how well the last stride was timed, -1 for a fresh chain
var stride_flow := 0.0  # the chain's flow over its cap
var stride_sweet := 0.0  # how close to the peak (SwishySwim.sweetness)
## The tail's timing cue: fill, glow, gold (SwishySwim.cue).
var stride_cue := Vector3.ZERO

# What the fish is on and how it carries itself.
var grounded := false
var surface_normal := Vector3.UP
## How far a jelly's bell leans toward the nose (rad), -1 when the fish isn't a bell swimmer.
var bell_lean := -1.0
## The gait it swims in (null for a fish without one: the model's defaults).
var gait: Gait

# Pose cues of the fish's own controls, for the pose formulas that haven't
# become motion yet (planning_core_roadmap.md 1.4 F4). Zero when synthesised.
var boosting := false
var reverse := 0.0  # the reverse throttle, 0..1
var slide := 0.0  # powersliding, 0 or 1
## The stick's side, flipped, while powersliding (else 0): the way the tail kicks out of the turn.
var slide_kick := 0.0
## The stick's sweep while a plain swim-stroke chain runs (the ORIGINAL style), else zero.
var stroke_dir := Vector2.ZERO

var _last_velocity := Vector3.ZERO
var _has_last := false
var _last_basis := Basis.IDENTITY
var _has_basis := false


## Forgets the history (a respawn or a cut), so the next step's acceleration and
## spin start from nothing instead of from the jump.
func reset() -> void:
	_has_last = false
	_has_basis = false
	accel = Vector3.ZERO
	spin = Vector3.ZERO


## The kinematic fields for a step of `dt` s that ended with `world_velocity`, the
## body facing along `body` (any basis; it's orthonormalised) and turning at
## `local_spin` (body frame). `top_speed` is the cruise speed speed_frac is of.
## Doesn't touch the stride or pose fields. No allocation.
func advance(world_velocity: Vector3, body: Basis, local_spin: Vector3, dt: float, top_speed: float) -> void:
	var frame := body.orthonormalized()
	velocity = world_velocity
	speed = world_velocity.length()
	speed_frac = clampf(speed / maxf(top_speed, 0.01), 0.0, 1.0)
	var local := frame.transposed() * world_velocity
	forward_speed = -local.z
	slip = Vector3(local.x, local.y, 0.0)
	var forward := -frame.z
	drift_angle = rad_to_deg(forward.angle_to(world_velocity)) if speed > 0.5 else 0.0
	spin = local_spin
	if _has_last and dt > 0.0 and dt < MAX_STEP:
		var raw := frame.transposed() * ((world_velocity - _last_velocity) / dt)
		accel = accel.lerp(raw, 1.0 - exp(-dt / ACCEL_TIME))
	else:
		accel = Vector3.ZERO
	_last_velocity = world_velocity
	_has_last = true


## advance() for a fish with no physics body (a puppet, a replay's car, a school
## fish): the spin comes from how far its basis turned since the last call.
func advance_from_velocity(world_velocity: Vector3, body: Basis, dt: float, top_speed: float) -> void:
	var frame := body.orthonormalized()
	var turned := Vector3.ZERO
	if _has_basis and dt > 0.0 and dt < MAX_STEP:
		var step := Quaternion((_last_basis.transposed() * frame).orthonormalized())
		var angle := step.get_angle()
		if angle > PI:
			angle -= TAU
		turned = step.get_axis() * (angle / dt) if absf(angle) > 1e-6 else Vector3.ZERO
	_last_basis = frame
	_has_basis = true
	advance(world_velocity, frame, turned, dt, top_speed)
	effort = maxf(stride_power, speed_frac)


## A state replayed from a history: `velocities[i]` and `bases[i]` are the
## fish's velocity and orientation after step i, `dt` s apart. For offline
## checks, bakes and anything that has a trail of samples rather than a body.
static func from_velocity_history(velocities: PackedVector3Array, bases: Array[Basis], dt: float, top_speed: float) -> SwimState:
	var state := SwimState.new()
	for i in mini(velocities.size(), bases.size()):
		state.advance_from_velocity(velocities[i], bases[i], dt, top_speed)
	return state
