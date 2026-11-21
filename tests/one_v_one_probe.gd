extends Node
## 1v1 (Fish Sticks: 1v1): H0 characterisation for the GameMode migration
## (planning_core_roadmap.md 3.3). A scripted, seeded match through the card,
## kickoff, a goal for each side with its replay, a battery and its respawn,
## time-up into overtime, the overtime goal's result, a restart, and back to
## Free Play, writing one row per moment (match state, HUD slots, camera
## claim, fish tuning) to tests/fixtures/one_v_one_baseline.json. A normal run
## diffs against it; --record rewrites it. The bot is switched off: the probe
## places the ball and the fish itself. Reads only the match, the HUD and the
## camera (not main's mode fields), so it holds across the migration.
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/one_v_one_probe.tscn [-- --record]

const TICK := 1.0 / 120.0
const BASELINE := "res://tests/fixtures/one_v_one_baseline.json"

var main: Node
var fish: FishController
var hud: Node
var camera: Node
var failures := 0
var snaps: Array[Dictionary] = []
var events: Array[Dictionary] = []
var record := false
var battered_count := 0


func _ready() -> void:
	seed(20261121)
	record = "--record" in OS.get_cmdline_args() or "--record" in OS.get_cmdline_user_args()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	hud = main.get_node("HUD")
	camera = main.get_node("FollowCamera")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _game() -> Match1v1:
	return main.match_1v1


