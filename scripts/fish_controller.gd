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
## An Extra Swishy stride began (SwishySwim): its timing (0..1, or -1 for a
## fresh start) and the flow it left.
signal strode(timing: float, flow: float)
## Start of every physics tick, before input is sampled: `state` is the result
## of the last step. Lets a test driver (tests/physics_parity_probe) read the
## state and set this tick's input with no lag.
signal physics_tick(state: PhysicsDirectBodyState3D)

## READY: on the first jump. SECOND_JUMP: a second press within double_jump_window
## gives a double jump (stick neutral) or a dodge (stick pushed). COOLDOWN: both used.
enum JumpState { READY, SECOND_JUMP, COOLDOWN }
## Every fish in play (the player's and bots') is in this group.
const GROUP := &"fish"
## RL's supersonic speed (2200 uu/s): demolitions need it.
const SUPERSONIC_SPEED := 22.0
## How quickly the bow wave grows and shrinks (its size, 0..1, per second).
const BOW_RESPONSE := 2.5
const BOW_SHADER := preload("res://shaders/bow_wave.gdshader")
## The bow wave's convex shape: rings from the middle to the tip, points per ring.
const BOW_RINGS := 6
const BOW_SIDES := 12
## Rocket League's deadzone shapes. CIRCLE: on the stick's distance from centre.
## CROSS: on each axis separately, so a nearly straight push stays exactly straight.
enum DeadzoneShape { CIRCLE, CROSS }
## How swim strokes work. ORIGINAL: a steady rhythm of stick sweeps adds a
## little speed per on-tempo beat. EXTRA_SWISHY: each sweep is a stride that
## builds and fades, and alternating at its peak compounds speed (SwishySwim).
enum SwimStyle { ORIGINAL, EXTRA_SWISHY }

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
## The hold push is this much weaker during JUMP_MIN_TIME (RocketSim JUMP_PRE_MIN_ACCEL_SCALE).
const RL_JUMP_PRE_MIN_ACCEL_SCALE := 0.62
## After a jump off a surface, RL's wheels stay on it for a few ticks while the
## suspension extends, and the sticky force keeps pulling until they lift off.
const RL_JUMP_WHEEL_CONTACT_TIME := 0.025 + 0.001  # 3 ticks; matches RocketSim tick for tick
# Rocket League driving (RocketSim RLConst.h). Throttle torque
# fades from full at a standstill to 10% just under max driving speed (1400 of
# 1410 uu/s), then to nothing. Steering angle shrinks with speed; the turn rate
# is speed * tan(angle) / wheelbase (the Octane's 0.85 m).
const RL_THROTTLE_FADE_AT := 1400.0 / 1410.0
const RL_STEER_ANGLE_CURVE := [Vector2(0.0, 0.53356), Vector2(500.0, 0.31930), Vector2(1000.0, 0.18203),
		Vector2(1500.0, 0.10570), Vector2(1750.0, 0.08507), Vector2(3000.0, 0.03454)]  # uu/s -> rad
const UU_PER_SPEED := 100.0  # our m/s -> RL uu/s (1 uu = 1 cm)
## RL's turning curvature by forward speed (uu/s -> 1/uu), measured in-game
## (RLBot wiki, RLUtilities); matches RocketSim's steady turns.
const RL_TURN_CURVATURE := [Vector2(0.0, 0.0069), Vector2(500.0, 0.00398), Vector2(1000.0, 0.00235),
		Vector2(1500.0, 0.001375), Vector2(1750.0, 0.0011), Vector2(2300.0, 0.00088)]
## RL's handbrake value rises and falls at these rates (RocketSim
## POWERSLIDE_RISE_RATE / FALL_RATE): grip and turning blend in, not snap.
const RL_HANDBRAKE_RISE_RATE := 5.0
const RL_HANDBRAKE_FALL_RATE := 2.0
const GROUND_STEER_RESPONSE := 20.0
## A contact counts as a surface under the fish when its normal is within ~45° of the fish's up.
const SURFACE_MIN_DOT := 0.5  # about 60 degrees: a ramp's contacts still count as the surface
## After a jump, surfaces are ignored this long so the fish leaves cleanly.
const SURFACE_JUMP_GRACE := 0.1
# Rocket League's auto-flip (RocketSim RLConst.h, Car::_UpdateAutoFlip): jump
# while lying on your roof gives a small hop off the surface plus a strong roll
# back onto your wheels, for up to 0.4 s scaled by how far over you are. Only
# when nearly upside down (rolled over 2.8 rad).
const RL_AUTOFLIP_IMPULSE := 2.0
const RL_AUTOFLIP_TORQUE := 50.0
const RL_AUTOFLIP_TIME := 0.4
## RL's auto-roll (see rl_auto_roll): the pull onto the surface (100 uu/s²)
## and the most it turns the car flush (rad/s²).
const RL_AUTOROLL_FORCE := 1.0
const RL_AUTOROLL_TORQUE := 80.0
const RL_AUTOFLIP_ROLL_THRESH := 2.8
# Rocket League dodge push scaling (RocketSim RLConst.h, Car::_UpdateDoubleJumpOrFlip).
const RL_CAR_MAX_SPEED := 23.0  # 2300 uu/s, what "forward speed ratio" is relative to
const RL_DODGE_SIDE_MAX_SPEED_SCALE := 1.9
const RL_DODGE_BACKWARD_MAX_SPEED_SCALE := 2.5
const RL_DODGE_BACKWARD_SCALE := 16.0 / 15.0
## Below this forward speed (100 uu/s) a dodge counts as backwards by stick alone.
const RL_DODGE_BACKWARDS_MIN_SPEED := 1.0
## RocketSim's suspension (RLConst::BTVehicle): each wheel's spring moves 12
## uu either side of its rest length (the CarConfig one less those 12 uu), its
## ray reaches that far plus the wheel's radius less 2.5 uu, and it pushes with
## SUSPENSION_STIFFNESS 500 per BT unit of compression, damped 25 compressing
## and 40 extending, all times a force scale per axle, against the 180-unit
## chassis. In our units that's a per-wheel acceleration (m/s²) of
## (500 compression - damping speed) * scale / 180, compression in m.
const RL_SUSPENSION_TRAVEL := 0.12
const RL_SUSPENSION_SUBTRACTION := 0.025
const RL_SUSPENSION_STIFFNESS := 500.0
const RL_SUSPENSION_DAMPING_COMPRESS := 25.0
const RL_SUSPENSION_DAMPING_EXTEND := 40.0
const RL_SUSPENSION_FORCE_SCALE_FRONT := 36.0 - 1.0 / 4.0
const RL_SUSPENSION_FORCE_SCALE_BACK := 54.0 + 1.0 / 4.0 + 1.5 / 100.0
const RL_CAR_MASS_BT := 180.0
## A wheel pressed further than this past its rest length (2.5 uu) also gets
## a solid-contact push back out, a quarter of what would stop and unsink its
## contact point (Bullet resolveSingleCollision, ERP 0.2), as RocketSim's do.
const RL_SUSPENSION_PUSHBACK_ERP := 0.2
## RL's tyres (RocketSim btVehicleRL::calcFrictionImpulses): each tick a wheel
## pushes sideways with a fifth of the impulse that would stop its contact
## point sliding (Bullet's resolveSingleBilateral), scaled by the chassis mass
## over 3 (RocketSim's units: 180 / 3) times the tick.
const RL_TYRE_CONTACT_DAMPING := 0.2
const RL_TYRE_FRICTION_SCALE := 60.0
## Braking per wheel ramps with the contact point's forward speed at this rate
## (1/s) up to the brake's limit (RocketSim ROLLING_FRICTION_SCALE_MAGIC / 3).
const RL_ROLLING_FRICTION_SLOPE := 113.73963 / 3.0
## Coasting slower than this (25 uu/s) brakes fully (RL STOPPING_FORWARD_VEL).
const RL_STOPPING_FORWARD_VEL := 0.25
## A wheel's slip only counts above this sideways speed at its mount (5 uu/s).
const RL_FRICTION_SLIP_MIN := 0.05
## Front wheel angle at full lock while powersliding (rad, by speed in uu/s).
const RL_POWERSLIDE_STEER_ANGLE_CURVE := [Vector2(0.0, 0.39235), Vector2(2500.0, 0.12610)]
## How much the hitbox's lower front and rear edges are bevelled for hitting
## the arena (up, along): see _apply_hitbox. RL's (Bullet's) box has its edges
## rounded by 2 cm. Square, a low car's nose digs into the back walls' ramp
## facets and Jolt stops it dead (RocketSim parity: the Breakout up the back wall).
const HULL_BEVEL := Vector2(0.02, 0.02)
## A contact counts as on the roof when its normal is this far against the fish's up
## (lying upside down or over on its upper flank).
const ROOF_CONTACT_DOT := -0.1
## An uncompleted flip counts as over once its spin has wound down below this (rad/s).
const FLIP_SPIN_OUT_MIN_RATE := 0.2
## Tolerance for comparing summed tick times to RL durations (78 ticks of 1/120 s
## add up to a hair over 0.65 in floating point).
const TIME_EPSILON := 0.0001

@export_group("Thrust")
## RL: air throttle, 66.7 uu/s^2.
@export_range(0.0, 60.0, 0.01) var forward_accel := 0.67
@export_range(0.0, 60.0, 0.01) var reverse_accel := 0.67
## Deceleration when holding reverse while still swimming forward.
@export_range(0.0, 120.0, 0.01) var brake_accel := 0.67
## Keep below max_boost_speed so boosting raises top speed. Throttle alone can
## never pass forward_accel / linear_drag (drag balances thrust there).
@export_range(0.0, 60.0, 0.5) var max_speed := 23.0
@export_range(0.0, 30.0, 0.5) var max_reverse_speed := 23.0

