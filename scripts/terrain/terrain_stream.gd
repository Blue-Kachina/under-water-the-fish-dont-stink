class_name TerrainStream
extends Node3D
## Endless terrain for the open ocean (planning_procedural_world.md, phase 8, D1c): square tiles round a followed node,
## each its own TerrainField, seeded from the stream's seed and the tile's coordinates, so a tile is the same whenever
## (and on whichever machine) it is built. Tiles are generated and meshed on WorkerThreadPool tasks and turned into
## nodes on the main thread; tiles left behind are freed.
##
## Seams: a tile's features are rolled per tile, and every tile also takes in its eight neighbours' features, and is
## generated with a margin of one chunk round it, meshing only its own core. So two tiles agree along their shared
## edge. Here the floor itself is meshed (no flat sand plane under endless water) and has collision.
##
## This node sits at the floor's height: its y is the sand's. The Terrain query API doesn't answer for streamed tiles
## (nothing in an open-ocean mode places by the ground yet).

## Tile side (m), how far round the followed node tiles are kept (m), the grid's cell (m).
var tile_size := 96.0
var reach := 160.0
var cell := 2.0
var stream_seed := 1
var follow: Node3D
var settings: UnnaturalSettings
## Tiles being built or built: Vector2i -> {"task": id or -1, "data": Array, "node": Node3D or null}.
var _tiles := {}
var _material: ShaderMaterial
## Margin cells round each tile (one chunk).
const MARGIN := 8


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/terrain_rock.gdshader")


func _exit_tree() -> void:
	for key: Vector2i in _tiles:
		var tile: Dictionary = _tiles[key]
		if int(tile["task"]) >= 0:
			WorkerThreadPool.wait_for_task_completion(tile["task"])
	_tiles.clear()


func _process(_delta: float) -> void:
	if not is_instance_valid(follow) or settings == null:
		return
	_material.set_shader_parameter("base_y", global_position.y)
	var here := to_local(follow.global_position)
	var centre := Vector2i(floori(here.x / tile_size), floori(here.z / tile_size))
	var span := ceili(reach / tile_size)
	# Start the nearest missing tile first (one new task a frame keeps the frame time flat).
	var best := Vector2i.MAX
	var best_d := INF
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var key := centre + Vector2i(dx, dz)
			if _tiles.has(key):
				continue
			var d := Vector2(dx, dz).length()
			if d * tile_size <= reach + tile_size * 0.7 and d < best_d:
				best_d = d
				best = key
	if best != Vector2i.MAX:
		var params := tile_params(best)
		var tile := {"task": -1, "data": [], "node": null}
		tile["task"] = WorkerThreadPool.add_task(_build_tile.bind(params, tile), false, "terrain tile")
		_tiles[best] = tile
	# Finish built tiles, drop far ones.
	for key: Vector2i in _tiles.keys():
		var tile: Dictionary = _tiles[key]
		var far := Vector2(key - centre).length() * tile_size > reach + tile_size * 1.8
		if int(tile["task"]) >= 0 and WorkerThreadPool.is_task_completed(tile["task"]):
			WorkerThreadPool.wait_for_task_completion(tile["task"])
			tile["task"] = -1
			if not far:
				tile["node"] = _make_node(key, tile["data"])
			tile["data"] = []
		if far and int(tile["task"]) < 0:
			if is_instance_valid(tile["node"]):
				(tile["node"] as Node3D).queue_free()
			_tiles.erase(key)


## How many tiles have nodes.
func built_count() -> int:
	var n := 0
	for key: Vector2i in _tiles:
		if is_instance_valid(_tiles[key]["node"]):
			n += 1
	return n


