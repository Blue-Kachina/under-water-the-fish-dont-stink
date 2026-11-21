class_name RigTailDrive
extends RigLayer
## A stride's swing (state.stride_dir, SwishySwim.tail_swing) on the tail
## (planning_core_roadmap.md 2.2): the caudal fin takes it at once (rig_tail_snap,
## so the timing cue still reads) and the spine's joints follow it up the body, the
## one by the tail first and the one by the head last (rig_stride_follow), so the
## stroke whips through the body. Stage 0 is the fin, 1 to 3 the joints behind to
## in front. The joints share it as the wave's envelope does.

var _yaw := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _pitch := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func weight(gait: Gait) -> float:
	return gait.rig_tail_drive


func reset() -> void:
	for i in 4:
		_yaw[i] = 0.0
		_pitch[i] = 0.0


func evaluate(rig: SwimRig, state: SwimState, gait: Gait, dt: float, pose: SwimPose) -> void:
	var w := gait.rig_tail_drive
	if dt > 0.0:
		var snap := 1.0 - exp(-gait.rig_tail_snap * dt)
		var follow := 1.0 - exp(-gait.rig_stride_follow * dt)
		var swing := state.stride_dir * gait.rig_stride_swing
		_yaw[0] += (swing.x - _yaw[0]) * snap
		_pitch[0] += (swing.y - _pitch[0]) * snap
		for i in range(1, 4):
			_yaw[i] += (_yaw[i - 1] - _yaw[i]) * follow
			_pitch[i] += (_pitch[i - 1] - _pitch[i]) * follow
	var total := 0.0
	for j in SwimPose.JOINTS:
		total += pow(j + 1.0, 2.0 * gait.rig_envelope)
	var yaw_sum := 0.0
	var pitch_sum := 0.0
	for j in SwimPose.JOINTS:
		var share := rig.bend_share * pow(j + 1.0, 2.0 * gait.rig_envelope) / total
		var stage := SwimPose.JOINTS - j  # the joint by the tail follows stage 1
		pose.joint_yaw[j] += w * share * _yaw[stage]
		pose.joint_pitch[j] += w * share * _pitch[stage]
		yaw_sum += share * _yaw[stage]
		pitch_sum += share * _pitch[stage]
	pose.tail_yaw += w * (_yaw[0] - yaw_sum)
	pose.tail_pitch += w * (_pitch[0] - pitch_sum)
