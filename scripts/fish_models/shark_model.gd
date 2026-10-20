class_name SharkModel
extends RefCounted
## Dominus's shark (FishModel.build hands it here): skin m.skin of
## FishCharacter.SKINS[FishCharacter.Family.DOMINUS]. One smooth body lofted
## from its snout to its tail stalk (_body_mesh: slices whose width, height,
## squareness and keels the species sets; a hammerhead's flat wide head is part
## of it), painted by shark_skin.gdshader; solid stiff fins with an airfoil's
## thickness (_fin, shark_fin.gdshader); small dark eyes set into the head.
## The rear of the body bends into the tail (FishModel._bend_body).

const SKIN_SHADER := preload("res://shaders/shark_skin.gdshader")
const FIN_SHADER := preload("res://shaders/shark_fin.gdshader")

## Fin kinds for shark_fin.gdshader (UV2.y).
const FIN_DORSAL := 0.0
const FIN_PECTORAL := 1.0
const FIN_CAUDAL := 2.0
const FIN_SMALL := 3.0
const FIN_LOWER := 4.0

## Each skin's species. Body: `semi` its widest half width (of the hitbox's
## width) and half height (of its height); `widest` where along it (nose 0 to
## tail stalk 1), `nose` the snout (toward 0.35 blunt, 1 a needle), `snout_flat`
## how flat the head is, `snout_lift` how high the snout sits (so the mouth is
## underslung), `square` the snout's squareness (2 round), `stalk`/`stalk_size`
## where the tail stalk is and how thick, `stalk_wide` its width against its
## height, `keel` a ridge either side of the stalk, `hammer` a hammer head's
## half span (of the hitbox's width). Fins: [root chord, tip back, tip out,
## leading edge bulge, trailing edge hollow], in the length (the dorsal's root
## chord is its `dorsal_at` span instead). Skin: shark_skin.gdshader's params.
const SPECIES := [
	{  # Great white: stocky, conical snout, sharp ragged line, near-symmetric crescent tail.
		"color": Color(0.3, 0.34, 0.38), "belly": Color(0.93, 0.94, 0.92), "mark": Color(0.06, 0.07, 0.08),
		"semi": Vector2(0.22, 0.48), "widest": 0.37, "nose": 0.7, "snout_flat": 0.6, "snout_lift": 0.22,
		"square": 2.0, "stalk": 0.9, "stalk_size": 0.16, "stalk_wide": 0.95, "keel": 0.35, "hammer": 0.0,
		"line": -0.08, "line_soft": 0.012, "ragged": 0.2, "ragged_scale": 7.0, "flank_lift": 0.3, "metal": 0.0, "pattern": 3.0,
		"eye_s": 0.12, "eye_up": 0.4, "eye_r": 0.017, "iris": Color(0.04, 0.045, 0.05), "pupil": 0.62, "stretch": 1.25,
		"gill_s": 0.22, "mouth_s": Vector2(0.075, 0.15), "mouth_w": 0.72,
		"dorsal_at": Vector2(0.37, 0.52), "dorsal": [0.0, 0.105, 0.135, 0.1, 0.1],
		"pectoral": [0.12, 0.15, 0.23, 0.07, 0.13], "droop": 0.42,
		"upper": [0.085, 0.165, 0.2, 0.07, 0.13], "lower": [0.08, 0.135, 0.17, 0.06, 0.1],
		"tips": 0.0, "band": 0.0, "under_tips": 1.0, "edge_dark": 0.2,
	},
	{  # Shortfin mako: slim, needle snout, metallic indigo, keeled stalk, crescent tail.
		"color": Color(0.1, 0.19, 0.42), "belly": Color(0.95, 0.955, 0.965), "mark": Color(0.05, 0.08, 0.16),
		"semi": Vector2(0.19, 0.45), "widest": 0.4, "nose": 0.95, "snout_flat": 0.55, "snout_lift": 0.2,
		"square": 2.0, "stalk": 0.9, "stalk_size": 0.14, "stalk_wide": 1.0, "keel": 0.55, "hammer": 0.0,
		"line": 0.0, "line_soft": 0.01, "ragged": 0.03, "ragged_scale": 5.0, "flank_lift": 0.75, "metal": 0.45, "pattern": 0.0,
		"eye_s": 0.115, "eye_up": 0.38, "eye_r": 0.021, "iris": Color(0.03, 0.035, 0.05), "pupil": 0.7, "stretch": 1.0,
		"gill_s": 0.22, "mouth_s": Vector2(0.07, 0.15), "mouth_w": 0.68,
		"dorsal_at": Vector2(0.39, 0.51), "dorsal": [0.0, 0.08, 0.115, 0.16, 0.06],
		"pectoral": [0.1, 0.12, 0.19, 0.06, 0.09], "droop": 0.35,
		"upper": [0.08, 0.175, 0.19, 0.07, 0.15], "lower": [0.075, 0.155, 0.17, 0.06, 0.13],
		"tips": 0.0, "band": 0.0, "under_tips": 0.0, "edge_dark": 0.15,
	},
	{  # Blacktip reef: slim, rounded snout, sandy grey, ink-dipped fins, pale flank band.
		"color": Color(0.47, 0.455, 0.39), "belly": Color(0.94, 0.93, 0.9), "mark": Color(0.07, 0.07, 0.07),
		"semi": Vector2(0.185, 0.45), "widest": 0.36, "nose": 0.5, "snout_flat": 0.6, "snout_lift": 0.12,
		"square": 2.0, "stalk": 0.9, "stalk_size": 0.15, "stalk_wide": 0.85, "keel": 0.0, "hammer": 0.0,
		"line": -0.18, "line_soft": 0.02, "ragged": 0.04, "ragged_scale": 5.0, "flank_lift": 0.35, "metal": 0.05, "pattern": 2.0,
		"eye_s": 0.12, "eye_up": 0.4, "eye_r": 0.018, "iris": Color(0.42, 0.44, 0.34), "pupil": 0.42, "stretch": 0.45,
		"gill_s": 0.22, "mouth_s": Vector2(0.075, 0.14), "mouth_w": 0.68,
		"dorsal_at": Vector2(0.37, 0.51), "dorsal": [0.0, 0.105, 0.13, 0.1, 0.15],
		"pectoral": [0.11, 0.15, 0.21, 0.06, 0.15], "droop": 0.42,
		"upper": [0.09, 0.22, 0.17, 0.05, 0.19], "lower": [0.07, 0.095, 0.12, 0.06, 0.06],
		"tips": 1.0, "band": 1.0, "under_tips": 0.0, "edge_dark": 0.15,
	},
	{  # Tiger: the bruiser, deep chest, blunt square snout, bars, long upper lobe.
		"color": Color(0.38, 0.36, 0.28), "belly": Color(0.91, 0.9, 0.86), "mark": Color(0.16, 0.14, 0.09),
		"semi": Vector2(0.235, 0.5), "widest": 0.33, "nose": 0.36, "snout_flat": 0.66, "snout_lift": 0.12,
		"square": 2.9, "stalk": 0.9, "stalk_size": 0.13, "stalk_wide": 1.0, "keel": 0.3, "hammer": 0.0,
		"line": -0.22, "line_soft": 0.03, "ragged": 0.05, "ragged_scale": 5.0, "flank_lift": 0.4, "metal": 0.0, "pattern": 1.0,
		"eye_s": 0.11, "eye_up": 0.42, "eye_r": 0.019, "iris": Color(0.3, 0.33, 0.22), "pupil": 0.45, "stretch": 1.35,
		"gill_s": 0.21, "mouth_s": Vector2(0.06, 0.13), "mouth_w": 0.78,
		"dorsal_at": Vector2(0.36, 0.5), "dorsal": [0.0, 0.11, 0.13, 0.08, 0.11],
		"pectoral": [0.13, 0.15, 0.22, 0.06, 0.12], "droop": 0.42,
		"upper": [0.09, 0.27, 0.16, 0.04, 0.24], "lower": [0.07, 0.1, 0.12, 0.06, 0.06],
		"tips": 0.0, "band": 0.0, "under_tips": 0.0, "edge_dark": 0.3,
	},
	{  # Hammerhead: a great hammerhead's wide flat cephalofoil, eyes at its tips, tall sickle dorsal.
		"color": Color(0.43, 0.41, 0.35), "belly": Color(0.93, 0.92, 0.88), "mark": Color(0.1, 0.09, 0.07),
		"semi": Vector2(0.185, 0.45), "widest": 0.4, "nose": 0.5, "snout_flat": 0.4, "snout_lift": 0.05,
		"square": 2.0, "stalk": 0.9, "stalk_size": 0.15, "stalk_wide": 0.85, "keel": 0.0, "hammer": 0.3,
		"line": -0.12, "line_soft": 0.03, "ragged": 0.05, "ragged_scale": 5.0, "flank_lift": 0.32, "metal": 0.12, "pattern": 0.0,
		"eye_s": 0.04, "eye_up": 0.0, "eye_r": 0.019, "iris": Color(0.62, 0.5, 0.2), "pupil": 0.45, "stretch": 1.3,
		"gill_s": 0.25, "mouth_s": Vector2(0.17, 0.215), "mouth_w": 0.55,
		"dorsal_at": Vector2(0.37, 0.48), "dorsal": [0.0, 0.16, 0.21, 0.1, 0.24],
		"pectoral": [0.1, 0.12, 0.17, 0.05, 0.11], "droop": 0.32,
		"upper": [0.09, 0.23, 0.18, 0.05, 0.2], "lower": [0.08, 0.12, 0.14, 0.05, 0.09],
		"tips": 0.0, "band": 0.0, "under_tips": 0.0, "edge_dark": 0.25,
	},
]

