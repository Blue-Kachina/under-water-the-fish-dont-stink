class_name WhaleSharkModel
extends RefCounted
## The baby whale shark (FishModel.build hands it here): skin m.skin of
## FishCharacter.SKINS[FishCharacter.Family.WHALE_SHARK].
##
## One smooth lofted body (_body_mesh): superelliptic slices, wide and low at
## the front for a whale shark's flat head (a basking shark's conical snout),
## with the flank ridges and the tail stalk's keels shaped into it. The hide is
## painted in whale_skin.gdshader (spots, stripes, gill slits, mouth); the fins
## are thick stiff blades (_fin, whale_fin.gdshader). The rear of the body bends
## into the tail (FishModel._bend_body), sharks being stiff up front.

const SKIN_SHADER := preload("res://shaders/whale_skin.gdshader")
const FIN_SHADER := preload("res://shaders/whale_fin.gdshader")

## Body slices nose to tail, and points round each.
const ROWS := 100
const HALF := 52
const AROUND := HALF * 2

## Shared by the whale shark skins: a broad flat head with a blunt front, the
## back highest over the first dorsal fin, a flat belly. Tables run nose 0 to
## tail 1 (FishModel._sample): half width (of the widest), and the top and
## bottom (of half the hitbox's height).
const WHALE_SHAPE := {
	"width": 0.28,
	"w_tab": [0.82, 0.92, 0.99, 1.0, 0.98, 0.92, 0.8, 0.6, 0.4, 0.25, 0.18],
	"top_tab": [0.3, 0.5, 0.7, 0.86, 0.95, 0.93, 0.8, 0.6, 0.42, 0.28, 0.22],
	"bot_tab": [-0.42, -0.72, -0.9, -0.98, -1.0, -0.94, -0.76, -0.5, -0.28, -0.14, -0.08],
	"nose": 0.045, "nose_w": 0.12, "pointed": false,
	"n_head": Vector2(2.6, 3.0), "n_body": Vector2(2.15, 2.4),
	"ridge": 0.01, "keel": 0.012,
	"ridge_from": Vector3(0.15, 0.26, 0.38), "ridge_to": Vector3(0.3, 0.4, 0.5),
	"eye": 0.017, "eye_a": 0.085, "eye_s": 0.42,
	"mouth_s": 0.56, "mouth_a": 0.075, "mouth_front_a": -1.0, "mouth_droop": 0.07, "mouth_w": 0.009,
	"gill_a": 0.15, "gill_step_a": 0.024, "gill_s": Vector2(0.24, 0.6), "gill_shrink": 0.02, "gill_bow": 0.006,
	"pec_a": 0.28, "pec_s": 0.66, "pec_len": 0.36,
	"dorsal": Vector2(0.47, 0.61), "dorsal_h": 0.62,
	"tail_len": 1.15, "tail_angles": [1.0, 0.72, 0.12, -0.45, -0.72], "tail_lengths": [1.0, 0.68, 0.22, 0.42, 0.55],
}

