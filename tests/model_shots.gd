extends Node3D
## Not a probe: screenshots of one fish model on its own (front three-quarter,
## side, top, back and below) for checking its look by eye, then swimming,
## wagging its tail (top views, to see the tail stay on the body) and mid
## stride. Needs a window (not --headless). `--species=N` picks a species
## (FishCharacter.SPECIES); its shots are named <fish>_<species key>_<view>.png.
## `--look=sardine` shoots a zombie's own model (ZombieLooks) instead.
##   Godot_console.exe --path . res://tests/model_shots.tscn -- --fish=glider --species=1 --out=DIR
## `--skin=N` picks a skin (the Titans' variants). `--qa` shoots the art QA set
## instead (planning_marco_whales.md §6a step 3): 6 angles under 3 lights
## (studio, underwater, rim), gameplay distances (chase, across the arena, far:
## the LODs), beside the approved assets (the koi, the calf), and the flukes
## beating; named <fish>_<species>[_<skin>]_qa_<light>_<view>.png.

var out_dir := "user://model_shots"
var fish_key := "glider"
var species := 0
var skin := 0
var look := ""
var qa := false
var swim := false
var _name := ""
var _environment: Environment
var _sun: DirectionalLight3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--fish="):
			fish_key = arg.trim_prefix("--fish=")
		elif arg.begins_with("--species="):
			species = int(arg.trim_prefix("--species="))
		elif arg.begins_with("--look="):
			look = arg.trim_prefix("--look=")
		elif arg.begins_with("--skin="):
			skin = int(arg.trim_prefix("--skin="))
		elif arg == "--qa":
			qa = true
		elif arg == "--swim":
			swim = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1200, 800) if qa or swim else Vector2i(900, 700)
	var environment := Environment.new()
	_environment = environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.82, 0.88, 0.94)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.6, 0.0)
	sun.light_energy = 1.2
	add_child(sun)
	_sun = sun
	var fish_class := FishCharacter.from_key(fish_key)
	var model: FishModel
	if look != "":
		model = ZombieLooks.build(look, fish_class)
		_name = look
	else:
		model = FishModel.build(fish_class, species, skin)
		_name = "%s_%s" % [fish_key, FishCharacter.species_key(fish_class, model.species)]
		if skin > 0:
			_name += "_skin%d" % skin
	add_child(model)
	if qa:
		_qa.call_deferred(model)
	elif swim:
		_swim_loop.call_deferred(model)
	else:
		_run.call_deferred(model)


## The art QA set (see the description).
func _qa(model: FishModel) -> void:
	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.far = 600.0
	add_child(camera)
	camera.make_current()
	var length := model._size.z
	var reach := length * 1.05
	var views := {
		"front": Vector3(-0.8, 0.45, -1.0),
		"head": Vector3(0.0, 0.08, -1.0),
		"side": Vector3(-1.0, 0.05, 0.0),
		"top": Vector3(0.0, 1.0, 0.01),
		"back": Vector3(0.6, 0.6, 1.0),
		"below": Vector3(-0.5, -0.6, -0.7),
	}
	for light: String in ["studio", "water", "rim"]:
		_light(light)
		for view: String in views:
			camera.position = Vector3(views[view]).normalized() * reach
			camera.look_at(Vector3.ZERO, Vector3.FORWARD if view == "top" else Vector3.UP)
			await _save("%s_qa_%s_%s.png" % [_name, light, view])
	# Close-ups (studio): the head, the flipper, the flukes from below.
	_light("studio")
	for close: Array in [["close_head", Vector3(-0.55, 0.2, -0.42), 0.32], ["close_flipper", Vector3(-0.55, -0.5, -0.15), 0.38],
			["close_flukes", Vector3(0.0, -1.0, 0.25), 0.4], ["close_eye", Vector3(1.0, 0.15, -0.35), 0.1]]:
		var target := _close_target(model, close[0])
		camera.position = target + Vector3(close[1]).normalized() * length * float(close[2])
		camera.look_at(target, Vector3.UP if close[0] != "close_flukes" else Vector3.FORWARD)
		await _save("%s_qa_%s.png" % [_name, close[0]])
	# Gameplay distances in the water light: the chase cam behind and above,
	# then seen across the arena and far off (the LODs swap).
	_light("water")
	for far: Array in [["chase", Vector3(0.0, 0.32, 1.0), 1.25], ["mid", Vector3(-1.0, 0.25, 0.4), 4.0],
			["far", Vector3(-1.0, 0.2, 0.2), 8.0]]:
		camera.position = Vector3(far[1]).normalized() * length * float(far[2])
		camera.look_at(Vector3(0.0, 0.0, -length * 0.15) if far[0] == "chase" else Vector3.ZERO, Vector3.UP)
		await _save("%s_qa_gameplay_%s.png" % [_name, far[0]])
	# Beside the approved assets: the koi and the calf, both scaled to its length.
	_light("studio")
	var others: Array[FishModel] = []
	for other: Array in [[FishCharacter.FishClass.CHARMER, length * 0.55], [FishCharacter.FishClass.BREACHER, -length * 0.5]]:
		var fish := FishModel.build(other[0], 0)
		var grow := length / fish._size.z
		fish.scale = Vector3.ONE * grow
		fish.position = Vector3(0.0, float(other[1]), 0.0)
		add_child(fish)
		others.append(fish)
	camera.position = Vector3(-1.0, 0.1, -0.2).normalized() * length * 1.9
	camera.look_at(Vector3.ZERO, Vector3.UP)
	await _save("%s_qa_compare.png" % _name)
	for fish in others:
		fish.queue_free()
	# The flukes beating: down and up, from the side (held a moment, so a
	# Titan's wave has reached the flukes).
	for beat: Array in [["fluke_down", 0.6], ["fluke_up", -0.6]]:
		for i in 45:
			model.tail.rotation = Vector3(float(beat[1]), 0.0, 0.0)
			model.react(1.0 / 60.0, Vector3(0.0, 0.0, -10.0))
		camera.position = Vector3(views["side"]).normalized() * reach
		camera.look_at(Vector3.ZERO, Vector3.UP)
		await _save("%s_qa_%s.png" % [_name, beat[0]])
	model.tail.rotation = Vector3.ZERO
	get_tree().quit()


