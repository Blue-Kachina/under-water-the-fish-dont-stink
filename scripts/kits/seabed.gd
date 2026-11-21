class_name Seabed
extends Node3D
## Unnatural's arena floor (planning_unnatural.md §1; planning_environment.md
## Phases 4-5): rippled sand out past the arena's edge, a living reef (coral
## patches, sponges and anemones where a slow noise says so, open sand and
## sea-grass meadows between, a few kelp forests, rocks, small life), and the
## ruins of a sunken Greek city (a few small temple ruins, rubble thinly
## everywhere). Built from a seed: every machine in co-op lays out the same
## seabed. Everything scattered is a Scatter (tiles culled beyond the murk).
##
## The arena's edge is marked so it reads from far off: a ring of tall rock
## outcrops and a thick band of tall kelp on `radius`, and a faint red wall of
## light rising from it (round 2).
##
## With terrain_enabled (planning_procedural_world.md) a Terrain is built first: rock round the open middle and an edge
## ring that takes the outcrops' place. The reef, ruins and sand keep to the flat floor between the rock (D9), and
## _grow_terrain dresses the rock itself (kelp on its flats as tall as the water above allows, fronds under overhangs,
## tufts on walls, carpets, corals and boulders).

const GEMS := ["staghorn", "brain", "table", "fan"]

var radius := 150.0
var edge_height := 40.0
## The red wall of light on the edge (Unnatural's; off for a mode whose wall is just murk).
var edge_glow := true
var rng := RandomNumberGenerator.new()
## The ruin clusters' middles (this node's space, y 0), for shrines to keep clear of.
var cluster_spots: Array[Vector3] = []
## Where the blade kelp columns stand (x, z; this node's space), for the Look Tank to find a forest.
var kelp_spots: Array[Vector2] = []
## The reef, ruins and edge: tiles of MultiMeshes.
var scatter: Scatter
## The blade flora (kelp columns and their glints; null with `flora_blades` off): tiles of curved-ribbon MultiMeshes.
var flora: FloraField
## The procedural rock (null with terrain off).
var terrain: Terrain
## The set pieces (phase 7) and the background schools.
var pieces: Array[Node3D] = []
var schools: Array[School] = []
var _settings: TerrainSettings
var _glow := ShaderMaterial.new()
var _clusters: Array[MeshInstance3D] = []
var _reef_noise := FastNoiseLite.new()
var _kelp_noise := FastNoiseLite.new()
var _grass_noise := FastNoiseLite.new()
var _murk := -1.0
## What the flora grows on and round (this node's space), recorded as the scenery is laid out: rocks (x, z, size, slab 1/0),
## ruins ({at, yaw, seed}), outcrop rocks ({at, size, upper}) and the old sea-grass spots (x, z, size).
var _rocks: Array[Vector4] = []
var _ruins: Array[Dictionary] = []
var _outcrops: Array[Dictionary] = []
var _grass_spots: Array[Vector3] = []
var _cover_noise := FastNoiseLite.new()
## A terrain being generated ahead on a worker thread (prefetch()), and what it was made for.
var _prefetched: Terrain
var _prefetch_key := ""
var _prefetch_task := -1


## The seabed `settings.arena_radius` round, its top at this node's height.
func setup(settings: TerrainSettings, rng_seed := 11, edge_tall := 40.0) -> void:
	_settings = settings
	radius = settings.arena_radius
	edge_height = edge_tall
	rng.seed = rng_seed
	WaterLook.biome_seed = rng_seed
	for child in get_children():
		child.queue_free()
	_clusters.clear()
	cluster_spots.clear()
	_murk = -1.0
	_rocks.clear()
	_ruins.clear()
	_outcrops.clear()
	_grass_spots.clear()
	_cover_noise.seed = rng_seed * 7 + 3
	_cover_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_cover_noise.frequency = 0.09
	for noise: FastNoiseLite in [_reef_noise, _kelp_noise, _grass_noise]:
		noise.seed = rng.randi()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_reef_noise.frequency = 0.035
	_kelp_noise.frequency = 0.02
	_grass_noise.frequency = 0.045
	scatter = Scatter.new()
	scatter.name = "Scatter"
	add_child(scatter)
	flora = null
	if settings.flora_blades:
		flora = FloraField.new()
		flora.name = "Flora"
		flora.lod_distance = settings.flora_lod_distance
		flora.far_keep = settings.flora_far_keep
		flora.rows_near = settings.flora_rows
		flora.rows_far = settings.flora_rows_far
		flora.count_mult = settings.flora_blade_mult
		flora.cover_cap = settings.flora_cover_budget
		add_child(flora)
	_build_sand()
	terrain = null
	if settings.terrain_enabled:
		var key := _terrain_key(settings, rng_seed, edge_height)
		if _prefetched != null and _prefetch_key == key:
			WorkerThreadPool.wait_for_task_completion(_prefetch_task)
			terrain = _prefetched
			_prefetched = null
			_prefetch_task = -1
			add_child(terrain)
			terrain.apply(settings)
		else:
			_drop_prefetch()
			terrain = Terrain.new()
			terrain.name = "Terrain"
			add_child(terrain)
			terrain.build(settings, rng_seed, radius, edge_height)
		_build_set_pieces()
	_build_ruins()
	_build_reef()
	_build_edge()
	_build_cover()
	scatter.build()
	if flora:
		flora.build()
	_push_flora_look()
	_build_life()
	_murk = -1.0


## Starts generating the terrain setup() will want for `rng_seed` on a worker thread (the stage-clear screen calls it
## for the next stage, so the stage change only builds the nodes). A no-op with terrain off.
func prefetch(settings: TerrainSettings, rng_seed: int, edge_tall: float) -> void:
	if not settings.terrain_enabled:
		return
	var key := _terrain_key(settings, rng_seed, edge_tall)
	if _prefetched != null and _prefetch_key == key:
		return
	_drop_prefetch()
	_prefetched = Terrain.new()
	_prefetched.name = "Terrain"
	_prefetch_key = key
	_prefetch_task = WorkerThreadPool.add_task(_prefetched.prepare.bind(settings, rng_seed, settings.arena_radius, edge_tall), false,
			"terrain prefetch")


func _terrain_key(settings: TerrainSettings, rng_seed: int, edge_tall: float) -> String:
	return "%d/%.1f/%.1f/%.2f/%d" % [rng_seed, settings.arena_radius, edge_tall, settings.terrain_cell, settings.terrain_quality]


