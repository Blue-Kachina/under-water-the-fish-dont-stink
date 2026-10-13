class_name BubbleColumn
extends Node3D
## A column of rising bubbles that carries fish up it: anyone inside is lifted
## towards the ceiling (gravity cancelled, then eased up to RISE_SPEED), swirled
## gently round the middle and drawn back towards it, and left to bob just
## under the top. Swim out of the side (it's easily out-swum) to drop back down. The 1v1 puts one up at centre field once the match
## is over, in the winners' colour, so everyone can play about in it.

## How fast it carries a fish up (m/s), and how quickly it gets it there (m/s²).
const RISE_SPEED := 9.0
const LIFT := 22.0
## Round the middle (m/s, anticlockwise from above).
const SWIRL_SPEED := 2.5
const SWIRL := 4.0
## Drawn in towards the middle at up to this (m/s at the edge), this quickly (m/s²).
const DRAW_SPEED := 2.0
const DRAW := 5.0
## The lift eases off over this far (m) below the top, so fish bob there.
const EASE := 4.0
const GROW_TIME := 0.8

## Across (m), and from the floor up to where the lift gives out (m).
var radius := 6.0
var height := 17.0
var color := Color(0.8, 0.95, 1.0)

var _age := 0.0
var _tube := MeshInstance3D.new()


func _ready() -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	cylinder.radial_segments = 48
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_BACK  # seen from outside: from inside it would tint the whole view
	material.albedo_color = Color(color, 0.1)
	cylinder.material = material
	_tube.mesh = cylinder
	_tube.position.y = height / 2.0
	_tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tube)

	for big in [false, true]:
		var particles := CPUParticles3D.new()
		particles.mesh = _bubble_mesh(0.16 if big else 0.07)
		particles.amount = 120 if big else 520
		particles.lifetime = height / RISE_SPEED * (1.25 if big else 1.0)
		particles.preprocess = particles.lifetime  # already full when it appears
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		particles.emission_ring_axis = Vector3.UP
		particles.emission_ring_radius = radius * 0.95
		particles.emission_ring_inner_radius = 0.0
		particles.emission_ring_height = 0.4
		particles.direction = Vector3.UP
		particles.spread = 6.0
		particles.gravity = Vector3.ZERO
		particles.initial_velocity_min = RISE_SPEED * 0.7
		particles.initial_velocity_max = RISE_SPEED * 1.2
		particles.tangential_accel_min = 0.5
		particles.tangential_accel_max = 1.5
		particles.scale_amount_min = 0.5
		particles.scale_amount_max = 1.5
		particles.emitting = true
		add_child(particles)
	_tube.scale.y = 0.01


func _process(delta: float) -> void:
	_age += delta
	var grown := BroadcastUI.ease_out(_age / GROW_TIME)
	_tube.scale.y = maxf(grown, 0.01)
	_tube.position.y = height * grown / 2.0


func _physics_process(delta: float) -> void:
	for fish: FishController in get_tree().get_nodes_in_group(FishController.GROUP):
		if fish.demolished or fish.freeze or not fish.is_visible_in_tree():
			continue
		var push := lift(fish.global_position, fish.linear_velocity, fish.buoyancy, delta)
		if push != Vector3.ZERO:
			fish.apply_push(push)


## The velocity change (m/s) the column gives a fish at `at` going `velocity`
## this `delta`, with its own `buoyancy` (an upward acceleration, negative to sink).
func lift(at: Vector3, velocity: Vector3, buoyancy: float, delta: float) -> Vector3:
	var local := at - global_position
	var out := Vector2(local.x, local.z)
	if out.length() > radius or local.y > height + 1.0 or local.y < -1.0:
		return Vector3.ZERO
	var target := RISE_SPEED * clampf((height - local.y) / EASE, -0.5, 1.0)
	var push := Vector3.UP * (clampf(target - velocity.y, -LIFT * delta, LIFT * delta) - buoyancy * delta)
	if out.length() > 0.5:
		var around := Vector3(-out.y, 0.0, out.x).normalized()
		push += around * clampf(SWIRL_SPEED - velocity.dot(around), 0.0, SWIRL * delta)
		var inward := Vector3(-out.x, 0.0, -out.y).normalized()
		var draw := DRAW_SPEED * out.length() / radius
		push += inward * clampf(draw - velocity.dot(inward), 0.0, DRAW * delta)
	return push


func _bubble_mesh(size: float) -> Mesh:
	var bubble := SphereMesh.new()
	bubble.radius = size
	bubble.height = size * 2.0
	bubble.radial_segments = 12
	bubble.rings = 6
	var material := ShaderMaterial.new()  # the ball's look: a clear rim and a little refraction
	material.shader = Ball.BUBBLE_SHADER
	material.set_shader_parameter("tint", Color(0.85, 0.97, 1.0).lerp(color, 0.3))
	material.set_shader_parameter("wobble", 0.0)
	bubble.material = material
	return bubble
