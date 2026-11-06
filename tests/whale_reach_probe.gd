extends Node3D
## Probe and report for the arenas' room for a whale (planning_marco_whales.md §8).
## Per arena it flood-fills the water twice on a voxel grid, once with a hider-sized
## sphere from the hiders' spawns and once with a whale-sized sphere from the
## seeker's start, then reports:
##   1. hider-only pockets: space a hider reaches and the whale can not, that is not a
##      porthole's or a registered Hideaway's. These must be zero (the probe fails);
##   2. tight passages: whale-reachable space that a whale 1.4x as wide could not
##      use (chokepoints on its routes), grouped;
##   3. how much of the hider-reachable water the whale can use.
## and writes a top-down map PNG per arena (green whale-reachable, orange tight,
## red hider-only pocket, grey solid).
##   Godot_console.exe --headless --path . res://tests/whale_reach_probe.tscn -- --out=DIR [--arena=temple,tank] [--cell=0.75] [--whale=1.3]
## `--whale=R` sets the whale's body radius (m); otherwise it is the Titans' own half
## width times whale_hitbox_scale. A hideaway is a spot the arena lists in
## hideaway_spots() or any node in group "mp_hideaway" with a global_position and `radius`.

const ARENAS := {"temple": "res://scripts/marco_polo/temple_arena.gd", "tank": "res://scripts/marco_polo/fish_tank_arena.gd"}
## Both layers: the arena's furniture and its sight blockers.
const MASK := 1 | (1 << 5)
## A pocket within this of a porthole's mouth belongs to the porthole (m).
const PORTHOLE_REACH := 7.0
## Pockets under this volume (m3) are grid slivers (corners, crevices a cell wide), listed but not failed.
const POCKET_MIN := 4.0
const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

var out_dir := "user://whale_reach"
var arenas := ["temple", "tank"]
var cell := 0.75
var whale_radius := -1.0
var failures := 0
## `--inspect=x,y,z`: also list what is within 2 m of that world point in each arena (to find what makes a pocket).
var inspect := Vector3.INF


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--arena="):
			arenas = Array(arg.trim_prefix("--arena=").split(","))
		elif arg.begins_with("--cell="):
			cell = float(arg.trim_prefix("--cell="))
		elif arg.begins_with("--inspect="):
			var parts := arg.trim_prefix("--inspect=").split(",")
			inspect = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
		elif arg.begins_with("--whale="):
			whale_radius = float(arg.trim_prefix("--whale="))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var hider_r := _hider_radius()
	var whale_r := whale_radius if whale_radius > 0.0 else _whale_radius()
	print("hider body radius %.2f m, whale body radius %.2f m, cell %.2f m" % [hider_r, whale_r, cell])
	for key: String in arenas:
		await _arena(key, hider_r, whale_r)
	print("whale_reach_probe: %s" % ("no hider-only pockets" if failures == 0 else "%d arena(s) with hider-only pockets" % failures))
	get_tree().quit(1 if failures else 0)


## The smallest hider's half width: the tightest gap any hider can use.
func _hider_radius() -> float:
	var smallest := INF
	for fish_class: FishCharacter.FishClass in FishCharacter.pickable_classes():
		var box := FishCharacter.hitbox_size(fish_class)
		smallest = minf(smallest, minf(box.x, box.y) * 0.5)
	return smallest


## The Titans' body radius: half its widest cross-section, hitbox scale and length on top.
func _whale_radius() -> float:
	var titan: int = int(FishCharacter.FishClass.get("TITAN", -1))
	if titan < 0:
		return 1.2
	var box := FishCharacter.hitbox_size(titan as FishCharacter.FishClass)
	var shared := MarcoPoloSettings.new()
	var scale := shared.whale_length / box.z if shared.whale_length > 0.0 else 1.0
	return maxf(box.x, box.y) * 0.5 * scale * shared.whale_hitbox_scale


func _whale_length() -> float:
	var titan: int = int(FishCharacter.FishClass.get("TITAN", -1))
	var shared := MarcoPoloSettings.new()
	if shared.whale_length > 0.0:
		return shared.whale_length
	return FishCharacter.hitbox_size(titan as FishCharacter.FishClass).z if titan >= 0 else 6.0


