class_name RaceLayout
extends TerrainLayout
## The terrain feature records for a race track (planning_race.md section 5), in place of TerrainLayout.roll: the whole
## box is rock up to the rim (the slab), the track's channel is carved out of it, and the arch and the split's pillar
## stand in the water. Nothing is rolled: the same track gives the same rock every time. Terrain.build/prepare take it
## as their `fixed` layout, so core names no race.
##
## The channel is a chain of short capsule segments (`STEP` m) along the centreline, each with the track's width and
## height at its ends, open to the sky above its middle except where the track is roofed (tunnel, overhang).

## The channel's segment length along the track (m).
const STEP := 4.0
## The rim: the rock's top (local y) and how far it varies (m), then the water above it that is still generated.
const RIM := 52.0
const RIM_AMP := 3.0
const HEADROOM := 8.0
## The rock beyond the outermost channel edge, so the box has walls on every side (m).
const MARGIN := 30.0
## The arch: its ring is the channel's half width plus this much, as thick as MINOR (m).
const ARCH_EXTRA := 3.0
const ARCH_MINOR := 2.6
## The split's pillar (one per `solids` span of the track): its radius, the top and the foot's depth (m).
const PILLAR_RADIUS := 4.8
const PILLAR_TOP := 62.0
const PILLAR_BASE := -4.0

var track: RaceTrack
## The box the rock fills (local space) and the start line's middle, where the navigability pass begins.
var bounds := AABB()
var start := Vector3.ZERO


## The layout for `track` (a RaceTrack), tuned by the terrain `settings` (cell size, erosion, clearance and the rest).
static func for_track(track_in: RaceTrack, settings: TerrainSettings, rim := RIM, rim_amp := RIM_AMP) -> RaceLayout:
	var layout := RaceLayout.new()
	layout._make(track_in, settings, rim, rim_amp)
	return layout


func _make(track_in: RaceTrack, s: TerrainSettings, rim: float, rim_amp: float) -> void:
	track = track_in
	open_radius = 0.0
	ring_height = 0.0
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var channels := PackedFloat32Array()
	var segments := maxi(roundi(track.lap_length / STEP), 4)
	var step := track.lap_length / segments
	for i in segments:
		var a := track.sample(float(i) * step)
		var b := track.sample(float(i + 1) * step)
		var mid := track.sample((float(i) + 0.5) * step)
		channels.append_array([a.pos.x, a.pos.y, a.pos.z, b.pos.x, b.pos.y, b.pos.z, a.width, b.width, a.height, b.height,
				0.0 if track.roofed(mid.d) else 1.0])
		var reach := maxf(a.width, b.width) * 0.5 + MARGIN
		lo = lo.min(a.pos - Vector3(reach, 0.0, reach))
		hi = hi.max(a.pos + Vector3(reach, 0.0, reach))
	var arch_records := PackedFloat32Array()
	var arch_marks: Array[Dictionary] = []
	for cp in track.checkpoints:
		if cp["tag"] == "arch":
			arch_marks.append(cp)
	for cp in arch_marks:
		var pos: Vector3 = cp["pos"]
		var fwd: Vector3 = cp["forward"]
		var major := float(cp["width"]) * 0.5 + ARCH_EXTRA
		var flat := Vector2(fwd.x, fwd.z).normalized()
		arch_records.append_array([pos.x, pos.y, pos.z, flat.x, flat.y, major, ARCH_MINOR])
		arches.append(Vector4(pos.x, pos.z, major, ARCH_MINOR))
	for span in track.solids:  # a pillar fills each solid span's middle, rounded off at both ends
		var d0 := float(span["d0"]) + PILLAR_RADIUS
		var d1 := float(span["d1"]) - PILLAR_RADIUS
		var a := track.sample(d0).pos
		var b := track.sample(d1).pos
		_mesa_records.append_array([a.x, a.z, b.x, b.z, PILLAR_RADIUS, PILLAR_TOP - PILLAR_BASE, 0.25, 0.0, 0.05, PILLAR_BASE])
		mesas.append(Vector4((a.x + b.x) * 0.5, (a.z + b.z) * 0.5, PILLAR_RADIUS * 1.5 + a.distance_to(b) * 0.5, PILLAR_TOP))
	start = track.sample(0.0).pos
	var top := rim + rim_amp + HEADROOM
	bounds = AABB(Vector3(lo.x, -6.0, lo.z), Vector3(hi.x - lo.x, top + 6.0, hi.z - lo.z))
	var cell := quality_cell(s)
	params = {
		"seed": 7,
		"cell": cell,
		"chunk_cells": maxi(roundi(s.terrain_chunk_cells * s.terrain_cell / cell), 8),
		"origin": bounds.position,
		"size": bounds.size,
		"sand_cut": -0.3,
		"cull_radius": 1.0e9,
		"slab_top": rim,
		"slab_amp": rim_amp,
		"slab_freq": 0.02,
		"floor_base": -0.8,
		"floor_amp1": 0.0,
		"floor_amp2": 0.0,
		"relief_inner": 1.0e6,
		"relief_outer": 2.0e6,
		"warp_xz": 4.0,
		"warp_y": 1.5,
		"warp_freq": 0.04,
		"ring_height": 0.0,
		"plat_max": 0.0,
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
		"spawn": start,
		"mesas": _mesa_records,
		"arches": arch_records,
		"channels": channels,
	}
