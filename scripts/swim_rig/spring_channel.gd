class_name SpringChannel
extends RefCounted
## One critically damped spring (planning_core_roadmap.md 2.2): `value` eases to
## the target it is given with no overshoot and keeps its velocity, so a changing
## target never snaps it. Stable at any step. No allocation.

var value := 0.0
var velocity := 0.0


## Moves `value` toward `target` for `dt` s; `rate` (1/s) is how stiff: its time
## constant is about 1 / rate. Returns the new value.
func step(target: float, rate: float, dt: float) -> float:
	if dt <= 0.0:
		return value
	var w := maxf(rate, 0.001)
	var x := w * dt
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := value - target
	var temp := (velocity + w * change) * dt
	velocity = (velocity - w * temp) * decay
	value = target + (change + temp) * decay
	return value


func reset(to := 0.0) -> void:
	value = to
	velocity = 0.0