## Each skin (FishCharacter.SKINS order): its colours and pattern, and any
## shape it changes from WHALE_SHAPE.
const LOOKS := [
	{  # Whale shark, Indo-Pacific classic
		"back": Color("2a4664"), "flank": Color("5a7a9a"), "belly": Color("e8eef0"),
		"spot": Color("e8f0f4"), "stripe": Color("cfe0ea"), "iris": Color(0.42, 0.4, 0.36),
		"spot_cell": 0.044, "spot_size": 0.22, "head_spot": 0.5, "spots": 1.0, "stripes": 0.55,
		"ridge_light": 0.45, "mottle": 0.0, "belly_s": 0.62,
	},
	{  # Deep charcoal: near black, dense fine spots
		"back": Color("1e2024"), "flank": Color("46484c"), "belly": Color("d8dcd8"),
		"spot": Color("e0e4e0"), "stripe": Color("8a8e90"), "iris": Color(0.35, 0.34, 0.32),
		"spot_cell": 0.034, "spot_size": 0.2, "head_spot": 0.55, "spots": 0.85, "stripes": 0.3,
		"ridge_light": 0.2, "mottle": 0.0, "belly_s": 0.63,
	},
	{  # Juvenile: a bigger head on a rounder body, paler, fewer bigger spots
		"back": Color("4a6a8a"), "flank": Color("86a6c0"), "belly": Color("f0f4f6"),
		"spot": Color("f4f8fa"), "stripe": Color("e4eef4"), "iris": Color(0.45, 0.43, 0.38),
		"spot_cell": 0.068, "spot_size": 0.26, "head_spot": 0.55, "spots": 1.0, "stripes": 0.4,
		"ridge_light": 0.3, "mottle": 0.0, "belly_s": 0.6,
		"width": 0.27,
		"w_tab": [0.86, 0.96, 1.0, 1.0, 0.95, 0.85, 0.68, 0.48, 0.32, 0.21, 0.16],
		"top_tab": [0.46, 0.72, 0.88, 0.96, 0.97, 0.9, 0.75, 0.56, 0.39, 0.27, 0.21],
		"bot_tab": [-0.5, -0.8, -0.96, -1.0, -1.0, -0.93, -0.74, -0.48, -0.27, -0.14, -0.08],
		"nose": 0.055, "nose_w": 0.13, "n_head": Vector2(2.3, 2.7), "n_body": Vector2(2.0, 2.2),
		"ridge": 0.0045, "eye": 0.02, "dorsal_h": 0.58,
		"tail_angles": [1.05, 0.75, 0.12, -0.42, -0.66], "tail_lengths": [1.08, 0.62, 0.2, 0.36, 0.46],
	},
	{  # Basking shark: a conical snout over a huge closed mouth, gill slits
		# nearly round its head, plain mottled grey-brown
		"back": Color("5a564a"), "flank": Color("8a8472"), "belly": Color("b0ac9c"),
		"spot": Color("b8b4a4"), "stripe": Color("8a8676"), "iris": Color(0.3, 0.27, 0.22),
		"spot_cell": 0.05, "spot_size": 0.2, "head_spot": 0.5, "spots": 0.0, "stripes": 0.0,
		"ridge_light": 0.0, "mottle": 1.0, "belly_s": 0.68,
		"width": 0.235,
		"w_tab": [0.42, 0.78, 0.95, 1.0, 1.0, 0.92, 0.76, 0.55, 0.36, 0.23, 0.17],
		"top_tab": [0.42, 0.66, 0.85, 0.95, 1.0, 0.95, 0.8, 0.6, 0.42, 0.28, 0.22],
		"bot_tab": [0.0, -0.52, -0.85, -0.97, -1.0, -0.94, -0.76, -0.5, -0.28, -0.14, -0.08],
		"nose": 0.15, "nose_w": 0.15, "pointed": true, "n_head": Vector2(2.05, 2.2), "n_body": Vector2(2.0, 2.15),
		"ridge": 0.0, "eye": 0.016, "eye_a": 0.1, "eye_s": 0.4,
		"mouth_s": 0.64, "mouth_a": 0.17, "mouth_front_a": 0.05, "mouth_droop": 0.0, "mouth_w": 0.0055,
		"gill_a": 0.19, "gill_step_a": 0.03, "gill_s": Vector2(0.07, 0.93), "gill_shrink": 0.0, "gill_bow": 0.012,
		"dorsal": Vector2(0.45, 0.58), "dorsal_h": 0.74,
		"tail_angles": [0.98, 0.7, 0.1, -0.55, -0.85], "tail_lengths": [0.96, 0.58, 0.2, 0.5, 0.74],
	},
]


