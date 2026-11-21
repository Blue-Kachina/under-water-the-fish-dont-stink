class_name RigDrift
extends RigLayer
## The body aligning part-way to the flow (planning_core_roadmap.md 2.2), from
## state.slip (the velocity less its part along the nose, body frame): the rear
## joints bend toward the velocity, more toward the tail (yaw + toward the fish's
## right, a climb pitches the tail end up), and the pectorals flare as air brakes
## the more it slips.

const SHARE := [0.2, 0.35, 0.45]

var _side := SpringChannel.new()
var _rise := SpringChannel.new()


func weight(gait: Gait) -> float:
	return gait.rig_drift


func reset() -> void:
	_side.reset()
	_rise.reset()


func evaluate(_rig: SwimRig, state: SwimState, gait: Gait, dt: float, pose: SwimPose) -> void:
	var w := gait.rig_drift
	var gate := clampf(state.speed / 2.0, 0.0, 1.0)
	var along := maxf(state.speed, 1.0)
	var side := _side.step(clampf(state.slip.x / along, -1.0, 1.0) * gate, gait.rig_drift_rate, dt)
	var rise := _rise.step(clampf(state.slip.y / along, -1.0, 1.0) * gate, gait.rig_drift_rate, dt)
	for j in SwimPose.JOINTS:
		pose.joint_yaw[j] += w * side * gait.rig_drift_bend * SHARE[j]
		pose.joint_pitch[j] -= w * rise * gait.rig_drift_bend * SHARE[j]
	var brake := w * maxf(absf(side), absf(rise)) * gait.rig_drift_fins
	pose.fin_sweep += Vector2(brake, brake)