@export_group("Boost")
## Off: the boost button does nothing (and the gauge hides), e.g. in Nature.
@export var boost_enabled := true
## The boost button holds the direction lock instead (e.g. in Nature, where
## there's no boost). The lock's own key still works.
@export var boost_button_locks := false
## RL: 1058.3 uu/s^2 in the air.
@export_range(0.0, 60.0, 0.01) var boost_accel := 10.58
## Absolute speed cap, also applied to jumps and dodges. RL: 2300 uu/s.
@export_range(0.0, 120.0, 0.5) var max_boost_speed := 23.0
@export var boost_unlimited := false
## Percent of the tank used per second (Rocket League: 33.3).
@export_range(0.0, 100.0, 0.01) var boost_drain := 33.33
## RL has none (boost comes from pads, which this game doesn't have yet), so a
## slow refill stands in for them.
@export_range(0.0, 100.0, 0.5) var boost_regen := 10.0

@export_group("Water")
## Fraction of speed lost per second.
@export_range(0.0, 3.0, 0.01) var linear_drag := 0.0
## Momentum above max_speed (from dodges, swim strokes or boost) fades at this
## rate while you keep swimming (throttle, boost or a stroke rhythm), like
## holding throttle above top speed in Rocket League. Applies to the extra speed
## only: 0.5 halves it in about 1.4 s. Coasting uses linear_drag as normal.
@export_range(0.0, 3.0, 0.01) var overspeed_drag := 0.0
## Extra drag on sideways/vertical slip. 0 = free drift, high = carves like it's on rails.
@export_range(0.0, 10.0, 0.05) var lateral_drag := 0.0
@export_range(0.0, 5.0, 0.05) var angular_drag := 0.0
## Upward acceleration. 0 = neutral buoyancy, negative sinks. RL: gravity, -650 uu/s^2.
@export_range(-30.0, 10.0, 0.01) var buoyancy := -6.5
## RL (RocketSim): car-world restitution 0.3, friction 0.3.
@export_range(0.0, 1.0, 0.05) var wall_bounce := 0.3:
	set(value):
		wall_bounce = value
		_apply_physics_material()
@export_range(0.0, 1.0, 0.05) var wall_friction := 0.3:
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
@export var swim_style := SwimStyle.ORIGINAL
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

@export_group("Extra Swishy")
## Sweeps only stride while swimming forward (throttle held). Without
## throttle, the stick just steers, directly. Off = sweeps always stride.
@export var stride_needs_throttle := true
## How far the stick must reach for a sweep to count as a stride.
@export_range(0.1, 1.0, 0.05) var stride_threshold := 0.5
## How opposite the next sweep must be (cosine): 0.5 = within 60° of straight back.
@export_range(0.0, 1.0, 0.05) var stride_reversal := 0.5
## Push at a stride's peak (m/s²), before flow and timing.
@export_range(0.0, 150.0, 0.5) var stride_force := 40.0
## Time from a stride's start to its peak: alternate here for full timing.
@export_range(0.05, 1.5, 0.01) var stride_peak_time := 0.35
## Time from the peak until the stride has faded to nothing.
@export_range(0.05, 2.0, 0.01) var stride_fade_time := 0.6
## A stride with nothing before it (or after a mistimed one) pushes this much.
@export_range(0.0, 1.0, 0.05) var stride_fresh := 0.6
## How far off straight ahead each stride pushes, away from the sweep (degrees).
@export_range(0.0, 45.0, 0.5) var stride_side_angle := 12.0
## Strides fade out approaching this forward speed.
@export_range(1.0, 120.0, 0.5) var stride_max_speed := 45.0
## Flow gained by a perfectly timed stride (lost by one timed at zero).
@export_range(0.0, 2.0, 0.01) var stride_flow_gain := 0.3
## Most flow: strides push up to 1 + this times as hard.
@export_range(0.0, 6.0, 0.1) var stride_flow_max := 2.0
## Flow lost per second while no stride is pushing.
@export_range(0.0, 10.0, 0.1) var stride_flow_decay := 1.5
## Off a surface, the stick steers through a smoothing of this long (s), so
## alternating sweeps mostly cancel out while a held direction still turns.
## 0 = the stick steers directly, sweeps and all.
@export_range(0.0, 1.0, 0.01) var stride_steer_smoothing := 0.35
## How far the tail swings to each side on a stride (rad). A stride sweeps it
## across, away from the push, arriving at the far side at the peak.
@export_range(0.0, 1.5, 0.01) var stride_tail_swing := 0.6
## How much bigger the tail grows with flow: at full flow it's 1 + this times
## its size (Battletoads style), and each stride swells it a little more.
@export_range(0.0, 3.0, 0.05) var stride_tail_growth := 0.8
## While a stride pushes, the tail pours a stream of tiny bubbles
## (StrideStream), like a boost trail: denser and brighter as the stride builds
## and with flow, coloured by its timing. It stops once out of stride.
@export var stride_bubbles := true

@export_group("Bow Wave")
## Speed pushes a torpedo-tip shell of water out ahead of the fish, from
## bow_start_speed to full size at bow_full_speed. It counts as the fish's front
## for demolitions (Demolition), and for nothing else: it doesn't push anything.
@export var bow_wave := false
@export_range(0.0, 60.0, 0.5) var bow_start_speed := 8.0
@export_range(1.0, 80.0, 0.5) var bow_full_speed := 30.0
## How far its tip reaches ahead of the hitbox's front at full size (m).
@export_range(0.0, 5.0, 0.05) var bow_length := 1.0
## How wide it is at full size, as a multiple of the hitbox's width. It's
## rounder than the hitbox: at least 0.7 times as tall as it is wide.
@export_range(1.0, 4.0, 0.05) var bow_girth := 1.8

@export_group("Nature")
## The slowest ram that demolishes Nature's target fish (m/s). RL's supersonic: 22.
@export_range(5.0, 60.0, 0.5) var nature_demo_speed := 22.0

@export_group("Jump & Dodge")
## Instant push along the fish's up axis on pressing jump. A double jump is this alone.
## RL: 291.7 uu/s.
@export_range(0.0, 40.0, 0.001) var jump_impulse := 2.917
## Holding jump pushes higher, as in Rocket League: the first jump keeps
## accelerating while held, up to jump_hold_time. Off = every jump is a tap.
@export var variable_jump := true
## Push while held. RL's full hold adds as much again as the instant push
## (jump_impulse / jump_hold_time), so a full hold is twice a tap.
## RL: 1458.3 uu/s^2.
@export_range(0.0, 150.0, 0.01) var jump_hold_accel := 14.58
## Longest the hold keeps pushing. RL: 0.2 s.
@export_range(0.05, 1.0, 0.01) var jump_hold_time := 0.2
## RL: 500 uu/s.
@export_range(0.0, 60.0, 0.1) var dodge_impulse := 5.0
## Time after the first jump (after its hold ends) during which a second press double-jumps or dodges. RL: 1.25 s.
@export_range(0.0, 3.0, 0.05) var double_jump_window := 1.25
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
## Sideways grip at full handbrake (per second; ground_grip is the normal grip):
## low = the fish keeps sliding the old way while it turns. On RL's tyres
## (rl_tyres) a surface powerslide is the tyres' own, so this applies in water.
@export_range(0.0, 10.0, 0.05) var powerslide_lateral_drag := 1.0
## Extra turning at full handbrake (on a surface by the whole sliding speed;
## in water it scales pitch/yaw torque and the spin cap). Not on a surface
## with rl_tyres, where the front wheels turn further instead, as in RL.
@export_range(1.0, 4.0, 0.05) var powerslide_turn_multiplier := 1.5
## Forward thrust kept while powersliding (1 = full thrust).
@export_range(0.0, 1.0, 0.05) var powerslide_thrust_scale := 1.0  # RL: the handbrake never cuts throttle

@export_group("Surface")
## While the fish's underside touches a surface (floor, walls, ceiling, the
## ball), drive like a Rocket League car: ground throttle, steering, grip and
## sticky force, sitting flat on the surface. Off = swim everywhere.
## Defaults are RocketSim's values (1 uu = 1 cm).
@export var rl_surface_mechanics := true
## Top driving speed. RL: 1410 uu/s.
@export_range(5.0, 80.0, 0.1) var ground_max_speed := 14.1
## Throttle acceleration from a standstill, fading to nothing at
## ground_max_speed on RL's curve. RL: 1600 uu/s².
@export_range(0.0, 100.0, 0.5) var ground_accel := 16.0
## Throttle against the direction of travel. RL: 3500 uu/s².
@export_range(0.0, 150.0, 0.5) var ground_brake := 35.0
## Slowing with no throttle. RL: 525 uu/s².
@export_range(0.0, 50.0, 0.01) var ground_coast_decel := 5.25
## RL: 991.7 uu/s² on the ground.
@export_range(0.0, 80.0, 0.01) var ground_boost_accel := 9.92
## Top speed with boost. RL: 2300 uu/s.
@export_range(5.0, 120.0, 0.5) var ground_max_boost_speed := 23.0
## Tyre grip: how quickly sliding sideways is stopped (per second).
## Powersliding uses powerslide_lateral_drag instead.
@export_range(0.0, 60.0, 0.5) var ground_grip := 30.0  # fitted to RocketSim: slip and speed loss in turns
## Off the throttle on a steep surface, the most sideways push the tyres can
## give before they slide (m/s², at 45 degrees): a tenth of it on a wall,
## and no limit on the floor or with the throttle held. So a fish let go on a
## wall slides off it as RL's car does. Fitted to RocketSim.
@export_range(0.0, 100.0, 0.5) var ground_lateral_friction := 30.0
## Push into the surface, like RL's sticky force: half of this at rest, and
## while driving up to 1.5x on a wall. RL: its gravity, 650 uu/s².
@export_range(0.0, 40.0, 0.5) var surface_stick := 6.5
## How quickly the fish turns to sit flat on the surface it's on.
@export_range(1.0, 40.0, 0.5) var surface_align_rate := 15.0
## Ride on four sprung wheels as RL's car does (RocketSim's raycast wheels):
## the wheels decide when the fish is on a surface, and the springs tilt it
## onto ramps and soak up landings. Off = a rigid belly that snaps flat.
@export var rl_suspension := true
## How much of the cornering grip slows the car, via the steered front wheels'
## angle. Fitted to RocketSim's turns.
@export_range(0.0, 2.0, 0.01) var ground_turn_drag := 0.2
## Drive on RL's four tyres (RocketSim's btVehicleRL): throttle, brakes and
## grip act at each wheel and steering turns the front wheels, so the car
## turns, slides and swings round by those forces as RL's does. Off = grip on
## the whole body (ground_grip, ground_turn_drag, powerslide_lateral_drag) and
## turning-circle steering. Needs rl_suspension.
@export var rl_tyres := true
## Sideways tyre grip along the axle laid flat on the surface, as RocketSim
## does. Off = along the wheel's own axle, as RL's shipped code does (it skips
## the flattening; see private_content/rea/rl_physics_evidence.md §1.2), which
## differs only where the surface isn't level with the car: ramps and curves.
@export var tyre_axle_on_surface := true
## How far below the centre of mass the tyres' forces act (m), so they also
## pitch and roll the car. RL's code has this offset (a per-wheel value read
## from data, unknown); RocketSim and the default apply them level with it.
@export_range(-0.5, 0.5, 0.005) var tyre_force_drop := 0.0
## A wheel pressed past its rest length gets a solid push back out. On: as
## RocketSim and RL's code do it, that push is applied with the spring's (so
## not while the spring is slack) and is kept until the wheel next bottoms out
## or leaves the ground. Off: fresh each tick, only while bottomed out.
@export var rl_pushback_holds := false
## RL's auto-roll (RocketSim Car::_UpdateAutoRoll): on the throttle with only
## some wheels down, or the body touching the arena, the car is pulled onto
## the surface and turned to sit flush with it. It carries a car over a ramp's
## creases and onto a wall without its nose scraping. Needs rl_suspension.
@export var rl_auto_roll := true

