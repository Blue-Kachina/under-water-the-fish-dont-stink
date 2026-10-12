extends Node
## Not a probe: screenshots of the HUD in a 1v1 (live, the goal splash, the
## goal replay's two shots, the result) for checking the look by eye. Needs a
## window (not --headless).
##   Godot_console.exe --path . res://tests/hud_shots.tscn -- --out=DIR

const TICK := 1.0 / 120.0

var main: Node
var fish: FishController
var out_dir := "user://hud_shots"


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
	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	main.set_environment("Aquarium Arena", false)
	main.set_mode(main.ONE_V_ONE)
	var game: Match1v1 = main.match_1v1
	game.goal_replays = true
	game.bot.set_physics_process(false)
	game.bot_fish.controls = FishInput.new()
	var ball: Ball = main._environment.ball
	await _seconds(1.0)
	await _shot("1_countdown")
	await _seconds(2.5)
	fish.boost_amount = 64.0
	await _shot("2_live")
	await _shoot(ball)
	await _seconds(0.6)
	await _shot("3_goal_splash")
	await _seconds(ball.settings.goal_reset_delay)
	await _seconds(0.8)
	await _shot("4_replay_chase")
	while is_instance_valid(game.goal_replay) and game.goal_replay.shot != "net":
		await get_tree().process_frame
	await _seconds(0.5)
	await _shot("5_replay_net")
	while is_instance_valid(game.goal_replay) and game.goal_replay.time < game.goal_replay.goal_time + 0.1:
		await get_tree().process_frame
	await _shot("6_replay_goal")
	if is_instance_valid(game.goal_replay):
		game.goal_replay.skip()
	main._environment.scores = [3, 2]
	game.clock_left = 0.1
	await _seconds(4.0)
	await _seconds(0.8)
	await _shot("7_result")
	print("hud_shots: saved to %s" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))


func _shoot(ball: Ball) -> void:
	var spot := Vector3(-3.0, ball.settings.radius + 0.05, -40.0)
	fish.set_spawn(Transform3D(Basis.looking_at(Vector3(0.1, 0.0, -1.0)), spot + Vector3(0.3, 0.3, 4.0)))
	ball.respawn(spot)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var push := FishInput.new()
	push.forward = 1.0
	push.boost = true
	fish.controls = push
	var before: Array = main._environment.scores.duplicate()
	var waited := 0.0
	while main._environment.scores == before and waited < 8.0:
		await get_tree().physics_frame
		waited += TICK
	fish.controls = null


func _seconds(time: float) -> void:
	for i in roundi(time / TICK):
		await get_tree().physics_frame
