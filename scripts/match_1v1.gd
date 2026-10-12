class_name Match1v1
extends Node
## A 1v1 in the aquarium: the player (Blue, defending +Z) against a FishBot
## (Orange). Runs Rocket League's match flow: everyone lined up on one of RL's
## kickoff spots with 33 boost, frozen through a 3-2-1 countdown; after a goal
## (and its explosion, see AquariumArena) a few seconds' celebration, then the
## next kickoff. A supersonic fish that rams an opponent with its front
## demolishes it: it explodes and respawns at the back of its own half 3 s later.
##
## Lives under the AquariumArena (setup() before adding it). end() hands the
## arena and the player's fish back as they were, for Free Play.

## A kickoff or respawn has moved `fish` (cameras following it can snap).
signal fish_teleported(fish: FishController)
signal demolished(attacker: FishController, victim: FishController)

enum Phase { COUNTDOWN, LIVE, GOAL }

const FISH_SCENE := preload("res://scenes/fish.tscn")
const COUNTDOWN_TIME := 3.0
## Boost at a kickoff and after a respawn (RL: 33.3).
const SPAWN_BOOST := 33.3
const RESPAWN_TIME := 3.0
## How long "GO!" shows after the countdown.
const GO_TIME := 0.8
## The hitboxes must come within this (m) for a demolition.
const DEMO_REACH := 0.1
## The victim must be at least this far ahead of the attacker (cosine of the
## angle off its nose): a demolition takes the front of the fish, as RL's bumper.
const DEMO_FRONT := 0.3
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
## RL's respawn spots after a demolition, for the team defending +Z (mirrored likewise).
const RESPAWN_SPOTS := [Vector2(-23.04, 46.08), Vector2(-26.88, 46.08), Vector2(23.04, 46.08), Vector2(26.88, 46.08)]

var arena: AquariumArena
var player: FishController
var bot_fish: FishController
var bot: FishBot
var phase := Phase.COUNTDOWN
var countdown_left := 0.0
var go_time_left := 0.0
var goal_time_left := 0.0

## Demolished fish -> seconds until it respawns.
var _respawn_left := {}
var _demo_box := BoxShape3D.new()


func setup(match_arena: AquariumArena, player_fish: FishController) -> void:
	arena = match_arena
	player = player_fish


func _ready() -> void:
	arena.auto_respawn = false
	arena.scores = [0, 0]
	arena.goal_scored.connect(_on_goal_scored)

	bot_fish = FISH_SCENE.instantiate()
	bot_fish.name = "BotFish"
	bot_fish.character = BOT_CHARACTER
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
	kickoff()


## Hands everything back for Free Play. Call before freeing the match.
func end() -> void:
	if is_instance_valid(arena):
		if arena.goal_scored.is_connected(_on_goal_scored):
			arena.goal_scored.disconnect(_on_goal_scored)
		arena.auto_respawn = true
		if is_instance_valid(arena.ball):
			arena.ball.remove_player(bot_fish)
	player.team_color = Color.TRANSPARENT
	player.controls_locked = false
	player.spawn_boost = 100.0
	if player.demolished:
		player.revive(arena.spawn_transform() if is_instance_valid(arena) else player.global_transform)


## Everyone to a kickoff spot (a random one of RL's, mirrored for the other
## team), ball to the centre, and the countdown starts.
func kickoff() -> void:
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
		Phase.GOAL:
			goal_time_left -= delta
			if goal_time_left <= 0.0:
				kickoff()
				return
	go_time_left = maxf(go_time_left - delta, 0.0)

	for fish: FishController in _respawn_left.keys():
		_respawn_left[fish] -= delta
		if _respawn_left[fish] <= 0.0:
			_respawn_left.erase(fish)
			fish.spawn_boost = SPAWN_BOOST
			fish.revive(_respawn_transform(_team_of(fish)))
			_announce_teleport([fish])

	if phase != Phase.COUNTDOWN:
		_check_demolition(player, bot_fish)
		_check_demolition(bot_fish, player)


func _on_goal_scored(_team: int) -> void:
	phase = Phase.GOAL
	goal_time_left = arena.ball.settings.goal_reset_delay


## `attacker` demolishes `victim` if it's supersonic and its front is touching it.
func _check_demolition(attacker: FishController, victim: FishController) -> void:
	if attacker.demolished or victim.demolished or attacker.speed < FishController.SUPERSONIC_SPEED:
		return
	var ahead := (victim.global_position - attacker.global_position).normalized()
	if ahead.dot(-attacker.global_basis.z) < DEMO_FRONT or not _touching(attacker, victim):
		return
	Explosion.spawn(arena, victim.global_position, AquariumArena.TEAM_COLORS[_team_of(victim)], 6.0)
	victim.demolish()
	_respawn_left[victim] = RESPAWN_TIME
	demolished.emit(attacker, victim)


## Whether `attacker`'s hitbox (grown by DEMO_REACH) overlaps `victim`.
func _touching(attacker: FishController, victim: FishController) -> bool:
	var hitbox := attacker.get_node("Collision") as CollisionShape3D
	_demo_box.size = (hitbox.shape as BoxShape3D).size + Vector3.ONE * DEMO_REACH * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _demo_box
	query.transform = hitbox.global_transform
	query.exclude = [attacker.get_rid()]
	for hit in attacker.get_world_3d().direct_space_state.intersect_shape(query, 8):
		if hit.collider == victim:
			return true
	return false


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