static func build(m: FishModel) -> void:
	var look := _look(m.skin)
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	var ends := Vector2(-l * 0.5, l * 0.39)
	var span := ends.y - ends.x
	var at := func(along: float) -> float: return ends.x + span * along
	var back: Color = look.back
	var flank: Color = look.flank
	# One gain for all channels, so a team tint keeps its hue down the flanks.
	var gain := Vector3.ONE * minf((_ratio(flank.r, back.r) + _ratio(flank.g, back.g) + _ratio(flank.b, back.b)) / 3.0, 4.0)
	m._body_material = m._material(back, 0.45)  # for set_body_color(); the skin does the shading
	m.bend_share = 0.55

	# The body.
	var skin := ShaderMaterial.new()
	skin.shader = SKIN_SHADER
	skin.set_shader_parameter("albedo", back)
	skin.set_shader_parameter("flank_gain", gain)
	skin.set_shader_parameter("belly_color", look.belly)
	skin.set_shader_parameter("belly_s", look.belly_s)
	skin.set_shader_parameter("spot_color", look.spot)
	skin.set_shader_parameter("spot_cell", look.spot_cell)
	skin.set_shader_parameter("spot_size", look.spot_size)
	skin.set_shader_parameter("spot_strength", look.spots)
	skin.set_shader_parameter("head_spot", look.head_spot)
	skin.set_shader_parameter("stripe_color", look.stripe)
	skin.set_shader_parameter("stripes", look.stripes)
	skin.set_shader_parameter("stripe_span", Vector2(at.call(float(look.gill_a) + 4.6 * float(look.gill_step_a)), at.call(0.86)))
	skin.set_shader_parameter("mottle", look.mottle)
	skin.set_shader_parameter("nose_z", ends.x)
	skin.set_shader_parameter("tail_z", ends.y)
	skin.set_shader_parameter("ridge", look.ridge)
	skin.set_shader_parameter("ridge_from", look.ridge_from)
	skin.set_shader_parameter("ridge_to", look.ridge_to)
	skin.set_shader_parameter("ridge_light", look.ridge_light)
	skin.set_shader_parameter("gill_z", at.call(look.gill_a))
	skin.set_shader_parameter("gill_step", span * float(look.gill_step_a))
	skin.set_shader_parameter("gill_s", look.gill_s)
	skin.set_shader_parameter("gill_shrink", look.gill_shrink)
	skin.set_shader_parameter("gill_bow", look.gill_bow)
	var front: float = look.mouth_front_a
	skin.set_shader_parameter("mouth_s", look.mouth_s)
	skin.set_shader_parameter("mouth_corner_z", at.call(look.mouth_a))
	skin.set_shader_parameter("mouth_front_z", at.call(front) if front >= 0.0 else ends.x - 1.0)
	skin.set_shader_parameter("mouth_under", front >= 0.0)
	skin.set_shader_parameter("mouth_droop", look.mouth_droop)
	skin.set_shader_parameter("mouth_width", look.mouth_w)
	m._skins.append(skin)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _body_mesh(look, ends, w, h)
	body.material_override = skin
	m.add_child(body)

	# Fins: thick, stiff, in the body's colour (tinted with it).
	var fins := ShaderMaterial.new()
	fins.shader = FIN_SHADER
	fins.set_shader_parameter("albedo", back)
	fins.set_shader_parameter("flank_gain", gain)
	fins.set_shader_parameter("belly_color", look.belly)
	fins.set_shader_parameter("spot_color", look.spot)
	fins.set_shader_parameter("spot_cell", float(look.spot_cell) * 0.75)
	fins.set_shader_parameter("spot_size", look.spot_size)
	fins.set_shader_parameter("spot_strength", look.spots)
	fins.set_shader_parameter("mottle", look.mottle)
	m._skins.append(fins)
	var top := func(along: float) -> Vector3: return _surface(look, along, 0.0, w, h, ends)[0]
	var bottom := func(along: float) -> Vector3: return _surface(look, along, 1.0, w, h, ends)[0]
	var bent: Array = []
	# The first dorsal fin, well back; a small second one and an anal fin near
	# the tail; small pelvics.
	var dorsal: Vector2 = look.dorsal
	var dorsal_h: float = h * float(look.dorsal_h)
	var inset := Vector3(0.0, -0.014, 0.0)
	bent.append(_fin(m, fins, top.call(dorsal.x) + inset, top.call(dorsal.y) + inset, Vector3.UP,
			[-0.62, -0.7, -0.86, -1.1, -1.45], [dorsal_h, dorsal_h * 0.88, dorsal_h * 0.6, dorsal_h * 0.3, dorsal_h * 0.1],
			Vector3(0.0, 0.0, 0.08), 0.026))
	bent.append(_fin(m, fins, top.call(0.79) + inset * 0.6, top.call(0.85) + inset * 0.6, Vector3.UP,
			[-0.7, -0.85, -1.1, -1.4], [h * 0.2, h * 0.15, h * 0.07, h * 0.03], Vector3(0.0, 0.0, 0.05), 0.014, 12, 6))
	bent.append(_fin(m, fins, bottom.call(0.81) - inset * 0.6, bottom.call(0.86) - inset * 0.6, Vector3.DOWN,
			[-0.7, -0.85, -1.1, -1.4], [h * 0.17, h * 0.13, h * 0.06, h * 0.03], Vector3(0.0, 0.0, 0.05), 0.012, 12, 6))
	for side: float in [-1.0, 1.0]:
		var pelvic := _surface(look, 0.6, 0.84, w, h, ends)
		var root: Vector3 = (pelvic[0] as Vector3) * Vector3(side, 1.0, 1.0) + Vector3(-side * 0.012, 0.01, 0.0)
		bent.append(_fin(m, fins, root, root + Vector3(0.0, 0.0, l * 0.06), Vector3(side * 0.55, -1.0, 0.25),
				[-0.35, -0.55, -0.85, -1.2], [h * 0.3, h * 0.24, h * 0.13, h * 0.05], Vector3(0.0, 0.0, 0.08), 0.014, 12, 6))
	# Big sickle pectorals low behind the gills, on the swim animation's pivots.
	var pectoral := _surface(look, look.pec_a, look.pec_s, w, h, ends)
	var pec_at: Vector3 = (pectoral[0] as Vector3) - (pectoral[1] as Vector3) * 0.014
	m._fin_pivots(pec_at)
	var pec_len: float = w * float(look.pec_len)
	var pec_root := l * 0.11
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		_fin(pivot, fins, Vector3(0.0, 0.0, -pec_root * 0.5), Vector3(0.0, 0.0, pec_root * 0.5), Vector3(side, -0.32, 0.3),
				[0.08, -0.3, -0.62, -0.95, -1.3], [pec_len, pec_len * 0.66, pec_len * 0.42, pec_len * 0.24, pec_len * 0.1],
				Vector3(0.0, -0.04, 0.3), 0.022, 20, 9)

	# The tail: a tall crescent on the stalk, its top lobe the bigger.
	var tail_a := 0.935
	var stalk := _section(look, tail_a, w, h)
	m._tail_pivot(Vector3(0.0, stalk[3], at.call(tail_a)))
	var tail_len: float = h * float(look.tail_len)
	var lengths: Array = []
	for k: float in look.tail_lengths:
		lengths.append(k * tail_len)
	_fin(m.tail, fins, Vector3(0.0, stalk[1] * 0.85, -0.03), Vector3(0.0, -stalk[2] * 0.85, -0.03), Vector3.BACK,
			look.tail_angles, lengths, Vector3(0.0, 0.0, 0.16), 0.034, 24, 10)
	m._bend_body(at.call(0.52), bent)

	# Small eyes on the sides of the head, set in deep.
	var eye_r: float = look.eye
	var eye := _surface(look, look.eye_a, look.eye_s, w, h, ends)
	var eye_at: Vector3 = (eye[0] as Vector3) - (eye[1] as Vector3) * eye_r * 0.6
	skin.set_shader_parameter("eye_pos", eye[0])
	skin.set_shader_parameter("eye_radius", eye_r)
	for side: float in [-1.0, 1.0]:
		var normal: Vector3 = eye[1]
		var gaze := (normal + Vector3(0.0, 0.05, -0.3)).normalized() * Vector3(side, 1.0, 1.0)
		var ball := m._real_eye(eye_at * Vector3(side, 1.0, 1.0), eye_r, gaze, look.iris, 0.5)
		var material := ball.material_override as ShaderMaterial
		material.set_shader_parameter("rim_color", Color(0.04, 0.045, 0.05))
		material.set_shader_parameter("pupil_stretch", 1.15)
		material.set_shader_parameter("sheen", 0.35)


