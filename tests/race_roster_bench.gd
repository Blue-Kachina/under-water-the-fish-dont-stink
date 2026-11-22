extends Node
## Fin-ish Line balance bench (planning_race.md section 3 and 9): every roster entry laps the course alone, driven by an
## ideal RaceBot (perfect stride timing, no steering noise, the racing line exactly), from a flying start, and the lap
## times are compared: the target is a spread of about 3% or less on a clean lap. The numbers are open items for a
## play-test (play-test-before-tuning); nothing is retuned from them here.
##   Godot_console.exe --headless --fixed-fps 60 --path . res://tests/race_roster_bench.tscn
##       [-- --track=grey|canyon --family=fish|hunter|titan --limit=20 --skip_skins=1 --skills=0|1 --timescale=4
##           --max_time=120]
## Keep timescale at 4 or less: at 8 the Drifter laps 25% slower (a physics-step artefact, not its handling).
## `skip_skins` keeps one entry per (family, class, species) instead of every Titan skin (skins share a body).

var main: Node
var track_name := "grey"
var family := ""
var limit := 0
var skip_skins := true
var skills := true
var timescale := 4.0
var max_time := 120.0
## Speed the flying start gives (m/s).
var start_speed := 12.0
## Ideal driving (perfect timing, no noise); off: the HARD tier's timing and noise.
var ideal := true


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=")
		if pair.size() != 2:
			continue
		match pair[0]:
			"track":
				track_name = pair[1]
			"family":
				family = pair[1]
			"limit":
				limit = int(pair[1])
			"skip_skins":
				skip_skins = pair[1] != "0"
			"skills":
				skills = pair[1] != "0"
			"timescale":
				timescale = float(pair[1])
			"ideal":
				ideal = pair[1] != "0"
			"max_time":
				max_time = float(pair[1])
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean")
	main.get_node("DebugPanel").load_mode_preset(main.NATURE_PRESET)
	_run.call_deferred()


func _run() -> void:
	var started := Time.get_ticks_msec()
	RaceSettings.shared().skills = skills
	main.get_node("Fish").visible = false
	Engine.time_scale = timescale
	var entries: Array[Dictionary] = []
	var seen := {}
	for e in RaceRoster.entries():
		if family != "" and e["family"] != family:
			continue
		var body := "%s/%s/%s" % [e["family"], e["class"], e["species"]]
		if skip_skins and seen.has(body):
			continue
		seen[body] = true
		entries.append(e)
		if limit > 0 and entries.size() >= limit:
			break
	print("race_roster_bench: %d entries, track %s, shared speed %.1f m/s" % [entries.size(), track_name,
			RaceSettings.shared().race_top_speed])
	var rows: Array = []
	for e in entries:
		rows.append(await _lap(e))
	Engine.time_scale = 1.0
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	var times: Array = []
	for r: Dictionary in rows:
		times.append(r["time"])
		print("%-36s lap %6.2f s  avg %5.1f m/s  rescues %d  skills %d  stream %4.1f%%  (turn %.2f coast %.2f)" % [
				str(r["key"]).left(36), r["time"], r["avg"], r["rescues"], r["skills"], r["stream"], r["turn"], r["coast"]])
	var clean: Array = rows.filter(func(r: Dictionary) -> bool: return r["rescues"] == 0 and r["time"] > 0.0)
	var sp := RaceSimRig.spread(clean.map(func(r: Dictionary) -> float: return r["time"]))
	print("clean laps (%d of %d): mean %.2f s, fastest %.2f, slowest %.2f, spread %.1f%% (target 3 percent or less)" % [clean.size(),
			rows.size(), sp[0], sp[1], sp[2], sp[3] * 100.0])
	print("race_roster_bench: done in %.1f s wall" % ((Time.get_ticks_msec() - started) / 1000.0))
	get_tree().quit(0)


## One entry's flying lap alone: the time from the line to the line again (0 when it never gets round).
func _lap(entry: Dictionary) -> Dictionary:
	var rig := RaceSimRig.new(main, self)
	rig.build_track(track_name)
	var start_fix := rig.track.sample(0.0)
	var slot := {"xform": Transform3D(Basis(start_fix.right, start_fix.up, -start_fix.forward), rig.track.racing_line(0.0))}
	var r := rig.add(entry, slot, RaceSettings.Bots.HARD, ideal)
	r.fish.linear_velocity = start_fix.forward * start_speed
	r.bot.go = true
	var time := 0.0
	while time < max_time:
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		time += delta
		rig.tick(delta, time, 1)
		if r.laps_done >= 1:
			break
	var out := {"key": entry["key"], "time": r.lap_times[0] if r.laps_done >= 1 else 0.0, "rescues": r.rescues,
			"skills": r.bot.skills_used, "turn": r.row["turn_scale"], "coast": r.row["coast"],
			"avg": rig.track.lap_length / maxf(time, 0.001), "stream": 100.0 * r.bot.stream_time / maxf(time, 1.0)}
	if r.laps_done < 1:
		out["time"] = 0.0
		out["avg"] = r.bot.lap_progress / maxf(time, 0.001)
	r.bot.queue_free()
	r.fish.queue_free()
	await get_tree().physics_frame
	return out
