class_name MantisModel
extends RefCounted
## The mantis shrimp (FishModel.build hands it here): skin m.skin of
## FishCharacter.SKINS[FishCharacter.Family.MANTIS].
##
## One continuous armoured body (_shell_mesh): a carapace, three free thoracic
## rings and six abdominal plates, each plate's front tucked under the one
## before it, so the ridges are in the shape and the seams painted on
## (mantis_shell.gdshader). The abdomen bends smoothly into the tail fan
## (FishModel._bend_body): the telson and the uropods ride the tail pivot. Its
## stalked trinocular eyes swivel on their own (mantis_eye.gdshader), its
## raptorial claws (a club, or a barbed spear) fold under its front on the swim
## animation's fin pivots, and its swimmerets beat under the abdomen.

const SHELL := preload("res://shaders/mantis_shell.gdshader")
const LIMB := preload("res://shaders/mantis_limb.gdshader")
const EYE := preload("res://shaders/mantis_eye.gdshader")

## Each skin (FishCharacter.SKINS order): its colours and markings, and its
## body's layout along its length (m): where the front is, then how long the
## carapace, each free thoracic ring, each of abdominal plates 1-5, the 6th and
## the telson are; and its half width and its height over and under its middle.
const SKINS := [
	{  # Peacock Mantis (Odontodactylus scyllarus): a smasher.
		"albedo": Color("3a9a3e"), "belly": Color("a8d878"), "belly_mix": 0.55, "top_shade": 0.55,
		"pattern": 0, "mark": Color("0e3a14"), "mark2": Color("0e3a14"), "mark_size": 0.016, "band_width": 0.0,
		"iridescence": 0.55, "sheen": Color(0.25, 0.75, 1.0), "margin_glow": 0.45,
		"front": -0.6, "carapace": 0.26, "thorax": 0.045, "abdomen": 0.095, "six": 0.075, "telson": 0.22,
		"width": 0.19, "top": 0.095, "bottom": 0.075,
		"claw": "club", "merus": Color("e8402a"), "club": Color("f05a7a"), "propodus": Color("f27a8a"),
		"meral_spot": Color(0, 0, 0, 0), "barb": Color("f0e0d0"),
		"leg": Color("e84a2a"), "swimmeret": Color("e86a3a"), "leg_bands": false,
		"scale": Color("f07a2a"), "scale_edge": Color("2a6ad8"), "thread": Color("e8823a"),
		"uropod": Color("2a6ad8"), "uropod_edge": Color("f08a2a"), "telson_edge": Color("f08a2a"),
		"eye": Color("5ac06a"), "eye2": Color("3a8a7a"), "eye_band": Color("102018"), "stripe": Color("7ad0f0"),
	},
	{  # Zebra Mantis (Lysiosquillina maculata): a long, banded spearer.
		"albedo": Color("cbbb94"), "belly": Color("ece2c4"), "belly_mix": 0.6, "top_shade": 0.82,
		"pattern": 1, "mark": Color("3a2a1a"), "mark2": Color("3a2a1a"), "mark_size": 0.012, "band_width": 0.022,
		"iridescence": 0.12, "sheen": Color(0.9, 0.85, 0.7), "margin_glow": 0.25,
		"front": -0.64, "carapace": 0.2, "thorax": 0.05, "abdomen": 0.105, "six": 0.085, "telson": 0.24,
		"width": 0.165, "top": 0.085, "bottom": 0.068,
		"claw": "spear", "merus": Color("b8a880"), "club": Color("cbbb94"), "propodus": Color("cbbb94"),
		"meral_spot": Color(0, 0, 0, 0), "barb": Color("3a2a1a"),
		"leg": Color("a8987a"), "swimmeret": Color("b8a880"), "leg_bands": true,
		"scale": Color("b8a880"), "scale_edge": Color("3a2a1a"), "thread": Color("8a7a5a"),
		"uropod": Color("b8a880"), "uropod_edge": Color("3a2a1a"), "telson_edge": Color("3a2a1a"),
		"eye": Color("8a8a8a"), "eye2": Color("6a6a70"), "eye_band": Color("1a1a1a"), "stripe": Color("a0a0a0"),
	},
	{  # Purple-spot Mantis (Gonodactylus smithii): a compact olive smasher.
		"albedo": Color("6e6a36"), "belly": Color("a8a068"), "belly_mix": 0.6, "top_shade": 0.68,
		"pattern": 2, "mark": Color("c8c090"), "mark2": Color("2a2a10"), "mark_size": 0.008, "band_width": 0.0,
		"iridescence": 0.15, "sheen": Color(0.6, 0.5, 1.0), "margin_glow": 0.3,
		"front": -0.57, "carapace": 0.25, "thorax": 0.042, "abdomen": 0.09, "six": 0.07, "telson": 0.19,
		"width": 0.2, "top": 0.1, "bottom": 0.08,
		"claw": "club", "merus": Color("7a7240"), "club": Color("c8b870"), "propodus": Color("c8b870"),
		"meral_spot": Color("7a3ab8"), "barb": Color("e8e0b0"),
		"leg": Color("9a3a3a"), "swimmeret": Color("8a7a4a"), "leg_bands": false,
		"scale": Color("7a6a9a"), "scale_edge": Color("4a3a8a"), "thread": Color("8a8450"),
		"uropod": Color("4a3a8a"), "uropod_edge": Color("8a7ac0"), "telson_edge": Color("4a3a8a"),
		"eye": Color("d8c060"), "eye2": Color("a88a30"), "eye_band": Color("1a1a0a"), "stripe": Color("e8d890"),
	},
	{  # Pink-eared Mantis (Odontodactylus latirostris): lime-olive, pink "ears".
		"albedo": Color("a2b85c"), "belly": Color("dce2a8"), "belly_mix": 0.55, "top_shade": 0.72,
		"pattern": 3, "mark": Color("4a6a1a"), "mark2": Color("4a6a1a"), "mark_size": 0.01, "band_width": 0.0,
		"iridescence": 0.25, "sheen": Color(1.0, 0.6, 0.8), "margin_glow": 0.4,
		"front": -0.6, "carapace": 0.26, "thorax": 0.045, "abdomen": 0.095, "six": 0.075, "telson": 0.22,
		"width": 0.19, "top": 0.095, "bottom": 0.075,
		"claw": "club", "merus": Color("c8d890"), "club": Color("f2a8b8"), "propodus": Color("f0c8c8"),
		"meral_spot": Color(0, 0, 0, 0), "barb": Color("f4e8d0"),
		"leg": Color("e8a080"), "swimmeret": Color("f080b0"), "leg_bands": false,
		"scale": Color("f070a8"), "scale_edge": Color("c83a70"), "thread": Color("c8d090"),
		"uropod": Color("a8c060"), "uropod_edge": Color("f080b0"), "telson_edge": Color("f080b0"),
		"eye": Color("6a8a4a"), "eye2": Color("4a6a3a"), "eye_band": Color("0a1a0a"), "stripe": Color("c0e0a0"),
	},
]

