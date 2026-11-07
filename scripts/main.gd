extends Node3D
## Movement playground root: owns the swappable environment, global shortcuts,
## the home screen the game starts on (HomeScreen, whose mode picker starts a
## mode) and the pause menu (PauseMenu, on Start), whose Settings shows the
## settings (DebugPanel). The mode decides the environment: Free Play and
## 1v1 (against a bot, Match1v1) in the Aquarium Arena, Free Swim and Nature
## (Extra Swishy strides after a fish to batter, NatureRun) and Hunt (a 1v1
## on Nature's tuning against a hostile fish, HuntMatch) and Unnatural (zombie
## fish under a blood moon, a survivors mode on Nature's tuning, UnnaturalRun)
## in the Ocean, the Obstacle Course, and Replays.
##
## Match modes (MATCH_MODES) start on a card (MatchCard) with the fish sitting
## out; its Play starts the match (play_match). Nature, Hunt and Unnatural play on Nature's
## tuning (NATURE_PRESET), and leaving them puts the tuning from before back.
## The Obstacle Course plays like Unnatural: its tuning, its survivor cam
## (UnnaturalSettings' camera, Y swapping follow and free cam) and each fish's
## traversal, the mobility skill on the boost button (CourseSkill).
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
signal marco_polo_started(game: MarcoPoloMatch)
signal marco_polo_ended
signal what_stinks_started(game: WhatStinksMatch)
signal what_stinks_ended

