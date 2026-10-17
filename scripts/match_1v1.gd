class_name Match1v1
extends Node
## A 1v1 in the aquarium: the player (Blue, defending +Z) against a FishBot
## (Orange). Runs Rocket League's match flow: everyone lined up on one of RL's
## kickoff spots with 33 boost, frozen through a 3-2-1 countdown; after a goal
## (and its explosion, see AquariumArena) a few seconds' celebration, then the
## next kickoff. A supersonic fish that rams an opponent with its front
## batters it: it explodes and respawns at the back of its own half 3 s later.
## A 5-minute clock runs while the ball's live; tied at 0:00 goes to overtime,
## where the next goal wins. After each goal, once the explosion's settled, a
## replay of it (GoalReplay, from a GoalRecorder) plays unless goal_replays is
## off; it can be skipped. Goals, assists, shots, saves and battered fish are called
## out as they happen (stat_event; see MatchStats), and each fish's scoreboard
## line (stats) adds them up with its touches, clears and centres, RL's points
## and all, for the HUD's scoreboard; each team's possession, boost used and
## time with the ball in the other half go in team_stats.
##
## At the end, instead of RL's podium, a bubble column (BubbleColumn) rises at
## centre field in the winners' colour with both fish in it, and everyone's free
## to swim about, on unlimited boost, until the next match (or Start / R).
##
## Lives under the AquariumArena (setup() before adding it). end() hands the
## arena and the player's fish back as they were, for Free Play.

## A kickoff or respawn has moved `fish` (cameras following it can snap).
signal fish_teleported(fish: FishController)
signal battered(attacker: FishController, victim: FishController)
signal goal_replay_started(replay: GoalReplay)
signal goal_replay_ended
## The clock ran out with a winner, or someone scored in overtime.
signal match_over(winner: int)
## A goal, assist, shot, save or battery (MatchStats): "type", "player" (0 the
## player, 1 the bot), "team", and for a battery "victim".
signal stat_event(event: Dictionary)

enum Phase { COUNTDOWN, LIVE, GOAL, REPLAY, OVER }

const FISH_SCENE := preload("res://scenes/fish.tscn")
const COUNTDOWN_TIME := 3.0
## Boost at a kickoff and after a respawn (RL: 33.3).
const SPAWN_BOOST := 33.3
const RESPAWN_TIME := 3.0
## RL's game clock (s).
const MATCH_TIME := 300.0
## The goal replay starts this long before the goal and runs on this long after it.
const REPLAY_BEFORE := 5.0
const REPLAY_AFTER := 1.2
## How long the result shows before a new match kicks off (Start / R sooner).
const OVER_TIME := 20.0
## The bot's name, picked at random each match.
const BOT_NAMES := ["Barracuda", "Snapper", "Grouper", "Kipper", "Wahoo", "Marlin", "Halibut", "Mackerel", "Pike", "Tarpon"]
## How long "GO!" shows after the countdown.
const GO_TIME := 0.8
const BOT_CHARACTER := FishCharacter.Family.OCTANE
## RL's kickoff spots for the team defending +Z (x, z in m) and whether the
## fish there faces the ball (the diagonals) or straight down the tank. The
## other team gets the same spot mirrored through the centre.
const KICKOFF_SPOTS := [
	[Vector2(-20.48, 25.60), true],
	[Vector2(20.48, 25.60), true],
	[Vector2(-2.56, 38.40), false],
	[Vector2(2.56, 38.40), false],
	[Vector2(0.0, 46.08), false],
]
## RL's respawn spots after a demo (ours after a battery), for the team defending +Z (mirrored likewise).
const RESPAWN_SPOTS := [Vector2(-23.04, 46.08), Vector2(-26.88, 46.08), Vector2(23.04, 46.08), Vector2(26.88, 46.08)]