## Path distance (voxels) through `reach` from the nearest of `sources`: -1 where unreached.
func _depth_from(sources: PackedByteArray, reach: PackedByteArray, dims: Vector3i) -> PackedInt32Array:
	var depth := PackedInt32Array()
	depth.resize(sources.size())
	depth.fill(1 << 30)
	var frontier: Array[int] = []
	for i in sources.size():
		if sources[i] == 1 and reach[i] == 1:
			depth[i] = 0
			frontier.append(i)
	while not frontier.is_empty():
		var next: Array[int] = []
		for i in frontier:
			var v := Vector3i(i / (dims.y * dims.z), (i / dims.z) % dims.y, i % dims.z)
			for d: Vector3i in DIRS:
				var n := v + d
				if n.x < 0 or n.y < 0 or n.z < 0 or n.x >= dims.x or n.y >= dims.y or n.z >= dims.z:
					continue
				var j := _index(n, dims)
				if reach[j] == 1 and depth[j] > depth[i] + 1:
					depth[j] = depth[i] + 1
					next.append(j)
		frontier = next
	return depth


func _arena(key: String, hider_r: float, whale_r: float) -> void:
	var arena := (load(ARENAS[key]) as GDScript).new() as MarcoArena
	add_child(arena)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var started := Time.get_ticks_msec()
	if inspect != Vector3.INF:
		var probe_shape := SphereShape3D.new()
		probe_shape.radius = 2.0
		var probe_query := PhysicsShapeQueryParameters3D.new()
		probe_query.shape = probe_shape
		probe_query.collision_mask = MASK
		probe_query.transform = Transform3D(Basis.IDENTITY, inspect)
		for hit in get_world_3d().direct_space_state.intersect_shape(probe_query, 32):
			var collider := hit.collider as Node
			print("  inspect near %s: %s (%s)" % [inspect, collider.get_path() if collider else "?", collider.get_parent().name if collider and collider.get_parent() else ""])
	var box := AABB(arena.global_position + Vector3(-arena.size.x * 0.5, 0.0, -arena.size.z * 0.5), arena.size)
	var dims := Vector3i((box.size / cell).ceil())
	var space := get_world_3d().direct_space_state
	var small := _free_grid(space, box, dims, maxf(hider_r, cell * 0.5))
	var big := _free_grid(space, box, dims, maxf(whale_r, cell * 0.5), small)
	var wider := _free_grid(space, box, dims, maxf(whale_r * 1.4, cell * 0.5), big)
	# Seeds: each hider spawn's nearest free voxel, and the whale's start.
	var hider_seeds: Array = []
	for xform in arena.hider_spawns():
		hider_seeds.append(_nearest_free(small, box, dims, xform.origin))
	var whale_seed := _nearest_free(big, box, dims, arena.seeker_start().origin)
	var hider_reach := _fill(small, dims, hider_seeds)
	var whale_reach := _fill(big, dims, [whale_seed])
	var wide_reach := _fill(wider, dims, [whale_seed])
	# Dead ends: where a whale has to back out because a sphere of half its length (the
	# room it needs to turn round in) fits nowhere near. Path distance to the nearest such room.
	var turn_r := _whale_length() * 0.5
	var turn := _free_grid(space, box, dims, maxf(turn_r, cell * 0.5), big)
	var depth := _depth_from(turn, whale_reach, dims)
	var dead_cells := PackedInt32Array()
	var dead_depth := _whale_length() / cell
	var covered := _cover(whale_reach, dims, (whale_r + hider_r) / cell + 1.5)  # a cell and a half of slack: the grid snaps the whale to cell centres
	var strict := _cover(whale_reach, dims, (whale_r + hider_r) / cell + 0.5)
	var mouths: Array[Vector3] = []
	for porthole in arena.portholes():
		mouths.append(porthole.mouth())
	for i in depth.size():
		if whale_reach[i] == 1 and depth[i] > dead_depth:
			dead_cells.append(i)
	var voxel_volume := cell * cell * cell
	var reachable := 0
	var whale_total := 0
	var pockets := PackedInt32Array()  # voxel indexes: hider-reachable, whale-unreachable
	var tight := PackedInt32Array()
	var deep := PackedInt32Array()
	for i in hider_reach.size():
		if hider_reach[i] == 1:
			reachable += 1
			if covered[i] == 1:
				whale_total += 1
				if strict[i] == 0 and not _near_any(mouths, _world(Vector3(i / (dims.y * dims.z), (i / dims.z) % dims.y, i % dims.z), box), PORTHOLE_REACH):
					deep.append(i)
			elif not _near_any(mouths, _world(Vector3(i / (dims.y * dims.z), (i / dims.z) % dims.y, i % dims.z), box), PORTHOLE_REACH):
				pockets.append(i)
		if whale_reach[i] == 1 and wide_reach[i] == 0:
			tight.append(i)
	print("%s: %s, %d x %d x %d voxels in %.1f s" % [key, arena.get_script().resource_path.get_file(), dims.x, dims.y, dims.z, (Time.get_ticks_msec() - started) / 1000.0])
	print("  hider-reachable %.0f m3, within the whale's body reach %.0f m3 (%.0f%%)" % [reachable * voxel_volume, whale_total * voxel_volume, 100.0 * whale_total / maxf(reachable, 1.0)])
	var pocket_groups := _components(pockets, dims)
	var bad := 0
	for group: Dictionary in pocket_groups:
		var owner := _owner_of(arena, group, box)
		var line := "  pocket %.1f m3 around %s, spanning %s to %s (%s)" % [group.count * voxel_volume, _fmt(_world(group.centre, box)),
				_fmt(_world(group.min, box)), _fmt(_world(group.max, box)), owner if owner != "" else "NOT A PORTHOLE OR HIDEAWAY"]
		if group.count * voxel_volume >= POCKET_MIN or owner == "":
			print(line)
		if owner == "" and group.count * voxel_volume >= POCKET_MIN:
			bad += 1
	print("  hider-only pockets (%.0f m3 and up) that are not portholes or hideaways: %d" % [POCKET_MIN, bad])
	if bad > 0:
		failures += 1
	var deep_groups := _components(deep, dims).filter(func(g: Dictionary) -> bool: return g.count * voxel_volume >= 8.0)
	deep_groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.count > b.count)
	print("  deep cover (a hider the whale's body only just reaches, 8 m3 and up, not a porthole): %d groups" % deep_groups.size())
	for g: Dictionary in deep_groups.slice(0, 12):
		print("    %.0f m3 around %s, spanning %s to %s" % [g.count * voxel_volume, _fmt(_world(g.centre, box)), _fmt(_world(g.min, box)), _fmt(_world(g.max, box))])
	var dead_groups := _components(dead_cells, dims).filter(func(g: Dictionary) -> bool: return g.count * voxel_volume >= 8.0)
	dead_groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.count > b.count)
	print("  dead ends (more than one body length from room to turn round in, %.1f m): %d groups of 8 m3 and up" % [_whale_length(), dead_groups.size()])
	for g: Dictionary in dead_groups.slice(0, 8):
		print("    dead end %.0f m3 around %s" % [g.count * voxel_volume, _fmt(_world(g.centre, box))])
	var tight_groups := _components(tight, dims)
	var tight_big := tight_groups.filter(func(g: Dictionary) -> bool: return g.count * voxel_volume >= 4.0)
	print("  tight passages (a %.1f m whale fits, a %.1f m one does not): %d groups, %d over 4 m3" % [whale_r * 2.0, whale_r * 2.8, tight_groups.size(), tight_big.size()])
	tight_big.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.count > b.count)
	for g: Dictionary in tight_big.slice(0, 8):
		print("    %.0f m3 around %s" % [g.count * voxel_volume, _fmt(_world(g.centre, box))])
	_map(key, arena, box, dims, small, strict, hider_reach, wide_reach, whale_reach)
	arena.queue_free()
	await get_tree().physics_frame


