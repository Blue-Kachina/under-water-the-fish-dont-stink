extends Node
## The procedural terrain (planning_procedural_world.md): the native field generates deterministically and fast enough,
## meshes into chunks with collision, the query API answers (flat with no terrain), the middle stays open, and rule N
## holds over many seeds: the start is reachable with clearance, every arch and tunnel bore is passable, and a ball of the
## clearance swept along each bore never wedges. Prints timings and triangle counts.
##   Godot_console.exe --headless --path . res://tests/terrain_probe.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.new()
	settings.terrain_enabled = true
	var radius := settings.arena_radius
	var height := settings.arena_ceiling - settings.arena_floor + 5.0

	print("Flat fallback:")
	check(Terrain.floor_y(3.0, 4.0, -25.0) == -25.0, "no terrain: floor_y is the flat floor")
	check(Terrain.sdf(Vector3.ZERO) > 1000.0 and Terrain.is_open(Vector3.ZERO, 5.0), "no terrain: everywhere open")

	print("Determinism:")
	var a := TerrainLayout.roll(settings, 4242, radius, height)
	var b := TerrainLayout.roll(settings, 4242, radius, height)
	var fa := TerrainField.new()
	fa.configure(a.params)
	var sa := fa.generate()
	var fb := TerrainField.new()
	fb.configure(b.params)
	fb.generate()
	check(fa.checksum() == fb.checksum(), "same seed, same field (%d)" % fa.checksum())
	var c := TerrainLayout.roll(settings, 4243, radius, height)
	var fc := TerrainField.new()
	fc.configure(c.params)
	fc.generate()
	check(fa.checksum() != fc.checksum(), "another seed, another field")
	print("    generate: %s" % [sa])

	print("Build (seed 4242):")
	var terrain := Terrain.new()
	add_child(terrain)
	terrain.build(settings, 4242, radius, height)
	print("    stats: %s" % [terrain.stats])
	check(terrain.chunks.size() > 0 and int(terrain.stats["triangles"]) > 1000, "chunks meshed (%d chunks, %d triangles)" % [terrain.chunks.size(), terrain.stats["triangles"]])
	check(float(terrain.stats["ms_prepare"]) + float(terrain.stats["ms_apply"]) < 3000.0, "builds in under 3 s (%.0f ms)" % (float(terrain.stats["ms_prepare"]) + float(terrain.stats["ms_apply"])))
	check(terrain.body != null and terrain.body.get_child_count() == terrain.chunks.size(), "a collision shape per chunk")
	check(Terrain.active == terrain, "the built terrain answers the queries")
	check(Terrain.is_open(Vector3(0, height * 0.5, 0), settings.terrain_clearance), "the middle is open")
	check(absf(Terrain.floor_y(10.0, 10.0, 0.0)) < 0.01, "the open middle's floor is the flat floor")
	var ring := Vector3(radius + settings.terrain_ring_width * 0.5, 2.0, 0.0)
	check(Terrain.sdf(ring) < 0.0, "the edge ring is rock near its base")
	var push := Terrain.push(ring, 1.0)
	check(push.length() > 0.5, "push moves a point out of the rock")
	check(not Terrain.line_clear(Vector3(0, 2, 0), Vector3(radius + 30.0, 2.0, 0.0), 1.0), "a line through the ring is blocked")

	print("Rule N over seeds:")
	var bad_reach := 0
	var bad_bores := 0
	var bores := 0
	var slow := 0.0
	for n in 12:
		var seed_value := 1000 + n * 37
		var lay := TerrainLayout.roll(settings, seed_value, radius, height)
		var f := TerrainField.new()
		f.configure(lay.params)
		var st := f.generate()
		slow = maxf(slow, float(st["ms_total"]))
		if not (f.is_reachable(Vector3(0, height * 0.5, 0)) and f.sdf(Vector3(0, height * 0.5, 0)) > settings.terrain_clearance):
			bad_reach += 1
		for arch in lay.arches:
			bores += 1
			# Through the hole: a little above the floor, along the arch's axis.
			var hole := Vector3(arch.x, settings.terrain_clearance + 0.6, arch.y)
			if f.sdf(hole) < settings.terrain_clearance * 0.9:
				bad_bores += 1
				print("    arch %s: %.2f m of room" % [arch, f.sdf(hole)])
		for tunnel: Array in lay.tunnels:
			bores += 1
			if not f.segment_clear(tunnel[0], tunnel[1], settings.terrain_clearance * 0.9):
				bad_bores += 1
				var worst := 1e4
				for t in 21:
					worst = minf(worst, f.sdf((tunnel[0] as Vector3).lerp(tunnel[1], t / 20.0)))
				print("    tunnel %s: %.2f m of room at worst" % [tunnel, worst])
	check(bad_reach == 0, "the start is open and reachable on every seed")
	check(bad_bores == 0, "every arch hole and tunnel bore passes a clearance ball (%d bores)" % bores)
	print("    slowest generate: %.0f ms" % slow)

	terrain.queue_free()
	await get_tree().process_frame

	print("Stage build (Seabed, terrain on vs off):")
	var times := []
	for on in [false, true]:
		var stage_settings := UnnaturalSettings.new()
		stage_settings.terrain_enabled = on
		var bed := Seabed.new()
		add_child(bed)
		var t0 := Time.get_ticks_usec()
		bed.setup(stage_settings, 4242, height)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		times.append(ms)
		if on:
			check(bed.terrain != null and bed.pieces.size() >= 2, "terrain and set pieces built (%d pieces)" % bed.pieces.size())
			var inside := 0
			for piece in bed.pieces:
				var at := piece.position
				if bed.terrain.field.sdf(at + Vector3.UP * 3.0) < 0.0:
					inside += 1
			check(inside == 0, "no set piece sits inside rock")
			print("    flora blades %d, kelp columns %d" % [bed.flora.blade_count() if bed.flora else 0, bed.kelp_spots.size()])
		bed.queue_free()
		await get_tree().process_frame
	print("    seabed build: terrain off %.0f ms, on %.0f ms" % [times[0], times[1]])
	var pre_settings := UnnaturalSettings.new()
	pre_settings.terrain_enabled = true
	var pre := Seabed.new()
	add_child(pre)
	pre.prefetch(pre_settings, 5151, height)
	await get_tree().create_timer(1.5).timeout
	var tp := Time.get_ticks_usec()
	pre.setup(pre_settings, 5151, height)
	var pre_ms := (Time.get_ticks_usec() - tp) / 1000.0
	print("    seabed build after a prefetch: %.0f ms" % pre_ms)
	check(pre.terrain != null and pre._prefetched == null and pre_ms < float(times[1]), "a prefetched terrain is used (%.0f ms vs %.0f)" % [pre_ms, times[1]])
	pre.queue_free()
	check(float(times[1]) < 2500.0, "a stage with terrain builds in under 2.5 s headless")
	print("DONE: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)
