extends Node
## Not a probe: Nature's split-screen co-op (LocalCoop) for checking by eye, and
## what it costs. Screenshots of a Nature run with 1, 2, 3 and 4 players (the
## extra ones on made-up controllers, swum forward by script), and the frame
## time of each (Nature's default schools). Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/split_shots.tscn -- --out=DIR

var out_dir := "user://split_shots"
var main: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	main.set_mode(main.NATURE)
	await _frames(5)
	main._match_card.play_requested.emit()
	await _seconds(2.0)
	var local: LocalCoop = main._local
	var lines := PackedStringArray()
	for players in [1, 2, 3, 4]:
		while local.count() < players:
			local.join(20 + local.count())
		for slot in local.slots:
			var input := FishInput.new()
			input.forward = 0.7
			slot.fish.controls = input
		await _seconds(3.0)
		var times := PackedFloat32Array()
		for i in 120:
			var start := Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			times.append((Time.get_ticks_usec() - start) / 1000.0)
		times.sort()
		var line := "%d player%s: median frame %.1f ms, 90th %.1f ms, %d draw calls" % [players, "" if players == 1 else "s",
				times[times.size() / 2], times[int(times.size() * 0.9)],
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]
		print(line)
		lines.append(line)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("players_%d.png" % players))
	var file := FileAccess.open(out_dir.path_join("frame_times.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	print("split_shots: saved to %s" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