## Skin `skin`'s look: its own entries over WHALE_SHAPE's.
static func _look(skin: int) -> Dictionary:
	var look: Dictionary = WHALE_SHAPE.duplicate()
	look.merge(LOOKS[clampi(skin, 0, LOOKS.size() - 1)], true)
	return look


## How many times brighter `to` is than `from` (sRGB channels, in linear light).
static func _ratio(to: float, from: float) -> float:
	var a := pow(maxf(to, 0.0), 2.2)
	var b := pow(maxf(from, 0.0), 2.2)
	return clampf(a / maxf(b, 0.002), 1.0, 6.0)


static func _spow(value: float, power: float) -> float:
	return signf(value) * pow(absf(value), power)


## The body's slice `along` it (nose 0, tail 1): half width, height of its top
## and of its bottom from its middle, its middle's height, and how square its
## top and bottom halves are (superellipse exponents, 2 an oval).
static func _section(look: Dictionary, along: float, w: float, h: float) -> PackedFloat32Array:
	var half_w := w * float(look.width) * FishModel._sample(look.w_tab, along)
	var top := h * 0.5 * FishModel._sample(look.top_tab, along)
	var bot := h * 0.5 * FishModel._sample(look.bot_tab, along)
	var mid := lerpf(bot, top, 0.45)
	# The nose closes the slices: over `nose` in height, and over `nose_w` across
	# (longer, so a flat head's front is a broad arc from above).
	var pointed: bool = look.get("pointed", false)
	var cap := _nose_cap(along, look.nose, pointed)
	var cap_w := _nose_cap(along, look.nose_w, pointed)
	if along > 0.965:
		var end := sqrt(maxf(1.0 - pow((along - 0.965) / 0.035, 2.0), 0.0))
		cap *= end
		cap_w *= end
	var head := 1.0 - smoothstep(0.08, 0.3, along)
	var n_head: Vector2 = look.n_head
	var n_body: Vector2 = look.n_body
	var n := n_body.lerp(n_head, head)
	return PackedFloat32Array([half_w * cap_w, (top - mid) * cap, (mid - bot) * cap, mid, n.x, n.y])


