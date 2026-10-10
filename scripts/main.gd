extends Node3D
## Movement playground root: owns the swappable environment and global shortcuts.

## Environment name -> script. Each script builds its own world and provides
## spawn_transform() and configure_environment(env).
const ENVIRONMENTS := {
	"Obstacle Course": preload("res://scripts/arena.gd"),
	"Ocean": preload("res://scripts/ocean.gd"),
	"Aquarium Arena": preload("res://scripts/aquarium_arena.gd"),
}
const SETTINGS_PATH := "user://playground.cfg"

## Shared with the tuning panel so ball tuning outlives any one arena.
@export var ball_settings: BallSettings

var current_environment := ""
var _environment: Node3D

@onready var _fish: FishController = $Fish
@onready var _world: WorldEnvironment = $WorldEnvironment
@onready var _hud: Node = $HUD
@onready var _panel: Node = $DebugPanel
@onready var _camera: Node = $FollowCamera


func _ready() -> void:
	var settings := ConfigFile.new()
	var saved := "Obstacle Course"
	if settings.load(SETTINGS_PATH) == OK:
		saved = settings.get_value("playground", "environment", saved)
	set_environment(saved, false)
	_panel.set_environments(ENVIRONMENTS.keys(), current_environment)
	_panel.environment_selected.connect(set_environment)


func set_environment(env_name: String, remember := true) -> void:
	if not ENVIRONMENTS.has(env_name):
		env_name = "Obstacle Course"
	current_environment = env_name
	if _environment:
		_environment.queue_free()
	_environment = ENVIRONMENTS[env_name].new()
	_environment.name = env_name.replace(" ", "")
	if _environment is Arena:
		(_environment as Arena).fish = _fish
	elif _environment is AquariumArena:
		(_environment as AquariumArena).fish = _fish
		(_environment as AquariumArena).ball_settings = ball_settings
	add_child(_environment)
	_environment.configure_environment(_world.environment)
	_hud.set_arena(_environment as Arena)
	_hud.set_aquarium(_environment as AquariumArena)
	_camera.ball = (_environment as AquariumArena).ball if _environment is AquariumArena else null
	_fish.set_spawn(_environment.spawn_transform())

	if remember:
		var settings := ConfigFile.new()
		settings.load(SETTINGS_PATH)
		settings.set_value("playground", "environment", env_name)
		settings.save(SETTINGS_PATH)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		_fish.request_reset()
		if _environment is Arena:
			(_environment as Arena).reset_course()
		elif _environment is AquariumArena:
			(_environment as AquariumArena).reset_kickoff()