var arena: AquariumArena
var player: FishController
var bot_fish: FishController
var bot: FishBot
var phase := Phase.COUNTDOWN
var countdown_left := 0.0
var go_time_left := 0.0
var goal_time_left := 0.0
## Seconds left on the clock; in overtime, how long it's run.
var clock_left := MATCH_TIME
var overtime := false
var overtime_elapsed := 0.0
## Replays each goal before the next kickoff.
var goal_replays := true
## The goal replay playing, if any.
var goal_replay: GoalReplay
## Once the match is over: 0 Blue, 1 Orange.
var winner := -1
## Each fish's scoreboard line this match (MatchStats.new_line): the player's, then the bot's.
var stats: Array[Dictionary] = []
## Each team's totals this match, Blue's then Orange's: "possession" (s the
## ball was theirs, by the last touch), "boost" (used) and "territory" (s the
## ball spent in the other team's half). Live play only.
var team_stats := {}
## Once the match is over: seconds until the next one.
var over_left := 0.0
## The end-of-match bubble column, while there is one.
var bubble_column: BubbleColumn
## Each fish's own boost_unlimited, put back after the celebration's free boost.
var _saved_unlimited := {}
## The team that touched the ball last, -1 since the kickoff.
var _possession := -1
var _recorder := GoalRecorder.new()
## Whether each fish has a shot on that the other hasn't touched since: a goal
## without one counts as a shot too (as in RL, shots never fall short of goals).
var _shot_on := [false, false]
## The recorder's time when the last goal went in.
var _goal_record_time := 0.0

## Battered fish -> seconds until it respawns.
var _respawn_left := {}
## Touches waiting a tick to see where they sent the ball: [fish, ball position
## and velocity before].
var _pending_touches: Array = []
var _ball_before := [Vector3.ZERO, Vector3.ZERO]


func setup(match_arena: AquariumArena, player_fish: FishController) -> void:
	arena = match_arena
	player = player_fish


func _ready() -> void:
	arena.auto_respawn = false
	arena.scores = [0, 0]
	arena.goal_scored.connect(_on_goal_scored)
	arena.ball.touched.connect(_on_touched)

	bot_fish = FISH_SCENE.instantiate()
	bot_fish.name = "BotFish"
	bot_fish.character = BOT_CHARACTER
	bot_fish.display_name = BOT_NAMES.pick_random()
	bot_fish.team = 1
	add_child(bot_fish)
	bot = FishBot.new()
	bot.name = "Bot"
	bot.fish = bot_fish
	bot.ball = arena.ball
	bot.arena = arena
	bot.team = 1
	add_child(bot)

	arena.ball.add_player(player)
	arena.ball.add_player(bot_fish)
	player.team_color = AquariumArena.TEAM_COLORS[0]
	bot_fish.team_color = AquariumArena.TEAM_COLORS[1]
	player.team = 0
	_recorder.setup(arena.ball, [player, bot_fish] as Array[FishController])
	_reset_stats()
	kickoff()


## Hands everything back for Free Play. Call before freeing the match.
func end() -> void:
	_stop_replay()
	_end_celebration()
	if is_instance_valid(arena):
		if arena.goal_scored.is_connected(_on_goal_scored):
			arena.goal_scored.disconnect(_on_goal_scored)
		if is_instance_valid(arena.ball) and arena.ball.touched.is_connected(_on_touched):
			arena.ball.touched.disconnect(_on_touched)
		arena.auto_respawn = true
		if is_instance_valid(arena.ball):
			arena.ball.remove_player(bot_fish)
	player.team_color = Color.TRANSPARENT
	player.team = -1
	player.controls_locked = false
	player.visible = not player.battered  # a goal replay hides it
	player.freeze = player.battered
	player.spawn_boost = 100.0
	if player.battered:
		player.revive(arena.spawn_transform() if is_instance_valid(arena) else player.global_transform)


