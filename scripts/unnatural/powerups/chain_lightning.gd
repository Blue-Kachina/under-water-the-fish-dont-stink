class_name ChainLightning
extends Powerup
## Chain Lightning (planning_unnatural.md §7): any hit (an attack, a battery,
## another powerup's) has a chance to start lightning that jumps from the
## zombie hit to the nearest one not yet struck, again and again, each jump
## doing lightning_damage (proc coefficient chain_proc, so it can start
## torpedoes, but never lightning again). More stacks: more chance, more jumps.

## Jumps made so far (all bolts), for the probes.
var jumps_made := 0


func chance() -> float:
	return settings.lightning_chance + settings.lightning_chance_per_stack * (stacks - 1)


func jumps() -> int:
	return settings.lightning_jumps + settings.lightning_jumps_per_stack * (stacks - 1)


func on_hit(index: int, _damage: float, _source: String, proc: float, chain: Array) -> void:
	if not roll(chance() * proc):
		return
	strike(index, chain)


## Lightning from zombie `index`, jumping jumps() times.
func strike(index: int, chain: Array) -> void:
	var horde := run.horde
	var struck := {index: true}
	var from := horde.enemy_position(index)
	var path := PackedVector3Array([from])
	var next_chain := chain + [id]
	for jump in jumps():
		var best := -1
		var best_gap := INF
		for j in horde.query_sphere(from, settings.lightning_range):
			if struck.has(j):
				continue
			var gap := horde.enemy_position(j).distance_squared_to(from)
			if gap < best_gap:
				best_gap = gap
				best = j
		if best < 0:
			break
		struck[best] = true
		var to := horde.enemy_position(best)
		path.append(to)
		jumps_made += 1
		run.hit(best, settings.lightning_damage, fish, id, (to - from).normalized(), run.powerup_settings.chain_proc, next_chain)
		from = to
	if path.size() > 1:
		var bolt := Bolt.new()
		bolt.path = path
		run.add_child(bolt)


## A jagged bolt along `path`, there for a moment.
class Bolt extends MeshInstance3D:
	const LIFE := 0.2
	var path := PackedVector3Array()
	var _age := 0.0
	var _material := StandardMaterial3D.new()

	func _ready() -> void:
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_material.albedo_color = Color(0.6, 0.9, 1.0, 1.0)
		_material.vertex_color_use_as_albedo = false
		var lines := ImmediateMesh.new()
		lines.surface_begin(Mesh.PRIMITIVE_LINES, _material)
		var dice := RandomNumberGenerator.new()
		dice.seed = path.size() * 7919 + int(path[0].x * 13.0)
		for strand in 3:
			for i in path.size() - 1:
				var a := path[i]
				var b := path[i + 1]
				var last := a
				for k in range(1, 6):
					var p := a.lerp(b, k / 5.0)
					if k < 5:
						p += Vector3(dice.randf_range(-1, 1), dice.randf_range(-1, 1), dice.randf_range(-1, 1)) * 0.35
					lines.surface_add_vertex(last)
					lines.surface_add_vertex(p)
					last = p
		lines.surface_end()
		mesh = lines
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		_material.albedo_color.a = 1.0 - _age / LIFE
