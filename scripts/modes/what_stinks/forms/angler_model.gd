class_name AnglerModel
extends Node3D
## The Lantern Angler's body (what_stinks: planning_new_hunters.md D1; the API is angler_contract.md). One seamless
## BossMesh bent along a SpineRig by angler_skin.gdshader, like the bosses: a heavy globe of a head whose underside slants
## up to the snout (that slant IS the mouth line, so the roof of the mouth is the skull's own bottom), a separate lower
## jaw (hinge weight 1) that sticks out past the snout and turns in the shader about the corner of the mouth, behind the head
## a real fish body tapering to a narrow peduncle (angler_fish_side_profile.png), needle teeth in a second mesh (glassy, clear
## toward the tips), the illicium deformed in the shader by a 6-point spring chain with the glowing esca at its end, hair-like
## tufts, cold eyes and photophores. The fins (spiny and soft dorsal, anal, caudal fan, pectorals) are a third mesh of plain
## membranes whose rays, translucent torn web, ragged edges, fraying filaments and ripple are all angler_fin.gdshader's.
## Design numbers are in metres at a 7.5 m body ("design"), times `k` = length / 7.5.

const SKIN := preload("res://shaders/angler_skin.gdshader")
const FIN_SKIN := preload("res://shaders/angler_fin.gdshader")
const EYE := preload("res://shaders/fish_eye.gdshader")
const DESIGN_LENGTH := 7.5
## Where the body's loft ends (design m): the caudal fan carries on from the peduncle to DESIGN_LENGTH.
const BODY_END := 6.25
## Fin ids for angler_fin.gdshader (UV2.x in the fin mesh).
const FIN_SPINY := 10.0
const FIN_SOFT := 11.0
const FIN_ANAL := 12.0
const FIN_CAUDAL := 13.0
const FIN_PECTORAL := 14.0
## The jaw's angle at jaw_open 1, and the most it can turn (rad).
const GAPE_ANGLE := 0.9
const MAX_JAW_ANGLE := 2.1
## The jaw hangs a little open when jaw_open is 0 (rad), so the teeth show: a closed angler still looks like it will bite.
const JAW_REST := 0.1
## The hinge: (y, z) at the mouth's corner in design metres.
const HINGE := Vector2(-0.62, 2.25)
## The mouth line's y at z0, z0, dy/dz, and where the mouth ends (design).
const MOUTH_LINE := Vector4(0.0, 0.25, -0.297, 2.3)
const STALK_REST: Array[Vector3] = [
	Vector3(0.0, 1.53, 1.15), Vector3(0.0, 2.03, 1.0), Vector3(0.0, 2.5, 0.65),
	Vector3(0.0, 2.8, 0.15), Vector3(0.0, 2.85, -0.35), Vector3(0.0, 2.62, -0.8),
]
const BULB_DROP := 0.22  # design m the bulb's centre hangs below the chain's end
## Where the tail snap starts (design m): the body behind the head, and the fins on it.
const TAIL_FROM := 3.9
## The right pectoral's root (design m, mirrored for the left): its hinge in the shader.
const PECT_ROOT := Vector3(1.5, -0.25, 2.8)

## How many esca point lights may exist at once across all anglers (the murk system may lower it). The rest use the halo.
static var light_cap := 6
static var lights_in_use := 0

@export var stalk_stiffness := 38.0
@export var stalk_damping := 5.5
@export var stalk_sway := 0.5

var k := 1.0
var length := DESIGN_LENGTH
var rig: SpineRig
var skin: ShaderMaterial
var teeth_skin: ShaderMaterial
var fin_skin: ShaderMaterial
var body_node: MeshInstance3D
var teeth_node: MeshInstance3D
var fin_node: MeshInstance3D
var eyes: Array[MeshInstance3D] = []
var stalk_nodes: Array[Node3D] = []
var light_enabled := true
var esca_color := Color(0.3, 0.9, 1.0):
	set(value):
		esca_color = value
		_push_esca()

var jaw_open := 0.0:
	set(value):
		jaw_open = clampf(value, -0.12, (MAX_JAW_ANGLE - JAW_REST) / GAPE_ANGLE)
		_push_jaw()
var esca_intensity := 1.0:
	set(value):
		esca_intensity = maxf(value, 0.0)
		_push_esca()
var eye_glint := 1.0:
	set(value):
		eye_glint = clampf(value, 0.0, 2.0)
		_push_eyes()
var tail_bend := 0.0:
	set(value):
		tail_bend = value
		for m in _skins():
			m.set_shader_parameter("tail_bend", value)
## The stride's Battletoads swell of the tail (0 none): its girth and the caudal fan grow by this much at the tip.
var tail_grow := 0.0:
	set(value):
		tail_grow = value
		for m in _skins():
			m.set_shader_parameter("tail_grow", value)
var fin_flutter := 0.6:
	set(value):
		fin_flutter = clampf(value, 0.0, 2.0)
		_push_flutter()
var flap_l := 0.0
var flap_r := 0.0
var sweep := 0.0

var _stats := {"vertices": 0, "triangles": 0, "teeth": 0}
var _stalk := PackedVector3Array()  # rest space, metres: the spring chain
var _stalk_vel := PackedVector3Array()
var _stalk_rest := PackedVector3Array()
var _stalk_len := PackedFloat32Array()
var _stalk_kick := Vector3.ZERO
var _age := 0.0
var _eye_rest: Array = []  # [rest point, rest basis] per eye
var _esca: Node3D
var _light: OmniLight3D
var _light_on := false
var _halo: MeshInstance3D
var _halo_mat: StandardMaterial3D
var _bulb_rest := Vector3.ZERO


