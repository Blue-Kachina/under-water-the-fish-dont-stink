class_name RigFinStabilizer
extends RigLayer
## The pectorals as control surfaces (planning_core_roadmap.md 2.2): ailerons
## against the body's roll (spin.z) and pitch (spin.x) rates (a roll left lifts the
## left fin, a nose-up pitch drops both leading edges), trimmed by the climb
## (slip.y over speed), fluttering with speed on the layer's own clock. The
## caudal fin's own flutter, twice as quick, rides effort.

var _roll := SpringChannel.new()
var _pitch := SpringChannel.new()
var _trim := SpringChannel.new()
var _clock := 0.0


func weight(gait: Gait) -> float:
	return gait.rig_fin_stabilizer


func reset() -> void:
	_roll.reset()
	_pitch.reset()
	_trim.reset()


func evaluate(_rig: SwimRig, state: SwimState, gait: Gait, dt: float, pose: SwimPose) -> void:
	var w := gait.rig_fin_stabilizer
	var rate := gait.rig_fin_stab_rate
	var counter := _roll.step(clampf(-state.spin.z * gait.rig_fin_stab, -1.0, 1.0), rate, dt)
	var nose := _pitch.step(clampf(-state.spin.x * gait.rig_fin_stab, -1.0, 1.0), rate, dt)
	var climb := _trim.step(clampf(state.slip.y / maxf(state.speed, 1.0), -1.0, 1.0) * clampf(state.speed / 2.0, 0.0, 1.0), rate, dt)
	if dt > 0.0:
		_clock = fmod(_clock + TAU * gait.rig_fin_flutter_hz * dt, TAU)
	var flutter := sin(_clock) * gait.rig_fin_flutter * state.speed_frac
	pose.fin_flap += w * Vector2(counter + flutter, -counter + flutter)
	var pitch := w * (nose + climb * gait.rig_fin_trim)
	pose.fin_pitch += Vector2(pitch, pitch)
	pose.tail_yaw += w * 0.5 * gait.rig_fin_flutter * state.effort * sin(2.0 * _clock)
