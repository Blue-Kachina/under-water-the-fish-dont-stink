extends Node
## How much pressure each final boss puts on a player (planning_bosses_and_survival.md
## §3a): a SurvivorBot (mortal, a fixed mid-run build: its main weapon at
## WEAPON_LEVEL, the team at PLAYER_LEVEL) alone with one final boss (no
## horde, no stage events) for `seconds`, per phase and seed. The boss's hp is
## held in its phase's band (out of a huge max, so the bot's hits never move
## it on). Records, per minute: attacks started (its moves' counters: chomps,
## dives, spits, lashes, lunges, gulps, sucks, bites, locks, grabs), attacks
## landed (hits the player took), damage to the player and grabs; the share of
## time under threat (within `threat` m of any of its parts, in its telegraphed
## lane, held, or hurt in the last HURT_MEMORY s), the longest gap with no
## threat, and the time to its first attack. The Fallen Angel's numbers are
## the target profile (§3d: the others within about ±25% on damage a minute
## and threat uptime, longest gap at most 1.5x the Angel's).
## Reported, not pass/fail.
##
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/boss_pressure_bench.tscn -- --bosses angel,king
##
## Options (after --):
##   --bosses B     king, gulper, whale, lamprey, angel, a list (all)
##   --phases P     1 (circle), 2 (spit), 3 (fury), a list (1,3)
##   --seeds N      runs per boss x phase (5), seeded 1..N
##   --seconds S    per run (90)
##   --threat M     the threat range round its parts (15 m)
##   --fish F       the bot's class (HUNTER)
##   --out NAME     user://run_logs/boss_bench/NAME.csv (boss_pressure_<date>)
##   --set K=V,...  tuning for this bench only, as run_sim's --set
##   --kite         the bot kites instead of hunting (planning_balance_followups.md
##                  §5c): it keeps boss_stalk_range x KITE_SHARE m from the boss's
##                  head (the Whale Fall: its nearest hagfish's), circling, and
##                  swims out of any telegraphed lane it's in or near
##   --kite_share X that share (0.5)

const BOSSES := ["king", "gulper", "whale", "lamprey", "angel"]
## The final boss's run kind -> its name in the table.
const TITLES := {"king": "King of Herrings", "gulper": "Gulper Mother", "whale": "Whale Fall", "lamprey": "Lamprey Queen",
		"angel": "Fallen Angel"}
## The counters a boss keeps of the moves it starts (whichever it has).
## The Whale Fall's strikes are every hagfish strike, hit or miss (its bites only
## the ones that held a player), so bites count only where there are no strikes.
const COUNTERS := ["chomp_count", "dives", "lashes", "lunges", "gulps", "sucks", "strikes", "bites", "locks"]
## The share of hp each phase is held at (BloodLeviathan.take: fury at 1/3, spit at 2/3).
const PHASE_SHARE := {1: 0.9, 2: 0.5, 3: 0.2}
const BOSS_HP := 1.0e9
## The fixed build: the main weapon's level and the team's (real runs' medians at the boss, §5a).
const WEAPON_LEVEL := 20
const PLAYER_LEVEL := 34
## A hit taken counts as under threat this long after (s).
const HURT_MEMORY := 0.5
const COLUMNS := ["boss", "phase", "seed", "seconds", "survived", "attacks_per_min", "landed_per_min", "damage_per_min",
		"threat_share", "longest_gap", "first_attack", "grabs_per_min", "telegraphs_per_min", "fish_speed", "fish_top_speed", "moves"]

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var options := {"bosses": BOSSES.duplicate(), "phases": [1, 3], "seeds": 5, "seconds": 90.0, "threat": 15.0, "fish": "HUNTER",
		"out": "", "set": {}, "kite": false, "kite_share": 0.5}
var rows: Array[Dictionary] = []

var _run: UnnaturalRun
var _landed := 0
var _damage := 0.0
var _last_hurt := -INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse(OS.get_cmdline_user_args())
	_go.call_deferred()


