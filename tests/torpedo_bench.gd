extends Node
## Not a probe: what a big Torpedo Launcher costs (planning_unnatural.md round
## 2, item 10), in a window with the real renderer. The Test Tank with
## tank_horde chasing zombies (default 500) round the parked player, its
## Ghost Bite on, and the launcher at --stacks=N (default each of 0, 8 and 16
## in turn); prints the frame time (average and worst), the physics, process
## and render time, the torpedoes in flight and the blasts a second.
## --attack=K gives the player another attack (FishAttack.Kind: 1 sting, 2
## bite, 3 lash, 4 thrust, 5 bubbles, 6 spines; default 2).
##   Godot_console.exe --path . res://tests/torpedo_bench.tscn -- --stacks=16 --horde=500 --lightning=0 --attack=2 [--build] [--old]
## It also prints the hit path's cost (UnnaturalRun.hit_usec: ms a second spent in hits
## and what they set off) and hits a second.

var stacks: Array[int] = [0, 8, 16]
var horde_count := 500
var lightning := 0
var seconds := 6.0
var attack := 2
## --old: the hit path as before the perf pass (UnnaturalRun.batch_hits off), for A/B.
var old := false
## --build: the items of the user's 16-minute run (2026-10-23), a late build, on top.
var build := false
## --set=name=value (repeatable): an UnnaturalSettings or PowerupSettings value, e.g. --set=damage_numbers=false.
var sets: Array[String] = []
## --build=id,id: only those of the build's items.
var only: PackedStringArray = []
const BUILD := {"abyssal_engine": 2, "ammonite_spiral": 2, "bioluminescence": 4, "divers_goggles": 4, "fizzy_soda": 2, "ghost_swordfish": 10,
		"kelp_wrap": 2, "krakens_grasp": 1, "lamprey": 7, "momentum_fin": 5, "poseidons_trident": 1, "reef_guardian": 4, "riptide": 5,
		"sea_salt": 4, "speedy_seahorse": 2, "electric_eel": 1}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stacks="):
			stacks = [arg.trim_prefix("--stacks=").to_int()]
		elif arg.begins_with("--horde="):
			horde_count = arg.trim_prefix("--horde=").to_int()
		elif arg.begins_with("--lightning="):
			lightning = arg.trim_prefix("--lightning=").to_int()
		elif arg.begins_with("--attack="):
			attack = arg.trim_prefix("--attack=").to_int()
		elif arg.begins_with("--set="):
			sets.append(arg.trim_prefix("--set="))
		elif arg == "--old":
			old = true
		elif arg == "--build":
			build = true
		elif arg.begins_with("--build="):
			build = true
			only = arg.trim_prefix("--build=").split(",")
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
	settings.fish_attack = attack
	settings.tank_attack_speed = 2.0
	powers.lightning_stacks = lightning
	UnnaturalRun.batch_hits = not old
	for pair in sets:
		var key := pair.get_slice("=", 0)
		var value: Variant = str_to_var(pair.get_slice("=", 1))
		if key in settings:
			settings.set(key, value)
		else:
			powers.set(key, value)
	if build:
		for id: String in BUILD:
			if not only.is_empty() and id not in only:
				continue
			powers.set(PowerupSettings.STACKS[id], BUILD[id])
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
		UnnaturalRun.hit_usec = 0
		UnnaturalRun.hits_counted = 0
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
		print("BENCH attack=%d torpedo stacks=%d horde=%d alive=%d lightning=%d  frame %.2f ms avg (%.0f fps), worst %.1f ms  physics %.2f ms  process %.2f ms  draw calls %.0f  torpedoes in flight (most) %d  blasts %.0f/s  hit path %.1f ms/s for %.0f hits/s%s%s" % [
			attack, count, horde_count, run.horde.alive_count(), lightning, elapsed * 1000.0 / frames, frames / elapsed, worst,
			physics_ms / frames, process_ms / frames, draws / frames, flying, blasts / elapsed, UnnaturalRun.hit_usec / 1000.0 / elapsed, UnnaturalRun.hits_counted / elapsed,
			"  OLD PATH" if old else "", "  +BUILD" if build else ""])
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
