class_name ShockLash
extends FishAttack
## The String Ray's auto-attack (planning_unnatural.md §5): its tail whips the
## nearest zombie within lash_range, any way round, and the shock arcs on to
## lash_arcs more (one more per Projectiles stat), each the nearest not yet
## struck within lash_arc_range of the last, for lash_arc_share of the damage
## (and a lower proc coefficient).
##
## As a weapon (Weapons): at its first milestone each lash whips the second
## nearest zombie too (arcing on from it as well); at its second, the arcs
## jump FAR_ARCS times as far.

const COLOR := Color(1.0, 0.95, 0.45, 1.0)
const FAR_ARCS := 2.0
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
	var first := horde.nearest_in_cone(origin(), nose(), reach(), -1.0)
	if first < 0:
		return false
	var struck_now := {}
	_lash(first, struck_now)
	if milestones >= 1:
		var second := -1
		var gap := INF
		for j in horde.query_sphere(origin(), reach()):
			var d := horde.enemy_position(j).distance_squared_to(origin())
			if not struck_now.has(j) and d < gap:
				gap = d
				second = j
		if second >= 0:
			_lash(second, struck_now)
	return true


## One lash at zombie `first`, arcing on to the nearest not in `struck_now`.
func _lash(first: int, struck_now: Dictionary) -> void:
	var from := tail()
	var path := PackedVector3Array([from, horde.enemy_position(first)])
	strike(first, settings.lash_damage, toward(from, first, nose()))
	struck_now[first] = true
	var last := horde.enemy_position(first)
	var arc_reach := settings.lash_arc_range * area_scale * (FAR_ARCS if milestones >= 2 else 1.0)
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


## The lash, for a moment: a curved crack from the tail (a thick FxKit
## ribbon, tapering to the zombie, with a thinner strand round it), then
## jagged arcs on from zombie to zombie, flickering out.
class Whip extends MeshInstance3D:
	const CRACK := 0.2
	const ARC := 0.11
	var path := PackedVector3Array()
	var bend := Vector3.UP
	var _age := 0.0
	var _material := FxKit.glow(ShockLash.COLOR, FxKit.across())

	func _ready() -> void:
		top_level = true
		global_transform = Transform3D.IDENTITY
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dice := RandomNumberGenerator.new()
		dice.seed = int(path[0].x * 31.0) ^ path.size()
		var reach := path[0].distance_to(path[1])
		var crack := FxKit.jagged(path[0], path[1], 12, 0.08, dice, bend * reach * 0.25)
		var strands := [crack, FxKit.jagged(path[0], path[1], 10, 0.2, dice, bend * reach * 0.25)]
		var widths := [CRACK, ARC * 0.6]
		for i in range(1, path.size() - 1):
			strands.append(FxKit.jagged(path[i], path[i + 1], 5, 0.35, dice))
			widths.append(ARC)
		mesh = FxKit.ribbons(strands, widths)
		if mesh.get_surface_count() > 0:
			mesh.surface_set_material(0, _material)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= ShockLash.LIFE:
			queue_free()
			return
		_material.albedo_color.a = (1.0 - _age / ShockLash.LIFE) * (0.75 + 0.25 * sin(_age * 80.0))