## The body's middle line (m above the hitbox centre).
const MIDDLE := -0.015


## A mesh in the making: vertices with colours and UVs, and triangles.
class Builder:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	func add(p: Vector3, c: Color, uv := Vector2.ZERO) -> void:
		verts.append(p)
		colors.append(c)
		uvs.append(uv)

	## Triangles over `rows` + 1 rings of `cols` vertices from `start`, round
	## each ring; `flip` turns them the other way out.
	func grid(start: int, rows: int, cols: int, flip := false) -> void:
		for i in rows:
			for k in cols:
				var a := start + i * cols + k
				var b := start + i * cols + (k + 1) % cols
				var c := a + cols
				var d := b + cols
				if flip:
					indices.append_array([a, c, b, b, c, d])
				else:
					indices.append_array([a, b, c, b, d, c])

	func commit() -> ArrayMesh:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in verts.size():
			tool.set_color(colors[i])
			tool.set_uv(uvs[i])
			tool.add_vertex(verts[i])
		for i in indices:
			tool.add_index(i)
		tool.generate_normals()
		return tool.commit()


static func build(m: FishModel) -> void:
	var sk: Dictionary = SKINS[clampi(m.skin, 0, SKINS.size() - 1)]
	var seams := _seams(sk)
	var albedo: Color = sk.albedo
	m._body_material = m._material(albedo)  # for set_body_color(); the shell shader does the shading

	# The body.
	var shell := _shell_material(m, sk, seams, Vector3.ZERO)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _shell_mesh(sk, seams)
	body.material_override = shell
	m.add_child(body)

	# The tail fan on the tail pivot, at the back of the 6th plate.
	var six_end: float = seams[seams.size() - 1]
	var pivot := Vector3(0.0, MIDDLE, six_end - 0.012)
	m._tail_pivot(pivot)
	m.bend_share = 0.65
	_tail_fan(m, sk, seams, pivot)

	# Swimmerets under abdominal plates 1-5, beating, bending with the abdomen.
	var swim := _swimmerets(m, sk, seams)
	m._bend_body(seams[4], [swim])

	# The rest of the limbs, the claws on the fin pivots, and the eyes.
	_legs(m, sk, seams)
	_claws(m, sk, seams)
	_head(m, sk, seams)


## Where each plate starts and ends along the body (m): the front, the
## carapace's back, the three thoracic rings', abdominal plates 1-5's and the
## 6th's.
static func _seams(sk: Dictionary) -> PackedFloat32Array:
	var seams := PackedFloat32Array()
	var z: float = sk.front
	seams.append(z)
	z += sk.carapace
	seams.append(z)
	for i in 3:
		z += sk.thorax
		seams.append(z)
	for i in 5:
		z += sk.abdomen
		seams.append(z)
	z += sk.six
	seams.append(z)
	return seams