func _drop_prefetch() -> void:
	if _prefetch_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_prefetch_task)
	if _prefetched != null:
		_prefetched.free()
	_prefetched = null
	_prefetch_task = -1
	_prefetch_key = ""


func _exit_tree() -> void:
	_drop_prefetch()


## The panel's blade look (live), onto the shared blade materials.
func _push_flora_look() -> void:
	if _settings == null or flora == null:
		return
	FloraField.push_look(_settings.flora_sway, _settings.flora_width, _settings.flora_length, _settings.flora_brightness,
			flora.draw_distance if flora.draw_distance > 0.0 else 150.0, _settings.flora_far_keep)


func _process(_delta: float) -> void:
	_push_flora_look()


## Whether a reef patch covers `spot` (x, z).
func is_reef(spot: Vector2) -> bool:
	return _reef_noise.get_noise_2dv(spot) > 0.5 - _settings.reef_cover


## Clears the scenery round `spot` (global; a shrine went there).
func clear_around(spot: Vector3, clearing: float) -> void:
	if is_instance_valid(scatter):
		scatter.clear_around(to_local(spot), clearing)
	if is_instance_valid(flora):
		flora.clear_around(to_local(spot), clearing)


## The murk's density (0: none): the edge's glow fades with distance as the
## fog would (it's additive and fog-free, so the fog can't do it), and the
## scenery isn't drawn past where the horde stops being drawn.
func set_murk(density: float) -> void:
	_glow.set_shader_parameter("murk", density)
	if absf(density - _murk) < 0.0005 or not is_instance_valid(scatter):
		return
	_murk = density
	var reach := _settings.scenery_draw_distance
	if reach <= 0.0 and density > 0.0:
		reach = TerrainSettings.fog_reach(_settings.murk_cull, density) + _settings.murk_cull_margin + Scatter.TILE * 0.7
	scatter.draw_distance = reach
	if flora:
		flora.draw_distance = _settings.flora_draw_distance if _settings.flora_draw_distance > 0.0 else reach
	for cluster in _clusters:
		cluster.visibility_range_end = reach
	if is_instance_valid(terrain):
		terrain.set_draw_distance(reach)


# --- Sand ------------------------------------------------------------------

func _build_sand() -> void:
	var sand := MeshInstance3D.new()
	sand.name = "Sand"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.6
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/sand.gdshader")
	plane.material = material
	sand.mesh = plane
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sand)


# --- Ruins (Phase 4) -----------------------------------------------------------

func _build_ruins() -> void:
	for n in _settings.ruin_clusters:
		var spot := Vector2.ZERO
		var found := false
		for attempt in 40:
			spot = _point(0.85)
			found = spot.length() > maxf(_settings.scenery_clearing, 0.0) + 22.0 and _flat(spot, 14.0)
			for other in cluster_spots:
				if Vector2(other.x, other.z).distance_to(spot) < _settings.ruin_spacing:
					found = false
					break
			if found:
				break
		if not found:
			continue
		var at := Vector3(spot.x, 0.0, spot.y)
		cluster_spots.append(at)
		var ruin := MeshInstance3D.new()
		ruin.name = "Ruin%d" % n
		var key := "ruin/%d" % (rng.seed % 100000 * 10 + n)
		var seed_value := rng.randi()
		ruin.mesh = GreekKit.cached(key, func() -> MeshKit: return RuinCluster.build(seed_value), GreekKit.marble())
		ruin.position = at
		ruin.rotation.y = rng.randf() * TAU
		_ruins.append({"at": at, "yaw": ruin.rotation.y, "seed": seed_value})
		add_child(ruin)
		_clusters.append(ruin)
	if _settings.ruin_rubble <= 0:
		return
	# Rubble: half of it thickening round the clusters, half anywhere.
	var kinds: Array[Mesh] = []
	for n in 3:
		kinds.append(GreekKit.cached("rubble/drum/%d" % n, func() -> MeshKit: return GreekKit.drum(0.9, GreekKit.COLUMN_RADIUS, n > 0, 900 + n),
				GreekKit.marble()))
		kinds.append(GreekKit.cached("rubble/block/%d" % n, func() -> MeshKit:
				return GreekKit.block(Vector3(0.6 + n * 0.3, 0.38 + n * 0.08, 0.5 + n * 0.12), 910 + n), GreekKit.marble()))
	kinds.append(GreekKit.cached("rubble/capital", func() -> MeshKit: return GreekKit.capital(GreekKit.COLUMN_RADIUS * 0.94, 920), GreekKit.marble()))
	kinds.append(GreekKit.cached("rubble/amphora", func() -> MeshKit: return GreekKit.amphora(false, false, 930), GreekKit.marble()))
	kinds.append(GreekKit.cached("rubble/amphora_broken", func() -> MeshKit: return GreekKit.amphora(false, true, 931), GreekKit.marble()))
	kinds.append(GreekKit.cached("rubble/krater", func() -> MeshKit: return GreekKit.amphora(true, true, 932), GreekKit.marble()))
	var placed := {}
	for n in _settings.ruin_rubble:
		var spot := _point(1.0)
		if not cluster_spots.is_empty() and n % 2 == 0:
			var near: Vector3 = cluster_spots[rng.randi() % cluster_spots.size()]
			spot = Vector2(near.x, near.z) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10.0, 28.0)
		if not _clear_of_start(spot) or not _flat(spot, 1.0):
			continue
		var kind := kinds[rng.randi() % kinds.size()]
		_rocks.append(Vector4(spot.x, spot.y, 0.7, 0.0))  # a stone of rubble
		var lying := rng.randf() < 0.6
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		var lift := 0.0
		if lying:
			basis = basis * Basis(Vector3.BACK, PI / 2.0 + rng.randf_range(-0.2, 0.2))
			lift = 0.22
		basis = basis * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
		var size := rng.randf_range(0.85, 1.2)
		if not placed.has(kind):
			placed[kind] = [[] as Array[Transform3D], [] as Array[Color]]
		(placed[kind][0] as Array[Transform3D]).append(Transform3D(basis.scaled(Vector3.ONE * size), Vector3(spot.x, lift - 0.12, spot.y)))
		(placed[kind][1] as Array[Color]).append(Color(rng.randf(), rng.randf(), rng.randf(), 0.0))
	for kind: Mesh in placed:
		scatter.add(kind, placed[kind][0], placed[kind][1])


# --- The reef (Phase 5) -------------------------------------------------------