func _parse(args: PackedStringArray) -> void:
	options.kite = "--kite" in args
	for n in args.size() - 1:
		var value := args[n + 1]
		match args[n].trim_prefix("--"):
			"bosses":
				options.bosses = Array(value.to_lower().split(",", false))
			"phases":
				options.phases = Array(value.split(",", false)).map(func(v: String) -> int: return clampi(v.to_int(), 1, 3))
			"seeds":
				options.seeds = maxi(value.to_int(), 1)
			"seconds":
				options.seconds = maxf(value.to_float(), 5.0)
			"threat":
				options.threat = maxf(value.to_float(), 0.0)
			"fish":
				options.fish = value.to_upper()
			"out":
				options.out = value
			"kite_share":
				options.kite_share = maxf(value.to_float(), 0.0)
			"set":
				for pair in value.split(",", false):
					var parts := pair.split("=")
					if parts.size() == 2:
						options["set"][parts[0].strip_edges()] = str_to_var(parts[1].strip_edges())


func _go() -> void:
	var was_logging := settings.run_logs
	var was_spawning := settings.spawning
	var had_events := settings.stage_events
	settings.run_logs = false
	settings.spawning = false  # the boss alone
	settings.stage_events = false
	settings.god_mode = false
	for key: String in options["set"]:
		var target: Object = settings if key in settings else (PowerupSettings.shared() if key in PowerupSettings.shared() else null)
		if target == null:
			print("boss_pressure_bench: no setting called %s" % key)
			continue
		target.set(key, options["set"][key])
		print("boss_pressure_bench: %s = %s" % [key, str(target.get(key))])
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	var fish_class := maxi(FishCharacter.FishClass.keys().find(options.fish), 0)
	print("boss_pressure_bench: %s vs %s, phases %s, %d seeds x %.0f s, threat %.0f m%s" % [options.fish, ",".join(options.bosses),
			",".join(options.phases.map(func(p: int) -> String: return str(p))), options.seeds, options.seconds, options.threat,
			", kiting at %.0f m" % (settings.boss_stalk_range * float(options.kite_share)) if options.kite else ""])
	for kind: String in options.bosses:
		for phase: int in options.phases:
			for s in int(options.seeds):
				var row := await _play(fish_class, kind, phase, s + 1)
				rows.append(row)
				print("  %-16s phase %d seed %d: %4.1f attacks/min, %4.1f landed/min, %5.0f dmg/min, threat %3.0f%%, gap %4.1f s, first %4.1f s, grabs %.1f/min%s" % [
						TITLES.get(kind, kind), phase, s + 1, row.attacks_per_min, row.landed_per_min, row.damage_per_min,
						row.threat_share * 100.0, row.longest_gap, row.first_attack, row.grabs_per_min,
						"" if row.survived else ", down at %.0f s" % row.seconds])
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	settings.run_logs = was_logging
	settings.spawning = was_spawning
	settings.stage_events = had_events
	_report()
	get_tree().quit(0)


