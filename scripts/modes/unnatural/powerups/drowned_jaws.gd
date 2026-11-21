class_name DrownedJaws
extends Powerup
## Drowned Jaws (planning_bosses_and_survival.md §2, legendary: the Drowned
## Shark's own drop, never a chest's or shrine's pick). Every every() s
## (sooner a stack, and with attack speed) the jaws are ready, and the fish's
## next attack (its own or a held weapon's; a fish with only steady weapons:
## at once) is a chomp too: one huge bite, jaws_damage (more
## jaws_damage_per_stack a stack), on the zombie (or boss) nearest straight
## ahead within jaws_reach m and jaws_cone degrees, with a chomp's impact
## (ChompKit.chomp_zombie: the big number, blood and teeth, the camera's punch,
## jaws_impact times a boss chomp's).

## Chomps so far, for the probes.
var chomps := 0
var _left := 0.0
var _ready := false
var _counted := -1


func every() -> float:
	return settings.jaws_every / (1.0 + settings.jaws_rate_per_stack * extra()) / rate_scale()


func damage() -> float:
	return settings.jaws_damage + settings.jaws_damage_per_stack * extra()


func is_ready() -> bool:
	return _ready


func on_tick(delta: float) -> void:
	if not is_instance_valid(fish):
		return
	var made := _attacks_made()
	if not _ready:
		_left -= delta
		if _left <= 0.0:
			_ready = true
			Sfx.play_at("pw/jaws_ready", fish.global_position)
		_counted = made
		return
	if made < 0 or made > _counted:
		if chomp():
			_ready = false
			_left = every()
	_counted = made


## The chomp, if anything's in reach ahead (false: none, it stays ready).
func chomp() -> bool:
	var target := _target()
	if target < 0:
		return false
	chomps += 1
	Sfx.play_at("boss/chomp", run.horde.enemy_position(target))
	ChompKit.chomp_zombie(run, target, damage(), fish, id, settings.jaws_impact)
	return true


## The zombie (or boss) nearest straight ahead within jaws_reach m and jaws_cone degrees.
func _target() -> int:
	var horde := run.horde
	var head := fish.global_position
	var ahead := -fish.global_basis.z
	var min_cos := cos(deg_to_rad(settings.jaws_cone))
	var best := -1
	var best_gap := INF
	for i in horde.query_sphere(head, settings.jaws_reach * size_scale()):
		var to := horde.enemy_position(i) - head
		var gap := to.length()
		if gap > 0.001 and to.dot(ahead) < gap * min_cos - horde.enemy_radius(i):
			continue
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


## Attacks made so far by the fish's fired weapons (-1: it has only steady ones).
func _attacks_made() -> int:
	var made := 0
	var any := false
	var own := run.attack_of(fish)
	if own and own.counts_uses():
		made += own.uses
		any = true
	for id_held: String in run.powerups_of(fish).held:
		var held: Powerup = run.powerups_of(fish).held[id_held]
		if held is AttackWeapon and is_instance_valid((held as AttackWeapon).attack) and (held as AttackWeapon).attack.counts_uses():
			made += (held as AttackWeapon).attack.uses
			any = true
	return made if any else -1


## A drowned shark's tooth on the nose.
func make_worn() -> Node3D:
	var look := Node3D.new()
	look.name = "WornJaws"
	look.position = Vector3(0.0, -fish.hitbox_height * 0.2, -fish.hitbox_length * 0.45)
	look.add_child(worn_mesh(WornKit.tooth(0.16), worn_material(0.6), Vector3.ZERO, Vector3(PI, 0.0, 0.0)))
	return look
