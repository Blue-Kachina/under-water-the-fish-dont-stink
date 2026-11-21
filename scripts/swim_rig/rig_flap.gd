class_name RigFlap
extends RigLayer
## The fin pivots' own roll (planning_core_roadmap.md 2.4, Gait.rig_bell_flap), the pose FishController._process gave
## them, on the layer's own clocks (no Time): swimming backwards the pectorals flutter (rig_reverse_flutter at
## rig_reverse_hz); under Gait.Visual.FLAP (the sea hare's parapodia) the flaps beat down with each stride's power and
## lift back up between, with a slow idle wave on the swim's rhythm. Into pose.pivot_roll (+ lowers, both sides).

var _flap := 0.0
var _idle_phase := 0.0
var _flutter_phase := 0.0


func weight(gait: Gait) -> float:
	return 1.0 if gait.rig_bell_flap else 0.0


func reset() -> void:
	_flap = 0.0


func evaluate(_rig: SwimRig, state: SwimState, gait: Gait, dt: float, pose: SwimPose) -> void:
	_idle_phase = fmod(_idle_phase + dt * lerpf(4.0, 18.0, state.effort) * gait.rig_flap_idle_pace, TAU)
	_flutter_phase = fmod(_flutter_phase + TAU * gait.rig_reverse_hz * dt, TAU)
	var roll := sin(_flutter_phase) * gait.rig_reverse_flutter * state.reverse
	if gait.visual == Gait.Visual.FLAP:
		var idle := sin(_idle_phase) * gait.rig_flap_idle
		_flap = lerpf(_flap, gait.rig_flap_beat * state.stride_power + idle, 1.0 - exp(-gait.rig_flap_rate * dt))
		roll += _flap
	pose.pivot_roll += Vector2(roll, roll)
