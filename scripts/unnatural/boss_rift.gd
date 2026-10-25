class_name BossRift
extends Node3D
## The boss rift: a random spot on each stage's seabed where Greek rubble has
## half fallen over a narrow crevice, just big enough for a fish. From close up
## it goes down much further than it should, lit an eerie red from far below,
## with red fog drifting up out of it. It's on every player's minimap and
## compass from the start (a big red skull). Swim down into it
## (UnnaturalRun._try_rift) and the crevice spits you back out into the arena
## and the stage's final boss rises out of it, early. Once the final boss has
## come (woken or on time) it goes cold. UnnaturalRun keeps its state; this
## draws it.
##
## The seabed can't have a real hole, so the mouth is a plate over the sand
## whose shader (rift_mouth.gdshader) paints the slot going down beneath it.

## The opening's half length (x) and half width (z), m.
const MOUTH := Vector2(2.3, 0.85)
## How deep the painted slot goes (m).
const DEPTH := 18.0
const GLOW := Color(1.0, 0.12, 0.05)
const LIGHT_RANGE := 8.0
const LIGHT_ENERGY := 2.4

## Used up: the final boss has come.
var spent := false
## Woken by a player going in (the boss rises out of it).
var woken := false
## The light's strength (UnnaturalSettings.rift_glow).
var glow := 1.0

static var _mouth_mesh: ArrayMesh
static var _lip_mesh: ArrayMesh
static var _rubble_mesh: ArrayMesh
static var _fog_mesh: QuadMesh
static var _shader: Shader

var _mouth := MeshInstance3D.new()
var _mouth_material := ShaderMaterial.new()
var _light := OmniLight3D.new()
var _fog := CPUParticles3D.new()
var _burst := CPUParticles3D.new()
var _age := 0.0
var _flare := 0.0
var _cold := 0.0


func _ready() -> void:
	if _shader == null:
		_shader = preload("res://shaders/rift_mouth.gdshader")
	_mouth_material.shader = _shader
	_mouth_material.set_shader_parameter("half_size", MOUTH)
	_mouth_material.set_shader_parameter("depth", DEPTH)
	_mouth_material.set_shader_parameter("glow_color", Vector3(GLOW.r, GLOW.g, GLOW.b))
	_mouth.name = "Mouth"
	_mouth.mesh = mouth_mesh()
	_mouth.material_override = _mouth_material
	_mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mouth)
	var lip := MeshInstance3D.new()
	lip.name = "Lip"
	lip.mesh = lip_mesh()
	add_child(lip)
	var rubble := MeshInstance3D.new()
	rubble.name = "Rubble"
	rubble.mesh = rubble_mesh()
	add_child(rubble)
	_light.name = "Glow"
	_light.light_color = GLOW
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 1.6
	_light.position = Vector3(0.0, 0.35, 0.0)
	add_child(_light)
	# Red fog seeping up out of the crack.
	_fog.name = "Fog"
	_fog.mesh = fog_mesh()
	_fog.amount = 18
	_fog.lifetime = 7.0
	_fog.preprocess = 7.0
	_fog.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fog.emission_box_extents = Vector3(MOUTH.x * 0.8, 0.1, MOUTH.y * 0.6)
	_fog.direction = Vector3.UP
	_fog.spread = 25.0
	_fog.initial_velocity_min = 0.25
	_fog.initial_velocity_max = 0.6
	_fog.gravity = Vector3(0.0, 0.05, 0.0)
	_fog.damping_min = 0.05
	_fog.damping_max = 0.1
	_fog.scale_amount_min = 0.8
	_fog.scale_amount_max = 1.6
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.6))
	_fog.scale_amount_curve = grow
	_fog.color_ramp = _ramp([[0.0, Color(0.9, 0.12, 0.06, 0.0)], [0.2, Color(0.85, 0.1, 0.06, 0.3)],
			[0.7, Color(0.5, 0.05, 0.04, 0.16)], [1.0, Color(0.25, 0.03, 0.03, 0.0)]])
	_fog.position.y = 0.2
	_fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fog)
	# The eruption when it's woken: a gout of red fog up the water.
	_burst.name = "Burst"
	_burst.mesh = fog_mesh()
	_burst.one_shot = true
	_burst.emitting = false
	_burst.explosiveness = 0.85
	_burst.amount = 40
	_burst.lifetime = 3.0
	_burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_burst.emission_box_extents = Vector3(MOUTH.x * 0.7, 0.2, MOUTH.y * 0.5)
	_burst.direction = Vector3.UP
	_burst.spread = 30.0
	_burst.initial_velocity_min = 6.0
	_burst.initial_velocity_max = 14.0
	_burst.damping_min = 3.0
	_burst.damping_max = 5.0
	_burst.scale_amount_min = 1.2
	_burst.scale_amount_max = 2.6
	_burst.scale_amount_curve = grow
	_burst.color_ramp = _ramp([[0.0, Color(1.0, 0.25, 0.12, 0.7)], [0.3, Color(0.7, 0.06, 0.04, 0.45)], [1.0, Color(0.2, 0.02, 0.02, 0.0)]])
	_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_burst)


