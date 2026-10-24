class_name HuntMatch
extends Node
## Hunt: a 1v1 in the Ocean against a hostile fish (a HunterBot) with the
## player's own tuning (Nature's: Extra Swishy strides, no boost, bow wave).
## A battery (Battery) is a goal: ramming
## the other fish nose first at nature_batter_speed or faster scores for the
## rammer. Both fish ramming each other at once: the faster one scores; at the
## same speed both are battered (a "Fish Fry") and nobody scores.
##
## Each play starts from a kickoff: the fish facing each other down parallel
## lanes KICKOFF_DISTANCE out from the centre, a little offset (one of
## KICKOFF_LAYOUTS, mirrored for team 1), frozen through a 3-2-1 countdown, the
## clock stopped. After a battery, a moment for the explosion, then a replay
## of it (GoalReplay, shot arcade style) unless battery_replays is off, then the
## next kickoff. A Fish Fry is replayed too.
##
## A 5-minute clock. At 0:00 the most goals wins; level on goals, the most
## points (StylePoints: close calls, dodges, perfect rhythm, battered fish) wins;
## level on those too, overtime from a kickoff, where the next battery wins.
##
## The arena is a sphere ARENA_RADIUS round the ocean's spawn: past its edge a
## fish is pushed back in, and the Ocean's fog shifts as the camera nears it.
##
## Lives under the Ocean (setup() before adding it). end() hands the player's
## fish back.

## A kickoff has moved `fish` (cameras following it can snap).
signal fish_teleported(fish: FishController)
## `attacker` null: both fish battered each other at the same speed (a Fish Fry).
signal battered(attacker: FishController, victim: FishController)
signal battery_replay_started(replay: GoalReplay)
signal battery_replay_ended
## The clock ran out with a winner, or someone scored in overtime.
signal match_over(winner: int)
## A battery (a goal), close call, dodge or perfect-rhythm streak: "type"
## (StylePoints' types), "player" (0 the player, 1 the opponent), "team",
## "points", "title", and the type's extras ("victim", "streak", "distance").
signal stat_event(event: Dictionary)

enum Phase { COUNTDOWN, LIVE, BATTERED, REPLAY, OVER }

const FISH_SCENE := preload("res://scenes/fish.tscn")
const COUNTDOWN_TIME := 3.0
## How long "GO!" shows after the countdown.
const GO_TIME := 0.8
## The game clock (s).
const MATCH_TIME := 300.0
## After a battery, this long (s) for the explosion before the replay.
const BATTERY_PAUSE := 1.6
## The replay starts this long before the battery and runs on this long after it.
const REPLAY_BEFORE := 4.0
const REPLAY_AFTER := 1.0
## How long the result shows before a new match kicks off (R sooner).
const OVER_TIME := 20.0
## Each fish starts this far from the centre (m), along the Z axis.
const KICKOFF_DISTANCE := 40.0
## Kickoff offsets for team 0 (m, sideways and up), mirrored for team 1, so
## the lanes pass this close.
const KICKOFF_LAYOUTS := [Vector2(6.0, 0.0), Vector2(-6.0, 0.0), Vector2(4.0, 4.0), Vector2(-4.0, -4.0)]
## The arena's radius (m) round the ocean's spawn.
const ARENA_RADIUS := 90.0
## Past the edge: pushed back in this hard per metre out (m/s²), plus against
## any speed outward, up to BOUNDARY_MAX.
const BOUNDARY_STIFFNESS := 2.0
const BOUNDARY_OUTWARD := 2.0
const BOUNDARY_MAX := 30.0
## Rams this close in speed (m/s) count as the same speed.
const SAME_SPEED := 0.05
const BATTERY_EXPLOSION := 6.0
## The opponent's name, picked at random each match.
const OPPONENT_NAMES := ["Moray", "Piranha", "Barracuda", "Muskie", "Gar", "Wolffish", "Lionfish", "Stonefish", "Bluefish", "Snakehead"]

