extends Node
## Not a probe: what split-screen costs in Unnatural, in a window with the real
## renderer. An Unnatural run with --players=P local players (default 3), each
## frozen --apart=M m from the middle (default 30), with --count=N zombies
## (default 2000) chasing them, spread --spread=M m out (default 100). Prints
## the average frame time, each view's GPU and render-thread time, the Horde's
## draw and step, and the process/physics times.
##   Godot_console.exe --path . res://tests/split_bench.tscn -- --players=3 --count=2000
## --pearls=N XP pearls lying about (default 0).
## --powers=N every player has N stacks of each attacking powerup (torpedoes,
## lightning, fire, bubbles, spines, jellyfish, eel, depth charges), and the
## director keeps the horde at --count.
## --seconds=S how long to measure (default 4); --profile: each script's process times after.

const PADS := [11, 12, 13]

var players := 3
var count := 2000
var spread := 100.0
var apart := 30.0
var seconds := 4.0
var pearls := 0
var powers := 0
var profile := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			players = clampi(arg.trim_prefix("--players=").to_int(), 1, 4)
		elif arg.begins_with("--count="):
			count = arg.trim_prefix("--count=").to_int()
		elif arg.begins_with("--spread="):
			spread = arg.trim_prefix("--spread=").to_float()
		elif arg.begins_with("--apart="):
			apart = arg.trim_prefix("--apart=").to_float()
		elif arg.begins_with("--pearls="):
			pearls = arg.trim_prefix("--pearls=").to_int()
		elif arg.begins_with("--powers="):
			powers = arg.trim_prefix("--powers=").to_int()
		elif arg == "--profile":
			profile = true
		elif arg.begins_with("--seconds="):
			seconds = arg.trim_prefix("--seconds=").to_float()
	get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred(main)


