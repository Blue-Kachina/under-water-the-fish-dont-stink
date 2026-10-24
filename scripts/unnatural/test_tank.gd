class_name TestTank
extends RefCounted
## Unnatural's shooting range (planning_unnatural.md §8), the Test Tank mode:
## an UnnaturalRun with no director, no contact damage (unless tank_contact)
## and no deaths. Immortal dummies (the Horde's last kind, DUMMY) wait ahead in
## a school-shaped cluster and in lines 10, 20 and 40 m off, still or (with
## tank_slow_walkers) drifting towards the player. A hit that would have
## killed one counts as a kill it would have scored, and its hp starts again.
##
## It logs every hit by source ("bite", "battery", powerups later): total
## damage, damage per second over the last DPS_WINDOW and since the reset,
## hits and would-be kills (sources()). The tuning panel's Test Tank group
## sets the dummies' hp, the team's level and every stat directly, and
## tank_horde keeps that many chasing zombies out (mortal, no contact damage
## unless tank_contact): the perf bench in the game. tank_boss brings in a
## boss (the Drowned Shark or any final boss) to practise on, back again
## tank_boss_respawn s after it's beaten. R resets it all.

## DPS is over this many seconds.
const DPS_WINDOW := 5.0
## The cluster's place ahead of the spawn (m) and its half-size (across, up, along).
const CLUSTER_AHEAD := 22.0
const CLUSTER_SIZE := Vector3(4.0, 2.5, 6.0)
const CLUSTER_COUNT := 40
## The lines: this far ahead (m), this far to the side, this many each.
const LINES := [10.0, 20.0, 40.0]
const LINE_SIDE := 16.0
const LINE_COUNT := 5
## tank_boss's bosses, in its order ("": None), and how far ahead of the spawn they come in (m).
const BOSSES: Array[String] = ["", "miniboss", "boss", "gulper", "whale", "lamprey"]
const BOSS_AHEAD := 45.0
## tank_preset's levels, and what fills the slots, in order.
const PRESET_LEVELS := [0, 5, 10, 20]
const PRESET_WEAPONS: Array[String] = ["attack_greek_fire", "attack_jellyfish_halo", "attack_depth_charges", "attack_remora_buddy",
		"attack_leviathans_coil"]
const PRESET_TOMES: Array[String] = ["teeth", "tides", "reef", "shell", "schools", "kill", "ages", "currents", "fins", "ram",
		"fortune", "pearls"]

var run: UnnaturalRun
## The dummy kind's index in the horde.
var dummy_kind := -1
## Since the last reset (s).
var elapsed := 0.0

## Source -> {"damage", "hits", "kills"}; and the recent hits [time, source, amount].
var _sources := {}
var _recent: Array = []
var _rng := RandomNumberGenerator.new()
## The tank_preset last applied (0 at the start: Off leaves the panel's values be).
var _preset := 0
## The tank_boss out (or due back), and the boss itself (null: none out now).
var _boss_pick := 0
var boss: Boss
## Seconds until a beaten boss comes back (-1: not due).
var _boss_back := -1.0


## Every weapon and tome slot full at `level` (0: all cleared): the weapons'
## level overrides (PowerupSettings) and the tank's stats, as `level` common
## tome cards would give them.
static func apply_preset(level: int, settings: UnnaturalSettings) -> void:
	var powerup_settings := PowerupSettings.shared()
	powerup_settings.attack_level = level
	for n in PRESET_WEAPONS.size():
		var id := PRESET_WEAPONS[n]
		powerup_settings.set(PowerupSettings.STACKS[id], level if n < settings.weapon_slots - 1 else 0)
	for stat: String in StatBlock.STATS:
		settings.set("tank_" + stat, 0.0)
	if level <= 0:
		return
	for n in mini(settings.tome_slots, PRESET_TOMES.size()):
		var given := Tomes.gives(PRESET_TOMES[n], float(level), settings)
		for stat: String in given:
			settings.set("tank_" + stat, float(settings.get("tank_" + stat)) + float(given[stat]))


