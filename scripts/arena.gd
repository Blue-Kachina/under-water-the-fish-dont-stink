class_name Arena
extends Node3D
## Builds the movement test arena in code: a walled water volume, obstacles,
## floating specks for motion reference, and a timed hoop course.

signal course_finished(time: float, is_best: bool)

const SIZE := Vector3(160.0, 70.0, 160.0)  # floor at y = 0, centred on x/z
const GRID_SHADER := preload("res://shaders/grid.gdshader")

const COLOR_ROCK := Color(0.32, 0.3, 0.28)
const COLOR_WALL := Color(0.14, 0.28, 0.33)
const COLOR_SAND := Color(0.45, 0.4, 0.3)
const COLOR_REEF := Color(0.55, 0.25, 0.35)

## Hoop centres in course order. Hoops 3 -> 4 run through the tunnel.
const COURSE := [
	Vector3(0, 12, 55),
	Vector3(45, 22, 45),
	Vector3(62, 35, 0),
	Vector3(35, 20, -40),
	Vector3(-35, 20, -40),
	Vector3(-60, 45, -15),
	Vector3(-45, 10, 30),
	Vector3(-10, 55, 25),
	Vector3(20, 30, 10),
	Vector3(0, 12, 35),
]

@export var fish: Node3D

var hoops: Array[Hoop] = []
var next_hoop := 0
var running := false
var course_time := 0.0
var best_time := INF


func _ready() -> void:
	_build_bounds()
	_build_obstacles()
	_build_specks()
	_build_course()


func _process(delta: float) -> void:
	if running:
		course_time += delta


func spawn_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0, 12, 72))


func configure_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.1, 0.16)
	env.sky = null


func reset_course() -> void:
	running = false
	next_hoop = 0
	course_time = 0.0
	_refresh_hoops()


func _on_hoop_fish_entered(hoop: Hoop, body: Node3D) -> void:
	if body != fish:
		return
	if hoop.index == 0:  # the first hoop always (re)starts a run
		running = true
		course_time = 0.0
		next_hoop = 0
	elif hoop.index != next_hoop:
		return
	next_hoop += 1
	if next_hoop >= hoops.size():
		var is_best := course_time < best_time
		best_time = minf(best_time, course_time)
		running = false
		next_hoop = 0
		course_finished.emit(course_time, is_best)
	_refresh_hoops()


func _refresh_hoops() -> void:
	for hoop in hoops:
		if hoop.index < next_hoop:
			hoop.set_state(Hoop.State.PASSED)
		elif hoop.index == next_hoop:
			hoop.set_state(Hoop.State.NEXT)
		else:
			hoop.set_state(Hoop.State.IDLE)


func _build_bounds() -> void:
	var half := SIZE / 2.0
	_add_box(Vector3(0, -1, 0), Vector3(SIZE.x + 4, 2, SIZE.z + 4), COLOR_SAND)  # sea floor
	_add_box(Vector3(0, SIZE.y + 1, 0), Vector3(SIZE.x + 4, 2, SIZE.z + 4), COLOR_WALL)  # surface
	_add_box(Vector3(half.x + 1, half.y, 0), Vector3(2, SIZE.y, SIZE.z), COLOR_WALL)
	_add_box(Vector3(-half.x - 1, half.y, 0), Vector3(2, SIZE.y, SIZE.z), COLOR_WALL)
	_add_box(Vector3(0, half.y, half.z + 1), Vector3(SIZE.x, SIZE.y, 2), COLOR_WALL)
	_add_box(Vector3(0, half.y, -half.z - 1), Vector3(SIZE.x, SIZE.y, 2), COLOR_WALL)