static func _shell_material(m: FishModel, sk: Dictionary, seams: PackedFloat32Array, offset: Vector3) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHELL
	mat.set_shader_parameter("albedo", sk.albedo)
	mat.set_shader_parameter("belly_color", sk.belly)
	mat.set_shader_parameter("belly_mix", sk.belly_mix)
	mat.set_shader_parameter("top_shade", sk.top_shade)
	mat.set_shader_parameter("mark_color", sk.mark)
	mat.set_shader_parameter("mark_color2", sk.mark2)
	mat.set_shader_parameter("pattern", sk.pattern)
	mat.set_shader_parameter("mark_size", sk.mark_size)
	mat.set_shader_parameter("band_width", sk.band_width)
	mat.set_shader_parameter("accent_color", sk.telson_edge)
	mat.set_shader_parameter("sheen_color", sk.sheen)
	mat.set_shader_parameter("iridescence", sk.iridescence)
	mat.set_shader_parameter("margin_glow", sk.margin_glow)
	var padded := PackedFloat32Array(seams)
	padded.resize(12)
	mat.set_shader_parameter("seams", padded)
	mat.set_shader_parameter("seam_count", seams.size())
	mat.set_shader_parameter("carapace", Vector2(seams[0], seams[1]))
	var carapace_len: float = seams[1] - seams[0]
	mat.set_shader_parameter("extra_bands", Vector2(seams[0] + carapace_len * 0.4, seams[0] + carapace_len * 0.72))
	mat.set_shader_parameter("rest_offset", offset)
	m._skins.append(mat)
	return mat


# --- The body ---------------------------------------------------------------------

## The body's slice at `z` before its plates are shaped: half width, height over
## and under its middle.
static func _base_slice(sk: Dictionary, seams: PackedFloat32Array, z: float) -> Vector3:
	var w: float = sk.width
	var t: float = sk.top
	var b: float = sk.bottom
	var carapace_len: float = seams[1] - seams[0]
	# (z, half width, top, bottom), front to back.
	var keys := [
		[seams[0], 0.42, 0.42, 0.5],
		[seams[0] + carapace_len * 0.35, 0.66, 0.78, 0.78],
		[seams[1] - 0.012, 0.84, 0.92, 0.92],
		[seams[1] + 0.01, 0.76, 0.84, 0.9],
		[seams[4] - 0.01, 0.8, 0.88, 0.92],
		[seams[4] + 0.02, 0.9, 0.95, 0.98],
		[seams[7], 1.0, 1.0, 1.0],
		[seams[8], 0.99, 0.97, 0.96],
		[seams[9], 0.9, 0.86, 0.85],
		[seams[10], 0.7, 0.66, 0.68],
	]
	var last: Array = keys[keys.size() - 1]
	var slice := Vector3(last[1], last[2], last[3])
	if z <= keys[0][0]:
		slice = Vector3(keys[0][1], keys[0][2], keys[0][3])
	else:
		for i in keys.size() - 1:
			var a: Array = keys[i]
			var c: Array = keys[i + 1]
			if z <= c[0]:
				var f := smoothstep(float(a[0]), float(c[0]), z)
				slice = Vector3(lerpf(a[1], c[1], f), lerpf(a[2], c[2], f), lerpf(a[3], c[3], f))
				break
	return slice * Vector3(w, t, b)


## How much each plate's shape swells `along` it (0 its front, 1 its back): its
## front tucked under the plate before, its back margin a little proud.
static func _plate_swell(along: float, carapace: bool) -> float:
	if carapace:
		return 1.0 + 0.025 * smoothstep(0.85, 0.98, along)
	return 1.0 - 0.06 * (1.0 - smoothstep(0.0, 0.3, along)) + 0.018 * smoothstep(0.7, 0.96, along)


## One closed shell from the rostrum to the 6th plate's rounded back: slices a
## little flat underneath, domed over the back, each plate shaped (_plate_swell),
## with rows packed round the seams so the steps stay crisp.
static func _shell_mesh(sk: Dictionary, seams: PackedFloat32Array) -> ArrayMesh:
	var around := 48
	var front := seams[0]
	var back := seams[seams.size() - 1]
	var cap_front := 0.04
	var cap_back := 0.035
	# (z, swell) for every ring.
	var rings: Array[Vector2] = []
	for f: float in [0.0, 0.08, 0.2, 0.38, 0.58, 0.8, 1.0]:
		rings.append(Vector2(front + cap_front * (1.0 - cos(f * PI / 2.0)), 1.0))
	var carapace_rows := 14
	for i in range(1, carapace_rows + 1):
		var t := float(i) / carapace_rows
		var z := lerpf(front + cap_front, seams[1], t)
		rings.append(Vector2(z, _plate_swell((z - front) / (seams[1] - front), true)))
	for s in range(1, seams.size() - 1):
		var a := seams[s]
		var c := seams[s + 1]
		for t: float in [0.003, 0.07, 0.16, 0.3, 0.45, 0.62, 0.78, 0.9, 0.97, 1.0]:
			rings.append(Vector2(lerpf(a, c, t), _plate_swell(t, false)))
	for f: float in [0.25, 0.5, 0.72, 0.88, 0.97, 1.0]:
		rings.append(Vector2(back + cap_back * f, 1.0 - 0.03 * f))
	var builder := Builder.new()
	for r in rings.size():
		var z := rings[r].x
		var slice := _base_slice(sk, seams, clampf(z, front, back)) * rings[r].y
		var cap := 1.0
		if z < front + cap_front:
			cap = sqrt(maxf(1.0 - pow((front + cap_front - z) / cap_front, 2.0), 0.0))
		elif z > back:
			cap = sqrt(maxf(1.0 - pow((z - back) / cap_back, 2.0), 0.0))
		# The rostrum's end is a blunt, low shovel: flatter than it is wide.
		var cap_h := cap * cap if z < front + cap_front else cap
		for k in around:
			var angle := TAU * k / around
			var s := sin(angle)
			var c := cos(angle)
			var x := signf(s) * pow(absf(s), 0.62) * slice.x * cap
			var y := MIDDLE + (slice.y * pow(c, 0.62) if c >= 0.0 else -slice.z * pow(-c, 0.5)) * cap_h
			builder.add(Vector3(x, y, z), Color.WHITE, Vector2(float(r) / (rings.size() - 1), float(k) / around))
	builder.grid(0, rings.size() - 1, around)
	# The rostral plate: a small hinged shield over the front, between the eyes.
	var nose := _base_slice(sk, seams, front + cap_front)
	var shield := func(angle: float) -> float:
		var r := _oval(angle, 0.036, nose.x * 0.42)
		return r * (1.0 - 0.18 * maxf(-cos(angle), 0.0))  # narrower to its front
	_plate(builder, Vector3(0.0, MIDDLE + nose.y * 0.86, front + 0.014), Vector3.FORWARD, Vector3.UP.rotated(Vector3.RIGHT, 0.12),
			shield, Vector2(0.008, 0.004), func(_f: float, _a: float) -> Color: return Color.WHITE, 4, 20)
	return builder.commit()


