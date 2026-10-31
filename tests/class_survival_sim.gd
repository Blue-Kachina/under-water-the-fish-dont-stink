extends Node
## The class survival sim (planning_bosses_and_survival.md §5): how well each
## class survives, and how much it puts out, with only its main weapon. Each
## run drops a SurvivorBot (MAIN_ONLY: no cards, pearls or chests) into an
## Unnatural run jumped to the minute real runs reach the weapon's level
## (UnnaturalRun.scenario_jump): the clock, the team's level, the attack at
## that level with its milestones, the director held at that minute's target
## and (prefill) the horde already out. It plays `minutes` and records a row:
## survival (time to down, hp lost, damage taken by source, contact time) and
## offence (damage, kills, ttk, overkill, hits, fill, clear ratio). Each class
## x level also gets its weapon sheet (the attack's own numbers) and the
## class's base stats. Two passes: mortal (does it survive) and god (a whole
## minute of offence). tools/survival_report.py reads the CSV.
## Reported, not pass/fail.
##
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/class_survival_sim.tscn -- --fish HUNTER --levels 5,10
##
## Options (after --):
##   --fish F          classes (FishCharacter names, a list) or "all" (all)
##   --levels L        main weapon levels, a list (5,10,15,20); each takes its
##                     conditions from CONDITIONS unless --at etc. say otherwise
##   --passes P        mortal, god or both (mortal,god)
##   --seeds N         runs per class x level x pass (5), seeded seed_base + n
##   --seed_base S     (1)
##   --minutes M       played after the jump (1)
##   --at MIN          the minute to jump to (every level)
##   --player_level N  the team's level (every level)
##   --target N        the director's target alive (every level; 0: its own, unheld)
##   --no_prefill      start with the horde empty (it ramps in as usual)
##   --events          keep the stage events still to come (default: none)
##   --out NAME        files in user://run_logs/survival/ (survival_<date>):
##                     NAME.csv (a row per run), NAME.json (logs, sheets)
##   --set K=V,...     tuning for this sim only, as run_sim's --set
##   --picks P         main_only (the analysis), greedy or random: the bot takes
##                     cards after the jump as run_sim's does (whole-run checks
##                     from a minute on, e.g. a boss item's --set <id>_stacks=1)

## Real runs' medians when the main weapon reached each level (§5a, from
## tools/medians.py): [minute, team level, director's target].
const CONDITIONS := {5: [2.3, 8, 125], 10: [4.8, 16, 395], 15: [8.0, 29, 896], 20: [10.1, 34, 1205]}
const COLUMNS := ["fish", "attack", "weapon_level", "pass", "seed", "at_min", "player_level", "target", "target_end", "survived", "time_to_down",
		"seconds", "max_hp", "hp_lost_per_s", "lowest_hp_share", "taken", "taken_contact", "taken_lunge", "taken_hazard",
		"taken_ranged", "taken_boss", "taken_other", "battered", "battery_damage", "contact_share", "damage", "dps", "kills",
		"kills_per_min", "avg_zombie_hp", "ttk", "overkill_share", "hits", "hits_per_s", "damage_per_hit", "avg_alive",
		"max_alive", "fill", "spawn_rate", "clear_ratio", "spawned", "level_end", "cards_passed", "forced_picks", "real_s"]

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var options := {"fish": "all", "levels": [5, 10, 15, 20], "passes": ["mortal", "god"], "seeds": 5, "seed_base": 1, "minutes": 1.0,
		"at": -1.0, "player_level": -1, "target": -1, "prefill": true, "events": false, "out": "", "set": {}, "picks": "main_only"}
var rows: Array[Dictionary] = []
var logs: Array[Dictionary] = []
## "CLASS:level" -> the weapon sheet; class -> its base stats.
var sheets := {}
var bases := {}

var _run: UnnaturalRun
var _hits := 0
var _hit_amount := 0.0
var _hit_dealt := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse(OS.get_cmdline_user_args())
	_go.call_deferred()


