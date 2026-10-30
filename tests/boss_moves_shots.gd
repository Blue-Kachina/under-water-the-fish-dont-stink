extends Node
## Not a probe: screenshots of the bosses' signature moves for checking them
## by eye (the memorable-bosses pass): the Drowned Shark's jaw open and shut,
## the King's gaping jaw and its coil round a player, the Gulper sucking and
## then swallowed (its lump, the break-free panel), the Lamprey's flared disc
## and her latch, a hagfish's knot, the Fallen Angel locked on (its halo).
## Each boss is live in a real Unnatural run (enemy speed 0). Needs a window.
##   Godot_console.exe --path . res://tests/boss_moves_shots.tscn -- --out=DIR [--only=shark|king|gulper|lamprey|whale|angel]

var out_dir := "user://boss_moves_shots"
var only := ""
var main: Node
var fish: FishController
var run: UnnaturalRun
var camera := Camera3D.new()
var settings := UnnaturalSettings.shared()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	settings.spawning = false
	settings.stage_events = false
	settings.chest_count = 0
	settings.chest_interval = 0.0
	settings.card_choices = 0
	settings.shrine_count = 0
	settings.god_mode = true
	settings.xp_base = 1.0e9
	settings.enemy_speed_scale = 0.0
	settings.murk_density = 0.0
	settings.bite_damage = 0.0
	settings.final_hold_time = 20.0
	main.set_mode(main.UNNATURAL)
	await _frames(5)
	main._match_card.play_requested.emit()
	await _frames(10)
	run = main.unnatural_run
	run.start()
	await _frames(10)
	add_child(camera)
	camera.far = 2000.0
	camera.current = true
	_hud(false)
	for step: String in ["shark", "king", "gulper", "lamprey", "whale", "angel"]:
		if only == "" or only == step:
			await call("_" + step)
	get_tree().quit()


func _place(at: Vector3) -> void:
	fish.freeze = false
	fish.global_position = at
	fish.linear_velocity = Vector3.ZERO
	fish.freeze = true


func _spawn(boss: Boss) -> Boss:
	_place(run.centre + Vector3(0.0, 8.0, 60.0))
	run._add_boss(boss, run.centre + Vector3(0.0, 10.0, 0.0), 1.0e9)
	await _physics(4)
	return boss


func _gone(boss: Boss) -> void:
	if boss is BloodLeviathan:
		(boss as BloodLeviathan).release()
	run.bosses.erase(boss)
	boss.queue_free()
	await _physics(4)


func _shark() -> void:
	var shark := await _spawn(DrownedShark.new()) as DrownedShark
	shark._charge_left = 1000.0
	shark._chomp_cool = 1000.0
	var head := shark.mouth_point()
	var side := shark.global_basis.x
	var fwd := -shark.global_basis.z
	var l := shark._length
	await _view(head + side * l * 0.45 + fwd * l * 0.1 - Vector3.UP * l * 0.05, head, "shark_shut")
	shark.jaw = 1.0
	shark._pose_jaw()
	await _view(head + side * l * 0.45 + fwd * l * 0.1 - Vector3.UP * l * 0.05, head, "shark_open_side")
	await _view(head + fwd * l * 0.55 + side * l * 0.12 + Vector3.UP * l * 0.02, head, "shark_open_front")
	await _gone(shark)


func _king() -> void:
	var king := await _spawn(UnnaturalRun.make_final_boss("boss")) as BloodLeviathan
	king._dive_left = 1000.0
	king._chomp_cool = 1000.0
	await _physics(30)
	var g := settings.leviathan_girth
	var frame := king.rig.frame_at(0.0)
	var head := frame.origin
	var side := frame.basis.x
	var fwd := -frame.basis.z
	var eye := head + side * g * 2.2 + fwd * g * 0.6 - Vector3.UP * g * 0.3
	var look := head - frame.basis.z * -g * 0.4 - Vector3.UP * g * 0.4
	await _view(eye, look, "king_jaw_rest")
	king.jaw = 1.0
	king._glow_now()
	await _view(eye, look, "king_jaw_gape")
	king.jaw = -1.0
	king._glow_now()
	await _view(eye, look, "king_jaw_snapped")
	king.jaw = 0.0
	king.hp = king.max_hp * 0.2
	king.phase = BloodLeviathan.Phase.FURY
	king._regrab_left = 0.0
	_place(king.mouth_point())
	await _physics(200)
	var c := king._coil_center
	await _view(c + Vector3(g * 4.5, g * 1.2, g * 4.5), c, "king_coil_side")
	await _view(c + Vector3(0.5, g * 12.0, 0.0), c, "king_coil_top")
	await _gone(king)


