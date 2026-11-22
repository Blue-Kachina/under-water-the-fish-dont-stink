extends Node
## Race laps (planning_race.md probes): throttle-only racers (driven here, not by RaceBot) finish 2 laps of the Grey Box
## in order, every gate passes in order (1 + laps x gates passes), the positions follow the finish order, and a racer
## who skips a gate gets no credit past it (it has to swim round to that gate).
##   Godot_console.exe --headless --path . res://tests/race_lap_probe.tscn

const KIT := preload("res://tests/race_probe_kit.gd")
const LAPS := 2
const TIMEOUT_TICKS := 30000

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
	var race: RaceMatch = await KIT.start(self, main, LAPS, 4)
	check(race != null, "the race mode starts")
	if race == null:
		get_tree().quit(1)
		return
	check(race.racers.size() == 4, "4 racers (%d)" % race.racers.size())
	check(race.phase == RaceMatch.Phase.COUNTDOWN, "countdown first")
	var cheat: RaceMatch.Racer = race.racers[3]
	var cheated := false
	var cheat_next := -1
	var cheat_checked_at := INF
	var cheat_next_held := false
	var ticks := 0
	while race.phase != RaceMatch.Phase.OVER and ticks < TIMEOUT_TICKS:
		await get_tree().physics_frame
		ticks += 1
		for r in race.racers:
			KIT.drive(race, r, 1.0)
		if race.phase == RaceMatch.Phase.RACING and not cheated and race.race_time > 4.0:
			# The cheat jumps past two gates without passing them, and keeps swimming.
			cheated = true
			cheat_next = cheat.next_cp
			KIT.place(race, cheat, float(race.track.checkpoints[cheat_next + 1]["d"]) + 3.0)
			cheat.fish.apply_push(-cheat.fish.global_basis.z * 8.0)
			cheat_checked_at = race.race_time + 6.0
			print("  cheat placed past gate %d with %d passes" % [cheat_next + 1, cheat.passes])
		if race.race_time >= cheat_checked_at and cheat_checked_at != INF:
			cheat_checked_at = INF
			cheat_next_held = cheat.next_cp == cheat_next
			print("  cheat after 6 s: next gate %d (was %d), progress %.0f" % [cheat.next_cp, cheat_next, cheat.progress])
	print("race over after %d ticks (%.1f s)" % [ticks, race.race_time])
	check(race.phase == RaceMatch.Phase.OVER, "the race ends")
	var gates := race.track.checkpoints.size()
	var fastest := INF
	for r in race.racers:
		print("  %s: laps %d, passes %d, finish %.1f s, laps %s, rescues %d" % [r.name, r.laps, r.passes, r.finish_time,
				r.lap_times.map(func(t: float) -> String: return "%.1f" % t), r.rescues])
		# In-order passing means: passes = 1 (the line) + laps x gates + the gates past the line this lap.
		var past_line := r.next_cp - 1 if r.next_cp >= 1 else gates - 1
		check(r.passes == 1 + r.laps * gates + past_line, "%s: passes %d match %d laps and gate %d next" % [r.name, r.passes, r.laps, r.next_cp])
		if r.finished and r != cheat:
			fastest = minf(fastest, r.finish_time)
			check(r.passes == 1 + LAPS * gates and r.lap_times.size() == LAPS, "%s finished %d laps through every gate (%d passes)" % [r.name, LAPS, r.passes])
	check(fastest < INF, "someone finished")
	check(cheat_next_held, "a skipped gate was not passed by swimming on (the cheat still waited for gate %d)" % cheat_next)
	check(not cheat.finished or cheat.finish_time > fastest + 15.0,
			"skipping gates is no shortcut: the cheat had to swim back round to them (finish %.1f s against the fastest %.1f s)" % [cheat.finish_time, fastest])
	var order := race.results
	check(order.size() == 4, "results for all racers")
	var finished_order_ok := true
	var last_time := -1.0
	for row in order:
		if row["finished"]:
			if float(row["time"]) < last_time:
				finished_order_ok = false
			last_time = float(row["time"])
	check(finished_order_ok, "finishers are in time order")
	check(int(order[0]["place"]) == 1, "the winner is place 1")
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)
