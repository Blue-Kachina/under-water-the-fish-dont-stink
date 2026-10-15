extends Node
## Not a probe: screenshots of Nature's cues through the chase camera, for
## checking them by eye: each fish's tail half lit (a stride building) and fully
## lit and gold (at its peak), and a full bow wave, each also from the side.
## Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/stride_shots.tscn -- --out=DIR

var out_dir := "user://stride_shots"


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
	var chase: Camera3D = main.get_node("FollowCamera")
	var side := Camera3D.new()
	side.fov = 45.0
	add_child(side)
	for key: String in ["octane", "dominus", "plank", "breakout", "hybrid", "merc"]:
		fish.character = FishCharacter.from_key(key)
		fish.set_spawn(Transform3D.IDENTITY)
		await _frames(10)
		main.get_node("FollowCamera").snap()
		fish.freeze = true
		fish.set_process(false)  # hold the cues where they're put
		var visual: FishModel = fish._visual
		for shot: Array in [["building", 0.55, 0.78, 0.0, 0.0], ["peak", 1.0, 1.0, 1.0, 0.0], ["bow", 0.0, 0.0, 0.0, 1.0]]:
			visual.set_stride_cue(shot[1], shot[2], shot[3])
			fish.bow_amount = shot[4]
			fish.speed = 30.0 if shot[4] > 0.0 else 0.0
			fish._update_bow_view(1.0 / 60.0)
			chase.make_current()
			await _frames(4)
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [key, shot[0]]))
			side.position = fish.global_position + Vector3(-2.6, 0.9, 0.6)
			side.look_at(fish.global_position + Vector3(0.0, 0.0, 0.2))
			side.make_current()
			await _frames(4)
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s_side.png" % [key, shot[0]]))
		fish.freeze = false
		fish.set_process(true)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
