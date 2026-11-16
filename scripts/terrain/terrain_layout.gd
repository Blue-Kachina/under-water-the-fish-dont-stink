class_name TerrainLayout
extends RefCounted
## The terrain's feature records for one stage (planning_procedural_world.md, phase 2), rolled from the seed by rules,
## so any seed makes a sensible arena: an open middle (D6a), mesas in 2-3 canyon arcs toward the edge plus a few
## singles, one overhanging grotto set back from the start, 1-3 arches and a tunnel bored through a big mesa where
## there is room, plateaus in the outer band and the edge ring. Bores and grotto mouths are sized from the clearance
## (rule N); the native navigability pass then guarantees the rest.
##
## Everything is in the Seabed's space (y 0 is the flat sand). `params` goes straight to TerrainField.configure().

## TerrainField.configure()'s dictionary.
var params := {}
## Grottoes as (x, z, zone radius, cavity height): the zone tint and the scatter's "grotto" rules read them.
var grottoes: Array[Vector4] = []
## Arches as (x, z, major radius, minor radius) and tunnels as [from, to, radius] (Vector3s), for the scatter and probes.
var arches: Array[Vector4] = []
var tunnels: Array = []
## Mesas as (x, z, reach, top y) (a segment's middle), for the scatter and the minimap.
var mesas: Array[Vector4] = []
## Set pieces as {kind (SetPieces.Kind), at (Vector2), yaw}: each on a clearing of flat floor.
var pieces: Array[Dictionary] = []
## The open middle's radius (m).
var open_radius := 0.0
## How tall the edge ring and the mesas go (m, local).
var ring_height := 0.0

var _rng := RandomNumberGenerator.new()
var _mesa_records := PackedFloat32Array()


## The layout for `seed_value` in an arena `radius` round whose depth band is `height` tall (the Seabed's edge_height).
static func roll(settings: UnnaturalSettings, seed_value: int, radius: float, height: float) -> TerrainLayout:
	var layout := TerrainLayout.new()
	layout._roll(settings, seed_value, radius, height)
	return layout