## A grid of 1 (free for a sphere of `radius`) and 0 (hit something or outside), x-major;
## cells `only_where` marks 0 are skipped (a bigger sphere can not fit where a smaller can not).
func _free_grid(space: PhysicsDirectSpaceState3D, box: AABB, dims: Vector3i, radius: float, only_where := PackedByteArray()) -> PackedByteArray:
	var grid := PackedByteArray()
	grid.resize(dims.x * dims.y * dims.z)
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = MASK
	query.margin = 0.0
	for x in dims.x:
		for y in dims.y:
			for z in dims.z:
				var i := (x * dims.y + y) * dims.z + z
				if not only_where.is_empty() and only_where[i] == 0:
					continue
				var at := box.position + (Vector3(x, y, z) + Vector3.ONE * 0.5) * cell
				# The water's inside: a sphere poking through the box's faces is out.
				if at.x - radius < box.position.x or at.x + radius > box.end.x or at.y - radius < box.position.y \
						or at.y + radius > box.end.y or at.z - radius < box.position.z or at.z + radius > box.end.z:
					continue
				query.transform = Transform3D(Basis.IDENTITY, at)
				if space.intersect_shape(query, 1).is_empty():
					grid[i] = 1
	return grid


## 1 where a voxel is within `reach` (voxels) of one `reached` marks: what the whale's body touches.
func _cover(reached: PackedByteArray, dims: Vector3i, reach: float) -> PackedByteArray:
	var offsets: Array[Vector3i] = []
	var span := ceili(reach)
	for dx in range(-span, span + 1):
		for dy in range(-span, span + 1):
			for dz in range(-span, span + 1):
				if Vector3(dx, dy, dz).length() <= reach:
					offsets.append(Vector3i(dx, dy, dz))
	var out := PackedByteArray()
	out.resize(reached.size())
	for x in dims.x:
		for y in dims.y:
			for z in dims.z:
				if reached[(x * dims.y + y) * dims.z + z] == 0:
					continue
				for o in offsets:
					var n := Vector3i(x, y, z) + o
					if n.x >= 0 and n.y >= 0 and n.z >= 0 and n.x < dims.x and n.y < dims.y and n.z < dims.z:
						out[_index(n, dims)] = 1
	return out


