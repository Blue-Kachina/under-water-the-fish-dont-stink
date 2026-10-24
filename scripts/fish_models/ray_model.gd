class_name RayModel
extends RefCounted
## The Gliders' rays (FishModel.build hands it here): species m.species of
## FishCharacter.SPECIES[FishCharacter.FishClass.GLIDER]. One smooth disc per species
## (its outline, dome, head and eye mounds from LOOKS below) drawn with
## FishModel.RAY_SKIN, so FishModel's swim beats, ripples and banks the wings and
## bends the tail (m._skin, m._tail_skin, m._whip). The tail's thick root sits
## in a short stalk at the back of the disc, round the tail pivot, so it never
## parts from the body however it swings.
##
## Sizes below: x and z in hitbox lengths (l), heights in hitbox heights (h).
## The outline is (along nose 0 to tail end 1, half width) points, "tip" the
## index of a pointed wingtip (-1 rounded).

const LOOKS := [
	{  # Reef manta (Mobula alfredi): wide swept wings, black back with white
		# shoulder patches, white belly with dark spots, head lobes, short tail.
		"pattern": 0,
		"color": Color(0.085, 0.09, 0.105),
		"belly": Color(0.93, 0.93, 0.9),
		"mark": Color(0.92, 0.93, 0.9),
		"mark2": Color(0.16, 0.17, 0.2),
		"nose": -0.43, "end": 0.2,
		"outline": [[0.0, 0.072], [0.05, 0.08], [0.13, 0.1], [0.23, 0.16], [0.33, 0.26], [0.41, 0.39],
				[0.48, 0.56], [0.53, 0.47], [0.62, 0.3], [0.72, 0.18], [0.82, 0.095], [0.9, 0.045],
				[0.95, 0.026], [1.0, 0.0]],
		"tip": 6, "front_cap": 0.035, "back_cap": 0.05,
		"dome": [0.38, 0.22, 0.12, 0.2, -0.13],  # top, belly, half wide, half long, centre z
		"wing_root": [0.1, 0.07, 0.26],  # top, belly, half wide: the wings' thick root
		"head": [0.16, 0.08, 0.08, -0.36],  # height, half wide, half long, centre z
		"snout": [0.0, 0.05, 0.03],  # height, half wide, half long (at the nose)
		"brow": [0.0, 0.0, 0.0],  # height, x, z
		"eye": [0.068, -0.395, 0.022, 0.0],  # x, z, radius (m), how far up the side (0 rim)
		"eye_look": Vector3(1.0, 0.05, -0.25), "iris": Color(0.18, 0.16, 0.14), "eye_side": true,
		"hinge": 0.11, "rest_flap": 0.12,
		"stalk": 0.026,  # m: the tail root's radius
		"tail": [0.2, 0.024, 0.2, 0.0],  # length (l), root radius (m), tip radius share, curl
		"spots": [0.06, Vector2(0.1, 0.2), 0.3, 0.0],
		"mottle": 0.12, "rim_shade": 0.1, "bump": 0.25, "denticle": 180.0, "wet": 0.7,
		"gills": [-0.33, -0.2, 0.06, 0.022], "mouth": [-0.425, 0.06], "front_mouth": true,
		"belly_margin": 0.12, "spiracle": [0.0, 0.0, 0.0],
		"patch": [0.045, -0.33, 0.25, -0.2, 0.034, 0.007],  # a x, z, b x, z, half widths (l)
		"lobes": true, "dorsal": 0.035,
	},
	{  # Spotted eagle ray (Aetobatus narinari): pointed duck-bill head, swept
		# falcon wings, navy back covered in white spots and rings, long whip.
		"pattern": 1,
		"color": Color(0.1, 0.14, 0.24),
		"belly": Color(0.95, 0.95, 0.93),
		"mark": Color(0.94, 0.95, 0.92),
		"mark2": Color(0.08, 0.1, 0.18),
		"nose": -0.45, "end": 0.17,
		"outline": [[0.0, 0.0], [0.025, 0.026], [0.07, 0.04], [0.13, 0.046], [0.19, 0.056], [0.24, 0.07],
				[0.28, 0.1], [0.36, 0.22], [0.44, 0.37], [0.52, 0.52], [0.57, 0.42], [0.66, 0.26],
				[0.76, 0.15], [0.86, 0.08], [0.93, 0.035], [1.0, 0.0]],
		"tip": 9, "front_cap": 0.025, "back_cap": 0.05,
		"dome": [0.36, 0.2, 0.08, 0.2, -0.1],
		"wing_root": [0.07, 0.05, 0.22],
		"head": [0.2, 0.05, 0.09, -0.31],
		"snout": [0.02, 0.035, 0.06],
		"brow": [0.0, 0.0, 0.0],
		"eye": [0.047, -0.305, 0.022, 0.55],
		"eye_look": Vector3(1.0, 0.25, -0.15), "iris": Color(0.3, 0.26, 0.16), "eye_side": true,
		"hinge": 0.1, "rest_flap": 0.18,
		"stalk": 0.021,
		"tail": [1.0, 0.019, 0.08, 0.25],
		"spots": [0.042, Vector2(0.1, 0.2), 0.12, 0.35],
		"mottle": 0.08, "rim_shade": 0.3, "bump": 0.25, "denticle": 220.0, "wet": 0.75,
		"gills": [-0.24, -0.13, 0.05, 0.016], "mouth": [-0.4, 0.025], "front_mouth": false,
		"belly_margin": 0.0, "spiracle": [0.0, 0.0, 0.0],
		"patch": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		"lobes": false, "dorsal": 0.03,
	},
	{  # Southern stingray (Hypanus americanus): diamond disc, plain sandy brown,
		# raised eyes and spiracles, long whip with a barb.
		"pattern": 2,
		"color": Color(0.36, 0.33, 0.24),
		"belly": Color(0.94, 0.92, 0.86),
		"mark": Color(0.78, 0.74, 0.6),
		"mark2": Color(0.45, 0.42, 0.36),
		"nose": -0.47, "end": 0.28,
		"outline": [[0.0, 0.0], [0.025, 0.03], [0.1, 0.095], [0.25, 0.22], [0.4, 0.35], [0.5, 0.405],
				[0.6, 0.35], [0.72, 0.23], [0.81, 0.14], [0.86, 0.11], [0.9, 0.1], [0.94, 0.05],
				[0.97, 0.03], [1.0, 0.0]],
		"tip": -1, "front_cap": 0.03, "back_cap": 0.05,
		"dome": [0.36, 0.2, 0.13, 0.26, -0.08],
		"wing_root": [0.08, 0.06, 0.24],
		"head": [0.1, 0.09, 0.1, -0.28],
		"snout": [0.03, 0.04, 0.06],
		"brow": [0.1, 0.045, -0.27],
		"eye": [0.045, -0.275, 0.019, 1.0],
		"eye_look": Vector3(0.6, 1.0, -0.3), "iris": Color(0.62, 0.56, 0.38), "eye_side": false,
		"hinge": 0.13, "rest_flap": 0.15,
		"stalk": 0.026,
		"tail": [0.78, 0.024, 0.08, 0.1],
		"spots": [0.06, Vector2(0.1, 0.2), 0.3, 0.0],
		"mottle": 0.2, "rim_shade": 0.3, "bump": 0.7, "denticle": 300.0, "wet": 0.55,
		"gills": [-0.27, -0.15, 0.06, 0.018], "mouth": [-0.33, 0.03], "front_mouth": false,
		"belly_margin": 0.1, "spiracle": [0.05, -0.235, 0.011],
		"patch": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		"lobes": false, "dorsal": 0.0, "barb": 0.36,
	},
	{  # Blue-spotted ribbontail (Taeniura lymma): oval disc, tan with vivid blue
		# spots, big gold eyes, a thick tail with blue side stripes and a fold.
		"pattern": 3,
		"color": Color(0.55, 0.42, 0.2),
		"belly": Color(0.95, 0.93, 0.86),
		"mark": Color(0.12, 0.5, 1.0),
		"mark2": Color(0.3, 0.22, 0.1),
		"nose": -0.46, "end": 0.24,
		"outline": [[0.0, 0.0], [0.015, 0.07], [0.05, 0.15], [0.14, 0.24], [0.28, 0.305], [0.43, 0.325],
				[0.58, 0.3], [0.7, 0.24], [0.78, 0.17], [0.84, 0.12], [0.89, 0.105], [0.93, 0.06],
				[0.965, 0.034], [1.0, 0.0]],
		"tip": -1, "front_cap": 0.03, "back_cap": 0.05,
		"dome": [0.36, 0.2, 0.12, 0.25, -0.1],
		"wing_root": [0.08, 0.06, 0.22],
		"head": [0.08, 0.09, 0.1, -0.28],
		"snout": [0.0, 0.04, 0.05],
		"brow": [0.13, 0.05, -0.29],
		"eye": [0.05, -0.29, 0.024, 1.0],
		"eye_look": Vector3(0.5, 1.0, -0.2), "iris": Color(0.9, 0.68, 0.16), "eye_side": false,
		"hinge": 0.13, "rest_flap": 0.12,
		"stalk": 0.036,
		"tail": [0.55, 0.036, 0.18, 0.05],
		"spots": [0.05, Vector2(0.12, 0.24), 0.2, 0.0],
		"mottle": 0.1, "rim_shade": 0.25, "bump": 0.3, "denticle": 220.0, "wet": 0.75,
		"gills": [-0.26, -0.15, 0.055, 0.017], "mouth": [-0.33, 0.028], "front_mouth": false,
		"belly_margin": 0.0, "spiracle": [0.052, -0.25, 0.012],
		"patch": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		"lobes": false, "dorsal": 0.0, "fold": true,
	},
]


