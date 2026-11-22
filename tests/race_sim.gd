extends Node
## Fin-ish Line with bots only (planning_race.md section 9): the real RaceMatch (rules, streams, wakes, bumps, rescues,
## rubber band) with every racer driven by a RaceBot, the human seat's too. Per racer: place, lap times, rescues per
## lap, and the share of the race spent in a bubble stream or a rival's wake. The human seat's bot also stands in as
## "the leading human" the match's rubber band measures against. Balance numbers from it are open items for a
## play-test (play-test-before-tuning); nothing is retuned here. Keep runs short (feedback-limit-analysis):
##   Godot_console.exe --headless --fixed-fps 60 --path . res://tests/race_sim.tscn
##       [-- --track=grey|canyon --laps=2 --field=8 --tier=easy|normal|hard --max_time=200 --pick=<roster key>
##           --skills=0|1 --rubber=0|1 --bumps=0|1 --timescale=4]
## Timescale above 4 changes physics-step-sensitive classes (Drifter): keep it at 4 or less.

var main: Node
var track_name := "Grey Box"
var laps := 2
var field := 8
var tier := RaceSettings.Bots.NORMAL
var max_time := 200.0
var pick := ""
var skills := true
var rubber := true
var bumps := true
var timescale := 4.0
var trace := 0.0
var map_span := Vector2.ZERO


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=")
		if pair.size() != 2:
			continue
		match pair[0]:
			"track":
				track_name = "Canyon Reef Circuit" if pair[1].begins_with("canyon") else "Grey Box"
			"laps":
				laps = int(pair[1])
			"field":
				field = int(pair[1])
			"tier":
				tier = {"easy": RaceSettings.Bots.EASY, "hard": RaceSettings.Bots.HARD}.get(pair[1], RaceSettings.Bots.NORMAL)
			"max_time":
				max_time = float(pair[1])
			"pick":
				pick = pair[1]
			"skills":
				skills = pair[1] != "0"
			"rubber":
				rubber = pair[1] != "0"
			"bumps":
				bumps = pair[1] != "0"
			"timescale":
				timescale = float(pair[1])
			"trace":
				trace = float(pair[1])
			"map":
				var span := pair[1].split(",")
				map_span = Vector2(float(span[0]), float(span[1]))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	var started := Time.get_ticks_msec()
	RaceBest.persist = false
	RaceMatch.forced_pick = pick if pick != "" else str(RaceRoster.entries()[0]["key"])
	var rs := RaceSettings.shared()
	rs.track = track_name
	rs.laps = laps
	rs.field_size = field
	rs.bot_difficulty = tier
	rs.skills = skills
	rs.bumps = bumps
	rs.countdown = 2.0
	rs.finish_clock = 120.0  # everyone gets to finish: the human seat is a bot too
	if not rubber:
		rs.rubber_easy = 0.0
		rs.rubber_normal = 0.0
		rs.rubber_hard = 0.0
	main.set_mode("race")
	for i in 3:
		await get_tree().physics_frame
	main.play_match()
	for i in 5:
		await get_tree().physics_frame
	var race := main.active_mode() as RaceMatch
	if race == null:
		print("race_sim: the race mode did not start")
		get_tree().quit(1)
		return
	var seat_bots: Array[RaceBot] = []
	for r in race.racers:
		if r.bot != null and r.bot is RaceBot:
			seat_bots.append(r.bot)
		elif r.human:  # the human seat gets a bot too
			var bot := RaceBot.new()
			bot.fish = r.fish
			bot.set("race", race)
			bot.track = race.track
			bot.difficulty = int(tier)
			bot.handling = r.row
			bot.traversal = r.traversal
			bot.name = "SeatBot"
			race.add_child(bot)
			r.bot = bot
			seat_bots.append(bot)
	print("race_sim: %s, lap %.0f m, %d laps, %d racers, tier %s, rubber %s, skills %s, bumps %s" % [race.track.track_name,
			race.track.lap_length, laps, race.racers.size(), RaceSettings.BOT_NAMES[tier], rubber, skills, bumps])
	if map_span != Vector2.ZERO:
		_map(race)
		get_tree().quit(0)
		return
	Engine.time_scale = timescale
	var guard := 0.0
	var next_trace := trace
	while race.phase != RaceMatch.Phase.OVER and guard < max_time:
		await get_tree().physics_frame
		guard += get_physics_process_delta_time()
		if trace > 0.0 and guard >= next_trace:
			next_trace += trace
			_trace(race, guard)
	Engine.time_scale = 1.0
	_report(race)
	print("race_sim: done in %.1f s wall" % ((Time.get_ticks_msec() - started) / 1000.0))
	get_tree().quit(0)


