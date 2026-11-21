class_name RigLegacy
extends RigLayer
## The controller's own tail pose (FishController._process: the swim stroke and
## the stride swing, written to the tail pivot) expressed as a layer: the pivot's
## swing as the controller left it goes on the spine as it always has (bend_share
## of it, shared evenly down the joints, an even arc) and the rest on the caudal
## fin. rig_legacy_tail 1 with the other layers off is today's pose exactly.


func weight(gait: Gait) -> float:
	return gait.rig_legacy_tail


func evaluate(rig: SwimRig, _state: SwimState, gait: Gait, _dt: float, pose: SwimPose) -> void:
	var w := gait.rig_legacy_tail
	var seen := rig.legacy_tail * w
	var share := rig.bend_share / SwimPose.JOINTS
	for j in SwimPose.JOINTS:
		pose.joint_pitch[j] += seen.x * share
		pose.joint_yaw[j] += seen.y * share
	pose.tail_pitch += seen.x * (1.0 - rig.bend_share)
	pose.tail_yaw += seen.y * (1.0 - rig.bend_share)
