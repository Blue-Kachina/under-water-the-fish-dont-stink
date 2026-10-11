extends Node3D
## Movement playground root: owns the swappable environment and global shortcuts.
##
## Also plays Rocket League replays in the Aquarium Arena (load_replay): pick
## one in the tuning panel, drop a file on the window, or start the game with
## `-- --replay=PATH`. A .replay is converted first by tools/rl_replay (needs
## uv); a converted .rlreplay.json loads directly. A soundtrack next to the
## replay with its name (7.replay, 7.ogg) plays with it; another can be picked
## in the replay's controls or dropped on the window.

## Environment name -> script. Each script builds its own world and provides
## spawn_transform() and configure_environment(env).
const ENVIRONMENTS := {
	"Obstacle Course": preload("res://scripts/arena.gd"),
	"Ocean": preload("res://scripts/ocean.gd"),
	"Aquarium Arena": preload("res://scripts/aquarium_arena.gd"),
}
const SETTINGS_PATH := "user://playground.cfg"
const REPLAY_ENVIRONMENT := "Aquarium Arena"
## Converted replays are kept here, so a .replay converts only once. Bump the
## folder when the converter's output changes, so old conversions are redone.
const CONVERTED_DIR := "user://replays/converter-1.2"

## Shared with the tuning panel so ball tuning outlives any one arena.
@export var ball_settings: BallSettings

var current_environment := ""
var replay: ReplayPlayer
var _environment: Node3D
var _replay_controls: ReplayControls
var _environment_before_replay := ""
var _loader: Thread

@onready var _fish: FishController = $Fish
@onready var _world: WorldEnvironment = $WorldEnvironment
@onready var _hud: Node = $HUD
@onready var _panel: Node = $DebugPanel
@onready var _camera: Node = $FollowCamera


func _ready() -> void:
	var settings := ConfigFile.new()
	var saved := "Obstacle Course"
	var saved_character := FishCharacter.Family.OCTANE
	if settings.load(SETTINGS_PATH) == OK:
		saved = settings.get_value("playground", "environment", saved)
		saved_character = FishCharacter.from_key(settings.get_value("playground", "character", "octane"))
	_fish.character = saved_character
	set_environment(saved, false)
	_panel.set_environments(ENVIRONMENTS.keys(), current_environment)
	_panel.environment_selected.connect(func(env_name: String) -> void:
		stop_replay()
		set_environment(env_name))
	_panel.set_character(_fish.character)
	_panel.character_selected.connect(set_character)
	_panel.replay_requested.connect(load_replay)
	get_window().files_dropped.connect(func(files: PackedStringArray) -> void:
		if files.is_empty():
			return
		if replay and ReplayAudio.is_audio(files[0]):
			load_replay_audio(files[0])
		else:
			load_replay(files[0]))
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i].begins_with("--replay="):
			load_replay(args[i].trim_prefix("--replay="))
		elif args[i] == "--replay" and i + 1 < args.size():
			load_replay(args[i + 1])


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


## Plays as `character` from now on (and remembers it): the fish respawns as it.
## Not during a replay, where the live fish sits out.
func set_character(character: FishCharacter.Family) -> void:
	if replay:
		return
	_fish.character = character
	_fish.set_spawn(_environment.spawn_transform())
	_panel.set_character(character)
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("playground", "character", FishCharacter.CARS[character].key)
	settings.save(SETTINGS_PATH)


func _process(_delta: float) -> void:
	if replay:
		return  # the replay's own controls are in charge
	if Input.is_action_just_pressed("reset"):
		_fish.set_spawn(_environment.spawn_transform())  # re-read: the aquarium's depends on the ball type
		if _environment is Arena:
			(_environment as Arena).reset_course()
		elif _environment is AquariumArena:
			(_environment as AquariumArena).reset_kickoff()


## Loads (converting a .replay first) and plays a replay. Runs in the
## background; progress and problems show in the tuning panel.
func load_replay(path: String) -> void:
	if _loader and _loader.is_alive():
		_panel.show_status("Still loading the last replay...")
		return
	if _loader:
		_loader.wait_to_finish()
	var lower := path.to_lower()
	if not (lower.ends_with(".replay") or lower.ends_with(".rlreplay.json")):
		_panel.show_status("Not a replay: %s (expected .replay or .rlreplay.json)" % path.get_file())
		return
	_panel.show_status("Loading %s..." % path.get_file())
	_loader = Thread.new()
	_loader.start(_load_in_background.bind(path))


## On the loader thread: convert if needed, then read and convert the data.
## Touches no nodes; hands the result back with call_deferred.
func _load_in_background(path: String) -> void:
	var json_path := path
	if path.to_lower().ends_with(".replay"):
		var result := _convert(path)
		if result.has("error"):
			_replay_failed.call_deferred(result.error)
			return
		json_path = result.path
	var data := ReplayData.new()
	var problem := data.load_file(json_path)
	if problem:
		_replay_failed.call_deferred(problem)
	else:
		_start_replay.call_deferred(data, path)


