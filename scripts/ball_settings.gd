class_name BallSettings
extends Resource
## Tunable ball physics, shared by the tuning panel and whichever Ball is in the
## world, so values survive environment switches and save with the fish tuning.
##
## Defaults follow Rocket League's ball (RocketSim RLConst.h), scaled to this
## game: the fish tops out near 2x a car's speed, so speeds and accelerations
## are 2x too (times stay the same).

## WATER: an air bubble drifting in the water, with water drag and buoyancy.
## SURFACE: ignores the water and flies like Rocket League's ball, with gravity.
enum BallType { WATER, SURFACE }

@export_group("Ball")
@export var ball_type := BallType.SURFACE
@export_range(0.25, 6.0, 0.05) var radius := 2.5
## Relative to the fish (mass 1). RL's ball is 1/6 of a car.
@export_range(0.05, 5.0, 0.01) var mass := 0.75
## Restitution. RL: 0.6; mutators "low"/"high"/"super high" bounciness.
@export_range(0.0, 1.0, 0.05) var bounciness := 0.75
@export_range(0.0, 2.0, 0.05) var friction := 0.2
## RL: 60 m/s (x2). Mutators "slow"/"fast"/"super fast" max ball speed.
@export_range(5.0, 300.0, 1.0) var max_speed := 200.0
## RL: 6 rad/s.
@export_range(0.0, 30.0, 0.5) var max_angular_speed := 10.0

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
## Downward acceleration. RL: 6.5 m/s² (x2); mutators "low"/"high"/"super high" gravity.
@export_range(0.0, 60.0, 0.5) var gravity := 15.0
## Fraction of speed lost per second in the air. RL: 0.03.
@export_range(0.0, 1.0, 0.01) var air_drag := 0.03
## Fraction of spin lost per second. RL: none.
@export_range(0.0, 5.0, 0.05) var spin_drag := 1.7

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
	return true
