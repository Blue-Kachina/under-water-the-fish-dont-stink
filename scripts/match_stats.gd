class_name MatchStats
extends RefCounted
## The moments the HUD's player lists call out (goal, assist, save, shot,
## demo), worked out the same way for the live 1v1 and for Rocket League
## replays (whose files only carry goals, demos and touches):
##   shot: a touch that puts the ball on course for the other team's net;
##   save: a touch that takes it off course for the toucher's own net;
##   assist: see AquariumArena.goal_credit (a teammate's touch before the scorer's).
## "On course" is a quick flight of the ball (gravity, drag, bounces off the
## floor, walls and ceiling) for a few seconds: does it cross a goal line
## inside the mouth?
##
## Events are dictionaries like ReplayData's: "type", "time", "player" (an index)
## and "team"; a demo also has "victim".
##
## The live 1v1 also keeps a scoreboard line per player (new_line, tally): RL's
## points for each of those, plus every touch, clears out of your own third and
## centring passes across the other team's (classify_play), which score points
## but aren't called out.

const GOAL = "goal"
const ASSIST = "assist"
const SAVE = "save"
const SHOT = "shot"
const DEMO = "demo"
const TOUCH = "touch"
const CLEAR = "clear"
const CENTER = "center"
## Rocket League's points for each. RL doesn't publish its rules for touches,
## clears and centres; these are its usual values, and the judging below a guess.
const POINTS := {GOAL: 100, ASSIST: 50, SAVE: 50, SHOT: 20, DEMO: 15, CLEAR: 20, CENTER: 10, TOUCH: 2}
## A scoreboard line's columns, as RL's scoreboard orders them, and the event
## each counts.
const COLUMNS := ["score", "goals", "shots", "assists", "saves", "demos", "touches"]
const COUNTED := {GOAL: "goals", SHOT: "shots", ASSIST: "assists", SAVE: "saves", DEMO: "demos", TOUCH: "touches"}
## A clear sends the ball from your own third towards the other end at least
## this fast (m/s); a centre sends it from out wide in the other team's third
## towards the middle at least this fast.
const CLEAR_SPEED := 10.0
const CENTER_SPEED := 5.0
const WIDE := 12.0
## How far ahead the ball's flight is followed (s), and in what steps.
const HORIZON := 3.0
const STEP := 1.0 / 60.0
## The goal mouth (m), from the arena's centre line (AquariumArena's).
const GOAL_LINE := 51.2
const MOUTH_HALF_WIDTH := 8.96
const MOUTH_HEIGHT := 6.4
const HALF_WIDTH := 40.96
const CEILING := 20.48
## Rocket League's ball, for replays.
const RL_BALL := {"gravity": 6.5, "drag": 0.03, "bounce": 0.6, "radius": 0.9125}


## The end of the tank `team` attacks: -1 for Blue (who defends +Z), +1 for Orange.
static func attack_direction(team: int) -> float:
	return -1.0 if team == 0 else 1.0


## The live ball's flight settings.
static func ball_model(settings: BallSettings) -> Dictionary:
	var surface := settings.ball_type == BallSettings.BallType.SURFACE
	return {"gravity": settings.gravity if surface else -settings.buoyancy,
			"drag": settings.air_drag if surface else settings.linear_drag,
			"bounce": settings.bounciness, "radius": settings.radius}


## Whether a ball at `pos` going `vel` crosses the goal line at the `end` end
## (+1 or -1 along Z) inside the mouth within HORIZON.
static func would_score(pos: Vector3, vel: Vector3, end: float, model: Dictionary) -> bool:
	var r: float = model.radius
	var t := 0.0
	while t < HORIZON:
		vel.y -= model.gravity * STEP
		vel *= exp(-model.drag * STEP)
		pos += vel * STEP
		t += STEP
		if pos.y < r:
			pos.y = r
			vel.y = absf(vel.y) * model.bounce
		elif pos.y > CEILING - r:
			pos.y = CEILING - r
			vel.y = -absf(vel.y) * model.bounce
		if absf(pos.x) > HALF_WIDTH - r:
			pos.x = signf(pos.x) * (HALF_WIDTH - r)
			vel.x = -vel.x * model.bounce
		if absf(pos.z) > GOAL_LINE - r:
			if signf(pos.z) == end and absf(pos.x) < MOUTH_HALF_WIDTH - r * 0.5 and pos.y < MOUTH_HEIGHT - r * 0.5:
				if absf(pos.z) > GOAL_LINE + r:
					return true  # wholly over the line
				continue
			if absf(pos.z) > GOAL_LINE:
				return false  # off the back wall beside the mouth (or out the other end)
			pos.z = signf(pos.z) * (GOAL_LINE - r)
			vel.z = -vel.z * model.bounce
	return false