func _build_reef() -> void:
	# Corals in reef patches.
	var gems := {}
	for n in _settings.corals:
		var spot := _find(func(s: Vector2) -> bool: return is_reef(s) and _clear_of_ruins(s, 9.0))
		if spot == Vector2.INF:
			continue
		var what: String = GEMS[_pick([0.34, 0.24, 0.2, 0.22])]
		var size := rng.randf_range(0.7, 1.5) * (1.6 if what == "table" else 1.0)
		_put(gems, ReefKit.mesh(what, rng.randi() % ReefKit.VARIANTS), spot, size, 0.08, -0.05)
	_flush(gems)
	var sponges := {}
	for n in _settings.sponges:
		var spot := _find(func(s: Vector2) -> bool: return is_reef(s) and _clear_of_ruins(s, 9.0))
		if spot != Vector2.INF:
			_put(sponges, ReefKit.mesh("tube_sponge" if rng.randf() < 0.6 else "barrel", rng.randi() % ReefKit.VARIANTS), spot,
					rng.randf_range(1.1, 2.0), 0.1, -0.06)
	_flush(sponges)
	var anemones := {}
	for n in _settings.anemones:
		# Mostly in the reef, some out on the sand and on the ruins' rubble.
		var spot := _find(func(s: Vector2) -> bool: return is_reef(s) or rng.randf() < 0.25)
		if spot != Vector2.INF:
			_put(anemones, ReefKit.mesh("anemone", rng.randi() % ReefKit.VARIANTS), spot, rng.randf_range(1.2, 2.4), 0.15, -0.02)
	_flush(anemones)
	# Rocks: anywhere, more at the reef's edges.
	var rocks := {}
	for n in _settings.seabed_rocks:
		var spot := _find(func(s: Vector2) -> bool:
				return _clear_of_ruins(s, 8.0) and (absf(_reef_noise.get_noise_2dv(s) - (0.5 - _settings.reef_cover)) < 0.15 or rng.randf() < 0.4))
		if spot == Vector2.INF:
			continue
		var size := rng.randf_range(0.6, 3.2) * (2.2 if rng.randf() < 0.06 else 1.0)
		var slab := rng.randf() < 0.35
		_put(rocks, ReefKit.mesh("slab" if slab else "boulder", rng.randi() % ReefKit.VARIANTS), spot, size, 0.3, -0.1 * size)
		_rocks.append(Vector4(spot.x, spot.y, size, 1.0 if slab else 0.0))
	_flush(rocks)
	# Kelp forests: clumps where the kelp noise is high.
	var kelp := {}
	var planted := 0
	var tries := 0
	while planted < _settings.seabed_kelp and tries < _settings.seabed_kelp * 30:
		tries += 1
		var centre := _point(1.05)
		if _kelp_noise.get_noise_2dv(centre) < 0.25 or not _clear_of_ruins(centre, 10.0) or not _clear_of_start(centre) \
				or not _flat(centre, 4.0):
			continue
		for k in rng.randi_range(3, 7):
			var spot := centre + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
			if flora:
				_plant_column(spot, rng.randf_range(0.8, 1.25), 1.0)
			else:
				_put(kelp, ReefKit.mesh("kelp", rng.randi() % ReefKit.VARIANTS), spot, rng.randf_range(0.8, 1.25), 0.06, 0.0, false)
			planted += 1
	_flush_kelp(kelp)
	# Sea-grass meadows, out on the sand.
	var grass := {}
	for n in _settings.seagrass:
		var spot := _find(func(s: Vector2) -> bool:
				return not is_reef(s) and _grass_noise.get_noise_2dv(s) > 0.05 and _clear_of_ruins(s, 7.0), 6)
		if spot != Vector2.INF:
			var tall := rng.randf_range(0.7, 1.4)
			_put(grass, ReefKit.mesh("seagrass", rng.randi() % ReefKit.VARIANTS), spot, tall, 0.1, 0.0)
			_grass_spots.append(Vector3(spot.x, spot.y, tall))
	if not (flora and _settings.flora_replace_seagrass):
		_flush(grass)
	# Small life on the open sand.
	var life := {}
	for n in _settings.small_life:
		var spot := _find(func(s: Vector2) -> bool: return not is_reef(s))
		if spot != Vector2.INF:
			var what: String = ["starfish", "urchin", "clam"][_pick([0.45, 0.3, 0.25])]
			_put(life, ReefKit.mesh(what, rng.randi() % ReefKit.VARIANTS), spot, rng.randf_range(1.6, 2.8), 0.1, -0.01)
	_flush(life)


## A kelp column of blades at `spot` (x, z): 6.5-9.5 m x `size` tall. Draws its own dice from one value of the seabed's, so the
## layout of everything after it does not depend on the blade settings. `density` multiplies its blades.
func _plant_column(spot: Vector2, size: float, density: float) -> void:
	var dice := RandomNumberGenerator.new()
	kelp_spots.append(spot)
	dice.seed = rng.randi()
	var roll := dice.randf()
	var kind := 1 if roll < 0.08 else (2 if roll < 0.2 else 0)
	var glints := _settings.flora_glints_per_m if WaterLook.shared().glints_per_plant > 0 else 0.0
	flora.add_kelp_column(Vector3(spot.x, 0.0, spot.y), dice.randf_range(6.5, 9.5) * size * _settings.flora_kelp_height, kind,
			_settings.flora_blades_per_m * _settings.flora_blade_mult, density * _settings.flora_kelp_density, glints, 1.0, dice)


## Copies of `mesh` waiting to go into the scatter: mesh -> [transforms, customs].
func _put(into: Dictionary, mesh: Mesh, spot: Vector2, size: float, tilt: float, sink: float, upright := true) -> void:
	var basis := Basis(Vector3.UP, rng.randf() * TAU)
	if upright and tilt > 0.0:
		basis = Basis(Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, tilt)) * basis
	if not into.has(mesh):
		into[mesh] = [[] as Array[Transform3D], [] as Array[Color]]
	(into[mesh][0] as Array[Transform3D]).append(Transform3D(basis.scaled(Vector3.ONE * size), Vector3(spot.x, sink, spot.y)))
	(into[mesh][1] as Array[Color]).append(Color(rng.randf(), rng.randf(), rng.randf(), 0.0))


func _flush(sets: Dictionary) -> void:
	for mesh: Mesh in sets:
		scatter.add(mesh, sets[mesh][0], sets[mesh][1])


