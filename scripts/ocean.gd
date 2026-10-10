class_name Ocean
extends Node3D
## Endless open water for tuning movement: no walls, floor or obstacles. Floating
## specks wrap around the camera so there's always a speed reference, and the
## background fades from light above to dark below so up stays readable.

const SPECKS_SHADER := preload("res://shaders/wrapped_specks.gdshader")
const SPECK_COUNT := 6000
## Edge of the cube of water filled with specks; keep it beyond the fog's reach.
const SPECK_BOX := 120.0

var _specks_material := ShaderMaterial.new()


func _ready() -> void:
	_build_specks()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		_specks_material.set_shader_parameter("center", camera.global_position)


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
