extends Node
## Not a probe: renders the Look Tank's six viewpoints (LookTank) to
## logs/look_shots/<label>/<n>_<name>.png and measures each one's GPU time, so
## every phase of planning_abyssal_look.md can be compared side by side. Writes
## gpu.txt next to the shots (and prints it). Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/look_shots.tscn -- --label=baseline [--frames=90] [--views=1,2,3] [--sunlit] [--moon]
## --label names the folder (default "shots"); --frames is how many frames each
## GPU reading averages (default 90); --views picks viewpoints (default all);
## --sunlit switches WaterLook to its Sunlit preset first; --moon puts Unnatural's Blood Moon on
## (WaterLook.tank_blood_moon 1; the default is the plain ocean).
## --set=name=value sets any WaterLook setting first (repeatable), e.g. --set=transparent_fog=0.

const OUT_BASE := "res://logs/look_shots"

var label := "shots"
var frames := 90
var views: Array[int] = [1, 2, 3, 4, 5, 6]
var sunlit := false
var sets := {}
var tank: LookTank


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
		elif arg.begins_with("--frames="):
			frames = maxi(arg.trim_prefix("--frames=").to_int(), 1)
		elif arg.begins_with("--views="):
			views.clear()
			for part in arg.trim_prefix("--views=").split(","):
				views.append(part.to_int())
		elif arg.begins_with("--set="):  # --set=name=value: any WaterLook setting, e.g. --set=transparent_fog=0
			var kv := arg.trim_prefix("--set=").split("=")
			sets[kv[0]] = kv[1].to_float()
		elif arg == "--nomsaa":
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		elif arg == "--sunlit":
			sunlit = true
		elif arg == "--moon":
			WaterLook.shared().tank_blood_moon = 1.0
	get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for key in sets:
		WaterLook.shared().set(key, sets[key])
	if sunlit:
		WaterLook.shared().preset = WaterLook.Preset.SUNLIT
	tank = load("res://scenes/look_tank.tscn").instantiate()
	add_child(tank)
	_run.call_deferred()


func _run() -> void:
	var out_dir := ProjectSettings.globalize_path(OUT_BASE).path_join(label)
	DirAccess.make_dir_recursive_absolute(out_dir)
	while not tank.is_ready():
		await get_tree().process_frame
	var look := WaterLook.shared()
	var lines := PackedStringArray()
	lines.append("look_shots %s  window %s  %d frames per reading  preset %s" % [label, get_window().size,
			frames, WaterLook.Preset.keys()[look.preset]])
	for n in views:
		tank.go(n)
		for i in look.tank_settle_frames + 5:
			await RenderingServer.frame_post_draw
		var rids := _viewports(n)
		for rid in rids:
			RenderingServer.viewport_set_measure_render_time(rid, true)
		for i in 5:
			await RenderingServer.frame_post_draw
		var gpu := 0.0
		var cpu := 0.0
		for i in frames:
			await RenderingServer.frame_post_draw
			for rid in rids:
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		var file_name := "%d_%s.png" % [n, LookTank.NAMES[n - 1]]
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(file_name))
		var line := "view %d %-12s gpu %.2f ms  cpu %.2f ms  (%d viewport%s)  draw calls %.0f" % [n, LookTank.NAMES[n - 1], gpu / frames, cpu / frames,
				rids.size(), "" if rids.size() == 1 else "s", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
		print(line)
		lines.append(line)
		for rid in rids:
			RenderingServer.viewport_set_measure_render_time(rid, false)
	var file := FileAccess.open(out_dir.path_join("gpu.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("look_shots: saved to %s" % out_dir)
	get_tree().quit()


## The viewports whose GPU time makes up view `n`: the window's, or each split-screen view's.
func _viewports(n: int) -> Array[RID]:
	var rids: Array[RID] = []
	var split: SplitScreen = tank.main.get_node_or_null("SplitScreen")
	if n == LookTank.COUNT and split:
		for v in split.count():
			rids.append(split.view(v).get_viewport_rid())
	else:
		rids.append(get_viewport().get_viewport_rid())
	return rids