## The hammer head (along the body, nose 0 to tail 1): its front corners round
## off over HAMMER_FRONT, its tips run back to HAMMER_TIPS, and its rear edge
## sweeps back into the neck by HAMMER_END.
const HAMMER_FRONT := 0.05
const HAMMER_TIPS := 0.075
const HAMMER_END := 0.23


static func build(m: FishModel) -> void:
	var sp: Dictionary = SPECIES[clampi(m.skin, 0, SPECIES.size() - 1)]
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	var shape := _shape(sp, m._size)
	var ends: Vector2 = shape.ends
	var span := ends.y - ends.x
	var color: Color = sp.color
	var belly: Color = sp.belly
	# The body.
	m._body_material = m._material(color)  # for set_body_color(); the skin does the shading
	var skin := ShaderMaterial.new()
	skin.shader = SKIN_SHADER
	skin.set_shader_parameter("albedo", color)
	skin.set_shader_parameter("belly_color", belly)
	skin.set_shader_parameter("mark_color", sp.mark)
	for key: String in ["flank_lift", "line_soft", "ragged", "ragged_scale", "metal", "pattern"]:
		skin.set_shader_parameter(key, sp[key])
	skin.set_shader_parameter("belly_line", sp.line)
	m._skins.append(skin)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _body_mesh(shape, 120 if float(sp.hammer) > 0.0 else 100, 44)
	body.material_override = skin
	m.add_child(body)
	var at := func(along: float) -> float: return ends.x + span * along
	# Gills, mouth, nostrils, the tiger's bars and the blacktip's band.
	var gill_s: float = sp.gill_s
	skin.set_shader_parameter("gill_z", at.call(gill_s))
	skin.set_shader_parameter("gill_step", l * 0.019)
	skin.set_shader_parameter("gill_up", Vector2(-0.5, 0.45))
	var mouth_s: Vector2 = sp.mouth_s
	var jaw := _slice(shape, mouth_s.y)
	skin.set_shader_parameter("mouth_z", at.call(mouth_s.x))
	skin.set_shader_parameter("mouth_back", at.call(mouth_s.y) - at.call(mouth_s.x))
	skin.set_shader_parameter("mouth_width", jaw[0] * float(sp.mouth_w))
	var nose_s := 0.03 if float(sp.hammer) > 0.0 else mouth_s.x * 0.45
	var snout := _slice(shape, nose_s)
	skin.set_shader_parameter("nostril", Vector2(snout[0] * (0.82 if float(sp.hammer) > 0.0 else 0.55), at.call(nose_s)))
	skin.set_shader_parameter("head_z", at.call(0.24))
	skin.set_shader_parameter("bar_step", l * 0.055)
	skin.set_shader_parameter("band_span", Vector2(at.call(0.42), at.call(0.86)))
	# Fins in the back's colour, tinted with it.
	var fins := ShaderMaterial.new()
	fins.shader = FIN_SHADER
	fins.set_shader_parameter("albedo", color)
	fins.set_shader_parameter("belly_color", belly)
	fins.set_shader_parameter("tip_color", sp.mark)
	for key: String in ["tips", "band", "under_tips", "edge_dark", "metal"]:
		fins.set_shader_parameter(key, sp[key])
	m._skins.append(fins)
	# First dorsal: tall and swept back, its root sunk into the back.
	var dorsal_at: Vector2 = sp.dorsal_at
	var d_front := _surface(shape, dorsal_at.x, 0.0) - Vector3(0.0, h * 0.04, 0.0)
	var d_back := _surface(shape, dorsal_at.y, 0.0) - Vector3(0.0, h * 0.05, 0.0)
	var dorsal: Array = (sp.dorsal as Array).duplicate()
	dorsal[0] = d_front.distance_to(d_back) / l
	_fin(m, fins, d_front, d_back - d_front, Vector3.UP, _scaled(dorsal, l), 0.13, FIN_DORSAL, Vector3.RIGHT)
	# The rear fins ride the bend: a small second dorsal, an anal fin, pelvics.
	var bent: Array = []
	var d2_front := _surface(shape, 0.8, 0.0) - Vector3(0.0, h * 0.03, 0.0)
	var d2_back := _surface(shape, 0.845, 0.0) - Vector3(0.0, h * 0.03, 0.0)
	bent.append(_fin(m, fins, d2_front, d2_back - d2_front, Vector3.UP,
			[d2_front.distance_to(d2_back), l * 0.045, l * 0.04, 0.06, 0.12], 0.12, FIN_SMALL, Vector3.RIGHT))
	var a_front := _surface(shape, 0.79, PI) + Vector3(0.0, h * 0.03, 0.0)
	var a_back := _surface(shape, 0.84, PI) + Vector3(0.0, h * 0.03, 0.0)
	bent.append(_fin(m, fins, a_front, a_back - a_front, Vector3.DOWN,
			[a_front.distance_to(a_back), l * 0.05, l * 0.045, 0.06, 0.12], 0.12, FIN_SMALL, Vector3.RIGHT))
	for side: float in [-1.0, 1.0]:
		var p_front := _surface(shape, 0.6, PI - side * 0.6) * Vector3(0.85, 1.0, 1.0)
		var p_back := _surface(shape, 0.66, PI - side * 0.45) * Vector3(0.8, 1.0, 1.0)
		bent.append(_fin(m, fins, p_front, p_back - p_front, Vector3(side * 0.7, -0.75, 0.0),
				[p_front.distance_to(p_back), l * 0.07, l * 0.065, 0.06, 0.1], 0.12, FIN_SMALL, Vector3.UP))
	# Long pectorals low behind the gills, on the swim animation's pivots.
	var pectoral := _surface(shape, 0.3, PI * 0.64)
	m._fin_pivots(Vector3(pectoral.x * 0.9, pectoral.y, pectoral.z))
	var pec: Array = _scaled(sp.pectoral, l)
	var droop: float = sp.droop
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		_fin(m, fins, Vector3(-side * l * 0.012, h * 0.02, -pec[0] * 0.45), Vector3.BACK, Vector3(side, -droop, 0.0),
				pec, 0.12, FIN_PECTORAL, Vector3.UP, pivot)
	# The tail: two lobes off the end of the stalk.
	m._tail_pivot(Vector3(0.0, _slice(shape, 0.95)[3], at.call(0.95)))
	var upper: Array = _scaled(sp.upper, l)
	var lower: Array = _scaled(sp.lower, l)
	_fin(m, fins, Vector3(0.0, 0.0, -upper[0] * 0.55), Vector3.BACK, Vector3.UP, upper, 0.12, FIN_CAUDAL, Vector3.RIGHT, m.tail)
	_fin(m, fins, Vector3(0.0, 0.0, -lower[0] * 0.5), Vector3.BACK, Vector3.DOWN, lower, 0.12, FIN_LOWER, Vector3.RIGHT, m.tail)
	m.bend_share = 0.65
	m._bend_body(at.call(0.56), bent)
	# Small dark eyes set into the head (a hammerhead's out on its tips), the
	# skin folding dark round them.
	var radius: float = sp.eye_r
	var eye_at: Vector3
	var look: Vector3
	if float(sp.hammer) > 0.0:
		var s_tip := (HAMMER_FRONT * 0.8 + HAMMER_TIPS) * 0.5
		eye_at = _surface(shape, s_tip, PI * 0.5) - Vector3(radius * 0.55, 0.0, 0.0)
		look = Vector3(1.0, 0.05, -0.2)
	else:
		var s_eye: float = sp.eye_s
		var around := acos(clampf(float(sp.eye_up), -1.0, 1.0))
		var surface := _surface(shape, s_eye, around)
		var middle := Vector3(0.0, _slice(shape, s_eye)[3], surface.z)
		var outward := (surface - middle).normalized()
		eye_at = surface - outward * radius * 0.7
		look = (outward + Vector3(0.0, 0.0, -0.25)).normalized()
	skin.set_shader_parameter("eye_at", eye_at)
	skin.set_shader_parameter("eye_size", radius)
	for side: float in [-1.0, 1.0]:
		var eye := m._real_eye(eye_at * Vector3(side, 1.0, 1.0), radius, look * Vector3(side, 1.0, 1.0), sp.iris, sp.pupil)
		var material := eye.material_override as ShaderMaterial
		material.set_shader_parameter("pupil_stretch", sp.stretch)
		material.set_shader_parameter("rim_color", Color(0.03, 0.03, 0.035))
		material.set_shader_parameter("iris_inner", (sp.iris as Color).darkened(0.6))
		material.set_shader_parameter("sheen", 0.25)
	# The great white's dark armpit patch, just behind the pectoral's root.
	skin.set_shader_parameter("axilla", Vector3(pectoral.x * 0.95, pectoral.y + h * 0.02, pectoral.z + l * 0.06))
	skin.set_shader_parameter("axilla_size", l * 0.028)


