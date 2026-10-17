extends Node
## The 1v1's scoreboard: RL's points (MatchStats.tally), touches, clears and
## centres (classify_play), a goal counting as a shot, the teams' possession,
## boost and territory, the HUD's board showing only while its button's held,
## the end of the match (the bubble column lifting everyone, the final board
## coming up by itself) and a new match starting from nothing.
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/scoreboard_probe.tscn

const TICK := 1.0 / 120.0
const HUD_RESULT_TIME := 4.5

var main: Node
var fish: FishController
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	_check_rules()
	_check_column()

	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	main.set_environment("Aquarium Arena")
	main.set_mode(main.ONE_V_ONE)
	main.play_match()
	var game: Match1v1 = main.match_1v1
	game.goal_replays = false
	var aquarium: AquariumArena = main._environment
	var ball := aquarium.ball
	var hud: Node = main.get_node("HUD")
	var board: BroadcastUI.StatsBoard = hud._board
	game.bot.set_physics_process(false)
	game.bot_fish.controls = FishInput.new()
	check(game.stats.size() == 2 and game.stats[0] == MatchStats.new_line(), "both lines start at nothing")
	check(InputMap.has_action("show_scoreboard"), "a show_scoreboard action")

	await get_tree().process_frame
	check(not board.shown and not board.visible, "the board's down until the button's held")
	Input.action_press("show_scoreboard")
	await _seconds(0.3)
	check(board.shown and board.visible and is_equal_approx(board.modulate.a, 1.0), "held: the board's up")
	check(board.teams.size() == 2 and board.teams[0].rows[0].name == fish.display_name
			and board.teams[1].rows[0].name == game.bot_fish.display_name, "a row per fish, on its team")
	check(board.teams[0].rows[0].focus and not board.teams[1].rows[0].focus, "the player's own row is marked")
	check(board.size.x < hud.get_viewport().get_visible_rect().size.x * 0.75 and board.size.y < 300.0,
			"it leaves most of the screen clear (%s)" % str(board.size))
	Input.action_release("show_scoreboard")
	await _seconds(0.3)
	check(not board.visible, "released: it's gone")

	await _seconds(3.2)  # the countdown
	await _shoot(ball, fish, -1.0)
	var line: Dictionary = game.stats[0]
	check(aquarium.scores == [1, 0], "the player scores (%s)" % str(aquarium.scores))
	check(line.goals == 1 and line.shots == 1 and line.touches >= 1, "a goal, one shot (however many touches) and a touch (%s)" % str(line))
	check(line.score >= MatchStats.POINTS[MatchStats.GOAL] + MatchStats.POINTS[MatchStats.SHOT] + MatchStats.POINTS[MatchStats.TOUCH],
			"at least 122 points (%d)" % line.score)
	check(game.stats[1] == MatchStats.new_line(), "the bot's line's untouched (%s)" % str(game.stats[1]))
	Input.action_press("show_scoreboard")
	await get_tree().process_frame
	await get_tree().process_frame
	check(board.teams[0].score == 1 and board.teams[0].rows[0]["values"][0] == line.score and board.teams[0].rows[0]["values"][1] == 1,
			"the board shows the team's score and the player's points and goal (%s)" % str(board.teams[0]))
	var totals: Dictionary = game.team_stats
	check(totals.possession[0] > 0.0 and totals.possession[1] == 0.0, "possession: all Blue's (%s)" % str(totals.possession))
	check(totals.boost[0] > 0.0 and totals.boost[1] == 0.0, "boost used: the player's (%s)" % str(totals.boost))
	check(totals.territory[0] > 0.0, "territory: the ball's been in Orange's half (%s)" % str(totals.territory))
	check(board.bars.size() == 3 and board.bars[0].share == 1.0 and board.bars[0].text == ["100%", "0%"],
			"the bars: possession all Blue's (%s)" % str(board.bars))
	Input.action_release("show_scoreboard")

	# Time runs out with Blue ahead: the result.
	await _seconds(ball.settings.goal_reset_delay + Match1v1.COUNTDOWN_TIME + 0.3)
	check(game.phase == Match1v1.Phase.LIVE, "live again after the goal")
	game.clock_left = 0.02
	await _seconds(0.2)
	check(game.phase == Match1v1.Phase.OVER and game.winner == 0, "the match is over, Blue wins")
	check(is_instance_valid(game.bubble_column) and game.bot.celebrating, "a bubble column goes up, the bot celebrates")
	check(not fish.controls_locked and fish.visible, "the player's free to swim")
	await get_tree().process_frame
	check(not board.shown, "the winner's splash first, not the board")
	var start_y := fish.global_position.y
	await _seconds(3.0)
	check(fish.global_position.y > start_y + 5.0, "the column carries the player up (%.1f -> %.1f m)" % [start_y, fish.global_position.y])
	await _seconds(HUD_RESULT_TIME - 3.0 + 0.4)
	check(board.shown and board.title == "FINAL STATS" and board.footer.begins_with("NEXT MATCH IN"),
			"then the final board comes up by itself (%s / %s)" % [board.title, board.footer])
	await _seconds(3.0)
	check(fish.global_position.y > 12.0 and fish.global_position.y < AquariumArena.SIZE.y, "and bobs near the top, still in it (%.1f m up, %.1f m out)" % [fish.global_position.y, Vector2(fish.global_position.x, fish.global_position.z).length()])

	check(fish.boost_unlimited, "everyone's on unlimited boost")
	# Boosting out of the side: the column doesn't hold on.
	fish.set_spawn(Transform3D(Basis.looking_at(Vector3.RIGHT), Vector3(0.0, 10.0, 0.0)))
	await _seconds(0.1)
	var swim := FishInput.new()
	swim.forward = 1.0
	swim.boost = true
	fish.controls = swim
	await _seconds(1.5)
	fish.controls = null
	var out := Vector2(fish.global_position.x, fish.global_position.z).length()
	check(out > game.bubble_column.radius + 2.0, "a fish can boost out of it (%.1f m out)" % out)

	# Start / R: a new match, everyone back to nothing.
	game.kickoff()
	await get_tree().process_frame
	check(game.stats[0] == MatchStats.new_line() and game.stats[1] == MatchStats.new_line(), "a new match starts the lines afresh")
	check(game.team_stats.possession == [0.0, 0.0], "and the team totals")
	check(not is_instance_valid(game.bubble_column) and not game.bot.celebrating, "the column's gone, the bot's back to playing")
	check(not fish.boost_unlimited and not game.bot_fish.boost_unlimited, "and boost is limited again")

	print("scoreboard_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _check_column() -> void:
	var column := BubbleColumn.new()
	add_child(column)
	var dt := 1.0 / 120.0
	check(column.lift(Vector3(column.radius + 1.0, 2.0, 0.0), Vector3.ZERO, -6.5, dt) == Vector3.ZERO, "no lift outside the column")
	var push := column.lift(Vector3(1.0, 2.0, 0.0), Vector3.ZERO, -6.5, dt)
	check(push.y > 6.5 * dt, "inside, more than gravity's taken back (%.3f)" % push.y)
	check(push.z > 0.0 and push.x < 0.0, "and a swirl round the middle, drawing in (%s)" % str(push))
	push = column.lift(Vector3(0.0, column.height, 0.0), Vector3(0.0, 5.0, 0.0), -6.5, dt)
	check(push.y < 6.5 * dt, "at the top it lets up (%.3f)" % push.y)
	column.free()


func _check_rules() -> void:
	var line := MatchStats.new_line()
	check(line.keys() == MatchStats.COLUMNS, "a line has RL's columns, in order")
	for type in [MatchStats.GOAL, MatchStats.ASSIST, MatchStats.SAVE, MatchStats.SHOT, MatchStats.BATTERY, MatchStats.TOUCH,
			MatchStats.CLEAR, MatchStats.CENTER]:
		MatchStats.tally(line, type)
	check(line.score == 100 + 50 + 50 + 20 + 15 + 2 + 20 + 10, "RL's points add up (%d)" % line.score)
	check(line.goals == 1 and line.assists == 1 and line.saves == 1 and line.shots == 1 and line.battered_fish == 1 and line.touches == 1,
			"each counted once; clears and centres only score (%s)" % str(line))
	# Blue defends +Z.
	check(MatchStats.classify_play(0, Vector3(0, 1, 40), Vector3(0, 0, -20)) == MatchStats.CLEAR, "Blue clears out of its own third")
	check(MatchStats.classify_play(0, Vector3(0, 1, 40), Vector3(0, 0, 20)) == "", "not by knocking it back towards its own goal")
	check(MatchStats.classify_play(0, Vector3(0, 1, 0), Vector3(0, 0, -20)) == "", "not from midfield")
	check(MatchStats.classify_play(0, Vector3(25, 1, -40), Vector3(-10, 0, 0)) == MatchStats.CENTER, "Blue centres from out wide in Orange's third")
	check(MatchStats.classify_play(0, Vector3(25, 1, -40), Vector3(10, 0, 0)) == "", "not by sending it wider")
	check(MatchStats.classify_play(1, Vector3(0, 1, -40), Vector3(0, 0, 20)) == MatchStats.CLEAR, "Orange clears the other way")


func _shoot(ball: Ball, shooter: FishController, end: float) -> void:
	var height: float = ball.settings.radius + 0.05
	var spot := Vector3(0.0, height, end * 44.0)
	shooter.set_spawn(Transform3D(Basis.looking_at(Vector3(0.0, 0.0, end)), spot - Vector3(0.0, 0.0, end * 3.0) + Vector3(0.0, 0.3, 0.0)))
	# The other fish waits out on the wing: parked on its kickoff spot it can block the shot.
	var game: Match1v1 = main.match_1v1
	var other := game.bot_fish if shooter == game.player else game.player
	other.set_spawn(Transform3D(Basis.IDENTITY, Vector3(30.0, height + 0.3, 0.0)))
	ball.respawn(spot)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var push := FishInput.new()
	push.forward = 1.0
	push.boost = true
	var before := shooter.controls
	shooter.controls = push
	var goals: Array = (main._environment as AquariumArena).scores.duplicate()
	var waited := 0.0
	while (main._environment as AquariumArena).scores == goals and waited < 6.0:
		await get_tree().physics_frame
		waited += TICK
	shooter.controls = before


func _seconds(time: float) -> void:
	for i in roundi(time / TICK):
		await get_tree().physics_frame
