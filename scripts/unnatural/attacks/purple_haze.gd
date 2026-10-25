class_name PurpleHaze
extends FishAttack
## Purple Haze (big_changes.md §5), a steady weapon (FishAttack), the
## Alchemists' own, built from the retired Depth Charges: every interval() s it
## scatters per_scatter() bombs over haze_scatter_time s, each lobbed over
## haze_lob_time s at the densest pack within reach() m in any direction (led
## by the pack's velocity over the lob), the rest round it, or fanned round the
## fish if nothing's near (scatter(true); on its own timer it holds instead,
## until something is). A bomb bursts the moment it lands into a purple
## cloud radius() m round that lasts life() s: every haze_tick s it does
## damage() to each zombie inside (proc haze_proc) and hazes them: they drift
## at haze_slow of their speed while in it. At most haze_max clouds (the oldest
## go). Unpalatable (Traversal) coats zombies: they take more from it.
##
## Milestones: at the first, Opaline: a zombie that leaves a cloud stays slowed
## haze_film_slow for haze_film_time s; at the second, clouds that touch merge
## into one bigger cloud; at the third, a zombie that dies hazed bursts into a
## small cloud; at the fourth, clouds creep toward the nearest zombie.

## A lob arcs LOB_RISE of its length up.
const LOB_RISE := 0.3
## How many zombies near the fish are tried as a pack's centre (each costs a sphere query).
const PACK_TRIES := 12
## Untargeted bombs: fanned round the fish FAN_SHARE of reach() out.
const FAN_SHARE := 0.35
## Seconds before it looks again when a scatter found nothing in reach.
const HOLD_RETRY := 0.25
## Bombs past the packs land this many cloud radii apart along the best pack's path.
const PATH_STEP := 0.9
## The third milestone's death clouds: this share of the size, and of the life.
const DEATH_SIZE := 0.5
const DEATH_LIFE := 0.6
## Merging: the bigger cloud grows to hold both (by volume), capped at MERGE_MAX times its own size.
const MERGE_MAX := 2.5
const COLOR := Color(0.62, 0.3, 0.85)

## For the probes and weapon_bench: bombs lobbed, clouds that burst, clouds
## that hurt something (one each, the first time), zombie-seconds hazed,
## clouds merged and death clouds.
var lobbed := 0
var burst := 0
var paid := 0
var hazed_seconds := 0.0
var merges := 0
var death_clouds := 0
var clouds: Array[Cloud] = []
var bombs: Array[Bomb] = []
var _next := 0.0
## Bombs still to throw this scatter: [s left, where it lands].
var _queue: Array = []
## Zombies hazed on the last tick (index -> true), for Opaline and the death clouds.
var _hazed := {}


## It reads its own facets, and has no attacks to count (FishAttack).
func own_facets() -> bool:
	return true


func counts_uses() -> bool:
	return false


## Attack speed counts haze_speed_weight times over here (a scatter every few
## seconds barely feels a few percent).
func interval() -> float:
	var hurry := maxf(1.0 + (attack_speed - 1.0) * powers.haze_speed_weight, 0.1)
	return powers.haze_interval / (1.0 + facet("rate")) / hurry


## Bombs in each scatter: the base, the bombs facet and Quantity.
func per_scatter() -> int:
	return maxi(powers.haze_per_scatter + facet_count("bombs") + extra_projectiles, 1)


## How far it looks for a pack (m), times Size.
func reach() -> float:
	return powers.haze_reach * size_scale


func radius() -> float:
	return powers.haze_radius * (1.0 + facet("size")) * size_scale


func damage() -> float:
	return powers.haze_damage * (1.0 + facet("damage"))


func life() -> float:
	return (powers.haze_life + facet("life")) * duration_scale


func max_clouds() -> int:
	return maxi(powers.haze_max, 1)


## The share of bombs whose cloud hurt something, so far (weapon_bench's "bombs that did damage").
func paid_share() -> float:
	return float(paid) / maxf(burst, 1.0)


