class_name KoiModel
extends RefCounted
## Hybrid's koi (FishModel.build hands it here): a butterfly koi in skin m.skin
## of FishCharacter.SKINS[FishCharacter.Family.HYBRID] (LOOKS, in that order).
## One smooth carp body from its fleshy lips (a real open mouth) back to its
## tail stalk (_body_mesh), painted by koi_skin.gdshader with big overlapping
## scales; long, frilly, rippling fins (_fin, koi_fin.gdshader) and a big
## flowing tail; two pairs of barbels and real eyes. The back half of the body
## bends into the tail as it wags (FishModel._bend_body), fins and all.

const SKIN := preload("res://shaders/koi_skin.gdshader")
const FIN := preload("res://shaders/koi_fin.gdshader")

## The body's outline from its snout (just behind the lips, 0) to its tail
## stalk (1), evenly spaced: its top and bottom (of the half height) and its
## half width (of the widest).
const TOP := [0.06, 0.45, 0.68, 0.84, 0.94, 0.97, 0.94, 0.86, 0.73, 0.58, 0.45, 0.37, 0.43]
const BOTTOM := [-0.4, -0.66, -0.8, -0.9, -0.96, -0.97, -0.95, -0.89, -0.77, -0.6, -0.45, -0.36, -0.42]
const WIDE := [0.42, 0.66, 0.8, 0.92, 0.99, 1.0, 0.96, 0.86, 0.7, 0.51, 0.34, 0.22, 0.14]
## The mouth and lips as rings, from inside the throat out to the lips' rim and
## back over them to the snout: [z from the snout (of the hitbox length), half
## width (of the body's), half height (of its), height (of its half height)
## above the lips' middle (LIPS_Y), UV.x (below 0 the lips, below -0.25 inside
## the mouth), how much it leans (upper lip forward, MOUTH_LEAN)].
const MOUTH := [
	[0.003, 0.0, 0.0, 0.0, -1.0, 1.0],
	[-0.005, 0.04, 0.03, 0.0, -1.0, 1.0],
	[-0.014, 0.07, 0.055, 0.0, -0.8, 1.0],
	[-0.0195, 0.1, 0.075, 0.0, -0.5, 1.0],
	[-0.0215, 0.15, 0.11, 0.005, -0.2, 1.0],
	[-0.0185, 0.2, 0.15, 0.015, -0.12, 0.9],
	[-0.0125, 0.225, 0.17, 0.03, -0.07, 0.7],
	[-0.006, 0.215, 0.165, 0.045, -0.035, 0.4],
	[-0.002, 0.3, 0.2, 0.08, -0.012, 0.15],
]
const LIPS_Y := -0.32
const LIP_REACH := 0.0215  # of the hitbox length: how far the lips reach past the snout
const MOUTH_LEAN := 0.55
const AROUND := 48
const BODY_ROWS := 92
const CAP_ROWS := 8
const CAP := 0.07  # of the body's length past the stalk: it narrows to a thin blade the tail fin grows out of
const SCALE_ROWS := 26.0  # scales round the body
const GILL := 0.2  # where the gill cover ends, along the body
const BEND_FROM := 0.4  # where the body starts to bend into the tail