static func build(m: FishModel) -> void:
	var p: Dictionary = LOOKS[clampi(m.species, 0, LOOKS.size() - 1)]
	var shape := Shape.new(m._size, p)
	var w := m._size.x
	var l := m._size.z
	var color: Color = p.color
	m._body_material = m._material(color, 0.45)  # for set_body_color(); the skin is shaded by _skin
	m._skin = ShaderMaterial.new()
	m._skin.shader = FishModel.RAY_SKIN
	_paint(m._skin, p, l)
	var hinge: float = p.hinge
	m._skin.set_shader_parameter("hinge", hinge)
	m._skin.set_shader_parameter("span", shape.span)
	m._skin.set_shader_parameter("rest_flap", p.rest_flap)
	m._skin.set_shader_parameter("wave", TAU / (shape.length() * 1.1))
	m._skin.set_shader_parameter("wave_from", shape.ends.x)
	m._skin.set_shader_parameter("wave_to", shape.ends.y)
	var gills: Array = p.gills
	m._skin.set_shader_parameter("gill_from", l * float(gills[0]))
	m._skin.set_shader_parameter("gill_to", l * float(gills[1]))
	m._skin.set_shader_parameter("gill_x", l * float(gills[2]))
	m._skin.set_shader_parameter("gill_length", l * float(gills[3]))
	var mouth: Array = p.mouth
	m._skin.set_shader_parameter("mouth_z", l * float(mouth[0]))
	m._skin.set_shader_parameter("mouth_width", l * float(mouth[1]))
	m._skin.set_shader_parameter("front_mouth", p.front_mouth)
	m._skin.set_shader_parameter("belly_margin", p.belly_margin)
	var spiracle: Array = p.spiracle
	m._skin.set_shader_parameter("spiracle", Vector3(l * float(spiracle[0]), l * float(spiracle[1]), l * float(spiracle[2])))
	var patch: Array = p.patch
	m._skin.set_shader_parameter("patch_a", Vector2(float(patch[0]), float(patch[1])) * l)
	m._skin.set_shader_parameter("patch_b", Vector2(float(patch[2]), float(patch[3])) * l)
	m._skin.set_shader_parameter("patch_w", Vector2(float(patch[4]), float(patch[5])) * l)
	m._skin.set_shader_parameter("ridge", Vector2(shape.ends.x + shape.length() * 0.3, shape.ends.y))
	m._skin.set_shader_parameter("ridge_width", l * 0.03)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = shape.mesh()
	body.material_override = m._skin
	body.extra_cull_margin = 0.3  # the shader bends the wings out of the mesh's bounds
	m.add_child(body)
	if p.lobes:
		_head_lobes(m, shape)
	if float(p.dorsal) > 0.0:
		_dorsal_fin(m, shape, float(p.dorsal))
	_eyes(m, shape, p)
	# The wings bend in the shader: the pivots only carry the swim animation's
	# flap and sweep to it (FishModel._swim).
	m._fin_pivots(Vector3(maxf(hinge, w * 0.18), 0.0, shape.tip_z()))
	_tail(m, shape, p)


