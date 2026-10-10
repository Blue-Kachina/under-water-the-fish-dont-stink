class_name Ball
extends RigidBody3D
## The match ball, drawn as an air bubble. Physics values come from a
## BallSettings resource and are re-read every tick, so the tuning panel changes
## it live. A Water ball drifts with water drag and buoyancy (optionally the
## fish's); a Surface ball ignores the water and falls like Rocket League's.

const BUBBLE_SHADER := preload("res://shaders/bubble.gdshader")

## Rocket League's extra hit impulse factor by relative speed (RocketSim
## BALL_CAR_EXTRA_IMPULSE_FACTOR_CURVE: 0-500 uu/s 0.65, 2300 0.55, 4600 0.30),
## with speeds doubled to match the fish. Relative speed is capped at the last point.
const HIT_CURVE := [Vector2(0.0, 0.65), Vector2(10.0, 0.65), Vector2(46.0, 0.55), Vector2(92.0, 0.30)]
## A fish that stays in contact only gets the extra impulse once per touch, and
## at most this often while bumping repeatedly.
const HIT_COOLDOWN := 0.1

signal touched(by: Node3D, hit_speed: float)

@export var settings: BallSettings
## Source of the water settings when settings.inherit_water is on.
@export var fish: FishController

var popped := false
var speed := 0.0

var _shape := SphereShape3D.new()
var _collision := CollisionShape3D.new()
var _visual := MeshInstance3D.new()
var _material := ShaderMaterial.new()
var _trail := CPUParticles3D.new()
var _radius := -1.0
var _reset_queued := false
var _spawn_position := Vector3.ZERO
# Both velocities as they were at the end of last tick, before the collision
# that this tick's contacts report was resolved: what the hit speed measures.
var _last_velocity := Vector3.ZERO
var _fish_velocity := Vector3.ZERO
var _touching_fish := false
var _hit_cooldown := 0.0


func _ready() -> void:
	if settings == null:
		settings = BallSettings.new()
	gravity_scale = 0.0
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	physics_material_override = PhysicsMaterial.new()
	_spawn_position = global_position

	_collision.shape = _shape
	add_child(_collision)

	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_material.shader = BUBBLE_SHADER
	_visual.mesh = sphere
	_visual.material_override = _material
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)

	_build_trail()
	_apply_settings()


## Teleport to `at`, stopped, and bring the ball back if it was popped.
func respawn(at: Vector3) -> void:
	_spawn_position = at
	_reset_queued = true
	popped = false
	visible = true
	freeze = false
	_collision.set_deferred("disabled", false)


## Burst after a goal: hidden, frozen and non-solid until respawn().
func pop() -> void:
	popped = true
	visible = false
	_trail.emitting = false
	freeze = true
	_collision.set_deferred("disabled", true)


func _physics_process(_delta: float) -> void:
	_apply_settings()


func _process(_delta: float) -> void:
	# Stretch a little along the direction of travel, like a bubble in a current.
	var velocity := linear_velocity
	var stretch := clampf(velocity.length() / maxf(settings.max_speed, 1.0), 0.0, 1.0) * 0.25
	_material.set_shader_parameter("stretch_dir", velocity.normalized() if velocity.length() > 0.1 else Vector3.UP)
	_material.set_shader_parameter("stretch", stretch)
	_trail.emitting = not popped and speed > 12.0


func _apply_settings() -> void:
	if not is_equal_approx(settings.radius, _radius):
		_radius = settings.radius
		_shape.radius = _radius
		_visual.scale = Vector3.ONE * _radius
		_trail.emission_sphere_radius = _radius * 0.8
	mass = settings.mass
	physics_material_override.bounce = settings.bounciness
	physics_material_override.friction = settings.friction


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dt := state.step
	if _reset_queued:
		_reset_queued = false
		state.transform = Transform3D(Basis.IDENTITY, _spawn_position)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_last_velocity = Vector3.ZERO
		_touching_fish = false
		reset_physics_interpolation.call_deferred()
		return

	var velocity := state.linear_velocity
	var spin := state.angular_velocity
	velocity = _apply_hits(state, velocity)

	if settings.ball_type == BallSettings.BallType.SURFACE:
		velocity *= exp(-settings.air_drag * dt)
		velocity.y -= settings.gravity * dt
		spin *= exp(-settings.spin_drag * dt)
	else:
		var inherit := settings.inherit_water and is_instance_valid(fish)
		var linear_drag := fish.linear_drag if inherit else settings.linear_drag
		var angular_drag := fish.angular_drag if inherit else settings.angular_drag
		var buoyancy := fish.buoyancy if inherit else settings.buoyancy
		velocity *= exp(-linear_drag * dt)
		velocity.y += buoyancy * dt
		spin *= exp(-angular_drag * dt)

	state.linear_velocity = velocity.limit_length(settings.max_speed)
	state.angular_velocity = spin.limit_length(settings.max_angular_speed)
	speed = state.linear_velocity.length()
	_last_velocity = state.linear_velocity
	if is_instance_valid(fish):
		_fish_velocity = fish.linear_velocity


## Rocket League's extra impulse on a fresh touch from the fish (RocketSim
## Ball::OnHit): push along fish -> ball with the world-vertical part and the
## fish's forward part of that direction scaled down, by the relative speed
## before the touch.
func _apply_hits(state: PhysicsDirectBodyState3D, velocity: Vector3) -> Vector3:
	_hit_cooldown -= state.step
	var hitter: FishController = null
	for i in state.get_contact_count():
		var collider := state.get_contact_collider_object(i)
		if collider is FishController:
			hitter = collider
			break
	var fresh := hitter != null and not _touching_fish
	_touching_fish = hitter != null
	if not fresh:
		return velocity

	var hit_speed := minf((_last_velocity - _fish_velocity).length(), HIT_CURVE[-1].x)
	touched.emit(hitter, hit_speed)
	if not settings.rl_hit_impulse or _hit_cooldown > 0.0 or hit_speed <= 0.0:
		return velocity
	_hit_cooldown = HIT_COOLDOWN

	var forward := -hitter.global_basis.orthonormalized().z
	var direction := state.transform.origin - hitter.global_position
	direction.y *= settings.hit_up_scale  # world up, as in RL
	direction = direction.normalized()
	direction = (direction - forward * direction.dot(forward) * (1.0 - settings.hit_forward_scale)).normalized()
	return velocity + direction * hit_speed * _hit_factor(hit_speed) * settings.hit_force_scale


func _hit_factor(hit_speed: float) -> float:
	for i in range(1, HIT_CURVE.size()):
		var a: Vector2 = HIT_CURVE[i - 1]
		var b: Vector2 = HIT_CURVE[i]
		if hit_speed <= b.x:
			return lerpf(a.y, b.y, (hit_speed - a.x) / (b.x - a.x))
	return HIT_CURVE[-1].y


func _build_trail() -> void:
	var bubble := SphereMesh.new()
	bubble.radius = 0.08
	bubble.height = 0.16
	bubble.radial_segments = 8
	bubble.rings = 4
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.85, 0.97, 1.0, 0.5)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bubble.material = material

	_trail.mesh = bubble
	_trail.emitting = false
	_trail.amount = 64
	_trail.lifetime = 1.2
	_trail.local_coords = false
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail.direction = Vector3.UP
	_trail.spread = 180.0
	_trail.gravity = Vector3(0, 2.0, 0)
	_trail.initial_velocity_min = 0.2
	_trail.initial_velocity_max = 1.0
	_trail.scale_amount_min = 0.5
	_trail.scale_amount_max = 1.6
	add_child(_trail)
