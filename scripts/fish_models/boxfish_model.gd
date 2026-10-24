class_name BoxfishModel
extends RefCounted
## The Bulwarks' boxfish (FishModel.build hands it here): species m.species of
## FishCharacter.SPECIES[FishCharacter.FishClass.BULWARK]. A rigid carapace of
## hexagonal plates (box_skin.gdshader), one smooth mesh from the pursed mouth on
## the front of its face, over the box, down the rear of the shell and out along
## a short soft tail stalk that bends into the tail fan (FishModel._bend_body);
## the shell itself never bends, only the stalk, fins and tail move, as a real
## boxfish swims. Real eyes on low mounds, and for the cowfish, horns on the brow
## and under the rear of the shell. The whole fish sits in a unit Squash node,
## which FishModel.react can squash and stretch like a jelly sweet (off now,
## squash_strength 0, for the realistic look).
##
## Skins: 0 Yellow Boxfish (Ostracion cubicus), 1 Longhorn Cowfish (Lactoria
## cornuta), 2 Spotted Boxfish male (Ostracion meleagris), 3 Scrawled Cowfish
## (Acanthostracion quadricornis).

const BOX_SKIN := preload("res://shaders/box_skin.gdshader")

## Rows of the body mesh in each stretch, nose to tail, and round it.
const AROUND := 64
const FACE_ROWS := 16
const BODY_ROWS := 30
const REAR_ROWS := 10
const STALK_ROWS := 12
const CAP_ROWS := 6
## The pursed lips, from inside the mouth out: (z from the face's front, m;
## size of the mouth ring).
const LIPS: Array[Vector2] = [
	Vector2(-0.006, 0.0), Vector2(-0.013, 0.42), Vector2(-0.019, 0.8), Vector2(-0.021, 1.08),
	Vector2(-0.017, 1.26), Vector2(-0.008, 1.22),
]


## Each species' look and shape. Lengths are of the hitbox (h its height, l its
## length) unless marked m.
static func _params(skin: int) -> Dictionary:
	match skin:
		1:  # Longhorn Cowfish: a triangular shell, long horns fore and aft, a long tail.
			return {
				"albedo": Color("c8b84a"), "back_shade": 0.66, "belly": Color("ece2a0"), "belly_mix": 0.6,
				"seam": Color("4a4200"), "seam_strength": 0.5, "mark": Color("3a8ad8"), "mark2": Color("6ab4f4"),
				"ring": Color("2a4a70"), "lip": Color("d89a60"), "pattern": 1, "plate_size": 0.085,
				"iris": Color("8aa048"), "squareness": 2.5, "tri": 0.46, "keel": 0.16,
				"rear_h": 0.66, "rear_w": 0.6, "carapace_end": 0.235, "pivot": 0.415, "stalk": 0.17,
				"tail": [0.24, 0.31, 0.33, 0.31, 0.24], "tail_spread": 0.75,
				"fin": Color("c8b84a"), "fin_edge": 1.12, "fin_rays": Color("6a6010"), "tint_fins": true,
				"horns": Vector2(0.27, 0.22), "horn_radius": 0.045,
			}
		2:  # Spotted Boxfish (male): a white-dotted black roof over gold-flecked blue flanks.
			return {
				"albedo": Color("2a50b0"), "back_shade": 0.8, "belly": Color("4a78d0"), "belly_mix": 0.55,
				"seam": Color("000000"), "seam_strength": 0.35, "mark": Color("f4f4f0"), "mark2": Color("f2b836"),
				"ring": Color("221c2a"), "lip": Color("c87a50"), "pattern": 2, "plate_size": 0.09,
				"iris": Color("e8b038"), "squareness": 3.2, "tri": 0.1, "keel": 0.0,
				"rear_h": 0.74, "rear_w": 0.66, "carapace_end": 0.3, "pivot": 0.44, "stalk": 0.2,
				"tail": [0.17, 0.22, 0.24, 0.22, 0.17], "tail_spread": 1.2,
				"fin": Color("2a3a7a"), "fin_edge": 1.3, "fin_rays": Color("f2c040"), "tint_fins": false,
				"horns": Vector2.ZERO, "horn_radius": 0.0,
			}
		3:  # Scrawled Cowfish: olive with electric-blue scribbles, short horns.
			return {
				"albedo": Color("a6a462"), "back_shade": 0.68, "belly": Color("d4d2ac"), "belly_mix": 0.6,
				"seam": Color("3a3a10"), "seam_strength": 0.45, "mark": Color("3a7ad8"), "mark2": Color("5a9ae8"),
				"ring": Color("1a3a6a"), "lip": Color("c88a5a"), "pattern": 3, "plate_size": 0.085,
				"iris": Color("a0a448"), "squareness": 2.6, "tri": 0.34, "keel": 0.1,
				"rear_h": 0.7, "rear_w": 0.68, "carapace_end": 0.28, "pivot": 0.43, "stalk": 0.18,
				"tail": [0.18, 0.23, 0.25, 0.23, 0.18], "tail_spread": 1.1,
				"fin": Color("9a9a6a"), "fin_edge": 1.15, "fin_rays": Color("3a7ad8"), "tint_fins": true,
				"horns": Vector2(0.095, 0.085), "horn_radius": 0.036,
			}
		_:  # Yellow Boxfish: lemon shell, a black-ringed white spot on every plate.
			return {
				"albedo": Color("f6cc1e"), "back_shade": 0.8, "belly": Color("faE27a"), "belly_mix": 0.6,
				"seam": Color("7a5a00"), "seam_strength": 0.45, "mark": Color("fbfbf4"), "mark2": Color("fbfbf4"),
				"ring": Color("111111"), "lip": Color("d88a50"), "pattern": 0, "plate_size": 0.09,
				"iris": Color("3f80d0"), "squareness": 3.5, "tri": 0.06, "keel": 0.0,
				"rear_h": 0.72, "rear_w": 0.64, "carapace_end": 0.3, "pivot": 0.44, "stalk": 0.2,
				"tail": [0.17, 0.22, 0.24, 0.22, 0.17], "tail_spread": 1.2,
				"fin": Color("f2c81a"), "fin_edge": 1.12, "fin_rays": Color("a87a00"), "tint_fins": true,
				"horns": Vector2.ZERO, "horn_radius": 0.0,
			}


