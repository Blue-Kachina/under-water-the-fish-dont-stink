extends SceneTree
## Measures a built fish model back from its meshes and prints each number
## next to its target in titan_specs.md (planning_marco_whales.md §6a step 2):
## eye placement, flipper root, length and chord, fluke span and sweep, the
## dorsal fin's (or hump's, or ridge's) place and height, the body's width and
## depth at five stations, where it's deepest and where the tail stock starts.
## Every ratio is over L, the standard length: the Body mesh's length (snout to
## the fluke notch). Pass: each within ±10 % of its target (TOLERANCE).
##
## Titans are built straight from scripts/fish_models/titan_model.gd (by path,
## so it works before the class is in FishCharacter); any other class through
## FishModel.build, printed without targets (a check of the tool itself).
##   Godot_console.exe --headless --path . --script res://tools/model_measure.gd -- --species=humpback
##   ... -- --species=all          every Titan species; exit code 1 if any fails
##   ... -- --fish=breacher --species=0   a calf, numbers only
##   ... -- --skin=1               a Titan skin (looks only; the shape is the same)

const SPEC := "res://titan_specs.md"
const TITAN := "res://scripts/fish_models/titan_model.gd"
const TOLERANCE := 0.10
const STATIONS := [0.1, 0.3, 0.5, 0.7, 0.9]
## The order the numbers print in.
const KEYS := ["eye_at", "eye_up", "pec_at", "pec_len", "pec_chord", "fluke_span", "fluke_sweep",
		"dorsal_at", "dorsal_h", "max_w", "max_d", "max_d_at", "stock_at", "jaw_len",
		"w10", "d10", "w30", "d30", "w50", "d50", "w70", "d70", "w90", "d90"]

var _failed := false


func _initialize() -> void:
	var fish := "titan"
	var which := "all"
	var skin := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fish="):
			fish = arg.trim_prefix("--fish=")
		elif arg.begins_with("--species="):
			which = arg.trim_prefix("--species=")
		elif arg.begins_with("--skin="):
			skin = int(arg.trim_prefix("--skin="))
	_run.call_deferred(fish, which, skin)


func _run(fish: String, which: String, skin: int) -> void:
	var specs := _read_specs(FileAccess.get_file_as_string(SPEC))
	if fish == "titan":
		var titan: GDScript = load(TITAN)
		if titan == null:
			push_error("model_measure: %s doesn't load" % TITAN)
			quit(2)
			return
		var keys: Array = titan.SPECIES_KEYS
		var picks: Array = keys if which == "all" else [which]
		for key: String in picks:
			var species := keys.find(key)
			if species < 0:
				species = clampi(int(key), 0, keys.size() - 1)
				key = keys[species]
			var model: FishModel = titan.make(species, skin)
			root.add_child(model)
			await process_frame
			_report("titan/%s" % key, _measure(model), specs.get(key, {}), model)
			model.queue_free()
	else:
		var fish_class := FishCharacter.from_key(fish)
		var model := FishModel.build(fish_class, int(which) if which.is_valid_int() else 0)
		root.add_child(model)
		await process_frame
		_report("%s/%d" % [fish, model.species], _measure(model), {}, model)
		model.queue_free()
	quit(1 if _failed else 0)


## The targets in titan_specs.md: species key -> {measure key: target}. Its
## proportion tables (`| key | 0.23 | note |`, `| max_w / max_d | 0.21 / 0.24 |`)
## and station tables (`| 0.1 | W | D | shape |`), under each `## N. Name — `key``.
static func _read_specs(text: String) -> Dictionary:
	var specs := {}
	var current := {}
	var header := RegEx.create_from_string("^## \\d+\\..*`(\\w+)`")
	for line in text.split("\n"):
		var found := header.search(line)
		if found:
			current = {}
			specs[found.get_string(1)] = current
			continue
		if not line.begins_with("|"):
			continue
		var cells := line.split("|")
		if cells.size() < 4:
			continue
		var first := cells[1].strip_edges()
		var second := cells[2].strip_edges()
		if first.is_valid_float() and second.is_valid_float():
			var station := int(roundf(float(first) * 100.0))
			current["w%d" % station] = float(second)
			current["d%d" % station] = float(cells[3].strip_edges())
			continue
		var names := first.split("/")
		var values := second.split("/")
		if names.size() != values.size():
			continue
		for i in names.size():
			var name := names[i].strip_edges()
			var value := values[i].strip_edges()
			if KEYS.has(name) and value.is_valid_float():
				current[name] = float(value)
	return specs


