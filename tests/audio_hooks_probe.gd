extends Node
## Sound effects, phase 1 (planning_audio.md §4): the game asks for its sounds.
## Every fish, the ball and the aquarium get their sound node; boost (start,
## loop, tail, empty), jumps, dodges, strokes, strides, supersonic and resets;
## ball hits, bounces and respawns; the goal net and horn; a 1v1's countdown,
## GO, last ten seconds, buzzer, overtime and result; the UI's sounds settled
## once a frame, buttons, the pause menu. Listens to Sfx.requested, so it
## works whatever profile is picked.
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/audio_hooks_probe.tscn

const TICK := 1.0 / 120.0

var main: Node
var fish: FishController
var failures := 0
var heard: Array[String] = []


func _ready() -> void:
	Sfx.requested.connect(func(id: String) -> void: heard.append(id))
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
	var aquarium: AquariumArena = main._environment
	var ball := aquarium.ball
	print("hooked up:")
	check(fish.get_node_or_null("Sounds") is FishSounds, "the fish has its FishSounds")
	check(ball.get_node_or_null("Sounds") is BallSounds, "the ball has its BallSounds")
	check(aquarium.get_node_or_null("Sounds") is ArenaSounds, "the aquarium has its ArenaSounds")
	# The game's startup scene is in the tree before the hooks listen (unlike a
	# probe's): a ball that arrived unseen is still hooked up by the first sweep.
	get_tree().node_added.disconnect(Sfx.hooks._on_node_added)
	var unseen := Ball.new()
	add_child(unseen)
	get_tree().node_added.connect(Sfx.hooks._on_node_added)
	Sfx.hooks._hook_existing(get_tree().root)
	await get_tree().process_frame
	check(unseen.get_node_or_null("Sounds") is BallSounds, "a node already in the tree when the hooks start gets its sounds")
	check(fish.get_children().filter(func(child: Node) -> bool: return child is FishSounds).size() == 1, "and nothing is hooked twice")
	unseen.queue_free()

	await _fish_sounds()
	await _ball_sounds(aquarium)
	await _match_sounds(aquarium)
	await _ui_sounds()
	print("audio_hooks_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


func _fish_sounds() -> void:
	print("fish:")
	var input := FishInput.new()
	fish.controls = input
	fish.boost_enabled = true
	fish.boost_unlimited = false
	fish.boost_amount = 100.0
	heard.clear()
	input.boost = true
	await _seconds(3.0)
	check(heard.has("fish/boost_start") and heard.has("fish/boost_loop"), "boost: its start and its loop")
	check(heard.has("fish/supersonic"), "supersonic on the way (%.1f m/s)" % fish.linear_velocity.length())
	input.boost = false
	await _seconds(0.1)
	check(heard.has("fish/boost_stop"), "letting go: the tail")
	var regen := fish.boost_regen
	fish.boost_regen = 0.0
	fish.boost_amount = 0.0
	heard.clear()
	input.boost = true
	await _seconds(0.1)
	check(heard.has("fish/boost_empty") and not heard.has("fish/boost_start"), "boost with none left: the empty click, no boost")
	input.boost = false
	fish.boost_regen = regen
	fish.boost_amount = 100.0
	await _seconds(1.5)

	heard.clear()
	await _press_jump(input)
	await _seconds(0.1)
	await _press_jump(input)
	check(heard.has("fish/jump") and heard.has("fish/double_jump"), "jump, then a double jump")
	await _seconds(2.0)
	heard.clear()
	await _press_jump(input)
	input.stick = Vector2(0.0, -1.0)
	await _seconds(0.1)
	await _press_jump(input)
	input.stick = Vector2.ZERO
	check(heard.has("fish/dodge"), "jump, then a dodge")
	await _seconds(2.0)
	print("  (info) heard landing after the air: %s" % heard.has("fish/land"))

	heard.clear()
	fish.stroke_beat.emit(0.0, false)
	fish.stroke_beat.emit(0.9, false)
	fish.stroke_beat.emit(0.0, true)
	fish.strode.emit(0.8, 0.4)
	check(heard.count("fish/stroke") == 2 and heard.has("fish/stroke_miss") and heard.has("fish/stride"),
			"strokes, a missed one and a stride")
	heard.clear()
	main.reset_play()
	await _seconds(0.05)
	check(heard.has("fish/reset"), "a reset (R)")
	heard.clear()
	fish.revive(fish.global_transform)
	fish.set_spawn(fish.global_transform)
	await _seconds(0.05)
	check(not heard.has("fish/reset"), "a mode placing the fish (revive, set_spawn) stays quiet")
	fish.batter()
	await _seconds(0.05)
	fish.controls_locked = true
	heard.clear()
	fish.revive(fish.global_transform)
	await _seconds(0.05)
	check(not heard.has("fish/reset"), "back from a battery at a kickoff (controls locked) stays quiet")
	fish.batter()
	await _seconds(0.05)
	fish.controls_locked = false
	heard.clear()
	fish.revive(fish.global_transform)
	await _seconds(0.05)
	check(heard.has("fish/reset"), "back from a battery mid-play: the respawn")
	fish.controls_locked = false
	fish.controls = null
	await _seconds(0.5)


func _ball_sounds(aquarium: AquariumArena) -> void:
	print("ball:")
	var ball := aquarium.ball
	heard.clear()
	ball.respawn(Vector3(0.0, 8.0, 0.0))
	check(heard.has("ball/reset"), "respawning")
	await _seconds(0.05)
	ball.linear_velocity = Vector3(0.0, -18.0, 0.0)
	await _seconds(1.5)
	check(heard.has("ball/bounce"), "a bounce off the floor")
	heard.clear()
	ball.touched.emit(fish, 12.0)
	check(heard.has("ball/hit"), "a fish's hit")
	heard.clear()
	aquarium._score(aquarium.goals[0])
	check(heard.has("arena/goal_net") and heard.has("match/goal_horn_aquarium"), "a goal: the net and the aquarium's horn")
	await _seconds(0.2)
	aquarium.reset_kickoff()
	await _seconds(0.5)


func _match_sounds(aquarium: AquariumArena) -> void:
	print("1v1:")
	heard.clear()
	main.set_mode(main.ONE_V_ONE)
	main.play_match()
	var game: Match1v1 = main.match_1v1
	game.goal_replays = false
	await _seconds(0.1)
	check(game.get_node_or_null("Sounds") is MatchSounds, "the match has its MatchSounds")
	check(game.bot_fish.get_node_or_null("Sounds") is FishSounds, "the bot's fish has its FishSounds")
	await _seconds(3.2)
	check(heard.count("match/countdown") == 3, "3, 2, 1 (%d)" % heard.count("match/countdown"))
	check(heard.has("match/go"), "GO")
	check(not heard.has("fish/reset"), "nobody's kickoff respawn makes a reset sound")
	game.bot.set_physics_process(false)
	game.clock_left = 10.5
	heard.clear()
	await _seconds(11.0)
	check(heard.count("match/clock_tick") == 10, "the last ten seconds tick (%d)" % heard.count("match/clock_tick"))
	check(heard.has("match/time_up") and heard.has("match/overtime"), "the buzzer, tied: overtime")
	await _seconds(3.5)
	heard.clear()
	var theirs: Goal = aquarium.goals.filter(func(goal: Goal) -> bool: return goal.team == 1)[0]
	aquarium._score(theirs)  # the player's team (0) scores in team 1's goal
	await _seconds(aquarium.ball.settings.goal_reset_delay + 0.5)
	check(heard.has("match/win") and not heard.has("match/lose"), "an overtime goal for you: a win")
	main.set_mode(main.FREE_PLAY)
	await _seconds(0.5)


func _ui_sounds() -> void:
	print("menus:")
	heard.clear()
	Sfx.ui("ui/move")
	Sfx.ui("ui/select")
	Sfx.ui("ui/mode_chosen")
	Sfx.ui("ui/mode_picker_close")
	await get_tree().process_frame
	await get_tree().process_frame
	check(heard == ["ui/mode_chosen"], "one press, one sound: the most specific, the first of equals %s" % [heard])
	heard.clear()
	Sfx.ui("ui/move")
	await get_tree().process_frame
	await get_tree().process_frame
	check(heard.is_empty(), "focus landing just after: quiet")
	await _seconds(0.3)

	var button := Button.new()
	add_child(button)
	var silent := Button.new()
	silent.set_meta(&"sfx", "")
	add_child(silent)
	heard.clear()
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(heard == ["ui/select"], "a button: select %s" % [heard])
	await _seconds(0.3)
	heard.clear()
	silent.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(heard.is_empty(), "a button with its own sound (sfx \"\"): nothing from the hooks")
	await _seconds(0.3)

	var pause: PauseMenu = main._pause_menu
	heard.clear()
	pause.open()
	await get_tree().process_frame
	await get_tree().process_frame
	check(heard.has("ui/pause") and not heard.has("ui/move"), "the pause menu opens (focus landing in it is quiet) %s" % [heard])
	await _seconds(0.3)
	heard.clear()
	pause.close()
	await get_tree().process_frame
	await get_tree().process_frame
	check(heard == ["ui/unpause"], "and closes %s" % [heard])


func _press_jump(input: FishInput) -> void:
	input.jump = true
	await _seconds(0.05)
	input.jump = false
	await _seconds(0.02)


func _seconds(time: float) -> void:
	for i in roundi(time / TICK):
		await get_tree().physics_frame