## Builds the body `length_m` long. Safe to call again for a size change (frees the old parts).
func build(length_m: float = DESIGN_LENGTH) -> AnglerModel:
	_release_light()
	for child in get_children():
		child.queue_free()
	eyes.clear()
	stalk_nodes.clear()
	_eye_rest.clear()
	length = length_m
	k = length_m / DESIGN_LENGTH
	rig = SpineRig.new(length_m, 3.4 * k)
	_stalk_rest = PackedVector3Array()
	for p in STALK_REST:
		_stalk_rest.append(p * k)
	_stalk = _stalk_rest.duplicate()
	_stalk_vel = PackedVector3Array()
	_stalk_vel.resize(6)
	_stalk_len = PackedFloat32Array()
	_stalk_len.resize(6)
	for i in range(1, 6):
		_stalk_len[i] = _stalk_rest[i].distance_to(_stalk_rest[i - 1])
	_bulb_rest = _stalk_rest[5] + Vector3(0.0, -BULB_DROP * k, 0.0)
	var body := BossMesh.new(length_m)
	var teeth := BossMesh.new(length_m)
	var fins := BossMesh.new(length_m)
	_build_body(body)
	_build_teeth(teeth)
	_build_fins(fins)
	var body_mesh: ArrayMesh = body.commit()
	var teeth_mesh: ArrayMesh = teeth.commit()
	var fin_mesh: ArrayMesh = fins.commit()
	_make_materials()
	body_node = rig.add_mesh(self, body_mesh, skin)
	body_node.name = "Body"
	teeth_node = rig.add_mesh(self, teeth_mesh, teeth_skin)
	teeth_node.name = "Teeth"
	fin_node = rig.add_mesh(self, fin_mesh, fin_skin)
	fin_node.name = "Fins"
	fin_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tris := 0
	for mesh: ArrayMesh in [body_mesh, teeth_mesh, fin_mesh]:
		tris += mesh.surface_get_array_index_len(0) / 3
	_stats = {"vertices": body.count + teeth.count + fins.count, "triangles": tris, "teeth": _tooth_count, "fin_vertices": fins.count}
	_build_eyes()
	_build_esca()
	_push_all()
	_stalk_age_reset()
	return self


func mesh_stats() -> Dictionary:
	return _stats


## The whole creature's rest-space bounds (body, teeth and fins): snout to the caudal fan's tip in z.
func rest_aabb() -> AABB:
	var box := body_node.mesh.get_aabb()
	box = box.merge(teeth_node.mesh.get_aabb())
	return box.merge(fin_node.mesh.get_aabb())


# ---------------------------------------------------------------------------------------------------------
# Posing

## A still or preview pose: the spine along this node's own transform (head at its origin, tailward along its +Z, up its +Y),
## curved sideways by `bend` rad in total (eased toward the tail).
func pose_straight(bend := 0.0, delta := 0.0) -> void:
	var xf := global_transform
	var back := xf.basis.z.normalized()
	var up := xf.basis.y.normalized()
	var side := xf.basis.x.normalized()
	var chain := PackedVector3Array()
	var at := xf.origin
	var dir := back
	var steps := 14
	chain.append(at)
	for i in steps:
		var t := float(i) / steps
		dir = dir.rotated(up, bend / steps * (0.2 + 1.6 * t) * 0.62)
		at += dir * (length / steps)
		chain.append(at)
	rig.head_up = up
	rig.head_back = back
	rig.follow_chain(chain)
	update(delta, Vector3.ZERO)


## Once per frame after the spine moved (angler_contract.md).
func update(delta: float, accel_world := Vector3.ZERO) -> void:
	if rig == null:
		return
	_age += delta
	rig.apply()
	_step_stalk(delta, accel_world)
	_place_riders()


## The esca flicked by a world impulse (m/s of kick).
func kick_stalk(impulse_world: Vector3) -> void:
	var frame := rig.frame_at(0.0)
	_stalk_kick += frame.basis.inverse() * impulse_world


func set_pectoral(flap: float, sweep_angle := 0.0) -> void:
	flap_l = flap
	flap_r = flap
	sweep = sweep_angle
	_push_fins()


func set_pectoral_sides(left: float, right: float, sweep_angle := 0.0) -> void:
	flap_l = left
	flap_r = right
	sweep = sweep_angle
	_push_fins()


func has_light() -> bool:
	return _light_on


func esca_rest() -> Vector3:
	return _bulb_rest


func esca_world() -> Vector3:
	return _place(_stalk[5] + Vector3(0.0, -BULB_DROP * k, 0.0)) if rig else global_position


## Where prey are taken: between the jaws about a metre behind the snout, in rest space.
func mouth_rest() -> Vector3:
	return Vector3(0.0, -0.45, 1.0) * k


## `mouth_rest` with the jaw's turn at `open` (a point's turn: the mouth's middle drops with the jaw).
func mouth_world(open := -1.0) -> Vector3:
	var o := jaw_open if open < 0.0 else open
	var rest := mouth_rest()
	return _place(_hinged(Vector3(rest.x, rest.y, rest.z), _jaw_angle(o)))


