class_name SeaHareModel
extends RefCounted
## The Alchemists' sea hare (FishModel.build hands it here): species m.species of
## FishCharacter.SPECIES[FishCharacter.FishClass.ALCHEMIST] (LOOKS, in that order).
##
## A soft slug body (_profile, lofted) swelling from a small head and neck to a
## big hump, tapering to a pointed tail foot (on the tail pivot, so it wags a
## little). Two wavy parapodia (the "wings") rise from its sides and fold up
## over its back; they sit on the swim animation's fin pivots, so the flap gait
## beats them (Gait.Visual.FLAP). On the head: the two rolled, ear-like
## rhinophores (why it's a "hare"), small dark eyes in front of them, and two
## flat oral tentacles curling out at the front. The Ragged Sea Hare is covered
## in little branching hairs. The skin is sea_hare_skin.gdshader.

const SKIN := preload("res://shaders/sea_hare_skin.gdshader")

## The body from its head (0) to its tail tip (1), evenly spaced: half width
## (of the widest), half height (of the tallest) and its middle's height (of
## the hitbox's half height).
const WIDE := [0.12, 0.42, 0.46, 0.44, 0.58, 0.82, 0.97, 1.0, 0.92, 0.7, 0.42, 0.18, 0.02]
const TALL := [0.12, 0.4, 0.42, 0.4, 0.55, 0.8, 0.95, 1.0, 0.9, 0.66, 0.38, 0.17, 0.02]
const MIDDLE := [-0.15, -0.1, -0.08, -0.1, -0.08, -0.02, 0.02, 0.02, -0.04, -0.14, -0.26, -0.36, -0.42]
## Where the tail foot (on the tail pivot) takes over, along the body.
const TAIL_FROM := 0.78

## Each species: the skin's colours and pattern (sea_hare_skin.gdshader), the
## parapodia's root and edge, the rhinophores' and tentacles' colour, and
## whether it's hairy (the Ragged).
const LOOKS := [
	{  # California Sea Hare (Aplysia californica): mottled reds, browns and greens, purple-edged wings.
		"albedo": Color("7a3a2e"), "second": Color("4e5a2a"), "third": Color("d8c8a8"), "belly": Color("8a5a4a"),
		"pattern": 0, "seed": 3.0, "wing": Color("6e3a34"), "wing_edge": Color("5a2a6a"), "horn": Color("6a3a30"), "hairy": false,
	},
	{  # Spotted Sea Hare (Aplysia dactylomela): pale olive-tan with dark rings.
		"albedo": Color("b8a878"), "second": Color("3a2e22"), "third": Color("e0d8b8"), "belly": Color("c8bc98"),
		"pattern": 1, "seed": 7.0, "wing": Color("b0a070"), "wing_edge": Color("4a3a2a"), "horn": Color("9a8a60"), "hairy": false,
	},
	{  # Ragged Sea Hare (Bursatella leachii): brownish, fuzzy, with bright blue spots.
		"albedo": Color("6a5a40"), "second": Color("8a7a58"), "third": Color("2a8aff"), "belly": Color("8a7a60"),
		"pattern": 2, "seed": 11.0, "wing": Color("6a5a40"), "wing_edge": Color("8a7a58"), "horn": Color("7a6a4a"), "hairy": true,
	},
]


