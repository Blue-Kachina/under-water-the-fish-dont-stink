extends Node
## The Obstacle Course as a migrating mode (planning_core_roadmap.md 3.3, item 4), step H0: a
## scripted, seeded run through the real game that records coarse snapshots of the mode's seams
## (mode lists, environment, survivor cam on and ball cam off, the CourseSkill, the fish's tuning,
## R, picking it again, leaving for another mode) to tests/fixtures/course_baseline.json. Every
## migration step must keep it matching. Flags, counts and tuning only.
##   Godot_console.exe --headless --path . res://tests/course_baseline_probe.tscn
##   ... -- --record    rewrite the fixture

const BASELINE := "res://tests/fixtures/course_baseline.json"

var main: Node
var fish: FishController
var camera: Node
var failures := 0
var snaps: Array[Dictionary] = []
var record := false


func _ready() -> void:
	seed(20261121)
	record = "--record" in OS.get_cmdline_args() or "--record" in OS.get_cmdline_user_args()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _skill() -> Node:
	return main.find_child("CourseSkill", true, false)


func _arena() -> Arena:
	return main.get_node_or_null("ObstacleCourse") as Arena


func _run() -> void:
	SurvivorCamSettings.shared().steady_camera = true
	TraversalSettings.shared().twists = true
	fish.character = FishCharacter.FishClass.LANCER
	print("before:")
	main.set_mode(main.FREE_PLAY, false)
	await _ticks(3)
	var max_speed_before := fish.max_speed
	camera.ball_cam = true
	_snap("free_play")

	print("course:")
	main.set_mode(main.OBSTACLE_COURSE, false)
	await _ticks(3)
	check(main.current_environment == "Obstacle Course" and _arena() != null, "the course plays in the Obstacle Course")
	check(main._match_card == null and fish.visible, "no card: the course plays at once")
	check(bool(camera.get("steady_heading")) and not camera.ball_cam, "survivor cam on, ball cam off")
	check(camera.course == _arena(), "the camera has the course (ring cam)")
	check(not fish.boost_enabled and fish.swim_strokes, "Nature's tuning: strides, no boost")
	var skill := _skill()
	check(skill != null and skill.get("twist") != null and skill.twist.run == null, "the CourseSkill with its traversal, no run")
	check(main._reset_label() == "Reset", "R resets")
	_snap("course")

	print("reset:")
	var arena := _arena()
	arena.running = true
	arena.next_hoop = 2
	arena.course_time = 5.0
	var spawn: Transform3D = arena.spawn_transform()
	fish.global_position = spawn.origin + Vector3(20.0, 3.0, -15.0)
	main.reset_play()
	await _ticks(3)
	check(not arena.running and arena.next_hoop == 0 and arena.course_time == 0.0, "R resets the course")
	check(fish.global_position.distance_to(spawn.origin) < 2.0, "and puts the fish back at the start")
	check(_skill() == skill, "the same CourseSkill")
	_snap("reset")

	print("picked again:")
	arena.next_hoop = 1
	fish.global_position = spawn.origin + Vector3(10.0, 0.0, 10.0)
	main.start_mode(main.OBSTACLE_COURSE)
	await _ticks(3)
	check(arena.next_hoop == 0 and fish.global_position.distance_to(spawn.origin) < 2.0, "picking it again resets it")
	_snap("picked_again")

	print("character:")
	fish.global_position = spawn.origin + Vector3(10.0, 0.0, 10.0)
	main.set_character(FishCharacter.FishClass.SKIRMISHER)
	await _ticks(3)
	check(fish.global_position.distance_to(spawn.origin) < 2.0, "a new character starts at the spawn")
	_snap("character")

	print("leaving:")
	main.set_mode(main.FREE_PLAY, false)
	await _ticks(3)
	check(not bool(camera.get("steady_heading")) and fish.boost_enabled, "Free Play: the usual camera and tuning back")
	check(_skill() == null or skill.is_queued_for_deletion(), "the CourseSkill gone")
	check(is_equal_approx(fish.max_speed, max_speed_before) and fish.speed_scale == 1.0, "the tuning and swimming from before")
	_snap("left_free_play")
	main.set_mode(main.OBSTACLE_COURSE, false)
	await _ticks(3)
	_snap("course_again")
	main.set_mode(main.FREE_SWIM, false)
	await _ticks(3)
	check(not bool(camera.get("steady_heading")) and _skill() == null, "Free Swim: survivor cam and skill off")
	_snap("left_free_swim")

	fish.character = FishCharacter.FishClass.SKIRMISHER
	_finish_baseline()
	print("course_baseline_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


func _snap(label: String) -> void:
	var skill := _skill()
	var arena := _arena()
	var row := {
		"at": label,
		"mode": main.current_mode,
		"environment": main.current_environment,
		"card": main._match_card != null,
		"fish_visible": fish.visible,
		"character": FishCharacter.CLASSES[fish.character].key,
		"swim_style": FishController.SwimStyle.keys()[fish.swim_style],
		"swim_strokes": fish.swim_strokes,
		"boost_enabled": fish.boost_enabled,
		"max_speed": snappedf(fish.max_speed, 0.01),
		"speed_scale": snappedf(fish.speed_scale, 0.01),
		"locked": fish.controls_locked,
		"camera_steady": bool(camera.get("steady_heading")),
		"camera_ball": camera.ball != null,
		"camera_ball_cam": camera.ball_cam,
		"camera_course": camera.course != null,
		"hud_survivor_cam": main._hud.survivor_cam,
		"course_skill": skill != null and not skill.is_queued_for_deletion(),
		"skill_run": skill != null and skill.get("twist") != null and skill.twist.run != null,
		"reset_label": main._reset_label(),
		"arena": arena != null,
	}
	if arena != null:
		row["hoops"] = arena.hoops.size()
		row["next_hoop"] = arena.next_hoop
		row["running"] = arena.running
	if label == "course":
		# The host's mode lists and the picker's tile order: registering the mode must not move them.
		row["modes"] = Array(main.MODES)
		row["match_modes"] = Array(main.MATCH_MODES)
		row["match_modes"].sort()  # a set: its order is not behaviour
		row["nature_modes"] = Array(main.NATURE_MODES)
		row["nature_modes"].sort()
		row["tile_order"] = Array(main.MODE_TILES.keys())
		var tile: Dictionary = main.MODE_TILES[main.OBSTACLE_COURSE]
		row["tile"] = [tile.title, tile.icon, tile.pitch, tile.short, tile.play, str(tile.colors)]
		row["mode_environment"] = main.mode_environment(main.OBSTACLE_COURSE)
	snaps.append(row)


func _finish_baseline() -> void:
	var path := ProjectSettings.globalize_path(BASELINE)
	if record:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var out := FileAccess.open(path, FileAccess.WRITE)
		out.store_string(JSON.stringify({"snaps": snaps}, "\t", true))
		out.close()
		print("  baseline recorded: %s (%d snapshots)" % [path, snaps.size()])
		return
	if not FileAccess.file_exists(BASELINE):
		check(false, "no baseline at %s (run with --record)" % BASELINE)
		return
	var want: Array = JSON.parse_string(FileAccess.get_file_as_string(BASELINE)).snaps
	var got: Array = JSON.parse_string(JSON.stringify({"snaps": snaps})).snaps
	var bad := 0
	for i in maxi(want.size(), got.size()):
		var a: Variant = want[i] if i < want.size() else null
		var b: Variant = got[i] if i < got.size() else null
		if a != b:
			bad += 1
			print("    baseline differs: want %s got %s" % [a, b])
	check(bad == 0, "matches course_baseline.json (%d snapshots)" % snaps.size())
