class_name ClownfishModel
extends RefCounted
## The Skirmishers' clownfish (FishModel.build hands it here): species m.species of
## FishCharacter.SPECIES[FishCharacter.FishClass.SKIRMISHER]. One smooth lofted body (a
## deep, blunt-headed oval narrowing to a thick tail stalk, an egg-shaped cross
## section narrower along the back) painted by clown_skin.gdshader, which bends
## into the tail (FishModel._bend_body); a notched dorsal fin (low spiny front,
## taller soft back), a rounded anal fin, pelvics, paddle pectorals on the swim
## pivots and a rounded tail fan; real eyes set into the head. The species share it
## all and differ in colour, bands, fin edging and a few details (the maroon's
## cheek spine, the tomato's deeper body).

const SKIN_SHADER := preload("res://shaders/clown_skin.gdshader")

## Where the bands sit along the body (nose 0 to tail 1) at their top and bottom.
const BAND_ALONG := Vector3(0.205, 0.565, 0.925)

## Per species, in FishCharacter.SPECIES order. Sizes are of the body's length.
const LOOKS := [
	{  # Ocellaris: orange, three white bands thinly edged in black, black fin margins.
		"body": Color("#f07a1e"), "back": 0.66, "belly": Color("#f8b066"), "belly_mix": 0.55,
		"bands": Vector3(1.0, 1.0, 1.0), "band": Color("#fbfbf7"), "band_width": Vector3(0.036, 0.034, 0.016),
		"rim": 0.011, "rim_color": Color("#111111"), "rim_alpha": 1.0, "sheen": 0.0,
		"fin": Color("#e86a14"), "fin_edge": 1.15, "margin": 0.09, "margin_color": Color("#111111"), "rays": Color("#b84a10"), "fin_alpha": 0.92,
		"paddle": Color("#f28a2e"), "paddle_tint": true, "pelvic_paddle": false,
		"iris": Color("#e0a030"), "lip": Color("#4a1600"), "depth": 0.96, "girth": 1.0,
	},
	{  # Black Percula: near-black, broad white bands, orange face and pelvics, orange fin edging.
		"body": Color("#1c1411"), "back": 0.8, "belly": Color("#2e1f18"), "belly_mix": 0.6,
		"bands": Vector3(1.0, 1.0, 1.0), "band": Color("#fbfbf7"), "band_width": Vector3(0.042, 0.04, 0.02),
		"rim": 0.0, "rim_color": Color("#111111"), "rim_alpha": 0.0, "sheen": 0.0,
		"face": Color("#e8701c"),
		"fin": Color("#1a1210"), "fin_edge": 1.4, "margin": 0.08, "margin_color": Color("#e8701c"), "rays": Color("#4a3328"), "fin_alpha": 0.985,
		"paddle": Color("#e8701c"), "paddle_alpha": 0.75, "paddle_tint": false, "pelvic_paddle": true,
		"iris": Color("#c88a2a"), "lip": Color("#3a1404"), "depth": 0.96, "girth": 1.0,
	},
	{  # Tomato: red-orange, one white head bar edged dark, a dark flank, no fin edging, deeper body.
		"body": Color("#c8341a"), "back": 0.6, "belly": Color("#e8662e"), "belly_mix": 0.65,
		"bands": Vector3(1.0, 0.0, 0.0), "band": Color("#fbfbf7"), "band_width": Vector3(0.036, 0.03, 0.015),
		"rim": 0.013, "rim_color": Color("#1a0604"), "rim_alpha": 0.6, "sheen": 0.0,
		"blotch": Color("#2a0806"),
		"fin": Color("#d84a22"), "fin_edge": 1.1, "margin": 0.0, "margin_color": Color("#111111"), "rays": Color("#8a2410"), "fin_alpha": 0.965,
		"paddle": Color("#e86a36"), "paddle_tint": true, "pelvic_paddle": true,
		"iris": Color("#d8962a"), "lip": Color("#3a0800"), "depth": 1.0, "girth": 1.08,
	},
	{  # Gold-stripe Maroon: deep wine red, three thin gold stripes, a cheek spine under the eye.
		"body": Color("#6e0e1a"), "back": 0.55, "belly": Color("#9a2a2e"), "belly_mix": 0.6,
		"bands": Vector3(1.0, 1.0, 1.0), "band": Color("#f2c14e"), "band_width": Vector3(0.014, 0.014, 0.011),
		"rim": 0.0, "rim_color": Color("#111111"), "rim_alpha": 0.0, "sheen": 0.55,
		"fin": Color("#5a0a16"), "fin_edge": 1.25, "margin": 0.0, "margin_color": Color("#111111"), "rays": Color("#3a0610"), "fin_alpha": 0.985,
		"paddle": Color("#7a1a22"), "paddle_alpha": 0.85, "paddle_tint": true, "pelvic_paddle": false,
		"iris": Color("#b8762a"), "lip": Color("#1a0000"), "depth": 0.97, "girth": 1.04, "cheek_spine": true,
	},
]


