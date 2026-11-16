extends Node
## Not a probe: Free Swim with the endless terrain (TerrainStream), one shot from above the fish looking ahead and down,
## to logs/terrain_shots/<label>/stream.png. Needs a window.
##   Godot_console.exe --path . res://tests/stream_shot.tscn -- --label=NAME

var label := "stream"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
	get_window().size = Vector2i(1920, 1080)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred(main)


func _run(main: Node) -> void:
	main.get_node("DebugPanel")._panel.visible = false
	main.set_mode(main.FREE_SWIM, false)
	var stream: TerrainStream = null
	for i in 600:
		await get_tree().process_frame
		stream = main._terrain_stream
		if stream and stream.built_count() >= 12:
			break
	if stream == null:
		push_error("stream_shot: no stream")
		get_tree().quit(1)
		return
	var fish: Node3D = main.get_node("Fish")
	var camera := Camera3D.new()
	camera.far = 1000.0
	add_child(camera)
	var floor_y := stream.global_position.y
	camera.global_position = Vector3(fish.global_position.x, floor_y + 24.0, fish.global_position.z)
	camera.look_at(camera.global_position + Vector3(60.0, -22.0, 40.0), Vector3.UP)
	camera.current = true
	for i in 40:
		await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://logs/terrain_shots").path_join(label)
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("stream.png"))
	print("stream_shot: %d tiles, saved to %s" % [stream.built_count(), dir])
	get_tree().quit()
