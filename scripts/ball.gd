class_name Ball
extends RigidBody3D
## The match ball, drawn as an air bubble. Physics values come from a
## BallSettings resource and are re-read every tick, so the tuning panel changes
## it live. A Water ball drifts with water drag and buoyancy (optionally the
## fish's); a Surface ball ignores the water and falls like Rocket League's.

const BUBBLE_SHADER := preload("res://shaders/bubble.gdshader")

## Rocket League's extra hit impulse factor by relative speed (RocketSim
## BALL_CAR_EXTRA_IMPULSE_FACTOR_CURVE: 0-500 uu/s 0.65, 2300 0.55, 4600 0.30),
## in m/s (1 uu = 1 cm). Relative speed is capped at the last point.
const HIT_CURVE := [Vector2(0.0, 0.65), Vector2(5.0, 0.65), Vector2(23.0, 0.55), Vector2(46.0, 0.30)]
## A fish that stays in contact only gets the extra impulse once per touch, and
## at most this often while bumping repeatedly.
const HIT_COOLDOWN := 0.1
## Fish-ball contact, as RL's car-ball contact (RocketSim RLConst.h): no bounce
## (CARBALL_COLLISION_RESTITUTION 0) and very grippy (CARBALL_COLLISION_FRICTION).
const CARBALL_FRICTION := 2.0
## A fish this close counts as touching, so contact doesn't flicker on and off.
const CONTACT_MARGIN := 0.02
## Overlap allowed before the ball is pushed back out of the fish.
const PENETRATION_SLOP := 0.005
## Contact solver passes per tick (Bullet's default).
const SOLVER_ITERATIONS := 10

signal touched(by: Node3D, hit_speed: float)

@export var settings: BallSettings
## Source of the water settings when settings.inherit_water is on.
@export var fish: FishController

var popped := false
var speed := 0.0
## True from respawn() until the teleport happens on the next physics step.
## Until then global_position is still the old spot (e.g. inside a goal), so
## goal checks should skip the ball.
var respawn_pending: bool:
	get:
		return _reset_queued
## A kickoff ball holding still until its first touch (see respawn()).
var waiting_for_touch := false

var _shape := SphereShape3D.new()
var _collision := CollisionShape3D.new()
var _visual := MeshInstance3D.new()
var _material := ShaderMaterial.new()
var _trail := CPUParticles3D.new()
var _indicators := BallIndicators.new()
var _radius := -1.0
var _reset_queued := false
var _spawn_position := Vector3.ZERO
# Velocity handed to the physics step, this tick and the one before (see
# velocity_for_last_step): the ball's motion before the collision that this
# tick's contacts report was resolved.
var _step_velocity := Vector3.ZERO
var _prev_step_velocity := Vector3.ZERO
var _step_frame := -1
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
	# The physics engine would bounce the fish and ball off each other with both
	# bodies' bounciness and the fish's driving friction (none). RL's car-ball
	# contact is resolved here instead (_resolve_fish_contact); the engine still
	# handles the ball against the arena.
	if fish:
		add_collision_exception_with(fish)

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
	_visual.layers = BallIndicators.BALL_LAYER  # the indicator rings don't paint the ball
	add_child(_visual)

	_build_trail()
	_indicators.ball = self
	add_child(_indicators)
	_apply_settings()


## Teleport to `at`, stopped, and bring the ball back if it was popped. A
## kickoff ball waits in place, unaffected by gravity, until a fish touches it
## (RL's kickoff rule), if settings.kickoff_float is on.
func respawn(at: Vector3, kickoff := false) -> void:
	_spawn_position = at
	_reset_queued = true
	waiting_for_touch = kickoff and settings.kickoff_float and settings.ball_type == BallSettings.BallType.SURFACE
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