## The body's shape: oval slices from the nose (`ends.x`) to the tail
## (`ends.y`), `semi` its widest half width and height.
class Shape:
	extends RefCounted
	## How much narrower the back is than the belly (the cross section's egg).
	const EGG := 0.16
	var ends := Vector2.ZERO
	var semi := Vector2.ONE

	func z(along: float) -> float:
		return lerpf(ends.x, ends.y, along)

	func along_at(at_z: float) -> float:
		return inverse_lerp(ends.x, ends.y, at_z)

	## The slice `along` (nose 0 to tail 1): half width, half height, height of its middle.
	func slice(along: float) -> Vector3:
		var a := clampf(along, 0.0, 1.0)
		var deep := ClownfishModel._taper(a, 0.42, 0.87, 0.31, 0.42)
		var wide := ClownfishModel._taper(a, 0.3, 0.87, 0.24, 0.62) * lerpf(1.0, 0.72, a)
		# The snout sits a little low, so the forehead slopes more than the chin.
		var middle := -0.1 * semi.y * (1.0 - smoothstep(0.0, 0.4, a))
		return Vector3(semi.x * wide, semi.y * deep, middle)

	## A point on the skin `along` it, `angle` round from the top (+ toward +X).
	func point(along: float, angle: float) -> Vector3:
		var s := slice(along)
		var x := s.x * sin(angle) * (1.0 - EGG * cos(angle))
		return Vector3(x, s.z + s.y * cos(angle), z(along))

	## The outward normal there.
	func normal(along: float, angle: float) -> Vector3:
		var e := 0.002
		var round_way := point(along, angle + e) - point(along, angle - e)
		var long_way := point(along + e, angle) - point(along - e, angle)
		var n := round_way.cross(long_way).normalized()
		var s := slice(along)
		if n.dot(point(along, angle) - Vector3(0.0, s.z, z(along))) < 0.0:
			n = -n
		return n

	## The skin's mesh: `rows` slices (closer together at the rounded ends),
	## `around` points round each.
	func mesh(rows: int, around: int) -> ArrayMesh:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in rows + 1:
			var t := float(i) / rows
			var along := 0.5 - 0.5 * cos(PI * t)
			along = lerpf(t, along, 0.6)
			for k in around:
				var angle := TAU * k / around
				tool.set_uv(Vector2(along, float(k) / around))
				tool.add_vertex(point(along, angle))
		for i in rows:
			for k in around:
				var a := i * around + k
				var b := i * around + (k + 1) % around
				for corner: int in [a, b, a + around, b, b + around, a + around]:
					tool.add_index(corner)
		tool.generate_normals()
		return tool.commit()


static func build(m: FishModel) -> void:
	var look: Dictionary = LOOKS[clampi(m.species, 0, LOOKS.size() - 1)]
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	var shape := Shape.new()
	shape.ends = Vector2(-l * 0.48, l * 0.33)
	shape.semi = Vector2(w * 0.17 * float(look.girth), h * 0.5 * float(look.depth))
	var span := shape.ends.y - shape.ends.x
	_body(m, shape, look, span)
	var bent := _fins(m, shape, look, span)
	_face(m, shape, look)
	# The rear of the body flexes into the tail; the head and chest stay stiff.
	m.bend_share = 0.68
	m._bend_body(shape.z(0.5), bent)


