class_name BallSettings
extends Resource
## Tunable ball physics, shared by the tuning panel and whichever Ball is in the
## world, so values survive environment switches and save with the fish tuning.
##
## Defaults follow Rocket League's ball (RocketSim RLConst.h), scaled to this
## game: the fish tops out near 2x a car's speed, so speeds are about 2x too.

@export_group("Water")
## Use the fish's linear_drag, angular_drag and buoyancy instead of the values below.
@export var inherit_water := true
## Fraction of speed lost per second. RL's ball (in air) is 0.03.
@export_range(0.0, 3.0, 0.01) var linear_drag := 0.4
## Fraction of spin lost per second.
@export_range(0.0, 5.0, 0.05) var angular_drag := 1.0
## Upward acceleration. 0 = neutral, negative sinks (RL gravity is -6.5 m/s² scaled).
@export_range(-20.0, 20.0, 0.1) var buoyancy := 0.0

@export_group("Ball")
@export_range(0.25, 6.0, 0.05) var radius := 1.5
## Relative to the fish (mass 1). RL's ball is 1/6 of a car.
@export_range(0.05, 5.0, 0.01) var mass := 0.17
## Restitution. RL: 0.6; mutators "low"/"high"/"super high" bounciness.
@export_range(0.0, 1.0, 0.05) var bounciness := 0.6
@export_range(0.0, 2.0, 0.05) var friction := 0.35
## RL: 60 m/s.
@export_range(5.0, 200.0, 1.0) var max_speed := 110.0
## RL: 6 rad/s.
@export_range(0.0, 30.0, 0.5) var max_angular_speed := 6.0

@export_group("Hits")
## Rocket League's extra hit impulse: on top of the collision, the ball gets a
## push along the line from the fish to the ball, scaled by the hit speed.
@export var rl_hit_impulse := true
## RL mutator "ball hit extra force scale".
@export_range(0.0, 4.0, 0.05) var hit_force_scale := 1.0
## How much of the push's world-vertical part is kept. RL squashes it to 0.35
## so hits send the ball along the floor more than up into the air.
@export_range(0.0, 1.5, 0.05) var hit_up_scale := 0.35
## How much of the push along the fish's facing is kept (RL: 0.65).
@export_range(0.0, 1.0, 0.05) var hit_forward_scale := 0.65

@export_group("Match")
## Seconds after a goal before the ball respawns at centre.
@export_range(0.0, 10.0, 0.5) var goal_reset_delay := 3.0
