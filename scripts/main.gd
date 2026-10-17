extends Node3D
## Movement playground root: owns the swappable environment, global shortcuts
## and the pause menu (PauseMenu, on Start), whose Settings shows the tuning
## panel. The mode (picked in the tuning panel) decides the environment: Free Play and
## 1v1 (against a bot, Match1v1) in the Aquarium Arena, Free Swim and Nature
## (Extra Swishy strides after a fish to batter, NatureRun) and Hunt (a 1v1
## on Nature's tuning against a hostile fish, HuntMatch) and Unnatural (zombie
## fish under a blood moon, a survivors mode on Nature's tuning, UnnaturalRun)
## in the Ocean, the Obstacle Course, and Replays.
##
## Match modes (MATCH_MODES) start on a card (MatchCard) with the fish sitting
## out; its Play starts the match (play_match). Nature, Hunt and Unnatural play on Nature's
## tuning (NATURE_PRESET), and leaving them puts the tuning from before back.
## Changes made to the tuning while in them are kept for the next time (until
## the game closes).
##
## Replays mode plays Rocket League replays in the Aquarium Arena (load_replay):
## pick one with the replay card's Open, drop a file on the window (from any
## mode), or start the game with `-- --replay=PATH`. A .replay is converted
## first by tools/rl_replay (needs uv); a converted .rlreplay.json loads
## directly. A soundtrack next to the replay with its name (7.replay, 7.ogg)
## plays with it; another can be picked in the replay's controls or dropped on
## the window.

## A Nature run started (Play, a restart doesn't count), or ended.
signal nature_started(run: NatureRun)
signal nature_ended
signal unnatural_started(run: UnnaturalRun)
signal unnatural_ended

## Environment name -> script. Each script builds its own world and provides
## spawn_transform() and configure_environment(env).
const ENVIRONMENTS := {
	"Obstacle Course": preload("res://scripts/arena.gd"),
	"Ocean": preload("res://scripts/ocean.gd"),
	"Aquarium Arena": preload("res://scripts/aquarium_arena.gd"),
}
const SETTINGS_PATH := "user://playground.cfg"
const FREE_PLAY := "Free Play"
const ONE_V_ONE := "1v1"
const FREE_SWIM := "Free Swim (Ocean)"
const NATURE := "Nature"
const HUNT := "Hunt"
const UNNATURAL := "Unnatural"
const TEST_TANK := "Test Tank"
const OBSTACLE_COURSE := "Obstacle Course"
const REPLAYS := "Replays"
const MODES := [FREE_PLAY, ONE_V_ONE, FREE_SWIM, NATURE, HUNT, UNNATURAL, TEST_TANK, OBSTACLE_COURSE, REPLAYS]
## Modes played as a match, which wait on a card for Play.
const MATCH_MODES := [ONE_V_ONE, NATURE, HUNT, UNNATURAL, TEST_TANK]
## Modes played on Nature's tuning.
const NATURE_MODES := [NATURE, HUNT, UNNATURAL, TEST_TANK]
## Nature's tuning: Extra Swishy strides, no boost.
const NATURE_PRESET := "res://presets/nature.cfg"
## Mode -> the environment it's played in.
const MODE_ENVIRONMENTS := {
	FREE_PLAY: "Aquarium Arena",
	ONE_V_ONE: "Aquarium Arena",
	FREE_SWIM: "Ocean",
	NATURE: "Ocean",
	HUNT: "Ocean",
	UNNATURAL: "Ocean",
	TEST_TANK: "Ocean",
	OBSTACLE_COURSE: "Obstacle Course",
	REPLAYS: "Aquarium Arena",
}
## Converted replays are kept here, so a .replay converts only once. Bump the
## folder when the converter's output changes, so old conversions are redone.
const CONVERTED_DIR := "user://replays/converter-1.2"

## Shared with the tuning panel so ball tuning outlives any one arena.
@export var ball_settings: BallSettings

var current_environment := ""
var current_mode := ""
var replay: ReplayPlayer
## The 1v1 being played, if any.
var match_1v1: Match1v1
## The Nature run being played, if any.
var nature_run: NatureRun
## The Hunt match being played, if any.
var hunt_match: HuntMatch
## The Unnatural run being played, if any, and its HUD.
var unnatural_run: UnnaturalRun
var _unnatural_hud: UnnaturalHud
## The first player's school wheel and edge arrows, while a Nature run is on.
var _target_wheel: TargetWheel:
	get:
		return _local.slots[0].wheel if _local and not _local.slots.is_empty() else null