## A rest point turned with the lower jaw by `angle` rad (what spine_hinge does to hinge weight 1).
func _hinged(rest: Vector3, angle: float) -> Vector3:
	var hy := HINGE.x * k
	var hz := HINGE.y * k
	var c := cos(angle)
	var s := sin(angle)
	var dy := rest.y - hy
	var dz := rest.z - hz
	return Vector3(rest.x, hy + dy * c + dz * s, hz - dy * s + dz * c)


## A rest point (x right, y up, z tailward from the snout, may be negative ahead of it) where the spine puts it now.
func _place(rest: Vector3) -> Vector3:
	var d := clampf(rest.z, 0.0, length)
	var frame := rig.frame_at(d)
	return frame.origin + frame.basis.x * rest.x + frame.basis.y * rest.y + frame.basis.z * (rest.z - d)


func _frame_basis(rest_z: float) -> Basis:
	return rig.frame_at(clampf(rest_z, 0.0, length)).basis


# ---------------------------------------------------------------------------------------------------------
# The stalk's spring chain, in rest space.

func _stalk_age_reset() -> void:
	_stalk = _stalk_rest.duplicate()
	_stalk_vel.fill(Vector3.ZERO)
	_push_stalk()


func _step_stalk(delta: float, accel_world: Vector3) -> void:
	if delta <= 0.0:
		_push_stalk()
		return
	var frame := rig.frame_at(0.0)
	var inv := frame.basis.inverse()
	var accel := inv * accel_world
	var kick := _stalk_kick
	_stalk_kick = Vector3.ZERO
	var steps := clampi(int(ceil(delta / 0.008)), 1, 6)
	var h := minf(delta, 0.05) / steps
	for s in steps:
		for i in range(1, 6):
			var f := float(i) / 5.0
			var stiff := stalk_stiffness * lerpf(1.6, 0.55, f)
			var want := _stalk_rest[i]
			# The pull back to its rest shape, the head's push (inertia: the stalk lags the head), a lazy idle sway and any kick.
			var acc := (want - _stalk[i]) * stiff
			acc -= accel * (0.55 + f * 0.9)
			acc += Vector3(sin(_age * 1.3 + i * 0.9), cos(_age * 0.9 + i * 1.7), sin(_age * 1.1 + i * 0.4)) * stalk_sway * f * k * 1.4
			_stalk_vel[i] += acc * h
			_stalk_vel[i] *= exp(-stalk_damping * h)
		if s == 0 and kick != Vector3.ZERO:
			for i in range(1, 6):
				_stalk_vel[i] += kick * (float(i) / 5.0)
		for i in range(1, 6):
			_stalk[i] += _stalk_vel[i] * h
		# The rod keeps its length: each joint at its segment's reach from the one before.
		_stalk[0] = _stalk_rest[0]
		for i in range(1, 6):
			var d := _stalk[i] - _stalk[i - 1]
			var l := d.length()
			if l > 0.0001:
				_stalk[i] = _stalk[i - 1] + d / l * _stalk_len[i]
	_push_stalk()


func _push_stalk() -> void:
	if skin:
		skin.set_shader_parameter("stalk_now", _stalk)
	for i in stalk_nodes.size():
		if rig and is_instance_valid(stalk_nodes[i]):
			stalk_nodes[i].global_position = _place(_stalk[i])


func _place_riders() -> void:
	for i in eyes.size():
		var rest: Vector3 = _eye_rest[i][0]
		var rb: Basis = _eye_rest[i][1]
		var frame := rig.frame_at(clampf(rest.z, 0.0, length))
		eyes[i].global_transform = Transform3D((frame.basis * rb).scaled(Vector3.ONE * 0.23 * k), _place(rest))
	if _esca:
		var at := esca_world()
		_esca.global_position = at
		_sync_light()
		_halo.global_position = at
		var size := k * (1.6 + 2.6 * minf(esca_intensity, 3.0)) * (0.8 if _light_on else 1.25)
		(_halo.mesh as QuadMesh).size = Vector2(size, size)
		_halo_mat.albedo_color = Color(esca_color.r, esca_color.g, esca_color.b, clampf(0.12 + 0.28 * esca_intensity, 0.0, 0.95) * (0.7 if _light_on else 1.0))
		if _light_on:
			_light.light_energy = 3.0 * esca_intensity
			_light.light_color = esca_color
			_light.omni_range = 9.0 * k * (0.6 + 0.4 * minf(esca_intensity, 2.0))
		_halo.visible = esca_intensity > 0.01


func _sync_light() -> void:
	var want := light_enabled and esca_intensity > 0.02
	if want and not _light_on and lights_in_use < light_cap:
		lights_in_use += 1
		_light_on = true
		_light.visible = true
	elif _light_on and (not want or lights_in_use > light_cap):
		_release_light()


func _release_light() -> void:
	if _light_on:
		lights_in_use = maxi(lights_in_use - 1, 0)
	_light_on = false
	if _light and is_instance_valid(_light):
		_light.visible = false


func _exit_tree() -> void:
	_release_light()


# ---------------------------------------------------------------------------------------------------------
# Uniform pushes

func _push_all() -> void:
	_push_jaw()
	_push_esca()
	_push_eyes()
	_push_fins()
	_push_flutter()
	tail_bend = tail_bend
	tail_grow = tail_grow


## Every material the pose channels (tail, pectorals, flutter) reach: body, teeth, fins.
func _skins() -> Array[ShaderMaterial]:
	var out := _body_skins()
	if fin_skin:
		out.append(fin_skin)
	return out


## The skin shader's two copies (jaw hinge, esca, stalk).
func _body_skins() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	if skin:
		out.append(skin)
	if teeth_skin:
		out.append(teeth_skin)
	return out


