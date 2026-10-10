class_name Goal
extends Node3D
## A recessed net behind an opening in an arena wall. The origin is the centre
## of the goal mouth on the wall; local +Z points out of the arena, into the net.
## Like Rocket League, a goal counts once the whole ball is past the goal line.

const NET_SHADER := preload("res://shaders/net.gdshader")
const POST_RADIUS := 0.45
const WALL := 1.0  # thickness of the solid net panels

@export var team := 0
@export var color := Color(1.0, 0.5, 0.1)
@export var width := 28.0
@export var height := 16.0
@export var depth := 12.0


func _ready() -> void:
	var net := ShaderMaterial.new()
	net.shader = NET_SHADER
	net.set_shader_parameter("net_color", color)

	var half_w := width / 2.0
	var half_h := height / 2.0
	var mid := depth / 2.0
	_add_panel(Vector3(0, 0, depth + WALL / 2.0), Vector3(width + WALL * 2.0, height + WALL * 2.0, WALL), net)  # back
	_add_panel(Vector3(0, half_h + WALL / 2.0, mid), Vector3(width, WALL, depth), net)  # top
	_add_panel(Vector3(0, -half_h - WALL / 2.0, mid), Vector3(width, WALL, depth), net)  # bottom
	_add_panel(Vector3(half_w + WALL / 2.0, 0, mid), Vector3(WALL, height + WALL * 2.0, depth), net)
	_add_panel(Vector3(-half_w - WALL / 2.0, 0, mid), Vector3(WALL, height + WALL * 2.0, depth), net)

	var frame := StandardMaterial3D.new()
	frame.albedo_color = color
	frame.emission_enabled = true
	frame.emission = color
	frame.emission_energy_multiplier = 1.2
	# Rounded posts around the mouth so the ball glances off the frame.
	_add_post(Vector3(half_w, 0, 0), Vector3.UP, height, frame)
	_add_post(Vector3(-half_w, 0, 0), Vector3.UP, height, frame)
	_add_post(Vector3(0, half_h, 0), Vector3.RIGHT, width, frame)
	_add_post(Vector3(0, -half_h, 0), Vector3.RIGHT, width, frame)

	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 2.0
	glow.omni_range = maxf(width, height)
	glow.position = Vector3(0, 0, depth * 0.6)
	add_child(glow)


## True once a ball of `radius` centred at `world_position` is wholly past the goal line.
func contains_ball(world_position: Vector3, radius: float) -> bool:
	var local := to_local(world_position)
	return local.z > radius and absf(local.x) < width / 2.0 and absf(local.y) < height / 2.0


func _add_panel(pos: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)
	add_child(body)


func _add_post(pos: Vector3, axis: Vector3, length: float, material: Material) -> void:
	var body := StaticBody3D.new()
	# CylinderShape3D runs along Y; turn it onto `axis`.
	var post_basis := Basis.IDENTITY if axis == Vector3.UP else Basis(Vector3.BACK, PI / 2.0)
	body.transform = Transform3D(post_basis, pos)
	var shape := CylinderShape3D.new()
	shape.radius = POST_RADIUS
	shape.height = length + POST_RADIUS * 2.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh := CylinderMesh.new()
	mesh.top_radius = POST_RADIUS
	mesh.bottom_radius = POST_RADIUS
	mesh.height = shape.height
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)
	add_child(body)
