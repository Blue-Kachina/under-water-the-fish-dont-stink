class_name ReplayControls
extends CanvasLayer
## The replay's transport bar: a scrub bar marked with goals and kickoffs,
## play/pause, skipping, speed, the Target (a player, Auto or Free) and Camera
## (Player or Director), and display toggles. Keyboard and D-pad shortcuts are
## registered in controls.gd (replay_* actions); the jump button also plays and
## pauses, and boost switches the Camera.
##
## Without a player (Replays mode before a replay is picked) it's just a
## message and Open.

signal close_requested
## A soundtrack was picked (Audio...).
signal audio_requested(path: String)
## A replay file was picked (Open, Replay...): .replay or .rlreplay.json.
signal replay_requested(path: String)

const GOAL_TICK_COLORS := [Color(0.35, 0.6, 1.0), Color(1.0, 0.55, 0.15)]
## Where the replay picker remembers its folder (shared with main.gd's settings).
const SETTINGS_PATH := "user://playground.cfg"

var player: ReplayPlayer
## Where the audio picker opens: the replay's own folder.
var audio_dir := ""

var _message: Label

var _scrub: HSlider
var _scrubbing := false
var _play: Button
var _clock: Label
var _speed: OptionButton
var _watch: OptionButton
var _view: OptionButton
var _sound: CheckBox


func setup(replay_player: ReplayPlayer) -> void:
	player = replay_player


