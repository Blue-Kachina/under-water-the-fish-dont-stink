extends Node3D
## Not a probe: screenshots of the Ember Octopus alone (OctopusModel, C1) in a dark underwater set with glow, for checking it by eye
## against private_content/giant_glowing_octopus.png. Turntable angles, close-ups (head and eyes, an arm with suckers, the mantle,
## the siphon, the web), poses (idle, mantle contracted, charged), a lit-vs-studio pair. Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/octopus_model_shots.tscn -- --out=DIR [--set=turn,close,pose,studio]
## Named octopus_<set>_<view>.png.

var out_dir := "user://octopus_model_shots"
var sets := ["turn", "close", "pose", "studio"]
var octo: OctopusModel
var camera: Camera3D
var _env: Environment
var _key: DirectionalLight3D
var _rim: DirectionalLight3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--set="):
			sets = arg.trim_prefix("--set=").split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1100, 800)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.015, 0.03, 0.045)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.18, 0.28, 0.4)
	_env.ambient_light_energy = 0.7
	_env.glow_enabled = true
	_env.glow_intensity = 0.55
	_env.glow_bloom = 0.1
	_env.glow_hdr_threshold = 0.9
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = _env
	add_child(world)
	_key = DirectionalLight3D.new()
	_key.rotation = Vector3(-0.8, 0.7, 0.0)
	_key.light_color = Color(0.7, 0.82, 1.0)
	_key.light_energy = 0.9
	add_child(_key)
	_rim = DirectionalLight3D.new()
	_rim.rotation = Vector3(0.5, -2.4, 0.0)
	_rim.light_color = Color(1.0, 0.6, 0.35)
	_rim.light_energy = 0.8
	add_child(_rim)
	octo = OctopusModel.build(1.0)
	add_child(octo)
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 100.0
	add_child(camera)
	camera.make_current()
	_run.call_deferred()


func _save(file: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))


func _frame(dir: Vector3, dist: float, target: Vector3 = Vector3(0, 0, 0.08)) -> void:
	camera.position = target + dir.normalized() * dist
	camera.look_at(target, Vector3.UP)


func _run() -> void:
	if "turn" in sets:
		octo.reset_pose()
		var views := {
			"front34": Vector3(-0.8, 0.45, -1.0), "front": Vector3(0.0, 0.1, -1.0), "side": Vector3(-1.0, 0.05, 0.0),
			"top": Vector3(0.0, 1.0, 0.01), "back34": Vector3(0.7, 0.4, 1.0), "below": Vector3(-0.5, -0.7, -0.6),
			"back": Vector3(0.0, 0.25, 1.0),
		}
		for v: String in views:
			_frame(views[v], 1.9)
			await _save("octopus_turn_%s.png" % v)
	if "close" in sets:
		octo.reset_pose()
		var k := octo.unit
		var closes := {
			"head": [Vector3(-0.8, 0.35, -0.6), 0.55, Vector3(0, 0.0, -0.02) * k],
			"eye": [Vector3(-1.0, 0.35, -0.3), 0.2, Vector3(-0.083, 0.044, 0.004) * k],
			"arm": [Vector3(-0.2, 1.0, 0.6), 0.55, octo.arm_rest_joints(1)[5]],
			"arm_under": [Vector3(0.0, -1.0, 0.4), 0.5, octo.arm_rest_joints(6)[5]],
			"mantle": [Vector3(-0.9, 0.5, -0.7), 0.8, Vector3(0, 0.03, -0.3) * k],
			"siphon": [Vector3(-0.6, -0.8, 0.5), 0.32, Vector3(0, -0.09, 0.02) * k],
			"web": [Vector3(0.0, 0.5, 1.0), 0.5, Vector3(0, 0.0, 0.2) * k],
			"tips": [Vector3(-0.4, 0.7, 0.7), 0.5, octo.arm_rest_joints(2)[12]],
			"roots_top": [Vector3(-0.5, 1.0, 0.5), 0.45, Vector3(0, 0.0, 0.08) * k],
			"roots_side": [Vector3(-1.0, 0.1, 0.25), 0.45, Vector3(0, 0.0, 0.08) * k],
			"roots_below": [Vector3(-0.4, -1.0, 0.5), 0.45, Vector3(0, 0.0, 0.08) * k],
			"roots_back": [Vector3(0.15, 0.25, 1.0), 0.5, Vector3(0, 0.0, 0.08) * k],
		}
		for c: String in closes:
			var cfg: Array = closes[c]
			_frame(cfg[0], float(cfg[1]), cfg[2])
			await _save("octopus_close_%s.png" % c)
		# the roots with the arms bent hard (they must stay on the body)
		for a in 8:
			var bends := PackedVector3Array()
			bends.resize(14)
			for j in 14:
				bends[j] = Vector3(0.35 if j < 2 else 0.08, (0.3 if a % 2 == 0 else -0.3) if j < 2 else 0.0, 0.0)
			octo.set_arm_pose(a, bends)
		for c: String in ["roots_top", "roots_side", "roots_below"]:
			var cfg: Array = closes[c]
			_frame(cfg[0], float(cfg[1]), cfg[2])
			await _save("octopus_close_%s_bent.png" % c)
		octo.reset_pose()
	if "pose" in sets:
		_frame(Vector3(-0.8, 0.35, -1.0), 1.9)
		octo.reset_pose()
		octo.idle_pose(2.0)
		await _save("octopus_pose_idle.png")
		octo.idle_pose(2.0)
		octo.set_mantle_pulse(1.0)
		octo.set_stroke(1.0)
		octo.set_vein_travel(0.4)
		await _save("octopus_pose_contract.png")
		octo.reset_pose()
		octo.idle_pose(3.4)
		octo.set_charge(1.0)
		octo.set_eye_glow(1.2)
		octo.set_sucker_glow(1.0)
		await _save("octopus_pose_charged.png")
		octo.reset_pose()
		for a in 8:
			var curl := PackedVector3Array()
			curl.resize(14)
			for j in 14:
				curl[j] = Vector3(0.16, 0.0, 0.0)
			octo.set_arm_pose(a, curl)
		octo.set_mantle_bend(0.5, 0.0)
		await _save("octopus_pose_curl.png")
		octo.reset_pose()
		# a crown: every arm curled back and out, the mantle drawn in
		for a in 8:
			var bends := PackedVector3Array()
			bends.resize(14)
			for j in 14:
				bends[j] = Vector3(-0.07, 0.0, 0.0) if j < 7 else Vector3(0.1, 0.0, 0.0)
			octo.set_arm_pose(a, bends)
		await _save("octopus_pose_crown.png")
		octo.reset_pose()
		octo.set_flash(0.8)
		octo.set_chroma_shift(0.8)
		await _save("octopus_pose_flash_violet.png")
		octo.reset_pose()
		octo.set_param("hurt", 0.8)
		await _save("octopus_pose_hurt.png")
		octo.reset_pose()
	if "studio" in sets:
		_env.background_color = Color(0.5, 0.55, 0.6)
		_env.ambient_light_energy = 1.0
		_env.glow_enabled = false
		_key.light_energy = 1.4
		_key.light_color = Color.WHITE
		_rim.light_energy = 0.3
		octo.reset_pose()
		_frame(Vector3(-0.8, 0.45, -1.0), 2.3)
		await _save("octopus_studio_front34.png")
		_frame(Vector3(0.7, 0.3, 1.0), 2.3)
		await _save("octopus_studio_back34.png")
	get_tree().quit()