func _near_any(points: Array[Vector3], at: Vector3, reach: float) -> bool:
	for p in points:
		if p.distance_to(at) <= reach:
			return true
	return false


func _index(v: Vector3i, dims: Vector3i) -> int:
	return (v.x * dims.y + v.y) * dims.z + v.z


func _cell_of(box: AABB, dims: Vector3i, at: Vector3) -> Vector3i:
	return Vector3i(clampi(int((at.x - box.position.x) / cell), 0, dims.x - 1), clampi(int((at.y - box.position.y) / cell), 0, dims.y - 1),
			clampi(int((at.z - box.position.z) / cell), 0, dims.z - 1))


## The free voxel nearest `at` (searching outward in shells), or the voxel at `at`.
func _nearest_free(grid: PackedByteArray, box: AABB, dims: Vector3i, at: Vector3) -> Vector3i:
	var origin := _cell_of(box, dims, at)
	for ring in range(0, 40):
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				for dz in range(-ring, ring + 1):
					if maxi(absi(dx), maxi(absi(dy), absi(dz))) != ring:
						continue
					var v := origin + Vector3i(dx, dy, dz)
					if v.x < 0 or v.y < 0 or v.z < 0 or v.x >= dims.x or v.y >= dims.y or v.z >= dims.z:
						continue
					if grid[_index(v, dims)] == 1:
						return v
	return origin


## Flood fill over `grid`'s free voxels from `seeds`: 1 where reached.
func _fill(grid: PackedByteArray, dims: Vector3i, seeds: Array) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(grid.size())
	var stack: Array[Vector3i] = []
	for seed: Vector3i in seeds:
		var i := _index(seed, dims)
		if grid[i] == 1 and seen[i] == 0:
			seen[i] = 1
			stack.append(seed)
	while not stack.is_empty():
		var v: Vector3i = stack.pop_back()
		for d: Vector3i in DIRS:
			var n := v + d
			if n.x < 0 or n.y < 0 or n.z < 0 or n.x >= dims.x or n.y >= dims.y or n.z >= dims.z:
				continue
			var j := _index(n, dims)
			if grid[j] == 1 and seen[j] == 0:
				seen[j] = 1
				stack.append(n)
	return seen


