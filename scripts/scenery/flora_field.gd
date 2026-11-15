class_name FloraField
extends Node3D
## Blade flora (planning_abyssal_look.md, flora pass): kelp, grass and cover made of thousands of curved-ribbon blades, each one
## instance of a single small mesh (ROWS rows of two vertices). The blade's data rides in its MultiMesh transform (see
## shaders/flora_blade.gdshader for the layout) and the shader does the arc, twist, ruffle, sway and colour, so a blade costs 48 bytes
## and no CPU per frame.
##
## Like Scatter, the copies are cut into TILE-metre tiles, one MultiMeshInstance3D per tile (per layer), each drawn only within
## `draw_distance`. Blades have two levels of detail: the near tile draws the full mesh out to `lod_distance`, past that a second
## MultiMesh draws only `far_keep` of the blades (a stable subset), each on a 3-row mesh and a little wider.
## Glints (sparkles riding on the kelp) are a second layer on the same tiles.
##
##   field.add_kelp_column(base, height, kind, density, dice, glints)   # the abyssal-garden column
##   field.add_blade(...) / add_glint(...)                              # single pieces
##   field.build()
##   field.clear_around(spot, radius)                                   # a shrine went here
##
## The node must only be translated (the shaders read the blade data from MODEL_MATRIX).

const TILE := 32.0
## Floats per instance (a 3x4 transform).
const STRIDE := 12
enum Layer { BLADE, GLINT }
## Blade types (flora_blade.gdshader): the palette the shader gives each.
enum Type { OLIVE, DARK, TEAL, VIOLET, AMBER, MAGENTA, RED, CYAN }

## Past this (m) a tile isn't drawn (0: always).
var draw_distance := 0.0:
	set(value):
		draw_distance = value
		_apply_ranges()
## How far a tile fades out before draw_distance (m).
var fade := 8.0
## Where the full-detail mesh hands over to the thin far one (m; 0: always full detail).
var lod_distance := 28.0
## The share of blades the far level keeps (0..1).
var far_keep := 0.6
var rows_near := 7
var rows_far := 3

static var _blade_materials := {}
static var _glint_material: ShaderMaterial
static var _meshes := {}

## layer -> {tile key (Vector2i) -> PackedFloat32Array of STRIDE floats per copy}
var _tiles: Array[Dictionary] = [{}, {}]
## [layer, key, far] -> MultiMeshInstance3D
var _nodes := {}


# --- Shared pieces -----------------------------------------------------------------

## The blade mesh with `rows` rows (2 vertices each). UV = (side -1/+1, row fraction, spaced as the shader likes: sin of a quarter
## wave, so rows bunch up toward the tip where the curl is).
static func blade_mesh(rows: int) -> ArrayMesh:
	rows = maxi(rows, 2)
	var key := "blade/%d" % rows
	if _meshes.has(key):
		return _meshes[key]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for r in rows:
		var v := sin(float(r) / float(rows - 1) * PI * 0.5)
		for side: float in [-1.0, 1.0]:
			verts.append(Vector3(side * 0.1, v, 0.0))
			normals.append(Vector3(0.0, 0.0, 1.0))
			uvs.append(Vector2(side, v))
	for r in rows - 1:
		var a := r * 2
		idx.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 90, 80))
	_meshes[key] = mesh
	return mesh


static func glint_quad() -> ArrayMesh:
	if _meshes.has("glint"):
		return _meshes["glint"]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	_meshes["glint"] = mesh
	return mesh


## The blade material: `far` is the thin level (a little wider blades to make up for the dropped ones).
static func blade_material(far := false) -> ShaderMaterial:
	if not _blade_materials.has(far):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/flora_blade.gdshader")
		_blade_materials[far] = m
	return _blade_materials[far]


## The glint material (WaterLook pushes its look to it each frame, like the old glint material).
static func glint_material() -> ShaderMaterial:
	if _glint_material == null:
		_glint_material = ShaderMaterial.new()
		_glint_material.shader = preload("res://shaders/flora_glint.gdshader")
	return _glint_material


