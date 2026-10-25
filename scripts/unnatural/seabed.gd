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

const GEMS := ["staghorn", "brain", "table", "fan"]

var radius := 150.0
var edge_height := 40.0
var rng := RandomNumberGenerator.new()
## The ruin clusters' middles (this node's space, y 0), for shrines to keep clear of.
var cluster_spots: Array[Vector3] = []
## The reef, ruins and edge: tiles of MultiMeshes.
var scatter: Scatter
var _settings: UnnaturalSettings
var _glow := ShaderMaterial.new()
var _clusters: Array[MeshInstance3D] = []
var _reef_noise := FastNoiseLite.new()
var _kelp_noise := FastNoiseLite.new()
var _grass_noise := FastNoiseLite.new()
var _murk := -1.0


## The seabed `settings.arena_radius` round, its top at this node's height.
func setup(settings: UnnaturalSettings, rng_seed := 11, edge_tall := 40.0) -> void:
	_settings = settings
	radius = settings.arena_radius
	edge_height = edge_tall
	rng.seed = rng_seed
	for child in get_children():
		child.queue_free()
	_clusters.clear()
	cluster_spots.clear()
	_murk = -1.0
	for noise: FastNoiseLite in [_reef_noise, _kelp_noise, _grass_noise]:
		noise.seed = rng.randi()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_reef_noise.frequency = 0.035
	_kelp_noise.frequency = 0.02
	_grass_noise.frequency = 0.045
	scatter = Scatter.new()
	scatter.name = "Scatter"
	add_child(scatter)
	_build_sand()
	_build_ruins()
	_build_reef()
	_build_edge()
	scatter.build()


## Whether a reef patch covers `spot` (x, z).
func is_reef(spot: Vector2) -> bool:
	return _reef_noise.get_noise_2dv(spot) > 0.5 - _settings.reef_cover


## Clears the scenery round `spot` (global; a shrine went there).
func clear_around(spot: Vector3, clearing: float) -> void:
	if is_instance_valid(scatter):
		scatter.clear_around(to_local(spot), clearing)


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
		reach = UnnaturalSettings.fog_reach(_settings.murk_cull, density) + _settings.murk_cull_margin + Scatter.TILE * 0.7
	scatter.draw_distance = reach
	for cluster in _clusters:
		cluster.visibility_range_end = reach


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
			found = spot.length() > maxf(_settings.scenery_clearing, 0.0) + 22.0
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
		if not _clear_of_start(spot):
			continue
		var kind := kinds[rng.randi() % kinds.size()]
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
		_put(rocks, ReefKit.mesh("slab" if rng.randf() < 0.35 else "boulder", rng.randi() % ReefKit.VARIANTS), spot, size, 0.3, -0.1 * size)
	_flush(rocks)
	# Kelp forests: clumps where the kelp noise is high.
	var kelp := {}
	var planted := 0
	var tries := 0
	while planted < _settings.seabed_kelp and tries < _settings.seabed_kelp * 30:
		tries += 1
		var centre := _point(1.05)
		if _kelp_noise.get_noise_2dv(centre) < 0.25 or not _clear_of_ruins(centre, 10.0) or not _clear_of_start(centre):
			continue
		for k in rng.randi_range(3, 7):
			var spot := centre + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
			_put(kelp, ReefKit.mesh("kelp", rng.randi() % ReefKit.VARIANTS), spot, rng.randf_range(0.8, 1.25), 0.06, 0.0, false)
			planted += 1
	_flush(kelp)
	# Sea-grass meadows, out on the sand.
	var grass := {}
	for n in _settings.seagrass:
		var spot := _find(func(s: Vector2) -> bool:
				return not is_reef(s) and _grass_noise.get_noise_2dv(s) > 0.05 and _clear_of_ruins(s, 7.0), 6)
		if spot != Vector2.INF:
			_put(grass, ReefKit.mesh("seagrass", rng.randi() % ReefKit.VARIANTS), spot, rng.randf_range(0.7, 1.4), 0.1, 0.0)
	_flush(grass)
	# Small life on the open sand.
	var life := {}
	for n in _settings.small_life:
		var spot := _find(func(s: Vector2) -> bool: return not is_reef(s))
		if spot != Vector2.INF:
			var what: String = ["starfish", "urchin", "clam"][_pick([0.45, 0.3, 0.25])]
			_put(life, ReefKit.mesh(what, rng.randi() % ReefKit.VARIANTS), spot, rng.randf_range(1.6, 2.8), 0.1, -0.01)
	_flush(life)


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


## A random point that passes `test` and is clear of the start (INF: none found in `tries`).
func _find(test: Callable, tries := 24) -> Vector2:
	for attempt in tries:
		var spot := _point(1.05)
		if _clear_of_start(spot) and test.call(spot):
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


func _clear_of_ruins(spot: Vector2, margin: float) -> bool:
	for at in cluster_spots:
		if Vector2(at.x, at.z).distance_to(spot) < margin:
			return false
	return true


# --- The edge -------------------------------------------------------------------

## The edge's outcrops (piles of big rocks), its kelp band, and its wall of light.
func _build_edge() -> void:
	if _settings.edge_rocks > 0:
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
				y += h * 0.75
				drift += Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * w * 0.25
				k += 1
		_flush(piles)
	if _settings.edge_kelp > 0:
		var band := {}
		var most := maxf(edge_height * 0.75 / 8.0, 1.0)
		for i in _settings.edge_kelp:
			var at := Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.95, 1.06)
			_put(band, ReefKit.mesh("kelp", rng.randi() % ReefKit.VARIANTS), at, rng.randf_range(most * 0.45, most), 0.05, 0.0, false)
		_flush(band)
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
