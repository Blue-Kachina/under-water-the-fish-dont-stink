class_name RigWingBeat
extends RigLayer
## A ray's wings (planning_core_roadmap.md 2.3 P5, the Gliders), the pectoral channels' "flap axis": they beat up and
## down on the body's wave (rig_wing_amp, rig_wing_lag behind the Undulation layer's phase, deeper with effort), and
## each stride is a downstroke that springs back up past level as it fades (the old FishModel._beat_wings, on
## rig_wing_spring / rig_wing_damping, so it overshoots), the wing away from a sideways push beating harder while the
## body rolls away from it (rig_wing_roll). On a surface the body levels and the tips stay out of the floor. Last in the
## layer order, so its levelling sees every layer's bank.

var _beat := Vector2.ZERO  # (left, right), + up
var _beat_speed := Vector2.ZERO
var _last_power := 0.0
var _ground := SpringChannel.new()


func weight(gait: Gait) -> float:
	return gait.rig_wing_beat


func reset() -> void:
	_beat = Vector2.ZERO
	_beat_speed = Vector2.ZERO
	_last_power = 0.0
	_ground.reset()


func evaluate(rig: SwimRig, state: SwimState, gait: Gait, dt: float, pose: SwimPose) -> void:
	var w := gait.rig_wing_beat
	var drive := clampf(maxf(state.effort, state.speed_frac * gait.rig_coast_wave), 0.0, 1.0)
	var wave := gait.rig_wing_amp * pow(drive, 0.7) * sin(rig.wave_phase - gait.rig_wing_lag)
	if dt > 0.0:
		var lean := clampf(state.stride_dir.x, -1.0, 1.0) * gait.rig_wing_lean
		# Fading (power falling over about a third of a second) lifts them.
		var fading := clampf((_last_power - state.stride_power) / dt * 0.35, 0.0, 1.0)
		_last_power = state.stride_power
		var target := Vector2(1.0 + lean, 1.0 - lean) * (gait.rig_wing_lift * fading - gait.rig_wing_stride * state.stride_power)
		var omega := gait.rig_wing_spring
		var steps := ceili(dt * 120.0)
		var h := dt / steps
		for k in steps:
			_beat_speed += ((target - _beat) * omega * omega - _beat_speed * 2.0 * gait.rig_wing_damping * omega) * h
			_beat += _beat_speed * h
	if state.grounded:
		_beat = _beat.max(Vector2(-gait.rig_wing_ground, -gait.rig_wing_ground))
	pose.fin_flap += w * (Vector2(wave, wave) - _beat)
	pose.bank -= w * state.stride_dir.x * state.stride_power * gait.rig_wing_roll
	var level := _ground.step(1.0 if state.grounded else 0.0, gait.rig_wing_spring, dt) * minf(w, 1.0)
	pose.bank *= 1.0 - level
	if state.grounded:
		pose.fin_flap = pose.fin_flap.min(Vector2(gait.rig_wing_ground, gait.rig_wing_ground))
