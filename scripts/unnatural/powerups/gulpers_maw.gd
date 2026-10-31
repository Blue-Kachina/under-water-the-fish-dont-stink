class_name GulpersMaw
extends Powerup
## Gulper's Maw (planning_bosses_and_survival.md §2, boss item: the Gulper
## Mother's). Every maw_every s (cooldown(): sooner a stack, and with attack
## speed) a maw opens maw_reach m ahead of the fish, a spinning funnel that
## sucks in the zombies within maw_radius m (with Size) for maw_suck_time s.
## Then it swallows up to swallow_count() of those within maw_mouth m,
## chewing each for maw_chew_damage, and spits them out ahead (shoved hard
## along a fan) with a volley: a bolt along each one's way out, hurting
## every zombie it passes (volley_damage()). Bosses aren't pulled or
## swallowed, but the volley hits them.

## How wide the spat volley fans (rad, edge to edge), and how hard the spat
## zombies are thrown out along it (m/s).
const FAN := 0.9
const SPIT_SPEED := 22.0
## The funnel's glow at its strongest: a see-through swirl, so it never hides the fish.
const FUNNEL_STRENGTH := 0.55

## Times it gulped and zombies swallowed, and volley bolts fired, for the probes.
var gulps := 0
var swallowed := 0
var bolts := 0
var _left := 0.0
## Seconds left sucking (below 0: shut).
var _sucking := -1.0
var _funnel: MeshInstance3D
var _material: ShaderMaterial


func cooldown() -> float:
	return settings.maw_every / (1.0 + settings.maw_rate_per_stack * extra()) / rate_scale()


func swallow_count() -> int:
	return maxi(settings.maw_swallow + roundi(settings.maw_swallow_per_stack * extra()), 0)


func volley_damage() -> float:
	return settings.maw_volley_damage + settings.maw_volley_damage_per_stack * extra()


func is_sucking() -> bool:
	return _sucking >= 0.0


## Where the maw opens: maw_reach m ahead of the fish.
func mouth() -> Vector3:
	return fish.global_position - fish.global_basis.z * settings.maw_reach


func on_tick(delta: float) -> void:
	if not is_instance_valid(fish):
		return
	if is_sucking():
		_suck(delta)
		return
	_left -= delta
	if _left > 0.0:
		return
	_left = cooldown()
	open()


## The maw opens now (its funnel shows, and it starts to suck).
func open() -> void:
	_sucking = settings.maw_suck_time
	_ensure_funnel()
	_funnel.visible = true
	Sfx.play_at("pw/maw_suck", mouth())


func _suck(delta: float) -> void:
	_sucking -= delta
	var at := mouth()
	var ahead := -fish.global_basis.z
	var horde := run.horde
	for i in horde.query_sphere(at, settings.maw_radius * size_scale()):
		if horde.is_proxy(i):
			continue  # a boss's body: too big to swallow
		var inward := at - horde.enemy_position(i)
		if inward.length_squared() > 0.04:
			var swirl := ahead.cross(inward).normalized()
			horde.shove(i, (inward.normalized() * settings.maw_pull + swirl * settings.maw_pull * 0.4) * delta * 4.0)
	if is_instance_valid(_funnel):
		var open_share := clampf(1.0 - _sucking / maxf(settings.maw_suck_time, 0.01), 0.0, 1.0)
		var tip := ahead if ahead.length_squared() > 0.0001 else Vector3.FORWARD
		var side := tip.cross(Vector3.UP if absf(tip.y) < 0.95 else Vector3.RIGHT).normalized()
		# The funnel's wide lip faces the fish, its throat away.
		_funnel.global_transform = Transform3D(Basis(side, -tip, side.cross(-tip)).rotated(tip, _sucking * 6.0), at)
		_material.set_shader_parameter("strength", minf(open_share * 3.0, 1.0) * FUNNEL_STRENGTH)
	if _sucking <= 0.0:
		_swallow(at, ahead)


