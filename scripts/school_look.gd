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
## Baked the first time each kind is asked for, then kept. A kind is a class
## (FishCharacter.FishClass) or a zombie's own look's id (ZombieLooks: "sardine").
## A whale (FishModel.fluke) beats its tail up and down in its poses.

## The tail's swing (rad) in each pose.
const POSES := [0.0, 0.42, -0.42]
const CENTRE := 0
const RIGHT := 1
const LEFT := 2

## Class -> Array[Mesh], one per pose.
static var _baked := {}
## Class -> Array[ImporterMesh], one per pose: the bakes with their LODs.
static var _importers := {}
## "class:error" -> Array[Mesh], one per pose (detail_meshes()).
static var _detailed := {}


## The baked meshes for `fish_class` (a class, or a ZombieLooks id), one per pose in POSES.
static func meshes(fish_class: Variant) -> Array:
	if not _baked.has(fish_class):
		var baked := []
		for importer: ImporterMesh in _importers_for(fish_class):
			baked.append(importer.get_mesh())
		_baked[fish_class] = baked
	return _baked[fish_class]


## The baked meshes for `fish_class` at a fixed detail, one per pose: each part at
## its coarsest LOD whose error is within `error` (a share of the part's size;
## 0: full detail). For a MultiMesh spread over a whole arena (the Horde),
## where Godot's own LOD, picked by the MultiMesh's bounds, never steps down.
static func detail_meshes(fish_class: Variant, error: float) -> Array:
	if error <= 0.0:
		return meshes(fish_class)
	var key := "%s:%.4f" % [str(fish_class), error]
	if not _detailed.has(key):
		var built := []
		for importer: ImporterMesh in _importers_for(fish_class):
			built.append(_at_detail(importer, error))
		_detailed[key] = built
	return _detailed[key]


static func _importers_for(fish_class: Variant) -> Array:
	if not _importers.has(fish_class):
		var model: FishModel
		if fish_class is String:
			model = ZombieLooks.build(fish_class, FishCharacter.FishClass.SKIRMISHER)
		else:
			model = FishModel.build(fish_class)
		var baked := []
		for swing: float in POSES:
			if model.tail:
				if model.fluke:
					model.tail.rotation.x = swing
				else:
					model.tail.rotation.y = swing
				model.apply_bend()
			baked.append(_bake(model))
		model.free()
		_importers[fish_class] = baked
	return _importers[fish_class]


## `importer`'s mesh with each part at the fewest triangles within `error`,
## and parts that look the same (equal materials) merged into one surface, so
## a fish is a few draws rather than one per part.
static func _at_detail(importer: ImporterMesh, error: float) -> ArrayMesh:
	var merged := {}  # material key -> [arrays, material, primitive]
	var order: Array[String] = []
	for surface in importer.get_surface_count():
		var arrays := importer.get_surface_arrays(surface).duplicate(true)  # not the bake's own
		for lod in importer.get_surface_lod_count(surface):
			if importer.get_surface_lod_size(surface, lod) <= error:
				var indices := importer.get_surface_lod_indices(surface, lod)
				if indices.size() < (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size():
					arrays[Mesh.ARRAY_INDEX] = indices
		var material := importer.get_surface_material(surface)
		var key := "%d %s" % [importer.get_surface_primitive_type(surface), _material_key(material)]
		for slot in Mesh.ARRAY_MAX:
			key += "1" if arrays[slot] != null else "0"
		if importer.get_surface_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES or not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			key += " %d" % surface  # not mergeable
		if not merged.has(key):
			merged[key] = [arrays, material, importer.get_surface_primitive_type(surface)]
			order.append(key)
			continue
		var into: Array = merged[key][0]
		var offset := (into[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for n in indices.size():
			indices[n] += offset
		arrays[Mesh.ARRAY_INDEX] = indices
		for slot in Mesh.ARRAY_MAX:
			if into[slot] != null:
				into[slot].append_array(arrays[slot])
	var mesh := ArrayMesh.new()
	for key in order:
		var entry: Array = merged[key]
		mesh.add_surface_from_arrays(entry[2], entry[0])
		mesh.surface_set_material(mesh.get_surface_count() - 1, entry[1])
	return mesh


## Equal for materials that draw the same: the same one, or standard materials
## with the same settings.
static func _material_key(material: Material) -> String:
	if not material is BaseMaterial3D:
		return str(material.get_instance_id()) if material else "none"
	var parts := PackedStringArray()
	for property in material.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE:
			parts.append(str(material.get(property.name)))
	return "|".join(parts)


## Which pose shows a tail at `phase` (rad) in its beat: centre, right, centre, left.
static func pose_for(phase: float) -> int:
	var quarter := int(fposmod(phase, TAU) / (TAU / 4.0))
	return [CENTRE, RIGHT, CENTRE, LEFT][quarter]


## Every visible mesh part of `model`, merged into one mesh in the model's own
## space, with LODs. Parts that bend with its body are baked bent
## (FishModel.bend_transform), since a MultiMesh can't bend them per fish.
static func _bake(model: FishModel) -> ImporterMesh:
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
			var bent := model.is_bent(part)
			var bends: Array[Basis] = []
			for i in vertices.size():
				vertices[i] = to_model * vertices[i]
				if bent:
					var bend := model.bend_transform(vertices[i])
					vertices[i] = bend.origin
					bends.append(bend.basis)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in normals.size():
					normals[i] = (normal_basis * normals[i]).normalized()
					if bent:
						normals[i] = bends[i] * normals[i]
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
	return importer


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
