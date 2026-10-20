class_name SwordfishModel
extends RefCounted
## Breakout's billfish (FishModel.build hands it here), in skin m.skin of
## FishCharacter.SKINS[FishCharacter.Family.BREAKOUT]: one smooth lofted body
## from the tip of its bill to its keeled tail stalk (sword_skin.gdshader), a
## short lower jaw, stiff dark fins (sword_fin.gdshader) and a deeply forked
## crescent tail on the swim pivot. The rear of the body bends into the tail
## (FishModel._bend_body); the front stays stiff, as a tuna-shaped swimmer's
## does. The bill reaches the front of the hitbox; the dorsal fin and tail poke
## out of it.

const SKIN := preload("res://shaders/sword_skin.gdshader")
const FIN := preload("res://shaders/sword_fin.gdshader")

## Each skin's look. Fin outlines are (along the body, height) pairs: along is 0
## at the bill's base to 1 at the tail stalk's end, height is in the body's half
## heights above its back (below its belly for the anal fin).
const LOOKS: Array[Dictionary] = [
	{  # Broadbill swordfish: a long flat broad sword, a rigid tall sickle dorsal,
		# no pelvic fins, bronze-purple back, scaleless hide, one big keel a side.
		"albedo": Color(0.42, 0.31, 0.37), "back_shade": 0.42, "belly": Color(0.86, 0.85, 0.87),
		"sheen": Color(0.85, 0.6, 0.35), "fin_shade": Vector2(0.5, 0.36), "rays": Color(0.75, 0.6, 0.6),
		"bill": 0.33, "bill_size": Vector2(0.036, 0.01), "bill_power": 0.4,
		"semi": Vector2(0.095, 0.125), "keel": 0.5, "eye": 0.034, "iris": Color(0.12, 0.17, 0.32),
		"scales": 0.0, "pelvic": 0.0, "bars": 0.0,
		"dorsal": [Vector2(0.14, 0.0), Vector2(0.155, 0.9), Vector2(0.18, 1.8), Vector2(0.225, 2.45),
				Vector2(0.235, 1.7), Vector2(0.26, 0.8), Vector2(0.33, 0.0)],
	},
	{  # Blue marlin: round spear bill, cobalt back, faint pale-blue bars, the
		# dorsal high in front then low and long.
		"albedo": Color(0.17, 0.32, 0.64), "back_shade": 0.33, "belly": Color(0.9, 0.92, 0.95),
		"sheen": Color(0.35, 0.65, 1.0), "fin_shade": Vector2(0.55, 0.4), "rays": Color(0.6, 0.75, 1.0),
		"bill": 0.25, "bill_size": Vector2(0.016, 0.016), "bill_power": 0.7,
		"semi": Vector2(0.09, 0.125), "keel": 0.3, "eye": 0.03, "iris": Color(0.1, 0.16, 0.34),
		"scales": 1.0, "pelvic": 0.13,
		"bars": 0.28, "bar_color": Color(0.62, 0.78, 1.0), "bar_spacing": 0.07, "bar_width": 0.16,
		"bar_slant": 0.12, "bar_low": -0.35, "bar_dash": 0.0,
		"dorsal": [Vector2(0.12, 0.0), Vector2(0.14, 0.8), Vector2(0.17, 1.45), Vector2(0.2, 1.7),
				Vector2(0.24, 1.05), Vector2(0.32, 0.55), Vector2(0.45, 0.28), Vector2(0.6, 0.14), Vector2(0.66, 0.0)],
	},
	{  # Sailfish: a huge spotted sail down most of the back, slender body,
		# dashed pale bars, long trailing pelvic fins.
		"albedo": Color(0.15, 0.28, 0.55), "back_shade": 0.35, "belly": Color(0.9, 0.92, 0.94),
		"sheen": Color(0.4, 0.7, 1.0), "fin_shade": Vector2(0.75, 0.42), "rays": Color(0.45, 0.62, 1.0),
		"bill": 0.25, "bill_size": Vector2(0.013, 0.013), "bill_power": 0.75,
		"semi": Vector2(0.08, 0.11), "keel": 0.3, "eye": 0.028, "iris": Color(0.1, 0.16, 0.34),
		"scales": 1.0, "pelvic": 0.42,
		"bars": 0.75, "bar_color": Color(0.78, 0.88, 1.0), "bar_spacing": 0.065, "bar_width": 0.22,
		"bar_slant": 0.0, "bar_low": -0.3, "bar_dash": 0.026,
		"sail": true,
		"dorsal": [Vector2(0.11, 0.0), Vector2(0.115, 1.5), Vector2(0.14, 2.6), Vector2(0.21, 3.2),
				Vector2(0.33, 3.4), Vector2(0.45, 3.1), Vector2(0.56, 2.4), Vector2(0.66, 1.2), Vector2(0.74, 0.0)],
	},
	{  # Striped marlin: bold lavender-blue stripes over the whole flank, a
		# pointed dorsal as tall as the body is deep.
		"albedo": Color(0.17, 0.25, 0.53), "back_shade": 0.36, "belly": Color(0.92, 0.93, 0.95),
		"sheen": Color(0.55, 0.6, 1.0), "fin_shade": Vector2(0.6, 0.42), "rays": Color(0.55, 0.65, 1.0),
		"bill": 0.25, "bill_size": Vector2(0.015, 0.015), "bill_power": 0.7,
		"semi": Vector2(0.09, 0.125), "keel": 0.3, "eye": 0.03, "iris": Color(0.1, 0.16, 0.34),
		"scales": 1.0, "pelvic": 0.15,
		"bars": 0.85, "bar_color": Color(0.7, 0.75, 1.0), "bar_spacing": 0.06, "bar_width": 0.36,
		"bar_slant": 0.14, "bar_low": -0.5, "bar_dash": 0.0,
		"dorsal": [Vector2(0.12, 0.0), Vector2(0.15, 1.1), Vector2(0.19, 1.85), Vector2(0.225, 2.15),
				Vector2(0.25, 1.4), Vector2(0.31, 0.7), Vector2(0.45, 0.32), Vector2(0.6, 0.14), Vector2(0.64, 0.0)],
	},
]