func _roll(s: UnnaturalSettings, seed_value: int, radius: float, height: float) -> void:
	_rng.seed = seed_value * 977 + 13
	open_radius = minf(s.terrain_open_radius, radius * 0.7)
	ring_height = s.terrain_ring_height * height
	var ring_inner := radius - s.terrain_ring_inset
	var ring_outer := ring_inner + s.terrain_ring_width
	var band_in := open_radius + 6.0
	var band_out := minf(ring_inner + 4.0, radius + 6.0)
	var clearance := s.terrain_clearance
	var mesa_tall := s.terrain_mesa_height * height
	var r0 := s.terrain_mesa_radius

	# Canyon arcs: a chain of short capsules along an arc, so the mesas join into one wall with a ragged top.
	var canyon_share := 0.7 if s.terrain_canyons > 0 else 0.0
	var per_canyon := floori(s.terrain_mesas * canyon_share / maxf(s.terrain_canyons, 1))
	var base_angle := _rng.randf() * TAU
	for c in s.terrain_canyons:
		if per_canyon <= 0:
			break
		var angle := base_angle + c * TAU / s.terrain_canyons + _rng.randf_range(-0.4, 0.4)
		var r := r0 * _rng.randf_range(0.8, 1.2)
		var reach := r * 1.6
		var lo := band_in + reach
		var hi := band_out - reach * 0.3
		if hi <= lo:
			continue
		var arc_r := _rng.randf_range(lo, hi)
		var step := r * 1.5 / arc_r  # radians between capsule ends
		var start := angle - step * per_canyon * 0.5
		for m in per_canyon:
			var a0 := start + m * step
			var a1 := a0 + step * _rng.randf_range(0.8, 1.1)
			var wobble0 := arc_r + _rng.randf_range(-r, r) * 0.4
			var wobble1 := arc_r + _rng.randf_range(-r, r) * 0.4
			_add_mesa(Vector2.from_angle(a0) * wobble0, Vector2.from_angle(a1) * wobble1, r * _rng.randf_range(0.8, 1.1),
					mesa_tall * _rng.randf_range(0.55, 1.0), _rng.randf_range(0.2, 0.5), _rng.randf_range(0.0, 0.35),
					_rng.randf_range(0.0, 0.18), s.terrain_floor_swell)
	# Singles: mesas standing alone in the band.
	var singles := s.terrain_mesas - per_canyon * s.terrain_canyons
	for n in singles:
		var r := r0 * _rng.randf_range(0.6, 1.3)
		var reach := r * 1.6
		var spot := _spot(band_in + reach, band_out, reach + clearance * 2.0)
		if spot == Vector2.INF:
			continue
		var dir := Vector2.from_angle(_rng.randf() * TAU) * r * _rng.randf_range(0.0, 1.2)
		_add_mesa(spot - dir * 0.5, spot + dir * 0.5, r, mesa_tall * _rng.randf_range(0.4, 0.9), _rng.randf_range(0.25, 0.6),
				_rng.randf_range(0.0, 0.5), _rng.randf_range(0.0, 0.25), s.terrain_floor_swell)

	# Grottoes: a broad mesa with a big overhang, and a cavity under its lip facing the middle.
	var cavities := PackedFloat32Array()
	# Clearings (x, z, radius): the floor's relief and the plateaus stay out of them, so arches, grotto mouths and tunnel
	# ends stand on the flat floor the layout sized them for.
	var clearings := PackedFloat32Array()
	for g in s.terrain_grottoes:
		var r := r0 * 1.7
		var reach := r * 2.0
		var spot := _spot(band_in + reach, band_out, reach + clearance)
		if spot == Vector2.INF:
			continue
		var tall := mesa_tall * 1.1
		_add_mesa(spot, spot + Vector2.from_angle(_rng.randf() * TAU) * r * 0.4, r, tall, 0.15, 0.85, 0.3, s.terrain_floor_swell)
		var inward := -spot.normalized()
		var cav_h := maxf(clearance * 1.6, tall * 0.3)
		var cav := spot + inward * r * 0.55
		cavities.append_array([cav.x, cav_h * 0.45, cav.y, r * 1.05, cav_h, r * 1.05])
		clearings.append_array([cav.x + inward.x * r, cav.y + inward.y * r, r * 1.6])
		grottoes.append(Vector4(spot.x, spot.y, r * 2.4, cav_h))

	# Arches: a vertical torus half sunk in the floor, its hole at least 2 x clearance across.
	var arch_records := PackedFloat32Array()
	for n in s.terrain_arches:
		var minor := maxf(_rng.randf_range(1.8, 3.2), s.terrain_lip * 2.0 + 0.4)
		var major := maxf(_rng.randf_range(9.0, 14.0), (clearance * 2.0 + minor + 2.0) / 0.9)
		var spot := _spot(band_in + major + minor, ring_inner - major - minor - 6.0, major + minor + clearance)
		if spot == Vector2.INF:
			continue
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		arch_records.append_array([spot.x, -major * 0.1, spot.y, dir.x, dir.y, major, minor])
		clearings.append_array([spot.x, spot.y, major + minor + 10.0])
		arches.append(Vector4(spot.x, spot.y, major, minor))

	# Pillars: a slim mesa rising to the top of the depth band, flared at its foot.
	for n in s.terrain_pillars:
		var r := r0 * _rng.randf_range(0.45, 0.7)
		var spot := _spot(band_in + r * 2.0, band_out - r, r * 2.0 + clearance * 2.0)
		if spot == Vector2.INF:
			continue
		_add_mesa(spot, spot + Vector2.from_angle(_rng.randf() * TAU) * r * 0.3, r, height + 3.0, 0.9, 0.1, 0.12, s.terrain_floor_swell)

	# Set pieces: each on a clearing (flat floor) in the band, clear of the rock so far.
	var kinds: Array[int] = []
	for n in s.terrain_whale_falls:
		kinds.append(SetPieces.Kind.WHALE_FALL)
	for n in s.terrain_hulls:
		kinds.append(SetPieces.Kind.HULL)
	for n in s.terrain_vents:
		kinds.append(SetPieces.Kind.VENTS)
	for kind in kinds:
		var room := SetPieces.reach(kind)
		var spot := _spot(band_in + room * 0.5, ring_inner - room - 4.0, room + clearance)
		if spot == Vector2.INF:
			continue
		pieces.append({"kind": kind, "at": spot, "yaw": _rng.randf() * TAU})
		mesas.append(Vector4(spot.x, spot.y, room, 0.0))  # keeps later features off it
		clearings.append_array([spot.x, spot.y, room + 8.0])

	# Tunnels: a horizontal bore through the biggest mesas, radial (so it opens toward the middle and the edge).
	var tunnel_records := PackedFloat32Array()
	var order: Array[int] = []
	for m in mesas.size():
		order.append(m)
	order.sort_custom(func(a: int, b: int) -> bool: return mesas[a].z > mesas[b].z)
	var bore := maxf(clearance * 1.25, 3.5)
	for n in mini(s.terrain_tunnels, order.size()):
		var m := mesas[order[n]]
		if m.w < bore * 2.0 + 4.0:
			continue
		var mid := Vector2(m.x, m.y)
		var dir := mid.normalized().rotated(_rng.randf_range(-0.5, 0.5))
		var half := m.z + 6.0
		var y := bore + 1.0
		var from := Vector3(mid.x - dir.x * half, y, mid.y - dir.y * half)
		var to := Vector3(mid.x + dir.x * half, y + _rng.randf_range(-1.0, 2.0), mid.y + dir.y * half)
		tunnel_records.append_array([from.x, from.y, from.z, to.x, to.y, to.z, bore])
		tunnels.append([from, to, bore])
		clearings.append_array([from.x, from.z, bore * 3.0, to.x, to.z, bore * 3.0])

	var plat_on := s.terrain_plateau_cover > 0.0 and s.terrain_plateau_max > 0.0
	var top := maxf(ring_height, maxf(mesa_tall * 1.15, height)) + 6.0
	var half := maxf(ring_outer, radius) + 8.0
	params = {
		"seed": seed_value,
		"cell": quality_cell(s),
		"chunk_cells": maxi(roundi(s.terrain_chunk_cells * s.terrain_cell / quality_cell(s)), 8),
		"origin": Vector3(-half, -6.0, -half),
		"size": Vector3(half * 2.0, top + 6.0, half * 2.0),
		"sand_cut": -0.3,
		"cull_radius": ring_outer + 3.0,
		"floor_base": -0.8,
		"floor_amp1": s.terrain_floor_swell,
		"floor_freq1": 0.011,
		"floor_amp2": s.terrain_floor_detail,
		"floor_freq2": 0.07,
		"relief_inner": open_radius,
		"relief_outer": open_radius + 35.0,
		"warp_xz": s.terrain_warp,
		"warp_y": s.terrain_warp * 0.25,
		"warp_freq": 0.04,
		"ring_height": ring_height,
		"ring_inner": ring_inner,
		"ring_outer": ring_outer,
		"ring_warp": 8.0,
		"plat_freq": 0.0125,
		"plat_threshold": lerpf(0.5, -0.3, s.terrain_plateau_cover),
		"plat_min": s.terrain_plateau_min,
		"plat_max": s.terrain_plateau_max if plat_on else 0.0,
		"plat_inner": open_radius + 12.0,
		"ero_amp1": 1.2 * s.terrain_erosion,
		"ero_freq1": 0.17,
		"ero_amp2": 0.5 * s.terrain_erosion,
		"ero_freq2": 0.41,
		"ero_fbm": 0.6 * s.terrain_erosion,
		"ero_fade": 3.0,
		"strata_amp": s.terrain_strata,
		"strata_spacing": 4.8,
		"blend": s.terrain_blend,
		"nav": s.terrain_clearance > 0.0 or s.terrain_lip > 0.0,
		"clearance": s.terrain_clearance,
		"lip": s.terrain_lip,
		"spawn": Vector3(0.0, height * 0.5, 0.0),
		"mesas": _mesa_records,
		"arches": arch_records,
		"tunnels": tunnel_records,
		"cavities": cavities,
		"clearings": clearings,
	}


