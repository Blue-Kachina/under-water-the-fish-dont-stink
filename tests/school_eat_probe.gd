extends Node3D
## School.eat() (what_stinks.md section 5, Phase 1): the Hunter's bite takes
## fish out of a school like batter() does, but the survivors panic harder and
## scatter along a few headings, then reform. Checks: the fish named go (live
## ones only, dead and bad indices ignored), where they were comes back, the
## alive mask and counts stay in step (a guest's apply_alive_mask gives the same
## school), the school goes to full alarm, survivors near the bite are flung
## harder than batter() would, the school spreads out (splits) and then reforms
## by reform_time, and the school keeps swimming with fewer fish.
##   Godot_console.exe --headless --path . res://tests/school_eat_probe.tscn

var failures := 0
var camera := Camera3D.new()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	add_child(camera)
	camera.global_position = Vector3(0, 500, 0)  # far off: no full models
	camera.make_current()
	_run.call_deferred()


func _run() -> void:
	var settings := NatureSettings.new()
	settings.fish_per_school = 40
	settings.fish_scale = 0.5
	var school := _school(settings)
	var twin := _school(settings)  # a second school, the same seed: batter() for comparison
	await _ticks(600)  # 5 s to settle
	await _ticks(0)

	print("eating:")
	var nearest := _nearest_to(school, school.fish_position(0), 6)
	var expected := PackedVector3Array()
	for i in nearest:
		expected.append(school.fish_position(i))
	var spots := school.eat(nearest + [nearest[0], -1, 9999], 2.5, 2.5, 3, 6.0)
	check(school.alive_count() == 34, "six gone, bad and repeated indices ignored (%d left)" % school.alive_count())
	check(spots.size() == 6, "it says where each was (%d spots)" % spots.size())
	var same := true
	for k in 6:
		same = same and spots[k].is_equal_approx(expected[k])
	check(same, "the spots are where the fish were")
	for i in nearest:
		check(not school.is_alive(i), "fish %d is gone" % i)
	check(school.eat([nearest[0]]).is_empty(), "eating a gone fish takes nothing")
	var mask := school.alive_mask()
	check(mask.count(0) == 6 and mask.size() == 40, "the alive mask shows six gone of 40")
	var guest := _school(settings)
	guest.apply_alive_mask(mask)
	check(guest.alive_mask() == mask and guest.alive_count() == 34, "a guest given the mask has the same fish")

	print("panic:")
	check(is_equal_approx(school.alarm, 1.0), "the school goes to full alarm (%.2f)" % school.alarm)
	# The same bite as a battery on the twin: the eaten fish's neighbours go flying harder.
	var at := twin.fish_position(nearest[0])
	twin.batter(nearest[0])
	var batter_push := _max_speed_gain(twin, at, settings.burst_radius)
	var eat_push := _max_speed_gain(school, spots[0], settings.burst_radius)
	check(eat_push > batter_push, "survivors are flung harder than a battery (%.1f vs %.1f m/s)" % [eat_push, batter_push])

	print("scatter and reform:")
	var tight := school.radius()
	await _ticks(360)  # 3 s: scattered
	var spread := _farthest_from_middle(school)
	check(spread > tight * 1.5, "the school splits up (farthest %.1f m, school radius %.1f)" % [spread, tight])
	await _ticks(120 * 14)  # past reform_time and then some
	var after := _farthest_from_middle(school)
	check(after < spread * 0.8 and after < tight * 2.0, "it reforms (farthest %.1f m, from %.1f)" % [after, spread])
	check(school.alive_count() == 34, "no fish came back")
	var moved := school.leader_position.distance_to(school.home)
	check(moved < settings.roam_radius + 20.0, "it's still roaming near home")
	print("school_eat_probe: %d failed" % failures)
	get_tree().quit(1 if failures else 0)


func _school(settings: NatureSettings) -> School:
	var school := School.new()
	add_child(school)
	school.setup(settings, Vector3.ZERO, Vector3.FORWARD, FishCharacter.FishClass.SKIRMISHER, 7)
	return school


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## The `count` live fish nearest `point`.
func _nearest_to(school: School, point: Vector3, count: int) -> Array:
	var list: Array = []
	for i in school.fish_count():
		list.append([school.fish_position(i).distance_to(point), i])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return list.slice(0, count).map(func(entry: Array) -> int: return entry[1])


## The fastest any live fish within `reach` of `at` swims now (m/s).
func _max_speed_gain(school: School, at: Vector3, reach: float) -> float:
	var top := 0.0
	for i in school.fish_count():
		if school.is_alive(i) and school.fish_position(i).distance_to(at) < reach:
			top = maxf(top, school.fish_velocity(i).length())
	return top


func _farthest_from_middle(school: School) -> float:
	var middle := school.middle()
	var far := 0.0
	for i in school.fish_count():
		if school.is_alive(i):
			far = maxf(far, school.fish_position(i).distance_to(middle))
	return far
