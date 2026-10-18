extends Node
## The run simulator (planning_unnatural.md, "Playability pass" P2): a
## SurvivorBot plays whole Unnatural runs in the real game, headless and as
## fast as the machine goes, and every run's RunLog (a sample a minute: damage
## per second, time to kill, damage taken, level, pearls, chests, builds) is
## gathered into a report: each minute's averages over the runs, the minutes
## when the horde's fill (zombies out over the director's target) is under
## fill_target_min (the build wipes each pack as it comes: too strong), when
## and why the bot went down, and the drops' rates.
## Reported, not pass/fail.
##
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/run_sim.tscn -- --runs 6
##
## Options (after --):
##   --runs N        runs to play (6)
##   --minutes M     a run that lasts this long stops there (20)
##   --fish F        a FishCharacter family or a list (OCTANE,DOMINUS,MERC: in turns; PLANK, BREAKOUT,
##                   HYBRID, MERC), or "all" to take turns (all)
##   --picks P       greedy, random, or mixed (turns) (greedy)
##   --god           the bot can't go down (to see the power curve all run)
##   --seed S        the bot's dice (random)
##   --out NAME      the report's name in user://run_logs/sim/ (sim_<date>)
##   --set K=V,...   tuning for this sim only (UnnaturalSettings or
##                   PowerupSettings names), e.g. --set xp_curve=1.7,pearl_elite_value=1
## --fixed-fps 120 (the physics rate) runs it unhinged from the clock: without
## it the sim only goes at real time.

const SAMPLE_KEYS := ["level", "kills", "dps", "ttk", "avg_hp", "alive", "fill", "taken", "pearls_dropped", "chests_dropped",
		"pearls_taken", "purse", "chests_opened"]

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var options := {"runs": 6, "minutes": 20.0, "fish": "all", "picks": "greedy", "god": false, "seed": -1, "out": "", "set": {}}
var logs: Array[Dictionary] = []
var _bot_picks := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse(OS.get_cmdline_user_args())
	_run.call_deferred()


func _parse(args: PackedStringArray) -> void:
	var n := 0
	while n < args.size():
		var key := args[n].trim_prefix("--")
		var value := args[n + 1] if n + 1 < args.size() else ""
		match key:
			"runs":
				options.runs = maxi(value.to_int(), 1)
				n += 1
			"minutes":
				options.minutes = maxf(value.to_float(), 0.5)
				n += 1
			"fish":
				options.fish = value.to_upper() if value.to_lower() != "all" else "all"
				n += 1
			"picks":
				options.picks = value.to_lower()
				n += 1
			"seed":
				options.seed = value.to_int()
				n += 1
			"out":
				options.out = value
				n += 1
			"god":
				options.god = true
			"set":
				for pair in value.split(",", false):
					var parts := pair.split("=")
					if parts.size() == 2:
						options["set"][parts[0].strip_edges()] = str_to_var(parts[1].strip_edges())
				n += 1
		n += 1


func _run() -> void:
	var was_logging := settings.run_logs
	settings.run_logs = false  # the sim keeps its own
	settings.god_mode = options.god
	for key: String in options["set"]:
		var target: Object = settings if key in settings else (PowerupSettings.shared() if key in PowerupSettings.shared() else null)
		if target == null:
			print("run_sim: no setting called %s" % key)
			continue
		target.set(key, options["set"][key])
		print("run_sim: %s = %s" % [key, str(target.get(key))])
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	var families: Array = FishCharacter.Family.keys()
	print("run_sim: %d runs of up to %.0f min, fish %s, %s picks%s" % [options.runs, options.minutes, options.fish,
			options.picks, ", god mode" if options.god else ""])
	var clock := Time.get_ticks_msec()
	for n in options.runs:
		var listed: PackedStringArray = (options.fish as String).split(",", false)
		var family: int = n % families.size() if options.fish == "all" else maxi(families.find(listed[n % listed.size()]), 0)
		var picks := SurvivorBot.Picks.GREEDY
		if options.picks == "random" or (options.picks == "mixed" and n % 2 == 1):
			picks = SurvivorBot.Picks.RANDOM
		var started := Time.get_ticks_msec()
		var log_entry := await _play(family, picks, n)
		logs.append(log_entry)
		var seconds := (Time.get_ticks_msec() - started) / 1000.0
		var ending: Dictionary = log_entry.ending
		print("  run %d: %s, %s picks: %s at %s, Lv %d, %d kills (%.0fx real time)%s" % [n + 1, families[family],
				"greedy" if picks == SurvivorBot.Picks.GREEDY else "random", ending.outcome, _clock(ending.t), ending.level,
				ending.kills, ending.t / maxf(seconds, 0.01), (", " + ending.cause) if ending.cause != "" else ""])
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	settings.run_logs = was_logging
	settings.god_mode = false
	_report((Time.get_ticks_msec() - clock) / 1000.0)
	get_tree().quit(0)