## Each skin: the skin shader's variety and colours (albedo is the one a team
## tint replaces), the barbels', the eyes', and the fins': pectorals, dorsal,
## the low fins (pelvics and anal) and the tail. A fin: root and edge colours,
## its rays, how see-through its edge is (alpha), a patch of `base` colour at
## its root `base_len` deep over `base_span` of it, dark rays (`stripe`) out
## `stripe_len`, and how metallic it is. `tint`: the fins follow a team tint.
const LOOKS := [
	{  # Kohaku
		"variety": 0, "albedo": Color(0.85, 0.19, 0.12), "base": Color(0.965, 0.955, 0.93),
		"second": Color(0.95, 0.94, 0.91), "third": Color(0.05, 0.045, 0.04),
		"lip": Color(0.96, 0.89, 0.86), "barbel": Color(0.95, 0.89, 0.85), "iris": Color(0.78, 0.6, 0.23), "seed": 3.0,
		"tint": false,
		"pect": {"root": Color(0.98, 0.96, 0.93), "edge": Color(1.0, 1.0, 1.0), "ray": Color(0.9, 0.8, 0.74)},
		"dorsal": {"root": Color(0.97, 0.95, 0.92), "edge": Color(1.0, 1.0, 1.0), "ray": Color(0.88, 0.78, 0.72)},
		"low": {"root": Color(0.98, 0.96, 0.93), "edge": Color(1.0, 1.0, 1.0), "ray": Color(0.9, 0.8, 0.74)},
		"tail": {"root": Color(0.97, 0.95, 0.92), "edge": Color(1.0, 1.0, 1.0), "ray": Color(0.86, 0.76, 0.7)},
	},
	{  # Showa
		"variety": 1, "albedo": Color(0.8, 0.18, 0.11), "base": Color(0.05, 0.045, 0.04),
		"second": Color(0.95, 0.935, 0.9), "third": Color(0.045, 0.04, 0.038),
		"lip": Color(0.55, 0.5, 0.48), "barbel": Color(0.35, 0.32, 0.3), "iris": Color(0.62, 0.47, 0.22), "seed": 11.0,
		"tint": false,
		"pect": {"root": Color(0.95, 0.94, 0.91), "edge": Color(1.0, 1.0, 1.0), "ray": Color(0.8, 0.78, 0.76),
				"base": Color(0.05, 0.045, 0.04), "base_len": 0.32, "stripe": Color(0.06, 0.055, 0.05), "stripe_len": 0.8},
		"dorsal": {"root": Color(0.95, 0.94, 0.91), "edge": Color(1.0, 1.0, 1.0), "ray": Color(0.75, 0.72, 0.7),
				"base": Color(0.05, 0.045, 0.04), "base_len": 0.55, "base_span": Vector2(-0.1, 0.3)},
		"low": {"root": Color(0.95, 0.94, 0.91), "edge": Color(1.0, 1.0, 1.0), "ray": Color(0.75, 0.72, 0.7),
				"base": Color(0.05, 0.045, 0.04), "base_len": 0.3},
		"tail": {"root": Color(0.95, 0.94, 0.91), "edge": Color(1.0, 1.0, 1.0), "ray": Color(0.75, 0.72, 0.7),
				"base": Color(0.05, 0.045, 0.04), "base_len": 0.32},
	},
	{  # Yamabuki Ogon
		"variety": 2, "albedo": Color(0.95, 0.74, 0.2), "base": Color(0.95, 0.74, 0.2),
		"second": Color(1.0, 0.94, 0.66), "third": Color(0.66, 0.45, 0.05),
		"lip": Color(0.97, 0.8, 0.4), "barbel": Color(0.93, 0.74, 0.3), "iris": Color(0.95, 0.75, 0.3), "seed": 5.0,
		"tint": true,
		"pect": {"root": Color(0.95, 0.74, 0.2), "edge": Color(0.98, 0.86, 0.45), "ray": Color(0.72, 0.5, 0.08),
				"alpha": 0.55, "metal": 0.75, "edge_shade": 1.12},
		"dorsal": {"root": Color(0.95, 0.74, 0.2), "edge": Color(0.98, 0.86, 0.45), "ray": Color(0.72, 0.5, 0.08),
				"alpha": 0.55, "metal": 0.75, "edge_shade": 1.12},
		"low": {"root": Color(0.95, 0.74, 0.2), "edge": Color(0.98, 0.86, 0.45), "ray": Color(0.72, 0.5, 0.08),
				"alpha": 0.55, "metal": 0.75, "edge_shade": 1.12},
		"tail": {"root": Color(0.95, 0.74, 0.2), "edge": Color(0.98, 0.86, 0.45), "ray": Color(0.72, 0.5, 0.08),
				"alpha": 0.55, "edge_shade": 1.12},
	},
	{  # Asagi
		"variety": 3, "albedo": Color(0.42, 0.55, 0.67), "base": Color(0.42, 0.55, 0.67),
		"second": Color(0.96, 0.46, 0.21), "third": Color(0.8, 0.84, 0.87),
		"lip": Color(0.95, 0.72, 0.6), "barbel": Color(0.93, 0.7, 0.58), "iris": Color(0.74, 0.65, 0.5), "seed": 7.0,
		"tint": false,
		"pect": {"root": Color(0.9, 0.42, 0.2), "edge": Color(0.92, 0.87, 0.82), "ray": Color(0.85, 0.45, 0.25),
				"base": Color(0.88, 0.38, 0.17), "base_len": 0.28},
		"dorsal": {"root": Color(0.45, 0.57, 0.68), "edge": Color(0.8, 0.85, 0.88), "ray": Color(0.36, 0.46, 0.56)},
		"low": {"root": Color(0.9, 0.42, 0.2), "edge": Color(0.92, 0.87, 0.82), "ray": Color(0.85, 0.45, 0.25),
				"base": Color(0.88, 0.38, 0.17), "base_len": 0.25},
		"tail": {"root": Color(0.6, 0.69, 0.77), "edge": Color(0.86, 0.89, 0.91), "ray": Color(0.45, 0.55, 0.64)},
	},
]