## Where the body starts to bend into the tail (along) and how much of the
## tail's swing it takes: a stiff front, a supple rear third.
const BEND_FROM := 0.6
const BEND_SHARE := 0.55


## A billfish's shape: the loft from the bill tip (along 0) to the end of the
## tail stalk (along 1). The bill runs to `bill`; the head swells out of it.
class Shape:
	var ends := Vector2.ZERO  # z of the bill tip and the stalk's end
	var semi := Vector2.ONE  # the body's widest half width and half height (m)
	var bill := 0.3
	var bill_size := Vector2.ONE  # the bill's half width and height at its base (m)
	var bill_power := 0.5  # how the bill swells from its tip: low stays broad, high a spike
	var bill_y := 0.0  # the bill's height (m)
	var head := 0.27  # along where the head starts round the bill
	var keel := 0.7
	const STALK := 0.2  # the tail stalk's thickness, of the widest

	## Along the body from the bill's base (0) to the stalk's end (1): along.
	func at_body(t: float) -> float:
		return bill + t * (1.0 - bill)

	func z(along: float) -> float:
		return lerpf(ends.x, ends.y, along)

	func along_at(at_z: float) -> float:
		return inverse_lerp(ends.x, ends.y, at_z)

	## The slice `along`: (half width, half height, middle's height, keel 0..1).
	func slice(along: float) -> Vector4:
		var s := (along - head) / (1.0 - head)
		var r := Shape.radius(s)
		var t := clampf(along / bill, 0.0, 1.0)
		var b := bill_size * pow(t, bill_power)
		var sx := Shape.smax(semi.x * r, b.x, 0.012)
		var sy := Shape.smax(semi.y * r * lerpf(1.0, 0.8, smoothstep(0.75, 0.95, s)), b.y, 0.012)
		var lift := 1.0 - smoothstep(0.0, 0.4, s)  # the head rises from the bill
		var middle := lerpf(bill_y * 0.6 - semi.y * 0.04, bill_y, lift)
		var k := keel * smoothstep(0.7, 0.9, s) * (1.0 - smoothstep(0.94, 1.0, s))
		return Vector4(sx, sy, middle, k)

	## A point on the right side at `along`, `up` of the way from the middle
	## to the top (-1 the bottom).
	func point(along: float, up: float) -> Vector3:
		var s := slice(along)
		var c := sqrt(maxf(1.0 - up * up, 0.0))
		return Vector3(s.x * c * (1.0 - 0.1 * up), s.z + s.y * up, z(along))

	## How thick the body is (of its widest) `s` along it from the head's
	## start (0) to the stalk's end (1): a long conical head, widest a third of
	## the way back, a slim tail stalk that runs on to the tail and closes
	## quickly behind the tail's root.
	static func radius(s: float) -> float:
		var widest := 0.36
		if s <= 0.0:
			return 0.0
		if s < widest:
			return 1.0 - pow(1.0 - s / widest, 2.2)
		if s < 0.9:
			var t := (s - widest) / (0.9 - widest)
			return lerpf(1.0, STALK, t * t * (3.0 - 2.0 * t))
		if s < 0.96:
			return STALK
		return STALK * sqrt(maxf(1.0 - pow((s - 0.96) / 0.04, 2.0), 0.0))

	static func smax(a: float, b: float, k: float) -> float:
		var h := maxf(k - absf(a - b), 0.0) / k
		return maxf(a, b) + h * h * k * 0.25