func _parse(args: PackedStringArray) -> void:
	var n := 0
	while n < args.size():
		var key := args[n].trim_prefix("--")
		var value := args[n + 1] if n + 1 < args.size() else ""
		var takes := true
		match key:
			"fish":
				options.fish = value.to_upper() if value.to_lower() != "all" else "all"
			"levels":
				options.levels = Array(value.split(",", false)).map(func(v: String) -> int: return v.to_int())
			"passes":
				options.passes = Array(value.to_lower().split(",", false))
			"seeds":
				options.seeds = maxi(value.to_int(), 1)
			"seed_base":
				options.seed_base = value.to_int()
			"minutes":
				options.minutes = maxf(value.to_float(), 0.1)
			"at":
				options.at = value.to_float()
			"player_level":
				options.player_level = value.to_int()
			"target":
				options.target = value.to_int()
			"out":
				options.out = value
			"picks":
				options.picks = value.to_lower()
			"set":
				for pair in value.split(",", false):
					var parts := pair.split("=")
					if parts.size() == 2:
						options["set"][parts[0].strip_edges()] = str_to_var(parts[1].strip_edges())
			"no_prefill":
				options.prefill = false
				takes = false
			"events":
				options.events = true
				takes = false
			_:
				takes = false
		n += 2 if takes else 1


func _go() -> void:
	var was_logging := settings.run_logs
	settings.run_logs = false  # the sim keeps its own
	for key: String in options["set"]:
		var target: Object = settings if key in settings else (PowerupSettings.shared() if key in PowerupSettings.shared() else null)
		if target == null:
			print("class_survival_sim: no setting called %s" % key)
			continue
		target.set(key, options["set"][key])
		print("class_survival_sim: %s = %s" % [key, str(target.get(key))])
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	var classes: Array = FishCharacter.FishClass.keys()
	var chosen: Array = classes.duplicate() if options.fish == "all" else Array((options.fish as String).split(",", false))
	var total: int = chosen.size() * (options.levels as Array).size() * (options.passes as Array).size() * int(options.seeds)
	print("class_survival_sim: %d runs (%s; Lv %s; %s; %d seeds; %.1f min each%s)" % [total, ",".join(chosen),
			",".join(options.levels.map(func(l: int) -> String: return str(l))), ",".join(options.passes), options.seeds,
			options.minutes, ", prefill" if options.prefill else ""])
	var clock := Time.get_ticks_msec()
	var done := 0
	for class_id: String in chosen:
		var fish_class := classes.find(class_id)
		if fish_class < 0:
			print("class_survival_sim: no class called %s" % class_id)
			continue
		for level: int in options.levels:
			for pass_name: String in options.passes:
				for s in int(options.seeds):
					var row := await _play(fish_class, level, pass_name, int(options.seed_base) + s)
					rows.append(row)
					done += 1
					print("  %3d/%d %-10s Lv %2d %-6s seed %d: %s, %.0f dps, %d kills, clear %.2f, hp lost %.1f/s (%.1fx real time)" % [done,
							total, class_id, level, pass_name, row.seed, ("survived" if row.survived else "down at %.0f s" % row.time_to_down),
							row.dps, row.kills, row.clear_ratio, row.hp_lost_per_s, row.seconds / maxf(row.real_s, 0.01)])
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	settings.run_logs = was_logging
	settings.god_mode = false
	_save((Time.get_ticks_msec() - clock) / 1000.0)
	get_tree().quit(0)