## Nature's split-screen co-op: the local players (the first is this fish,
## camera and HUD).
var _local: LocalCoop
## The tuning from before Nature's, while Nature's is on (else empty).
var _tuning_before_nature := {}
## Nature's tuning as it was when last left, changes included (empty: not yet).
var _nature_tuning := {}
## Shown in a match mode until Play starts the match.
var _match_card: MatchCard
var _environment: Node3D
## Shown throughout Replays mode, with or without a replay.
var _replay_controls: ReplayControls
## Where closing Replays goes back to.
var _mode_before_replays := FREE_PLAY
var _loader: Thread
## Start pauses the game here; the tuning panel opens from it.
var _pause_menu: PauseMenu

@onready var _fish: FishController = $Fish
@onready var _world: WorldEnvironment = $WorldEnvironment
@onready var _hud: Node = $HUD
@onready var _panel: Node = $DebugPanel
@onready var _camera: Node = $FollowCamera


func _ready() -> void:
	var settings := ConfigFile.new()
	var saved_mode := FREE_PLAY
	var saved_character := FishCharacter.Family.OCTANE
	if settings.load(SETTINGS_PATH) == OK:
		saved_mode = _saved_mode(settings)
		saved_character = FishCharacter.from_key(settings.get_value("playground", "character", "octane"))
	if get_tree().current_scene != self and (saved_mode == ONE_V_ONE or saved_mode in NATURE_MODES):
		saved_mode = FREE_PLAY  # inside a test probe: no bot or Nature tuning, whatever was last played
	_fish.character = saved_character
	_fish.display_name = UISettings.display_name()
	UISettings.changed.connect(func(key: String) -> void:
		if key == "player_name":
			_fish.display_name = UISettings.display_name()
		elif key == "goal_replays" and match_1v1:
			match_1v1.goal_replays = UISettings.goal_replays)
	set_mode(saved_mode, false)
	_panel.set_modes(MODES, current_mode)
	_panel.mode_selected.connect(set_mode)
	_panel.set_character(_fish.character)
	_panel.character_selected.connect(set_character)
	var arcade := ArcadeFx.new()
	arcade.name = "ArcadeFx"
	arcade.fish = _fish
	arcade.camera = _camera
	add_child(arcade)
	var first := PlayerSlot.new()
	first.fish = _fish
	first.camera = _camera
	first.hud = _hud
	first.arcade = arcade
	_local = LocalCoop.new()
	_local.name = "LocalCoop"
	_local.setup(self, first, _panel)
	add_child(_local)
	if nature_run:  # a Nature run already on (started before the split-screen players were set up)
		_local.attach_run(nature_run)
	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.settings_panel = _panel
	_pause_menu.reset_label = _reset_label
	_pause_menu.reset_requested.connect(reset_play)
	add_child(_pause_menu)
	# Online co-op: the pause menu doesn't stop the world, but holds the local players still.
	_pause_menu.pauses = func() -> bool: return not NetSession.is_online()
	_pause_menu.opened.connect(func() -> void: _hold_local_players(NetSession.is_online()))
	_pause_menu.closed.connect(func() -> void: _hold_local_players(false))
	_pause_menu.coop_requested.connect(func() -> void:
		var menu := CoopMenu.new()
		menu.name = "CoopMenu"
		add_child(menu))
	NetSession.coop.attach_main(self)
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


## The mode last played (not Replays). Older settings picked the environment
## separately; its Ocean and Obstacle Course are modes now.
func _saved_mode(settings: ConfigFile) -> String:
	var mode: String = settings.get_value("playground", "mode", FREE_PLAY)
	match settings.get_value("playground", "environment", ""):
		"Ocean":
			mode = FREE_SWIM
		"Obstacle Course":
			mode = OBSTACLE_COURSE
	return mode if mode in MODES and mode != REPLAYS else FREE_PLAY


## Builds `env_name` (one of ENVIRONMENTS) and plays the current mode in it.
## Modes pick their environment through set_mode; probes call this directly.
func set_environment(env_name: String) -> void:
	if not ENVIRONMENTS.has(env_name):
		env_name = "Obstacle Course"
	current_environment = env_name
	_end_match()
	_close_match_card()  # while the environment it sat the fish out in is still here
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
	_camera.course = _environment as Arena
	_camera.floor_height = AquariumArena.FLOOR_HEIGHT if _environment is AquariumArena else -INF
	_fish.set_spawn(_environment.spawn_transform())
	_apply_mode()


