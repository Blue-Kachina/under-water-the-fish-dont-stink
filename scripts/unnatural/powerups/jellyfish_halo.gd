class_name JellyfishHalo
extends Powerup
## Jellyfish Halo (planning_unnatural.md §7b, D14, uncommon): jellies orbit
## the fish (count(): jelly_count, + per stack) halo_radius m out, halo_spin
## turns a second. Every jelly_tick s each stings the zombies it touches
## (jelly_radius) for jelly_damage, proc coefficient jelly_proc. The jellies
## live in the world (one node for them all), not on the fish, so its strides
## don't swing them.

## Stings so far, for the probes.
var stings := 0
var _halo: Node3D
var _turn := 0.0
var _sting_left := 0.0


func count() -> int:
	return settings.jelly_count + settings.jelly_count_per_stack * (stacks - 1)


func on_stacks_changed() -> void:
	_build()


func on_removed() -> void:
	if is_instance_valid(_halo):
		_halo.queue_free()
	_halo = null


## Where jelly `k` is now.
func jelly_position(k: int) -> Vector3:
	var a := _turn + k * TAU / maxi(count(), 1)
	return fish.global_position + Vector3(cos(a), 0.15 * sin(a * 3.0 + _turn), sin(a)) * settings.halo_radius


func on_tick(delta: float) -> void:
	if not is_instance_valid(_halo):
		_build()
	_turn = fmod(_turn + settings.halo_spin * TAU * delta, TAU)
	var n := count()
	for k in mini(n, _halo.get_child_count()):
		var jelly := _halo.get_child(k) as Node3D
		jelly.global_position = jelly_position(k)
	_sting_left -= delta
	if _sting_left > 0.0:
		return
	_sting_left += settings.jelly_tick
	_sting_left = maxf(_sting_left, 0.0)
	for k in n:
		var at := jelly_position(k)
		for i in run.horde.query_sphere(at, settings.jelly_radius):
			stings += 1
			var push := run.horde.enemy_position(i) - at
			run.hit(i, settings.jelly_damage, fish, id, push.normalized() if push.length_squared() > 0.0001 else Vector3.UP,
					settings.jelly_proc, [id])


func _build() -> void:
	if not is_instance_valid(_halo):
		_halo = Node3D.new()
		_halo.name = "JellyHalo"
		_halo.top_level = true
		run.add_child(_halo)
	for child in _halo.get_children():
		child.queue_free()
		_halo.remove_child(child)
	var bell_material := StandardMaterial3D.new()
	bell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bell_material.albedo_color = Color(color(id), 0.55)
	bell_material.emission_enabled = true
	bell_material.emission = color(id)
	bell_material.emission_energy_multiplier = 1.4
	bell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bell := SphereMesh.new()
	bell.radius = 0.35
	bell.height = 0.4
	bell.is_hemisphere = true
	bell.radial_segments = 12
	bell.rings = 4
	bell.material = bell_material
	var strand := CylinderMesh.new()
	strand.top_radius = 0.02
	strand.bottom_radius = 0.005
	strand.height = 0.5
	strand.radial_segments = 4
	strand.rings = 1
	strand.material = bell_material
	for k in count():
		var jelly := Node3D.new()
		jelly.add_child(worn_mesh(bell, bell_material, Vector3.ZERO))
		for t in 4:
			var a := t * TAU / 4.0
			jelly.add_child(worn_mesh(strand, bell_material, Vector3(cos(a) * 0.15, -0.25, sin(a) * 0.15)))
		jelly.scale = Vector3.ONE * settings.jelly_radius
		_halo.add_child(jelly)
		jelly.global_position = jelly_position(k)


## A thin glowing ring over the head.
func make_worn() -> Node3D:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.14
	ring.outer_radius = 0.17
	ring.rings = 16
	ring.ring_segments = 4
	var halo := worn_mesh(ring, worn_material(1.5), Vector3(0.0, fish.hitbox_height * 0.5 + 0.2, -fish.hitbox_length * 0.15))
	halo.name = "Halo"
	return halo
