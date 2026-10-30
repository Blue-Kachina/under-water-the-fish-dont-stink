class_name BossMesh
extends RefCounted
## Builds a final boss's look as ONE mesh in its rest pose (spine_bend.gdshaderinc
## bends it): lofted bodies, fin membranes, tubes (filaments, barbels, ribs,
## jaws) and cones (teeth) all in one surface, so the boss is one seamless
## shape that bends as one. Every vertex carries:
## - UV: (along the part 0..1, round it 0..1);
## - UV2: (the part's id, its flutter weight 0..1: fins and filaments ripple);
## - COLOR: (sin, cos) round its slice as 0..1, how far along the whole body
##   (z / body length), and a free value per part;
## - CUSTOM0.x: its hinge weight (`hinge` while it was added): a jaw turns round
##   its hinge by that much of the shader's angle (spine_hinge).
## Winding follows FishModel._loft_mesh, so generate_normals points outward.
## Parts the shader tells apart by UV2.x: BODY, FIN, BONE (teeth, ribs),
## FILAMENT, INSIDE (a mouth or wound's flesh), and any the boss adds.

const BODY := 0.0
const FIN := 1.0
const BONE := 2.0
const FILAMENT := 3.0
const INSIDE := 4.0
const EXTRA := 5.0
const EXTRA2 := 6.0

var tool := SurfaceTool.new()
var count := 0
## The whole body's length (COLOR.b is z over it).
var body_length := 60.0
## The hinge weight given to the vertices added while it's set (a jaw: 1).
var hinge := 0.0


func _init(whole_length := 60.0) -> void:
	body_length = whole_length
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_custom_format(0, SurfaceTool.CUSTOM_R_FLOAT)


func _vertex(at: Vector3, uv: Vector2, part: float, weight: float, ring: Vector2, extra := 0.0) -> void:
	tool.set_uv(uv)
	tool.set_uv2(Vector2(part, weight))
	tool.set_color(Color(ring.x * 0.5 + 0.5, ring.y * 0.5 + 0.5, clampf(at.z / maxf(body_length, 0.001), 0.0, 1.0), extra))
	tool.set_custom(0, Color(hinge, 0.0, 0.0, 0.0))
	tool.add_vertex(at)
	count += 1


## A body of slices from z `from` to z `to`: `profile` gives each slice
## (`along` 0..1) as Vector4(half width, half height, its middle's height,
## squareness: 2 an oval, more boxier, less pointier); a slice that isn't 0
## thick at an end leaves that end open (a mouth). `weight`: a Callable(along)
## -> flutter weight. `bump`: a Callable(along, angle) -> how much further out
## (a multiplier) the surface sits there: folds, wrinkles, pleats in the shape.
func loft(from: float, to: float, profile: Callable, rows: int, around: int, part := BODY, weight := Callable(), extra := 0.0,
		bump := Callable()) -> void:
	var start := count
	for i in rows + 1:
		var along := float(i) / rows
		var z := lerpf(from, to, along)
		var slice: Vector4 = profile.call(along)
		var power := 2.0 / maxf(slice.w, 0.2)
		var w := 0.0 if not weight.is_valid() else float(weight.call(along))
		for k in around:
			var angle := TAU * k / around
			var s := sin(angle)
			var c := cos(angle)
			var out := 1.0 if not bump.is_valid() else float(bump.call(along, angle))
			var x := signf(s) * pow(absf(s), power) * slice.x * out
			var y := slice.z + signf(c) * pow(absf(c), power) * slice.y * out
			_vertex(Vector3(x, y, z), Vector2(along, float(k) / around), part, w, Vector2(s, c), extra)
	for i in rows:
		for k in around:
			var a := start + i * around + k
			var b := start + i * around + (k + 1) % around
			for corner: int in [a, b, a + around, b, b + around, a + around]:
				tool.add_index(corner)


