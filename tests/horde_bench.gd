extends Node
## Not a probe: how much the Horde costs (planning_unnatural.md phase 0), in a
## window with the real renderer. Free Swim in the Ocean with --count=N
## zombies (default: each of 500, 1000, 2000, 5000 in turn) chasing the
## player, parked in the middle of them; prints the average frame time, the
## Horde's step on its own (ms per 30 Hz step) and its draw (ms per frame).
##   Godot_console.exe --path . res://tests/horde_bench.tscn -- --count=2000
## --headless works too, for the step and draw loops only (no rendering).

var counts: Array[int] = [500, 1000, 2000, 5000]
var seconds := 3.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			counts = [arg.trim_prefix("--count=").to_int()]
		elif arg.begins_with("--seconds="):
			seconds = arg.trim_prefix("--seconds=").to_float()
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
	for count in counts:
		var horde := Horde.new()
		horde.name = "Horde"
		main.get_node("Ocean").add_child(horde)
		horde.setup(settings, EnemyKind.defaults(), settings.max_enemies, 1)
		var rng := RandomNumberGenerator.new()
		rng.seed = 2
		for n in count:
			var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)).normalized()
			var kind := 0 if n % 3 != 0 else 1 + n % 4
			horde.spawn(kind, player.global_position + direction * rng.randf_range(8.0, 70.0), -direction)
		horde.targets = PackedVector3Array([player.global_position])
		horde.chaseable = PackedByteArray([1])
		await _seconds(1.0)  # settle
		var frames := 0
		var physics_ms := 0.0
		var draws := 0.0
		var started := Time.get_ticks_usec()
		while (Time.get_ticks_usec() - started) / 1e6 < seconds:
			await RenderingServer.frame_post_draw
			frames += 1
			physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
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
		print("BENCH zombies=%d alive=%d  frame %.2f ms (%.0f fps)  physics %.2f ms  draw calls %.0f  step %.2f ms/step (%.2f ms/s at 30 Hz)  draw %.2f ms/frame  query(8 m) %.3f ms (%d hit)" % [
			count, horde.alive_count(), elapsed * 1000.0 / frames, frames / elapsed, physics_ms / frames, draws / frames,
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