## Plays as `character` from now on (and remembers it): the fish respawns as it.
## Not in Replays mode, where the live fish sits out.
func set_character(character: FishCharacter.Family) -> void:
	if current_mode == REPLAYS:
		return
	_fish.character = character
	if match_1v1:
		match_1v1.kickoff()  # back to a kickoff as the new character
	elif nature_run:
		nature_run.start()
	elif hunt_match:
		hunt_match.kickoff()
	elif unnatural_run:
		unnatural_run.start()
	else:
		_fish.set_spawn(_environment.spawn_transform())
	_panel.set_character(character)
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("playground", "character", FishCharacter.CARS[character].key)
	settings.save(SETTINGS_PATH)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		reset_play()
	if unnatural_run:
		for slot in _local.slots:
			UnnaturalRun.steady_camera(slot.camera, true, unnatural_run.settings)  # live from the panel


## R or the pause menu's reset: a 1v1 back to a kickoff, otherwise the fish
## back to the spawn and the course or ball reset. Not in Replays or on a match
## card, where the replay bar or card is in charge.
func reset_play() -> void:
	if _reset_label().is_empty():
		return
	if match_1v1:
		match_1v1.kickoff()
		return
	if nature_run:
		if nature_run.authority:
			nature_run.start()  # online, the host's restart is everyone's
		else:
			nature_run.respawn_local()  # a guest: just their own fish back to the start
		return
	if hunt_match:
		hunt_match.restart()
		return
	if unnatural_run:
		if unnatural_run.authority:
			unnatural_run.start()  # online, the host's restart is everyone's
		return
	_fish.set_spawn(_environment.spawn_transform())  # re-read: the aquarium's depends on the ball type
	if _environment is Arena:
		(_environment as Arena).reset_course()
	elif _environment is AquariumArena:
		(_environment as AquariumArena).reset_kickoff()


## What reset_play does right now, for the pause menu ("" when nothing).
func _reset_label() -> String:
	if current_mode == REPLAYS or _match_card:
		return ""
	if match_1v1:
		return "Restart kickoff"
	if hunt_match:
		return "Restart match"
	if unnatural_run:
		return "Reset the tank" if unnatural_run.test_tank else "Restart run"
	return "Restart" if nature_run else "Reset"


## Loads (converting a .replay first) and plays a replay. Runs in the
## background; progress and problems show in the tuning panel.
func load_replay(path: String) -> void:
	if _loader and _loader.is_alive():
		_replay_status("Still loading the last replay...")
		return
	if _loader:
		_loader.wait_to_finish()
	var lower := path.to_lower()
	if not (lower.ends_with(".replay") or lower.ends_with(".rlreplay.json")):
		_replay_status("Not a replay: %s (expected .replay or .rlreplay.json)" % path.get_file())
		return
	set_mode(REPLAYS)
	_replay_status("Loading %s..." % path.get_file())
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
	_replay_status("Replay: %s" % problem)
	push_warning("replay: %s" % problem)


## Replay progress and problems: in the tuning panel, and in the replay bar
## while no replay plays.
func _replay_status(text: String) -> void:
	_panel.show_status(text)
	if _replay_controls:
		_replay_controls.show_message(text)


## `source`: the file picked (the .replay, not its conversion), whose folder
## may hold a soundtrack.
func _start_replay(data: ReplayData, source: String) -> void:
	if current_mode != REPLAYS:
		return  # Replays was left while it loaded
	_close_replay()
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
	_show_replay_controls()
	_replay_controls.audio_dir = source.get_base_dir()

	var info := data.match_info
	var status := "Replay: %s, %d players, %s, final score %d-%d" % [data.path.get_file(), data.players.size(),
			ReplayControls._time_text(data.duration), info.score[0], info.score[1]]
	var soundtrack := ReplayAudio.find_beside(source)
	if not soundtrack.is_empty():
		var problem := replay.load_audio(soundtrack)
		status += ", soundtrack: %s" % (problem if problem else soundtrack.get_file())
	_panel.show_status(status)


## The replay bar for the replay playing, or for picking one when none is.
func _show_replay_controls() -> void:
	if _replay_controls:
		_replay_controls.queue_free()
	_replay_controls = ReplayControls.new()
	_replay_controls.setup(replay)
	_replay_controls.close_requested.connect(stop_replay)
	_replay_controls.audio_requested.connect(load_replay_audio)
	_replay_controls.replay_requested.connect(load_replay)
	add_child(_replay_controls)