static func build(m: FishModel) -> void:
	var p := _params(m.species)
	var g := _geometry(m, p)
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	# A unit box scaled to the hitbox, so it all squashes as one; `inside` undoes
	# that, so everything in it is placed in model metres (and the Body, at its
	# origin, has model coordinates for the bend).
	m.squash = Node3D.new()
	m.squash.name = "Squash"
	m._squash_base = m._size
	m.squash.scale = m._squash_base
	m.add_child(m.squash)
	var inside := Node3D.new()
	inside.name = "Inside"
	inside.scale = Vector3.ONE / m._squash_base
	m.squash.add_child(inside)

	var albedo: Color = p.albedo
	m._body_material = m._material(albedo)  # for set_body_color(); the skin does the shading
	var skin := _skin_material(p, false)
	m._skins.append(skin)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _body_mesh(g)
	body.material_override = skin
	inside.add_child(body)

	# Fins: translucent fans that flutter fast (a boxfish sculls with them).
	var fin_color: Color = p.fin
	var fins := m._fin_material(fin_color, Color(), 9.0, 0.012, 2.6, 0.82)
	fins.set_shader_parameter("edge_shade", p.fin_edge)
	fins.set_shader_parameter("ray_color", p.fin_rays)
	var clear := m._fin_material(fin_color, Color(), 10.0, 0.01, 3.2, 0.5)
	clear.set_shader_parameter("edge_shade", p.fin_edge)
	clear.set_shader_parameter("ray_color", fin_color.darkened(0.25))
	if p.tint_fins:
		m._skins.append_array([fins, clear])
	var zc0: float = g.zc0
	var zc: float = g.zc
	var zp: float = g.zp
	# Pectorals low on the sides behind the eyes, on the swim animation's pivots.
	var pectoral := _surface(g, -l * 0.15, 0.6, 1.0)
	m._fin_pivots(Vector3(pectoral.x - 0.01, pectoral.y, pectoral.z), inside)
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		m._membrane(pivot, clear, Vector3(0.0, h * 0.07, -0.01), Vector3(0.0, -h * 0.07, 0.01), Vector3(side * 0.75, -0.05, 1.0),
				[l * 0.1, l * 0.14, l * 0.15, l * 0.11], -0.9, 0.05)
	# A rounded dorsal fin on the back near the rear of the shell, an anal fin
	# under it.
	var fin_from := zc0 - l * 0.15
	var fin_to := zc0 - l * 0.05
	var dorsal := m._membrane(inside, fins, _surface(g, fin_from, 0.0, 1.0) - Vector3(0.0, 0.012, 0.0), _surface(g, fin_to, 0.0, 1.0) - Vector3(0.0, 0.012, 0.0),
			Vector3(0.0, 1.0, 0.8), [l * 0.06, l * 0.1, l * 0.11, l * 0.07], -0.35, 0.06)
	dorsal.name = "Dorsal"
	var anal := m._membrane(inside, clear if m.species == 2 else fins, _surface(g, fin_from + l * 0.01, 1.0, 1.0) + Vector3(0.0, 0.012, 0.0),
			_surface(g, fin_to + l * 0.01, 1.0, 1.0) + Vector3(0.0, 0.012, 0.0), Vector3(0.0, -1.0, 0.8),
			[l * 0.05, l * 0.09, l * 0.1, l * 0.06], 0.35, 0.06)
	anal.name = "Anal"

	# The tail: the stalk bends out of the back of the shell (only behind zc,
	# where the shell has closed round it) and the fan rides its end.
	var stalk_end := _slice(g, zp)
	m._tail_pivot(Vector3(0.0, stalk_end[3], zp), inside)
	m.bend_share = 0.55
	m._bend_body(zc)
	var stalk: float = stalk_end[2]
	var tail_lengths: Array = []
	for f: float in p.tail:
		tail_lengths.append(l * f)
	m._membrane(m.tail, fins, Vector3(0.0, stalk * 0.9, -0.016), Vector3(0.0, -stalk * 0.9, -0.016), Vector3(0.0, 0.0, 1.0),
			tail_lengths, -float(p.tail_spread), 0.05).name = "Caudal"

	# Real eyes on their mounds, riding the squash without squashing.
	var eye_z: float = g.ez
	var eye_fold: float = g.efold
	var iris: Color = p.iris
	for side: float in [-1.0, 1.0]:
		var at := _surface(g, eye_z, eye_fold, side)
		var outward := Vector3(side, 0.35, -0.2).normalized()
		var radius := h * 0.095
		var anchor := m._face_anchor(at - outward * radius * 0.34)
		var eye := m._real_eye(Vector3.ZERO, radius, Vector3(side, 0.22, -0.32), iris, 0.46, anchor)
		var look := eye.material_override as ShaderMaterial
		look.set_shader_parameter("rim_color", albedo.darkened(0.75))
		look.set_shader_parameter("sheen", 0.55)
		look.set_shader_parameter("iris_inner", iris.darkened(0.3))
		look.set_shader_parameter("pupil", 0.4)

	# Cowfish horns: a pair forward off the brow, a pair back off the rear
	# corners of the belly. They're part of the shell, so they squash with it.
	var horns: Vector2 = p.horns
	if horns.x > 0.0:
		var horn_skin := _skin_material(p, true)
		m._skins.append(horn_skin)
		var radius: float = h * float(p.horn_radius)
		for side: float in [-1.0, 1.0]:
			var brow := _surface(g, float(g.zf) + l * 0.09, 0.17, side)
			_horn(inside, horn_skin, brow, Vector3(side * 0.1, 0.16, -1.0), l * horns.x, radius, 0.12, m)
			var corner := _surface(g, zc0 - l * 0.035, 0.8, side)
			_horn(inside, horn_skin, corner, Vector3(side * 0.12, -0.12, 1.0), l * horns.y, radius * 0.9, -0.1, m)


