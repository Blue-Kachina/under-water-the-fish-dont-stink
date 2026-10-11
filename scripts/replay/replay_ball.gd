class_name ReplayBall
extends Node3D
## The replay's ball: the live ball's bubble, at RL's size, set from ReplayData
## samples every rendered frame. No physics.

const RADIUS := 0.9125  # RL: 91.25 uu
## RL's top ball speed (m/s), for the bubble's stretch.
const MAX_SPEED := 60.0

var linear_velocity := Vector3.ZERO
var speed := 0.0

var _material := ShaderMaterial.new()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var sphere := SphereMesh.new()
	sphere.radius = 1.0  # scaled, as the live ball's (the shader works on the unit sphere)
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_material.shader = Ball.BUBBLE_SHADER
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.material_override = _material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.layers = BallIndicators.BALL_LAYER
	mesh.scale = Vector3.ONE * RADIUS
	add_child(mesh)


func apply(sample: ReplayData.Sample) -> void:
	visible = sample.present
	if not sample.present:
		return
	global_transform = Transform3D(Basis(sample.rotation), sample.position)
	linear_velocity = sample.velocity
	speed = sample.velocity.length()
	# Stretch a little along the direction of travel, as the live ball does.
	_material.set_shader_parameter("stretch_dir", linear_velocity.normalized() if speed > 0.1 else Vector3.UP)
	_material.set_shader_parameter("stretch", clampf(speed / MAX_SPEED, 0.0, 1.0) * 0.25)
