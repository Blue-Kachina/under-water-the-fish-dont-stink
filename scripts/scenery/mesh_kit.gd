class_name MeshKit
extends RefCounted
## Procedural meshes for scenery (planning_environment.md): every piece is
## one or more smooth parametric surfaces (a grid of rows x columns, wrapped
## round when it's a solid of revolution), merged into one mesh, with smooth
## normals and no seams. Shaders paint the material in world space
## (triplanar), so there are no UVs; the vertex colour carries what a
## shader can't know:
##   r = cavity (0 open .. 1 deep in a hollow: grime, darker),
##   g = wear (0 crisp .. 1 a broken or chipped face: paler, rougher),
##   b = a per-piece random (variation between copies),
##   a = height share up the piece (0 at its foot .. 1 at its top).
##
## A surface is defined by `point(u, v)` with u round (0..1) and v along
## (0..1), returning a Vector3, or [Vector3, cavity, wear].
##
##   var kit := MeshKit.new()
##   kit.surface(32, 16, func(u, v): return Vector3(cos(u * TAU), v, sin(u * TAU)), true)
##   var mesh := kit.mesh(true)  # with LODs

var verts := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
## Each vertex's normal group (vertices sharing a group are smoothed
## together; caps get their own, so a break's edge stays crisp).
var _random := 0.0
var _bottom := INF
var _top := -INF


## Adds a grid surface `cols` x `rows` quads. `wrap`: u goes all the way round
## (the last column joins the first). Caps close the v = 0 / v = 1 ends with a
## fan to their centre (a separate, crisp face, its wear `cap_wear`).
func surface(cols: int, rows: int, point: Callable, wrap := true, cap_start := false, cap_end := false, cap_wear := 0.0,
		flip := false) -> void:
	var first := verts.size()
	var width := cols if wrap else cols + 1
	for row in rows + 1:
		var v := float(row) / rows
		for col in width:
			var u := float(col) / cols
			_add_point(point.call(u, v))
	for row in rows:
		for col in cols:
			var a := first + row * width + col
			var b := first + row * width + (col + 1) % width if wrap else a + 1
			var c := a + width
			var d := b + width
			_quad(a, b, d, c, flip)
	if cap_start:
		_cap(first, width, wrap, cap_wear, not flip)
	if cap_end:
		_cap(first + rows * width, width, wrap, cap_wear, flip)


## A solid of revolution round +Y: `profile` is [radius, height] pairs from
## the bottom up; `shape(angle, v)` (optional) scales the radius round the
## way (flutes, a superellipse for a square block). Caps as surface().
func lathe(profile: PackedVector2Array, sides: int, shape := Callable(), cap_start := true, cap_end := true, cap_wear := 0.0) -> void:
	var rows := profile.size() - 1
	surface(sides, rows, func(u: float, v: float) -> Variant:
		var row := clampi(roundi(v * rows), 0, rows)
		var p := profile[row]
		var angle := u * TAU
		var r: float = p.x * (shape.call(angle, v) if shape.is_valid() else 1.0)
		return Vector3(cos(angle) * r, p.y, sin(angle) * r), true, cap_start, cap_end, cap_wear)


## A tube along `path` (points), `radius` at each point (or one for all).
func tube(path: PackedVector3Array, radii: PackedFloat32Array, sides: int, cap_start := true, cap_end := true) -> void:
	var n := path.size()
	var frames := MeshKit.frames(path)
	surface(sides, n - 1, func(u: float, v: float) -> Vector3:
		var i := clampi(roundi(v * (n - 1)), 0, n - 1)
		var r := radii[mini(i, radii.size() - 1)]
		var f: Basis = frames[i]
		var angle := u * TAU
		return path[i] + (f.x * cos(angle) + f.y * sin(angle)) * r, true, cap_start, cap_end, 0.0, true)  # its frames turn the other way round to a lathe's


## Rotation-minimising frames along `path`: x and y across, z along.
static func frames(path: PackedVector3Array) -> Array[Basis]:
	var out: Array[Basis] = []
	var n := path.size()
	var up := Vector3.UP
	for i in n:
		var along := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		if absf(along.dot(up)) > 0.98:
			up = Vector3.RIGHT
		var x := up.cross(along).normalized()
		var y := along.cross(x).normalized()
		up = y
		out.append(Basis(x, y, along))
	return out


