class_name Ocean
extends Node3D
## Endless open water for tuning movement: no walls, floor or obstacles. Floating
## specks wrap around the camera so there's always a speed reference, and the
## background fades from light above to dark below so up stays readable.
##
## A match here (Hunt) can mark out its arena with boundary_radius: the water
## darkens and thickens as the camera nears the edge (the fog shifts), and past
## it, more so. 0 = no edge.

const WATER_SKY_SHADER := preload("res://shaders/water_sky.gdshader")
const WATER_SURFACE_SHADER := preload("res://shaders/water_surface.gdshader")
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

var _snow: MultiMeshInstance3D
var _env: Environment
## The fog as configured, before any edge shift: [colour, density].
var _fog_base := []
## How far the fog's shifted to the edge's now (0..1).
var _edge_amount := 0.0
var _grade_signature := 0
var _quality_signature := 0
## The sky as it was (a procedural gradient, still used when the water model is switched off, and by the Blood Moon's restyle) and the water model's.
var _procedural_sky := ProceduralSkyMaterial.new()
var _water_sky := ShaderMaterial.new()
var _model_on := false
## The fog's density now (1x is WaterLook.density_ref), after the edge's thickening: what the murk and the water model are measured by.
var _density_now := 0.012
var _sun: DirectionalLight3D
var _sun_base := Color.WHITE
var _water_clock := 0.0  # drives the caustics' shader clock
var _surface: MeshInstance3D
var _surface_material := ShaderMaterial.new()
var _shafts: MultiMeshInstance3D


func _ready() -> void:
	_build_specks()
	_build_shafts()
	RenderingServer.frame_pre_draw.connect(_hold_cameras_under_surface)


## The cameras drawing this water: the window's and every split-screen view's follow cam.
func _cameras(main_camera: Camera3D) -> Array[Camera3D]:
	var cameras: Array[Camera3D] = []
	if main_camera:
		cameras.append(main_camera)
	for node in get_tree().get_nodes_in_group(&"follow_cameras"):
		var cam := node as Camera3D
		if cam and cam.is_inside_tree() and cam.current and not cameras.has(cam):
			cameras.append(cam)
	return cameras


## In open modes the surface recedes ahead of the highest camera (WaterLook.surface_y), so it can't be reached.
func _track_top_camera(main_camera: Camera3D) -> void:
	var top := -INF
	for cam in _cameras(main_camera):
		top = maxf(top, cam.global_position.y)
	WaterLook.top_camera_y = top


## Where the surface is fixed over a ceiling, no camera goes above surface_camera_gap under it (after every camera has moved this frame).
func _hold_cameras_under_surface() -> void:
	if not is_inside_tree() or not WaterLook.fog_active or not WaterLook.surface_fixed():
		return
	var look := WaterLook.shared()
	var limit := look.surface_y() - look.surface_camera_gap
	for cam in _cameras(get_viewport().get_camera_3d()):
		if cam.global_position.y > limit:
			cam.global_position.y = limit


func _process(delta: float) -> void:
	_water_clock += delta  # stops while paused
	_regrade(false)
	_requality()
	WaterLook.shared().push_particles()
	WaterLook.shared().push_materials()
	_update_snow()
	var camera := get_viewport().get_camera_3d()
	_track_top_camera(camera)
	if camera:
		if boundary_radius > 0.0:
			var inside := boundary_radius * (1.0 - EDGE_FADE)
			_shift_fog(smoothstep(inside, boundary_radius * 1.1, camera.global_position.distance_to(boundary_center)))
	_update_water(camera)


## The procedural sky (the Blood Moon restyles it when the water model is off).
func procedural_sky() -> ProceduralSkyMaterial:
	return _procedural_sky


