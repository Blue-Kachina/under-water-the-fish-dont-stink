class_name WhirlpoolCharm
extends Powerup
## Whirlpool Charm (planning_unnatural.md §7b, uncommon): a spiral shell. A
## kill has charm_chance (more charm_chance_per_stack a stack) to open a little
## whirlpool where it fell for charm_time s: it pulls the zombies within
## charm_radius m in (charm_pull m/s) and grinds them, charm_dps a second (more
## charm_dps_per_stack a stack). At most charm_max out at once (a whirlpool's
## own kills can open more).

## Whirlpools opened, for the probes; those out now.
var opened := 0
var _out: Array[Vortex] = []


func chance() -> float:
	return soft_chance(settings.charm_chance + settings.charm_chance_per_stack * extra())


func on_kill(at: Vector3, _source: String) -> void:
	_out.assign(_out.filter(func(vortex: Vortex) -> bool: return is_instance_valid(vortex)))
	if _out.size() >= settings.charm_max or not roll(chance()):
		return
	open_at(at)


func open_at(at: Vector3) -> Vortex:
	var vortex := Vortex.new()
	vortex.owner_charm = self
	vortex.radius = settings.charm_radius * size_scale()
	vortex.life = settings.charm_time * duration_scale()
	vortex.dps = settings.charm_dps + settings.charm_dps_per_stack * extra()
	vortex.pull = settings.charm_pull
	vortex.tint = color(id)
	run.add_child(vortex)
	vortex.global_position = at
	_out.append(vortex)
	opened += 1
	Sfx.play("pw/tsunami_wave")
	return vortex


func on_removed() -> void:
	for vortex in _out:
		if is_instance_valid(vortex):
			vortex.queue_free()
	_out.clear()


## A spiral shell on a cord.
func make_worn() -> Node3D:
	var charm := Node3D.new()
	charm.name = "WhirlpoolCharm"
	charm.position = Vector3(0.0, -fish.hitbox_height * 0.4, -fish.hitbox_length * 0.2)
	var skin := worn_material(0.6)
	var shell := TorusMesh.new()
	shell.inner_radius = 0.025
	shell.outer_radius = 0.07
	shell.rings = 12
	shell.ring_segments = 6
	charm.add_child(worn_mesh(shell, skin, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0)))
	return charm


## One whirlpool: pulls in, grinds every TICK s, spins, then fades.
class Vortex extends Node3D:
	const TICK := 0.25
	var owner_charm: WhirlpoolCharm
	var radius := 6.0
	var life := 3.0
	var dps := 30.0
	var pull := 12.0
	var tint := Color.WHITE
	var _age := 0.0
	var _tick := 0.0
	var _rings: Array[MeshInstance3D] = []
	var _material: StandardMaterial3D

	func _ready() -> void:
		_material = FxKit.glow(tint, FxKit.band())
		for n in 3:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = radius * (0.25 + n * 0.25) - 0.15
			torus.outer_radius = radius * (0.25 + n * 0.25) + 0.15
			torus.rings = 24
			torus.ring_segments = 4
			ring.mesh = torus
			ring.material_override = _material
			ring.scale = Vector3(1.0, 0.2, 1.0)
			ring.position = Vector3.UP * (n * 0.4 - 0.4)
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ring)
			_rings.append(ring)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= life or not is_instance_valid(owner_charm) or owner_charm.run == null:
			queue_free()
			return
		for n in _rings.size():
			_rings[n].rotate_y(delta * (6.0 - n * 1.5))
		var fade := minf(minf(_age / 0.25, (life - _age) / 0.4), 1.0)
		_material.albedo_color.a = 0.7 * fade
		var run := owner_charm.run
		var centre := global_position
		_tick -= delta
		var grind := _tick <= 0.0
		if grind:
			_tick += TICK
		var caught := run.horde.query_sphere(centre, radius)
		for i in caught:
			var inward := centre - run.horde.enemy_position(i)
			if inward.length_squared() > 0.04 and not run.horde.is_proxy(i):
				var swirl := Vector3.UP.cross(inward).normalized()
				run.horde.shove(i, (inward.normalized() * pull + swirl * pull * 0.5) * delta * 4.0)
		if grind and is_instance_valid(owner_charm.fish):
			run.hit_area(caught, dps * TICK, owner_charm.fish, owner_charm.id, Vector3.INF, 0.0, run.powerup_settings.fire_proc, [owner_charm.id])