func _work(delta: float) -> void:
	_next -= delta
	if _next <= 0.0:
		# Nothing within reach: it holds the scatter (like a fired attack with
		# nothing to fire at) and looks again shortly.
		_next = interval() if scatter() else HOLD_RETRY
	for k in range(_queue.size() - 1, -1, -1):
		_queue[k][0] -= delta
		if _queue[k][0] <= 0.0:
			var to: Vector3 = _queue[k][1]
			_queue.remove_at(k)
			lob(_throw_from(), to)
	for k in range(bombs.size() - 1, -1, -1):
		var bomb := bombs[k]
		if not is_instance_valid(bomb):
			bombs.remove_at(k)
			continue
		bomb.left = maxf(bomb.left - delta, 0.0)
		var t := 1.0 - bomb.left / maxf(bomb.time, 0.001)
		bomb.global_position = bomb.from.lerp(bomb.to, t) + Vector3.UP * bomb.from.distance_to(bomb.to) * LOB_RISE * sin(t * PI)
		if bomb.left <= 0.0:
			bombs.remove_at(k)
			open_cloud(bomb.to, radius(), life())
			bomb.queue_free()
	_tick_clouds(delta)


## Where a bomb leaves the fish: its back.
func _throw_from() -> Vector3:
	return fish.global_position + Vector3.UP * fish.hitbox_height * 0.4


## A scatter, now: per_scatter() bombs over haze_scatter_time s, at the packs
## round the fish (spots()). Whether it threw (not if no zombie is in reach,
## unless `always`).
func scatter(always := false) -> bool:
	if not always and run.horde.query_sphere(fish.global_position, reach()).is_empty():
		return false
	var count := per_scatter()
	var spots := spots(count)
	for n in spots.size():
		var wait := powers.haze_scatter_time * n / maxf(count - 1, 1.0) if count > 1 else 0.0
		_queue.append([wait, spots[n]])
	Sfx.play_at("pw/haze_scatter", fish.global_position)
	return true


## Where `count` bombs should land: the densest pack within reach() (led by its
## velocity over the lob), the next packs that don't overlap it, then round
## the first; fanned round the fish when nothing's near.
func spots(count: int) -> Array[Vector3]:
	var from := fish.global_position
	var near := run.horde.query_sphere(from, reach())
	var result: Array[Vector3] = []
	if near.is_empty():
		for n in count:
			var out := Vector3.FORWARD.rotated(Vector3.UP, TAU * n / count + run.rng.randf() * 0.4)
			result.append(from + out * reach() * FAN_SHARE)
		return result
	# Rank a handful of zombies by how many others are within a cloud of them.
	var tries: Array = []  # [count, centre, velocity]
	var step := maxi(near.size() / PACK_TRIES, 1)
	var r := radius()
	for k in range(0, near.size(), step):
		var at := run.horde.enemy_position(near[k])
		var pack := run.horde.query_sphere(at, r)
		var centre := Vector3.ZERO
		var velocity := Vector3.ZERO
		for i in pack:
			centre += run.horde.enemy_position(i)
			velocity += run.horde.enemy_velocity(i)
		tries.append([pack.size(), centre / maxf(pack.size(), 1.0), velocity / maxf(pack.size(), 1.0)])
		if tries.size() >= PACK_TRIES:
			break
	tries.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var lead := powers.haze_lob_time
	for entry: Array in tries:
		if result.size() >= count:
			break
		var spot: Vector3 = entry[1] + (entry[2] as Vector3) * lead
		var apart := true
		for taken in result:
			if taken.distance_to(spot) < r * 1.4:
				apart = false
				break
		if apart:
			result.append(spot)
	# The rest go in the best pack's path, a little under a cloud apart, so it
	# drifts into them; a pack that holds still gets them round it, overlapping.
	var first: Vector3 = result[0]
	var drift: Vector3 = tries[0][2]
	var n := 1
	while result.size() < count:
		if drift.length() > 0.5:
			result.append(first + drift.normalized() * r * PATH_STEP * n)
		else:
			var out := Vector3.FORWARD.rotated(Vector3.UP, TAU * n / maxf(count - 1, 1.0))
			result.append(first + out * r * PATH_STEP)
		n += 1
	return result


## One bomb from `from`, landing at `to` haze_lob_time s later.
func lob(from: Vector3, to: Vector3) -> void:
	var bomb := Bomb.new()
	bomb.from = from
	bomb.to = to
	bomb.time = powers.haze_lob_time
	bomb.left = bomb.time if from.distance_squared_to(to) > 0.01 else 0.0
	run.add_child(bomb)
	bomb.global_position = from
	bombs.append(bomb)
	lobbed += 1


