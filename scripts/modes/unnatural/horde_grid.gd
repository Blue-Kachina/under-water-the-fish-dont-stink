class_name HordeGrid
extends RefCounted
## A uniform spatial hash for the Horde (planning_unnatural.md §2): every live
## zombie filed under the cell it's in, rebuilt each sim step by a counting
## sort into flat arrays (no allocation once sized). Cells hash into a
## power-of-two table, so cells far apart can share a bucket: every query
## checks real distances, and a query visits each bucket once.
##
## Shared by separation (a zombie's own bucket), attack queries (everything
## within r of p; the nearest in a cone) and contact damage. Written to port
## straight to C++ along with the Horde's step.

var cell_size := 2.0
var mask := 4095
## Bucket b's zombies are entries[starts[b] .. starts[b + 1]).
var starts := PackedInt32Array()
var entries := PackedInt32Array()
## Each zombie's bucket (by its index in the Horde), as of the last build.
var bucket_of := PackedInt32Array()
var _counts := PackedInt32Array()
var _cursor := PackedInt32Array()
var _inverse := 0.5


## A grid of `buckets` buckets (rounded up to a power of two) of cells
## `size` m across, for up to `capacity` zombies.
func _init(size := 2.0, buckets := 4096, capacity := 1024) -> void:
	var table := 1
	while table < buckets:
		table <<= 1
	mask = table - 1
	starts.resize(table + 1)
	_counts.resize(table)
	_cursor.resize(table)
	set_cell_size(size)
	reserve(capacity)


func set_cell_size(size: float) -> void:
	cell_size = maxf(size, 0.05)
	_inverse = 1.0 / cell_size


func reserve(capacity: int) -> void:
	if bucket_of.size() < capacity:
		bucket_of.resize(capacity)
		entries.resize(capacity)


## The bucket for cell (x, y, z).
func bucket(x: int, y: int, z: int) -> int:
	return ((x * 73856093) ^ (y * 19349663) ^ (z * 83492791)) & mask


func bucket_at(point: Vector3) -> int:
	return bucket(floori(point.x * _inverse), floori(point.y * _inverse), floori(point.z * _inverse))


## Files every zombie in `alive` (indices into `positions`) under its bucket.
func build(positions: PackedVector3Array, alive: PackedInt32Array) -> void:
	_counts.fill(0)
	var inverse := _inverse
	var table_mask := mask
	for i in alive:
		var p := positions[i]
		var b := ((floori(p.x * inverse) * 73856093) ^ (floori(p.y * inverse) * 19349663) ^ (floori(p.z * inverse) * 83492791)) & table_mask
		bucket_of[i] = b
		_counts[b] += 1
	var total := 0
	for b in _counts.size():
		starts[b] = total
		_cursor[b] = total
		total += _counts[b]
	starts[_counts.size()] = total
	for i in alive:
		var b := bucket_of[i]
		entries[_cursor[b]] = i
		_cursor[b] += 1


## The buckets covering the box around `centre` out to `reach`, each once.
func buckets_near(centre: Vector3, reach: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	var low := Vector3i(floori((centre.x - reach) * _inverse), floori((centre.y - reach) * _inverse), floori((centre.z - reach) * _inverse))
	var high := Vector3i(floori((centre.x + reach) * _inverse), floori((centre.y + reach) * _inverse), floori((centre.z + reach) * _inverse))
	var cells := (high.x - low.x + 1) * (high.y - low.y + 1) * (high.z - low.z + 1)
	if cells > mask + 1:
		# Bigger than the table: every bucket.
		found.resize(mask + 1)
		for b in mask + 1:
			found[b] = b
		return found
	var seen := {}
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for z in range(low.z, high.z + 1):
				var b := bucket(x, y, z)
				if not seen.has(b):
					seen[b] = true
					found.append(b)
	return found