## Everyone to a kickoff spot (a random one of RL's, mirrored for the other
## team), ball to the centre, and the countdown starts. Once the match is
## over, a new match.
func kickoff() -> void:
	_stop_replay()
	if phase == Phase.OVER:
		arena.scores = [0, 0]
		clock_left = MATCH_TIME
		overtime = false
		overtime_elapsed = 0.0
		winner = -1
		_reset_stats()
	_recorder.clear()
	_pending_touches.clear()
	_shot_on = [false, false]
	_possession = -1
	_end_celebration()
	phase = Phase.COUNTDOWN
	countdown_left = COUNTDOWN_TIME
	go_time_left = 0.0
	_respawn_left.clear()
	arena.reset_kickoff()
	copy_tuning(player, bot_fish)  # tuning changes since the last kickoff apply to the bot too
	var spot: Array = KICKOFF_SPOTS.pick_random()
	for team in 2:
		var fish := _fish_of(team)
		fish.spawn_boost = SPAWN_BOOST
		fish.controls_locked = true
		fish.revive(_kickoff_transform(spot[0], spot[1], team))
	_announce_teleport([player, bot_fish])


func _physics_process(delta: float) -> void:
	match phase:
		Phase.COUNTDOWN:
			countdown_left -= delta
			if countdown_left <= 0.0:
				phase = Phase.LIVE
				go_time_left = GO_TIME
				player.controls_locked = false
				bot_fish.controls_locked = false
		Phase.LIVE:
			if overtime:
				overtime_elapsed += delta
			else:
				clock_left = maxf(clock_left - delta, 0.0)
				if clock_left <= 0.0:
					_time_up()
					return
			_add_team_stats(delta)
		Phase.GOAL:
			goal_time_left -= delta
			if goal_time_left <= 0.0:
				if not (goal_replays and _start_replay()):
					_after_goal()
				return
		Phase.REPLAY:
			return  # everything waits for the replay
		Phase.OVER:
			over_left -= delta
			if over_left <= 0.0:
				kickoff()
				return
	if phase == Phase.LIVE or phase == Phase.GOAL:
		_recorder.record(delta)
	_judge_touches()
	go_time_left = maxf(go_time_left - delta, 0.0)

	for fish: FishController in _respawn_left.keys():
		_respawn_left[fish] -= delta
		if _respawn_left[fish] <= 0.0:
			_respawn_left.erase(fish)
			fish.spawn_boost = SPAWN_BOOST
			fish.revive(_respawn_transform(_team_of(fish)))
			_announce_teleport([fish])

	if phase != Phase.COUNTDOWN and phase != Phase.OVER:
		_check_battery(player, bot_fish)
		_check_battery(bot_fish, player)


func _on_goal_scored(team: int) -> void:
	phase = Phase.GOAL
	goal_time_left = arena.ball.settings.goal_reset_delay
	_goal_record_time = _recorder.time
	_pending_touches.clear()  # the ball's popped: nothing to judge them by
	var credit := arena.last_goal
	if credit.get("scorer") is FishController:
		if not _shot_on[_team_of(credit.scorer)]:
			_announce(MatchStats.SHOT, credit.scorer)
		_announce(MatchStats.GOAL, credit.scorer, {"team": team})
	if credit.get("assister") is FishController:
		_announce(MatchStats.ASSIST, credit.assister, {"team": team})


func _on_touched(by: Node3D, _hit_speed: float) -> void:
	if (by == player or by == bot_fish) and phase == Phase.LIVE:
		_pending_touches.append([by, _ball_before[0], _ball_before[1]])
		_shot_on[1 - _team_of(by)] = false
		_possession = _team_of(by)
		MatchStats.tally(stats[_team_of(by)], MatchStats.TOUCH)