## Plays `path` with the replay that's playing.
func load_replay_audio(path: String) -> void:
	if replay == null:
		return
	var problem := replay.load_audio(path)
	_panel.show_status("Soundtrack: %s" % (problem if problem else path.get_file()))


## Back to playing: leaves Replays for the mode played before it.
func stop_replay() -> void:
	if current_mode == REPLAYS:
		set_mode(_mode_before_replays)


## Into Replays mode: the live fish and ball sit it out, and the replay bar
## shows (without a replay until one's picked).
func _enter_replays() -> void:
	_end_match()
	_sit_out()
	_panel.set_character_enabled(false)
	_show_replay_controls()


## Out of Replays mode, back to the live fish in the Aquarium (the next mode
## may then swap the environment).
func _leave_replays() -> void:
	_close_replay()
	_replay_controls.queue_free()
	_replay_controls = null
	_panel.set_character_enabled(true)
	_come_back()


## The live fish (and the Aquarium's ball) sit out (Replays, a match card).
func _sit_out() -> void:
	_fish.visible = false
	_fish.freeze = true
	_fish.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.fish_sitting_out = true
	var aquarium := _environment as AquariumArena
	if aquarium:
		aquarium.set_physics_process(false)  # no scoring, no ball respawn
		aquarium.ball.pop()


## Back from _sit_out: the live fish (and ball, at a kickoff).
func _come_back() -> void:
	_fish.visible = true
	_fish.freeze = false
	_fish.process_mode = Node.PROCESS_MODE_INHERIT
	_hud.fish_sitting_out = false
	var aquarium := _environment as AquariumArena
	if aquarium:
		aquarium.set_physics_process(true)
		aquarium.reset_kickoff()
	_camera.ball = aquarium.ball if aquarium else null
	_fish.set_spawn(_environment.spawn_transform())


## Starts the match mode's match, from its card.
func play_match() -> void:
	if _match_card == null:
		return
	_close_match_card()
	_start_match()


## The card a match mode waits on, with the fish sitting out.
func _show_match_card() -> void:
	_sit_out()
	_match_card = MatchCard.new()
	_match_card.message = _match_card_text(current_mode)
	_match_card.play_requested.connect(play_match)
	add_child(_match_card)


## What a match mode's card says.
static func _match_card_text(mode: String) -> String:
	match mode:
		ONE_V_ONE:
			return "1v1 against a bot: %d minutes on the clock, overtime on a tie." % int(Match1v1.MATCH_TIME / 60.0)
		NATURE:
			return "Swim like a fish: no boost here. Hold throttle and sweep the stick from side to side (any direction, as long as each sweep goes back the other way). Each stride builds to a peak, when its glow flashes; sweep back right then and the next stride pushes harder. Keep it up and the push builds. Ram the fish your camera's locked on fast enough to batter it."
		HUNT:
			return "Hunt: 1v1 in open water, %d minutes on the clock. Batter your opponent (ram it nose first, fast) to score, and watch out: it's out to batter you too. Batter each other at once and it's a Fish Fry. Close calls, dodges and runs of perfect strides earn points, and level on goals, points decide it." % int(HuntMatch.MATCH_TIME / 60.0)
		TEST_TANK:
			return "Test Tank: Unnatural's shooting range. Immortal dummies wait ahead (a cluster, and lines at 10, 20 and 40 m) and the DPS readout shows each damage source. Set your level, every stat, the dummies and a chasing horde in the tuning panel's UNNATURAL > Test Tank. R resets."
		UNNATURAL:
				return "Unnatural: there's a blood moon tonight, and every fish in the sea has turned but you. Survive the zombie horde. Your fish bites on its own: huge ghost jaws snap on whatever's ahead. Ram them at speed to batter them too (it doesn't hurt you), but any other touch does. Swim through the XP pearls they drop to level up."
	return mode


func _close_match_card() -> void:
	if _match_card == null:
		return
	_match_card.queue_free()
	_match_card = null
	_come_back()


## Stops the replay playing, if any (Replays mode carries on).
func _close_replay() -> void:
	if replay == null:
		return
	replay.queue_free()
	replay = null
	_camera.make_current()  # now, not when the replay's freed at the end of the frame
	_hud.set_replay(null)
	_camera.target = null
	_camera.ball = (_environment as AquariumArena).ball


