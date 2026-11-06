extends Node
## Not a probe: screenshots of Marco Polo's arenas (planning_marco_polo.md §12)
## for checking by eye: an overview from above (murk off), a high three-quarter
## view, the seeker's start, swimming-height views from the hiding spots, every
## porthole from in front and from inside, and the furniture up close. Prints
## each arena's counts (portholes, spawns, triangles, bodies, build time) too;
## with --headless it only prints those. ("arena_shots" is the match tank's.)
##   Godot_console.exe --path . res://tests/marco_arena_shots.tscn -- --out=DIR [--arena=temple,tank] [--what=over,start,spots,portholes,close] [--clear]

const ARENAS := {"temple": "res://scripts/marco_polo/temple_arena.gd", "tank": "res://scripts/marco_polo/fish_tank_arena.gd"}

var out_dir := "user://marco_arena_shots"
var arenas := ["temple", "tank"]
var what := ["over", "start", "spots", "portholes", "close"]
var clear := false
var headless := false
var camera := Camera3D.new()
var env := Environment.new()
var arena: MarcoArena


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--arena="):
			arenas = Array(arg.trim_prefix("--arena=").split(","))
		elif arg.begins_with("--what="):
			what = Array(arg.trim_prefix("--what=").split(","))
		elif arg == "--clear":
			clear = true
	headless = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(out_dir)
	if not headless:
		get_window().size = Vector2i(1600, 900)
	# The water as main.tscn sets it up; the arena changes it.
	env.background_mode = Environment.BG_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.5, 0.0)
	sun.light_color = Color(0.75, 0.95, 1.0)
	sun.shadow_enabled = true
	add_child(sun)
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	_run.call_deferred()


func _run() -> void:
	for key: String in arenas:
		if not ARENAS.has(key) or not ResourceLoader.exists(ARENAS[key]):
			print("no arena ", key)
			continue
		var t0 := Time.get_ticks_msec()
		arena = (load(ARENAS[key]) as GDScript).new()
		add_child(arena)
		arena.configure_environment(env)
		print("%s: built in %d ms, %d portholes, %d hider spawns, %d outlines, %d curtains, sight %.1f m, ~%d triangles, %d bodies"
				% [key, Time.get_ticks_msec() - t0, arena.portholes().size(), arena.hider_spawns().size(), arena.map_outlines().size(),
				arena.curtains().size(), arena.sight_range(), _triangles(), arena.find_children("*", "StaticBody3D", true, false).size()])
		var start := arena.seeker_start().origin
		for p in arena.portholes():
			print("  porthole %s at %s axis %s, %.1f m from the seeker start" % [p.name, p.mouth().snapped(Vector3.ONE * 0.1),
					p.axis().snapped(Vector3.ONE * 0.01), p.mouth().distance_to(start)])
		if not headless:
			await _frames(30)
			if "over" in what:
				await _overview(key)
			if "start" in what:
				await _shot_at(key + "_start", arena.seeker_start())
			if "spots" in what:
				var n := 0
				for spawn in arena.hider_spawns():
					await _shot_at("%s_spot%d" % [key, n], spawn)
					n += 1
			if "portholes" in what:
				var n := 0
				for p in arena.portholes():
					var front := p.mouth() + p.axis() * 6.0 + Vector3.UP * 1.0
					await _look(front, p.mouth(), "%s_porthole%d_front" % [key, n])
					camera.global_transform = p.camera_transform(1.2)
					await _shot("%s_porthole%d_inside" % [key, n])
					n += 1
			if "close" in what:
				await _close_ups(key)
		arena.queue_free()
		await _frames(2)
	get_tree().quit()


func _overview(key: String) -> void:
	var density := env.fog_density
	env.fog_enabled = false
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(arena.size.x, arena.size.z) * 1.1
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	# Under the roof (the temple's beams would hide it all).
	camera.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0.0, arena.size.y - 1.5, 0.0))
	camera.near = 0.05
	await _shot(key + "_over_top")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 70.0
	var corner := Vector3(arena.size.x * 0.45, arena.size.y * 0.85, arena.size.z * 0.45)
	await _look(corner, Vector3(0.0, 2.0, 0.0), key + "_over_three_quarter")
	await _look(Vector3(-corner.x, corner.y, -corner.z), Vector3(0.0, 2.0, 0.0), key + "_over_three_quarter_b")
	env.fog_enabled = not clear
	env.fog_density = density
	await _look(corner, Vector3(0.0, 2.0, 0.0), key + "_murk_three_quarter")


func _close_ups(key: String) -> void:
	var spots := []
	if key == "temple":
		spots = [[Vector3(0.0, 6.0, -8.0), Vector3(0.0, 6.0, -23.0), "front"], [Vector3(14.0, 4.0, 10.0), Vector3(0.0, 3.0, 0.0), "tholos"],
				[Vector3(8.0, 3.0, -9.0), Vector3(2.0, 1.5, -14.0), "altar"], [Vector3(32.0, 3.0, -10.0), Vector3(41.0, 1.0, -12.0), "amphorae"],
				[Vector3(-18.0, 4.0, 22.0), Vector3(-34.0, 2.0, 27.0), "steps"], [Vector3(0.0, 4.0, -18.0), Vector3(0.0, 3.0, -32.0), "cella"],
				[Vector3(0.0, 2.0, 0.0), Vector3(0.0, 25.0, -10.0), "roof"]]
	else:
		spots = [[Vector3(10.0, 10.0, 8.0), Vector3(-18.0, 6.0, -6.0), "castle"], [Vector3(-2.0, 8.0, 10.0), Vector3(18.0, 3.0, -4.0), "ship"],
				[Vector3(0.0, 5.0, 12.0), Vector3(0.0, 2.0, 0.0), "middle"], [Vector3(10.0, 12.0, 0.0), Vector3(10.0, 12.0, -20.0), "back_panel"],
				[Vector3(0.0, 10.0, -5.0), Vector3(0.0, 10.0, 25.0), "glass"], [Vector3(-30.0, 4.0, 12.0), Vector3(-34.0, 2.0, 2.0), "corner"]]
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	for spot: Array in spots:
		await _look(spot[0], spot[1], "%s_close_%s" % [key, spot[2]])


## A swimming-height view from `xform`, the way it faces, and turned round.
func _shot_at(shot_name: String, xform: Transform3D) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 70.0
	camera.global_transform = Transform3D(xform.basis, xform.origin + Vector3.UP * 0.8 - xform.basis.z * -2.5)
	await _shot(shot_name)
	camera.global_transform = Transform3D(xform.basis.rotated(Vector3.UP, PI), xform.origin + Vector3.UP * 0.8)
	await _shot(shot_name + "_back")


func _look(from: Vector3, at: Vector3, shot_name: String) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 70.0
	camera.global_transform = Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
	await _shot(shot_name)


func _shot(shot_name: String) -> void:
	await _frames(6)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % shot_name))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _triangles() -> int:
	var total := 0
	for node in arena.find_children("*", "MeshInstance3D", true, false):
		total += _mesh_triangles((node as MeshInstance3D).mesh)
	for node in arena.find_children("*", "MultiMeshInstance3D", true, false):
		var multimesh := (node as MultiMeshInstance3D).multimesh
		total += multimesh.instance_count * _mesh_triangles(multimesh.mesh)
	return total


func _mesh_triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		total += indices.size() / 3 if indices.size() > 0 else verts.size() / 3
	return total