static func _jaw_angle(open: float) -> float:
	return clampf(JAW_REST + open * GAPE_ANGLE, -0.02, MAX_JAW_ANGLE)


func _push_jaw() -> void:
	var angle := _jaw_angle(jaw_open)
	for m in _body_skins():
		m.set_shader_parameter("hinge", Vector3(HINGE.x * k, HINGE.y * k, angle))


func _push_esca() -> void:
	for m in _body_skins():
		m.set_shader_parameter("esca_intensity", esca_intensity)
		m.set_shader_parameter("esca_color", esca_color)


func _push_eyes() -> void:
	for e in eyes:
		var mat := e.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("glow", eye_glint * 0.5)
	if skin:
		skin.set_shader_parameter("glint", eye_glint)


func _push_fins() -> void:
	for m in _skins():
		m.set_shader_parameter("pect_flap_l", flap_l)
		m.set_shader_parameter("pect_flap_r", flap_r)
		m.set_shader_parameter("pect_sweep", sweep)


func _push_flutter() -> void:
	for m in _skins():
		m.set_shader_parameter("flutter", Vector3(0.1 * k * fin_flutter, 2.2 / k, 3.4))
		m.set_shader_parameter("spine_wave", Vector4(0.04 * k, 1.8 / k, 2.4, 0.45))


func _make_materials() -> void:
	skin = ShaderMaterial.new()
	skin.shader = SKIN
	var alpha := Shader.new()
	alpha.code = SKIN.code.replace("//@alpha", "ALPHA = ta;")
	teeth_skin = ShaderMaterial.new()
	teeth_skin.shader = alpha
	fin_skin = ShaderMaterial.new()
	fin_skin.shader = FIN_SKIN
	for m in _skins():
		m.set_shader_parameter("k", k)
		m.set_shader_parameter("tail_from", TAIL_FROM * k)
		m.set_shader_parameter("pect_root", PECT_ROOT)
		m.set_shader_parameter("spine_length", length)
	for m in _body_skins():
		m.set_shader_parameter("mouth_line", MOUTH_LINE)
		m.set_shader_parameter("stalk_rest", _stalk_rest)
		m.set_shader_parameter("stalk_now", _stalk)
	skin.set_shader_parameter("bump_strength", 0.9)


# ---------------------------------------------------------------------------------------------------------
# Shape: design-metre profile curves (Hermite through knots with finite-difference tangents).

static func _curve(knots: Array, x: float) -> float:
	var n := knots.size()
	if x <= (knots[0] as Vector2).x:
		return (knots[0] as Vector2).y
	if x >= (knots[n - 1] as Vector2).x:
		return (knots[n - 1] as Vector2).y
	var i := 0
	while i < n - 2 and x > (knots[i + 1] as Vector2).x:
		i += 1
	var a: Vector2 = knots[i]
	var b: Vector2 = knots[i + 1]
	var h := b.x - a.x
	var ma := _slope(knots, i)
	var mb := _slope(knots, i + 1)
	var t := (x - a.x) / h
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * a.y + (t3 - 2.0 * t2 + t) * h * ma + (-2.0 * t3 + 3.0 * t2) * b.y + (t3 - t2) * h * mb


static func _slope(knots: Array, i: int) -> float:
	var n := knots.size()
	var a: Vector2 = knots[maxi(i - 1, 0)]
	var b: Vector2 = knots[mini(i + 1, n - 1)]
	var m := (b.y - a.y) / maxf(b.x - a.x, 0.0001)
	# Monotone-ish: flat at local extremes so the curve doesn't overshoot.
	var here: Vector2 = knots[i]
	if (here.y - a.y) * (b.y - here.y) <= 0.0:
		return 0.0
	return m


const SKULL_TOP: Array = [Vector2(0.0, 0.3), Vector2(0.12, 0.62), Vector2(0.5, 1.0), Vector2(1.0, 1.42), Vector2(1.7, 1.85), Vector2(2.4, 1.97),
		Vector2(3.1, 1.78), Vector2(3.8, 1.42), Vector2(4.5, 1.02), Vector2(5.2, 0.68), Vector2(5.8, 0.48), Vector2(6.25, 0.42)]
const SKULL_BOTTOM: Array = [Vector2(0.0, 0.3), Vector2(0.12, 0.13), Vector2(0.5, -0.04), Vector2(1.0, -0.22), Vector2(1.7, -0.43), Vector2(2.2, -0.58),
		Vector2(2.55, -1.02), Vector2(3.0, -1.66), Vector2(3.5, -1.62), Vector2(4.1, -1.2), Vector2(4.8, -0.62), Vector2(5.4, -0.26),
		Vector2(5.9, -0.1), Vector2(6.25, -0.08)]
const SKULL_WIDTH: Array = [Vector2(0.0, 0.0), Vector2(0.12, 0.45), Vector2(0.5, 0.88), Vector2(1.0, 1.22), Vector2(1.6, 1.52), Vector2(2.4, 1.68),
		Vector2(3.2, 1.42), Vector2(4.0, 0.98), Vector2(4.8, 0.6), Vector2(5.5, 0.32), Vector2(6.0, 0.2), Vector2(6.25, 0.17)]
