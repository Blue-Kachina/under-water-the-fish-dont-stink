class_name GreekFire
extends FishAttack
## Greek Fire Trail (planning_unnatural.md §7), a steady weapon (FishAttack),
## the Lionfish's own: burning patches left
## behind as the fish swims, one every spacing() m. Zombies in a patch burn
## (damage over time, BURN_TICK at a time, proc coefficient fire_proc). Its
## facets (Weapons): burn damage, patch life, patch size, a denser trail, more
## patches out. Milestones: at the first, a zombie that burns to death leaves a
## patch where it fell; at the second, the trail fans out three wide; at the
## third, every FLARE_EVERY s each patch flares FLARE_REACH times as wide for
## FLARE_BURN s of burn at once; at the fourth, the patches creep toward the
## nearest zombie within CREEP_REACH at CREEP_SPEED m/s.

const BURN_TICK := 0.25
const FLARE_EVERY := 3.0
const FLARE_REACH := 1.4
const FLARE_BURN := 0.5
const CREEP_REACH := 5.0
const CREEP_SPEED := 1.0
## The fan's side patches sit this many patch radii off the middle one.
const FAN_SPREAD := 1.6
## A burnt zombie's patch: at most one this often (s), so a crowd burning
## doesn't carpet the sea.
const KILL_PATCH_GAP := 0.15

var patches: Array[FirePatch] = []
var _last_drop := Vector3.INF
var _burn_left := BURN_TICK
var _kill_patch_left := 0.0
var _flare_left := FLARE_EVERY
## Flares so far (the third milestone), for the probes.
var flares := 0


## It reads its own facets, and has no attacks to count (FishAttack).
func own_facets() -> bool:
	return true


func counts_uses() -> bool:
	return false


func spacing() -> float:
	return powers.fire_spacing / (1.0 + facet("density")) / attack_speed


func radius() -> float:
	return powers.fire_radius * (1.0 + facet("radius")) * size_scale


func life() -> float:
	return (powers.fire_life + facet("life")) * duration_scale


func dps() -> float:
	return powers.fire_dps * (1.0 + facet("burn"))


func damage() -> float:
	return dps()


func max_patches() -> int:
	return powers.fire_max_patches + facet_count("patches")


func _work(delta: float) -> void:
	# Burnt-out patches go first (by index: a freed one in a typed loop or
	# erase errors).
	for k in range(patches.size() - 1, -1, -1):
		if not is_instance_valid(patches[k]):
			patches.remove_at(k)
	_kill_patch_left -= delta
	var at := fish.global_position
	if fish.speed > 2.0 and (_last_drop == Vector3.INF or at.distance_to(_last_drop) >= spacing()):
		var back := at - fish.swim_velocity().normalized() * 0.8
		_drop(back)
		if milestone(2):
			var side := fish.global_basis.x * radius() * FAN_SPREAD
			_drop(back + side)
			_drop(back - side)
		_last_drop = at
	if milestone(4):
		_creep(delta)
	if milestone(3):
		_flare_left -= delta
		if _flare_left <= 0.0:
			_flare_left = FLARE_EVERY
			_flare()
	_burn_left -= delta
	if _burn_left > 0.0:
		return
	_burn_left += BURN_TICK
	var burn := dps() * BURN_TICK
	# Every patch's zombies in one area hit (one in two patches burns twice, as before).
	var burning := PackedInt32Array()
	for patch in patches:
		burning.append_array(run.horde.query_sphere(patch.global_position, patch.radius))
	strike_area(burning, burn, Vector3.INF, powers.fire_proc)


## The first milestone: a zombie burnt to death leaves a patch where it fell.
func on_kill(at: Vector3, source: String) -> void:
	if source == source() and milestone(1) and _kill_patch_left <= 0.0:
		_kill_patch_left = KILL_PATCH_GAP
		_drop(at)


## The third milestone: every patch flares wide, FLARE_BURN s of burn at once.
func _flare() -> void:
	flares += 1
	var burn := dps() * FLARE_BURN
	var flared := PackedInt32Array()
	for patch in patches:
		if not is_instance_valid(patch):
			continue
		var reach := patch.radius * FLARE_REACH
		PowerupFx.ring(run, patch.global_position, reach, tint(), Vector3.UP, 0.4)
		flared.append_array(run.horde.query_sphere(patch.global_position, reach))
	var ups := PackedVector3Array()
	ups.resize(flared.size())
	ups.fill(Vector3.UP)
	strike_area(flared, burn, Vector3.INF, powers.fire_proc, ups)


## The fourth: the patches creep toward the nearest zombie close by (looked
## for each burn tick, so not every patch searches every physics tick).
func _creep(delta: float) -> void:
	var look := _burn_left - delta <= 0.0
	for patch in patches:
		if not is_instance_valid(patch):
			continue
		if look:
			var target := run.horde.nearest_in_cone(patch.global_position, Vector3.FORWARD, CREEP_REACH, -1.0)
			patch.creep_to = run.horde.enemy_position(target) if target >= 0 else Vector3.INF
		if patch.creep_to == Vector3.INF:
			continue
		var to := patch.creep_to - patch.global_position
		if to.length() > 0.2:
			patch.global_position += to.normalized() * minf(CREEP_SPEED * delta, to.length())