## Runs tools/rl_replay/convert.py through uv, into CONVERTED_DIR. Returns
## {"path": converted file} or {"error": why not}.
func _convert(source: String) -> Dictionary:
	var target_dir := ProjectSettings.globalize_path(CONVERTED_DIR)
	DirAccess.make_dir_recursive_absolute(target_dir)
	var target := target_dir.path_join(source.get_file().get_basename() + ".rlreplay.json")
	if FileAccess.file_exists(target) and FileAccess.get_modified_time(target) >= FileAccess.get_modified_time(source):
		return {"path": target}  # converted before
	var tool_dir := _converter_dir()
	if tool_dir.is_empty():
		return {"error": "Can't convert .replay files here: tools/rl_replay wasn't found. Convert it with tools/rl_replay/convert.py and load the .rlreplay.json."}
	var output := []
	var code := OS.execute("uv", ["run", "--directory", tool_dir, "convert.py", source, "-o", target], output, true)
	if code != 0:
		var details := "".join(output).strip_edges()
		if code == -1:
			details = "uv isn't installed or isn't on the PATH"
		return {"error": "Converting %s failed: %s" % [source.get_file(), details]}
	return {"path": target}


## The converter's folder: in the project (running from the editor), or two
## levels above the game (builds/windows/ in the repo).
func _converter_dir() -> String:
	for dir: String in [ProjectSettings.globalize_path("res://tools/rl_replay"),
			OS.get_executable_path().get_base_dir().path_join("../../tools/rl_replay").simplify_path()]:
		if FileAccess.file_exists(dir.path_join("convert.py")):
			return dir
	return ""


func _replay_failed(problem: String) -> void:
	_panel.show_status("Replay: %s" % problem)
	push_warning("replay: %s" % problem)


## `source`: the file picked (the .replay, not its conversion), whose folder
## may hold a soundtrack.
func _start_replay(data: ReplayData, source: String) -> void:
	stop_replay()
	_environment_before_replay = current_environment
	if current_environment != REPLAY_ENVIRONMENT:
		set_environment(REPLAY_ENVIRONMENT, false)
	var aquarium := _environment as AquariumArena
	# The live fish and ball sit the replay out.
	_fish.visible = false
	_fish.freeze = true
	_fish.process_mode = Node.PROCESS_MODE_DISABLED
	_panel.set_character_enabled(false)
	aquarium.set_physics_process(false)  # no scoring, no ball respawn
	aquarium.ball.pop()

	replay = ReplayPlayer.new()
	replay.setup(data)
	replay.follow_camera = _camera
	add_child(replay)
	_camera.target = replay.target
	_camera.ball = replay.ball
	replay.target_changed.connect(func(car: ReplayCar) -> void: _camera.target = car)
	replay.cut.connect(Callable(_camera, "snap"))
	_camera.snap()
	_hud.set_replay(replay)
	_replay_controls = ReplayControls.new()
	_replay_controls.setup(replay)
	_replay_controls.close_requested.connect(stop_replay)
	_replay_controls.audio_requested.connect(load_replay_audio)
	_replay_controls.audio_dir = source.get_base_dir()
	add_child(_replay_controls)

	var info := data.match_info
	var status := "Replay: %s, %d players, %s, final score %d-%d" % [data.path.get_file(), data.players.size(),
			ReplayControls._time_text(data.duration), info.score[0], info.score[1]]
	var soundtrack := ReplayAudio.find_beside(source)
	if not soundtrack.is_empty():
		var problem := replay.load_audio(soundtrack)
		status += ", soundtrack: %s" % (problem if problem else soundtrack.get_file())
	_panel.show_status(status)


## Plays `path` with the replay that's playing.
func load_replay_audio(path: String) -> void:
	if replay == null:
		return
	var problem := replay.load_audio(path)
	_panel.show_status("Soundtrack: %s" % (problem if problem else path.get_file()))


## Back to playing (in the environment from before the replay).
func stop_replay() -> void:
	if replay == null:
		return
	replay.queue_free()
	replay = null
	_camera.make_current()  # now, not when the replay's freed at the end of the frame
	_replay_controls.queue_free()
	_replay_controls = null
	_hud.set_replay(null)
	_camera.target = null
	_fish.visible = true
	_fish.freeze = false
	_fish.process_mode = Node.PROCESS_MODE_INHERIT
	_panel.set_character_enabled(true)
	if _environment_before_replay != current_environment:
		set_environment(_environment_before_replay, false)
	else:
		var aquarium := _environment as AquariumArena
		aquarium.set_physics_process(true)
		aquarium.reset_kickoff()
		_camera.ball = aquarium.ball
		_fish.set_spawn(_environment.spawn_transform())
	_camera.snap()


func _exit_tree() -> void:
	if _loader:
		_loader.wait_to_finish()
