class_name ChainLightning
extends Powerup
## Chain Lightning (planning_unnatural.md §7): any hit (an attack, a battery,
## another powerup's) has a chance to start lightning that jumps from the
## zombie hit to the nearest one not yet struck, again and again, each jump
## doing lightning_damage (proc coefficient chain_proc, so it can start
## torpedoes, but never lightning again). More stacks: more chance, more jumps.
## At most lightning_max_rate strikes a second (a short burst may go a
## little over), and at most MAX_BOLTS bolts shown at once, so a big proc
## chain stays smooth. Strikes past the rate aren't lost: they bank into the
## next strike's power (up to Powerup.BANK_MAX), and a strike's jumps land as
## one area hit (UnnaturalRun.hit_area()).

## Bolts shown at once, at most (past it a strike still hurts, unseen).
const MAX_BOLTS := 40

static var _bolts := 0

## Jumps made so far (all bolts), for the probes.
var jumps_made := 0
## Strikes held back by lightning_max_rate, kept as the next strike's power.
var banked := 0.0
## Strikes it may make now (refilled at lightning_max_rate a second).
var _strikes_left := 0.0
var _refilled := -1.0


func chance() -> float:
	return soft_chance(settings.lightning_chance + settings.lightning_chance_per_stack * extra())


func jumps() -> int:
	return settings.lightning_jumps + roundi(settings.lightning_jumps_per_stack * extra())


func on_hit(index: int, _damage: float, _source: String, proc: float, chain: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var rate := settings.lightning_max_rate
	if _refilled < 0.0:
		_strikes_left = maxf(rate * 0.1, 1.0)
	else:
		_strikes_left = minf(_strikes_left + (now - _refilled) * rate, maxf(rate * 0.1, 1.0))
	_refilled = now
	var power := proc_power(chance() * proc)
	if power <= 0.0:
		return
	if _strikes_left < 1.0:
		# Over lightning_max_rate: not lost, it goes into the next strike (the perf pass).
		banked = minf(banked + power, BANK_MAX)
		return
	_strikes_left -= 1.0
	strike(index, chain, power + banked)
	banked = 0.0


## Lightning from zombie `index`, jumping jumps() times, `power` times
## lightning_damage at each (an area hit's proc past certain, or strikes the
## rate held back). The jumps are found first, then hit as one area hit.
func strike(index: int, chain: Array, power := 1.0) -> void:
	var horde := run.horde
	var struck := {index: true}
	var from := horde.enemy_position(index)
	var path := PackedVector3Array([from])
	var next_chain := chain + [id]
	var targets := PackedInt32Array()
	var pushes := PackedVector3Array()
	for jump in jumps():
		var best := _nearest_unstruck(from, struck)
		if best < 0:
			break
		struck[best] = true
		var to := horde.enemy_position(best)
		path.append(to)
		jumps_made += 1
		targets.append(best)
		pushes.append((to - from).normalized())
		from = to
	run.hit_area(targets, settings.lightning_damage * maxf(power, 1.0), fish, id, Vector3.INF, 0.0, run.powerup_settings.chain_proc, next_chain, pushes)
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
	coil.add_child(worn_mesh(WornKit.coil(0.4), copper, Vector3.ZERO))
	var spark := worn_material(3.0)
	coil.add_child(worn_mesh(WornKit.ball(0.045), spark, Vector3(0.0, 0.42, 0.0)))
	coil.ready.connect(func() -> void:
		var crackle := coil.create_tween().set_loops()
		crackle.tween_property(spark, "emission_energy_multiplier", 6.0, 0.05)
		crackle.tween_property(spark, "emission_energy_multiplier", 1.5, 0.21))
	return coil


## A jagged bolt along `path`, there for a moment, flickering as it goes:
## three strands of FxKit ribbons, soft at the edges with a white-hot core,
## the first the main one and the other two thinner.
class Bolt extends MeshInstance3D:
	const LIFE := 0.2
	## The main strand's width and the others' (m).
	const WIDTH := 0.16
	const THIN := 0.07
	var path := PackedVector3Array()
	var _age := 0.0
	var _material := FxKit.glow(Color(0.6, 0.9, 1.0), FxKit.across())

	func _ready() -> void:
		var dice := RandomNumberGenerator.new()
		dice.seed = path.size() * 7919 + int(path[0].x * 13.0)
		var strands := []
		for strand in 3:
			var line := PackedVector3Array([path[0]])
			for i in path.size() - 1:
				var leg := FxKit.jagged(path[i], path[i + 1], 5, 0.35, dice)
				line.append_array(leg.slice(1))
			strands.append(line)
		mesh = FxKit.ribbons(strands, [WIDTH, THIN, THIN])
		if mesh.get_surface_count() > 0:
			mesh.surface_set_material(0, _material)
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		_material.albedo_color.a = (1.0 - _age / LIFE) * (0.75 + 0.25 * sin(_age * 90.0))