## A point on the body's surface at `z`, `up` of the way from its middle to its
## top (-1 its bottom) and `out` of the way to its side (signed).
static func _surface(sk: Dictionary, seams: PackedFloat32Array, z: float, up: float, out := 0.0) -> Vector3:
	var slice := _base_slice(sk, seams, z)
	var y := MIDDLE + (slice.y * up if up >= 0.0 else slice.z * up)
	return Vector3(slice.x * out, y, z)


# --- Shapes -------------------------------------------------------------------------

## A smooth curve through `ctrl` (Catmull-Rom), `f` 0 its start to 1 its end.
static func _along(ctrl: Array, f: float) -> Vector3:
	var n := ctrl.size()
	var at := clampf(f, 0.0, 1.0) * (n - 1)
	var i := mini(int(at), n - 2)
	var a: Vector3 = ctrl[i]
	var b: Vector3 = ctrl[i + 1]
	var pre: Vector3 = ctrl[maxi(i - 1, 0)]
	var post: Vector3 = ctrl[mini(i + 2, n - 1)]
	return a.cubic_interpolate(b, pre, post, at - i)


## A tube along the curve through `ctrl`, `radii` thick along it (0 at an end
## closes it), its section `shape` (across its side, across its `hint` way).
## `color` is a Color or a Callable(f along it, point) -> Color.
static func _tube(b: Builder, ctrl: Array, radii: Array, rows: int, color: Variant, around := 10,
		shape := Vector2.ONE, hint := Vector3.UP, uv := Vector2.ZERO) -> void:
	var start := b.verts.size()
	for i in rows + 1:
		var f := float(i) / rows
		var p := _along(ctrl, f)
		var t := (_along(ctrl, minf(f + 0.01, 1.0)) - _along(ctrl, maxf(f - 0.01, 0.0))).normalized()
		var side := hint.cross(t)
		if side.length() < 1e-3:
			side = Vector3.BACK.cross(t)
		side = side.normalized()
		var up := t.cross(side)
		var r := FishModel._sample(radii, f)
		var c: Color = (color as Callable).call(f, p) if color is Callable else color
		for k in around:
			var angle := TAU * k / around
			b.add(p + side * sin(angle) * r * shape.x + up * cos(angle) * r * shape.y, c, Vector2(uv.x, f * uv.y))
	b.grid(start, rows, around)


## A thin plate (a scale, a uropod, the telson): an outline `outline`(angle) m
## from `centre` round its plane, angle 0 along `u`, domed `thick` (over,
## under) toward its middle along `n`. `color` is Callable(f out from the
## middle, angle) -> Color. UV.y runs along `u` from `root` (0) to `reach` m.
static func _plate(b: Builder, centre: Vector3, u: Vector3, n: Vector3, outline: Callable, thick: Vector2, color: Callable,
		rings := 6, segs := 28, uv_x := 0.0, root := Vector3.ZERO, reach := 1.0) -> void:
	var v := n.cross(u).normalized()
	for face in 2:
		var start := b.verts.size()
		var lift := thick.x if face == 0 else -thick.y
		for j in rings + 1:
			var f := float(j) / rings
			for k in segs:
				var angle := TAU * k / segs
				var radius: float = outline.call(angle)
				var p := centre + (u * cos(angle) + v * sin(angle)) * radius * f + n * lift * sqrt(maxf(1.0 - f * f, 0.0))
				b.add(p, color.call(f, angle), Vector2(uv_x, clampf((p - root).dot(u) / reach, 0.0, 1.0)))
		b.grid(start, rings, segs, face == 1)


## An oval's radius at `angle` (half lengths `a` along, `c` across).
static func _oval(angle: float, a: float, c: float) -> float:
	return 1.0 / sqrt(pow(cos(angle) / a, 2.0) + pow(sin(angle) / c, 2.0))


