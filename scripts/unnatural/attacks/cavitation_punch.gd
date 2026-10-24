class_name CavitationPunch
extends FishAttack
## The Mantis Shrimp's auto-attack (big_changes.md §4), the Brawlers' own: a
## boxing glove thrown at the nearest zombie within punch_aim_cone of the nose
## (straight on if one is anywhere within reach ahead). The glove flies
## punch_speed m/s for reach() m with a punch_size m hit radius, fading out
## over the last punch_fade of its flight, and stops at the first zombie it
## touches: the strike, punch_damage and a heavy knockback (punch_knock).
## punch_collapse_delay s later the cavitation bubble it left collapses at the
## impact point: a flash and a ring, punch_collapse_share of the strike to
## every zombie within punch_collapse_radius m (proc punch_collapse_proc),
## the struck one too. Two impacts per punch.
##
## Each Quantity throws one more glove from the other claw (a one-two),
## punch_follow_gap s after the last. punch() throws one along a given way
## (the Recoil Dash, Traversal). The Brawlers' twist, Heavy Hitter, turns the
## struck zombies into missiles (Traversal.fling()).
##
## As a weapon (Weapons): at its first milestone the collapse ring is
## RING_GROW times as wide; at its second, collapses stun for STUN_TIME s; at
## its third, the glove pierces one zombie and collapses at each it hits; at
## its fourth, every HAYMAKER_EVERY-th punch is a Haymaker: HAYMAKER_SIZE
## times the glove, and its collapse hits for the strike's full damage.

const COLOR := Color(1.0, 0.45, 0.35)
const BUBBLE_COLOR := Color(0.75, 0.95, 1.0)
const RING_GROW := 1.5
const STUN_TIME := 0.5
const HAYMAKER_EVERY := 3
const HAYMAKER_SIZE := 2.0
## A follow-up glove comes from the other claw, this far (m) to the side.
const CLAW_APART := 0.35

## Gloves thrown, struck zombies, collapses gone off and Haymakers thrown, for the probes.
var gloves_thrown := 0
var glove_hits := 0
var collapses := 0
var haymakers := 0
## The gloves in flight: {node, at, velocity, life, total, damage, radius, pierce, hit, haymaker}.
var gloves: Array[Dictionary] = []
## Collapses to come: {left, at, damage, haymaker}.
var _collapses: Array[Dictionary] = []
## Follow-up gloves to come: {left, side, way (ZERO: aim then)}.
var _follow_ups: Array[Dictionary] = []
var _punches := 0
var _glove_mesh: Mesh


func _init() -> void:
	name = "CavitationPunch"


func cooldown() -> float:
	return settings.punch_cooldown


func damage() -> float:
	return settings.punch_damage


func uses_stat(id: String) -> bool:
	return id == "quantity"


## How far a glove flies (m): punch_range, never less than the bow wave's full
## reach times punch_over_bow (it's melee: it must out-reach ramming).
func reach() -> float:
	return maxf(settings.punch_range, GhostBite.bow_reach(fish) * settings.punch_over_bow)


## The glove's hit radius (m), Size and a Haymaker on it.
func glove_radius(haymaker := false) -> float:
	return settings.punch_size * size_scale * (HAYMAKER_SIZE if haymaker else 1.0)


func collapse_radius() -> float:
	return settings.punch_collapse_radius * size_scale * (RING_GROW if milestones >= 1 else 1.0)


## The nearest zombie within reach and punch_aim_cone of the nose.
func aim_target() -> int:
	return horde.nearest_in_cone(origin(), nose(), reach(), cos(deg_to_rad(settings.punch_aim_cone)))


## Something to punch: one in the cone, or any within reach ahead.
func fire() -> bool:
	if aim_target() < 0 and horde.nearest_in_cone(origin(), nose(), reach(), 0.0) < 0:
		return false
	_punch(Vector3.ZERO)
	return true


## A full punch along `way` (unit), whatever's there (the Recoil Dash): its
## follow-ups go the same way. Counts as a use.
func punch(way: Vector3) -> void:
	_punch(way.normalized())
	uses += 1


func _punch(way: Vector3) -> void:
	_punches += 1
	var haymaker := milestones >= 4 and _punches % HAYMAKER_EVERY == 0
	haymakers += 1 if haymaker else 0
	_throw(way, 0.0, haymaker)
	for n in extra_projectiles:
		_follow_ups.append({"left": settings.punch_follow_gap * (n + 1), "side": -1.0 if n % 2 == 0 else 1.0, "way": way})


## One glove from the claw `side` (-1 left, 1 right, 0 middle), along `way`
## (ZERO: at the aim target, else straight on).
func _throw(way: Vector3, side: float, haymaker := false) -> void:
	var at := origin()
	var ahead := nose()
	var direction := way
	if direction == Vector3.ZERO:
		var target := aim_target()
		direction = toward(at, target, ahead) if target >= 0 else ahead
	var start := at + direction * fish.hitbox_length * 0.5 + fish.global_basis.x * side * CLAW_APART
	var life := reach() / maxf(settings.punch_speed, 0.1)
	var radius := glove_radius(haymaker)
	var node := _glove_node()
	add_child(node)
	gloves.append({"node": node, "at": start, "velocity": direction * settings.punch_speed, "life": life, "total": life,
			"damage": settings.punch_damage, "radius": radius, "pierce": 2 if milestones >= 3 else 1, "hit": {},
			"haymaker": haymaker})
	gloves_thrown += 1
	_place(gloves[-1])


