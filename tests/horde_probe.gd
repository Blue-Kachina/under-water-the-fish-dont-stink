extends Node
## Unnatural's Horde on its own (planning_unnatural.md §2): its grid queries
## match brute force; zombies chase the nearest chaseable player and spread
## into a crowd rather than piling into one point; nobody to chase, they mill
## about; damage kills, the dead fade and their slots are reused; immortal
## ones never die; a full horde refuses more.
##   Godot_console.exe --headless --path . res://tests/horde_probe.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	var settings := UnnaturalSettings.new()
	var horde := Horde.new()
	add_child(horde)
	horde.setup(settings, EnemyKind.defaults(), 1200, 3)
	horde.set_physics_process(false)
	horde.set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9

	print("grid:")
	for n in 800:
		horde.spawn(rng.randi_range(0, horde.kinds.size() - 1), Vector3(rng.randf_range(-30, 30), rng.randf_range(-10, 10), rng.randf_range(-30, 30)))
	horde.targets = PackedVector3Array([Vector3(500, 0, 0)])
	horde.chaseable = PackedByteArray([0])
	horde.step_once(1.0 / 30.0)
	var matched := true
	var cone_matched := true
	for q in 60:
		var centre := Vector3(rng.randf_range(-30, 30), rng.randf_range(-10, 10), rng.randf_range(-30, 30))
		var reach := rng.randf_range(0.5, 14.0)
		var found := horde.query_sphere(centre, reach)
		var expected := []
		for i in horde.alive:
			if horde._position[i].distance_to(centre) <= reach + horde.enemy_radius(i):
				expected.append(i)
		var got := Array(found)
		got.sort()
		expected.sort()
		matched = matched and got == expected
		var forward := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var nearest := horde.nearest_in_cone(centre, forward, reach, 0.5)
		var best := -1
		var best_gap := INF
		for i in expected:
			var offset: Vector3 = horde.enemy_position(i) - centre
			if offset.length() > 0.001 and offset.normalized().dot(forward) < 0.5:
				continue
			# As auto-aim counts it: height weighs more with depth assist (Horde.aim_gap()).
			var gap := offset.length() + absf(offset.y) * settings.depth_assist * Horde.DEPTH_AIM
			if gap < best_gap:
				best_gap = gap
				best = i
		cone_matched = cone_matched and nearest == best
	check(matched, "60 sphere queries match brute force")
	check(cone_matched, "60 nearest-in-cone queries match brute force")
	var buckets := horde.grid.buckets_near(Vector3.ZERO, 5.0)
	var unique := {}
	for b in buckets:
		unique[b] = true
	check(unique.size() == buckets.size(), "a query visits each bucket once")

	print("nobody to chase:")
	var before := _spread_centre(horde)
	for s in 60:
		horde.step_once(1.0 / 30.0)
	var stays := true
	for i in horde.alive:
		stays = stays and horde.enemy_target(i) == -1
	check(stays, "no chaseable player: no zombie has a target")
	check(_spread_centre(horde).distance_to(before) < 12.0, "they mill about (the crowd's middle moved %.1f m)" % _spread_centre(horde).distance_to(before))

	print("chase:")
	horde.clear()
	for n in 300:
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)).normalized()
		horde.spawn(n % 2, direction * rng.randf_range(30.0, 50.0))
	horde.targets = PackedVector3Array([Vector3.ZERO, Vector3(400, 0, 0)])
	horde.chaseable = PackedByteArray([1, 1])
	horde.step_once(1.0 / 30.0)
	var start_gap := _mean_gap(horde, Vector3.ZERO)
	for s in 30 * 10:
		horde.step_once(1.0 / 30.0)
	var all_on_near := true
	for i in horde.alive:
		all_on_near = all_on_near and horde.enemy_target(i) == 0
	check(all_on_near, "each chases the nearest player")
	var end_gap := _mean_gap(horde, Vector3.ZERO)
	check(end_gap < 8.0 and end_gap < start_gap * 0.3, "they close in (mean distance %.1f m -> %.1f m)" % [start_gap, end_gap])
	var stacked := 0
	for i in horde.alive:
		var nearest := INF
		for j in horde.alive:
			if j != i:
				nearest = minf(nearest, horde._position[i].distance_to(horde._position[j]))
		if nearest < 0.15:
			stacked += 1
	check(stacked < horde.alive.size() * 0.1, "they spread into a crowd (%d of %d within 0.15 m of another)" % [stacked, horde.alive.size()])
	horde.chaseable = PackedByteArray([0, 1])
	for s in 31:
		horde.step_once(1.0 / 30.0)
	var switched := true
	for i in horde.alive:
		switched = switched and horde.enemy_target(i) == 1
	check(switched, "the near player gone (down, invisible): they go for the other")

	print("bounds:")
	horde.clear()
	settings.arena_radius = 20.0
	var outside := horde.spawn(0, Vector3(40, 0, 0))
	horde.chaseable = PackedByteArray([0, 0])
	for s in 30 * 8:
		horde.step_once(1.0 / 30.0)
	var flat := Vector2(horde._position[outside].x, horde._position[outside].z).length()
	check(flat < 25.0, "a zombie outside the arena is pushed back in (%.1f m from the middle, radius 20)" % flat)
	settings.arena_radius = 150.0

	print("damage and slots:")
	horde.clear()
	horde.chaseable = PackedByteArray([1, 1])
	var deaths := []
	horde.killed.connect(func(index: int, kind: int, at: Vector3, source: String, by: Object) -> void: deaths.append([index, kind, source]))
	var a := horde.spawn(1, Vector3(1, 0, 0))
	var b := horde.spawn(1, Vector3(2, 0, 0))
	var hp := horde.enemy_hp(a)
	check(not horde.damage(a, hp * 0.5, "bite") and horde.is_alive(a), "half its hp: still alive")
	check(horde.damage(a, hp, "bite") and not horde.is_alive(a), "the rest: dead")
	check(deaths.size() == 1 and deaths[0][0] == a and deaths[0][2] == "bite", "killed says which, and what killed it")
	check(horde.alive_count() == 1, "one left alive")
	check(not horde.damage(a, 10.0, "bite"), "the dead can't be hurt again")
	for s in 12:
		horde.step_once(1.0 / 30.0)
	var c := horde.spawn(0, Vector3(3, 0, 0))
	check(c == a, "its slot is reused once it's faded (%d)" % c)
	horde.remove(b)
	check(horde.alive_count() == 1 and deaths.size() == 1, "remove() takes one away without a death")
	horde.immortal = true
	check(not horde.damage(c, 99999.0, "bite") and horde.is_alive(c), "immortal: never dies")
	horde.immortal = false

	print("behaviours:")
	horde.clear()
	horde.targets = PackedVector3Array([Vector3.ZERO])
	horde.target_velocities = PackedVector3Array([Vector3.ZERO])
	horde.chaseable = PackedByteArray([1])
	settings.separation = 0.0
	var sword := horde.spawn(3, Vector3(0, 0, 30))
	var stages := []
	var top := 0.0
	for st in 30 * 6:
		horde.step_once(1.0 / 30.0)
		var stage := horde.enemy_mode(sword)
		if stages.is_empty() or stages[-1] != stage:
			stages.append(stage)
		if stage == Horde.Lunge.LUNGE:
			top = maxf(top, horde.enemy_velocity(sword).length())
	check(stages.slice(0, 4) == [Horde.Lunge.STALK, Horde.Lunge.TELEGRAPH, Horde.Lunge.LUNGE, Horde.Lunge.REST],
			"a swordfish stalks, telegraphs, lunges, rests (%s)" % [stages])
	check(top > settings.lunge_speed * 0.8, "its lunge is fast (%.0f m/s)" % top)
	horde.clear()
	settings.glide_sweep = 0.0
	settings.wander = 0.0
	horde.target_velocities = PackedVector3Array([Vector3(12, 0, 0)])
	var ray := horde.spawn(4, Vector3(0, 0, 30), Vector3.FORWARD)
	for st in 30:
		horde.step_once(1.0 / 30.0)
	var heading := horde.enemy_velocity(ray).normalized()
	check(heading.x > 0.3, "a ray leads a moving player, cutting across its path (heading %s)" % heading)
	settings.glide_sweep = 10.0
	settings.wander = 1.0
	settings.separation = 0.6

	print("capacity:")
	horde.clear()
	var made := horde.spawn_pack(0, 1500, Vector3.ZERO, 10.0)
	check(made == 1200 and horde.spawn(0, Vector3.ZERO) == -1, "a full horde refuses more (%d made of 1500)" % made)

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _mean_gap(horde: Horde, to: Vector3) -> float:
	var sum := 0.0
	for i in horde.alive:
		sum += horde._position[i].distance_to(to)
	return sum / maxi(horde.alive.size(), 1)


func _spread_centre(horde: Horde) -> Vector3:
	var sum := Vector3.ZERO
	for i in horde.alive:
		sum += horde._position[i]
	return sum / maxi(horde.alive.size(), 1)
