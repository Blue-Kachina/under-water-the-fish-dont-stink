extends Node
## Not a probe: screenshots of the home screen's Class details panel, one per
## class, for checking by eye; prints any class whose panel runs off the
## screen (headless text doesn't measure true). Needs a window.
##   Godot_console.exe --path . res://tests/details_shots.tscn -- --out=DIR [--size=1280x720]

var out_dir := "user://details_shots"
var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # through the home screen's pause
	var window_size := Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			window_size = Vector2i(parts[0].to_int(), parts[1].to_int())
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = window_size
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _frames(10)
	var home: HomeScreen = main._home
	home.open()
	await _seconds(0.5)
	home._toggle_details()
	var fish: FishController = main.get_node("Fish")
	for fish_class: FishCharacter.FishClass in FishCharacter.CLASSES.keys():
		home.character_changed.emit(fish_class)
		home._show_fish(fish_class)
		await _seconds(0.6)
		await _shot("details_%s" % FishCharacter.display_name(fish.character).to_lower())
		var panel := home._details.get_child(1) as Control
		var over := panel.get_global_rect().end.y - get_viewport().get_visible_rect().size.y
		print("%s  %s%s" % ["TOO TALL" if over > 0.5 else "fits", FishCharacter.display_name(fish.character), " (%d px over)" % over if over > 0.5 else ""])
	get_tree().quit()


func _shot(shot_name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(time: float) -> void:
	await get_tree().create_timer(time, true).timeout
