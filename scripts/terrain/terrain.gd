class_name Terrain
extends Node3D
## The procedural seabed's rock (planning_procedural_world.md): a TerrainField generated from the stage's seed and a
## TerrainLayout, meshed into chunks (one MeshInstance3D and one trimesh collision shape each, culled by the murk).
##
## The ground query API lives here too, as statics that every system calls instead of reading `arena_floor`: with no
## terrain built (or terrain off) they answer for the flat floor, so callers are safe either way. Positions are global.
##   floor_y(x, z, flat)   the ground's height under (x, z): the terrain's lowest floor or the flat floor, whichever is higher
##   sdf(p)                distance from p to rock (m, negative inside; huge with no terrain)
##   normal(p)             the way out of the rock nearest p
##   headroom(x, z)        open water above the floor at (x, z) (m)
##   is_open(p, r)         p is in reachable water with r m of room round it
##   push(p, r)            how far to move p so it sits r m clear of rock (zero when it already is)
##   line_clear(a, b, r)   a ball of radius r can travel from a to b without touching rock

## The terrain the queries answer for (the last one built and still in the tree).
static var active: Terrain

var field: TerrainField
var layout: TerrainLayout
## The rock's chunks.
var chunks: Array[MeshInstance3D] = []
var body: StaticBody3D
## Timings and counts from the last build (ms, triangles), for benches and PROGRESS.md.
var stats := {}
var material: ShaderMaterial
var _built_data: Array = []
var _settings: UnnaturalSettings


## Builds the terrain for `seed_value` (blocking): generate, mesh, then the nodes. `height` is the depth band's height.
func build(settings: UnnaturalSettings, seed_value: int, radius: float, height: float) -> void:
	prepare(settings, seed_value, radius, height)
	apply(settings)


## The heavy half (thread-safe: touches no nodes): generates the field and meshes every chunk.
func prepare(settings: UnnaturalSettings, seed_value: int, radius: float, height: float) -> void:
	var t0 := Time.get_ticks_usec()
	layout = TerrainLayout.roll(settings, seed_value, radius, height)
	field = TerrainField.new()
	field.configure(layout.params)
	stats = field.generate()
	var t1 := Time.get_ticks_usec()
	_built_data.clear()
	var grid := field.chunk_grid()
	for cz in grid.z:
		for cx in grid.x:
			var data := field.build_chunk(cx, cz)
			if not data.is_empty():
				_built_data.append(data)
	stats["ms_mesh"] = (Time.get_ticks_usec() - t1) / 1000.0
	stats["ms_prepare"] = (Time.get_ticks_usec() - t0) / 1000.0


## The node half (main thread): the chunk meshes and the collision.
func apply(settings: UnnaturalSettings) -> void:
	var t0 := Time.get_ticks_usec()
	for child in get_children():
		child.queue_free()
	chunks.clear()
	if material == null:
		material = ShaderMaterial.new()
		material.shader = preload("res://shaders/terrain_rock.gdshader")
	_settings = settings
	_push_look()
	body = null
	if settings.terrain_collision:
		body = StaticBody3D.new()
		body.name = "RockBody"
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
	var triangles := 0
	for data: Dictionary in _built_data:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
		arrays[Mesh.ARRAY_NORMAL] = data["normals"]
		arrays[Mesh.ARRAY_COLOR] = data["colors"]
		arrays[Mesh.ARRAY_INDEX] = data["indices"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		var chunk := MeshInstance3D.new()
		chunk.name = "Chunk%d" % chunks.size()
		chunk.mesh = mesh
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chunk)
		chunks.append(chunk)
		triangles += (data["indices"] as PackedInt32Array).size() / 3
		if body:
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(data["faces"])
			var collision := CollisionShape3D.new()
			collision.shape = shape
			body.add_child(collision)
	_built_data.clear()
	stats["triangles"] = triangles
	stats["chunks"] = chunks.size()
	stats["ms_apply"] = (Time.get_ticks_usec() - t0) / 1000.0
	active = self
	if is_inside_tree():
		var t1 := Time.get_ticks_usec()
		stats.merge(TerrainLight.bake(self, settings), true)
		stats["ms_light"] = (Time.get_ticks_usec() - t1) / 1000.0


