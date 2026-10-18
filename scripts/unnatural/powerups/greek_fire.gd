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
	# Burnt-out patches go (by index: erasing a freed one from a typed array errors).
	for k in range(patches.size() - 1, -1, -1):
		if not is_instance_valid(patches[k]):
			patches.remove_at(k)
	for patch in patches:
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


## A lantern hung off the tail, its flame flickering.
func make_worn() -> Node3D:
	var lantern := Node3D.new()
	lantern.name = "Lantern"
	lantern.position = Vector3(0.0, fish.hitbox_height * 0.35, fish.hitbox_length * 0.45)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.55, 0.4, 0.15)
	brass.metallic = 0.8
	brass.roughness = 0.35
	var cap := CylinderMesh.new()
	cap.top_radius = 0.02
	cap.bottom_radius = 0.09
	cap.height = 0.08
	cap.radial_segments = 8
	lantern.add_child(worn_mesh(cap, brass, Vector3(0.0, 0.2, 0.0)))
	var glass := CylinderMesh.new()
	glass.top_radius = 0.07
	glass.bottom_radius = 0.07
	glass.height = 0.2
	glass.radial_segments = 8
	lantern.add_child(worn_mesh(glass, worn_material(2.2), Vector3(0.0, 0.07, 0.0)))
	var base := CylinderMesh.new()
	base.top_radius = 0.09
	base.bottom_radius = 0.09
	base.height = 0.04
	base.radial_segments = 8
	lantern.add_child(worn_mesh(base, brass, Vector3(0.0, -0.05, 0.0)))
	var light := OmniLight3D.new()
	light.light_color = color(id)
	light.light_energy = 0.8
	light.omni_range = 2.5
	light.position.y = 0.07
	lantern.add_child(light)
	lantern.ready.connect(func() -> void:
		var flicker := lantern.create_tween().set_loops()
		flicker.tween_property(light, "light_energy", 1.3, 0.12)
		flicker.tween_property(light, "light_energy", 0.6, 0.17))
	return lantern


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
