extends Node
## Gameplay on the procedural terrain (planning_procedural_world.md, phase 6), in a real Unnatural run with terrain on:
## over several stages (each a new seed) no chest, shrine or rift sits in or under the rock, and spawn points are clear;
## the ground queries follow the rock; a zombie put inside the rock is pushed out; a boss put in the rock is moved out;
## the fish doesn't drive on the rock (terrain_stick_to_rock off) and gets its setting back after; and a fish swept
## through each arch and tunnel bore (real physics) comes out the far side without wedging.
##   Godot_console.exe --headless --path . res://tests/terrain_play_probe.tscn

const STAGES := 4

var failures := 0
var main: Node
var fish: FishController


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	settings.terrain_enabled = true
	settings.spawning = false
	settings.fish_attack = FishAttack.Kind.BITE
	settings.twists = false
	settings.card_choices = 0
	settings.chest_count = 14
	settings.chest_interval = 0.0
	settings.rift = true
	settings.stage_events = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	var surface_before := fish.rl_surface_mechanics
	fish.character = FishCharacter.FishClass.HUNTER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	check(run != null and is_instance_valid(run.seabed) and run.seabed.terrain != null, "the run's seabed has terrain")
	if run == null or run.seabed.terrain == null:
		_finish()
		return
	check(fish.rl_surface_mechanics == settings.terrain_stick_to_rock, "the fish doesn't drive on the rock")

	var bad := 0
	var placed := 0
	var spawns_bad := 0
	for stage in STAGES:
		if stage > 0:
			var prefetched := stage % 2 == 0  # every other stage: the next terrain generated on a thread first (the whirlpool's wait)
			if prefetched:
				run.seabed.prefetch(settings, run._seabed_seed_for(run.stage + 1), settings.arena_ceiling - settings.arena_floor + 5.0)
				await get_tree().create_timer(1.5).timeout
			var t0 := Time.get_ticks_usec()
			run.next_stage()
			print("    stage change %.0f ms%s" % [(Time.get_ticks_usec() - t0) / 1000.0, " (prefetched)" if prefetched else ""])
			await _ticks(3)
		var terrain := run.seabed.terrain
		print("stage %d (seed %d): %s ms, %d triangles" % [run.stage, run._seabed_seed, terrain.stats.get("ms_prepare", 0.0), terrain.stats.get("triangles", 0)])
		for chest in run.chests:
			if not is_instance_valid(chest):
				continue
			placed += 1
			var top := chest.global_position + Vector3.UP * TreasureChest.SIZE.y
			if Terrain.sdf(top) < 0.3 or not Terrain.is_open(top + Vector3.UP * 1.5, 1.0):
				bad += 1
				print("    chest in the rock at %s (sdf %.2f)" % [chest.global_position, Terrain.sdf(top)])
		for shrine in run.shrines:
			placed += 1
			if not Terrain.is_open(shrine.global_position + Vector3.UP * (Shrine.STEP_RADIUS + 0.5), Shrine.STEP_RADIUS):
				bad += 1
				print("    shrine in the rock at %s" % shrine.global_position)
		if is_instance_valid(run.rift):
			placed += 1
			if not Terrain.is_open(run.rift.global_position + Vector3.UP * (BossRift.MOUTH.x + 0.5), BossRift.MOUTH.x):
				bad += 1
				print("    rift in the rock at %s" % run.rift.global_position)
		for n in 40:
			var around := run.centre + Vector3(cos(n * 0.7), 0.0, sin(n * 0.7)) * 120.0
			var point := run.spawn_point(around)
			if Terrain.sdf(point) < settings.terrain_spot_room * 0.8:
				spawns_bad += 1
	check(bad == 0, "no chest, shrine or rift in or under the rock (%d placed over %d stages)" % [placed, STAGES])
	check(spawns_bad == 0, "spawn points keep clear of the rock (%d of 160 not)" % spawns_bad)

	var terrain := run.seabed.terrain
	var lay := terrain.layout
	var base := run.seabed.global_position
	print("ground:")
	var mesa := Vector4.ZERO
	for m in lay.mesas:
		if m.w > mesa.w:
			mesa = m
	var flat := run.centre.y + settings.arena_floor
	check(is_equal_approx(run.ground_y(run.centre.x + 5.0, run.centre.z + 5.0), flat), "the open middle's ground is the flat seabed")
	var ring_x := run.centre.x + settings.arena_radius + settings.terrain_ring_width * 0.5 - settings.terrain_ring_inset
	check(run.ground_y(ring_x, run.centre.z) > flat + 5.0, "the ground rises on the edge ring (%.1f m)" % (run.ground_y(ring_x, run.centre.z) - flat))

	print("horde:")
	var inside := base + Vector3(ring_x - base.x, 3.0, 0.0)
	var depth := Terrain.sdf(inside)
	var index := run.horde.spawn(0, inside)
	for i in 30:
		run.horde.step_once(1.0 / 30.0)
	var out := Terrain.sdf(run.horde.enemy_position(index)) if index >= 0 else -1.0
	check(depth < 0.0 and out >= run.horde.enemy_radius(index) * 0.9, "a zombie put %.1f m deep in the rock is pushed out (%.2f m clear)" % [-depth, out])

	print("boss:")
	var boss_at := run.out_of_rock(inside, Boss.BOSS_ROCK_ROOM)
	check(Terrain.sdf(boss_at) >= Boss.BOSS_ROCK_ROOM * 0.9, "out_of_rock moves a point clear (%.2f m)" % Terrain.sdf(boss_at))

	print("bores (physics):")
	var swept := 0
	var wedged := 0
	var routes: Array = []
	for arch in lay.arches:
		var at := Vector3(arch.x, settings.terrain_clearance + 0.8, arch.y)
		var dir := Vector3(arch.x, 0.0, arch.y).normalized().cross(Vector3.UP)
		routes.append([base + at - dir * (arch.z + 10.0), base + at + dir * (arch.z + 10.0)])
	for tunnel: Array in lay.tunnels:
		routes.append([base + (tunnel[0] as Vector3), base + (tunnel[1] as Vector3)])
	for route: Array in routes:
		var a: Vector3 = route[0]
		var b: Vector3 = route[1]
		# An arch's axis is rolled at random: try both crossings and keep the clear one (a tunnel's line is its bore).
		if not Terrain.line_clear(a, b, 0.6):
			var mid := (a + b) * 0.5
			var other := (b - a).cross(Vector3.UP).normalized() * a.distance_to(b) * 0.5
			if Terrain.line_clear(mid - other, mid + other, 0.6):
				a = mid - other
				b = mid + other
			else:
				continue
		swept += 1
		var ok := await _sweep(a, b)
		if not ok:
			wedged += 1
	check(wedged == 0, "a fish swims through every passable arch and tunnel (%d swept of %d)" % [swept, routes.size()])

	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	check(fish.rl_surface_mechanics == surface_before, "the fish gets its surface setting back after the run")
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## Pushes the fish from `a` toward `b` for a few seconds; true when it gets within 4 m of `b`.
func _sweep(a: Vector3, b: Vector3) -> bool:
	fish.global_position = a
	fish.linear_velocity = Vector3.ZERO
	var dir := (b - a).normalized()
	fish.global_basis = Basis.looking_at(dir, Vector3.UP)
	var limit := int(a.distance_to(b) / 2.0 * 60.0) + 240  # the push nets about 4 m/s
	for i in limit:
		await get_tree().physics_frame
		fish.linear_velocity = (b - fish.global_position).normalized() * 8.0
		if fish.global_position.distance_to(b) < 4.0:
			return true
	print("    stuck at %s (%.1f m short, %.2f m from rock), from %s to %s" % [fish.global_position, fish.global_position.distance_to(b),
			Terrain.sdf(fish.global_position), a, b])
	return false


func _finish() -> void:
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