## What a touch by `team` did, from the ball's motion just before and just
## after it: SAVE, SHOT or "" (neither).
static func classify_touch(team: int, before_pos: Vector3, before_vel: Vector3, after_pos: Vector3, after_vel: Vector3,
		model: Dictionary) -> String:
	var own := -attack_direction(team)
	if would_score(before_pos, before_vel, own, model) and not would_score(after_pos, after_vel, own, model):
		return SAVE
	if would_score(after_pos, after_vel, attack_direction(team), model) \
			and not would_score(before_pos, before_vel, attack_direction(team), model):
		return SHOT
	return ""


## What else a touch by `team` (neither a shot nor a save) earned: CLEAR, CENTER or "".
static func classify_play(team: int, before_pos: Vector3, after_vel: Vector3) -> String:
	var attack := attack_direction(team)
	var third := GOAL_LINE / 3.0
	if before_pos.z * -attack > third and after_vel.z * attack >= CLEAR_SPEED:
		return CLEAR
	if before_pos.z * attack > third and absf(before_pos.x) > WIDE and after_vel.x * -signf(before_pos.x) >= CENTER_SPEED:
		return CENTER
	return ""


## A fresh scoreboard line: every COLUMNS entry at 0.
static func new_line() -> Dictionary:
	var line := {}
	for column: String in COLUMNS:
		line[column] = 0
	return line


## Adds a `type` event (GOAL ... CENTER) to `line`: its points, and its count.
static func tally(line: Dictionary, type: String) -> void:
	line.score += POINTS.get(type, 0)
	if COUNTED.has(type):
		line[COUNTED[type]] += 1


## A replay's goals, demos and the shots, saves and assists worked out from its
## touches, in time order. The replay itself is left as it was.
static func replay_events(data: ReplayData) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var touches: Array = []  # [player, team, time]
	var sample := ReplayData.Sample.new()
	for event in data.events:
		match event.type:
			"touch":
				if event.get("player") == null:
					continue
				var player: int = event.player
				var team: int = data.players[player].team
				touches.append([player, team, event.time])
				data.sample_ball(maxf(event.time - 1.0 / 30.0, 0.0), sample)
				var before_pos := sample.position
				var before_vel := sample.velocity
				data.sample_ball(minf(event.time + 0.1, data.duration), sample)
				if not sample.present:
					continue
				var kind := classify_touch(team, before_pos, before_vel, sample.position, sample.velocity, RL_BALL)
				if kind:
					found.append({"type": kind, "time": event.time, "player": player, "team": team})
			"goal":
				found.append(event)
				if event.get("player") != null:
					var assister := assist_for(touches, event.player, event.team, event.time)
					if assister >= 0:
						found.append({"type": ASSIST, "time": event.time, "player": assister, "team": event.team})
				touches.clear()
			"demo":
				if event.get("attacker") != null:
					found.append({"type": DEMO, "time": event.time, "player": event.attacker, "team": data.players[event.attacker].team,
							"victim": event.get("victim")})
			"kickoff":
				touches.clear()
	return found


## The assist on `scorer`'s goal for `team` at `time`, from touches [player,
## team, time] (oldest first), by AquariumArena.goal_credit's rule; -1 for none.
static func assist_for(touches: Array, scorer: int, team: int, time: float) -> int:
	var i := touches.size() - 1
	while i >= 0 and touches[i][0] != scorer:
		i -= 1
	while i >= 0 and touches[i][0] == scorer:
		i -= 1
	while i >= 0 and time - touches[i][2] <= AquariumArena.ASSIST_WINDOW:
		if touches[i][1] == team and touches[i][0] != scorer:
			return touches[i][0]
		i -= 1
	return -1