## The kind the dummies are (appended to the horde's kinds).
static func dummy() -> EnemyKind:
	var kind := EnemyKind.make("dummy", "Dummy", FishCharacter.Family.OCTANE, 1.0, 100.0, 0.0, 0.0, 0.0,
			EnemyKind.Behaviour.CHASE, 999.0, 0.0, Color(0.3, 0.42, 0.55))
	kind.accel = 6.0
	return kind


func _init(tank_run: UnnaturalRun) -> void:
	run = tank_run
	dummy_kind = run.horde.kinds.size() - 1
	_rng.seed = 21


## Back to the start: the dummies in place, the log empty.
func start() -> void:
	elapsed = 0.0
	_sources.clear()
	_recent.clear()
	_apply_dummy_kind()
	var spawn: Transform3D = run.ocean.spawn_transform()
	var ahead := -spawn.basis.z
	var side := spawn.basis.x
	var middle := spawn.origin + ahead * CLUSTER_AHEAD
	for n in CLUSTER_COUNT:
		var p := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
		while p.length_squared() > 1.0:
			p = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
		var at := middle + side * p.x * CLUSTER_SIZE.x + Vector3.UP * p.y * CLUSTER_SIZE.y + ahead * p.z * CLUSTER_SIZE.z
		run.horde.spawn(dummy_kind, at, -ahead, false, true)
	for distance: float in LINES:
		for n in LINE_COUNT:
			var at := spawn.origin + ahead * distance + side * (LINE_SIDE + (n - LINE_COUNT / 2.0) * 2.5)
			run.horde.spawn(dummy_kind, at, -ahead, false, true)
	boss = null  # the run's start cleared it
	_boss_pick = run.settings.tank_boss
	_spawn_boss()


## Every tick: the dummy kind, level and stats from the panel, the chasers topped up.
func update(delta: float) -> void:
	elapsed += delta
	_apply_dummy_kind()
	var settings := run.settings
	if settings.tank_preset != _preset:
		_preset = settings.tank_preset
		apply_preset(PRESET_LEVELS[clampi(_preset, 0, PRESET_LEVELS.size() - 1)], settings)
	if run.levels.level != settings.tank_level:
		run.levels.level = maxi(settings.tank_level, 1)
		for fish in run.players:
			run._apply_stats(fish)
	for fish in run.local_players():
		var block := run.block_of(fish)
		var changed := false
		for id: String in StatBlock.STATS:
			var wanted: float = settings.get("tank_" + id)
			if not is_equal_approx(block.value(id), wanted):
				block.values[id] = wanted
				changed = true
		if changed:
			run._apply_stats(fish)
	var chasers := run.horde.alive_count() - dummy_count()
	var missing := settings.tank_horde - chasers
	if missing > 0 and not run.players.is_empty():
		var around: Vector3 = run.players[0].global_position
		var count := mini(missing, 200)
		run.horde.spawn_pack(_rng.randi_range(0, dummy_kind - 1), count, run.spawn_point(around), 2.0 + sqrt(float(count)))
	elif missing < 0 and not is_instance_valid(boss):  # a boss's brood and summons stay while it's out
		for i in run.horde.alive:
			if missing >= 0:
				break
			if not run.horde.is_immortal(i):
				run.horde.remove(i)
				missing += 1
	var since := elapsed - DPS_WINDOW
	while not _recent.is_empty() and float(_recent[0][0]) < since:
		_recent.pop_front()
	_update_boss(delta)


func dummy_count() -> int:
	return CLUSTER_COUNT + LINES.size() * LINE_COUNT


## A new tank_boss pick swaps the boss out; a beaten one comes back when due.
func _update_boss(delta: float) -> void:
	if run.settings.tank_boss != _boss_pick:
		_boss_pick = run.settings.tank_boss
		_send_boss_away()
		_spawn_boss()
		return
	if _boss_back >= 0.0:
		_boss_back -= delta
		if _boss_back <= 0.0:
			_spawn_boss()


