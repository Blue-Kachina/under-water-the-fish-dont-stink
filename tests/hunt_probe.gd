extends Node
## Hunt mode: its card with the fish sitting out on Nature's tuning; Play
## starts a match against a hostile opponent, both locked through the countdown
## with the clock stopped; a fast ram by either fish scores (a slow bump
## doesn't), explodes the victim ("Battered"), replays it arcade style (the
## ghosts showing the bow wave and the grown stride tail, a hit-stop at the
## impact) and kicks off again with both back at their spots and their flow
## gone; head-on, the faster fish scores and the same speed batters both for
## nothing (a Fish Fry, replayed too); at 0:00 goals decide, then points,
## then overtime's next battery; the arena's edge pushes back and darkens
## the water; leaving puts everything back.
##   Godot_console.exe --headless --path . res://tests/hunt_probe.tscn

var main: Node
var fish: FishController
var camera: Node
var failures := 0
var events: Array[Dictionary] = []


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	print("card:")
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	var max_speed_before := fish.max_speed
	main.set_mode(main.HUNT)
	await _ticks(3)
	check(main.current_environment == "Ocean", "Hunt plays in the Ocean")
	check(main._match_card != null and main.hunt_match == null and not fish.visible, "waits on its card, fish sitting out")
	check(fish.swim_style == FishController.SwimStyle.EXTRA_SWISHY and not fish.boost_enabled, "Nature's tuning: Extra Swishy, no boost")
	check(main.HUNT in main.MODES, "Hunt is in the mode list")

	print("kickoff:")
	main._match_card.play_requested.emit()
	await _ticks(5)
	var hunt: HuntMatch = main.hunt_match
	check(hunt != null and main._match_card == null and fish.visible, "Play starts the match, fish back")
	hunt.stat_event.connect(func(event: Dictionary) -> void: events.append(event))
	# The bot is hunter_bot_probe's business: here it would only score in between checks.
	hunt.bot.process_mode = Node.PROCESS_MODE_DISABLED
	hunt.bot.input.clear()
	var opponent := hunt.opponent
	check(is_instance_valid(opponent) and opponent.visible and opponent.team == 1 and fish.team == 0, "an opponent on team 1, the player on team 0")
	check(opponent.swim_style == FishController.SwimStyle.EXTRA_SWISHY and not opponent.boost_enabled and opponent.bow_wave,
			"the opponent swims on the player's tuning")
	check(camera.ball == opponent and camera.ball_cam, "ball cam locked on the opponent")
	check(hunt.phase == HuntMatch.Phase.COUNTDOWN and fish.controls_locked and opponent.controls_locked, "both locked for the countdown")
	var gap := fish.global_position.distance_to(opponent.global_position)
	check(absf(gap - 2.0 * HuntMatch.KICKOFF_DISTANCE) < 12.0, "facing off across the centre (%.1f m apart)" % gap)
	check(main._reset_label() == "Restart match", "reset restarts the match")
	await _ticks(roundi((HuntMatch.COUNTDOWN_TIME + 0.1) * 120.0))
	check(hunt.phase == HuntMatch.Phase.LIVE and not fish.controls_locked and not opponent.controls_locked, "GO: both free")
	check(hunt.clock_left > HuntMatch.MATCH_TIME - 0.2, "the clock stood still through the countdown (%.2f)" % hunt.clock_left)

	print("slow bump:")
	await _ram(fish, opponent, 5.0)
	check(hunt.scores == [0, 0] and not opponent.battered, "a slow bump doesn't score")

	print("player battery:")
	hunt.battery_replays = true
	events.clear()
	await _ram(fish, opponent, hunt.batter_speed() + 6.0)
	check(hunt.scores == [1, 0] and opponent.battered, "a fast ram scores 1-0 and batters the opponent")
	check(hunt.phase == HuntMatch.Phase.BATTERED, "a pause for the explosion")
	check(hunt.style.points[0] >= StylePoints.POINTS[StylePoints.BATTERY], "+%d points for it (%d)" % [StylePoints.POINTS[StylePoints.BATTERY], hunt.style.points[0]])
	check(events.any(func(e: Dictionary) -> bool: return e.type == StylePoints.BATTERY and e.player == 0 and e.victim == 1), "called out as a battery")
	check(StylePoints.TITLES[StylePoints.BATTERY] == "BATTERED" and "BATTERIES" in load("res://scripts/hud.gd").HUNT_HEADINGS,
			"called BATTERED, counted as BATTERIES on the scoreboard")
	fish.swishy.flow = 1.5  # to see the kickoff clear it
	await _ticks(roundi((HuntMatch.BATTERY_PAUSE + 0.2) * 120.0))
	check(hunt.phase == HuntMatch.Phase.REPLAY and is_instance_valid(hunt.battery_replay), "then a replay of it")
	if is_instance_valid(hunt.battery_replay):
		var replay := hunt.battery_replay
		check(replay.victim == 1 and replay.scorer == 0 and not replay.in_arena and replay.arcade and not replay.fish_fry,
				"replaying the player into the opponent, in open water, arcade style")
		var track: ReplayData.Track = replay.data.cars[0]
		check(not track.fx.is_empty() and track.fx.size() == track.flags.size(), "the clip has the fish's looks every tick (%d)" % track.fx.size())
		var stats := await _watch_replay(hunt)
		check(stats.shot, "the replay's camera is shooting")
		check(stats.bow, "the attacker's ghost pushes its bow wave")
		check(stats.tail > 1.3, "and its tail is grown with flow (x%.2f)" % stats.tail)
		check(stats.froze, "a hit-stop at the impact")
		check(stats.vignette, "the arcade vignette shows")
	await _ticks(5)
	check(hunt.phase == HuntMatch.Phase.COUNTDOWN and hunt.battery_replay == null, "the replay ends at the kickoff")
	check(not opponent.battered and opponent.visible and fish.visible, "both back")
	check(fish.swishy.flow == 0.0 and fish.linear_velocity.length() < 0.5, "the player's flow and speed are gone")
	var spots_ok := false
	for layout: Vector2 in HuntMatch.KICKOFF_LAYOUTS:
		if fish.global_position.distance_to(hunt.kickoff_transform(layout, 0).origin) < 0.5 \
				and opponent.global_position.distance_to(hunt.kickoff_transform(layout, 1).origin) < 0.5:
			spots_ok = true
	check(spots_ok, "both on a kickoff layout's spots")

	print("opponent battery:")
	hunt.battery_replays = false
	await _go_live(hunt)
	await _ram(opponent, fish, hunt.batter_speed() + 6.0)
	check(hunt.scores == [1, 1] and fish.battered, "the opponent ramming the player scores 1-1")
	await _ticks(roundi((HuntMatch.BATTERY_PAUSE + 0.2) * 120.0))
	check(hunt.phase == HuntMatch.Phase.COUNTDOWN and not fish.battered, "replays off: straight to the kickoff")

	print("head-on:")
	await _go_live(hunt)
	await _joust(hunt, hunt.batter_speed() + 8.0, hunt.batter_speed() + 3.0)
	check(hunt.scores == [2, 1] and opponent.battered and not fish.battered, "the faster fish scores")
	await _ticks(roundi((HuntMatch.BATTERY_PAUSE + 0.2) * 120.0))
	await _go_live(hunt)
	hunt.battery_replays = true
	await _joust(hunt, hunt.batter_speed() + 5.0, hunt.batter_speed() + 5.0)
	check(hunt.scores == [2, 1] and opponent.battered and fish.battered and hunt.last_battery.fish_fry,
			"the same speed: a Fish Fry, both battered, nobody scores")
	await _ticks(roundi((HuntMatch.BATTERY_PAUSE + 0.2) * 120.0))
	check(hunt.phase == HuntMatch.Phase.REPLAY and is_instance_valid(hunt.battery_replay) and hunt.battery_replay.fish_fry,
			"the Fish Fry is replayed")
	if is_instance_valid(hunt.battery_replay):
		hunt.battery_replay.skip()
	await _ticks(5)
	hunt.battery_replays = false
	check(hunt.phase == HuntMatch.Phase.COUNTDOWN and not fish.battered and not opponent.battered, "and back to a kickoff")

	print("time up:")
	await _go_live(hunt)
	hunt.scores = [1, 1]
	hunt.style.points = [60, 30]
	hunt.clock_left = 0.02
	await _ticks(5)
	check(hunt.phase == HuntMatch.Phase.OVER and hunt.winner == 0 and hunt.won_on_points(), "level on goals: the most points wins")
	check(not fish.controls_locked and fish.visible, "the player swims free at the end")
	main.reset_play()
	await _ticks(3)
	check(hunt.phase == HuntMatch.Phase.COUNTDOWN and hunt.scores == [0, 0] and hunt.style.points == [0, 0]
			and hunt.clock_left == HuntMatch.MATCH_TIME, "R starts a new match")
	await _go_live(hunt)
	hunt.scores = [1, 1]
	hunt.style.points = [40, 40]
	hunt.clock_left = 0.02
	await _ticks(5)
	check(hunt.overtime and hunt.phase == HuntMatch.Phase.COUNTDOWN, "level on both: overtime from a kickoff")
	await _go_live(hunt)
	await _ticks(60)
	check(hunt.overtime_elapsed > 0.3 and hunt.clock_left == 0.0, "overtime counts up (%.2f s)" % hunt.overtime_elapsed)
	await _ram(opponent, fish, hunt.batter_speed() + 6.0)
	await _ticks(roundi((HuntMatch.BATTERY_PAUSE + 0.2) * 120.0))
	check(hunt.phase == HuntMatch.Phase.OVER and hunt.winner == 1 and not hunt.won_on_points(), "overtime's battery wins it")

	print("arena edge:")
	main.reset_play()
	await _go_live(hunt)
	var ocean: Ocean = main._environment
	check(ocean.boundary_radius == HuntMatch.ARENA_RADIUS, "the ocean marks the edge")
	var base_density: float = ocean._fog_base[1]
	var out := Vector3(0.0, 0.0, HuntMatch.ARENA_RADIUS + 25.0)
	fish.global_transform = Transform3D(Basis.IDENTITY, hunt.center + out)
	fish.linear_velocity = Vector3.ZERO
	camera.snap()
	await _ticks(5)
	var env: Environment = main.get_node("WorldEnvironment").environment
	check(env.fog_density > base_density * 1.5, "out there the water's thicker (fog %.4f, was %.4f)" % [env.fog_density, base_density])
	var from := fish.global_position.distance_to(hunt.center)
	await _ticks(240)
	var now := fish.global_position.distance_to(hunt.center)
	check(now < from - 3.0, "and it's pushed back in (%.1f m -> %.1f m)" % [from, now])

	print("leaving:")
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	check(main.hunt_match == null and camera.ball == null, "the match is over")
	check(ocean.boundary_radius == 0.0 and absf(env.fog_density - base_density) < 0.0001, "the edge and its fog are gone")
	check(fish.team == -1 and fish.team_color == Color.TRANSPARENT and not fish.controls_locked, "the player's fish is handed back")
	check(fish.swim_style == FishController.SwimStyle.ORIGINAL and fish.boost_enabled, "Original strokes and boost back")
	check(is_equal_approx(fish.max_speed, max_speed_before), "the tuning from before is back (max_speed %.1f)" % fish.max_speed)

	print("nature to hunt:")
	main.set_mode(main.NATURE)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	main.set_mode(main.HUNT)
	await _ticks(3)
	check(main.nature_run == null and main._match_card != null and main._match_card.message == main._match_card_text(main.HUNT),
			"straight from a Nature run: the run ends and Hunt's card shows")

	print("hunt_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## Plays the battery replay through, noting what it showed: "shot" (the camera
## framed something), "bow" (the attacker's ghost showed its bow wave),
## "tail" (its tail's largest scale), "froze" (the hit-stop) and "vignette".
func _watch_replay(hunt: HuntMatch) -> Dictionary:
	var stats := {"shot": false, "bow": false, "tail": 0.0, "froze": false, "vignette": false}
	var replay := hunt.battery_replay
	for i in 2400:
		if not is_instance_valid(replay) or hunt.battery_replay != replay:
			break
		var ghost: ReplayCar = replay.cars[replay.scorer]
		stats.shot = stats.shot or replay.shot != ""
		stats.bow = stats.bow or (ghost.visible and ghost._bow_view.visible)
		stats.tail = maxf(stats.tail, ghost._tail.scale.x)
		stats.froze = stats.froze or replay._freeze_left > 0.0
		stats.vignette = stats.vignette or (replay._vignette.is_visible_in_tree() and replay._flow_level > 0.0)
		await get_tree().process_frame
	return stats


## Through a kickoff's countdown to live play.
func _go_live(hunt: HuntMatch) -> void:
	for i in 1200:
		if hunt.phase == HuntMatch.Phase.LIVE:
			return
		await get_tree().physics_frame


## `attacker` 2.5 m behind `victim`, nose on, at `speed` (m/s), for a moment.
## The victim is held still.
func _ram(attacker: FishController, victim: FishController, speed: float) -> void:
	var heading := -victim.global_basis.z
	victim.linear_velocity = Vector3.ZERO
	victim.angular_velocity = Vector3.ZERO
	attacker.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), victim.global_position - heading * 2.5)
	attacker.linear_velocity = heading * speed
	attacker.angular_velocity = Vector3.ZERO
	await _ticks(30)


## Nose to nose, 3 m apart, the player at `player_speed` and the opponent at
## `opponent_speed`, until they meet.
func _joust(hunt: HuntMatch, player_speed: float, opponent_speed: float) -> void:
	var at := hunt.center + Vector3(0.0, 10.0, 0.0)
	fish.global_transform = Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP), at + Vector3.BACK * 1.6)
	hunt.opponent.global_transform = Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), at + Vector3.FORWARD * 1.6)
	fish.angular_velocity = Vector3.ZERO
	hunt.opponent.angular_velocity = Vector3.ZERO
	fish.linear_velocity = Vector3.FORWARD * player_speed
	hunt.opponent.linear_velocity = Vector3.BACK * opponent_speed
	# Their speeds as the controller reads them, from the start.
	fish.speed = player_speed
	hunt.opponent.speed = opponent_speed
	await _ticks(30)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
