extends Node3D
## Not a probe: contact sheet frames of the Ember Octopus' Tendril Lash (WhipAttack, C3) on a real OctopusModel: rest, press, flare,
## hold at low and full charge, the lash in flight, the hits, the reel-in. Targets are small ember spheres. Needs a window.
##   Godot_console.exe --path . res://tests/octopus_whip_shots.tscn -- --out=DIR [--view=side|top|front34]
## Named whip_<view>_<NN>_<label>.png.

const DT := 1.0 / 120.0
var out_dir := "user://octopus_whip_shots"
var view := "side"
var octo: OctopusModel
var camera: Camera3D
var attack: WhipAttack
var targets: Array[Dictionary] = []
var marks: Array[MeshInstance3D] = []
var origin := Vector3.ZERO


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--view="):
			view = arg.trim_prefix("--view=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1100, 700)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.03, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.28, 0.4)
	env.ambient_light_energy = 0.7
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_hdr_threshold = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.8, 0.7, 0.0)
	key.light_color = Color(0.7, 0.82, 1.0)
	key.light_energy = 0.9
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(0.5, -2.4, 0.0)
	rim.light_color = Color(1.0, 0.6, 0.35)
	rim.light_energy = 0.8
	add_child(rim)
	octo = OctopusModel.build(6.0)
	add_child(octo)
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 200.0
	add_child(camera)
	camera.make_current()
	origin = octo.global_transform * octo.mouth_local()
	for i in 6:
		var ang := float(i) * 1.0
		var pos := origin + Vector3(sin(ang) * 1.5, cos(ang) * 1.0, -(3.0 + 0.5 * float(i)))
		targets.append({"key": i, "pos": pos, "vel": Vector3.ZERO})
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.18
		s.height = 0.36
		m.mesh = s
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.8, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.6, 0.2)
		mat.emission_energy_multiplier = 2.0
		m.material_override = mat
		m.position = pos
		add_child(m)
		marks.append(m)
	attack = WhipAttack.new()
	attack.target_source = func() -> Array: return targets
	attack.push_sink = Callable()
	attack.attach_model(octo)
	_run.call_deferred()


func _cam() -> void:
	var c := origin + Vector3(0, 0, -2.2)
	match view:
		"top":
			camera.position = c + Vector3(0, 11.0, 0.01)
		"front34":
			camera.position = c + Vector3(-5.5, 3.0, -6.5)
		_:
			camera.position = c + Vector3(-11.0, 0.6, 0.0)
	camera.look_at(c, Vector3.UP)


var _n := 0


func _shot(label: String) -> void:
	_cam()
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("whip_%s_%02d_%s.png" % [view, _n, label]))
	_n += 1


func _tick(n: int, holding: bool, charge: float) -> void:
	for i in n:
		attack.charge_now = charge
		attack.step(DT, origin, Vector3(0, 0, -1), holding)
		attack.blend_pose(octo)
		await get_tree().process_frame


func _run() -> void:
	octo.idle_pose(1.0)
	await _shot("rest")
	attack.press(origin, Vector3(0, 0, -1))
	await _tick(12, true, 0.0)
	await _shot("press_flare")
	await _tick(30, true, 0.4)
	await _shot("hold_mid")
	await _tick(60, true, 1.0)
	await _shot("hold_full")
	attack.release(1.0)
	for k in 14:
		await _tick(4, false, 1.0)
		await _shot("lash_t%03d" % int((k + 1) * 4 * DT * 1000.0))
		if not attack.busy():
			break
	await _tick(60, false, 1.0)
	await _shot("settled")
	get_tree().quit()
