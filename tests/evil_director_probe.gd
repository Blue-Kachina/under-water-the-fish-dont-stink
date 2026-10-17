extends Node
## Unnatural's EvilDirector on its own (planning_unnatural.md §4) over a
## simulated run: the target alive follows its curve over 10 minutes and grows
## with players; packs fill the horde to it and no more; kinds unlock on time;
## elites come more often later; mowing them down easily raises the pressure,
## a hard time lowers it, and high intensity brings a breather with no packs.
## (Named for the EvilDirector: director_probe is the replay director's.)
##   Godot_console.exe --headless --path . res://tests/evil_director_probe.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	var settings := UnnaturalSettings.new()
	var horde := Horde.new()
	add_child(horde)
	horde.setup(settings, EnemyKind.defaults(), 6000, 5)
	horde.set_physics_process(false)
	horde.set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var director := EvilDirector.new(settings, horde, rng)
	director.spawn_point = func(around: Vector3) -> Vector3: return around + Vector3(30, 0, 0)
	var around := PackedVector3Array([Vector3.ZERO])

	print("the curve:")
	var on_curve := true
	for minute in [0.0, 1.0, 2.5, 5.0, 10.0]:
		director.elapsed = minute * 60.0
		var expected := roundi(settings.base_alive + settings.alive_per_minute * pow(minute, settings.alive_curve))
		on_curve = on_curve and director.target_alive() == expected
	check(on_curve, "target alive = base + per_minute * minutes ^ curve, at 0 to 10 minutes")
	director.elapsed = 300.0
	var solo := director.target_alive()
	director.players = 3
	check(absi(director.target_alive() - roundi(solo * (1.0 + settings.coop_scale * 2.0))) <= 1, "three players: x(1 + 2 coop_scale) (%d -> %d)" % [solo, director.target_alive()])
	director.players = 1

	print("filling the horde:")
	director.reset()
	var overshoot := 0
	var kinds_by_minute := {}
	var elites_early := 0
	var spawned_early := 0
	var elites_late := 0
	var spawned_late := 0
	var dt := 0.25
	for step in roundi(600.0 / dt):
		director.elapsed += dt
		director.update(dt, around)
		overshoot = maxi(overshoot, horde.alive_count() - director.target_alive() - director.swarm_size() * 2)
		# Kill a share each tick, as players would, and log what came.
		horde.step_once(dt)
		var minute := floori(director.minutes())
		for i in horde.alive:
			if horde.cooldown(i) > 1e8:
				continue
			horde.set_cooldown(i, 1e9)  # seen
			if not kinds_by_minute.has(minute):
				kinds_by_minute[minute] = {}
			kinds_by_minute[minute][horde.enemy_kind(i).id] = true
			if director.minutes() < 2.0:
				spawned_early += 1
				elites_early += 1 if horde.is_elite(i) else 0
			elif director.minutes() > 8.0:
				spawned_late += 1
				elites_late += 1 if horde.is_elite(i) else 0
		var cull := horde.alive.size() / 8
		for n in cull:
			horde.remove(horde.alive[n])
		horde.step_once(0.0)
	check(overshoot <= 0, "packs never take it far past the target (worst %d over)" % overshoot)
	check(not kinds_by_minute.get(0, {}).has("boxfish") and not kinds_by_minute.get(1, {}).has("swordfish"), "the first minutes: no boxfish or swordfish yet")
	var late: Dictionary = kinds_by_minute.get(9, {})
	check(late.size() == horde.kinds.size(), "by minute 9 every kind comes (%s)" % [late.keys()])
	var early_share := float(elites_early) / maxi(spawned_early, 1)
	var late_share := float(elites_late) / maxi(spawned_late, 1)
	check(late_share > early_share and late_share > 0.03, "elites get likelier (%.1f%% early, %.1f%% late)" % [early_share * 100.0, late_share * 100.0])

	print("pressure:")
	horde.clear()
	director.reset()
	director.elapsed = 120.0
	settings.spawning = false
	for second in 30:
		for k in 4:
			director.on_kill()
		for t in 4:
			director.elapsed += 0.25
			director.update(0.25, around)
	check(director.pressure > 1.4, "mowing them down unhurt raises the pressure (x%.2f)" % director.pressure)
	var pushed := director.target_alive()
	director.pressure = 1.0
	check(pushed > director.target_alive(), "and with it the target (%d vs %d)" % [pushed, director.target_alive()])
	var at := director.elapsed
	director.reset()
	director.elapsed = at
	director.pressure = 1.3
	for second in 10:
		director.on_damage(0.06)
		for t in 4:
			director.elapsed += 0.25
			director.update(0.25, around)
	check(director.pressure < 1.3, "a hard time lowers it (x%.2f)" % director.pressure)

	print("breathers:")
	settings.spawning = true
	director.reset()
	director.elapsed = 180.0
	horde.clear()
	director.on_damage(settings.relief_intensity + 0.05)
	director.elapsed += 1.0
	director.update(1.0, around)
	check(director.in_relief() and director.reliefs == 1, "a burst of damage brings a breather")
	var packs_before := director.packs
	var t := 1.0
	var quiet := true
	while director.in_relief():
		director.elapsed += 0.25
		director.update(0.25, around)
		t += 0.25
		quiet = quiet and (director.packs == packs_before or not director.in_relief())
	check(quiet, "no packs during it (%.1f s)" % t)
	check(absf(t - settings.relief_time) < 1.0, "it lasts relief_time")
	for k in 8:
		director.elapsed += 0.25
		director.update(0.25, around)
	check(director.packs > packs_before, "then they come again")

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)
