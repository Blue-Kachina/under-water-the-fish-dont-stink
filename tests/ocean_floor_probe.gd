extends Node
## Sea floors for the open-ocean modes (OceanFloor, planning_procedural_world.md phase 8): with HuntSettings.floor_enabled
## Hunt builds a seabed (with terrain) under its arena and keeps the fish above it; with nature_floor Nature streams
## endless terrain far below; Free Swim streams its own (terrain_stream). Off (the default) nothing is built.
##   Godot_console.exe --headless --path . res://tests/ocean_floor_probe.tscn

var failures := 0
var main: Node


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var nature := NatureSettings.shared()
	var unnatural := UnnaturalSettings.shared()
	print("Free Swim:")
	main.set_mode(main.FREE_SWIM, false)
	await _ticks(30)
	check(main._terrain_stream != null and main._terrain_stream.built_count() > 0, "Free Swim streams terrain")
	unnatural.terrain_stream = false
	main.set_mode(main.HUNT, false)
	await _ticks(3)
	check(main._terrain_stream == null, "leaving Free Swim drops the stream")

	print("Hunt (floor off):")
	main._match_card.play_requested.emit()
	await _ticks(5)
	var hunt: HuntMatch = main.hunt_match
	check(hunt != null and hunt.seabed == null, "no seabed by default")
	main._end_match()
	await _ticks(3)

	print("Hunt (floor on):")
	HuntSettings.shared().floor_enabled = true
	unnatural.terrain_enabled = true
	main.set_mode(main.FREE_SWIM, false)
	await _ticks(2)
	main.set_mode(main.HUNT, false)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	hunt = main.hunt_match
	check(hunt != null and hunt.seabed != null and hunt.seabed.terrain != null, "a seabed with terrain under the arena")
	if hunt and hunt.seabed:
		var fish: FishController = main.get_node("Fish")
		var flat := hunt.center.y - HuntSettings.shared().floor_depth
		fish.global_position = Vector3(hunt.center.x + 5.0, flat - 2.0, hunt.center.z)
		fish.linear_velocity = Vector3.ZERO
		var y0 := fish.global_position.y
		await _ticks(60)
		check(fish.global_position.y > y0 + 0.5, "a fish under the floor is pushed back up (%.1f -> %.1f)" % [y0, fish.global_position.y])
	main._end_match()
	await _ticks(3)
	HuntSettings.shared().floor_enabled = false

	print("Nature (floor on):")
	nature.nature_floor = true
	main.set_mode(main.NATURE, false)
	await _ticks(3)
	if main._match_card:
		main._match_card.play_requested.emit()
	await _ticks(60)
	var run: NatureRun = main.nature_run
	var stream: TerrainStream = null
	if run:
		for child in run.get_children():
			if child is TerrainStream:
				stream = child
	check(stream != null and stream.built_count() > 0, "Nature streams terrain far below")
	nature.nature_floor = false
	unnatural.terrain_enabled = false
	unnatural.terrain_stream = true
	var panel: Node = main.get_node("DebugPanel")
	check(panel._section_lists.has("hunt") and panel._rows.has("hunt/floor_depth") and panel._rows.has("battery/batter_speed"), "the panel has Hunt and Battery sections from the descriptor")
	print("DONE: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)