## The shader's colours and markings for skin `p` (both the body's and the tail's).
static func _paint(material: ShaderMaterial, p: Dictionary, l: float) -> void:
	material.set_shader_parameter("pattern", p.pattern)
	material.set_shader_parameter("albedo", p.color)
	material.set_shader_parameter("belly_color", p.belly)
	material.set_shader_parameter("mark_color", p.mark)
	material.set_shader_parameter("mark_color2", p.mark2)
	material.set_shader_parameter("mark_glow", 0.25 if int(p.pattern) == 3 else 0.0)
	var spots: Array = p.spots
	material.set_shader_parameter("spot_cell", l * float(spots[0]))
	material.set_shader_parameter("spot_size", spots[1])
	material.set_shader_parameter("spot_gap", spots[2])
	material.set_shader_parameter("ring_share", spots[3])
	material.set_shader_parameter("mottle", p.mottle)
	material.set_shader_parameter("rim_shade", p.rim_shade)
	material.set_shader_parameter("bumpiness", p.bump)
	material.set_shader_parameter("denticle", p.denticle)
	material.set_shader_parameter("wetness", p.wet)
	material.set_shader_parameter("stripe_color", p.mark)


## Eyes in their mounds (or on the sides of the head), set deep in the skin.
static func _eyes(m: FishModel, shape: Shape, p: Dictionary) -> void:
	var l := m._size.z
	var eye: Array = p.eye
	var radius: float = eye[2]
	var z := l * float(eye[1])
	for side: float in [-1.0, 1.0]:
		var at: Vector3
		var look: Vector3 = p.eye_look
		look.x *= side
		if p.eye_side:
			# On the side of the head: out at the rim, `eye[3]` of the way up it.
			var edge := shape.edge(shape.along_at(z))
			var x := edge * lerpf(0.97, 0.75, float(eye[3]))
			var y := shape.top(x, z) * float(eye[3]) * 0.9
			at = Vector3(side * (x - radius * 0.35), y, z)
		else:
			var x := l * float(eye[0])
			at = Vector3(side * x, shape.top(x, z) - radius * 0.5, z)
		var ball := m._real_eye(at, radius, look, p.iris, 0.5)
		var material := ball.material_override as ShaderMaterial
		material.set_shader_parameter("pupil_stretch", 1.6)
		material.set_shader_parameter("rim_color", (p.color as Color).darkened(0.5))
		if int(p.pattern) == 3:
			material.set_shader_parameter("sheen", 0.7)
			material.set_shader_parameter("pupil", 0.36)