func _run() -> void:
	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	main.set_mode(main.FREE_PLAY)
	main.set_environment("Aquarium Arena")
	await _ticks(30)
	_snap("free_play")
	check(main.current_environment == "Aquarium Arena" and _game() == null, "Free Play: the arena, no match")

	print("card:")
	main.set_mode(main.ONE_V_ONE)
	await _ticks(5)
	_snap("card")
	check(main._match_card != null and _game() == null and not fish.visible, "1v1 waits on its card, fish sitting out")
	check(main.ONE_V_ONE in main.MODES and main.ONE_V_ONE in main.MATCH_MODES, "1v1 is in the mode lists")
	check(main.current_environment == "Aquarium Arena", "1v1 plays in the Aquarium Arena")
	check(main._match_card.message == main._match_card_text(main.ONE_V_ONE) and "5 minutes" in main._match_card.message, "the card's text")

	print("kickoff:")
	main._match_card.play_requested.emit()
	await _ticks(5)
	var game := _game()
	check(game != null and main._match_card == null and fish.visible, "Play starts the match, fish back")
	game.goal_replays = false
	game.bot.process_mode = Node.PROCESS_MODE_DISABLED
	game.bot_fish.controls = FishInput.new()
	game.stat_event.connect(func(event: Dictionary) -> void: events.append(event))
	var aquarium: AquariumArena = main._environment
	var ball := aquarium.ball
	check(game.phase == Match1v1.Phase.COUNTDOWN and fish.controls_locked and game.bot_fish.controls_locked, "both locked for the countdown")
	check(fish.team == 0 and game.bot_fish.team == 1 and fish.team_color == AquariumArena.TEAM_COLORS[0], "teams and colours")
	check(camera.ball == ball, "the camera looks at the arena's ball")
	check(main._reset_label() != "", "a reset label (%s)" % main._reset_label())
	_snap("countdown")
	await _ticks(roundi((Match1v1.COUNTDOWN_TIME + 0.1) * 120.0))
	_snap("go_live")
	check(game.phase == Match1v1.Phase.LIVE and not fish.controls_locked, "GO: live")
	await _ticks(120)
	_snap("live_1s")

	print("goal for the player, with its replay:")
	game.goal_replays = true
	await _shoot(ball, fish, -1.0)
	await _ticks(2)
	_snap("player_goal")
	check(game.phase == Match1v1.Phase.GOAL and aquarium.scores == [1, 0], "the player scores 1-0")
	await _ticks(roundi((ball.settings.goal_reset_delay + 0.2) * 120.0))
	_snap("replay_starts")
	check(game.phase == Match1v1.Phase.REPLAY and is_instance_valid(game.goal_replay), "then the goal replay")
	await _ticks(2)
	_snap("replay_hud")
	game.goal_replay.skip()
	await _ticks(5)
	_snap("replay_ends")
	check(game.phase == Match1v1.Phase.COUNTDOWN and game.goal_replay == null, "the replay ends at the next kickoff")
	game.goal_replays = false

	print("battery:")
	await _go_live(game)
	var battered_log := []
	game.battered.connect(func(attacker: FishController, victim: FishController) -> void:
		battered_count += 1
		battered_log.append([attacker == game.player, victim == game.player]))
	await _ram(game.bot_fish, fish)
	_snap("battery")
	check(fish.battered and not fish.visible and battered_log == [[false, true]], "a fast ram batters the player (%s)" % str(battered_log))
	await _ticks(roundi((Match1v1.RESPAWN_TIME - 0.5) * 120.0))
	while fish.battered:
		await get_tree().physics_frame
	await _ticks(2)
	_snap("respawned")
	check(not fish.battered and fish.visible and absf(fish.boost_amount - Match1v1.SPAWN_BOOST) < 0.5, "back after the respawn with 33 boost")
	await _ram(fish, game.bot_fish)
	_snap("player_battery")
	check(game.bot_fish.battered and battered_log.size() == 2, "the player batters the bot")
	await _ticks(roundi((Match1v1.RESPAWN_TIME + 0.3) * 120.0))

	print("goal for the bot, time up, overtime:")
	await _shoot(ball, game.bot_fish, 1.0)
	await _ticks(2)
	_snap("bot_goal")
	check(aquarium.scores == [1, 1], "the bot scores 1-1")
	await _ticks(roundi((ball.settings.goal_reset_delay + 0.3) * 120.0))
	_snap("after_goal_kickoff")
	await _go_live(game)
	game.clock_left = 0.02
	await _ticks(5)
	_snap("overtime_start")
	check(game.overtime and game.phase == Match1v1.Phase.COUNTDOWN, "tied at 0:00: overtime from a kickoff")
	await _go_live(game)
	await _ticks(60)
	_snap("overtime_live")
	var results := []
	game.match_over.connect(func(w: int) -> void: results.append(w))
	await _shoot(ball, fish, -1.0)
	await _ticks(roundi((ball.settings.goal_reset_delay + 0.3) * 120.0))
	_snap("over")
	check(results == [0] and game.phase == Match1v1.Phase.OVER and game.winner == 0, "the overtime goal wins it for the player")
	check(is_instance_valid(game.bubble_column), "the bubble column rises")
	await _ticks(60)
	Input.action_press("show_scoreboard")
	await _ticks(3)
	_snap("scoreboard_held")
	Input.action_release("show_scoreboard")
	main.reset_play()
	await _ticks(3)
	_snap("new_match")
	check(game.phase == Match1v1.Phase.COUNTDOWN and aquarium.scores == [0, 0] and game.clock_left == Match1v1.MATCH_TIME and not game.overtime, "R: a new match")

	print("leaving:")
	main.set_mode(main.FREE_PLAY)
	await _ticks(10)
	_snap("left")
	check(_game() == null and not is_instance_valid(game), "the match and bot are gone")
	check(fish.team == -1 and fish.team_color.a == 0.0 and not fish.controls_locked and fish.visible and aquarium.auto_respawn, "player and arena handed back")
	check(camera.ball == aquarium.ball, "the camera keeps the arena's ball (Free Play)")

	_finish_baseline()
	print("one_v_one_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _go_live(game: Match1v1) -> void:
	for i in 1200:
		if game.phase == Match1v1.Phase.LIVE:
			return
		await get_tree().physics_frame


## `attacker` drives at `victim` from 35 m, boosting, down the tank's middle (the
## ball is popped and the bot and arena stood down by the caller's setup); returns
## once the ram has landed or 5 s have passed.
func _ram(attacker: FishController, victim: FishController) -> void:
	var game := _game()
	var arena := game.arena
	arena.ball.pop()
	var height := arena.spawn_transform().origin.y
	victim.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0.0, height, -10.0)))
	attacker.set_spawn(Transform3D(Basis.looking_at(Vector3(0, 0, 1)), Vector3(0.0, height, -45.0)))
	await _ticks(2)
	var drive := FishInput.new()
	drive.forward = 1.0
	drive.boost = true
	var before_controls := attacker.controls
	attacker.controls = drive
	attacker.boost_amount = 100.0
	var before := battered_count
	var waited := 0.0
	while battered_count == before and waited < 5.0:
		await get_tree().physics_frame
		waited += TICK
	attacker.controls = before_controls