## Shots and saves (and the clears and centres they score points for): each
## touch from last tick, by where it has sent the ball. Then notes the ball's
## motion before this tick's touches.
func _judge_touches() -> void:
	var ball := arena.ball
	if not _pending_touches.is_empty() and not ball.popped:
		var model := MatchStats.ball_model(ball.settings)
		for touch: Array in _pending_touches:
			var fish: FishController = touch[0]
			var team := _team_of(fish)
			var kind := MatchStats.classify_touch(team, touch[1], touch[2], ball.global_position, ball.linear_velocity, model)
			if kind:
				_shot_on[team] = _shot_on[team] or kind == MatchStats.SHOT
				_announce(kind, fish)
			else:
				kind = MatchStats.classify_play(team, touch[1], ball.linear_velocity)
				if kind:
					MatchStats.tally(stats[team], kind)  # points only: nothing to call out
	_pending_touches.clear()
	_ball_before = [ball.global_position, ball.linear_velocity]


## Tells the HUD (stat_event) and the recorder, for replays.
func _announce(type: String, fish: FishController, extra := {}) -> void:
	var event := {"type": type, "player": 0 if fish == player else 1, "team": _team_of(fish)}
	event.merge(extra, true)
	MatchStats.tally(stats[event.player], type)
	_recorder.log_event(event)
	stat_event.emit(event)


func _reset_stats() -> void:
	stats.assign([MatchStats.new_line(), MatchStats.new_line()])
	team_stats = {"possession": [0.0, 0.0], "boost": [0.0, 0.0], "territory": [0.0, 0.0]}
	_shot_on = [false, false]


func _add_team_stats(delta: float) -> void:
	if _possession >= 0:
		team_stats.possession[_possession] += delta
	for team in 2:
		var fish := _fish_of(team)
		if fish.is_boosting:
			team_stats.boost[team] += fish.boost_drain * delta
	if not arena.ball.popped:
		# Blue defends +Z: the ball beyond the centre line there is Orange's ground.
		team_stats.territory[1 if arena.ball.global_position.z > 0.0 else 0] += delta


## After a goal (and its replay): the next kickoff, or in overtime the end.
func _after_goal() -> void:
	if overtime:
		_finish_match()
	else:
		kickoff()


## The clock hit 0:00: a winner, or overtime from a fresh kickoff.
func _time_up() -> void:
	if arena.scores[0] != arena.scores[1]:
		_finish_match()
	else:
		overtime = true
		kickoff()


func _finish_match() -> void:
	_stop_replay()
	phase = Phase.OVER
	winner = 0 if arena.scores[0] > arena.scores[1] else 1
	over_left = OVER_TIME
	arena.ball.pop()
	_respawn_left.clear()
	_celebrate()
	match_over.emit(winner)


## The end of the match: a bubble column at centre field in the winners'
## colour, both fish at the foot of it (back from a battery or a replay too),
## free to swim on unlimited boost (off a surface, boost is what really moves a
## fish, as in RL), the bot looping about in it.
func _celebrate() -> void:
	_end_celebration()
	bubble_column = BubbleColumn.new()
	bubble_column.name = "BubbleColumn"
	bubble_column.color = AquariumArena.TEAM_COLORS[winner]
	bubble_column.height = AquariumArena.SIZE.y - 3.5
	arena.add_child(bubble_column)
	var y := arena.spawn_transform().origin.y
	for team in 2:
		var fish := _fish_of(team)
		var side := -1.0 if team == 0 else 1.0
		var at := Vector3(side * 2.5, y, 0.0)
		fish.controls_locked = false
		_saved_unlimited[fish] = fish.boost_unlimited
		fish.boost_unlimited = true
		fish.revive(Transform3D(Basis.looking_at(Vector3(-side, 0.0, 0.0), Vector3.UP), at))
	bot.celebrating = true
	_announce_teleport([player, bot_fish])


func _end_celebration() -> void:
	if is_instance_valid(bubble_column):
		bubble_column.queue_free()
	bubble_column = null
	if bot:
		bot.celebrating = false
	for fish: FishController in _saved_unlimited:
		if is_instance_valid(fish):
			fish.boost_unlimited = _saved_unlimited[fish]
	_saved_unlimited.clear()