static func build(m: FishModel) -> void:
	var look: Dictionary = LOOKS[clampi(m.species, 0, LOOKS.size() - 1)]
	var w := m._size.x
	var h := m._size.y
	var l := m._size.z
	var semi := Vector2(w * 0.4, h * 0.5)
	var ends := Vector2(-l * 0.5, l * 0.5)
	var profile := func(t: float) -> Vector3:
		return Vector3(FishModel._sample(WIDE, t) * semi.x, FishModel._sample(TALL, t) * semi.y, FishModel._sample(MIDDLE, t) * h * 0.5)

	var albedo: Color = look.albedo
	m._body_material = m._material(albedo)  # for set_body_color(); the skin does the shading
	var skin := ShaderMaterial.new()
	skin.shader = SKIN
	skin.set_shader_parameter("albedo", albedo)
	skin.set_shader_parameter("second_color", look.second)
	skin.set_shader_parameter("third_color", look.third)
	skin.set_shader_parameter("belly_color", look.belly)
	skin.set_shader_parameter("pattern", look.pattern)
	skin.set_shader_parameter("seed", look.seed)
	m._skins.append(skin)

	# The body, head to the tail foot's root (a little past it, under the foot).
	var split := lerpf(ends.x, ends.y, TAIL_FROM)
	var front := func(t: float) -> Vector3:
		var slice: Vector3 = profile.call(t * (TAIL_FROM + 0.04))
		if t < 0.06:  # round the head off
			var k := sqrt(t / 0.06)
			slice.x *= k
			slice.y *= k
		return slice
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _open_loft(Vector2(ends.x, lerpf(ends.x, ends.y, TAIL_FROM + 0.04)), front, 56, 32)
	body.material_override = skin
	m.add_child(body)

	# The tail foot on the tail pivot: the rest of the body to its point.
	m._tail_pivot(Vector3(0.0, FishModel._sample(MIDDLE, TAIL_FROM) * h * 0.5, split))
	var foot_from := split - l * 0.03
	var foot := MeshInstance3D.new()
	foot.name = "TailFoot"
	foot.mesh = m._loft_mesh(Vector2(foot_from - split, ends.y - split), func(t: float) -> Vector3:
		var along := lerpf(inverse_lerp(ends.x, ends.y, foot_from), 1.0, t)
		var slice: Vector3 = profile.call(along)
		slice.z -= m.tail.position.y
		if t < 0.02:
			slice.x *= 0.98
		return slice, 24, 24)
	foot.material_override = skin
	m.tail.add_child(foot)

	# The parapodia: a wavy wing up each side of the hump, folding in over the back.
	var hump_t := 0.55
	var hump: Vector3 = profile.call(hump_t)
	var hump_z := lerpf(ends.x, ends.y, hump_t)
	m._fin_pivots(Vector3(hump.x * 0.9, hump.z + hump.y * 0.25, hump_z))
	var wing_material := m._fin_material(look.wing, look.wing_edge, 5.0, 0.03, 0.6, 0.95)
	wing_material.set_shader_parameter("ray_color", (look.wing as Color).darkened(0.08))
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		var span := l * 0.2
		m._membrane(pivot, wing_material, Vector3(-side * w * 0.03, -h * 0.06, -span * 1.25), Vector3(-side * w * 0.03, -h * 0.08, span),
				Vector3(side * 0.55, 1.0, 0.0), [h * 0.06, h * 0.26, h * 0.36, h * 0.38, h * 0.3, h * 0.1], 0.0, 0.06, 0.3)

	# The head: rhinophores (rolled ears) on top, eyes before them, oral
	# tentacles curling out at the front.
	var horn_material := m._material(look.horn, 0.5)
	var head_t := 0.12
	var head: Vector3 = profile.call(head_t)
	var head_z := lerpf(ends.x, ends.y, head_t)
	for side: float in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		ear.name = "Rhinophore"
		ear.mesh = m._tube_mesh(h * 0.3, l * 0.042, -0.7)
		ear.material_override = horn_material
		ear.position = Vector3(side * head.x * 0.45, head.z + head.y * 0.7, head_z + l * 0.02)
		ear.basis = Basis.looking_at(-Vector3(side * 0.35, 1.0, 0.35).normalized()) * Basis.from_scale(Vector3(1.0, 0.6, 1.0))
		m.add_child(ear)
		var eye := MeshInstance3D.new()
		eye.name = "Eye"
		var ball := SphereMesh.new()
		ball.radius = l * 0.012
		ball.height = l * 0.024
		ball.radial_segments = 10
		ball.rings = 5
		eye.mesh = ball
		eye.material_override = m._material(Color(0.04, 0.03, 0.03), 0.2)
		eye.position = Vector3(side * head.x * 0.62, head.z + head.y * 0.62, head_z - l * 0.03)
		m.add_child(eye)
		var tentacle := MeshInstance3D.new()
		tentacle.name = "OralTentacle"
		tentacle.mesh = m._tube_mesh(l * 0.1, l * 0.04, 0.9)
		tentacle.material_override = horn_material
		tentacle.position = Vector3(side * head.x * 0.45, head.z - head.y * 0.25, ends.x + l * 0.06)
		tentacle.basis = Basis.looking_at(-Vector3(side * 0.9, -0.3, -1.0).normalized()) * Basis.from_scale(Vector3(1.7, 0.4, 1.0))
		m.add_child(tentacle)

	if look.hairy:
		_hairs(m, profile, ends, look)


## The Ragged Sea Hare's fuzz: little branching hairs all over its top half,
## one merged mesh.
static func _hairs(m: FishModel, profile: Callable, ends: Vector2, look: Dictionary) -> void:
	var l := m._size.z
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var hair := m._tube_mesh(l * 0.035, l * 0.005, 0.8)
	var twig := m._tube_mesh(l * 0.018, l * 0.0035, -0.6)
	var parts: Array = []
	for n in 220:
		var t := rng.randf_range(0.08, 0.92)
		var angle := rng.randf_range(-1.9, 1.9)  # round the top, not the sole
		var slice: Vector3 = profile.call(t)
		var normal := Vector3(sin(angle) / maxf(slice.x, 0.01), cos(angle) / maxf(slice.y, 0.01), 0.0).normalized()
		var at := Vector3(sin(angle) * slice.x, slice.z + cos(angle) * slice.y, lerpf(ends.x, ends.y, t)) - normal * l * 0.004
		var turn := Basis.looking_at(-(normal + Vector3(0.0, 0.0, 0.4)).normalized())
		turn = turn.rotated(normal, rng.randf() * TAU)
		parts.append([hair, Transform3D(turn, at)])
		parts.append([twig, Transform3D(turn.rotated(normal, PI * 0.5) * Basis(Vector3.RIGHT, 0.7), at + turn * Vector3(0.0, 0.0, l * 0.02))])
	var mesh := ArrayMesh.new()
	FxKit.merge_into(mesh, parts, m._material((look.second as Color).lightened(0.1), 0.8))
	var fuzz := MeshInstance3D.new()
	fuzz.name = "Fuzz"
	fuzz.mesh = mesh
	fuzz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(fuzz)


## A lofted body like FishModel._loft_mesh but open at its back end (the tail
## foot carries on from there).
static func _open_loft(ends: Vector2, profile: Callable, rows: int, around: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows + 1:
		var along := float(i) / rows
		var z := lerpf(ends.x, ends.y, along)
		var slice: Vector3 = profile.call(along)
		for k in around:
			var angle := TAU * k / around
			tool.set_uv(Vector2(along, float(k) / around))
			tool.add_vertex(Vector3(sin(angle) * slice.x, slice.z + cos(angle) * slice.y, z))
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, b, a + around, b, b + around, a + around]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()
