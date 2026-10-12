class_name Explosion
extends Node3D
## A one-off burst: a flash of light, a shockwave shell racing out, sparks in a
## team's colour and a cloud of bubbles. Optionally a blast that shoves nearby
## fish away (a goal explosion, as in Rocket League). Frees itself when done.

const LIFETIME := 2.5
const FLASH_ENERGY := 3.0

var color := Color.WHITE
## Shockwave and spark reach (m).
var radius := 10.0
## Velocity change at the centre for fish caught in the blast (m/s), falling
## off to nothing at `radius`. 0: no blast.
var blast := 0.0
## Where it goes off (world).
var origin := Vector3.ZERO

var _shell := MeshInstance3D.new()
var _shell_material := StandardMaterial3D.new()
var _light := OmniLight3D.new()
var _age := 0.0


## Sets one off at `at` (world) under `parent`.
static func spawn(parent: Node, at: Vector3, explosion_color: Color, reach: float, blast_speed := 0.0) -> Explosion:
	var explosion := Explosion.new()
	explosion.color = explosion_color
	explosion.radius = reach
	explosion.blast = blast_speed
	explosion.origin = at
	parent.add_child(explosion)
	return explosion


func _ready() -> void:
	global_position = origin
	_light.light_color = color
	_light.omni_range = radius * 1.5
	_light.light_energy = FLASH_ENERGY
	_light.shadow_enabled = false
	add_child(_light)

	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shell_material.cull_mode = BaseMaterial3D.CULL_BACK  # seen from outside: from inside it would tint the whole view
	_shell_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shell_material.albedo_color = Color(color, 0.35)
	sphere.material = _shell_material
	_shell.mesh = sphere
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell.scale = Vector3.ONE * 0.1
	add_child(_shell)

	add_child(_particles(_spark_mesh(), 160, radius * 2.2, 0.6, Vector3.ZERO, 1.2))
	add_child(_particles(_bubble_mesh(), 140, radius * 1.1, 2.0, Vector3(0, 3.0, 0), 2.2))

	if blast > 0.0:
		for fish: FishController in get_tree().get_nodes_in_group(FishController.GROUP):
			if fish.demolished:
				continue
			var away := fish.global_position - global_position
			var falloff := 1.0 - away.length() / radius
			if falloff > 0.0:
				fish.apply_push(away.normalized() * blast * falloff)


func _process(delta: float) -> void:
	_age += delta
	var shock := clampf(_age / 0.45, 0.0, 1.0)
	_shell.scale = Vector3.ONE * maxf(radius * (1.0 - pow(1.0 - shock, 3.0)), 0.1)
	_shell_material.albedo_color.a = 0.35 * (1.0 - shock)
	_shell.visible = shock < 1.0
	_light.light_energy = FLASH_ENERGY * exp(-_age * 5.0)
	if _age >= LIFETIME:
		queue_free()


func _particles(mesh: Mesh, amount: int, speed: float, life: float, gravity: Vector3, damping: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.mesh = mesh
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = life
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.5
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.gravity = gravity
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.damping_min = speed * damping * 0.5
	particles.damping_max = speed * damping
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.6
	particles.emitting = true
	return particles


func _spark_mesh() -> Mesh:
	var spark := SphereMesh.new()
	spark.radius = 0.09
	spark.height = 0.18
	spark.radial_segments = 6
	spark.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color.lightened(0.3)
	spark.material = material
	return spark


func _bubble_mesh() -> Mesh:
	var bubble := SphereMesh.new()
	bubble.radius = 0.12
	bubble.height = 0.24
	bubble.radial_segments = 8
	bubble.rings = 4
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.85, 0.97, 1.0, 0.6)
	bubble.material = material
	return bubble