## Puts `shooter` behind the ball near a goal (`end`: -1 Orange's at -Z, +1 Blue's)
## and rolls the ball in off it, waiting for the goal.
func _shoot(ball: Ball, shooter: FishController, end: float) -> void:
	var game := _game()
	var height: float = ball.settings.radius + 0.05
	var spot := Vector3(0.0, height, end * 44.0)
	shooter.set_spawn(Transform3D(Basis.looking_at(Vector3(0.0, 0.0, end)), spot - Vector3(0.0, 0.0, end * 3.0) + Vector3(0.0, 0.3, 0.0)))
	var other := game.bot_fish if shooter == game.player else game.player
	other.set_spawn(Transform3D(Basis.IDENTITY, Vector3(30.0, height + 0.3, 0.0)))
	ball.respawn(spot)
	await _ticks(2)
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


## One row of the baseline: match state, HUD slots, camera claim and fish at a named moment.
func _snap(label: String) -> void:
	var game := _game()
	var row := {"at": label, "match": game != null}
	var bug: Node = hud._scorebug
	row["hud"] = {
		"scorebug": bug.visible, "teams": bug.team_names.duplicate() if bug.visible else [],
		"scores": bug.scores.duplicate(), "players": bug.players.duplicate(), "clock": bug.clock,
		"caption": bug.caption, "countdown": hud._countdown.text, "splash": hud._splash.visible,
		"splash_title": hud._splash.title, "banner": hud._banner.text, "board": hud._board.shown,
		"board_title": hud._board.title, "overlay": hud._replay_overlay.visible,
		"lists": [hud._lists[0].visible, hud._lists[1].visible], "hint": hud._hint.text,
		"course": hud._course.text, "hint_visible": hud._hint.visible, "feed_visible": hud._feed.visible,
	}
	row["camera"] = {"ball_set": camera.ball != null, "ball_cam": camera.ball_cam}
	row["fish"] = {"team": fish.team, "locked": fish.controls_locked, "visible": fish.visible, "battered": fish.battered,
			"colored": fish.team_color.a > 0.0, "swim": fish.swim_style, "boost_enabled": fish.boost_enabled}
	if game != null:
		var arena := game.arena
		row["game"] = {
			"phase": Match1v1.Phase.keys()[game.phase], "scores": arena.scores.duplicate(),
			"clock": snappedf(game.clock_left, 0.01), "overtime": game.overtime,
			"overtime_elapsed": snappedf(game.overtime_elapsed, 0.01), "winner": game.winner,
			"replay": game.goal_replay != null, "bubble": game.bubble_column != null,
			"stats": game.stats.map(func(line: Dictionary) -> Array:
				return MatchStats.COLUMNS.map(func(column: String) -> int: return line[column])),
			"battered": [game.player.battered, game.bot_fish.battered], "events": events.size(),
			"bot_team": game.bot_fish.team, "bot_colored": game.bot_fish.team_color.a > 0.0,
		}
	snaps.append(row)


## A baseline row matches when its floats are within one physics tick.
func _same(a: Variant, b: Variant) -> bool:
	if a == b:
		return true
	if a is Dictionary and b is Dictionary and (a as Dictionary).size() == (b as Dictionary).size():
		for key: Variant in (a as Dictionary):
			if not (b as Dictionary).has(key) or not _same(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array and (a as Array).size() == (b as Array).size():
		for i in (a as Array).size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a is float and b is float and absf(a - b) <= 0.011


func _finish_baseline() -> void:
	var log: Array[Dictionary] = []
	for e: Dictionary in events:
		log.append({"type": e.type, "player": e.player, "victim": e.get("victim", -1)})
	var now := {"snaps": snaps, "events": log}
	var path := ProjectSettings.globalize_path(BASELINE)
	if record:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var out := FileAccess.open(path, FileAccess.WRITE)
		out.store_string(JSON.stringify(now, "\t", true))
		out.close()
		print("  baseline recorded: %s (%d snapshots, %d events)" % [path, snaps.size(), log.size()])
		return
	if not FileAccess.file_exists(BASELINE):
		check(false, "no baseline at %s (run with --record)" % BASELINE)
		return
	var want: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	var got: Variant = JSON.parse_string(JSON.stringify(now))
	var bad := 0
	for i in maxi(want.snaps.size(), got.snaps.size()):
		var a: Variant = want.snaps[i] if i < want.snaps.size() else null
		var b: Variant = got.snaps[i] if i < got.snaps.size() else null
		if not _same(a, b):
			bad += 1
			print("    baseline differs: want %s\n                      got  %s" % [a, b])
	if not _same(want.events, got.events):
		bad += 1
		print("    event log differs: want %s got %s" % [want.events, got.events])
	check(bad == 0, "matches one_v_one_baseline.json (%d snapshots, %d events)" % [snaps.size(), log.size()])