func _process(delta: float) -> void:
	_age += delta
	_flare = move_toward(_flare, 0.0, delta * 0.6)
	_cold = move_toward(_cold, 1.0 if spent else 0.0, delta * 0.25)
	var pulse := 0.5 + 0.5 * sin(_age * 1.3) * sin(_age * 0.37 + 1.0)
	_light.light_energy = LIGHT_ENERGY * glow * (0.75 + 0.45 * pulse) * (1.0 - 0.85 * _cold) + 8.0 * _flare
	_light.omni_range = LIGHT_RANGE * (1.0 + _flare)
	_fog.emitting = _cold < 0.5
	_mouth_material.set_shader_parameter("flare", _flare)
	_mouth_material.set_shader_parameter("spent", _cold)
	_mouth_material.set_shader_parameter("glow_energy", 4.0 * glow * (0.85 + 0.3 * pulse))


## It spits a fish back out: a flare and a gout of red fog.
func erupt() -> void:
	_flare = 1.0
	_burst.restart()


## Whether `point` has gone down into it: over the mouth (with `pad` m to
## spare round it) and within `height` m of the sand.
func is_inside(point: Vector3, pad: float, height: float) -> bool:
	var local := to_local(point)
	if local.y > height:
		return false
	var x := local.x / (MOUTH.x + pad)
	var z := local.z / (MOUTH.y + pad)
	return x * x + z * z <= 1.0


