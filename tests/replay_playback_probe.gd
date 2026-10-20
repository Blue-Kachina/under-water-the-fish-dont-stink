## Replay playback in the game: loading the converter's fixture switches to the
## Aquarium, sets the live fish and ball aside, and plays ghosts the camera and
## HUD follow. Seeking is exact and repeatable, the ball is in Orange's net at
## Blue's goal, a demolished car vanishes and comes back, and closing the replay
## restores everything.
## Run headless: Godot_console.exe --headless --path . res://tests/replay_playback_probe.tscn [-- REAL.replay]
## With a real .replay (or .rlreplay.json), also checks it converts and plays.
extends Node

const FIXTURE := "res://tests/fixtures/replay_fixture.rlreplay.json"

var main: Node
var fish: FishController
var camera: Camera3D
var hud: Node
var failures := 0
var stage := "loading"
var wait := 0.0
var goals_seen := 0
var cuts := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_mode(main.FREE_SWIM)  # the replay must switch to the Aquarium, and back after
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	hud = main.get_node("HUD")
	main.load_replay(ProjectSettings.globalize_path(FIXTURE))


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _process(delta: float) -> void:
	wait += delta
	match stage:
		"loading":
			if main.replay != null:
				_check_started()
				stage = "playing"
				wait = 0.0
			elif wait > 10.0:
				check(false, "the replay loads within 10 s")
				_finish()
		"playing":
			if wait > 1.0:
				_check_playing()
				_check_seeking()
				_check_following()
				stage = "fast"
				wait = 0.0
				var replay: ReplayPlayer = main.replay
				replay.seek(5.0)
				replay.speed = 4.0
				replay.playing = true
		"fast":
			var replay: ReplayPlayer = main.replay
			if not replay.playing or wait > 5.0:
				check(goals_seen == 1, "played through the goal once: goal_reached x%d" % goals_seen)
				check(replay.time == replay.data.duration and not replay.playing, "stops at the end: %.2f / %.2f s" % [replay.time, replay.data.duration])
				_check_closing()
				var args := OS.get_cmdline_user_args()
				if args.is_empty():
					_finish()
				else:
					print("real replay %s:" % args[0].get_file())
					stage = "real"
					wait = 0.0
					main.load_replay(args[0])
		"real":
			if main.replay != null:
				var replay: ReplayPlayer = main.replay
				check(replay.cars.size() >= 2 and replay.data.duration > 60.0,
						"converted and playing: %d players, %.0f s (%.1f s to convert and load)" % [replay.cars.size(), replay.data.duration, wait])
				check(main._panel._status.text.begins_with("Replay: "), main._panel._status.text)
				main.stop_replay()
				_finish()
			elif wait > 120.0 or main._panel._status.text.contains("failed") or main._panel._status.text.contains("Can't"):
				check(false, "converts and plays: %s" % main._panel._status.text)
				_finish()


func _check_started() -> void:
	print("started:")
	var replay: ReplayPlayer = main.replay
	replay.goal_reached.connect(func(_event: Dictionary) -> void: goals_seen += 1)
	replay.cut.connect(func() -> void: cuts += 1)
	check(main.current_environment == "Aquarium Arena", "switched to the Aquarium")
	var aquarium: AquariumArena = main._environment
	check(not fish.visible and fish.freeze and fish.process_mode == Node.PROCESS_MODE_DISABLED, "live fish set aside")
	check(aquarium.ball.popped and not aquarium.is_physics_processing(), "live ball set aside, no scoring or respawns")
	check(replay.cars.size() == 2 and replay.ball != null, "two ghosts and a ball")
	check(camera.target == replay.target and camera.ball == replay.ball, "camera follows the ghost, ball cam the replay ball")
	check(hud.replay == replay, "HUD shows the replay")


func _check_playing() -> void:
	print("playing:")
	var replay: ReplayPlayer = main.replay
	check(replay.playing and replay.time > 0.5, "time advances: %.2f s" % replay.time)
	var car := replay.cars[0]
	var s := replay.data.sample_car(0, replay.time, ReplayData.Sample.new())
	var expected: Vector3 = s.position + Basis(s.rotation) * replay.data.players[0].hitbox_offset
	check(car.global_position.is_equal_approx(expected), "ghost sits at its hitbox centre: %s" % car.global_position)
	check((car.get_node("Visual") as FishModel).body_color() == AquariumArena.TEAM_COLORS[0], "team 0's ghost wears its team colour")
	var family := FishCharacter.from_key(replay.data.players[0].hitbox_family)
	check(car.get_node("Visual").scale.is_equal_approx(replay.data.players[0].hitbox_size / FishCharacter.hitbox_size(family)), "ghost sized to its hitbox")
	check(replay.cars[1].get_node("Visual").family == FishCharacter.from_key(replay.data.players[1].hitbox_family),
			"each ghost is its car's fish (%s, %s)" % [replay.data.players[0].hitbox_family, replay.data.players[1].hitbox_family])