## The manta's cephalic fins: two paddles curling forward off the corners of
## its wide mouth, dark outside and pale inside.
static func _head_lobes(m: FishModel, shape: Shape) -> void:
	var l := m._size.z
	var h := m._size.y
	var front := shape.ends.x
	var x0 := shape.edge(0.03) * 0.9
	for side: float in [-1.0, 1.0]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rows := 14
		var around := 14
		for i in rows + 1:
			var t := float(i) / rows
			# Out of the head's corner, forward and a little in, curling inward at the tip.
			var centre := Vector3(side * (x0 - l * 0.004 * t - l * 0.018 * t * t), -h * 0.03 * t,
					front + l * 0.025 - l * 0.1 * t)
			var chord := l * 0.016 * sin(PI * lerpf(0.25, 0.9, t)) + 0.003
			var thick := l * 0.008 * (1.0 - 0.6 * t) + 0.002
			# Rolled into a horn: the flat of it upright, turning in toward the tip.
			var roll := lerpf(0.2, 0.7, t) * side
			var wide := Vector3(sin(roll) * 0.5, cos(roll), 0.0).normalized()
			var thin := Vector3(cos(roll), -sin(roll) * 0.5, 0.0).normalized() * side
			for k in around:
				var angle := TAU * k / around
				var off := wide * cos(angle) * chord + thin * sin(angle) * thick
				# Curl: the paddle's edges bend inward (a C in section).
				off += thin * -0.6 * chord * cos(angle) * cos(angle)
				var outside := sin(angle) > 0.0
				tool.set_uv(Vector2(t, 1.0 if outside else 0.55))
				tool.set_uv2(Vector2(0.5, -1.0))
				tool.add_vertex(centre + off)
		_close_loft(tool, rows, around, side < 0.0)
		var lobe := MeshInstance3D.new()
		lobe.name = "HeadLobe"
		lobe.mesh = tool.commit()
		lobe.material_override = m._skin
		m.add_child(lobe)


