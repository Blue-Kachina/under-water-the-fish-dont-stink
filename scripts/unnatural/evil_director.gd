class_name EvilDirector
extends RefCounted
## Decides what spawns in Unnatural and when (planning_unnatural.md §4), on the
## authority only: a Left 4 Dead style director for a survivors game, a
## time-driven baseline bent by how the players are doing.
##
## The baseline: base_alive + alive_per_minute * minutes ^ alive_curve
## zombies, times 1 + coop_scale per extra player. Bent by:
## - pressure: mowing through them too easily (a high kill rate over the last
##   KILL_WINDOW seconds while intensity is low) raises a multiplier on it, up
##   to pressure_max; a hard time lowers it, down to pressure_min;
## - intensity: the share of their max hp the players lost recently
##   (on_damage()), fading over time. At relief_intensity it holds off new
##   packs for relief_time, a breather, so the run has peaks and valleys
##   rather than a flat ramp.
## While there are fewer than the target it sends packs of swarm_size() at most
## every spawn_interval, from a point out of every player's view
## (UnnaturalRun.spawn_point()). The kinds are a weighted mix of those unlocked
## by now (EnemyKind.unlock_minute), each zombie elite by elite_chance(). While
## `hushed` (a stage event coming: StageTimeline.hushed()) it sends none; after
## the Leviathan enrages, `escalation` multiplies the target too. Once the final
## boss falls, `cleared` sends packs cleared_spawn_rate times as often, and
## cleared_alive_scale more of them.

## Kills over this many seconds make the kill rate.
const KILL_WINDOW := 10.0
## Inputs are read this often (s).
const READ_INTERVAL := 1.0

var settings: UnnaturalSettings
var horde: Horde
var rng: RandomNumberGenerator
## Returns a spawn point near the players: (around: Vector3) -> Vector3.
var spawn_point: Callable
## Run time (s) and players up in the run, set by the run each tick.
var elapsed := 0.0
var players := 1
## No packs while set (a stage event is close), and a multiplier on the target (enraged).
var hushed := false
var escalation := 1.0
## The final boss is beaten (the whirlpool's open): packs come faster.
var cleared := false
## Seconds until the next pack may come, and packs sent so far.
var next_pack := 0.0
var packs := 0
## The multiplier on the baseline (see the class description).
var pressure := 1.0
## Recent damage, as a share of max hp (fading).
var intensity := 0.0
## Seconds left of a breather (no new packs).
var relief_left := 0.0
## Breathers so far.
var reliefs := 0

var _kill_times := PackedFloat32Array()
var _read_left := 0.0


func _init(director_settings: UnnaturalSettings, director_horde: Horde, dice: RandomNumberGenerator) -> void:
	settings = director_settings
	horde = director_horde
	rng = dice


func reset() -> void:
	elapsed = 0.0
	next_pack = 0.0
	packs = 0
	pressure = 1.0
	intensity = 0.0
	relief_left = 0.0
	reliefs = 0
	hushed = false
	escalation = 1.0
	cleared = false
	_kill_times.clear()
	_read_left = READ_INTERVAL


func minutes() -> float:
	return elapsed / 60.0


## A zombie killed (by anyone).
func on_kill() -> void:
	_kill_times.append(elapsed)


## A player lost `share` of their max hp.
func on_damage(share: float) -> void:
	intensity += maxf(share, 0.0)
	_check_relief()


## A breather once intensity reaches relief_intensity (not during one).
func _check_relief() -> void:
	if settings.relief_time > 0.0 and settings.relief_intensity > 0.0 and intensity >= settings.relief_intensity and not in_relief():
		relief_left = settings.relief_time
		reliefs += 1
		intensity *= 0.5  # the breather counts down from here


## Kills a second over the last KILL_WINDOW.
func kill_rate() -> float:
	var since := elapsed - KILL_WINDOW
	var count := 0
	for t in _kill_times:
		if t >= since:
			count += 1
	return count / minf(KILL_WINDOW, maxf(elapsed, 1.0))


## The baseline before pressure.
func baseline() -> float:
	var base := settings.base_alive + settings.alive_per_minute * pow(minutes(), settings.alive_curve)
	return base * (1.0 + settings.coop_scale * maxi(players - 1, 0))


## How many zombies it wants out now.
func target_alive() -> int:
	var after := settings.cleared_alive_scale if cleared else 1.0
	return mini(roundi(baseline() * pressure * escalation * after), horde.capacity)


## How big a pack is now.
func swarm_size() -> int:
	return maxi(roundi(settings.swarm_base + settings.swarm_per_minute * minutes()), 1)


## The chance each new zombie is elite now.
func elite_chance() -> float:
	return clampf(settings.elite_chance + settings.elite_per_minute * minutes(), 0.0, 1.0)


func in_relief() -> bool:
	return relief_left > 0.0


## One tick: reads how the players are doing every READ_INTERVAL, then sends
## a pack near a player (`around`: the positions of those up) if it's time,
## there's no breather on and the horde is short.
func update(delta: float, around: PackedVector3Array) -> void:
	intensity = maxf(intensity - settings.intensity_fade * intensity * delta - 0.01 * delta, 0.0)
	relief_left = maxf(relief_left - delta, 0.0)
	_read_left -= delta
	if _read_left <= 0.0:
		_read_left = READ_INTERVAL
		_read()
	next_pack -= delta
	if not settings.spawning or around.is_empty() or next_pack > 0.0 or in_relief() or hushed:
		return
	var missing := target_alive() - horde.alive_count()
	if missing <= 0:
		return
	next_pack = settings.spawn_interval / (maxf(settings.cleared_spawn_rate, 0.05) if cleared else 1.0)
	var kind := pick_kind()
	var count := mini(swarm_size() * (2 if horde.kinds[kind].behaviour == EnemyKind.Behaviour.SWARM else 1), missing)
	var near := around[rng.randi_range(0, around.size() - 1)]
	var at: Vector3 = spawn_point.call(near)
	var heading := (near - at).normalized()
	horde.spawn_pack(kind, count, at, 1.5 + sqrt(float(count)) * 0.6, heading, elite_chance())
	packs += 1


## Pressure and breathers from the kill rate and intensity.
func _read() -> void:
	var since := elapsed - KILL_WINDOW
	while not _kill_times.is_empty() and _kill_times[0] < since:
		_kill_times.remove_at(0)
	_check_relief()
	var easy := kill_rate() / maxi(players, 1) >= settings.easy_kill_rate and intensity < settings.calm_intensity
	if easy:
		pressure = minf(pressure + settings.pressure_rate * READ_INTERVAL, settings.pressure_max)
	elif intensity >= settings.calm_intensity * 2.0:
		pressure = maxf(pressure - settings.pressure_rate * 2.0 * READ_INTERVAL, settings.pressure_min)
	else:
		pressure = move_toward(pressure, 1.0, settings.pressure_rate * 0.25 * READ_INTERVAL)


## A kind unlocked by now, by weight (the first kind if none are).
func pick_kind() -> int:
	var total := 0.0
	for kind in horde.kinds:
		if kind.unlock_minute <= minutes():
			total += kind.weight
	if total <= 0.0:
		return 0
	var roll := rng.randf() * total
	for k in horde.kinds.size():
		var kind := horde.kinds[k]
		if kind.unlock_minute > minutes():
			continue
		roll -= kind.weight
		if roll <= 0.0:
			return k
	return 0
