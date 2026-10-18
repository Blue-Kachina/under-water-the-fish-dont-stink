extends Node
## Schools in a Nature run (NatureRun + School, NatureSettings): three schools
## of fifty turn up with the lone fish; ball cam looks at the nearest thing ahead
## and picks again when pressed; the school count and the lone fish follow their
## settings live; a school left behind is replaced out of view; the panel shows
## NATURE with whole-number sliders that take preset values past their end; and
## tuning changed in Nature is kept for the next visit, while leaving still puts
## the tuning from before back.
##   Godot_console.exe --headless --path . res://tests/nature_schools_probe.tscn

var main: Node
var fish: FishController
var camera: Node
var settings := NatureSettings.shared()
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	var stride_before := fish.stride_force
	main.set_mode(main.NATURE)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: NatureRun = main.nature_run

	print("schools:")
	check(run.schools.size() == 3, "three schools (%d)" % run.schools.size())
	check(run.schools.all(func(s: School) -> bool: return s.fish_count() == 50), "of fifty fish each (Nature's defaults)")
	var first := run.schools[0].centre.global_position.distance_to(fish.global_position)
	check(absf(first - settings.first_school_distance) < 5.0, "the first waits %.1f m off" % first)
	check(camera.ball == run.target and run.focus == run.target, "ball cam on the lone fish, nearest ahead")

	print("lone fish off:")
	settings.lone_target = false
	await _ticks(3)
	check(run.target.battered and not run.target.visible, "the lone fish goes")
	check(run.focus is Node3D and run.focus.get_parent() is School and camera.ball == run.focus, "ball cam moves to a school")

	print("ball cam picks again:")
	var other: School = null
	for school in run.schools:
		if school.centre != run.focus:
			other = school
	# 12 m behind the other school, facing it.
	var to_other := (other.centre.global_position - fish.global_position).normalized()
	fish.global_transform = Transform3D(Basis.looking_at(to_other, Vector3.UP), other.centre.global_position - to_other * 12.0)
	fish.linear_velocity = Vector3.ZERO
	await _ticks(2)
	check(run.focus != other.centre, "ball cam stays put until pressed")
	await _press_ball_cam()
	await _press_ball_cam()  # off and on again
	check(run.focus == other.centre and camera.ball == other.centre and camera.ball_cam, "pressing it looks at the school ahead now")

	print("school count:")
	settings.school_count = 5
	await _ticks(3)
	check(run.schools.size() == 5 and run.get_children().filter(func(n: Node) -> bool: return n is School).size() == 5, "up to five")
	settings.school_count = 1
	await _ticks(3)
	check(run.schools.size() == 1, "down to one")
	settings.school_count = 3
	await _ticks(3)

	print("left behind:")
	var stray := run.schools[0]
	var ahead := -fish.global_basis.z
	fish.global_position = stray.leader_position + Vector3(settings.leash + 20.0, 0, 0)
	await _ticks(3)
	check(not is_instance_valid(stray) or stray.is_queued_for_deletion() or stray not in run.schools, "a school past the leash is replaced")
	check(run.schools.size() == 3, "still three")
	ahead = -fish.global_basis.z
	var newest := run.schools[-1]
	var offset := newest.leader_position - fish.global_position
	check(offset.length() >= settings.spawn_distance_min - 1.0 and offset.length() <= settings.spawn_distance_max + 1.0,
			"the new one turns up %.1f m off" % offset.length())
	check(offset.normalized().dot(ahead) < NatureRun.SPAWN_HIDDEN, "out of view ahead")
	settings.lone_target = true
	await _ticks(3)
	check(not run.target.battered and run.target.visible, "the lone fish comes back when switched on")

	print("panel:")
	var panel: Node = main._panel
	var slider: Dictionary = panel.option_range("nature/school_count")
	check(slider.get("whole", false) and is_equal_approx(slider.get("step", 0.0), 1.0) and slider.get("allow_greater", false),
			"NATURE section: school_count is a whole-number slider that allows more")
	panel._apply("nature", {"school_count": 40.0})
	check(settings.school_count == 40 and typeof(settings.school_count) == TYPE_INT, "a preset value past the end applies (%s)" % settings.school_count)
	panel._apply("nature", {"school_count": 3})
	await _ticks(3)

	print("tuning kept:")
	fish.stride_force = 99.0
	settings.fish_per_school = 6
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	check(is_equal_approx(fish.stride_force, stride_before) and settings.fish_per_school == 50, "leaving puts the tuning from before back")
	main.set_mode(main.NATURE)
	await _ticks(3)
	check(is_equal_approx(fish.stride_force, 99.0) and settings.fish_per_school == 6, "coming back keeps the changes made in Nature")
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)

	print("nature_schools_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _press_ball_cam() -> void:
	Input.action_press("ball_cam")
	await _ticks(12)
	Input.action_release("ball_cam")
	await _ticks(12)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
