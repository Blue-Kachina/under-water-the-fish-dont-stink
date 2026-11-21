extends Node3D
## Not a probe: contact sheets of the great white's procedural rig (SwimRig, planning_core_roadmap.md 2.3 P4), for
## judging the pose by eye (shader and pose work can't be judged headless). A bare shark model on a holder that is moved
## and turned by script, its SwimState made from the holder's own motion (advance_from_velocity), stepped at 60 fps.
## Each sheet is a row of tiles, the rig OFF (the controller's old pose, copied below since there is no controller here)
## on the top row and ON (layers at the Hunter gait's defaults) on the bottom. The camera rides with the holder.
## Needs a window (not --headless); it quits when done.
##   Godot_console.exe --path . res://tests/shark_rig_shots.tscn -- --out=DIR [--set=straight,turn,brake,stride,drift]
##     [--views=side,three_quarter,top]
## Writes shark_rig_<scenario>_<view>.png in DIR. Scenarios: straight_0/5/15/30 (steady speeds, tiles across one wave),
## turn_15 and turn_30 (a full-lock turn from straight, tiles 0.25 s apart from its start), brake_30 (30 m/s to a stop),
## stride (a chain of strides), drift (the nose 35 degrees off the travel).

const TILE := Vector2i(360, 240)
const TILES := 6
const DT := 1.0 / 60.0

var out_dir := "user://shark_rig_shots"
var sets: Array[String] = ["straight", "turn", "brake", "stride", "drift"]
var views: Array[String] = ["side", "three_quarter", "top"]
var holder: Node3D
var camera: Camera3D
var model: FishModel
var gait: Gait
var swim := SwimState.new()
var _legacy_phase := 0.0

## Each scenario: speed (m/s), speed_after and ramp (s) for a brake, spin (rad/s) for a turn, slip (degrees) for a drift,
## strides for a stride chain, lead (s of straight running first), every (s between tiles), the views it's shot from.
const SCENARIOS := [
	{"name": "straight_0", "set": "straight", "speed": 0.0, "lead": 1.5, "every": 0.15, "views": ["top", "three_quarter"]},
	{"name": "straight_5", "set": "straight", "speed": 5.0, "lead": 2.0, "every": 0.12, "views": ["top", "three_quarter"]},
	{"name": "straight_15", "set": "straight", "speed": 15.0, "lead": 2.0, "every": 0.09, "views": ["top", "three_quarter"]},
	{"name": "straight_30", "set": "straight", "speed": 30.0, "lead": 2.0, "every": 0.07, "views": ["top", "three_quarter"]},
	{"name": "turn_15", "set": "turn", "speed": 15.0, "spin": 2.0, "lead": 2.0, "every": 0.25, "views": ["top", "three_quarter", "side"]},
	{"name": "turn_30", "set": "turn", "speed": 30.0, "spin": 1.4, "lead": 2.0, "every": 0.25, "views": ["top", "three_quarter", "side"]},
	{"name": "brake_30", "set": "brake", "speed": 30.0, "speed_after": 0.0, "ramp": 1.5, "lead": 2.0, "every": 0.25, "views": ["top", "three_quarter"]},
	{"name": "stride", "set": "stride", "speed": 14.0, "strides": true, "lead": 1.5, "every": 0.2, "views": ["side", "top"]},
	{"name": "drift", "set": "drift", "speed": 15.0, "slip": 35.0, "ramp": 0.3, "lead": 2.0, "every": 0.2, "views": ["top", "three_quarter"]},
]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--set="):
			sets.assign(arg.trim_prefix("--set=").split(","))
		elif arg.begins_with("--views="):
			views.assign(arg.trim_prefix("--views=").split(","))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = TILE
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.07, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.42, 0.55)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.9, 0.6, 0.0)
	key.light_color = Color(0.85, 0.92, 1.0)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(0.6, -2.4, 0.0)
	fill.light_energy = 0.5
	add_child(fill)
	holder = Node3D.new()
	add_child(holder)
	model = FishModel.build(FishCharacter.FishClass.HUNTER, 0)
	holder.add_child(model)
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 100.0
	holder.add_child(camera)
	camera.make_current()
	gait = GaitSettings.default_for(FishCharacter.FishClass.HUNTER)
	swim.gait = gait
	_run.call_deferred()


func _snap() -> Image:
	for i in 3:
		await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im


