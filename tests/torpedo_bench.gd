extends Node
## Not a probe: what a big Torpedo Launcher costs (planning_unnatural.md round
## 2, item 10), in a window with the real renderer. The Test Tank with
## tank_horde chasing zombies (default 500) round the parked player, its
## Ghost Bite on, and the launcher at --stacks=N (default each of 0, 8 and 16
## in turn); prints the frame time (average and worst), the physics, process
## and render time, the torpedoes in flight and the blasts a second.
##   Godot_console.exe --path . res://tests/torpedo_bench.tscn -- --stacks=16 --horde=500 --lightning=0

var stacks: Array[int] = [0, 8, 16]
var horde_count := 500
var lightning := 0
var seconds := 6.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stacks="):
			stacks = [arg.trim_prefix("--stacks=").to_int()]
		elif arg.begins_with("--horde="):
			horde_count = arg.trim_prefix("--horde=").to_int()
		elif arg.begins_with("--lightning="):
			lightning = arg.trim_prefix("--lightning=").to_int()
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
	var powers := PowerupSettings.shared()
	settings.tank_horde = horde_count
	settings.fish_attack = 2  # Ghost Bite
	settings.tank_attack_speed = 2.0
	powers.lightning_stacks = lightning
	main.set_mode(main.TEST_TANK)
	await _frames(5)
	main._match_card.play_requested.emit()
	await _frames(10)
	var run: UnnaturalRun = main.unnatural_run
	var fish: FishController = main.get_node("Fish")
	fish.freeze = true
	for count in stacks:
		powers.torpedo_stacks = count
		await _seconds(2.0)  # the horde comes in, torpedoes get going
		var launcher: TorpedoLauncher = run.powerups_of(fish).held.get("torpedo")
		var blasts_before := launcher.blasts if launcher else 0
		var frames := 0
		var worst := 0.0
		var physics_ms := 0.0
		var process_ms := 0.0
		var flying := 0
		var draws := 0.0
		var started := Time.get_ticks_usec()
		var last := started
		while (Time.get_ticks_usec() - started) / 1e6 < seconds:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			worst = maxf(worst, (now - last) / 1000.0)
			last = now
			frames += 1
			physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			flying = maxi(flying, _torpedoes(run))
		var elapsed := (Time.get_ticks_usec() - started) / 1e6
		var blasts := (launcher.blasts if launcher else 0) - blasts_before
		print("BENCH torpedo stacks=%d horde=%d alive=%d lightning=%d  frame %.2f ms avg (%.0f fps), worst %.1f ms  physics %.2f ms  process %.2f ms  draw calls %.0f  torpedoes in flight (most) %d  blasts %.0f/s" % [
			count, horde_count, run.horde.alive_count(), lightning, elapsed * 1000.0 / frames, frames / elapsed, worst,
			physics_ms / frames, process_ms / frames, draws / frames, flying, blasts / elapsed])
	get_tree().quit()


## Torpedoes in flight now (however they're drawn).
func _torpedoes(run: UnnaturalRun) -> int:
	for fish in run.players:
		var launcher: TorpedoLauncher = run.powerups_of(fish).held.get("torpedo")
		if launcher:
			return launcher.in_flight()
	return 0


func _seconds(s: float) -> void:
	var left := s
	while left > 0.0:
		await RenderingServer.frame_post_draw
		left -= get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