## The swim loop (`--swim`): the flukes beat as the swim drives them (a steady
## beat of `beat` s), straight for two beats and then turning left, captured
## as frames from the side (and behind, turning) and put together on one
## contact sheet each, <name>_swim_sheet_<view>.png (frames left to right, top
## to bottom). Prints each FishModel.power_stroke as it comes.
func _swim_loop(model: FishModel) -> void:
	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.make_current()
	_light("studio")
	var holder := Node3D.new()
	add_child(holder)
	model.reparent(holder)
	var strokes: Array[String] = []
	var clock := [0.0]
	model.power_stroke.connect(func(strength: float, at: Transform3D) -> void:
		strokes.append("t=%.2f strength=%.2f at=%s" % [clock[0], strength, at.origin]))
	var length := model._size.z
	var beat := 1.4
	var dt := 1.0 / 60.0
	var reach := [0.0, 0.0, 0.0, 0.0, 0.0]  # flukes min, max; head; surge; bank
	for view: Array in [["side", Vector3(-1.0, 0.05, 0.0), false], ["turn", Vector3(0.6, 0.55, 1.0), true]]:
		var frames: Array[Image] = []
		var total := int(beat * 2.0 / dt)
		var every := int(total / 16.0)
		for f in total:
			clock[0] += dt
			model.tail.rotation = Vector3(0.5 * sin(TAU * clock[0] / beat), 0.0, 0.0)
			if view[2]:
				holder.rotate_y(0.5 * dt)  # a steady left turn
			model.react(dt, holder.global_basis * Vector3(0.0, 0.0, -8.0))
			reach[0] = minf(reach[0], model.tail.rotation.x)
			reach[1] = maxf(reach[1], model.tail.rotation.x)
			reach[2] = maxf(reach[2], absf(model._bend_head.x))
			reach[3] = maxf(reach[3], absf(model._surge))
			reach[4] = maxf(reach[4], absf(model.rotation.z))
			if f % every == 0 and frames.size() < 16:
				camera.position = holder.global_basis * Vector3(view[1]).normalized() * length * 1.1
				camera.look_at(Vector3.ZERO, Vector3.UP)
				for i in 2:
					await RenderingServer.frame_post_draw
				frames.append(get_viewport().get_texture().get_image())
		var sheet := Image.create(1200, 800, false, frames[0].get_format())
		for i in frames.size():
			var frame := frames[i]
			frame.resize(300, 200)
			sheet.blit_rect(frame, Rect2i(0, 0, 300, 200), Vector2i((i % 4) * 300, (i / 4) * 200))
		sheet.save_png(out_dir.path_join("%s_swim_sheet_%s.png" % [_name, view[0]]))
	print("flukes %.2f..%.2f rad, head %.3f rad, surge %.3f m, bank %.3f rad" % reach)
	print("power strokes: %d" % strokes.size())
	for line in strokes:
		print("  ", line)
	get_tree().quit()


## One of the QA set's lights: "studio" (bright, pale sky), "water" (the
## arenas' blue-green murk, sun from above), "rim" (low, warm, from behind).
func _light(which: String) -> void:
	_environment.fog_enabled = false
	match which:
		"studio":
			_environment.background_color = Color(0.82, 0.88, 0.94)
			_environment.ambient_light_color = Color(0.75, 0.8, 0.9)
			_environment.ambient_light_energy = 0.6
			_sun.rotation = Vector3(-1.0, 0.6, 0.0)
			_sun.light_color = Color.WHITE
			_sun.light_energy = 1.2
		"water":
			_environment.background_color = Color(0.06, 0.2, 0.26)
			_environment.ambient_light_color = Color(0.35, 0.55, 0.62)
			_environment.ambient_light_energy = 0.55
			_environment.fog_enabled = true
			_environment.fog_light_color = Color(0.06, 0.2, 0.26)
			_environment.fog_density = 0.008
			_sun.rotation = Vector3(-1.45, 0.3, 0.0)
			_sun.light_color = Color(0.8, 0.95, 1.0)
			_sun.light_energy = 1.0
		"rim":
			_environment.background_color = Color(0.1, 0.12, 0.16)
			_environment.ambient_light_color = Color(0.4, 0.42, 0.5)
			_environment.ambient_light_energy = 0.25
			_sun.rotation = Vector3(-0.25, PI, 0.0)
			_sun.light_color = Color(1.0, 0.85, 0.7)
			_sun.light_energy = 2.2