@export_group("Hitbox")
## Which fish this is, one per Rocket League hitbox (FishCharacter): sets the
## hitbox, belly, centre of mass, wheels and model below to that car's. Picked
## in the tuning panel's Character row, not tuned like the rest.
var character := FishCharacter.Family.OCTANE:
	set(value):
		character = value
		_apply_character()
## A box, like Rocket League's car hitboxes: flat on the floor, flat on top to
## carry the ball. Set by the character (Octane: 120.5 x 86.7 x 38.7 uu, 1 uu =
## 1 cm). The fish's model is built to fill it.
var hitbox_length := 1.205:
	set(value):
		hitbox_length = value
		_apply_hitbox()
var hitbox_width := 0.867:
	set(value):
		hitbox_width = value
		_apply_hitbox()
var hitbox_height := 0.387:
	set(value):
		hitbox_height = value
		_apply_hitbox()
## A belly under the box, where a Rocket League car's wheels are, so the fish
## rides as high as a car does. Set by the character (Octane: the body sits
## 18.4 uu off the ground, and the wheels cover 112.5 x 70 uu). 0 height = no
## belly. Without rl_suspension it collides as two round "axles" (front and
## rear, at the car's wheel positions, as wide as the belly), so it rolls up a
## curving ramp the way wheels do instead of catching on it. Not drawn: it
## only shows as a see-through box with show_hitbox.
var belly_height := 0.184:
	set(value):
		belly_height = value
		_apply_hitbox()
var belly_length := 1.125:
	set(value):
		belly_length = value
		_apply_hitbox()
var belly_width := 0.70:
	set(value):
		belly_width = value
		_apply_hitbox()
## Draw the hitbox (and belly) as see-through boxes.
@export var show_hitbox := false:
	set(value):
		show_hitbox = value
		_apply_hitbox()
@export_group("Controller")
## Rocket League's controller settings, with the same meanings. Stick travel
## inside the deadzone counts as nothing; the rest is stretched back to 0..1.
@export_range(0.0, 0.5, 0.01) var controller_deadzone := 0.15
@export var deadzone_shape := DeadzoneShape.CIRCLE
## The stick is multiplied by this (each axis capped at full), so values above 1
## reach full lock before the stick does. RL: Steering Sensitivity, on a surface.
@export_range(0.1, 3.0, 0.01) var steering_sensitivity := 1.0
## The same in the air (pitch, yaw, and air roll from the stick). RL: Aerial Sensitivity.
@export_range(0.1, 3.0, 0.01) var aerial_sensitivity := 1.0

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

## Where this fish's input comes from instead of the player's controller, e.g.
## a bot's (FishBot); null for the player.
var controls: FishInput
## No input at all while set, e.g. during a kickoff countdown.
var controls_locked := false
## Boost after a reset (RL: 33.3 at a kickoff or a respawn in a match).
var spawn_boost := 100.0
## Tints the body in a team's colour; fully transparent for the character's own.
var team_color := Color.TRANSPARENT:
	set(value):
		team_color = value
		_apply_team_color()
## Out of play (see demolish()).
var demolished := false
## The team it plays for in a match (0 Blue, 1 Orange), or -1 outside one.
var team := -1
## Its name on the scoreboard and goal announcements.
var display_name := ""
var _saved_layers := Vector2i.ONE
var _idle_input := FishInput.new()  # what controls_locked reads

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
## Ticks left (in seconds) of wheel contact after jumping off a surface, and that surface's normal.
var _jump_wheel_contact_left := 0.0
## RL's handbrake value, 0..1 (see RL_HANDBRAKE_RISE_RATE).
var _handbrake := 0.0
## The suspension's push this tick (velocity and spin), and how many wheels touch.
var _suspension_push := Vector3.ZERO
var _suspension_twist := Vector3.ZERO
var wheels_touching := 0
var _tyre_push := Vector3.ZERO
var _tyre_twist := Vector3.ZERO
## What RL's Car::_UpdateWheels set last tick, which this tick's tyre forces
## use (RocketSim works out the forces first): front wheel angle (rad, + =
## right), engine and brake limit per wheel (m/s²), and each wheel's sideways
## and lengthways friction.
var _wheel_steer := 0.0
var _wheel_engine := 0.0
var _wheel_brake := 0.0
var _wheel_lat_friction := PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
var _wheel_long_friction := PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
## Each wheel's raycast hit this tick ({} when it touches nothing).
var _wheel_hits: Array[Dictionary] = [{}, {}, {}, {}]
## Each wheel's bottoming-out push (an impulse, kg·m/s; _update_suspension).
var _wheel_pushback := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _slide_sign := 1.0
var _jump_surface_normal := Vector3.UP
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
## Set by a dodge press; the flip torque waits until the next tick, as in RL.
var _flip_pressed_this_tick := false
## Velocity handed to the physics step, this tick and the one before (see velocity_for_last_step).
var _step_velocity := Vector3.ZERO
var _prev_step_velocity := Vector3.ZERO
var _step_frame := -1
## The ball's push on the fish this tick (Ball._resolve_fish_contact), applied
## at the start of the next _integrate_forces.
var _ball_push := Vector3.ZERO
var _ball_twist := Vector3.ZERO
var _reset_queued := false
var _surface_grace := 0.0
## Normal of a surface touching the fish's roof while it's nearly upside down (else zero).
var _roof_normal := Vector3.ZERO
## The normal of a contact between the body and the arena last step (else zero), for auto-roll.
var _world_contact_normal := Vector3.ZERO
## The sum of the touching wheels' surface normals this tick (_update_suspension).
var _wheel_normal_sum := Vector3.ZERO
## Lying on its upper side (roof or upper flank) against the arena: air control can't roll it over.
var _resting_on_roof := false
var _autoflip_left := 0.0
var _autoflip_dir := 1.0
var _spawn_transform: Transform3D
var _swim_phase := 0.0

var _stroke_clock := 0.0
var _stroke_side := Vector2i.ZERO  # last side each stick axis reached: -1, 0 or 1
var _stroke_axis := -1  # axis the current rhythm is on (0 = side to side, 1 = up and down)
var _last_stroke_time := -INF
var _last_stroke_interval := 0.0
var _queued_stroke := 0.0
## How big the bow wave is now, 0..1 (see bow_wave).
var bow_amount := 0.0
var _bow_view := MeshInstance3D.new()
var _bow_material := ShaderMaterial.new()
var _bow_flow := 0.0  # how far its ripples have streamed back
var _stream := StrideStream.new()
## Extra Swishy's strides (swim_style), read by the HUD's stride meter.
var swishy := SwishySwim.new(self)

## The character's model (built in _apply_character) and the parts the swim
## animation moves.
var _visual: FishModel
var _tail: Node3D
var _fin_left: Node3D
var _fin_right: Node3D
## The character's wheels (FishCharacter.wheels): front left, front right, back
## left, back right.
var _wheels: Array[Dictionary] = FishCharacter.wheels(FishCharacter.Family.OCTANE)
@onready var _bubbles: CPUParticles3D = $Bubbles
@onready var _collision: CollisionShape3D = $Collision
var _hitbox_view := MeshInstance3D.new()
var _world_hull := CollisionShape3D.new()
var _wheel_collisions: Array[CollisionShape3D] = [CollisionShape3D.new(), CollisionShape3D.new()]
var _belly_hitbox_view := MeshInstance3D.new()


func _ready() -> void:
	add_to_group(GROUP)
	_spawn_transform = global_transform
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM  # the character's car's (_apply_character)
	physics_material_override = PhysicsMaterial.new()
	_apply_physics_material()
	_collision.shape = _collision.shape.duplicate()  # sized per fish
	# The arena meets a bevelled copy of the hitbox (see _apply_hitbox); the box
	# itself stays the hitbox the ball is checked against (Ball._fish_contact).
	_collision.disabled = true
	_world_hull.name = "WorldHull"
	_world_hull.shape = ConvexPolygonShape3D.new()
	add_child(_world_hull)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 1.0, 0.5, 0.25)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_hitbox_view.mesh = BoxMesh.new()
	_hitbox_view.material_override = material
	_hitbox_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hitbox_view)
	_build_bow_view()
	_stream.name = "StrideStream"
	add_child(_stream)

	for i in _wheel_collisions.size():
		_wheel_collisions[i].name = ["FrontWheels", "RearWheels"][i]
		_wheel_collisions[i].shape = CylinderShape3D.new()
		_wheel_collisions[i].rotation = Vector3(0.0, 0.0, PI / 2.0)  # the cylinder's axis across the fish
		add_child(_wheel_collisions[i])
	_belly_hitbox_view.mesh = BoxMesh.new()
	_belly_hitbox_view.material_override = material
	_belly_hitbox_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_belly_hitbox_view)
	_apply_character()


