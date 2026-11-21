class_name RigIdle
extends RigLayer
## The hover of a fish that isn't swimming (planning_core_roadmap.md 2.2): the
## pectorals scull, the tail sways slowly along the spine, on the layer's own
## clock. Its weight is (1 - effort), and zero from rig_idle_speed up.

var _clock := 0.0


func weight(gait: Gait) -> float:
	return gait.rig_idle


func evaluate(_rig: SwimRig, state: SwimState, gait: Gait, dt: float, pose: SwimPose) -> void:
	if dt > 0.0:
		_clock = fmod(_clock + TAU * gait.rig_idle_hz * dt, TAU * 100.0)
	var fade := gait.rig_idle * (1.0 - clampf(state.effort, 0.0, 1.0)) * (1.0 - smoothstep(0.0, gait.rig_idle_speed, state.speed))
	if fade <= 0.0:
		return
	for j in SwimPose.JOINTS:
		pose.joint_yaw[j] += fade * gait.rig_idle_sway * (j + 1.0) / 6.0 * sin(_clock - j * 0.8)
	pose.tail_yaw += fade * gait.rig_idle_sway * 0.5 * sin(_clock - 2.4)
	var scull := fade * gait.rig_idle_scull * sin(_clock * 1.7)
	pose.fin_flap += Vector2(scull, scull)
	pose.fin_sweep += Vector2(1.0, 1.0) * fade * gait.rig_idle_scull * 0.3 * sin(_clock * 1.7 + 1.2)
