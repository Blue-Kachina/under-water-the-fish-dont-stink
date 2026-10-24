extends Node
## Not a probe: screenshots of Nature's schools (School) for checking them by
## eye: a school of each kind of fish from the side and from behind as it
## swims, one mid-turn, and the chase camera in a Nature run with ball cam on a
## school. Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/school_shots.tscn -- --out=DIR

var out_dir := "user://school_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean")
	main.get_node("DebugPanel").load_mode_preset(main.NATURE_PRESET)
	_run.call_deferred(main)


func _run(main: Node) -> void:
	var fish: FishController = main.get_node("Fish")
	fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 200, 0)))  # out of the way
	var shot := Camera3D.new()
	shot.fov = 50.0
	add_child(shot)
	var settings := NatureSettings.shared()
	for key: String in ["skirmisher", "hunter", "glider", "lancer", "charmer", "bulwark"]:
		var school := School.new()
		main._environment.add_child(school)
		school.setup(settings, Vector3.ZERO, Vector3.FORWARD, FishCharacter.from_key(key))
		await _seconds(4.0)
		var centre := school.centre.global_position
		var heading := school.leader_heading
		var right := heading.cross(Vector3.UP).normalized()
		shot.make_current()
		_aim(shot, centre + right * 9.0 + Vector3.UP * 1.5, centre)
		await _frames(2)
		_save("%s_side" % key)
		_aim(shot, centre - heading * 10.0 + Vector3.UP * 2.0, centre)
		await _frames(2)
		_save("%s_behind" % key)
		_aim(shot, centre + Vector3.UP * 12.0 + right * 0.1, centre)
		await _frames(2)
		_save("%s_above" % key)
		if key == "skirmisher":
			# A sharp turn, shot from above while it ripples through.
			school.leader_heading = right
			await _seconds(0.6)
			centre = school.centre.global_position
			_aim(shot, centre + Vector3.UP * 14.0 + heading * 0.1, centre)
			await _frames(2)
			_save("octane_turning")
		school.queue_free()
		await _frames(2)

	# A Nature run: the chase camera with ball cam on a school.
	settings.lone_target = false
	main.set_mode(main.NATURE)
	await _frames(3)
	main._match_card.play_requested.emit()
	await _seconds(1.0)
	var chase: Camera3D = main.get_node("FollowCamera")
	chase.make_current()
	var run: NatureRun = main.nature_run
	# Close behind the school ball cam is on, so it's in the frame.
	var school_centre: Vector3 = run.focus.global_position
	var to_school := (school_centre - fish.global_position).normalized()
	fish.set_spawn(Transform3D(Basis.looking_at(to_school, Vector3.UP), school_centre - to_school * 14.0))
	chase.snap()
	await _seconds(1.5)
	_save("nature_chase")

	# The school wheel, open.
	var wheel: TargetWheel = main._target_wheel
	wheel.open()
	await _frames(4)
	_save("wheel")
	wheel.is_open = false

	# A ram through a school at speed: the multi callout and the chain bar.
	var school: School = run.focus.get_parent()
	var middle := school.middle()
	var line := (middle - fish.global_position).normalized()
	line.y = 0.0
	line = line.normalized()
	fish.set_spawn(Transform3D(Basis.looking_at(line, Vector3.UP), middle - line * 14.0))
	chase.snap()
	var shot_multi := false
	for i in 200:
		fish.linear_velocity = line * 22.0
		await RenderingServer.frame_post_draw
		if not shot_multi and run.score.chain >= 2:
			await _seconds(0.25)
			_save("multi")
			shot_multi = true
	fish.linear_velocity = Vector3.ZERO

	# A pearl, close up, with the player beside it.
	settings.magnet_radius = 0.0  # so it stays put for the picture
	var pearl := Pearl.new(settings)
	pearl.position = chase.global_position + (-chase.global_basis.z) * 2.5 + chase.global_basis.x * 0.5
	run.add_child(pearl)
	await _seconds(0.5)
	_save("pearl")
	settings.magnet_radius = 6.0

	settings.lone_target = true
	get_tree().quit()


func _aim(camera: Camera3D, from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at, Vector3.UP if absf((at - from).normalized().y) < 0.95 else Vector3.FORWARD)


func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % name))


func _seconds(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await RenderingServer.frame_post_draw
		left -= get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
