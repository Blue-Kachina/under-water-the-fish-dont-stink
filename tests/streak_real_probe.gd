extends Node
## Phase 1 diagnosis (planning_marco_whales.md): the real build path. A human
## local seeker in a real MarcoPoloMatch (main.tscn), bot hiders live; calls
## Marco! and logs, per call, what each hider was doing and how many ghost
## cells it left. Answers "why aren't the streaks seen": moving or frozen
## hiders, window length, fade, and whether the scan is in seeker view.
##   Godot_console.exe --headless --path . res://tests/streak_real_probe.tscn
## `-- --calls=N --arena=Aquarium` to vary.

const TICKS := 120

var main: Node
var failures := 0
var calls := 3
var arena := "Sunken Temple"
var shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--calls="):
			calls = int(arg.trim_prefix("--calls="))
		elif arg.begins_with("--arena="):
			arena = arg.trim_prefix("--arena=")
		elif arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var mp := MarcoPoloSettings.shared()
	mp.arena = arena
	mp.hide_time = 0.5
	mp.round_time = 120.0
	mp.min_players = 5
	mp.rounds = 0
	mp.bot_seeker_rounds = 0
	mp.marco_cooldown = 0.0
	mp.marco_auto = false
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	mp.start_as = MarcoPoloSettings.StartAs.SEEKER
	main.set_mode(main.MARCO_POLO)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	var game: MarcoPoloMatch = main.marco_polo
	if game == null:
		print("FAIL no match")
		get_tree().quit(1)
		return
	for i in TICKS * 8:
		if game.phase == MarcoPoloMatch.Phase.LIVE:
			break
		await get_tree().physics_frame
	var scan: MarcoScan = game._looks.scan if game.get("_looks") else null
	if scan == null:
		for n in main.get_tree().root.find_children("*", "Node", true, false):
			if n is MarcoScan:
				scan = n
				break
	print("scan found: %s, phase live: %s, seeker role: %s" % [scan != null, game.phase == MarcoPoloMatch.Phase.LIVE, game.local_view_role()])
	if scan == null:
		get_tree().quit(1)
		return
	var seeker: FishController = game.seekers()[0]
	await _ticks(TICKS * 3)  # let hiders scatter and cruise
	for c in calls:
		var speeds := {}
		for h in game.live_hiders():
			speeds[h] = h.linear_velocity.length()
		var ok := game.marco(seeker)
		print("call %d accepted=%s  hider speeds: %s" % [c, ok, speeds.values().map(func(v: float) -> String: return "%.1f" % v)])
		var peak := 0
		var cost := 0
		var peak_t := 0.0
		var t := 0.0
		for i in TICKS * 6:
			await get_tree().physics_frame
			t += 1.0 / TICKS
			if shots_dir != "" and i % 60 == 30 and i < TICKS * 4:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/c%d_t%03d.png" % [shots_dir, c, int(t * 100)])
			if scan.cells.size() > peak:
				peak = scan.cells.size()
				peak_t = t
				var began := Time.get_ticks_usec()
				scan._draw_ghosts()
				scan._draw_ripples()
				cost = maxi(cost, Time.get_ticks_usec() - began)
		print("   pulse view=%s  peak cells %d at %.2fs, left after 6s %d, visible=%s; draw cost at peak %.2f ms (%d ripples)" % [scan.seeker_view, peak, peak_t, scan.cells.size(), scan._ghosts.visible, cost / 1000.0, scan.ripples.size()])
	get_tree().quit(0)
