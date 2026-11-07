class_name HunterJaw
extends RefCounted
## The Drowned Shark's jaw rig (DrownedShark._build_jaw, taken out so a player's
## Hunter wears it too): the lower jaw hinged at the mouth's corners under the
## head, the upper teeth and palate it bares, cheeks of flesh stretched between.
## Built into the model's own space, so it scales and moves with the model.
## pose(open) opens it (0 shut to 1 gaping); the Bite's `open` drives it.

## How far the jaw drops open (rad), and how far the upper jaw pushes forward then (of the mouth's length).
const GAPE := 0.95
const PROTRUDE := 0.25
const FLESH := Color(0.42, 0.07, 0.08)
const TOOTH := Color(0.86, 0.83, 0.72)

var mouth := {}
var _hinge: Node3D
var _upper: Node3D
var _palate: MeshInstance3D
var _cheeks: MeshInstance3D
var _cheek_mesh := ImmediateMesh.new()
var _flesh := StandardMaterial3D.new()
var _shown := -1.0


## The jaw on `model` (a shark's: SharkModel.mouth_geometry), its skin `skin_color`.
func build(model: FishModel, skin_color: Color) -> void:
	mouth = SharkModel.mouth_geometry(model)
	var front: Vector3 = mouth.front
	var back: Vector3 = mouth.back
	var width: float = mouth.width
	var length: float = mouth.length
	_flesh.albedo_color = FLESH
	_flesh.roughness = 0.35
	_flesh.cull_mode = BaseMaterial3D.CULL_DISABLED
	var skin := StandardMaterial3D.new()
	skin.albedo_color = skin_color.darkened(0.15)
	skin.roughness = 0.6
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tooth := StandardMaterial3D.new()
	tooth.albedo_color = TOOTH
	tooth.roughness = 0.25
	_hinge = Node3D.new()
	_hinge.name = "Jaw"
	_hinge.position = Vector3(0.0, back.y, back.z)
	model.add_child(_hinge)
	var thick := length * 0.012
	var floor_top := DrownedShark._plate(front - back, width, 0.0, true)
	var under := DrownedShark._plate(front - back, width, -thick, false)
	for pair: Array in [[floor_top, _flesh], [under, skin]]:
		var node := MeshInstance3D.new()
		node.mesh = pair[0]
		node.material_override = pair[1]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hinge.add_child(node)
	_upper = Node3D.new()
	_upper.name = "UpperTeeth"
	_upper.position = _hinge.position
	model.add_child(_upper)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = length * 0.006
	spike.height = length * 0.022
	spike.radial_segments = 4
	spike.rings = 1
	spike.material = tooth
	var count := 15
	for n in count:
		var u := lerpf(-0.88, 0.88, n / float(count - 1))
		var at := DrownedShark._rim(front - back, width, u)
		var low := MeshInstance3D.new()
		low.mesh = spike
		low.position = at * Vector3(0.94, 1.0, 0.94) + Vector3(0.0, spike.height * 0.45, 0.0)
		low.rotation.z = -u * 0.25
		_hinge.add_child(low)
		var high := MeshInstance3D.new()
		high.mesh = spike
		high.position = at * Vector3(0.96, 1.0, 0.96) + Vector3(0.0, -spike.height * 0.4, 0.0)
		high.rotation = Vector3(PI, 0.0, u * 0.25)
		high.scale = Vector3.ONE * lerpf(1.15, 0.8, absf(u))
		_upper.add_child(high)
	_palate = MeshInstance3D.new()
	_palate.mesh = DrownedShark._plate(front - back, width * 0.97, -length * 0.002, false)
	_palate.material_override = _flesh
	_palate.position = _hinge.position
	_palate.visible = false
	model.add_child(_palate)
	_cheeks = MeshInstance3D.new()
	_cheeks.mesh = _cheek_mesh
	var cheek := StandardMaterial3D.new()
	cheek.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cheek.albedo_color = FLESH.darkened(0.45)
	cheek.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cheeks.material_override = cheek
	_cheeks.position = _hinge.position
	_cheeks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(_cheeks)
	pose(0.0)


## Where the mouth is, in the model's space: a little in front of the jaws.
func mouth_local() -> Vector3:
	var front: Vector3 = mouth.front
	return front + Vector3(0.0, -0.03, -0.05) * float(mouth.length)


## The jaw as open as `jaw` says (0 shut to 1 gaping).
func pose(jaw: float) -> void:
	if _hinge == null or is_equal_approx(jaw, _shown):
		return
	_shown = jaw
	var open := smoothstep(0.0, 1.0, jaw)
	var angle := -GAPE * open
	_hinge.rotation.x = angle
	var front: Vector3 = mouth.front
	var back: Vector3 = mouth.back
	var reach := front - back
	_upper.position = Vector3(0.0, back.y, back.z) + Vector3(0.0, reach.z * 0.1, reach.z * PROTRUDE) * open
	_upper.scale = Vector3(1.0, maxf(open, 0.02), 1.0)
	_upper.visible = open > 0.03
	for node in _hinge.get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is CylinderMesh:
			(node as Node3D).scale = Vector3(1.0, maxf(open, 0.02), 1.0)
	_palate.visible = open > 0.03
	_cheek_mesh.clear_surfaces()
	if open <= 0.03:
		return
	var width: float = mouth.width
	_cheek_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 5
	for side: float in [-1.0, 1.0]:
		var cols := 6
		for c in cols:
			var u0 := side * lerpf(1.0, 0.45, c / float(cols))
			var u1 := side * lerpf(1.0, 0.45, (c + 1) / float(cols))
			for r in rows:
				var a0 := angle * r / float(rows)
				var a1 := angle * (r + 1) / float(rows)
				var p00 := DrownedShark._rim(reach, width, u0).rotated(Vector3.RIGHT, a0)
				var p01 := DrownedShark._rim(reach, width, u0).rotated(Vector3.RIGHT, a1)
				var p10 := DrownedShark._rim(reach, width, u1).rotated(Vector3.RIGHT, a0)
				var p11 := DrownedShark._rim(reach, width, u1).rotated(Vector3.RIGHT, a1)
				for corner: Vector3 in [p00, p10, p01, p10, p11, p01]:
					_cheek_mesh.surface_add_vertex(corner)
	_cheek_mesh.surface_end()