func _physics_process(delta: float) -> void:
	_apply_settings()
	_indicators.update(delta)


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
	# Like RL (RocketSim Ball::_FinishPhysicsTick), speed and spin are capped
	# after each step, so a step runs at the cap plus that tick's acceleration.
	state.linear_velocity = state.linear_velocity.limit_length(settings.max_speed)
	state.angular_velocity = state.angular_velocity.limit_length(settings.max_angular_speed)
	if _reset_queued:
		_reset_queued = false
		state.transform = Transform3D(Basis.IDENTITY, _spawn_position)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_step_velocity = Vector3.ZERO
		_prev_step_velocity = Vector3.ZERO
		_touching_fish = false
		reset_physics_interpolation.call_deferred()
		return

	var velocity := state.linear_velocity
	var spin := state.angular_velocity
	var contact := _fish_contact(state.transform.origin)
	if waiting_for_touch:
		if contact.is_empty() or contact.depth <= 0.0:
			# Held in place: nothing but a fish wakes it (RL's kickoff ball).
			state.linear_velocity = Vector3.ZERO
			state.angular_velocity = Vector3.ZERO
			_prev_step_velocity = _step_velocity
			_step_velocity = Vector3.ZERO
			_step_frame = Engine.get_physics_frames()
			return
		waiting_for_touch = false
	var before := velocity
	_hit_cooldown -= dt

	if settings.ball_type == BallSettings.BallType.SURFACE:
		# Gravity, then drag as Bullet's linear damping (what RL uses): speed x (1 - air_drag) per second.
		velocity.y -= settings.gravity * dt
		velocity *= pow(1.0 - settings.air_drag, dt)
		spin *= exp(-settings.spin_drag * dt)
	else:
		var inherit := settings.inherit_water and is_instance_valid(fish)
		var linear_drag := fish.linear_drag if inherit else settings.linear_drag
		var angular_drag := fish.angular_drag if inherit else settings.angular_drag
		velocity *= exp(-linear_drag * dt)
		velocity.y += _buoyancy() * dt
		spin *= exp(-angular_drag * dt)

	# After gravity, as a physics engine's contact solver runs after the forces.
	if contact.is_empty():
		_touching_fish = false
	else:
		var result := _resolve_fish_contact(state, contact, velocity, spin, before)
		velocity = result[0]
		spin = result[1]

	state.linear_velocity = velocity
	state.angular_velocity = spin
	speed = minf(velocity.length(), settings.max_speed)
	_prev_step_velocity = _step_velocity
	_step_velocity = velocity
	_step_frame = Engine.get_physics_frames()


## The velocity the ball moved with during the physics step that just ran. For
## contact maths in the fish's _integrate_forces, which can run before or after
## this one's in the same tick.
func velocity_for_last_step() -> Vector3:
	return _prev_step_velocity if _step_frame == Engine.get_physics_frames() else _step_velocity


## A Water ball's buoyancy: the fish's when inheriting, otherwise its own.
func _buoyancy() -> float:
	return fish.buoyancy if settings.inherit_water and is_instance_valid(fish) else settings.buoyancy


## The nearest point where the fish's collision boxes (hitbox and belly) touch
## the ball at `centre`: {fish, normal (fish -> ball), depth (overlap, negative
## while still just apart)}, or empty when the fish isn't touching.
func _fish_contact(centre: Vector3) -> Dictionary:
	if not is_instance_valid(fish) or popped:
		return {}
	var best := {}
	for child in fish.get_children():
		var shape_node := child as CollisionShape3D
		# The fish's box hitbox: disabled for the engine (the arena meets a
		# bevelled hull), but it's the shape the ball is checked against.
		if shape_node == null or not shape_node.shape is BoxShape3D:
			continue
		var xform := shape_node.global_transform
		var half: Vector3 = (shape_node.shape as BoxShape3D).size / 2.0
		var local := xform.affine_inverse() * centre
		var closest := local.clamp(-half, half)
		var normal: Vector3
		var depth: float
		if closest == local:
			# Centre inside the box: out through the nearest face.
			var room := half - local.abs()
			var axis := 0 if room.x <= room.y and room.x <= room.z else (1 if room.y <= room.z else 2)
			var local_normal := Vector3.ZERO
			local_normal[axis] = signf(local[axis]) if local[axis] != 0.0 else 1.0
			normal = (xform.basis * local_normal).normalized()
			depth = _radius + room[axis]
		else:
			var offset := centre - xform * closest
			var distance := offset.length()
			normal = offset / distance
			depth = _radius - distance
		if depth > -CONTACT_MARGIN and (best.is_empty() or depth > best.depth):
			best = {"fish": fish, "normal": normal, "depth": depth}
	return best


