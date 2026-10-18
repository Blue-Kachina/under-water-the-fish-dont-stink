extends Node
## Not a probe: screenshots of Unnatural's second play-test round, checked by
## eye: the arena's edge (outcrops, kelp, the red wall of light), the three
## drops, a dropped chest, every powerup worn, and your stats beside the board.
## Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/round2_shots.tscn -- --out=DIR

var out_dir := "user://round2_shots"
var main: Node
var fish: FishController


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	var powers := PowerupSettings.shared()
	settings.spawning = false
	settings.stage_events = false
	settings.bite_damage = 0.0
	settings.chest_open_time = 999.0  # the chest shown stays shut
	main.set_mode(main.UNNATURAL)
	await _frames(5)
	main._match_card.play_requested.emit()
	await _frames(10)
	var run: UnnaturalRun = main.unnatural_run
	var camera: Camera3D = main._camera
	fish.freeze = true

	# The edge: near it, looking out.
	var out := Vector3(1, 0, 0.3).normalized()
	var at := run.centre + out * settings.arena_radius * 0.8 + Vector3.UP * 2.0
	fish.global_transform = Transform3D(Basis.looking_at(out, Vector3.UP), at)
	fish.reset_physics_interpolation()
	camera.snap()
	await _seconds(1.5)
	await _shot("edge")
	fish.global_transform = Transform3D(Basis.looking_at(out, Vector3.UP), run.centre + out * (settings.arena_radius - 12.0) + Vector3.UP * 4.0)
	fish.reset_physics_interpolation()
	camera.snap()
	await _seconds(1.5)
	await _shot("edge_near")

	# The drops in a row ahead, and a chest dropped beside them.
	fish.global_transform = Transform3D(Basis.IDENTITY, run.centre + Vector3.UP * 2.0)
	fish.reset_physics_interpolation()
	camera.snap()
	await _seconds(1.0)
	for kind in 3:
		run.drop_pickup(kind, fish.global_position + Vector3((kind - 1) * 1.6, 0.6, -5.0))
	run.add_chest(fish.global_position + Vector3(3.5, -1.0, -7.0), 0.4)
	await _seconds(1.0)
	await _shot("drops")

	# Every powerup worn, seen from the side.
	powers.fire_stacks = 2
	powers.lightning_stacks = 2
	powers.torpedo_stacks = 2
	powers.bow_stacks = 2
	for pickup in run.pickups:
		pickup.queue_free()
	await _seconds(0.5)
	camera.set_process(false)
	camera.global_transform = Transform3D(Basis.IDENTITY, fish.global_position + Vector3(2.2, 0.8, 0.5))
	camera.look_at(fish.global_position, Vector3.UP)
	await _seconds(0.5)
	await _shot("worn")
	camera.set_process(true)

	# Your stats beside the board.
	run.block_of(fish).add("damage", 0.3)
	run.block_of(fish).add("luck", 0.2)
	Input.action_press("show_scoreboard")
	await _seconds(0.5)
	await _shot("stats")
	Input.action_release("show_scoreboard")
	powers.fire_stacks = 0
	powers.lightning_stacks = 0
	powers.torpedo_stacks = 0
	powers.bow_stacks = 0
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", ProjectSettings.globalize_path(path))


func _seconds(s: float) -> void:
	var left := s
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
