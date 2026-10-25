extends Node
## The boss rift (BossRift): one per stage, far enough from the start, its
## look built, the HUD's hint near it, swimming low over it not waking it but
## diving in does (the fish spat out, the final boss now, rising out of it,
## the timeline's boss gone, the rift cold), only once; the boss on time
## leaving it cold too; rift off placing none; a new one each stage.
##   Godot_console.exe --headless --path . res://tests/rift_probe.tscn

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
	settings.spawning = false
	settings.fish_attack = FishAttack.Kind.BITE
	settings.twists = false
	settings.card_choices = 0
	settings.chest_count = 0
	settings.chest_interval = 0.0
	settings.rift = true
	settings.stage_events = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	fish.character = FishCharacter.FishClass.HUNTER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run

	print("placed:")
	var rift := run.rift
	check(is_instance_valid(rift), "the stage has a rift")
	if not is_instance_valid(rift):
		_finish()
		return
	var off := Vector2(rift.global_position.x - run.centre.x, rift.global_position.z - run.centre.z).length()
	check(off >= minf(settings.rift_min_start, settings.arena_radius * 0.64) - 0.01, "away from the start (%.0f m)" % off)
	check(is_equal_approx(rift.global_position.y, run.centre.y + settings.arena_floor), "on the sand")
	check(not rift.spent and not rift.woken, "not spent or woken yet")
	for part in ["Mouth", "Lip", "Rubble"]:
		var mesh := (rift.get_node(part) as MeshInstance3D).mesh
		check(mesh != null and mesh.get_surface_count() > 0, "its %s is built" % part.to_lower())
	for shrine in run.shrines:
		var gap := Vector2(shrine.global_position.x - rift.global_position.x, shrine.global_position.z - rift.global_position.z).length()
		if gap < settings.rift_shrine_gap:
			check(false, "rift_shrine_gap from every shrine (%.0f m)" % gap)
	await _frames(3)  # the map and compass draw it

	print("near it:")
	_put(rift.global_position + Vector3(settings.rift_hint_range - 2.0, 4.0, 0.0), Vector3.ZERO)
	await _ticks(2)
	check(run.rift_near(fish) == rift, "the HUD's hint within rift_hint_range")
	_put(rift.global_position + Vector3(settings.rift_hint_range + 6.0, 4.0, 0.0), Vector3.ZERO)
	await _ticks(2)
	check(run.rift_near(fish) == null, "and not from further off")

	print("over it, not diving:")
	for n in 6:
		_put(rift.global_position + Vector3(0.0, 2.5, 0.0), Vector3(2.0, 0.0, 0.0))
		await _ticks(1)
	check(not rift.woken, "swimming low over it doesn't wake it")

	print("diving in:")
	var woken_by: Array = []
	var arrived: Array = []
	run.rift_woken.connect(func(by: FishController) -> void: woken_by.append(by))
	run.boss_arrived.connect(func(boss: Boss) -> void: arrived.append([boss, boss.global_position]))
	for n in 10:
		if rift.woken:
			break
		_put(rift.global_position + Vector3(0.3, 2.5, 0.1), Vector3(0.0, -3.0, 0.0))
		await _ticks(1)
	check(rift.woken and rift.spent, "diving in wakes it")
	check(woken_by.size() == 1 and woken_by[0] == fish, "rift_woken by the fish")
	check(arrived.size() == 1 and arrived[0][0] is BloodLeviathan, "the final boss comes now")
	if arrived.size() == 1:
		var at: Vector3 = arrived[0][1]
		check(at.distance_to(rift.global_position + Vector3.UP * settings.rift_boss_rise) < 0.5, "rising out of the rift")
	check(not run.timeline.is_pending("boss") and "boss" in run.timeline.fired, "the timeline's boss has come")
	await _ticks(6)
	var thrown := rift.distance_to(fish.global_position)
	check(thrown > settings.rift_throw_distance * 0.7, "the fish is spat out (%.0f m away)" % thrown)
	check(fish.global_position.y > rift.global_position.y + 3.0, "up in the water (%.1f m up)" % (fish.global_position.y - rift.global_position.y))
	check(not run.can_wake_rift() and run.rift_near(fish) == null, "it can't be woken again")
	for n in 6:
		_put(rift.global_position + Vector3(0.0, 2.5, 0.0), Vector3(0.0, -3.0, 0.0))
		await _ticks(1)
	check(arrived.size() == 1, "going in again brings no second boss")
	check(run.stats_of(fish).get("rifts", 0) == 1, "counted in the run's stats")

	print("on time:")
	run.start()
	await _ticks(3)
	rift = run.rift
	check(is_instance_valid(rift) and not rift.spent, "a fresh rift on a new start")
	if is_instance_valid(rift):
		run.timeline.trigger("boss")  # as if boss_time came
		await _ticks(2)
		check(rift.spent and not rift.woken, "the boss on time leaves it cold, not woken")
		var final := run.current_boss()
		check(final != null and final.global_position.distance_to(rift.global_position + Vector3.UP * settings.rift_boss_rise) > 1.0,
				"and the boss comes from the usual spot")

	print("next stage:")
	var before := run.rift
	run.next_stage()
	await _ticks(3)
	check(is_instance_valid(run.rift) and run.rift != before and not run.rift.spent, "a new rift each stage")

	print("off:")
	settings.rift = false
	run.start()
	await _ticks(3)
	check(not is_instance_valid(run.rift), "rift off: none")
	settings.rift = true
	_finish()


func _put(at: Vector3, velocity: Vector3) -> void:
	fish.global_position = at
	fish.linear_velocity = velocity


func _finish() -> void:
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
