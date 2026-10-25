class_name Scatter
extends Node3D
## Scenery spread over the seabed (planning_environment.md, "Chunked
## scatter"): each mesh's copies are cut into TILE-metre tiles, one
## MultiMeshInstance3D per mesh per tile, so the camera's frustum drops
## whole tiles, each tile is drawn only within `draw_distance` (set from the
## murk), and Godot's mesh LODs work (a tile's bounds are small; one MultiMesh
## over the whole arena never gets them).
##
## Each copy carries custom data (INSTANCE_CUSTOM in its shader): r a
## colour or variant pick (0..1), g a random (0..1), b and a spare.
##
##   scatter.add(mesh, transforms, customs)
##   scatter.build()
##   scatter.clear_around(spot, radius)  # a shrine went here: rebuild the tiles under it

const TILE := 64.0

## Past this (m) a tile isn't drawn (0: always).
var draw_distance := 0.0:
	set(value):
		draw_distance = value
		_apply_ranges()
## How far a tile fades out before draw_distance (m).
var fade := 10.0

## mesh -> {tile key (Vector2i) -> [Array[Transform3D], PackedColorArray]}
var _sets := {}
## mesh -> shadow setting
var _shadows := {}
## [mesh, tile key] -> MultiMeshInstance3D
var _instances := {}


## Adds copies of `mesh` at `transforms` (with `customs`, one per copy, or none).
func add(mesh: Mesh, transforms: Array[Transform3D], customs: Array[Color] = [], shadows := false) -> void:
	if transforms.is_empty():
		return
	var tiles: Dictionary = _sets.get(mesh, {})
	for i in transforms.size():
		var at := transforms[i].origin
		var key := Vector2i(floori(at.x / TILE), floori(at.z / TILE))
		if not tiles.has(key):
			tiles[key] = [[] as Array[Transform3D], [] as Array[Color]]
		(tiles[key][0] as Array[Transform3D]).append(transforms[i])
		(tiles[key][1] as Array[Color]).append(customs[i] if i < customs.size() else Color(0.0, randf(), 0.0, 0.0))
	_sets[mesh] = tiles
	_shadows[mesh] = shadows


## Makes (or remakes) every tile's MultiMesh.
func build() -> void:
	for mesh: Mesh in _sets:
		for key: Vector2i in _sets[mesh]:
			_build_tile(mesh, key)
	_apply_ranges()


## Removes every copy within `radius` m (flat) of `spot` (this node's space)
## and rebuilds the tiles it touched.
func clear_around(spot: Vector3, radius: float) -> void:
	var r2 := radius * radius
	for mesh: Mesh in _sets:
		var tiles: Dictionary = _sets[mesh]
		for key: Vector2i in tiles:
			var low := Vector2(key) * TILE - Vector2.ONE * radius
			var high := (Vector2(key) + Vector2.ONE) * TILE + Vector2.ONE * radius
			if spot.x < low.x or spot.z < low.y or spot.x > high.x or spot.z > high.y:
				continue
			var kept: Array[Transform3D] = []
			var kept_custom: Array[Color] = []
			var xfs: Array[Transform3D] = tiles[key][0]
			var customs: Array[Color] = tiles[key][1]
			for i in xfs.size():
				var o := xfs[i].origin
				if (o.x - spot.x) * (o.x - spot.x) + (o.z - spot.z) * (o.z - spot.z) > r2:
					kept.append(xfs[i])
					kept_custom.append(customs[i])
			if kept.size() != xfs.size():
				tiles[key] = [kept, kept_custom]
				_build_tile(mesh, key)
	_apply_ranges()


## How many copies are placed in all (for the probes and benches).
func count() -> int:
	var total := 0
	for mesh: Mesh in _sets:
		for key: Vector2i in _sets[mesh]:
			total += (_sets[mesh][key][0] as Array).size()
	return total


## How many tiles have something in them (draw calls at most, per mesh kind).
func tile_count() -> int:
	return _instances.size()


func _build_tile(mesh: Mesh, key: Vector2i) -> void:
	var xfs: Array[Transform3D] = _sets[mesh][key][0]
	var customs: Array[Color] = _sets[mesh][key][1]
	var slot := [mesh, key]
	var instance: MultiMeshInstance3D = _instances.get(slot)
	if xfs.is_empty():
		if instance:
			instance.queue_free()
			_instances.erase(slot)
		return
	if instance == null:
		instance = MultiMeshInstance3D.new()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _shadows.get(mesh, false) \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_instances[slot] = instance
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = xfs.size()
	for i in xfs.size():
		multimesh.set_instance_transform(i, xfs[i])
		multimesh.set_instance_custom_data(i, customs[i])
	instance.multimesh = multimesh


func _apply_ranges() -> void:
	for slot: Array in _instances:
		var instance: MultiMeshInstance3D = _instances[slot]
		instance.visibility_range_end = draw_distance
		instance.visibility_range_end_margin = fade if draw_distance > 0.0 else 0.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if draw_distance > 0.0 \
				else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