static func build(m: FishModel) -> void:
	var look: Dictionary = LOOKS[clampi(m.skin, 0, LOOKS.size() - 1)]
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	var semi := Vector2(w * 0.2, h * 0.47)
	var nose := -l * 0.5 + l * LIP_REACH  # the snout, behind the lips
	var length := l * 0.8 - l * LIP_REACH  # snout to tail stalk
	var tint: bool = look.tint

	# The body and its skin.
	var albedo: Color = look.albedo
	m._body_material = m._material(albedo)  # for set_body_color(); the skin does the shading
	var skin := ShaderMaterial.new()
	skin.shader = SKIN
	skin.set_shader_parameter("albedo", albedo)
	skin.set_shader_parameter("variety", look.variety)
	skin.set_shader_parameter("base_color", look.base)
	skin.set_shader_parameter("second_color", look.second)
	skin.set_shader_parameter("third_color", look.third)
	skin.set_shader_parameter("lip_color", look.lip)
	skin.set_shader_parameter("seed", look.seed)
	skin.set_shader_parameter("gill_t", GILL)
	skin.set_shader_parameter("scales_t", GILL + 0.04)
	skin.set_shader_parameter("rows_around", SCALE_ROWS)
	m._skins.append(skin)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _body_mesh(nose, length, semi, l)
	body.material_override = skin
	m.add_child(body)

	# Real eyes set into the sides of the head, and the nostrils in front of them.
	var eye_radius := l * 0.02
	var iris: Color = look.iris
	for side: float in [-1.0, 1.0]:
		var normal := _normal(0.115, 0.22, side, semi)
		var at := _surface(0.115, 0.22, side, nose, length, semi) - normal * eye_radius * 0.42
		var eye := m._real_eye(at, eye_radius, normal + Vector3(0.0, 0.05, -0.3), iris, 0.47)
		(eye.material_override as ShaderMaterial).set_shader_parameter("iris_size", 0.86)
		if side > 0.0:
			skin.set_shader_parameter("eye_at", at)
			skin.set_shader_parameter("eye_radius", eye_radius)
	skin.set_shader_parameter("nostril", _surface(0.06, 0.42, 1.0, nose, length, semi))

	# Two pairs of barbels: long ones at the corners of the mouth, short ones on
	# the upper lip.
	var barbel_color: Color = look.barbel
	var barbel_material := m._material(barbel_color, 0.45)
	var lips_y := LIPS_Y * semi.y
	for side: float in [-1.0, 1.0]:
		for barbel: Array in [
				[Vector3(side * 0.25 * semi.x, lips_y - 0.02 * semi.y, nose - 0.011 * l), l * 0.045, Vector3(side * 0.55, -0.6, 0.6), -0.7],
				[Vector3(side * 0.13 * semi.x, lips_y + 0.13 * semi.y, nose - 0.017 * l), l * 0.024, Vector3(side * 0.45, -0.85, -0.25), -0.5]]:
			var whisker := MeshInstance3D.new()
			whisker.name = "Barbel"
			whisker.mesh = m._tube_mesh(barbel[1], l * 0.0036, barbel[3])
			whisker.material_override = barbel_material
			whisker.position = barbel[0]
			var direction: Vector3 = barbel[2]
			whisker.basis = Basis.looking_at(-direction.normalized())
			m.add_child(whisker)

	# The fins: long, soft and frilly, rippling in broad folds.
	var pect := _fin_look(m, look.pect, 16.0, 0.035, 0.8, tint)
	var dorsal_look := _fin_look(m, look.dorsal, 20.0, 0.03, 0.9, tint)
	var low := _fin_look(m, look.low, 14.0, 0.03, 0.85, tint)
	var bending: Array = []
	# Big butterfly pectorals on the swim animation's pivots.
	var pect_at := _surface(0.25, -0.62, 1.0, nose, length, semi) - _normal(0.25, -0.62, 1.0, semi) * 0.012
	m._fin_pivots(pect_at)
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		_fin(pivot, pect, [Vector3(0.0, 0.012, -0.03), Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.008, 0.03)],
				Vector3(side, -0.45, 0.75), [l * 0.13, l * 0.21, l * 0.26, l * 0.27, l * 0.21], 0.75, 0.1, 0.06,
				Vector3(side * 0.25, -0.55, 1.0).normalized() * 0.45, 80, 18, 1.0)
	# Pelvics under the belly, on the bending part.
	for side: float in [-1.0, 1.0]:
		var inset := Vector3(side * 0.012, 0.01, 0.0)
		bending.append(_fin(m, low, [_surface(0.45, -0.86, side, nose, length, semi) - inset, _surface(0.505, -0.86, side, nose, length, semi) - inset],
				Vector3(side * 0.45, -0.8, 0.65), [l * 0.1, l * 0.16, l * 0.2, l * 0.18], 0.55, 0.1, 0.06,
				Vector3(side * 0.2, -0.45, 1.0).normalized() * 0.45, 64, 16, 1.0))
	# The long dorsal fin along the back, and the anal fin underneath.
	var dorsal_roots: Array = []
	for t: float in [0.36, 0.43, 0.5, 0.57, 0.64, 0.7]:
		var slice := _slice(t, semi)
		dorsal_roots.append(Vector3(0.0, slice.z + slice.y - 0.008, nose + t * length))
	bending.append(_fin(m, dorsal_look, dorsal_roots, Vector3(0.0, 1.0, 0.75),
			[h * 0.4, h * 0.6, h * 0.62, h * 0.6, h * 0.58, h * 0.56], 0.25, 0.12, 0.06,
			Vector3(0.0, 0.1, 1.0).normalized() * 0.5, 96, 16, 2.0))
	var anal_roots: Array = []
	for t: float in [0.75, 0.79, 0.83]:
		var slice := _slice(t, semi)
		anal_roots.append(Vector3(0.0, slice.z - slice.y + 0.008, nose + t * length))
	bending.append(_fin(m, low, anal_roots, Vector3(0.0, -1.0, 0.65),
			[h * 0.3, h * 0.44, h * 0.42, h * 0.34], 0.25, 0.12, 0.06, Vector3(0.0, -0.3, 1.0).normalized() * 0.45, 64, 16, 1.0))

	# The big forked tail fan on its pivot. Its root runs the full height of the
	# flared, flattened stalk and starts well up it, so the body flows into it.
	var stalk := _slice(1.0, semi)
	m._tail_pivot(Vector3(0.0, stalk.z, nose + length * (1.0 + CAP * 0.7)))
	var tail_fin := _fin_look(m, look.tail, 22.0, 0.045, 0.75, tint)
	_fin(m.tail, tail_fin, [Vector3(0.0, stalk.y * 1.38, 0.01), Vector3(0.0, 0.0, -0.03), Vector3(0.0, -stalk.y * 1.38, 0.01)],
			Vector3(0.0, 0.0, 1.0), [l * 0.34, l * 0.31, l * 0.23, l * 0.16, l * 0.23, l * 0.31, l * 0.34], -1.15, 0.12, 0.05,
			Vector3.ZERO, 112, 18, 1.5)

	# Carp are flexible: the back half of the body takes most of the wag.
	m.bend_share = 0.82
	m._bend_body(nose + length * BEND_FROM, bending)