## Pushes the panel's look (sway, width, length, brightness, where blades have faded out) to the shared materials.
static func push_look(sway: float, width: float, length: float, brightness: float, far_dist: float, far_keep_share: float) -> void:
	for far: bool in [false, true]:
		var m := blade_material(far)
		m.set_shader_parameter("sway_amount", sway)
		m.set_shader_parameter("width_mul", width * (1.0 / sqrt(clampf(far_keep_share, 0.05, 1.0)) if far else 1.0))
		m.set_shader_parameter("length_mul", length)
		m.set_shader_parameter("brightness", brightness)
		m.set_shader_parameter("far_dist", maxf(far_dist, 20.0))
	glint_material().set_shader_parameter("sway_amount", sway)


# --- Adding ------------------------------------------------------------------------

func add_blade(origin: Vector3, length: float, yaw: float, tilt: float, width: float, sway_height: float, type: int, bend: float,
		s1: float, s2: float) -> void:
	var data := _tile(Layer.BLADE, origin)
	var n := data.size()
	data.resize(n + STRIDE)
	data[n] = length
	data[n + 1] = width
	data[n + 2] = s1
	data[n + 3] = origin.x
	data[n + 4] = yaw
	data[n + 5] = sway_height
	data[n + 6] = s2
	data[n + 7] = origin.y
	data[n + 8] = tilt
	data[n + 9] = float(type) + clampf(bend, 0.0, 1.0) * 0.99
	data[n + 10] = 0.0
	data[n + 11] = origin.z


func add_glint(at: Vector3, sway_height: float, r1: float, r2: float) -> void:
	var data := _tile(Layer.GLINT, at)
	var n := data.size()
	data.resize(n + STRIDE)
	data[n] = sway_height
	data[n + 3] = at.x
	data[n + 4] = r1
	data[n + 7] = at.y
	data[n + 8] = r2
	data[n + 11] = at.z


## One giant-kelp column (abyssal-garden's `column`): 2-4 strands twisting round each other, a stipe of long dark leaves every 1.7 m
## along each, and `blades_per_m` ribbons per metre of height scattered over the strands, shorter and more upright toward the top.
## `kind`: 0 olive, 1 violet (types 3/4), 2 amber (4/0). `density` multiplies the blade count (rolled at 0.55-1.3 per column).
## `glints_per_m` sparkles ride along the strands. Returns the number of blades added.
func add_kelp_column(base: Vector3, height: float, kind: int, blades_per_m: float, density: float, glints_per_m: float, width_scale: float,
		dice: RandomNumberGenerator) -> int:
	var strands := 2 + (1 if dice.randf() < 0.6 else 0) + (1 if dice.randf() < 0.3 else 0)
	var phase := dice.randf() * TAU
	var twist := dice.randf_range(0.1, 0.28)
	var strand_r := dice.randf_range(0.2, 0.55)
	var size_mul := dice.randf_range(0.75, 1.25)
	var lean_angle := dice.randf() * TAU
	var lean_amount := dice.randf_range(0.0, 0.11)
	var full := dice.randf_range(0.55, 1.3) * density
	var lean_dir := Vector2(cos(lean_angle), sin(lean_angle))
	var stem := func(s: int, h: float) -> Vector3:
		var a := phase + float(s) * TAU / float(strands) + h * twist
		var r := strand_r * (1.0 - 0.6 * h / height)
		var ln := lean_amount * h * h / height
		return Vector3(base.x + cos(a) * r + lean_dir.x * ln, a, base.z + sin(a) * r + lean_dir.y * ln)  # y holds the angle
	var added := 0
	# The stipe: long, dark, almost straight leaves, one per 1.7 m of each strand.
	for s in strands:
		var h := 0.0
		while h < height - 1.0:
			var p: Vector3 = stem.call(s, h)
			add_blade(Vector3(p.x, base.y + h, p.z), 2.1, p.y + PI / 2.0, 0.1, 0.17 * width_scale, h, Type.DARK, 0.3, dice.randf(), dice.randf())
			added += 1
			h += 1.7
	var count := floori(height * blades_per_m * full)
	for i in count:
		var t := pow(dice.randf(), 0.9)
		var h := t * height
		var p: Vector3 = stem.call(dice.randi() % strands, h)
		var length := ((0.55 + 0.75 * dice.randf() * dice.randf()) * (1.0 - 0.5 * t * t) * size_mul + 0.25) * (1.25 if kind == 1 else 1.15)
		var tilt := lerpf(dice.randf_range(0.4, 1.0), dice.randf_range(0.15, 0.45), t)
		var type := Type.OLIVE
		if kind == 1:
			type = Type.VIOLET if dice.randf() < 0.8 else Type.AMBER
		elif kind == 2:
			type = Type.AMBER if dice.randf() < 0.5 else Type.OLIVE
		var width := (length * (dice.randf_range(0.09, 0.13) if kind == 1 else dice.randf_range(0.15, 0.21)) + 0.03) * width_scale
		add_blade(Vector3(p.x, base.y + h, p.z), length, dice.randf() * TAU, tilt, width, h, type, dice.randf_range(0.38, 0.95),
				dice.randf(), dice.randf())
		added += 1
	for i in roundi(height * glints_per_m):
		var h := dice.randf() * height
		var a := dice.randf() * TAU
		var r := dice.randf_range(0.15, 0.8) * (1.0 - 0.5 * h / height)
		var ln := lean_amount * h * h / height
		add_glint(Vector3(base.x + cos(a) * r + lean_dir.x * ln, base.y + h, base.z + sin(a) * r + lean_dir.y * ln), h, dice.randf(),
				dice.randf() if kind == 1 else dice.randf() * 0.6)
	return added


