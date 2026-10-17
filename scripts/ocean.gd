class_name Ocean
extends Node3D
## Endless open water for tuning movement: no walls, floor or obstacles. Floating
## specks wrap around the camera so there's always a speed reference, and the
## background fades from light above to dark below so up stays readable.
##
## A match here (Hunt) can mark out its arena with boundary_radius: the water
## darkens and thickens as the camera nears the edge (the fog shifts), and past
## it, more so. 0 = no edge.

const SPECKS_SHADER := preload("res://shaders/wrapped_specks.gdshader")
const SPECK_COUNT := 6000
## Edge of the cube of water filled with specks; keep it beyond the fog's reach.
const SPECK_BOX := 120.0
## The fog's colour at and past the arena's edge, and how much thicker it gets there.
const EDGE_FOG_COLOR := Color(0.01, 0.04, 0.08)
const EDGE_FOG_THICKEN := 2.5
## The shift starts this far inside the edge (fraction of the radius).
const EDGE_FADE := 0.25

## The arena's edge (m from boundary_center), or 0 for none.
var boundary_radius := 0.0:
	set(value):
		boundary_radius = value
		_shift_fog(0.0)
var boundary_center := Vector3.ZERO

var _specks_material := ShaderMaterial.new()
var _env: Environment
## The fog as configured, before any edge shift: [colour, density].
var _fog_base := []
## How far the fog's shifted to the edge's now (0..1).
var _edge_amount := 0.0


func _ready() -> void:
	_build_specks()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		_specks_material.set_shader_parameter("center", camera.global_position)
		if boundary_radius > 0.0:
			var inside := boundary_radius * (1.0 - EDGE_FADE)
			_shift_fog(smoothstep(inside, boundary_radius * 1.1, camera.global_position.distance_to(boundary_center)))


## The environment it configured (null before configure_environment()).
func environment() -> Environment:
	return _env


## The fog before any edge shift: [colour, density] (empty before configure_environment()).
func fog_base() -> Array:
	return _fog_base.duplicate()


## A new fog to shift from (Unnatural's blood moon), applied at once.
func set_fog_base(color: Color, density: float) -> void:
	_fog_base = [color, density]
	_shift_fog(_edge_amount)


func spawn_transform() -> Transform3D:
	return Transform3D.IDENTITY


func configure_environment(env: Environment) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.2, 0.55, 0.7)
	sky_material.sky_horizon_color = Color(0.04, 0.2, 0.28)
	sky_material.ground_horizon_color = Color(0.04, 0.2, 0.28)
	sky_material.ground_bottom_color = Color(0.0, 0.02, 0.05)
	sky_material.sun_angle_max = 40.0  # soft glow from the surface instead of a sharp sun
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_sky_affect = 0.25  # keep the light-above/dark-below gradient visible through the fog
	_env = env
	_fog_base = [env.fog_light_color, env.fog_density]


func _build_specks() -> void:
	var speck := SphereMesh.new()
	speck.radius = 0.05
	speck.height = 0.1
	speck.radial_segments = 6
	speck.rings = 3
	_specks_material.shader = SPECKS_SHADER
	_specks_material.set_shader_parameter("box_size", SPECK_BOX)
	speck.material = _specks_material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = speck
	multimesh.instance_count = SPECK_COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var half := SPECK_BOX / 2.0
	for i in SPECK_COUNT:
		var pos := Vector3(rng.randf_range(-half, half), rng.randf_range(-half, half), rng.randf_range(-half, half))
		var size := rng.randf_range(0.6, 1.8)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), pos))

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves specks to wherever the camera is, so never cull them.
	instance.custom_aabb = AABB(Vector3.ONE * -1e6, Vector3.ONE * 2e6)
	add_child(instance)


## Shifts the fog `amount` (0..1) of the way to the edge's.
func _shift_fog(amount: float) -> void:
	_edge_amount = amount
	if _env == null or _fog_base.is_empty():
		return
	_env.fog_light_color = (_fog_base[0] as Color).lerp(EDGE_FOG_COLOR, amount)
	_env.fog_density = _fog_base[1] * (1.0 + EDGE_FOG_THICKEN * amount)


func _exit_tree() -> void:
	if boundary_radius > 0.0:
		_shift_fog(0.0)  # the environment outlives the ocean