## The body's slice `t` along it (snout 0 to tail stalk 1): half width, half
## height and the height of its middle (m).
static func _slice(t: float, semi: Vector2) -> Vector3:
	var top := FishModel._sample(TOP, t) * semi.y
	var bottom := FishModel._sample(BOTTOM, t) * semi.y
	return Vector3(FishModel._sample(WIDE, t) * semi.x, (top - bottom) * 0.5, (top + bottom) * 0.5)


## A point on the body's skin `t` along it, `up` of the way from its middle to
## its top (-1 its belly), on its right side (`side` 1) or left (-1).
static func _surface(t: float, up: float, side: float, nose: float, length: float, semi: Vector2) -> Vector3:
	var slice := _slice(t, semi)
	return Vector3(side * slice.x * sqrt(maxf(1.0 - up * up, 0.0)), slice.z + slice.y * up, nose + t * length)


## The skin's outward direction there (ignoring the body's slope along it).
static func _normal(t: float, up: float, side: float, semi: Vector2) -> Vector3:
	var slice := _slice(t, semi)
	return Vector3(side * sqrt(maxf(1.0 - up * up, 0.0)) / slice.x, up / slice.y, 0.0).normalized()


## About how far round an oval `a` by `b` (half sizes) is.
static func _round_oval(a: float, b: float) -> float:
	return PI * (3.0 * (a + b) - sqrt(maxf((3.0 * a + b) * (a + 3.0 * b), 0.0)))