## The fog's density now as the arena and murk set it (1x is WaterLook.density_ref). The Environment's own is thinner with the water model on.
func fog_density() -> float:
	return _density_now


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
	_procedural_sky.sky_top_color = Color(0.2, 0.55, 0.7)
	_procedural_sky.sky_horizon_color = Color(0.04, 0.2, 0.28)
	_procedural_sky.ground_horizon_color = Color(0.04, 0.2, 0.28)
	_procedural_sky.ground_bottom_color = Color(0.0, 0.02, 0.05)
	_procedural_sky.sun_angle_max = 40.0  # soft glow from the surface instead of a sharp sun
	_water_sky.shader = WATER_SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _procedural_sky
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	_env = env
	_fog_base = [env.fog_light_color, env.fog_density]
	_density_now = env.fog_density
	_model_on = false
	_apply_model(true)
	_regrade(true)


## Marine snow (WaterLook "Marine snow"): quads that face the camera, spread in a unit cube; the shader wraps them into a box round
## each view's camera. All built once at the most flakes there can be, snow_count of them drawn.
func _build_specks() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = WaterLook.get_snow_material()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = WaterLook.SNOW_MAX
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in WaterLook.SNOW_MAX:
		var pos := Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5)
		var size := rng.randf_range(0.6, 1.8)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), pos))
	multimesh.visible_instance_count = 0
	_snow = MultiMeshInstance3D.new()
	_snow.name = "MarineSnow"
	_snow.multimesh = multimesh
	_snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves flakes to wherever each camera is, so never cull them.
	_snow.custom_aabb = AABB(Vector3.ONE * -1e6, Vector3.ONE * 2e6)
	add_child(_snow)


## Light shafts (WaterLook "Light shafts"): unit cylinders in one MultiMesh, each a cell in a unit square and a radius in its scale;
## light_shaft.gdshader stands them along the light and wraps them round each view's camera. Built once at the most there can be.
func _build_shafts() -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 12
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	cylinder.material = WaterLook.get_shaft_material()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = cylinder
	multimesh.instance_count = WaterLook.SHAFT_MAX
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in WaterLook.SHAFT_MAX:
		var size := rng.randf_range(0.6, 1.6)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), Vector3(rng.randf(), 0.0, rng.randf())))
	multimesh.visible_instance_count = 0
	_shafts = MultiMeshInstance3D.new()
	_shafts.name = "LightShafts"
	_shafts.multimesh = multimesh
	_shafts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shafts.custom_aabb = AABB(Vector3.ONE * -1e6, Vector3.ONE * 2e6)  # the shader places them round each camera
	add_child(_shafts)


## The shafts' values and count each frame (hidden with the water model off, and the Blood Moon's old rays take over then).
func _update_shafts(look: WaterLook) -> void:
	if _shafts == null:
		return
	var on := _model_on and look.shafts_enabled
	_shafts.multimesh.visible_instance_count = clampi(look.eff_shaft_count(), 0, WaterLook.SHAFT_MAX) if on else 0
	if not on:
		return
	var moon := WaterLook.moon_dir
	var moon_on := moon.length() > 0.5 and look.moon_share > 0.01
	var share := look.moon_share if moon_on else 0.0
	var dir := WaterLook.sun_dir.lerp(moon.normalized(), share).normalized() if moon_on else WaterLook.sun_dir
	look.push_shafts(dir, look.density_scale(), share)


func _update_snow() -> void:
	if _snow == null:
		return
	var look := WaterLook.shared()
	_snow.multimesh.visible_instance_count = clampi(look.eff_snow_count(), 0, WaterLook.SNOW_MAX) if look.snow_enabled else 0


## Puts WaterLook's grade (tonemap, adjustments, bloom) on the environment, and again whenever a value
## it uses changes (a panel edit, the Blood Moon's strength).
func _regrade(force: bool) -> void:
	if _env == null or is_queued_for_deletion():
		return
	var look := WaterLook.shared()
	var signature := look.grade_signature()
	if force or signature != _grade_signature:
		_grade_signature = signature
		look.apply_grade(_env)


