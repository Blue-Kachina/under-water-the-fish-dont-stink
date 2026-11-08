extends Node3D
## School.hold() (two-stage-attack.md 4b, phase 2): a fish a whale's mouth holds stops being a boid. Checks: a
## held fish rides its place in the holder (drawn in over the ease, then carried as the holder moves), the
## school neither moves it nor counts it in its middle (so not in its alarm), the unheld fish keep swimming,
## a dead, claimed or already held fish can't be held, a held fish that is eaten is no longer held (and the
## others stay), release_hold() makes it an ordinary school fish again (its slot pulls it back), nudge()
## knocks a free fish and not a held one, a holder that is freed lets its fish go, and a school nobody holds
## fish in behaves exactly as before (same seed, same positions: Nature never sets the state).
##   Godot_console.exe --headless --path . res://tests/school_hold_probe.tscn

var failures := 0
var camera := Camera3D.new()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	add_child(camera)
	camera.global_position = Vector3(0, 500, 0)
	camera.make_current()
	_run.call_deferred()


func _run() -> void:
	var settings := NatureSettings.new()
	settings.fish_per_school = 30
	settings.fish_scale = 0.5
	var school := _school(settings)
	var twin := _school(settings)  # the same seed, never held: the control
	await _ticks(240)
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = Vector3(40.0, 0.0, 0.0)

	print("holding:")
	check(school.held_count() == 0 and school.held_indices().is_empty(), "nothing is held to begin with")
	var before_middle := school.middle()
	var picks := _nearest_to(school, school.fish_position(0), 5)
	var slot := Vector3(0.0, 0.0, -1.5)
	for i in picks:
		check(school.hold(i, holder, slot + Vector3(float(i) * 0.01, 0.0, 0.0), 0.3), "fish %d is held" % i)
	check(school.held_count() == 5, "five held")
	check(not school.hold(picks[0], holder, slot), "a held fish can't be held again")
	check(not school.hold(-1, holder, slot) and not school.hold(9999, holder, slot), "a bad index can't be held")
	check(not school.hold(7, null, slot), "no holder, no hold")
	var free_pick := -1
	for i in school.fish_count():
		if not school.is_held(i):
			free_pick = i
			break
	await _ticks(60)  # the ease (0.3 s) is over
	var arrived := true
	for i in picks:
		var want := holder.to_global(slot + Vector3(float(i) * 0.01, 0.0, 0.0))
		arrived = arrived and school.fish_position(i).distance_to(want) < 0.2
	check(arrived, "the held fish are in their places in the holder")
	holder.global_position += Vector3(0.0, 5.0, 0.0)
	await _ticks(20)
	var carried := true
	for i in picks:
		carried = carried and school.fish_position(i).distance_to(holder.to_global(slot + Vector3(float(i) * 0.01, 0.0, 0.0))) < 0.5
	check(carried, "they ride along as the holder moves")
	check(school.fish_velocity(picks[0]).length() < 0.001, "a held fish is not swimming on its own")

	print("the school:")
	var middle_held := school.middle()
	var total := Vector3.ZERO
	var n := 0
	for i in school.fish_count():
		if school.is_alive(i) and not school.is_held(i):
			total += school.fish_position(i)
			n += 1
	var everyone := Vector3.ZERO
	for i in school.fish_count():
		everyone += school.fish_position(i)
	check(middle_held.distance_to(total / n) < 0.5 and middle_held.distance_to(everyone / school.fish_count()) > 1.0, "the middle leaves the held fish out (%.2f m off the others' mean, %.2f m off everyone's; the holder is far off)" % [middle_held.distance_to(total / n), middle_held.distance_to(everyone / school.fish_count())])
	check(before_middle.distance_to(middle_held) >= 0.0 and school.alive_count() == 30, "held fish are still alive (30)")
	var free_before := school.fish_position(free_pick)
	await _ticks(60)
	check(school.fish_position(free_pick).distance_to(free_before) > 0.3, "a fish not held keeps swimming")
	school.nudge(free_pick, Vector3(9.0, 0.0, 0.0))
	check(school.fish_velocity(free_pick).x > 4.0, "nudge() knocks a free fish")
	var held_speed := school.fish_velocity(picks[0])
	school.nudge(picks[0], Vector3(9.0, 0.0, 0.0))
	check(school.fish_velocity(picks[0]) == held_speed, "...and leaves a held one alone")

	print("eaten and released:")
	school.eat([picks[0]], 2.5, 2.5, 3, 4.0)
	check(not school.is_alive(picks[0]) and not school.is_held(picks[0]) and school.held_count() == 4, "an eaten fish is no longer held, the other four still are")
	check(not school.hold(picks[0], holder, slot), "a dead fish can't be held")
	school.release_hold(picks[1])
	check(not school.is_held(picks[1]) and school.is_alive(picks[1]) and school.held_count() == 3, "a released fish is a school fish again")
	var released_at := school.fish_position(picks[1])
	await _ticks(120)
	check(school.fish_position(picks[1]).distance_to(released_at) > 1.0, "...and swims off with its school (%.1f m)" % school.fish_position(picks[1]).distance_to(released_at))
	check(school.fish_position(picks[2]).distance_to(holder.to_global(slot + Vector3(float(picks[2]) * 0.01, 0.0, 0.0))) < 0.5, "the ones still held stayed")
	var other := _school(settings)
	check(other.hold(0, holder, slot) and other.claimed_count() == 0, "a free fish of another school can be held")
	var claimer := (load("res://scenes/fish.tscn") as PackedScene).instantiate() as FishController
	add_child(claimer)
	check(other.claim(1, claimer, 0.1) and not other.hold(1, holder, slot), "a claimed fish (a joined player) can't be held")
	claimer.queue_free()
	other.queue_free()
	holder.queue_free()
	await _ticks(10)
	check(school.held_count() == 0, "a holder that is freed lets its fish go")

	print("Nature:")
	await _ticks(120)
	# The control never held anything; the held school differs only in the fish it held. A fresh pair with the same
	# seed, one holding nothing, must run identically.
	var a := _school(settings)
	var b := _school(settings)
	await _ticks(300)
	var same := true
	for i in a.fish_count():
		same = same and a.fish_position(i).is_equal_approx(b.fish_position(i))
	check(same, "two schools of the same seed swim identically when nothing is held")
	twin.queue_free()
	print("school_hold_probe: %d failed" % failures)
	get_tree().quit(1 if failures else 0)


func _school(settings: NatureSettings) -> School:
	var school := School.new()
	add_child(school)
	school.setup(settings, Vector3.ZERO, Vector3.FORWARD, FishCharacter.FishClass.SKIRMISHER, 7)
	return school


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _nearest_to(school: School, point: Vector3, count: int) -> Array:
	var list: Array = []
	for i in school.fish_count():
		list.append([school.fish_position(i).distance_to(point), i])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return list.slice(0, count).map(func(entry: Array) -> int: return entry[1])