## The koi's body, one smooth shape: inside its mouth out over its lips, back
## along its body to its rounded-off tail stalk. UV.x: nose (0, the snout) to
## the stalk (1), the lips and mouth below 0; UV.y round it from the belly;
## UV2: its scales (koi_skin.gdshader), x along it (smaller toward the tail,
## as the body narrows) and y the SCALE_ROWS round it.
static func _body_mesh(nose: float, length: float, semi: Vector2, l: float) -> ArrayMesh:
	var rings: Array[Vector4] = []  # half width, half height, middle height, z
	var marks: Array[float] = []  # UV.x
	var leans: Array[float] = []
	var lips_y := LIPS_Y * semi.y
	for row: Array in MOUTH:
		rings.append(Vector4(float(row[1]) * semi.x, float(row[2]) * semi.y, lips_y + float(row[3]) * semi.y, nose + float(row[0]) * l))
		marks.append(float(row[4]))
		leans.append(float(row[5]))
	for i in BODY_ROWS + 1:
		var t := float(i) / BODY_ROWS
		var slice := _slice(t, semi)
		rings.append(Vector4(slice.x, slice.y, slice.z, nose + t * length))
		marks.append(t)
		leans.append(0.0)
	var stalk := _slice(1.0, semi)
	for k in range(1, CAP_ROWS + 1):
		var f := float(k) / CAP_ROWS
		var closing := pow(1.0 - f, 0.75)
		var tall := 1.0 + 0.45 * f * f
		rings.append(Vector4(stalk.x * closing, stalk.y * tall, stalk.z, nose + length * (1.0 + CAP * f)))
		marks.append(1.0 + CAP * f)
		leans.append(0.0)
	var stride := AROUND + 1
	var count := rings.size()
	var points := PackedVector3Array()
	points.resize(count * stride)
	var uvs := PackedVector2Array()
	uvs.resize(count * stride)
	var uv2s := PackedVector2Array()
	uv2s.resize(count * stride)
	var scales_along := 0.0
	for i in count:
		var ring := rings[i]
		if i > 0 and marks[i] > 0.0:
			var cell := maxf(_round_oval(ring.x, ring.y) / SCALE_ROWS * 0.85, 0.016)
			scales_along += (ring.w - rings[i - 1].w) / cell
		for k in stride:
			var v := float(k) / AROUND
			var angle := PI + TAU * float(k % AROUND) / AROUND
			var y := cos(angle) * ring.y
			points[i * stride + k] = Vector3(sin(angle) * ring.x, ring.z + y, ring.w - MOUTH_LEAN * leans[i] * y)
			uvs[i * stride + k] = Vector2(marks[i], v)
			uv2s[i * stride + k] = Vector2(scales_along, v * SCALE_ROWS)
	# Smooth normals straight off the grid (round the seam too).
	var normals := PackedVector3Array()
	normals.resize(count * stride)
	for i in count:
		var before := maxi(i - 1, 0)
		var after := mini(i + 1, count - 1)
		for k in AROUND:
			var along := points[after * stride + k] - points[before * stride + k]
			var around := points[i * stride + (k + 1) % AROUND] - points[i * stride + (k + AROUND - 1) % AROUND]
			var normal := along.cross(around)
			if normal.length_squared() < 1e-14:
				normal = Vector3.FORWARD if i == 0 else Vector3.BACK  # the closed throat, the tail's end
			normals[i * stride + k] = normal.normalized()
		normals[i * stride + AROUND] = normals[i * stride]
	var indices := PackedInt32Array()
	for i in count - 1:
		for k in AROUND:
			var a := i * stride + k
			var b := a + 1
			for corner: int in [a, b, a + stride, b, b + stride, a + stride]:
				indices.append(corner)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A fin's look (koi_fin.gdshader) from a LOOKS fin, rippling `flutter` m at
