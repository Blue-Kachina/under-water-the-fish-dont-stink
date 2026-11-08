## Not a probe: contact sheets of the Drowned Shark's exaggerated chomp for looking at by eye (rest / press / hold-peak /
## release / settle) from the side and a three-quarter front view. Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/b2_shark_shots.tscn -- --out=DIR [--master=1.0]
extends Node

const KEY := "drowned_shark"
const SIZE := 480

var out_dir := "user://b2_shark_shots"
var master := 1.0
var main: Node
var fish: FishController
var camera := Camera3D.new()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--master="):
			master = float(arg.trim_prefix("--master="))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(SIZE, SIZE)
	WhatStinksSettings.shared().bite_mode = WhatStinksSettings.BiteMode.HOLD
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(sheet: Image, index: int) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	shot.resize(SIZE, SIZE)
	sheet.blend_rect(shot, Rect2i(0, 0, SIZE, SIZE), Vector2i(index * SIZE, 0))


func _run() -> void:
	await _frames(5)
	main.set_environment("Ocean")
	await _frames(5)
	var form := HunterForms.sheet(KEY)
	HunterSize.shared().size_mult = 1.0
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().apply(fish, form)
	HunterForms.dress(fish, KEY)
	await _frames(3)
	var bite := HunterBite.new()
	bite.name = "HunterBite"
	fish.add_child(bite)
	bite.setup(fish, form)
	var model := fish.get("_visual") as Node3D
	var rig := model.get_node("SharkRig")
	rig.ex.set_strength(master, 1.0)
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	fish.freeze = true
	fish.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 4.0, 0.0))
	add_child(camera)
	camera.far = 500.0
	camera.fov = 50.0
	camera.current = true
	var length: float = float(model.get("_size").z) * model.scale.z
	Engine.time_scale = 0.1  # a screenshot takes a few draws: keep the bite from moving on while one is taken
	var views := {
		"side": Vector3(1.0, 0.12, 0.0), "front34": Vector3(0.55, 0.22, -1.0), "above": Vector3(0.4, 0.9, -0.5),
	}
	# beats: [name, ticks after the start of the bite], the release at 0.8 s
	var beats := [["rest", -1], ["press", 14], ["hold", 96], ["r3", 100], ["r6", 103], ["r10", 107], ["r16", 113], ["settle", 190]]
	for view_name: String in views:
		var sheet := Image.create(SIZE * beats.size(), SIZE, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.05, 0.2, 0.3))
		var n := 0
		while bite.busy() and n < 600:
			await get_tree().physics_frame
			n += 1
		await _frames(150)
		bite.cooldown = 0.0
		var head: Vector3 = fish.global_position + (-fish.global_basis.z) * length * 0.3
		camera.position = head + (views[view_name] as Vector3).normalized() * length * 0.55
		camera.look_at(head, Vector3.UP)
		var tick := 0
		var index := 0
		var bite_started := false
		while index < beats.size():
			var at: int = beats[index][1]
			if at < 0:
				camera.position = fish.global_position + (-fish.global_basis.z) * length * 0.3 + (views[view_name] as Vector3).normalized() * length * 0.55
				camera.look_at(fish.global_position + (-fish.global_basis.z) * length * 0.3, Vector3.UP)
				await _shot(sheet, index)
				index += 1
				continue
			if not bite_started:
				bite.try_open()
				bite_started = true
			await get_tree().physics_frame
			tick += 1
			camera.position = fish.global_position + (-fish.global_basis.z) * length * 0.3 + (views[view_name] as Vector3).normalized() * length * 0.55
			camera.look_at(fish.global_position + (-fish.global_basis.z) * length * 0.3, Vector3.UP)
			if tick == 96:
				pass
			if tick == 97:
				bite.try_close()
			if tick == at:
				await _shot(sheet, index)
				index += 1
		var path := "%s/%s.png" % [out_dir, view_name]
		sheet.save_png(path)
		print("saved ", path)
	get_tree().quit()