## How far `point` is from the mouth along the sand (m).
func distance_to(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


static func _ramp(stops: Array) -> Gradient:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop: Array in stops:
		offsets.append(stop[0])
		colors.append(stop[1])
	var ramp := Gradient.new()
	ramp.offsets = offsets
	ramp.colors = colors
	return ramp


## The opening's shape round the way (a rounded slit, its edge ragged):
## its radius scale at `angle`, 1 on the slot's walls.
static func _outline(angle: float, noise: FastNoiseLite) -> float:
	return GreekKit.squarish(angle, 3.0) * (0.92 + 0.08 * noise.get_noise_2d(cos(angle) * 2.0, sin(angle) * 2.0))


static func _noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = 6611
	noise.frequency = 0.9
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return noise


## The plate over the hole (the shader paints the slot under it).
static func mouth_mesh() -> ArrayMesh:
	if _mouth_mesh:
		return _mouth_mesh
	var noise := _noise()
	var verts := PackedVector3Array([Vector3(0.0, 0.04, 0.0)])
	var sides := 64
	for n in sides:
		var angle := TAU * n / sides
		var r := _outline(angle, noise) * 0.97
		verts.append(Vector3(cos(angle) * MOUTH.x * r, 0.04, sin(angle) * MOUTH.y * r))
	var indices := PackedInt32Array()
	for n in sides:
		indices.append_array([0, 1 + (n + 1) % sides, 1 + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	_mouth_mesh = ArrayMesh.new()
	_mouth_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _mouth_mesh


## The broken rock lip round the opening: from the sand outside up over a
## ragged crest and down under the mouth's edge.
static func lip_mesh() -> ArrayMesh:
	if _lip_mesh:
		return _lip_mesh
	var noise := _noise()
	var bumps := FastNoiseLite.new()
	bumps.seed = 6612
	bumps.frequency = 1.6
	var kit := MeshKit.new()
	kit.set_random(0.4)
	# [distance out past the edge (m), height (m), cavity], from outside in.
	var profile := [[1.7, -0.25, 0.0], [1.1, 0.05, 0.1], [0.55, 0.32, 0.2], [0.2, 0.42, 0.3], [-0.05, 0.25, 0.6], [-0.2, -0.3, 1.0]]
	kit.surface(96, profile.size() - 1, func(u: float, v: float) -> Array:
		var angle := u * TAU
		var row := clampi(roundi(v * (profile.size() - 1)), 0, profile.size() - 1)
		var step: Array = profile[row]
		var r := _outline(angle, noise)
		var edge := Vector3(cos(angle) * MOUTH.x * r, 0.0, sin(angle) * MOUTH.y * r)
		var out := Vector3(cos(angle) * MOUTH.y, 0.0, sin(angle) * MOUTH.x).normalized()  # roughly across the edge
		var p := edge + out * float(step[0])
		var rough := bumps.get_noise_2d(p.x * 1.3, p.z * 1.3)
		p.y = float(step[1]) * (0.7 + 0.6 * (rough * 0.5 + 0.5)) if row > 0 else float(step[1])
		p += out * rough * 0.15
		return [p, float(step[2]), clampf(rough, 0.0, 1.0) * 0.5], true)
	_lip_mesh = kit.mesh(true, GreekKit.rock())
	return _lip_mesh


## The marble that's fallen over it: a cracked slab tipped across one end, a
## fallen column across the other, and blocks, a capital and a pot about it,
## leaving the middle open (a fish's width).
static func rubble_mesh() -> ArrayMesh:
	if _rubble_mesh:
		return _rubble_mesh
	var kit := MeshKit.new()
	var s := 7300
	# The slab: a big lintel, its near end on the lip, its far end sunk in the sand.
	kit.merge(GreekKit.block(Vector3(2.4, 0.42, 2.1), s + 1, true),
			Transform3D(Basis(Vector3.UP, 0.25) * Basis(Vector3.BACK, 0.16), Vector3(1.55, 0.05, 0.1)))
	kit.merge(GreekKit.block(Vector3(0.9, 0.35, 0.8), s + 2), Transform3D(Basis(Vector3.UP, 0.9) * Basis(Vector3.RIGHT, 0.25), Vector3(2.9, -0.05, -1.3)))
	# The fallen column across the other end, its drums tumbled off one side.
	kit.merge(GreekKit.fallen_column(3, s + 3), Transform3D(Basis(Vector3.UP, -(PI * 0.5 + 0.35)), Vector3(-1.45, 0.3, -1.6)))
	kit.merge(GreekKit.drum(0.8, GreekKit.COLUMN_RADIUS, true, s + 4),
			Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.UP, 0.4), Vector3(-2.6, GreekKit.COLUMN_RADIUS * 0.8, 0.9)))
	kit.merge(GreekKit.capital(GreekKit.COLUMN_RADIUS * 0.95, s + 5),
			Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.RIGHT, 2.0), Vector3(-2.2, 0.35, -0.2)))
	# Broken blocks and a pot round about.
	var dice := RandomNumberGenerator.new()
	dice.seed = s
	for n in 6:
		var angle := dice.randf() * TAU
		var at := Vector3(cos(angle) * (MOUTH.x + dice.randf_range(1.2, 3.2)), -0.1, sin(angle) * (MOUTH.y + dice.randf_range(1.2, 2.8)))
		var size := Vector3(dice.randf_range(0.35, 0.9), dice.randf_range(0.2, 0.45), dice.randf_range(0.3, 0.7))
		kit.merge(GreekKit.block(size, s + 10 + n), Transform3D(Basis(Vector3.UP, dice.randf() * TAU) * Basis(Vector3.RIGHT, dice.randf_range(-0.3, 0.3)), at))
	kit.merge(GreekKit.amphora(false, true, s + 20), Transform3D(Basis(Vector3.FORWARD, 1.45) * Basis(Vector3.UP, 1.1), Vector3(0.6, 0.18, 2.0)))
	_rubble_mesh = kit.mesh(true, GreekKit.marble())
	return _rubble_mesh


## A soft puff of fog (see-through, not added on: it reads as murk, not light).
static func fog_mesh() -> QuadMesh:
	if _fog_mesh:
		return _fog_mesh
	_fog_mesh = QuadMesh.new()
	_fog_mesh.size = Vector2(1.6, 1.6)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = FxKit.dot()
	FxKit.fade_near(material)
	_fog_mesh.material = material
	return _fog_mesh
