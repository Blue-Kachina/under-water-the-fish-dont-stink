class_name RunLog
extends Node
## What happened in an Unnatural run, for balancing (planning_unnatural.md,
## "Playability pass" P2): a sample every minute (the team's damage per second,
## time to kill, damage taken, level, pearls, chests, and each player's build),
## every card picked, and how it ended (the cause of death, damage by source).
## UnnaturalRun keeps one (not in the Test Tank) and saves it to
## user://run_logs/ after every sample (so a run cut short keeps what it had)
## and when the run ends, the game closes or quits, if UnnaturalSettings.run_logs
## is on. Only the real game saves (not probes, unless they set save_anywhere).
## The run simulator (tests/run_sim.tscn) reads the same samples.
##
## Time to kill (ttk) is the zombies' average hp out now over the team's damage
## per second that minute: how long the whole build takes to chew through one
## average zombie. Fill is the zombies out over the number the director wants
## out: near 0, the build wipes every pack as it comes (too strong); near 1, the
## horde is full round it.

const DIR := "user://run_logs"

## Where logs go (a probe points it elsewhere, so it never prunes real ones).
static var dir := DIR
## Save outside the real game too (the probes that test saving).
static var save_anywhere := false

var run: UnnaturalRun
var settings := UnnaturalSettings.shared()
## Every minute's sample, oldest first (see _sample()).
var samples: Array[Dictionary] = []
## Every card picked: {"t" (s), "player", "card" (what it was)}.
var picks: Array[Dictionary] = []
## How it ended (empty while it's going): {"t", "outcome" ("down", "won",
## "quit"), "cause", "players": [each one's totals]}.
var ending := {}
## Pearls dropped (their worth) and chests dropped by kills, all run.
var pearls_dropped := 0
var chests_dropped := 0
## When each stage after the first began ({"stage", "t" (s)}), P5.
var stages: Array[Dictionary] = []
## The path it was saved to ("" until saved).
var saved_path := ""

var _started := ""
var _next_sample := 60.0
## The totals at the last sample, for the minute's change.
var _last := {}
## Per player: what last hurt them ("" when nothing has).
var _last_hurt := {}


func _init(owner_run: UnnaturalRun) -> void:
	run = owner_run
	name = "RunLog"


func _ready() -> void:
	run.card_picked.connect(_on_card_picked)


## A fresh log, for a run starting now.
func begin() -> void:
	samples.clear()
	picks.clear()
	ending = {}
	pearls_dropped = 0
	chests_dropped = 0
	saved_path = ""
	stages.clear()
	_started = Time.get_datetime_string_from_system()
	_next_sample = 60.0
	_last = {"damage": 0.0, "taken": 0.0, "kills": 0, "pearls_dropped": 0, "chests_dropped": 0}
	_last_hurt.clear()


func _physics_process(_delta: float) -> void:
	if ending.is_empty() and not run.is_over and run.elapsed >= _next_sample:
		samples.append(_sample(60.0))
		_next_sample += 60.0
		if settings.run_logs and may_save():
			save()  # in progress: a run cut short keeps what it had


## The game closing or quitting mid-run: the log, as quit.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if ending.is_empty() and is_instance_valid(run) and run.elapsed >= 10.0:
			finish("quit")


## Whether this is the real game (its main scene), or a probe allowed to.
func may_save() -> bool:
	if save_anywhere:
		return true
	var scene := get_tree().current_scene if is_inside_tree() else null
	return scene != null and scene.scene_file_path == "res://scenes/main.tscn"


## What hurt `fish` last (its cause of death if it goes down).
func hurt_by(fish: FishController, cause: String) -> void:
	_last_hurt[fish] = cause


## The run reached stage `stage` (P5).
func stage_reached(stage: int) -> void:
	stages.append({"stage": stage, "t": snappedf(run.elapsed, 0.1)})


## The run's over (`outcome`: "down", "won" or "quit"): a last sample for the
## part minute, the totals, and the file (when run_logs is on).
func finish(outcome: String) -> void:
	if not ending.is_empty():
		return
	var part := run.elapsed - (_next_sample - 60.0)
	if part >= 5.0:
		samples.append(_sample(part))
	var players := []
	var cause := ""
	for fish in run.players:
		var stats := run.stats_of(fish)
		var health := run.health_of(fish)
		var died := health != null and health.down
		if died and cause == "":
			cause = _last_hurt.get(fish, "")
		players.append({
			"fish": FishCharacter.FishClass.keys()[fish.character] if fish.character < FishCharacter.FishClass.size() else str(fish.character),
			"kills": stats.kills, "battered": stats.battered, "damage": snappedf(stats.damage, 0.1),
			"by_source": _rounded(stats.by_source), "taken": snappedf(stats.taken, 0.1), "pearls": stats.pearls,
			"chests": stats.get("chests", 0), "bosses": stats.get("bosses", 0), "down": died, "shrines": stats.get("shrines", 0), "rifts": stats.get("rifts", 0),
			"rerolls": stats.get("rerolls", 0), "skips": stats.get("skips", 0), "banished": stats.get("banished", []),
			"build": _build(fish),
		})
	ending = {"t": snappedf(run.elapsed, 0.1), "outcome": outcome, "cause": cause, "level": run.levels.level,
			"kills": run.kills, "pearls_dropped": pearls_dropped, "chests_dropped": chests_dropped, "players": players,
			"stage": run.stage, "stages": stages, "run_length": ["short", "standard", "endless"][clampi(settings.run_length, 0, 2)]}
	if settings.run_logs and may_save():
		save()