## A small dorsal fin just in front of the tail, `height` (m) tall.
static func _dorsal_fin(m: FishModel, shape: Shape, height: float) -> void:
	var z := shape.ends.y - shape.length() * 0.06
	var base := shape.top(0.0, z)
	var chord := shape.length() * 0.08
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 8
	var around := 12
	for i in rows + 1:
		var t := float(i) / rows
		var centre := Vector3(0.0, base - 0.01 + (height + 0.01) * t, z - chord * 0.3 + chord * 0.55 * t * t)
		var half := chord * 0.5 * (1.0 - t * 0.85)
		for k in around:
			var angle := TAU * k / around
			tool.set_uv(Vector2(t, 1.0))
			tool.set_uv2(Vector2(0.5, -1.0))
			tool.add_vertex(centre + Vector3(sin(angle) * 0.004 * (1.0 - t * 0.7), 0.0, cos(angle) * half))
	_close_loft(tool, rows, around, false)
	var fin := MeshInstance3D.new()
	fin.name = "DorsalFin"
	fin.mesh = tool.commit()
	fin.material_override = m._skin
	m.add_child(fin)


## Indexes a loft of `rows` + 1 rings of `around` vertices, closed round and
## capped at its last ring (it starts inside the body), then normals.
static func _close_loft(tool: SurfaceTool, rows: int, around: int, flip: bool) -> void:
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			var c := a + around
			var d := b + around
			var corners := [a, b, c, b, d, c] if flip else [a, c, b, b, c, d]
			for corner: int in corners:
				tool.add_index(corner)
	var last := rows * around
	for k in range(1, around - 1):
		var corners := [last, last + k, last + k + 1] if flip else [last, last + k + 1, last + k]
		for corner: int in corners:
			tool.add_index(corner)
	tool.generate_normals()


## The tail on its pivot, inside the stalk at the back of the disc: the whip
## FishModel bends (m._whip, m._tail_skin), with its thick root ball round the
## pivot so it turns in the stalk like a joint.
static func _tail(m: FishModel, shape: Shape, p: Dictionary) -> void:
	var l := m._size.z
	var tail_p: Array = p.tail
	var root: float = tail_p[1]
	var stalk: float = p.stalk
	# The pivot sits a little in front of the end of the stalk, deep in it.
	m._tail_pivot(Vector3(0.0, shape.stalk_y(), shape.ends.y - stalk * 1.6))
	var length := l * float(tail_p[0])
	m._tail_skin = ShaderMaterial.new()
	m._tail_skin.shader = FishModel.RAY_SKIN
	_paint(m._tail_skin, p, l)
	m._tail_skin.set_shader_parameter("tail_mode", true)
	m._tail_skin.set_shader_parameter("tail_length", length)
	m._skins.append_array([m._skin, m._tail_skin])
	m._waving.append_array([m._skin, m._tail_skin])
	m._whip = MeshInstance3D.new()
	m._whip.name = "Whip"
	m._whip.mesh = _tail_mesh(length, root, float(tail_p[2]), float(tail_p[3]), p)
	m._whip.material_override = m._tail_skin
	m._whip.extra_cull_margin = length  # the shader bends it out of the mesh's bounds
	m.tail.add_child(m._whip)
	var bounds := m._whip.mesh.get_aabb()
	m._whip_rest_tip = Vector3(0.0, bounds.end.y, bounds.end.z)