## Become `character`: its car's hitbox, belly, centre of mass (rotations pivot
## about it, as in RL) and wheels, and its fish model.
func _apply_character() -> void:
	if _collision == null:  # set before _ready; applied there
		return
	center_of_mass = FishCharacter.com_from_hitbox(character)
	_wheels = FishCharacter.wheels(character)
	if _visual:
		remove_child(_visual)
		_visual.queue_free()
	_visual = FishModel.build(character)
	add_child(_visual)
	_tail = _visual.tail
	_fin_left = _visual.fin_left
	_fin_right = _visual.fin_right
	_apply_team_color()
	# Each setter re-applies the hitbox; the last one sees all of them.
	var size := FishCharacter.hitbox_size(character)
	var belly := FishCharacter.belly(character)
	hitbox_width = size.x
	hitbox_height = size.y
	hitbox_length = size.z
	belly_width = belly.x
	belly_height = belly.y
	belly_length = belly.z


## The body's colour as shown: its team's, or the character's own.
func body_color() -> Color:
	return _visual.body_color() if _visual else team_color


func _apply_team_color() -> void:
	if _visual == null:
		return
	if team_color.a > 0.0:
		_visual.set_body_color(team_color)
	else:
		_visual.reset_body_color()


func _apply_hitbox() -> void:
	if _visual == null:  # set before _ready; applied there
		return
	var size := Vector3(hitbox_width, hitbox_height, hitbox_length)
	# Spin inertia of the hitbox as a solid box, as RL's car (RocketSim sizes its
	# hitboxes to reproduce the game's inertia), whatever else the fish carries.
	inertia = Vector3(size.y * size.y + size.z * size.z, size.x * size.x + size.z * size.z,
			size.x * size.x + size.y * size.y) * mass / 12.0
	(_collision.shape as BoxShape3D).size = size
	# The hitbox with its lower front and rear edges bevelled, for meeting the
	# arena: driving onto a wall the suspension tips the fish up, and a square
	# corner would snag on the curve (Jolt's contacts are harder than the Bullet
	# ones RL uses, where the car rides through it).
	var half := size / 2.0
	var bevel := Vector2(minf(HULL_BEVEL.x, half.y), minf(HULL_BEVEL.y, half.z))
	var hull := PackedVector3Array()
	for x: float in [-half.x, half.x]:
		for z: float in [-half.z, half.z]:
			hull.append(Vector3(x, half.y, z))  # top corners
			hull.append(Vector3(x, -half.y + bevel.x, z))  # end faces stop short of the bottom
			hull.append(Vector3(x, -half.y, z - signf(z) * bevel.y))  # bottom stops short of the ends
	(_world_hull.shape as ConvexPolygonShape3D).points = hull
	(_hitbox_view.mesh as BoxMesh).size = size
	_hitbox_view.visible = show_hitbox

	var belly := Vector3(belly_width, belly_height, belly_length)
	var belly_centre := Vector3(0.0, -(hitbox_height + belly_height) / 2.0, 0.0)
	var has_belly := belly_height > 0.0
	var wheel_radius := belly_height / 2.0
	var axle_offsets := FishCharacter.axles(character)
	var axles := [center_of_mass.z - axle_offsets.x, center_of_mass.z + axle_offsets.y]
	for i in _wheel_collisions.size():
		_wheel_collisions[i].disabled = not has_belly or rl_suspension
		if has_belly:
			var cylinder := _wheel_collisions[i].shape as CylinderShape3D
			cylinder.radius = wheel_radius
			cylinder.height = belly_width
		_wheel_collisions[i].position = Vector3(0.0, -hitbox_height / 2.0 - wheel_radius, axles[i])
	(_belly_hitbox_view.mesh as BoxMesh).size = belly
	_belly_hitbox_view.position = belly_centre
	_belly_hitbox_view.visible = show_hitbox and has_belly

	_visual.scale = size / FishCharacter.hitbox_size(character)  # 1 unless the hitbox was changed by hand
	_bubbles.position.z = size.z * 0.6  # just behind the tail


## The velocity the fish moved with during the physics step that just ran. For
## contact maths in another body's _integrate_forces, which can run before or
## after this one's in the same tick.
func velocity_for_last_step() -> Vector3:
	return _prev_step_velocity if _step_frame == Engine.get_physics_frames() else _step_velocity


## The fish's live physics state. Inside another body's _integrate_forces the
## node's transform and velocities can still be last tick's: Jolt syncs each
## node right after its own callback, so it depends which body went first.
func physics_state() -> PhysicsDirectBodyState3D:
	return PhysicsServer3D.body_get_direct_state(get_rid())


## The ball's half of a contact (Ball._resolve_fish_contact): `impulse` at
## world point `at`, moving and turning the fish by its mass and inertia.
func apply_ball_impulse(impulse: Vector3, at: Vector3) -> void:
	var xform := physics_state().transform
	_ball_push += impulse / mass
	_ball_twist += inverse_inertia_world(xform.basis) * (at - xform * center_of_mass).cross(impulse)


## The fish's inverse inertia tensor in world axes (for the fish turned to `basis`).
func inverse_inertia_world(basis := global_basis) -> Basis:
	var b := basis.orthonormalized()
	return b * Basis.from_scale(Vector3.ONE / inertia) * b.transposed()


func request_reset() -> void:
	_reset_queued = true


## True from a dodge until its flip is fully over, including a cancelled flip's
## wind-down (unlike is_dodging, which a cancel clears straight away) and an
## uncompleted flip that's still turning round on its own.
func is_flipping() -> bool:
	return is_dodging or _flip_time >= 0.0 or _flip_spin_out


## Whether a setting does anything with the current toggles; the tuning panel hides the rest.
func is_option_active(property: String) -> bool:
	if property.begins_with("bow_") and property != "bow_wave":
		return bow_wave
	if property.begins_with("stride_"):
		return swim_strokes and swim_style == SwimStyle.EXTRA_SWISHY
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
				"ground_max_boost_speed", "surface_stick", "rl_suspension":
			return rl_surface_mechanics
		"ground_grip", "ground_turn_drag", "ground_lateral_friction":  # the tyres grip instead
			return rl_surface_mechanics and not _uses_tyres()
		"surface_align_rate":  # the suspension sits the fish on the surface instead
			return rl_surface_mechanics and not rl_suspension
		"rl_tyres":
			return rl_surface_mechanics and rl_suspension
		"tyre_axle_on_surface", "tyre_force_drop":
			return _uses_tyres()
		"rl_pushback_holds", "rl_auto_roll":
			return rl_surface_mechanics and rl_suspension
		"boost_unlimited", "boost_accel":
			return boost_enabled
		"boost_drain", "boost_regen":
			return boost_enabled and not boost_unlimited
		"swim_style", "strokes_need_lock":
			return swim_strokes
		"stroke_impulse", "stroke_max_speed", "stroke_threshold", \
				"stroke_min_interval", "stroke_max_interval", "rhythm_tolerance":
			return swim_strokes and swim_style == SwimStyle.ORIGINAL
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
	if controls_locked:
		_read_controls(_idle_input)
	elif controls:
		_read_controls(controls)
	else:
		input_forward = Input.get_action_strength("thrust_forward")
		input_reverse = Input.get_action_strength("thrust_reverse")
		input_stick = _processed_stick()
		input_roll = Input.get_action_strength("roll_right") - Input.get_action_strength("roll_left")
		air_roll_held = Input.is_action_pressed("air_roll")
		boost_held = Input.is_action_pressed("boost")
		powerslide_held = Input.is_action_pressed("powerslide")
		var boost_locks := boost_button_locks and Input.is_action_pressed("boost")
		direction_lock_held = Input.is_action_pressed("direction_lock") or boost_locks
		jump_held = Input.is_action_pressed("jump")
	# Detect the press ourselves: "just pressed" is tracked per frame and isn't
	# reliable this early in the physics tick.
	if jump_held and not _jump_was_held:
		_jump_queued = true
	_jump_was_held = jump_held
	_detect_strokes(delta)


func _read_controls(source: FishInput) -> void:
	input_forward = source.forward
	input_reverse = source.reverse
	input_stick = source.stick.clamp(-Vector2.ONE, Vector2.ONE)
	input_roll = source.roll
	air_roll_held = source.air_roll
	boost_held = source.boost
	powerslide_held = source.powerslide
	direction_lock_held = source.direction_lock
	jump_held = source.jump


## Out of play after a demolition: hidden, frozen where it was and touching
## nothing (not the ball, not other fish) until revive().
func demolish() -> void:
	demolished = true
	visible = false
	_saved_layers = Vector2i(collision_layer, collision_mask)
	collision_layer = 0
	collision_mask = 0
	set_deferred("freeze", true)


## Back in play after demolish(), at `spawn`.
func revive(spawn: Transform3D) -> void:
	if demolished:
		collision_layer = _saved_layers.x
		collision_mask = _saved_layers.y
	demolished = false
	visible = true
	freeze = false
	set_spawn(spawn)


## A sudden change of velocity (m/s), e.g. a goal explosion's blast, applied at
## the start of the next physics step.
func apply_push(velocity_change: Vector3) -> void:
	_ball_push += velocity_change