## Starts the replay of the goal just scored. False when there's too little
## recorded to show.
func _start_replay() -> bool:
	var from := maxf(_recorder.start_time(), _goal_record_time - REPLAY_BEFORE)
	var clip := _recorder.clip(from, _goal_record_time + REPLAY_AFTER)
	if clip.times.size() < 30:
		return false
	var credit: Dictionary = arena.last_goal
	var team: int = credit.get("team", 0)
	var net: Goal = null
	for goal in arena.goals:
		if goal.team != team:
			net = goal
	goal_replay = GoalReplay.new()
	goal_replay.name = "GoalReplay"
	goal_replay.setup(clip, _goal_record_time - from, [player, bot_fish].find(credit.get("scorer")), net,
			AquariumArena.TEAM_COLORS[team], arena.ball.settings.radius)
	goal_replay.finished.connect(func() -> void:
		_stop_replay()
		_after_goal())
	phase = Phase.REPLAY
	# The live fish wait out of sight; the next kickoff (revive) brings them back.
	for fish: FishController in [player, bot_fish]:
		fish.controls_locked = true
		fish.visible = false
		fish.freeze = true
	add_child(goal_replay)
	goal_replay_started.emit(goal_replay)
	return true


func _stop_replay() -> void:
	if goal_replay == null:
		return
	goal_replay.restore_camera()
	goal_replay.queue_free()
	goal_replay = null
	goal_replay_ended.emit()


## `attacker` batters `victim` if it's supersonic and its front is touching it.
func _check_battery(attacker: FishController, victim: FishController) -> void:
	if not Battery.hits(attacker, victim):
		return
	Explosion.spawn(arena, victim.global_position, AquariumArena.TEAM_COLORS[_team_of(victim)], 6.0)
	victim.batter()
	_respawn_left[victim] = RESPAWN_TIME
	_announce(MatchStats.BATTERY, attacker, {"victim": 0 if victim == player else 1})
	battered.emit(attacker, victim)


## Fish the cameras should snap to once they've actually moved (resets land on
## the next physics step).
func _announce_teleport(moved: Array) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for fish: FishController in moved:
		if is_instance_valid(fish):
			fish_teleported.emit(fish)


func _fish_of(team: int) -> FishController:
	return player if team == 0 else bot_fish


func _team_of(fish: FishController) -> int:
	return 0 if fish == player else 1


## A spot given for the team defending +Z, for `team` (mirrored through the
## centre for the other), at the arena's spawn height.
func _spot(spot: Vector2, team: int) -> Vector3:
	var flip := 1.0 if team == 0 else -1.0
	return Vector3(spot.x * flip, arena.spawn_transform().origin.y, spot.y * flip)


func _kickoff_transform(spot: Vector2, faces_ball: bool, team: int) -> Transform3D:
	var at := _spot(spot, team)
	var facing := Vector3(-at.x, 0.0, -at.z) if faces_ball else Vector3(0.0, 0.0, -signf(at.z))
	return Transform3D(Basis.looking_at(facing.normalized(), Vector3.UP), at)


func _respawn_transform(team: int) -> Transform3D:
	var at := _spot(RESPAWN_SPOTS.pick_random(), team)
	return Transform3D(Basis.looking_at(Vector3(0.0, 0.0, -signf(at.z)), Vector3.UP), at)


## Copies `from`'s tunable settings (everything exported but the character and
## the hitbox view) onto `to`, so a bot plays by the same physics as the player.
static func copy_tuning(from: FishController, to: FishController) -> void:
	for property in from.get_property_list():
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (property.usage & PROPERTY_USAGE_EDITOR):
			continue
		if property.name in ["character", "show_hitbox"]:
			continue
		to.set(property.name, from.get(property.name))
