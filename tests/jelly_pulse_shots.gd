extends Node3D
## Not a probe: side-on screenshots of a jelly hanging upright through a bell
## pulse (BellPulse), for checking it by eye against
## private_content/jellyfish_swim_compact.gif. It rests, makes a power stroke,
## a recovery stroke chained at the power stroke's peak and left to fade, then
## glides; a shot every `--every=` frames (60 fps), numbered in order. Needs a
## window (not --headless).
##   Godot_console.exe --path . res://tests/jelly_pulse_shots.tscn -- --species=0 --out=DIR

const DT := 1.0 / 60.0

var out_dir := "user://jelly_pulse_shots"
var species := 0
var every := 3


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--species="):
			species = int(arg.trim_prefix("--species="))
		elif arg.begins_with("--every="):
			every = maxi(int(arg.trim_prefix("--every=")), 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(360, 560)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.1, 0.25, 0.45)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.75, 0.95)
	environment.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.2, 0.4, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var model := FishModel.build(FishCharacter.FishClass.DRIFTER, species)
	add_child(model)
	_run.call_deferred(model)


func _run(model: FishModel) -> void:
	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.make_current()
	var reach := model._size.length() * 1.6
	# Upright, the bell's wide side (its x) faces along world Z.
	var centre := Vector3(0.0, -model._size.z * 0.15, 0.0)
	camera.position = centre + Vector3(0.0, -0.1, 1.0).normalized() * reach
	camera.look_at(centre, Vector3.UP)
	model.bell_lean = 0.0  # upright, the apex up
	model.bell_gait = Gait.new()
	var peak := 0.28
	var fade := 0.48
	model.stride_peak = peak
	model.stride_fade = fade
	# [stride time (-1: none), seconds]: rest, power, recovery (chained at the
	# peak, left to fade), a glide, then a power stroke left to relax alone.
	var plan := [[-1.0, 0.5], [0.0, peak], [0.0, peak + fade], [-1.0, 0.8], [0.0, peak + fade], [-1.0, 1.0]]
	var frame := 0
	var shot := 0
	for step: Array in plan:
		var start: float = step[0]
		var time := 0.0
		while time < float(step[1]) - 1e-4:
			model.stride_phase = start + time if start >= 0.0 else -1.0
			model.react(DT, Vector3.ZERO)
			time += DT
			if frame % every == 0:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out_dir.path_join("pulse_%03d.png" % shot))
				shot += 1
			frame += 1
	print("jelly_pulse_shots: %d shots -> %s" % [shot, out_dir])
	get_tree().quit()
