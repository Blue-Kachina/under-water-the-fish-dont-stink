class_name HunterJaw
extends RefCounted
## The Drowned Shark's jaw rig (the mini-boss wears it too: DrownedShark). The lower jaw is the
## body's own underside under the mouth, lifted off it as a piece: while the jaw is open the
## skin shader (shark_skin.gdshader, jaw_cut) cuts that patch out of the body and a copy of it
## (jaw_part 1: the same skin, painted from the resting shape so nothing slides; 2: its inside,
## raw flesh) swings down on a hinge at the mouth's corners, with the lower teeth riding it.
## The upper jaw (gum and teeth) pushes forward and down out from under the snout, a roof and a
## dark throat fill the hole, and lit cheeks of flesh stretch between the lips at the corners.
## Built into the model's own space, so it scales and moves with the model.
## pose(open) opens it (0 shut to 1 gaping); the Bite's `open` drives it, and set_overshoot()
## swings it past wide for the stylised snap (a cartoon jaw dropping further than it should).

## How far the jaw drops open (rad), and how far the upper jaw pushes forward then (of the mouth's length).
const GAPE := 1.0
const PROTRUDE := 0.3
const FLESH := Color(0.42, 0.07, 0.08)
const TOOTH := Color(0.88, 0.85, 0.7)
## The grid the lower jaw's skin is lofted on: across the mouth, and back from its lip.
const COLS := 28
const ROWS := 7

var mouth := {}
## Past-wide (and past-shut: negative) on top of the pose, in jaws' worth.
var overshoot := 0.0
var _lower: Node3D
var _upper: Node3D
var _inside: MeshInstance3D
var _cheeks: MeshInstance3D
var _cheek_mesh := ImmediateMesh.new()
var _skins: Array[ShaderMaterial] = []  # the body's, then the jaw's two
var _hinge := Vector3.ZERO
var _lip: Array[Vector3] = []  # the mouth's lip, across it, in the model's space
var _shown := -999.0
var _shown_over := 0.0


