class_name RigBellPulse
extends RigLayer
## A jelly's bell (planning_core_roadmap.md 2.4, Gait.rig_bell_flap): the BellPulse step FishModel._pulse_bell did, as
## a layer. Strides drive it while the bell leans (state.bell_lean >= 0: a Drifter under Gait.Visual.BELL_PULSE),
## otherwise it beats on its own, quicker with speed. It steps the model's own BellPulse (SwimRig.bell), so switching
## the layer on or off mid-stroke carries on where the bell was; its shape goes into the pose's bell channels.


func weight(gait: Gait) -> float:
	return 1.0 if gait.rig_bell_flap else 0.0


func evaluate(rig: SwimRig, state: SwimState, gait: Gait, dt: float, pose: SwimPose) -> void:
	var bell := rig.bell
	if bell == null:
		return
	pose.bell_squeeze = 1.0
	pose.bell_flatten = 1.0
	if state.bell_lean >= 0.0:
		bell.step_strides(dt, state.stride_phase, state.stride_peak, state.stride_fade, gait)
		pose.bell_squeeze = gait.bell_squeeze
		pose.bell_flatten = gait.bell_flatten
	else:
		var effort := clampf(state.speed / FishModel.SWIM_REF_SPEED, 0.0, 1.0)
		bell.step_free(dt, lerpf(0.4, 0.9, effort), effort)
	pose.bell_crown = bell.crown
	pose.bell_margin = bell.margin
	pose.bell_ripple = bell.ripple
	pose.bell_ripple_phase = bell.ripple_phase
