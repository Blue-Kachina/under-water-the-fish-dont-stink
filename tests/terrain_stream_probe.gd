extends Node
## Endless terrain (TerrainStream, planning_procedural_world.md phase 8): tile params are deterministic, two neighbouring
## tiles agree along their shared edge (no seams), tiles build on worker threads round a moving node and far ones are
## dropped. Prints per-tile generate times.
##   Godot_console.exe --headless --path . res://tests/terrain_stream_probe.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.new()
	var stream := TerrainStream.new()
	stream.settings = settings
	stream.stream_seed = 7
	print("Tiles:")
	check(str(stream.tile_params(Vector2i(2, -3))) == str(stream.tile_params(Vector2i(2, -3))), "a tile's params are the same every time")
	var a := TerrainField.new()
	a.configure(stream.tile_params(Vector2i(0, 0)))
	var t0 := Time.get_ticks_usec()
	a.generate()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var b := TerrainField.new()
	b.configure(stream.tile_params(Vector2i(1, 0)))
	b.generate()
	print("    one tile generates in %.0f ms" % ms)
	# Along the shared edge x = tile_size: the same rock both sides (the exact distance can differ a little where the
	# nearest rock lies outside one tile's margin, so compare the sign near the surface and the value close to it).
	var mismatched := 0
	var samples := 0
	for zi in 48:
		for yi in 20:
			var p := Vector3(stream.tile_size, -6.0 + yi * 2.0, zi * 2.0 + 0.5)
			var da := a.sdf(p)
			var db := b.sdf(p)
			if absf(da) < 3.0 or absf(db) < 3.0:
				samples += 1
				if (da < 0.0) != (db < 0.0):
					mismatched += 1
	check(samples > 20 and mismatched <= samples / 50, "neighbouring tiles agree along their edge (%d of %d near-surface samples differ)" % [mismatched, samples])

	print("Streaming:")
	var follow := Node3D.new()
	add_child(follow)
	add_child(stream)
	stream.follow = follow
	var waited := 0
	while stream.built_count() < 9 and waited < 600:
		await get_tree().process_frame
		waited += 1
	check(stream.built_count() >= 9, "tiles round the start built (%d after %d frames)" % [stream.built_count(), waited])
	var near := stream.get_child_count()
	follow.position = Vector3(stream.tile_size * 8.0, 0.0, 0.0)
	waited = 0
	while waited < 900:
		await get_tree().process_frame
		waited += 1
		if stream.built_count() >= 9 and not stream._tiles.has(Vector2i(0, 0)):
			break
	check(not stream._tiles.has(Vector2i(0, 0)), "the start's tile dropped once far behind")
	check(stream._tiles.has(Vector2i(8, 0)) and is_instance_valid(stream._tiles[Vector2i(8, 0)]["node"]), "a tile built under the new spot")
	print("    nodes near the start %d, tiles now %d" % [near, stream._tiles.size()])
	stream.queue_free()
	await get_tree().process_frame
	print("DONE: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)
