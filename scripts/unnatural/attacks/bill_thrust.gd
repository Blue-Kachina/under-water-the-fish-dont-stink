class_name BillThrust
extends FishAttack
## The Swordfish's auto-attack (planning_unnatural.md §5): a spear of light
## shot off its bill, at the nearest zombie within thrust_aim_cone of the nose
## (or straight on if one is anywhere within range ahead), piercing up to
## thrust_pierce zombies. Each Projectiles stat adds a spear, fanned
## thrust_spread degrees apart; Projectile Speed (the Swordfish's signature)
## makes them faster and fly further in the same time.
##
## As a weapon (Weapons): at its first milestone the spears pierce one more
## zombie; at its second, a spear that flies its full range bursts, hurting
## every zombie within BURST_REACH (times area) for BURST_SHARE of its damage;
## at its third, MORE_SPEARS more spears fan out with each thrust; at its
## fourth, they pierce everything in their way.

const COLOR := Color(0.55, 0.85, 1.0, 0.9)
const BURST_REACH := 2.5
const BURST_SHARE := 0.6
const MORE_SPEARS := 2
const PIERCE_ALL := 9999

var spears := ProjectileSwarm.new()


func _init() -> void:
	name = "BillThrust"
	# A lance of light, point first along -z: a white-hot core in an icy sheath,
	# a trail streaming off behind (FxKit.lance_mesh).
	spears.set_look(FxKit.lance_mesh(Color(0.85, 0.97, 1.0, 0.95), COLOR, -1.1, 0.5, 0.2, 0.8, 2.2))
	spears.stretch = 2.5
	add_child(spears)


func _ready() -> void:
	spears.horde = horde
	spears.on_hit = func(index: int, amount: float, push: Vector3) -> void: strike(index, amount, push)
	spears.on_expire = func(at: Vector3, amount: float) -> void:
		if milestones < 2:
			return
		var reach := BURST_REACH * area_scale
		PowerupFx.pop(self, at, reach, COLOR, 0.25)
		for i in horde.query_sphere(at, reach):
			strike(i, amount * BURST_SHARE, toward(at, i, Vector3.UP))


func cooldown() -> float:
	return settings.thrust_cooldown


func damage() -> float:
	return settings.thrust_damage


func uses_stat(id: String) -> bool:
	return id == "projectile_count" or id == "projectile_speed"


func speed() -> float:
	return settings.thrust_speed * projectile_speed


func fire() -> bool:
	var at := origin()
	var ahead := nose()
	var target := horde.nearest_in_cone(at, ahead, settings.thrust_range, cos(deg_to_rad(settings.thrust_aim_cone)))
	if target < 0:
		return false
	var aim := toward(at, target, ahead)
	var count := 1 + extra_projectiles + (MORE_SPEARS if milestones >= 3 else 0)
	var pierce := PIERCE_ALL if milestones >= 4 else settings.thrust_pierce + (1 if milestones >= 1 else 0)
	var side := aim.cross(Vector3.UP if absf(aim.y) < 0.98 else Vector3.BACK).normalized()
	var up := side.cross(aim)
	var tip := at + ahead * fish.hitbox_length * 0.5
	for n in count:
		var offset := (n - (count - 1) * 0.5) * deg_to_rad(settings.thrust_spread)
		var direction := aim.rotated(up, offset)
		spears.fire(tip, direction * speed(), settings.thrust_damage, settings.thrust_size * area_scale,
				settings.thrust_range / settings.thrust_speed, pierce)
	return true
