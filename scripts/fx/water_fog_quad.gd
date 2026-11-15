class_name WaterFogQuad
extends MeshInstance3D
## The water look's per-camera fog pass (planning_abyssal_look.md, phase 2): a full-screen quad
## child of a Camera3D that replaces the Environment's one-colour fog on everything opaque with
## the water model (shaders/water_fog_pass.gdshader). Each camera gets its own, on its own visual
## layer that only that camera draws (split-screen shares one World3D), so each view fogs from its
## own position. Visible only while an Ocean mode's water model is on (WaterLook.fog_active).
##
## Ported from abyssal-garden (MIT, (c) Noniv), see THIRD_PARTY_NOTICES.md

const SHADER := preload("res://shaders/water_fog_pass.gdshader")
## Visual layers 16 to 20 (bits 15 to 19) are the quads' (at most 5 cameras at once).
const FIRST_BIT := 15
const BITS := 5

static var _material: ShaderMaterial
static var _taken := {}

var _bit := -1


## Gives `camera` its fog quad (once).
static func attach(camera: Camera3D) -> void:
	if camera == null:
		return
	for child in camera.get_children():
		if child is WaterFogQuad:
			return
	var bit := -1
	for i in BITS:
		if not _taken.has(i):
			bit = i
			break
	if bit < 0:
		return  # more cameras than layers: that one goes without the water model's fog
	var quad := WaterFogQuad.new()
	quad._bit = bit
	_taken[bit] = true
	quad.name = "WaterFogQuad"
	quad.layers = 1 << (FIRST_BIT + bit)
	var all_bits := ((1 << BITS) - 1) << FIRST_BIT
	camera.cull_mask = (camera.cull_mask & ~all_bits) | quad.layers
	camera.add_child(quad)


## The material every quad shares; Ocean pushes the water model's values into it each frame.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.render_priority = -128  # first among the transparents, so everything else draws over the fogged picture
	return _material


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.material = material()
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0  # the vertex shader puts it on the whole screen, wherever it is
	visible = false


func _process(_delta: float) -> void:
	visible = WaterLook.fog_active


func _exit_tree() -> void:
	if _bit >= 0:
		_taken.erase(_bit)
		_bit = -1
