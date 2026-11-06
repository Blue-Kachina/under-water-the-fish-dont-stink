extends Node
## Marco Polo HUD shots: a real match in the Sunken Temple, one shot per local
## role (seeker, hider, spectator) once the round's LIVE, so the base HUD (the
## boost gauge), MarcoPoloHud and the SonarMap can be checked for overlaps.
## Not headless (it needs the renderer); pick the window size with --resolution.
##   Godot_console.exe --path . --resolution 1600x900 res://tests/marco_hud_shots.tscn -- --out=<dir>

const TICKS := 120

var main: Node
var fish: FishController
var out_dir := "user://marco_hud_shots"


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
	var mp := MarcoPoloSettings.shared()
	mp.arena = "Sunken Temple"
	mp.hide_time = 0.5
	mp.round_time = 120.0
	mp.min_players = 4
	mp.rounds = 3
	mp.bot_seeker_rounds = 1
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	main.set_mode(main.MARCO_POLO)
	await _ticks(5)
	main._match_card.play_requested.emit()
	await _ticks(10)
	var game: MarcoPoloMatch = main.marco_polo
	if game == null:
		print("marco_hud_shots: no match")
		get_tree().quit(1)
		return
	var size := Vector2(get_window().size)
	var tag := "%dx%d" % [roundi(size.x), roundi(size.y)]
	await _live(game)
	await _shot("seeker_%s" % tag)
	game.start_round(1)  # a bot seeks: the player hides
	await _live(game)
	await _shot("hider_%s" % tag)
	game._eliminate(fish)
	await _ticks(TICKS)
	await _shot("spectator_%s" % tag)
	print("marco_hud_shots: done (%s)" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit(0)


func _live(game: MarcoPoloMatch) -> void:
	for i in TICKS * 5:
		if game.phase == MarcoPoloMatch.Phase.LIVE:
			break
		await get_tree().physics_frame
	await _ticks(TICKS)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(shot_name + ".png"))


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
