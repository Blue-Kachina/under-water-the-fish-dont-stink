extends Node3D
## Not a probe: screenshots of each Titan's hinged jaw (WhaleJaw) on its own model, for looking at the Hunter
## whales' mouths: shut, half open, wide open (the Bite's fling past wide too) from the side, the front, below,
## and wide open with the throat full. Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/whale_jaw_shots.tscn -- --out=DIR [--species=0,1,2,3,4] [--gape=80]

var out_dir := "user://whale_jaw_shots"
var species_list := [0, 1, 2, 3, 4]
var gape := -1.0
var _camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--species="):
			species_list = []
			for part in arg.trim_prefix("--species=").split(","):
				species_list.append(int(part))
		elif arg.begins_with("--gape="):
			gape = float(arg.trim_prefix("--gape="))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1000, 700)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.2, 0.36, 0.5)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.6, 0.0)
	sun.light_energy = 1.3
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.far = 500.0
	add_child(_camera)
	_camera.make_current()
	_run.call_deferred()


func _run() -> void:
	if gape >= 0.0:
		WhatStinksSettings.shared().whale_gape_deg = gape
	for species: int in species_list:
		var model := FishModel.build(FishCharacter.FishClass.TITAN, species, 0)
		add_child(model)
		var jaw := WhaleJaw.new()
		jaw.build(model, Color.WHITE)
		model.set_meta("hunter_jaw", jaw)
		var key: String = load(FishModel.TITAN_MODEL).SPECIES_KEYS[species]
		var length := model._size.z
		var head := Vector3(0.0, 0.0, -length * 0.38)
		var states := {
			"shut": [0.0, 0.0, 0.0], "half": [0.5, 0.0, 0.0], "wide": [1.0, 0.0, 0.0], "fling": [1.0, 0.28, 0.0], "full": [1.0, 0.0, 1.0],
		}
		for state: String in states:
			var s: Array = states[state]
			jaw.set_overshoot(float(s[1]))
			jaw.fullness = float(s[2])
			jaw.pose(float(s[0]))
			model.apply_bend()
			for view: Array in [["side", Vector3(1.0, 0.1, 0.0)], ["front", Vector3(0.45, 0.25, -1.0)], ["low", Vector3(0.35, -0.7, -0.8)]]:
				if state in ["shut", "half", "fling"] and view[0] == "low":
					continue
				_camera.position = head + (view[1] as Vector3).normalized() * length * 0.55
				_camera.look_at(head + Vector3(0.0, -length * 0.02, length * 0.05), Vector3.UP)
				for i in 3:
					await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s_%s.png" % [key, state, view[0]]))
		model.queue_free()
		await get_tree().process_frame
	print("whale_jaw_shots: done")
	get_tree().quit()
