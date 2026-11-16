extends Node
## Not a probe: runs another probe with the procedural terrain on (planning_procedural_world.md, phase 6), so the
## regression suite can be run both ways.
##   Godot_console.exe --headless --path . res://tests/with_terrain.tscn -- --probe=res://tests/stage_probe.tscn


func _ready() -> void:
	UnnaturalSettings.shared().terrain_enabled = true
	var probe := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe="):
			probe = arg.trim_prefix("--probe=")
	if probe.is_empty():
		push_error("with_terrain: pass --probe=res://tests/<name>.tscn")
		get_tree().quit(2)
		return
	print("with_terrain: %s (terrain on)" % probe)
	add_child.call_deferred(load(probe).instantiate())
