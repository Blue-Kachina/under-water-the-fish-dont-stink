extends Node
## The zombie roster (big_changes.md §8, Phase 6) in the real game: every class
## has a zombie (and the sardines their own model); each stage plays a
## rotation of the kinds (D10) and the director only picks from it; the new
## behaviours (the koi's circling school, the jelly's surges, the mantis's
## telegraphed punch, the Ghoul Shark's quicker lunge, the whale calf's bob);
## and what they do to the players (the punch, the sting, the cinder trail,
## the sour cloud, the whale's sardines).
##   Godot_console.exe --headless --path . res://tests/roster_probe.tscn

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var run: UnnaturalRun
var horde: Horde
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	settings.spawning = false
	settings.card_choices = 0
	settings.enemy_hp_scale = 100.0
	settings.difficulty_per_minute = 0.0
	settings.enemy_damage_scale = 0.0
	settings.chest_count = 0
	settings.twists = false
	settings.depth_assist = 0.0
	settings.wander = 0.0
	fish.character = FishCharacter.FishClass.BULWARK
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde

	print("the roster:")
	var kinds := EnemyKind.defaults()
	var classes := {}
	for kind in kinds:
		if kind.look == "":
			classes[kind.fish_class] = kind.id
	var missing: Array = []
	for fish_class: int in FishCharacter.FishClass.values():
		if not classes.has(fish_class):
			missing.append(FishCharacter.display_name(fish_class))
	check(missing.is_empty(), "every class has a zombie (%d kinds; missing: %s)" % [kinds.size(), ", ".join(missing)])
	check(kinds[0].id == "sardine" and kinds[0].look == "sardine" and kinds[0].always, "kind 0 is the sardines, in their own model, in every rotation")
	var ids := {}
	for kind in kinds:
		ids[kind.id] = true
	check(ids.size() == kinds.size(), "every kind has its own id")

	print("their looks:")
	var baked := true
	var notes: Array = []
	for kind in kinds:
		var meshes := SchoolLook.detail_meshes(kind.look_key(), 0.0)
		var ok := meshes.size() == 3
		for mesh: Mesh in meshes:
			ok = ok and mesh != null and mesh.get_surface_count() > 0
		if not ok:
			notes.append(kind.id)
		baked = baked and ok
	check(baked, "every kind's look bakes in three poses (bad: %s)" % ", ".join(notes))
	var sardine: Array = SchoolLook.meshes("sardine")
	var tris := 0
	for surface in (sardine[0] as Mesh).get_surface_count():
		tris += (sardine[0] as ArrayMesh).surface_get_array_index_len(surface) / 3
	check(tris > 500 and tris < 16000, "the sardine is a real model, light enough for a horde: %d triangles" % tris)
	var whale: Array = SchoolLook.meshes(FishCharacter.FishClass.BREACHER)
	var centre := (whale[SchoolLook.CENTRE] as Mesh).get_aabb()
	var right := (whale[SchoolLook.RIGHT] as Mesh).get_aabb()
	var left := (whale[SchoolLook.LEFT] as Mesh).get_aabb()
	var down := _tail_height(whale[SchoolLook.RIGHT]) - _tail_height(whale[SchoolLook.CENTRE])
	var up := _tail_height(whale[SchoolLook.LEFT]) - _tail_height(whale[SchoolLook.CENTRE])
	check(down < -0.03 and up > 0.03, "a whale calf's poses beat its flukes down and up (%.2f / %.2f m)" % [down, up])
	check(absf(right.get_center().x - left.get_center().x) < 0.005, "not sideways")

	print("rotation (D10):")
	settings.stage_kinds = 6
	run._rotate_kinds()
	var rotation := run.director.rotation
	var count := 0
	var opener := false
	for k in rotation.size():
		if rotation[k] == 1:
			count += 1
			if k > 0 and horde.kinds[k].unlock_minute <= 0.0:
				opener = true
	check(count == 6 and rotation[0] == 1 and opener, "a stage plays 6 kinds: the sardines, an opener, and 4 more (%d)" % count)
	run.director.elapsed = 3600.0
	var outside := 0
	for n in 400:
		if rotation[run.director.pick_kind()] == 0:
			outside += 1
	check(outside == 0, "the director only picks kinds in the rotation")
	var seen := {}
	for n in 12:
		run._rotate_kinds()
		for k in run.director.rotation.size():
			if run.director.rotation[k] == 1:
				seen[k] = true
	var pickable := 0
	for kind in horde.kinds:
		if kind.weight > 0.0:
			pickable += 1
	check(seen.size() == pickable, "over a few stages every kind the director picks comes round (%d of %d)" % [seen.size(), pickable])
	settings.stage_kinds = 0
	run._rotate_kinds()
	var all := true
	for k in run.director.rotation.size():
		all = all and run.director.rotation[k] == 1
	check(all, "stage_kinds 0: every kind at once")
	settings.stage_kinds = 6
	run.director.elapsed = 0.0

	print("behaviours:")
	await _park(Vector3.ZERO, Vector3.FORWARD)
	var koi := await _spawn("koi", Vector3(0, 0, -24))
	var modes := {}
	var ring_gaps: Array = []
	for t in 900:
		await get_tree().physics_frame
		if not horde.is_alive(koi):
			break
		var mode := horde.enemy_mode(koi)
		modes[mode] = true
		if mode == Horde.Lunge.REST:
			ring_gaps.append(horde.enemy_position(koi).distance_to(fish.global_position))
		if modes.has(Horde.Lunge.LUNGE) and modes.has(Horde.Lunge.REST):
			break
	var mean_gap := 0.0
	for g: float in ring_gaps:
		mean_gap += g / maxf(ring_gaps.size(), 1)
	check(modes.has(Horde.Lunge.REST) and modes.has(Horde.Lunge.LUNGE), "a Drowned Koi closes in, circles, then darts")
	check(mean_gap > settings.school_ring * 0.6 and mean_gap < settings.school_ring * 1.6,
			"it circles about school_ring off (%.1f m, ring %.0f)" % [mean_gap, settings.school_ring])

	horde.clear()
	var jelly := await _spawn("jelly", Vector3(0, 0, -40))
	var speeds: Array = []
	for t in 480:
		await get_tree().physics_frame
		speeds.append(horde.enemy_velocity(jelly).length())
	var fast: float = speeds.slice(120).max()
	var slow: float = speeds.slice(120).min()
	check(fast > slow * 2.5 and fast > 0.5, "a Grave Jelly surges and coasts (%.1f to %.1f m/s)" % [slow, fast])

	horde.clear()
	var mantis := await _spawn("mantis", Vector3(0, 0, -14))
	var wound_at := -1.0
	var struck := [false]
	var on_stage := func(index: int, stage: int) -> void:
		if index == mantis and stage == Horde.Lunge.LUNGE:
			struck[0] = true
	horde.lunge_stage.connect(on_stage)
	for t in 600:
		await get_tree().physics_frame
		if wound_at < 0.0 and horde.enemy_mode(mantis) == Horde.Lunge.TELEGRAPH:
			wound_at = horde.enemy_position(mantis).distance_to(fish.global_position)
		if struck[0]:
			break
	check(wound_at > 0.0 and wound_at < settings.zombie_punch_range + 0.6,
			"a Rotten Mantis stops short and winds up (%.1f m off)" % wound_at)
	check(struck[0], "then throws its punch")

	horde.clear()
	var shark := await _spawn("shark", Vector3(0, 0, -10))
	await _until(func() -> bool: return horde.enemy_mode(shark) == Horde.Lunge.TELEGRAPH, 300)
	check(is_equal_approx(horde._wind[shark], settings.lunge_telegraph * 0.6), "a Ghoul Shark winds up quicker (%.2f s)" % horde._wind[shark])

	horde.clear()
	var calf := await _spawn("whale", Vector3(0, 0, -40))
	var ups: Array = []
	for t in 360:
		await get_tree().physics_frame
		ups.append(horde.enemy_velocity(calf).y)
	check(float(ups.max()) - float(ups.min()) > 1.0, "a whale calf rises and falls as it comes (%.1f to %.1f m/s)" % [ups.min(), ups.max()])
	horde.lunge_stage.disconnect(on_stage)

	print("what they do to you:")
	settings.enemy_damage_scale = 1.0
	var health := run.health_of(fish)
	horde.clear()
	health.heal(1000.0)
	health.iframes_left = 0.0
	var before := health.hp
	mantis = await _spawn("mantis", Vector3(0, 0, -6))
	struck[0] = false
	await _until(func() -> bool: return health.hp < before - 0.01, 600)
	check(health.hp < before - 5.0, "the punch hurts from %.0f m off (%.0f hp)" % [settings.zombie_punch_range, before - health.hp])
	horde.clear()
	await _ticks(2)
	run._chill.clear()
	health.iframes_left = 0.0
	await _spawn("jelly", Vector3(0, 0, -0.8))
	await _until(func() -> bool: return run._chill.has(fish), 120)
	check(run._chill.has(fish), "a Grave Jelly's sting slows")
	settings.enemy_damage_scale = 0.0
	horde.clear()
	run._chill.clear()
	var hare := await _spawn("sea_hare", Vector3(0, 0, -8))
	horde.damage(hare, 1e9, "probe")
	await _ticks(2)
	check(_clouds(UnnaturalRun.SOUR_CAUSE) == 1, "a Sour Sea Hare leaves a slowing cloud where it dies")
	var calf2 := await _spawn("whale", Vector3(0, 0, -20))
	var sardines := _alive_of("sardine")
	horde.damage(calf2, 1e9, "probe")
	await _ticks(12)
	check(_alive_of("sardine") - sardines == horde.kinds[_kind("whale")].death_spawn, "a whale calf spills sardines (%d)" % (_alive_of("sardine") - sardines))
	horde.clear()
	await _spawn("lionfish", Vector3(0, 0, -30))
	await _ticks(240)
	check(_clouds(UnnaturalRun.CINDER_CAUSE) >= 1, "a Cinder Lionfish leaves fire behind it (%d patches)" % _clouds(UnnaturalRun.CINDER_CAUSE))

	print("roster_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## The mean height of `mesh`'s last tenth (its tail).
func _tail_height(mesh: Mesh) -> float:
	var back := -INF
	var front := INF
	var points: Array[PackedVector3Array] = []
	for surface in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		points.append(vertices)
		for v in vertices:
			back = maxf(back, v.z)
			front = minf(front, v.z)
	var from := back - (back - front) * 0.1
	var total := 0.0
	var n := 0
	for vertices in points:
		for v in vertices:
			if v.z >= from:
				total += v.y
				n += 1
	return total / maxi(n, 1)


func _kind(id: String) -> int:
	for k in horde.kinds.size():
		if horde.kinds[k].id == id:
			return k
	return -1


## A zombie of kind `id` at `offset` from the fish (heading for it), once the
## horde has stepped with it.
func _spawn(id: String, offset: Vector3) -> int:
	var at := fish.global_position + offset
	var index := horde.spawn(_kind(id), at, -offset)
	await _ticks(14)
	return index


func _alive_of(id: String) -> int:
	var n := 0
	for i in horde.alive:
		if horde.enemy_kind(i).id == id:
			n += 1
	return n


func _clouds(cause: String) -> int:
	var n := 0
	for cloud in run._clouds:
		if is_instance_valid(cloud) and cloud.cause == cause:
			n += 1
	return n


func _until(done: Callable, most: int) -> void:
	for n in most:
		if done.call():
			return
		await get_tree().physics_frame


func _park(at: Vector3, facing: Vector3) -> void:
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(facing), run.centre + at))
	await _ticks(2)
	fish.freeze = true


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
