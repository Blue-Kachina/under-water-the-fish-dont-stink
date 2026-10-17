extends Node
## Not a probe: how much schools cost, in a window with the real renderer. A
## Nature run with --schools=N schools of --fish=M fish (NatureSettings), the
## player parked among them looking at the nearest; prints the average frame
## time, physics and process time, draw calls and the schools' own loop.
##   Godot_console.exe --path . res://tests/school_bench.tscn -- --schools=6 --fish=50

var schools := 6
var fish := 50
var seconds := 4.0
var no_shadows := false
var no_separation := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--schools="):
			schools = arg.trim_prefix("--schools=").to_int()
		elif arg.begins_with("--fish="):
			fish = arg.trim_prefix("--fish=").to_int()
		elif arg == "--no-shadows":
			no_shadows = true
		elif arg == "--no-separation":
			no_separation = true
		elif arg.begins_with("--seconds="):
			seconds = arg.trim_prefix("--seconds=").to_float()
	get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred(main)


func _run(main: Node) -> void:
	var settings := NatureSettings.shared()
	main.set_mode(main.NATURE)
	await _frames(3)
	settings.school_count = schools
	settings.fish_per_school = fish
	settings.first_school_distance = 25.0
	settings.spawn_distance_min = 20.0
	settings.spawn_distance_max = 45.0
	main._match_card.play_requested.emit()
	await _frames(10)
	var run: NatureRun = main.nature_run
	var player: FishController = main.get_node("Fish")
	player.freeze = true
	if no_separation:
		settings.separation = 0.0
	if no_shadows:
		for school in run.schools:
			for node in school.find_children("*", "GeometryInstance3D", true, false):
				(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await _seconds(1.5)  # settle
	var frames := 0
	var physics_ms := 0.0
	var process_ms := 0.0
	var draws := 0.0
	var primitives := 0.0
	var started := Time.get_ticks_usec()
	var school_usec := 0
	while (Time.get_ticks_usec() - started) / 1e6 < seconds:
		await RenderingServer.frame_post_draw
		frames += 1
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var elapsed := (Time.get_ticks_usec() - started) / 1e6
	# The schools' own loop on its own, per physics tick.
	for school in run.schools:
		school.set_physics_process(false)
	var loop_started := Time.get_ticks_usec()
	for tick in 120:
		for school in run.schools:
			school._physics_process(1.0 / 120.0)
	school_usec = Time.get_ticks_usec() - loop_started
	var total := 0
	for school in run.schools:
		total += school.fish_count()
	print("BENCH schools=%d fish=%d (%d total) nodes=%d" % [schools, fish, total, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	print("BENCH frame %.2f ms (%.0f fps)  physics %.2f ms  process %.2f ms  draw calls %.0f  primitives %.0fk  schools' loop %.3f ms/tick" % [
		elapsed * 1000.0 / frames, frames / elapsed, physics_ms / frames, process_ms / frames, draws / frames, primitives / frames / 1000.0,
		school_usec / 1000.0 / 120.0])
	get_tree().quit()


func _seconds(s: float) -> void:
	var left := s
	while left > 0.0:
		await RenderingServer.frame_post_draw
		left -= get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