## Kelp, and its glints: a second mesh scattered with the plants' own transforms, so tiles and culling treat them as one.
func _flush_kelp(sets: Dictionary) -> void:
	_flush(sets)
	for mesh: Mesh in sets:
		var glints := KelpGlints.mesh_for(mesh)
		if glints:
			scatter.add(glints, sets[mesh][0], sets[mesh][1])


## A random point that passes `test` and is clear of the start (INF: none found in `tries`).
func _find(test: Callable, tries := 24) -> Vector2:
	for attempt in tries:
		var spot := _point(1.05)
		if _clear_of_start(spot) and _flat(spot, 1.5) and test.call(spot):
			return spot
	return Vector2.INF


## An index into `weights` (summing to about 1), at random.
func _pick(weights: Array) -> int:
	var roll := rng.randf()
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


func _clear_of_start(spot: Vector2) -> bool:
	return spot.length() > _settings.scenery_clearing


## Whether `spot` (x, z) is on the flat sand with `margin` m clear of any rock (always, with no terrain).
func _flat(spot: Vector2, margin: float) -> bool:
	if terrain == null:
		return true
	for piece in terrain.layout.pieces:
		if spot.distance_to(piece["at"]) < SetPieces.reach(piece["kind"]) * 0.8 + margin:
			return false
	return terrain.field.floor_y(spot.x, spot.y) < 0.15 and terrain.field.sdf(Vector3(spot.x, 0.6, spot.y)) > margin


## The layout's set pieces, each standing on the floor of its clearing.
func _build_set_pieces() -> void:
	pieces.clear()
	for i in terrain.layout.pieces.size():
		var record: Dictionary = terrain.layout.pieces[i]
		var piece := SetPieces.build(record["kind"], rng.seed * 31 + i * 7 + 1, _settings.terrain_collision)
		var at: Vector2 = record["at"]
		piece.position = Vector3(at.x, maxf(terrain.field.floor_y(at.x, at.y), 0.0), at.y)
		piece.rotation.y = record["yaw"]
		add_child(piece)
		pieces.append(piece)


## Background life: a few schools roaming high over the outer band, clear of the mesas' tops.
func _build_life() -> void:
	schools.clear()
	if _settings.terrain_schools <= 0 or not _settings.terrain_enabled:
		return
	var nature := SchoolSettings.new()
	nature.fish_per_school = _settings.terrain_school_fish
	nature.roam_radius = 22.0
	nature.roam_height = 2.0
	var dice := RandomNumberGenerator.new()
	dice.seed = rng.seed * 17 + 9
	var kinds := FishCharacter.pickable_classes()
	var inner := terrain.layout.open_radius if terrain else radius * 0.5
	for n in _settings.terrain_schools:
		var school := School.new()
		school.name = "School%d" % n
		add_child(school)
		var spot := Vector2.from_angle(dice.randf() * TAU) * dice.randf_range(inner, radius * 0.85)
		var at := to_global(Vector3(spot.x, edge_height * 0.82, spot.y))
		school.setup(nature, at, Vector3.FORWARD.rotated(Vector3.UP, dice.randf() * TAU), kinds[dice.randi() % kinds.size()], dice.randi())
		schools.append(school)


func _clear_of_ruins(spot: Vector2, margin: float) -> bool:
	for at in cluster_spots:
		if Vector2(at.x, at.z).distance_to(spot) < margin:
			return false
	return true


# --- The edge -------------------------------------------------------------------

## The edge's outcrops (piles of big rocks), its kelp band, and its wall of light.
func _build_edge() -> void:
	if _settings.edge_rocks > 0 and (terrain == null or terrain.layout.ring_height <= 0.0):
		var piles := {}
		for i in _settings.edge_rocks:
			var angle := (float(i) + rng.randf_range(-0.3, 0.3)) / _settings.edge_rocks * TAU
			var base := Vector2.from_angle(angle) * radius * rng.randf_range(1.0, 1.08)
			# Each outcrop: a broad base of slabs, then rocks stacked up it,
			# shrinking and leaning as they go, to `tall`.
			var tall := edge_height * rng.randf_range(0.35, 0.9)
			var width := rng.randf_range(5.0, 9.0)
			var y := 0.0
			var drift := Vector2.ZERO
			var k := 0
			while y < tall and k < 9:
				var w := width * pow(0.82, k) * rng.randf_range(0.75, 1.2)
				var h := w * rng.randf_range(0.7, 1.2)
				var what := "slab" if k == 0 else "boulder"
				var mesh := ReefKit.mesh(what, rng.randi() % ReefKit.VARIANTS)
				var size := Vector3(w * 1.2, h * (3.0 if what == "slab" else 1.6), w * 1.1)
				var lean := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
				var at := Vector3(base.x + drift.x, y, base.y + drift.y)
				if not piles.has(mesh):
					piles[mesh] = [[] as Array[Transform3D], [] as Array[Color]]
				(piles[mesh][0] as Array[Transform3D]).append(Transform3D(lean.scaled(size), at))
				(piles[mesh][1] as Array[Color]).append(Color(rng.randf(), rng.randf(), 0.0, 0.0))
				_outcrops.append({"at": at, "size": size, "upper": k > 0, "slab": what == "slab"})
				y += h * 0.75
				drift += Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * w * 0.25
				k += 1
		_flush(piles)
	if _settings.edge_kelp > 0:
		var band := {}
		var most := maxf(edge_height * 0.75 / 8.0, 1.0)
		for i in _settings.edge_kelp:
			var at := Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.95, 1.06)
			if terrain and not _flat(at, 1.0):
				at = Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.8, 0.92)  # the ring's in the way: just inside it
				if not _flat(at, 1.0):
					continue
			if flora:
				_plant_column(at, rng.randf_range(most * 0.45, most), _settings.flora_edge_density)
			else:
				_put(band, ReefKit.mesh("kelp", rng.randi() % ReefKit.VARIANTS), at, rng.randf_range(most * 0.45, most), 0.05, 0.0, false)
		_flush_kelp(band)
	if not edge_glow:
		return
	var wall := MeshInstance3D.new()
	wall.name = "EdgeGlow"
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = edge_height
	tube.radial_segments = 96
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	var glow := _glow
	glow.shader = _edge_shader()
	glow.set_shader_parameter("tall", edge_height)
	tube.material = glow
	wall.mesh = tube
	wall.position.y = edge_height * 0.5
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)