func _play(fish_class: int, kind: String, phase: int, dice: int) -> Dictionary:
	main.set_mode(main.NATURE)
	await _ticks(2)
	fish.character = fish_class
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main.play_match()
	await _ticks(5)
	_run = main.unnatural_run
	_run.rng.seed = dice * 104729 + phase
	_build()
	var bot: SurvivorBot = KiteBot.new() if options.kite else SurvivorBot.new()
	bot.name = "SurvivorBot"
	bot.fish = fish
	bot.run = _run
	bot.picks = SurvivorBot.Picks.GREEDY  # nothing to pick: no horde, no XP
	bot.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bot)
	bot.rng.seed = dice
	var boss := UnnaturalRun.make_final_boss(kind)
	_run._add_boss(boss, _run.spawn_point(fish.global_position), BOSS_HP)
	if bot is KiteBot:
		(bot as KiteBot).boss = boss
		(bot as KiteBot).keep = settings.boss_stalk_range * float(options.kite_share)
	var share: float = PHASE_SHARE[phase]
	boss.hp = BOSS_HP * share
	boss.phase = (phase - 1) as BloodLeviathan.Phase
	boss.phase_changed.emit(boss.phase)
	await _ticks(1)
	var counts := {}
	for counter: String in COUNTERS:
		if counter in boss and not (counter == "bites" and "strikes" in boss):
			counts[counter] = int(boss.get(counter))
	var moves := {}
	var spits := [0]
	var on_spit := func(_from: Vector3, _directions: PackedVector3Array) -> void: spits[0] += 1
	boss.spat.connect(on_spit)
	_landed = 0
	_damage = 0.0
	_last_hurt = -INF
	_run.player_hurt.connect(_on_hurt)
	var health := _run.health_of(fish)
	var start := _run.elapsed
	var threat_time := 0.0
	var gap := 0.0
	var longest := 0.0
	var first_attack := -1.0
	var grabs := 0
	var was_held := false
	var telegraphs := 0
	var was_warning := false
	var attacks := 0
	var speed_sum := 0.0
	var top_speed := 0.0
	var ticks := 0
	var delta := 1.0 / Engine.physics_ticks_per_second
	while _run.elapsed - start < options.seconds and not health.down and is_instance_valid(boss):
		await get_tree().physics_frame
		boss.hp = BOSS_HP * share  # held in its phase's band
		var now := _run.elapsed - start
		speed_sum += fish.speed
		top_speed = maxf(top_speed, fish.speed)
		ticks += 1
		var started: int = spits[0]
		spits[0] = 0
		if started > 0:
			moves["spits"] = int(moves.get("spits", 0)) + started
		for counter: String in counts:
			var value := int(boss.get(counter))
			if value > int(counts[counter]):
				moves[counter] = int(moves.get(counter, 0)) + value - int(counts[counter])
				started += value - int(counts[counter])
			counts[counter] = value
		var held := _run.holder_of(fish) == boss
		if held and not was_held:
			grabs += 1
			started += 1
			moves["grabs"] = int(moves.get("grabs", 0)) + 1
		was_held = held
		# Every lane it shows (Boss.telegraphs(): a hagfish's each); a boss from before it has one.
		var lanes: Array = boss.telegraphs() if boss.has_method("telegraphs") else [boss.telegraph()]
		var in_lane := false
		var warning: bool = boss.winding_up()
		for lane: Dictionary in lanes:
			warning = warning or not lane.is_empty()
			in_lane = in_lane or _in_lane(lane)
		if warning and not was_warning:
			telegraphs += 1
		was_warning = warning
		attacks += started
		if first_attack < 0.0 and (started > 0 or warning or _damage > 0.0):
			first_attack = now
		var threat := held or (now - (_last_hurt - start)) <= HURT_MEMORY or in_lane or _near_parts(boss)
		if threat:
			threat_time += delta
			gap = 0.0
		else:
			gap += delta
			longest = maxf(longest, gap)
	var seconds := _run.elapsed - start
	var minutes := maxf(seconds / 60.0, 0.01)
	_run.player_hurt.disconnect(_on_hurt)
	if is_instance_valid(boss):
		boss.spat.disconnect(on_spit)
	bot.queue_free()
	fish.controls = null
	return {
		"boss": TITLES.get(kind, kind), "phase": phase, "seed": dice, "seconds": snappedf(seconds, 0.1), "survived": not health.down,
		"attacks_per_min": snappedf(attacks / minutes, 0.1), "landed_per_min": snappedf(_landed / minutes, 0.1),
		"damage_per_min": snappedf(_damage / minutes, 0.1), "threat_share": snappedf(threat_time / maxf(seconds, 0.01), 0.001),
		"longest_gap": snappedf(longest, 0.1), "first_attack": snappedf(first_attack, 0.1) if first_attack >= 0.0 else -1.0,
		"grabs_per_min": snappedf(grabs / minutes, 0.01), "telegraphs_per_min": snappedf(telegraphs / minutes, 0.1),
		"fish_speed": snappedf(speed_sum / maxi(ticks, 1), 0.1), "fish_top_speed": snappedf(top_speed, 0.1), "moves": moves,
	}