## One run: `fish_class` with its main weapon at `level`, `pass_name` ("mortal"
## or "god"), the bot's dice `dice`. Its CSV row.
func _play(fish_class: int, level: int, pass_name: String, dice: int) -> Dictionary:
	var started_real := Time.get_ticks_msec()
	var conditions: Array = CONDITIONS.get(level, CONDITIONS[20])
	var at_min: float = options.at if options.at >= 0.0 else float(conditions[0])
	var player_level: int = options.player_level if options.player_level > 0 else int(conditions[1])
	var target: int = options.target if options.target >= 0 else int(conditions[2])
	settings.god_mode = pass_name == "god"
	main.set_mode(main.NATURE)  # the same ocean, so the next Unnatural is a fresh one
	await _ticks(2)
	fish.character = fish_class
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main.play_match()
	await _ticks(5)
	_run = main.unnatural_run
	_run.rng.seed = dice * 7919 + level
	_run.scenario_jump(at_min * 60.0, player_level, level, target, options.prefill, options.events)
	var bot := SurvivorBot.new()
	bot.name = "SurvivorBot"
	bot.fish = fish
	bot.run = _run
	bot.picks = {"greedy": SurvivorBot.Picks.GREEDY, "random": SurvivorBot.Picks.RANDOM}.get(options.picks, SurvivorBot.Picks.MAIN_ONLY)
	bot.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bot)
	bot.rng.seed = dice  # after its _ready's randomize
	var class_name_now: String = FishCharacter.FishClass.keys()[fish_class]
	var key := "%s:%d" % [class_name_now, level]
	if not sheets.has(key):
		sheets[key] = _weapon_sheet()
	if not bases.has(class_name_now):
		bases[class_name_now] = _base_stats()
	var health := _run.health_of(fish)
	var max_hp := health.max_hp
	var start := _run.elapsed
	var alive_start := _run.horde.alive_count()
	var target_start := _run.director.target_alive()
	var swarm_start := _run.director.swarm_size()
	var cap: float = start + options.minutes * 60.0
	_hits = 0
	_hit_amount = 0.0
	_hit_dealt = 0.0
	_run.zombie_hit.connect(_on_zombie_hit)
	var frames := 0
	var contact_frames := 0
	var alive_sum := 0.0
	var alive_max := 0
	var fill_sum := 0.0
	var lowest := 1.0
	var hp_sum := 0.0
	var hp_samples := 0
	var next_hp := start
	while _run.run_log.ending.is_empty() and _run.elapsed < cap:
		await get_tree().physics_frame
		frames += 1
		var alive := _run.horde.alive_count()
		alive_sum += alive
		alive_max = maxi(alive_max, alive)
		fill_sum += float(alive) / maxf(_run.director.target_alive(), 1.0)
		lowest = minf(lowest, health.share())
		if _run.horde.query_sphere(fish.global_position, UnnaturalRun.PLAYER_RADIUS).size() > 0:
			contact_frames += 1
		if _run.elapsed >= next_hp:
			next_hp += 1.0
			hp_sum += _run.run_log.average_hp()
			hp_samples += 1
	var survived := _run.run_log.ending.is_empty()
	var seconds := _run.elapsed - start
	if survived:
		_run.run_log.finish("time")
	_run.zombie_hit.disconnect(_on_zombie_hit)
	var stats := _run.stats_of(fish)
	var entry := _run.run_log.to_dict()
	var taken_by: Dictionary = _run.run_log.taken_by
	var sorted := _sort_taken(taken_by)
	var damage: float = stats.damage
	var dps := damage / maxf(seconds, 0.01)
	var avg_hp := hp_sum / maxf(hp_samples, 1)
	# The most the director can send a minute (a pack each spawn_interval), over the minute.
	var spawn_rate := (swarm_start + _run.director.swarm_size()) * 0.5 * 60.0 / maxf(settings.spawn_interval, 0.05)
	var kills_per_min := _run.kills / maxf(seconds / 60.0, 0.01)
	var row := {
		"fish": class_name_now, "attack": FishAttack.title(_run.attack_of(fish).kind), "weapon_level": level, "pass": pass_name,
		"seed": dice, "at_min": at_min, "player_level": player_level, "target": target_start, "target_end": _run.director.target_alive(),
		"survived": survived, "time_to_down": -1.0 if survived else snappedf(seconds, 0.1), "seconds": snappedf(seconds, 0.1),
		"max_hp": snappedf(max_hp, 0.1), "hp_lost_per_s": snappedf(float(stats.taken) / maxf(seconds, 0.01), 0.01),
		"lowest_hp_share": snappedf(lowest, 0.001), "taken": snappedf(float(stats.taken), 0.1),
		"taken_contact": sorted.contact, "taken_lunge": sorted.lunge, "taken_hazard": sorted.hazard,
		"taken_ranged": sorted.ranged, "taken_boss": sorted.boss, "taken_other": sorted.other,
		"battered": int(stats.battered), "battery_damage": snappedf(float((stats.by_source as Dictionary).get("battery", 0.0)), 0.1),
		"contact_share": snappedf(float(contact_frames) / maxf(frames, 1), 0.001), "damage": snappedf(damage, 0.1),
		"dps": snappedf(dps, 0.1), "kills": _run.kills, "kills_per_min": snappedf(kills_per_min, 0.1),
		"avg_zombie_hp": snappedf(avg_hp, 0.1), "ttk": snappedf(avg_hp / dps, 0.001) if dps > 0.0 else -1.0,
		"overkill_share": snappedf(1.0 - _hit_dealt / _hit_amount, 0.001) if _hit_amount > 0.0 else 0.0,
		"hits": _hits, "hits_per_s": snappedf(_hits / maxf(seconds, 0.01), 0.01),
		"damage_per_hit": snappedf(_hit_amount / maxf(_hits, 1), 0.01), "avg_alive": snappedf(alive_sum / maxf(frames, 1), 0.1),
		"max_alive": alive_max, "fill": snappedf(fill_sum / maxf(frames, 1), 0.001), "spawn_rate": snappedf(spawn_rate, 0.1),
		"clear_ratio": snappedf(kills_per_min / maxf(spawn_rate, 0.01), 0.001),
		"spawned": _run.horde.alive_count() - alive_start + _run.kills, "level_end": _run.levels.level,
		"cards_passed": int(bot.picked.get("none", 0)), "forced_picks": int(bot.picked.get("forced", 0)),
		"real_s": snappedf((Time.get_ticks_msec() - started_real) / 1000.0, 0.1),
	}
	entry["row"] = row
	entry["taken_by"] = _rounded(taken_by)
	entry["by_source"] = _rounded(stats.by_source)
	logs.append(entry)
	bot.queue_free()
	fish.controls = null
	settings.god_mode = false
	return row


