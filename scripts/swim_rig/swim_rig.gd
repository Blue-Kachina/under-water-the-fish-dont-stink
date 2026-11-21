class_name SwimRig
extends Node
## The procedural animation rig (planning_core_roadmap.md 2.2): an ordered set of
## layers that read the SwimState and add into a SwimPose, which this carries to
## the model: the spine's joints and the head's counter-bend (the chain
## fish_bend.gdshaderinc already has for the Titans), the surge, the body's bank,
## the caudal fin and the pectoral pivots' wrappers. FishModel.react() steps it
## for a class whose Gait has procedural_rig on (the shark so far); it reads
## nothing but the state and the gait (no input, no TIME) and writes no physics.
##
## The controller still writes the tail pivot's own pose each frame; the rig
## reads it as the RigLegacy layer's input (rig_legacy_tail) and then writes the
## pivot itself, so it also knows when nothing rewrote the pivot since (a fish
## with no controller) and holds the pose it last saw.

var model: FishModel
var pose := SwimPose.new()
var layers: Array[RigLayer] = []
var engaged := false

## What the controller last wrote to the tail pivot (pitch x, yaw y).
var legacy_tail := Vector2.ZERO
## The body's length (m) and the span its chain bends over.
var length := 1.0
var span := 1.0
var bend_share := 0.65
## Undulation's clock and its rate (Hz), kept here so a probe and the shaders can read them.
var wave_phase := 0.0
var wave_freq := 0.0

var _written := Vector3(INF, INF, INF)
var _wrappers: Array[Node3D] = []


func _init() -> void:
	name = "SwimRig"
	layers.append(RigLegacy.new())
	for layer_class: Variant in _later_layers():
		layers.append((layer_class as GDScript).new() as RigLayer)


## The layers after the legacy pose, in order (later steps add theirs).
static func _later_layers() -> Array:
	return [RigUndulation, RigTailDrive, RigTurn, RigAccel, RigDrift]


func attach(m: FishModel) -> void:
	model = m
	bend_share = m.bend_share
	length = m._size.z
	span = maxf(m._bend_span.y - m._bend_span.x, 0.01)


## Poses the model for a frame of `dt` s.
func step(dt: float, state: SwimState, gait: Gait) -> void:
	if model == null or model.tail == null:
		return
	if not engaged:
		_engage()
	var tail := model.tail
	if not tail.rotation.is_equal_approx(_written):
		legacy_tail = Vector2(tail.rotation.x, tail.rotation.y)
	pose.clear()
	for layer in layers:
		if layer.weight(gait) != 0.0:
			layer.evaluate(self, state, gait, dt, pose)
		elif dt > 0.0:
			layer.reset()
	pose.wave_phase = wave_phase
	_apply(gait)


func _engage() -> void:
	engaged = true
	model._rig_chain = true
	model._segments = SwimPose.JOINTS
	_make_wrappers()


## The fins' pivots belong to the controller (it eases their sweep from where it
## stands), so the rig turns a wrapper inside each, holding the fin's meshes.
func _make_wrappers() -> void:
	if not _wrappers.is_empty():
		return
	for pivot: Node3D in [model.fin_left, model.fin_right]:
		var wrapper := Node3D.new()
		wrapper.name = "RigFin"
		for child in pivot.get_children():
			pivot.remove_child(child)
			wrapper.add_child(child)
		pivot.add_child(wrapper)
		_wrappers.append(wrapper)


func _apply(gait: Gait) -> void:
	var m := model
	for j in SwimPose.JOINTS:
		m._bend_turns[j] = Vector3(pose.joint_pitch[j], pose.joint_yaw[j], 0.0)
	m.head_span = gait.rig_head_span * length
	m._bend_head = Vector3(pose.head_pitch, pose.head_yaw, 0.0)
	m._surge = pose.surge
	m.tail.rotation = Vector3(pose.spine_pitch() + pose.tail_pitch, pose.spine_yaw() + pose.tail_yaw, 0.0)
	_written = m.tail.rotation
	m.rotation.z = pose.bank
	if _wrappers.size() == 2:
		_wrappers[0].rotation = Vector3(pose.fin_pitch.x, pose.fin_sweep.x, pose.fin_flap.x)
		_wrappers[1].rotation = Vector3(pose.fin_pitch.y, -pose.fin_sweep.y, -pose.fin_flap.y)


## The toggle went off: the model goes back to its own bend.
func release() -> void:
	if not engaged:
		return
	engaged = false
	var m := model
	m._rig_chain = false
	m._segments = 1
	m.head_span = 0.0
	m._bend_head = Vector3.ZERO
	m._surge = 0.0
	for j in 3:
		m._bend_turns[j] = Vector3.ZERO
	for part in m._bent:
		part.set_instance_shader_parameter("bend_turn2", Vector3.ZERO)
		part.set_instance_shader_parameter("bend_turn3", Vector3.ZERO)
		part.set_instance_shader_parameter("bend_head", Vector4.ZERO)
		part.set_instance_shader_parameter("bend_shape", Vector2.ZERO)
	m.rotation.z = 0.0
	for wrapper in _wrappers:
		wrapper.rotation = Vector3.ZERO
	_written = Vector3(INF, INF, INF)
	for layer in layers:
		layer.reset()