## The fixed mid-run build: the team at PLAYER_LEVEL (each level's max hp and
## signature stat), the main weapon at WEAPON_LEVEL, at full health.
func _build() -> void:
	while _run.levels.level < PLAYER_LEVEL:
		_run.levels.level += 1
		_run.block_of(fish).add(StatBlock.signature(fish.character),
				StatBlock.signature_amount(fish.character, settings.signature_steps, settings))
	var attack := _run.attack_of(fish)
	if attack:
		_run.loadout_of(fish).attack_kind = attack.kind
	_run.loadout_of(fish).add_weapon(Weapons.ATTACK, WEAPON_LEVEL)
	_run._apply_stats(fish)
	_run.health_of(fish).reset(_run.max_hp_of(fish))


func _on_hurt(hurt_fish: FishController, amount: float) -> void:
	if hurt_fish != fish:
		return
	_landed += 1
	_damage += amount
	_last_hurt = _run.elapsed


## Whether the fish is in the boss's telegraphed lane now ({}: none).
func _in_lane(lane: Dictionary) -> bool:
	if lane.is_empty():
		return false
	var from: Vector3 = lane.from
	var dir: Vector3 = lane.dir
	var along := clampf((fish.global_position - from).dot(dir), 0.0, float(lane.length))
	return fish.global_position.distance_to(from + dir * along) <= float(lane.width) * 0.5 + UnnaturalRun.PLAYER_RADIUS


## Whether the fish is within the threat range of any of the boss's parts or its mouth.
func _near_parts(boss: BloodLeviathan) -> bool:
	var reach: float = options.threat
	var at := fish.global_position
	if at.distance_to(boss.mouth_point()) <= reach:
		return true
	for index in boss.parts:
		if _run.horde.is_alive(index) and at.distance_to(_run.horde.enemy_position(index)) - _run.horde.enemy_radius(index) <= reach:
			return true
	return false


## Each boss x phase: the means over the seeds, beside the Angel's (the target profile).
func _report() -> void:
	var cells := {}
	for row in rows:
		var key := "%s|%d" % [row.boss, row.phase]
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(row)
	var means := {}
	for key: String in cells:
		var list: Array = cells[key]
		var mean := {"runs": list.size(), "downs": 0}
		for column: String in ["attacks_per_min", "landed_per_min", "damage_per_min", "threat_share", "longest_gap",
				"first_attack", "grabs_per_min", "telegraphs_per_min", "fish_speed", "fish_top_speed"]:
			var total := 0.0
			for row: Dictionary in list:
				total += float(row[column])
			mean[column] = total / list.size()
		for row: Dictionary in list:
			mean.downs += 0 if row.survived else 1
		means[key] = mean
	print("\nmeans over the seeds (vs the Fallen Angel in the same phase: damage/min and threat within ±25%, gap <= 1.5x):")
	print("  %-16s %5s %8s %8s %8s %7s %7s %7s %7s %5s %11s  %s" % ["boss", "phase", "atk/min", "land/min", "dmg/min", "threat", "gap s",
			"first s", "grab/m", "downs", "speed/top", "vs Angel"])
	for phase: int in options.phases:
		var angel: Dictionary = means.get("%s|%d" % [TITLES.angel, phase], {})
		for kind: String in options.bosses:
			var key := "%s|%d" % [TITLES.get(kind, kind), phase]
			if not means.has(key):
				continue
			var m: Dictionary = means[key]
			var verdict := "-"
			if not angel.is_empty() and kind != "angel":
				var notes := []
				var damage_ratio: float = m.damage_per_min / maxf(angel.damage_per_min, 0.01)
				var threat_ratio: float = m.threat_share / maxf(angel.threat_share, 0.001)
				var gap_ratio: float = m.longest_gap / maxf(angel.longest_gap, 0.01)
				notes.append("dmg %.2fx%s" % [damage_ratio, "" if absf(damage_ratio - 1.0) <= 0.25 else " !"])
				notes.append("threat %.2fx%s" % [threat_ratio, "" if absf(threat_ratio - 1.0) <= 0.25 else " !"])
				notes.append("gap %.2fx%s" % [gap_ratio, "" if gap_ratio <= 1.5 else " !"])
				verdict = ", ".join(notes)
			elif kind == "angel":
				verdict = "target"
			print("  %-16s %5d %8.1f %8.1f %8.0f %6.0f%% %7.1f %7.1f %7.2f %5d %5.1f/%5.1f  %s" % [TITLES.get(kind, kind), phase,
					m.attacks_per_min, m.landed_per_min, m.damage_per_min, m.threat_share * 100.0, m.longest_gap, m.first_attack,
					m.grabs_per_min, m.downs, m.fish_speed, m.fish_top_speed, verdict])
	var dir := "%s/boss_bench" % RunLog.DIR
	DirAccess.make_dir_recursive_absolute(dir)
	var stem: String = options.out if options.out != "" else "boss_pressure_" + Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var csv := FileAccess.open("%s/%s.csv" % [dir, stem], FileAccess.WRITE)
	if csv:
		csv.store_line(",".join(COLUMNS))
		for row in rows:
			var line := []
			for column: String in COLUMNS:
				var value: Variant = row.get(column, "")
				line.append(JSON.stringify(value).replace(",", ";") if value is Dictionary else str(value))
			csv.store_line(",".join(line))
		csv.close()
	print("saved %s/%s.csv" % [ProjectSettings.globalize_path(dir), stem])


