class_name OctopusModel
extends Node3D
## The Ember Octopus's body (planning_new_hunters.md phase C1): a skinned loft
## model, built in code like the koi and the jelly. One bulbous mantle + head
## surface, eight tapering arms along curled splines (14 bones each, three
## rings per bone so the bend is smooth), a web between each pair of arm
## bases, two rows of suckers on every arm, slit-pupil eyes and a siphon.
## Skinned on one Skeleton3D (118 bones), so rigs pose bones, not meshes.
## The public API (bones, joints, pose setters, shader uniforms) is
## `octopus_contract.md`; the skin is `shaders/octopus_skin.gdshader`.
## -Z is the direction of travel and the mantle leads (as a real octopus jets):
## the head and eyes behind it, the arms trailing along +Z in a flat swept-back
## delta (octopus_formation.png) with the web between their bases as the wing.

const ARMS := 8
const SEGMENTS := 14
const SUB := 3  # rings per bone along an arm
const MANTLE_BONES := 4
const AROUND_BODY := 40
const AROUND_ARM := 14
const ROOT_BONE := 0
const HEAD_BONE := 1
const FIRST_MANTLE := 2
const FIRST_ARM := 6

const SKIN_SHADER := preload("res://shaders/octopus_skin.gdshader")

# Design units (the head centre is the origin; scaled to metres by `unit`).
# The mantle LEADS (-Z, the travel direction); the arms trail along +Z in a flat, swept-back delta.
const MANTLE_END := -0.56  ## the mantle tip, ahead of the head
const ARM_LENGTH := 0.86
const ARM_RADIUS := 0.042
## The arm bases sit on a flat ellipse round the crown (wide in X, thin in Y), a little behind the head centre and inside the body.
const ARM_BASE_RX := 0.058
const ARM_BASE_RY := 0.036
const ARM_BASE_Z := 0.072
## Each arm's fan angle in the delta (degrees, toward +X), by arm: the dorsal arms 0-3 and the ventral arms 4-7 interleave.
const ARM_FAN := [56.0, 20.0, -20.0, -56.0, -40.0, -7.0, 7.0, 40.0]
const MANTLE_Z := [-0.10, -0.22, -0.34, -0.46]
const MANTLE_PROFILE := [0.55, 0.9, 1.0, 0.75]  # how much each mantle bone swells with the pulse
## Radius of the head and mantle along zz = -z (toward the mantle tip): [zz, radius]. Hermite through these,
## flat (zero slope) at both ends where the caps join. The first key is the crown (the arms' side), the last the mantle's widest.
const BODY_KEYS := [
	[-0.10, 0.074], [-0.06, 0.094], [-0.02, 0.1], [0.02, 0.097], [0.065, 0.088], [0.12, 0.102],
	[0.19, 0.128], [0.26, 0.146], [0.33, 0.154], [0.38, 0.152],
]
const FRONT_CAP := 0.045  ## the crown's cap behind the head (toward +Z), hidden in the arm roots and the web
const REAR_TAIL := -MANTLE_END - 0.38  ## the mantle's end is an analytic bulb: r = r0 * (1 - t^2.2)^0.55
const CROWN_END := 0.10 + FRONT_CAP  ## z of the crown's pole
const BODY_U_HEAD := 0.45  # body_u at the crown, tip of the mantle is 0, the arm tips 1

## Set by build().
var length_m := 1.0
var unit := 1.0  ## metres per design unit
var skeleton: Skeleton3D
var head_bone := HEAD_BONE
var root_bone := ROOT_BONE
var mantle_bones := PackedInt32Array()
var arm_bones: Array = []  ## 8 PackedInt32Array of 14 bone indices: arm_bones[arm][segment]
var arm_tips: Array[Node3D] = []
var eyes: Array[MeshInstance3D] = []
var siphon: Node3D
var siphon_mouth: Marker3D
var body_mesh: MeshInstance3D
var web_mesh: MeshInstance3D
var sucker_mesh: MeshInstance3D
var sucker_mesh_lo: MeshInstance3D
var sucker_range_lengths := 7.0:  ## suckers vanish past this many body lengths (0 = never)
	set(v):
		sucker_range_lengths = v
		_apply_sucker_ranges()
var sucker_hi_range_lengths := 3.0:  ## the full-detail suckers swap for the cheap ones past this
	set(v):
		sucker_hi_range_lengths = v
		_apply_sucker_ranges()
var materials: Array[ShaderMaterial] = []

var _arm_rest_joints: Array[PackedVector3Array] = []
var _arm_dense: Array[PackedVector3Array] = []  # rest centre line, SEGMENTS * SUB + 1 points, metres
var _arm_radii: Array[PackedFloat32Array] = []
var _arm_frames: Array = []  # per arm: Array[Basis], one per bone
var _arm_tip_offset: Array[Vector3] = []  # bone-local offset of the tip from the last bone
var _arm_len: Array[float] = []
var _arm_seg_len: Array[PackedFloat32Array] = []
var _rest_q: Array[Quaternion] = []
var _pose_cache: Array[Vector3] = []
var _arm_glow_a := Vector4.ZERO
var _arm_glow_b := Vector4.ZERO
var _siphon_rest := Basis.IDENTITY
var _mantle_pulse := 0.0
var _mantle_pop := 0.0
var _mantle_bend := Vector2.ZERO
var _seed := 7
var _bone_count := 0


static func build(length: float = 1.0, seed_value: int = 7) -> OctopusModel:
	var model := OctopusModel.new()
	model.name = "OctopusModel"
	model._construct(maxf(length, 0.01), seed_value)
	return model


static func arm_angle(arm: int) -> float:
	return deg_to_rad(22.5 + 45.0 * float(arm))


static func arm_side(arm: int) -> int:
	return 1 if cos(arm_angle(arm)) >= 0.0 else -1


static func arm_radial(arm: int) -> Vector3:
	var a := arm_angle(arm)
	return Vector3(cos(a), sin(a), 0.0)


# ---------------------------------------------------------------- the pose API

## Per-segment bends for one arm: Vector3(pitch, yaw, twist) in radians,
## relative to the rest pose, in each bone's own axes (octopus_contract.md).
func set_arm_pose(arm: int, bends: PackedVector3Array) -> void:
	var bones: PackedInt32Array = arm_bones[arm]
	for j in SEGMENTS:
		_pose_bone(bones[j], bends[j] if j < bends.size() else Vector3.ZERO)


