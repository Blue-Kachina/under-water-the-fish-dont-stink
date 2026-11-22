extends Node
## The Canyon Reef arena as RaceMatch meets it (planning_race.md phases 2-3): it builds as a RaceArena with the carved
## rock, the streams' bubbles, the cues and the slipstream look; the soft ceiling and the out-of-bounds query answer
## right; a stream pushes along the track inside it and not outside; every checkpoint (a rescue puts a racer there) is
## open water a size-cap ball fits in, as is every grid slot; both lanes of the split are passable.
##   Godot_console.exe --headless --path . res://tests/race_arena_probe.tscn

const BALL := 1.2

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := CanyonReefArena.new()
	var t0 := Time.get_ticks_usec()
	add_child(arena)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var track := arena.track
	check(track != null and arena.terrain != null and Terrain.active == arena.terrain, "the arena builds its track and rock (%.0f ms)" % ms)
	check(ms < 6000.0, "the whole build (rock, flora, streams, cues) is under 6 s headless")
	check(arena.streams.size() == track.streams.size(), "a BubbleStream per stream span (%d)" % arena.streams.size())
	check(arena.cues != null and arena.cues.get_child_count() >= 6, "the cues are dressed (%d nodes)" % arena.cues.get_child_count())
	var counts := {}
	for child in arena.cues.get_children():
		var key := String(child.name).rstrip("0123456789")
		counts[key] = int(counts.get(key, 0)) + 1
	print("    cues: %s" % [counts])
	check(counts.has("Buoys") and counts.has("GlowCoral") and counts.has("Stripe") and counts.has("Lamps") and counts.has("Glyph"), "buoys, coral, stripe, lamps and glyphs all placed")
	check(arena.slipstream_fx != null, "the slipstream look is up")
	var pole: Transform3D = arena.spawn_transform()
	check(Terrain.is_open(pole.origin, BALL), "the pole position is open water")

	var closed := 0
	for cp: Dictionary in track.checkpoints:
		if not Terrain.is_open(cp["pos"], BALL):
			closed += 1
			print("    checkpoint at d=%.0f (%s) is not open water" % [cp["d"], cp["tag"]])
	check(closed == 0, "every checkpoint (a rescue point) is open water (%d of %d)" % [closed, track.checkpoints.size()])
	var slot_closed := 0
	for slot in track.grid_slots(12):
		if not Terrain.is_open((slot["xform"] as Transform3D).origin, BALL):
			slot_closed += 1
	check(slot_closed == 0, "all 12 grid slots are open water")

	# Both lanes of the split: a ball swims either side of the pillar, easing out to the lane over 6 m and back.
	var lanes_ok := not track.solids.is_empty()
	if lanes_ok:
		var span := track.solids[0]
		var s0 := float(span["d0"])
		var s1 := float(span["d1"])
		for side: float in [-1.0, 1.0]:
			var d_run := s0 - 8.0
			while d_run < s1 + 8.0:
				var a := track.sample(d_run)
				var b := track.sample(d_run + 2.0)
				var pa := a.pos + a.right * _lane(d_run, s0, s1) * side
				var pb := b.pos + b.right * _lane(d_run + 2.0, s0, s1) * side
				if not Terrain.line_clear(pa, pb, BALL):
					lanes_ok = false
					print("    lane %.0f blocked at d=%.0f (clearance %.2f)" % [side, d_run, Terrain.sdf(pa)])
				d_run += 2.0
	check(lanes_ok, "both lanes of the split pass a size-cap ball")

	# Soft ceiling.
	var rim := arena.rim_y()
	check(arena.ceiling_accel(Vector3(0.0, rim - 5.0, 0.0)) == Vector3.ZERO, "no ceiling push below the rim")
	var margin := RaceSettings.shared().ceiling_margin
	check(arena.ceiling_accel(Vector3(0.0, rim + margin - 0.5, 0.0)) == Vector3.ZERO, "none until the margin")
	var low := arena.ceiling_accel(Vector3(0.0, rim + margin + 3.0, 0.0))
	var high := arena.ceiling_accel(Vector3(0.0, rim + margin + 20.0, 0.0))
	check(low.y < 0.0 and high.y < low.y, "a downward push that grows with height (%.1f, %.1f m/s^2)" % [low.y, high.y])

	# Out of bounds.
	var mid := track.sample(150.0)
	check(not arena.is_out_of_bounds(mid.pos, 150.0), "the centreline is in bounds")
	check(not arena.is_out_of_bounds(mid.pos + mid.up * 15.0, 150.0), "high in the open canyon is in bounds (the ceiling handles it)")
	check(arena.is_out_of_bounds(mid.pos + mid.right * (mid.width * 0.5 + 20.0), 150.0), "beside the channel is out of bounds")
	var tunnel_d := float(CanyonReefTrack.features()["tunnel"])
	var roofed := track.sample(tunnel_d)
	check(not arena.is_out_of_bounds(roofed.pos, tunnel_d), "inside the tunnel is in bounds")
	check(arena.is_out_of_bounds(roofed.pos + roofed.up * (roofed.height * 0.5 * 1.1 + 8.0), tunnel_d), "above the tunnel's roof is out of bounds")

	# A stream pushes along the track inside it, with a speed cap and nothing outside.
	var settings := RaceSettings.shared()
	var stream := arena.streams[0]
	var def := track.streams[0]
	var d_mid := (float(def["d0"]) + float(def["d1"])) * 0.5
	var f := track.sample(d_mid)
	var off: Vector2 = def["offset"]
	var core := f.pos + f.right * off.x + f.up * off.y
	var push := stream.push_for(core, Vector3.ZERO, 1.0, 0.1)
	check(push.dot(f.forward) > 0.0 and absf(push.length() - settings.stream_push * 0.1) < 0.2, "a stream pushes along the track at its core (%.2f m/s per 0.1 s)" % push.length())
	check(stream.push_for(core + f.right * 12.0, Vector3.ZERO, 1.0, 0.1) == Vector3.ZERO, "and not 12 m to the side")
	check(stream.push_for(core, f.forward * (settings.race_top_speed + settings.stream_max_gain + 1.0), 1.0, 0.1) == Vector3.ZERO, "and not past the speed cap")
	check(stream.push_for(core, Vector3.ZERO, 2.0, 0.1).length() > push.length() * 1.9, "grip scales the push")

	arena.queue_free()
	await get_tree().process_frame
	print("race_arena_probe: %s" % ("ok" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(0 if failures == 0 else 1)


## The lane's sideways offset at `d` (m): 11 beside the pillar's span, easing to the centre over 6 m outside it.
func _lane(d: float, s0: float, s1: float) -> float:
	var outside := maxf(maxf(s0 - d, d - s1), 0.0)
	return 11.0 * clampf(1.0 - outside / 6.0, 0.0, 1.0)
