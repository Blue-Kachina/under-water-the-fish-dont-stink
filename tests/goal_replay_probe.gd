extends Node
## The 1v1's broadcast pieces: goal credit (scorer and assist), the goal replay
## (its clip, camera shots, slow motion, skipping and finishing), the clock
## running out into overtime and the result, and the HUD's UI toggles.
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/goal_replay_probe.tscn

const TICK := 1.0 / 120.0

var main: Node
var fish: FishController
var failures := 0


class Toucher extends Node3D:
	var team := -1


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
	_check_credit()

	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	main.set_environment("Aquarium Arena", false)
	main.set_mode(main.ONE_V_ONE)
	var game: Match1v1 = main.match_1v1
	game.goal_replays = true
	var aquarium: AquariumArena = main._environment
	var ball := aquarium.ball
	var follow: Camera3D = main.get_node("FollowCamera")
	var hud: Node = main.get_node("HUD")
	game.bot.set_physics_process(false)  # the probe places the ball itself
	game.bot_fish.controls = FishInput.new()
	check(not game.bot_fish.display_name.is_empty() and game.bot_fish.team == 1 and fish.team == 0, "names and teams (bot: %s)" % game.bot_fish.display_name)
	check(hud._scorebug.visible and hud._boost.visible, "scoreboard and boost gauge show in the 1v1")
	check(hud._scorebug.clock == "5:00", "the clock starts at 5:00 (%s)" % hud._scorebug.clock)
	await _seconds(3.2)
	check(game.phase == Match1v1.Phase.LIVE, "live after the countdown")
	await _seconds(2.0)
	check(game.clock_left < Match1v1.MATCH_TIME - 1.5 and game.clock_left > Match1v1.MATCH_TIME - 2.5, "the clock runs while live (%.2f)" % game.clock_left)

	# A goal for Blue: the player taps the ball into the Orange net (-Z).
	await _shoot(ball, fish, -1.0)
	check(game.phase == Match1v1.Phase.GOAL and aquarium.scores == [1, 0], "Blue scores (%s)" % str(aquarium.scores))
	check(aquarium.last_goal.get("scorer") == fish, "the player is credited")
	check(hud._splash.visible and hud._splash.headline == fish.display_name, "the splash names the scorer (%s)" % hud._splash.headline)
	var clock_at_goal := game.clock_left
	await _seconds(ball.settings.goal_reset_delay + 0.1)
	check(is_equal_approx(game.clock_left, clock_at_goal), "the clock stops after a goal")
	check(game.phase == Match1v1.Phase.REPLAY and is_instance_valid(game.goal_replay), "then the goal replay")
	var replay := game.goal_replay
	if replay:
		check(get_viewport().get_camera_3d() == replay._camera, "on the replay camera")
		check(not fish.visible and not game.bot_fish.visible, "the live fish wait out of sight")
		check(hud._replay_overlay.visible and hud._replay_overlay.scorer == fish.display_name, "the replay overlay names the scorer")
		check(replay.data.duration > 3.0 and replay.goal_time > 2.5, "a clip from before the goal (%.1f s, goal at %.1f)" % [replay.data.duration, replay.goal_time])
		check(replay.shot == "chase", "it opens on the chase camera")
		check(replay.playback_rate(replay.goal_time) < 0.5 and replay.playback_rate(0.0) == 1.0, "slow motion at the goal only")
		var shots := {}
		var waited := 0.0
		while is_instance_valid(replay) and not replay._done and waited < 20.0:
			shots[replay.shot] = true
			await get_tree().process_frame
			waited += get_process_delta_time()
		check(shots.has("net"), "it cuts to the net camera (%s)" % ", ".join(shots.keys()))
		check(waited < 15.0, "and finishes by itself (%.1f s)" % waited)
		await get_tree().physics_frame
		check(game.phase == Match1v1.Phase.COUNTDOWN and game.goal_replay == null, "then the next kickoff")
		check(get_viewport().get_camera_3d() == follow, "back on the follow camera")
		await _seconds(0.1)
		check(fish.visible and game.bot_fish.visible and not hud._replay_overlay.visible, "fish back, overlay gone")

	# A second goal, replay skipped.
	await _seconds(3.2)
	await _shoot(ball, fish, -1.0)
	await _seconds(ball.settings.goal_reset_delay + 0.3)
	check(game.phase == Match1v1.Phase.REPLAY, "second goal's replay")
	if game.goal_replay:
		game.goal_replay.skip()
		await get_tree().physics_frame
		check(game.phase == Match1v1.Phase.COUNTDOWN and get_viewport().get_camera_3d() == follow, "skipped: straight to the kickoff")

	# Time runs out tied -> overtime; a goal in overtime ends it.
	aquarium.scores = [2, 2]
	await _seconds(3.2)
	game.clock_left = 0.2
	await _seconds(0.4)
	check(game.overtime and game.phase == Match1v1.Phase.COUNTDOWN, "tied at 0:00: overtime from a kickoff")
	await _seconds(3.5)
	check(game.overtime_elapsed > 0.1, "the overtime clock counts up (%.2f)" % game.overtime_elapsed)
	check(hud._scorebug.caption == "OVERTIME" and hud._scorebug.clock.begins_with("+"), "scoreboard shows overtime (%s)" % hud._scorebug.clock)
	game.goal_replays = false
	var results := []
	game.match_over.connect(func(w: int) -> void: results.append(w))
	await _shoot(ball, game.bot_fish, 1.0)
	await _seconds(ball.settings.goal_reset_delay + 0.2)
	check(results == [1] and game.phase == Match1v1.Phase.OVER, "an overtime goal wins it (Orange)")
	check(hud._splash.visible and hud._splash.title.begins_with("ORANGE"), "the result splash (%s)" % hud._splash.title)
	await _seconds(Match1v1.OVER_TIME + 0.2)
	check(game.phase == Match1v1.Phase.COUNTDOWN and aquarium.scores == [0, 0] and not game.overtime
			and game.clock_left == Match1v1.MATCH_TIME, "then a new match")

	# UI toggles (set directly: set_value would save over this PC's settings).
	check(UISettings.show_stats == hud._stats_panel.visible, "stats panel follows its setting")
	for on in [true, false]:
		UISettings.show_stats = on
		UISettings.show_input_overlay = on
		UISettings.changed.emit("show_stats")
		check(hud._stats_panel.visible == on and hud._viz.visible == on, "stats panel and controller overlay %s" % ("on" if on else "off"))

	main.set_mode(main.FREE_PLAY)
	print("goal_replay_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## Credit rules, on stand-in fish.
func _check_credit() -> void:
	var a := Toucher.new()
	a.team = 0
	var b := Toucher.new()
	b.team = 0
	var c := Toucher.new()
	c.team = 1
	var credit := AquariumArena.goal_credit([[b, 1.0], [c, 2.0], [a, 3.0], [a, 3.1]], 0, 4.0)
	check(credit.scorer == a and credit.assister == b, "scorer a, assist b")
	credit = AquariumArena.goal_credit([[b, 1.0], [a, 7.0]], 0, 8.0)
	check(credit.scorer == a and credit.assister == null, "no assist from a touch 7 s before the goal")
	credit = AquariumArena.goal_credit([[a, 1.0], [c, 2.0]], 0, 3.0)
	check(credit.scorer == a, "a defender's last touch doesn't steal the goal")
	credit = AquariumArena.goal_credit([[c, 2.0]], 0, 3.0)
	check(credit.scorer == null, "own goal: nobody credited")
	var free := Toucher.new()
	credit = AquariumArena.goal_credit([[free, 1.0]], 1, 2.0)
	check(credit.scorer == free, "Free Play: the fish gets it either way")
	for node in [a, b, c, free]:
		node.free()


## Puts `shooter` behind the ball near a goal (`end`: -1 Orange's at -Z, +1 Blue's)
## and rolls the ball in off it, waiting for the goal.
func _shoot(ball: Ball, shooter: FishController, end: float) -> void:
	var height: float = ball.settings.radius + 0.05
	var spot := Vector3(0.0, height, end * 44.0)
	shooter.set_spawn(Transform3D(Basis.looking_at(Vector3(0.0, 0.0, end)), spot - Vector3(0.0, 0.0, end * 3.0) + Vector3(0.0, 0.3, 0.0)))
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
