extends Node3D
## Not a probe: screenshots of one fish model on its own (front three-quarter,
## side, top, back and below) for checking its look by eye, then swimming,
## wagging its tail (top views, to see the tail stay on the body) and mid
## stride. Needs a window (not --headless). `--skin=N` picks a skin
## (FishCharacter.SKINS); its shots are named <fish>_<skin key>_<view>.png.
##   Godot_console.exe --path . res://tests/model_shots.tscn -- --fish=plank --skin=1 --out=DIR

var out_dir := "user://model_shots"
var fish_key := "plank"
var skin := 0
var _name := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--fish="):
			fish_key = arg.trim_prefix("--fish=")
		elif arg.begins_with("--skin="):
			skin = int(arg.trim_prefix("--skin="))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(900, 700)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.82, 0.88, 0.94)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.6, 0.0)
	sun.light_energy = 1.2
	add_child(sun)
	var family := FishCharacter.from_key(fish_key)
	var model := FishModel.build(family, skin)
	_name = "%s_%s" % [fish_key, FishCharacter.skin_key(family, model.skin)]
	add_child(model)
	_run.call_deferred(model)


func _run(model: FishModel) -> void:
	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.make_current()
	var reach := model._size.length() * 1.15
	var views := {
		"front": Vector3(-0.8, 0.45, -1.0),
		"side": Vector3(-1.0, 0.05, 0.0),
		"top": Vector3(0.0, 1.0, 0.01),
		"back": Vector3(0.6, 0.6, 1.0),
		"below": Vector3(-0.5, -0.6, -0.7),
	}
	for view: String in views:
		camera.position = Vector3(views[view]).normalized() * reach
		camera.look_at(Vector3.ZERO, Vector3.FORWARD if view == "top" else Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [_name, view]))
	# Mid-swim: fins rolled and swept as the swim animation leaves them, a moment
	# into swimming at full speed.
	model.fin_left.rotation = Vector3(0.0, 0.5, -0.5)
	model.fin_right.rotation = Vector3(0.0, -0.5, 0.5)
	model.tail.rotation.y = 0.3
	for i in 20:
		model.react(1.0 / 60.0, Vector3(0.0, 0.0, -23.0))
	for view: String in ["front", "back"]:
		camera.position = Vector3(views[view]).normalized() * reach
		camera.look_at(Vector3.ZERO, Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_swim_%s.png" % [_name, view]))
	# Wagging: the tail swung hard each way and up, seen from above and the
	# side, to check it stays on the body (FishModel._bend_body).
	model.fin_left.rotation = Vector3.ZERO
	model.fin_right.rotation = Vector3.ZERO
	for wag: Array in [["wag_left", Vector3(0.0, -0.9, 0.0), "top"], ["wag_right", Vector3(0.0, 0.9, 0.0), "top"],
			["wag_up", Vector3(-0.6, 0.0, 0.0), "side"], ["wag_three", Vector3(0.0, 0.7, 0.0), "back"]]:
		model.tail.rotation = wag[1]
		model.react(1.0 / 60.0, Vector3(0.0, 0.0, -10.0))
		camera.position = Vector3(views[wag[2]]).normalized() * reach
		camera.look_at(Vector3.ZERO, Vector3.FORWARD if wag[2] == "top" else Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [_name, wag[0]]))
	model.tail.rotation = Vector3.ZERO
	# Mid-stride: an Extra Swishy stride pushing left (the tail swung left),
	# nearly at its peak, turning left; then fading, a moment later.
	model.fin_left.rotation = Vector3.ZERO
	model.fin_right.rotation = Vector3.ZERO
	model.tail.rotation.y = -0.6
	model.stride_swing = Vector2(-1.0, 0.0)
	for shot: Array in [["stride", 18, 0.0], ["recover", 12, -1.0]]:
		for i in shot[1]:
			model.stride_power = clampf(model.stride_power + (1.0 / 18.0 if shot[2] >= 0.0 else -1.0 / 12.0), 0.0, 1.0)
			model.rotate_y(1.5 / 60.0)
			model.react(1.0 / 60.0, model._body_frame() * Vector3(0.0, 0.0, -18.0))
		camera.position = model.global_basis * Vector3(views["back"]).normalized() * reach
		camera.look_at(Vector3.ZERO, Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s_back.png" % [_name, shot[0]]))
	get_tree().quit()
