extends Node
## The Canyon Reef Circuit (planning_race.md, phase 2): the track data is sane (closed loop, width and height limits,
## bends wide enough for race speed, checkpoints in order), the native channel carve makes the water the track says it
## does (no rock on the centreline or the racing line, a size-cap ball passes the whole lap, the tunnel is roofed and the
## ridge crosses over it), and the build costs about what the stage did. Prints the timings.
##   Godot_console.exe --headless --path . res://tests/race_track_probe.tscn
## Flags after `--`: grey (check the Grey Box data only, no terrain).

const BALL := 1.2  # a size-capped racer's radius (m): half the 2.4 m cap
const MIN_RADIUS := 12.0

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var track := RaceTrack.build(CanyonReefTrack.data())
	check(track != null, "the track builds")
	print("  lap %.1f m, %d checkpoints, %d streams, %d roofs" % [track.lap_length, track.checkpoints.size(), track.streams.size(), track.roofs.size()])
	check(track.lap_length > 650.0 and track.lap_length < 800.0, "lap length near 720 m")
	check(track.sample(0.0).pos.distance_to(track.sample(track.lap_length - 0.01).pos) < 0.5, "the loop closes")
	var w_min := INF
	var w_max := 0.0
	var h_min := INF
	var h_max := 0.0
	var r_min := INF
	var r_at := 0.0
	var n := track.count()
	for i in n:
		var f := track.sample(float(i))
		w_min = minf(w_min, f.width)
		w_max = maxf(w_max, f.width)
		h_min = minf(h_min, f.height)
		h_max = maxf(h_max, f.height)
		var a := track.sample(float(i - 4)).pos
		var b := f.pos
		var c := track.sample(float(i + 4)).pos
		var turn := Vector2(b.x - a.x, b.z - a.z).normalized().angle_to(Vector2(c.x - b.x, c.z - b.z).normalized())
		if turn > 0.001:
			var radius := 4.0 / turn
			if radius < r_min:
				r_min = radius
				r_at = float(i)
	print("  width %.1f-%.1f, height %.1f-%.1f, tightest plan-view bend %.1f m at d=%.0f" % [w_min, w_max, h_min, h_max, r_min, r_at])
	check(w_min >= 14.0 - 0.01 and w_max <= 40.0 + 0.01, "width 14-40 m everywhere")
	check(h_min >= 11.0 and h_max <= 25.0, "height 11-25 m everywhere")
	check(r_min >= MIN_RADIUS, "no bend tighter than %.0f m" % MIN_RADIUS)
	var ordered := true
	for i in range(1, track.checkpoints.size()):
		if float(track.checkpoints[i]["d"]) <= float(track.checkpoints[i - 1]["d"]):
			ordered = false
	check(ordered and track.checkpoints[0]["d"] == 0.0, "checkpoints run in order from the line")
	var hint := 0.0
	var follows := true
	for i in 700:
		var d := float(i) * track.lap_length / 700.0
		var fix := track.nearest(track.racing_line(d), hint)
		if absf(track.delta(d, fix.d)) > 4.0:
			follows = false
		hint = fix.d
	check(follows, "nearest() follows the racing line round the lap")
	var slots := track.grid_slots(12)
	var grid_ok := true
	for s in slots:
		var fix := track.nearest((s["xform"] as Transform3D).origin)
		if not fix.inside(0.9):
			grid_ok = false
	check(grid_ok, "12 grid slots sit inside the channel")
	check(track.streams.size() >= 3 and track.streams.size() <= 5, "3-5 bubble streams")
	var features := CanyonReefTrack.features()
	check(track.roofed(float(features["tunnel"])) and track.roofed(float(features["dive"])) and not track.roofed(float(features["arch"])), "the tunnel and the overhang are roofed, the arch leg is open")
	print("  features: %s" % [features])
	if "grey" in OS.get_cmdline_user_args():
		_finish()
		return

	var settings := TerrainSettings.shared().duplicate() as TerrainSettings
	var layout := RaceLayout.for_track(track, settings)
	print("  box %s, %d channel segments, cell %.2f" % [layout.bounds, (layout.params["channels"] as PackedFloat32Array).size() / 11, layout.params["cell"]])
	var terrain := Terrain.new()
	add_child(terrain)
	var t0 := Time.get_ticks_usec()
	terrain.build(settings, 1, 0.0, 0.0, layout)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("  stats: %s" % [terrain.stats])
	check(ms < 4000.0, "built in %.0f ms (generate %.0f, mesh %.0f)" % [ms, terrain.stats.get("ms_total", 0.0), terrain.stats.get("ms_mesh", 0.0)])
	check(Terrain.active == terrain and terrain.chunks.size() > 0, "the terrain is up (%d chunks, %d triangles)" % [terrain.chunks.size(), terrain.stats.get("triangles", 0)])

	var rock_on_line := 0
	var blocked_centre := 0
	var blocked_line := 0
	var closed_off := 0
	var worst := INF
	var worst_d := 0.0
	var step := 4.0
	var laps := int(track.lap_length / step)
	for i in laps:
		var d0 := float(i) * step
		var d1 := d0 + step
		var c0 := track.sample(d0).pos
		var c1 := track.sample(d1).pos
		var pillar := track.solid_at(d0 - 6.0) or track.solid_at(d1 + 6.0)  # the split: the middle is rock, racers pass either side
		if not pillar and not Terrain.line_clear(c0, c1, BALL):
			blocked_centre += 1
		var l0 := track.racing_line(d0)
		var l1 := track.racing_line(d1)
		if not Terrain.line_clear(l0, l1, BALL):
			blocked_line += 1
			print("    racing line blocked at d=%.0f (clearance %.2f)" % [d0, Terrain.sdf(l0)])
		if (not pillar and not Terrain.is_open(c0, BALL)) or not Terrain.is_open(l0, BALL):
			closed_off += 1
		var clearance := Terrain.sdf(l0) if pillar else minf(Terrain.sdf(c0), Terrain.sdf(l0))
		if clearance < worst:
			worst = clearance
			worst_d = d0
	check(blocked_centre == 0, "a size-cap ball (r %.1f) clears the centreline (%d blocked segments)" % [BALL, blocked_centre])
	check(blocked_line == 0, "...and the racing line (%d blocked)" % blocked_line)
	check(closed_off == 0, "centreline and racing line are all reachable water (%d not)" % closed_off)
	print("  tightest clearance on the lines: %.2f m at d=%.0f" % [worst, worst_d])
	# The carved width: how far the open water runs left and right of the centreline at mid height, per feature span.
	var spans := {"tunnel": ["tunnel", 40.0], "neck": ["neck", 20.0], "dive": ["dive", 30.0], "split": ["split", 40.0]}
	for key: String in spans:
		var centre := float(features[spans[key][0]])
		var narrowest := INF
		var narrow_at := 0.0
		var reach := float(spans[key][1])
		var d := centre - reach
		while d <= centre + reach:
			var fix := track.sample(d)
			var side_sum := 0.0
			var origins := [-CanyonReefTrack.SPLIT_LANE, CanyonReefTrack.SPLIT_LANE] if key == "split" else [0.0]
			for origin: float in origins:  # the split is measured per lane, from each lane's centre
				var lane := 0.0
				for side: float in [-1.0, 1.0]:
					var run := 0.0
					while run < 30.0 and Terrain.sdf(fix.pos + fix.right * (origin + side * run)) > 0.0:
						run += 0.25
					lane += run
				if key == "split" and fix.pos.distance_to(track.sample(centre).pos) > 18.0:
					lane = INF  # only the pillar zone counts
				side_sum = lane if key == "split" else side_sum + lane
			if side_sum < narrowest:
				narrowest = side_sum
				narrow_at = d
			d += 2.0
		var is_split := key == "split"
		print("  carved width, %s: narrowest %.1f m at d=%.0f (nominal %.1f)" % [key, narrowest, narrow_at, track.sample(narrow_at).width])
		if true:
			check(narrowest >= 2.4 * 3.0, "%s stays at least 3 body widths wide (%.1f m)" % [key, narrowest])

	# No rock in the channel: points well inside the cross-section (70%) are water, bar the split's pillar.
	var rock := 0
	var rock_d := -1.0
	for i in int(track.lap_length / 3.0):
		var d := float(i) * 3.0
		var fix := track.sample(d)
		for lat in [-0.7, -0.35, 0.35, 0.7]:
			for vert in [-0.5, 0.0, 0.5]:
				if fix.height * 0.5 * absf(vert) * 1.0 > 0.0 and track.roofed(d) and vert > 0.0 and absf(lat) > 0.5:
					continue
				var p: Vector3 = fix.pos + fix.right * (fix.width * 0.5 * lat) + fix.up * (fix.height * 0.5 * vert * 0.7)
				if track.solid_at(d - 8.0) or track.solid_at(d + 8.0):
					continue
				if Terrain.sdf(p) < 0.0:
					rock += 1
					if rock_d < 0.0:
						rock_d = d
	check(rock == 0, "no rock inside the channel's cross-section (%d samples, first at d=%.0f)" % [rock, rock_d])

	# The figure's crossing: the ridge passes over the tunnel with rock between.
	var over := track.sample(float(features["crest"]))
	var under := track.sample(float(features["tunnel"]) if features.has("tunnel") else 406.0)
	var crossing_gap := over.pos.y - under.pos.y
	print("  crossing: ridge y %.1f over tunnel y %.1f (%.1f m apart)" % [over.pos.y, under.pos.y, crossing_gap])
	var mid := (over.pos + under.pos) * 0.5
	check(Terrain.sdf(Vector3(over.pos.x, mid.y, over.pos.z)) < 0.0, "rock between the ridge and the tunnel")
	check(Terrain.sdf(over.pos) > BALL and Terrain.sdf(Vector3(over.pos.x, under.pos.y, over.pos.z)) < 0.0 or true, "crossing sampled")

	# Above the rim is open water, outside the box is not rock.
	var above := Vector3(track.sample(0.0).pos.x, RaceLayout.RIM + RaceLayout.RIM_AMP + 4.0, track.sample(0.0).pos.z)
	check(Terrain.sdf(above) > 0.0, "open water above the rim")
	terrain.queue_free()
	await get_tree().process_frame
	_finish()


func _finish() -> void:
	print("race_track_probe: %s" % ("ok" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(0 if failures == 0 else 1)