# --- Cover recipes (phase 3) -----------------------------------------------------------
# Small things made of a few blades each. They share a blade budget (`cover_cap`, 0: none) and a count multiplier.

## Multiplies the number of blades in every recipe below (stochastic rounding, so a tuft of 3 at 0.5 is 1 or 2).
var count_mult := 1.0
## The most blades the recipes below may add in all (0: no limit).
var cover_cap := 0
## Blades the recipes below have added.
var cover_added := 0


func has_room() -> bool:
	return cover_cap <= 0 or cover_added < cover_cap


func _scaled(n: float, dice: RandomNumberGenerator) -> int:
	var scaled := n * count_mult
	var whole := floori(scaled)
	return whole + (1 if dice.randf() < scaled - whole else 0)


func _cover_blade(origin: Vector3, length: float, yaw: float, tilt: float, width: float, sway: float, type: int, bend: float,
		dice: RandomNumberGenerator) -> void:
	add_blade(origin, length, yaw, tilt, width, sway, type, bend, dice.randf(), dice.randf())
	cover_added += 1


## A ground-cover tuft: 2-4 short blades spread round a point (abyssal-garden's carpets). `scale` stretches the lengths.
func add_tuft(at: Vector3, type: int, scale: float, dice: RandomNumberGenerator, extra := 0.0) -> void:
	var n := _scaled(2.0 + dice.randf() * 3.0 + extra, dice)
	var yaw := dice.randf() * TAU
	for j in n:
		_cover_blade(at, dice.randf_range(0.08, 0.26) * scale, yaw + j * TAU / maxf(n, 1) + dice.randf_range(-0.4, 0.4),
				dice.randf_range(0.15, 0.85), dice.randf_range(0.035, 0.07) * (0.6 + 0.4 * scale), 0.0, type, dice.randf_range(0.3, 0.7), dice)


