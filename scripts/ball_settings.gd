class_name BallSettings
extends Resource
## Tunable ball physics, shared by the tuning panel and whichever Ball is in the
## world, so values survive environment switches and save with the fish tuning.
##
## Defaults follow Rocket League's ball (RocketSim RLConst.h). Its size is RL's
## (1 uu = 1 cm, like the arena and the fish's hitbox), and so are its speeds
## and accelerations.

## WATER: an air bubble drifting in the water, with water drag and buoyancy.
## SURFACE: ignores the water and flies like Rocket League's ball, with gravity.
enum BallType { WATER, SURFACE }

@export_group("Ball")
@export var ball_type := BallType.SURFACE
## RL: 0.9125 m (91.25 uu).
@export_range(0.25, 6.0, 0.0025) var radius := 0.9125
## Relative to the fish (mass 1). RL's ball is 1/6 of a car (30 vs 180).
@export_range(0.05, 5.0, 0.001) var mass := 0.167
## Restitution. RL: 0.6; mutators "low"/"high"/"super high" bounciness.
@export_range(0.0, 1.0, 0.05) var bounciness := 0.6
## RL: 0.35 against the arena.
@export_range(0.0, 2.0, 0.05) var friction := 0.35
## RL: 60 m/s. Mutators "slow"/"fast"/"super fast" max ball speed.
@export_range(5.0, 300.0, 1.0) var max_speed := 60.0
## RL: 6 rad/s.
@export_range(0.0, 30.0, 0.5) var max_angular_speed := 6.0
## Rocket League's ball indicator: a ring on each surface near the ball,
## pulsing when the ball touches it.
@export var surface_indicator := true
## How far from a surface the ball still shows its ring there (m).
@export_range(1.0, 80.0, 0.5) var indicator_range := 4.0

@export_group("Water Ball")
## Use the fish's linear_drag, angular_drag and buoyancy instead of the values below.
@export var inherit_water := true
## Fraction of speed lost per second.
@export_range(0.0, 3.0, 0.01) var linear_drag := 0.4
## Fraction of spin lost per second.
@export_range(0.0, 5.0, 0.05) var angular_drag := 1.0
## Upward acceleration. 0 = neutral, negative sinks.
@export_range(-20.0, 20.0, 0.1) var buoyancy := 0.0

@export_group("Surface Ball")
## Downward acceleration. RL: 6.5 m/s²; mutators "low"/"high"/"super high" gravity.
@export_range(0.0, 60.0, 0.5) var gravity := 6.5
## Fraction of speed lost per second in the air (applied like Bullet's linear
## damping: speed x (1 - air_drag) each second). RL: 0.03.
@export_range(0.0, 1.0, 0.01) var air_drag := 0.03
## Fraction of spin lost per second. RL: none.
@export_range(0.0, 5.0, 0.05) var spin_drag := 0.0

@export_group("Hits")
## Rocket League's extra hit impulse: on top of the collision, the ball gets a
## push along the line from the fish to the ball, scaled by the hit speed.
@export var rl_hit_impulse := true
## RL mutator "ball hit extra force scale" (Boomer mode is 1.5).
@export_range(0.0, 4.0, 0.05) var hit_force_scale := 1.0
## How much of the push's world-vertical part is kept. RL squashes it to 0.35
## so hits send the ball along the floor more than up into the air.
@export_range(0.0, 1.5, 0.05) var hit_up_scale := 0.35
## How much of the push along the fish's facing is kept (RL: 0.65).
@export_range(0.0, 1.0, 0.05) var hit_forward_scale := 0.65

@export_group("Match")
## RL's kickoff rule: after a kickoff or goal reset the ball floats where it
## spawned, ignoring gravity, until a fish first touches it. Surface ball only.
@export var kickoff_float := true
## Seconds after a goal before the ball respawns at centre.
@export_range(0.0, 10.0, 0.5) var goal_reset_delay := 3.0


## Whether an option affects the current ball; the tuning panel hides the rest.
func is_option_active(property: String) -> bool:
	match property:
		"inherit_water":
			return ball_type == BallType.WATER
		"linear_drag", "angular_drag", "buoyancy":
			return ball_type == BallType.WATER and not inherit_water
		"gravity", "air_drag", "spin_drag":
			return ball_type == BallType.SURFACE
		"indicator_range":
			return surface_indicator
	return true