static func build(m: FishModel) -> void:
	var look: Dictionary = LOOKS[clampi(m.skin, 0, LOOKS.size() - 1)]
	var l := m._size.z
	var shape := Shape.new()
	shape.ends = Vector2(-l * 0.5, l * 0.415)
	shape.semi = look.semi
	shape.bill = look.bill
	shape.bill_size = look.bill_size
	shape.bill_power = look.bill_power
	shape.bill_y = shape.semi.y * 0.12
	shape.head = shape.bill - 0.05
	shape.keel = look.keel
	var color: Color = look.albedo
	m._body_material = m._material(color)  # for set_body_color(); the skin does the shading
	var skin := _skin(m, look, shape)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _body_mesh(shape, 150, 40)
	body.material_override = skin
	m.add_child(body)
	var jaw := MeshInstance3D.new()
	jaw.name = "Jaw"
	jaw.mesh = _jaw_mesh(shape)
	jaw.material_override = skin
	m.add_child(jaw)
	var fins := _fin_material(m, look, false)
	var bent: Array = []
	_dorsal_fins(m, look, shape, fins, bent)
	_belly_fins(m, look, shape, fins, bent)
	_pectorals(m, shape, fins)
	_tail(m, shape, fins)
	m.bend_share = BEND_SHARE
	m._bend_body(shape.z(BEND_FROM), bent)
	_eyes(m, look, shape)


## The body's skin (sword_skin.gdshader), painted for this species.
static func _skin(m: FishModel, look: Dictionary, shape: Shape) -> ShaderMaterial:
	var skin := ShaderMaterial.new()
	skin.shader = SKIN
	skin.set_shader_parameter("albedo", look.albedo)
	skin.set_shader_parameter("back_shade", look.back_shade)
	skin.set_shader_parameter("belly_color", look.belly)
	skin.set_shader_parameter("sheen_color", look.sheen)
	skin.set_shader_parameter("bill_color", Color(0.16, 0.15, 0.17))
	var bill_end := shape.z(shape.bill + 0.01)
	skin.set_shader_parameter("bill_end", bill_end)
	skin.set_shader_parameter("mouth_z", shape.z(shape.at_body(0.09)))
	skin.set_shader_parameter("mouth_y", shape.bill_y - shape.bill_size.y * 1.1)
	skin.set_shader_parameter("gill_z", shape.z(shape.at_body(0.17)))
	skin.set_shader_parameter("gill_curve", shape.semi.y * 0.3)
	skin.set_shader_parameter("keel_z", shape.z(shape.at_body(0.86)))
	skin.set_shader_parameter("girth", (shape.semi.x + shape.semi.y) / 2.0)
	skin.set_shader_parameter("scales", look.scales)
	skin.set_shader_parameter("bar_strength", look.bars)
	if look.bars > 0.0:
		skin.set_shader_parameter("bar_color", look.bar_color)
		skin.set_shader_parameter("bar_spacing", look.bar_spacing)
		skin.set_shader_parameter("bar_width", look.bar_width)
		skin.set_shader_parameter("bar_slant", look.bar_slant)
		skin.set_shader_parameter("bar_low", look.bar_low)
		skin.set_shader_parameter("bar_dash", look.bar_dash)
		skin.set_shader_parameter("bar_span", Vector2(shape.z(shape.at_body(0.2)), shape.z(shape.at_body(0.82))))
	m._skins.append(skin)
	return skin