## The left stick after Rocket League's deadzone and sensitivity settings. Read
## raw (the input map's own stick deadzone is bypassed) so the deadzone and
## its shape are exactly the ones set here.
func _processed_stick() -> Vector2:
	var raw := Vector2(
			Input.get_action_raw_strength("stick_right") - Input.get_action_raw_strength("stick_left"),
			Input.get_action_raw_strength("stick_down") - Input.get_action_raw_strength("stick_up"))
	var stick := Vector2.ZERO
	var keep := maxf(1.0 - controller_deadzone, 0.001)
	if deadzone_shape == DeadzoneShape.CROSS:
		for axis in 2:
			stick[axis] = signf(raw[axis]) * clampf((absf(raw[axis]) - controller_deadzone) / keep, 0.0, 1.0)
	else:
		var length := minf(raw.length(), 1.0)
		if length > controller_deadzone:
			stick = raw.normalized() * clampf((length - controller_deadzone) / keep, 0.0, 1.0)
	var sensitivity := steering_sensitivity if on_surface else aerial_sensitivity
	return (stick * sensitivity).clamp(-Vector2.ONE, Vector2.ONE)


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
		swishy.reset()
		return
	if swim_style == SwimStyle.EXTRA_SWISHY:
		swishy.sample(input_stick, delta)
		stroke_chain = swishy.strides
		stroke_quality = maxf(swishy.last_timing, 0.0)
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
	# Rocket League caps speed and spin after each physics step (RocketSim
	# Car::_PostTickUpdate), so a step itself runs at the capped value plus that
	# tick's acceleration: a flip turns at ~7.4 rad/s although 5.5 is "the cap".
	# Capping the last step's result here, before anything reads it, does the same.
	var spin_cap := RL_MAX_ANGULAR_SPEED if rl_roll_timing else max_angular_speed * (powerslide_turn_multiplier if is_powersliding else 1.0)
	# The ball's contact push belongs to the step that just ran, before the caps.
	state.linear_velocity += _ball_push
	state.angular_velocity += _ball_twist
	_ball_push = Vector3.ZERO
	_ball_twist = Vector3.ZERO
	state.linear_velocity = state.linear_velocity.limit_length(max_boost_speed)
	state.angular_velocity = state.angular_velocity.limit_length(spin_cap)
	physics_tick.emit(state)
	var dt := state.step
	_sample_input(dt)
	if _reset_queued:
		_apply_reset(state)
		return

	var body_basis := state.transform.basis.orthonormalized()
	var forward := -body_basis.z
	var velocity := state.linear_velocity
	is_powersliding = powerslide_held and not is_dodging
	_handbrake = move_toward(_handbrake, 1.0 if powerslide_held else 0.0,
			(RL_HANDBRAKE_RISE_RATE if powerslide_held else RL_HANDBRAKE_FALL_RATE) * state.step)

	# Direction lock: the nose stays pointed where it faced when the lock was
	# pressed (no turning left/right/up/down), while roll stays free.
	if direction_lock_held and not _was_locked:
		_lock_direction = forward
	_was_locked = direction_lock_held
	_lock_local = body_basis.transposed() * _lock_direction

	var start_velocity := velocity
	var start_spin := state.angular_velocity
	_detect_surface(state, body_basis, dt)
	velocity += _suspension_push + _tyre_push
	state.angular_velocity += _suspension_twist + _tyre_twist
	# Before this tick's gravity and thrust, as RL damps the velocity the step starts with.
	velocity = _apply_flip_z_damp(velocity, dt)
	if on_surface:
		velocity = _apply_ground(velocity, body_basis, dt)
	else:
		velocity = _apply_thrust(velocity, forward, dt)
		if swim_style == SwimStyle.EXTRA_SWISHY:
			velocity = swishy.apply(velocity, body_basis, dt)
		else:
			velocity = _apply_strokes(velocity, forward)
		velocity = _apply_water(velocity, forward, dt)
	if _uses_tyres():
		_update_tyre_settings(start_velocity, start_spin, state, body_basis)
	velocity = _start_autoflip(velocity, body_basis)
	velocity = _apply_jump(velocity, body_basis, state.get_contact_count() > 0, dt)
	if rl_auto_roll and rl_suspension and rl_surface_mechanics:
		var roll := _auto_roll(body_basis, dt)
		velocity += roll[0]
		state.angular_velocity += roll[1]

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
	elif _resting_on_roof and _flip_time < 0.0 and not _flip_pressed_this_tick:
		pass  # on its roof, as in RL: air roll can't right it, only the auto-flip jump
	else:
		local_spin = _apply_rotation(local_spin, dt)
	if _autoflip_left > 0.0:
		_autoflip_left -= dt
		# Roll about the nose (local -Z); capped like all spin at the next tick's start.
		local_spin.z -= _autoflip_dir * RL_AUTOFLIP_TORQUE * dt

	state.linear_velocity = velocity
	state.angular_velocity = body_basis * local_spin
	_prev_step_velocity = _step_velocity
	_step_velocity = velocity
	_step_frame = Engine.get_physics_frames()

	speed = velocity.length()
	forward_speed = velocity.dot(forward)
	drift_angle = rad_to_deg(forward.angle_to(velocity)) if speed > 0.5 else 0.0
	angular_speed = local_spin.length()
	var bow_target := 0.0
	if bow_wave:
		bow_target = clampf((speed - bow_start_speed) / maxf(bow_full_speed - bow_start_speed, 0.1), 0.0, 1.0)
	bow_amount = move_toward(bow_amount, bow_target, BOW_RESPONSE * dt)


## RL's auto-roll (RocketSim Car::_UpdateAutoRoll), while on the throttle with
## one to three wheels down or the body touching the arena: a pull towards the
## surface (the wheels' average normal, else the body's contact) and a turn
## about the nose and the axle, by how far the car is from sitting flush.
## Returns [velocity change, spin change] (world axes).
func _auto_roll(body_basis: Basis, dt: float) -> Array:
	var throttle := 1.0 if is_boosting else input_forward - input_reverse
	var some_wheels := wheels_touching > 0 and wheels_touching < 4
	if throttle == 0.0 or not (some_wheels or _world_contact_normal != Vector3.ZERO):
		return [Vector3.ZERO, Vector3.ZERO]
	var ground_up := _wheel_normal_sum.normalized() if wheels_touching > 0 else _world_contact_normal
	var forward := -body_basis.z
	# RocketSim's "right" axis is up x forward, which in our axes points left.
	var left := -body_basis.x
	var cross_left := ground_up.cross(forward)  # the car's left, were it flush
	var cross_forward := -ground_up.cross(cross_left)  # and its forward
	var roll_factor := 1.0 - clampf(left.dot(cross_left), 0.0, 1.0)
	var pitch_factor := 1.0 - clampf(forward.dot(cross_forward), 0.0, 1.0)
	var roll := forward * (-1.0 if left.dot(ground_up) >= 0.0 else 1.0) * roll_factor
	var pitch := left * (1.0 if forward.dot(ground_up) >= 0.0 else -1.0) * pitch_factor
	return [-ground_up * RL_AUTOROLL_FORCE * dt, (roll + pitch) * RL_AUTOROLL_TORQUE * dt]


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


## Jump while lying on your roof: RL's auto-flip instead of a jump.
func _start_autoflip(velocity: Vector3, body_basis: Basis) -> Vector3:
	if not _jump_queued or _roof_normal == Vector3.ZERO or _autoflip_left > 0.0:
		return velocity
	_jump_queued = false
	var forward := -body_basis.z
	var over := body_basis.y.angle_to(_roof_normal)
	_autoflip_left = RL_AUTOFLIP_TIME * over / PI
	# Roll whichever way brings the fish's up round to the surface normal soonest.
	var side := body_basis.y.cross(_roof_normal).dot(forward)
	_autoflip_dir = 1.0 if side >= 0.0 else -1.0
	return velocity - body_basis.y * RL_AUTOFLIP_IMPULSE  # up points into the surface: hop off it


func _update_boost(dt: float) -> void:
	if not boost_enabled:
		is_boosting = false
		return
	is_boosting = boost_held and (boost_unlimited or boost_amount > 0.0)
	if boost_unlimited:
		return
	if is_boosting:
		boost_amount = maxf(boost_amount - boost_drain * dt, 0.0)
	else:
		boost_amount = minf(boost_amount + boost_regen * dt, 100.0)


## On a surface when a contact under the fish (normal within ~45° of its up)
## touches anything: floor, wall, ceiling, the ball. Not just after a jump, nor
## mid-flip unless three wheels touch down (which ends the flip, as in RL).
func _detect_surface(state: PhysicsDirectBodyState3D, body_basis: Basis, dt: float) -> void:
	_surface_grace -= dt
	var normal_sum := Vector3.ZERO
	_roof_normal = Vector3.ZERO
	_resting_on_roof = false
	_world_contact_normal = Vector3.ZERO
	for i in state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		if state.get_contact_collider_object(i) is StaticBody3D:
			_world_contact_normal = normal  # RocketSim keeps the last one too
		# Touching on its underside (belly or the hitbox's bottom) counts too,
		# however steep: RL's wheels follow a curving ramp, and the fish's flat
		# bottom meets it at its front edge.
		var local_point := body_basis.transposed() * (state.get_contact_local_position(i) - state.transform.origin)
		var underneath := local_point.y < -hitbox_height / 2.0 + 0.05
		if body_basis.y.angle_to(normal) > RL_AUTOFLIP_ROLL_THRESH:
			_roof_normal = normal
		elif normal.dot(body_basis.y) > SURFACE_MIN_DOT or (underneath and normal.dot(body_basis.y) > 0.0):
			normal_sum += normal
		# Not the ball: an air dribble keeps its air control.
		if normal.dot(body_basis.y) < ROOF_CONTACT_DOT and state.get_contact_collider_object(i) is StaticBody3D:
			_resting_on_roof = true
	_tyre_push = Vector3.ZERO
	_tyre_twist = Vector3.ZERO
	_wheel_normal_sum = Vector3.ZERO
	if rl_suspension and rl_surface_mechanics:
		normal_sum = _update_suspension(state, body_basis, dt)
		_wheel_normal_sum = normal_sum
	# A Rocket League flip ends the moment three wheels are down (RocketSim
	# Car::_PreTickUpdate), so a dodge just before landing keeps its push and
	# drives on: the wave dash. Short of that, a flip stays airborne.
	var flip_landed := _flip_time >= 0.0 and rl_suspension and wheels_touching >= 3
	if not rl_surface_mechanics or _surface_grace > 0.0 or ((_flip_time >= 0.0 or is_dodging) and not flip_landed):
		normal_sum = Vector3.ZERO
	if flip_landed and normal_sum != Vector3.ZERO:
		_flip_time = -1.0
		is_dodging = false
		_flip_spin_out = false
	var was_on_surface := on_surface
	on_surface = normal_sum != Vector3.ZERO
	if on_surface != was_on_surface:
		_apply_physics_material()
	if on_surface:
		surface_normal = normal_sum.normalized()
		_flip_spin_out = false