func _drop(at: Vector3) -> void:
	while patches.size() >= max_patches():
		var oldest: Variant = patches.pop_front()  # untyped: a burnt-out one is a freed instance
		if is_instance_valid(oldest):
			oldest.queue_free()
	var patch := FirePatch.new()
	patch.radius = radius()
	patch.lifetime = life()
	patch.position = at
	run.add_child(patch)
	patches.append(patch)
	Sfx.loop_for("pw/greek_fire_loop", patch)


func on_removed() -> void:
	for patch in patches:
		if is_instance_valid(patch):
			patch.queue_free()
	patches.clear()


## A lantern hung off the tail, its flame flickering.
func make_worn() -> Node3D:
	var lantern := Node3D.new()
	lantern.name = "Lantern"
	lantern.position = Vector3(0.0, fish.hitbox_height * 0.35, fish.hitbox_length * 0.45)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.55, 0.4, 0.15)
	brass.metallic = 0.8
	brass.roughness = 0.35
	var parts := WornKit.lantern()
	lantern.add_child(worn_mesh(parts[0], brass, Vector3.ZERO))
	lantern.add_child(worn_mesh(parts[1], worn_material(2.2), Vector3.ZERO))
	var light := OmniLight3D.new()
	light.light_color = tint()
	light.light_energy = 0.8
	light.omni_range = 2.5
	light.position.y = 0.07
	lantern.add_child(light)
	lantern.ready.connect(func() -> void:
		var flicker := lantern.create_tween().set_loops()
		flicker.tween_property(light, "light_energy", 1.3, 0.12)
		flicker.tween_property(light, "light_energy", 0.6, 0.17))
	return lantern


## One burning patch: tongues of flame licking up through the patch, white-hot
## to orange to a dull red as they rise and go out. They fade away close to
## the camera (it follows from behind, so the trail runs right past it), and
## the patch stops feeding them a flame's life before it's gone.
class FirePatch extends Node3D:
	## A flame's life (s).
	const FLAME_LIFE := 0.7
	## A new patch catches a moment after it's dropped, so it isn't burning
	## between the camera and the fish while the fish is still right on it.
	## (It burns zombies from the start.)
	const LIGHT_AFTER := 0.3

	var radius := 1.6
	var lifetime := 2.0
	var age := 0.0
	## Where it's creeping to (the fourth milestone; INF: nowhere).
	var creep_to := Vector3.INF
	var _flames := CPUParticles3D.new()

	static var _mesh: QuadMesh
	static var _ramp: Gradient
	static var _scale: Curve

	func _ready() -> void:
		var spread := radius / 1.6  # the flames' sizes were set for the default radius
		_flames.mesh = _flame_mesh()
		_flames.amount = 12
		_flames.emitting = false  # see LIGHT_AFTER
		_flames.lifetime = FLAME_LIFE
		_flames.lifetime_randomness = 0.4
		_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_flames.emission_sphere_radius = radius * 0.55
		_flames.direction = Vector3.UP
		_flames.spread = 20.0
		_flames.initial_velocity_min = 0.3
		_flames.initial_velocity_max = 0.9
		_flames.gravity = Vector3(0.0, 1.6, 0.0)  # flames rise
		_flames.angle_min = -12.0
		_flames.angle_max = 12.0
		_flames.scale_amount_min = 0.7 * spread
		_flames.scale_amount_max = 1.3 * spread
		_flames.scale_amount_curve = _scale
		_flames.color_ramp = _ramp
		_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_flames)

	func _process(delta: float) -> void:
		age += delta
		if age >= lifetime:
			queue_free()
		elif age >= lifetime - FLAME_LIFE:
			_flames.emitting = false  # the last flames burn out with the patch
		else:
			_flames.emitting = age >= LIGHT_AFTER

	## The flame quad, its material and ramps, made once and shared.
	static func _flame_mesh() -> QuadMesh:
		if _mesh:
			return _mesh
		var glow := Gradient.new()
		glow.set_color(0, Color(1, 1, 1, 1))
		glow.set_color(1, Color(1, 1, 1, 0))
		glow.add_point(0.45, Color(1, 1, 1, 0.55))
		var texture := GradientTexture2D.new()
		texture.gradient = glow
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.55)  # hot low in the tongue
		texture.fill_to = Vector2(0.5, 0.0)
		texture.width = 64
		texture.height = 64
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = texture
		FxKit.fade_near(material)  # gone close to the camera (it follows from behind)
		_mesh = QuadMesh.new()
		_mesh.size = Vector2(0.45, 0.85)  # taller than wide: a tongue
		_mesh.material = material
		_ramp = Gradient.new()
		_ramp.set_color(0, Color(1.0, 0.95, 0.7, 0.0))
		_ramp.set_color(1, Color(0.25, 0.05, 0.03, 0.0))
		# Soft: they're added on, and overlapping patches would burn out to white.
		_ramp.add_point(0.1, Color(1.0, 0.8, 0.4, 0.6))
		_ramp.add_point(0.4, Color(1.0, 0.42, 0.08, 0.5))
		_ramp.add_point(0.75, Color(0.7, 0.12, 0.04, 0.22))
		_scale = Curve.new()
		_scale.add_point(Vector2(0.0, 0.4))
		_scale.add_point(Vector2(0.3, 1.0))
		_scale.add_point(Vector2(1.0, 0.25))
		return _mesh