func _check_seeking() -> void:
	print("seeking:")
	var replay: ReplayPlayer = main.replay
	var data := replay.data
	replay.playing = false
	replay.seek(5.5)
	var first: Array = replay.cars.map(func(c: ReplayCar) -> Transform3D: return c.global_transform)
	var ball_first := replay.ball.global_position
	replay.seek(2.0)
	replay.seek(9.0)
	replay.seek(5.5)
	var again: Array = replay.cars.map(func(c: ReplayCar) -> Transform3D: return c.global_transform)
	check(first == again and replay.ball.global_position == ball_first, "seeking back to a time gives exactly the same scene")
	check(cuts >= 4, "each seek is a camera cut (%d)" % cuts)

	var goal_time := data.next_event_time("goal", 0.0)
	replay.seek(goal_time)
	var orange_goal: Goal = (main._environment as AquariumArena).goals[1]
	check(replay.ball.visible and orange_goal.contains_ball(replay.ball.global_position, ReplayBall.RADIUS),
			"at Blue's goal the ball is in Orange's net: %s" % replay.ball.global_position)
	hud._process(0.0)  # the HUD refreshes once a frame; read it now
	check(hud._scorebug.scores == [1, 0] and hud._scorebug.visible, "scoreboard shows the score at the goal: %s" % str(hud._scorebug.scores))
	check(hud._lists[0].visible and hud._lists[1].visible and hud._lists[0].rows[0].name == data.players[0].name,
			"player lists show each team")
	var types: Array = MatchStats.replay_events(data).map(func(e: Dictionary) -> String: return e.type)
	check(types.has(MatchStats.GOAL) and types.has(MatchStats.SHOT), "events worked out from the touches: %s" % str(types))
	replay.seek(goal_time - 0.3)
	hud._process(0.0)
	replay.seek(goal_time + 0.05)
	hud._process(0.0)
	check(hud._lists[0]._badges.get(0, [""])[0] == MatchStats.GOAL, "the scorer's goal badge pops as the goal plays")
	replay.seek(goal_time + 0.5)
	check(not replay.ball.visible, "ball gone after the goal")

	replay.seek(data.times[190])
	check(not replay.cars[1].visible, "demolished car hidden")
	replay.seek(data.times[205])
	check(replay.cars[1].visible, "and back after its respawn")
	replay.seek(1.0)
	hud._process(0.0)
	check(hud._course.text == "Kickoff in 3" and hud._scorebug.scores == [0, 0], "countdown shown: %s, score %s" % [hud._course.text, str(hud._scorebug.scores)])

	replay.step(1)
	var after_step := replay.time
	check(not replay.playing and is_equal_approx(after_step, data.times[data.frame_at(1.0) + 1]), "steps one frame: %.4f s" % after_step)


func _check_following() -> void:
	print("following:")
	var replay: ReplayPlayer = main.replay
	replay.seek(5.0)  # both cars present
	replay.view = ReplayPlayer.View.PLAYER
	replay.set_watch(0)
	replay.cycle_watch()
	check(replay.watch == 1 and replay.follow == 1 and camera.current and camera.target == replay.cars[1],
			"next Target: the car cam follows %s" % replay.target.player.name)
	hud._process(0.0)
	check(hud._stats.text.begins_with(replay.target.player.name), "HUD reads the followed player")
	replay.seek(data_time(190))  # Orange demolished: cycling skips it
	replay.set_watch(0)
	replay.cycle_watch()
	check(replay.watch == ReplayPlayer.FREE, "skips a player who isn't in the game (on to Free)")
	replay.cycle_watch()
	check(replay.watch == ReplayPlayer.AUTO, "and round to Auto")
	replay.set_watch(0)


func data_time(frame: int) -> float:
	return (main.replay as ReplayPlayer).data.times[frame]


func _check_closing() -> void:
	print("closing:")
	main.stop_replay()
	check(main.replay == null and main.current_environment == "Ocean", "back to the Ocean")
	check(fish.visible and not fish.freeze and fish.process_mode == Node.PROCESS_MODE_INHERIT, "live fish back")
	check(camera.target == null and hud.replay == null, "camera and HUD back on the fish")


func _finish() -> void:
	stage = "done"
	print("replay_playback_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	await get_tree().process_frame  # let closed replays free first
	get_tree().quit(1 if failures else 0)