## It shuts on what's in its mouth (the nearest swallow_count()), chews them and
## spits them out with the volley.
func _swallow(at: Vector3, ahead: Vector3) -> void:
	_sucking = -1.0
	if is_instance_valid(_funnel):
		_funnel.visible = false
	gulps += 1
	var horde := run.horde
	var near := Array(horde.query_sphere(at, settings.maw_mouth * size_scale())).filter(func(i: int) -> bool: return not horde.is_proxy(i))
	near.sort_custom(func(a: int, b: int) -> bool:
		return horde.enemy_position(a).distance_squared_to(at) < horde.enemy_position(b).distance_squared_to(at))
	var eaten := PackedInt32Array()
	for n in mini(swallow_count(), near.size()):
		eaten.append(near[n])
	swallowed += eaten.size()
	PowerupFx.shock(run, at, settings.maw_mouth * size_scale(), color(id), ahead, 0.35)
	Sfx.play_at("pw/maw_spit", at)
	if eaten.is_empty():
		return
	run.hit_area(eaten, settings.maw_chew_damage, fish, id, Vector3.INF, 0.0, settings.maw_proc, [id])
	var up := Vector3.UP if absf(ahead.y) < 0.95 else Vector3.RIGHT
	for n in eaten.size():
		var turn := 0.0 if eaten.size() == 1 else lerpf(-FAN * 0.5, FAN * 0.5, float(n) / (eaten.size() - 1))
		var way := ahead.rotated(up, turn).normalized()
		if horde.is_alive(eaten[n]):
			horde.relocate(eaten[n], at + way * 0.5)
			horde.shove(eaten[n], way * SPIT_SPEED)
		_bolt(at, way, eaten[n])


## A volley bolt from `from` along `way`, hurting every zombie it passes (not
## `spat`, the one it carries out).
func _bolt(from: Vector3, way: Vector3, spat: int) -> void:
	var long := settings.maw_volley_length
	var width := settings.maw_volley_width * size_scale()
	var to := from + way * long
	var cut := PackedInt32Array()
	var pushes := PackedVector3Array()
	for i in run.horde.query_sphere((from + to) * 0.5, long * 0.5 + width):
		if i == spat:
			continue
		var at := run.horde.enemy_position(i)
		var along := clampf((at - from).dot(way), 0.0, long)
		if at.distance_to(from + way * along) <= width + run.horde.enemy_radius(i):
			cut.append(i)
			pushes.append(way * 2.0)
	run.hit_area(cut, volley_damage(), fish, id, Vector3.INF, 0.0, settings.maw_proc, [id], pushes)
	bolts += 1
	GhostSwordfish.streak(run, from, to, color(id).lightened(0.2), width, 0.3)


func _ensure_funnel() -> void:
	if is_instance_valid(_funnel):
		return
	var radius := settings.maw_mouth * 0.9
	var tall := radius * 1.4
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/vortex.gdshader")
	var tint := color(id)
	_material.set_shader_parameter("color", Vector3(tint.r, tint.g, tint.b))
	_material.set_shader_parameter("tall", tall)
	_material.set_shader_parameter("spin", 6.0)
	_funnel = MeshInstance3D.new()
	_funnel.name = "GulpersMaw"
	_funnel.mesh = Whirlpool.funnel_mesh(tall, radius, radius * 0.15)
	_funnel.material_override = _material
	_funnel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_funnel.top_level = true
	_funnel.visible = false
	run.add_child(_funnel)


func on_removed() -> void:
	if is_instance_valid(_funnel):
		_funnel.queue_free()
	_funnel = null
	_sucking = -1.0


## A ring of teeth round the fish's nose.
func make_worn() -> Node3D:
	var look := Node3D.new()
	look.name = "WornMaw"
	look.position = Vector3(0.0, 0.0, -fish.hitbox_length * 0.5)
	look.add_child(worn_mesh(WornKit.toothed_ring(snappedf(fish.hitbox_width * 0.35, 0.05)), worn_material(0.8), Vector3.ZERO))
	return look
