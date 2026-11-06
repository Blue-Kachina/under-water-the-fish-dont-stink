extends Node
## Every weapon's power curve (planning_unnatural.md, "Playability pass" P2):
## the Test Tank's dummies (immortal, drifting toward the fish, so they crowd
## like a horde) and the fish swimming slow circles round them, every weapon at
## Lv 1, 5, 10, 15 and 20 (no tomes, no items). Each level is played once per
## fish attack (the attacks' own curves), with the five powerup weapons on as
## well; each source's damage per second is its damage over the time.
## Reported, not pass/fail: the table to level the weapons against each other.
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/weapon_bench.tscn [-- --seconds 8 --set K=V,... --out NAME --spread]
## --spread: the dummies hold still, scattered SPREAD_RADIUS m round instead of
## in one tight cluster, and the whole field drifts (DRIFT_SPEED m/s, turning
## DRIFT_TURN rad/s) with the fish's circle following it. A tight, still
## cluster lets area weapons (Purple Haze) cover it all at Lv 1; spread out,
## bigger and more clouds have more to find.
## --out also saves the table as user://run_logs/survival/NAME.csv (source, level, dps), for
## tools/survival_report.py to cross-check the class survival sim against.

const LEVELS := [1, 5, 10, 15, 20]
const KINDS := [FishAttack.Kind.STING, FishAttack.Kind.BITE, FishAttack.Kind.LASH, FishAttack.Kind.THRUST,
		FishAttack.Kind.BUBBLES, FishAttack.Kind.SPINES, FishAttack.Kind.PUNCH]
## The circle the fish swims round the cluster (m) and how fast (m/s).
const CIRCLE := 6.0
const SWIM := 8.0
## --spread's field: its radius and half-height (m), and its drift.
const SPREAD_RADIUS := 14.0
const SPREAD_HEIGHT := 2.5
const DRIFT_SPEED := 1.0
const DRIFT_TURN := 0.12

var main: Node
var fish: FishController
var seconds := 8.0
var overrides := {}
var out := ""
var spread := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	spread = args.has("--spread")
	for n in args.size() - 1:
		if args[n] == "--out":
			out = args[n + 1]
		elif args[n] == "--seconds":
			seconds = maxf(args[n + 1].to_float(), 1.0)
		elif args[n] == "--set":
			for pair in args[n + 1].split(",", false):
				var parts := pair.split("=")
				if parts.size() == 2:
					overrides[parts[0].strip_edges()] = str_to_var(parts[1].strip_edges())
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	var powerups := PowerupSettings.shared()
	for key: String in overrides:
		var target: Object = settings if key in settings else (powerups if key in powerups else null)
		if target:
			target.set(key, overrides[key])
			print("weapon_bench: %s = %s" % [key, str(target.get(key))])
	settings.twists = false
	settings.weapon_slots = 6
	settings.tome_slots = 0
	settings.tank_horde = 0
	settings.tank_contact = false
	settings.tank_slow_walkers = not spread
	settings.tank_preset = 0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	fish.character = FishCharacter.FishClass.HUNTER
	main.set_mode(main.TEST_TANK)
	await _ticks(3)
	main.play_match()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	var spawn: Transform3D = run.ocean.spawn_transform()
	var middle := spawn.origin - spawn.basis.z * TestTank.CLUSTER_AHEAD
	# source -> level -> [dps, ...] (the powerups get one per attack played).
	var table := {}
	for level: int in LEVELS:
		for kind: int in KINDS:
			settings.fish_attack = kind
			TestTank.apply_preset(level, settings)
			await _ticks(3)
			run.start()
			await _ticks(2)
			var centre := middle
			var rng := RandomNumberGenerator.new()
			rng.seed = 7  # the same field at every level
			if spread:
				_scatter(run.horde, centre, rng)
			var turn := 0.0
			for n in roundi(seconds * 120.0):
				turn += SWIM / CIRCLE / 120.0
				if spread:
					var drift := Vector3.FORWARD.rotated(Vector3.UP, n * DRIFT_TURN / 120.0) * DRIFT_SPEED / 120.0
					centre += drift
					for i in run.horde.alive:
						if run.horde.is_immortal(i):
							run.horde.place(i, run.horde.enemy_position(i) + drift)
				var want := centre + Vector3(cos(turn), 0.0, sin(turn)) * CIRCLE
				var tangent := Vector3(-sin(turn), 0.0, cos(turn))
				fish.linear_velocity = tangent * SWIM + (want - fish.global_position) * 3.0
				await get_tree().physics_frame
			for row: Dictionary in run.tank.sources():
				var source: String = row.source
				if source == "total" or source == "battery":
					continue
				if not table.has(source):
					table[source] = {}
				if not (table[source] as Dictionary).has(level):
					table[source][level] = []
				(table[source][level] as Array).append(float(row.overall))
		print("  Lv %d done" % level)
	TestTank.apply_preset(0, settings)
	settings.weapon_slots = 2
	settings.tome_slots = 2

	print("\ndamage per second on the crowd, by level (powerups: the mean over the six attacks' runs):")
	var head := "  %-16s" % "source"
	for level: int in LEVELS:
		head += "  Lv %-6d" % level
	print(head + "  x(1->20)")
	var sources: Array = table.keys()
	sources.sort()
	var csv: FileAccess = null
	if out != "":
		DirAccess.make_dir_recursive_absolute(RunLog.DIR + "/survival")
		csv = FileAccess.open("%s/survival/%s.csv" % [RunLog.DIR, out], FileAccess.WRITE)
		if csv:
			csv.store_line("source,level,dps")
	for source: String in sources:
		var line := "  %-16s" % source
		var first := 0.0
		var last := 0.0
		for level: int in LEVELS:
			var values: Array = table[source].get(level, [])
			var mean := 0.0
			for v: float in values:
				mean += v
			mean /= maxf(values.size(), 1.0)
			first = mean if level == LEVELS[0] else first
			last = mean
			line += "  %9.0f" % mean
			if csv:
				csv.store_line("%s,%d,%.1f" % [source, level, mean])
		print(line + "  %7.1f" % (last / maxf(first, 0.01)))
	if csv:
		csv.close()
		print("saved %s/survival/%s.csv" % [ProjectSettings.globalize_path(RunLog.DIR), out])
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	get_tree().quit(0)


## --spread: every dummy to a random spot in a flat disc SPREAD_RADIUS m round `centre`.
func _scatter(horde: Horde, centre: Vector3, rng: RandomNumberGenerator) -> void:
	for i in horde.alive:
		if not horde.is_immortal(i):
			continue
		var out := Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * SPREAD_RADIUS * sqrt(rng.randf())
		horde.relocate(i, centre + out + Vector3.UP * rng.randf_range(-SPREAD_HEIGHT, SPREAD_HEIGHT))


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