## Connected groups of the voxel indexes in `indexes`: [{count, centre (grid), min, max}].
func _components(indexes: PackedInt32Array, dims: Vector3i) -> Array[Dictionary]:
	var members := {}
	for i in indexes:
		members[i] = true
	var out: Array[Dictionary] = []
	for start in indexes:
		if not members.has(start):
			continue
		members.erase(start)
		var stack := [start]
		var count := 0
		var sum := Vector3.ZERO
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		while not stack.is_empty():
			var i: int = stack.pop_back()
			var v := Vector3i(i / (dims.y * dims.z), (i / dims.z) % dims.y, i % dims.z)
			count += 1
			sum += Vector3(v)
			lo = lo.min(Vector3(v))
			hi = hi.max(Vector3(v))
			for d: Vector3i in DIRS:
				var n := v + d
				if n.x < 0 or n.y < 0 or n.z < 0 or n.x >= dims.x or n.y >= dims.y or n.z >= dims.z:
					continue
				var j := _index(n, dims)
				if members.has(j):
					members.erase(j)
					stack.append(j)
		out.append({"count": count, "centre": sum / count, "min": lo, "max": hi})
	return out


func _world(group_centre: Variant, box: AABB) -> Vector3:
	return box.position + ((group_centre as Vector3) + Vector3.ONE * 0.5) * cell


func _fmt(at: Vector3) -> String:
	return "(%.0f, %.0f, %.0f)" % [at.x, at.y, at.z]


## "porthole N" / "hideaway NAME" when a pocket is one of those, else "".
func _owner_of(arena: MarcoArena, group: Dictionary, box: AABB) -> String:
	var lo := box.position + (group.min as Vector3) * cell
	var hi := box.position + ((group.max as Vector3) + Vector3.ONE) * cell
	var hull := AABB(lo, hi - lo)
	var n := 0
	for porthole in arena.portholes():
		if hull.grow(PORTHOLE_REACH).has_point(porthole.mouth()):
			return "porthole %d" % n
		n += 1
	for spot in arena.hideaway_spots():
		if hull.grow(float(spot.radius)).has_point(spot.position as Vector3):
			return "hideaway %s" % spot.name
	for node: Variant in get_tree().get_nodes_in_group("mp_hideaway"):
		if node is Node3D:
			var radius_value: Variant = (node as Object).get("radius")
			var radius := float(radius_value) if radius_value != null else 3.0
			if hull.grow(radius).has_point((node as Node3D).global_position):
				return "hideaway %s" % (node as Node).name
	return ""


## Top-down map: per (x, z) column, the most important thing in it.
func _map(key: String, arena: MarcoArena, box: AABB, dims: Vector3i, small: PackedByteArray, whale: PackedByteArray,
		hider: PackedByteArray, wide: PackedByteArray, whale_free: PackedByteArray) -> void:
	var scale := maxi(1, int(6.0 / cell))
	var image := Image.create_empty(dims.x * scale, dims.z * scale, false, Image.FORMAT_RGB8)
	image.fill(Color(0.12, 0.13, 0.15))
	for x in dims.x:
		for z in dims.z:
			var pocket := 0
			var tight := 0
			var open := 0
			var free := 0
			for y in dims.y:
				var i := (x * dims.y + y) * dims.z + z
				if hider[i] == 1 and whale[i] == 0:
					pocket += 1
				if whale_free[i] == 1 and wide[i] == 0:
					tight += 1
				elif whale_free[i] == 1:
					open += 1
				if small[i] == 1:
					free += 1
			var col := Color(0.12, 0.13, 0.15)
			if pocket >= 2:
				col = Color(0.95, 0.25, 0.2)
			elif tight + open > 0:
				col = Color(0.95, 0.65, 0.2).lerp(Color(0.2, 0.75, 0.45), float(open) / float(tight + open))
			elif free > 0:
				col = Color(0.35, 0.4, 0.5)
			image.fill_rect(Rect2i(x * scale, z * scale, scale, scale), col)
	for porthole in arena.portholes():
		var spot := (porthole.mouth() - box.position) / cell
		image.fill_rect(Rect2i(int(spot.x) * scale - 2, int(spot.z) * scale - 2, 5, 5), Color.WHITE)
	var path := out_dir.path_join("reach_%s.png" % key)
	image.save_png(path)
	print("  map: %s" % ProjectSettings.globalize_path(path))
