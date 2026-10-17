class_name Seabed
extends Node3D
## Unnatural's arena floor (planning_unnatural.md §1): sand out past the
## arena's edge, scattered rocks and swaying kelp (one MultiMesh each), so
## there's a sense of place and somewhere to bury chests. Built from a seed:
## every machine in co-op lays out the same seabed.

const KELP_SHADER := preload("res://shaders/kelp.gdshader")
const KELP_HEIGHT := 6.0

var radius := 150.0
var rocks := 260
var kelp := 600
var rng := RandomNumberGenerator.new()


## The seabed `arena_radius` round, its top at this node's height.
func setup(arena_radius: float, rock_count: int, kelp_count: int, rng_seed := 11) -> void:
	radius = arena_radius
	rocks = rock_count
	kelp = kelp_count
	rng.seed = rng_seed
	for child in get_children():
		child.queue_free()
	_build_sand()
	_build_rocks()
	_build_kelp()


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


## A random point on the floor (x, z), out a little past the arena's edge.
func _point() -> Vector2:
	return Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius * 1.1