func _build_obstacles() -> void:
	# Pillars
	_add_cylinder(Vector3(-20, 0, -5), 3.0, 50.0, COLOR_ROCK)
	_add_cylinder(Vector3(25, 0, -15), 2.5, 40.0, COLOR_ROCK)
	_add_cylinder(Vector3(-35, 0, 60), 4.0, 30.0, COLOR_ROCK)
	_add_cylinder(Vector3(60, 0, 60), 3.0, 60.0, COLOR_ROCK)
	_add_cylinder(Vector3(-65, 0, -60), 3.0, 45.0, COLOR_ROCK)

	# Boulders, including one floating mid-water
	_add_sphere(Vector3(10, 0, -10), 6.0, COLOR_ROCK)
	_add_sphere(Vector3(-25, 0, 40), 5.0, COLOR_ROCK)
	_add_sphere(Vector3(50, 0, -55), 8.0, COLOR_ROCK)
	_add_sphere(Vector3(0, 40, -10), 4.0, COLOR_REEF)

	# Square tunnel along X (inner 10 x 10)
	var tunnel_centre := Vector3(0, 20, -40)
	var length := 40.0
	_add_box(tunnel_centre + Vector3(0, 5.5, 0), Vector3(length, 1, 12), COLOR_REEF)
	_add_box(tunnel_centre + Vector3(0, -5.5, 0), Vector3(length, 1, 12), COLOR_REEF)
	_add_box(tunnel_centre + Vector3(0, 0, 5.5), Vector3(length, 10, 1), COLOR_REEF)
	_add_box(tunnel_centre + Vector3(0, 0, -5.5), Vector3(length, 10, 1), COLOR_REEF)

	# Ramps for wall play
	_add_box(Vector3(0, 6, -72), Vector3(30, 1, 20), COLOR_SAND, Vector3(deg_to_rad(-35), 0, 0))
	_add_box(Vector3(72, 6, 20), Vector3(20, 1, 30), COLOR_SAND, Vector3(0, 0, deg_to_rad(35)))

	# Half-buried reef arch
	var arch := TorusMesh.new()
	arch.inner_radius = 10.0
	arch.outer_radius = 13.0
	arch.rings = 64
	arch.ring_segments = 16
	var arch_basis := Basis(Vector3.UP, deg_to_rad(90)) * Basis(Vector3.RIGHT, PI / 2.0)
	_add_static(arch.create_trimesh_shape(), arch, Transform3D(arch_basis, Vector3(30, 0, 25)), COLOR_REEF)


func _build_specks() -> void:
	var speck := SphereMesh.new()
	speck.radius = 0.05
	speck.height = 0.1
	speck.radial_segments = 6
	speck.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.7, 0.9, 1.0)
	speck.material = material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = speck
	multimesh.instance_count = 3000
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var half := SIZE / 2.0
	for i in multimesh.instance_count:
		var pos := Vector3(rng.randf_range(-half.x, half.x), rng.randf_range(0.5, SIZE.y), rng.randf_range(-half.z, half.z))
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _build_course() -> void:
	for i in COURSE.size():
		var pos: Vector3 = COURSE[i]
		var prev: Vector3 = COURSE[maxi(i - 1, 0)]
		var next: Vector3 = COURSE[mini(i + 1, COURSE.size() - 1)]
		var direction := (next - prev).normalized()
		var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD

		var hoop := Hoop.new()
		hoop.index = i
		hoop.transform = Transform3D(Basis.looking_at(direction, up), pos)
		hoop.fish_entered.connect(_on_hoop_fish_entered)
		add_child(hoop)
		hoops.append(hoop)
	_refresh_hoops()


func _add_box(pos: Vector3, size: Vector3, color: Color, rotation_euler := Vector3.ZERO) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var mesh := BoxMesh.new()
	mesh.size = size
	_add_static(shape, mesh, Transform3D(Basis.from_euler(rotation_euler), pos), color)


func _add_cylinder(base: Vector3, radius: float, height: float, color: Color) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	_add_static(shape, mesh, Transform3D(Basis.IDENTITY, base + Vector3(0, height / 2.0, 0)), color)


func _add_sphere(centre: Vector3, radius: float, color: Color) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	_add_static(shape, mesh, Transform3D(Basis.IDENTITY, centre), color)


func _add_static(shape: Shape3D, mesh: Mesh, xform: Transform3D, color: Color) -> void:
	var body := StaticBody3D.new()
	body.transform = xform
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var material := ShaderMaterial.new()
	material.shader = GRID_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("line_color", color.lightened(0.35))
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
