extends Node
## Canyon Reef Circuit smoke (planning_race.md): the track in the `environments` map builds its arena, a Solo match
## counts down and the bots (RaceBot) drive a lap of it. The human sits on the grid (no input).
##   Godot_console.exe --headless --path . res://tests/race_canyon_smoke.tscn

const TIMEOUT_TICKS := 9000

var main: Node
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	RaceBest.persist = false
	var rs := RaceSettings.shared()
	rs.track = "Canyon Reef Circuit"
	rs.laps = 1
	rs.field_size = 4
	rs.countdown = 1.0
	main.set_mode("race")
	for i in 3:
		await get_tree().physics_frame
	main.play_match()
	for i in 10:
		await get_tree().physics_frame
	var race := main.active_mode() as RaceMatch
	check(race != null, "the race mode starts")
	if race == null:
		get_tree().quit(1)
		return
	check(race.arena is CanyonReefArena, "the arena is the CanyonReefArena (%s)" % race.arena)
	check(race.track != null and race.track.track_name != "", "the track is built (%s, lap %.0f m)" % [race.track.track_name, race.track.lap_length])
	check(race.racers.size() == 4 and race.racers.any(func(r: RaceMatch.Racer) -> bool: return r.bot != null), "4 racers with bot drivers")
	var ticks := 0
	var first_lap := -1.0
	while ticks < TIMEOUT_TICKS and race.phase != RaceMatch.Phase.OVER:
		await get_tree().physics_frame
		ticks += 1
		if first_lap < 0.0:
			for r in race.racers:
				if r.laps >= 1:
					first_lap = race.race_time
	check(race.phase != RaceMatch.Phase.COUNTDOWN, "the countdown ended")
	var best := 0.0
	var rescues := 0
	for r in race.racers:
		best = maxf(best, r.progress)
		rescues += r.rescues
		print("  %s: progress %.0f m, laps %d, rescues %d" % [r.name, r.progress, r.laps, r.rescues])
	check(first_lap > 0.0, "a bot finished the lap (%.1f s)" % first_lap)
	check(best > race.track.lap_length * 0.9, "the bots covered the lap (%.0f of %.0f m)" % [best, race.track.lap_length])
	print("RESULT: %s (%d failures, %d rescues)" % ["PASS" if failures == 0 else "FAIL", failures, rescues])
	get_tree().quit(1 if failures > 0 else 0)
