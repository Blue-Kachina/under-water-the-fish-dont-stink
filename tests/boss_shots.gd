extends Node
## Not a probe: screenshots of the final bosses for checking their models by
## eye. Each boss is spawned in a real Unnatural run, its body laid along a set
## S-curve (no AI), and shot from the side (whole body), its head three-quarter
## and front, above, and through the murk as you'd meet it. Needs a window.
##   Godot_console.exe --path . res://tests/boss_shots.tscn -- --boss=king|gulper|whale|lamprey|all --out=DIR

const KINDS := ["king", "gulper", "whale", "lamprey"]

var out_dir := "user://boss_shots"
var wanted := "all"
var main: Node
var fish: FishController
var run: UnnaturalRun
var camera := Camera3D.new()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--boss="):
			wanted = arg.trim_prefix("--boss=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
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
	fish.global_position = run.centre + Vector3(0.0, 0.0, -400.0)  # out of every shot (and its bubbles with it)
	await _frames(2)
	fish.freeze = true
	fish.visible = false
	add_child(camera)
	camera.far = 2000.0
	camera.current = true
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for kind: String in KINDS:
		if wanted == "all" or wanted == kind:
			await _shoot(kind)
	get_tree().quit()


func _shoot(kind: String) -> void:
	var settings := UnnaturalSettings.shared()
	var murk := settings.murk_density
	var boss := run.make_final_boss(kind)
	var head := run.centre + Vector3(0.0, -2.0, 0.0)
	run._add_boss(boss, head, 1.0e9)
	boss.set_physics_process(false)
	await _frames(2)
	var length := boss.body_length()
	# An S-curve back from the head, heading -x.
	var trail := PackedVector3Array()
	var steps := 160
	for i in range(steps, -1, -1):
		var d := length * 1.3 * i / steps
		trail.append(head + Vector3(d, sin(d / length * PI * 1.2) * length * 0.04, sin(d / length * TAU * 0.9) * length * 0.16))
	boss.global_position = head
	boss.velocity = Vector3(-1.0, 0.0, 0.0) * 10.0
	boss.face(boss.velocity)
	boss.pose_for_shot(trail)
	await _frames(3)
	var mid := head + Vector3(length * 0.45, 0.0, 0.0)
	settings.murk_density = 0.0
	await _frames(2)
	await _view(mid + Vector3(0.0, length * 0.25, length * 0.85), mid, "%s_side" % kind)
	var g := settings.leviathan_girth
	await _view(head + Vector3(-g * 2.2, g * 0.9, g * 2.6), head + Vector3(g * 0.6, -g * 0.1, 0.0), "%s_head" % kind)
	await _view(head + Vector3(-g * 3.2, g * 0.2, 0.2), head + Vector3(0.0, -g * 0.2, 0.0), "%s_front" % kind)
	await _view(mid + Vector3(0.0, length * 0.55, 1.0), mid, "%s_top" % kind)
	settings.murk_density = murk
	await _frames(2)
	await _view(head + Vector3(-g * 6.0, g * 1.5, g * 5.0), head + Vector3(g * 2.0, 0.0, 0.0), "%s_murk" % kind)
	boss.queue_free()
	run.bosses.erase(boss)
	await _frames(3)


func _view(from: Vector3, at: Vector3, shot_name: String) -> void:
	camera.global_position = from
	camera.look_at(at, Vector3.UP)
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % shot_name))
	print("shot ", shot_name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