func _on_zombie_hit(index: int, amount: float, by: FishController, _source: String, _chain: Array) -> void:
	if by != fish or _run.boss_at(index) != null:
		return
	_hits += 1
	_hit_amount += amount
	_hit_dealt += _run.last_hit_dealt


## Damage taken by what hurt (RunLog.taken_by's causes) in the report's kinds:
## contact (a zombie's touch, by kind), lunge (a mantis's punch), hazard (an
## elite's or a cinder's fire, a cloud, a shock, a burst), ranged (bolts),
## boss (a boss by its title) and other.
func _sort_taken(taken_by: Dictionary) -> Dictionary:
	var out := {"contact": 0.0, "lunge": 0.0, "hazard": 0.0, "ranged": 0.0, "boss": 0.0, "other": 0.0}
	var boss_titles := []
	for boss in _run.bosses:
		if is_instance_valid(boss):
			boss_titles.append(boss.title.capitalize())
	for cause: String in taken_by:
		var amount := float(taken_by[cause])
		var lower := cause.to_lower()
		var kind := "contact"
		if "punch" in lower:
			kind = "lunge"
		elif "bolt" in lower:
			kind = "ranged"
		elif "fire" in lower or "cloud" in lower or "shock" in lower or "burst" in lower or "curse" in lower:
			kind = "hazard"
		elif cause in boss_titles:
			kind = "boss"
		elif cause == "?" or cause == "something else":
			kind = "other"
		out[kind] += amount
	for kind: String in out:
		out[kind] = snappedf(out[kind], 0.1)
	return out