var ocean: Ocean
var player: FishController
var opponent: FishController
var bot: HunterBot
var difficulty := BotDifficulty.basic()
var phase := Phase.COUNTDOWN
var countdown_left := 0.0
var go_time_left := 0.0
## Seconds left on the clock; in overtime, how long it's run.
var clock_left := MATCH_TIME
var overtime := false
var overtime_elapsed := 0.0
## Goals (battered fish): the player's, then the opponent's.
var scores := [0, 0]
## Once the match is over: 0 the player, 1 the opponent.
var winner := -1
## Once the match is over: seconds until the next one.
var over_left := 0.0
## Replays each battery before the next kickoff.
var battery_replays := true
## The battery replay playing, if any.
var battery_replay: GoalReplay
var style := StylePoints.new()
## The last battery: "attacker" and "victim" (both null for a Fish Fry),
## "speed", "team" (-1 for a Fish Fry) and "fish_fry".
var last_battery := {}
## The arena's centre (the ocean's spawn).
var center := Vector3.ZERO

var _battery_left := 0.0
var _recorder := GoalRecorder.new()
## The recorder's time at the last battery.
var _battery_record_time := 0.0


func setup(hunt_ocean: Ocean, player_fish: FishController) -> void:
	ocean = hunt_ocean
	player = player_fish


func _ready() -> void:
	center = ocean.spawn_transform().origin
	opponent = FISH_SCENE.instantiate()
	opponent.name = "Opponent"
	opponent.team = 1
	_pick_opponent()
	add_child(opponent)
	opponent.team_color = AquariumArena.TEAM_COLORS[1]
	player.team = 0
	player.team_color = AquariumArena.TEAM_COLORS[0]

	bot = HunterBot.new()
	bot.name = "HunterBot"
	bot.fish = opponent
	bot.target = player
	bot.difficulty = difficulty
	bot.arena_center = center
	bot.arena_radius = ARENA_RADIUS
	add_child(bot)

	style.setup([player, opponent] as Array[FishController])
	style.awarded.connect(_on_awarded)
	_recorder.setup(null, [player, opponent] as Array[FishController])
	ocean.boundary_center = center
	ocean.boundary_radius = ARENA_RADIUS
	kickoff()


## Hands the player's fish back. Call before freeing the match.
func end() -> void:
	_stop_replay()
	style.detach()
	if is_instance_valid(ocean):
		ocean.boundary_radius = 0.0
	if not is_instance_valid(player):
		return
	player.team_color = Color.TRANSPARENT
	player.team = -1
	player.controls_locked = false
	player.visible = not player.battered  # a replay hides it
	player.freeze = player.battered
	if player.battered:
		player.revive(player.global_transform)


## A new match from the first kickoff.
func restart() -> void:
	phase = Phase.OVER
	kickoff()


## Both fish to a kickoff (a random layout) and the countdown starts. Once the
## match is over, a new match.
func kickoff() -> void:
	_stop_replay()
	if phase == Phase.OVER:
		_new_match()
	phase = Phase.COUNTDOWN
	countdown_left = COUNTDOWN_TIME
	go_time_left = 0.0
	_battery_left = 0.0
	Match1v1.copy_tuning(player, opponent)  # tuning changes since the last kickoff apply to it too
	var layout: Vector2 = KICKOFF_LAYOUTS.pick_random()
	for team in 2:
		var fish := _fish_of(team)
		fish.controls_locked = true
		fish.revive(kickoff_transform(layout, team))
	bot.reset()
	style.live = false
	style.clear_windows()
	_recorder.clear()
	_announce_teleport([player, opponent])


## Where `team` starts a kickoff with `layout` (team 0's offset; mirrored for team 1).
func kickoff_transform(layout: Vector2, team: int) -> Transform3D:
	var flip := 1.0 if team == 0 else -1.0
	var at := center + Vector3(layout.x * flip, layout.y * flip, KICKOFF_DISTANCE * flip)
	return Transform3D(Basis.looking_at(Vector3(0.0, 0.0, -flip), Vector3.UP), at)