static func _body(m: FishModel, shape: Shape, look: Dictionary, span: float) -> void:
	var color: Color = look.body
	m._body_material = m._material(color)  # for set_body_color(); the skin does the shading
	var skin := ShaderMaterial.new()
	skin.shader = SKIN_SHADER
	skin.set_shader_parameter("albedo", color)
	skin.set_shader_parameter("back_shade", look.back)
	skin.set_shader_parameter("belly_color", look.belly)
	skin.set_shader_parameter("belly_mix", look.belly_mix)
	skin.set_shader_parameter("band_color", look.band)
	skin.set_shader_parameter("rim_color", look.rim_color)
	skin.set_shader_parameter("rim_alpha", look.rim_alpha)
	skin.set_shader_parameter("band_on", look.bands)
	skin.set_shader_parameter("band_z", Vector3(shape.z(BAND_ALONG.x), shape.z(BAND_ALONG.y), shape.z(BAND_ALONG.z)))
	skin.set_shader_parameter("band_width", (look.band_width as Vector3) * span)
	skin.set_shader_parameter("band_bulge", Vector3(-0.04, -0.075, 0.0) * span)
	skin.set_shader_parameter("rim", float(look.rim) * span)
	skin.set_shader_parameter("band_sheen", look.sheen)
	skin.set_shader_parameter("height", shape.semi.y)
	skin.set_shader_parameter("girth", (shape.semi.x + shape.semi.y) / 2.0)
	skin.set_shader_parameter("nose_z", shape.ends.x)
	skin.set_shader_parameter("mouth_y", shape.slice(0.0).z - shape.semi.y * 0.02)
	skin.set_shader_parameter("mouth_length", span * 0.045)
	skin.set_shader_parameter("gill_z", shape.z(0.215))
	skin.set_shader_parameter("gill_bulge", span * 0.03)
	skin.set_shader_parameter("lip_color", look.lip)
	skin.set_shader_parameter("scale_size", span * 0.013)
	if look.has("face"):
		skin.set_shader_parameter("face_on", 1.0)
		skin.set_shader_parameter("face_color", look.face)
		skin.set_shader_parameter("face_span", Vector2(shape.z(0.15), shape.z(0.21)))
	if look.has("blotch"):
		skin.set_shader_parameter("blotch_on", 1.0)
		skin.set_shader_parameter("blotch_color", look.blotch)
		skin.set_shader_parameter("blotch_at", Vector2(shape.z(0.6), -shape.semi.y * 0.05))
		skin.set_shader_parameter("blotch_size", Vector2(span * 0.3, shape.semi.y * 0.8))
	m._skins.append(skin)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = shape.mesh(72, 40)
	body.material_override = skin
	m.add_child(body)


static func _fins(m: FishModel, shape: Shape, look: Dictionary, span: float) -> Array:
	var h := m._size.y
	var l := m._size.z
	var margin: float = look.margin
	var fins := _fin_look(m, look.fin, look.fin_edge, look.rays, 16.0, 0.012, 1.3, look.fin_alpha, margin, look.margin_color)
	m._skins.append(fins)
	var spiny := _fin_look(m, look.fin, look.fin_edge, look.rays, 10.0, 0.01, 1.3, look.fin_alpha, margin, look.margin_color)
	m._skins.append(spiny)
	var paddles := _fin_look(m, look.paddle, 1.15, (look.paddle as Color).darkened(0.25), 11.0, 0.012, 2.2, look.get("paddle_alpha", 0.55), 0.0, look.margin_color)
	if look.paddle_tint:
		m._skins.append(paddles)
	var pelvic_look := paddles if look.pelvic_paddle else fins
	var bent: Array = []
	# The dorsal fin: a low spiny front with a notch behind it, then a taller,
	# rounded soft part; the anal fin opposite the soft dorsal.
	bent.append(_body_fin(m, shape, spiny, 0.28, 0.56, 0.0, Vector3(0.0, 1.0, 0.45),
			[h * 0.12, h * 0.21, h * 0.22, h * 0.2, h * 0.17, h * 0.13], 0.0, 0.1))
	bent.append(_body_fin(m, shape, fins, 0.54, 0.87, 0.0, Vector3(0.0, 1.0, 0.6),
			[h * 0.14, h * 0.27, h * 0.33, h * 0.31, h * 0.22, h * 0.06], 0.0, 0.03))
	bent.append(_body_fin(m, shape, fins, 0.6, 0.86, PI, Vector3(0.0, -1.0, 0.6),
			[h * 0.12, h * 0.26, h * 0.3, h * 0.24, h * 0.06], 0.0, 0.03))
	for side: float in [-1.0, 1.0]:
		bent.append(_body_fin(m, shape, pelvic_look, 0.3, 0.37, side * 2.6, Vector3(side * 0.35, -1.0, 0.75),
				[h * 0.22, h * 0.31, h * 0.22], 0.35, 0.02))
	# Round paddle pectorals just behind the head bar, on the swim pivots.
	var root := shape.point(0.26, 1.85)
	m._fin_pivots(Vector3(root.x * 0.88, root.y, root.z))
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		m._membrane(pivot, paddles, Vector3(0.0, h * 0.06, -l * 0.01), Vector3(0.0, -h * 0.05, l * 0.01), Vector3(side * 0.55, -0.12, 1.0),
				[l * 0.11, l * 0.155, l * 0.17, l * 0.15, l * 0.1], 1.0, 0.03)
	# The rounded tail fan, its root well inside the stalk.
	var pivot_along := 0.962
	m._tail_pivot(Vector3(0.0, shape.slice(pivot_along).z, shape.z(pivot_along)))
	var stalk := shape.slice(pivot_along - 0.04).y
	var back := -span * 0.03
	m._membrane(m.tail, fins, Vector3(0.0, stalk * 0.85, back), Vector3(0.0, -stalk * 0.85, back), Vector3(0.0, 0.0, 1.0),
			[l * 0.17, l * 0.205, l * 0.22, l * 0.215, l * 0.2, l * 0.215, l * 0.22, l * 0.205, l * 0.17], -1.15, 0.025)
	return bent


