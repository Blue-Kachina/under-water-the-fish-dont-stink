extends Node
## Not a probe: What Stinks?'s cameras (WhatStinksCam), to check by eye. Plays
## the real mode through Main in a window and shoots the Hunter's actual view:
## the follow cam (the Hunter swimming, then a moment after a hard turn) and the
## lock-on (a school 80 m off to the side, locked, with the school wheel open in
## a last frame) for the Shark at 0.5x/1x/3x/10x and the King of Herrings and
## Gulper Mother at 1x. One PNG per form and size, the four views side by side.
## Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/what_stinks_cam_shots.tscn -- --out=DIR

const CELL := Vector2i(640, 360)
const CASES := [["drowned_shark", 0.5], ["drowned_shark", 1.0], ["drowned_shark", 3.0], ["drowned_shark", 10.0],
		["king_of_herrings", 1.0], ["gulper_mother", 1.0]]

var out_dir := "user://what_stinks_cam_shots"
var main: Node
var game: WhatStinksMatch
var fish: FishController
var camera: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = CELL
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _shot() -> Image:
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _place(at: Vector3, facing: Vector3) -> void:
	fish.global_transform = Transform3D(Basis.looking_at(facing.normalized(), Vector3.UP), at)
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	await _frames(5)
	var settings := WhatStinksSettings.shared()
	settings.hide_time = 0.5
	settings.round_time = 900.0
	settings.arena_radius = 200.0
	settings.school_count = 2
	settings.school_min = 30
	settings.school_max = 40
	settings.school_speed = 0.0
	settings.min_players = 3
	settings.hunter_blind = false
	main.set_mode(main.WHAT_STINKS)
	await _frames(3)
	main.play_match()
	await _frames(3)
	game = main.what_stinks
	while game.phase != WhatStinksMatch.Phase.LIVE:
		await _ticks(1)
	for prey in game.live_prey():
		prey.freeze = true
	for case: Array in CASES:
		await _case(case[0], case[1])
	print("what_stinks_cam_shots: done, in %s" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _case(form: String, size: float) -> void:
	WhatStinksSettings.shared().form = form
	HunterSize.shared().size_mult = size
	game._become_hunter(fish)
	await _ticks(3)
	var school: School = game.field.schools[0]
	var other: School = game.field.schools[1]
	var sheet := Image.create_empty(CELL.x * 4, CELL.y, false, Image.FORMAT_RGBA8)
	# Follow cam: swimming with the school off to the right, 80 m ahead and aside.
	var ahead := Vector3(0.6, 0.0, -0.8)
	var right := ahead.cross(Vector3.UP).normalized()
	var spot := school.middle() - ahead * 80.0 - right * 30.0
	_place(spot, ahead)
	fish.freeze = false
	camera.snap()
	for i in 120:
		fish.linear_velocity = ahead * 6.0 * pow(size, 0.5)
		await get_tree().physics_frame
	await _frames(2)
	sheet.blit_rect(_shot(), Rect2i(Vector2i.ZERO, CELL), Vector2i(0, 0))
	# A hard turn to the right and a moment on: the view is turning with it.
	var turned := right
	fish.global_transform = Transform3D(Basis.looking_at(turned, Vector3.UP), fish.global_position)
	for i in 36:
		fish.linear_velocity = turned * 6.0 * pow(size, 0.5)
		await get_tree().physics_frame
	await _frames(2)
	sheet.blit_rect(_shot(), Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x, 0))
	# Lock-on: the Hunter still, the nearest school ahead locked.
	fish.freeze = true
	_place(spot, school.middle() - spot)
	camera.snap()
	camera.call("set_ball_cam", true)
	await _ticks(2)
	game.lock_cam.pick_focus(fish)
	camera.snap()
	await _ticks(100)
	await _frames(2)
	sheet.blit_rect(_shot(), Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * 2, 0))
	# The wheel open over it, the other school picked.
	game.lock_cam.wheel.open()
	game.lock_cam.wheel.picked = [other.centre, other.display_name, other.alive_count()]
	await _frames(3)
	sheet.blit_rect(_shot(), Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * 3, 0))
	game.lock_cam.wheel.is_open = false
	camera.call("set_ball_cam", false)
	sheet.save_png(out_dir.path_join("%s_%s.png" % [form, str(size).replace(".", "_")]))
	print("what_stinks_cam_shots: %s %.1fx" % [form, size])