## The tail: a tube along +Z from a round root (centred on the pivot) tapering
## to `tip` of its `root` radius, curling up by `curl` (rad) toward the tip.
## UV.x runs 0 at the root to 1 at the tip (the shader bends it by that), UV.y
## round it (0.25 on top); UV2.x marks the barb (1) and the ribbon fold (2).
static func _tail_mesh(length: float, root: float, tip: float, curl: float, p: Dictionary) -> ArrayMesh:
	var rings := 44
	var sides := 12
	var cap := 4  # rings round the root ball
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := cap + rings
	for i in rows + 1:
		var centre: Vector3
		var up: Vector3
		var radius: float
		var s: float
		if i < cap:
			var angle := PI / 2.0 * (1.0 - float(i) / cap)
			centre = Vector3(0.0, 0.0, -root * sin(angle))
			up = Vector3.UP
			radius = root * cos(angle)
			s = 0.0
		else:
			s = float(i - cap) / rings
			var frame := _tail_frame(length, curl, s)
			centre = frame[0]
			up = frame[1]
			radius = _tail_radius(root, tip, s)
		for k in sides + 1:
			var angle := TAU * k / sides
			tool.set_uv(Vector2(s, float(k) / sides))
			tool.set_uv2(Vector2.ZERO)
			# A little flattened, as a ray's tail is (wider than deep).
			tool.add_vertex(centre + Vector3.RIGHT * cos(angle) * radius * 1.1 + up * sin(angle) * radius * 0.9)
	for i in rows:
		for k in sides:
			var a := i * (sides + 1) + k
			var b := a + 1
			var c := a + sides + 1
			var d := c + 1
			for corner: int in [a, c, b, b, c, d]:
				tool.add_index(corner)
	var next := (rows + 1) * (sides + 1)
	if p.has("barb"):
		next = _barb(tool, next, length, root, tip, curl, float(p.barb))
	if p.has("fold"):
		next = _fold(tool, next, length, root, tip, curl)
	tool.generate_normals()
	return tool.commit()


## The tail's middle and its up `s` along it (0 root to 1 tip), at rest.
static func _tail_frame(length: float, curl: float, s: float) -> Array:
	var at := Vector3.ZERO
	var steps := 24
	for k in steps:
		var pitch := curl * pow((k + 0.5) / steps * s, 1.6)
		at += Vector3(0.0, sin(pitch), cos(pitch)) * length * s / steps
	var pitch := curl * pow(s, 1.6)
	return [at, Vector3(0.0, cos(pitch), -sin(pitch))]


static func _tail_radius(root: float, tip: float, s: float) -> float:
	# Thick at the root, thinning quickly at first, then slowly to the tip.
	var shape := lerpf(1.0, tip, 1.0 - pow(1.0 - s, 2.2))
	return root * maxf(shape, 0.06)


## The stingray's barb: a flat serrated spine lying back along the top of the
## tail at `at` along it. Returns the next free vertex index.
static func _barb(tool: SurfaceTool, first: int, length: float, root: float, tip: float, curl: float, at: float) -> int:
	var frame := _tail_frame(length, curl, at)
	var base: Vector3 = frame[0] + (frame[1] as Vector3) * _tail_radius(root, tip, at) * 0.8
	var long := length * 0.12
	var points := [
		base + Vector3(-0.009, 0.0, 0.0), base + Vector3(0.009, 0.0, 0.0),
		base + Vector3(0.0, 0.007, 0.0), base + Vector3(0.0, 0.014, long)]
	for point: Vector3 in points:
		tool.set_uv(Vector2(at, 0.25))
		tool.set_uv2(Vector2(1.0, 0.0))
		tool.add_vertex(point)
	for corner: int in [0, 2, 3, 2, 1, 3, 1, 0, 3, 0, 1, 2, 0, 3, 2, 2, 3, 1, 1, 3, 0, 0, 2, 1]:
		tool.add_index(first + corner)  # both ways round: it's thin
	return first + points.size()


