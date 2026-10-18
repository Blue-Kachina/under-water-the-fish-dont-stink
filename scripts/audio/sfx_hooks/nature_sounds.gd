class_name NatureSounds
extends Node
## Nature's sounds (planning_audio.md §3.6): batteries, pearls (dropping and
## climbing the scale on a streak), points, schools nearby and startled, and the
## lone fish turning up. SfxHooks adds one to every NatureRun. Everything comes
## off the run's signals, which fire on every machine of an online run, so a
## guest hears the same. The target wheel's own sounds are WheelSounds.

## A school this close (m) to a player is heard, the nearest few of them.
const LOOP_RANGE := 70.0
const MAX_LOOPS := 3
## The loops are looked after this often (s).
const LOOP_INTERVAL := 0.25
## Pearls collected this soon (s) after the last one are a streak.
const STREAK_WINDOW := 2.0
## A battery's loudness runs from the battering speed to this much faster (m/s).
const HARD_BEYOND := 20.0
## A school this scared startles.
const SCATTER_ALARM := 0.5
## Points for the quietest and the loudest style sound.
const STYLE_SOFT := 100.0
const STYLE_HARD := 1500.0

var run: NatureRun

var _loops := {}
var _scared := {}
var _since_loops := 0.0
var _streak := 0
var _streak_left := 0.0


func _ready() -> void:
	run = get_parent() as NatureRun
	run.school_fish_battered.connect(_on_school_fish_battered)
	run.battered.connect(_on_target_battered)
	run.battery_confirmed.connect(_on_battery_confirmed)
	run.pearl_collected.connect(_on_pearl_collected)
	run.awarded.connect(_on_awarded)
	run.fish_teleported.connect(_on_fish_teleported)


func _exit_tree() -> void:
	for school: Variant in _loops:
		Sfx.stop_loop(_loops[school])
	_loops.clear()


func _process(delta: float) -> void:
	_streak_left = maxf(_streak_left - delta, 0.0)
	_since_loops += delta
	if _since_loops < LOOP_INTERVAL:
		return
	_since_loops = 0.0
	_update_schools()


## The nearest few schools within earshot have a loop that swells as you near
## and flutters faster when they're scared; a school that startles scatters.
func _update_schools() -> void:
	var near := {}
	var heard: Array[School] = []
	for school in run.schools:
		if not is_instance_valid(school) or school.alive_count() == 0:
			continue
		var gap := _gap_to_players(school.middle())
		if gap < LOOP_RANGE:
			near[school] = gap
			heard.append(school)
		_check_scatter(school)
	heard.sort_custom(func(a: School, b: School) -> bool: return near[a] < near[b])
	heard = heard.slice(0, MAX_LOOPS)
	for gone: Variant in _loops.keys():  # untyped: a wiped-out school may be freed already
		if not is_instance_valid(gone) or not gone in heard:
			Sfx.stop_loop(_loops[gone], 0.5)
			_loops.erase(gone)
	for gone: Variant in _scared.keys():
		if not is_instance_valid(gone):
			_scared.erase(gone)
	for school in heard:
		if not _loops.has(school):
			_loops[school] = Sfx.start_loop("nature/school_loop", school.centre)
		Sfx.set_loop(_loops[school], 1.0 - near[school] / LOOP_RANGE, lerpf(1.0, 1.35, school.alarm))


func _check_scatter(school: School) -> void:
	var scared := school.alarm >= SCATTER_ALARM
	if scared and not _scared.get(school, false):
		Sfx.play_at("nature/school_scatter", school.middle())
	_scared[school] = scared


## The distance to the nearest player on this machine.
func _gap_to_players(point: Vector3) -> float:
	var best := INF
	for fish in run.local_players():
		best = minf(best, fish.global_position.distance_to(point))
	return best


func _on_school_fish_battered(attacker: FishController, _school: School, at: Vector3) -> void:
	Sfx.play_at("nature/battery", at, _hardness(attacker))


func _on_target_battered(attacker: FishController, victim: FishController) -> void:
	Sfx.play_at("nature/battery", victim.global_position, _hardness(attacker))


func _hardness(attacker: FishController) -> float:
	if not is_instance_valid(attacker):
		return 0.5
	return clampf(inverse_lerp(attacker.nature_batter_speed, attacker.nature_batter_speed + HARD_BEYOND, attacker.speed), 0.0, 1.0)


func _on_battery_confirmed(_key: String, _attackers: Array, at: Vector3, pearl_id: int) -> void:
	if pearl_id >= 0:
		Sfx.play_at("nature/pearl_drop", at)


## Each pearl in quick succession climbs a step of the scale.
func _on_pearl_collected(by: FishController) -> void:
	if is_instance_valid(by) and by.puppet:
		return
	_streak = _streak + 1 if _streak_left > 0.0 else 0
	_streak_left = STREAK_WINDOW
	Sfx.play_pitched("nature/pearl", mini(_streak, 7))


## Multis and sprees: the Fish Fry stinger for a double, a climbing one past it,
## and the points' own sound for the bigger awards.
func _on_awarded(event: Dictionary) -> void:
	var by: Variant = event.get("by")
	if is_instance_valid(by) and by.puppet:
		return
	var type: String = event.get("type", "")
	if type == NatureScore.MULTI:
		var chain := int(event.get("chain", 2))
		if chain == 2:
			Sfx.play("battered/fish_fry")
			Sfx.play("voice/fish_fry")
		else:
			Sfx.play_pitched("battered/fish_fry_more", mini(chain - 3, 7))
	if type != NatureScore.BATTERY:
		Sfx.play("nature/style", clampf(inverse_lerp(STYLE_SOFT, STYLE_HARD, float(event.get("points", 0))), 0.0, 1.0))


## The lone fish placed anew (the players' own moves are the fish's reset sound).
func _on_fish_teleported(fish: FishController) -> void:
	if fish == run.target:
		Sfx.play_at("nature/target_respawn", fish.global_position)
