extends Node
## Not a probe: how much the Horde costs (planning_unnatural.md phase 0), in a
## window with the real renderer. Free Swim in the Ocean with --count=N
## zombies (default: each of 500, 1000, 2000, 5000 in turn) chasing the
## player, parked in the middle of them; prints the average frame time, the
## Horde's step on its own (ms per 30 Hz step) and its draw (ms per frame).
##   Godot_console.exe --path . res://tests/horde_bench.tscn -- --count=2000
## --headless works too, for the step and draw loops only (no rendering).
## Murk (planning_murk.md phase 0):
##   --spread=M   spawn 8..M m out (default 70; 150 = the whole arena, a late run)
##   --murk=D     fog density (with the sky fogged too), 0 = the ocean's own
##   --cull=F     murk_cull (the fog amount it stops drawing at; 1: never)
##   --frustum=0  draw zombies behind the camera too (murk_frustum off)
## Also prints the GPU's and the render thread's time per frame.

var counts: Array[int] = [500, 1000, 2000, 5000]
var seconds := 3.0
var spread := 70.0
var murk := 0.0
var cull := -1.0
var frustum := true


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			counts = [arg.trim_prefix("--count=").to_int()]
		elif arg.begins_with("--seconds="):
			seconds = arg.trim_prefix("--seconds=").to_float()
		elif arg.begins_with("--spread="):
			spread = arg.trim_prefix("--spread=").to_float()
		elif arg.begins_with("--murk="):
			murk = arg.trim_prefix("--murk=").to_float()
		elif arg.begins_with("--cull="):
			cull = arg.trim_prefix("--cull=").to_float()
		elif arg.begins_with("--frustum="):
			frustum = arg.trim_prefix("--frustum=").to_int() != 0
	get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred(main)


func _run(main: Node) -> void:
	main.set_mode(main.FREE_SWIM)
	await _frames(5)
	var player: FishController = main.get_node("Fish")
	player.freeze = true
	var settings := UnnaturalSettings.new()
	settings.max_enemies = 6000
	settings.murk_density = murk
	settings.murk_frustum = frustum
	if cull >= 0.0:
		settings.murk_cull = cull
	if murk > 0.0:
		var env: Environment = main.get_node("Ocean").environment()
		env.fog_density = murk
		env.fog_sky_affect = 1.0
	var viewport := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	for count in counts:
		var horde := Horde.new()
		horde.name = "Horde"
		main.get_node("Ocean").add_child(horde)
		horde.setup(settings, EnemyKind.defaults(), settings.max_enemies, 1)
		horde.apply_murk(murk)
		var rng := RandomNumberGenerator.new()
		rng.seed = 2
		for n in count:
			var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)).normalized()
			var kind := 0 if n % 3 != 0 else 1 + n % 4
			horde.spawn(kind, player.global_position + direction * rng.randf_range(8.0, maxf(spread, 8.0)), -direction)
		horde.targets = PackedVector3Array([player.global_position])
		horde.chaseable = PackedByteArray([1])
		await _seconds(1.0)  # settle
		var frames := 0
		var physics_ms := 0.0
		var draws := 0.0
		var drawn := 0.0
		var glints := 0.0
		var gpu_ms := 0.0
		var render_ms := 0.0
		var started := Time.get_ticks_usec()
		while (Time.get_ticks_usec() - started) / 1e6 < seconds:
			await RenderingServer.frame_post_draw
			frames += 1
			physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			drawn += horde.drawn_count
			glints += horde.glint_count
			gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
			render_ms += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		var elapsed := (Time.get_ticks_usec() - started) / 1e6
		horde.set_physics_process(false)
		horde.set_process(false)
		var step_started := Time.get_ticks_usec()
		for tick in 60:
			horde.step_once(1.0 / 30.0)
		var step_ms := (Time.get_ticks_usec() - step_started) / 1000.0 / 60.0
		var draw_started := Time.get_ticks_usec()
		for frame in 60:
			horde._draw_horde(1.0 / 60.0)
		var draw_ms := (Time.get_ticks_usec() - draw_started) / 1000.0 / 60.0
		var query_started := Time.get_ticks_usec()
		var hits := 0
		for q in 200:
			hits += horde.query_sphere(player.global_position, 8.0).size()
		var query_ms := (Time.get_ticks_usec() - query_started) / 1000.0 / 200.0
		print("BENCH zombies=%d spread=%.0f murk=%.3f cull=%.2f frustum=%s alive=%d drawn=%.0f eyes=%.0f  frame %.2f ms (%.0f fps)  gpu %.2f ms  render cpu %.2f ms  physics %.2f ms  draw calls %.0f  step %.2f ms/step (%.2f ms/s at 30 Hz)  draw %.2f ms/frame  query(8 m) %.3f ms (%d hit)" % [
			count, spread, murk, cull, frustum, horde.alive_count(), drawn / frames, glints / frames, elapsed * 1000.0 / frames, frames / elapsed, gpu_ms / frames, render_ms / frames, physics_ms / frames, draws / frames,
			step_ms, step_ms * 30.0, draw_ms, query_ms, hits / 200])
		horde.queue_free()
		await _frames(3)
	get_tree().quit()


func _seconds(s: float) -> void:
	var left := s
	while left > 0.0:
		await RenderingServer.frame_post_draw
		left -= get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