## The species' body in metres for _slice: the ends, widest half sizes and its
## shape numbers.
static func _shape(sp: Dictionary, size: Vector3) -> Dictionary:
	var semi: Vector2 = sp.semi
	var shape := sp.duplicate()
	shape.ends = Vector2(-size.z * 0.5, size.z * 0.4)
	shape.hw = size.x * semi.x
	shape.hh = size.y * semi.y
	shape.hammer_m = size.x * float(sp.hammer)
	return shape


## A fin's [root chord, tip back, tip out, bulge, hollow] with its lengths
## (the first three, given in the body's length) in metres.
static func _scaled(fin: Array, length: float) -> Array:
	return [float(fin[0]) * length, float(fin[1]) * length, float(fin[2]) * length, fin[3], fin[4]]


## The body's slice `along` it (nose 0 to tail 1): [half width, height above
## its middle, depth below it, its middle's height, squareness (2 an oval),
## keel].
static func _slice(shape: Dictionary, along: float) -> PackedFloat32Array:
	var stalk: float = shape.stalk
	var stalk_size: float = shape.stalk_size
	var r := FishModel._taper(along, shape.widest, stalk, stalk_size, shape.nose)
	# Past the stalk it narrows to a point rising into the tail's top lobe.
	var end := clampf((along - stalk) / (1.0 - stalk), 0.0, 1.0)
	if end > 0.0:
		r = stalk_size * pow(1.0 - end, 0.75)
	var head := smoothstep(0.0, 0.34, along)
	var rear := smoothstep(0.55, 0.95, along)
	var hw: float = shape.hw * r * lerpf(1.0, float(shape.stalk_wide), rear)
	var flat := lerpf(float(shape.snout_flat), 1.0, head)
	var hh: float = shape.hh
	var top := hh * r * flat
	var bottom := hh * r * flat * lerpf(0.8, 0.9, head)
	var middle := hh * float(shape.snout_lift) * (1.0 - head) * r + hh * stalk_size * 0.5 * end
	var square := lerpf(float(shape.square), 2.15, smoothstep(0.0, 0.3, along))
	var keel: float = float(shape.keel) * smoothstep(0.8, 0.9, along) * (1.0 - smoothstep(0.96, 1.0, along))
	var half_span: float = shape.hammer_m
	if half_span > 0.0:
		# The hammer: a flat wide lens, its front nearly straight across with
		# rounded corners, its rear edge sweeping back into the neck.
		var front := sqrt(maxf(1.0 - pow(1.0 - minf(along / HAMMER_FRONT, 1.0), 2.0), 0.0))
		var t := clampf((along - HAMMER_TIPS) / (HAMMER_END - HAMMER_TIPS), 0.0, 1.0)
		var hammer := half_span * front * pow(1.0 - t, 1.6)
		var lens := smoothstep(0.0, 1.0, (hammer - hw) / (half_span * 0.35))
		hw = maxf(hw, hammer)
		top = maxf(top, hh * 0.17 * front * (1.0 - 0.2 * t))
		bottom = maxf(bottom, hh * 0.12 * front * (1.0 - 0.2 * t))
		middle = lerpf(middle, hh * 0.08, lens)
		square = lerpf(square, 2.05, lens)
	return PackedFloat32Array([hw, top, bottom, middle, square, keel])