## The jaw on `model` (a shark's: SharkModel.mouth_geometry), its skin `skin_color`.
func build(model: FishModel, _skin_color: Color) -> void:
	mouth = SharkModel.mouth_geometry(model)
	var front: Vector3 = mouth.front
	var back: Vector3 = mouth.back
	var width: float = mouth.width
	var length: float = mouth.length
	_hinge = Vector3(0.0, back.y, back.z)
	var depth := back.z - front.z  # how far the corners sit behind the front of the lip
	var jaw_end := back.z + length * 0.012  # the footprint ends at the hinge line
	var thick := length * 0.012
	# The lip: where the body's mouth line runs (the skin shader's curve), on its underside.
	_lip.clear()
	for c in COLS + 1:
		var u := lerpf(-1.0, 1.0, c / float(COLS))
		_lip.append(_lip_point(model, u, width, front.z, depth))
	var body: ShaderMaterial = model._skins[0]
	body.set_shader_parameter("jaw_end", jaw_end)
	var outer := body.duplicate() as ShaderMaterial
	outer.set_shader_parameter("jaw_part", 1.0)
	outer.set_shader_parameter("jaw_hinge", Vector2(_hinge.y, _hinge.z))
	var inner := outer.duplicate() as ShaderMaterial
	inner.set_shader_parameter("jaw_part", 2.0)
	inner.set_shader_parameter("jaw_flesh", FLESH)
	_skins.append_array([body, outer, inner])
	model._skins.append(outer)  # tinted, bent and flashed with the body
	model._skins.append(inner)
	# The lower jaw: the underside's patch under the lip, its skin and its inside.
	_lower = Node3D.new()
	_lower.name = "Jaw"
	_lower.position = _hinge
	model.add_child(_lower)
	var skin_mesh := SurfaceTool.new()
	var flesh_mesh := SurfaceTool.new()
	skin_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	flesh_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outside: Array = []  # [column][row] of {"pos", "uv", "uv2"}
	for c in COLS + 1:
		var u := lerpf(-1.0, 1.0, c / float(COLS))
		var column: Array = []
		var lip_z := front.z + depth * u * u
		for r in ROWS + 1:
			column.append(SharkModel.underside(model, u * width, lerpf(lip_z, jaw_end, r / float(ROWS))))
		outside.append(column)
	for c in COLS:
		for r in ROWS:
			var a: Dictionary = outside[c][r]
			var b: Dictionary = outside[c + 1][r]
			var d: Dictionary = outside[c][r + 1]
			var e: Dictionary = outside[c + 1][r + 1]
			# The skin faces down and out, the inside up into the mouth (a lifted by `thick`).
			for corner: Dictionary in [b, a, d, b, d, e]:
				_vertex(skin_mesh, corner, 0.0)
			for corner: Dictionary in [b, d, a, b, e, d]:
				_vertex(flesh_mesh, corner, thick)
	# The lip's thickness (front) and the jaw's two sides, closed with flesh, seen from both ways.
	for c in COLS:
		_band(flesh_mesh, outside[c][0], outside[c + 1][0], thick)
	for r in ROWS:
		_band(flesh_mesh, outside[0][r], outside[0][r + 1], thick)
		_band(flesh_mesh, outside[COLS][r], outside[COLS][r + 1], thick)
	skin_mesh.generate_normals()
	flesh_mesh.generate_normals()
	for pair: Array in [[skin_mesh, outer], [flesh_mesh, inner]]:
		var node := MeshInstance3D.new()
		node.mesh = (pair[0] as SurfaceTool).commit()
		node.material_override = pair[1]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = -_hinge  # the mesh is in the model's space: the pivot is the hinge
		_lower.add_child(node)
	var tooth := StandardMaterial3D.new()
	tooth.albedo_color = TOOTH
	tooth.roughness = 0.25
	tooth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gum := StandardMaterial3D.new()
	gum.albedo_color = FLESH.lightened(0.05)
	gum.roughness = 0.3
	gum.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Lower teeth ride the jaw (small, ragged, pointing up); upper ones hang from the gum.
	var low_teeth := _teeth(_lip, length, Vector3.UP, 0.019, 0.011, 0.8, rng, _hinge)
	var low := MeshInstance3D.new()
	low.mesh = low_teeth
	low.material_override = tooth
	low.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lower.add_child(low)
	_upper = Node3D.new()
	_upper.name = "UpperTeeth"
	model.add_child(_upper)
	var high := MeshInstance3D.new()
	high.mesh = _teeth(_lip, length, Vector3.DOWN, 0.027, 0.013, 1.0, rng, Vector3.ZERO)
	high.material_override = tooth
	high.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_upper.add_child(high)
	var band := MeshInstance3D.new()
	band.mesh = _gum_band(length * 0.024)
	band.material_override = gum
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_upper.add_child(band)
	# The roof of the mouth and the dark throat, fixed in the head.
	_inside = MeshInstance3D.new()
	_inside.mesh = _inside_mesh(model, width, front.z, depth, jaw_end, length)
	var lining := StandardMaterial3D.new()
	lining.vertex_color_use_as_albedo = true
	lining.roughness = 0.3
	lining.cull_mode = BaseMaterial3D.CULL_DISABLED
	_inside.material_override = lining
	_inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(_inside)
	_cheeks = MeshInstance3D.new()
	_cheeks.mesh = _cheek_mesh
	var cheek := StandardMaterial3D.new()
	cheek.albedo_color = FLESH.darkened(0.1)
	cheek.roughness = 0.4
	cheek.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cheeks.material_override = cheek
	_cheeks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(_cheeks)
	pose(0.0)


## Where the mouth is, in the model's space: a little in front of the jaws.
func mouth_local() -> Vector3:
	var front: Vector3 = mouth.front
	return front + Vector3(0.0, -0.03, -0.05) * float(mouth.length)


## Swings the jaw `extra` past wide (negative: crushed past shut) on top of the pose; takes
## effect on the next pose().
func set_overshoot(extra: float) -> void:
	overshoot = extra


