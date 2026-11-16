extends Node
## Not a probe: the Terrain Tank view (planning_procedural_world.md, phase 0). Starts the Look Tank with terrain on, then
## renders fixed terrain viewpoints to logs/terrain_shots/<label>/<n>_<name>.png with their GPU time (gpu.txt):
##   1 map        straight down over the whole arena (murk off, high up)
##   2 grotto     from the middle toward the grotto's mouth, at mouth height
##   3 inside     inside the grotto, looking out
##   4 canyon     floor level toward the biggest mesa
##   5 arch       through the first arch
##   6 edge       the edge ring from inside, low
##   7 fly        a wide oblique over the outer band
##   8 whale      the whale fall set piece   9 hull   the sunken hull   10 vents   the vent field
## Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/terrain_shots.tscn -- --label=NAME [--seed=N] [--views=1,2] [--moon] [--frames=30]
## --set=name=value sets any UnnaturalSettings value first (repeatable).

const OUT_BASE := "res://logs/terrain_shots"
const NAMES: Array[String] = ["map", "grotto", "inside", "canyon", "arch", "edge", "fly", "whale", "hull", "vents"]

var label := "shots"
var frames := 30
var views: Array[int] = [1, 2, 3, 4, 5, 6, 7]
var tank: LookTank


func _ready() -> void:
	var settings := UnnaturalSettings.shared()
	settings.terrain_enabled = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
		elif arg.begins_with("--frames="):
			frames = maxi(arg.trim_prefix("--frames=").to_int(), 1)
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
		elif arg == "--moon":
			WaterLook.shared().tank_blood_moon = 1.0
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
		push_error("terrain_shots: no terrain was built")
		get_tree().quit(1)
		return
	var lines := PackedStringArray()
	lines.append("terrain_shots %s  stats %s" % [label, terrain.stats])
	print(lines[0])
	tank.go(1)  # freezes the fish and takes the camera
	for n in views:
		var pose := _pose(n, seabed, terrain)
		var murk := UnnaturalSettings.shared().murk_density
		if n == 1 or n == 7:
			tank.run.settings.murk_density = 0.0
		tank.camera.global_position = pose[0]
		if n == 1:
			tank.camera.look_at(pose[1], Vector3.FORWARD)
		else:
			tank.camera.look_at(pose[1], Vector3.UP)
		tank.camera.far = 1500.0
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
		var file_name := "%d_%s.png" % [n, NAMES[n - 1]]
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(file_name))
		var line := "view %d %-8s gpu %.2f ms  draw calls %.0f" % [n, NAMES[n - 1], gpu / frames,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
		print(line)
		lines.append(line)
		tank.run.settings.murk_density = murk
	var file := FileAccess.open(out_dir.path_join("gpu.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("terrain_shots: saved to %s" % out_dir)
	get_tree().quit()


## [from, to] (global) for view `n`.
func _pose(n: int, seabed: Seabed, terrain: Terrain) -> Array:
	var base := seabed.global_position
	var lay := terrain.layout
	var r := seabed.radius
	var h := seabed.edge_height
	match n:
		1:
			return [base + Vector3(0.0, r * 2.6, 0.01), base]
		2, 3:
			if lay.grottoes.is_empty():
				return [base + Vector3(0, 6, 0), base + Vector3(r, 6, 0)]
			var g := lay.grottoes[0]
			var mouth := Vector2(g.x, g.y)
			var inward := -mouth.normalized()
			var y := g.w * 0.45
			if n == 2:
				var from := mouth + inward * (g.z * 1.2)
				return [base + Vector3(from.x, y + 2.0, from.y), base + Vector3(mouth.x, y, mouth.y)]
			var inside := mouth + inward * (g.z * 0.12)
			var out := mouth + inward * (g.z * 2.0)
			return [base + Vector3(inside.x, y, inside.y), base + Vector3(out.x, y + 3.0, out.y)]
		4:
			var best := Vector4.ZERO
			for m in lay.mesas:
				if m.z > best.z:
					best = m
			var at := Vector2(best.x, best.y)
			var from := at - at.normalized() * (best.z + 30.0)
			return [base + Vector3(from.x, 2.0, from.y), base + Vector3(at.x, h * 0.35, at.y)]
		5:
			if lay.arches.is_empty():
				return [base + Vector3(0, 6, 0), base + Vector3(-r, 6, 0)]
			var a := lay.arches[0]
			var at := Vector2(a.x, a.y)
			var side := at.normalized().orthogonal()
			var from := at + side * (a.z * 2.5) - at.normalized() * a.z
			return [base + Vector3(from.x, a.z * 0.45, from.y), base + Vector3(at.x, a.z * 0.4, at.y)]
		6:
			return [base + Vector3(0.0, 3.0, r * 0.55), base + Vector3(0.0, h * 0.4, r * 1.1)]
		8, 9, 10:
			var want: int = [SetPieces.Kind.WHALE_FALL, SetPieces.Kind.HULL, SetPieces.Kind.VENTS][n - 8]
			for piece: Dictionary in lay.pieces:
				if piece["kind"] == want:
					var at: Vector2 = piece["at"]
					var from := at - at.normalized() * 22.0 + at.normalized().orthogonal() * 8.0
					return [base + Vector3(from.x, 7.0, from.y), base + Vector3(at.x, 1.5, at.y)]
			return [base + Vector3(0, 6, 0), base + Vector3(r, 6, 0)]
		_:
			return [base + Vector3(-r * 0.2, h * 1.6, -r * 0.2), base + Vector3(r * 0.7, 0.0, r * 0.5)]