## How far open the body is `along` it near the nose, closing over `nose`:
## round, or a cone if `pointed`.
static func _nose_cap(along: float, nose: float, pointed: bool) -> float:
	if along >= nose:
		return 1.0
	var x := along / nose
	var cap := x * (2.0 - x)
	return pow(cap, 0.8) if pointed else sqrt(cap)


## A slice of the body `along` it, without the ridges: its points round from
## the top (down the right side first), their outward normals, how far round
## each is (0 the top to 1 the bottom) and the half round (m).
static func _ring(look: Dictionary, along: float, w: float, h: float) -> Array:
	var section := _section(look, along, w, h)
	var points := PackedVector2Array()
	for k in AROUND:
		var t := TAU * k / AROUND
		var up := cos(t)
		var n := section[4] if up >= 0.0 else section[5]
		var x := section[0] * _spow(sin(t), 2.0 / n)
		var y := section[3] + (section[1] if up >= 0.0 else section[2]) * _spow(up, 2.0 / n)
		points.append(Vector2(x, y))
	var half := HALF
	var arcs := PackedFloat32Array()
	arcs.resize(AROUND)
	arcs[0] = 0.0
	for k in range(1, half + 1):
		arcs[k] = arcs[k - 1] + points[k].distance_to(points[k - 1])
	for k in range(half + 1, AROUND):
		arcs[k] = arcs[AROUND - k]
	var half_round := arcs[half]
	var round_share := PackedFloat32Array()
	var normals := PackedVector2Array()
	for k in AROUND:
		round_share.append(arcs[k] / half_round if half_round > 1e-6 else minf(k, AROUND - k) / float(half))
		var tangent := points[(k + 1) % AROUND] - points[(k + AROUND - 1) % AROUND]
		normals.append(Vector2(-tangent.y, tangent.x).normalized())
	return [points, normals, round_share, half_round]


## How far the flank ridges, the tail stalk's keels and the ridge down the
## back raise the skin (m) `along` the body, `s` round it (0 top, 1 bottom).
static func _ridges(look: Dictionary, along: float, s: float, half_round: float) -> float:
	var raised := 0.0
	var ridge: float = look.ridge
	if ridge > 0.0:
		var fade := smoothstep(0.17, 0.3, along) * (1.0 - smoothstep(0.86, 0.97, along))
		var from: Vector3 = look.ridge_from
		var to: Vector3 = look.ridge_to
		var shift := smoothstep(0.55, 0.9, along)
		for i in 3:
			var d := (s - lerpf(from[i], to[i], shift)) * half_round / 0.016
			raised += ridge * fade * exp(-d * d)
		var spine := s * half_round / 0.016
		raised += ridge * 0.6 * smoothstep(0.1, 0.2, along) * (1.0 - smoothstep(0.4, 0.47, along)) * exp(-spine * spine)
	var keel: float = look.keel
	var k := (s - 0.5) * half_round / 0.014
	raised += keel * smoothstep(0.78, 0.9, along) * (1.0 - smoothstep(0.975, 1.0, along)) * exp(-k * k)
	return raised


