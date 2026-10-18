class_name Explosion
extends Node3D
## A one-off burst: a flash of light with a soft fireball at its heart, a
## shockwave shell racing out (bright at its rim, clear face on: FxKit.rim),
## glowing streaks of spark in a team's colour flying out along their paths,
## and a cloud of bubbles. Optionally a blast that shoves nearby fish away (a
## goal explosion, as in Rocket League). Frees itself when done.
##
## The spark and bubble meshes are made once per colour and shared.

const LIFETIME := 2.5
const FLASH_ENERGY := 3.0
## How long the fireball glows (s).
const CORE_TIME := 0.35

var color := Color.WHITE
## Shockwave and spark reach (m).
var radius := 10.0
## Velocity change at the centre for fish caught in the blast (m/s), falling
## off to nothing at `radius`. 0: no blast.
var blast := 0.0
## Where it goes off (world).
var origin := Vector3.ZERO
## How many sparks and bubbles, against a full one: e.g. a school fish's small
## pop (Nature), when many go off at once right in front of the camera.
var particle_share := 1.0
## Just a pop: sparks and a flash, no shockwave shell or bubble cloud (which
## fill the view when the camera swims straight through them).
var pop := false

static var _sparks := {}
static var _bubble: Mesh
static var _shell_mesh: SphereMesh
static var _core_mesh: QuadMesh

var _shell := MeshInstance3D.new()
var _shell_material: ShaderMaterial
var _core := MeshInstance3D.new()
var _core_material: StandardMaterial3D
var _light := OmniLight3D.new()
var _age := 0.0


## Sets one off at `at` (world) under `parent`.
static func spawn(parent: Node, at: Vector3, explosion_color: Color, reach: float, blast_speed := 0.0, particles := 1.0) -> Explosion:
	var explosion := Explosion.new()
	explosion.color = explosion_color
	explosion.radius = reach
	explosion.blast = blast_speed
	explosion.origin = at
	explosion.particle_share = particles
	explosion.pop = particles < 1.0
	parent.add_child(explosion)
	return explosion


func _ready() -> void:
	global_position = origin
	_light.light_color = color
	_light.omni_range = radius * 1.5
	_light.light_energy = FLASH_ENERGY
	_light.shadow_enabled = false
	add_child(_light)

	if _shell_mesh == null:
		_shell_mesh = SphereMesh.new()
		_shell_mesh.radius = 1.0
		_shell_mesh.height = 2.0
		_shell_mesh.radial_segments = 32
		_shell_mesh.rings = 16
		_core_mesh = QuadMesh.new()
		_core_mesh.size = Vector2(2.0, 2.0)
	# Culled from inside (the shader's cull_back): from inside it would tint the whole view.
	_shell_material = FxKit.rim(Color(color.lerp(Color.WHITE, 0.2), 0.6), 0.0, 0.0)
	_shell_material.set_shader_parameter("rim_power", 4.0)  # a crisp edge, clear inside
	_shell.mesh = _shell_mesh
	_shell.material_override = _shell_material
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell.scale = Vector3.ONE * 0.1
	_shell.visible = not pop
	add_child(_shell)

	_core_material = FxKit.glow(color.lerp(Color.WHITE, 0.5), FxKit.dot(), true)
	_core_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_core_material.billboard_keep_scale = true
	_core.mesh = _core_mesh
	_core.material_override = _core_material
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)

	var sparks := _particles(_spark_mesh(color), maxi(roundi(160 * particle_share), 1), radius * 2.2, 0.6, Vector3.ZERO, 1.2)
	sparks.particle_flag_align_y = true  # each streak along its flight
	add_child(sparks)
	if not pop:
		add_child(_particles(_bubble_mesh(), maxi(roundi(140 * particle_share), 1), radius * 1.1, 2.0, Vector3(0, 3.0, 0), 2.2))
	_process(0.0)

	if blast > 0.0:
		for fish: FishController in get_tree().get_nodes_in_group(FishController.GROUP):
			if fish.battered:
				continue
			var away := fish.global_position - global_position
			var falloff := 1.0 - away.length() / radius
			if falloff > 0.0:
				fish.apply_push(away.normalized() * blast * falloff)


func _process(delta: float) -> void:
	_age += delta
	var shock := clampf(_age / 0.45, 0.0, 1.0)
	_shell.scale = Vector3.ONE * maxf(radius * (1.0 - pow(1.0 - shock, 3.0)), 0.1)
	_shell_material.set_shader_parameter("tint", Color(color.lerp(Color.WHITE, 0.2), 0.6 * (1.0 - shock)))
	_shell.visible = shock < 1.0 and not pop
	var core := clampf(_age / CORE_TIME, 0.0, 1.0)
	_core.visible = core < 1.0
	_core.scale = Vector3.ONE * radius * (0.25 + 0.35 * sqrt(core))
	_core_material.albedo_color.a = (1.0 - core) * (1.0 - core)
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
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = true
	return particles


## A spark: a short glowing streak along y (crossed ribbons, soft-edged,
## brightest at its head), one per colour.
static func _spark_mesh(spark_color: Color) -> Mesh:
	var key := spark_color.to_html()
	if not _sparks.has(key):
		var mesh := FxKit.ribbons([PackedVector3Array([Vector3(0, 0.22, 0), Vector3(0, -0.22, 0)])], [0.11], true)
		mesh.surface_set_material(0, FxKit.glow(spark_color.lightened(0.35), FxKit.across()))
		_sparks[key] = mesh
	return _sparks[key]


## A bubble: clear face on, bright at its rim, with a glint.
static func _bubble_mesh() -> Mesh:
	if _bubble == null:
		var bubble := SphereMesh.new()
		bubble.radius = 0.12
		bubble.height = 0.24
		bubble.radial_segments = 8
		bubble.rings = 4
		bubble.material = FxKit.rim(Color(0.85, 0.97, 1.0, 0.8), 0.08, 0.8)
		_bubble = bubble
	return _bubble