## One tick of Rocket League's car-ball contact against the fish, worked out
## here as a physics engine would: an impulse at the contact point that stops
## the two closing (restitution 0) and grips sideways up to friction 2.0, with
## each body's mass and spin inertia. So a glancing touch spins the ball, the
## ball can climb the fish's nose, and the fish recoils by how heavy it is (6x
## the ball). The fish gets its half via FishController.apply_ball_impulse. A
## fresh touch also gets RL's extra impulse (RocketSim Ball::OnHit): a push
## along the line from the fish's centre of mass to the ball, with its
## world-vertical part and the fish's forward part scaled down, by the relative
## speed before the touch. Returns [velocity, spin].
func _resolve_fish_contact(state: PhysicsDirectBodyState3D, contact: Dictionary, velocity: Vector3, spin: Vector3, before: Vector3) -> Array:
	var hitter: FishController = contact.fish
	var normal: Vector3 = contact.normal
	var depth: float = contact.depth
	var centre := state.transform.origin
	var point := centre - normal * _radius
	var r_ball := point - centre
	var r_fish := point - hitter.global_transform * hitter.center_of_mass
	var fish_velocity := hitter.linear_velocity
	var fish_spin := hitter.angular_velocity
	var inv_mass_ball := 1.0 / mass
	var inv_mass_fish := 1.0 / hitter.mass
	var inv_inertia_ball := 1.0 / (0.4 * mass * _radius * _radius)  # solid sphere
	var inv_inertia_fish := hitter.inverse_inertia_world()

	# Speculative: a ball still just apart may close the gap this tick, but no more.
	var allowed := maxf(-depth, 0.0) / state.step
	var normal_mass := _inverse_effective_mass(normal, r_ball, r_fish, inv_mass_ball, inv_mass_fish, inv_inertia_ball, inv_inertia_fish)
	# Sequential impulses, as Bullet's solver: the push and the grip each change
	# how the bodies move and turn at the contact, which changes what the other
	# needs (a hit makes the fish pitch, and its face then rubs spin onto the ball).
	var pushed := 0.0
	var gripped := Vector3.ZERO
	var fish_v := fish_velocity
	var fish_w := fish_spin
	for i in SOLVER_ITERATIONS:
		var relative := (velocity + spin.cross(r_ball)) - (fish_v + fish_w.cross(r_fish))
		var push := maxf(pushed - (relative.dot(normal) + allowed) / normal_mass, 0.0) - pushed
		pushed += push
		var impulse := normal * push
		relative += _contact_velocity_change(impulse, normal, r_ball, r_fish, inv_mass_ball, inv_mass_fish, inv_inertia_ball, inv_inertia_fish)
		var slide := relative - normal * relative.dot(normal)
		if slide.length() > 0.00001:
			var tangent := slide.normalized()
			var stop := slide.length() / _inverse_effective_mass(tangent, r_ball, r_fish, inv_mass_ball, inv_mass_fish, inv_inertia_ball, inv_inertia_fish)
			var total := (gripped - tangent * stop).limit_length(CARBALL_FRICTION * pushed)
			impulse += total - gripped
			gripped = total
		velocity += impulse * inv_mass_ball
		spin += r_ball.cross(impulse) * inv_inertia_ball
		fish_v -= impulse * inv_mass_fish
		fish_w -= inv_inertia_fish * r_fish.cross(impulse)
	if pushed > 0.0 or gripped != Vector3.ZERO:
		hitter.apply_ball_impulse(-(normal * pushed + gripped), point)
	if depth > PENETRATION_SLOP:
		state.transform = Transform3D(state.transform.basis, centre + normal * (depth - PENETRATION_SLOP))

	var fresh := not _touching_fish and depth > 0.0
	if depth > 0.0:
		_touching_fish = true
	if not fresh:
		return [velocity, spin]
	var hit_speed := minf((before - fish_velocity).length(), HIT_CURVE[-1].x)
	touched.emit(hitter, hit_speed)
	if not settings.rl_hit_impulse or _hit_cooldown > 0.0 or hit_speed <= 0.0:
		return [velocity, spin]
	_hit_cooldown = HIT_COOLDOWN

	var forward := -hitter.global_basis.orthonormalized().z
	var direction := centre - hitter.global_transform * hitter.center_of_mass
	direction.y *= settings.hit_up_scale  # world up, as in RL
	direction = direction.normalized()
	direction = (direction - forward * direction.dot(forward) * (1.0 - settings.hit_forward_scale)).normalized()
	velocity += direction * hit_speed * _hit_factor(hit_speed) * settings.hit_force_scale
	return [velocity, spin]


## How an `impulse` (on the ball, the opposite on the fish) changes the
## contact point's relative velocity, ball side minus fish side. Only the
## normal part is needed mid-iteration, so this is exact for pushes along `normal`.
func _contact_velocity_change(impulse: Vector3, normal: Vector3, r_ball: Vector3, r_fish: Vector3, inv_mass_ball: float,
		inv_mass_fish: float, inv_inertia_ball: float, inv_inertia_fish: Basis) -> Vector3:
	return impulse * (inv_mass_ball + inv_mass_fish) \
			+ (r_ball.cross(impulse) * inv_inertia_ball).cross(r_ball) \
			+ (inv_inertia_fish * r_fish.cross(impulse)).cross(r_fish)


## 1 / (the effective mass the contact sees along `dir`): both bodies' masses
## plus how much each would rather turn than move at that point.
func _inverse_effective_mass(dir: Vector3, r_ball: Vector3, r_fish: Vector3, inv_mass_ball: float, inv_mass_fish: float,
		inv_inertia_ball: float, inv_inertia_fish: Basis) -> float:
	return inv_mass_ball + inv_mass_fish \
			+ dir.dot((r_ball.cross(dir) * inv_inertia_ball).cross(r_ball)) \
			+ dir.dot((inv_inertia_fish * r_fish.cross(dir)).cross(r_fish))


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
