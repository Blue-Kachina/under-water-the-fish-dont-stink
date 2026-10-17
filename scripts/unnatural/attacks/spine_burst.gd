class_name SpineBurst
extends FishAttack
## The Boxfish's auto-attack (planning_unnatural.md §5): whenever a zombie is
## within spine_range, spine_count spines (plus 4 per Projectiles stat) shoot
## out in every direction (most round its level), each piercing up to spine_pierce zombies.

const COLOR := Color(1.0, 0.8, 0.4, 0.85)
## A burst hits many at once.
const PROC := 0.4
## This share of the spines go round the fish's level.
const LEVEL_SHARE := 0.65

var spines := ProjectileSwarm.new()
var _turn := 0.0


func _init() -> void:
	name = "SpineBurst"
	var spine := BoxMesh.new()
	spine.size = Vector3(0.5, 0.5, 2.0)
	spines.set_look(spine, FishAttack.ghost_material(COLOR))
	spines.stretch = 1.5
	add_child(spines)


func _ready() -> void:
	spines.horde = horde
	spines.on_hit = func(index: int, amount: float, push: Vector3) -> void: strike(index, amount, push)


func cooldown() -> float:
	return settings.spine_cooldown


func damage() -> float:
	return settings.spine_damage


func proc() -> float:
	return PROC


func uses_stat(id: String) -> bool:
	return id == "projectile_count" or id == "projectile_speed"


func count() -> int:
	return settings.spine_count + 4 * extra_projectiles


func fire() -> bool:
	var at := origin()
	var reach := settings.spine_range * area_scale
	if horde.query_sphere(at, reach).is_empty():
		return false
	var n := count()
	var speed := settings.spine_speed * projectile_speed
	_turn += 0.7  # each burst a little turned, so the gaps move
	var basis := fish.global_basis
	# Most round the fish's level (that's where zombies mostly are), a little
	# zigzag up and down; the rest spread over a sphere (Fibonacci).
	var level := ceili(n * LEVEL_SHARE)
	for t in n:
		var out: Vector3
		if t < level:
			var angle := TAU * t / level + _turn
			var tilt := deg_to_rad(10.0) * (1.0 if t % 2 == 0 else -1.0)
			out = Vector3(cos(angle) * cos(tilt), sin(tilt), sin(angle) * cos(tilt))
		else:
			var k := t - level
			var rest := n - level
			var y := 1.0 - 2.0 * (k + 0.5) / rest
			var ring := sqrt(1.0 - y * y)
			var angle := k * PI * (3.0 - sqrt(5.0)) + _turn
			out = Vector3(cos(angle) * ring, y, sin(angle) * ring)
		out = (basis * out).normalized()
		spines.fire(at + out * 0.6, out * speed, settings.spine_damage, settings.spine_size * area_scale, reach / speed, settings.spine_pierce)
	return true
