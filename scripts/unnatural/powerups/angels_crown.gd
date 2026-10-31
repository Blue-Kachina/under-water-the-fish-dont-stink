class_name AngelsCrown
extends Powerup
## Angel's Crown (planning_bosses_and_survival.md §2, boss item: the Fallen
## Angel's). Every crown_every s (cooldown(): sooner a stack, and with attack
## speed) a crown of tentacles bursts from the fish's head and lashes the cone
## ahead lash_count() times, crown_lash_gap s apart: each lash damage() to
## every zombie within crown_reach m (with Size) and angle() degrees of
## straight ahead. Each zombie it kills heals the fish kill_heal() hp.

## Tentacle strokes drawn for each lash.
const STROKES := 3

## Bursts, lashes and hp healed so far, for the probes.
var bursts := 0
var lashes := 0
var healed := 0.0
var _left := 0.0
var _lashes_left := 0
var _gap := 0.0
var _dice := RandomNumberGenerator.new()


func cooldown() -> float:
	return settings.crown_every / (1.0 + settings.crown_rate_per_stack * extra()) / rate_scale()


func lash_count() -> int:
	return maxi(settings.crown_lashes + roundi(settings.crown_lashes_per_stack * extra()), 1)


func damage() -> float:
	return settings.crown_damage + settings.crown_damage_per_stack * extra()


## The cone's half-angle (degrees), up to 180 (all round).
func angle() -> float:
	return minf(settings.crown_angle + settings.crown_angle_per_stack * extra(), 180.0)


func kill_heal() -> float:
	return settings.crown_heal + settings.crown_heal_per_stack * extra()


func reach() -> float:
	return settings.crown_reach * size_scale()


func on_tick(delta: float) -> void:
	if not is_instance_valid(fish):
		return
	if _lashes_left > 0:
		_gap -= delta
		if _gap <= 0.0:
			_gap = settings.crown_lash_gap
			_lashes_left -= 1
			lash()
		return
	_left -= delta
	if _left > 0.0:
		return
	_left = cooldown()
	burst()


## The crown bursts open: its lashes follow.
func burst() -> void:
	bursts += 1
	_lashes_left = lash_count()
	_gap = 0.0
	PowerupFx.ring(run, _head(), fish.hitbox_width * 1.2, color(id), fish.global_basis.y, 0.3)
	Sfx.play_at("pw/crown_burst", fish.global_position)


## One lash across the cone ahead.
func lash() -> void:
	lashes += 1
	var head := _head()
	var ahead := -fish.global_basis.z
	var far := reach()
	var min_cos := cos(deg_to_rad(angle()))
	var horde := run.horde
	var struck := PackedInt32Array()
	for i in horde.query_sphere(head, far):
		var to := horde.enemy_position(i) - head
		var gap := to.length()
		if gap < 0.001 or to.dot(ahead) >= gap * min_cos - horde.enemy_radius(i):
			struck.append(i)
	run.hit_area(struck, damage(), fish, id, head, 1.0, settings.crown_proc, [id])
	var up := fish.global_basis.y
	var half := deg_to_rad(angle())
	for n in STROKES:
		var turn := _dice.randf_range(-half, half)
		var lift := _dice.randf_range(-0.25, 0.25)
		var tip := head + ahead.rotated(up, turn).rotated(fish.global_basis.x, lift).normalized() * far
		GhostSwordfish.streak(run, head, tip, color(id), 0.35, 0.22)
	Sfx.play_at("pw/crown_lash", head)


func on_kill(_at: Vector3, source: String) -> void:
	if source != id or not is_instance_valid(fish):
		return
	var health := run.health_of(fish)
	if health and not health.down:
		var before := health.hp
		health.heal(kill_heal())
		healed += health.hp - before


func _head() -> Vector3:
	return fish.global_position + fish.global_basis.y * fish.hitbox_height * 0.4 - fish.global_basis.z * fish.hitbox_length * 0.3


## A small crown of tentacle stubs on the head.
func make_worn() -> Node3D:
	var look := Node3D.new()
	look.name = "WornCrown"
	look.position = Vector3(0.0, fish.hitbox_height * 0.45, -fish.hitbox_length * 0.2)
	var skin := worn_material(0.9)
	for n in 5:
		var a := TAU * n / 5.0
		look.add_child(worn_mesh(WornKit.tentacle(0.22, 0.03, 1.5), skin, Vector3(cos(a), 0.0, sin(a)) * 0.1, Vector3(0.0, -a, 0.0)))
	return look
