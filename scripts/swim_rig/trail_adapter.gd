class_name TrailAdapter
extends RefCounted
## Hunter forms and bosses that lay a long body along the trail their head leaves (King, Lamprey, Angel, Gulper, Lantern)
## each kept their own speed estimate and wave clock (planning_core_roadmap.md 2.4). Behind Gait.trail_rig this
## adapter gives them the shared ones instead: the speed and the turn come from the fish's SwimState (the one thing the
## animation reads), the wave clock is one object here, and, when Gait.trail_pose is above 0, the SwimRig layers (its
## undulation, turn and acceleration) are evaluated headless and carried onto the spine's points as bends on top of the
## trail (SwimPose -> spine points). The trail itself stays the form's: it is the path-following part of a long body,
## which is what the Turn layer does for a short one. AttackExaggerate stays a separate layer the forms apply after.
##
## Off (the default) no TrailAdapter is made: `sync` returns null and the form runs the code it always had.

var fish: FishController
## The speed (m/s), smoothed like the forms' own (8/s), and the turn (0..1 of 1.5 rad/s) of the SwimState.
var speed := 0.0
var turn := 0.0
## The wave clock (rad), the form's stroke rate advanced by `advance`.
var clock := 0.0
## The rig's pose after `bend` (zero when trail_pose is 0).
var pose: SwimPose
var _rig: SwimRig
var _fresh := true


func _init(with_fish: FishController) -> void:
	fish = with_fish


## The adapter a form should use now: `current` made, kept or dropped as the fish's gait says.
static func sync(current: TrailAdapter, with_fish: FishController) -> TrailAdapter:
	var on := is_instance_valid(with_fish) and with_fish.gait != null and with_fish.gait.trail_rig
	if on and current == null:
		return TrailAdapter.new(with_fish)
	if not on and current != null:
		current.release()
		return null
	return current


## Reads the state for a frame of `dt` s. `seed_speed` is the form's own estimate, so a switch on mid-swim does not jump.
func update(dt: float, seed_speed := 0.0) -> void:
	var state := fish.swim_state
	if _fresh:
		_fresh = false
		speed = seed_speed
	if dt > 0.0:
		speed = lerpf(speed, state.speed, 1.0 - exp(-8.0 * dt))
	turn = clampf(absf(state.spin.y) / 1.5, 0.0, 1.0)


## `speed` as a share of `reference` m/s, 0..1.
func speed_t(reference: float) -> float:
	return clampf(speed / maxf(reference, 0.1), 0.0, 1.0)


## Advances the wave clock at `rate` rad/s and returns it, so a change of rate never jumps the phase.
func advance(dt: float, rate: float) -> float:
	clock = fposmod(clock + dt * rate, TAU)
	return clock


## Evaluates the rig's layers for the fish and bends `spine`'s points by their pose, `weight` (Gait.trail_pose) of it.
## `body_length` is the body's length in metres. Does nothing at weight 0.
func bend(spine: SpineRig, dt: float, body_length: float) -> void:
	var gait := fish.gait
	var w := gait.trail_pose if gait != null else 0.0
	if w <= 0.0:
		if pose != null:
			pose.clear()
		return
	if _rig == null:
		_rig = SwimRig.new()
		pose = _rig.pose
	_rig.step_bare(dt, fish.swim_state, gait, body_length)
	pose_to_points(spine, pose, w)


## The pose's spine joints (each turning its third of the body, chained: the angle at a point is the sum of the
## joints' turns so far) as bends of the spine's segments: yaw about the
## head's up, pitch about its right (the head's counter-bend is not carried: the trail's head is the fish's). Points keep their spacing; the frames
## are recomputed. `weight` scales the angles.
static func pose_to_points(spine: SpineRig, with_pose: SwimPose, weight: float) -> void:
	var n := SpineRig.SPINE_N
	var from := spine.points.duplicate()
	var yaw_axis := spine.ups[0]
	var pitch_axis := spine.rights[0]
	var third := float(n - 1) / SwimPose.JOINTS
	for s in range(1, n):
		var yaw := 0.0
		var pitch := 0.0
		for j in SwimPose.JOINTS:
			var share := clampf(float(s) / third - j, 0.0, 1.0)
			yaw += with_pose.joint_yaw[j] * share
			pitch += with_pose.joint_pitch[j] * share
		var step := from[s] - from[s - 1]
		step = step.rotated(yaw_axis, yaw * weight).rotated(pitch_axis, -pitch * weight)
		spine.points[s] = spine.points[s - 1] + step
	spine.call("_frames")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rig != null and is_instance_valid(_rig):
		_rig.free()


## Frees the headless rig.
func release() -> void:
	if _rig != null:
		_rig.free()
		_rig = null
	pose = null