## RL's suspension, as RocketSim's btVehicleRL: each wheel casts a ray down
## its suspension; where it meets a surface, the spring pushes along that
## surface's normal at the contact point (harder the more slanted the surface
## is to the suspension, up to 10x, so a wheel meeting a ramp tips the car onto
## it), damped, never pulling. A wheel pressed past its rest length also gets a
## solid push back out, so the hitbox never meets the floor. Every wheel works
## from the motion the tick started with. Sets _suspension_push/_twist,
## _wheel_hits and wheels_touching, adds the tyre forces, and returns the sum
## of the touched surfaces' normals (zero when no wheel touches).
func _update_suspension(state: PhysicsDirectBodyState3D, body_basis: Basis, dt: float) -> Vector3:
	_suspension_push = Vector3.ZERO
	_suspension_twist = Vector3.ZERO
	wheels_touching = 0
	var normal_sum := Vector3.ZERO
	var up := body_basis.y
	var com := state.transform.origin + body_basis * center_of_mass
	var inverse_inertia := state.inverse_inertia_tensor
	var space := state.get_space_state()
	for i in _wheels.size():
		var wheel: Dictionary = _wheels[i]
		_wheel_hits[i] = {}
		var rest: float = wheel.rest - RL_SUSPENSION_TRAVEL
		var radius: float = wheel.radius
		var mount: Vector3 = state.transform.origin + body_basis * wheel.mount
		var reach: float = rest + RL_SUSPENSION_TRAVEL + radius - RL_SUSPENSION_SUBTRACTION
		var query := PhysicsRayQueryParameters3D.create(mount, mount - up * reach, AquariumArena.WORLD_QUERY_MASK)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.collider is Ball:
			_wheel_pushback[i] = 0.0
			continue
		_wheel_hits[i] = hit
		wheels_touching += 1
		if _uses_tyres():
			_add_tyre_impulse(state, body_basis, i, hit, com, dt)
		var normal: Vector3 = hit.normal
		normal_sum += normal
		var contact: Vector3 = hit.position
		var trace := (mount - contact).dot(up)
		var length := clampf(trace - radius, rest - RL_SUSPENSION_TRAVEL, rest + RL_SUSPENSION_TRAVEL)
		var r := contact - com
		var contact_velocity := state.linear_velocity + state.angular_velocity.cross(r)
		var facing := normal.dot(up)
		var slant := 10.0
		var along := 0.0  # + = moving away from the surface
		if facing > 0.1:
			slant = 1.0 / facing
			along = normal.dot(contact_velocity) * slant
		var damping := RL_SUSPENSION_DAMPING_COMPRESS if along < 0.0 else RL_SUSPENSION_DAMPING_EXTEND
		var scale := RL_SUSPENSION_FORCE_SCALE_FRONT if i < 2 else RL_SUSPENSION_FORCE_SCALE_BACK
		var accel := maxf(((rest - length) * RL_SUSPENSION_STIFFNESS * slant - damping * along) * scale / RL_CAR_MASS_BT, 0.0)
		var impulse := normal * accel * mass * dt
		var pushback_at := rest + radius - RL_SUSPENSION_SUBTRACTION
		if trace < pushback_at and hit.collider is StaticBody3D:
			var effective := 1.0 / mass + normal.dot((inverse_inertia * r.cross(normal)).cross(r))
			var stop := RL_SUSPENSION_PUSHBACK_ERP * (pushback_at - trace) / dt - normal.dot(contact_velocity)
			_wheel_pushback[i] = maxf(stop / effective, 0.0) / _wheels.size()
		elif not rl_pushback_holds:
			_wheel_pushback[i] = 0.0
		if rl_pushback_holds:
			# As RocketSim's btVehicleRL (m_extraPushback) and RL's suspension
			# loop: the push is part of the spring's impulse, applied only while
			# the spring pushes, and it holds until the wheel next bottoms out or
			# leaves the ground.
			if accel > 0.0:
				impulse += normal * _wheel_pushback[i]
		else:
			impulse += normal * _wheel_pushback[i]
		_suspension_push += impulse / mass
		_suspension_twist += inverse_inertia * r.cross(impulse)
	return normal_sum


## Forget last tick's tyre settings, as a freshly spawned RL car starts.
func reset_tyres() -> void:
	_wheel_steer = 0.0
	_wheel_engine = 0.0
	_wheel_brake = 0.0
	_wheel_lat_friction.fill(1.0)
	_wheel_long_friction.fill(1.0)
	_wheel_pushback.fill(0.0)


func _uses_tyres() -> bool:
	return rl_tyres and rl_suspension and rl_surface_mechanics


## A wheel's directions (x across, -z along), turned by the steering on the
## front wheels (_wheels 0 and 1).
func _wheel_basis(body_basis: Basis, i: int) -> Basis:
	if i < 2 and _wheel_steer != 0.0:
		return body_basis.rotated(body_basis.y, -_wheel_steer)
	return body_basis


## One wheel's tyre force this tick (RocketSim btVehicleRL::calcFrictionImpulses
## and applyFrictionImpulses): sideways grip at the contact point, plus engine
## or brake along the wheel, each scaled by the wheel's friction. It's applied
## level with the centre of mass, so it turns the fish but never rolls it.
func _add_tyre_impulse(state: PhysicsDirectBodyState3D, body_basis: Basis, i: int, hit: Dictionary, com: Vector3, dt: float) -> void:
	var normal: Vector3 = hit.normal
	var wheel := _wheel_basis(body_basis, i)
	var axle := wheel.x
	if tyre_axle_on_surface:
		axle -= normal * wheel.x.dot(normal)
		if axle.length_squared() < 0.0001:
			return
		axle = axle.normalized()
	var along := normal.cross(axle)  # the wheel's forward, on the surface
	if along.length_squared() < 0.0001:
		return
	along = along.normalized()
	var r: Vector3 = hit.position - com
	var contact_velocity := state.linear_velocity + state.angular_velocity.cross(r)
	var inverse_inertia := state.inverse_inertia_tensor
	var r_axle := r.cross(axle)
	var effective := 1.0 / mass + r_axle.dot(inverse_inertia * r_axle)
	var side := -RL_TYRE_CONTACT_DAMPING * contact_velocity.dot(axle) / effective
	var rolling := 0.0  # m/s² along the wheel
	if _wheel_engine != 0.0:
		rolling = _wheel_engine
	elif _wheel_brake > 0.0:
		rolling = clampf(-contact_velocity.dot(along) * RL_ROLLING_FRICTION_SLOPE, -_wheel_brake, _wheel_brake)
	var impulse := (along * rolling * mass * _wheel_long_friction[i]
			+ axle * side * RL_TYRE_FRICTION_SCALE * _wheel_lat_friction[i]) * dt
	var up := body_basis.y
	var level := r - up * (r.dot(up) + tyre_force_drop)
	_tyre_push += impulse / mass
	_tyre_twist += inverse_inertia * level.cross(impulse)


## RL's Car::_UpdateWheels, for next tick's tyre forces: throttle, brake and
## coasting brake, the front wheels' steering angle, and each touching wheel's
## friction: full grip across a wheel rolling straight, down to a fifth of it
## sliding sideways, a tenth of that powersliding, and less on steep surfaces
## off the throttle. From the velocity the tick started with.
func _update_tyre_settings(velocity: Vector3, spin: Vector3, state: PhysicsDirectBodyState3D, body_basis: Basis) -> void:
	var forward := -body_basis.z
	var forward_speed := velocity.dot(forward)
	var abs_forward := absf(forward_speed)
	var throttle := 1.0 if is_boosting else input_forward - input_reverse
	var engine_throttle := throttle
	var brake := 0.0
	if not powerslide_held:  # the handbrake leaves the throttle as it is
		if absf(throttle) >= 0.001:
			if abs_forward > RL_STOPPING_FORWARD_VEL and signf(throttle) != signf(forward_speed):
				brake = 1.0  # driving against the motion brakes instead
				engine_throttle = 0.0
		else:
			engine_throttle = 0.0
			brake = 1.0 if abs_forward < RL_STOPPING_FORWARD_VEL else ground_coast_decel / maxf(ground_brake, 0.001)
	var drive_scale := _ground_torque_factor(abs_forward)
	if wheels_touching < 3:
		drive_scale /= 4.0
	_wheel_engine = engine_throttle * ground_accel / 4.0 * drive_scale
	_wheel_brake = brake * ground_brake / 4.0

	var com := state.transform.origin + body_basis * center_of_mass
	for i in _wheels.size():
		var hit := _wheel_hits[i]
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.normal
		var mount: Vector3 = state.transform.origin + body_basis * _wheels[i].mount
		var v := velocity + spin.cross(mount - com)
		var wheel_axle := _wheel_basis(body_basis, i).x
		var sliding := absf(v.dot(wheel_axle))
		var slip := 0.0  # 0 = rolling straight, 1 = sliding sideways
		if sliding > RL_FRICTION_SLIP_MIN:
			slip = sliding / (absf(v.dot(wheel_axle.cross(normal))) + sliding)
		var lat := lerpf(1.0, 0.2, slip)
		var lon := 1.0
		if _handbrake > 0.0:
			lat *= (0.1 - 1.0) * _handbrake + 1.0
			lon *= (lerpf(0.5, 0.9, slip) - 1.0) * _handbrake + 1.0
		if throttle == 0.0:
			var non_sticky := _rl_non_sticky_friction(normal.y)
			lat *= non_sticky
			lon *= non_sticky
		_wheel_lat_friction[i] = lat
		_wheel_long_friction[i] = lon

	# After the friction, which (as in RocketSim) sees the wheels as last tick steered them.
	var steer := _rl_steer_angle(abs_forward)
	if _handbrake > 0.0:
		steer += (_rl_curve(RL_POWERSLIDE_STEER_ANGLE_CURVE, abs_forward * UU_PER_SPEED) - steer) * _handbrake
	_wheel_steer = steer * input_stick.x


