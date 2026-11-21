class_name RigTurn
extends RigLayer
## Turning (planning_core_roadmap.md 2.2), from the state's yaw rate: the spine
## curls into the turn (toward its inside) by the path's curvature, spin / max(speed,
## v0), over the bend's length; the body rolls into it (bank, + to the left, as a
## left turn has + yaw); the pectorals bank first on a quicker spring, the inside
## one tucking and the outside one reaching out.

var _bend := SpringChannel.new()
var _bank := SpringChannel.new()
var _fins := SpringChannel.new()


func weight(gait: Gait) -> float:
	return gait.rig_turn


func reset() -> void:
	_bend.reset()
	_bank.reset()
	_fins.reset()


func evaluate(rig: SwimRig, state: SwimState, gait: Gait, dt: float, pose: SwimPose) -> void:
	var w := gait.rig_turn
	var gate := clampf(state.speed / (gait.rig_turn_min_speed * 2.0), 0.0, 1.0)
	var curve := state.spin.y / maxf(state.speed, gait.rig_turn_min_speed)
	var bend := clampf(-curve * rig.span * gait.rig_turn_bend, -gait.rig_turn_max, gait.rig_turn_max)
	var turn := clampf(state.spin.y / gait.rig_turn_ref, -1.0, 1.0) * gate
	var curl := _bend.step(bend, gait.rig_turn_rate, dt)
	var roll := _bank.step(turn * gait.rig_bank, gait.rig_turn_rate, dt)
	var lead := _fins.step(turn, gait.rig_fin_rate, dt)
	for j in SwimPose.JOINTS:
		pose.joint_yaw[j] += w * curl / SwimPose.JOINTS
	pose.bank += w * roll
	var aileron := w * lead * gait.rig_fin_bank
	pose.fin_flap += Vector2(aileron, -aileron)
	var tuck := w * lead * gait.rig_fin_tuck
	pose.fin_sweep += Vector2(-tuck, tuck)