static func _limb_material(sk: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = LIMB
	mat.set_shader_parameter("iridescence", float(sk.iridescence) * 0.6)
	mat.set_shader_parameter("sheen_color", sk.sheen)
	return mat


static func _mesh(parent: Node3D, name: String, builder: Builder, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name
	part.mesh = builder.commit()
	part.material_override = material
	parent.add_child(part)
	return part


# --- The tail fan -------------------------------------------------------------------

## The telson (in the body's armour, edged in the skin's accent, with a keel
## and teeth at its back) and a uropod either side: an outer blade with spines
## along its edge, an inner blade, and the forked spine between them.
static func _tail_fan(m: FishModel, sk: Dictionary, seams: PackedFloat32Array, pivot: Vector3) -> void:
	var tl: float = sk.telson
	var six_w := _base_slice(sk, seams, seams[seams.size() - 1]).x
	var half_w := six_w * 0.95
	var has_edge := 1.0
	var telson := Builder.new()
	var outline := func(angle: float) -> float:
		var r := _oval(angle, tl * 0.58, half_w)
		var back := maxf(cos(angle), 0.0)
		# Squarer shoulders and teeth along the back edge.
		r *= 1.0 + 0.12 * pow(absf(sin(angle)), 2.0) * back
		r *= 1.0 + 0.09 * pow(back, 2.0) * maxf(cos(angle * 9.0), 0.0) - 0.05 * pow(back, 6.0)
		return r
	var centre := Vector3(0.0, 0.0, tl * 0.42)
	var rim := func(f: float, _angle: float) -> Color:
		var edge := smoothstep(0.8, 0.95, f) * has_edge
		return Color(1.0, 1.0 - edge, 1.0)
	_plate(telson, centre, Vector3.BACK, Vector3.UP, outline, Vector2(0.034, 0.016), rim, 9, 44)
	# A rounded keel down its middle.
	_tube(telson, [Vector3(0.0, 0.022, -0.02), Vector3(0.0, 0.026, tl * 0.4), Vector3(0.0, 0.012, tl * 0.85)],
			[0.0, 0.016, 0.014, 0.0], 8, Color.WHITE, 8, Vector2(0.7, 1.0))
	# And a lower keel either side, ending in a tooth.
	for side: float in [-1.0, 1.0]:
		var x := side * half_w * 0.48
		_tube(telson, [Vector3(x * 0.8, 0.018, tl * 0.08), Vector3(x, 0.02, tl * 0.45), Vector3(x * 1.1, 0.006, tl * 0.86)],
				[0.0, 0.009, 0.008, 0.0], 8, Color.WHITE, 6, Vector2(0.8, 1.0))
	var shell := _shell_material(m, sk, seams, pivot)
	var telson_mesh := _mesh(m.tail, "Telson", telson, shell)
	telson_mesh.position = Vector3.ZERO

	var fan := Builder.new()
	var blade: Color = sk.uropod
	var edge: Color = sk.uropod_edge
	for side: float in [-1.0, 1.0]:
		var root := Vector3(side * six_w * 0.75, -0.01, -0.025)
		# The outer blade (exopod), its spiny edge outward.
		var out_dir := Vector3(side * sin(0.8), -0.06, cos(0.8)).normalized()
		var exo_len := tl * 1.05
		var exo_outline := func(angle: float) -> float:
			var r := _oval(angle, exo_len * 0.5, exo_len * 0.2)
			var outer := maxf(sin(angle) * side, 0.0)
			return r * (1.0 + 0.1 * outer * maxf(cos(angle * 14.0), 0.0))
		var exo_color := func(f: float, angle: float) -> Color:
			# The blade's colour, darker toward its tip (the distal segment), its
			# spiny edge and tip in the edge colour.
			var tip := smoothstep(0.55, 0.95, cos(angle)) * smoothstep(0.55, 0.9, f)
			var c := blade.darkened(0.15).lerp(blade.lightened(0.1), f * 0.6)
			c = c.lerp(blade.darkened(0.55), smoothstep(0.3, 0.8, cos(angle)) * f * 0.6)
			return c.lerp(edge, maxf(smoothstep(0.84, 0.97, f) * 0.85, tip))
		var up := Vector3.UP.rotated(out_dir, -side * 0.15)
		_plate(fan, root + out_dir * exo_len * 0.48, out_dir, up, exo_outline, Vector2(0.012, 0.008), exo_color, 6, 32)
		# The inner blade (endopod), rounder, nearer the telson.
		var in_dir := Vector3(side * sin(0.45), -0.04, cos(0.45)).normalized()
		var endo_len := tl * 0.85
		var endo_color := func(f: float, _angle: float) -> Color:
			return blade.darkened(0.1).lerp(edge, smoothstep(0.75, 0.95, f) * 0.7)
		_plate(fan, root + Vector3(-side * 0.01, -0.006, 0.0) + in_dir * endo_len * 0.5, in_dir,
				Vector3.UP, func(angle: float) -> float: return _oval(angle, endo_len * 0.5, endo_len * 0.2),
				Vector2(0.01, 0.007), endo_color, 5, 28)
		# The basal prolongation: a forked spine pointing back between them.
		var spine_dir := Vector3(side * sin(0.45), -0.12, cos(0.45)).normalized()
		var base := root + Vector3(0.0, -0.012, 0.0)
		_tube(fan, [base, base + spine_dir * tl * 0.4, base + spine_dir * tl * 0.62], [0.016, 0.01, 0.0], 6,
				(sk.uropod as Color).darkened(0.2), 7)
		var fork := spine_dir.rotated(Vector3.UP, side * 0.35)
		_tube(fan, [base + spine_dir * tl * 0.35, base + spine_dir * tl * 0.35 + fork * tl * 0.22], [0.006, 0.0], 4,
				(sk.uropod as Color).darkened(0.2), 6)
		# The blade's protopod, a stout knuckle at the root.
		_tube(fan, [root - out_dir * 0.025, root + out_dir * 0.035], [0.0, 0.026, 0.0], 6, (sk.albedo as Color).darkened(0.1), 10,
				Vector2(1.0, 0.6))
	var limbs := _limb_material(sk)
	_mesh(m.tail, "Uropods", fan, limbs)


# --- Limbs ----------------------------------------------------------------------------

## Five pairs of swimmerets hanging under abdominal plates 1-5, leafy and
## fringed, beating front to back.
static func _swimmerets(m: FishModel, sk: Dictionary, seams: PackedFloat32Array) -> MeshInstance3D:
	var b := Builder.new()
	var color: Color = sk.swimmeret
	for i in 5:
		var z := lerpf(seams[4 + i], seams[5 + i], 0.45)
		var belly := _surface(sk, seams, z, -0.85)
		var len_i := 0.09 * lerpf(1.0, 0.8, i / 4.0)
		for side: float in [-1.0, 1.0]:
			var root := Vector3(side * _base_slice(sk, seams, z).x * 0.3, belly.y + 0.012, z)
			var dir := Vector3(side * 0.2, -0.5, 0.85).normalized()
			var n := Vector3(1.0, 0.0, 0.0).cross(dir).normalized()
			var leaf := func(f: float, angle: float) -> Color:
				return color.darkened(0.2).lerp(color.lightened(0.3), f * (0.4 + 0.6 * maxf(cos(angle), 0.0)))
			# Two leaves each: the outer blade and the smaller inner one.
			_plate(b, root + dir * len_i * 0.5, dir, n, func(angle: float) -> float: return _oval(angle, len_i * 0.5, len_i * 0.3),
					Vector2(0.003, 0.003), leaf, 3, 16, i / 4.0, root, len_i)
			var dir2 := dir.rotated(Vector3.UP, -side * 0.35)
			_plate(b, root + Vector3(-side * 0.01, 0.003, 0.0) + dir2 * len_i * 0.38, dir2, n,
					func(angle: float) -> float: return _oval(angle, len_i * 0.38, len_i * 0.2),
					Vector2(0.003, 0.003), leaf, 3, 14, i / 4.0, root, len_i)
	var mat := _limb_material(sk)
	mat.set_shader_parameter("flap", 0.012)
	mat.set_shader_parameter("tempo", 1.6)
	m._waving.append(mat)
	return _mesh(m, "Swimmerets", b, mat)


## Three pairs of slender walking legs under the thoracic rings, and the small
## folded maxillipeds under the carapace.
static func _legs(m: FishModel, sk: Dictionary, seams: PackedFloat32Array) -> void:
	var b := Builder.new()
	var leg: Color = sk.leg
	var floor_y := -m._size.y * 0.5 + 0.004
	var banded: bool = sk.leg_bands
	var band_color: Color = sk.mark
	var paint := func(f: float, _p: Vector3) -> Color:
		var c := leg.lerp(leg.lightened(0.3), smoothstep(0.6, 1.0, f))
		if banded and fmod(f * 4.0, 1.0) < 0.35:
			c = c.lerp(band_color, 0.7)
		return c
	for i in 3:
		var z := lerpf(seams[1 + i], seams[2 + i], 0.5)
		var slice := _base_slice(sk, seams, z)
		for side: float in [-1.0, 1.0]:
			var root := Vector3(side * slice.x * 0.55, MIDDLE - slice.z * 0.6, z)
			var knee := Vector3(side * (slice.x * 0.95 + 0.02), MIDDLE - slice.z * 0.9, z + 0.01 * (i - 1))
			var tip := Vector3(side * (slice.x * 1.02 + 0.03), floor_y, z - 0.02 + 0.02 * (i - 1))
			_tube(b, [root, knee, knee.lerp(tip, 0.5) + Vector3(side * 0.012, 0.0, 0.0), tip],
					[0.0, 0.008, 0.008, 0.007, 0.007, 0.0065, 0.0], 16, paint, 8)
	# Maxillipeds 3-5: small folded hooks tucked under the carapace.
	for i in 3:
		var z := lerpf(seams[0], seams[1], 0.55 + 0.13 * i)
		var slice := _base_slice(sk, seams, z)
		for side: float in [-1.0, 1.0]:
			var root := Vector3(side * slice.x * 0.3, MIDDLE - slice.z * 0.7, z)
			var elbow := root + Vector3(side * 0.03, -0.035, -0.035)
			var hook := elbow + Vector3(side * 0.0, 0.012, 0.04)
			_tube(b, [root, elbow, hook], [0.0, 0.01, 0.009, 0.006, 0.0], 10, leg.darkened(0.1), 7)
	_mesh(m, "Legs", b, _limb_material(sk))


## The raptorial claws, folded under the front on the fin pivots: a thick
## merus angled down and forward from under the head, then (a smasher) the
## heavy club at the bottom with the propodus and dactyl folded back up along
## it, or (a spearer) a long propodus and a dactyl lined with barbs folded back
## along the bottom.
static func _claws(m: FishModel, sk: Dictionary, seams: PackedFloat32Array) -> void:
	var z0 := seams[0] + (seams[1] - seams[0]) * 0.32
	var slice := _base_slice(sk, seams, z0)
	m._fin_pivots(Vector3(slice.x * 0.42, MIDDLE - slice.z * 0.55, z0))
	var merus: Color = sk.merus
	var club: Color = sk.club
	var propodus: Color = sk.propodus
	var spot: Color = sk.meral_spot
	var barb: Color = sk.barb
	var banded: bool = sk.leg_bands
	var band_color: Color = sk.mark
	var floor_y := -m._size.y * 0.5 + 0.006 - (MIDDLE - slice.z * 0.55)  # the hitbox floor, in pivot space
	var spear: bool = sk.claw == "spear"
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		var b := Builder.new()
		var elbow := Vector3(side * 0.035, floor_y + (0.03 if spear else 0.036), -0.12 if spear else -0.065)
		var spot_at := Vector3(side * 0.04, elbow.y * 0.55, elbow.z * 0.55)
		var merus_paint := func(f: float, p: Vector3) -> Color:
			var c := merus.darkened(0.15).lerp(merus.lightened(0.08), f)
			if banded and fmod(f * 3.0, 1.0) < 0.3:
				c = c.lerp(band_color, 0.75)
			if spot.a > 0.0:
				var d := Vector2(p.y - spot_at.y, p.z - spot_at.z).length()
				c = c.lerp(spot, 1.0 - smoothstep(0.011, 0.017, d))
			return c
		# Coxa and ischium: a short stout root.
		_tube(b, [Vector3(0.0, 0.03, 0.025), Vector3(side * 0.012, -0.004, 0.0)], [0.0, 0.022, 0.019, 0.0], 6, merus.darkened(0.2), 10)
		# The merus, deep and flat sided.
		_tube(b, [Vector3(side * 0.01, 0.0, 0.0), Vector3(side * 0.026, elbow.y * 0.5, elbow.z * 0.45), elbow],
				[0.0, 0.025, 0.03, 0.028, 0.022, 0.0], 18, merus_paint, 14, Vector2(0.6, 1.0), Vector3.BACK)
		if not spear:
			# The club: the dactyl's swollen heel at the bottom front, heavy and glossy.
			var heel := elbow + Vector3(side * 0.006, -0.004, -0.014)
			_tube(b, [heel + Vector3(0.0, 0.012, 0.03), heel, heel + Vector3(0.0, -0.002, -0.03)],
					[0.0, 0.025, 0.031, 0.027, 0.0], 14, func(f: float, _p: Vector3) -> Color: return club.darkened(0.1).lerp(club.lightened(0.15), f),
					14, Vector2(0.85, 1.0))
			# The propodus folded back up beside the merus, and the slim dactyl
			# folded along its underside.
			var back := elbow + Vector3(side * 0.024, 0.045, 0.1)
			_tube(b, [heel + Vector3(side * 0.012, 0.004, 0.012), heel.lerp(back, 0.5) + Vector3(side * 0.018, -0.006, 0.0), back],
					[0.018, 0.019, 0.016, 0.011, 0.0], 12, propodus, 10, Vector2(0.7, 1.0))
			_tube(b, [heel + Vector3(side * 0.016, -0.012, 0.01), heel.lerp(back, 0.45) + Vector3(side * 0.022, -0.018, 0.0),
					back + Vector3(side * 0.008, -0.022, -0.015)], [0.009, 0.008, 0.006, 0.0], 10, club.darkened(0.15), 8)
		else:
			# The propodus: a long blade lying back along the bottom, with a comb of
			# small teeth; the dactyl folded into it, lined with barbs.
			var back := Vector3(side * 0.045, floor_y + 0.03, 0.06)
			_tube(b, [elbow, elbow.lerp(back, 0.5) + Vector3(0.0, -0.01, 0.0), back],
					[0.024, 0.022, 0.018, 0.012, 0.0], 16, func(f: float, _p: Vector3) -> Color:
						var c := propodus
						if fmod(f * 3.0 + 0.5, 1.0) < 0.25:
							c = c.lerp(band_color, 0.7)
						return c, 10, Vector2(0.7, 1.0))
			var d0 := elbow + Vector3(side * 0.01, -0.02, -0.012)
			var d1 := back + Vector3(side * 0.01, -0.025, 0.02)
			_tube(b, [d0 + Vector3(0.0, 0.01, -0.015), d0, d0.lerp(d1, 0.5), d1], [0.008, 0.012, 0.01, 0.007, 0.0], 14, club, 8)
			for k in 9:
				var f := 0.12 + 0.09 * k
				var at := d0.lerp(d1, f) + Vector3(0.0, -0.006, 0.0)
				var tip := at + Vector3(side * 0.003, -0.022 * (1.0 - f * 0.4), -0.008)
				_tube(b, [at, tip], [0.004, 0.0025, 0.0], 3, barb, 5)
		_mesh(pivot, "Claw", b, _limb_material(sk))


## The head: stalked eyes swivelling over the rostrum, the antennules (three
## whips each) between them, and the antennae with their paddle-shaped scales
## out to the sides.
static func _head(m: FishModel, sk: Dictionary, seams: PackedFloat32Array) -> void:
	var front := seams[0]
	var top := _surface(sk, seams, front + 0.05, 1.0)
	var thread: Color = sk.thread
	var b := Builder.new()
	# Antennules: a three-jointed stalk forward and up, then three whips.
	for side: float in [-1.0, 1.0]:
		var root := Vector3(side * 0.025, MIDDLE + 0.015, front + 0.035)
		var stalk_end := root + Vector3(side * 0.035, 0.06, -0.13)
		_tube(b, [root, root.lerp(stalk_end, 0.5) + Vector3(0.0, 0.01, 0.0), stalk_end], [0.0, 0.011, 0.009, 0.008, 0.0], 10,
				(sk.albedo as Color).lerp(thread, 0.4), 7)
		for k in 3:
			var length := 0.2 + 0.05 * k
			var dir := Vector3(side * (0.15 + 0.12 * k), 0.35 - 0.12 * k, -1.0).normalized()
			var mid := stalk_end + dir * length * 0.5 + Vector3(0.0, 0.03 - 0.02 * k, 0.0)
			var end := stalk_end + dir * length + Vector3(side * 0.02 * k, -0.03 * k, 0.0)
			_tube(b, [stalk_end, mid, end], [0.004, 0.003, 0.0015, 0.0], 10, thread, 4)
	# Antennae: a stout stalk out to the side, a long whip and the scale.
	var scale_mesh := Builder.new()
	var scale_color: Color = sk.scale
	var scale_edge: Color = sk.scale_edge
	for side: float in [-1.0, 1.0]:
		var slice := _base_slice(sk, seams, front + 0.04)
		var root := Vector3(side * slice.x * 0.7, MIDDLE - 0.01, front + 0.05)
		var stalk_end := root + Vector3(side * 0.05, -0.008, -0.07)
		_tube(b, [root, stalk_end], [0.0, 0.014, 0.011, 0.0], 6, (sk.albedo as Color).lerp(thread, 0.3), 8)
		var whip_dir := Vector3(side * 0.45, 0.05, -1.0).normalized()
		_tube(b, [stalk_end, stalk_end + whip_dir * 0.18 + Vector3(0.0, 0.02, 0.0), stalk_end + whip_dir * 0.34 + Vector3(side * 0.04, -0.01, 0.0)],
				[0.005, 0.004, 0.002, 0.0], 12, thread, 4)
		var scale_dir := Vector3(side * 0.5, -0.2, -0.85).normalized()
		var scale_len := 0.11
		var n := Vector3.UP.rotated(scale_dir, side * 0.5)
		var paint := func(f: float, angle: float) -> Color:
			var c := scale_color.lerp(scale_color.lightened(0.2), f * 0.5)
			return c.lerp(scale_edge, smoothstep(0.78, 0.95, f) * (0.6 + 0.4 * absf(sin(angle))))
		_plate(scale_mesh, stalk_end + scale_dir * scale_len * 0.45, scale_dir, n,
				func(angle: float) -> float: return _oval(angle, scale_len * 0.5, scale_len * 0.2) * (1.0 + 0.1 * maxf(-cos(angle), 0.0)),
				Vector2(0.006, 0.004), paint, 5, 26)
	var limbs := _limb_material(sk)
	_mesh(m, "Antennae", b, limbs)
	_mesh(m, "AntennalScales", scale_mesh, limbs)

	# Eyes: a stalk up and forward from over the rostrum, an oval eye on it.
	for side: float in [-1.0, 1.0]:
		var root := Vector3(side * 0.035, top.y - 0.02, front + 0.05)
		var stalk_top := Vector3(side * 0.022, 0.075, -0.045)
		var centre := stalk_top + Vector3(side * 0.006, 0.03, -0.006)
		var radii := Vector3(0.025, 0.034, 0.025) * (0.9 if sk.claw == "spear" else 1.0)
		var e := Builder.new()
		_tube(e, [Vector3.ZERO, stalk_top * 0.5 + Vector3(0.0, 0.0, -0.01), stalk_top], [0.012, 0.01, 0.01, 0.014], 6,
				Color(0.0, 0.0, 0.0), 10)
		# The eye: a UV sphere scaled to the oval, its waist a touch narrower.
		var start := e.verts.size()
		var lat_rows := 14
		var around := 20
		for j in lat_rows + 1:
			var lat := lerpf(-PI / 2.0, PI / 2.0, float(j) / lat_rows)
			var waist := 1.0 - 0.06 * exp(-pow(lat / 0.18, 2.0))
			for k in around:
				var lon := TAU * k / around
				var d := Vector3(cos(lat) * sin(lon) * waist, sin(lat), cos(lat) * cos(lon) * waist)
				e.add(centre + d * radii, Color(1.0, 0.0, 0.0))
		# Rings run bottom to top: wind them so they face out.
		e.grid(start, lat_rows, around, true)
		var mat := ShaderMaterial.new()
		mat.shader = EYE
		mat.set_shader_parameter("albedo", sk.albedo)
		mat.set_shader_parameter("eye_color", sk.eye)
		mat.set_shader_parameter("eye_color2", sk.eye2)
		mat.set_shader_parameter("band_color", sk.eye_band)
		mat.set_shader_parameter("stripe_color", sk.stripe)
		mat.set_shader_parameter("centre", centre)
		mat.set_shader_parameter("radii", radii)
		mat.set_shader_parameter("seed", 1.3 if side < 0.0 else 4.1)
		m._skins.append(mat)
		m._waving.append(mat)
		var eye := _mesh(m, "Eye", e, mat)
		eye.position = root
