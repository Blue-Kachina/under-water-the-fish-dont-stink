extends Node3D
## A School on its own (NatureSettings defaults unless changed): it keeps
## together, swims mostly in unison and keeps its fish apart; it turns as one,
## the back following the front; it roams near home; the school size, fish size
## and spread change live; it's drawn through its baked looks, with full models
## only for the few fish nearest the camera; and its step stays within budget
## for lots of fish.
##   Godot_console.exe --headless --path . res://tests/school_probe.tscn

## One step of ten schools of 50 (ms).
const BUDGET_MS := 4.0

var failures := 0
var camera := Camera3D.new()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	add_child(camera)
	camera.global_position = Vector3(0, 500, 0)  # far off: no full models yet
	camera.make_current()
	_run.call_deferred()


func _run() -> void:
	var settings := NatureSettings.new()
	settings.fish_per_school = 8
	settings.fish_scale = 0.5
	settings.spread = 1.4
	var school := _school(settings, Vector3.ZERO, Vector3.FORWARD)

	print("together:")
	check(school.fish_count() == 8, "%d fish" % school.fish_count())
	await _ticks(1200)  # 10 s
	var reach := _farthest_from_centre(school)
	check(reach < school.radius() * 1.6 + settings.wander, "every fish within the school (farthest %.2f m of %.2f)" % [reach, school.radius()])
	var closest := _closest_pair(school)
	check(closest > settings.separation * 0.4, "none on top of another (closest %.2f m)" % closest)
	var unison := _unison(school)
	check(unison > 0.9, "swimming in unison (mean heading dot %.3f)" % unison)
	var speed := _mean_speed(school)
	check(absf(speed - settings.school_speed) < 1.5, "at the school's cruise (%.1f m/s of %.1f)" % [speed, settings.school_speed])
	var from_home := school.leader_position.distance_to(school.home)
	check(from_home < settings.roam_radius + 10.0, "roaming near home (%.1f m)" % from_home)
	var steepest := 0.0
	for i in school.fish_count():
		steepest = maxf(steepest, absf(school.fish_heading(i).y))
	check(steepest < sin(deg_to_rad(settings.max_climb + 25.0)), "no fish steeper than the school climbs, give or take (%.0f degrees)" % rad_to_deg(asin(steepest)))

	print("turning:")
	# Point the leader straight back: the front of the school turns before the back.
	school.leader_heading = -school.leader_heading
	var front := 0
	var rear := 0
	for i in school.fish_count():
		if school.fish_slot_back(i) < school.fish_slot_back(front):
			front = i
		if school.fish_slot_back(i) > school.fish_slot_back(rear):
			rear = i
	var front_turned := -1
	var rear_turned := -1
	for tick in 600:
		await get_tree().physics_frame
		if front_turned < 0 and school.fish_velocity(front).dot(school.leader_heading) > 0.0:
			front_turned = tick
		if rear_turned < 0 and school.fish_velocity(rear).dot(school.leader_heading) > 0.0:
			rear_turned = tick
	check(front_turned >= 0 and rear_turned >= 0, "the whole school turned round")
	check(rear_turned > front_turned, "the turn ripples back (front at tick %d, back at %d)" % [front_turned, rear_turned])
	await _ticks(600)
	unison = _unison(school)
	check(unison > 0.9, "back in unison after (%.3f)" % unison)

	print("drawn:")
	var looks := school.find_children("*", "MultiMeshInstance3D", true, false)
	check(looks.size() == SchoolLook.POSES.size(), "one baked look per tail pose (%d)" % looks.size())
	check(_shown(looks) == 8 and school.detail_count() == 0, "far from the camera every fish is in the looks (%d), no full models" % _shown(looks))
	var drawn_size := _drawn_size(looks)
	check(is_equal_approx(drawn_size, 0.5), "drawn at fish_scale (%.2f)" % drawn_size)
	check(looks.all(func(l: MultiMeshInstance3D) -> bool: return l.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "no shadows by default")
	camera.global_position = school.fish_position(0) + Vector3(0, 1, 3)
	await _frames(30)
	var details := school.detail_count()
	check(details > 0 and details <= settings.detail_fish, "near the camera the nearest get full models (%d)" % details)
	check(_shown(looks) + details == 8, "and leave the looks (%d + %d)" % [_shown(looks), details])
	camera.global_position = Vector3(0, 500, 0)
	await _frames(30)
	check(school.detail_count() == 0 and _shown(looks) == 8, "and give them back when it's gone")

	print("live changes:")
	settings.fish_per_school = 14
	await _ticks(2)
	check(school.fish_count() == 14, "more fish join (%d)" % school.fish_count())
	settings.fish_per_school = 5
	await _ticks(2)
	check(school.fish_count() == 5, "and leave (%d)" % school.fish_count())
	var tight := _farthest_from_centre(school)
	settings.spread *= 2.5
	await _ticks(600)
	var wide := _farthest_from_centre(school)
	check(wide > tight * 1.5, "a bigger spread loosens it (%.2f m -> %.2f m)" % [tight, wide])
	settings.fish_scale = 1.5
	await _frames(3)
	drawn_size = _drawn_size(looks)
	check(is_equal_approx(drawn_size, 1.5), "fish size follows fish_scale (%.2f)" % drawn_size)
	settings.fish_shadows = true
	await _frames(2)
	check(looks.all(func(l: MultiMeshInstance3D) -> bool: return l.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON), "shadows when asked for")
	settings.school_speed = 0.0
	await _ticks(600)  # settle
	var held := school.leader_position
	await _ticks(600)
	var moved := school.leader_position.distance_to(held)
	var drift := _mean_speed(school)
	check(moved < 0.01 and drift < 2.0, "school speed 0 holds it in place, turning on the spot (%.2f m in 5 s, fish at %.2f m/s)" % [moved, drift])
	settings.sim_rate = 10.0
	settings.school_speed = 6.0
	await _ticks(600)
	unison = _unison(school)
	check(unison > 0.85, "still schools at a 10 Hz step (%.3f)" % unison)
	school.queue_free()

	print("centre:")
	var other := _school(NatureSettings.new(), Vector3(0, 0, -50), Vector3.RIGHT)
	await _ticks(120)
	var middle := Vector3.ZERO
	for i in other.fish_count():
		middle += other.fish_position(i)
	middle /= other.fish_count()
	check(other.centre.visible and other.centre.global_position.distance_to(middle) < 1.0, "centre follows the middle of the fish")
	other._alive.fill(0)
	await _frames(2)
	check(other.alive_count() == 0 and not other.centre.visible, "hidden once none are left")
	other.queue_free()

	print("budget:")
	var heavy := NatureSettings.new()  # the defaults: 50 fish a school
	var many: Array[School] = []
	for i in 10:
		var one := _school(heavy, Vector3(i * 30.0, 0, 0), Vector3.FORWARD)
		one.set_physics_process(false)
		one.set_process(false)
		many.append(one)
	var started := Time.get_ticks_usec()
	var steps := 60
	for step in steps:
		for one in many:
			one._step(1.0 / heavy.sim_rate)
	var per_step := (Time.get_ticks_usec() - started) / 1000.0 / steps
	started = Time.get_ticks_usec()
	for frame in steps:
		for one in many:
			one._draw(1.0 / 60.0)
	var per_frame := (Time.get_ticks_usec() - started) / 1000.0 / steps
	check(per_step < BUDGET_MS, "10 schools of 50: %.2f ms a step at %.0f Hz (%.1f ms a second); drawing %.2f ms a frame" % [
			per_step, heavy.sim_rate, per_step * heavy.sim_rate, per_frame])

	print("school_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _school(settings: NatureSettings, at: Vector3, heading: Vector3) -> School:
	var school := School.new()
	add_child(school)
	school.setup(settings, at, heading, FishCharacter.Family.OCTANE)
	return school


func _shown(looks: Array) -> int:
	var shown := 0
	for look: MultiMeshInstance3D in looks:
		shown += look.multimesh.visible_instance_count
	return shown


## The size of the first fish drawn in the looks, from the buffer the school
## hands them (headless rendering doesn't keep instance transforms).
func _drawn_size(looks: Array) -> float:
	var school: School = looks[0].get_parent()
	for pose in looks.size():
		if looks[pose].multimesh.visible_instance_count > 0:
			var buffer: PackedFloat32Array = school._buffers[pose]
			return Vector3(buffer[0], buffer[4], buffer[8]).length()
	return 0.0


func _farthest_from_centre(school: School) -> float:
	var farthest := 0.0
	for i in school.fish_count():
		farthest = maxf(farthest, school.fish_position(i).distance_to(school.centre.global_position))
	return farthest


func _closest_pair(school: School) -> float:
	var closest := INF
	for a in school.fish_count():
		for b in school.fish_count():
			if a != b:
				closest = minf(closest, school.fish_position(a).distance_to(school.fish_position(b)))
	return closest


func _unison(school: School) -> float:
	var total := 0.0
	for i in school.fish_count():
		total += school.fish_velocity(i).normalized().dot(school.leader_heading)
	return total / school.fish_count()


func _mean_speed(school: School) -> float:
	var total := 0.0
	for i in school.fish_count():
		total += school.fish_velocity(i).length()
	return total / school.fish_count()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
