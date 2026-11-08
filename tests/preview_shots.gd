extends Node
## Not a probe: contact sheets of the card's Hunter previews swimming (6 frames, 0.7 s apart, 3 x 2) for looking at the
## gait by eye. Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/preview_shots.tscn -- --out=DIR [--keys=a,b] [--gap=0.7]

const Showcase := preload("res://scripts/ui/home_screen.gd").FishShowcase
const SIZE := 420

var out_dir := "user://preview_shots"
var keys: Array[String] = []
var gap := 0.7


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--keys="):
			for k in arg.trim_prefix("--keys=").split(","):
				keys.append(k)
		elif arg.begins_with("--gap="):
			gap = float(arg.trim_prefix("--gap="))
	if keys.is_empty():
		keys = HunterForms.ready_keys()
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 800)
	_run.call_deferred()


func _run() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.2, 0.3)
	backdrop.size = Vector2(SIZE, SIZE)
	add_child(backdrop)
	var showcase: Showcase = Showcase.new()
	showcase.size = Vector2(SIZE, SIZE)
	add_child(showcase)
	await get_tree().process_frame
	for key in keys:
		showcase.show_form(key)
		await get_tree().create_timer(0.5).timeout
		var sheet := Image.create(SIZE * 3, SIZE * 2, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.05, 0.2, 0.3))
		for i in 6:
			await get_tree().create_timer(gap).timeout
			var shot := showcase._view.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			shot.resize(SIZE, SIZE)
			sheet.blend_rect(shot, Rect2i(0, 0, SIZE, SIZE), Vector2i((i % 3) * SIZE, (i / 3) * SIZE))
		var path := "%s/%s.png" % [out_dir, key]
		sheet.save_png(path)
		print("saved ", path)
	get_tree().quit()