const JAW_DEPTH: Array = [Vector2(-0.35, 0.0), Vector2(-0.25, 0.38), Vector2(0.3, 0.88), Vector2(1.0, 1.08), Vector2(1.8, 1.18), Vector2(2.4, 1.0), Vector2(2.9, 0.78), Vector2(3.3, 0.1)]
const JAW_WIDTH: Array = [Vector2(-0.35, 0.0), Vector2(-0.2, 0.4), Vector2(0.3, 0.66), Vector2(1.0, 1.0), Vector2(1.8, 1.36), Vector2(2.4, 1.5), Vector2(2.9, 1.3), Vector2(3.3, 0.25)]
const SQUARE := 3.0


static func line_y(z: float) -> float:
	return MOUTH_LINE.x + (z - MOUTH_LINE.y) * MOUTH_LINE.z


static func jaw_top(z: float) -> float:
	var up := 0.38 * smoothstep(0.9, -0.35, z)
	return line_y(z) + up - maxf(z - 2.2, 0.0) * 0.4


## The skull's slice at design z as the loft's Vector4 (half width, half height, middle height, squareness), design metres.
static func skull_slice(z: float) -> Vector4:
	var top := _curve(SKULL_TOP, z)
	var bottom := _curve(SKULL_BOTTOM, z)
	var w := _curve(SKULL_WIDTH, z)
	# The peduncle closes in its last stretch (the caudal fan carries on from there).
	var close := sqrt(maxf(1.0 - pow(maxf(z - (BODY_END - 0.2), 0.0) / 0.2, 2.0), 0.0))
	var h := (top - bottom) * 0.5 * close
	var square := lerpf(lerpf(SQUARE, 2.3, smoothstep(2.5, 3.5, z)), 2.05, smoothstep(3.5, 5.0, z))
	return Vector4(w * close, h, (top + bottom) * 0.5, square if z > 0.3 else 2.2)


static func jaw_slice(z: float) -> Vector4:
	var top := jaw_top(z)
	var d := _curve(JAW_DEPTH, z)
	var w := _curve(JAW_WIDTH, z)
	return Vector4(w, d * 0.5, top - d * 0.5, SQUARE if z > 0.2 else 2.0)


## A point on a slice's ring at `angle` (0 the top, TAU/4 the right), design metres.
static func ring_point(slice: Vector4, angle: float, z: float) -> Vector3:
	var power := 2.0 / maxf(slice.w, 0.2)
	var s := sin(angle)
	var c := cos(angle)
	return Vector3(signf(s) * pow(absf(s), power) * slice.x, slice.z + signf(c) * pow(absf(c), power) * slice.y, z)


var _tooth_count := 0


func _build_body(m: BossMesh) -> void:
	var kk := k
	# The skull and body: a globe of a head, its bottom the mouth's roof, then a fish's body tapering to the peduncle.
	var skull := func(a: float) -> Vector4:
		var z := a * BODY_END
		var s := skull_slice(z)
		return Vector4(s.x * kk, s.y * kk, s.z * kk, s.w)
	var wrinkles := func(a: float, angle: float) -> float:
		var z := a * BODY_END
		var mirror := minf(angle, TAU - angle)
		# Brow ridges over the eyes, a sunk socket, fine folds across the face and heavy furrows along the cheeks.
		var brow := 0.1 * exp(-pow((z - 0.95) / 0.45, 2.0)) * exp(-pow((mirror - 0.62) / 0.28, 2.0))
		var socket := -0.05 * exp(-pow((z - 1.0) / 0.3, 2.0)) * exp(-pow((mirror - 1.15) / 0.22, 2.0))
		var folds := 0.016 * sin(mirror * 7.0 + z * 4.5) * smoothstep(0.1, 0.7, z) * (1.0 - smoothstep(2.6, 3.8, z))
		var chin := 0.025 * sin(z * 17.0 + mirror * 2.0) * (1.0 - smoothstep(0.4, 2.3, z)) * smoothstep(1.6, 2.6, mirror)
		# The gill cover's rim behind the head, loose folds of skin round the body, and warty knobs breaking the outline.
		var gill := -0.035 * exp(-pow((z - 3.05 - 0.15 * cos(mirror)) / 0.09, 2.0)) * smoothstep(0.3, 0.9, mirror) * smoothstep(2.9, 2.2, mirror)
		var body_folds := 0.02 * sin(z * 8.5 + sin(mirror * 3.0) * 1.6) * smoothstep(2.9, 3.6, z) * (1.0 - smoothstep(5.5, 6.1, z))
		var knob := 0.045 * pow(maxf(sin(z * 19.0 + mirror * 11.0) * sin(z * 11.0 - mirror * 15.0 + 1.3), 0.0), 5.0)
		knob *= smoothstep(0.5, 1.0, z) * smoothstep(2.6, 1.6, mirror) * (1.0 - smoothstep(5.4, 6.0, z))
		return 1.0 + brow + socket + folds + chin + gill + body_folds + knob
	m.loft(0.0, BODY_END * kk, skull, 260, 80, BossMesh.BODY, Callable(), 0.0, wrinkles)
	# The lower jaw: a heavy chin turned up at its tip, hinged at the mouth's corner. Its top is the floor of the mouth.
	m.hinge = 1.0
	var jaw := func(a: float) -> Vector4:
		var z := lerpf(-0.35, 3.3, a)
		var s := jaw_slice(z)
		return Vector4(s.x * kk, s.y * kk, s.z * kk, s.w)
	var jaw_bump := func(a: float, angle: float) -> float:
		var z := lerpf(-0.35, 3.3, a)
		var mirror := minf(angle, TAU - angle)
		return 1.0 + 0.02 * sin(z * 15.0 + mirror * 2.0) * smoothstep(0.0, 0.6, z) * smoothstep(1.7, 3.0, mirror)
	m.loft(-0.35 * kk, 3.3 * kk, jaw, 130, 48, BossMesh.BODY, Callable(), 0.0, jaw_bump)
	# Tongue: a low pad on the floor.
	m.blob(Vector3(0.0, jaw_top(1.35) * kk + 0.02 * kk, 1.35 * kk), Vector3(0.62, 0.07, 1.0) * kk, Basis.IDENTITY, 8, 16, BossMesh.INSIDE)
	m.hinge = 0.0
	# The throat: a dark mass behind the roof's cliff.
	m.blob(Vector3(0.0, -0.8 * kk, 2.5 * kk), Vector3(1.3, 0.85, 0.42) * kk, Basis.IDENTITY, 10, 22, BossMesh.INSIDE)
	# Lips: gristly rims along the mouth's edge, upper (still) and lower (with the jaw).
	for side: float in [-1.0, 1.0]:
		var path := PackedVector3Array()
		for i in 34:
			var z := lerpf(0.18, 2.35, i / 33.0)
			var sl := skull_slice(z)
			var p := ring_point(sl, side * (PI - 0.55), z)
			p.y = line_y(z) + 0.04
			p.x = side * absf(ring_point(sl, PI - 0.55, z).x) * 0.97
			path.append(p * kk)
		m.tube(path, func(t: float) -> float: return lerpf(0.06, 0.1, sin(t * PI)) * kk + 0.01 * kk, 8, BossMesh.BODY)
	m.hinge = 1.0
	for side: float in [-1.0, 1.0]:
		var path := PackedVector3Array()
		for i in 40:
			var z := lerpf(-0.3, 2.35, i / 39.0)
			var sl := jaw_slice(z)
			var p := ring_point(sl, side * 0.55, z)
			path.append(p * kk + Vector3(0.0, 0.005, 0.0))
		m.tube(path, func(t: float) -> float: return lerpf(0.07, 0.11, sin(t * PI)) * kk + 0.01 * kk, 8, BossMesh.BODY)
	# Chin barbels and a fringe under the jaw's tip.
	for j in 5:
		var base := Vector3(lerpf(-0.45, 0.45, j / 4.0), jaw_top(0.05) * kk - 0.8 * kk, 0.05 * kk)
		var path := PackedVector3Array()
		for i in 7:
			var t := i / 6.0
			path.append(base + Vector3(sin(j * 2.1) * 0.08 * t, -0.34 * t * (0.7 + 0.1 * j) , -0.05 * t + 0.22 * t * t) * kk)
		_tuft(m, path, 0.016 * kk)
	m.hinge = 0.0
	_build_tufts(m)
	_build_stalk(m)