## The grid cell (m) at the settings' quality tier.
static func quality_cell(s: UnnaturalSettings) -> float:
	return s.terrain_cell * [1.5, 1.0, 0.75][clampi(s.terrain_quality, 0, 2)]


## How much of the dressing (kelp, fronds, tufts, carpets, corals, boulders) the quality tier keeps.
static func quality_dressing(s: UnnaturalSettings) -> float:
	return [0.6, 1.0, 1.25][clampi(s.terrain_quality, 0, 2)]


## A mesa: a capsule from `a` to `b` (x, z) of radius `r`, `tall` m above the floor, with flare at the base, an overhang
## at the top and a waist between.
func _add_mesa(a: Vector2, b: Vector2, r: float, tall: float, flare: float, overhang: float, waist: float, swell: float) -> void:
	var base := -0.8 - swell * 0.5  # sunk past the floor's lowest swells
	_mesa_records.append_array([a.x, a.y, b.x, b.y, r, tall - base, flare, overhang, waist, base])
	var mid := (a + b) * 0.5
	mesas.append(Vector4(mid.x, mid.y, r * (1.0 + flare + overhang) + a.distance_to(b) * 0.5, tall))


## A random spot (x, z) between `inner` and `outer` from the middle, at least `gap` from every mesa, arch and grotto so
## far (INF: none in 40 tries).
func _spot(inner: float, outer: float, gap: float) -> Vector2:
	if outer <= inner:
		return Vector2.INF
	for attempt in 40:
		var spot := Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf_range(inner * inner, outer * outer))
		var ok := true
		for m in mesas:
			if spot.distance_to(Vector2(m.x, m.y)) < m.z + gap:
				ok = false
				break
		for a in arches:
			if ok and spot.distance_to(Vector2(a.x, a.y)) < a.z + a.w + gap:
				ok = false
		if ok:
			return spot
	return Vector2.INF
