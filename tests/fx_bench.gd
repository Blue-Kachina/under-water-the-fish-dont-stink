extends Node
## Not a probe: what Greek Fire's patches cost to draw, in a window with the
## real renderer. The Test Tank with no horde, the player parked, and in turn:
## nothing; --patches=N (default 80, fire_max_patches) of today's flame
## patches (GreekFire.FirePatch) in front of the camera; and the same of the
## old glowing balls (OldPatch, kept here to compare). Prints each one's frame
## time (average and worst), process time and draw calls.
##   Godot_console.exe --path . res://tests/fx_bench.tscn -- --patches=80 --seconds=5

var patches := 80
var seconds := 5.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--patches="):
			patches = arg.trim_prefix("--patches=").to_int()
		elif arg.begins_with("--seconds="):
			seconds = arg.trim_prefix("--seconds=").to_float()
	get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred(main)


func _run(main: Node) -> void:
	UnnaturalSettings.shared().tank_horde = 0
	main.set_mode(main.TEST_TANK)
	await _frames(5)
	main._match_card.play_requested.emit()
	await _frames(10)
	var run: UnnaturalRun = main.unnatural_run
	var fish: FishController = main.get_node("Fish")
	fish.freeze = true
	await _seconds(1.0)
	await _measure("nothing")
	for kind in ["flames", "old balls"]:
		var camera := get_viewport().get_camera_3d()
		var made: Array[Node3D] = []
		for i in patches:
			var patch: Node3D = GreekFire.FirePatch.new() if kind == "flames" else OldPatch.new()
			patch.set("lifetime", 1000.0)
			# A trail snaking away in front of the camera, 3 to 40 m out.
			var depth := 3.0 + 37.0 * i / patches
			patch.position = camera.global_position - camera.global_basis.z * depth + camera.global_basis.x * sin(i * 0.4) * depth * 0.3
			run.add_child(patch)
			made.append(patch)
		await _seconds(1.0)
		await _measure(kind)
		for patch in made:
			patch.queue_free()
		await _frames(3)
	get_tree().quit()


func _measure(what: String) -> void:
	var frames := 0
	var worst := 0.0
	var process_ms := 0.0
	var draws := 0.0
	var started := Time.get_ticks_usec()
	var last := started
	while (Time.get_ticks_usec() - started) / 1e6 < seconds:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var elapsed := (Time.get_ticks_usec() - started) / 1e6
	print("BENCH fire %s x%d  frame %.2f ms avg (%.0f fps), worst %.1f ms  process %.2f ms  draw calls %.0f" % [
		what, patches if what != "nothing" else 0, elapsed * 1000.0 / frames, frames / elapsed, worst, process_ms / frames, draws / frames])


func _seconds(s: float) -> void:
	var left := s
	while left > 0.0:
		await RenderingServer.frame_post_draw
		left -= get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


## Greek Fire's patch as it was before its flames: a flickering additive ball.
class OldPatch extends Node3D:
	var radius := 1.6
	var lifetime := 2.0
	var age := 0.0
	var _material := StandardMaterial3D.new()
	var _ball := MeshInstance3D.new()

	func _ready() -> void:
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_material.albedo_color = Color(1.0, 0.45, 0.1, 0.6)
		sphere.material = _material
		_ball.mesh = sphere
		_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ball)

	func _process(delta: float) -> void:
		age += delta
		var flicker := 0.85 + 0.15 * sin(age * 23.0 + position.x)
		_ball.scale = Vector3(radius, radius * 0.6, radius) * flicker * clampf(age / 0.15, 0.3, 1.0)
		_material.albedo_color = Color(1.0, 0.4 + 0.15 * flicker, 0.1, 0.55)