## A fin on the body along `from`..`to` (nose 0 to tail 1) at `angle` round
## from the top, fanning toward `out`, `heights` showing above the skin (the
## part of the root line sunk into the curving body is added on).
static func _body_fin(m: FishModel, shape: Shape, material: ShaderMaterial, from: float, to: float, angle: float, out: Vector3,
		heights: Array, spread: float, frill: float) -> MeshInstance3D:
	var sink := 0.012
	var start := shape.point(from, angle) - shape.normal(from, angle) * sink
	var end := shape.point(to, angle) - shape.normal(to, angle) * sink
	var direction := out.normalized()
	var lengths: Array = []
	for k in heights.size():
		var u := float(k) / (heights.size() - 1)
		var skin := shape.point(lerpf(from, to, u), angle)
		var under := maxf((skin - start.lerp(end, u)).dot(direction), 0.0)
		lengths.append(float(heights[k]) + under)
	return m._membrane(m, material, start, end, out, lengths, spread, frill)


## A fin membrane's look (fin_membrane.gdshader) whose edge follows its tint.
static func _fin_look(m: FishModel, color: Color, edge_shade: float, rays_color: Color, rays: float, flutter: float, tempo: float,
		edge_alpha: float, margin: float, margin_color: Color) -> ShaderMaterial:
	var material := m._fin_material(color, color, rays, flutter, tempo, edge_alpha)
	material.set_shader_parameter("edge_shade", edge_shade)
	material.set_shader_parameter("ray_color", rays_color)
	material.set_shader_parameter("margin", margin)
	material.set_shader_parameter("margin_color", margin_color)
	return material


## Real eyes set into the head, and the maroon's cheek spine.
static func _face(m: FishModel, shape: Shape, look: Dictionary) -> void:
	var radius := m._size.y * 0.115
	var along := 0.115
	var angle := acos(0.3)
	for side: float in [-1.0, 1.0]:
		var skin := shape.point(along, angle) * Vector3(side, 1.0, 1.0)
		var normal := shape.normal(along, angle) * Vector3(side, 1.0, 1.0)
		var eye := m._real_eye(skin - normal * radius * 0.58, radius, (normal + Vector3(side * 0.4, 0.05, -0.15)).normalized(),
				look.iris, 0.47)
		var material := eye.material_override as ShaderMaterial
		material.set_shader_parameter("iris_inner", (look.iris as Color).darkened(0.35))
		material.set_shader_parameter("rim_color", (look.body as Color).darkened(0.7))
		material.set_shader_parameter("sheen", 0.55)
	if look.get("cheek_spine", false):
		var spine_material := m._material(Color("#b88e8a"), 0.4)
		for side: float in [-1.0, 1.0]:
			var root := shape.point(0.1, PI - acos(0.35)) * Vector3(side, 1.0, 1.0)
			var spine := CylinderMesh.new()
			spine.top_radius = 0.0
			spine.bottom_radius = 0.006
			spine.height = 0.05
			spine.radial_segments = 8
			spine.rings = 1
			var part := MeshInstance3D.new()
			part.name = "CheekSpine"
			part.mesh = spine
			part.material_override = spine_material
			var direction := Vector3(side * 0.3, -0.6, 0.75).normalized()
			part.basis = Basis(Quaternion(Vector3.UP, direction))
			part.position = root + direction * 0.02 - Vector3(side * 0.005, 0.0, 0.0)
			m.add_child(part)


## How thick the body is (of its widest) `along` it, nose 0 to tail 1: a snout
## swelling to its widest at `widest` (`nose` 0.5 a round head, toward 1 a
## pointed one), narrowing to a tail stalk `stalk_size` thick at `stalk`, with a
## rounded end.
static func _taper(along: float, widest: float, stalk: float, stalk_size: float, nose := 0.5) -> float:
	if along < widest:
		return pow(maxf(1.0 - pow((widest - along) / widest, 2.0), 0.0), nose)
	if along < stalk:
		var t := (along - widest) / (stalk - widest)
		return lerpf(1.0, stalk_size, t * t * (3.0 - 2.0 * t))
	return stalk_size * sqrt(maxf(1.0 - pow((along - stalk) / (1.0 - stalk), 2.0), 0.0))
