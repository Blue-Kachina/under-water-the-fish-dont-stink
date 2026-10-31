extends Node
## Not a probe: screenshots of the murk (planning_murk.md) for checking it by
## eye: packs at 15 to 150 m round a fish in the murk (bodies near, red eyes
## further out), looking up at the surface (no light ring), the minimap with
## swarms, elites, a boss and chests, and the same without murk. Needs a
## window (not --headless).
## The distance ladder (planning_bosses_and_survival.md §1): one zombie facing
## the camera at 8, 20, 40, 80 and 140 m (ladder_<m>.png), printing how red the
## brightest bit round it is ("eyes"; it should fall with distance).
##   Godot_console.exe --path . res://tests/murk_shots.tscn -- --out=DIR

var out_dir := "user://murk_shots"
var main: Node
var fish: FishController


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	settings.spawning = false
	settings.enemy_speed_scale = 0.0  # they hold still where they're put
	settings.god_mode = true
	main.set_mode(main.UNNATURAL)
	await _frames(5)
	main._match_card.play_requested.emit()
	await _frames(10)
	var run: UnnaturalRun = main.unnatural_run
	var horde := run.horde
	run.start()
	await _frames(20)
	fish.freeze = true
	settings.card_choices = 0  # no level-up pause mid-ladder
	await _ladder(horde)
	var ahead := -fish.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var side := Vector3.UP.cross(ahead)
	# Packs at 15, 30, 50, 75, 100, 130 and 150 m, ahead and to the sides.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var n := 0
	for gap: float in [15.0, 30.0, 50.0, 75.0, 100.0, 130.0, 150.0]:
		for lean: float in [-0.5, 0.0, 0.5]:
			var middle := fish.global_position + (ahead + side * lean).normalized() * gap
			for k in 14:
				var spot := middle + Vector3(rng.randf_range(-4, 4), rng.randf_range(-2, 2), rng.randf_range(-4, 4))
				horde.spawn(0 if n % 3 else 1 + n % 4, spot, -ahead, n % 23 == 0)
				n += 1
	# And a big swarm behind, for the minimap.
	for k in 120:
		horde.spawn(0, fish.global_position - ahead * 40.0 + Vector3(rng.randf_range(-10, 10), 0.0, rng.randf_range(-10, 10)), ahead)
	run.add_chest(fish.global_position + side * 30.0 + ahead * 10.0, 0.0)
	run.add_chest(fish.global_position - side * 140.0, 0.0)
	await _seconds(1.0)
	await _shot("murk")
	print("drawn %d of %d, eyes %d, cull %.0f m, eyes %.0f..%.0f m" % [horde.drawn_count, horde.alive_count(), horde.glint_count,
			horde.cull_distance, horde.glint_near, horde.glint_far])
	run._start_event("miniboss")
	await _seconds(1.5)
	await _shot("murk_boss")
	# Looking up at the surface: no ring of light where it meets the sky.
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.global_position = run.centre + Vector3(0.0, 5.0, 0.0)
	camera.look_at(run.centre + Vector3(0.0, 40.0, -150.0))
	await _frames(4)
	await _shot("murk_up")
	camera.current = false
	camera.queue_free()
	# The same without murk.
	settings.murk_density = 0.0
	await _seconds(0.5)
	await _shot("clear")
	settings.murk_density = 0.035
	get_tree().quit()


## One zombie at each rung, alone, with its eyes measured off the screen.
func _ladder(horde: Horde) -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var ahead := -fish.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var side := Vector3.UP.cross(ahead)
	var from := fish.global_position + side * 25.0 + Vector3.UP * 3.0  # clear of the fish and its weapon
	camera.global_transform = Transform3D(Basis.looking_at(ahead), from)
	var cameras := School.view_cameras
	School.view_cameras = [camera] as Array[Camera3D]
	var last := INF
	var falling := true
	for gap: float in [8.0, 20.0, 40.0, 80.0, 140.0]:
		horde.clear()
		var at := from + ahead * gap
		horde.spawn(1, at, (-ahead + side * 0.7).normalized())  # a clownfish, three-quarters on
		await _frames(10)
		await _shot("ladder_%d" % int(gap))
		var image := get_viewport().get_texture().get_image()
		var centre := camera.unproject_position(at)
		var per_metre := absf(camera.unproject_position(at + side).x - centre.x)
		var half := int(maxf(per_metre * 1.5, 10.0))
		# How much redder than the water round it its reddest pixel is (the
		# blood moon tints the water red, so the window's median is taken off).
		var reds: Array[float] = []
		var peak := 0.0
		for y in range(maxi(int(centre.y) - half, 0), mini(int(centre.y) + half, image.get_height())):
			for x in range(maxi(int(centre.x) - half, 0), mini(int(centre.x) + half, image.get_width())):
				var c := image.get_pixel(x, y)
				var red := c.r - maxf(c.g, c.b)
				reds.append(red)
				peak = maxf(peak, red)
		reds.sort()
		var water := reds[reds.size() / 2] if not reds.is_empty() else 0.0
		peak -= water
		var zoom := image.get_region(Rect2i(Vector2i(int(centre.x) - 40, int(centre.y) - 40), Vector2i(80, 80)))
		zoom.resize(320, 320, Image.INTERPOLATE_NEAREST)
		zoom.save_png(out_dir.path_join("ladder_%d_zoom.png" % int(gap)))
		print("ladder %3d m: eyes %.3f (reddest pixel over the water), %d px window, glints drawn %d" % [int(gap), peak, half * 2, horde.glint_count])
		if peak > last + 0.02:
			falling = false
		last = peak
	print("ladder: eye brightness %s with distance" % ("FALLS" if falling else "does NOT fall"))
	horde.clear()
	School.view_cameras = cameras
	camera.current = false
	camera.queue_free()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % shot_name))
	print("shot ", shot_name)


func _seconds(s: float) -> void:
	var left := s
	while left > 0.0:
		await RenderingServer.frame_post_draw
		left -= get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