## The whole log as one Dictionary (what's saved).
func to_dict() -> Dictionary:
	return {"started": _started, "minutes": snappedf(run.elapsed / 60.0, 0.01), "in_progress": ending.is_empty(), "settings": _settings_snapshot(),
			"samples": samples, "picks": picks, "ending": ending}


## Saves it to user://run_logs/run_<date>.json (the same file all run), keeping
## the newest run_logs_keep.
func save() -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := _started.replace(":", "-").replace("T", "_")
	var path := "%s/run_%s.json" % [dir, stamp]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	saved_path = path
	_prune()
	return path


## A sample over the last `span` seconds.
func _sample(span: float) -> Dictionary:
	var damage := 0.0
	var taken := 0.0
	var pearls := 0
	var purse := 0
	var chests := 0
	var builds := []
	for fish in run.players:
		var stats := run.stats_of(fish)
		damage += stats.damage
		taken += stats.taken
		pearls += stats.pearls
		purse += run.purse_of(fish)
		chests += stats.get("chests", 0)
		builds.append(_build(fish))
	var dps := (damage - float(_last.damage)) / maxf(span, 1.0)
	var hp := _average_hp()
	var sample := {
		"t": snappedf(run.elapsed / 60.0, 0.01),
		"stage": run.stage,
		"level": run.levels.level,
		"kills": run.kills - int(_last.kills),
		"dps": snappedf(dps, 0.1),
		"ttk": snappedf(hp / dps, 0.001) if dps > 0.0 else -1.0,
		"avg_hp": snappedf(hp, 0.1),
		"alive": run.horde.alive_count(),
		"target": run.director.target_alive(),
		"fill": snappedf(float(run.horde.alive_count()) / maxf(run.director.target_alive(), 1.0), 0.01),
		"difficulty": snappedf(run.difficulty(), 0.01),
		"taken": snappedf(taken - float(_last.taken), 0.1),
		"pearls_dropped": pearls_dropped - int(_last.pearls_dropped),
		"chests_dropped": chests_dropped - int(_last.chests_dropped),
		"pearls_taken": pearls,
		"purse": purse,
		"chests_opened": chests,
		"builds": builds,
	}
	_last = {"damage": damage, "taken": taken, "kills": run.kills, "pearls_dropped": pearls_dropped, "chests_dropped": chests_dropped}
	return sample


## The average max hp of the zombies out now (bosses' bodies left out); with
## none out, a plain one's at the difficulty now.
func _average_hp() -> float:
	var total := 0.0
	var count := 0
	for i in run.horde.alive:
		if run.horde.is_proxy(i) or run.horde.is_immortal(i) or run.boss_at(i) != null:
			continue
		total += run.horde.enemy_max_hp(i)
		count += 1
	if count > 0:
		return total / count
	var plain: EnemyKind = run.horde.kinds[0]
	return plain.hp * settings.enemy_hp_scale * settings.hp_growth(run.difficulty())


## `fish`'s weapons and tomes with their levels, and items with their stacks.
func _build(fish: FishController) -> Dictionary:
	var loadout := run.loadout_of(fish)
	var weapons := {}
	for id in loadout.weapons:
		weapons[Weapons.ATTACK + ":" + FishAttack.Kind.keys()[loadout.attack_kind] if id == Weapons.ATTACK else id] = loadout.level(id)
	var tomes := {}
	for id in loadout.tomes:
		tomes[id] = loadout.tome_level(id)
	var items := {}
	for entry: Array in run.powerups_of(fish).items():
		items[entry[0]] = entry[1]
	return {"weapons": weapons, "tomes": tomes, "items": items}


func _on_card_picked(fish: FishController, card: Dictionary) -> void:
	if not ending.is_empty():
		return
	var what := ""
	match card.get("kind", ""):
		"weapon", "new_weapon":
			what = "%s Lv %d" % [card.weapon, card.level]
		"tome", "new_tome":
			what = "%s Lv %d" % [card.tome, card.level]
		"fallback":
			what = "fallback %s" % card.what
		"swap":
			what = "swap %s for %s" % [card.weapon, card.incoming]
		_:
			if card.has("powerup"):
				what = "item %s x%d" % [card.powerup, card.get("stacks", 1)]
	if card.has("tier") and int(card.tier) < Rarity.NAMES.size():
		what += " (%s)" % Rarity.NAMES[int(card.tier)].to_lower()
	picks.append({"t": snappedf(run.elapsed, 0.1), "player": run.players.find(fish), "card": what})


func _settings_snapshot() -> Dictionary:
	var keys := ["pearl_drop_chance", "pearl_elite_value", "boss_pearls", "chest_drop_chance", "chest_count", "chest_interval",
			"chest_cost", "chest_price_base", "chest_price_growth", "weapon_slots", "tome_slots", "card_choices",
			"difficulty_per_minute", "difficulty_hp", "difficulty_hp_curve", "xp_base", "xp_curve", "enemy_hp_scale", "enemy_damage_scale", "base_hp"]
	var snapshot := {}
	for key: String in keys:
		snapshot[key] = settings.get(key)
	return snapshot


## Only the newest run_logs_keep files stay.
func _prune() -> void:
	var names: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.begins_with("run_") and file.ends_with(".json"):
			names.append(file)
	names.sort()
	while names.size() > maxi(settings.run_logs_keep, 1):
		DirAccess.remove_absolute("%s/%s" % [dir, names.pop_front()])


static func _rounded(by_source: Dictionary) -> Dictionary:
	var out := {}
	for source: String in by_source:
		out[source] = snappedf(float(by_source[source]), 0.1)
	return out
