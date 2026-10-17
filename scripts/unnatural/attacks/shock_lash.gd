class_name ShockLash
extends FishAttack
## The String Ray's auto-attack (planning_unnatural.md §5): its tail whips the
## nearest zombie within lash_range, any way round, and the shock arcs on to
## lash_arcs more (one more per Projectiles stat), each the nearest not yet
## struck within lash_arc_range of the last, for lash_arc_share of the damage
## (and a lower proc coefficient).

const COLOR := Color(1.0, 0.95, 0.45, 1.0)
const LIFE := 0.22
const ARC_PROC := 0.5

## Arcs made so far, for the probes.
var arcs_made := 0


func _init() -> void:
	name = "ShockLash"


func cooldown() -> float:
	return settings.lash_cooldown


func damage() -> float:
	return settings.lash_damage


func uses_stat(id: String) -> bool:
	return id == "projectile_count"


## How far the tail reaches (m): lash_range, never less than the bow wave's
## full reach times the bite's margin (it's a whip: it must out-reach ramming).
func reach() -> float:
	return maxf(settings.lash_range, GhostBite.bow_reach(fish) * settings.bite_over_bow) * area_scale


func arcs() -> int:
	return settings.lash_arcs + extra_projectiles


## The tail's tip.
func tail() -> Vector3:
	return origin() + fish.global_basis.z * fish.hitbox_length * 0.5


func fire() -> bool:
	var from := tail()
	var first := horde.nearest_in_cone(origin(), nose(), reach(), -1.0)
	if first < 0:
		return false
	var path := PackedVector3Array([from, horde.enemy_position(first)])
	strike(first, settings.lash_damage, toward(from, first, nose()))
	var struck_now := {first: true}
	var last := horde.enemy_position(first)
	var arc_reach := settings.lash_arc_range * area_scale
	for n in arcs():
		var best := -1
		var best_gap := INF
		for j in horde.query_sphere(last, arc_reach):
			if struck_now.has(j):
				continue
			var gap := horde.enemy_position(j).distance_squared_to(last)
			if gap < best_gap:
				best_gap = gap
				best = j
		if best < 0:
			break
		struck_now[best] = true
		var at := horde.enemy_position(best)
		arcs_made += 1
		strike(best, settings.lash_damage * settings.lash_arc_share, (at - last).normalized(), ARC_PROC)
		path.append(at)
		last = at
	var whip := Whip.new()
	whip.path = path
	whip.bend = fish.global_basis.y
	add_child(whip)
	return true


## The lash: a curved crack from the tail, then jagged arcs, for a moment.
class Whip extends MeshInstance3D:
	var path := PackedVector3Array()
	var bend := Vector3.UP
	var _age := 0.0
	var _material := FishAttack.ghost_material(ShockLash.COLOR)

	func _ready() -> void:
		top_level = true
		global_transform = Transform3D.IDENTITY
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lines := ImmediateMesh.new()
		lines.surface_begin(Mesh.PRIMITIVE_LINES, _material)
		var dice := RandomNumberGenerator.new()
		dice.seed = int(path[0].x * 31.0) ^ path.size()
		for strand in 3:
			for i in path.size() - 1:
				var a := path[i]
				var b := path[i + 1]
				var last := a
				var steps := 10 if i == 0 else 5
				for k in range(1, steps + 1):
					var t := float(k) / steps
					var p := a.lerp(b, t)
					if i == 0:
						p += bend * sin(t * PI) * a.distance_to(b) * 0.25  # the whip's curve
					if k < steps:
						p += Vector3(dice.randf_range(-1, 1), dice.randf_range(-1, 1), dice.randf_range(-1, 1)) * (0.12 if i == 0 else 0.35)
					lines.surface_add_vertex(last)
					lines.surface_add_vertex(p)
					last = p
		lines.surface_end()
		mesh = lines

	func _process(delta: float) -> void:
		_age += delta
		if _age >= ShockLash.LIFE:
			queue_free()
			return
		_material.albedo_color.a = 1.0 - _age / ShockLash.LIFE