func _physics_process(delta: float) -> void:
	if horde == null:
		return
	var n := 0
	while n < _follow_ups.size():
		_follow_ups[n].left -= delta
		if _follow_ups[n].left <= 0.0:
			var follow: Dictionary = _follow_ups.pop_at(n)
			if is_instance_valid(fish):
				_throw(follow.way, follow.side)
		else:
			n += 1
	n = 0
	while n < gloves.size():
		if _fly(gloves[n], delta):
			n += 1
		else:
			_drop(n)
	n = 0
	while n < _collapses.size():
		_collapses[n].left -= delta
		if _collapses[n].left <= 0.0:
			_collapse(_collapses.pop_at(n))
		else:
			n += 1


## Moves a glove and strikes what it touches; false: it's spent.
func _fly(glove: Dictionary, delta: float) -> bool:
	glove.life -= delta
	if glove.life <= 0.0:
		return false
	var velocity: Vector3 = glove.velocity
	var from: Vector3 = glove.at
	var to: Vector3 = from + velocity * delta
	glove.at = to
	_place(glove)
	var reach_now: float = glove.radius + velocity.length() * delta * 0.5
	var way := velocity.normalized()
	for j in horde.query_sphere((from + to) * 0.5, reach_now):
		if glove.hit.has(j):
			continue
		glove.hit[j] = true
		glove_hits += 1
		var impact := horde.enemy_position(j)
		strike(j, glove.damage, way * settings.punch_knock)
		_fling(j, glove.damage)
		_collapses.append({"left": settings.punch_collapse_delay, "at": impact, "damage": glove.damage, "haymaker": glove.haymaker})
		glove.pierce -= 1
		if glove.pierce <= 0:
			PowerupFx.pop(self, impact, glove.radius * 1.2, COLOR, 0.15)
			return false
	return true


## The bubble collapses: the second impact.
func _collapse(collapse: Dictionary) -> void:
	collapses += 1
	var at: Vector3 = collapse.at
	var radius := collapse_radius()
	PowerupFx.pop(self, at, radius * 0.6, BUBBLE_COLOR, 0.2)
	PowerupFx.flash(self, at, radius * 0.4, Color(1.0, 0.95, 0.8), 0.12)
	PowerupFx.ring(self, at, radius, BUBBLE_COLOR, Vector3.UP, 0.25)
	var targets := horde.query_sphere(at, radius)
	if targets.is_empty():
		return
	var share := 1.0 if collapse.haymaker else settings.punch_collapse_share
	strike_area(targets, collapse.damage * share, at, settings.punch_collapse_proc)
	if milestones >= 2:
		var twist: Traversal = run.twist_of(fish) if run and is_instance_valid(fish) else null
		for i in targets:
			if not (twist and twist.is_flung(i)):  # a stun would stop Heavy Hitter's missile dead
				horde.slow(i, 1.0, STUN_TIME)


## Heavy Hitter (the Brawlers' twist): the struck zombie becomes a missile.
func _fling(index: int, amount: float) -> void:
	var twist: Traversal = run.twist_of(fish) if run and is_instance_valid(fish) else null
	if twist:
		twist.fling(index, amount * damage_scale)


func _drop(n: int) -> void:
	var node: Node3D = gloves[n].node
	if is_instance_valid(node):
		node.queue_free()
	gloves.remove_at(n)


## The glove where it is now, facing its flight, fading over its last punch_fade.
func _place(glove: Dictionary) -> void:
	var node: MeshInstance3D = glove.node
	if not is_instance_valid(node):
		return
	var velocity: Vector3 = glove.velocity
	var up := Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.BACK
	node.global_transform = Transform3D(Basis.looking_at(velocity, up).scaled(Vector3.ONE * float(glove.radius)), glove.at)
	var fade_from := maxf(settings.punch_fade, 0.001) * float(glove.total)
	var alpha := clampf(float(glove.life) / fade_from, 0.0, 1.0)
	var material := node.material_override as StandardMaterial3D
	material.albedo_color.a = alpha
	material.emission_energy_multiplier = 1.5 * alpha


## A glove: a fist (a squashed ball) with a cuff behind it, 1 m round (_place() sizes it).
func _glove_node() -> MeshInstance3D:
	if _glove_mesh == null:
		var mesh := ArrayMesh.new()
		var fist := SphereMesh.new()
		fist.radius = 1.0
		fist.height = 1.7
		fist.radial_segments = 16
		fist.rings = 8
		var cuff := CylinderMesh.new()
		cuff.top_radius = 0.6
		cuff.bottom_radius = 0.7
		cuff.height = 0.8
		cuff.radial_segments = 12
		var thumb := SphereMesh.new()
		thumb.radius = 0.35
		thumb.height = 0.7
		thumb.radial_segments = 8
		thumb.rings = 4
		FxKit.merge_into(mesh, [
			[fist, Transform3D.IDENTITY],
			[cuff, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 1.0))],
			[thumb, Transform3D(Basis.IDENTITY, Vector3(0.8, 0.1, -0.1))],
		], null)
		_glove_mesh = mesh
	var node := MeshInstance3D.new()
	node.mesh = _glove_mesh
	node.top_level = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = COLOR
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = COLOR
	material.emission_energy_multiplier = 1.5
	node.material_override = material
	return node


func on_removed() -> void:
	for glove in gloves:
		if is_instance_valid(glove.node):
			glove.node.queue_free()
	gloves.clear()
	_collapses.clear()
	_follow_ups.clear()
