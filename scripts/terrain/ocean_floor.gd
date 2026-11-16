class_name OceanFloor
extends RefCounted
## A sea floor for the open-ocean modes (planning_procedural_world.md, phase 8, D1c), the way What Stinks has one:
##   seabed(...)     a fixed arena's floor: Unnatural's Seabed (terrain included when terrain_enabled), sized to the arena,
##                   with no red edge wall (Hunt)
##   stream(...)     an endless floor: a TerrainStream following a fish, far below (Nature)
##   keep_above(...) the soft push that keeps fish above a seabed's flat floor (rock has its own collision)


## A Seabed `depth` m under `center`, `radius` round, laid out from `seed_value`, added to `parent`.
static func seabed(parent: Node, center: Vector3, radius: float, depth: float, seed_value: int, fog_density: float) -> Seabed:
	var floor_settings := UnnaturalSettings.shared().duplicate() as UnnaturalSettings
	floor_settings.arena_radius = radius
	var bed := Seabed.new()
	bed.name = "Seabed"
	bed.edge_glow = false
	parent.add_child(bed)
	bed.global_position = center + Vector3.DOWN * depth
	bed.setup(floor_settings, seed_value, depth + 10.0)
	bed.set_murk(fog_density)
	return bed


## An endless TerrainStream `depth` m under `center` following `fish`, added to `parent`.
static func stream(parent: Node, center: Vector3, depth: float, fish: Node3D, seed_value: int) -> TerrainStream:
	var settings := UnnaturalSettings.shared()
	var terrain := TerrainStream.new()
	terrain.name = "TerrainStream"
	terrain.settings = settings
	terrain.follow = fish
	terrain.stream_seed = seed_value
	terrain.tile_size = settings.terrain_stream_tile
	terrain.reach = settings.terrain_stream_reach
	terrain.cell = settings.terrain_stream_cell
	parent.add_child(terrain)
	terrain.global_position = Vector3(0.0, center.y - depth, 0.0)
	return terrain


## Pushes each of `fishes` back up when it dips under the floor (flat at `flat_y`, or the terrain's floor where higher)
## plus `clearance`, `push` m/s² per metre under (and its downward speed damped).
static func keep_above(fishes: Array, flat_y: float, clearance: float, push: float, delta: float) -> void:
	for fish: FishController in fishes:
		if not is_instance_valid(fish) or fish.freeze or fish.puppet:
			continue
		var floor_y := Terrain.floor_y(fish.global_position.x, fish.global_position.z, flat_y) + clearance
		if fish.global_position.y >= floor_y:
			continue
		var under := floor_y - fish.global_position.y
		var change := push * (1.0 + under) * delta
		if fish.linear_velocity.y < 0.0:
			change -= fish.linear_velocity.y * minf(8.0 * delta, 1.0)
		fish.apply_push(Vector3.UP * change)