## A bigger clump of long ribbons rising from a spot (abyssal-garden's `cluster`): `n` blades within 0.5 m of `at`.
func add_cluster(at: Vector3, n: float, type: int, lmin: float, lmax: float, wmin: float, wmax: float, tmax: float, sway: float,
		dice: RandomNumberGenerator) -> void:
	for i in _scaled(n, dice):
		var a := dice.randf() * TAU
		var r := dice.randf() * 0.5
		_cover_blade(at + Vector3(cos(a) * r, 0.0, sin(a) * r), dice.randf_range(lmin, lmax), a, dice.randf_range(0.05, tmax),
				dice.randf_range(wmin, wmax), sway, type, dice.randf_range(0.3, 0.8), dice)


## A hanging clump: `n` fronds streaming down from the underside of something (roots at `at`, lengths scaled by `length`).
## `spread` is how far round `at` the roots scatter.
func add_hanging(at: Vector3, n: float, type_a: int, type_b: int, length: float, spread: float, dice: RandomNumberGenerator) -> void:
	for j in _scaled(n, dice):
		var p := at + Vector3(dice.randf_range(-spread, spread), 0.0, dice.randf_range(-spread, spread))
		_cover_blade(p, dice.randf_range(0.8, 3.2) * length, dice.randf() * TAU, PI - dice.randf_range(0.0, 0.4),
				dice.randf_range(0.08, 0.18) * (0.5 + 0.5 * length), 0.0, type_a if dice.randf() < 0.5 else type_b, dice.randf_range(0.3, 0.6), dice)


## A tuft growing out of a wall: `n` blades leaning out along `yaw` (the wall's outward direction).
func add_wall_tuft(at: Vector3, yaw: float, n: float, type: int, scale: float, dice: RandomNumberGenerator) -> void:
	for j in _scaled(n, dice):
		_cover_blade(at, dice.randf_range(0.5, 1.4) * scale, yaw + dice.randf_range(-0.9, 0.9), dice.randf_range(0.3, 1.1),
				dice.randf_range(0.06, 0.12) * (0.5 + 0.5 * scale), 0.5, type, dice.randf_range(0.2, 0.6), dice)


# --- Tiles ---------------------------------------------------------------------------

func _tile(layer: int, at: Vector3) -> PackedFloat32Array:
	var tiles: Dictionary = _tiles[layer]
	var key := Vector2i(floori(at.x / TILE), floori(at.z / TILE))
	if not tiles.has(key):
		tiles[key] = PackedFloat32Array()
	return tiles[key]


## Makes (or remakes) every tile's MultiMeshes.
func build() -> void:
	for layer in 2:
		for key: Vector2i in _tiles[layer]:
			_build_tile(layer, key)
	_apply_ranges()


## Removes every copy within `radius` m (flat) of `spot` (this node's space) and rebuilds the tiles it touched.
func clear_around(spot: Vector3, radius: float) -> void:
	var r2 := radius * radius
	for layer in 2:
		var tiles: Dictionary = _tiles[layer]
		for key: Vector2i in tiles.keys():
			var low := Vector2(key) * TILE - Vector2.ONE * radius
			var high := (Vector2(key) + Vector2.ONE) * TILE + Vector2.ONE * radius
			if spot.x < low.x or spot.z < low.y or spot.x > high.x or spot.z > high.y:
				continue
			var data: PackedFloat32Array = tiles[key]
			var kept := PackedFloat32Array()
			for i in _copies(data):
				var o := i * STRIDE
				var dx := data[o + 3] - spot.x
				var dz := data[o + 11] - spot.z
				if dx * dx + dz * dz > r2:
					kept.append_array(data.slice(o, o + STRIDE))
			if kept.size() != data.size():
				tiles[key] = kept
				_build_tile(layer, key)
	_apply_ranges()


## Blades placed in all.
func blade_count() -> int:
	var total := 0
	for key: Vector2i in _tiles[Layer.BLADE]:
		total += _copies(_tiles[Layer.BLADE][key])
	return total


func glint_count() -> int:
	var total := 0
	for key: Vector2i in _tiles[Layer.GLINT]:
		total += _copies(_tiles[Layer.GLINT][key])
	return total