## Everything model_measure reads off `model` (at rest), over L.
func _measure(model: FishModel) -> Dictionary:
	var out := {}
	var body := model.find_child("Body", true, false) as MeshInstance3D
	if body == null:
		push_error("model_measure: no Body mesh")
		return out
	var rings := _rings(_points(body, model))
	var nose: float = rings[0].z
	var end: float = rings[-1].z
	var length := end - nose
	out["L"] = length
	var at := func(along: float) -> Dictionary: return _ring_at(rings, nose + along * length)
	for station: float in STATIONS:
		var ring: Dictionary = at.call(station)
		out["w%d" % int(roundf(station * 100.0))] = ring.w / length
		out["d%d" % int(roundf(station * 100.0))] = (ring.top - ring.bot) / length
	# Biggest slice, and where the tail stock starts (narrow and tall).
	var widest := 0.0
	var deepest := 0.0
	var deepest_z := nose
	for ring: Dictionary in rings:
		widest = maxf(widest, ring.w)
		if ring.top - ring.bot > deepest:
			deepest = ring.top - ring.bot
			deepest_z = ring.z
	out["max_w"] = widest / length
	out["max_d"] = deepest / length
	out["max_d_at"] = (deepest_z - nose) / length
	for ring: Dictionary in rings:
		var along: float = (ring.z - nose) / length
		if along > 0.55 and ring.w / maxf(ring.top - ring.bot, 1e-6) < 0.75:
			out["stock_at"] = along
			break
	# Eyes: the right one.
	for eye: Node in model.find_children("*Eye*","MeshInstance3D", true, false):
		var place := _in_model(eye as Node3D, model).origin
		if place.x <= 0.0:
			continue
		out["eye_at"] = (place.z - nose) / length
		var ring: Dictionary = at.call(out.eye_at)
		out["eye_up"] = (place.y - ring.bot) / maxf(ring.top - ring.bot, 1e-6)
		break
	# The right flipper: root at its pivot, length to its farthest point, and its
	# widest chord across the span.
	if model.fin_right:
		var pivot := _in_model(model.fin_right, model).origin
		out["pec_at"] = (pivot.z - nose) / length
		var points := PackedVector3Array()
		for part: Node in model.fin_right.find_children("*", "MeshInstance3D", true, false):
			if int(part.get_meta("lod", 0)) == 0:
				points.append_array(_points(part as MeshInstance3D, model))
		if not points.is_empty():
			var far := Vector3.ZERO
			for p in points:
				if (p - pivot).length() > far.length():
					far = p - pivot
			out["pec_len"] = far.length() / length
			out["pec_chord"] = _widest_chord(points, pivot, far.normalized(), far.length()) / length
	# Flukes: span tip to tip and how far the tips trail the notch.
	var flukes := PackedVector3Array()
	for part: Node in model.find_children("*Fluke*", "MeshInstance3D", true, false):
		if int(part.get_meta("lod", 0)) == 0:
			flukes.append_array(_points(part as MeshInstance3D, model))
	if not flukes.is_empty():
		var low := INF
		var high := -INF
		var back := -INF
		for p in flukes:
			low = minf(low, p.x)
			high = maxf(high, p.x)
			back = maxf(back, p.z)
		out["fluke_span"] = (high - low) / length
		out["fluke_sweep"] = (back - end) / length
	# The dorsal fin's peak above the back; or, without one, the highest the
	# relief (hump, ridge) raises the back over the bare body.
	var bare_rings: Array = []
	if model.has_meta("titan_species"):
		var titan: GDScript = load(TITAN)
		var bare: ArrayMesh = titan.bare_body_mesh(model)
		bare_rings = _rings(_mesh_points(bare, Transform3D.IDENTITY))
	var dorsal := model.find_child("Dorsal", true, false) as MeshInstance3D
	if dorsal:
		var peak := Vector3(0.0, -INF, 0.0)
		for p in _points(dorsal, model):
			if p.y > peak.y:
				peak = p
		var under: Dictionary = _ring_at(bare_rings if not bare_rings.is_empty() else rings, peak.z)
		out["dorsal_at"] = (peak.z - nose) / length
		out["dorsal_h"] = (peak.y - under.top) / length
	elif not bare_rings.is_empty():
		var best := 0.0
		var best_z := nose
		for ring: Dictionary in rings:
			var along: float = (ring.z - nose) / length
			if along < 0.35 or along > 0.9:
				continue
			var raised: float = ring.top - (_ring_at(bare_rings, ring.z).top as float)
			if raised > best:
				best = raised
				best_z = ring.z
		out["dorsal_at"] = (best_z - nose) / length
		out["dorsal_h"] = best / length
	var jaw := model.find_child("Jaw", true, false) as MeshInstance3D
	if jaw:
		var front := INF
		var rear := -INF
		for p in _points(jaw, model):
			front = minf(front, p.z)
			rear = maxf(rear, p.z)
		out["jaw_len"] = (rear - front) / length
	return out


