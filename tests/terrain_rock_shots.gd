extends Node
## Not a probe: close-ups for the terrain's rock material and its light (planning_procedural_world.md, phases 3 and 5).
## Starts the Look Tank with terrain on and renders to logs/terrain_shots/<label>/r<n>_<name>.png with GPU times:
##   1 wall       6 m from the biggest mesa's face, looking at it
##   2 cavity     inside the grotto's cavity, looking out of the mouth
##   3 mouth      just outside the grotto's mouth, looking in
##   4 overhang   under a mesa's lip, looking up along the wall
##   5 shafts     from the open middle toward the grotto (shafts against rock)
## Needs a window.
##   Godot_console.exe --path . res://tests/terrain_rock_shots.tscn -- --label=NAME [--seed=N] [--views=1,2] [--set=name=value]

const OUT_BASE := "res://logs/terrain_shots"
const NAMES: Array[String] = ["wall", "cavity", "mouth", "overhang", "shafts"]

var label := "rock"
var frames := 20
var views: Array[int] = [1, 2, 3, 4, 5]
var tank: LookTank


func _ready() -> void:
	var settings := UnnaturalSettings.shared()
	settings.terrain_enabled = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
		elif arg.begins_with("--views="):
			views.clear()
			for part in arg.trim_prefix("--views=").split(","):
				views.append(part.to_int())
		elif arg.begins_with("--seed="):
			UnnaturalRun.seabed_seed_override = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--set="):
			var kv := arg.trim_prefix("--set=").split("=")
			var current: Variant = settings.get(kv[0])
			if current is bool:
				settings.set(kv[0], kv[1] == "1" or kv[1] == "true")
			elif current is int:
				settings.set(kv[0], kv[1].to_int())
			else:
				settings.set(kv[0], kv[1].to_float())
	get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	tank = load("res://scenes/look_tank.tscn").instantiate()
	add_child(tank)
	_run.call_deferred()


func _run() -> void:
	var out_dir := ProjectSettings.globalize_path(OUT_BASE).path_join(label)
	DirAccess.make_dir_recursive_absolute(out_dir)
	while not tank.is_ready():
		await get_tree().process_frame
	var seabed: Seabed = tank.run.seabed
	var terrain := seabed.terrain
	if terrain == null:
		push_error("terrain_rock_shots: no terrain")
		get_tree().quit(1)
		return
	tank.go(1)
	var lines := PackedStringArray(["terrain_rock_shots %s  stats %s" % [label, terrain.stats]])
	for n in views:
		var pose := _pose(n, seabed, terrain)
		tank.camera.global_position = pose[0]
		tank.camera.look_at(pose[1], Vector3.UP)
		tank.camera.current = true
		for i in 25:
			await RenderingServer.frame_post_draw
		var rid := get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(rid, true)
		var gpu := 0.0
		for i in frames:
			await RenderingServer.frame_post_draw
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		RenderingServer.viewport_set_measure_render_time(rid, false)
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("r%d_%s.png" % [n, NAMES[n - 1]]))
		var line := "view r%d %-9s gpu %.2f ms" % [n, NAMES[n - 1], gpu / frames]
		print(line)
		lines.append(line)
	var file := FileAccess.open(out_dir.path_join("gpu_rock.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("terrain_rock_shots: saved to %s" % out_dir)
	get_tree().quit()


## [from, to] (global) for view `n`.
func _pose(n: int, seabed: Seabed, terrain: Terrain) -> Array:
	var base := seabed.global_position
	var lay := terrain.layout
	var f := terrain.field
	var best := Vector4.ZERO
	for m in lay.mesas:
		if m.z > best.z:
			best = m
	var cav := PackedFloat32Array(lay.params["cavities"])
	match n:
		1, 4:
			# March from the middle toward the biggest mesa until the rock is 6 m (or 2 m) away.
			var dir := Vector2(best.x, best.y).normalized()
			var y := 4.0 if n == 1 else 2.0
			var keep := 6.0 if n == 1 else 2.5
			var at := Vector3.ZERO
			for step in 400:
				at = Vector3(dir.x, 0.0, dir.y) * step * 0.5 + Vector3.UP * y
				var ahead := at + Vector3(dir.x, 0.0, dir.y) * keep
				if f.sdf(at) < keep and f.floor_y(ahead.x, ahead.z) > y * 0.5:  # rock rising ahead, not just the floor below
					break
			if n == 1:
				return [base + at, base + at + Vector3(dir.x, 0.15, dir.y) * 10.0]
			return [base + at, base + at + Vector3(dir.x * 3.0, 8.0, dir.y * 3.0)]
		2, 3:
			if cav.size() < 6:
				return [base + Vector3(0, 6, 0), base + Vector3(30, 6, 0)]
			var c := Vector3(cav[0], cav[1], cav[2])
			var out := -Vector2(c.x, c.z).normalized()
			if n == 2:
				var from := c - Vector3(out.x, 0.0, out.y) * cav[3] * 0.3
				return [base + from, base + from + Vector3(out.x, 0.1, out.y) * 20.0]
			var from := c + Vector3(out.x, 0.0, out.y) * cav[3] * 1.6
			return [base + from, base + c]
		_:
			if lay.grottoes.is_empty():
				return [base + Vector3(0, 4, 0), base + Vector3(60, 10, 0)]
			var g := lay.grottoes[0]
			var to := Vector3(g.x, 8.0, g.y)
			var from := to * 0.45 + Vector3.UP * 2.0
			return [base + from, base + to]