## The controller's own tail pose (FishController._process, copied), since a bare model has no controller: the swim
## stroke swinging the tail with effort and the stride swing, on its own clock, written to the tail pivot each frame.
func _controller_pose(effort: float, stride: Vector2) -> void:
	_legacy_phase += DT * lerpf(4.0, 18.0, effort)
	if swim.striding:
		var idle := sin(_legacy_phase) * lerpf(0.1, 0.25, effort) * (1.0 - minf(stride.length(), 1.0))
		model.tail.rotation.y = stride.x * 0.6 + idle
		model.tail.rotation.x = stride.y * 0.6
	else:
		model.tail.rotation.y = sin(_legacy_phase) * lerpf(0.15, 0.45, effort)
		model.tail.rotation.x = 0.0


## One step of scenario `sc` at time `t`: moves and turns the holder, makes the state, poses the model.
func _step(sc: Dictionary, t: float) -> void:
	var lead: float = sc.lead
	var after := maxf(t - lead, 0.0)
	var speed: float = sc.speed
	if sc.has("speed_after"):
		speed = lerpf(speed, float(sc.speed_after), clampf(after / maxf(float(sc.ramp), 0.01), 0.0, 1.0))
	var spin := float(sc.get("spin", 0.0)) * clampf(after / 0.2, 0.0, 1.0)
	var slip := deg_to_rad(float(sc.get("slip", 0.0))) * clampf(after / maxf(float(sc.get("ramp", 0.3)), 0.01), 0.0, 1.0)
	holder.rotate_y(spin * DT)
	var forward := -holder.global_basis.z
	var velocity := forward.rotated(Vector3.UP, -slip) * speed
	swim.advance_from_velocity(velocity, holder.global_basis, DT, FishModel.SWIM_REF_SPEED)
	var stride := Vector2.ZERO
	swim.striding = sc.has("strides")
	swim.stride_power = 0.0
	if swim.striding:
		var cycle := fposmod(t, 1.0)
		stride = Vector2(1.0 if fposmod(t, 2.0) < 1.0 else -1.0, 0.0)
		swim.stride_power = sin(cycle * PI)
		swim.stride_dir = stride * swim.stride_power
		swim.effort = 1.0
		model.set_stride_cue(cycle, 0.6 + 0.4 * swim.stride_power, smoothstep(0.6, 1.0, cycle))
		stride = swim.stride_dir
	else:
		swim.stride_dir = Vector2.ZERO
	_controller_pose(swim.effort, stride)
	model.react(DT, swim)


func _frame_camera(view: String) -> void:
	var size := model._size.z
	var centre := Vector3(0.0, 0.0, size * 0.05)
	var d := size * 1.4
	match view:
		"side":
			camera.position = centre + Vector3(d, d * 0.05, 0.0)
			camera.transform = camera.transform.looking_at(centre, Vector3.UP)
		"three_quarter":
			camera.position = centre + Vector3(d * 0.65, d * 0.35, -d * 0.6)
			camera.transform = camera.transform.looking_at(centre, Vector3.UP)
		_:
			camera.position = centre + Vector3(0.0, d * 1.05, 0.0)
			camera.transform = camera.transform.looking_at(centre, Vector3.FORWARD)


## One scenario's sheet for `view`: the rig OFF row then the rig ON row.
func _sheet(sc: Dictionary, view: String) -> void:
	var sheet := Image.create(TILE.x * TILES, TILE.y * 2, false, Image.FORMAT_RGBA8)
	for row in 2:
		gait.procedural_rig = row == 1
		holder.transform = Transform3D.IDENTITY
		model.rotation = Vector3.ZERO
		swim.reset()
		var t := 0.0
		for tile in TILES:
			var upto := t + (float(sc.lead) if tile == 0 else float(sc.every))
			while t < upto:
				_step(sc, t)
				t += DT
			_frame_camera(view)
			var img := await _snap()
			sheet.blit_rect(img, Rect2i(0, 0, TILE.x, TILE.y), Vector2i(tile * TILE.x, row * TILE.y))
	sheet.save_png(out_dir.path_join("shark_rig_%s_%s.png" % [sc.name, view]))


func _run() -> void:
	await get_tree().process_frame
	for sc: Dictionary in SCENARIOS:
		if not (sc.set in sets):
			continue
		for view: String in sc.views:
			if view in views:
				await _sheet(sc, view)
				print("wrote shark_rig_%s_%s.png" % [sc.name, view])
	print("shark_rig_shots: done, in %s" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit()