func _rl_curve(points: Array, x: float) -> float:
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		if x <= b.x:
			return lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))
	return points[-1].y


## Rocket League driving on whatever surface the fish is on (RocketSim
## Car::_UpdateWheels, simplified to the whole body): throttle on RL's torque
## curve, braking, coasting, boost, tyre grip across the nose, and the sticky
## push into the surface. Water drag doesn't apply; buoyancy still does.
func _apply_ground(velocity: Vector3, body_basis: Basis, dt: float) -> Vector3:
	var forward := -body_basis.z
	var along := velocity.dot(forward)
	_update_boost(dt)
	var throttle := 1.0 if is_boosting else input_forward - input_reverse  # RL: boost implies full throttle
	# Off the throttle, RL's tyres lose grip the steeper the surface (RocketSim
	# NON_STICKY_FRICTION_FACTOR_CURVE), so a car let go on a wall rolls back
	# down almost freely and slides off sideways.
	var friction := 1.0 if throttle != 0.0 else _rl_non_sticky_friction(surface_normal.y)
	if _uses_tyres():
		# The tyres drive, brake and grip (_add_tyre_impulse); only boost here.
		if is_boosting and along < ground_max_boost_speed:
			velocity += forward * ground_boost_accel * dt
		return _apply_stick(velocity, body_basis, throttle, along, dt)
	var accel := 0.0
	if throttle != 0.0:
		if along * throttle < -0.5:
			accel = ground_brake * signf(throttle)  # pushing against the motion brakes
		else:
			accel = throttle * ground_accel * _ground_torque_factor(absf(along))
	else:
		accel = -signf(along) * minf(ground_coast_decel * friction, absf(along) / dt)
	if is_boosting and along < ground_max_boost_speed:
		accel += ground_boost_accel
	velocity += forward * accel * dt

	var side := body_basis.x * velocity.dot(body_basis.x)
	var grip := lerpf(ground_grip, powerslide_lateral_drag, _handbrake)
	var gripped := side * (1.0 - exp(-grip * dt))
	if friction < 1.0:
		gripped = gripped.limit_length(ground_lateral_friction * friction / (1.0 - friction) * dt)
	velocity -= gripped
	# Cornering costs speed: RL's steered front wheels point into the turn, so
	# part of their sideways grip pulls back on the car.
	var steer_angle := absf(input_stick.x) * _rl_steer_angle(absf(along))
	velocity -= forward * signf(along) * ground_turn_drag * (gripped.length() / dt) * sin(steer_angle) * dt

	return _apply_stick(velocity, body_basis, throttle, along, dt)


## RL sticky force: half strength always, plus up to full strength more the
## further the surface is from level while driving, so walls hold.
func _apply_stick(velocity: Vector3, body_basis: Basis, throttle: float, along: float, dt: float) -> Vector3:
	var driving := throttle != 0.0 or absf(along) > 0.5
	var stick := 0.5 + (1.0 - absf(body_basis.y.y) if driving else 0.0)
	velocity -= surface_normal * surface_stick * stick * dt
	velocity.y += buoyancy * dt
	return velocity


## How much of its grip a tyre keeps off the throttle on a surface whose
## normal points `normal_up` up (RocketSim NON_STICKY_FRICTION_FACTOR_CURVE):
## all of it on the floor, half at 45 degrees, a tenth on a wall or the ceiling.
func _rl_non_sticky_friction(normal_up: float) -> float:
	if normal_up <= 0.0:
		return 0.1
	if normal_up < 0.7075:
		return lerpf(0.1, 0.5, normal_up / 0.7075)
	return lerpf(0.5, 1.0, minf((normal_up - 0.7075) / (1.0 - 0.7075), 1.0))


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
	if _uses_tyres():
		return local_spin  # the front wheels' grip turns the fish
	var along := velocity.dot(-body_basis.z)
	var turn := powerslide_turn_multiplier if is_powersliding else 1.0
	# Signed by the direction of travel, so reversing steers like a car.
	# RL's measured turning circle for this speed. Powersliding, the car keeps
	# turning by its whole speed, not just the forward part, so a slide keeps
	# swinging round (RL's rear wheels let go and the front ones pull it round).
	var speed := along
	var flat_speed := (velocity - surface_normal * velocity.dot(surface_normal)).length()
	# Which way the slide is going (forwards or reversing), held through a spin
	# while the car is mostly sideways, so it keeps swinging the same way.
	if absf(along) > 0.3 * flat_speed:
		_slide_sign = signf(along)
	if _handbrake > 0.0:
		speed = lerpf(along, flat_speed * _slide_sign, _handbrake)
	turn = lerpf(1.0, powerslide_turn_multiplier, _handbrake)
	var target := input_stick.x * turn * speed * _rl_curvature(absf(speed))
	var yaw_rate := lerpf(-local_spin.y, target, 1.0 - exp(-GROUND_STEER_RESPONSE * dt))
	if rl_suspension:
		return Vector3(local_spin.x, -yaw_rate, local_spin.z)  # pitch and roll from the springs
	var align := body_basis.transposed() * (body_basis.y.cross(surface_normal) * surface_align_rate)
	return Vector3(align.x, -yaw_rate, align.z)


func _rl_curvature(ground_speed: float) -> float:
	var uu := ground_speed * UU_PER_SPEED
	for i in range(1, RL_TURN_CURVATURE.size()):
		var a: Vector2 = RL_TURN_CURVATURE[i - 1]
		var b: Vector2 = RL_TURN_CURVATURE[i]
		if uu <= b.x:
			return lerpf(a.y, b.y, (uu - a.x) / (b.x - a.x)) * UU_PER_SPEED
	return RL_TURN_CURVATURE[-1].y * UU_PER_SPEED


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
	var stroking := swishy.power > 0.0 if swim_style == SwimStyle.EXTRA_SWISHY else stroke_chain >= 2
	var swimming := input_forward > 0.0 or is_boosting or stroking
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
	# RL's flip clock for this tick: it counts from the press tick, one tick ahead
	# of _flip_time, which starts with the torque on the tick after (and isn't
	# advanced yet this tick).
	var t := _flip_time + 2.0 * dt
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
	if _jump_wheel_contact_left > 0.0 and not pressed:
		_jump_wheel_contact_left -= dt
		# Resting-strength sticky push while the wheels are still down (RocketSim).
		velocity -= _jump_surface_normal * surface_stick * 0.5 * dt

	match jump_state:
		JumpState.READY:
			if pressed:
				if on_surface:
					# The ground still holds the fish up on the press tick, as in
					# RL: no sinking from this tick's gravity and sticky push.
					velocity -= surface_normal * minf(velocity.dot(surface_normal), 0.0)
					_jump_wheel_contact_left = RL_JUMP_WHEEL_CONTACT_TIME
					_jump_surface_normal = surface_normal
				velocity += body_basis.y * jump_impulse
				jump_state = JumpState.SECOND_JUMP
				_jump_timer = double_jump_window
				_jump_hold_elapsed = -1.0
				if variable_jump:
					# RL's hold push starts on the press tick itself.
					velocity += body_basis.y * jump_hold_accel * RL_JUMP_PRE_MIN_ACCEL_SCALE * dt
					_jump_hold_elapsed = dt
				_surface_grace = SURFACE_JUMP_GRACE
				_post_jump_time_left = post_jump_drag_time
				jumped.emit()
		JumpState.SECOND_JUMP:
			if _jump_hold_elapsed >= 0.0:
				# Holding the first jump keeps pushing; the double jump window
				# only starts counting once the hold is over, as in RL.
				# RocketSim Car::_UpdateJump: the push lasts at least JUMP_MIN_TIME
				# (at 62% strength) and while held up to JUMP_MAX_TIME.
				var early := _jump_hold_elapsed < RL_JUMP_MIN_HOLD - TIME_EPSILON
				var holding := jump_held or early
				if holding and not pressed and _jump_hold_elapsed < jump_hold_time - TIME_EPSILON:
					var scale := RL_JUMP_PRE_MIN_ACCEL_SCALE if early else 1.0
					velocity += body_basis.y * jump_hold_accel * scale * dt
					_jump_timer = double_jump_window
					_jump_hold_elapsed += dt
				else:
					_jump_hold_elapsed = -1.0
			if pressed:
				# No landing grace here, unlike the first jump: RL has none, and a
				# dodge just above the floor has to be able to land (wave dash).
				velocity = _second_jump(velocity, body_basis)
				_post_jump_time_left = post_jump_drag_time
				_start_cooldown()
			elif _jump_timer <= 0.0:
				_start_cooldown()
		JumpState.COOLDOWN:
			if _jump_timer <= 0.0 or (touching and contact_refreshes_jump):
				jump_state = JumpState.READY
	return velocity


## Dodge when the stick or roll is pushed, otherwise a straight double jump. As
## in RL, |pitch| + |yaw| + |roll| decides, so air roll alone dodges sideways.
func _second_jump(velocity: Vector3, body_basis: Basis) -> Vector3:
	if absf(input_stick.x) + absf(input_stick.y) + absf(input_roll) < dodge_deadzone:
		double_jumped.emit()
		return velocity + body_basis.y * jump_impulse

	# Stick up = dodge forward (local -Z); stick right or roll right = dodge right (local +X).
	var local_dir := Vector3(input_stick.x + input_roll, 0.0, input_stick.y).normalized()
	if rl_dodge_timing:
		_start_rl_flip()
		var push := _rl_dodge_push(velocity, body_basis)
		dodged.emit(push.normalized())
		return velocity + push
	if dodge_flip_turns > 0.0:
		# Spin so the nose dips toward the dodge direction (front flip, side flip...).
		_flip_axis = Vector3.UP.cross(local_dir).normalized()
		_flip_time_left = dodge_flip_duration
		is_dodging = true
	var world_dir := body_basis * local_dir
	dodged.emit(world_dir)
	return velocity + world_dir * dodge_impulse


