extends Node
## Not a probe: screenshots for checking that pop-ups and panes fit the screen:
## the mode picker's Unnatural run-length card, and Settings' detail pane on
## options with a lot in it (the fish list, a Sound Board entry). Needs a
## window (not --headless).
##   Godot_console.exe --path . res://tests/fit_shots.tscn -- --out=DIR [--size=1600x900]

var out_dir := "user://fit_shots"
var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var window_size := Vector2i(1600, 900)
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
	main.set_mode(main.UNNATURAL, false)
	await _frames(10)
	var home: HomeScreen = main._home
	home.open()
	await _frames(10)
	home.open_picker()
	await _frames(6)
	# Each mode's setup screen, over the picker (its options, then the Hunter form for What Stinks?).
	for mode: String in [main.UNNATURAL, "Fish Sticks", main.MARCO_POLO, main.WHAT_STINKS, main.NATURE]:
		home._picker._choose(mode)
		await _frames(8)
		await _shot("setup_" + mode.to_lower().replace(" ", "_").replace("?", ""))
		var setup: ModeSetup = main.get_node("ModeSetup")
		if mode == main.MARCO_POLO or mode == main.WHAT_STINKS:
			setup._focus = 1
			setup.refresh()
			await _frames(4)
			await _shot("setup_%s_options" % mode.to_lower().replace(" ", "_").replace("?", ""))
		setup.cancel()
		await _frames(3)
	# Every Hunter form's preview on What Stinks?'s setup screen.
	WhatStinksSettings.shared().start_as = WhatStinksSettings.StartAs.HUNTER
	home._picker._choose(main.WHAT_STINKS)
	await _frames(6)
	var forms: ModeSetup = main.get_node("ModeSetup")
	for i in forms.pool.size():
		forms.pool_index = i
		forms.refresh()
		await _frames(8)
		await _shot("setup_form_%s" % forms.pool[i].form)
	forms.cancel()
	await _frames(3)
	home._picker._cancel()
	home.close()

	var panel: Node = main._panel
	panel.set_open(true)
	await _frames(4)
	for key: String in ["game/character", "game/skin"]:
		if panel._rows.has(key):
			panel._focus_rows("game")
			panel._rows[key].grab_focus()
			await _frames(4)
			await _shot("settings_" + key.replace("/", "_"))
	# Unnatural > Test Tank > Test Boss: the option, then its dropdown open.
	UISettings.show_debug_tweaks = true
	panel._refresh_visibility()
	var boss := "unnatural/tank_boss"
	for tab in panel._tabs["unnatural"].size():
		if panel._tabs["unnatural"][tab].list.is_ancestor_of(panel._rows[boss]):
			panel._tab_at["unnatural"] = tab
	panel._focus_rows("unnatural")
	panel._rows[boss].grab_focus()
	await _frames(4)
	await _shot("settings_test_boss_row")
	panel._enter_detail()
	await _frames(4)
	await _shot("settings_test_boss_dropdown")
	panel.set_open(false)
	print("fit_shots: saved to %s" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _shot(shot_name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