## The slowest ram that batters (m/s): the player's tuning, which the opponent shares.
func batter_speed() -> float:
	return player.nature_batter_speed


func _physics_process(delta: float) -> void:
	match phase:
		Phase.COUNTDOWN:
			countdown_left -= delta
			if countdown_left <= 0.0:
				phase = Phase.LIVE
				go_time_left = GO_TIME
				player.controls_locked = false
				opponent.controls_locked = false
		Phase.LIVE:
			if overtime:
				overtime_elapsed += delta
			else:
				clock_left = maxf(clock_left - delta, 0.0)
				if clock_left <= 0.0:
					_time_up()
					return
		Phase.BATTERED:
			_battery_left -= delta
			if _battery_left <= 0.0:
				if not (battery_replays and _start_replay()):
					_after_battery()
				return
		Phase.REPLAY:
			return  # everything waits for the replay
		Phase.OVER:
			over_left -= delta
			if over_left <= 0.0:
				kickoff()
				return
	go_time_left = maxf(go_time_left - delta, 0.0)
	if phase == Phase.LIVE or phase == Phase.BATTERED:
		_recorder.record(delta)
	_keep_in_arena(delta)
	style.batter_speed = batter_speed()
	style.live = phase == Phase.LIVE
	style.update(delta)
	if phase == Phase.LIVE:
		_check_battered_fish()


func _check_battered_fish() -> void:
	var by_player := Battery.hits(player, opponent, batter_speed())
	var by_opponent := Battery.hits(opponent, player, batter_speed())
	if by_player and by_opponent:
		if absf(player.speed - opponent.speed) < SAME_SPEED:
			_fish_fry()
			return
		by_player = player.speed > opponent.speed
		by_opponent = not by_player
	if by_player:
		_batter(player, opponent)
	elif by_opponent:
		_batter(opponent, player)


func _batter(attacker: FishController, victim: FishController) -> void:
	var team := _team_of(attacker)
	scores[team] += 1
	last_battery = {"attacker": attacker, "victim": victim, "speed": attacker.speed, "team": team, "fish_fry": false}
	Explosion.spawn(ocean, victim.global_position, AquariumArena.TEAM_COLORS[1 - team], BATTERY_EXPLOSION)
	victim.batter()
	style.on_battery(team, 1 - team)
	_battery_record_time = _recorder.time
	phase = Phase.BATTERED
	_battery_left = BATTERY_PAUSE
	battered.emit(attacker, victim)


## Both at once at the same speed: a Fish Fry. Both explode, nobody scores.
func _fish_fry() -> void:
	last_battery = {"attacker": null, "victim": null, "speed": player.speed, "team": -1, "fish_fry": true}
	for team in 2:
		var fish := _fish_of(team)
		Explosion.spawn(ocean, fish.global_position, AquariumArena.TEAM_COLORS[team], BATTERY_EXPLOSION)
		fish.batter()
	_battery_record_time = _recorder.time
	phase = Phase.BATTERED
	_battery_left = BATTERY_PAUSE
	battered.emit(null, null)


## After a battery (and its replay): the next kickoff, or in overtime the end.
func _after_battery() -> void:
	if overtime and scores[0] != scores[1]:
		_finish_match()
	else:
		kickoff()


## The clock hit 0:00: a winner on goals, then on points, else overtime.
func _time_up() -> void:
	if scores[0] != scores[1] or style.points[0] != style.points[1]:
		_finish_match()
	else:
		overtime = true
		kickoff()


func _finish_match() -> void:
	_stop_replay()
	phase = Phase.OVER
	if scores[0] != scores[1]:
		winner = 0 if scores[0] > scores[1] else 1
	else:
		winner = 0 if style.points[0] > style.points[1] else 1
	over_left = OVER_TIME
	style.live = false
	# Both back out (from a battery or the replay), the player free to swim
	# about; the opponent waits.
	var layout: Vector2 = KICKOFF_LAYOUTS[0]
	for team in 2:
		var fish := _fish_of(team)
		fish.revive(kickoff_transform(layout, team))
	player.controls_locked = false
	opponent.controls_locked = true
	_announce_teleport([player, opponent])
	match_over.emit(winner)


