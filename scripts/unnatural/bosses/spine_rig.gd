class_name SpineRig
extends RefCounted
## A final boss's spine (spine_bend.gdshaderinc): SPINE_N points spaced evenly
## along its body's `length`, from the head back along the way it came (or
## along a chain of points: a hagfish's rope), each with a frame (right, up;
## tailward is their cross). It feeds every material in `materials` and keeps
## every node in `instances` drawn (their bounds round the points, `reach` m
## out), and places riders (eyes, lampreys) and proxies with frame_at().

const SPINE_N := 48

var length := 60.0
## How far the body reaches out from its spine (m), for the bounds.
var reach := 6.0
var points := PackedVector3Array()
var rights := PackedVector3Array()
var ups := PackedVector3Array()
var materials: Array[ShaderMaterial] = []
## A roll round its length (rad), the whole body turning with it (the Lamprey
## Queen corkscrewing on her prey).
var twist := 0.0
var instances: Array[GeometryInstance3D] = []


func _init(body_length := 60.0, body_reach := 6.0) -> void:
	length = body_length
	reach = body_reach
	points.resize(SPINE_N)
	rights.resize(SPINE_N)
	ups.resize(SPINE_N)
	rights.fill(Vector3.RIGHT)
	ups.fill(Vector3.UP)


## The spine along a path: `head` now, back along `trail` (oldest first, newest
## last), carried on straight along `back` (tailward) past the trail's end.
func follow_trail(head: Vector3, trail: PackedVector3Array, back: Vector3) -> void:
	var step := length / float(SPINE_N - 1)
	var index := trail.size() - 1
	var from := head
	var walked := 0.0
	var tail_dir := back.normalized() if back.length_squared() > 0.0001 else Vector3.BACK
	points[0] = head
	for s in range(1, SPINE_N):
		var want := s * step
		var placed := false
		while index >= 0:
			var to := trail[index]
			var gap := from.distance_to(to)
			if walked + gap >= want and gap > 0.0001:
				points[s] = from.lerp(to, (want - walked) / gap)
				placed = true
				break
			walked += gap
			from = to
			index -= 1
		if not placed:
			var last := points[s - 1]
			var dir := (last - points[s - 2]).normalized() if s >= 2 and last.distance_squared_to(points[s - 2]) > 0.0001 else tail_dir
			points[s] = last + dir * step
	_frames()


## The spine along a chain of `nodes` (head first), through a smooth curve
## (Catmull-Rom) resampled evenly by length.
func follow_chain(chain: PackedVector3Array) -> void:
	var nodes := PackedVector3Array()
	var n_in := chain.size()
	for c in n_in - 1:
		var p0 := chain[maxi(c - 1, 0)]
		var p1 := chain[c]
		var p2 := chain[c + 1]
		var p3 := chain[mini(c + 2, n_in - 1)]
		for j in 4:
			nodes.append(p1.cubic_interpolate(p2, p0, p3, j / 4.0))
	if n_in > 0:
		nodes.append(chain[n_in - 1])
	var step := length / float(SPINE_N - 1)
	var k := 1
	var walked := 0.0
	points[0] = nodes[0]
	for s in range(1, SPINE_N):
		var want := s * step
		while k < nodes.size() - 1 and walked + nodes[k].distance_to(nodes[k - 1]) < want:
			walked += nodes[k].distance_to(nodes[k - 1])
			k += 1
		var a := nodes[k - 1]
		var b := nodes[mini(k, nodes.size() - 1)]
		var gap := a.distance_to(b)
		points[s] = a.lerp(b, clampf((want - walked) / maxf(gap, 0.0001), 0.0, 1.5))
	_frames()


## Each point's frame, tailward along the spine. The head's up is as near the
## world's up as it can be; every frame after it carries the one before along
## (a rotation-minimising frame), so the body never twists, even where it
## runs straight up or down (a hagfish rising out of its hole).
func _frames() -> void:
	var last_up := Vector3.UP
	for s in SPINE_N:
		var ahead := points[maxi(s - 1, 0)]
		var behind := points[mini(s + 1, SPINE_N - 1)]
		var back := behind - ahead
		if back.length_squared() < 0.000001:
			back = Vector3.BACK
		back = back.normalized()
		var guess := last_up
		if s == 0:
			guess = Vector3.UP if absf(back.y) < 0.95 else Vector3.FORWARD
		guess = guess - back * guess.dot(back)
		if guess.length_squared() < 0.0001:
			guess = Vector3.FORWARD - back * back.z
		var right := guess.normalized().cross(back).normalized()
		var up := back.cross(right).normalized()
		last_up = up
		if twist != 0.0:
			right = right.rotated(back, twist)
			up = up.rotated(back, twist)
		rights[s] = right
		ups[s] = up


## The frame `d` m back from the head: its basis's x right, y up, z tailward.
func frame_at(d: float) -> Transform3D:
	var t := clampf(d / maxf(length, 0.001), 0.0, 1.0) * (SPINE_N - 1)
	var i := mini(int(t), SPINE_N - 2)
	var f := t - i
	var right := rights[i].lerp(rights[i + 1], f).normalized()
	var up := ups[i].lerp(ups[i + 1], f).normalized()
	var back := right.cross(up).normalized()
	up = back.cross(right)
	return Transform3D(Basis(right, up, back), points[i].lerp(points[i + 1], f))


## A rest-space point (x right, y up, z back from the head) where it is now.
func place(rest: Vector3) -> Vector3:
	var frame := frame_at(rest.z)
	return frame.origin + frame.basis.x * rest.x + frame.basis.y * rest.y


## The uniforms to every material, and every node's bounds round the spine.
func apply() -> void:
	for material in materials:
		material.set_shader_parameter("spine_pos", points)
		material.set_shader_parameter("spine_right", rights)
		material.set_shader_parameter("spine_up", ups)
		material.set_shader_parameter("spine_length", length)
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	box = box.grow(reach)
	for node in instances:
		if is_instance_valid(node):
			node.custom_aabb = box


## A node for a mesh bent by this spine: at the origin, unrotated (the shader
## writes world positions), never culled off its spine.
func add_mesh(parent: Node, mesh: Mesh, material: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.top_level = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(node)
	node.global_transform = Transform3D.IDENTITY
	if material not in materials:
		materials.append(material)
	instances.append(node)
	return node