func _report(race: RaceMatch) -> void:
	var time := maxf(race.race_time, 1.0)
	print("race ran %.1f s%s. place, entry, total, laps, rescues per lap, stream share, wake share, skills" % [time,
			"" if race.phase == RaceMatch.Phase.OVER else " (cut short)"])
	var order: Array = race.racers.duplicate()
	order.sort_custom(func(a: RaceMatch.Racer, b: RaceMatch.Racer) -> bool: return a.place < b.place)
	var bests: Array = []
	for r: RaceMatch.Racer in order:
		var lap_text := ", ".join(r.lap_times.map(func(t: float) -> String: return "%.1f" % t))
		var total := "%.1f" % r.finish_time if r.finished else "DNF %.0f%%" % (100.0 * r.progress / (race.track.lap_length * laps))
		var skills_used: int = r.bot.skills_used if r.bot is RaceBot else 0
		print("%d. %-30s %-9s laps [%s]  rescues/lap %.2f  stream %4.1f%%  wake %4.1f%%  skills %d%s" % [r.place,
				str(r.entry["key"]).left(30), total, lap_text, float(r.rescues) / maxf(float(maxi(r.laps, 1)), 1.0),
				100.0 * r.in_stream / time, 100.0 * r.in_slip / time, skills_used, "  (seat)" if r.human else ""])
		if not r.lap_times.is_empty():
			bests.append(r.lap_times.min())
	var sp := RaceSimRig.spread(bests)
	print("best laps: mean %.1f s, min %.1f, max %.1f, spread %.1f percent (target 3 on clean laps; bots carry timing noise)" % [
			sp[0], sp[1], sp[2], sp[3] * 100.0])
	var total_rescues := 0
	for r: RaceMatch.Racer in race.racers:
		total_rescues += r.rescues
	print("rescues in the race: %d" % total_rescues)
	var spots := {}
	for r: RaceMatch.Racer in race.racers:
		if r.bot is RaceBot:
			for d: float in (r.bot as RaceBot).wedges:
				var bin := int(d / 25.0) * 25
				spots[bin] = int(spots.get(bin, 0)) + 1
	var keys := spots.keys()
	keys.sort()
	print("wedged (backed off rock) by 25 m of lap: %s" % ", ".join(keys.map(func(k: int) -> String: return "%d:%d" % [k, spots[k]])))


## --trace=seconds: where every racer is now (distance, speed, sideways offset, rock clearance).
func _trace(race: RaceMatch, time: float) -> void:
	var row: Array[String] = []
	for r in race.racers:
		var fix := race.track.nearest(r.fish.global_position, r.d)
		row.append("%s d%.0f v%.1f lat%.1f clr%.1f" % [str(r.entry["key"]).get_slice("/", 1).left(6), r.progress, r.fish.swim_velocity().length(),
				fix.lateral, Terrain.sdf(r.fish.global_position)])
	print("t %.0f: %s" % [time, " | ".join(row)])


## --map=d0,d1: the channel in cross-section slices from the terrain ('.' open with 3 m clear, 'o' open, '#' rock; the
## centreline is the middle column, left is - and right is +; one row per 5 m along the track).
func _map(race: RaceMatch) -> void:
	var d := map_span.x
	while d <= map_span.y:
		var fix := race.track.sample(d)
		var row := ""
		for lat in range(-20, 21, 2):
			var clear := Terrain.sdf(fix.pos + fix.right * float(lat))
			row += "." if clear >= 3.0 else ("o" if clear >= 0.0 else "#")
		var up_row := ""
		for rise in range(-8, 9, 2):
			var clear := Terrain.sdf(fix.pos + fix.up * float(rise))
			up_row += "." if clear >= 3.0 else ("o" if clear >= 0.0 else "#")
		print("d%4.0f w%4.1f h%4.1f  across %s   up %s" % [d, fix.width, fix.height, row, up_row])
		d += 5.0