## A point on the body's surface `along` it, `around` (rad) from its top
## toward its right side.
static func _surface(shape: Dictionary, along: float, around: float) -> Vector3:
	var ends: Vector2 = shape.ends
	return _ring_point(_slice(shape, along), around, lerpf(ends.x, ends.y, along))


static func _ring_point(slice: PackedFloat32Array, around: float, z: float) -> Vector3:
	var sx := sin(around)
	var cy := cos(around)
	var power := 2.0 / slice[4]
	var x := slice[0] * signf(sx) * pow(absf(sx), power) * (1.0 + slice[5] * pow(absf(sx), 12.0))
	var y := slice[3] + (slice[1] if cy >= 0.0 else slice[2]) * signf(cy) * pow(absf(cy), power)
	return Vector3(x, y, z)


## The body: `rows` slices from the snout to the tail stalk, closer together
## at the head, `around` points round each. UV is (along, cos round), UV2.x
## the sin round (shark_skin.gdshader paints from them).
static func _body_mesh(shape: Dictionary, rows: int, around: int) -> ArrayMesh:
	var ends: Vector2 = shape.ends
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bunch := 1.55 if float(shape.hammer) > 0.0 else 1.35
	for i in rows + 1:
		# Close together at the snout (the head's shape) and at the tail's end.
		var t := float(i) / rows
		var along := lerpf(pow(t, bunch), 1.0 - pow(1.0 - t, 1.6), smoothstep(0.5, 1.0, t))
		var z := lerpf(ends.x, ends.y, along)
		var slice := _slice(shape, along)
		for k in around:
			var angle := TAU * k / around
			tool.set_uv(Vector2(along, cos(angle)))
			tool.set_uv2(Vector2(sin(angle), 0.0))
			tool.add_vertex(_ring_point(slice, angle, z))
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, b, a + around, b, b + around, a + around]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## A stiff fin (shark_fin.gdshader) on `parent` (the model if null): a solid
## blade with an airfoil's section, its root running from `root` along `back`
## for `fin[0]` m, reaching out along `out` to its tip `fin[1]` m back and
## `fin[2]` m out from the root's front. Its leading edge bulges by `fin[3]`
## (of its length) and its trailing edge hollows by `fin[4]` (a shark's sickle
## fins). `thickness` is of its chord. `top` says which face is its top.
static func _fin(m: FishModel, material: ShaderMaterial, root: Vector3, back: Vector3, out: Vector3, fin: Array,
		thickness: float, kind: float, top: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var a := back.normalized()
	var b := (out - a * a.dot(out)).normalized()
	var n := a.cross(b).normalized()
	var top_sign := 1.0 if n.dot(top) >= 0.0 else -1.0
	var chord: float = fin[0]
	var tip := Vector2(fin[1], fin[2])
	var le_mid := tip * 0.5
	var le_dir := tip.normalized()
	var le_ctrl := le_mid + Vector2(-le_dir.y, le_dir.x) * float(fin[3]) * tip.length()
	var te_start := Vector2(chord, 0.0)
	var te_dir := (tip - te_start).normalized()
	var te_ctrl := (te_start + tip) * 0.5 + Vector2(-te_dir.y, te_dir.x) * float(fin[4]) * (tip - te_start).length()
	var rows := 14
	var ring := 22
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows + 1:
		var v := float(i) / rows
		var le := _bezier(Vector2.ZERO, le_ctrl, tip, v)
		var te := _bezier(te_start, te_ctrl, tip, v)
		var width := le.distance_to(te)
		for k in ring:
			var phi := TAU * k / ring
			var c := (1.0 - cos(phi)) * 0.5
			var flat := le.lerp(te, c)
			var half := 5.0 * thickness * width * (0.2969 * sqrt(c) - 0.126 * c - 0.3516 * c * c + 0.2843 * c * c * c - 0.1036 * c * c * c * c)
			half = maxf(half, 0.0) * (1.0 - 0.35 * v)
			var face := signf(sin(phi))
			tool.set_uv(Vector2(c, v))
			tool.set_uv2(Vector2(sin(phi) * top_sign, kind))
			tool.add_vertex(root + a * flat.x + b * flat.y + n * face * half)
	for i in rows:
		for k in ring:
			var p := i * ring + k
			var q := i * ring + (k + 1) % ring
			for corner: int in [p, q, p + ring, q, q + ring, p + ring]:
				tool.add_index(corner)
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "Fin"
	mesh.mesh = tool.commit()
	mesh.material_override = material
	(parent if parent else m).add_child(mesh)
	return mesh


static func _bezier(from: Vector2, control: Vector2, to: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return from * u * u + control * 2.0 * u * t + to * t * t