## One horn: a tapering tube from `root` (its base buried in the shell) along
## `direction`, `length` m long and `radius` m thick at its base, curling by `curl`.
static func _horn(parent: Node3D, material: ShaderMaterial, root: Vector3, direction: Vector3, length: float, radius: float,
		curl: float, m: FishModel) -> void:
	var along := direction.normalized()
	var horn := MeshInstance3D.new()
	horn.name = "Horn"
	horn.mesh = m._tube_mesh(length + radius * 2.0, radius, curl)
	horn.material_override = material
	horn.position = root - along * radius * 2.0
	horn.basis = Basis.looking_at(-along, Vector3.UP)
	parent.add_child(horn)


## The shell's skin (box_skin.gdshader); `horn` for the cowfish's horns.
static func _skin_material(p: Dictionary, horn: bool) -> ShaderMaterial:
	var skin := ShaderMaterial.new()
	skin.shader = BOX_SKIN
	skin.set_shader_parameter("albedo", p.albedo)
	skin.set_shader_parameter("horn", horn)
	skin.set_shader_parameter("pattern", p.pattern)
	skin.set_shader_parameter("plate_size", p.plate_size)
	skin.set_shader_parameter("back_shade", p.back_shade)
	skin.set_shader_parameter("belly_color", p.belly)
	skin.set_shader_parameter("belly_mix", p.belly_mix)
	skin.set_shader_parameter("seam_color", p.seam)
	skin.set_shader_parameter("seam_strength", p.seam_strength)
	skin.set_shader_parameter("mark_color", p.mark)
	skin.set_shader_parameter("mark_color2", p.mark2)
	skin.set_shader_parameter("ring_color", p.ring)
	skin.set_shader_parameter("lip_color", p.lip)
	return skin