## Whether the match was decided on points (level on goals).
func won_on_points() -> bool:
	return winner >= 0 and scores[0] == scores[1]


func _new_match() -> void:
	scores = [0, 0]
	clock_left = MATCH_TIME
	overtime = false
	overtime_elapsed = 0.0
	winner = -1
	last_battery = {}
	style.reset()
	_pick_opponent()


## A random fish (and its species) and name for the opponent.
func _pick_opponent() -> void:
	opponent.character = FishCharacter.CLASSES.keys().pick_random()
	opponent.display_name = OPPONENT_NAMES.pick_random()


## Starts the replay of the battery just made. False when there's too
## little recorded to show.
func _start_replay() -> bool:
	if last_battery.is_empty():
		return false
	var fish_fry: bool = last_battery.fish_fry
	# A Fish Fry is shot from the player's side, the opponent standing in as the victim.
	var attacker: FishController = player if fish_fry else last_battery.attacker
	var victim: FishController = opponent if fish_fry else last_battery.victim
	var from := maxf(_recorder.start_time(), _battery_record_time - REPLAY_BEFORE)
	var clip := _recorder.clip(from, _battery_record_time + REPLAY_AFTER)
	if clip.times.size() < 30:
		return false
	var fish := [player, opponent]
	battery_replay = GoalReplay.new()
	battery_replay.name = "BatteryReplay"
	# Each explosion in the victim's own team colour, as live.
	battery_replay.setup(clip, _battery_record_time - from, fish.find(attacker), null,
			AquariumArena.TEAM_COLORS[_team_of(victim)], ReplayBall.RADIUS)
	battery_replay.victim = fish.find(victim)
	battery_replay.fish_fry = fish_fry
	battery_replay.scorer_color = AquariumArena.TEAM_COLORS[_team_of(attacker)]
	battery_replay.explosion_radius = BATTERY_EXPLOSION
	battery_replay.in_arena = false
	battery_replay.arcade = true
	battery_replay.finished.connect(func() -> void:
		_stop_replay()
		_after_battery())
	phase = Phase.REPLAY
	# The live fish wait out of sight; the next kickoff (revive) brings them back.
	for f: FishController in fish:
		f.controls_locked = true
		f.visible = false
		f.freeze = true
	add_child(battery_replay)
	battery_replay_started.emit(battery_replay)
	return true


func _stop_replay() -> void:
	if battery_replay == null:
		return
	battery_replay.restore_camera()
	battery_replay.queue_free()
	battery_replay = null
	battery_replay_ended.emit()


## Past the arena's edge: a push back in, harder the further out and the faster outward.
func _keep_in_arena(delta: float) -> void:
	for fish: FishController in [player, opponent]:
		if fish.battered or fish.freeze:
			continue
		var out := fish.global_position - center
		var past := out.length() - ARENA_RADIUS
		if past <= 0.0:
			continue
		var direction := out.normalized()
		var outward := maxf(fish.linear_velocity.dot(direction), 0.0)
		var push := minf(past * BOUNDARY_STIFFNESS + outward * BOUNDARY_OUTWARD, BOUNDARY_MAX)
		fish.apply_push(-direction * push * delta)


func _on_awarded(index: int, type: String, points: int, extra: Dictionary) -> void:
	var event := {"type": type, "player": index, "team": index, "points": points, "title": StylePoints.TITLES[type]}
	event.merge(extra, true)
	_recorder.log_event(event)
	stat_event.emit(event)


## Fish the cameras should snap to once they've actually moved (resets land on
## the next physics step).
func _announce_teleport(moved: Array) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for fish: FishController in moved:
		if is_instance_valid(fish):
			fish_teleported.emit(fish)


func _fish_of(team: int) -> FishController:
	return player if team == 0 else opponent


func _team_of(fish: FishController) -> int:
	return 0 if fish == player else 1