## Prints `measured` next to `targets`, flags each that's off by more than
## TOLERANCE, and lists the meshes' triangles (per LOD where it has them).
func _report(title: String, measured: Dictionary, targets: Dictionary, model: FishModel) -> void:
	var length: float = measured.get("L", 0.0)
	print("\n=== %s  (L = %.2f m) ===" % [title, length])
	print("%-12s %9s %9s %8s" % ["key", "target", "measured", "off"])
	var fails := 0
	var checked := 0
	for key: String in KEYS:
		if not measured.has(key) and not targets.has(key):
			continue
		var value: float = measured.get(key, NAN)
		if not targets.has(key):
			print("%-12s %9s %9.4f" % [key, "-", value])
			continue
		var target: float = targets[key]
		checked += 1
		if is_nan(value):
			print("%-12s %9.4f %9s %8s  FAIL (not measured)" % [key, target, "-", "-"])
			fails += 1
			continue
		var off := (value - target) / target
		var ok := absf(off) <= TOLERANCE + 1e-6
		if not ok:
			fails += 1
		print("%-12s %9.4f %9.4f %+7.1f%%  %s" % [key, target, value, off * 100.0, "ok" if ok else "FAIL"])
	if checked > 0:
		print("%s: %d of %d within ±%d%%" % ["PASS" if fails == 0 else "FAIL", checked - fails, checked, int(TOLERANCE * 100)])
		if fails > 0:
			_failed = true
	if length > 0.0:
		print("natural size: width %.2f m, depth %.2f m, standard length %.2f m (fluke span %.2f m)" % [
				measured.get("max_w", 0.0) * length, measured.get("max_d", 0.0) * length, length,
				measured.get("fluke_span", 0.0) * length])
	var per_lod := {}
	for part: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (part as MeshInstance3D).mesh
		if mesh == null:
			continue
		var lod: int = part.get_meta("lod", 0)
		var triangles := 0
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += indices.size() / 3 if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		per_lod[lod] = per_lod.get(lod, 0) + triangles
	for lod: int in per_lod:
		print("LOD%d: %d triangles" % [lod, per_lod[lod]])


## `part`'s transform in `model`'s space (its own and its parents' up to it).
static func _in_model(part: Node3D, model: Node3D) -> Transform3D:
	var to_model := Transform3D.IDENTITY
	var node: Node = part
	while node and node != model:
		if node is Node3D:
			to_model = (node as Node3D).transform * to_model
		node = node.get_parent()
	return to_model


## `part`'s vertices in `model`'s space.
static func _points(part: MeshInstance3D, model: Node3D) -> PackedVector3Array:
	return _mesh_points(part.mesh, _in_model(part, model))


static func _mesh_points(mesh: Mesh, to_model: Transform3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	if mesh == null:
		return points
	for s in mesh.get_surface_count():
		for p: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			points.append(to_model * p)
	return points


## A lofted body's slices: its vertices grouped by z (each ring of the loft is
## one z), nose first, each slice's full width and its top and bottom.
static func _rings(points: PackedVector3Array) -> Array:
	var by_z := {}
	for p in points:
		var z := snappedf(p.z, 0.0001)
		if not by_z.has(z):
			by_z[z] = {"z": z, "w": 0.0, "top": -INF, "bot": INF}
		var ring: Dictionary = by_z[z]
		ring.w = maxf(ring.w, absf(p.x) * 2.0)
		ring.top = maxf(ring.top, p.y)
		ring.bot = minf(ring.bot, p.y)
	var rings: Array = by_z.values()
	rings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.z < b.z)
	return rings


## The slice at `z`, between the two rings either side of it.
static func _ring_at(rings: Array, z: float) -> Dictionary:
	if rings.is_empty():
		return {"z": z, "w": 0.0, "top": 0.0, "bot": 0.0}
	if z <= rings[0].z:
		return rings[0]
	for i in range(1, rings.size()):
		var b: Dictionary = rings[i]
		if z <= b.z:
			var a: Dictionary = rings[i - 1]
			var f := inverse_lerp(a.z, b.z, z)
			return {"z": z, "w": lerpf(a.w, b.w, f), "top": lerpf(a.top, b.top, f), "bot": lerpf(a.bot, b.bot, f)}
	return rings[-1]


## A flipper's widest chord: its points binned along its span (from `pivot`
## along `span` for `reach` m), the greatest spread across the span in a bin.
static func _widest_chord(points: PackedVector3Array, pivot: Vector3, span: Vector3, reach: float) -> float:
	var bins := 24
	var groups: Array = []
	groups.resize(bins)
	for i in bins:
		groups[i] = []  # packed arrays copy on cast; plain arrays share
	for p in points:
		var along := (p - pivot).dot(span)
		var i := clampi(int(along / reach * bins), 0, bins - 1)
		var across := (p - pivot) - span * along
		(groups[i] as Array).append(across)
	var widest := 0.0
	for group: Array in groups:
		for a in group.size():
			for b in range(a + 1, group.size()):
				widest = maxf(widest, (group[a] as Vector3).distance_to(group[b]))
	return widest