## Moves every vertex added since `first` by `offset(p) -> Vector3` (noise
## displacement, bends); call before mesh().
func displace(first: int, offset: Callable) -> void:
	for i in range(first, verts.size()):
		verts[i] += offset.call(verts[i])


## Everything added since `first`, transformed.
func transform(first: int, xf: Transform3D) -> void:
	for i in range(first, verts.size()):
		verts[i] = xf * verts[i]


## Copies `other`'s geometry in, transformed.
func merge(other: MeshKit, xf := Transform3D.IDENTITY) -> void:
	var offset := verts.size()
	for i in other.verts.size():
		verts.append(xf * other.verts[i])
		colors.append(other.colors[i])
	for index in other.indices:
		indices.append(index + offset)
	for span in other._caps:
		_caps.append(span + Vector2i(offset, offset))


## The vertex colour's per-piece random (b) for what's added next.
func set_random(value: float) -> void:
	_random = value


## The finished mesh: smooth normals (welded by position, so wrapped seams and
## shared rims shade as one), the height share (a), and `material`.
## `lods`: Godot's LOD chain, for scenery seen from far off.
func mesh(lods := false, material: Material = null) -> ArrayMesh:
	_bottom = INF
	_top = -INF
	for p in verts:
		_bottom = minf(_bottom, p.y)
		_top = maxf(_top, p.y)
	var span := maxf(_top - _bottom, 0.001)
	for i in colors.size():
		colors[i].a = (verts[i].y - _bottom) / span
	var normals := _normals()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	if lods:
		var importer := ImporterMesh.new()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, material)
		importer.generate_lods(25.0, 60.0, [])
		return importer.get_mesh()
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		out.surface_set_material(0, material)
	return out


func triangle_count() -> int:
	return indices.size() / 3


func _add_point(value: Variant) -> void:
	if value is Array:
		verts.append(value[0])
		colors.append(Color(value[1] if value.size() > 1 else 0.0, value[2] if value.size() > 2 else 0.0, _random, 0.0))
	else:
		verts.append(value)
		colors.append(Color(0.0, 0.0, _random, 0.0))


func _quad(a: int, b: int, d: int, c: int, flip: bool) -> void:
	if flip:
		indices.append_array([a, d, b, a, c, d])
	else:
		indices.append_array([a, b, d, a, d, c])


## A fan over the ring starting at `start` (`count` points), its own vertices.
func _cap(start: int, count: int, wrap: bool, wear: float, flip: bool) -> void:
	var ring := PackedVector3Array()
	var centre := Vector3.ZERO
	var last := count if wrap else count - 1
	for i in last:
		ring.append(verts[start + i])
		centre += verts[start + i]
	centre /= ring.size()
	var hub := verts.size()
	verts.append(centre)
	colors.append(Color(0.2, wear, _random, 0.0))
	for p in ring:
		verts.append(p)
		colors.append(Color(0.0, wear, _random, 0.0))
	for i in ring.size():
		var a := hub + 1 + i
		var b := hub + 1 + (i + 1) % ring.size()
		if flip:
			indices.append_array([hub, b, a])
		else:
			indices.append_array([hub, a, b])
	# Cap vertices stay out of the smoothing weld: a crisp edge.
	_caps.append(Vector2i(hub, hub + ring.size() + 1))


var _caps: Array[Vector2i] = []


## Area-weighted smooth normals, welding vertices at the same place (except
## caps', which keep their own face's normal for a crisp edge).
func _normals() -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		var n := (verts[c] - verts[a]).cross(verts[b] - verts[a])  # Godot: clockwise is the front
		normals[a] += n
		normals[b] += n
		normals[c] += n
	var in_cap := PackedByteArray()
	in_cap.resize(verts.size())
	for span in _caps:
		for i in range(span.x, span.y):
			in_cap[i] = 1
	# Weld: sum the normals of vertices at the same spot (seams, rims, poles).
	var cells := {}
	for i in verts.size():
		if in_cap[i]:
			continue
		var key := Vector3i((verts[i] * 2000.0).round())
		if cells.has(key):
			(cells[key] as PackedInt32Array).append(i)
		else:
			cells[key] = PackedInt32Array([i])
	for key: Vector3i in cells:
		var group: PackedInt32Array = cells[key]
		if group.size() < 2:
			continue
		var sum := Vector3.ZERO
		for i in group:
			sum += normals[i]
		for i in group:
			normals[i] = sum
	for i in normals.size():
		normals[i] = normals[i].normalized() if normals[i].length_squared() > 0.0 else Vector3.UP
	return normals