## One run with the bot as `family`, picking by `picks`: its log, ended.
func _play(family: int, picks: int, n: int) -> Dictionary:
	main.set_mode(main.NATURE)  # the same ocean, so the next Unnatural is a fresh one
	await _ticks(2)
	fish.character = family
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main.play_match()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	var bot := SurvivorBot.new()
	bot.name = "SurvivorBot"
	bot.fish = fish
	bot.run = run
	bot.picks = picks
	bot.process_mode = Node.PROCESS_MODE_PAUSABLE
	if options.seed >= 0:
		bot.rng.seed = options.seed + n
	add_child(bot)
	if options.seed >= 0:
		bot.rng.seed = options.seed + n  # after its _ready's randomize
	var cap: float = options.minutes * 60.0
	while run.run_log.ending.is_empty() and run.elapsed < cap:
		await get_tree().physics_frame
	if run.run_log.ending.is_empty():
		run.run_log.finish("time")
	var entry := run.run_log.to_dict()
	entry["fish"] = FishCharacter.Family.keys()[family]
	entry["picks"] = "greedy" if picks == SurvivorBot.Picks.GREEDY else "random"
	entry["bot_picked"] = bot.picked
	bot.queue_free()
	fish.controls = null
	return entry


## Each minute's averages over the runs still going, the minutes outside the
## target, the deaths and the drops; saved as JSON and CSV.
func _report(seconds: float) -> void:
	var longest := 0
	for entry in logs:
		longest = maxi(longest, (entry.samples as Array).size())
	var lo := settings.fill_target_min
	print("\nper minute (averages over the runs still going):")
	print("  min  runs  level  kills/min    dps     ttk(s)  avg hp  alive  fill  taken/min  pearls/min  chests/min  chests opened  purse")
	var outside := []
	var rows := []
	for m in longest:
		var sums := {}
		var count := 0
		for entry in logs:
			var samples: Array = entry.samples
			if m >= samples.size():
				continue
			count += 1
			var sample: Dictionary = samples[m]
			for key: String in SAMPLE_KEYS:
				sums[key] = sums.get(key, 0.0) + float(sample.get(key, 0.0))
		if count == 0:
			continue
		var mean := {}
		for key: String in SAMPLE_KEYS:
			mean[key] = sums.get(key, 0.0) / count
		var flag := ""
		if m >= 1 and mean.fill < lo:
			flag = "  << wipes the horde as it comes"
			outside.append([m + 1, mean.fill])
		print("  %3d  %4d  %5.1f  %9.0f  %7.0f  %7.2f  %6.0f  %5.0f  %4.2f  %9.0f  %10.1f  %10.2f  %13.1f  %5.0f%s" % [m + 1, count,
				mean.level, mean.kills, mean.dps, mean.ttk, mean.avg_hp, mean.alive, mean.fill, mean.taken, mean.pearls_dropped,
				mean.chests_dropped, mean.chests_opened, mean.purse, flag])
		mean["minute"] = m + 1
		mean["runs"] = count
		rows.append(mean)
	print("\nhorde fill (zombies out / the director's target), flagged under %.2f from minute 2: %s" % [lo, "never under" if outside.is_empty()
			else "%d minute(s) under (the build wipes each pack as it comes): %s" % [outside.size(), ", ".join(outside.map(func(o: Array) -> String: return "min %d (%.2f)" % [o[0], o[1]]))]])
	var downs := []
	var causes := {}
	var outcomes := {}
	for entry in logs:
		var ending: Dictionary = entry.ending
		outcomes[ending.outcome] = outcomes.get(ending.outcome, 0) + 1
		if ending.outcome == "down":
			downs.append(float(ending.t))
			var cause: String = ending.cause if ending.cause != "" else "?"
			causes[cause] = causes.get(cause, 0) + 1
	print("outcomes: %s" % JSON.stringify(outcomes))
	if not downs.is_empty():
		var total := 0.0
		for t: float in downs:
			total += t
		downs.sort()
		print("down at: mean %s, earliest %s, latest %s; causes %s" % [_clock(total / downs.size()), _clock(downs[0]),
				_clock(downs[-1]), JSON.stringify(causes)])
	var picked := {}
	for entry in logs:
		for kind: String in entry.bot_picked:
			picked[kind] = picked.get(kind, 0) + int(entry.bot_picked[kind])
	print("cards picked by kind: %s" % JSON.stringify(picked))
	print("sim time: %.0f s real for %.0f s of runs" % [seconds, _sum_minutes() * 60.0])

	var dir := "%s/sim" % RunLog.DIR
	DirAccess.make_dir_recursive_absolute(dir)
	var stem: String = options.out if options.out != "" else "sim_" + Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var json := FileAccess.open("%s/%s.json" % [dir, stem], FileAccess.WRITE)
	if json:
		json.store_string(JSON.stringify({"options": options, "per_minute": rows, "runs": logs}, "\t"))
		json.close()
	var csv := FileAccess.open("%s/%s.csv" % [dir, stem], FileAccess.WRITE)
	if csv:
		csv.store_line("run,fish,picks,minute," + ",".join(SAMPLE_KEYS))
		for n in logs.size():
			var entry: Dictionary = logs[n]
			for sample: Dictionary in entry.samples:
				var cells := [str(n + 1), entry.fish, entry.picks, str(sample.t)]
				for key: String in SAMPLE_KEYS:
					cells.append(str(sample.get(key, "")))
				csv.store_line(",".join(cells))
		csv.close()
	print("report: %s/%s.json and .csv" % [ProjectSettings.globalize_path(dir), stem])


func _sum_minutes() -> float:
	var total := 0.0
	for entry in logs:
		total += float(entry.minutes)
	return total


static func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