## Where things are along the fish (model z, m) and its shape's settings.
static func _geometry(m: FishModel, p: Dictionary) -> Dictionary:
	var h := m._size.y
	var l := m._size.z
	var g := p.duplicate()
	g.w = m._size.x
	g.h = h
	g.l = l
	g.zf = -l * 0.482  # the face's front, round the mouth (the lips stand out of it)
	g.df = l * 0.13  # how deep the face rounds back into the box
	g.zc0 = l * float(p.carapace_end)  # the shell starts closing round the stalk
	g.zc = g.zc0 + l * 0.065  # the stalk comes out of the shell
	g.zp = l * float(p.pivot)  # the tail pivot, at the end of the stalk
	g.cap = l * 0.016
	g.rm = h * 0.062  # the mouth ring's half height
	g.mouth_y = -h * 0.16
	g.ez = g.zf + l * 0.17  # the eyes
	g.efold = 0.33  # of the way round from the top to the belly
	g.bulge = h * 0.05  # the eye mounds
	return g


## The box at `z` before the face rounds in or the shell closes round the
## stalk: [half width, half height, centre y] (m).
static func _box(g: Dictionary, z: float) -> Vector3:
	var w: float = g.w
	var h: float = g.h
	var l: float = g.l
	var zf: float = g.zf
	var zc0: float = g.zc0
	var keel: float = g.keel
	var rear := smoothstep(-l * 0.22, zc0, z)
	var rear_h: float = g.rear_h
	var rear_w: float = g.rear_w
	var top := h * 0.485 / (1.0 + keel * 0.9) * lerpf(0.6, 1.0, smoothstep(zf, zf + l * 0.34, z)) * lerpf(1.0, rear_h, rear)
	var bottom := -h * 0.485 * lerpf(0.78, 1.0, smoothstep(zf, zf + l * 0.22, z)) * lerpf(1.0, rear_h, rear)
	var half_w := w * 0.48 * lerpf(0.8, 1.0, smoothstep(zf, zf + l * 0.3, z)) * lerpf(1.0, rear_w, rear)
	return Vector3(half_w, (top - bottom) / 2.0, (top + bottom) / 2.0)


## The tail stalk's slice at `z`: [half width, half height, centre y] (m),
## laterally flattened, thinning then flaring a little into the fan.
static func _stalk(g: Dictionary, z: float) -> Vector3:
	var zc: float = g.zc
	var zp: float = g.zp
	var t := clampf((z - zc) / (zp - zc), 0.0, 1.0)
	var size: float = float(g.h) * float(g.stalk)
	var hh := size * (lerpf(1.0, 0.74, smoothstep(0.0, 0.75, t)) + 0.07 * smoothstep(0.65, 1.0, t))
	return Vector3(hh * 0.58, hh, _box(g, float(g.zc0)).z)