## A membrane (a fin): `columns` along a root line, each a ray out from
## `root.call(u)` along `out.call(u)` (its length in it), `rows` from root to
## edge. Flutter weight grows from `flutter.x` at the root to `flutter.y` at the edge.
func membrane(root: Callable, out: Callable, columns: int, rows: int, flutter := Vector2(0.0, 1.0), part := FIN, extra := 0.0) -> void:
	var start := count
	for i in columns + 1:
		var u := float(i) / columns
		var base: Vector3 = root.call(u)
		var reach: Vector3 = out.call(u)
		for j in rows + 1:
			var v := float(j) / rows
			_vertex(base + reach * v, Vector2(u, v), part, lerpf(flutter.x, flutter.y, v), Vector2(0.0, 1.0), extra)
	for i in columns:
		for j in rows:
			var a := start + i * (rows + 1) + j
			var b := a + rows + 1
			for corner: int in [a, b, a + 1, a + 1, b, b + 1]:
				tool.add_index(corner)


## A tube through `path` (rest points, its start first), `radius.call(t)` thick
## (t 0..1 along it), `sides` round. Flutter weight from `flutter.x` to `flutter.y`.
func tube(path: PackedVector3Array, radius: Callable, sides: int, part := FILAMENT, flutter := Vector2.ZERO, extra := 0.0) -> void:
	var start := count
	var n := path.size()
	var last_up := Vector3.UP
	for i in n:
		var t := float(i) / maxf(n - 1, 1)
		var ahead := path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]
		var dir := ahead.normalized() if ahead.length_squared() > 1e-8 else Vector3.BACK
		var right := last_up.cross(dir)
		if right.length_squared() < 1e-6:
			right = Vector3.RIGHT.cross(dir)
		right = right.normalized()
		var up := dir.cross(right).normalized()
		last_up = up
		var r: float = radius.call(t)
		for k in sides:
			var angle := TAU * k / sides
			var s := sin(angle)
			var c := cos(angle)
			_vertex(path[i] + right * s * r + up * c * r, Vector2(t, float(k) / sides), part, lerpf(flutter.x, flutter.y, t), Vector2(s, c), extra)
	for i in n - 1:
		for k in sides:
			var a := start + i * sides + k
			var b := start + i * sides + (k + 1) % sides
			for corner: int in [a, b, a + sides, b, b + sides, a + sides]:
				tool.add_index(corner)


## A curved tooth: from a base `radius` round at `base`, along `axis` (its
## length in it) to a point, hooked toward `hook` (a direction) at its tip.
func tooth(base: Vector3, axis: Vector3, radius: float, hook := Vector3.ZERO, sides := 6, part := BONE) -> void:
	var path := PackedVector3Array()
	for i in 6:
		var t := i / 5.0
		path.append(base + axis * t + hook * t * t * axis.length())
	tube(path, func(t: float) -> float: return radius * (1.0 - t) + 0.002, sides, part)


## An ellipsoid `size` (half extents) at `at`, turned by `basis`.
func blob(at: Vector3, size: Vector3, basis := Basis.IDENTITY, rows := 8, around := 12, part := BODY, extra := 0.0) -> void:
	var start := count
	for i in rows + 1:
		var phi := PI * i / rows
		for k in around:
			var angle := TAU * k / around
			var local := Vector3(sin(phi) * sin(angle) * size.x, sin(phi) * cos(angle) * size.y, -cos(phi) * size.z)
			_vertex(at + basis * local, Vector2(float(i) / rows, float(k) / around), part, 0.0, Vector2(sin(angle), cos(angle)), extra)
	for i in rows:
		for k in around:
			var a := start + i * around + k
			var b := start + i * around + (k + 1) % around
			for corner: int in [a, b, a + around, b, b + around, a + around]:
				tool.add_index(corner)


func commit() -> ArrayMesh:
	tool.generate_normals()
	return tool.commit()


## A rest-pose loft profile helper: how thick (0..1) at `along`, swelling from
## a closed nose to its widest at `widest` (`nose`: 0.5 round, less blunter),
## then easing down to `tail_size` at 1 (closing to 0 if `close`).
static func taper(along: float, widest: float, tail_size: float, nose := 0.5, close := true) -> float:
	if along < widest:
		return pow(maxf(1.0 - pow((widest - along) / widest, 2.0), 0.0), nose)
	var t := (along - widest) / maxf(1.0 - widest, 0.001)
	var thick := lerpf(1.0, tail_size, t)
	if close:
		thick *= sqrt(maxf(1.0 - pow(maxf(t - 0.97, 0.0) / 0.03, 2.0), 0.0))
	return thick
