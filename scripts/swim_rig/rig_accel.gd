class_name RigAccel
extends RigLayer
## The body's answer to acceleration (planning_core_roadmap.md 2.2, replacing
## squash and stretch), each part on a critically damped spring: along the nose
## (+ speeding up) and up. Speeding up trails the tail down (pitch +, mostly the
## joints near the tail) and lifts the head against it, folds the pectorals back and
## surges the body ahead; braking folds the tail up, dips the head and flares the
## pectorals like air brakes.

var _tail := SpringChannel.new()
var _head := SpringChannel.new()
var _fins := SpringChannel.new()
var _surge := SpringChannel.new()


func weight(gait: Gait) -> float:
	return gait.rig_accel


func reset() -> void:
	_tail.reset()
	_head.reset()
	_fins.reset()
	_surge.reset()


func evaluate(rig: SwimRig, state: SwimState, gait: Gait, dt: float, pose: SwimPose) -> void:
	var w := gait.rig_accel
	var ahead := clampf(-state.accel.z / gait.rig_accel_ref, -1.0, 1.0)
	var up := clampf(state.accel.y / gait.rig_accel_ref, -1.0, 1.0)
	var rate := gait.rig_accel_rate
	var trail := _tail.step(clampf(ahead + up, -1.0, 1.0), rate, dt) * gait.rig_accel_tail
	var lift := _head.step(ahead, rate, dt)
	var fold := _fins.step(ahead, rate, dt) * gait.rig_accel_fins
	var push := _surge.step(ahead, rate, dt)
	pose.joint_pitch[0] += w * trail * 0.1 * rig.bend_share
	pose.joint_pitch[1] += w * trail * 0.3 * rig.bend_share
	pose.joint_pitch[2] += w * trail * 0.6 * rig.bend_share
	pose.tail_pitch += w * trail * (1.0 - rig.bend_share)
	pose.head_pitch += w * lift * gait.rig_accel_head
	pose.fin_sweep += Vector2(-fold, -fold) * w
	pose.surge += w * push * gait.rig_accel_surge * rig.length