func set_arm_bend(arm: int, seg: int, pitch: float, yaw: float, twist: float = 0.0) -> void:
	var bones: PackedInt32Array = arm_bones[arm]
	_pose_bone(bones[seg], Vector3(pitch, yaw, twist))


func clear_arm_pose(arm: int = -1) -> void:
	for a in ARMS:
		if arm >= 0 and a != arm:
			continue
		var bones: PackedInt32Array = arm_bones[a]
		for j in SEGMENTS:
			_pose_bone(bones[j], Vector3.ZERO)


## The stride's exaggeration on the mantle (-1 thin .. 0 none .. +1 swollen): swells the bones' radius on top of the pulse, up to 45% at
## 1. Takes effect with the next set_mantle_pulse (the rig calls it every frame).
func set_mantle_pop(p: float) -> void:
	_mantle_pop = clampf(p, -1.0, 1.0)


## -1 inflated .. 0 rest .. +1 contracted. Swells the mantle bones' radius
## (compensated down the chain so each bone's scale is its own).
func set_mantle_pulse(p: float) -> void:
	p = clampf(p, -1.0, 1.0)
	_mantle_pulse = p
	var previous := 1.0
	for k in MANTLE_BONES:
		var amount := 0.24 * p if p > 0.0 else 0.14 * p
		var target := (1.0 - amount * float(MANTLE_PROFILE[k])) * (1.0 + 0.45 * _mantle_pop * float(MANTLE_PROFILE[k]))
		var local := target / previous
		skeleton.set_bone_pose_scale(mantle_bones[k], Vector3(local, local, 1.0))
		previous = target
	set_param("mantle_pulse", p)


func set_mantle_bend(yaw: float, pitch: float) -> void:
	_mantle_bend = Vector2(yaw, pitch)
	for k in MANTLE_BONES:
		_pose_bone(mantle_bones[k], Vector3(pitch / MANTLE_BONES, yaw / MANTLE_BONES, 0.0))


func set_mantle_pose(bends: PackedVector3Array) -> void:
	for k in MANTLE_BONES:
		_pose_bone(mantle_bones[k], bends[k] if k < bends.size() else Vector3.ZERO)


func set_head_basis(b: Basis) -> void:
	skeleton.set_bone_pose_rotation(HEAD_BONE, _rest_q[HEAD_BONE] * b.get_rotation_quaternion())


func set_siphon_aim(yaw: float, pitch: float) -> void:
	siphon.basis = _siphon_rest * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)


func reset_pose() -> void:
	for i in _bone_count:
		skeleton.set_bone_pose_rotation(i, _rest_q[i])
		_pose_cache[i] = Vector3.ZERO
	for k in MANTLE_BONES:
		skeleton.set_bone_pose_scale(mantle_bones[k], Vector3.ONE)
	_mantle_pulse = 0.0
	siphon.basis = _siphon_rest
	_arm_glow_a = Vector4.ZERO
	_arm_glow_b = Vector4.ZERO
	for name_ in ["mantle_pulse", "stroke", "charge", "flash", "hurt", "chroma_shift"]:
		set_param(name_, 0.0)
	set_param("vein_travel", -1.0)
	set_param("arm_glow_a", Vector4.ZERO)
	set_param("arm_glow_b", Vector4.ZERO)


## A lazy baseline driver (arm sway, the mantle breathing); an example of a
## rig and what the shot tool poses with. `amount` 0..1.
func idle_pose(t: float, amount: float = 1.0) -> void:
	for a in ARMS:
		var bends := PackedVector3Array()
		bends.resize(SEGMENTS)
		for j in SEGMENTS:
			var w := 0.35 + 1.25 * float(j) / float(SEGMENTS - 1)
			var ph := t * 1.05 + float(a) * 0.83 - float(j) * 0.42
			bends[j] = Vector3(0.011 * w * sin(ph + 1.3), 0.014 * w * sin(ph), 0.0) * amount
		set_arm_pose(a, bends)
	set_mantle_pulse(0.22 * sin(t * 1.4) * amount)
	set_mantle_bend(0.14 * sin(t * 0.55) * amount, 0.07 * sin(t * 0.42 + 1.0) * amount)


# ------------------------------------------------------------------ read-back

func arm_rest_joints(arm: int) -> PackedVector3Array:
	return _arm_rest_joints[arm]