## its edge at `tempo`; with `tint` it follows a team tint.
static func _fin_look(m: FishModel, fin: Dictionary, rays: float, flutter: float, tempo: float, tint: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FIN
	material.set_shader_parameter("albedo", fin.root)
	material.set_shader_parameter("edge_color", fin.edge)
	material.set_shader_parameter("ray_color", fin.ray)
	material.set_shader_parameter("rays", rays)
	material.set_shader_parameter("flutter", flutter)
	material.set_shader_parameter("tempo", tempo)
	material.set_shader_parameter("edge_alpha", fin.get("alpha", 0.3))
	material.set_shader_parameter("root_alpha", fin.get("root_alpha", 0.8))
	material.set_shader_parameter("base_color", fin.get("base", Color.BLACK))
	material.set_shader_parameter("base_len", fin.get("base_len", 0.0))
	material.set_shader_parameter("base_span", fin.get("base_span", Vector2(-0.1, 1.1)))
	material.set_shader_parameter("stripe_color", fin.get("stripe", Color.BLACK))
	material.set_shader_parameter("stripe_len", fin.get("stripe_len", 0.0))
	material.set_shader_parameter("metallic", fin.get("metal", 0.0))
	if tint:
		material.set_shader_parameter("edge_shade", fin.get("edge_shade", 1.1))
		m._skins.append(material)
	m._waving.append(material)
	return material


## A long frilly fin on `parent`: rays fanning out of a root curve through
## `roots` (parent space) toward `out`, as long as `lengths` says along the root,
## `spread` (rad) fanning the outer ones apart. Its edge dips between the rays by
## `frill` (of their length) in soft scallops, the membrane ruffles by `ruffle`
## in about `folds` broad folds along it, and
## the rays flow round toward `droop` (its length: how far) as they go out.
## UV.x runs along the root and UV.y out to the edge (koi_fin, fin_membrane).
static func _fin(parent: Node3D, material: ShaderMaterial, roots: Array, out: Vector3, lengths: Array,
		spread: float, frill: float, ruffle: float, droop := Vector3.ZERO, columns := 72, rows := 14, folds := 2.5) -> MeshInstance3D:
	var rays: float = material.get_shader_parameter("rays")
	var first: Vector3 = roots[0]
	var last: Vector3 = roots[roots.size() - 1]
	var normal := (last - first).cross(out).normalized()
	var xs: Array = []
	var ys: Array = []
	var zs: Array = []
	for root: Vector3 in roots:
		xs.append(root.x)
		ys.append(root.y)
		zs.append(root.z)
	var trail_to := droop.normalized() if droop != Vector3.ZERO else out.normalized()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in columns + 1:
		var u := float(i) / columns
		var at := Vector3(FishModel._sample(xs, u), FishModel._sample(ys, u), FishModel._sample(zs, u))
		var direction := out.normalized().rotated(normal, (u - 0.5) * spread)
		var trail := direction.slerp(trail_to, clampf(droop.length(), 0.0, 1.0))
		var length := FishModel._sample(lengths, u) * (1.0 - frill * 0.5 * (1.0 - cos(u * rays * 0.5 * TAU)))
		for j in rows + 1:
			var v := float(j) / rows
			var wave := normal * ruffle * length * pow(v, 1.4) * sin(u * TAU * folds + v * 1.6)
			tool.set_uv(Vector2(u, v))
			tool.add_vertex(at + wave)
			at += direction.slerp(trail, v * v) * length / rows
	for i in columns:
		for j in rows:
			var a := i * (rows + 1) + j
			var b := a + rows + 1
			for corner: int in [a, b, a + 1, a + 1, b, b + 1]:
				tool.add_index(corner)
	tool.generate_normals()
	var fin := MeshInstance3D.new()
	fin.name = "Fin"
	fin.mesh = tool.commit()
	fin.material_override = material
	fin.extra_cull_margin = 0.15  # it ripples out of its bounds
	parent.add_child(fin)
	return fin
