extends Node3D
## Bench (numbers only) for MarcoScan's per-frame cost with its ghost cells and wake
## ripples full: fills the cap and times _draw_ghosts + _draw_ripples over 120 frames.
##   Godot_console.exe --headless --path . res://tests/ghost_bench.tscn -- [--cells=16000] [--ripples=3000]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var cells := 16000
	var ripples := 3000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cells="):
			cells = int(arg.trim_prefix("--cells="))
		elif arg.begins_with("--ripples="):
			ripples = int(arg.trim_prefix("--ripples="))
	var stub := Node.new()
	stub.set_script(load("res://tests/ghost_bench_stub.gd"))
	add_child(stub)
	var scan := MarcoScan.new()
	stub.add_child(scan)
	scan.bind(stub)
	await get_tree().process_frame
	scan.seeker_view = true
	var settings := scan.settings
	settings.set("ghost_max_cells", cells)
	settings.set("ghost_fade_min", 1000.0)
	settings.set("ghost_fade_max", 1000.0)
	settings.set("ghost_ripple_life", 1000.0)
	for i in cells:
		scan.cells[Vector3i(i % 40, (i / 40) % 20, i / 800)] = Vector4(0.8, scan._clock, 0.0, 0.0)
	for i in ripples:
		scan.ripples.append({"pos": Vector3(i % 50, (i / 50) % 10, 0.0), "born": scan._clock, "power": 0.7})
	var worst := 0
	var total := 0
	for i in 120:
		await get_tree().process_frame
		scan.seeker_view = true
		var began := Time.get_ticks_usec()
		scan._draw_ghosts()
		scan._draw_ripples()
		var cost := Time.get_ticks_usec() - began
		worst = maxi(worst, cost)
		total += cost
	print("ghost_bench: %d cells + %d ripples: mean %.2f ms, worst %.2f ms per frame (draw side only)" % [scan.cells.size(), scan.ripples.size(), total / 120000.0, worst / 1000.0])
	get_tree().quit()