## tank_boss's boss, ahead of the spawn (none for None, or with one out).
func _spawn_boss() -> void:
	_boss_back = -1.0
	var kind := BOSSES[clampi(_boss_pick, 0, BOSSES.size() - 1)]
	if kind == "" or is_instance_valid(boss):
		return
	var settings := run.settings
	var made: Boss = DrownedShark.new() if kind == "miniboss" else UnnaturalRun.make_final_boss(kind)
	var boss_hp := settings.tank_boss_hp
	if boss_hp <= 0.0:
		boss_hp = settings.shark_hp if kind == "miniboss" else settings.leviathan_hp
	var spawn: Transform3D = run.ocean.spawn_transform()
	var at := spawn.origin - spawn.basis.z * BOSS_AHEAD
	var flat := Vector2(at.x - run.centre.x, at.z - run.centre.z)
	var reach := settings.arena_radius - 10.0
	if flat.length() > reach:
		flat = flat.normalized() * maxf(reach, 0.0)
		at = Vector3(run.centre.x + flat.x, at.y, run.centre.z + flat.y)
	at.y = clampf(at.y, run.centre.y + settings.arena_floor + 4.0, run.centre.y + settings.arena_ceiling - 4.0)
	boss = made
	run._add_boss(made, at, boss_hp)


## The boss out now gone at once (a new pick).
func _send_boss_away() -> void:
	_boss_back = -1.0
	if not is_instance_valid(boss):
		boss = null
		return
	run.bosses.erase(boss)
	boss.queue_free()  # its proxies go as it leaves the tree
	boss = null


## A boss beaten in the tank: it's logged (a would-be kill for whatever finished
## it is already in the DPS readout), and comes back after tank_boss_respawn s.
func boss_beaten(beaten: Boss) -> void:
	if beaten != boss:
		return
	boss = null
	if run.settings.tank_boss_respawn > 0.0:
		_boss_back = run.settings.tank_boss_respawn


## A hit by `source` for `amount`.
func log_hit(source: String, amount: float) -> void:
	var line := _line(source)
	line.damage += amount
	line.hits += 1
	_recent.append([elapsed, source, amount])


## A hit by `source` that would have killed a dummy.
func log_kill(source: String) -> void:
	_line(source).kills += 1


## Each source's numbers: [{"source", "damage", "dps", "overall", "hits", "kills"}],
## the biggest first, with "total" last.
func sources() -> Array:
	var recent := {}
	for hit: Array in _recent:
		recent[hit[1]] = recent.get(hit[1], 0.0) + float(hit[2])
	var window := minf(DPS_WINDOW, maxf(elapsed, 0.001))
	var rows := []
	var total := {"source": "total", "damage": 0.0, "dps": 0.0, "overall": 0.0, "hits": 0, "kills": 0}
	for source: String in _sources:
		var line: Dictionary = _sources[source]
		var row := {"source": source, "damage": line.damage, "dps": recent.get(source, 0.0) / window,
				"overall": line.damage / maxf(elapsed, 0.001), "hits": line.hits, "kills": line.kills}
		rows.append(row)
		for key: String in ["damage", "dps", "overall", "hits", "kills"]:
			total[key] += row[key]
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.damage > b.damage)
	rows.append(total)
	return rows


func _line(source: String) -> Dictionary:
	if not _sources.has(source):
		_sources[source] = {"damage": 0.0, "hits": 0, "kills": 0}
	return _sources[source]


func _apply_dummy_kind() -> void:
	var kind := run.horde.kinds[dummy_kind]
	kind.hp = maxf(run.settings.tank_dummy_hp, 1.0)
	kind.speed = run.settings.tank_walk_speed if run.settings.tank_slow_walkers else 0.0
