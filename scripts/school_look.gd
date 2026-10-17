class_name SchoolLook
## How school fish (School) look from further than arm's length: each kind of
## fish's model (FishModel) baked into a single mesh, its parts merged in their
## rest places, with automatic LODs. Drawn through a MultiMesh, so a whole
## school costs a handful of draw calls rather than a model per fish.
##
## There's one mesh per tail pose (POSES: centre, swung right, swung left). A
## school shows each fish in the pose for where its tail is in its beat, a
## flipbook wag (pose_for()).
##
## Baked the first time each kind is asked for, then kept.

## The tail's swing (rad) in each pose.
const POSES := [0.0, 0.42, -0.42]
const CENTRE := 0
const RIGHT := 1
const LEFT := 2

## Family -> Array[Mesh], one per pose.
static var _baked := {}


## The baked meshes for `family`, one per pose in POSES.
static func meshes(family: FishCharacter.Family) -> Array:
	if not _baked.has(family):
		var model := FishModel.build(family)
		var baked := []
		for swing: float in POSES:
			if model.tail:
				model.tail.rotation.y = swing
			baked.append(_bake(model))
		model.free()
		_baked[family] = baked
	return _baked[family]


## Which pose shows a tail at `phase` (rad) in its beat: centre, right, centre, left.
static func pose_for(phase: float) -> int:
	var quarter := int(fposmod(phase, TAU) / (TAU / 4.0))
	return [CENTRE, RIGHT, CENTRE, LEFT][quarter]


## Every visible mesh part of `model`, merged into one mesh in the model's own
## space, with LODs.
static func _bake(model: FishModel) -> Mesh:
	var importer := ImporterMesh.new()
	var indexed := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or not _shown(part, model):
			continue
		var to_model := _transform_in(part, model)
		var normal_basis := to_model.basis.inverse().transposed()
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				vertices[i] = to_model * vertices[i]
			arrays[Mesh.ARRAY_VERTEX] = vertices
			if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in normals.size():
					normals[i] = (normal_basis * normals[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = normals
			if arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
				var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
				for i in tangents.size() / 4:
					var t := (to_model.basis * Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])).normalized()
					tangents[i * 4] = t.x
					tangents[i * 4 + 1] = t.y
					tangents[i * 4 + 2] = t.z
				arrays[Mesh.ARRAY_TANGENT] = tangents
			if not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array or (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
				indexed = false
			var primitive := (part.mesh as ArrayMesh).surface_get_primitive_type(surface) if part.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
			importer.add_surface(primitive, arrays, [], {},
					part.get_active_material(surface), "%s_%d" % [part.name, surface])
	if indexed:
		importer.generate_lods(25.0, 60.0, [])
	return importer.get_mesh()


## Whether `part` and everything above it up to `model` is visible.
static func _shown(part: Node3D, model: Node3D) -> bool:
	var node: Node = part
	while node != model and node != null:
		if node is Node3D and not (node as Node3D).visible:
			return false
		node = node.get_parent()
	return true


## `part`'s transform in `model`'s space (it needn't be in the tree).
static func _transform_in(part: Node3D, model: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var node: Node = part
	while node != model and node != null:
		if node is Node3D:
			transform = (node as Node3D).transform * transform
		node = node.get_parent()
	return transform