## SEGMENTS + 1 points in the current pose: bone origins, then the tip.
func arm_joints(arm: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var bones: PackedInt32Array = arm_bones[arm]
	for j in SEGMENTS:
		out.append(skeleton.get_bone_global_pose(bones[j]).origin)
	out.append(arm_tip_local(arm))
	return out


func arm_tip_local(arm: int) -> Vector3:
	var bones: PackedInt32Array = arm_bones[arm]
	var last: Transform3D = skeleton.get_bone_global_pose(bones[SEGMENTS - 1])
	return last * _arm_tip_offset[arm]


func arm_tip_global(arm: int) -> Vector3:
	return global_transform * arm_tip_local(arm)


func arm_bone_transform(arm: int, seg: int) -> Transform3D:
	var bones: PackedInt32Array = arm_bones[arm]
	return skeleton.get_bone_global_pose(bones[seg])


func arm_segment_length(arm: int, seg: int) -> float:
	return _arm_seg_len[arm][seg]


func arm_length(arm: int) -> float:
	return _arm_len[arm]


func siphon_exhaust_dir() -> Vector3:
	var head: Transform3D = skeleton.get_bone_global_pose(HEAD_BONE)
	return (head.basis * siphon.basis.z).normalized()


func siphon_mouth_local() -> Vector3:
	var head: Transform3D = skeleton.get_bone_global_pose(HEAD_BONE)
	return head * (siphon.transform * siphon_mouth.position)


func mouth_local() -> Vector3:
	var head: Transform3D = skeleton.get_bone_global_pose(HEAD_BONE)
	return head * Vector3(0.0, -0.004, 0.11) * unit


func mantle_tip_local() -> Vector3:
	var last: Transform3D = skeleton.get_bone_global_pose(mantle_bones[MANTLE_BONES - 1])
	return last * Vector3(0.0, 0.0, (MANTLE_END - float(MANTLE_Z[MANTLE_BONES - 1])) * unit)


## Hides the suckers and webs (far bots, shadow-only passes).
func _apply_sucker_ranges() -> void:
	if sucker_mesh == null:
		return
	var hi_end := sucker_hi_range_lengths * length_m
	var far := sucker_range_lengths * length_m if sucker_range_lengths > 0.0 else 0.0
	sucker_mesh.visibility_range_end = hi_end if hi_end > 0.0 else 0.0
	sucker_mesh_lo.visibility_range_begin = hi_end
	sucker_mesh_lo.visibility_range_end = far
	sucker_mesh_lo.visible = hi_end > 0.0


func set_detail(on: bool) -> void:
	sucker_mesh.visible = on
	sucker_mesh_lo.visible = on and sucker_hi_range_lengths > 0.0
	web_mesh.visible = on


# ------------------------------------------------------------- shader uniforms

func set_param(param: StringName, value: Variant) -> void:
	for m in materials:
		m.set_shader_parameter(param, value)


func set_charge(c: float) -> void:
	set_param("charge", clampf(c, 0.0, 1.0))


func set_stroke(s: float) -> void:
	set_param("stroke", clampf(s, 0.0, 1.0))


func set_vein_travel(t: float) -> void:
	set_param("vein_travel", t)


func set_glow(g: float) -> void:
	set_param("glow", g)


func set_flash(f: float) -> void:
	set_param("flash", clampf(f, 0.0, 1.0))


func set_chroma_shift(x: float) -> void:
	set_param("chroma_shift", clampf(x, -1.0, 1.0))


func set_sucker_glow(g: float) -> void:
	set_param("sucker_glow", g)


func set_eye_glow(g: float) -> void:
	set_param("eye_glow", g)


func set_arm_glow(arm: int, g: float) -> void:
	if arm < 4:
		_arm_glow_a[arm] = g
		set_param("arm_glow_a", _arm_glow_a)
	else:
		_arm_glow_b[arm - 4] = g
		set_param("arm_glow_b", _arm_glow_b)


func _pose_bone(idx: int, b: Vector3) -> void:
	if _pose_cache[idx] == b:
		return
	_pose_cache[idx] = b
	var q := Quaternion(Vector3.UP, b.y) * Quaternion(Vector3.RIGHT, b.x) * Quaternion(Vector3.BACK, b.z)
	skeleton.set_bone_pose_rotation(idx, _rest_q[idx] * q)


# ---------------------------------------------------------------- construction

func _construct(length: float, seed_value: int) -> void:
	_seed = seed_value
	set_meta("hunter_octopus", true)
	var arms: Array[Dictionary] = []
	var max_z := CROWN_END
	for a in ARMS:
		var d := _design_arm(a)
		arms.append(d)
		for p: Vector3 in d["pts"]:
			max_z = maxf(max_z, p.z)
	var extent := max_z - MANTLE_END
	unit = length / extent
	length_m = length
	_make_materials()
	set_param("unit_m", unit)
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	_build_skeleton(arms)
	body_mesh = _mesh_instance("Body", _build_body(arms), materials[0])
	var web_buf := _Buf.new()
	for a in ARMS:
		_add_web(web_buf, arms, a)
	web_mesh = _mesh_instance("Web", web_buf.to_mesh(true), materials[1])
	sucker_mesh = _mesh_instance("Suckers", _build_suckers(arms, true), materials[2])
	sucker_mesh_lo = _mesh_instance("SuckersLo", _build_suckers(arms, false), materials[2])
	for mi in [sucker_mesh, sucker_mesh_lo]:
		mi.visibility_range_begin_margin = 0.5 * length_m
		mi.visibility_range_end_margin = 0.5 * length_m
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_apply_sucker_ranges()
	_build_head_parts()
	_build_tip_nodes()
	skeleton.reset_bone_poses()
	for a in ARMS:
		_arm_len.append(_arm_len_of(a))


func _arm_len_of(a: int) -> float:
	var total := 0.0
	for s in _arm_seg_len[a]:
		total += s
	return total


func _make_materials() -> void:
	for mode in 4:
		var m := ShaderMaterial.new()
		m.shader = SKIN_SHADER
		m.set_shader_parameter("mode", mode)
		materials.append(m)  # 0 skin, 1 web, 2 sucker, 3 eye


func _mesh_instance(node_name: String, mesh: ArrayMesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.skin = skeleton.create_skin_from_rest_transforms()
	mi.skeleton = NodePath("..")
	mi.extra_cull_margin = length_m * 2.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	skeleton.add_child(mi)
	return mi


## One arm's rest curve in design units: from its base on the crown's flat
## ellipse it fans out at its delta angle, sweeps back toward the axis along
## its length, settles toward the delta's mid plane and curls its tip toward
## its sucker side (inward), a little differently per arm.
func _design_arm(a: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 7919 + a * 104729
	var phi := arm_angle(a)
	var base := Vector3(cos(phi) * ARM_BASE_RX, sin(phi) * ARM_BASE_RY, ARM_BASE_Z)
	# the sucker side: the outer arms' faces the delta's centre line, sideways in the wing's plane (a touch down), so their tips curl
	# in that plane; the inner arms' faces down (the wing's underside), so the dorsal and ventral layers never cross
	var outer := absf(cos(phi)) > 0.7
	var inward := Vector3(-signf(base.x), -0.25, 0.0).normalized() if outer else Vector3(-signf(base.x) * 0.35, -1.0, 0.0).normalized()
	var pair: float = [1.0, 1.04, 1.04, 1.0, 0.94, 0.9, 0.9, 0.94][a]
	var length: float = ARM_LENGTH * pair * (1.0 + 0.05 * rng.randf_range(-1.0, 1.0))
	var theta0 := deg_to_rad(float(ARM_FAN[a]) + rng.randf_range(-2.5, 2.5))
	var sweep := 0.2 + 0.12 * rng.randf()
	var curl := deg_to_rad(35.0 + 40.0 * rng.randf()) * (1.0 if outer else 0.45)
	var wob := deg_to_rad(4.0 + 5.0 * rng.randf())
	var wob_phase := rng.randf() * TAU
	var wob_freq := 0.9 + 0.5 * rng.randf()
	var m := SEGMENTS * SUB
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var frames: Array[Basis] = []
	var pos := base
	var tangent_prev := Vector3.ZERO
	var normal := Vector3.ZERO
	var ds := 1.0 / float(m)
	for i in m + 1:
		var s := float(i) / float(m)
		var theta := theta0 * (1.0 - sweep * pow(s, 1.3)) + wob * sin(TAU * wob_freq * s + wob_phase) * s
		# the dorsal and ventral layers close toward the delta's mid plane (a thin wing), then run level
		var y_now := base.y * (0.3 + 0.7 * pow(1.0 - s, 2.0))
		var y_next := base.y * (0.3 + 0.7 * pow(maxf(1.0 - s - ds, 0.0), 2.0))
		var slope := (y_next - y_now) / (length * ds)
		var d := Vector3(sin(theta), slope, cos(theta)).normalized()
		# the tip curls toward the sucker side (the transported oral normal)
		var oral := inward if i == 0 else normal
		oral = (oral - d * oral.dot(d)).normalized()
		var beta := curl * pow(s, 3.2)
		d = (d * cos(beta) + oral * sin(beta)).normalized()
		if i == 0:
			normal = (inward - d * inward.dot(d)).normalized()
		else:
			var q := Quaternion(tangent_prev, d)
			normal = q * normal
			normal = (normal - d * normal.dot(d)).normalized()
		var z := -d
		var y := normal
		var x := y.cross(z).normalized()
		frames.append(Basis(x, y, z))
		pts.append(pos)
		radii.append(_arm_radius(s))
		tangent_prev = d
		pos += d * length / float(m)
	return {"pts": pts, "radii": radii, "frames": frames, "length": length, "phi": phi}


static func _arm_radius(s: float) -> float:
	return ARM_RADIUS * (0.12 + 0.88 * pow(1.0 - s, 0.85)) * (1.0 + 0.32 * exp(-s * 9.0))


## Body radius at zz = -z (positive toward the mantle tip).
static func _body_radius(z: float) -> float:
	var keys := BODY_KEYS
	var n := keys.size()
	if z <= float(keys[0][0]):
		return float(keys[0][1])
	if z >= float(keys[n - 1][0]):
		return float(keys[n - 1][1])
	var i := 0
	while float(keys[i + 1][0]) < z:
		i += 1
	var z0 := float(keys[i][0])
	var z1 := float(keys[i + 1][0])
	var r0 := float(keys[i][1])
	var r1 := float(keys[i + 1][1])
	var m0 := 0.0
	var m1 := 0.0
	if i > 0:
		m0 = (r1 - float(keys[i - 1][1])) / (z1 - float(keys[i - 1][0]))
	if i + 2 < n:
		m1 = (float(keys[i + 2][1]) - r0) / (float(keys[i + 2][0]) - z0)
	var h := z1 - z0
	var t := (z - z0) / h
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * r0 + (t3 - 2.0 * t2 + t) * h * m0 + (-2.0 * t3 + 3.0 * t2) * r1 + (t3 - t2) * h * m1


## The body's centre line height at z: the mantle lifts a little toward its tip.
static func _centre_y(z: float) -> float:
	var f := clampf((-z - 0.1) / 0.46, 0.0, 1.0)
	return 0.022 * f * f


## The crown behind the head flattens into the delta's root: (x, y) scale of the body's cross-section at z.
static func _section_scale(z: float) -> Vector2:
	var c := smoothstep(-0.01, 0.1, z)
	return Vector2(1.0 + 0.26 * c, 1.0 - 0.24 * c)


static func _body_u(z: float) -> float:
	return BODY_U_HEAD * (z - MANTLE_END) / (CROWN_END - MANTLE_END)


func _build_skeleton(arms: Array[Dictionary]) -> void:
	var globals: Array[Transform3D] = []
	var parents: Array[int] = []
	var names: Array[String] = []
	var add := func(n: String, parent: int, g: Transform3D) -> int:
		names.append(n)
		parents.append(parent)
		globals.append(g)
		return names.size() - 1
	add.call("root", -1, Transform3D.IDENTITY)
	add.call("head", ROOT_BONE, Transform3D.IDENTITY)
	mantle_bones.clear()
	var prev := ROOT_BONE
	for k in MANTLE_BONES:
		var z: float = MANTLE_Z[k]
		prev = add.call("mantle_%d" % k, prev, Transform3D(Basis.IDENTITY, Vector3(0.0, _centre_y(z), z) * unit))
		mantle_bones.append(prev)
	arm_bones.clear()
	_arm_frames.clear()
	for a in ARMS:
		var d: Dictionary = arms[a]
		var pts: PackedVector3Array = d["pts"]
		var frames: Array[Basis] = d["frames"]
		var chain := PackedInt32Array()
		var fr: Array[Basis] = []
		var parent := HEAD_BONE
		for j in SEGMENTS:
			var idx: int = add.call("arm%d_%d" % [a, j], parent, Transform3D(frames[j * SUB], pts[j * SUB] * unit))
			chain.append(idx)
			fr.append(frames[j * SUB])
			parent = idx
		arm_bones.append(chain)
		_arm_frames.append(fr)
		# Rest joints in metres, and the tip's offset in the last bone's frame.
		var joints := PackedVector3Array()
		var seg_len := PackedFloat32Array()
		for j in SEGMENTS + 1:
			joints.append(pts[j * SUB] * unit)
		for j in SEGMENTS:
			var chord := 0.0
			for q in SUB:
				chord += (pts[j * SUB + q + 1] - pts[j * SUB + q]).length()
			seg_len.append(chord * unit)
		_arm_rest_joints.append(joints)
		_arm_seg_len.append(seg_len)
		var dense := PackedVector3Array()
		var radii := PackedFloat32Array()
		for i in pts.size():
			dense.append(pts[i] * unit)
			radii.append(float(d["radii"][i]) * unit)
		_arm_dense.append(dense)
		_arm_radii.append(radii)
		var last: Transform3D = globals[chain[SEGMENTS - 1]]
		_arm_tip_offset.append(last.affine_inverse() * (pts[SEGMENTS * SUB] * unit))
	_bone_count = names.size()
	for i in _bone_count:
		skeleton.add_bone(names[i])
	for i in _bone_count:
		skeleton.set_bone_parent(i, parents[i])
	for i in _bone_count:
		var local: Transform3D = globals[i] if parents[i] < 0 else globals[parents[i]].affine_inverse() * globals[i]
		skeleton.set_bone_rest(i, local)
		_rest_q.append(local.basis.get_rotation_quaternion())
		_pose_cache.append(Vector3.ZERO)
	skeleton.reset_bone_poses()


# --------------------------------------------------------------- body surface

## Skin weights of a body ring at z: the head and crown on the head bone, blending into the mantle chain toward the tip.
func _body_weights(z: float) -> Array:
	var zz := -z
	var z0: float = -float(MANTLE_Z[0])
	if zz <= 0.015:
		return [[HEAD_BONE, 0, 0, 0], [1.0, 0.0, 0.0, 0.0]]
	if zz < z0:
		var t := smoothstep(0.015, z0 + 0.02, zz)
		return [[HEAD_BONE, mantle_bones[0], 0, 0], [1.0 - t, t, 0.0, 0.0]]
	for k in MANTLE_BONES - 1:
		var a: float = -float(MANTLE_Z[k])
		var b: float = -float(MANTLE_Z[k + 1])
		if zz < b:
			var t := smoothstep(a, b, zz)
			return [[mantle_bones[k], mantle_bones[k + 1], 0, 0], [1.0 - t, t, 0.0, 0.0]]
	return [[mantle_bones[MANTLE_BONES - 1], 0, 0, 0], [1.0, 0.0, 0.0, 0.0]]


func _build_body(arms: Array[Dictionary]) -> ArrayMesh:
	var buf := _Buf.new()
	# Rings along zz = -z: the crown's cap (behind the head), the spline, the mantle's bulb (ahead).
	var rings: Array[Vector2] = []  # zz, radius
	var front_z: float = BODY_KEYS[0][0]
	var rear_z: float = BODY_KEYS[BODY_KEYS.size() - 1][0]
	var front_r := _body_radius(front_z)
	var rear_r := _body_radius(rear_z)
	var cap_n := 7
	for k in range(cap_n, 0, -1):
		var th := (float(k) / cap_n) * PI * 0.5
		rings.append(Vector2(front_z - FRONT_CAP * sin(th), front_r * cos(th)))
	var z := front_z
	var step := 0.014
	while z < rear_z:
		rings.append(Vector2(z, _body_radius(z)))
		z += step
	rings.append(Vector2(rear_z, rear_r))
	var tail_n := 18
	for k in range(1, tail_n + 1):
		var t := 1.0 - pow(1.0 - float(k) / tail_n, 2.0)
		rings.append(Vector2(rear_z + REAR_TAIL * t, rear_r * pow(maxf(1.0 - pow(t, 2.2), 0.0), 0.55)))
	var rows := rings.size()
	var cols := AROUND_BODY
	var stride := cols + 1
	var pos := PackedVector3Array()
	var centres := PackedVector3Array()
	var colors := PackedColorArray()
	var custom := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for i in rows:
		var rz := -rings[i].x
		var rr := rings[i].y
		var cy := _centre_y(rz)
		var wb := _body_weights(rz)
		var sc := _section_scale(rz)
		var vein := 0.55 + 0.45 * smoothstep(0.05, 0.25, -rz)
		centres.append(Vector3(0.0, cy, rz) * unit)
		for k in stride:
			var th := TAU * float(k % cols) / float(cols)
			var rx := rr * sc.x
			var ry := rr * sc.y * (0.95 if -rz < 0.1 else 0.93)
			var p := Vector3(sin(th) * rx, cy + cos(th) * ry, rz)
			pos.append(p * unit)
			var belly := clampf(-cos(th) * 0.9 - 0.15, 0.0, 1.0) * 0.5
			colors.append(Color(vein * (1.0 - belly * 0.5), 0.0, 0.0, belly))
			custom.append_array([p.x, p.y, p.z, _body_u(rz)])
			for q in 4:
				bones.append(int(wb[0][q]))
				weights.append(float(wb[1][q]))
	buf.add_grid(pos, PackedVector3Array(), centres, rows, cols, colors, custom, bones, weights, true, false)
	for a in ARMS:
		_add_arm(buf, arms[a], a)
	return buf.to_mesh(true)


## Bone segments and weights for the ring at dense index `m` along an arm.
func _arm_weights(m: float) -> Array:
	var jf := m / float(SUB)
	var bj := int(floor(jf))
	if bj >= SEGMENTS - 1:
		return [[SEGMENTS - 1, SEGMENTS - 1, SEGMENTS - 1, SEGMENTS - 1], [1.0, 0.0, 0.0, 0.0]]
	var t := smoothstep(0.0, 1.0, jf - float(bj))
	return [[bj, bj + 1, bj, bj], [1.0 - t, t, 0.0, 0.0]]


func _add_arm(buf: _Buf, d: Dictionary, a: int) -> void:
	var pts: PackedVector3Array = d["pts"]
	var radii: PackedFloat32Array = d["radii"]
	var frames: Array[Basis] = d["frames"]
	var m := SEGMENTS * SUB
	var cap_n := 3
	# root rings: the tube carries on back into the head, swelling, on the head bone, so the arm grows out of the body
	var root_n := 4
	var rows := root_n + m + 1 + cap_n
	var cols := AROUND_ARM
	var stride := cols + 1
	var chain: PackedInt32Array = arm_bones[a]
	var pos := PackedVector3Array()
	var centres := PackedVector3Array()
	var colors := PackedColorArray()
	var custom := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var tip_r := radii[m]
	var d0 := -frames[0].z
	for i in rows:
		var ii := clampi(i - root_n, 0, m)
		var c := pts[ii]
		var fr := frames[ii]
		var r := radii[ii]
		var s := float(ii) / float(m)
		var bone_ids: Array[int] = []
		var bone_w: Array[float] = []
		if i < root_n:
			var k := float(root_n - i)
			c = pts[0] - d0 * (0.01 * k) - Vector3(pts[0].x, pts[0].y, 0.0) * (0.12 * k)
			r = radii[0] * (1.0 + 0.05 * k)
			var hb := 1.0 if k > 1.5 else 0.85
			bone_ids = [HEAD_BONE, chain[0], chain[0], chain[0]]
			bone_w = [hb, 1.0 - hb, 0.0, 0.0]
		else:
			if i - root_n > m:
				var th := (float(i - root_n - m) / cap_n) * PI * 0.5
				c = pts[m] + (-fr.z) * tip_r * 1.1 * sin(th)
				r = tip_r * cos(th)
			# the first segment leans on the head too, so a bent arm's root does not open a seam
			var h := 0.75 * (1.0 - smoothstep(0.0, float(SUB) * 1.3, float(ii)))
			var aw := _arm_weights(float(ii))
			bone_ids = [chain[int(aw[0][0])], chain[int(aw[0][1])], HEAD_BONE, chain[int(aw[0][3])]]
			bone_w = [float(aw[1][0]) * (1.0 - h), float(aw[1][1]) * (1.0 - h), h, 0.0]
		centres.append(c * unit)
		for k in stride:
			var th2 := TAU * float(k % cols) / float(cols)
			var dir := fr.y * cos(th2) + fr.x * sin(th2)
			var p := c + dir * r * (0.93 if cos(th2) > 0.0 else 1.0)
			pos.append(p * unit)
			var ang := minf(th2, TAU - th2)
			var oral := 1.0 - smoothstep(0.35, 1.4, ang)
			var vein := (0.95 - 0.45 * s) * (1.0 - 0.55 * oral)
			colors.append(Color(vein, 0.0, float(a) / 7.0, oral))
			custom.append_array([p.x, p.y, p.z, BODY_U_HEAD + (1.0 - BODY_U_HEAD) * s])
			for q in 4:
				bones.append(bone_ids[q])
				weights.append(bone_w[q])
	buf.add_grid(pos, PackedVector3Array(), centres, rows, cols, colors, custom, bones, weights, true, false)


func _add_web(buf: _Buf, arms: Array[Dictionary], a: int) -> void:
	var b := (a + 1) % ARMS
	var pa: PackedVector3Array = arms[a]["pts"]
	var pb: PackedVector3Array = arms[b]["pts"]
	var ra: PackedFloat32Array = arms[a]["radii"]
	var rb: PackedFloat32Array = arms[b]["radii"]
	var chain_a: PackedInt32Array = arm_bones[a]
	var chain_b: PackedInt32Array = arm_bones[b]
	# the web runs a long way down the arms (the delta's wing), deepest along each arm, scalloped between
	var rows := 14
	var cols := 8
	var stride := cols + 1
	var m_centre := 14.0
	var m_edge := 25.0
	var pos := PackedVector3Array()
	var centres := PackedVector3Array()
	var colors := PackedColorArray()
	var custom := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var m_total := float(SEGMENTS * SUB)
	for i in rows + 1:
		var t := float(i) / float(rows)
		centres.append(Vector3(0.0, 0.0, -0.05) * unit)
		for k in stride:
			var cf := float(k) / float(cols)
			var edge := pow(absf(2.0 * cf - 1.0), 1.6)
			var m_max := lerpf(m_centre, m_edge, edge)
			var mf := t * m_max
			var i0 := int(floor(mf))
			var i1 := mini(i0 + 1, int(m_total))
			var fr := mf - float(i0)
			var qa := pa[i0].lerp(pa[i1], fr)
			var qb := pb[i0].lerp(pb[i1], fr)
			var ura := ra[i0] * (1.0 - fr) + ra[i1] * fr
			var urb := rb[i0] * (1.0 - fr) + rb[i1] * fr
			var dir := (qb - qa).normalized()
			var sa := qa + dir * ura * 0.8
			var sb := qb - dir * urb * 0.8
			var mid := sa.lerp(sb, cf)
			var out := Vector3(mid.x, mid.y, 0.0)
			if out.length() > 0.001:
				out = out.normalized()
			var sag := sin(PI * cf) * (sb - sa).length() * 0.16 * (0.4 + 0.6 * t)
			mid -= out * sag
			pos.append(mid * unit)
			var jf := mf / float(SUB)
			var bj := mini(int(floor(jf)), SEGMENTS - 1)
			var bn := mini(bj + 1, SEGMENTS - 1)
			var f := smoothstep(0.0, 1.0, jf - float(bj))
			# near the crown the web leans on the head like the arm roots do
			var h := 0.6 * (1.0 - smoothstep(0.0, float(SUB) * 1.2, mf))
			if h > 0.0005:
				bones.append_array([chain_a[bj], HEAD_BONE, chain_b[bj], chain_b[bn]])
				weights.append_array([(1.0 - cf) * (1.0 - h), h, cf * (1.0 - f) * (1.0 - h), cf * f * (1.0 - h)])
			else:
				bones.append_array([chain_a[bj], chain_a[bn], chain_b[bj], chain_b[bn]])
				weights.append_array([(1.0 - cf) * (1.0 - f), (1.0 - cf) * f, cf * (1.0 - f), cf * f])
			colors.append(Color(0.55 * (1.0 - 0.4 * t), 0.0, float(a) / 7.0, 0.35))
			custom.append_array([mid.x, mid.y, mid.z, BODY_U_HEAD + (1.0 - BODY_U_HEAD) * (mf / m_total)])
	buf.add_grid(pos, PackedVector3Array(), centres, rows + 1, cols, colors, custom, bones, weights, false, true)


# -------------------------------------------------------------------- suckers

func _build_suckers(arms: Array[Dictionary], hi: bool) -> ArrayMesh:
	var buf := _Buf.new()
	var profile: Array[Vector2] = [Vector2(1.4, -0.3), Vector2(1.16, 0.07), Vector2(0.9, 0.27), Vector2(0.64, 0.14), Vector2(0.32, -0.02), Vector2(0.0, -0.05)]
	var depth := PackedFloat32Array([0.0, 0.0, 0.0, 0.35, 0.8, 1.0])
	var around := 16
	if not hi:
		profile = [Vector2(1.35, -0.25), Vector2(1.0, 0.2), Vector2(0.62, 0.14), Vector2(0.3, -0.02), Vector2(0.0, -0.05)]
		depth = PackedFloat32Array([0.0, 0.0, 0.3, 0.8, 1.0])
		around = 7
	for a in ARMS:
		var d: Dictionary = arms[a]
		var pts: PackedVector3Array = d["pts"]
		var frames: Array[Basis] = d["frames"]
		var radii: PackedFloat32Array = d["radii"]
		var chain: PackedInt32Array = arm_bones[a]
		var m := SEGMENTS * SUB
		var length: float = d["length"]
		var s := 0.15
		var row_flip := 0
		while s < 0.92:
			var mf := s * float(m)
			var i0 := mini(int(floor(mf)), m - 1)
			var f := mf - float(i0)
			var r := lerpf(radii[i0], radii[i0 + 1], f)
			var cup := 0.36 * r
			if cup < 0.0036:
				break
			var c := pts[i0].lerp(pts[i0 + 1], f)
			var qa := frames[i0].get_rotation_quaternion()
			var qb := frames[i0 + 1].get_rotation_quaternion()
			var fr := Basis(qa.slerp(qb, f))
			for row in 2:
				var psi := (0.52 if row == 0 else -0.52)
				var shift := 0.5 * (2.9 * cup) / length if row == 1 else 0.0
				var sm := clampf(s + shift, 0.0, 0.95)
				var mm := sm * float(m)
				var j0 := mini(int(floor(mm)), m - 1)
				var ff := mm - float(j0)
				var rr := lerpf(radii[j0], radii[j0 + 1], ff)
				var cc := pts[j0].lerp(pts[j0 + 1], ff)
				var frr := Basis(frames[j0].get_rotation_quaternion().slerp(frames[j0 + 1].get_rotation_quaternion(), ff))
				var cupr := 0.36 * rr
				var dir := frr.y * cos(psi) + frr.x * sin(psi)
				var origin := cc + dir * rr * 0.94
				var sw := _arm_weights(mm)
				var bw := [[chain[int(sw[0][0])], chain[int(sw[0][1])], chain[int(sw[0][2])], chain[int(sw[0][3])]], sw[1]]
				_revolve(buf, profile, depth, origin, dir, -frr.z, cupr, bw, float(a) / 7.0, BODY_U_HEAD + (1.0 - BODY_U_HEAD) * sm, around)
			s += 2.9 * cup / length
			row_flip += 1
	return buf.to_mesh(true)


## Revolves a (rho, h) profile round `axis` at `origin`, scaled by `size`.
## Normals come from the profile (it runs from the rim toward the axis, or
## outer wall then back down the inside for a funnel).
func _revolve(buf: _Buf, profile: Array[Vector2], depth: PackedFloat32Array, origin: Vector3, axis: Vector3, tangent: Vector3, size: float,
		bw: Array, arm_id: float, u: float, around: int, cavity: PackedFloat32Array = PackedFloat32Array(), skinned: bool = true) -> void:
	var w := axis.normalized()
	var uu := (tangent - w * tangent.dot(w)).normalized()
	var vv := w.cross(uu)
	var rows := profile.size()
	var stride := around + 1
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var colors := PackedColorArray()
	var custom := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var centres := PackedVector3Array()
	for i in rows:
		var p0 := profile[maxi(i - 1, 0)]
		var p1 := profile[mini(i + 1, rows - 1)]
		var t := p1 - p0
		var n2 := Vector2(t.y, -t.x).normalized()
		var p := profile[i]
		centres.append(origin * unit)
		for k in stride:
			var ph := TAU * float(k % around) / float(around)
			var rho := uu * cos(ph) + vv * sin(ph)
			var pt := origin + w * (p.y * size) + rho * (p.x * size)
			pos.append(pt * unit)
			nrm.append((rho * n2.x + w * n2.y).normalized())
			var cav := cavity[i] if not cavity.is_empty() else 0.0
			colors.append(Color(depth[i], cav, arm_id, 1.0))
			custom.append_array([pt.x, pt.y, pt.z, u])
			if skinned:
				for q in 4:
					bones.append(int(bw[0][q]))
					weights.append(float(bw[1][q]))
	buf.add_grid(pos, nrm, centres, rows, around, colors, custom, bones, weights, true, false)


# ---------------------------------------------------------- head: eyes, siphon

func _build_head_parts() -> void:
	var attach := BoneAttachment3D.new()
	attach.name = "HeadAttach"
	skeleton.add_child(attach)
	attach.bone_name = "head"
	eyes.clear()
	for side in [-1, 1]:
		# small, set high on the side of the head, looking out and a little ahead, under a heavy brow
		var eye_dir := Vector3(0.86 * side, 0.36, -0.36).normalized()
		var centre := Vector3(0.083 * side, 0.044, -0.012)
		var basis := Basis.looking_at(-eye_dir, Vector3.UP)
		var eye := MeshInstance3D.new()
		eye.name = "EyeL" if side < 0 else "EyeR"
		eye.mesh = _eye_mesh(0.024)
		eye.material_override = materials[3]
		eye.transform = Transform3D(basis, centre * unit)
		attach.add_child(eye)
		eyes.append(eye)
		var lid := MeshInstance3D.new()
		lid.name = "LidL" if side < 0 else "LidR"
		lid.mesh = _lid_mesh()
		lid.material_override = materials[0]
		lid.transform = Transform3D(basis, centre * unit)
		attach.add_child(lid)
	# The siphon: a funnel from the mantle opening under the head, exhaust (+Z local) aimed back between the ventral arms, a little down.
	siphon = Node3D.new()
	siphon.name = "Siphon"
	var exhaust := Vector3(0.0, -0.22, 1.0).normalized()
	_siphon_rest = Basis.looking_at(-exhaust, Vector3.UP)
	siphon.transform = Transform3D(_siphon_rest, Vector3(0.0, -0.082, -0.03) * unit)
	attach.add_child(siphon)
	var sm := MeshInstance3D.new()
	sm.name = "SiphonMesh"
	sm.mesh = _siphon_mesh()
	sm.material_override = materials[0]
	siphon.add_child(sm)
	siphon_mouth = Marker3D.new()
	siphon_mouth.name = "SiphonMouth"
	siphon_mouth.position = Vector3(0.0, 0.0, 0.092 * unit)
	siphon.add_child(siphon_mouth)


func _eye_mesh(radius: float) -> ArrayMesh:
	var buf := _Buf.new()
	var rows := 18
	var cols := 28
	var pos := PackedVector3Array()
	var colors := PackedColorArray()
	var custom := PackedFloat32Array()
	var centres := PackedVector3Array()
	for i in rows + 1:
		var lat := PI * float(i) / float(rows)  # 0 = front pole (+Z)
		centres.append(Vector3.ZERO)
		for k in cols + 1:
			var ph := TAU * float(k % cols) / float(cols)
			var p := Vector3(sin(lat) * cos(ph), sin(lat) * sin(ph), cos(lat))
			pos.append(p * radius * unit)
			colors.append(Color(0, 0, 0, 0))
			custom.append_array([p.x, p.y, p.z, 0.0])
	buf.add_grid(pos, PackedVector3Array(), centres, rows + 1, cols, colors, custom, PackedInt32Array(), PackedFloat32Array(), true, false)
	return buf.to_mesh(false)


## The raised rim round an eye, swelling into a heavy brow ridge over its top
## (a torus whose tube thickens and leans out over the eye), skin material.
func _lid_mesh() -> ArrayMesh:
	var buf := _Buf.new()
	var rows := 12
	var cols := 36
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var colors := PackedColorArray()
	var custom := PackedFloat32Array()
	var centres := PackedVector3Array()
	var big := 0.026
	for i in rows + 1:
		var th := TAU * float(i % rows) / float(rows)
		centres.append(Vector3(0.0, 0.0, 0.0))
		for k in cols + 1:
			var ph := TAU * float(k % cols) / float(cols)
			var ring := Vector3(cos(ph), sin(ph), 0.0)
			var brow := smoothstep(-0.1, 0.85, sin(ph)) * (0.8 + 0.2 * cos(ph * 3.0))
			var tube := 0.0065 + 0.0125 * brow
			var lean := Vector3(0.0, 0.0, 0.009 * brow) - ring * (0.006 * brow)
			var off := ring * (big + cos(th) * tube) + Vector3(0.0, 0.0, sin(th) * tube * 0.75 - 0.004) + lean
			pos.append(off * unit)
			nrm.append((ring * cos(th) + Vector3(0, 0, sin(th))).normalized())
			colors.append(Color(0.3, 0, 0, 0.0))
			custom.append_array([off.x + 0.083, off.y + 0.044, off.z, 0.4])
	buf.add_grid(pos, nrm, centres, rows + 1, cols, colors, custom, PackedInt32Array(), PackedFloat32Array(), true, false)
	return buf.to_mesh(false)


func _siphon_mesh() -> ArrayMesh:
	var buf := _Buf.new()
	# (rho, h): outer wall base -> lip -> back down the inside to the closed end.
	var profile: Array[Vector2] = [
		Vector2(0.0, -0.075), Vector2(0.03, -0.072), Vector2(0.052, -0.058), Vector2(0.056, -0.035), Vector2(0.047, -0.012), Vector2(0.039, 0.008),
		Vector2(0.0335, 0.03), Vector2(0.0295, 0.062), Vector2(0.0275, 0.082),
		Vector2(0.0255, 0.0925), Vector2(0.0215, 0.094), Vector2(0.0195, 0.09), Vector2(0.0185, 0.07), Vector2(0.0185, 0.04),
		Vector2(0.0175, 0.02), Vector2(0.01, 0.013), Vector2(0.0, 0.012),
	]
	var cavity := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.25, 0.7, 1, 1, 1, 1, 1])
	var depth := PackedFloat32Array()
	depth.resize(profile.size())
	_revolve(buf, profile, depth, Vector3.ZERO, Vector3.BACK, Vector3.RIGHT, 1.0, [], 0.0, 0.4, 24, cavity, false)
	return buf.to_mesh(false)


func _build_tip_nodes() -> void:
	arm_tips.clear()
	for a in ARMS:
		var chain: PackedInt32Array = arm_bones[a]
		var att := BoneAttachment3D.new()
		att.name = "ArmTip%d" % a
		skeleton.add_child(att)
		att.bone_name = skeleton.get_bone_name(chain[SEGMENTS - 1])
		var tip := Marker3D.new()
		tip.name = "Tip"
		tip.position = _arm_tip_offset[a]
		att.add_child(tip)
		arm_tips.append(tip)


## A growable skinned mesh (positions, normals, vertex colours, rest position
## in CUSTOM0, 4 bone weights) with grid helpers.
class _Buf:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var cus := PackedFloat32Array()
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	var idx := PackedInt32Array()

	func add_grid(p: PackedVector3Array, n_given: PackedVector3Array, centres: PackedVector3Array, rows: int, cols: int,
			colors: PackedColorArray, custom: PackedFloat32Array, bone_ids: PackedInt32Array, weights: PackedFloat32Array,
			closed: bool, double_sided: bool) -> void:
		var stride := cols + 1
		var base := pos.size()
		var geo := PackedVector3Array()
		geo.resize(rows * stride)
		for i in rows:
			var before := maxi(i - 1, 0)
			var after := mini(i + 1, rows - 1)
			for k in stride:
				var kk := k % cols if closed else k
				var along := p[after * stride + kk] - p[before * stride + kk]
				var k0 := (kk + cols - 1) % cols if closed else maxi(kk - 1, 0)
				var k1 := (kk + 1) % cols if closed else mini(kk + 1, cols)
				var around := p[i * stride + k1] - p[i * stride + k0]
				geo[i * stride + k] = along.cross(around)
		var normals := PackedVector3Array()
		normals.resize(rows * stride)
		var agree := 0.0
		for i in rows:
			for k in stride:
				var v := i * stride + k
				var g := geo[v]
				var n: Vector3
				if not n_given.is_empty():
					n = n_given[v]
				else:
					var out := p[v] - centres[i]
					if g.length_squared() < 1e-16:
						n = out.normalized() if out.length_squared() > 1e-16 else Vector3.UP
					else:
						n = g.normalized()
						if g.dot(out) < 0.0:
							n = -n
				normals[v] = n
				agree += g.dot(n)
		var flip := agree < 0.0
		for v in rows * stride:
			pos.append(p[v])
			nrm.append(normals[v])
			col.append(colors[v])
		cus.append_array(custom)
		if not bone_ids.is_empty():
			bones.append_array(bone_ids)
			wts.append_array(weights)
		for i in rows - 1:
			for k in cols:
				var a := base + i * stride + k
				var b := a + 1
				var c := a + stride
				var d := b + stride
				if flip:
					idx.append_array([a, c, b, b, c, d])
				else:
					idx.append_array([a, b, c, b, d, c])
		if double_sided:
			var base2 := pos.size()
			for v in rows * stride:
				pos.append(p[v])
				nrm.append(-normals[v])
				col.append(colors[v])
			cus.append_array(custom)
			if not bone_ids.is_empty():
				bones.append_array(bone_ids)
				wts.append_array(weights)
			for i in rows - 1:
				for k in cols:
					var a := base2 + i * stride + k
					var b := a + 1
					var c := a + stride
					var d := b + stride
					if flip:
						idx.append_array([a, b, c, b, d, c])
					else:
						idx.append_array([a, c, b, b, c, d])

	func to_mesh(skinned: bool) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = pos
		arrays[Mesh.ARRAY_NORMAL] = nrm
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_CUSTOM0] = cus
		if skinned and not bones.is_empty():
			arrays[Mesh.ARRAY_BONES] = _pad4(bones)
			arrays[Mesh.ARRAY_WEIGHTS] = _pad4f(wts)
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		return mesh

	func _pad4(a: PackedInt32Array) -> PackedInt32Array:
		return a

	func _pad4f(a: PackedFloat32Array) -> PackedFloat32Array:
		return a