## Environment name -> script. Each script builds its own world and provides
## spawn_transform() and configure_environment(env).
const ENVIRONMENTS := {
	"Obstacle Course": preload("res://scripts/arena.gd"),
	"Ocean": preload("res://scripts/ocean.gd"),
	"Aquarium Arena": preload("res://scripts/aquarium_arena.gd"),
	"Sunken Temple": preload("res://scripts/marco_polo/temple_arena.gd"),  # Marco Polo's
	"Aquarium": preload("res://scripts/marco_polo/fish_tank_arena.gd"),
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
const MARCO_POLO := "Marco Polo"
const WHAT_STINKS := "What Stinks?"
const MODES := [FREE_PLAY, ONE_V_ONE, FREE_SWIM, NATURE, HUNT, UNNATURAL, TEST_TANK, OBSTACLE_COURSE, MARCO_POLO, WHAT_STINKS, REPLAYS]
## Modes played as a match, which wait on a card for Play.
const MATCH_MODES := [ONE_V_ONE, NATURE, HUNT, UNNATURAL, TEST_TANK, MARCO_POLO, WHAT_STINKS]
## Modes played on Nature's tuning.
const NATURE_MODES := [NATURE, HUNT, UNNATURAL, TEST_TANK, OBSTACLE_COURSE, MARCO_POLO, WHAT_STINKS]
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
	MARCO_POLO: "Sunken Temple",  # its card's arena picker decides (mode_environment())
	WHAT_STINKS: "Ocean",
	REPLAYS: "Aquarium Arena",
}
## Each mode's tile in the home screen's mode picker (ModePicker): its title,
## pitch (the featured tile), a short line (a small tile), its line icon
## (HexBadge), its colours (the tile, its accent) and how it can be played.
const MODE_TILES := {
	UNNATURAL: {"title": "Unnatural", "icon": "mode_unnatural", "colors": [Color(0.25, 0.04, 0.08), Color(0.93, 0.25, 0.3)],
		"pitch": "A blood moon has turned every fish but you. Survive the zombie horde, level up and stack powerups from chests.",
		"short": "Survive the zombie horde", "play": ["Solo", "Split-screen", "Online"]},
	"Fish Sticks": {"title": "Fish Sticks", "icon": "mode_1v1", "colors": [Color(0.04, 0.17, 0.3), Color(0.35, 0.65, 1.0)],
		"pitch": "Fish-ball in the aquarium arena: play a 1v1 against a bot, or Free Play with no clock.",
		"short": "1v1 or Free Play with a ball", "play": ["Solo"]},
	ONE_V_ONE: {"title": "Fish Sticks: 1v1", "icon": "mode_1v1", "colors": [Color(0.04, 0.17, 0.3), Color(0.35, 0.65, 1.0)],
		"pitch": "Fish-ball in the aquarium against a bot: five minutes on the clock, overtime on a tie.",
		"short": "Fish-ball against a bot", "play": ["Solo"]},
	HUNT: {"title": "Hunt", "icon": "mode_hunt", "colors": [Color(0.27, 0.1, 0.06), Color(1.0, 0.54, 0.36)],
		"pitch": "One on one in open water: batter the other fish before it batters you.",
		"short": "Batter it before it batters you", "play": ["Solo"]},
	NATURE: {"title": "Nature", "icon": "mode_nature", "colors": [Color(0.03, 0.2, 0.17), Color(0.3, 0.88, 0.62)],
		"pitch": "Swim like a real fish: sweep, stride and build speed, then batter the schools for points.",
		"short": "Stride, sweep and batter schools", "play": ["Solo", "Split-screen", "Online"]},
	FREE_PLAY: {"title": "Fish Sticks: Free Play", "icon": "mode_free_play", "colors": [Color(0.05, 0.14, 0.24), Color(0.22, 0.89, 0.84)],
		"pitch": "The aquarium arena and a ball, no clock: practise touches, aerials and shots.",
		"short": "The arena and a ball, no clock", "play": ["Solo"]},
	FREE_SWIM: {"title": "Free Swim", "icon": "mode_free_swim", "colors": [Color(0.04, 0.16, 0.24), Color(0.45, 0.8, 0.95)],
		"pitch": "The open ocean and nothing to do but swim it.",
		"short": "The open ocean, just swimming", "play": ["Solo"]},
	OBSTACLE_COURSE: {"title": "Obstacle Course", "icon": "mode_obstacle_course", "colors": [Color(0.16, 0.12, 0.05), Color(1.0, 0.8, 0.3)],
		"pitch": "Hoops, ramps and walls to swim through, round and over.",
		"short": "Hoops, ramps and walls", "play": ["Solo"]},
	TEST_TANK: {"title": "Test Tank", "icon": "mode_test_tank", "colors": [Color(0.12, 0.08, 0.2), Color(0.75, 0.55, 1.0)],
		"pitch": "Unnatural's shooting range: dummies to hit, every stat to set, and a DPS readout.",
		"short": "Dummies and a DPS readout", "play": ["Solo"]},
	MARCO_POLO: {"title": "Marco Polo", "icon": "mode_marco_polo", "colors": [Color(0.03, 0.14, 0.12), Color(0.4, 1.0, 0.7)],
		"pitch": "Hide and seek by sound. Score in the seeker's sight, keep quiet, and don't get tagged.",
		"short": "Hide and seek by sound", "play": ["Solo", "Online"]},
	WHAT_STINKS: {"title": "What Stinks?", "icon": "mode_what_stinks", "colors": [Color(0.05, 0.13, 0.1), Color(0.75, 0.9, 0.3)],
		"pitch": "One huge Hunter, a school of prey. Eat every fish in the crowd before the clock runs out, or stay in the swim and get away.",
		"short": "One Hunter, a crowd of prey", "play": ["Solo"]},
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
## The Marco Polo match being played, if any.
var marco_polo: MarcoPoloMatch
## The What Stinks? match being played, if any.
var what_stinks: WhatStinksMatch
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
## The Obstacle Course's survivor cam is on, and its traversal (null: not on the course).
var _course_cam := false
var _course_skill: CourseSkill
## Shown in a match mode until Play starts the match.
var _match_card: MatchCard
var _environment: Node3D
## Shown throughout Replays mode, with or without a replay.
var _replay_controls: ReplayControls
## Where closing Replays goes back to.
var _mode_before_replays := FREE_PLAY
var _loader: Thread
## Start pauses the game here; the settings open from it.
var _pause_menu: PauseMenu
## Where the game starts (and the pause menu's Main menu goes): the mode picker.
var _home: HomeScreen

@onready var _fish: FishController = $Fish
@onready var _world: WorldEnvironment = $WorldEnvironment
@onready var _hud: Node = $HUD
@onready var _panel: Node = $DebugPanel
@onready var _camera: Node = $FollowCamera


func _ready() -> void:
	var settings := ConfigFile.new()
	var saved_mode := FREE_PLAY
	var saved_character := FishCharacter.FishClass.SKIRMISHER
	if settings.load(SETTINGS_PATH) == OK:
		saved_mode = _saved_mode(settings)
		saved_character = FishCharacter.from_key(settings.get_value("playground", "character", "skirmisher"))
	if get_tree().current_scene != self and (saved_mode == ONE_V_ONE or saved_mode in NATURE_MODES):
		saved_mode = FREE_PLAY  # inside a test probe: no bot or Nature tuning, whatever was last played
	_fish.set_look(saved_character, saved_species(settings, saved_character))
	_fish.display_name = UISettings.display_name()
	UISettings.changed.connect(func(key: String) -> void:
		if key == "player_name":
			_fish.display_name = UISettings.display_name()
		elif key == "goal_replays" and match_1v1:
			match_1v1.goal_replays = UISettings.goal_replays)
	set_mode(saved_mode, false)
	_panel.set_character(_fish.character)
	_panel.set_species(_fish.species)
	_panel.character_selected.connect(set_character)
	_panel.species_selected.connect(set_species)
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
	_pause_menu.coop_requested.connect(_open_coop)
	_pause_menu.change_character_requested.connect(_change_character)
	_pause_menu.change_character_allowed = func() -> bool: return current_mode not in [UNNATURAL, REPLAYS]  # Unnatural's later
	_pause_menu.main_menu_allowed = func() -> bool: return not NetSession.is_online()
	_pause_menu.can_open = func() -> bool: return not _home.is_open()
	_pause_menu.main_menu_requested.connect(func() -> void: _home.open(true))
	_home = HomeScreen.new()
	_home.name = "HomeScreen"
	_home.main = self
	_home.settings_panel = _panel
	_home.mode_chosen.connect(_open_mode_setup)
	_home.replays_requested.connect(func() -> void:
		_home.close()
		set_mode(REPLAYS))
	_home.coop_requested.connect(_open_coop)
	_home.settings_requested.connect(func() -> void:
		_home.remember_focus()
		_panel.set_open(true))
	_home.character_changed.connect(set_character)
	_home.species_changed.connect(set_species)
	add_child(_home)
	NetSession.coop.attach_main(self)
	get_window().files_dropped.connect(func(files: PackedStringArray) -> void:
		if files.is_empty():
			return
		if replay and ReplayAudio.is_audio(files[0]):
			load_replay_audio(files[0])
		else:
			load_replay(files[0]))
	var args := OS.get_cmdline_user_args()
	var replay_given := false
	for i in args.size():
		if args[i].begins_with("--replay="):
			load_replay(args[i].trim_prefix("--replay="))
			replay_given = true
		elif args[i] == "--replay" and i + 1 < args.size():
			load_replay(args[i + 1])
			replay_given = true
	if get_tree().current_scene == self and not replay_given:
		_home.open()  # the game starts on the home screen (not in test probes)


## A mode was picked on the home screen: its setup screen (options and character)
## opens over the picker; Dive in starts the mode, Back returns to the picker.
func _open_mode_setup(mode: String) -> void:
	if has_node("ModeSetup"):
		return
	var setup := ModeSetups.build(self, mode)
	setup.name = "ModeSetup"
	setup.confirmed.connect(func() -> void:
		var to_start := ModeSetups.apply(self, setup)
		_home.close()
		start_mode(to_start))
	add_child(setup)


## The pause menu's Change Character: the current role's characters over the pause
## menu; Apply plays as the pick and resumes, Back returns to the menu.
func _change_character() -> void:
	if has_node("ModeSetup"):
		return
	var setup := ModeSetups.build_character(self, ModeSetups.current_role(self))
	setup.name = "ModeSetup"
	setup.confirmed.connect(func() -> void:
		ModeSetups.apply_character(self, setup)
		_pause_menu.close())
	add_child(setup)


## Wears `character` in `species` for the match about to start (the setup screen's
## pick): no respawn of its own, as starting the mode does that.
func apply_look(character: FishCharacter.FishClass, species: int) -> void:
	if current_mode == REPLAYS:
		return
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	_fish.set_look(character, species)
	_panel.set_character(character)
	_panel.set_species(_fish.species)
	settings.set_value("playground", "character", FishCharacter.CLASSES[character].key)
	store_species(settings, character, _fish.species)
	settings.save(SETTINGS_PATH)


## Online co-op (the pause menu's or the home screen's Co-op).
func _open_coop() -> void:
	if has_node("CoopMenu"):
		return
	var menu := CoopMenu.new()
	menu.name = "CoopMenu"
	add_child(menu)


## Starts `mode` straight away (the setup screen's Dive in): a match mode's match
## too, with no card to wait on. Picking the mode that's on starts it afresh.
func start_mode(mode: String) -> void:
	if mode not in MODES:
		return
	if mode == current_mode and current_environment == mode_environment(mode):
		if mode == REPLAYS:
			return
		if _playing():
			_end_match()
			_apply_mode()  # back on its card, which the match starts from below
		elif _match_card == null:
			reset_play()
	else:
		set_mode(mode)
	if _match_card:
		play_match()  # its options were picked on the setup screen (Marco Polo's too)


## The environment `mode` plays in: Marco Polo's is its card's arena pick
## (the plain Ocean only inside a test probe; a saved "Ocean" anywhere else
## plays the first of the card's arenas).
func mode_environment(mode: String) -> String:
	if mode != MARCO_POLO:
		return MODE_ENVIRONMENTS[mode]
	var arena: String = MarcoPoloSettings.shared().arena
	var in_probe := get_tree() != null and get_tree().current_scene != self
	if arena in MarcoPoloSettings.ARENAS or (in_probe and arena == MarcoPoloSettings.TEST_ARENA):
		if ENVIRONMENTS.has(arena):
			return arena
	for fallback: String in MarcoPoloSettings.ARENAS:
		if ENVIRONMENTS.has(fallback):
			return fallback
	return MODE_ENVIRONMENTS[mode]


## The mode last played (not Replays). Older settings picked the environment
## separately; its Ocean and Obstacle Course are modes now.
func _saved_mode(settings: ConfigFile) -> String:
	var mode: String = settings.get_value("playground", "mode", FREE_PLAY)
	match settings.get_value("playground", "environment", ""):
		"Ocean":
			mode = FREE_PLAY  # Free Swim is retired from the menus
		"Obstacle Course":
			mode = OBSTACLE_COURSE
	return mode if mode in MODES and mode != REPLAYS and mode != FREE_SWIM else FREE_PLAY


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


## Plays as `character` from now on (and remembers it), in the species last picked
## for it: the fish respawns as it. Not in Replays mode, where the live fish
## sits out.
func set_character(character: FishCharacter.FishClass) -> void:
	if current_mode == REPLAYS:
		return
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	_fish.set_look(character, saved_species(settings, character))
	if match_1v1:
		match_1v1.kickoff()  # back to a kickoff as the new character
	elif nature_run:
		nature_run.start()
	elif hunt_match:
		hunt_match.kickoff()
	elif marco_polo or what_stinks:
		pass  # the new look plays from the next round (each round respawns everyone)
	elif unnatural_run:
		unnatural_run.start()
	else:
		_fish.set_spawn(_environment.spawn_transform())
	_panel.set_character(character)
	_panel.set_species(_fish.species)
	settings.set_value("playground", "character", FishCharacter.CLASSES[character].key)
	settings.save(SETTINGS_PATH)


## Wears species `species` of the current character from now on (and remembers it
## for that fish): looks only, so no respawn. Not in Replays mode.
func set_species(species: int) -> void:
	if current_mode == REPLAYS:
		return
	_fish.species = species
	_panel.set_species(_fish.species)
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	store_species(settings, _fish.character, _fish.species)
	settings.save(SETTINGS_PATH)


## The species last picked for `fish_class` in `settings` (playground/species_<class
## key>, by species key; saves from before classes: skin_<old key>); its first if
## none, unknown or locked.
static func saved_species(settings: ConfigFile, fish_class: FishCharacter.FishClass) -> int:
	var entry: Dictionary = FishCharacter.CLASSES[fish_class]
	var key: String = str(settings.get_value("playground", "species_" + entry.key, ""))
	for alias: String in entry.aliases:
		if key == "":
			key = str(settings.get_value("playground", "skin_" + alias, ""))
	var species := FishCharacter.species_from_key(fish_class, key)
	return species if FishCharacter.is_species_unlocked(fish_class, species) else 0


## Remembers species `species` for `fish_class` in `settings` (by its key; save after).
static func store_species(settings: ConfigFile, fish_class: FishCharacter.FishClass, species: int) -> void:
	settings.set_value("playground", "species_" + FishCharacter.CLASSES[fish_class].key, FishCharacter.species_key(fish_class, species))


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		reset_play()
	if unnatural_run:
		for slot in _local.slots:
			UnnaturalRun.steady_camera(slot.camera, true, unnatural_run.settings, unnatural_run.camera_pull_of(slot.fish))  # live from the panel
	elif _course_cam:
		UnnaturalRun.steady_camera(_camera, true, UnnaturalSettings.shared())  # live from the panel


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
	if marco_polo:
		if marco_polo.authority:
			marco_polo.start_match()
		return
	if what_stinks:
		if what_stinks.authority:
			what_stinks.start_match()
		return
	if unnatural_run:
		if unnatural_run.authority:
			unnatural_run.start()  # online, the host's restart is everyone's
		return
	_fish.set_spawn(_environment.spawn_transform())  # re-read: the aquarium's depends on the ball type
	_fish.respawning.emit()
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
	if marco_polo:
		return "Restart match" if marco_polo.authority else ""
	if what_stinks:
		return "Restart match" if what_stinks.authority else ""
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
	if current_mode == MARCO_POLO:
		_marco_polo_card(_match_card)
	elif current_mode == WHAT_STINKS:
		_what_stinks_card(_match_card)
	add_child(_match_card)


## Marco Polo's card picks the variant, whether you seek or hide first (Start
## as) and the arena (only arenas that are
## built: ENVIRONMENTS), and notes split-screen players it dropped.
func _marco_polo_card(card: MatchCard) -> void:
	var mp := MarcoPoloSettings.shared()
	card.choices.append({"title": "Variant", "options": MarcoPoloSettings.VARIANT_NAMES, "index": int(mp.variant),
			"changed": func(i: int) -> void: mp.variant = i as MarcoPoloSettings.Variant})
	card.choices.append({"title": "Start as", "options": MarcoPoloSettings.START_AS_NAMES, "index": int(mp.start_as),
			"changed": func(i: int) -> void: mp.start_as = i as MarcoPoloSettings.StartAs})
	var arenas: Array = MarcoPoloSettings.ARENAS.filter(func(arena_name: String) -> bool: return ENVIRONMENTS.has(arena_name))
	card.choices.append({"title": "Arena", "options": arenas, "index": maxi(arenas.find(mp.arena), 0),
			"changed": func(i: int) -> void:
				mp.arena = arenas[i]
				if current_environment != mp.arena:
					set_environment.call_deferred(mp.arena)})  # a new card comes with it
	if _local and _local.dropped_for_marco_polo > 0:
		card.note = "No split-screen in Marco Polo (one screen would give the hiders away): %d local player%s dropped. Play together online." \
				% [_local.dropped_for_marco_polo, "" if _local.dropped_for_marco_polo == 1 else "s"]


## What Stinks?'s card picks the variant, whether you hunt or are prey first
## (Start as) and the Hunter's form.
func _what_stinks_card(card: MatchCard) -> void:
	var ws := WhatStinksSettings.shared()
	card.choices.append({"title": "Variant", "options": WhatStinksSettings.VARIANT_NAMES, "index": int(ws.variant),
			"changed": func(i: int) -> void: ws.variant = i as WhatStinksSettings.Variant})
	card.choices.append({"title": "Start as", "options": WhatStinksSettings.START_AS_NAMES, "index": int(ws.start_as),
			"changed": func(i: int) -> void: ws.start_as = i as WhatStinksSettings.StartAs})
	var ready: Array[String] = HunterForms.ready_keys()
	var forms: Array = ready.map(func(key: String) -> String: return HunterForms.name_of(key))
	card.choices.append({"title": "Hunter", "options": forms, "index": maxi(ready.find(HunterForms.playable(ws.form)), 0),
			"changed": func(i: int) -> void: ws.form = ready[i]})
	var size := HunterSize.shared()
	var sizes: Array = WhatStinksSettings.SIZE_CHOICES.duplicate()
	if not sizes.has(size.size_mult):
		sizes.append(size.size_mult)
		sizes.sort()
	card.choices.append({"title": "Size", "options": sizes.map(func(s: float) -> String: return "%sx" % str(snappedf(s, 0.01))),
			"index": maxi(sizes.find(size.size_mult), 0), "changed": func(i: int) -> void: size.size_mult = float(sizes[i])})
	if _local and _local.dropped_for_marco_polo > 0:
		card.note = "No split-screen in What Stinks? (play together online): %d local player%s dropped." \
				% [_local.dropped_for_marco_polo, "" if _local.dropped_for_marco_polo == 1 else "s"]


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
		MARCO_POLO:
			return "Marco Polo: hide and seek by sound. Each round one fish seeks and the rest hide: you seek once, and a bot seeks while you hide (Start as picks which comes first). Hiders score while they're in the seeker's line of sight, even unseen, but every noise (fast swimming, flips, badly timed strides) shows them to the seeker, layer by layer. The seeker tags by touch (click the left stick, or M, to call \"Marco!\"); hiders throw a Fake Fish with RB. Y swaps follow and free cam, as in Unnatural. Last Fish Swimming: tagged is out. Join the Seekers: tagged hunts with them."
		WHAT_STINKS:
			return "What Stinks?: one huge Hunter and a crowd of prey in an open ocean full of fish schools. The Hunter swims at the fish and bites (jump) to eat the ones nearest its mouth, school fish and players alike, and wins by eating every prey player before the clock runs out. Prey swim among the schools and have to be the fish it doesn't bite. An eaten prey watches the others (left / right)."
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
	if mode not in MODES or (mode == current_mode and current_environment == mode_environment(mode)):
		return
	var was_replays := current_mode == REPLAYS
	if mode == REPLAYS and not was_replays and current_mode in MODES:
		_mode_before_replays = current_mode
	current_mode = mode
	GaitSettings.fish_sticks_now = mode in [FREE_PLAY, ONE_V_ONE]
	if was_replays and mode != REPLAYS:
		_leave_replays()
	if current_environment != mode_environment(mode):
		set_environment(mode_environment(mode))  # which applies the mode
	else:
		_apply_mode()
	if mode == REPLAYS and not was_replays:
		_enter_replays()
	elif was_replays and mode != REPLAYS:
		_camera.snap()
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
	if _local:
		var one_screen: bool = current_mode == MARCO_POLO or current_mode == WHAT_STINKS
		_local.no_split_screen = one_screen
		if one_screen and _local.count() > 1:
			_local.dropped_for_marco_polo = _local.count() - 1
		elif not one_screen:
			_local.dropped_for_marco_polo = 0
	if current_mode not in [NATURE, UNNATURAL] and _local:
		_local.drop_extras()  # split-screen co-op is Nature's and Unnatural's
	_use_nature_tuning(current_mode in NATURE_MODES)
	_use_course_cam(current_mode == OBSTACLE_COURSE)
	var wanted: bool = current_mode in MATCH_MODES and current_environment == mode_environment(current_mode)
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
	return match_1v1 != null or nature_run != null or hunt_match != null or unnatural_run != null or marco_polo != null or what_stinks != null


## The mode of the match being played ("" when none).
func _playing_mode() -> String:
	if match_1v1:
		return ONE_V_ONE
	if nature_run:
		return NATURE
	if unnatural_run:
		return TEST_TANK if unnatural_run.test_tank else UNNATURAL
	if marco_polo:
		return MARCO_POLO
	if what_stinks:
		return WHAT_STINKS
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


## The Obstacle Course as Unnatural plays: its survivor cam and the fish's
## traversal (on), or the usual camera and swimming back (off).
func _use_course_cam(on: bool) -> void:
	if on == _course_cam:
		return
	_course_cam = on
	if on:
		_camera.ball_cam = false
		_course_skill = CourseSkill.new()
		_course_skill.name = "CourseSkill"
		_course_skill.fish = _fish
		add_child(_course_skill)
	elif _course_skill:
		remove_child(_course_skill)  # now: it gives the fish its own swimming back on leaving
		_course_skill.queue_free()
		_course_skill = null
	UnnaturalRun.steady_camera(_camera, on, UnnaturalSettings.shared())
	_hud.survivor_cam = on
	_camera.snap()


func _start_match() -> void:
	if current_mode == NATURE:
		_start_nature()
		return
	if current_mode == HUNT:
		_start_hunt()
		return
	if current_mode == MARCO_POLO:
		_start_marco_polo()
		return
	if current_mode == WHAT_STINKS:
		_start_what_stinks()
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


## Marco Polo in the arena picked on its card: the player and bots (no
## split-screen; online players join through CoopSession), the follow cam with
## no ball cam. The world's run here (`authority`) unless this is an online
## session's guest.
func _start_marco_polo(authority := true) -> void:
	_local.drop_extras()
	marco_polo = MarcoPoloMatch.new()
	marco_polo.name = "MarcoPolo"
	marco_polo.authority = authority
	marco_polo.setup(_environment, _fish, _camera)
	_hud.survivor_cam = true  # Unnatural's follow and free cam (MarcoPoloMatch keeps it on), no controls line
	_hud.plate_filter = marco_polo.shows_plate  # the seeker sees hiders' plates only once they show
	_camera.ball = null
	_camera.ball_cam = false
	_environment.add_child(marco_polo)
	_camera.snap()
	marco_polo_started.emit(marco_polo)


## Online co-op's host in Marco Polo: the match ours, the world run here. One
## already running stays (its guests join it).
func host_marco_polo() -> void:
	if marco_polo and marco_polo.authority:
		return
	set_mode(MARCO_POLO)
	_end_match()
	_close_match_card()
	_start_marco_polo(true)


## Online co-op's guest in Marco Polo: our fish in the host's match, in the
## host's arena.
func guest_marco_polo(arena: String) -> void:
	if ENVIRONMENTS.has(arena):
		MarcoPoloSettings.shared().arena = arena
	set_mode(MARCO_POLO)
	if current_environment != mode_environment(MARCO_POLO):
		set_environment(mode_environment(MARCO_POLO))
	_end_match()
	_close_match_card()
	_start_marco_polo(false)


## Back from being a guest: Marco Polo on our own again (us and bots).
func solo_marco_polo() -> void:
	if current_mode != MARCO_POLO:
		return
	_end_match()
	_close_match_card()
	_start_marco_polo(true)


## What Stinks? in the Ocean: the player and bots (online and split-screen come
## later), the follow cam with no ball cam. The world's run here (`authority`).
func _start_what_stinks(authority := true) -> void:
	_local.drop_extras()
	what_stinks = WhatStinksMatch.new()
	what_stinks.name = "WhatStinks"
	what_stinks.authority = authority
	what_stinks.setup(_environment, _fish, _camera)
	_camera.ball = null
	_camera.ball_cam = false
	_environment.add_child(what_stinks)
	_hud.plate_filter = what_stinks.shows_plate  # the Hunter sees no prey's name plate
	_camera.snap()
	what_stinks_started.emit(what_stinks)


## Online co-op's host in What Stinks?: the match ours, the world run here. One already running stays.
func host_what_stinks() -> void:
	if what_stinks and what_stinks.authority:
		return
	set_mode(WHAT_STINKS)
	_end_match()
	_close_match_card()
	_start_what_stinks(true)


## Online co-op's guest in What Stinks?: our fish in the host's match (the host's Ocean).
func guest_what_stinks() -> void:
	set_mode(WHAT_STINKS)
	if current_environment != mode_environment(WHAT_STINKS):
		set_environment(mode_environment(WHAT_STINKS))
	_end_match()
	_close_match_card()
	_start_what_stinks(false)


## Back from being a guest: What Stinks? on our own again (us and bots).
func solo_what_stinks() -> void:
	if current_mode != WHAT_STINKS:
		return
	_end_match()
	_close_match_card()
	_start_what_stinks(true)


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
	_hud.survivor_cam = true
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
		_hud.survivor_cam = false
		unnatural_run.end()
		unnatural_run.queue_free()
		unnatural_run = null
		_unnatural_hud.queue_free()
		_unnatural_hud = null
		unnatural_ended.emit()
	if marco_polo:
		marco_polo.end()
		marco_polo.queue_free()
		marco_polo = null
		_camera.target = null
		_hud.survivor_cam = false
		_hud.plate_filter = Callable()
		marco_polo_ended.emit()
	if what_stinks:
		what_stinks.end()
		what_stinks.queue_free()
		what_stinks = null
		_hud.plate_filter = Callable()
		_camera.target = null
		what_stinks_ended.emit()
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
