extends Node3D
## Flora close-ups on a plain background (no seabed, no fog pass): a kelp column and a grass patch lit by one sun.
##   Godot_console.exe --path . res://tests/flora_shot.tscn -- --out=logs/flora_shots/a.png [--cam=x,y,z --look=x,y,z]

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "res://logs/flora_shots/a.png"
	var cam_at := Vector3(50, -22, 36)
	var look_at := Vector3(50, -21.5, 30)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--cam="):
			var p := arg.substr(6).split_floats(",")
			cam_at = Vector3(p[0], p[1], p[2])
		elif arg.begins_with("--look="):
			var p := arg.substr(7).split_floats(",")
			look_at = Vector3(p[0], p[1], p[2])
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.0, 0.25, 0.4)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.3, 0.5, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	var field := FloraField.new()
	add_child(field)
	field.position = Vector3(50, -25, 30)
	var dice := RandomNumberGenerator.new()
	dice.seed = 3
	field.add_kelp_column(Vector3(0, 0, 0), 8.0, 0, 30.0, 1.0, 4.0, 1.0, dice)
	field.add_kelp_column(Vector3(2.5, 0, -1), 7.0, 1, 30.0, 1.0, 4.0, 1.0, dice)
	field.add_kelp_column(Vector3(-2.5, 0, -1), 7.0, 2, 30.0, 1.0, 4.0, 1.0, dice)
	for i in 300:
		field.add_blade(Vector3(dice.randf_range(-4, 4), 0, dice.randf_range(2, 4)), dice.randf_range(0.3, 0.9), dice.randf() * TAU,
				dice.randf_range(0.1, 0.8), dice.randf_range(0.04, 0.08), 0.0, [2, 5, 7][i % 3], dice.randf_range(0.4, 0.9), dice.randf(), dice.randf())
	field.build()
	FloraField.push_look(1.0, 1.0, 1.0, 2.0, 150.0, 0.6)
	var cam := Camera3D.new()
	cam.position = cam_at
	add_child(cam)
	cam.look_at(look_at)
	cam.current = true
	for i in 30:
		await get_tree().process_frame
	var path := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
	get_tree().quit()