func _tuft(m: BossMesh, path: PackedVector3Array, radius: float) -> void:
	m.tube(path, func(t: float) -> float: return radius * (1.0 - t * 0.85), 4, BossMesh.FILAMENT, Vector2(0.15, 1.0), -1.0)


## The fins: plain membranes (u along the root, v out to the tips) for angler_fin.gdshader to paint rays, torn web and filaments on.
## Each membrane is longer than its web: the outer part is where the rays run on as hair-like filaments.
func _build_fins(m: BossMesh) -> void:
	var kk := k
	# Spiny first dorsal: a few tall spines behind the lure's root, webbed only low down, raked back.
	m.membrane(func(u: float) -> Vector3:
			var z := lerpf(1.95, 3.35, u)
			return Vector3(0.0, (_curve(SKULL_TOP, z) - 0.1) * kk, z * kk),
		func(u: float) -> Vector3:
			var h := 1.15 * (1.0 - 0.4 * u)
			return Vector3(0.0, h * kk, 0.42 * h * kk),
		30, 8, Vector2.ZERO, FIN_SPINY)
	# Soft second dorsal, high on the tapering back.
	m.membrane(func(u: float) -> Vector3:
			var z := lerpf(4.25, 5.9, u)
			return Vector3(0.0, (_curve(SKULL_TOP, z) - 0.06) * kk, z * kk),
		func(u: float) -> Vector3:
			var h := 0.95 * sin(u * PI * 0.85 + 0.12) * (0.8 + 0.2 * u)
			return Vector3(0.0, h * kk, 0.5 * h * kk),
		40, 8, Vector2.ZERO, FIN_SOFT)
	# Anal fin, mirroring it underneath.
	m.membrane(func(u: float) -> Vector3:
			var z := lerpf(4.5, 5.9, u)
			return Vector3(0.0, (_curve(SKULL_BOTTOM, z) + 0.06) * kk, z * kk),
		func(u: float) -> Vector3:
			var h := 0.8 * sin(u * PI * 0.85 + 0.12)
			return Vector3(0.0, -h * kk, 0.5 * h * kk),
		34, 8, Vector2.ZERO, FIN_ANAL)
	# Caudal: a broad rounded fan from the peduncle to the body's full length.
	var reach := DESIGN_LENGTH - 5.95
	m.membrane(func(u: float) -> Vector3:
			return Vector3(0.0, lerpf(-0.06, 0.4, u) * kk, 5.95 * kk),
		func(u: float) -> Vector3:
			var spread := (u - 0.5) * 2.0
			return Vector3(0.0, spread * 1.2 * kk, (1.0 - 0.14 * spread * spread) * reach * kk),
		48, 10, Vector2.ZERO, FIN_CAUDAL)
	# Pectorals: fans behind the gill, rays spreading from back-and-up to back-and-down (turned in the shader at PECT_ROOT).
	for side: float in [-1.0, 1.0]:
		m.membrane(func(u: float) -> Vector3:
				var z := lerpf(2.62, 3.0, u)
				var sl := skull_slice(z)
				return Vector3(side * sl.x * 0.9 * kk, lerpf(0.1, -0.6, u) * kk, z * kk),
			func(u: float) -> Vector3:
				var ang := lerpf(0.85, -0.75, u)
				var l := 1.55 * (0.82 + 0.18 * sin(u * PI))
				return Vector3(side * 0.6, sin(ang), cos(ang)).normalized() * l * kk,
			34, 8, Vector2.ZERO, FIN_PECTORAL)


