extends Node3D
## Not a probe: screenshots of the Lantern Angler (AnglerModel) on its own for looking at it by eye: a turntable (8 angles),
## close-ups (head, mouth open at 0 / 1 / 2, teeth, esca, eye, fins), the stalk swinging, and a gameplay-distance view.
## Needs a window. D1 tooling.
##   Godot_console.exe --path . res://tests/angler_shots.tscn -- --out=DIR [--set=turn,close,open,stalk,game,fins]
var out_dir := "user://angler_shots"
var sets: Array[String] = ["turn", "close", "open", "stalk", "game", "fins"]
var model: AnglerModel
var camera: Camera3D
var _env: Environment


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--set="):
			sets.clear()
			for s in arg.trim_prefix("--set=").split(","):
				sets.append(s)
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1100, 750)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.01, 0.04, 0.06)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.25, 0.4, 0.5)
	_env.ambient_light_energy = 0.7
	_env.glow_enabled = true
	_env.glow_intensity = 0.8
	_env.glow_bloom = 0.15
	var world := WorldEnvironment.new()
	world.environment = _env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.light_energy = 1.3
	sun.light_color = Color(0.7, 0.85, 1.0)
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(0.5, -2.4, 0.0)
	fill.light_energy = 0.5
	fill.light_color = Color(0.5, 0.7, 0.9)
	add_child(fill)
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.far = 200.0
	add_child(camera)
	camera.make_current()
	model = AnglerModel.new()
	add_child(model)
	model.build(6.0)
	model.position = Vector3(0.0, 0.0, -2.2)
	_run.call_deferred()


func _shot(name: String, at: Vector3, target: Vector3, fov := 38.0) -> void:
	camera.fov = fov
	camera.position = at
	camera.look_at(target, Vector3.UP)
	for i in 3:
		model.pose_straight(0.0, 1.0 / 60.0)
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _run() -> void:
	await get_tree().process_frame
	var mid := model.position + Vector3(0.0, 0.2, 2.6)
	var head := model.position + Vector3(0.0, 0.3, 0.9)
	if "turn" in sets:
		model.jaw_open = 0.0
		for i in 8:
			var a := TAU * i / 8.0
			await _shot("turn_%d" % i, mid + Vector3(sin(a), 0.18, cos(a)) * 11.5, mid)
	if "close" in sets:
		model.jaw_open = 0.0
		await _shot("close_head_closed", head + Vector3(-4.2, 0.9, -4.6), head)
		await _shot("close_side", head + Vector3(-6.5, 0.5, 0.0), head + Vector3(0, 0, 0.6))
		await _shot("close_eye", head + Vector3(-1.9, 0.9, -1.5), model.position + Vector3(-1.1, 0.9, 1.0), 30.0)
		await _shot("close_top", head + Vector3(0.0, 8.0, 1.5), head + Vector3(0, 0, 1.0))
	if "open" in sets:
		for open: float in [0.5, 1.0, 1.6, 2.2]:
			model.jaw_open = open
			await _shot("open_%d_front" % int(open * 10), head + Vector3(-3.6, 1.0, -5.6), head + Vector3(0, -0.3, 0.6))
			await _shot("open_%d_side" % int(open * 10), head + Vector3(-7.5, 0.5, -0.5), head + Vector3(0, 0, 0.6))
		model.jaw_open = 1.0
		await _shot("open_teeth", head + Vector3(-1.4, 0.3, -2.4), head + Vector3(0.2, -0.2, 0.2), 45.0)
		await _shot("open_throat", head + Vector3(0.0, 0.2, -5.0), head + Vector3(0, -0.2, 1.0), 38.0)
		model.jaw_open = 0.0
	if "stalk" in sets:
		model.jaw_open = 0.2
		await _shot("esca_close", model.position + Vector3(-3.0, 2.8, -4.0), model.position + Vector3(0.0, 2.5, -0.4), 40.0)
		model.esca_intensity = 3.0
		await _shot("esca_flare", model.position + Vector3(-3.0, 2.8, -4.0), model.position + Vector3(0.0, 2.5, -0.4), 40.0)
		model.esca_intensity = 1.0
		for i in 8:
			model.update(1.0 / 60.0, Vector3(0.0, 0.0, 30.0) if i < 4 else Vector3.ZERO)
		await _shot("stalk_whip", model.position + Vector3(-7.0, 2.0, 0.0), model.position + Vector3(0.0, 1.8, 0.6))
	if "fins" in sets:
		model.jaw_open = 0.0
		model.set_pectoral(0.0, 0.0)
		await _shot("fins_rest_back", mid + Vector3(5.0, 3.0, 9.0), mid)
		model.set_pectoral(0.6, 0.4)
		await _shot("fins_up_back", mid + Vector3(5.0, 3.0, 9.0), mid)
		model.set_pectoral(-0.5, 0.0)
		await _shot("fins_down_top", mid + Vector3(0.0, 11.0, 2.0), mid)
		model.set_pectoral(0.0, 0.0)
		model.tail_bend = 0.7
		await _shot("tail_snap_top", mid + Vector3(0.0, 11.0, 2.0), mid)
		model.tail_bend = 0.0
	if "game" in sets:
		await _shot("game_chase", mid + Vector3(0.0, 4.0, 15.0), model.position + Vector3(0, 0, -1.0), 55.0)
		await _shot("game_far", mid + Vector3(-18.0, 3.0, -8.0), mid, 40.0)
	get_tree().quit()