## The ribbontail's fold: a fin running under the back half of its tail.
## Returns the next free vertex index.
static func _fold(tool: SurfaceTool, first: int, length: float, root: float, tip: float, curl: float) -> int:
	var count := 14
	var from := 0.4
	var to := 0.97
	for i in count + 1:
		var s := lerpf(from, to, float(i) / count)
		var frame := _tail_frame(length, curl, s)
		var up: Vector3 = frame[1]
		var radius := _tail_radius(root, tip, s)
		var depth := root * 1.3 * sin(PI * float(i) / count)
		for edge in 2:  # inside the tail, then the fold's free edge
			var y := -radius * 0.5 if edge == 0 else -radius * 0.85 - depth
			tool.set_uv(Vector2(s, 0.75))
			tool.set_uv2(Vector2(2.0, 0.0))
			tool.add_vertex(frame[0] + up * y)
	# Two faces, one each way, sharing the vertices (thin enough not to need a gap).
	for i in count:
		var a := first + i * 2
		var b := a + 2
		for corner: int in [a, a + 1, b, b, a + 1, b + 1, a, b, a + 1, b, b + 1, a + 1]:
			tool.add_index(corner)
	return first + (count + 1) * 2


## A species' disc: its outline, how thick it is where, and the mesh.
class Shape:
	var size: Vector3
	var p: Dictionary
	var ends: Vector2  # nose and tail end (z, m)
	var span: float  # the widest point out from the middle (m)
	var points: Array = []  # [along, half width m]
	var slopes: Array = []  # [in, out] at each point

	func _init(hitbox: Vector3, skin: Dictionary) -> void:
		size = hitbox
		p = skin
		ends = Vector2(float(p.nose), float(p.end)) * size.z
		for point: Array in p.outline:
			points.append([float(point[0]), float(point[1]) * size.z])
		span = 0.0
		for point: Array in points:
			span = maxf(span, float(point[1]))
		# Hermite slopes: smooth (and not overshooting) but at a pointed tip,
		# where each side keeps its own edge's slope.
		var tip: int = p.tip
		for i in points.size():
			var before := _secant(i - 1)
			var after := _secant(i)
			var slope := 0.0
			if i == 0:
				slope = after
			elif i == points.size() - 1:
				slope = before
			elif signf(before) != signf(after) or before == 0.0 or after == 0.0:
				slope = 0.0
			else:
				slope = (before + after) / 2.0
				slope = signf(slope) * minf(absf(slope), 3.0 * minf(absf(before), absf(after)))
			if i == tip:
				slopes.append([before * 0.9, after * 0.9])
			else:
				slopes.append([slope, slope])

	func _secant(i: int) -> float:
		if i < 0 or i >= points.size() - 1:
			return 0.0
		var a: Array = points[i]
		var b: Array = points[i + 1]
		return (float(b[1]) - float(a[1])) / (float(b[0]) - float(a[0]))

	func length() -> float:
		return ends.y - ends.x

	func along_at(z: float) -> float:
		return clampf(inverse_lerp(ends.x, ends.y, z), 0.0, 1.0)

	## How far out (m) the rim is `along` the disc.
	func edge(along: float) -> float:
		along = clampf(along, 0.0, 1.0)
		for i in points.size() - 1:
			var a: Array = points[i]
			var b: Array = points[i + 1]
			if along > float(b[0]) and i < points.size() - 2:
				continue
			var span_t := float(b[0]) - float(a[0])
			var t := (along - float(a[0])) / span_t
			var t2 := t * t
			var t3 := t2 * t
			var m0: float = slopes[i][1]
			var m1: float = slopes[i + 1][0]
			return maxf((2.0 * t3 - 3.0 * t2 + 1.0) * float(a[1]) + (t3 - 2.0 * t2 + t) * span_t * m0
					+ (-2.0 * t3 + 3.0 * t2) * float(b[1]) + (t3 - t2) * span_t * m1, 0.0)
		return 0.0

	## The z of the wingtips.
	func tip_z() -> float:
		var best := 0.0
		var at := 0.0
		for i in 101:
			var e := edge(i / 100.0)
			if e > best:
				best = e
				at = i / 100.0
		return lerpf(ends.x, ends.y, at)

	func _bump(x: float, z: float, wide: float, long: float, centre_z: float) -> float:
		if wide <= 0.0 or long <= 0.0:
			return 0.0
		return exp(-pow(x / wide, 2.0) - pow((z - centre_z) / long, 2.0))

	## How far the top (or the belly) is from the middle at (x, z), before the
	## rim rounds it off: a dome over the body falling away into thin wings,
	## the head and eye mounds on it, and the round tail stalk at the back.
	func thickness(x: float, z: float, top: bool) -> float:
		var h := size.y
		var l := size.z
		var dome: Array = p.dome
		var wing: Array = p.wing_root
		var head: Array = p.head
		var snout: Array = p.snout
		var brow: Array = p.brow
		var t := 0.005
		var body := _bump(x, z, l * float(dome[2]), l * float(dome[3]), l * float(dome[4]))
		t += h * float(dome[0] if top else dome[1]) * body
		var root := exp(-pow(x / (l * float(wing[2])), 2.0)) * smoothstep(ends.x, ends.x + length() * 0.25, z) \
				* (1.0 - smoothstep(ends.y - length() * 0.4, ends.y, z))
		t += h * float(wing[0] if top else wing[1]) * root
		var on_head := _bump(x, z, l * float(head[1]), l * float(head[2]), l * float(head[3]))
		t += h * float(head[0]) * on_head * (1.0 if top else 0.6)
		t += h * float(snout[0]) * _bump(x, z, l * float(snout[1]), l * float(snout[2]), ends.x + l * float(snout[2]))
		if top and float(brow[0]) > 0.0:
			for side: float in [-1.0, 1.0]:
				t += h * float(brow[0]) * _bump(x - side * l * float(brow[1]), z, l * 0.032, l * 0.04, l * float(brow[2]))
		# The stalk: round, about the tail root's size, from the back of the dome.
		var stalk: float = p.stalk
		var back := smoothstep(ends.y - length() * 0.22, ends.y - length() * 0.08, z)
		t = maxf(t, stalk * back * exp(-pow(x / (stalk * 1.6), 2.0)) * (1.0 if top else 0.95))
		return t

	## Rounds off the nose and the stalk's end (0 at the very ends).
	func cap(along: float) -> float:
		var front: float = p.front_cap
		var back: float = p.back_cap
		var c := 1.0
		if along < front:
			var u := 1.0 - along / front
			c = sqrt(maxf(1.0 - u * u, 0.0))
		elif along > 1.0 - back:
			var u := 1.0 - (1.0 - along) / back
			c = sqrt(maxf(1.0 - u * u, 0.0))
		return c

	## How high the top is at (x, z), rim and all.
	func top(x: float, z: float) -> float:
		var along := along_at(z)
		var e := edge(along)
		var across := clampf(x / maxf(e, 0.001), -1.0, 1.0)
		return thickness(x, z, true) * sqrt(1.0 - across * across) * cap(along)

	## The middle of the stalk at the back (y): halfway between top and belly.
	func stalk_y() -> float:
		var z := ends.y - float(p.stalk) * 1.6
		var along := along_at(z)
		return (thickness(0.0, z, true) - thickness(0.0, z, false)) * 0.5 * cap(along)

	## The disc as one closed surface: rings of vertices round it from nose to
	## tail, bunched toward the rim. UV = (along, 1 on the back / 0 the belly),
	## UV2.x = how far out toward the rim (0 middle, 1 rim).
	func mesh() -> ArrayMesh:
		var rows := 104
		var around := 72
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in rows + 1:
			# Rows bunched a little toward both ends, where the shape turns fastest.
			var u := float(i) / rows
			var along := u - 0.035 * sin(TAU * u)
			var z := lerpf(ends.x, ends.y, along)
			var e := edge(along)
			var c := cap(along)
			for k in around:
				var angle := TAU * k / around
				var across := cos(angle)
				var x := e * across
				var up := sin(angle)
				var y := thickness(x, z, up >= 0.0) * up * c
				tool.set_uv(Vector2(along, clampf(0.5 + up * 3.0, 0.0, 1.0)))
				tool.set_uv2(Vector2(absf(across), 0.0))
				tool.add_vertex(Vector3(x, y, z))
		for i in rows:
			for k in around:
				var a := i * around + k
				var b := i * around + (k + 1) % around
				var cc := a + around
				var d := b + around
				for corner: int in [a, cc, b, b, cc, d]:
					tool.add_index(corner)
		tool.generate_normals()
		return tool.commit()