## The lofted body from its nose (`ends.x`) to its tail (`ends.y`), its slices
## bunched toward both ends. UV is (distance back over the skin from the nose,
## arc round from the top) in metres, so spots on the head's front stay round,
## and UV2 (share of the half round, the half round in m), for whale_skin.
static func _body_mesh(look: Dictionary, ends: Vector2, w: float, h: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last := PackedVector3Array()
	var back := PackedFloat32Array()
	last.resize(AROUND)
	back.resize(AROUND)
	for i in ROWS + 1:
		var u := float(i) / ROWS
		var along := lerpf(u, 0.5 - 0.5 * cos(PI * u), 0.6)
		var z := lerpf(ends.x, ends.y, along)
		var ring := _ring(look, along, w, h)
		var points: PackedVector2Array = ring[0]
		var normals: PackedVector2Array = ring[1]
		var shares: PackedFloat32Array = ring[2]
		var half_round: float = ring[3]
		for k in AROUND:
			var p := points[k] + normals[k] * _ridges(look, along, shares[k], half_round)
			var vertex := Vector3(p.x, p.y, z)
			back[k] = ends.x if i == 0 else back[k] + vertex.distance_to(last[k])
			last[k] = vertex
			tool.set_uv(Vector2(back[k], shares[k] * half_round))
			tool.set_uv2(Vector2(shares[k], half_round))
			tool.add_vertex(vertex)
	for i in ROWS:
		for k in AROUND:
			var a := i * AROUND + k
			var b := i * AROUND + (k + 1) % AROUND
			for corner: int in [a, b, a + AROUND, b, b + AROUND, a + AROUND]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## A point on the right side of the body (ridges aside) `along` it, `s` round
## (0 top, 1 bottom), and its outward normal (across the body).
static func _surface(look: Dictionary, along: float, s: float, w: float, h: float, ends: Vector2) -> Array:
	var ring := _ring(look, along, w, h)
	var points: PackedVector2Array = ring[0]
	var normals: PackedVector2Array = ring[1]
	var shares: PackedFloat32Array = ring[2]
	var z := lerpf(ends.x, ends.y, along)
	for k in HALF:
		if s <= shares[k + 1] or k == HALF - 1:
			var f := clampf(inverse_lerp(shares[k], shares[k + 1], s), 0.0, 1.0)
			var p := points[k].lerp(points[k + 1], f)
			var n := normals[k].lerp(normals[k + 1], f).normalized()
			return [Vector3(p.x, p.y, z), Vector3(n.x, n.y, 0.0)]
	return [Vector3(0.0, 0.0, z), Vector3.UP]


## A thick, stiff fin on `parent`: from a root line `root0` to `root1` (parent
## space, its leading end first), columns reach out toward `out`, each turned
## `angles` (rad; + toward the leading end) and as long as `lengths` (both
## spread evenly along the root), their tips swept by `curl` (of the length, at
## the tip). It is `thick` m through at the root, thinning to a sharp edge.
static func _fin(parent: Node3D, material: ShaderMaterial, root0: Vector3, root1: Vector3, out: Vector3,
		angles: Array, lengths: Array, curl: Vector3, thick: float, columns := 16, rows := 8) -> MeshInstance3D:
	var root := root1 - root0
	var root_length := root.length()
	var along := root / root_length
	var outward := (out - along * out.dot(along)).normalized()
	var normal := along.cross(outward)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in 2:
		var facing := 1.0 if face == 0 else -1.0
		for i in columns + 1:
			var u := float(i) / columns
			var angle := FishModel._sample(angles, u)
			var length := FishModel._sample(lengths, u)
			var direction := outward * cos(angle) - along * sin(angle)
			for j in rows + 1:
				var v := float(j) / rows
				var mid := root0 + root * u + direction * length * v + curl * length * v * v
				var through := thick * pow(maxf(1.0 - v, 0.0), 0.55) * pow(sin(PI * u), 0.35) * (1.0 - 0.3 * v)
				var flat := mid - root0
				tool.set_uv(Vector2(flat.dot(along), flat.dot(outward)))
				tool.set_uv2(Vector2(u, v))
				tool.add_vertex(mid + normal * through * 0.5 * facing)
	var per_face := (columns + 1) * (rows + 1)
	for face in 2:
		for i in columns:
			for j in rows:
				var a := face * per_face + i * (rows + 1) + j
				var b := a + rows + 1
				var c := a + 1
				var d := b + 1
				var corners := [a, c, b, b, c, d] if face == 0 else [a, b, c, b, d, c]
				for corner: int in corners:
					tool.add_index(corner)
	tool.generate_normals()
	var fin := MeshInstance3D.new()
	fin.name = "Fin"
	fin.mesh = tool.commit()
	fin.material_override = material
	parent.add_child(fin)
	return fin
