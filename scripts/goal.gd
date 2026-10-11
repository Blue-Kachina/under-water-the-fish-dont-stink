class_name Goal
extends Node3D
## A recessed net behind an opening in an arena wall. The origin is the centre
## of the goal mouth on the wall; local +Z points out of the arena, into the net.
## Like Rocket League, a goal counts once the whole ball is past the goal line.
##
## As in RL, the inside is curved: the floor ramps up into the back wall and the
## back wall curves over onto the roof, which slopes back up to the crossbar,
## so a ball rolls up and back out, and a car (fish) can drive floor -> back ->
## roof for a "squishy" save. The sides are flat and meet the back round a
## vertical curve.

const NET_SHADER := preload("res://shaders/net.gdshader")
const POST_RADIUS := 0.3
const CURVE_STEPS := 8  # segments per curved edge
const CORNER_STEPS := 6  # segments per rounded side-to-back corner

@export var team := 0
@export var color := Color(1.0, 0.5, 0.1)
## Mouth size and depth; defaults are Rocket League's goal, measured from its
## collision mesh (1792 x 640 uu mouth, 880 deep).
@export var width := 17.92
@export var height := 6.40
@export var depth := 8.8
## Height of the net at the back: RL's roof slopes down from the crossbar to here.
@export var back_height := 5.12
## Radius of the curve from the net floor up into the back wall.
@export var floor_radius := 2.56
## Radius of the curve from the back wall over onto the net roof.
@export var roof_radius := 2.56
## Radius of the vertical curves where the side walls meet the back wall.
@export var corner_radius := 2.56
## Off for a goal standing on the floor, so the ball can roll straight in.
@export var bottom_post := true
## Off: the net gets no collider of its own and the arena merges `net_faces`
## into its own collision mesh, so nothing catches on the seam at the goal
## line (two separate meshes make a rolling ball hop there).
@export var own_collision := true
## The net's collision triangles in the goal's local space, set in _ready.
var net_faces := PackedVector3Array()


func _ready() -> void:
	assert(floor_radius + roof_radius <= back_height and back_height <= height and maxf(floor_radius, roof_radius) + corner_radius <= depth
			and corner_radius <= width / 2.0, "goal curves don't fit inside the net")
	var net := ShaderMaterial.new()
	net.shader = NET_SHADER
	net.set_shader_parameter("net_color", color)
	_build_net(net)

	var half_w := width / 2.0
	var half_h := height / 2.0

	var frame := StandardMaterial3D.new()
	frame.albedo_color = color
	frame.emission_enabled = true
	frame.emission = color
	frame.emission_energy_multiplier = 1.2
	# Rounded posts just outside the mouth (so it stays width x height) so the
	# ball glances off the frame.
	_add_post(Vector3(half_w + POST_RADIUS, 0, 0), Vector3.UP, height, frame)
	_add_post(Vector3(-half_w - POST_RADIUS, 0, 0), Vector3.UP, height, frame)
	_add_post(Vector3(0, half_h + POST_RADIUS, 0), Vector3.RIGHT, width + POST_RADIUS * 2.0, frame)
	if bottom_post:
		_add_post(Vector3(0, -half_h - POST_RADIUS, 0), Vector3.RIGHT, width + POST_RADIUS * 2.0, frame)

	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 2.0
	glow.omni_range = maxf(width, height)
	glow.position = Vector3(0, 0, depth * 0.6)
	add_child(glow)


## True once a ball of `radius` centred at `world_position` is wholly past the goal line.
func contains_ball(world_position: Vector3, radius: float) -> bool:
	var local := to_local(world_position)
	return local.z > radius and absf(local.x) < width / 2.0 and absf(local.y) < height / 2.0


