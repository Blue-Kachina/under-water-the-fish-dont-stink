extends Node
## The 1v1 mode: switching into it, the kickoff countdown, the bot playing
## (touching the ball, scoring on an idle player), the reset after a goal,
## a demolition and the respawn after it, and switching back to Free Play.
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/match_probe.tscn

const TICK := 1.0 / 120.0

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
	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	main.set_mode(main.FREE_PLAY)
	main.set_environment("Aquarium Arena")
	await _seconds(0.5)
	check(main.match_1v1 == null, "Free Play: no match")

	# Into 1v1.
	main.set_mode(main.ONE_V_ONE)
	main.play_match()
	var game: Match1v1 = main.match_1v1
	game.goal_replays = false  # goal_replay_probe covers those
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(absf(fish.boost_amount - Match1v1.SPAWN_BOOST) < 0.5, "kickoff boost 33 (%.1f)" % fish.boost_amount)
	check(game != null and is_instance_valid(game.bot_fish), "1v1: a match with a bot fish")
	var aquarium: AquariumArena = main._environment
	var ball := aquarium.ball
	check(ball.players.size() == 2 and game.bot_fish in ball.players and fish in ball.players, "both fish can touch the ball")
	check(fish.team_color == AquariumArena.TEAM_COLORS[0] and game.bot_fish.team_color == AquariumArena.TEAM_COLORS[1], "team colours")

	# The countdown: nobody moves.
	await _seconds(0.3)
	var fish_start := fish.global_position
	var bot_start := game.bot_fish.global_position
	check(game.phase == Match1v1.Phase.COUNTDOWN and fish.controls_locked and game.bot_fish.controls_locked, "countdown: both locked")
	check(absf(fish_start.z) > 20.0 and signf(fish_start.z) == -signf(bot_start.z), "kickoff spots at opposite ends (player z %.1f, bot z %.1f)" % [fish_start.z, bot_start.z])
	await _seconds(2.0)
	check(game.bot_fish.global_position.distance_to(bot_start) < 0.5, "the bot waits out the countdown (moved %.2f m)" % game.bot_fish.global_position.distance_to(bot_start))
	await _seconds(1.0)
	check(game.phase == Match1v1.Phase.LIVE and not game.bot_fish.controls_locked, "after 3 s: live")

	# The bot goes for the ball and touches it on the kickoff.
	var touches := {"bot": 0}
	var bot_fish := game.bot_fish
	var count_touch := func(by: Node3D, _hit_speed: float) -> void:
		if by == bot_fish:
			touches.bot += 1
	ball.touched.connect(count_touch)
	await _seconds(5.0)
	check(touches.bot > 0, "the bot touches the ball on the kickoff (%d touches)" % touches.bot)

	# Against an idle player, it scores (and the match resets after).
	var goals := {"orange": 0}
	aquarium.goal_scored.connect(func(team: int) -> void:
		if team == 1:
			goals.orange += 1)
	var waited := 0.0
	while goals.orange == 0 and waited < 120.0:
		await _seconds(1.0)
		waited += 1.0
	check(goals.orange > 0, "the bot scores on an idle player (%.0f s, %d touches)" % [waited, touches.bot])
	if goals.orange > 0:
		check(game.phase == Match1v1.Phase.GOAL, "after the goal: celebration")
		await _seconds(ball.settings.goal_reset_delay + 0.5)
		check(game.phase == Match1v1.Phase.COUNTDOWN and fish.controls_locked, "then the next kickoff's countdown")
		check(absf(fish.global_position.z) > 20.0, "player back on a kickoff spot (z %.1f)" % fish.global_position.z)
		await _seconds(3.0)

	ball.touched.disconnect(count_touch)

	# Demolition: the bot (driven by the probe) rams the parked player at full boost.
	game.bot.set_physics_process(false)
	ball.pop()
	aquarium.set_physics_process(false)
	var ram := FishInput.new()
	ram.forward = 1.0
	ram.boost = true
	game.bot_fish.controls = ram
	game.bot_fish.boost_amount = 100.0
	var spawn_height := aquarium.spawn_transform().origin.y
	fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0.0, spawn_height, -10.0)))
	game.bot_fish.set_spawn(Transform3D(Basis.looking_at(Vector3(0, 0, 1)), Vector3(0.0, spawn_height, -45.0)))
	await get_tree().physics_frame
	await get_tree().physics_frame
	game.bot_fish.boost_amount = 100.0
	var demos := []
	game.demolished.connect(func(attacker: FishController, victim: FishController) -> void: demos.append([attacker, victim]))
	var top_speed := 0.0
	waited = 0.0
	while demos.is_empty() and waited < 5.0:
		await get_tree().physics_frame
		top_speed = maxf(top_speed, game.bot_fish.speed)
		waited += TICK
	check(not demos.is_empty() and demos[0][1] == fish, "the bot demolishes the player (top speed %.1f m/s)" % top_speed)
	check(fish.demolished and not fish.visible, "the player is out of play")
	ram.clear()
	await _seconds(Match1v1.RESPAWN_TIME - 0.1)
	check(fish.demolished, "still out just before %.0f s" % Match1v1.RESPAWN_TIME)
	while fish.demolished:
		await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not fish.demolished and fish.visible, "and back after %.0f s" % Match1v1.RESPAWN_TIME)
	check(fish.global_position.z > 40.0 and absf(fish.global_position.x) > 20.0, "at a respawn spot (%.1f, %.1f)" % [fish.global_position.x, fish.global_position.z])
	check(absf(fish.boost_amount - Match1v1.SPAWN_BOOST) < 0.5, "with 33 boost (%.1f)" % fish.boost_amount)

	# A slow bump doesn't demolish.
	game.bot_fish.set_spawn(Transform3D(Basis.looking_at(Vector3(0, 0, 1)), Vector3(0.0, spawn_height, -16.0)))
	fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0.0, spawn_height, -10.0)))
	ram.forward = 1.0
	await _seconds(2.0)
	ram.clear()
	check(demos.size() == 1, "a slow bump doesn't demolish (bot reached %.1f m/s)" % game.bot_fish.speed)

	# A goal explosion blasts nearby fish.
	aquarium.set_physics_process(true)
	game.bot.set_physics_process(true)
	game.bot_fish.controls = game.bot.input
	main.set_mode(main.FREE_PLAY)
	await _seconds(0.5)
	check(main.match_1v1 == null and not is_instance_valid(game), "Free Play again: the match and bot are gone")
	check(ball.players.size() <= 1 and fish.team_color.a == 0.0 and not fish.controls_locked, "player back to normal")
	check(aquarium.auto_respawn, "the arena respawns the ball itself again")

	fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0.0, spawn_height, 0.0)))
	await _seconds(0.5)
	fish.linear_velocity = Vector3.ZERO
	Explosion.spawn(aquarium, Vector3(0.0, spawn_height, 3.0), Color.ORANGE, AquariumArena.GOAL_EXPLOSION_RADIUS, AquariumArena.GOAL_BLAST)
	await _seconds(0.1)
	check(fish.linear_velocity.z < -5.0, "a goal explosion blasts the fish away (%.1f m/s)" % fish.linear_velocity.z)

	print("match_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _seconds(time: float) -> void:
	for i in roundi(time / TICK):
		await get_tree().physics_frame
