extends Node
## Not a probe: screenshots of the settings for checking them by eye: a big
## section's tabs (Fish, Unnatural, Powerups), and the Controls section's
## keyboard & mouse and controller bindings, one of them waiting on a key.
## Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/settings_shots.tscn -- --out=DIR

var out_dir := "user://settings_shots"
var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _frames(10)
	var panel: Node = main._panel
	panel.set_open(true)
	await _frames(3)
	for shot: Array in [["fish", 1, "fish/swim_strokes"], ["unnatural", 3, ""], ["powerups", 2, ""], ["controls", 0, "controls/kb:boost"],
			["controls", 1, "controls/pad:jump"]]:
		panel._tab_at[shot[0]] = shot[1]
		panel._focus_rows(shot[0])
		if shot[2] and panel._rows.has(shot[2]):
			panel._rows[shot[2]].grab_focus()
		await _frames(4)
		await _shot("settings_%s_%d" % [shot[0], shot[1]])
	panel._start_capture("controls/pad:jump")
	await _frames(4)
	await _shot("settings_capture")
	panel._end_capture(null)
	panel.set_open(false)
	print("settings_shots: saved to %s" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _shot(shot_name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