## Hair-like tufts: a ragged mane off the back of the head and the cheeks (lit_angler_fish.png).
func _build_tufts(m: BossMesh) -> void:
	var kk := k
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 70211
	for i in 16:
		var angle := rnd.randf_range(0.25, 2.3)
		var side := -1.0 if i % 2 == 0 else 1.0
		var z0 := rnd.randf_range(2.2, 3.4)
		var sl := skull_slice(z0)
		var base := ring_point(sl, side * angle, z0) * 0.98 * kk
		var out := Vector3(side * sin(angle) * 0.5, cos(angle) * 0.4 + 0.15, 0.0)
		var len := rnd.randf_range(0.5, 1.2)
		var path := PackedVector3Array()
		for j in 8:
			var t := j / 7.0
			path.append(base + (out.normalized() * 0.3 * t + Vector3(0.0, 0.0, 1.0) * t * len + Vector3(0.0, -0.1, 0.0) * t * t) * kk)
		_tuft(m, path, rnd.randf_range(0.01, 0.016) * kk)


func _catmull(pts: Array, t: float) -> Vector3:
	var tt := clampf(t, 0.0, 1.0) * 5.0
	var i := mini(int(floor(tt)), 4)
	var f := tt - i
	var p0: Vector3 = pts[maxi(i - 1, 0)]
	var p1: Vector3 = pts[i]
	var p2: Vector3 = pts[i + 1]
	var p3: Vector3 = pts[mini(i + 2, 5)]
	var f2 := f * f
	var f3 := f2 * f
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f3)


func _build_stalk(m: BossMesh) -> void:
	var kk := k
	var pts: Array = []
	for p in STALK_REST:
		pts.append(p * kk)
	# The illicium, its t along the chain carried as the vertex's extra (the shader moves it with the spring chain).
	var steps := 54
	var sides := 7
	var start := m.count
	var last_up := Vector3.RIGHT
	var rings: Array = []
	for i in steps + 1:
		var t := float(i) / steps
		var at := _catmull(pts, t)
		var ahead := _catmull(pts, minf(t + 0.01, 1.0)) - _catmull(pts, maxf(t - 0.01, 0.0))
		var dir := ahead.normalized()
		var right := last_up.cross(dir)
		if right.length_squared() < 1e-6:
			right = Vector3.RIGHT.cross(dir)
		right = right.normalized()
		var up := dir.cross(right).normalized()
		last_up = right
		var r := lerpf(0.075, 0.026, pow(t, 0.8)) * kk
		for s in sides:
			var angle := TAU * s / sides
			var sn := sin(angle)
			var cs := cos(angle)
			m._vertex(at + right * sn * r + up * cs * r, Vector2(t, float(s) / sides), BossMesh.FILAMENT, 0.0, Vector2(sn, cs), t)
	for i in steps:
		for s in sides:
			var a := start + i * sides + s
			var b := start + i * sides + (s + 1) % sides
			for corner: int in [a, b, a + sides, b, b + sides, a + sides]:
				m.tool.add_index(corner)
	# The lantern: a translucent bulb with a trailing fringe, all riding the chain's end.
	var tip: Vector3 = pts[5]
	m.blob(tip + Vector3(0.0, -BULB_DROP * kk, 0.0), Vector3(0.17, 0.24, 0.17) * kk, Basis.IDENTITY, 12, 20, BossMesh.EXTRA, 1.0)
	m.blob(tip + Vector3(0.0, -0.01 * kk, 0.0), Vector3(0.07, 0.07, 0.07) * kk, Basis.IDENTITY, 6, 10, BossMesh.EXTRA, 1.0)
	for j in 7:
		var ang := TAU * j / 7.0
		var path := PackedVector3Array()
		for q in 6:
			var t := q / 5.0
			path.append(tip + Vector3(cos(ang) * 0.1 * (1.0 + t * 0.6), -BULB_DROP - 0.16 - 0.3 * t, sin(ang) * 0.1 * (1.0 + t * 0.6)) * kk)
		m.tube(path, func(t: float) -> float: return lerpf(0.022, 0.006, t) * kk, 4, BossMesh.EXTRA, Vector2(0.4, 1.0), 1.0)


