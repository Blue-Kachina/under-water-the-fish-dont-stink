class_name LeviathansCoil
extends Powerup
## Leviathan's Coil (planning_unnatural.md §7b, D13, boss: the Blood
## Leviathan's): a trail of glowing coils follows the fish, like the
## Leviathan's own body (count(): coil_segments, + per stack, coil_spacing m
## apart along the way it swam). Every coil_tick s each hurts the zombies it
## touches (coil_radius) for coil_damage, proc coefficient coil_proc. One
## MultiMesh for them all.

## Hits so far, for the probes.
var hits := 0
## Where the fish has been, newest first, coil_spacing m apart.
var trail := PackedVector3Array()
var _coils: MultiMeshInstance3D
var _tick_left := 0.0


func count() -> int:
	return settings.coil_segments + settings.coil_segments_per_stack * (stacks - 1)


func on_removed() -> void:
	if is_instance_valid(_coils):
		_coils.queue_free()
	_coils = null
	trail.clear()


func on_tick(delta: float) -> void:
	var at := fish.global_position
	if trail.is_empty():
		trail.append(at)
	elif at.distance_to(trail[0]) >= settings.coil_spacing:
		trail.insert(0, at)
	if trail.size() > count() + 1:
		trail.resize(count() + 1)
	_draw()
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = maxf(_tick_left + settings.coil_tick, 0.0)
	for k in range(1, trail.size()):
		for i in run.horde.query_sphere(trail[k], settings.coil_radius):
			hits += 1
			var push := run.horde.enemy_position(i) - trail[k]
			run.hit(i, settings.coil_damage, fish, id, push.normalized() if push.length_squared() > 0.0001 else Vector3.UP,
					settings.coil_proc, [id])


## The coils along the trail (the first spot is the fish itself, so not drawn).
func _draw() -> void:
	if not is_instance_valid(_coils):
		_coils = MultiMeshInstance3D.new()
		_coils.name = "Coils"
		_coils.top_level = true
		_coils.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_coils.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 10
		sphere.rings = 5
		sphere.material = worn_material(1.4)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = sphere
		multi.instance_count = 0
		_coils.multimesh = multi
		run.add_child(_coils)
		_coils.global_transform = Transform3D.IDENTITY
	var multi := _coils.multimesh
	var shown := maxi(trail.size() - 1, 0)
	if multi.instance_count < shown:
		multi.instance_count = maxi(shown, 8)
	multi.visible_instance_count = shown
	for k in shown:
		var size := settings.coil_radius * lerpf(0.9, 0.5, float(k) / maxf(count(), 1))
		multi.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3.ONE * size), trail[k + 1]))


## A red band round the tail, where the coils start.
func make_worn() -> Node3D:
	var ring := TorusMesh.new()
	ring.inner_radius = maxf(fish.hitbox_width, fish.hitbox_height) * 0.3
	ring.outer_radius = ring.inner_radius + 0.06
	ring.rings = 16
	ring.ring_segments = 5
	var band := worn_mesh(ring, worn_material(1.5), Vector3(0.0, 0.0, fish.hitbox_length * 0.35), Vector3(PI / 2.0, 0.0, 0.0))
	band.name = "CoilBand"
	return band