func _exit_tree() -> void:
	if active == self:
		active = null
	TerrainLight.clear(self)


func _process(_delta: float) -> void:
	_push_look()


## The rock material's live values (the panel's), and the light's strengths while this terrain owns the bake.
func _push_look() -> void:
	if _settings == null or material == null:
		return
	var s := _settings
	material.set_shader_parameter("ao_strength", s.terrain_ao)
	material.set_shader_parameter("crust_amount", s.terrain_crust)
	material.set_shader_parameter("crust_glow", s.terrain_crust_glow)
	material.set_shader_parameter("sand_blend", s.terrain_sand_blend)
	material.set_shader_parameter("zone_tint", s.terrain_zone_tint)
	material.set_shader_parameter("brightness", s.terrain_rock_bright)
	material.set_shader_parameter("base_y", global_position.y if is_inside_tree() else 0.0)
	var zones := PackedVector4Array()
	zones.resize(4)
	if layout:
		var base := global_position if is_inside_tree() else Vector3.ZERO
		for i in mini(layout.grottoes.size(), 4):
			var g := layout.grottoes[i]
			zones[i] = Vector4(base.x + g.x, base.z + g.y, g.z, 1.0)
	material.set_shader_parameter("zones", zones)
	if TerrainLight.owner() == self:
		TerrainLight.push(s)


## Chunks aren't drawn beyond `reach` m (0: always drawn).
func set_draw_distance(reach: float) -> void:
	var margin := 0.0
	if layout:
		margin = float(layout.params["cell"]) * float(layout.params["chunk_cells"]) * 0.75
	for chunk in chunks:
		chunk.visibility_range_end = reach + margin if reach > 0.0 else 0.0


# --- Local-space queries (this node's space) ---------------------------------------------------------------

func local_floor(x: float, z: float) -> float:
	return field.floor_y(x, z) if field else -INF


# --- The ground query API (global positions) -------------------------------------------------------------

static func _live() -> Terrain:
	if active != null and is_instance_valid(active) and active.is_inside_tree() and active.field != null:
		return active
	return null


static func floor_y(x: float, z: float, flat: float) -> float:
	var t := _live()
	if t == null:
		return flat
	var local := t.to_local(Vector3(x, 0.0, z))
	return maxf(flat, t.to_global(Vector3(local.x, t.field.floor_y(local.x, local.z), local.z)).y)


static func sdf(p: Vector3) -> float:
	var t := _live()
	return t.field.sdf(t.to_local(p)) if t else 1e4


static func normal(p: Vector3) -> Vector3:
	var t := _live()
	return t.global_basis * t.field.gradient(t.to_local(p)) if t else Vector3.UP


static func headroom(x: float, z: float) -> float:
	var t := _live()
	if t == null:
		return 1e4
	var local := t.to_local(Vector3(x, 0.0, z))
	return t.field.headroom(local.x, local.z)


static func is_open(p: Vector3, radius: float) -> bool:
	var t := _live()
	if t == null:
		return true
	var local := t.to_local(p)
	return t.field.sdf(local) >= radius and t.field.is_reachable(local)


static func push(p: Vector3, radius: float) -> Vector3:
	var t := _live()
	if t == null:
		return Vector3.ZERO
	var local := t.to_local(p)
	var d := t.field.sdf(local)
	if d >= radius:
		return Vector3.ZERO
	return t.global_basis * t.field.gradient(local) * (radius - d)


static func line_clear(a: Vector3, b: Vector3, radius: float) -> bool:
	var t := _live()
	return t.field.segment_clear(t.to_local(a), t.to_local(b), radius) if t else true