## --kite: a SurvivorBot that keeps `keep` m from the boss's head, circling it,
## and swims straight out of any telegraphed lane it's in or near (LANE_MARGIN m).
class KiteBot extends SurvivorBot:
	const LANE_MARGIN := 4.0
	## How far ahead round the ring it aims (rad).
	const LEAD := 0.6

	var boss: BloodLeviathan
	var keep := 22.5

	func _choose_goal() -> Vector3:
		_holding = false
		if not is_instance_valid(boss):
			return super()
		var me := fish.global_position
		var dodge := _out_of_lanes(me)
		if dodge != Vector3.INF:
			return _keep_in(dodge)
		var head := _head()
		var offset := me - head
		offset.y *= 0.5  # mostly round it, not over it
		var out := offset.normalized() if offset.length() > 0.5 else Vector3.BACK
		var around := out.cross(Vector3.UP)
		if around.length() < 0.1:
			around = Vector3.RIGHT
		var on_ring := (out * cos(LEAD) + around.normalized() * _kite_sign * sin(LEAD)).normalized()
		var goal := head + on_ring * keep
		# The other zombies (butterflies, loose hagfish) push it off, as SurvivorBot.
		var away := Vector3.ZERO
		for i in run.horde.query_sphere(me, DANGER_RANGE):
			if i in boss.parts:
				continue
			var from := me - run.horde.enemy_position(i)
			var gap := maxf(from.length() - run.horde.enemy_radius(i), 0.5)
			away += from.normalized() / (gap * gap)
		if away.length() > 0.0:
			var push := clampf(away.length() * 8.0, 0.0, 1.0)
			goal = me + ((goal - me).normalized() * (1.0 - push) + away.normalized() * push).normalized() * maxf(me.distance_to(goal), 15.0)
		var kept := _keep_in(goal)
		if kept.distance_to(goal) > 5.0 and rng.randf() < 0.02:
			_kite_sign = -_kite_sign  # pinned at the edge: go round the other way
		return kept

	## The boss's head; the Whale Fall's carcass stays put, so its nearest hagfish's.
	func _head() -> Vector3:
		var head := boss.mouth_point()
		if "hagfish" in boss:
			var best := INF
			for h: Variant in boss.get("hagfish"):
				if h.alive and fish.global_position.distance_to(h.head) < best:
					best = fish.global_position.distance_to(h.head)
					head = h.head
		return head

	## A goal straight out of the nearest telegraphed lane it's in or near (INF: none).
	func _out_of_lanes(me: Vector3) -> Vector3:
		for lane: Dictionary in boss.telegraphs():
			var from: Vector3 = lane.from
			var dir: Vector3 = lane.dir
			var along := clampf((me - from).dot(dir), 0.0, float(lane.length))
			var side := me - (from + dir * along)
			if side.length() > float(lane.width) * 0.5 + UnnaturalRun.PLAYER_RADIUS + LANE_MARGIN:
				continue
			side -= dir * side.dot(dir)
			if side.length() < 0.1:
				side = dir.cross(Vector3.UP) * _kite_sign
				if side.length() < 0.1:
					side = Vector3.RIGHT
			return me + side.normalized() * 20.0
		return Vector3.INF


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