## The jaw as open as `jaw` says (0 shut to 1 gaping), plus the overshoot.
func pose(jaw: float) -> void:
	if _lower == null or (is_equal_approx(jaw, _shown) and is_equal_approx(overshoot, _shown_over)):
		return
	_shown = jaw
	_shown_over = overshoot
	var open := smoothstep(0.0, 1.0, jaw)
	var swing := open + overshoot * (1.0 if open > 0.03 else 0.0)
	var angle := -GAPE * swing
	var cut := open > 0.03
	_skins[0].set_shader_parameter("jaw_cut", 1.0 if cut else 0.0)
	_skins[1].set_shader_parameter("jaw_angle", angle)
	_skins[2].set_shader_parameter("jaw_angle", angle)
	_lower.rotation.x = angle
	_lower.visible = cut
	var length: float = mouth.length
	var reach := Vector3(0.0, length * 0.03, length * PROTRUDE * 0.08)
	_upper.position = Vector3(0.0, -reach.y, -reach.z) * open
	_upper.visible = cut
	_inside.visible = cut
	_cheek_mesh.clear_surfaces()
	_cheeks.visible = cut
	if not cut:
		return
	# The cheeks: a web of flesh between the upper lip (pushed out) and the dropped jaw's lip, each side.
	var rows := 3
	_cheek_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var from_c := int(COLS * 0.5 * (1.0 + side))
		for c in 5:
			var i0 := from_c - int(side) * c
			var i1 := from_c - int(side) * (c + 1)
			if i0 < 0 or i0 > COLS or i1 < 0 or i1 > COLS:
				continue
			var top0 := _lip[i0] + _upper.position
			var top1 := _lip[i1] + _upper.position
			var low0 := _hinge + (_lip[i0] - _hinge).rotated(Vector3.RIGHT, angle)
			var low1 := _hinge + (_lip[i1] - _hinge).rotated(Vector3.RIGHT, angle)
			for r in rows:
				var t0 := r / float(rows)
				var t1 := (r + 1) / float(rows)
				# A web sags inward a little.
				var sag0 := -side * length * 0.03 * sin(t0 * PI)
				var sag1 := -side * length * 0.03 * sin(t1 * PI)
				var p00 := top0.lerp(low0, t0) + Vector3(sag0, 0.0, 0.0)
				var p10 := top1.lerp(low1, t0) + Vector3(sag0, 0.0, 0.0)
				var p01 := top0.lerp(low0, t1) + Vector3(sag1, 0.0, 0.0)
				var p11 := top1.lerp(low1, t1) + Vector3(sag1, 0.0, 0.0)
				for corner: Vector3 in [p00, p10, p01, p10, p11, p01]:
					_cheek_mesh.surface_add_vertex(corner)
	_cheek_mesh.surface_end()


## The mouth line's point `u` (-1 to 1) across the mouth: the skin shader's curve, on the underside.
static func _lip_point(model: FishModel, u: float, width: float, front_z: float, depth: float) -> Vector3:
	var z := front_z + depth * u * u
	return (SharkModel.underside(model, u * width, z) as Dictionary).pos


func _vertex(tool: SurfaceTool, point: Dictionary, lift: float) -> void:
	tool.set_uv(point.uv)
	tool.set_uv2(point.uv2)
	tool.add_vertex((point.pos as Vector3) + Vector3(0.0, lift, 0.0))


## A strip joining the skin's edge from `a` to `b` to its inside (`thick` above), flesh, both faces.
func _band(tool: SurfaceTool, a: Dictionary, b: Dictionary, thick: float) -> void:
	var lift := Vector3(0.0, thick, 0.0)
	var corners := [a, b, a, b, b, a]
	var offsets := [Vector3.ZERO, Vector3.ZERO, lift, Vector3.ZERO, lift, lift]
	for pass_back in 2:
		for n in 6:
			var m := n if pass_back == 0 else 5 - n
			var point: Dictionary = corners[m]
			tool.set_uv(point.uv)
			tool.set_uv2(point.uv2)
			tool.add_vertex((point.pos as Vector3) + (offsets[m] as Vector3))


