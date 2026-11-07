extends Node
## Not a probe: screenshots of the Drowned Shark's jaw for checking it by eye. The mini-boss is
## spawned in a real Unnatural run, held still (no AI), its chomp posed beat by beat (shut, the
## anticipation, the gape's fling, the hold, the lunge, the impact squash) and shot from the side,
## three-quarter and front. Needs a window.
##   Godot_console.exe --path . res://tests/shark_shots.tscn -- --out=DIR

var out_dir := "user://shark_shots"
var main: Node
var fish: FishController
var run: UnnaturalRun
var camera := Camera3D.new()

## [name, the Bite's phase, how far into it (0 to 1)].
const BEATS := [
	["0_shut", ChompKit.Phase.IDLE, 0.0],
	["1_anticipate", ChompKit.Phase.ANTICIPATE, 1.0],
	["2_gape", ChompKit.Phase.GAPE, 0.7],
	["3_hold", ChompKit.Phase.HOLD, 0.5],
	["4_strike", ChompKit.Phase.STRIKE, 0.6],
	["5_impact", ChompKit.Phase.SHAKE, 0.05],
	["6_wobble", ChompKit.Phase.SHAKE, 0.3],
]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	settings.spawning = false
	settings.stage_events = false
	settings.chest_count = 0
	settings.chest_interval = 0.0
	settings.card_choices = 0
	settings.shrine_count = 0
	settings.god_mode = true
	settings.xp_base = 1.0e9
	main.set_mode(main.UNNATURAL)
	await _frames(5)
	main._match_card.play_requested.emit()
	await _frames(10)
	run = main.unnatural_run
	run.start()
	await _frames(10)
	fish.global_position = run.centre + Vector3(0.0, 0.0, -400.0)
	await _frames(2)
	fish.freeze = true
	fish.visible = false
	add_child(camera)
	camera.far = 2000.0
	camera.current = true
	camera.fov = 55.0
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var murk := settings.murk_density
	settings.murk_density = 0.0
	var shark := DrownedShark.new()
	var at := run.centre + Vector3(0.0, -2.0, 0.0)
	run._add_boss(shark, at, 1.0e9)
	shark.set_physics_process(false)
	shark.global_position = at
	shark.face(Vector3(-1.0, 0.0, 0.0))
	await _frames(3)
	var size := shark._length
	var head := shark.mouth_point()
	for beat: Array in BEATS:
		_pose(shark, beat[1], beat[2])
		await _frames(3)
		await _view(head + Vector3(-size * 0.1, size * 0.02, size * 0.3), head, "%s_side" % beat[0])
		await _view(head + Vector3(-size * 0.25, size * 0.1, size * 0.22), head, "%s_three_quarter" % beat[0])
		await _view(head + Vector3(-size * 0.3, size * 0.03, 0.0), head, "%s_front" % beat[0])
	settings.murk_density = murk
	get_tree().quit()


## The shark's chomp held at `phase`, `into` (0 to 1) through it, as its Bite would have it.
func _pose(shark: DrownedShark, phase: ChompKit.Phase, into: float) -> void:
	var bite: ChompKit.Bite = shark._bite
	if phase == ChompKit.Phase.IDLE:
		bite.cancel()
		bite.smear = Vector3.ONE
		bite.update(1.0)
		shark.jaw = 0.0
	else:
		bite.start(0.52, 6.0)
		bite._enter(phase)
		bite.t = bite.duration(phase) * into
		bite.update(0.0001)
		shark.jaw = bite.open
	shark._pose_head()
	shark._pose_jaw()


func _view(from: Vector3, at: Vector3, shot_name: String) -> void:
	camera.global_position = from
	camera.look_at(at, Vector3.UP)
	await _frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % shot_name))
	print("shot ", shot_name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