func _ready() -> void:
	layer = 5
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.08, 0.85)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 470.0  # clear of the tuning panel
	panel.offset_right = -320.0  # and of the input display
	panel.offset_top = -132.0
	panel.offset_bottom = -44.0  # above the hint line
	add_child(panel)

	var column := VBoxContainer.new()
	panel.add_child(column)
	if player == null:
		_build_empty(column)
		return

	_scrub = HSlider.new()
	_scrub.focus_mode = Control.FOCUS_NONE
	_scrub.min_value = 0.0
	_scrub.max_value = player.data.duration
	_scrub.step = 0.0
	_scrub.drag_started.connect(func() -> void: _scrubbing = true)
	_scrub.drag_ended.connect(func(_changed: bool) -> void:
		_scrubbing = false
		player.seek(_scrub.value))
	_scrub.value_changed.connect(func(value: float) -> void:
		if _scrubbing:
			player.seek(value))
	column.add_child(_scrub)
	var ticks := _Ticks.new()
	ticks.data = player.data
	ticks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrub.add_child(ticks)

	var row := HBoxContainer.new()
	column.add_child(row)
	row.add_child(_button("<< Goal", "Previous goal  [", func() -> void: player.jump_to_goal(-1)))
	row.add_child(_button("-5 s", "Back 5 s  , / D-pad left", func() -> void: player.seek(player.time - 5.0)))
	row.add_child(_button("<", "Back a frame", func() -> void: player.step(-1)))
	_play = _button("Pause", "Play / pause  P / jump", player.toggle_play)
	_play.custom_minimum_size.x = 64.0
	row.add_child(_play)
	row.add_child(_button(">", "Forward a frame", func() -> void: player.step(1)))
	row.add_child(_button("+5 s", "Forward 5 s  . / D-pad right", func() -> void: player.seek(player.time + 5.0)))
	row.add_child(_button("Goal >>", "Next goal  ]", func() -> void: player.jump_to_goal(1)))

	_clock = Label.new()
	_clock.custom_minimum_size.x = 110.0
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_clock)

	_speed = OptionButton.new()
	_speed.focus_mode = Control.FOCUS_NONE
	_speed.tooltip_text = "Playback speed  - / ="
	for s: float in ReplayPlayer.SPEEDS:
		_speed.add_item("%sx" % str(s))
	_speed.item_selected.connect(func(index: int) -> void: player.speed = ReplayPlayer.SPEEDS[index])
	row.add_child(_speed)

	row.add_child(_button("Audio...", "Play a soundtrack with the replay (.ogg, .mp3, .wav, starting when the replay does)."
			+ " One next to the replay with its name (7.replay, 7.ogg) loads by itself", _pick_audio))
	_sound = _toggle("Sound", "", true, func(on: bool) -> void: player.audio.enabled = on)
	row.add_child(_sound)

	row = HBoxContainer.new()
	column.add_child(row)
	row.add_child(_label("Target"))
	_watch = OptionButton.new()
	_watch.focus_mode = Control.FOCUS_NONE
	_watch.tooltip_text = "Who to watch: a player (stays on them), Auto (the director picks, following the play)" 			+ " or Free (the camera stays where it is)  T / G / D-pad up and down"
	_watch.add_item("Auto")
	_watch.set_item_metadata(0, ReplayPlayer.AUTO)
	for i in player.data.players.size():
		var p: Dictionary = player.data.players[i]
		_watch.add_item("%s (%s)" % [p.name, AquariumArena.TEAM_NAMES[p.team]])
		_watch.set_item_icon(_watch.item_count - 1, _swatch(AquariumArena.TEAM_COLORS[p.team]))
		_watch.set_item_metadata(_watch.item_count - 1, i)
	_watch.add_item("Free")
	_watch.set_item_metadata(_watch.item_count - 1, ReplayPlayer.FREE)
	_watch.item_selected.connect(func(index: int) -> void: player.set_watch(_watch.get_item_metadata(index)))
	_watch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_watch.clip_text = true
	row.add_child(_watch)

	row.add_child(_label("Camera"))
	_view = OptionButton.new()
	_view.focus_mode = Control.FOCUS_NONE
	_view.tooltip_text = "How to show them: Player (the car cam behind them) or Director (broadcast framing with the ball in view)." 			+ " On Free: Director turns to follow the ball, Player holds still  V / boost"
	_view.add_item("Player", ReplayPlayer.View.PLAYER)
	_view.add_item("Director", ReplayPlayer.View.DIRECTOR)
	_view.item_selected.connect(func(index: int) -> void: player.view = _view.get_item_id(index))
	row.add_child(_view)
	row.add_child(_toggle("Hitboxes", "Show hitboxes  H", player.show_hitboxes,
			func(on: bool) -> void: player.show_hitboxes = on))
	row.add_child(_toggle("Names", "Show player names", player.show_names,
			func(on: bool) -> void: player.show_names = on))
	row.add_child(_toggle("Skip pauses", "Skip from each goal to the next kickoff", player.skip_pauses,
			func(on: bool) -> void: player.skip_pauses = on))
	row.add_child(_toggle("Loop", "Start again at the end", player.loop,
			func(on: bool) -> void: player.loop = on))
	row.add_child(_button("Replay...", "Watch another Rocket League replay (.replay or .rlreplay.json)", pick_replay))
	row.add_child(_button("Close", "Back to playing", func() -> void: close_requested.emit()))

	player.target_changed.connect(func(_car: ReplayCar) -> void: _show_choices())
	player.view_changed.connect(_show_choices)
	_show_choices()


## Before a replay is picked: a message (see show_message) and Open.
func _build_empty(column: VBoxContainer) -> void:
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	column.add_child(row)
	_message = _label("Pick a Rocket League replay (.replay or .rlreplay.json), or drop one on the window.")
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_message)
	row.add_child(_button("Open", "Watch a Rocket League replay (.replay or .rlreplay.json)", pick_replay))


## Shows `text` in place of the hint, before a replay is picked (loading
## progress, problems).
func show_message(text: String) -> void:
	if _message:
		_message.text = text