## A cloud bursts at `at`, `size` m round, for `seconds` (the oldest goes past the cap).
func open_cloud(at: Vector3, size: float, seconds: float, counted := true) -> Cloud:
	while clouds.size() >= max_clouds():
		var oldest: Cloud = clouds.pop_front()
		if is_instance_valid(oldest):
			oldest.fade_out()
	var cloud := Cloud.new()
	cloud.radius = size
	cloud.life = seconds
	cloud.counted = counted
	cloud.next_tick = 0.0  # it bites the moment it lands
	run.add_child(cloud)
	cloud.global_position = at
	clouds.append(cloud)
	if counted:
		burst += 1
	Sfx.play_at("pw/haze_burst", at)
	return cloud


func _tick_clouds(delta: float) -> void:
	if milestone(2):
		_merge()
	var hazed_now := {}
	var coated := run.twist_of(fish) if run else null
	for k in range(clouds.size() - 1, -1, -1):
		var cloud := clouds[k]
		if not is_instance_valid(cloud):
			clouds.remove_at(k)
			continue
		cloud.age += delta
		if cloud.age >= cloud.life:
			clouds.remove_at(k)
			cloud.fade_out()
			continue
		if milestone(4):
			_creep(cloud, delta)
		cloud.next_tick -= delta
		if cloud.next_tick > 0.0:
			for i in run.horde.query_sphere(cloud.global_position, cloud.radius):
				hazed_now[i] = true
			continue
		cloud.next_tick = powers.haze_tick
		var inside := run.horde.query_sphere(cloud.global_position, cloud.radius)
		if inside.is_empty():
			continue
		if cloud.counted and not cloud.paid:
			cloud.paid = true
			paid += 1
		hazed_seconds += inside.size() * powers.haze_tick
		var plain := PackedInt32Array()
		var extra := PackedInt32Array()
		for i in inside:
			hazed_now[i] = true
			run.horde.slow(i, powers.haze_slow, powers.haze_tick + 0.1)
			if coated and coated.is_coated(i):
				extra.append(i)
			else:
				plain.append(i)
		strike_area(plain, damage(), Vector3.INF, powers.haze_proc)
		if not extra.is_empty():
			strike_area(extra, damage() * (1.0 + settings.coat_bonus), Vector3.INF, powers.haze_proc)
	# Opaline: those that just left a cloud stay slowed a while.
	if milestone(1):
		for i: int in _hazed:
			if not hazed_now.has(i) and run.horde.is_alive(i):
				run.horde.slow(i, powers.haze_film_slow, powers.haze_film_time)
	_hazed = hazed_now


## The second milestone: two clouds that touch become one, the bigger grown to hold both.
func _merge() -> void:
	for a in clouds.size():
		var one := clouds[a]
		if not is_instance_valid(one) or one.fading:
			continue
		for b in range(a + 1, clouds.size()):
			var other := clouds[b]
			if not is_instance_valid(other) or other.fading:
				continue
			if one.global_position.distance_to(other.global_position) > one.radius + other.radius:
				continue
			var keep := one if one.radius >= other.radius else other
			var gone := other if keep == one else one
			var grown := pow(pow(keep.radius, 3.0) + pow(gone.radius, 3.0), 1.0 / 3.0)
			keep.radius = minf(grown, radius() * MERGE_MAX)
			keep.life = maxf(keep.life, keep.age + gone.life - gone.age)
			keep.paid = keep.paid or gone.paid
			keep.global_position = keep.global_position.lerp(gone.global_position, 0.3)
			gone.fade_out()
			merges += 1
			return  # one a tick: the list changes as it fades


## The fourth milestone: a cloud drifts toward the nearest zombie.
func _creep(cloud: Cloud, delta: float) -> void:
	var target := run.horde.nearest_in_cone(cloud.global_position, Vector3.FORWARD, reach(), -1.0)
	if target < 0:
		return
	var to := run.horde.enemy_position(target) - cloud.global_position
	if to.length() > 0.3:
		cloud.global_position += to.normalized() * minf(powers.haze_creep * delta, to.length())


## The third milestone: a zombie that dies hazed bursts into a small cloud.
func on_kill(at: Vector3, _source: String) -> void:
	if not milestone(3):
		return
	# The killed zombie's slot is already free; it was hazed if it died in a cloud.
	for cloud in clouds:
		if is_instance_valid(cloud) and not cloud.fading and cloud.global_position.distance_to(at) <= cloud.radius:
			death_clouds += 1
			open_cloud(at, radius() * DEATH_SIZE, life() * DEATH_LIFE, false)
			return


func on_removed() -> void:
	_queue.clear()
	_hazed.clear()
	for cloud in clouds:
		if is_instance_valid(cloud):
			cloud.queue_free()
	clouds.clear()
	for bomb in bombs:
		if is_instance_valid(bomb):
			bomb.queue_free()
	bombs.clear()