## The net as one mesh and one matching trimesh collider, built in horizontal
## slices: at each height of the side-on profile (floor curve, back wall, roof
## curve) the net is a U of two side walls joined to the back wall round the
## corner curves. Flat fans close the floor, the roof and the two side walls.
func _build_net(material: Material) -> void:
	var tris := [[], []]  # vertices, normals
	var half_w := width / 2.0
	var half_h := height / 2.0
	var r := corner_radius
	var profile := _net_profile()
	var rings: Array[Array] = []  # per profile entry: [points, normals], from the -x side round to the +x side
	for entry in profile:
		var points: Array[Vector3] = []
		var normals: Array[Vector3] = []
		var tangent := Vector3(0.0, -entry.w, entry.z)  # along the profile
		for side: float in [-1.0, 1.0]:
			for k in CORNER_STEPS + 1:
				var step := CORNER_STEPS - k if side < 0.0 else k  # walk -x side -> back -> +x side
				var angle := PI / 2.0 * step / CORNER_STEPS  # 0 facing the back wall, PI/2 the side wall
				points.append(Vector3(side * (half_w - r + r * sin(angle)), entry.x, entry.y - r + r * cos(angle)))
				# Roughly the inward normal: the profile's, turned round the corner.
				var inward := Vector3(side * sin(angle) * entry.w, entry.z, cos(angle) * entry.w).normalized()
				var exact := Vector3(side * cos(angle), 0.0, -sin(angle)).cross(tangent)
				if exact.length_squared() < 1e-8:
					normals.append(inward)  # where the corner pinches to nothing at the floor or roof
				else:
					normals.append(exact.normalized() * signf(exact.dot(inward)))
		rings.append([points, normals])

	for i in rings.size() - 1:
		var lo: Array = rings[i]
		var hi: Array = rings[i + 1]
		for j in lo[0].size() - 1:
			var corners := [lo[0][j], lo[0][j + 1], hi[0][j + 1], hi[0][j]]
			var normals := [lo[1][j], lo[1][j + 1], hi[1][j + 1], hi[1][j]]
			_append_triangle(tris, [corners[0], corners[1], corners[2]], [normals[0], normals[1], normals[2]])
			_append_triangle(tris, [corners[0], corners[2], corners[3]], [normals[0], normals[2], normals[3]])

	# Floor and roof: fans from the middle of the mouth to the bottom and top slices.
	for end: Array in [[rings[0][0], -half_h, Vector3.UP], [rings[-1][0], half_h, Vector3.DOWN]]:
		var edge: Array = [Vector3(-half_w, end[1], 0.0)] + end[0] + [Vector3(half_w, end[1], 0.0)]
		for j in edge.size() - 1:
			_add_flat_triangle(tris, Vector3(0.0, end[1], 0.0), edge[j], edge[j + 1], end[2])
	# Side walls: fans from the middle of each side of the mouth to the slices' ends.
	for side: float in [-1.0, 1.0]:
		var x := side * half_w
		var edge: Array = [Vector3(x, -half_h, 0.0)]
		for ring in rings:
			edge.append(ring[0][0] if side < 0.0 else ring[0][-1])
		edge.append(Vector3(x, half_h, 0.0))
		for j in edge.size() - 1:
			_add_flat_triangle(tris, Vector3(x, 0.0, 0.0), edge[j], edge[j + 1], Vector3(-side, 0.0, 0.0))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(tris[0])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(tris[1])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	net_faces = PackedVector3Array(tris[0])
	var body := StaticBody3D.new()
	body.name = "Net"
	if own_collision:
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(net_faces)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)
	add_child(body)


## The net's side-on profile from where the floor starts to curve, up the back
## wall and over to where the roof flattens out, as Vector4(y, z, inward
## normal's y and z).
func _net_profile() -> Array[Vector4]:
	var half_h := height / 2.0
	var profile: Array[Vector4] = []
	# Floor curving up into the back wall: centre at (floor + r, back - r).
	var r := floor_radius
	for k in CURVE_STEPS + 1:
		var angle := PI / 2.0 * k / CURVE_STEPS  # 0 on the floor, PI/2 on the back wall
		profile.append(Vector4(-half_h + r - r * cos(angle), depth - r + r * sin(angle), cos(angle), -sin(angle)))
	# Back wall curving over onto the roof: centre at (back top - r, back - r).
	# From there the roof slopes up to the crossbar (the roof fan), as RL's.
	r = roof_radius
	var back_top := -half_h + back_height
	for k in CURVE_STEPS + 1:
		var angle := PI / 2.0 * k / CURVE_STEPS  # 0 on the back wall, PI/2 on the roof
		profile.append(Vector4(back_top - r + r * sin(angle), depth - r + r * cos(angle), -sin(angle), -cos(angle)))
	return profile


## Adds one flat triangle facing `normal`.
func _add_flat_triangle(target: Array, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	_append_triangle(target, [a, b, c], [normal, normal, normal])


func _append_triangle(target: Array, points: Array, normals: Array) -> void:
	var cross: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
	if cross.length_squared() < 1e-10:
		return  # degenerate, e.g. a curve of radius 0
	# Godot treats clockwise triangles as front faces.
	var facing: Vector3 = normals[0] + normals[1] + normals[2]
	if cross.dot(facing) > 0.0:
		points.reverse()
		normals.reverse()
	for i in 3:
		target[0].append(points[i])
		target[1].append(normals[i])


func _add_post(pos: Vector3, axis: Vector3, length: float, material: Material) -> void:
	var body := StaticBody3D.new()
	# CylinderShape3D runs along Y; turn it onto `axis`.
	var post_basis := Basis.IDENTITY if axis == Vector3.UP else Basis(Vector3.BACK, PI / 2.0)
	body.transform = Transform3D(post_basis, pos)
	var shape := CylinderShape3D.new()
	shape.radius = POST_RADIUS
	shape.height = length + POST_RADIUS * 2.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh := CylinderMesh.new()
	mesh.top_radius = POST_RADIUS
	mesh.bottom_radius = POST_RADIUS
	mesh.height = shape.height
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)
	add_child(body)
