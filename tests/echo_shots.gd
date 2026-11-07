extends Node
## Not a probe: What Stinks?'s echo layers (what_stinks.md section 4), to check
## by eye. Plays the real mode through Main in a window and shoots, in the
## Hunter's view, a loner and a prey joined to a school slot at the middle of
## each layer (exposure 0.04 none, 0.16 skeleton, 0.35 cardiovascular, 0.55
## muscular, 0.75 skin, 0.92 aura) as sheets (loner.png, school.png); the
## echo shadows (shadows.png: a kelp stand and a rock arch); and the prey's
## view with the map and the noise and echo rings (prey_hud.png). Needs a
## window (not --headless).
##   Godot_console.exe --path . res://tests/echo_shots.tscn -- --out=DIR

const EXPOSURES := [0.04, 0.16, 0.35, 0.55, 0.75, 0.92]
const CELL := Vector2i(480, 300)

var out_dir := "user://echo_shots"
var main: Node
var game: WhatStinksMatch
var fish: FishController
var camera := Camera3D.new()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = CELL
	camera.fov = 50.0
	add_child(camera)
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw


func _settle() -> void:
	for i in 4:
		await get_tree().process_frame
	await _frames(2)


func _shot() -> Image:
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _start(start_as: int) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _frames(5)
	var settings := WhatStinksSettings.shared()
	settings.hide_time = 0.5
	settings.round_time = 900.0
	settings.arena_radius = 150.0
	settings.school_count = 5
	settings.school_min = 30
	settings.school_max = 40
	settings.min_players = 3
	settings.start_as = start_as
	settings.bots_join = false
	settings.join_any_class = true
	settings.join_radius = 8.0
	settings.join_ease = 0.1
	settings.shadow_count = 4
	settings.click_auto = false
	main.set_mode(main.WHAT_STINKS)
	await _frames(3)
	main.play_match()
	await _frames(3)
	game = main.what_stinks
	while game.phase != WhatStinksMatch.Phase.LIVE:
		await get_tree().physics_frame
	game.echo.set_physics_process(false)
	for prey in game.live_prey():
		prey.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		prey.freeze = true


func _run() -> void:
	await _start(WhatStinksSettings.StartAs.HUNTER)
	var hunter := fish
	hunter.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	hunter.freeze = true
	var prey := game.live_prey()
	var loner: FishController = prey[0]
	var member: FishController = prey[1]
	# A school's slot first: the member joins, the camera sits 7 m off its side.
	var school: School = game.field.schools[0]
	member.freeze = false
	member.global_position = school.fish_position(school.nearest_free(member.global_position)) + Vector3(1.0, 0.0, 0.0)
	game.join.join(member, school)
	await _settle()
	# The loner a little away from everything, in clear water.
	loner.global_position = Vector3(0, 0, 0) + game.center + Vector3(-60, 0, 90)
	camera.make_current()
	for entry: Array in [["loner", loner, false], ["school", member, true]]:
		var who: FishController = entry[1]
		var sheet := Image.create_empty(CELL.x * EXPOSURES.size(), CELL.y, false, Image.FORMAT_RGBA8)
		for n in EXPOSURES.size():
			game.echo.forced[who] = EXPOSURES[n]
			# Aim from the side of whoever it is, 7 m off, a little above; the school moves, so each shot re-aims.
			for k in 3:
				var at := who.global_position
				var side := who.global_basis.x.normalized()
				camera.global_position = at + side * 7.0 + Vector3.UP * 1.5
				camera.look_at(at, Vector3.UP)
				await _settle()
			sheet.blit_rect(_shot(), Rect2i(Vector2i.ZERO, CELL), Vector2i(n * CELL.x, 0))
		game.echo.forced.erase(who)
		sheet.save_png(out_dir.path_join("%s.png" % entry[0]))
		print("echo_shots: %s" % entry[0])
	# The shadows: a kelp stand and a rock arch from a little way off.
	var picture := Image.create_empty(CELL.x * 2, CELL.y, false, Image.FORMAT_RGBA8)
	for n in 2:
		var kind := "kelp" if n == 0 else "arch"
		for spot: Dictionary in game.shadows.spots:
			if spot["kind"] == kind:
				var at: Vector3 = spot["position"]
				var radius: float = spot["radius"]
				camera.global_position = at + Vector3(radius * 1.8, radius * 0.2, radius * 1.8)
				camera.look_at(at + Vector3.UP * radius * 0.1, Vector3.UP)
				break
		await _settle()
		picture.blit_rect(_shot(), Rect2i(Vector2i.ZERO, CELL), Vector2i(n * CELL.x, 0))
	picture.save_png(out_dir.path_join("shadows.png"))
	print("echo_shots: shadows")
	main.queue_free()
	await _frames(5)
	# The prey's view: the map and the rings.
	await _start(WhatStinksSettings.StartAs.PREY)
	game.echo.set_echo(fish, 0.55)
	game.echo.meter_of(fish).noise = 0.35
	get_window().size = Vector2i(960, 540)
	await _settle()
	await _settle()
	var hud := _shot()
	hud.save_png(out_dir.path_join("prey_hud.png"))
	print("echo_shots: prey_hud")
	get_tree().quit()
