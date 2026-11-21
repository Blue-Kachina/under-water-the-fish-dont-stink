class_name AmmoniteSpiral
extends Powerup
## Ammonite Spiral (planning_unnatural.md §7b, rare): a spiral shell. A
## projectile's hit (a spear, bubble, spine or torpedo) splits into
## ammonite_splits shards (one more a stack), each flying to another zombie
## within ammonite_range m (nearest first) for ammonite_share of the hit (before
## the player's Damage, which the shard's own hit adds again). At most
## ammonite_max_rate splits a second.

## The hit sources that are projectiles.
const PROJECTILES: Array[String] = ["thrust", "bubbles", "spines", "torpedo"]

## Shards sent, for the probes.
var shards := 0
var _splits_left := 0.0
var _refilled := -1.0


func splits() -> int:
	return settings.ammonite_splits + roundi(extra())


func on_hit(index: int, damage: float, source: String, _proc: float, chain: Array) -> void:
	if source not in PROJECTILES or not _may_split():
		return
	var horde := run.horde
	var from := horde.enemy_position(index)
	var near := horde.query_sphere(from, settings.ammonite_range)
	var order := []
	for j in near:
		if j != index:
			order.append(j)
	if order.is_empty():
		return
	order.sort_custom(func(a: int, b: int) -> bool:
		return horde.enemy_position(a).distance_squared_to(from) < horde.enemy_position(b).distance_squared_to(from))
	_splits_left -= 1.0
	var share := damage / maxf(1.0 + run.block_of(fish).value("damage"), 0.1) * settings.ammonite_share
	for n in mini(splits(), order.size()):
		var j: int = order[n]
		var to := horde.enemy_position(j)
		shards += 1
		run.hit(j, share, fish, id, (to - from).normalized(), run.powerup_settings.chain_proc, chain + [id])
		GhostSwordfish.streak(run, from, to, color(id), 0.18, 0.2)


func _may_split() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var cap := maxf(settings.ammonite_max_rate * 0.25, 1.0)
	_splits_left = cap if _refilled < 0.0 else minf(_splits_left + (now - _refilled) * settings.ammonite_max_rate, cap)
	_refilled = now
	return _splits_left >= 1.0


## A coiled shell on the back.
func make_worn() -> Node3D:
	var shell := Node3D.new()
	shell.name = "Ammonite"
	shell.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.08, fish.hitbox_length * 0.05)
	shell.add_child(worn_mesh(WornKit.spiral_shell(0.2), worn_material(0.4), Vector3.ZERO))
	return shell
