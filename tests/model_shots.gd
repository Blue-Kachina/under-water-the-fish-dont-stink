extends Node3D
## Not a probe: screenshots of one fish model on its own (front three-quarter,
## side, top, back and below) for checking its look by eye. Needs a window
## (not --headless).
##   Godot_console.exe --path . res://tests/model_shots.tscn -- --fish=plank --out=DIR

var out_dir := "user://model_shots"
var fish_key := "plank"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--fish="):
			fish_key = arg.trim_prefix("--fish=")
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
	var model := FishModel.build(FishCharacter.from_key(fish_key))
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
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [fish_key, view]))
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
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_swim_%s.png" % [fish_key, view]))
	get_tree().quit()