## The body's slice at `z` (any z from the face back to the tail's end):
## [z, half width, half height, centre y, squareness, top narrowing, keel,
## plates, lips, mouth].
static func _slice(g: Dictionary, z: float) -> PackedFloat32Array:
	var zf: float = g.zf
	var df: float = g.df
	var zc0: float = g.zc0
	var zc: float = g.zc
	var zp: float = g.zp
	var n: float = g.squareness
	var tri: float = g.tri
	var keel: float = g.keel
	if z < zf + df:
		# The face rounds back from the mouth ring into the box.
		var t := clampf((z - zf) / df, 0.0, 1.0)
		var f := pow(1.0 - pow(1.0 - t, 2.3), 1.0 / 2.3)
		var rm: float = g.rm
		var mouth := Vector3(rm * 1.3, rm, g.mouth_y)
		var box := mouth.lerp(_box(g, z), f)
		return PackedFloat32Array([z, box.x, box.y, box.z, lerpf(2.0, n, f), tri * f, keel * f,
				smoothstep(0.2, 0.7, f), 1.0 - smoothstep(0.0, 0.035, t), 0.0])
	if z < zc0:
		var box := _box(g, z)
		return PackedFloat32Array([z, box.x, box.y, box.z, n, tri, keel, 1.0, 0.0, 0.0])
	if z < zc:
		# The back of the shell rounds in round the stalk coming out of it.
		var t := (z - zc0) / (zc - zc0)
		var f := pow(1.0 - pow(t, 3.0), 1.5)
		var box := _stalk(g, zc).lerp(_box(g, zc0), f)
		return PackedFloat32Array([z, box.x, box.y, box.z, lerpf(2.0, n, f), tri * f, keel * f, smoothstep(0.5, 0.92, f), 0.0, 0.0, smoothstep(0.55, 0.95, f)])
	var stalk := _stalk(g, minf(z, zp))
	if z > zp:
		var cap: float = g.cap
		stalk = Vector3(stalk.x, stalk.y, 0.0) * sqrt(maxf(1.0 - pow((z - zp) / cap, 2.0), 0.0)) + Vector3(0.0, 0.0, stalk.z)
	var cap_marks := 1.0 - smoothstep(-0.3, 0.4, (z - zp) / float(g.cap))
	return PackedFloat32Array([z, stalk.x, stalk.y, stalk.z, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, cap_marks])


## The lips' slice: a ring `size` of the mouth's at `z`; `inside` 1 in the mouth.
static func _lip_slice(g: Dictionary, z: float, size: float, inside: float) -> PackedFloat32Array:
	var rm: float = g.rm
	return PackedFloat32Array([z, rm * 1.3 * size, rm * size, g.mouth_y, 2.0, 0.0, 0.0, 0.0, 1.0 - inside * 0.6, inside])


## The point on `slice` (_slice) `theta` round from the top (toward +X first):
## a superellipse, flatter on the belly, narrowing toward the top for the
## cowfish's triangular shells, with a ridge along the back and mounds for the eyes.
static func _point(g: Dictionary, slice: PackedFloat32Array, theta: float) -> Vector3:
	var s := sin(theta)
	var c := cos(theta)
	var n := slice[4]
	var e := 2.0 / (n if c >= 0.0 else 2.0 + (n - 2.0) * 1.6)
	var sx := signf(s) * pow(absf(s), e)
	var sy := signf(c) * pow(absf(c), e)
	var narrow := 1.0 - slice[5] * pow(clampf((sy + 0.25) / 1.25, 0.0, 1.0), 1.4)
	var x := sx * slice[1] * narrow
	var y := slice[3] + sy * slice[2] + slice[6] * slice[2] * maxf(sy, 0.0) * exp(-pow(sx / 0.35, 2.0))
	var fold := acos(clampf(c, -1.0, 1.0)) / PI
	var ez: float = g.ez
	var efold: float = g.efold
	var bulge: float = g.bulge
	x += signf(s) * bulge * slice[7] * exp(-pow((slice[0] - ez) / (float(g.l) * 0.05), 2.0) - pow((fold - efold) / 0.12, 2.0))
	return Vector3(x, y, slice[0])


