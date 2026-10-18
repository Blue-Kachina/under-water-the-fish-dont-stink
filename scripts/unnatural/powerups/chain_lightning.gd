class_name ChainLightning
extends Powerup
## Chain Lightning (planning_unnatural.md §7): any hit (an attack, a battery,
## another powerup's) has a chance to start lightning that jumps from the
## zombie hit to the nearest one not yet struck, again and again, each jump
## doing lightning_damage (proc coefficient chain_proc, so it can start
## torpedoes, but never lightning again). More stacks: more chance, more jumps.
## At most lightning_max_rate strikes a second (a short burst may go a
## little over), and at most MAX_BOLTS bolts shown at once, so a big proc
## chain stays smooth.

## Bolts shown at once, at most (past it a strike still hurts, unseen).
const MAX_BOLTS := 40

static var _bolts := 0

## Jumps made so far (all bolts), for the probes.
var jumps_made := 0
## Strikes it may make now (refilled at lightning_max_rate a second).
var _strikes_left := 0.0
var _refilled := -1.0


func chance() -> float:
	return settings.lightning_chance + settings.lightning_chance_per_stack * (stacks - 1)


func jumps() -> int:
	return settings.lightning_jumps + settings.lightning_jumps_per_stack * (stacks - 1)


func on_hit(index: int, _damage: float, _source: String, proc: float, chain: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var rate := settings.lightning_max_rate
	if _refilled < 0.0:
		_strikes_left = maxf(rate * 0.1, 1.0)
	else:
		_strikes_left = minf(_strikes_left + (now - _refilled) * rate, maxf(rate * 0.1, 1.0))
	_refilled = now
	if _strikes_left < 1.0 or not roll(chance() * proc):
		return
	_strikes_left -= 1.0
	strike(index, chain)


## Lightning from zombie `index`, jumping jumps() times.
func strike(index: int, chain: Array) -> void:
	var horde := run.horde
	var struck := {index: true}
	var from := horde.enemy_position(index)
	var path := PackedVector3Array([from])
	var next_chain := chain + [id]
	for jump in jumps():
		var best := _nearest_unstruck(from, struck)
		if best < 0:
			break
		struck[best] = true
		var to := horde.enemy_position(best)
		path.append(to)
		jumps_made += 1
		run.hit(best, settings.lightning_damage, fish, id, (to - from).normalized(), run.powerup_settings.chain_proc, next_chain)
		from = to
	if path.size() > 1 and _bolts < MAX_BOLTS:
		var bolt := Bolt.new()
		bolt.path = path
		_bolts += 1
		bolt.tree_exited.connect(func() -> void: _bolts -= 1)
		run.add_child(bolt)


## The nearest zombie to `from` within lightning_range not yet `struck` (-1:
## none). It looks close first and widens only if there's nothing there, so a
## jump through a packed crowd checks a handful, not hundreds.
func _nearest_unstruck(from: Vector3, struck: Dictionary) -> int:
	var horde := run.horde
	var reach := minf(2.0, settings.lightning_range)
	while true:
		var best := -1
		var best_gap := reach * reach
		for j in horde.query_sphere(from, reach):
			if struck.has(j):
				continue
			var gap := horde.enemy_position(j).distance_squared_to(from)
			if gap <= best_gap:
				best_gap = gap
				best = j
		if best >= 0 or reach >= settings.lightning_range:
			return best
		reach = minf(reach * 2.0, settings.lightning_range)
	return -1

## A coil antenna on the head, its tip sparking.
func make_worn() -> Node3D:
	var coil := Node3D.new()
	coil.name = "Coil"
	coil.position = Vector3(0.0, fish.hitbox_height * 0.5, -fish.hitbox_length * 0.05)
	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color(0.72, 0.45, 0.2)
	copper.metallic = 0.9
	copper.roughness = 0.3
	var rod := CylinderMesh.new()
	rod.top_radius = 0.015
	rod.bottom_radius = 0.02
	rod.height = 0.4
	rod.radial_segments = 6
	coil.add_child(worn_mesh(rod, copper, Vector3(0.0, 0.2, 0.0)))
	for n in 3:
		var turn := TorusMesh.new()
		turn.inner_radius = 0.035
		turn.outer_radius = 0.055
		turn.rings = 12
		turn.ring_segments = 6
		coil.add_child(worn_mesh(turn, copper, Vector3(0.0, 0.1 + n * 0.08, 0.0)))
	var tip := SphereMesh.new()
	tip.radius = 0.05
	tip.height = 0.1
	tip.radial_segments = 8
	tip.rings = 4
	var spark := worn_material(3.0)
	coil.add_child(worn_mesh(tip, spark, Vector3(0.0, 0.42, 0.0)))
	coil.ready.connect(func() -> void:
		var crackle := coil.create_tween().set_loops()
		crackle.tween_property(spark, "emission_energy_multiplier", 6.0, 0.05)
		crackle.tween_property(spark, "emission_energy_multiplier", 1.5, 0.21))
	return coil


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
