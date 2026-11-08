extends Node3D
## Not a probe: contact sheets of the Ember Octopus gait (OctopusRig, C2) on a bare rig stepped by hand, for checking blends by eye:
## each sheet is a grid of tiles taken every N frames. Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/octopus_gait_shots.tscn -- --out=DIR [--set=jet,dash,cruise,turn,crawl,roll,strip]
## `strip` is one jet cycle (12 tiles across one octopus_jet_period) twice: side view (octopus_gait_strip_side) and from above
## (octopus_gait_strip_top), so the swim's motion can be judged frame by frame.
## Writes octopus_gait_<set>.png (the sheet) in DIR. The camera rides with the rig (side view, from above a little) so the
## body motion is the arms' and mantle's, not the travel.

var out_dir := "user://octopus_gait_shots"
var sets := ["jet", "dash", "cruise", "turn", "crawl", "roll", "strip"]
var rig: OctopusRig
var holder: Node3D
var camera: Camera3D
const TILE := Vector2i(420, 300)
const COLS := 4
var _floor_y := -2.6
var _move := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--set="):
			sets = arg.trim_prefix("--set=").split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(TILE.x, TILE.y)
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
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(0.5, -2.4, 0.0)
	rim.light_color = Color(1.0, 0.6, 0.35)
	rim.light_energy = 0.8
	add_child(rim)
	holder = Node3D.new()
	add_child(holder)
	rig = OctopusRig.new()
	holder.add_child(rig)
	rig.build_model(6.0)
	rig.floor_query = func(from: Vector3, to: Vector3) -> Dictionary:
		if from.y >= _floor_y and to.y <= _floor_y:
			var t := (from.y - _floor_y) / maxf(from.y - to.y, 0.0001)
			return {"pos": from.lerp(to, t), "normal": Vector3.UP}
		return {}
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.far = 200.0
	add_child(camera)
	camera.make_current()
	_run.call_deferred()


func _snap() -> Image:
	for i in 3:
		await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im


## One sheet: `tiles` tiles, `every` frames apart, `ctx_fn(i)` the step context for frame i (Callable int -> Dictionary).
func _sheet(name: String, tiles: int, every: int, ctx_fn: Callable, warm := 60, view := Vector3(-1.0, 0.12, -0.1), dist := 12.0) -> void:
	var rows := ceili(float(tiles) / COLS)
	var sheet := Image.create(TILE.x * COLS, TILE.y * rows, false, Image.FORMAT_RGBA8)
	var frame := 0
	for i in warm:
		rig.step(1.0 / 60.0, ctx_fn.call(frame))
		frame += 1
	for t in tiles:
		for i in every:
			var c: Dictionary = ctx_fn.call(frame)
			rig.step(1.0 / 60.0, c)
			if _move:
				holder.position += (c["vel"] as Vector3) / 60.0
			frame += 1
		var centre := rig.model.global_position + rig.model.global_basis * Vector3(0, 0, rig.length * 0.12)
		camera.position = centre + view.normalized() * dist
		camera.look_at(centre, Vector3.UP)
		var img := await _snap()
		sheet.blit_rect(img, Rect2i(0, 0, TILE.x, TILE.y), Vector2i((t % COLS) * TILE.x, (t / COLS) * TILE.y))
	sheet.save_png(out_dir.path_join("octopus_gait_%s.png" % name))


func _run() -> void:
	await get_tree().process_frame
	if "jet" in sets:
		await _sheet("jet", 8, 8, func(_f: int) -> Dictionary: return {"throttle": 1.0, "vel": Vector3(0, 0, -6)})
	if "strip" in sets:
		var per := OctopusRig.opt("octopus_jet_period") * 0.8  # the period at speed (see _tick_jet)
		var every := maxi(1, roundi(per * 60.0 / 12.0))
		var jet := func(_f: int) -> Dictionary: return {"throttle": 1.0, "vel": Vector3(0, 0, -7)}
		await _sheet("strip_side", 12, every, jet, 66, Vector3(-1.0, 0.1, 0.0), 7.5)
		await _sheet("strip_top", 12, every, jet, 66 - 12 * every % 66, Vector3(0.0, 1.0, 0.02), 7.5)
	if "dash" in sets:
		await _sheet("dash", 8, 6, func(_f: int) -> Dictionary: return {"throttle": 1.0, "boost": true, "vel": Vector3(0, 0, -14)})
	if "cruise" in sets:
		await _sheet("cruise", 8, 10, func(_f: int) -> Dictionary: return {"throttle": 0.3, "vel": Vector3(0, 0, -3)})
	if "turn" in sets:
		await _sheet("turn", 8, 10, func(f: int) -> Dictionary: return {"throttle": 1.0, "stick": Vector2(sin(float(f) * 0.03), 0.0), "vel": Vector3(0, 0, -6)}, 60, Vector3(0.0, 1.0, -0.3), 12.0)
	if "roll" in sets:
		await _sheet("roll", 8, 10, func(_f: int) -> Dictionary: return {"throttle": 1.0, "air_roll": true, "stick": Vector2(1.0, 0.0), "vel": Vector3(0, 0, -6)}, 30, Vector3(-0.2, 0.3, 1.0), 9.0)
	if "crawl" in sets:
		holder.position = Vector3(0, -0.4, 0)
		_move = true
		var fl := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(80, 80)
		fl.mesh = pm
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.1, 0.16, 0.2)
		fm.roughness = 1.0
		fl.material_override = fm
		fl.position = Vector3(0, _floor_y, 0)
		add_child(fl)
		for gx in range(-10, 11):
			for gz in range(-14, 15):
				var dot := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.12, 0.02, 0.12)
				dot.mesh = bm
				dot.position = Vector3(gx * 1.5, _floor_y + 0.02, gz * 1.5)
				add_child(dot)
		await _sheet("crawl", 8, 14, func(_f: int) -> Dictionary: return {"throttle": 0.0, "vel": Vector3(0, 0, -0.8)}, 90, Vector3(-1.0, 0.8, -0.15), 12.0)
	get_tree().quit()
