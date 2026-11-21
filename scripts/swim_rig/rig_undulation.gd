class_name RigUndulation
extends RigLayer
## A travelling wave down the spine (planning_core_roadmap.md 2.2): its size from
## effort (a coasting fish keeps part of it), its rate from speed (Strouhal:
## f = St x U / reach, clamped), its phase from the rig's own clock. The joints
## beat one after another (rig_wave_lag), the share of the wave growing toward
## the tail (1 : 4 : 9 at rig_envelope 1, so it grows from the pectorals back,
## not from the nose); the head swings against it; the caudal fin flexes past
## the stalk, a few degrees ahead of it. A stride's power deepens it.

var _amp := SpringChannel.new()
var _freq := SpringChannel.new()


func weight(gait: Gait) -> float:
	return gait.rig_undulation


func reset() -> void:
	_amp.reset()
	_freq.reset()


func evaluate(rig: SwimRig, state: SwimState, gait: Gait, dt: float, pose: SwimPose) -> void:
	var w := gait.rig_undulation
	var drive := clampf(maxf(state.effort, state.speed_frac * gait.rig_coast_wave), 0.0, 1.0)
	var target := gait.rig_amplitude * pow(drive, 0.7) * (1.0 + gait.rig_cue_amp * state.stride_power)
	var amp := _amp.step(target, gait.rig_ease, dt)
	var reach := maxf(gait.rig_amplitude * rig.length * 0.4, 0.05)
	var wanted := clampf(gait.rig_strouhal * state.speed / reach, gait.rig_freq_min, gait.rig_freq_max)
	var freq := clampf(_freq.step(wanted, gait.rig_ease, dt), gait.rig_freq_min, gait.rig_freq_max)
	rig.wave_freq = freq
	if dt > 0.0:
		rig.wave_phase = fmod(rig.wave_phase + TAU * freq * dt, TAU)
	var phase := rig.wave_phase
	var axis := clampf(gait.rig_wave_axis, 0.0, 1.0)
	var total := 0.0
	for j in SwimPose.JOINTS:
		total += pow(j + 1.0, 2.0 * gait.rig_envelope)
	for j in SwimPose.JOINTS:
		var share := pow(j + 1.0, 2.0 * gait.rig_envelope) / total
		var beat := w * amp * share * sin(phase - j * gait.rig_wave_lag)
		pose.joint_yaw[j] += beat * (1.0 - axis)
		pose.joint_pitch[j] += beat * axis
	var sway := w * amp * gait.rig_head_sway * sin(phase + gait.rig_wave_lag)
	pose.head_yaw -= sway * (1.0 - axis)
	pose.head_pitch -= sway * axis
	var flex := w * amp * gait.rig_caudal_flex * sin(phase - SwimPose.JOINTS * gait.rig_wave_lag + deg_to_rad(gait.rig_caudal_lead))
	pose.tail_yaw += flex * (1.0 - axis)
	pose.tail_pitch += flex * axis
	pose.wave_amp = maxf(pose.wave_amp, clampf(amp / maxf(gait.rig_amplitude, 0.001), 0.0, 1.0) * minf(w, 1.0))
