class_name SwimPose
extends RefCounted
## The channels a SwimRig's layers add into each frame (planning_core_roadmap.md
## 2.2): plain numbers, preallocated and cleared, never reallocated. Angles are
## radians. Signs follow the shader and the pivots: a joint's pitch + x tips the
## tail end down, its yaw + y swings it toward +X (the fish's right); the head's
## pitch + lifts the nose; bank + rolls the fish to its left (left side down);
## fin sweep + flares a fin out, fin flap + lowers it, on both sides alike, and
## fin pitch + turns the leading edge up.

const JOINTS := 3

## Each spine joint's turn (they chain, tail end last; FishModel's _bend_turns).
var joint_yaw := PackedFloat32Array([0.0, 0.0, 0.0])
var joint_pitch := PackedFloat32Array([0.0, 0.0, 0.0])
## The head bending the other way in front of the chain.
var head_yaw := 0.0
var head_pitch := 0.0
## The whole body shifted along its nose (m, + forward).
var surge := 0.0
## The body rolling (rad, + banks to the left).
var bank := 0.0
## The caudal fin's own turn on top of the spine's end (the pivot's orientation is
## the joints' sum plus this).
var tail_yaw := 0.0
var tail_pitch := 0.0
## Pectorals, (left, right).
var fin_sweep := Vector2.ZERO
var fin_flap := Vector2.ZERO
var fin_pitch := Vector2.ZERO
## For the shaders: how deep the wave runs now (0..1) and its phase.
var wave_amp := 0.0
var wave_phase := 0.0
## The fin pivots' own roll (left, right; + lowers the fin, as fin_flap): the flap and reverse flutter
## (Gait.rig_bell_flap), written to the pivots themselves, where the sea hare's flaps and the ray's wings read it.
var pivot_roll := Vector2.ZERO
## A jelly's bell (BellPulse): crown, margin, ripple and the ripple's phase, and the stroke's squeeze and flatten, as its
## shaders take them (Gait.rig_bell_flap). Plain floats, so they reach the shaders at full precision.
var bell_crown := 0.0
var bell_margin := 0.0
var bell_ripple := 0.0
var bell_ripple_phase := 0.0
var bell_squeeze := 1.0
var bell_flatten := 1.0


func clear() -> void:
	for j in JOINTS:
		joint_yaw[j] = 0.0
		joint_pitch[j] = 0.0
	head_yaw = 0.0
	head_pitch = 0.0
	surge = 0.0
	bank = 0.0
	tail_yaw = 0.0
	tail_pitch = 0.0
	fin_sweep = Vector2.ZERO
	fin_flap = Vector2.ZERO
	fin_pitch = Vector2.ZERO
	wave_amp = 0.0
	wave_phase = 0.0
	pivot_roll = Vector2.ZERO
	bell_crown = 0.0
	bell_margin = 0.0
	bell_ripple = 0.0
	bell_ripple_phase = 0.0
	bell_squeeze = 1.0
	bell_flatten = 1.0


## The spine's end turn: the sum of the joints.
func spine_yaw() -> float:
	return joint_yaw[0] + joint_yaw[1] + joint_yaw[2]


func spine_pitch() -> float:
	return joint_pitch[0] + joint_pitch[1] + joint_pitch[2]


func is_finite_pose() -> bool:
	for j in JOINTS:
		if not (is_finite(joint_yaw[j]) and is_finite(joint_pitch[j])):
			return false
	for v: float in [head_yaw, head_pitch, surge, bank, tail_yaw, tail_pitch, fin_sweep.x, fin_sweep.y,
			fin_flap.x, fin_flap.y, fin_pitch.x, fin_pitch.y, wave_amp, wave_phase, pivot_roll.x, pivot_roll.y,
			bell_crown, bell_margin, bell_ripple, bell_ripple_phase, bell_squeeze, bell_flatten]:
		if not is_finite(v):
			return false
	return true