func _gulper() -> void:
	var gulper := await _spawn(UnnaturalRun.make_final_boss("gulper")) as GulperBoss
	gulper.hp = gulper.max_hp * 0.2
	gulper.phase = BloodLeviathan.Phase.FURY
	gulper._regrab_left = 1000.0
	var g := settings.leviathan_girth
	var frame := gulper.rig.frame_at(0.0)
	var fwd := -frame.basis.z
	var mouth := gulper.mouth_point()
	_place(mouth + fwd * settings.gulper_suck_range * 0.8)
	gulper._regrab_left = 0.0
	settings.gulper_suck = 0.001  # it sucks (the stream shows) but leaves them where they are
	await _physics(40)
	await _view(mouth + frame.basis.x * g * 6.0 + fwd * g * 3.0 + Vector3.UP * g, mouth + fwd * g * 2.0, "gulper_suck")
	settings.gulper_suck = 14.0
	_place(mouth)
	await _physics(160)
	var belly := gulper.rig.place(Vector3(0.0, 0.0, gulper._lump_z))
	_hud(true)
	await _view(belly + frame.basis.x * g * 6.0 + Vector3.UP * g * 1.5, belly, "gulper_swallowed")
	_hud(false)
	await _gone(gulper)


func _lamprey() -> void:
	var lamprey := await _spawn(UnnaturalRun.make_final_boss("lamprey")) as LampreyBoss
	lamprey._lunge_cool = 1000.0
	var g := settings.leviathan_girth
	var frame := lamprey.rig.frame_at(0.0)
	var fwd := -frame.basis.z
	var head := frame.origin
	await _view(head + fwd * g * 3.5 + frame.basis.x * g * 1.8, head, "lamprey_disc_rest")
	lamprey._lunge_wind = 1000.0
	await _physics(40)
	await _view(head + fwd * g * 3.5 + frame.basis.x * g * 1.8, head, "lamprey_disc_flared")
	lamprey._lunge_wind = 0.0
	lamprey.hp = lamprey.max_hp * 0.2
	lamprey.phase = BloodLeviathan.Phase.FURY
	lamprey._regrab_left = 0.0
	_place(lamprey.mouth_point())
	await _physics(70)
	frame = lamprey.rig.frame_at(0.0)
	await _view(frame.origin + frame.basis.x * g * 5.0 + -frame.basis.z * g * 3.0 + Vector3.UP * g, frame.origin + frame.basis.z * g * 3.0, "lamprey_latched")
	await _gone(lamprey)


func _whale() -> void:
	var whale := await _spawn(UnnaturalRun.make_final_boss("whale")) as WhaleFallBoss
	var h: WhaleFallBoss.Hagfish = whale.hagfish[2]
	_place(h.head + whale._exit_out(h.index) * 6.0)
	h.state = 2
	h.state_left = WhaleFallBoss.STRIKE
	h.aim = fish.global_position
	await _physics(int(settings.hagfish_knot_time * 120) + 120)
	var mid := h.rig.frame_at(settings.hagfish_length * 0.4).origin
	var out := whale._exit_out(h.index)
	var across := out.cross(Vector3.UP).normalized()
	await _view(mid + across * settings.hagfish_length * 0.9 + Vector3.UP * settings.hagfish_length * 0.3, mid, "whale_knot_side")
	await _view(mid + Vector3.UP * settings.hagfish_length * 1.1 + across, mid, "whale_knot_top")
	await _gone(whale)


func _angel() -> void:
	settings.enemy_speed_scale = 1.0
	var angel := await _spawn(UnnaturalRun.make_final_boss("angel")) as FallenAngelBoss
	_place(angel.global_position + Vector3(0.0, -4.0, 25.0))
	angel._start_lock(fish)
	await _physics(200)
	var mid := (angel.global_position + fish.global_position) * 0.5 + Vector3.DOWN * angel.height() * 0.2
	var side := (fish.global_position - angel.global_position).cross(Vector3.UP).normalized()
	await _view(mid + side * angel.height() * 0.9 + Vector3.UP * angel.height() * 0.15, mid, "angel_lock")
	settings.enemy_speed_scale = 0.0
	await _gone(angel)


## The HUD (and the boss's name splash) shown or not.
func _hud(on: bool) -> void:
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = on and layer is UnnaturalHud


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


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
