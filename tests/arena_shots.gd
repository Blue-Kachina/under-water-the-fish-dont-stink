extends Node
## Not a probe: screenshots of the match tank for checking the look by eye:
## the floor markings from above and at a goal, the glass walls from outside
## (the chase camera up under the ceiling), and the boost gauge in each
## character's own colour in Free Play. Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/arena_shots.tscn -- --out=DIR

const TICK := 1.0 / 120.0

var main: Node
var fish: FishController
var out_dir := "user://arena_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	main.get_node("DebugPanel")._panel.visible = false
	main.set_mode(main.FREE_PLAY, false)
	await _seconds(0.5)
	var follow: Camera3D = main.get_node("FollowCamera")

	var overhead := Camera3D.new()
	overhead.projection = Camera3D.PROJECTION_ORTHOGONAL
	overhead.size = AquariumArena.SIZE.x * 1.05
	overhead.keep_aspect = Camera3D.KEEP_HEIGHT
	overhead.far = 200.0
	add_child(overhead)
	# Lengthways across the screen.
	overhead.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.LEFT), Vector3(0.0, 60.0, 0.0))
	overhead.make_current()
	await _seconds(0.1)
	await _shot("1_floor_overhead")

	var at_goal := Camera3D.new()
	at_goal.fov = 90.0
	add_child(at_goal)
	at_goal.look_at_from_position(Vector3(12.0, 9.0, 28.0), Vector3(0.0, 0.0, 46.0))
	at_goal.make_current()
	await _seconds(0.1)
	await _shot("2_floor_team_0_end")
	at_goal.look_at_from_position(Vector3(0.0, 6.0, -12.0), Vector3(0.0, 0.0, 6.0))
	await _seconds(0.1)
	await _shot("3_centre_circle")
	at_goal.look_at_from_position(Vector3(-3.0, 3.0, -44.0), Vector3(0.0, 0.0, -51.0))
	await _seconds(0.1)
	await _shot("3a_team_1_goal_line")

	# Pressed up under the ceiling, facing along the tank: the chase camera sits outside it.
	follow.make_current()
	fish.buoyancy = 0.0
	fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0.0, AquariumArena.SIZE.y - 0.4, 10.0)))
	await _seconds(1.0)
	await _shot("4_glass_from_above")
	# Up the side wall: the camera ends up beyond it.
	fish.set_spawn(Transform3D(Basis(Vector3.UP, Vector3.LEFT, Vector3.BACK), Vector3(AquariumArena.SIZE.x / 2.0 - 0.4, 6.0, 20.0)))
	await _seconds(1.0)
	await _shot("5_glass_from_side")

	for fish_class: FishCharacter.FishClass in FishCharacter.CLASSES:
		main.set_character(fish_class)
		fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 30.0)))
		fish.boost_amount = 70.0
		await _seconds(0.6)
		await _shot("6_boost_%s" % FishCharacter.CLASSES[fish_class].key)
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))


func _seconds(time: float) -> void:
	for i in roundi(time / TICK):
		await get_tree().physics_frame
