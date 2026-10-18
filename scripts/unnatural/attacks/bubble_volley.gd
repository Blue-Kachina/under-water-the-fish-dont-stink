class_name BubbleVolley
extends FishAttack
## The Butterfly Koi's auto-attack (planning_unnatural.md §5): a volley of
## bubble_count homing bubbles (plus the Projectiles stat), each after one of
## the nearest zombies within bubble_range. A bubble pops on the first zombie
## it touches, hurting every one within bubble_pop.
##
## As a weapon (Weapons): at its first milestone the bubbles pop WIDE_POP
## times as wide; at its second, every volley ends with one big bubble
## (BIG_SIZE times the size, BIG_DAMAGE times the damage).

const COLOR := Color(0.75, 0.95, 1.0, 0.45)
## Each pop can hit several.
const PROC := 0.6
const WIDE_POP := 1.6
const BIG_SIZE := 2.5
const BIG_DAMAGE := 3.0

var bubbles := ProjectileSwarm.new()


func _init() -> void:
	name = "BubbleVolley"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	# A real bubble: clear face on, bright round its rim, a glint up top.
	bubbles.set_look(sphere, FxKit.rim(Color(COLOR, 0.85), 0.04, 0.8))
	add_child(bubbles)


func _ready() -> void:
	bubbles.horde = horde
	bubbles.on_hit = func(index: int, amount: float, push: Vector3) -> void: strike(index, amount, push)
	bubbles.on_pop = func(at: Vector3, radius: float) -> void:
		PowerupFx.pop(self, at, maxf(radius, settings.bubble_pop * area_scale * 0.5), COLOR, 0.25)


func cooldown() -> float:
	return settings.bubble_cooldown


func damage() -> float:
	return settings.bubble_damage


func proc() -> float:
	return PROC


func uses_stat(id: String) -> bool:
	return id == "projectile_count" or id == "projectile_speed"


func _physics_process(_delta: float) -> void:
	bubbles.homing = settings.bubble_turn
	bubbles.pop = settings.bubble_pop * area_scale * (WIDE_POP if milestones >= 1 else 1.0)


func fire() -> bool:
	var at := origin()
	var near := horde.query_sphere(at, settings.bubble_range)
	if near.is_empty():
		return false
	var sorted := Array(near)
	sorted.sort_custom(func(a: int, b: int) -> bool:
		return horde.enemy_position(a).distance_squared_to(at) < horde.enemy_position(b).distance_squared_to(at))
	var count := settings.bubble_count + extra_projectiles
	var basis := fish.global_basis
	var speed := settings.bubble_speed * projectile_speed
	for n in count:
		var target: int = sorted[n % sorted.size()]
		# Out of the mouth in a little fan, then they curl round to their zombies.
		var spread := (n - (count - 1) * 0.5) / maxf(count - 1, 1.0)
		var out := (-basis.z + basis.x * spread * 1.2 + basis.y * (0.3 + 0.2 * absf(spread))).normalized()
		bubbles.fire(at + out * 0.8, out * speed, settings.bubble_damage, settings.bubble_size, settings.bubble_life, 1, target)
	if milestones >= 2:
		var up := (-basis.z + basis.y * 0.5).normalized()
		bubbles.fire(at + up * 0.8, up * speed * 0.8, settings.bubble_damage * BIG_DAMAGE, settings.bubble_size * BIG_SIZE,
				settings.bubble_life, 1, sorted[0])
	return true
