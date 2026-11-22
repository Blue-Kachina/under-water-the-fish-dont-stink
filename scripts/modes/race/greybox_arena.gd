class_name GreyboxArena
extends RaceArena
## Phase 1's placeholder course (GreyboxTrack): no terrain, rings for walls every few metres, a brighter ring on every
## checkpoint, glowing buoys on the racing line, and the soft walls RaceMatch leans racers back with. Real tracks
## (the Canyon Reef Circuit) replace this behind the same RaceArena / RaceTrack API.

const RING_SPACING := 9.0
const BUOY_SPACING := 14.0


func _init() -> void:
	soft_walls = true


func track_data() -> Dictionary:
	return GreyboxTrack.data()


func _build_world() -> void:
	var rings: Array[Transform3D] = []
	var d := 0.0
	while d < track.lap_length:
		rings.append(_ring(track.sample(d), 1.0))
		d += RING_SPACING
	_add_rings(rings, Color(0.25, 0.55, 0.62, 0.55), 0.06)
	var gates: Array[Transform3D] = []
	for cp: Dictionary in track.checkpoints:
		gates.append(_gate(cp, 1.0))
	_add_rings(gates, Color(1.0, 0.8, 0.25, 0.8), 0.1)
	var line: Array[Transform3D] = [_gate(track.checkpoints[0], 1.03), _gate(track.checkpoints[0], 0.97)]
	_add_rings(line, Color(1.0, 1.0, 1.0, 1.0), 0.14)
	var buoys: Array[Transform3D] = []
	d = 0.0
	while d < track.lap_length:
		buoys.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.6), track.racing_line(d)))
		d += BUOY_SPACING
	var buoy := SphereMesh.new()
	buoy.radius = 0.5
	buoy.height = 1.0
	buoy.radial_segments = 8
	buoy.rings = 4
	_add_multimesh(buoy, buoys, _glow(Color(1.0, 0.85, 0.3, 1.0)))


## A ring (an ellipse in the plane across the track) at a frame: the torus' axis along `forward`.
func _ring(fix: RaceTrack.Fix, scale_by: float) -> Transform3D:
	return _frame(fix.pos, fix.right, fix.up, fix.forward, fix.width, fix.height, scale_by)


func _gate(cp: Dictionary, scale_by: float) -> Transform3D:
	return _frame(cp["pos"], cp["right"], cp["up"], cp["forward"], float(cp["width"]), float(cp["height"]), scale_by)


func _frame(pos: Vector3, right: Vector3, up: Vector3, forward: Vector3, width: float, height: float, scale_by: float) -> Transform3D:
	# TorusMesh lies in XZ with its axis on Y: X -> right, Y -> forward (the axis), Z -> up.
	var basis := Basis(right * width * 0.5 * scale_by, forward, up * height * 0.5 * scale_by)
	return Transform3D(basis, pos)


func _add_rings(transforms: Array[Transform3D], color: Color, thickness: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0 - thickness
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	_add_multimesh(torus, transforms, _glow(color))


func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var view := MultiMeshInstance3D.new()
	view.multimesh = multimesh
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


static func _glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.albedo_color = Color(color.r * color.a, color.g * color.a, color.b * color.a, 1.0)
	return material