func _process(_delta: float) -> void:
	if player == null:
		return
	if Input.is_action_just_pressed("replay_play_pause") or Input.is_action_just_pressed("jump"):
		player.toggle_play()
	if Input.is_action_just_pressed("replay_back"):
		player.seek(player.time - 5.0)
	if Input.is_action_just_pressed("replay_forward"):
		player.seek(player.time + 5.0)
	if Input.is_action_just_pressed("replay_next_target"):
		player.cycle_watch(1)
	if Input.is_action_just_pressed("replay_previous_target"):
		player.cycle_watch(-1)
	if Input.is_action_just_pressed("replay_previous_goal"):
		player.jump_to_goal(-1)
	if Input.is_action_just_pressed("replay_next_goal"):
		player.jump_to_goal(1)
	if Input.is_action_just_pressed("replay_slower"):
		player.set_speed_step(-1)
	if Input.is_action_just_pressed("replay_faster"):
		player.set_speed_step(1)
	if Input.is_action_just_pressed("replay_camera") or Input.is_action_just_pressed("boost"):
		player.view = ReplayPlayer.View.PLAYER if player.view == ReplayPlayer.View.DIRECTOR else ReplayPlayer.View.DIRECTOR
	if Input.is_action_just_pressed("replay_hitboxes"):
		player.show_hitboxes = not player.show_hitboxes

	if not _scrubbing:
		_scrub.set_value_no_signal(player.time)
	_play.text = "Pause" if player.playing else "Play"
	_clock.text = "%s / %s" % [_time_text(player.time), _time_text(player.data.duration)]
	var speed_index := ReplayPlayer.SPEEDS.find(player.speed)
	if speed_index >= 0 and _speed.selected != speed_index:
		_speed.select(speed_index)
	var loaded := player.audio.stream != null
	_sound.disabled = not loaded
	_sound.tooltip_text = "Play the soundtrack: %s" % player.audio.path.get_file() if loaded else "No soundtrack loaded (Audio...)"


## The Target and Camera pickers, showing the player's choices. Auto names who
## the director's watching.
func _show_choices() -> void:
	var who := ""
	if player.watch == ReplayPlayer.AUTO and player.target != null:
		who = ": %s" % player.target.player.name
	_watch.set_item_text(0, "Auto%s" % who)
	for i in _watch.item_count:
		if _watch.get_item_metadata(i) == player.watch:
			_watch.select(i)
	_view.select(_view.get_item_index(player.view))


## Opens a file picker in the folder last picked from; the first time, in the
## project's private_content/replays (gitignored) or else Rocket League's own
## replay folder. A pick is reported via replay_requested.
func pick_replay() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.title = "Watch a Rocket League replay"
	dialog.filters = PackedStringArray(["*.replay, *.rlreplay.json ; Rocket League replays"])
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	for dir: String in [settings.get_value("replay", "last_dir", ""),
			ProjectSettings.globalize_path("res://private_content/replays"),
			OS.get_executable_path().get_base_dir().path_join("../../private_content/replays").simplify_path(),
			OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("My Games/Rocket League/TAGame/Demos")]:
		if not dir.is_empty() and DirAccess.dir_exists_absolute(dir):
			dialog.current_dir = dir
			break
	dialog.file_selected.connect(func(path: String) -> void:
		settings.clear()
		settings.load(SETTINGS_PATH)  # again: other settings may have changed since
		settings.set_value("replay", "last_dir", path.get_base_dir())
		settings.save(SETTINGS_PATH)
		replay_requested.emit(path)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)


func _pick_audio() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.title = "Play a soundtrack with the replay"
	dialog.filters = PackedStringArray(["*.ogg, *.mp3, *.wav ; Audio"])
	if not audio_dir.is_empty():
		dialog.current_dir = audio_dir
	dialog.file_selected.connect(func(path: String) -> void:
		audio_requested.emit(path)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)


static func _time_text(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func _button(text: String, tooltip: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _toggle(text: String, tooltip: String, on: bool, on_toggled: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.tooltip_text = tooltip
	box.focus_mode = Control.FOCUS_NONE
	box.button_pressed = on
	box.toggled.connect(on_toggled)
	return box


func _swatch(color: Color) -> ImageTexture:
	var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


## Goal (team colour) and kickoff (white) marks along the scrub bar.
class _Ticks extends Control:
	var data: ReplayData

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if data == null or data.duration <= 0.0:
			return
		for event in data.events:
			var x: float = size.x * event.time / data.duration
			if event.type == "goal":
				draw_line(Vector2(x, 0.0), Vector2(x, size.y), ReplayControls.GOAL_TICK_COLORS[event.team], 3.0)
			elif event.type == "kickoff":
				draw_line(Vector2(x, size.y * 0.3), Vector2(x, size.y * 0.7), Color(1, 1, 1, 0.5), 1.0)