## The fins' look (sword_fin.gdshader), tinted with the body; the `sail` with
## spots and a slow ripple.
static func _fin_material(m: FishModel, look: Dictionary, sail: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FIN
	material.set_shader_parameter("albedo", look.albedo)
	var shade: Vector2 = look.fin_shade
	material.set_shader_parameter("root_shade", shade.x)
	material.set_shader_parameter("edge_shade", shade.y)
	material.set_shader_parameter("ray_color", look.rays)
	if sail:
		material.set_shader_parameter("root_shade", shade.x * 0.85)
		material.set_shader_parameter("edge_shade", shade.y * 0.8)
		material.set_shader_parameter("ray_strength", 0.45)
		material.set_shader_parameter("spots", 0.75)
		material.set_shader_parameter("flutter", 0.006)
	m._skins.append(material)
	m._waving.append(material)
	return material


## The body, nose to tail: oval slices (Shape.slice), a little narrower at the
## back than the belly, with keels out of the sides of the tail stalk.
static func _body_mesh(shape: Shape, rows: int, around: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows + 1:
		# Rows bunch toward the bill's tip and the stalk, where the shape turns.
		var t := float(i) / rows
		var along := t - 0.04 * sin(TAU * t)
		var slice := shape.slice(along)
		var z := shape.z(along)
		for k in around:
			var angle := TAU * k / around
			var c := cos(angle)
			var keel := 1.0 + slice.w * exp(-pow(c / 0.35, 2.0))
			tool.set_uv(Vector2(along, float(k) / around))
			tool.add_vertex(Vector3(sin(angle) * slice.x * (1.0 - 0.1 * c) * keel, slice.z + c * slice.y, z))
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, b, a + around, b, b + around, a + around]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## The short pointed lower jaw under the bill's base, running back into the
## head's underside.
static func _jaw_mesh(shape: Shape) -> ArrayMesh:
	var base := shape.z(shape.bill)
	var ends := Vector2(base - shape.semi.y * 0.45, base + shape.semi.y * 0.9)
	var size := Vector2(shape.bill_size.y * 1.6 + 0.01, shape.bill_size.y * 0.6 + 0.008)
	var top := shape.bill_y - shape.bill_size.y * 0.9
	var mesh_tool := SurfaceTool.new()
	mesh_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 14
	var around := 16
	for i in rows + 1:
		var t := float(i) / rows
		var r := pow(clampf(t / 0.45, 0.0, 1.0), 0.7) * sqrt(maxf(1.0 - pow(maxf(t - 0.8, 0.0) / 0.2, 2.0), 0.0))
		for k in around:
			var angle := TAU * k / around
			mesh_tool.add_vertex(Vector3(sin(angle) * size.x * r, top - size.y * r + cos(angle) * size.y * r, lerpf(ends.x, ends.y, t)))
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, b, a + around, b, b + around, a + around]:
				mesh_tool.add_index(corner)
	mesh_tool.generate_normals()
	return mesh_tool.commit()


## The tall dorsal fin (the sail on a sailfish), and the tiny second dorsal
## near the tail.
static func _dorsal_fins(m: FishModel, look: Dictionary, shape: Shape, fins: ShaderMaterial, bent: Array) -> void:
	var material := _fin_material(m, look, true) if look.get("sail", false) else fins
	var outline: Array = look.dorsal
	var dorsal := _body_fin(m, shape, material, outline, 1.0, 0.008, 1.0 if look.get("sail", false) else 0.6)
	bent.append(dorsal)
	var second := _body_fin(m, shape, fins, [Vector2(0.855, 0.0), Vector2(0.87, 0.35), Vector2(0.9, 0.5), Vector2(0.895, 0.2), Vector2(0.905, 0.0)], 1.0, 0.004, 0.4)
	bent.append(second)


