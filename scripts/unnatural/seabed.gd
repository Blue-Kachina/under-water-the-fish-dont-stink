class_name Seabed
extends Node3D
## Unnatural's arena floor (planning_unnatural.md §1): sand out past the
## arena's edge, scattered rocks and swaying kelp (one MultiMesh each), so
## there's a sense of place and somewhere to bury chests. Built from a seed:
## every machine in co-op lays out the same seabed.
##
## The arena's edge is marked so it reads from far off: a ring of tall rock
## outcrops and a thick band of tall kelp on `radius`, and a faint red wall of
## light rising from it (round 2).

const KELP_SHADER := preload("res://shaders/kelp.gdshader")
const KELP_HEIGHT := 6.0

var radius := 150.0
var rocks := 260
var kelp := 600
## The edge: how many outcrops and kelp blades, and how tall (m).
var edge_rocks := 90
var edge_kelp := 900
var edge_height := 40.0
var rng := RandomNumberGenerator.new()
var _glow := ShaderMaterial.new()


## The seabed `arena_radius` round, its top at this node's height.
func setup(arena_radius: float, rock_count: int, kelp_count: int, rng_seed := 11, edge_rock_count := 90,
		edge_kelp_count := 900, edge_tall := 40.0) -> void:
	radius = arena_radius
	rocks = rock_count
	kelp = kelp_count
	edge_rocks = edge_rock_count
	edge_kelp = edge_kelp_count
	edge_height = edge_tall
	rng.seed = rng_seed
	for child in get_children():
		child.queue_free()
	_build_sand()
	_build_rocks()
	_build_kelp()
	_build_edge()


func _build_sand() -> void:
	var sand := MeshInstance3D.new()
	sand.name = "Sand"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.6
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.3, 0.24)
	material.roughness = 1.0
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 256
	texture.height = 256
	material.albedo_texture = texture
	material.uv1_scale = Vector3.ONE * radius * 0.12
	plane.material = material
	sand.mesh = plane
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sand)


func _build_rocks() -> void:
	if rocks <= 0:
		return
	var mesh := SphereMesh.new()
	mesh.radial_segments = 9
	mesh.rings = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.22, 0.24)
	material.roughness = 0.95
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = rocks
	for i in rocks:
		var at := _point()
		var size := rng.randf_range(0.5, 3.5) * (3.0 if rng.randf() < 0.06 else 1.0)
		var scale := Vector3(size * rng.randf_range(0.8, 1.6), size * rng.randf_range(0.35, 0.8), size * rng.randf_range(0.8, 1.6))
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(scale)
		multimesh.set_instance_transform(i, Transform3D(basis, Vector3(at.x, 0.0, at.y)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Rocks"
	instance.multimesh = multimesh
	add_child(instance)


func _build_kelp() -> void:
	if kelp <= 0:
		return
	var blade := BoxMesh.new()
	blade.size = Vector3(0.35, KELP_HEIGHT, 0.04)
	blade.subdivide_height = 6
	var material := ShaderMaterial.new()
	material.shader = KELP_SHADER
	material.set_shader_parameter("height", KELP_HEIGHT)
	blade.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade
	multimesh.instance_count = kelp
	# In clumps, as kelp grows.
	var clump := Vector2.ZERO
	for i in kelp:
		if i % 7 == 0:
			clump = _point()
		var at := clump + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
		var tall := rng.randf_range(0.5, 1.6)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
		basis = basis.scaled(Vector3(1.0, tall, 1.0))
		multimesh.set_instance_transform(i, Transform3D(basis, Vector3(at.x, KELP_HEIGHT * 0.5 * tall, at.y)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Kelp"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## The edge's outcrops (piles of tall rocks), its kelp band, and its wall of light.
func _build_edge() -> void:
	if edge_rocks > 0:
		var mesh := SphereMesh.new()
		mesh.radial_segments = 10
		mesh.rings = 6
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.2, 0.19, 0.2)
		stone.roughness = 0.95
		mesh.material = stone
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = edge_rocks * 3
		for i in edge_rocks:
			var angle := (float(i) + rng.randf_range(-0.3, 0.3)) / edge_rocks * TAU
			var out := radius * rng.randf_range(1.0, 1.08)
			var base := Vector2.from_angle(angle) * out
			# Each outcrop: a big base, a tall spire, and a cap leaning off it.
			var tall := edge_height * rng.randf_range(0.35, 0.9)
			var width := rng.randf_range(4.0, 8.0)
			var parts := [
				[Vector3(width * 1.3, width * 0.6, width * 1.2), 0.0],
				[Vector3(width * 0.7, tall * 0.5, width * 0.7), tall * 0.35],
				[Vector3(width * 0.5, width * 0.6, width * 0.5), tall * 0.75],
			]
			for n in 3:
				var size: Vector3 = parts[n][0]
				var lean := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
				var at := Vector3(base.x + rng.randf_range(-1.5, 1.5), parts[n][1], base.y + rng.randf_range(-1.5, 1.5))
				multimesh.set_instance_transform(i * 3 + n, Transform3D(lean.scaled(size), at))
		var instance := MultiMeshInstance3D.new()
		instance.name = "EdgeRocks"
		instance.multimesh = multimesh
		add_child(instance)
	if edge_kelp > 0:
		var blade := BoxMesh.new()
		blade.size = Vector3(0.45, KELP_HEIGHT, 0.05)
		blade.subdivide_height = 8
		var material := ShaderMaterial.new()
		material.shader = KELP_SHADER
		material.set_shader_parameter("height", KELP_HEIGHT)
		blade.material = material
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = blade
		multimesh.instance_count = edge_kelp
		var most := maxf(edge_height * 0.6 / KELP_HEIGHT, 1.0)
		for i in edge_kelp:
			var at := Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.95, 1.06)
			var tall := rng.randf_range(most * 0.4, most)
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.1, 0.1))
			basis = basis.scaled(Vector3(1.0, tall, 1.0))
			multimesh.set_instance_transform(i, Transform3D(basis, Vector3(at.x, KELP_HEIGHT * 0.5 * tall, at.y)))
		var instance := MultiMeshInstance3D.new()
		instance.name = "EdgeKelp"
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	var wall := MeshInstance3D.new()
	wall.name = "EdgeGlow"
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = edge_height
	tube.radial_segments = 96
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	var glow := _glow
	glow.shader = _edge_shader()
	glow.set_shader_parameter("tall", edge_height)
	tube.material = glow
	wall.mesh = tube
	wall.position.y = edge_height * 0.5
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)


## The murk's density (0: none): the edge's glow fades with distance as the
## fog would (it's additive and fog-free, so the fog can't do it).
func set_murk(density: float) -> void:
	_glow.set_shader_parameter("murk", density)


## The edge's wall of light: red, brightest at the seabed and fading upward,
## both sides showing, breathing slowly, and fading into the murk.
static func _edge_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float tall = 40.0;
uniform float murk = 0.0;
varying float rise;
void vertex() {
	rise = clamp(VERTEX.y / tall + 0.5, 0.0, 1.0);  // 0 at the seabed, 1 at the top
}
void fragment() {
	float breathe = 0.8 + 0.2 * sin(TIME * 1.3 + UV.x * 40.0);
	float glow = pow(1.0 - rise, 2.0) * 0.6 * breathe;
	glow *= exp(-length(VERTEX) * murk);  // VERTEX is in view space here
	ALBEDO = vec3(1.0, 0.12, 0.08) * glow;
	ALPHA = glow;
}
"""
	return shader


## A random point on the floor (x, z), out a little past the arena's edge.
func _point() -> Vector2:
	return Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius * 1.1