## The edge's wall of light: red, brightest at the seabed and fading upward,
## both sides showing, breathing slowly, and fading into the murk.
static func _edge_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float tall = 40.0;
uniform float murk = 0.0;
varying float rise;
void vertex() {
	rise = clamp(VERTEX.y / tall + 0.5, 0.0, 1.0);  // 0 at the seabed, 1 at the top
}
void fragment() {
	float breathe = 0.8 + 0.2 * sin(TIME * 1.3 + UV.x * 40.0);
	float glow = pow(1.0 - rise, 2.0) * 0.6 * breathe;
	glow *= exp(-length(VERTEX) * murk);  // VERTEX is in view space here
	ALBEDO = vec3(1.0, 0.12, 0.08) * glow;
	ALPHA = glow;
}
"""
	return shader


## A random point on the floor (x, z), out to `reach` x the arena's radius.
func _point(reach: float) -> Vector2:
	return Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius * reach


# --- Ground cover, grass, tufts and fronds (flora pass, phase 3) ----------------------------
# Laid out with a dice of its own (from the seed alone), so the rest of the seabed doesn't depend on any of it. Structure first
# (ruins, outcrops, rocks), then grass, then the carpets, which take whatever is left of the blade budget.

func _build_cover() -> void:
	if flora == null:
		return
	var dice := RandomNumberGenerator.new()
	dice.seed = rng.seed * 31 + 17
	for ruin in _ruins:
		ruin["lay"] = RuinCluster.layout(ruin["seed"])
	var grid := _rock_grid()
	_grow_ruins(dice)
	_grow_outcrops(dice)
	_grow_rocks(dice)
	_grow_terrain(dice)
	_grow_grass(dice, grid)
	_grow_carpets(dice, grid)


## 0..1: how much the spot is reef (a soft version of is_reef).
func _reef_zone(spot: Vector2) -> float:
	var edge := 0.5 - _settings.reef_cover
	return smoothstep(edge - 0.25, edge + 0.1, _reef_noise.get_noise_2dv(spot))


## A whole number with the fraction of `x` as its chance of one more.
func _roll(x: float, dice: RandomNumberGenerator) -> int:
	var whole := floori(x)
	return whole + (1 if dice.randf() < x - whole else 0)


## Rocks (and rubble) by 8 m cell, so the carpets can keep off them.
func _rock_grid() -> Dictionary:
	var grid := {}
	for i in _rocks.size():
		var key := Vector2i(floori(_rocks[i].x / 8.0), floori(_rocks[i].y / 8.0))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(i)
	return grid


## Whether `spot` is inside a rock or on a ruin's platform.
func _blocked(spot: Vector2, grid: Dictionary) -> bool:
	var cell := Vector2i(floori(spot.x / 8.0), floori(spot.y / 8.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for i: int in grid.get(Vector2i(cell.x + dx, cell.y + dz), []):
				var rock := _rocks[i]
				var reach := rock.z * 0.5
				if spot.distance_squared_to(Vector2(rock.x, rock.y)) < reach * reach:
					return true
	for ruin in _ruins:
		var local := _ruin_local(ruin, spot)
		var lay: Dictionary = ruin["lay"]
		if absf(local.x) < (lay["width"] as float) * 0.5 + 0.4 and absf(local.y) < (lay["depth"] as float) * 0.5 + 0.4:
			return true
	return false


## A ruin's local (x, z) for a seabed point.
func _ruin_local(ruin: Dictionary, spot: Vector2) -> Vector2:
	var at: Vector3 = ruin["at"]
	var d := spot - Vector2(at.x, at.z)
	var yaw: float = ruin["yaw"]
	return Vector2(d.x * cos(yaw) - d.y * sin(yaw), d.x * sin(yaw) + d.y * cos(yaw))


## A ruin-local point as a seabed point.
func _ruin_world(ruin: Dictionary, local: Vector3) -> Vector3:
	return Basis(Vector3.UP, ruin["yaw"] as float) * local + (ruin["at"] as Vector3)


## The yaw (flora convention: blades lean along (cos, sin) in x, z) of a ruin-local direction.
func _ruin_yaw(ruin: Dictionary, dir: Vector2) -> float:
	var w := Basis(Vector3.UP, ruin["yaw"] as float) * Vector3(dir.x, 0.0, dir.y)
	return atan2(w.z, w.x)


func _cover_type(zone: float, dice: RandomNumberGenerator) -> int:
	if zone > 0.4:
		return FloraField.Type.MAGENTA
	return FloraField.Type.CYAN if dice.randf() < 0.7 else FloraField.Type.TEAL


## Ruins: a carpet round the platform's edge, tufts on the platform's step and the feet of the standing columns, fronds under
## the beams that still stand.
func _grow_ruins(dice: RandomNumberGenerator) -> void:
	var mul := _settings.flora_ruin_cover
	if mul <= 0.0:
		return
	var size := _settings.flora_cover_size
	for ruin in _ruins:
		var lay: Dictionary = ruin["lay"]
		var w: float = lay["width"]
		var d: float = lay["depth"]
		# Carpet in a 3 m band outside the platform, thinning outward.
		var band := 3.0
		var tries := roundi(_settings.flora_cover_per_m2 * mul * ((w + band * 2.0) * (d + band * 2.0) - w * d) * 0.8)
		for i in tries:
			if not flora.has_room():
				break
			var local := Vector2(dice.randf_range(-w * 0.5 - band, w * 0.5 + band), dice.randf_range(-d * 0.5 - band, d * 0.5 + band))
			var out := maxf(absf(local.x) - w * 0.5, absf(local.y) - d * 0.5)
			if out < 0.3 or dice.randf() > 1.0 - out / band:
				continue
			var spot := _ruin_world(ruin, Vector3(local.x, 0.0, local.y))
			var zone := _reef_zone(Vector2(spot.x, spot.z))
			flora.add_tuft(Vector3(spot.x, -0.03, spot.z), FloraField.Type.MAGENTA if dice.randf() < 0.5 + zone * 0.4 else FloraField.Type.CYAN,
					size, dice)
		# The platform's lower step: tufts leaning out of its side.
		var perimeter := 2.0 * (w + d)
		for i in _roll(perimeter * 0.5 * mul * _settings.flora_wall_tufts / 3.0, dice):
			if not flora.has_room():
				break
			var along := dice.randf() * perimeter
			var edge := Vector2.ZERO
			var normal := Vector2.ZERO
			if along < w:
				edge = Vector2(along - w * 0.5, d * 0.5)
				normal = Vector2(0.0, 1.0)
			elif along < w + d:
				edge = Vector2(w * 0.5, along - w - d * 0.5)
				normal = Vector2(1.0, 0.0)
			elif along < 2.0 * w + d:
				edge = Vector2(w * 0.5 - (along - w - d), -d * 0.5)
				normal = Vector2(0.0, -1.0)
			else:
				edge = Vector2(-w * 0.5, d * 0.5 - (along - 2.0 * w - d))
				normal = Vector2(-1.0, 0.0)
			var spot := _ruin_world(ruin, Vector3(edge.x, 0.12, edge.y))
			flora.add_wall_tuft(spot, _ruin_yaw(ruin, normal), 5.0, FloraField.Type.OLIVE if dice.randf() < 0.6 else FloraField.Type.VIOLET,
					0.5 * size, dice)
		# The feet of the standing columns.
		for base: Vector3 in lay["bases"]:
			for i in _roll(_settings.flora_wall_tufts * mul * 0.7, dice):
				if not flora.has_room():
					break
				var a := dice.randf() * TAU
				var foot := base + Vector3(cos(a), 0.0, sin(a)) * (GreekKit.COLUMN_RADIUS + 0.03) + Vector3.UP * dice.randf_range(0.0, 0.3)
				flora.add_wall_tuft(_ruin_world(ruin, foot), _ruin_yaw(ruin, Vector2(cos(a), sin(a))), 4.0, FloraField.Type.OLIVE, 0.45 * size, dice)
		# Fronds hanging from the beams.
		var gap: float = lay["gap"]
		for lintel: Vector3 in lay["lintels"]:
			for i in _roll(_settings.flora_frond_clumps * mul, dice):
				if not flora.has_room():
					break
				var local := lintel + Vector3(dice.randf_range(-gap * 0.5, gap * 0.5), -0.1, dice.randf_range(-0.25, 0.25))
				var spot := _ruin_world(ruin, local)
				var zone := _reef_zone(Vector2(spot.x, spot.z))
				flora.add_hanging(spot, _settings.flora_frond_blades, FloraField.Type.RED,
						FloraField.Type.RED if zone > 0.3 else FloraField.Type.OLIVE, 1.0, 0.25, dice)


## Outcrops (the arena's rock piles): tufts on the sides of every rock, fronds under the stacked ones.
func _grow_outcrops(dice: RandomNumberGenerator) -> void:
	var size := _settings.flora_cover_size
	for rock in _outcrops:
		if not flora.has_room():
			return
		var at: Vector3 = rock["at"]
		var dims: Vector3 = rock["size"]
		var mean := (dims.x + dims.z) * 0.5
		var slab: bool = rock["slab"]
		var zone := _reef_zone(Vector2(at.x, at.z))
		for i in _roll(_settings.flora_wall_tufts * clampf(mean / 5.0, 0.5, 3.0), dice):
			var a := dice.randf() * TAU
			var el := dice.randf_range(-0.3, 0.9)
			var r := 0.55 * mean * cos(el) * 0.92
			var y := at.y + dims.y * ((0.12 + 0.1 * sin(el)) if slab else (0.18 + 0.34 * sin(el)))
			flora.add_wall_tuft(Vector3(at.x + cos(a) * r, y, at.z + sin(a) * r), a, 5.0,
					FloraField.Type.VIOLET if zone > 0.4 and dice.randf() < 0.6 else FloraField.Type.OLIVE, clampf(mean / 6.0, 0.8, 2.5) * size, dice)
		if not rock["upper"]:
			continue
		for i in _roll(_settings.flora_frond_clumps, dice):
			var a := dice.randf() * TAU
			var r := 0.48 * mean
			var root_y := at.y + dims.y * 0.06
			var drop := minf(clampf(dims.y / 3.0, 0.8, 2.2), root_y * 1.1 / 3.2)  # no longer than the drop to the sand
			if drop < 0.2:
				continue
			flora.add_hanging(Vector3(at.x + cos(a) * r, root_y, at.z + sin(a) * r), _settings.flora_frond_blades, FloraField.Type.RED,
					FloraField.Type.RED if zone > 0.3 else FloraField.Type.OLIVE, drop, 0.5 * drop, dice)


## Seabed rocks: a ring of carpet tufts round the foot, tufts on the sides.
func _grow_rocks(dice: RandomNumberGenerator) -> void:
	var size := _settings.flora_cover_size
	for rock in _rocks:
		if not flora.has_room():
			return
		var spot := Vector2(rock.x, rock.y)
		var zone := _reef_zone(spot)
		var s := rock.z
		for i in _roll(_settings.flora_rock_tufts * 1.1 * s, dice):
			var p := spot + Vector2.from_angle(dice.randf() * TAU) * dice.randf_range(0.45, 0.9) * s
			if not _clear_of_start(p):
				continue
			flora.add_tuft(Vector3(p.x, -0.03, p.y), _cover_type(zone, dice), size, dice)
		if s < 0.8:  # the rubble's small stones: no side tufts
			continue
		var slab := rock.w > 0.5
		for i in _roll(_settings.flora_wall_tufts, dice):
			var a := dice.randf() * TAU
			var el := dice.randf_range(-0.1, 0.8)
			var r := 0.55 * s * cos(el) * 0.92
			var y := s * ((0.02 + 0.1 * sin(el)) if slab else (0.08 + 0.34 * sin(el)))
			flora.add_wall_tuft(Vector3(spot.x + cos(a) * r, y, spot.y + sin(a) * r), a, 4.0,
					FloraField.Type.VIOLET if zone > 0.4 and dice.randf() < 0.6 else FloraField.Type.OLIVE, clampf(s * 0.5, 0.4, 1.5) * size, dice)


## Grass: a clump at each old sea-grass spot, and bigger clusters on open ground in the grass zones.
func _grow_grass(dice: RandomNumberGenerator, grid: Dictionary) -> void:
	var gs := _settings.flora_grass_size
	if _settings.flora_replace_seagrass and _settings.flora_seagrass_blades > 0.0:
		for spot in _grass_spots:
			if not flora.has_room():
				return
			var type := FloraField.Type.TEAL if dice.randf() < 0.75 else FloraField.Type.CYAN
			var lmin := 0.5 * spot.z * gs
			var lmax := 1.4 * spot.z * gs
			flora.add_cluster(Vector3(spot.x, -0.02, spot.y), _settings.flora_seagrass_blades, type, lmin, lmax, 0.11 * lmin, 0.09 * lmax + 0.02, 0.6, 1.5, dice)
	var placed := 0
	var tries := 0
	while placed < _settings.flora_grass_clusters and tries < _settings.flora_grass_clusters * 14 and flora.has_room():
		tries += 1
		var spot := Vector2.from_angle(dice.randf() * TAU) * sqrt(dice.randf()) * radius * 0.93
		var reef := _reef_zone(spot)
		var hot := smoothstep(0.0, 0.35, _grass_noise.get_noise_2dv(spot)) * (1.0 - reef * 0.8) + reef * 0.1
		if dice.randf() > hot or not _clear_of_start(spot) or _blocked(spot, grid):
			continue
		var type := FloraField.Type.TEAL if dice.randf() < 0.8 else FloraField.Type.CYAN
		flora.add_cluster(Vector3(spot.x, -0.15, spot.y), _settings.flora_grass_blades * dice.randf_range(0.6, 1.4), type, 1.0 * gs, 3.0 * gs,
				0.13 * gs, 0.26 * gs, 0.6, 2.5, dice)
		placed += 1


## Carpets: patches of small tufts where the reef is, round the ruins, and in a few open spots.
func _grow_carpets(dice: RandomNumberGenerator, grid: Dictionary) -> void:
	var size := _settings.flora_cover_size
	var per_m2 := _settings.flora_cover_per_m2
	var made := 0
	var tries := 0
	while made < _settings.flora_cover_patches and tries < _settings.flora_cover_patches * 25 and flora.has_room():
		tries += 1
		var centre := Vector2.from_angle(dice.randf() * TAU) * sqrt(dice.randf()) * radius * 0.93
		var hot := 0.1 + _reef_zone(centre) * 0.9 + 0.4 * smoothstep(0.1, 0.4, _grass_noise.get_noise_2dv(centre))
		for at in cluster_spots:
			if Vector2(at.x, at.z).distance_to(centre) < 26.0:
				hot = maxf(hot, 0.8)
		if dice.randf() > hot or not _clear_of_start(centre):
			continue
		made += 1
		var reach := _settings.flora_cover_radius * dice.randf_range(0.5, 1.5)
		var attempts := roundi(per_m2 * PI * reach * reach)
		for i in attempts:
			var spot := centre + Vector2.from_angle(dice.randf() * TAU) * sqrt(dice.randf()) * reach
			var dist := spot.distance_to(centre)
			var keep := (smoothstep(reach, reach * 0.55, dist) + 0.1) * (0.4 + 0.6 * smoothstep(-0.3, 0.4, _cover_noise.get_noise_2dv(spot)))
			if dice.randf() > keep or spot.length() > radius * 0.95 or not _clear_of_start(spot) or _blocked(spot, grid):
				continue
			if not flora.has_room():
				return
			var here := _reef_zone(spot)
			var base := Vector3(spot.x, -0.03, spot.y)
			flora.add_tuft(base, _cover_type(here, dice), size, dice)
			if here > 0.4 and dice.randf() < 0.3:  # a couple of taller cyan blades among the magenta
				for j in 2:
					flora.add_cluster(base + Vector3(dice.randf_range(-0.2, 0.2), -0.01, dice.randf_range(-0.2, 0.2)), 1.0, FloraField.Type.CYAN,
							0.2 * size, 0.55 * size, 0.03, 0.06, 0.6, 0.0, dice)


# --- Terrain dressing (planning_procedural_world.md, phase 4) ------------------------------------------------------
# Every piece samples the rock's surface (area-weighted, from the meshed triangles) and checks its normal and the water
# above it: kelp on flats with room above (as tall as that room allows), fronds hanging from overhangs, tufts out of
# walls, carpets on flats, corals and sponges on the lower flats, boulders on slopes. Growth clumps: a slow noise times
# hot discs (the grottoes and a few rolled ones) decides what survives.

func _grow_terrain(dice: RandomNumberGenerator) -> void:
	if terrain == null or terrain.field == null:
		return
	var f := terrain.field
	var lay := terrain.layout
	var hot: Array[Vector3] = []  # x, z, radius
	for g in lay.grottoes:
		hot.append(Vector3(g.x, g.y, g.z))
	for n in 5:
		var spot := Vector2.from_angle(dice.randf() * TAU) * dice.randf_range(lay.open_radius, radius)
		hot.append(Vector3(spot.x, spot.y, dice.randf_range(18.0, 40.0)))
	var heat := func(p: Vector3) -> float:
		var h := 0.35 + 0.65 * smoothstep(-0.25, 0.35, _cover_noise.get_noise_2d(p.x * 0.4, p.z * 0.4))
		for d in hot:
			h = maxf(h, smoothstep(d.z, d.z * 0.4, Vector2(p.x, p.z).distance_to(Vector2(d.x, d.y))))
		return h
	var grotto := func(p: Vector3) -> float:
		var g := 0.0
		for d in lay.grottoes:
			g = maxf(g, smoothstep(d.z, d.z * 0.5, Vector2(p.x, p.z).distance_to(Vector2(d.x, d.y))))
		return g
	var top := 1e4
	var reach := radius + 40.0
	var size := _settings.flora_cover_size
	var seed_base := rng.seed * 13 + 5
	var q := TerrainLayout.quality_dressing(_settings)
	var want_kelp := roundi(_settings.terrain_kelp * q)
	var want_fronds := roundi(_settings.terrain_fronds * q)
	var want_tufts := roundi(_settings.terrain_wall_tufts * q)
	var want_carpets := roundi(_settings.terrain_carpets * q)
	var want_corals := roundi(_settings.terrain_corals * q)
	var want_boulders := roundi(_settings.terrain_boulders * q)

	# Kelp: flat rock (ny >= 0.55) with more than 9 m of water above; as tall as that water allows, capped.
	if flora and want_kelp > 0:
		var got: Dictionary = f.sample_surface(want_kelp * 6, seed_base + 1, 0.55, 1.01, 0.2, top, radius * 0.98)
		var used := {}
		var planted := 0
		var pts: PackedVector3Array = got["points"]
		for p in pts:
			if planted >= want_kelp:
				break
			var key := Vector2i(floori(p.x / 2.5), floori(p.z / 2.5))
			if used.has(key) or dice.randf() > heat.call(p):
				continue
			# Kelp needs the sky: none under a roof (grotto cavities, overhangs), where fronds and tufts go instead.
			var above := f.open_above(p + Vector3.UP * 0.3)
			var room := minf(above, edge_height + 2.0 - p.y)
			if room < 9.0 or above < 1e3:
				continue
			used[key] = true
			var tall := minf(room - dice.randf_range(0.8, 5.0), dice.randf_range(15.0, maxf(_settings.terrain_kelp_max, 15.0))) \
					* _settings.flora_kelp_height
			var column := RandomNumberGenerator.new()
			column.seed = dice.randi()
			var kind := 1 if grotto.call(p) > 0.4 and column.randf() < 0.7 else (2 if column.randf() < 0.12 else 0)
			var glints := _settings.flora_glints_per_m if WaterLook.shared().glints_per_plant > 0 else 0.0
			flora.add_kelp_column(p - Vector3.UP * 0.2, tall, kind, _settings.flora_blades_per_m * _settings.flora_blade_mult,
					_settings.flora_kelp_density, glints, 1.0, column)
			kelp_spots.append(Vector2(p.x, p.z))
			planted += 1

	# Fronds hang from overhangs (ny < -0.35).
	if flora and want_fronds > 0:
		var got: Dictionary = f.sample_surface(want_fronds * 2, seed_base + 2, -1.01, -0.35, 0.5, top, reach)
		var pts: PackedVector3Array = got["points"]
		var made := 0
		for p in pts:
			if made >= want_fronds or not flora.has_room():
				break
			if dice.randf() > heat.call(p):
				continue
			var drop := minf(f.sdf(p + Vector3.DOWN * 0.5) + 0.5, 3.0)
			if drop < 0.6:
				continue
			var red: bool = grotto.call(p) > 0.3 or dice.randf() < 0.5
			flora.add_hanging(p + Vector3.DOWN * 0.05, _settings.flora_frond_blades, FloraField.Type.RED,
					FloraField.Type.RED if red else FloraField.Type.OLIVE, clampf(drop / 2.5, 0.4, 1.4), 0.35, dice)
			made += 1

	# Wall tufts (-0.2 < ny < 0.8), leaning out along the wall's normal.
	if flora and want_tufts > 0:
		var got: Dictionary = f.sample_surface(want_tufts * 2, seed_base + 3, -0.2, 0.8, 0.3, top, reach)
		var pts: PackedVector3Array = got["points"]
		var nrm: PackedVector3Array = got["normals"]
		var made := 0
		for i in pts.size():
			if made >= want_tufts or not flora.has_room():
				break
			var p := pts[i]
			if dice.randf() > heat.call(p):
				continue
			var g: float = grotto.call(p)
			var type := FloraField.Type.VIOLET if g > 0.3 or dice.randf() < 0.3 else FloraField.Type.OLIVE
			flora.add_wall_tuft(p, atan2(nrm[i].z, nrm[i].x), 4.0, type, dice.randf_range(0.6, 1.4) * size, dice)
			made += 1

	# Carpets on the rock's flats: tufts by the magenta map (the grotto zone and the reef noise).
	if flora and want_carpets > 0:
		var got: Dictionary = f.sample_surface(want_carpets * 2, seed_base + 4, 0.75, 1.01, 0.2, top, reach)
		var pts: PackedVector3Array = got["points"]
		var made := 0
		for p in pts:
			if made >= want_carpets or not flora.has_room():
				break
			if dice.randf() > heat.call(p):
				continue
			var zone := maxf(grotto.call(p), _reef_zone(Vector2(p.x, p.z)))
			flora.add_tuft(p - Vector3.UP * 0.03, _cover_type(zone, dice), size, dice)
			made += 1

	# Corals, sponges and anemones on the lower flats, boulders on slopes (Scatter meshes, tilted to the surface).
	if want_corals > 0:
		var got: Dictionary = f.sample_surface(want_corals * 3, seed_base + 5, 0.7, 1.01, 0.2, edge_height * 0.5, radius * 0.98)
		var pts: PackedVector3Array = got["points"]
		var nrm: PackedVector3Array = got["normals"]
		var sets := {}
		var made := 0
		for i in pts.size():
			if made >= want_corals:
				break
			if dice.randf() > heat.call(pts[i]):
				continue
			var roll := dice.randf()
			var mesh: Mesh
			var s := dice.randf_range(0.8, 1.6)
			if roll < 0.6:
				mesh = ReefKit.mesh(GEMS[dice.randi() % GEMS.size()], dice.randi() % ReefKit.VARIANTS)
			elif roll < 0.85:
				mesh = ReefKit.mesh("tube_sponge" if dice.randf() < 0.6 else "barrel", dice.randi() % ReefKit.VARIANTS)
				s = dice.randf_range(1.1, 2.0)
			else:
				mesh = ReefKit.mesh("anemone", dice.randi() % ReefKit.VARIANTS)
				s = dice.randf_range(1.2, 2.4)
			_put3(sets, mesh, pts[i], nrm[i], s, -0.06 * s, dice)
			made += 1
		_flush(sets)
	if want_boulders > 0:
		var got: Dictionary = f.sample_surface(want_boulders * 2, seed_base + 6, 0.3, 0.85, 0.2, top, reach)
		var pts: PackedVector3Array = got["points"]
		var nrm: PackedVector3Array = got["normals"]
		var sets := {}
		for i in mini(pts.size(), want_boulders):
			var s := dice.randf_range(0.8, 3.0)
			_put3(sets, ReefKit.mesh("boulder" if dice.randf() < 0.7 else "slab", dice.randi() % ReefKit.VARIANTS), pts[i], nrm[i], s,
					-0.25 * s, dice)
		_flush(sets)


## A copy of `mesh` at `at` (this node's space) standing on a surface with normal `n` (half-way between it and up),
## sunk `sink` m along that.
func _put3(into: Dictionary, mesh: Mesh, at: Vector3, n: Vector3, size: float, sink: float, dice: RandomNumberGenerator) -> void:
	var up := (n.normalized() + Vector3.UP).normalized()
	var basis := Basis(Vector3.UP, dice.randf() * TAU)
	var axis := Vector3.UP.cross(up)
	if axis.length() > 0.001:
		basis = Basis(axis.normalized(), Vector3.UP.angle_to(up)) * basis
	if not into.has(mesh):
		into[mesh] = [[] as Array[Transform3D], [] as Array[Color]]
	(into[mesh][0] as Array[Transform3D]).append(Transform3D(basis.scaled(Vector3.ONE * size), at + up * sink))
	(into[mesh][1] as Array[Color]).append(Color(dice.randf(), dice.randf(), dice.randf(), 0.0))