## Shifts the fog `amount` (0..1) of the way to the edge's.
func _shift_fog(amount: float) -> void:
	_edge_amount = amount
	if _env == null or _fog_base.is_empty():
		return
	_density_now = _fog_base[1] * (1.0 + EDGE_FOG_THICKEN * amount)
	if _model_on:
		return  # the water model writes the Environment's thinner fog every frame (_update_water)
	_env.fog_light_color = (_fog_base[0] as Color).lerp(EDGE_FOG_COLOR, amount)
	_env.fog_density = _density_now


## Switches between the water model (shader sky, per-camera fog pass) and the old plain look as WaterLook.model_enabled says.
func _apply_model(force: bool) -> void:
	if _env == null or _env.sky == null:
		return
	var on := WaterLook.shared().model_enabled
	WaterLook.fog_active = on
	if on == _model_on and not force:
		return
	_model_on = on
	_env.sky.sky_material = _water_sky if on else _procedural_sky
	_env.fog_sky_affect = 0.0 if on else 0.25  # the water sky carries its own fog; the old one kept its gradient through a thin veil
	if not on:
		_shift_fog(_edge_amount)


## Each frame with the water model on: the shared look values the fog pass and sky read, the Environment's thin fog for see-through
## things (colour and density, the same ones the pass undoes on opaque things), the sky's uniforms and the sun's depth tint.
func _update_water(camera: Camera3D) -> void:
	if _env == null or is_queued_for_deletion():
		return
	var look := WaterLook.shared()
	_apply_model(false)
	if not _model_on:
		look.push_caustics(_water_clock)  # strength 0 with the model off
		if _surface:
			_surface.visible = false
		if _shafts:
			_shafts.multimesh.visible_instance_count = 0
		return
	WaterLook.density_now = _density_now
	WaterLook.edge_amount = _edge_amount
	if _sun == null or not is_instance_valid(_sun):
		_sun = get_tree().root.find_child("Sun", true, false) as DirectionalLight3D
		if _sun:
			if not _sun.has_meta("sun_base"):
				_sun.set_meta("sun_base", _sun.light_color)  # the scene's own colour, kept on the light so a tinted one is never taken for it
			_sun_base = _sun.get_meta("sun_base")
	if _sun:
		WaterLook.sun_dir = _sun.global_basis.z.normalized()
	var cam_y := camera.global_position.y if camera else look.surface_y() - 28.0
	var depth := maxf(look.surface_y() - cam_y, 0.0)
	var flat := look.flat_fog_color(depth)
	WaterLook.env_fog_linear = flat
	WaterLook.env_fog_density = _density_now * look.transparent_fog
	_env.fog_light_color = flat.linear_to_srgb()
	_env.fog_density = WaterLook.env_fog_density
	if _sun:
		_sun.light_color = _sun_base * look.sun_factor(depth)
	var scale := look.density_scale()
	var k := look.kd_k()
	var wcol := look.eff_wcol() * look.inscatter_gain
	var sun := WaterLook.sun_dir
	var sky_sig := look.eff_sig() * lerpf(1.0, scale, WaterLook.sky_murk)
	var phase := Vector2(look.phase_base, look.phase_forward)
	var m := _water_sky
	m.set_shader_parameter("ws_sig", sky_sig)
	m.set_shader_parameter("wf_k", k)
	m.set_shader_parameter("wf_wcol", wcol)
	m.set_shader_parameter("wf_sun_dir", sun)
	m.set_shader_parameter("wf_phase", phase)
	m.set_shader_parameter("ws_distance", look.sky_distance)
	m.set_shader_parameter("ws_gain", look.sky_gain)
	m.set_shader_parameter("ws_surface_y", look.surface_y())
	m.set_shader_parameter("ws_ref_depth", clampf(depth, 1.0, 400.0))
	var q := WaterFogQuad.material()  # the opaque world's fog pass (every camera's quad shares it)
	q.set_shader_parameter("wf_sig", look.eff_sig() * scale)
	q.set_shader_parameter("wf_k", k)
	q.set_shader_parameter("wf_wcol", wcol)
	q.set_shader_parameter("wf_sun_dir", sun)
	q.set_shader_parameter("wf_phase", phase)
	q.set_shader_parameter("wq_env_fog", Vector4(flat.r, flat.g, flat.b, WaterLook.env_fog_density))
	q.set_shader_parameter("wq_fade", Vector2(look.fade_start, look.fade_end))
	q.set_shader_parameter("wq_surface_y", look.surface_y())
	look.push_caustics(_water_clock)
	_update_surface(look, camera, k, wcol, phase)
	_update_shafts(look)


