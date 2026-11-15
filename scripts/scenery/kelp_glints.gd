class_name KelpGlints
extends RefCounted
## Sparkles for a kelp mesh (planning_abyssal_look.md, phase 5): a second mesh with one quad per glint, each at a random point on the
## kelp's blades. It is scattered with the same transforms and custom data as the plant (Scatter tiles and culls it with the plant),
## and kelp_glint.gdshader sways each point as kelp_plant.gdshader sways the blade there.
## Quad vertex: position = the point (kelp mesh space), UV = the corner, COLOR = (random, random, 0, height fraction on the plant).

static var _cache := {}


## The glint mesh for `kelp` (null when there is nothing to glint: no mesh data or glints_per_plant 0).
static func mesh_for(kelp: Mesh) -> Mesh:
	var per_plant := WaterLook.shared().glints_per_plant
	if kelp == null or per_plant <= 0:
		return null
	var key := [kelp.get_instance_id(), per_plant]
	if _cache.has(key):
		return _cache[key]
	var made := _build(kelp, per_plant)
	_cache[key] = made
	return made


static func _build(kelp: Mesh, count: int) -> Mesh:
	if kelp.get_surface_count() == 0:
		return null
	var arrays := kelp.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors = arrays[Mesh.ARRAY_COLOR]
	if verts.is_empty() or colors == null or (colors as PackedColorArray).is_empty():
		return null
	var cols: PackedColorArray = colors
	var dice := RandomNumberGenerator.new()
	dice.seed = kelp.get_instance_id() ^ 0x6c17
	var pos := PackedVector3Array()
	var uvs := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var made := 0
	var tries := 0
	while made < count and tries < count * 20:
		tries += 1
		var i := dice.randi() % verts.size()
		if cols[i].a < 0.12:
			continue  # keep off the bare foot of the stipe
		var seed_a := dice.randf()
		var seed_b := dice.randf()
		var base := pos.size()
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			pos.append(verts[i])
			uvs.append(corner)
			col.append(Color(seed_a, seed_b, 0.0, cols[i].a))
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		made += 1
	if made == 0:
		return null
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = pos
	out[Mesh.ARRAY_TEX_UV] = uvs
	out[Mesh.ARRAY_COLOR] = col
	out[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	mesh.surface_set_material(0, WaterLook.get_glint_material())
	# The shader moves the quads, so the bounds just have to be generous around the plant.
	mesh.custom_aabb = kelp.get_aabb().grow(1.5)
	return mesh