## Plays `mode` (one of MODES) from now on, in its environment. Remembered,
## apart from Replays (and in test probes).
func set_mode(mode: String, remember := true) -> void:
	if mode not in MODES or (mode == current_mode and current_environment == MODE_ENVIRONMENTS[mode]):
		return
	var was_replays := current_mode == REPLAYS
	if mode == REPLAYS and not was_replays and current_mode in MODES:
		_mode_before_replays = current_mode
	current_mode = mode
	if was_replays and mode != REPLAYS:
		_leave_replays()
	if current_environment != MODE_ENVIRONMENTS[mode]:
		set_environment(MODE_ENVIRONMENTS[mode])  # which applies the mode
	else:
		_apply_mode()
	if mode == REPLAYS and not was_replays:
		_enter_replays()
	elif was_replays and mode != REPLAYS:
		_camera.snap()
	if _panel.is_node_ready():
		_panel.set_mode(mode)
	if remember and mode != REPLAYS and get_tree().current_scene == self:  # not from probes
		var settings := ConfigFile.new()
		settings.load(SETTINGS_PATH)
		settings.set_value("playground", "mode", mode)
		if settings.has_section_key("playground", "environment"):
			settings.erase_section_key("playground", "environment")  # from before modes picked it
		settings.save(SETTINGS_PATH)


## Shows a match mode's card (the match starts on Play), or ends the match
## (or card) outside one.
func _apply_mode() -> void:
	if current_mode not in [NATURE, UNNATURAL] and _local:
		_local.drop_extras()  # split-screen co-op is Nature's and Unnatural's
	_use_nature_tuning(current_mode in NATURE_MODES)
	var wanted: bool = current_mode in MATCH_MODES and current_environment == MODE_ENVIRONMENTS[current_mode]
	if wanted:
		# From one match mode straight to another in the same water (Nature to Hunt):
		# the other's match or card goes first.
		if _playing() and _playing_mode() != current_mode:
			_end_match()
		if _match_card and _match_card.message != _match_card_text(current_mode):
			_close_match_card()
		if not _playing() and _match_card == null:
			_show_match_card()
		return
	_close_match_card()
	if not _playing():
		return
	_end_match()
	if current_mode == REPLAYS:
		return
	if _environment is AquariumArena:
		(_environment as AquariumArena).reset_kickoff()
	_fish.set_spawn(_environment.spawn_transform())


## A match, a Nature run or a Hunt is on.
func _playing() -> bool:
	return match_1v1 != null or nature_run != null or hunt_match != null or unnatural_run != null


## The mode of the match being played ("" when none).
func _playing_mode() -> String:
	if match_1v1:
		return ONE_V_ONE
	if nature_run:
		return NATURE
	if unnatural_run:
		return TEST_TANK if unnatural_run.test_tank else UNNATURAL
	return HUNT if hunt_match else ""


## Nature's tuning on (keeping what was there) or off (putting it back).
func _use_nature_tuning(on: bool) -> void:
	if on != _tuning_before_nature.is_empty():
		return  # already so
	if on:
		_tuning_before_nature = _panel.tuning_snapshot()
		_panel.load_mode_preset(NATURE_PRESET)
		if not _nature_tuning.is_empty():
			_panel.restore_tuning(_nature_tuning)
	else:
		_nature_tuning = _panel.tuning_snapshot()
		_panel.restore_tuning(_tuning_before_nature)
		_tuning_before_nature = {}


func _start_match() -> void:
	if current_mode == NATURE:
		_start_nature()
		return
	if current_mode == HUNT:
		_start_hunt()
		return
	if current_mode in [UNNATURAL, TEST_TANK]:
		_start_unnatural(current_mode == TEST_TANK)
		return
	match_1v1 = Match1v1.new()
	match_1v1.name = "Match"
	match_1v1.setup(_environment as AquariumArena, _fish)
	match_1v1.goal_replays = UISettings.goal_replays
	match_1v1.fish_teleported.connect(func(fish: FishController) -> void:
		if fish == _fish:
			_camera.snap())
	_environment.add_child(match_1v1)
	_hud.set_match(match_1v1)


## Online co-op's host: a Nature run of ours, the world run here (the one
## going on, or a new one).
func host_nature_run() -> void:
	set_mode(NATURE)
	if nature_run and nature_run.authority:
		return
	_end_match()
	_close_match_card()
	_start_nature(true)


## Online co-op's guest: a Nature run of our players in the host's world.
func guest_nature_run() -> void:
	set_mode(NATURE)
	_end_match()
	_close_match_card()
	_start_nature(false)


## Back from being a guest: Nature on our own again, the world ours.
func solo_nature_run() -> void:
	if current_mode != NATURE:
		return
	_end_match()
	_close_match_card()
	_start_nature(true)