## TerrainField.configure()'s dictionary for tile `key` (pure: the same on every machine).
func tile_params(key: Vector2i) -> Dictionary:
	var mesas := PackedFloat32Array()
	var arches := PackedFloat32Array()
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			_roll_tile(key + Vector2i(dx, dz), mesas, arches)
	var margin := MARGIN * cell
	var origin := Vector3(key.x * tile_size - margin, -10.0, key.y * tile_size - margin)
	var s := settings
	var tall := 34.0
	return {
		"seed": stream_seed,  # the noise is global; tile features come from per-tile dice
		"cell": cell,
		"chunk_cells": MARGIN,
		"threads": 2,
		"origin": origin,
		"size": Vector3(tile_size + margin * 2.0, tall + 16.0, tile_size + margin * 2.0),
		"sand_cut": -1e9,
		"floor_base": 0.0,
		"floor_amp1": s.terrain_floor_swell * 1.5,
		"floor_freq1": 0.011,
		"floor_amp2": s.terrain_floor_detail,
		"floor_freq2": 0.07,
		"relief_inner": -2.0,
		"relief_outer": -1.0,
		"warp_xz": s.terrain_warp,
		"warp_y": s.terrain_warp * 0.25,
		"ring_height": 0.0,
		"plat_threshold": lerpf(0.5, -0.3, s.terrain_plateau_cover),
		"plat_min": s.terrain_plateau_min,
		"plat_max": s.terrain_plateau_max if s.terrain_plateau_cover > 0.0 else 0.0,
		"plat_inner": -100.0,
		"ero_amp1": 1.2 * s.terrain_erosion,
		"ero_amp2": 0.5 * s.terrain_erosion,
		"ero_fbm": 0.6 * s.terrain_erosion,
		"strata_amp": s.terrain_strata,
		"blend": s.terrain_blend,
		"nav": true,
		"clearance": s.terrain_clearance,
		"lip": maxf(s.terrain_lip, cell * 0.75),
		"spawn": Vector3(key.x * tile_size + tile_size * 0.5, tall + 4.0, key.y * tile_size + tile_size * 0.5),
		"mesas": mesas,
		"arches": arches,
	}


## Tile `key`'s own features (stream space), from dice seeded by the tile alone.
func _roll_tile(key: Vector2i, mesas: PackedFloat32Array, arches: PackedFloat32Array) -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(Vector3i(key.x, key.y, stream_seed))
	var base := Vector2(key.x, key.y) * tile_size
	var r0 := settings.terrain_mesa_radius
	for n in dice.randi_range(0, 3):
		var at := base + Vector2(dice.randf(), dice.randf()) * tile_size
		var r := r0 * dice.randf_range(0.6, 1.3)
		var dir := Vector2.from_angle(dice.randf() * TAU) * r * dice.randf_range(0.0, 1.5)
		var tall := dice.randf_range(8.0, 30.0)
		mesas.append_array([at.x - dir.x * 0.5, at.y - dir.y * 0.5, at.x + dir.x * 0.5, at.y + dir.y * 0.5, r, tall + 4.0,
				dice.randf_range(0.2, 0.6), dice.randf_range(0.0, 0.5), dice.randf_range(0.0, 0.25), -4.0])
	if dice.randf() < 0.25:
		var at := base + Vector2(dice.randf_range(0.25, 0.75), dice.randf_range(0.25, 0.75)) * tile_size
		var minor := dice.randf_range(1.8, 3.0)
		var major := maxf(dice.randf_range(9.0, 13.0), (settings.terrain_clearance * 2.0 + minor + 2.0) / 0.9)
		var dir := Vector2.from_angle(dice.randf() * TAU)
		arches.append_array([at.x, -major * 0.1, at.y, dir.x, dir.y, major, minor])


## Worker thread: generates the tile's field and meshes its core chunks into `tile["data"]`.
func _build_tile(params: Dictionary, tile: Dictionary) -> void:
	var field := TerrainField.new()
	field.configure(params)
	field.generate()
	var grid := field.chunk_grid()
	var out: Array = []
	for cz in range(1, grid.z - 1):
		for cx in range(1, grid.x - 1):
			var data := field.build_chunk(cx, cz)
			if not data.is_empty():
				out.append(data)
	tile["data"] = out


func _make_node(key: Vector2i, chunks: Array) -> Node3D:
	var node := Node3D.new()
	node.name = "Tile_%d_%d" % [key.x, key.y]
	add_child(node)
	var body: StaticBody3D = null
	if settings.terrain_collision:
		body = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		node.add_child(body)
	for data: Dictionary in chunks:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
		arrays[Mesh.ARRAY_NORMAL] = data["normals"]
		arrays[Mesh.ARRAY_COLOR] = data["colors"]
		arrays[Mesh.ARRAY_INDEX] = data["indices"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _material)
		var chunk := MeshInstance3D.new()
		chunk.mesh = mesh
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.visibility_range_end = reach + tile_size
		node.add_child(chunk)
		if body:
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(data["faces"])
			var collision := CollisionShape3D.new()
			collision.shape = shape
			body.add_child(collision)
	return node