func _run(main: Node) -> void:
	var settings := UnnaturalSettings.shared()
	settings.spawning = false
	settings.stage_events = false
	settings.chest_count = 0
	settings.max_enemies = maxi(settings.max_enemies, count + 100)
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	for p in players - 1:
		_press(PADS[p], LocalCoop.JOIN_BUTTON)
		await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	var horde := run.horde
	var centre := horde.arena_centre
	for p in run.players.size():
		var fish := run.players[p]
		var angle := TAU * p / run.players.size()
		fish.global_position = Vector3(centre.x + cos(angle) * apart, fish.global_position.y, centre.z + sin(angle) * apart) if run.players.size() > 1 else fish.global_position
		fish.freeze = true

	settings.god_mode = true
	if powers > 0:
		var power := PowerupSettings.shared()
		for stack: String in ["torpedo", "lightning", "fire", "bubble", "spine", "jelly", "eel", "charge"]:
			power.set(stack + "_stacks", powers)
		settings.base_alive = count
		settings.alive_per_minute = 0.0
		settings.coop_scale = 0.0
		settings.swarm_base = 40
		settings.spawn_interval = 0.1
		settings.spawning = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for n in count:
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)).normalized()
		var kind := 0 if n % 3 != 0 else 1 + n % 4
		horde.spawn(kind % horde.kinds.size(), centre + direction * rng.randf_range(8.0, maxf(spread, 8.0)) + Vector3.UP * 6.0, -direction)
	for n in pearls:
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)).normalized()
		run.drop_pearl(centre + direction * rng.randf_range(10.0, spread) + Vector3.UP * 6.0, 1)
	var split: SplitScreen = main.get_node_or_null("SplitScreen")
	var viewports: Array[RID] = []
	if split:
		for v in split.count():
			viewports.append(split.view(v).get_viewport_rid())
	else:
		viewports.append(get_viewport().get_viewport_rid())
	for rid in viewports:
		RenderingServer.viewport_set_measure_render_time(rid, true)
	await _seconds(1.5)  # settle
	var frames := 0
	var gpu := PackedFloat64Array()
	gpu.resize(viewports.size())
	var cpu := PackedFloat64Array()
	cpu.resize(viewports.size())
	var process_ms := 0.0
	var physics_ms := 0.0
	var draws := 0.0
	var objects := 0.0
	var drawn := 0.0
	var worst := 0.0
	var started := Time.get_ticks_usec()
	var last := started
	var spikes: Array[String] = []
	var ticks := [0]
	var count_tick := func() -> void: ticks[0] += 1
	get_tree().physics_frame.connect(count_tick)
	var level := run.levels.level if "level" in run.levels else 0
	var kills := horde.alive_count()
	while (Time.get_ticks_usec() - started) / 1e6 < seconds:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var took := (now - last) / 1000.0
		worst = maxf(worst, took)
		if took > 10.0:
			spikes.append("%.1f ms at %.2f s: %d ticks, physics %.1f, process %.1f, level %s, alive %d->%d, pearls %d, compiles %d" % [took, (now - started) / 1e6, ticks[0],
					Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					str(run.levels.level) if "level" in run.levels else "?", kills, horde.alive_count(), run.pearls_out.size(),
					Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)])
		ticks[0] = 0
		kills = horde.alive_count()
		last = now
		frames += 1
		for v in viewports.size():
			gpu[v] += RenderingServer.viewport_get_measured_render_time_gpu(viewports[v])
			cpu[v] += RenderingServer.viewport_get_measured_render_time_cpu(viewports[v])
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		drawn += horde.drawn_count
	var elapsed := (Time.get_ticks_usec() - started) / 1e6
	var views := ""
	var gpu_total := 0.0
	for v in viewports.size():
		views += "  view%d gpu %.2f cpu %.2f" % [v, gpu[v] / frames, cpu[v] / frames]
		gpu_total += gpu[v] / frames
	horde.set_physics_process(false)
	horde.set_process(false)
	var t := Time.get_ticks_usec()
	for frame in 60:
		horde._draw_horde(1.0 / 60.0)
	var draw_ms := (Time.get_ticks_usec() - t) / 1000.0 / 60.0
	t = Time.get_ticks_usec()
	for tick in 60:
		horde.step_once(1.0 / 30.0)
	var step_ms := (Time.get_ticks_usec() - t) / 1000.0 / 60.0
	print("SPLIT players=%d zombies=%d pearls=%d alive=%d apart=%.0f drawn=%.0f powers=%d  frame %.2f ms (%.0f fps) worst %.1f  gpu total %.2f%s  process %.2f  physics %.2f  draw calls %.0f  objects %.0f  horde draw %.2f ms  step %.2f ms" % [
		run.players.size(), count, run.pearls_out.size(), horde.alive_count(), apart, drawn / frames, powers, elapsed * 1000.0 / frames, frames / elapsed, worst, gpu_total, views,
		process_ms / frames, physics_ms / frames, draws / frames, objects / frames, draw_ms, step_ms])
	for spike in spikes.slice(0, 12):
		print("SPIKE " + spike)
	if profile:
		_profile(main)
	get_tree().quit()


## Each script's _physics_process and _process on their own, called 30 times
## (ms per call, summed over its nodes), the costliest first.
func _profile(main: Node) -> void:
	var costs := {}
	for node: Node in main.find_children("*", "", true, false):
		var script: Script = node.get_script()
		if script == null:
			continue
		for method: String in ["_physics_process", "_process"]:
			if not node.has_method(method) or not (node.is_physics_processing() if method == "_physics_process" else node.is_processing()):
				continue
			var delta := 1.0 / 120.0 if method == "_physics_process" else 1.0 / 60.0
			var t := Time.get_ticks_usec()
			for n in 30:
				node.call(method, delta)
			var key := "%s %s" % [script.resource_path.get_file(), method]
			costs[key] = costs.get(key, 0.0) + (Time.get_ticks_usec() - t) / 1000.0 / 30.0
	var keys := costs.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return costs[a] > costs[b])
	for key: String in keys.slice(0, 25):
		print("PROFILE %7.3f ms  %s" % [costs[key], key])


func _press(pad: int, button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = pad
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	var left := s
	while left > 0.0:
		await RenderingServer.frame_post_draw
		left -= get_process_delta_time()