## The anal fins under the tail half, and the pelvic fins (none on a swordfish).
static func _belly_fins(m: FishModel, look: Dictionary, shape: Shape, fins: ShaderMaterial, bent: Array) -> void:
	var anal := _body_fin(m, shape, fins, [Vector2(0.53, 0.0), Vector2(0.56, 0.55), Vector2(0.6, 0.9), Vector2(0.64, 1.0),
			Vector2(0.62, 0.45), Vector2(0.6, 0.0)], -1.0, 0.006, 0.6)
	bent.append(anal)
	bent.append(_body_fin(m, shape, fins, [Vector2(0.86, 0.0), Vector2(0.875, 0.3), Vector2(0.9, 0.42), Vector2(0.895, 0.15), Vector2(0.905, 0.0)], -1.0, 0.004, 0.4))
	var pelvic: float = look.pelvic
	if pelvic <= 0.0:
		return
	# Two thin rays close together under the chest, trailing back and down.
	var root_along := shape.at_body(0.19)
	var root := shape.point(root_along, -0.92)
	var down := Vector3(0.0, -0.75, 1.0).normalized()
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 0.012, root.y, root.z)
		var out := Vector3(side * 0.12, -0.75, 1.0).normalized()
		_fin(m, m, fins, [at, at + Vector3.BACK * 0.02],
				[at, at + out * pelvic * 0.35 + down * 0.006, at + out * pelvic + Vector3.BACK * 0.01, at + out * pelvic * 0.4 + Vector3.BACK * 0.02, at + Vector3.BACK * 0.02],
				Vector3(1.0, 0.0, 0.0), 0.003, 4.0)


## A fin standing on the back (`up` 1) or hanging from the belly (-1) along
## the middle: `outline` its edge as (along the body, half heights out).
static func _body_fin(m: FishModel, shape: Shape, material: ShaderMaterial, outline: Array, up: float, thick: float, rays_per_dm: float) -> MeshInstance3D:
	var first: Vector2 = outline[0]
	var last: Vector2 = outline[outline.size() - 1]
	var root: Array[Vector3] = []
	for i in 9:
		var along := shape.at_body(lerpf(first.x, last.x, i / 8.0))
		root.append(_middle(shape, along, up * 0.9))
	var edge: Array[Vector3] = []
	for p: Vector2 in outline:
		var along := shape.at_body(p.x)
		var base := root[0] if p == first else (root[8] if p == last else _middle(shape, along, up))
		edge.append(base + Vector3.UP * up * p.y * shape.semi.y)
	var length := root[0].distance_to(root[8])
	return _fin(m, m, material, root, edge, Vector3.RIGHT, thick, maxf(length * 10.0 * rays_per_dm * 2.0, 3.0))


## The body's top (`up` 1) or bottom (-1) along its middle, `up` of the way
## out from its middle.
static func _middle(shape: Shape, along: float, up: float) -> Vector3:
	var slice := shape.slice(along)
	return Vector3(0.0, slice.z + slice.y * up, shape.z(along))


## Long sickle pectorals low behind the gills, on the swim animation's pivots.
static func _pectorals(m: FishModel, shape: Shape, fins: ShaderMaterial) -> void:
	var along := shape.at_body(0.2)
	var at := shape.point(along, -0.45)
	m._fin_pivots(Vector3(at.x * 0.9, at.y, at.z))
	var reach := shape.semi.y * 2.0
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		var out := Vector3(side * 0.85, -0.5, 0.0).normalized()
		var back := Vector3.BACK
		var root: Array[Vector3] = [back * -0.03, back * 0.035]
		var edge: Array[Vector3] = [back * -0.03, back * -0.01 + out * reach * 0.3, back * 0.04 + out * reach * 0.65,
				back * 0.15 + out * reach * 0.95, back * 0.28 + out * reach * 1.08, back * 0.15 + out * reach * 0.62,
				back * 0.07 + out * reach * 0.22, back * 0.035]
		_fin(m, pivot, fins, root, edge, out.cross(back).normalized(), 0.005, 9.0)


## The deeply forked crescent tail on the swim pivot at the stalk's end, its
## root sunk in the stalk.
static func _tail(m: FishModel, shape: Shape, fins: ShaderMaterial) -> void:
	var pivot_along := shape.head + 0.965 * (1.0 - shape.head)
	var at := _middle(shape, pivot_along, 0.0)
	m._tail_pivot(at)
	var stalk := shape.slice(pivot_along).y
	var span := shape.semi.y * 2.9
	var reach := shape.semi.y * 1.6
	var p := func(back: float, up: float) -> Vector3: return Vector3(0.0, up, back)
	var root: Array[Vector3] = [p.call(-0.035, stalk * 0.85), p.call(-0.02, 0.0), p.call(-0.035, -stalk * 0.85)]
	var edge: Array[Vector3] = [
		p.call(-0.035, stalk * 0.85), p.call(0.02, span * 0.18), p.call(reach * 0.45, span * 0.55),
		p.call(reach * 0.8, span * 0.85), p.call(reach, span), p.call(reach * 0.7, span * 0.62),
		p.call(reach * 0.42, span * 0.25), p.call(reach * 0.36, 0.0), p.call(reach * 0.42, -span * 0.25),
		p.call(reach * 0.7, -span * 0.62), p.call(reach, -span), p.call(reach * 0.8, -span * 0.85),
		p.call(reach * 0.45, -span * 0.55), p.call(0.02, -span * 0.18), p.call(-0.035, -stalk * 0.85),
	]
	_fin(m, m.tail, fins, root, edge, Vector3.RIGHT, 0.032, 22.0, 96)