## The surface seen from below (phase 4): one plane that puts itself under every camera (water_surface.gdshader).
func _update_surface(look: WaterLook, camera: Camera3D, k: Vector3, wcol: Vector3, phase: Vector2) -> void:
	var on := _model_on and look.surface_enabled
	if on and _surface == null:
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.0, 2.0)
		_surface_material.shader = WATER_SURFACE_SHADER
		_surface_material.render_priority = -100  # after the fog pass (-128), before every other see-through thing
		plane.material = _surface_material
		_surface = MeshInstance3D.new()
		_surface.name = "WaterSurface"
		_surface.mesh = plane
		_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_surface.extra_cull_margin = 16384.0
		_surface.custom_aabb = AABB(Vector3.ONE * -1e5, Vector3.ONE * 2e5)
		add_child(_surface)
	if _surface == null:
		return
	_surface.visible = on
	if not on:
		return
	var m := _surface_material
	var scale := look.density_scale()
	var moon := WaterLook.moon_dir
	var moon_on := moon.length() > 0.5 and look.moon_share > 0.01
	var share := look.moon_share if moon_on else 0.0
	var sky := Vector3(look.surface_sky_r, look.surface_sky_g, look.surface_sky_b).lerp(Vector3(look.moon_sky_r, look.moon_sky_g, look.moon_sky_b), share)
	var sun_col := Vector3(1.7, 1.6, 1.45).lerp(Vector3(1.0, 0.05, 0.03), share)
	var sun_dir := WaterLook.sun_dir.lerp(moon.normalized(), share).normalized() if moon_on else WaterLook.sun_dir
	var far := camera.far * 0.9 if camera else 900.0
	m.set_shader_parameter("wf_sig", look.eff_sig() * scale)
	m.set_shader_parameter("wf_k", k)
	m.set_shader_parameter("wf_wcol", wcol)
	m.set_shader_parameter("wf_sun_dir", WaterLook.sun_dir)
	m.set_shader_parameter("wf_phase", phase)
	m.set_shader_parameter("ws_radius", minf(look.surface_radius, far))
	m.set_shader_parameter("ws_surface_y", look.surface_y())
	m.set_shader_parameter("ws_time", _water_clock * look.surface_wave_speed)
	m.set_shader_parameter("ws_fade", Vector2(look.fade_start, look.fade_end))
	m.set_shader_parameter("ws_wave", look.surface_waves)
	m.set_shader_parameter("ws_far_calm", look.surface_calm_distance)
	m.set_shader_parameter("ws_sky", sky)
	m.set_shader_parameter("ws_sun_col", sun_col)
	m.set_shader_parameter("ws_sun_dir", sun_dir)
	m.set_shader_parameter("ws_glare", Vector2(lerpf(look.surface_sun_halo, look.moon_disc_halo, share), lerpf(look.surface_sun_core, look.moon_disc_core, share)))


func _exit_tree() -> void:
	if _sun != null and is_instance_valid(_sun) and _sun.has_meta("sun_base"):
		_sun.light_color = _sun.get_meta("sun_base")  # the depth tint is the Ocean's
	if boundary_radius > 0.0:
		_shift_fog(0.0)  # the environment outlives the ocean
	WaterLook.top_camera_y = -INF


## Puts the graphics quality's render scale on the window and the split-screen views when the tier (or the adaptive factor) changes.
func _requality() -> void:
	var look := WaterLook.shared()
	var signature := look.quality_signature()
	if signature != _quality_signature:
		_quality_signature = signature
		look.apply_scale_all(get_tree())
