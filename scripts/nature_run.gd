class_name NatureRun
extends Node
## Nature mode in the Ocean: the player swims Extra Swishy (no boost) after a
## calm fish (a WanderBot) that the camera's ball cam locks onto. Ramming it
## nose first at the player's nature_demo_speed or faster demolishes it: it
## explodes, the count goes up, and a moment later a new one turns up a little
## way off.
##
## Lives under the Ocean (setup() before adding it). end() hands the player's
## fish back.

## A kickoff or respawn has moved `fish` (cameras following it can snap).
signal fish_teleported(fish: FishController)
signal demolished(attacker: FishController, victim: FishController)

const FISH_SCENE := preload("res://scenes/fish.tscn")
## The first fish waits this far ahead of the player (m).
const FIRST_DISTANCE := 30.0
## Later ones turn up this far from the player (m), in any direction.
const RESPAWN_DISTANCE := Vector2(30.0, 50.0)
## Seconds between a demolition and the next fish.
const RESPAWN_TIME := 1.5
## The target's colour (and its explosion's).
const TARGET_COLOR := Color(0.55, 0.95, 0.75)
const TARGET_NAMES := ["Wanda", "Gill", "Bubbles", "Finley", "Coral", "Squirt", "Nemo-ish", "Sardine Steve"]
## A wandering target further than this from the player (m) is brought back near it.
const LEASH := 150.0

var ocean: Node3D
var player: FishController
var target: FishController
var bot: WanderBot
## Demolitions this run.
var demos := 0
## The speed of the last demolition (m/s).
var last_demo_speed := 0.0
var _respawn_left := -1.0


func setup(nature_ocean: Node3D, player_fish: FishController) -> void:
	ocean = nature_ocean
	player = player_fish


func _ready() -> void:
	target = FISH_SCENE.instantiate()
	target.name = "TargetFish"
	target.character = FishCharacter.Family.HYBRID
	target.display_name = TARGET_NAMES.pick_random()
	add_child(target)
	Match1v1.copy_tuning(player, target)
	target.swim_strokes = false  # it just cruises
	target.team_color = TARGET_COLOR
	bot = WanderBot.new()
	bot.name = "WanderBot"
	bot.fish = target
	bot.threat = player
	add_child(bot)
	start()


## The player at the ocean's spawn, the first fish waiting ahead of it.
func start() -> void:
	demos = 0
	last_demo_speed = 0.0
	_respawn_left = -1.0
	var spawn: Transform3D = ocean.spawn_transform()
	player.revive(spawn)
	var ahead := -spawn.basis.z
	_place_target(spawn.origin + ahead * FIRST_DISTANCE, ahead)
	_announce_teleport([player, target])


## Hands the player's fish back. Call before freeing the run.
func end() -> void:
	if is_instance_valid(player) and player.demolished:
		player.revive(player.global_transform)


func _physics_process(delta: float) -> void:
	if _respawn_left >= 0.0:
		_respawn_left -= delta
		if _respawn_left < 0.0:
			_respawn_target()
		return
	if Demolition.hits(player, target, player.nature_demo_speed):
		_demolish()
	elif target.global_position.distance_to(player.global_position) > LEASH:
		_respawn_target()


func _demolish() -> void:
	last_demo_speed = player.speed
	demos += 1
	Explosion.spawn(ocean, target.global_position, TARGET_COLOR, 6.0)
	target.demolish()
	_respawn_left = RESPAWN_TIME
	demolished.emit(player, target)


## A new fish somewhere around the player, heading off calmly.
func _respawn_target() -> void:
	var direction := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0)).normalized()
	var at := player.global_position + direction * randf_range(RESPAWN_DISTANCE.x, RESPAWN_DISTANCE.y)
	var heading := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	_place_target(at, heading)
	target.display_name = TARGET_NAMES.pick_random()
	_announce_teleport([target])


func _place_target(at: Vector3, heading: Vector3) -> void:
	Match1v1.copy_tuning(player, target)  # tuning changes since apply to it too
	target.swim_strokes = false
	target.bow_wave = false
	target.boost_enabled = false
	target.spawn_boost = 0.0
	target.revive(Transform3D(Basis.looking_at(heading, Vector3.UP), at))
	bot.home = at
	bot.pick_spot()


func _announce_teleport(moved: Array) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for fish: FishController in moved:
		if is_instance_valid(fish):
			fish_teleported.emit(fish)