## Big eyes set into the head just behind the bill.
static func _eyes(m: FishModel, look: Dictionary, shape: Shape) -> void:
	var disc: float = look.eye
	var radius := disc * 1.12
	var along := shape.at_body(0.065)
	for side: float in [-1.0, 1.0]:
		var surface := shape.point(along, 0.3)
		var normal := Vector3(1.0, 0.25, -0.35).normalized()
		var at := Vector3(side * (surface.x - radius * 0.6 * normal.x), surface.y - radius * 0.6 * normal.y, surface.z)
		var eye := m._real_eye(at, radius, Vector3(side * normal.x, normal.y, normal.z), look.iris, 0.5)
		var material := eye.material_override as ShaderMaterial
		material.set_shader_parameter("sheen", 0.65)
		material.set_shader_parameter("rim_color", (look.albedo as Color) * 0.25)


## A stiff fin on `parent`, its root along the polyline `root` and its edge
## through the points `edge` (smoothed; it starts at the root's first point and
## ends at its last), in the parent's space. Two sheets `thick` apart at the
## root, meeting at the edge, across `side`. `rays` fin rays along it.
static func _fin(m: FishModel, parent: Node3D, material: ShaderMaterial, root: Array, edge: Array, side: Vector3,
		thick: float, rays: float, columns := 64, rows := 8) -> MeshInstance3D:
	var roots := _resample(root, columns, false)
	var edges := _resample(edge, columns, true)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := side.normalized()
	for sheet: float in [1.0, -1.0]:
		for i in columns + 1:
			var u := float(i) / columns
			var taper := pow(sin(PI * clampf(u, 0.0, 1.0)), 0.35)
			for j in rows + 1:
				var v := float(j) / rows
				var at := roots[i].lerp(edges[i], v)
				tool.set_uv(Vector2(u * rays, v))
				tool.add_vertex(at + normal * sheet * thick * 0.5 * pow(1.0 - v, 1.4) * taper)
	var sheet_size := (columns + 1) * (rows + 1)
	for sheet in 2:
		for i in columns:
			for j in rows:
				var a := sheet * sheet_size + i * (rows + 1) + j
				var b := a + rows + 1
				var quad: Array = [a, b, a + 1, a + 1, b, b + 1] if sheet == 0 else [a, a + 1, b, a + 1, b + 1, b]
				for corner: int in quad:
					tool.add_index(corner)
	tool.generate_normals()
	var fin := MeshInstance3D.new()
	fin.name = "Fin"
	fin.mesh = tool.commit()
	fin.material_override = material
	parent.add_child(fin)
	return fin


## `points` as `count` + 1 points evenly spaced along it: a smooth curve
## through them (`smooth`), or straight lines between them.
static func _resample(points: Array, count: int, smooth: bool) -> Array[Vector3]:
	var dense: Array[Vector3] = []
	var n := points.size()
	for i in n - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var before: Vector3 = points[maxi(i - 1, 0)]
		var after: Vector3 = points[mini(i + 2, n - 1)]
		var steps := 12 if smooth else 1
		for s in steps:
			var t := float(s) / steps
			dense.append(a.cubic_interpolate(b, before, after, t) if smooth else a.lerp(b, t))
	dense.append(points[n - 1])
	var lengths: Array[float] = [0.0]
	for i in range(1, dense.size()):
		lengths.append(lengths[i - 1] + dense[i].distance_to(dense[i - 1]))
	var total: float = lengths[lengths.size() - 1]
	var out: Array[Vector3] = []
	var k := 1
	for i in count + 1:
		var want := total * i / count
		while k < dense.size() - 1 and lengths[k] < want:
			k += 1
		var span := maxf(lengths[k] - lengths[k - 1], 1e-6)
		out.append(dense[k - 1].lerp(dense[k], clampf((want - lengths[k - 1]) / span, 0.0, 1.0)))
	return out
