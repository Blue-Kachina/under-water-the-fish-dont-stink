class_name BloodMoon
extends Node3D
## Unnatural's look (planning_unnatural.md §1): a blood moon over the sea.
## Red-tinted fog, ambient light and sky, the water's surface overhead with a
## big red moon through it, and red god-rays slanting down. One node owns all
## of it, so it can pulse with events (pulse(): brighter as the boss
## arrives). Puts the environment back as it was when it leaves the tree.

const FOG_COLOR := Color(0.16, 0.025, 0.035)
const AMBIENT_COLOR := Color(0.75, 0.3, 0.3)
const SKY_TOP := Color(0.5, 0.07, 0.06)
const SKY_HORIZON := Color(0.14, 0.02, 0.03)
const MOON_COLOR := Color(1.0, 0.2, 0.12)
const RAY_COLOR := Color(1.0, 0.25, 0.15, 0.05)
const RAYS := 9

var ocean: Ocean
## How red it is (0: the plain ocean; UnnaturalSettings.blood_moon).
var strength := 1.0
## Over the arena: its middle, radius and the water's surface height.
var centre := Vector3.ZERO
var radius := 150.0
var surface_height := 20.0

var _env: Environment
var _before := {}
var _sky: ProceduralSkyMaterial
var _sky_before := []
var _pulse := 0.0
var _moon := MeshInstance3D.new()
var _moon_material := StandardMaterial3D.new()
var _rays: Array[MeshInstance3D] = []
var _ray_material := StandardMaterial3D.new()


func _ready() -> void:
	_build()
	if ocean:
		_env = ocean.environment()
	if _env:
		for key: String in ["fog_light_color", "fog_density", "ambient_light_color", "ambient_light_energy"]:
			_before[key] = _env.get(key)
		var base := ocean.fog_base() if ocean else []
		if base.size() == 2:  # the fog before the arena edge's shift
			_before.fog_light_color = base[0]
			_before.fog_density = base[1]
		_sky = _env.sky.sky_material as ProceduralSkyMaterial if _env.sky else null
		if _sky:
			_sky_before = [_sky.sky_top_color, _sky.sky_horizon_color, _sky.ground_horizon_color]
	_apply()


## Brightens it for `seconds` (fading back), e.g. as a boss arrives.
func pulse(amount := 1.0) -> void:
	_pulse = maxf(_pulse, amount)


func _process(delta: float) -> void:
	_pulse = move_toward(_pulse, 0.0, delta * 0.5)
	_apply()
	var camera := get_viewport().get_camera_3d()
	if camera:
		# The moon sits far overhead, off to one side, wherever the camera is.
		_moon.global_position = Vector3(camera.global_position.x, surface_height, camera.global_position.z) + Vector3(60.0, 160.0, -80.0)


func _apply() -> void:
	var red := clampf(strength * (1.0 + 0.6 * _pulse), 0.0, 2.0)
	var share := clampf(red, 0.0, 1.0)
	if _env and not _before.is_empty():
		var fog := (_before.fog_light_color as Color).lerp(FOG_COLOR, share)
		var density: float = _before.fog_density * (1.0 + 0.25 * share)
		if ocean:
			ocean.set_fog_base(fog, density)  # it shifts it toward the arena's edge
		else:
			_env.fog_light_color = fog
			_env.fog_density = density
		_env.ambient_light_color = (_before.ambient_light_color as Color).lerp(AMBIENT_COLOR, share)
		_env.ambient_light_energy = _before.ambient_light_energy * (1.0 + 0.2 * _pulse)
	if _sky and not _sky_before.is_empty():
		_sky.sky_top_color = (_sky_before[0] as Color).lerp(SKY_TOP, share)
		_sky.sky_horizon_color = (_sky_before[1] as Color).lerp(SKY_HORIZON, share)
		_sky.ground_horizon_color = (_sky_before[2] as Color).lerp(SKY_HORIZON, share)
	_moon.visible = share > 0.01
	_moon_material.emission_energy_multiplier = 2.0 + 2.0 * _pulse
	_ray_material.albedo_color = Color(RAY_COLOR, RAY_COLOR.a * share * (1.0 + _pulse))
	for ray in _rays:
		ray.visible = share > 0.01


func _build() -> void:
	# The surface: seen from below, faintly red.
	var surface := MeshInstance3D.new()
	surface.name = "Surface"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 3.0
	plane.flip_faces = true
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.35, 0.06, 0.06, 0.55)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.metallic = 0.6
	water.roughness = 0.15
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material = water
	surface.mesh = plane
	surface.position = centre + Vector3.UP * surface_height
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	# The moon: a glowing disc the fog doesn't swallow.
	var disc := SphereMesh.new()
	disc.radius = 28.0
	disc.height = 56.0
	disc.radial_segments = 24
	disc.rings = 12
	_moon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_moon_material.albedo_color = MOON_COLOR
	_moon_material.emission_enabled = true
	_moon_material.emission = MOON_COLOR
	_moon_material.disable_fog = true
	disc.material = _moon_material
	_moon.name = "Moon"
	_moon.mesh = disc
	_moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_moon.top_level = true
	add_child(_moon)
	# God-rays: long faint shafts slanting down from the moon's side.
	_ray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ray_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ray_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_ray_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dice := RandomNumberGenerator.new()
	dice.seed = 5
	var slant := Basis(Vector3(1.0, 0.0, 1.0).normalized(), deg_to_rad(-22.0))
	for i in RAYS:
		var shaft := CylinderMesh.new()
		shaft.top_radius = dice.randf_range(1.5, 4.0)
		shaft.bottom_radius = shaft.top_radius * 2.5
		shaft.height = 70.0
		shaft.radial_segments = 8
		shaft.cap_top = false
		shaft.cap_bottom = false
		shaft.material = _ray_material
		var ray := MeshInstance3D.new()
		ray.name = "Ray%d" % i
		ray.mesh = shaft
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var spot := Vector2.from_angle(dice.randf() * TAU) * dice.randf_range(0.0, radius * 0.8)
		ray.transform = Transform3D(slant, centre + Vector3(spot.x, surface_height - 30.0, spot.y))
		add_child(ray)
		_rays.append(ray)


func _exit_tree() -> void:
	if _env and not _before.is_empty():
		for key: String in _before:
			_env.set(key, _before[key])
		if ocean:
			ocean.set_fog_base(_before.fog_light_color, _before.fog_density)
	if _sky and not _sky_before.is_empty():
		_sky.sky_top_color = _sky_before[0]
		_sky.sky_horizon_color = _sky_before[1]
		_sky.ground_horizon_color = _sky_before[2]