## Where a close-up looks: the head, the right flipper's middle, the flukes, the eye.
func _close_target(model: FishModel, which: String) -> Vector3:
	var length := model._size.z
	match which:
		"close_flipper":
			return model.to_local(model.fin_left.global_position) + Vector3(-length * 0.07, -length * 0.04, length * 0.02)
		"close_flukes":
			return model.tail.position + Vector3(0.0, 0.0, length * 0.05)
		"close_eye":
			for eye: Node in model.find_children("*Eye*", "MeshInstance3D", true, false):
				var place := model.to_local((eye as Node3D).global_position)
				if place.x > 0.0:
					return place
	return Vector3(0.0, 0.0, -length * 0.38)


func _save(file: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))


func _run(model: FishModel) -> void:
	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.make_current()
	var reach := model._size.length() * 1.15
	var views := {
		"front": Vector3(-0.8, 0.45, -1.0),
		"side": Vector3(-1.0, 0.05, 0.0),
		"top": Vector3(0.0, 1.0, 0.01),
		"back": Vector3(0.6, 0.6, 1.0),
		"below": Vector3(-0.5, -0.6, -0.7),
	}
	for view: String in views:
		camera.position = Vector3(views[view]).normalized() * reach
		camera.look_at(Vector3.ZERO, Vector3.FORWARD if view == "top" else Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [_name, view]))
	# Mid-swim: fins rolled and swept as the swim animation leaves them, a moment
	# into swimming at full speed.
	model.fin_left.rotation = Vector3(0.0, 0.5, -0.5)
	model.fin_right.rotation = Vector3(0.0, -0.5, 0.5)
	model.tail.rotation.y = 0.3
	for i in 20:
		model.react(1.0 / 60.0, Vector3(0.0, 0.0, -23.0))
	for view: String in ["front", "back"]:
		camera.position = Vector3(views[view]).normalized() * reach
		camera.look_at(Vector3.ZERO, Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_swim_%s.png" % [_name, view]))
	# Wagging: the tail swung hard each way and up, seen from above and the
	# side, to check it stays on the body (FishModel._bend_body).
	model.fin_left.rotation = Vector3.ZERO
	model.fin_right.rotation = Vector3.ZERO
	for wag: Array in [["wag_left", Vector3(0.0, -0.9, 0.0), "top"], ["wag_right", Vector3(0.0, 0.9, 0.0), "top"],
			["wag_up", Vector3(-0.6, 0.0, 0.0), "side"], ["wag_three", Vector3(0.0, 0.7, 0.0), "back"]]:
		model.tail.rotation = wag[1]
		model.react(1.0 / 60.0, Vector3(0.0, 0.0, -10.0))
		camera.position = Vector3(views[wag[2]]).normalized() * reach
		camera.look_at(Vector3.ZERO, Vector3.FORWARD if wag[2] == "top" else Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [_name, wag[0]]))
	if model.fluke:
		# A whale's flukes beat up and down (Gait.Visual.FLUKE): down hard, seen
		# from the side and from behind.
		for wag: Array in [["fluke_down", "side"], ["fluke_down_back", "back"]]:
			model.tail.rotation = Vector3(0.7, 0.0, 0.0)
			model.react(1.0 / 60.0, Vector3(0.0, 0.0, -10.0))
			camera.position = Vector3(views[wag[1]]).normalized() * reach
			camera.look_at(Vector3.ZERO, Vector3.UP)
			for i in 3:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [_name, wag[0]]))
	model.tail.rotation = Vector3.ZERO
	# Mid-stride: an Extra Swishy stride pushing left (the tail swung left),
	# nearly at its peak, turning left; then fading, a moment later.
	model.fin_left.rotation = Vector3.ZERO
	model.fin_right.rotation = Vector3.ZERO
	model.tail.rotation.y = -0.6
	model.stride_swing = Vector2(-1.0, 0.0)
	for shot: Array in [["stride", 18, 0.0], ["recover", 12, -1.0]]:
		for i in shot[1]:
			model.stride_power = clampf(model.stride_power + (1.0 / 18.0 if shot[2] >= 0.0 else -1.0 / 12.0), 0.0, 1.0)
			model.rotate_y(1.5 / 60.0)
			model.react(1.0 / 60.0, model._body_frame() * Vector3(0.0, 0.0, -18.0))
		camera.position = model.global_basis * Vector3(views["back"]).normalized() * reach
		camera.look_at(Vector3.ZERO, Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s_back.png" % [_name, shot[0]]))
	get_tree().quit()