func _build_teeth(m: BossMesh) -> void:
	var kk := k
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 9917
	_tooth_count = 0
	# Upper teeth: down along the roof's edge and across the front, long fangs among short rows.
	m.hinge = 0.0
	for side: float in [-1.0, 1.0]:
		var n := 10
		for i in n:
			var z := lerpf(0.35, 2.15, (i + rnd.randf_range(-0.25, 0.25)) / (n - 1.0))
			var edge := Vector3(side * absf(ring_point(skull_slice(z), PI - 0.55, z).x) * 0.93, line_y(z) + 0.02, z)
			var fang := (i % 3 == 1)
			var l := (rnd.randf_range(0.5, 0.82) if fang else rnd.randf_range(0.2, 0.42)) * (1.0 - 0.15 * (z / 2.2))
			var dir := Vector3(-side * 0.2, -1.0, -0.12 + rnd.randf_range(-0.1, 0.1)).normalized()
			m.tooth(edge * kk, dir * l * kk, rnd.randf_range(0.02, 0.032) * kk * (1.0 + float(fang) * 0.4), Vector3(-side * 0.22, 0.0, 0.5), 6)
			_tooth_count += 1
	for i in 5:
		var x := lerpf(-0.2, 0.2, i / 4.0)
		var z := 0.14 + 0.04 * absf(x)
		m.tooth(Vector3(x, line_y(z) + 0.1, z) * kk, Vector3(0.0, -0.45 - 0.2 * float(i % 2), -0.06) * kk, 0.026 * kk, Vector3(0.0, 0.0, 0.5), 6)
		_tooth_count += 1
	# Lower teeth: up from the jaw's rim, the longest at the front, curved in toward the throat.
	m.hinge = 1.0
	for side: float in [-1.0, 1.0]:
		var n := 11
		for i in n:
			var z := lerpf(-0.18, 2.1, (i + rnd.randf_range(-0.25, 0.25)) / (n - 1.0))
			var sl := jaw_slice(z)
			var edge := ring_point(sl, side * 0.5, z)
			var fang := (i % 3 == 0 and z < 1.2)
			var l := (rnd.randf_range(0.7, 1.05) if fang else rnd.randf_range(0.22, 0.5)) * lerpf(1.0, 0.7, clampf(z / 2.2, 0.0, 1.0))
			var dir := Vector3(-side * 0.18, 1.0, -0.08 + rnd.randf_range(-0.08, 0.08)).normalized()
			m.tooth(edge * kk, dir * l * kk, rnd.randf_range(0.022, 0.034) * kk * (1.0 + float(fang) * 0.5), Vector3(-side * 0.2, 0.0, 0.6), 6)
			_tooth_count += 1
	var chin := [[-0.6, 0.85], [-0.33, 0.7], [0.0, 1.0], [0.33, 0.7], [0.6, 0.85], [-0.8, 0.5], [0.8, 0.5]]
	for c: Array in chin:
		var x: float = c[0]
		var z := -0.3 + 0.55 * pow(absf(x) / 0.65, 1.5)
		var l: float = c[1]
		var dir := Vector3(x * 0.45, 1.0, -0.1 + 0.1 * absf(x)).normalized()
		m.tooth(Vector3(x, jaw_top(z) + 0.04, z) * kk, dir * l * kk, 0.034 * kk, Vector3(-x * 0.3, 0.0, 0.7), 6)
		_tooth_count += 1
	m.hinge = 0.0


func _build_eyes() -> void:
	for side: float in [-1.0, 1.0]:
		var z := 0.98
		var sl := skull_slice(z)
		var at := ring_point(sl, side * 1.12, z)
		var dir := Vector3(side * 0.75, 0.35, -0.55).normalized()
		var rest := (at + dir * 0.02) * k
		var material := ShaderMaterial.new()
		material.shader = EYE
		material.set_shader_parameter("iris", Color(0.16, 0.34, 0.38))
		material.set_shader_parameter("iris_inner", Color(0.05, 0.14, 0.17))
		material.set_shader_parameter("rim_color", Color(0.02, 0.04, 0.05))
		material.set_shader_parameter("pupil", 0.6)
		material.set_shader_parameter("iris_size", 0.8)
		material.set_shader_parameter("sheen", 0.2)
		material.set_shader_parameter("glow_color", Color(0.3, 0.95, 1.0))
		material.set_shader_parameter("glow", eye_glint * 0.5)
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 24
		sphere.rings = 12
		var eye := MeshInstance3D.new()
		eye.name = "EyeR" if side > 0.0 else "EyeL"
		eye.mesh = sphere
		eye.material_override = material
		eye.scale = Vector3.ONE * 0.23 * k
		eye.top_level = true
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(eye)
		eyes.append(eye)
		_eye_rest.append([rest, Basis.looking_at(dir, Vector3.UP)])


func _build_esca() -> void:
	for i in 6:
		var marker := Node3D.new()
		marker.name = "Stalk%d" % i
		marker.top_level = true
		add_child(marker)
		stalk_nodes.append(marker)
	_esca = Node3D.new()
	_esca.name = "Esca"
	_esca.top_level = true
	add_child(_esca)
	_light = OmniLight3D.new()
	_light.name = "EscaLight"
	_light.light_color = esca_color
	_light.light_energy = 3.0
	_light.omni_range = 9.0 * k
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	_light.visible = false
	_esca.add_child(_light)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.12, Color(1.0, 1.0, 1.0, 0.55))
	gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 0.14))
	gradient.add_point(0.65, Color(1.0, 1.0, 1.0, 0.03))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_mat.albedo_texture = texture
	_halo_mat.disable_receive_shadows = true
	_halo_mat.no_depth_test = false
	_halo_mat.disable_fog = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * k * 4.0
	_halo = MeshInstance3D.new()
	_halo.name = "EscaHalo"
	_halo.mesh = quad
	_halo.material_override = _halo_mat
	_halo.top_level = true
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