## A row of tooth blades along `lip` (relative to `origin`) pointing along `dir`: each a flat
## pyramid, wide along the lip, ragged and a few missing (`wear`: how worn the row is, 1 least).
func _teeth(lip: Array[Vector3], length: float, dir: Vector3, tall: float, wide: float, wear: float,
		rng: RandomNumberGenerator, origin: Vector3) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 17
	for n in count:
		var u := lerpf(-0.9, 0.9, n / float(count - 1))
		if rng.randf() > 0.9 * wear + 0.1:
			continue  # a tooth gone
		var at := lip[int(round((u * 0.5 + 0.5) * COLS))] - origin
		var tangent := Vector3(1.0, 0.0, 2.0 * float(mouth.back.z - mouth.front.z) * u / float(mouth.width)).normalized()
		var depth_axis := dir.cross(tangent).normalized()
		var ragged := lerpf(0.55, 1.1, rng.randf()) * lerpf(1.1, 0.75, absf(u))
		var h := length * tall * ragged
		var w := length * wide * 0.5 * lerpf(1.0, 0.8, absf(u))
		var d := w * 0.5
		var lean := depth_axis * (h * 0.18 * (-1.0 if dir.y > 0.0 else 1.0)) + tangent * h * rng.randf_range(-0.12, 0.12)
		var base := at - dir * h * 0.15  # rooted a little in the gum
		var c0 := base - tangent * w - depth_axis * d
		var c1 := base + tangent * w - depth_axis * d
		var c2 := base + tangent * w + depth_axis * d
		var c3 := base - tangent * w + depth_axis * d
		var apex := base + dir * h + lean
		for tri: Array in [[c0, c1, apex], [c1, c2, apex], [c2, c3, apex], [c3, c0, apex]]:
			for corner: Vector3 in tri:
				tool.add_vertex(corner)
	tool.generate_normals()
	return tool.commit()


## The upper jaw's gum: a thin band along the lip, `drop` m deep, tucked behind the teeth.
func _gum_band(drop: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in COLS:
		var a := _lip[c]
		var b := _lip[c + 1]
		var a2 := a + Vector3(0.0, drop, 0.0)
		var b2 := b + Vector3(0.0, drop, 0.0)
		for corner: Vector3 in [a, b, a2, b, b2, a2]:
			tool.add_vertex(corner)
	tool.generate_normals()
	return tool.commit()


## The mouth's roof (an arch lifted into the head) and the throat's dark curtain behind it, vertex
## coloured from raw flesh at the lip to near black at the back.
func _inside_mesh(model: FishModel, width: float, front_z: float, depth: float, jaw_end: float, length: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rise := length * 0.04
	var grid: Array = []
	for c in COLS + 1:
		var u := lerpf(-1.0, 1.0, c / float(COLS))
		var column: Array = []
		for r in ROWS + 1:
			var t := r / float(ROWS)
			var z := lerpf(front_z + depth * u * u, jaw_end, t)
			var at: Vector3 = (SharkModel.underside(model, u * width * 0.97, z) as Dictionary).pos
			var arch := pow(maxf(1.0 - u * u, 0.0), 0.5) * smoothstep(0.0, 0.5, t)
			at.y += length * 0.004 + rise * arch
			column.append([at, FLESH.darkened(clampf(t * 0.9, 0.0, 0.9))])
		grid.append(column)
	for c in COLS:
		for r in ROWS:
			for corner: Array in [grid[c][r], grid[c + 1][r], grid[c][r + 1], grid[c + 1][r], grid[c + 1][r + 1], grid[c][r + 1]]:
				tool.set_color(corner[1])
				tool.add_vertex(corner[0])
	# The curtain: from the roof's back edge down to the underside.
	for c in COLS:
		var top0: Vector3 = grid[c][ROWS][0]
		var top1: Vector3 = grid[c + 1][ROWS][0]
		var low0 := top0 - Vector3(0.0, rise * 1.2, 0.0)
		var low1 := top1 - Vector3(0.0, rise * 1.2, 0.0)
		for corner: Vector3 in [top0, top1, low0, top1, low1, low0]:
			tool.set_color(Color(0.03, 0.005, 0.005))
			tool.add_vertex(corner)
	tool.generate_normals()
	return tool.commit()
