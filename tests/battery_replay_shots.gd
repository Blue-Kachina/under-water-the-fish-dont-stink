extends Node
## Renders Hunt's battery replay (needs a window): a HunterBot drives the player's
## fish at the opponent (left still) until it batters it, then frames of the
## arcade replay are saved: the ghosts' stride tails, bow waves and bubbles,
## the vignette, the hit-stop. Pass the folder to save into after `--`.
##   Godot_console.exe --path . res://tests/battery_replay_shots.tscn -- <out dir>

## Clip times (s before the impact; negative after it) to save a frame at.
const SHOTS := [2.0, 1.2, 0.6, 0.25, 0.05, -0.02, -0.3]

var main: Node
var out_dir := "user://battery_replay_shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	main.set_mode(main.HUNT)
	await _frames(3)
	main._match_card.play_requested.emit()
	await _frames(5)
	var hunt: HuntMatch = main.hunt_match
	hunt.battery_replays = true
	# The opponent waits; a second hunter swims the player's fish at it.
	hunt.bot.process_mode = Node.PROCESS_MODE_DISABLED
	hunt.bot.input.clear()
	var driver := HunterBot.new()
	driver.fish = hunt.player
	driver.target = hunt.opponent
	driver.difficulty = BotDifficulty.basic()
	driver.difficulty.evade_chance = 0.0
	driver.arena_center = hunt.center
	driver.arena_radius = HuntMatch.ARENA_RADIUS
	hunt.add_child(driver)
	Engine.max_physics_steps_per_frame = 16
	Engine.time_scale = 4.0
	for i in 60 * 60 * 2:
		if hunt.phase == HuntMatch.Phase.REPLAY:
			break
		await get_tree().process_frame
	Engine.time_scale = 1.0
	if hunt.phase != HuntMatch.Phase.REPLAY:
		print("battery_replay_shots: no battery to replay")
		get_tree().quit(1)
		return
	var replay := hunt.battery_replay
	var next := 0
	while is_instance_valid(replay) and hunt.battery_replay == replay and next < SHOTS.size():
		if replay.time >= replay.goal_time - SHOTS[next]:
			await RenderingServer.frame_post_draw
			var path := out_dir.path_join("replay_%d.png" % next)
			get_viewport().get_texture().get_image().save_png(path)
			print("saved %s (clip %.2f s, shot %s, freeze %.2f)" % [path, replay.time, replay.shot, replay._freeze_left])
			next += 1
			continue
		await get_tree().process_frame
	print("battery_replay_shots: %d frames" % next)
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
