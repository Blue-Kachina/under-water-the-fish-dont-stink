extends Node3D
## Not a probe: Marco Polo's reveal (planning_marco_polo.md §3) for every class,
## to check the anatomy against the models by eye. One sheet per class
## (<class>.png): a side view at the middle of each layer (exposure 0.04 none,
## 0.16 skeleton, 0.35 cardiovascular, 0.55 muscular, 0.75 skin, 0.92 aura), a
## three-quarter row under it, and a swimming strip (<class>_swim.png: the tail
## wagging, at the skeleton, cardiovascular and muscular layers). Needs a window
## (not --headless). `--fish=key` shoots one class; `--species=N` a species.
##   Godot_console.exe --path . res://tests/reveal_shots.tscn -- --out=DIR

const EXPOSURES := [0.04, 0.16, 0.35, 0.55, 0.75, 0.92]
const CELL := Vector2i(360, 260)

var out_dir := "user://reveal_shots"
var only := ""
var species := 0
var settings := MarcoPoloSettings.new()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--fish="):
			only = arg.trim_prefix("--fish=")
		elif arg.begins_with("--species="):
			species = int(arg.trim_prefix("--species="))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = CELL
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.1, 0.2, 0.22)  # murky water
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.7, 0.75)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.6, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	_run.call_deferred()


func _run() -> void:
	var camera := Camera3D.new()
	camera.fov = 36.0
	add_child(camera)
	camera.make_current()
	for fish_class: FishCharacter.FishClass in FishCharacter.CLASSES:
		var key: String = FishCharacter.CLASSES[fish_class].key
		if only != "" and key != only:
			continue
		var model := FishModel.build(fish_class, species)
		add_child(model)
		var reveal := HiderLooks.Reveal.new(model)
		var reach := model._size.length() * 1.05
		var sheet := Image.create_empty(CELL.x * EXPOSURES.size(), CELL.y * 2, false, Image.FORMAT_RGBA8)
		for row in 2:
			var view := Vector3(-1.0, 0.05, 0.0) if row == 0 else Vector3(-0.8, 0.5, -0.9)
			camera.position = view.normalized() * reach
			camera.look_at(Vector3.ZERO, Vector3.UP)
			for n in EXPOSURES.size():
				reveal.update(1.0 / 60.0, EXPOSURES[n], settings, Color(1.0, 0.55, 0.15))
				model.react(1.0 / 60.0, Vector3.ZERO)
				await _frames(1)
				reveal.update(1.0 / 60.0, EXPOSURES[n], settings, Color(1.0, 0.55, 0.15))
				await _frames(3)
				sheet.blit_rect(_shot(), Rect2i(Vector2i.ZERO, CELL), Vector2i(n * CELL.x, row * CELL.y))
		sheet.save_png(out_dir.path_join("%s.png" % key))
		# Swimming: the tail wagging, from above-side, at three layers.
		var strip := Image.create_empty(CELL.x * 4, CELL.y * 3, false, Image.FORMAT_RGBA8)
		camera.position = Vector3(-0.6, 0.75, 0.2).normalized() * reach
		camera.look_at(Vector3.ZERO, Vector3.UP)
		for row in 3:
			var exposure: float = [0.16, 0.35, 0.55][row]
			for n in 4:
				model.tail.rotation = Vector3(0.0, sin(n * PI / 2.0 + 0.4) * 0.7, 0.0)
				for k in 4:
					model.react(1.0 / 60.0, Vector3(0.0, 0.0, -12.0))
					reveal.update(1.0 / 60.0, exposure, settings, Color(1.0, 0.55, 0.15))
				await _frames(3)
				strip.blit_rect(_shot(), Rect2i(Vector2i.ZERO, CELL), Vector2i(n * CELL.x, row * CELL.y))
		strip.save_png(out_dir.path_join("%s_swim.png" % key))
		print("reveal_shots: %s" % key)
		reveal.restore()
		model.queue_free()
		await _frames(2)
	get_tree().quit()


func _shot() -> Image:
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw
