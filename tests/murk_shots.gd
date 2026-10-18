extends Node
## Not a probe: screenshots of the murk (planning_murk.md) for checking it by
## eye: packs at 15 to 150 m round a fish in the murk (bodies near, red eyes
## further out), looking up at the surface (no light ring), the minimap with
## swarms, elites, a boss and chests, and the same without murk. Needs a
## window (not --headless).
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
