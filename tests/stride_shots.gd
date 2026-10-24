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
	for key: String in ["skirmisher", "hunter", "glider", "lancer", "charmer", "bulwark"]:
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
		# Full flow: a big tail at its peak, stretches of bubble stream in each
		# timing's colour (perfect to fresh), the arcade vignette and zoom.
		fish.swishy.flow = fish.stride_flow_max
		fish.speed = 34.0
		fish._tail.scale = Vector3.ONE * (1.0 + fish.stride_tail_growth) * 1.2
		fish._tail.rotation.y = -fish.stride_tail_swing
		visual.set_stride_cue(1.0, 1.0, 1.0)
		fish.bow_amount = 1.0
		fish._update_bow_view(1.0 / 60.0)
		var back := fish.global_basis.z
		chase.make_current()  # the arcade effects only show through the chase camera
		for i in 4:
			var offset := Vector3.RIGHT * (0.5 if i % 2 == 0 else -0.5)
			var stream: StrideStream = fish.get_node("StrideStream")
			var color := StrideStream.color_for([1.0, 0.6, 0.3, -1.0][i])
			for k in 12:  # a short stretch of stream in each timing's colour
				stream.pour(1.0 / 60.0, fish.global_position + back * (0.8 + i * 0.6 + k * 0.05) + offset * 0.3, back, Vector3.ZERO, 0.03, 60.0, color)
		for i in 40:
			await RenderingServer.frame_post_draw
		chase.make_current()
		await _frames(2)
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_flow.png" % key))
		fish.swishy.flow = 0.0
		for i in 40:
			await RenderingServer.frame_post_draw
		fish._tail.scale = Vector3.ONE
		fish._tail.rotation = Vector3.ZERO
		fish.freeze = false
		fish.set_process(true)
	await _live(main, fish, chase, side)
	get_tree().quit()


## The real thing: striding at the peak for a while (the stream pouring, the
## tail growing), shot from the chase camera and from the side.
func _live(main: Node, fish: FishController, chase: Camera3D, side: Camera3D) -> void:
	fish.character = FishCharacter.FishClass.SKIRMISHER
	fish.set_spawn(Transform3D.IDENTITY)
	await _frames(10)
	var input := FishInput.new()
	fish.controls = input
	chase.make_current()
	chase.snap()
	var t := 0.0
	var shots := {1.2: "live_chase_a", 2.0: "live_side", 2.6: "live_chase_b"}
	while t < 2.7:
		input.forward = 1.0
		input.stick = Vector2.RIGHT * (1.0 if int(t / fish.stride_peak_time) % 2 == 0 else -1.0)
		input.direction_lock = true  # straight, so the trail lines up behind
		await RenderingServer.frame_post_draw
		t += get_process_delta_time()
		for at: float in shots:
			if t >= at and shots[at] != "":
				if shots[at] == "live_side":
					side.position = fish.global_position + Vector3(-4.0, 1.2, 1.5)
					side.look_at(fish.global_position + Vector3(0.0, 0.0, 1.5))
					side.make_current()
				else:
					chase.make_current()
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % shots[at]))
				shots[at] = ""
	chase.make_current()
	fish.controls = null


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
