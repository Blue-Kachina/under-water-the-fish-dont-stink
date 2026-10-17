class_name GreekFire
extends Powerup
## Greek Fire Trail (planning_unnatural.md §7): burning patches left behind as
## the fish swims, one every fire_spacing m. Zombies in a patch burn (damage
## over time, BURN_TICK at a time, proc coefficient fire_proc). More stacks:
## longer-lived patches, more burn.

const BURN_TICK := 0.25

var patches: Array[FirePatch] = []
var _last_drop := Vector3.INF
var _burn_left := BURN_TICK


func on_tick(delta: float) -> void:
	var at := fish.global_position
	if fish.speed > 2.0 and (_last_drop == Vector3.INF or at.distance_to(_last_drop) >= settings.fire_spacing):
		_drop(at - fish.swim_velocity().normalized() * 0.8)
		_last_drop = at
	_burn_left -= delta
	if _burn_left > 0.0:
		return
	_burn_left += BURN_TICK
	var burn := (settings.fire_dps + settings.fire_dps_per_stack * (stacks - 1)) * BURN_TICK
	for patch in patches.duplicate():
		if not is_instance_valid(patch):
			patches.erase(patch)
			continue
		for i in run.horde.query_sphere(patch.global_position, patch.radius):
			run.hit(i, burn, fish, id, Vector3.ZERO, settings.fire_proc, [id])


func _drop(at: Vector3) -> void:
	while patches.size() >= settings.fire_max_patches:
		var oldest: FirePatch = patches.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var patch := FirePatch.new()
	patch.radius = settings.fire_radius
	patch.lifetime = settings.fire_life + settings.fire_life_per_stack * (stacks - 1)
	patch.position = at
	run.add_child(patch)
	patches.append(patch)


func on_removed() -> void:
	for patch in patches:
		if is_instance_valid(patch):
			patch.queue_free()
	patches.clear()


## One burning patch: a flickering ball of fire that fades out.
class FirePatch extends Node3D:
	var radius := 1.6
	var lifetime := 2.0
	var age := 0.0
	var _material := StandardMaterial3D.new()
	var _ball := MeshInstance3D.new()

	func _ready() -> void:
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_material.albedo_color = Color(1.0, 0.45, 0.1, 0.6)
		sphere.material = _material
		_ball.mesh = sphere
		_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ball)

	func _process(delta: float) -> void:
		age += delta
		if age >= lifetime:
			queue_free()
			return
		var fade := 1.0 - clampf((age - lifetime * 0.7) / (lifetime * 0.3), 0.0, 1.0)
		var flicker := 0.85 + 0.15 * sin(age * 23.0 + position.x)
		_ball.scale = Vector3(radius, radius * 0.6, radius) * flicker * clampf(age / 0.15, 0.3, 1.0)
		_material.albedo_color = Color(1.0, 0.4 + 0.15 * flicker, 0.1, 0.55 * fade)