## Rocket League's dodge push (RocketSim Car::_UpdateDoubleJumpOrFlip): along the
## dodge direction in the ground plane, and stronger the faster the car is
## already going: sideways up to 1.9x at top speed, backwards up to 2.5x and
## 16/15 more even at rest. Forwards doesn't grow. Needs _start_rl_flip first.
func _rl_dodge_push(velocity: Vector3, body_basis: Basis) -> Vector3:
	var dir := _flip_direction  # x = forward, y = right; zero for a stall
	if dir == Vector2.ZERO:
		return Vector3.ZERO
	var forward := -body_basis.z
	var forward_speed := velocity.dot(forward)
	var speed_ratio := absf(forward_speed) / RL_CAR_MAX_SPEED
	var backwards := dir.x < 0.0 if absf(forward_speed) < RL_DODGE_BACKWARDS_MIN_SPEED else signf(forward_speed) != signf(dir.x)
	var push := dir * dodge_impulse
	if backwards:
		push.x *= ((RL_DODGE_BACKWARD_MAX_SPEED_SCALE - 1.0) * speed_ratio + 1.0) * RL_DODGE_BACKWARD_SCALE
	push.y *= (RL_DODGE_SIDE_MAX_SPEED_SCALE - 1.0) * speed_ratio + 1.0
	var forward_flat := Vector3(forward.x, 0.0, forward.z)
	forward_flat = forward_flat.normalized() if forward_flat.length() > 0.001 else -body_basis.y  # nose straight up or down
	var right_flat := forward_flat.cross(Vector3.UP).normalized()
	return forward_flat * push.x + right_flat * push.y


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
	_flip_pressed_this_tick = true
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
	var steer_stick := input_stick
	if swim_strokes and swim_style == SwimStyle.EXTRA_SWISHY:
		steer_stick = swishy.steer  # sweeps power strides more than they turn
	var pitch_in := -steer_stick.y if invert_pitch else steer_stick.y
	var yaw_in := steer_stick.x
	var roll_in := input_roll
	if air_roll_held:
		roll_in += yaw_in
		yaw_in = 0.0
	roll_in = clampf(roll_in, -1.0, 1.0)

	if _flip_pressed_this_tick:
		# RL's flip torque starts the tick after the press (RocketSim): the press
		# tick itself is ordinary air control.
		_flip_pressed_this_tick = false
		return _rl_air_control(local_spin, pitch_in, yaw_in, roll_in, dt)
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
## input is held, constant damping on roll. The 5.5 rad/s cap is applied at the
## start of the next tick, as in RL. Spin is in the fish's frame (x = pitch,
## y = yaw, z = roll) as elsewhere.
func _rl_air_control(spin: Vector3, pitch_in: float, yaw_in: float, roll_in: float, dt: float) -> Vector3:
	var pitch_rate := spin.x
	var yaw_rate := -spin.y
	var roll_rate := -spin.z
	pitch_rate += (RL_PITCH_TORQUE * pitch_in - RL_PITCH_DAMPING * (1.0 - absf(pitch_in)) * pitch_rate) * dt
	yaw_rate += (RL_YAW_TORQUE * yaw_in - RL_YAW_DAMPING * (1.0 - absf(yaw_in)) * yaw_rate) * dt
	roll_rate += (RL_ROLL_TORQUE * roll_in - RL_ROLL_DAMPING * roll_rate) * dt
	return Vector3(pitch_rate, -yaw_rate, -roll_rate)


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
	_flip_pressed_this_tick = false
	_flip_spin_out = false
	on_surface = false
	_surface_grace = 0.0
	_autoflip_left = 0.0
	_step_velocity = Vector3.ZERO
	_prev_step_velocity = Vector3.ZERO
	_ball_push = Vector3.ZERO
	_ball_twist = Vector3.ZERO
	_post_jump_time_left = 0.0
	_queued_stroke = 0.0
	stroke_chain = 0
	swishy.reset()
	bow_amount = 0.0
	is_dodging = false
	jump_state = JumpState.READY
	_jump_hold_elapsed = -1.0
	_jump_wheel_contact_left = 0.0
	_handbrake = 0.0
	reset_tyres()
	boost_amount = spawn_boost
	reset_physics_interpolation.call_deferred()


func _apply_physics_material() -> void:
	if physics_material_override == null:
		return
	# On RL's tyres the hitbox keeps RL's own scrape and bounce while driving,
	# as when it clips a ramp at speed. Otherwise, driving, the body neither
	# scrapes nor bounces: the ground model handles grip. (The ball grips a
	# fish it rests on itself.)
	var driving := on_surface and not _uses_tyres()
	physics_material_override.bounce = 0.0 if driving else wall_bounce
	physics_material_override.friction = 0.0 if driving else wall_friction


## Placeholder animation: driven by movement state, never the other way round.
func _process(delta: float) -> void:
	var effort := maxf(input_forward, 1.0 if is_boosting else 0.0)
	_swim_phase += delta * lerpf(4.0, 18.0, effort)
	# Powerslide: tail kicks out toward the turn, fins flare like air brakes.
	var slide := 1.0 if is_powersliding else 0.0
	var tail_kick := -input_stick.x * 0.6 * slide
	if swim_strokes and swim_style == SwimStyle.EXTRA_SWISHY:
		# Strides drive the tail: each sweeps it across, away from the push, to
		# the far side at the peak (SwishySwim.tail_swing). The idle wiggle only
		# shows between strides.
		var growth := stride_tail_growth * swishy.flow / maxf(stride_flow_max, 0.01)
		_tail.scale = Vector3.ONE * (1.0 + growth) * (1.0 + 0.2 * swishy.power)
		var swing := swishy.tail_swing * stride_tail_swing
		var idle := sin(_swim_phase) * lerpf(0.1, 0.25, effort) * (1.0 - minf(swishy.tail_swing.length(), 1.0))
		_tail.rotation.y = swing.x + idle + tail_kick
		_tail.rotation.x = swing.y
	else:
		_tail.scale = Vector3.ONE
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
	var striding := swim_strokes and swim_style == SwimStyle.EXTRA_SWISHY
	_visual.grounded = on_surface
	_visual.stride_swing = swishy.tail_swing if striding else Vector2.ZERO
	_visual.stride_power = swishy.power if striding else 0.0
	_visual.react(delta, linear_velocity)
	var cue := swishy.cue() if swim_style == SwimStyle.EXTRA_SWISHY else Vector3.ZERO
	_visual.set_stride_cue(cue.x, cue.y, cue.z)
	_bubbles.emitting = is_boosting
	_update_bow_view(delta)
	_pour_bubbles(delta)


## The bow wave's shape now (bow_amount), in the hitbox's space: an
## ellipse-nosed cone from the hitbox's middle out past its front, as points
## for a convex shape. Its size: (half width, half height, reach ahead).
func bow_size() -> Vector3:
	var half := (_collision.shape as BoxShape3D).size / 2.0
	var girth := lerpf(1.1, bow_girth, bow_amount)
	return Vector3(half.x, maxf(half.y, half.x * 0.7), 0.0) * girth + Vector3(0.0, 0.0, half.z + lerpf(0.1, bow_length, bow_amount))


func bow_points() -> PackedVector3Array:
	var size := bow_size()
	var points := PackedVector3Array([Vector3(0.0, 0.0, -size.z)])
	for ring in BOW_RINGS:
		var along := float(ring) / BOW_RINGS  # 0 at the middle to 1 at the tip
		var round_off := sqrt(1.0 - along * along)
		for side in BOW_SIDES:
			var angle := TAU * side / BOW_SIDES
			points.append(Vector3(cos(angle) * size.x * round_off, sin(angle) * size.y * round_off, -size.z * along))
	return points


## A unit bow (radius 1, reaching 1 ahead along -Z), scaled to bow_size() as it
## swims; UV.x runs round it and UV.y from its open back (0) to its tip (1).
func _build_bow_view() -> void:
	var rings := 16
	var sides := 32
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in rings + 1:
		var along := float(ring) / rings
		var round_off := sqrt(maxf(1.0 - along * along, 0.0))
		for side in sides + 1:
			var angle := TAU * side / sides
			tool.set_uv(Vector2(float(side) / sides, along))
			tool.add_vertex(Vector3(cos(angle) * round_off, sin(angle) * round_off, -along))
	for ring in rings:
		for side in sides:
			var a := ring * (sides + 1) + side
			var b := a + sides + 1
			for corner: int in [a, a + 1, b, b, a + 1, b + 1]:
				tool.add_index(corner)
	tool.generate_normals()
	_bow_view.name = "BowWave"
	_bow_view.mesh = tool.commit()
	_bow_material.shader = BOW_SHADER
	_bow_view.material_override = _bow_material
	_bow_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bow_view.visible = false
	add_child(_bow_view)


func _update_bow_view(delta: float) -> void:
	_bow_view.visible = bow_amount > 0.005
	if not _bow_view.visible:
		return
	_bow_view.position = _collision.position
	_bow_view.scale = bow_size()
	_bow_flow += delta * speed * 0.8
	_bow_material.set_shader_parameter("amount", bow_amount)
	_bow_material.set_shader_parameter("flow", _bow_flow)


## While a stride pushes, the tail pours a stream of bubbles (StrideStream):
## from its tip, jetting back and out to the side it's swinging from, denser
## as the stride builds and with flow, in the stride's timing colour.
func _pour_bubbles(delta: float) -> void:
	var swishing := stride_bubbles and swim_strokes and swim_style == SwimStyle.EXTRA_SWISHY
	if not swishing or swishy.phase < 0.0 or not is_visible_in_tree():
		return
	var tip := _tail.global_transform * _visual.tail_tip()
	var body := global_basis.orthonormalized()
	var swing := swishy.tail_swing
	var side := body.x * swing.x - body.y * swing.y
	var jet := (body.z + side * 0.4).normalized()  # body.z is backward
	var push := (1.0 + swishy.flow) / (1.0 + stride_flow_max)
	var rate := lerpf(60.0, 220.0, push) * lerpf(0.4, 1.0, swishy.power)
	var color := StrideStream.color_for(swishy.last_timing)
	color.a = lerpf(0.4, 1.0, push)
	# They keep most of the fish's speed, so the stream stays tight behind the tail.
	_stream.pour(delta, tip, jet, linear_velocity * 0.75, 0.025 * _tail.scale.x, rate, color)
