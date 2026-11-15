class_name WaterGradeEffect
extends CompositorEffect
## The water look's per-camera grade pass (planning_abyssal_look.md, phase 1): a
## vignette and a luminance S-curve on the HDR picture before tonemapping, in
## shaders/water_grade.glsl. One per Camera3D (attach()), so split-screen views
## each get their own vignette. Reads WaterLook live, and does nothing unless an
## Ocean mode's grade is on (WaterLook.grading_active). Phase 2's fog pass joins
## the same Compositor.
##
## Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md

const SHADER_PATH := "res://shaders/water_grade.glsl"

var _rd: RenderingDevice
var _shader := RID()
var _pipeline := RID()


## Gives `camera` the grade pass (once; it adds to any compositor effects the camera already has).
## Does nothing without a rendering device (headless runs).
static func attach(camera: Camera3D) -> void:
	if camera == null or RenderingServer.get_rendering_device() == null:
		return
	WaterFogQuad.attach(camera)  # the water model's fog pass rides along on every camera that is graded
	if camera.compositor == null:
		camera.compositor = Compositor.new()
	for effect in camera.compositor.compositor_effects:
		if effect is WaterGradeEffect:
			return
	var effects := camera.compositor.compositor_effects.duplicate()
	effects.append(WaterGradeEffect.new())
	camera.compositor.compositor_effects = effects


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	RenderingServer.call_on_render_thread(_initialize)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _shader.is_valid():
		var rd := _rd
		var shader := _shader
		RenderingServer.call_on_render_thread(func() -> void: rd.free_rid(shader))  # the pipeline goes with it


func _initialize() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	var file := load(SHADER_PATH) as RDShaderFile
	if file == null:
		return
	var spirv := file.get_spirv()
	if spirv.compile_error_compute != "":
		push_error("WaterGradeEffect: " + spirv.compile_error_compute)
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	if _shader.is_valid():
		_pipeline = _rd.compute_pipeline_create(_shader)


func _render_callback(_type: int, render_data: RenderData) -> void:
	if _rd == null or not _pipeline.is_valid() or not WaterLook.grading_active:
		return
	var look := WaterLook.shared()
	var vignette := look.eff_vignette()
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	# Depth exposure (phase 2): brightness follows how deep this camera is, so each split-screen view has its own.
	var exposure := 1.0
	if WaterLook.fog_active:
		var scene := render_data.get_render_scene_data()
		if scene:
			exposure = look.depth_exposure(scene.get_cam_transform().origin.y)
	if vignette <= 0.0 and look.curve <= 0.0 and look.highlight_desat <= 0.0 and is_equal_approx(exposure, 1.0):
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return
	var push := PackedFloat32Array([size.x, size.y, vignette, look.vignette_start, look.curve, look.highlight_desat, look.highlight_start, exposure])
	var groups := Vector2i((size.x - 1) / 8 + 1, (size.y - 1) / 8 + 1)
	for view in buffers.get_view_count():
		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.binding = 0
		uniform.add_id(buffers.get_color_layer(view))
		var uniform_set := UniformSetCacheRD.get_cache(_shader, 0, [uniform])
		var list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(list, _pipeline)
		_rd.compute_list_bind_uniform_set(list, uniform_set, 0)
		_rd.compute_list_set_push_constant(list, push.to_byte_array(), push.size() * 4)
		_rd.compute_list_dispatch(list, groups.x, groups.y, 1)
		_rd.compute_list_end()