## The attack's own numbers at its level now (what weapon_bench reads):
## damage, cooldown, its scales, milestones and facets, and a theoretical dps
## (per hit x hits a second x crits; for a fired attack only: the steady ones
## work on their own timers).
func _weapon_sheet() -> Dictionary:
	var attack := _run.attack_of(fish)
	var block := _run.block_of(fish)
	var crit := 1.0 + block.value("crit_chance") * (0.5 + block.value("crit_damage"))
	var per_hit := attack.damage() * attack.damage_scale * (1.0 + block.value("damage"))
	var steady := attack.own_facets()
	var single := -1.0 if steady else per_hit * attack.attack_speed / maxf(attack.cooldown(), 0.01) * crit
	var shots := 1 + attack.extra_projectiles if FishAttack.kind_uses_stat(attack.kind, "quantity") else 1
	var facets := {}
	for id: String in attack.facets:
		facets[id] = snappedf(float(attack.facets[id]), 0.001)
	return {
		"attack": FishAttack.title(attack.kind), "level": attack.level, "milestones": attack.milestones,
		"damage": snappedf(attack.damage(), 0.01), "damage_per_hit": snappedf(per_hit, 0.01),
		"cooldown": snappedf(attack.cooldown(), 0.001), "attack_speed": snappedf(attack.attack_speed, 0.001),
		"size": snappedf(attack.size_scale, 0.001), "damage_scale": snappedf(attack.damage_scale, 0.001),
		"knock": snappedf(attack.knock_scale, 0.001), "quantity": attack.extra_projectiles,
		"projectile_speed": snappedf(attack.projectile_speed, 0.001), "duration": snappedf(attack.duration_scale, 0.001),
		"reach": snappedf(attack.call("reach"), 0.01) if attack.has_method("reach") else -1.0,
		"crit_chance": snappedf(block.value("crit_chance"), 0.001), "crit_damage": snappedf(block.value("crit_damage"), 0.001),
		"steady": steady, "facets": facets,
		"single_dps": snappedf(single, 0.1), "crowd_dps": snappedf(single * shots, 0.1) if single >= 0.0 else -1.0,
	}


## The class's own numbers (at the scenario's level): max hp, armour, regen,
## top speed, hitbox and its signature stat.
func _base_stats() -> Dictionary:
	var block := _run.block_of(fish)
	var twist := _run.twist_of(fish)
	var signature := StatBlock.signature(fish.character)
	return {
		"max_hp_lv1": settings.base_hp, "armour": snappedf(block.value("armour"), 0.01),
		"regen": snappedf(settings.regen + block.value("regen"), 0.01), "max_speed": snappedf(fish.max_speed, 0.1),
		"batter_speed": snappedf(fish.nature_batter_speed, 0.1),
		"hitbox": [snappedf(fish.hitbox_length, 0.01), snappedf(fish.hitbox_width, 0.01), snappedf(fish.hitbox_height, 0.01)],
		"taken_factor": snappedf(twist.taken_factor(), 0.01) if twist else 1.0,
		"iframe_bonus": snappedf(twist.iframe_bonus(), 0.01) if twist else 0.0,
		"signature": signature,
		"signature_per_level": snappedf(StatBlock.signature_amount(fish.character, settings.signature_steps, settings), 0.001),
	}


func _save(seconds: float) -> void:
	var dir := "%s/survival" % RunLog.DIR
	DirAccess.make_dir_recursive_absolute(dir)
	var stem: String = options.out if options.out != "" else "survival_" + Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var csv := FileAccess.open("%s/%s.csv" % [dir, stem], FileAccess.WRITE)
	if csv:
		csv.store_line(",".join(COLUMNS))
		for row in rows:
			var cells := []
			for column: String in COLUMNS:
				cells.append(str(row.get(column, "")))
			csv.store_line(",".join(cells))
		csv.close()
	var json := FileAccess.open("%s/%s.json" % [dir, stem], FileAccess.WRITE)
	if json:
		json.store_string(JSON.stringify({"options": options, "conditions": CONDITIONS, "sheets": sheets, "bases": bases,
				"runs": logs}, "\t"))
		json.close()
	print("class_survival_sim: %d runs in %.0f s real; %s/%s.csv and .json" % [rows.size(), seconds, ProjectSettings.globalize_path(dir), stem])


static func _rounded(by: Dictionary) -> Dictionary:
	var out := {}
	for key: String in by:
		out[key] = snappedf(float(by[key]), 0.1)
	return out


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