## How many MultiMesh nodes (draw calls at most) there are.
func node_count() -> int:
	return _nodes.size()


## Blades the far level draws (the rest are dropped there).
func far_blade_count() -> int:
	var total := 0
	for key: Vector2i in _tiles[Layer.BLADE]:
		total += _copies(_far_subset(_tiles[Layer.BLADE][key]))
	return total


func _far_subset(data: PackedFloat32Array) -> PackedFloat32Array:
	if far_keep >= 0.999:
		return data
	var out := PackedFloat32Array()
	for i in _copies(data):
		var o := i * STRIDE
		if data[o + 2] < far_keep:  # s1 (a stable random)
			out.append_array(data.slice(o, o + STRIDE))
	return out


func _build_tile(layer: int, key: Vector2i) -> void:
	var data: PackedFloat32Array = _tiles[layer][key]
	if data.is_empty():
		for far: bool in [false, true]:
			var gone: MultiMeshInstance3D = _nodes.get([layer, key, far])
			if gone:
				gone.queue_free()
				_nodes.erase([layer, key, far])
		return
	var bounds := _bounds(layer, data)
	if layer == Layer.GLINT:
		_set_node(layer, key, false, glint_quad(), glint_material(), data, bounds)
		return
	_set_node(layer, key, false, blade_mesh(rows_near), blade_material(false), data, bounds)
	if lod_distance > 0.0:
		var thin := _far_subset(data)
		_set_node(layer, key, true, blade_mesh(rows_far), blade_material(true), thin, bounds)


func _set_node(layer: int, key: Vector2i, far: bool, mesh: Mesh, material: Material, data: PackedFloat32Array, bounds: AABB) -> void:
	var slot := [layer, key, far]
	var instance: MultiMeshInstance3D = _nodes.get(slot)
	if data.is_empty():
		if instance:
			instance.queue_free()
			_nodes.erase(slot)
		return
	if instance == null:
		instance = MultiMeshInstance3D.new()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.material_override = material
		add_child(instance)
		_nodes[slot] = instance
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = _copies(data)
	multimesh.buffer = data
	multimesh.custom_aabb = bounds
	instance.multimesh = multimesh


## A box round a tile's copies, grown by the longest blade and the sway (the shader moves the vertices well away from the roots).
func _bounds(layer: int, data: PackedFloat32Array) -> AABB:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var reach := 0.0
	for i in _copies(data):
		var o := i * STRIDE
		var p := Vector3(data[o + 3], data[o + 7], data[o + 11])
		low = low.min(p)
		high = high.max(p)
		var h := data[o + 5] if layer == Layer.BLADE else data[o]
		var length := data[o] * 2.5 if layer == Layer.BLADE else 0.0
		reach = maxf(reach, length + 0.024 * pow(h + length, 1.25) * 1.6)
	reach += 1.0
	return AABB(low - Vector3.ONE * reach, high - low + Vector3.ONE * reach * 2.0)


func _apply_ranges() -> void:
	for slot: Array in _nodes:
		var instance: MultiMeshInstance3D = _nodes[slot]
		var far: bool = slot[2]
		var end := draw_distance
		var begin := 0.0
		if lod_distance > 0.0 and slot[0] == Layer.BLADE:
			if far:
				begin = lod_distance
			else:
				end = lod_distance if draw_distance <= 0.0 else minf(lod_distance, draw_distance)
		instance.visibility_range_begin = begin
		instance.visibility_range_begin_margin = 0.0
		instance.visibility_range_end = end
		var fades_out := draw_distance > 0.0 and (end >= draw_distance - 0.01 or end == 0.0)
		instance.visibility_range_end_margin = fade if fades_out else 0.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if fades_out \
				else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## How many copies a tile's data holds.
@warning_ignore("integer_division")
static func _copies(data: PackedFloat32Array) -> int:
	return data.size() / STRIDE