## The body's surface at `z`, `fold` of the way round from the top (0) to the
## belly (1), on `side` (+1 right, -1 left).
static func _surface(g: Dictionary, z: float, fold: float, side: float) -> Vector3:
	var theta := PI * fold if side > 0.0 else TAU - PI * fold
	return _point(g, _slice(g, z), theta)


## Every slice of the body, from inside the mouth to the tail's end.
static func _slices(g: Dictionary) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	var zf: float = g.zf
	var df: float = g.df
	var zc0: float = g.zc0
	var zc: float = g.zc
	var zp: float = g.zp
	var cap: float = g.cap
	for i in LIPS.size():
		out.append(_lip_slice(g, zf + LIPS[i].x, LIPS[i].y, clampf(1.0 - i / 2.0, 0.0, 1.0)))
	for i in FACE_ROWS:
		var u := float(i) / FACE_ROWS
		out.append(_slice(g, zf + df * u * u))
	for i in BODY_ROWS:
		out.append(_slice(g, lerpf(zf + df, zc0, float(i) / BODY_ROWS)))
	for i in REAR_ROWS:
		var u := float(i) / REAR_ROWS
		out.append(_slice(g, lerpf(zc0, zc, 1.0 - (1.0 - u) * (1.0 - u))))
	for i in STALK_ROWS:
		out.append(_slice(g, lerpf(zc, zp, float(i) / STALK_ROWS)))
	for i in CAP_ROWS + 1:
		out.append(_slice(g, zp + cap * sin(PI / 2.0 * float(i) / CAP_ROWS)))
	return out


## The body as one mesh. UV is in metres for painting plates: x along the
## surface from inside the mouth, y round from the top. COLOR carries (plates,
## lips, fold: 0 the top to 1 the belly, inside the mouth).
static func _body_mesh(g: Dictionary) -> ArrayMesh:
	var slices := _slices(g)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var meridian := PackedFloat32Array()
	meridian.resize(AROUND)
	meridian.fill(0.0)
	var last := PackedVector3Array()
	var half := AROUND / 2
	var zc: float = g.zc
	var stalk_started := false
	for i in slices.size():
		var slice := slices[i]
		var ring := PackedVector3Array()
		for k in AROUND:
			ring.append(_point(g, slice, TAU * k / AROUND))
		var arc := PackedFloat32Array()
		arc.resize(AROUND)
		arc[0] = 0.0
		for k in range(1, half + 1):
			arc[k] = arc[k - 1] + ring[k].distance_to(ring[k - 1])
		# Out of the shell the stalk starts its own lengthwise measure: the shell's
		# back runs much further down its sides than its top, which would shear
		# the stalk's markings (they fade out round the back, hiding the jump).
		if not stalk_started and slice[0] >= zc and i > 0:
			stalk_started = true
			var top_line := meridian[0] + ring[0].distance_to(last[0])
			for k in AROUND:
				meridian[k] = top_line - ring[k].distance_to(last[k])
		for k in range(half + 1, AROUND):
			arc[k] = arc[AROUND - k]  # the left side mirrors the right
		for k in AROUND:
			if i > 0:
				meridian[k] += ring[k].distance_to(last[k])
			var fold := acos(clampf(cos(TAU * k / AROUND), -1.0, 1.0)) / PI
			tool.set_color(Color(slice[7], slice[8], fold, slice[9]))
			tool.set_uv(Vector2(meridian[k], arc[k]))
			tool.set_uv2(Vector2(slice[10] if slice.size() > 10 else 1.0, 0.0))
			tool.add_vertex(ring[k])
		last = ring
	for i in slices.size() - 1:
		for k in AROUND:
			var a := i * AROUND + k
			var b := i * AROUND + (k + 1) % AROUND
			for corner: int in [a, b, a + AROUND, b, b + AROUND, a + AROUND]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()