## Holds the local players' fish still (online, while the pause menu's open:
## the world doesn't stop) or lets them go.
func _hold_local_players(hold: bool) -> void:
	for slot in _local.slots:
		slot.fish.controls_locked = hold


## A Nature run with every local player (LocalCoop), the world run here
## (`authority`) unless this is an online session's guest (CoopSession).
func _start_nature(authority := true) -> void:
	nature_run = NatureRun.new()
	nature_run.name = "Nature"
	nature_run.authority = authority
	nature_run.setup(_environment, _fish)
	for slot in _local.slots:
		slot.fish.set_meta("coop_index", slot.index)
		if slot.index > 0:
			nature_run.players.append(slot.fish)
	_environment.add_child(nature_run)
	_local.attach_run(nature_run)  # each player's ball cam, school wheel and HUD
	nature_started.emit(nature_run)


func _start_hunt() -> void:
	hunt_match = HuntMatch.new()
	hunt_match.name = "Hunt"
	hunt_match.setup(_environment as Ocean, _fish)
	hunt_match.battery_replays = UISettings.goal_replays
	hunt_match.fish_teleported.connect(func(fish: FishController) -> void:
		if fish == _fish:
			_camera.snap())
	_environment.add_child(hunt_match)
	_camera.ball = hunt_match.opponent  # ball cam follows the opponent
	_camera.ball_cam = true
	_hud.set_hunt(hunt_match)


## Online co-op's host in Unnatural: a run of ours, the world run here.
func host_unnatural_run() -> void:
	set_mode(UNNATURAL)
	if unnatural_run and unnatural_run.authority and not unnatural_run.test_tank:
		return
	_end_match()
	_close_match_card()
	_start_unnatural(false, true)


## Online co-op's guest in Unnatural: a run of our players in the host's world.
func guest_unnatural_run() -> void:
	set_mode(UNNATURAL)
	_end_match()
	_close_match_card()
	_start_unnatural(false, false)


## Back from being a guest: Unnatural on our own again, the world ours.
func solo_unnatural_run() -> void:
	if current_mode != UNNATURAL:
		return
	_end_match()
	_close_match_card()
	_start_unnatural(false, true)


## Unnatural (or its Test Tank): the run with every local player (LocalCoop),
## its HUD, and the survivor cam. The world's run here (`authority`) unless
## this is an online session's guest.
func _start_unnatural(test_tank := false, authority := true) -> void:
	unnatural_run = UnnaturalRun.new()
	unnatural_run.name = "TestTank" if test_tank else "Unnatural"
	unnatural_run.test_tank = test_tank
	unnatural_run.authority = authority
	unnatural_run.setup(_environment as Ocean, _fish)
	for slot in _local.slots:
		slot.fish.set_meta("coop_index", slot.index)
		if slot.index > 0:
			unnatural_run.players.append(slot.fish)
	_environment.add_child(unnatural_run)
	_camera.ball = null
	_camera.ball_cam = false
	UnnaturalRun.steady_camera(_camera, true, unnatural_run.settings)
	_camera.snap()
	_unnatural_hud = UnnaturalHud.new()
	_unnatural_hud.name = "UnnaturalHud"
	_unnatural_hud.run = unnatural_run
	_unnatural_hud.fish = _fish
	add_child(_unnatural_hud)
	_local.slots[0].mode_hud = _unnatural_hud
	_local.attach_run(unnatural_run)  # each player's survivor cam and HUD
	unnatural_started.emit(unnatural_run)


func _end_match() -> void:
	if unnatural_run:
		_local.detach_run()
		_local.slots[0].mode_hud = null
		UnnaturalRun.steady_camera(_camera, false, unnatural_run.settings)
		unnatural_run.end()
		unnatural_run.queue_free()
		unnatural_run = null
		_unnatural_hud.queue_free()
		_unnatural_hud = null
		unnatural_ended.emit()
	if hunt_match:
		hunt_match.end()
		hunt_match.queue_free()
		hunt_match = null
		_camera.ball = null
		_hud.set_hunt(null)
	if nature_run:
		_local.detach_run()
		nature_run.end()
		nature_run.queue_free()
		nature_run = null
		nature_ended.emit()
	if match_1v1 == null:
		return
	match_1v1.end()
	match_1v1.queue_free()
	match_1v1 = null
	_hud.set_match(null)


func _exit_tree() -> void:
	if _loader:
		_loader.wait_to_finish()