## A little satchel of ink bombs on its back.
func make_worn() -> Node3D:
	var satchel := Node3D.new()
	satchel.name = "HazeSatchel"
	satchel.position = Vector3(0.0, fish.hitbox_height * 0.45, fish.hitbox_length * 0.1)
	var material := worn_material(0.8)
	material.roughness = 0.15
	material.clearcoat_enabled = true
	for n in 3:
		satchel.add_child(worn_mesh(WornKit.ball(0.07), material, Vector3((n - 1) * 0.1, 0.0, (n % 2) * 0.06)))
		satchel.add_child(worn_mesh(WornKit.tentacle(0.06, 0.008, 1.5), worn_material(0.1), Vector3((n - 1) * 0.1, 0.06, (n % 2) * 0.06)))
	return satchel


## A bomb in flight: a dark purple ball trailing a wisp.
class Bomb extends Node3D:
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var time := 0.4
	var left := 0.0
	static var _mesh: SphereMesh
	static var _material: StandardMaterial3D

	func _ready() -> void:
		if _mesh == null:
			_mesh = SphereMesh.new()
			_mesh.radius = 0.16
			_mesh.height = 0.32
			_mesh.radial_segments = 10
			_mesh.rings = 5
			_material = StandardMaterial3D.new()
			_material.albedo_color = Color(0.3, 0.12, 0.42)
			_material.emission_enabled = true
			_material.emission = COLOR
			_material.emission_energy_multiplier = 0.6
			_material.roughness = 0.3
		var ball := MeshInstance3D.new()
		ball.mesh = _mesh
		ball.material_override = _material
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ball)


## A cloud of ink and opaline: a soft purple ball with a few puffs turning in
## it, swelling in as it bursts and thinning out as it ends.
class Cloud extends Node3D:
	const SWELL := 0.25
	const FADE := 0.5
	var radius := 4.0
	var life := 5.0
	var age := 0.0
	var next_tick := 0.0
	## Whether it counts as a bomb's (weapon_bench), and whether it has hurt something yet.
	var counted := true
	var paid := false
	var fading := false
	var _fade_left := FADE
	var _ball := MeshInstance3D.new()
	var _puffs: Array[MeshInstance3D] = []
	static var _sphere: SphereMesh
	static var _shell: ShaderMaterial
	static var _puff_mesh: QuadMesh
	static var _puff: StandardMaterial3D

	func _ready() -> void:
		if _sphere == null:
			_sphere = SphereMesh.new()
			_sphere.radius = 1.0
			_sphere.height = 2.0
			_sphere.radial_segments = 20
			_sphere.rings = 10
			_shell = FxKit.rim(Color(COLOR, 0.5), 0.1, 0.35, true)
			_puff_mesh = QuadMesh.new()
			_puff_mesh.size = Vector2(1.0, 1.0)
			_puff = FxKit.glow(Color(0.55, 0.25, 0.75, 0.35), FxKit.dot(), true)
			_puff.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			_puff.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		_ball.mesh = _sphere
		_ball.material_override = _shell
		_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ball)
		for n in 5:
			var puff := MeshInstance3D.new()
			puff.mesh = _puff_mesh
			puff.material_override = _puff
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(puff)
			_puffs.append(puff)
		_process(0.0)

	func _process(delta: float) -> void:
		var size := radius * minf(age / SWELL, 1.0) if SWELL > 0.0 else radius
		if fading:
			_fade_left -= delta
			size *= 1.0 + 0.3 * (1.0 - _fade_left / FADE)
			if _fade_left <= 0.0:
				queue_free()
				return
		elif not is_inside_tree():
			return
		var thin := clampf(_fade_left / FADE, 0.0, 1.0) if fading else clampf((life - age) / FADE, 0.0, 1.0)
		_ball.scale = Vector3.ONE * maxf(size, 0.05)
		_ball.transparency = 1.0 - thin
		for n in _puffs.size():
			var turn := age * 0.4 + TAU * n / _puffs.size()
			_puffs[n].position = Vector3(cos(turn), sin(turn * 1.3 + n) * 0.35, sin(turn)) * size * 0.5
			_puffs[n].scale = Vector3.ONE * size * 1.1
			_puffs[n].transparency = 1.0 - thin

	## Thins out and goes (the cap, a merge, or its time's up).
	func fade_out() -> void:
		if fading:
			return
		fading = true
		age = minf(age, life)
