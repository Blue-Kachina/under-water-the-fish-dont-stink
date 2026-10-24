extends CanvasLayer
## Settings (UI Redesign Handoff, Settings C · Detail Pane): three columns,
## the sections, the options in the chosen one, and a detail pane explaining
## the focused option with its control. Also the live tuning model behind it:
## every @export_range float or int, @export bool and @export enum on the fish,
## the camera, the ball, Nature, Unnatural and the powerups is an option here,
## written to its target at once and saved/loaded with preset files. Add an
## export to any of them and it shows up under its @export_group's heading,
## its doc comment as the description (tools/gen_setting_docs.gd). A target
## can hide options that don't apply with is_option_active().
##
## The sections: Game (player name, fish, goal replays, tuning presets),
## Display and Controls (UISettings; Controls, with every rebindable action's
## keyboard & mouse and controller binding), then Camera, Fish, Gaits (GaitSettings), Ball, Nature,
## Unnatural and Powerups (the tuning). The big ones are split into tabs
## across the top (TABS).
##
## Controller: up/down move, left/right change the focused option (held, it
## repeats), A toggles / picks / edits / rebinds, Y puts the option back to its
## default, LB/RB step through the section's tabs (only ever its own), LT/RT jump
## whole sections, B goes back a column and then closes. Mouse
## works throughout. Shown from the pause menu's Settings (PauseMenu) and the
## home screen (HomeScreen); runs while the game is paused.

## Where Save and Load open: preset files (.cfg) on this PC. A preset's values
## are applied over the defaults (Rocket League's), so it only needs to list
## what it changes.
const PRESET_DIR := "user://presets"
## Presets that ship with the game, copied into PRESET_DIR when it lacks them.
const BUNDLED_PRESET_DIR := "res://presets"
## Remembers the preset last saved or loaded, which is loaded at startup.
const SETTINGS_PATH := "user://playground.cfg"
## Where Save wrote before presets: still loaded at startup until a preset is.
const LEGACY_SAVE_PATH := "user://tuning.cfg"
## Saved presets carry this (in [meta]).
const TUNING_VERSION := 2
## Optional preview stills for the detail pane: PREVIEW_DIR/<section>/<option>.png.
const PREVIEW_DIR := "res://assets/ui/previews"

## The sections in order: [id, title]. Game, Display and Controls are
## UISettings and Controls; the rest are tuning targets.
const SECTIONS := [["game", "Game"], ["display", "Display"], ["audio", "Audio"], ["controls", "Controls"], ["camera", "Camera"], ["fish", "Fish"],
		["gaits", "Gaits"], ["ball", "Ball"], ["nature", "Nature"], ["unnatural", "Unnatural"], ["powerups", "Powerups"]]
## Who each tuning section is for ("Used by ...").
const USED_BY := {
	"camera": "the follow camera, in every mode",
	"fish": "your fish, in every mode",
	"gaits": "each class's strides, in every mode",
	"ball": "the ball in Fish Sticks",
	"nature": "Nature, Hunt and Unnatural",
	"unnatural": "Unnatural and the Test Tank",
	"powerups": "Unnatural's powerups",
}
## The Game, Display and Controls options: key -> [title, group, description, used by].
const GAME_OPTIONS := {
	"game/player_name": ["Player name", "Player", "Your name on the scoreboard, over your fish, and to the people you play with online.", "the scoreboard and online co-op"],
	"game/character": ["Class", "Player", "The class you swim as. Each has its own body shape and, in Unnatural, its own weapon, signature stat and twist (press Y on the home screen to read them).", "every mode"],
	"game/species": ["Species", "Player", "Your fish's look: a species (or colour morph) of its class, with the same body shape and moves. Each class remembers its own (LT / RT on the home screen change it too).", "every mode"],
	"game/goal_replays": ["Goal replays", "Matches", "A replay of each goal in a Fish Sticks 1v1, and of each battery in Hunt, from the net. Any button skips one.", "Fish Sticks and Hunt"],
	"game/preset_save": ["Save tuning preset", "Tuning presets", "Saves every tuning section (Camera to Powerups) as a preset file. The last preset saved or loaded loads at startup.", "the tuning sections"],
	"game/preset_load": ["Load tuning preset", "Tuning presets", "Loads a preset file over the defaults, so a preset only needs to list what it changes. The shipped presets are in the same folder.", "the tuning sections"],
	"game/preset_default": ["Default tuning", "Tuning presets", "Puts every tuning section back to its defaults. Not saved until you save a preset.", "the tuning sections"],
	"game/preset_copy": ["Copy tuning", "Tuning presets", "Copies the tuning as preset text to the clipboard, to paste into a file or a message.", "the tuning sections"],
	"display/fullscreen": ["Fullscreen", "Window", "Fills the screen. F11 or Alt+Enter switches it any time. The game always starts fullscreen.", "the window"],
	"display/show_stats": ["Stats panel", "Tuning aids", "A readout of the fish's speed, forward speed, drift and more, for tuning.", "the HUD"],
	"display/show_input_overlay": ["Controller overlay", "Tuning aids", "Shows the controller's sticks, triggers and buttons live on screen.", "the HUD"],
	"controls/profile": ["Controller profile", "Controller", "Which controller buttons do what. The sticks, triggers and keyboard are the same in every profile.", "your controller"],
	"audio/profile": ["Sound profile", "Sound", "Which set of sounds plays. None is silent; Beeps is a placeholder beep for every sound. The rest are the folders in audio/profiles (see its README).", "every mode"],
	"audio/music_profile": ["Music", "Sound", "Whose music plays: the sound profile's, or another profile's.", "every mode"],
	"audio/master_volume": ["Master volume", "Volume", "Everything.", "every mode"],
	"audio/sfx_volume": ["Sound effects volume", "Volume", "The game's sounds and the menus'.", "every mode"],
	"audio/music_volume": ["Music volume", "Volume", "The music.", "every mode"],
	"audio/voice_volume": ["Callouts volume", "Volume", "Spoken or sung callouts (\"Fish Fry!\"), in profiles that have them.", "every mode"],
	"audio/beep_missing": ["Beep for missing sounds", "Making sounds", "A sound the profile doesn't have plays its placeholder beep instead of nothing, to hear where the gaps are.", "making sound profiles"],
	"audio/reload": ["Reload sounds", "Making sounds", "Reads the sound profile's files again, so a file just saved is heard. Running from the project, files load straight from disk.", "making sound profiles"],
	"audio/sheet": ["Write recording sheet", "Making sounds", "Writes audio/sound_sheet.csv: every sound, what it's for, how it plays and which profiles have it.", "making sound profiles"],
}
## The big sections' tabs, across the top: section -> [[title, [@export_group
## names]], ...]. A group not listed gets a tab of its own after these.
## Powerups' tabs are by rarity, weapons on their own (_tab_for()); Controls'
## are the keyboard and mouse's bindings and the controller's.
const TABS := {
	"fish": [["Swimming", ["Thrust", "Boost", "Water", "Rotation", "Steering"]],
			["Strokes", ["Swim Strokes", "Extra Swishy", "Bow Wave", "Nature"]],
			["Jumps & Surfaces", ["Jump & Dodge", "Powerslide", "Surface"]],
			["Body & Controller", ["Hitbox", "Controller"]]],
	"gaits": [["Classes", ["Skirmishers", "Hunters", "Gliders", "Lancers", "Charmers", "Bulwarks", "Scorchers", "Drifters", "Brawlers",
			"Breachers"]]],
	"nature": [["Schools", ["Schools", "Formation", "Spawning", "Performance"]],
			["Battering", ["Battered fish", "School Reactions", "Multis & Sprees"]],
			["Pearls & Targets", ["Pearls", "Targeting"]]],
	"unnatural": [["Arena", ["Arena", "Murk", "Minimap", "Camera"]],
			["Feel", ["Feel", "Assist"]],
			["Horde", ["Director", "Enemies", "Twists"]],
			["Survivor", ["Player", "Batteries", "Levels", "Weapons and Tomes", "Pearls"]],
			["Limits", ["Limits", "Choices"]],
			["Attacks", ["Attacks", "Ghost Bite", "Anemone Sting", "Shock Lash", "Bill Thrust", "Bubble Volley", "Spine Burst", "Cavitation Punch"]],
			["Stage & Bosses", ["Stage", "Run", "Drowned Shark", "Blood Leviathan", "Final Bosses"]],
			["Pacing", ["Shrines", "Elite Modifiers"]],
			["Loot", ["Chests", "Drops", "Rarity"]],
			["Test Tank", ["Test Tank"]],
			["Performance", ["Performance"]]],
	"powerups": [["General", []], ["Weapons", []], ["Common", []], ["Uncommon", []], ["Rare", []], ["Epic", []], ["Legendary", []], ["Boss", []],
			["Cursed", []]],
	"controls": [["Keyboard & Mouse", []], ["Controller", []]],
	"audio": [["Sound", []], ["Sound Board", []]],
}
## Options never shown: Rocket League behaviours that are always left on (the
## code keeps their switches; nobody is meant to turn them off).
const HIDDEN := ["fish/rl_roll_timing", "fish/rl_air_control", "fish/rl_dodge_timing", "fish/rl_flip_z_damp", "fish/rl_surface_mechanics",
		"fish/rl_suspension", "fish/rl_tyres", "fish/rl_auto_roll", "ball/rl_hit_impulse", "ball/kickoff_float", "camera/roll_with_surface"]
## The options everyone sees. Everything else waits behind Show Debug Tweaks
## (SELECT in Settings): the tuning presets, the stats panel and controller
## overlay, the sound tools, and every tuning section but the camera, plus the
## fish's controller options.
const EVERYDAY := ["game/player_name", "game/character", "game/species", "game/goal_replays", "display/fullscreen", "audio/profile", "audio/music_profile",
		"audio/master_volume", "audio/sfx_volume", "audio/music_volume", "audio/voice_volume"]
## A held left/right repeats after this, this often (s).
const REPEAT_DELAY := 0.38
const REPEAT_EVERY := 0.06
## A held up/down keeps moving through the list: after this, this often,
## speeding up to SCROLL_FAST once held for SCROLL_FAST_AFTER (s).
const SCROLL_DELAY := 0.35
const SCROLL_EVERY := 0.09
const SCROLL_FAST := 0.045
const SCROLL_FAST_AFTER := 1.2
## How long a rebind waits for a key or button before giving up (s).
const CAPTURE_TIME := 6.0
## A rebind ignores input this long at first (the A press that started it).
const CAPTURE_ARM := 0.2

@export var fish: FishController
@export var follow_camera: Camera3D
@export var ball_settings: BallSettings

## Any tuning value changed (a control, a preset, a restore): whatever copies
## the tuning (other local players' fish, an online session) can follow.
signal tuning_changed
signal character_selected(character: FishCharacter.FishClass)
## The Species row picked species `species` (FishCharacter.SPECIES) of the shown character.
signal species_selected(species: int)
## Settings closed (B from the sections, or set_open(false)).
signal closed

var _targets := {}
var _defaults := {}
## "section/property" -> its Row.
var _rows := {}
## "section/property" -> {section, prop, kind, group, min, max, step, whole,
## allow_greater, allow_lesser, choices: [[name, value], ...]}.
var _meta := {}
## Group heading Label -> its "section/property" keys (hidden when none show).
var _group_headings := {}
## Section id -> its button, and the list of its rows.
var _section_buttons := {}
var _section_lists := {}
var _section := "game"
## The root of the screen (shown while open).
var _panel: Control
var _status: Label
var _title: Label
var _subtitle: Label
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
## The mouse's way back a column (B on a controller): over the options to the
## sections, over the detail pane to its option. Shown when there's a column to go back to.
var _rows_back: Button
var _detail_back: Button
var _detail_preview: TextureRect
var _detail_group: Label
var _detail_title: Label
var _detail_text: Label
var _detail_control: VBoxContainer
var _detail_default: Label
var _detail_lock: Label
var _detail_key := ""
var _hints: ControllerHints
var _s := 1.0
var _character := FishCharacter.FishClass.SKIRMISHER
var _species := 0
var _character_enabled := true
## Sections someone else sets (an online session's host): shown, not editable.
var _locked := {}
var _lock_note := ""
var _repeat_dir := 0
var _repeat_time := 0.0
## What had focus last frame (the slider's repeat starts afresh on it).
var _repeat_focus: Control
## Held up/down: which way (-1 up, 1 down), and for how long.
var _scroll_dir := 0
var _scroll_held := 0.0
var _scroll_time := 0.0
## Section id -> its tabs, each {"title", "list": VBoxContainer, "groups": [names]}.
var _tabs := {}
## Section id -> the tab shown.
var _tab_at := {}
var _tab_bar: HBoxContainer
var _tab_strip: HBoxContainer
var _tab_scroll: ScrollContainer
## The option a rebind is waiting on ("" when none), and for how long.
var _capture_key := ""
var _capture_age := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 7  # over the pause menu and the home screen
	_targets = {"fish": fish, "gaits": GaitSettings.shared(), "camera": follow_camera, "ball": ball_settings, "nature": NatureSettings.shared(),
			"unnatural": UnnaturalSettings.shared(), "powerups": PowerupSettings.shared()}
	for section: String in _targets:
		_defaults[section] = _snapshot(_targets[section])
	_build_ui()
	_panel.visible = false
	_export_presets()
	_load_startup_preset()
	UISettings.changed.connect(func(key: String) -> void:
		for section: String in ["game", "display"]:
			if _rows.has("%s/%s" % [section, key]):
				_refresh_row("%s/%s" % [section, key])
		if _detail_key.ends_with("/" + key):
			_sync_detail())  # not rebuilt: its control may have focus (a dropdown closing, typing)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func is_open() -> bool:
	return _panel.visible


func set_open(open: bool) -> void:
	if open == _panel.visible:
		return
	_panel.visible = open
	_capture_key = ""
	if open:
		for action: String in ["ui_section_previous", "ui_section_next"]:
			_triggers_held[action] = Input.is_action_pressed(action)  # RT is the throttle: held on the way in doesn't count
		_refresh_visibility()
		for key: String in _rows:
			_refresh_row(key)
		_show_section(_section)
		(_section_buttons[_section] as Button).grab_focus.call_deferred()
	else:
		_repeat_dir = 0
		closed.emit()


func show_status(text: String) -> void:
	_status.text = text


## Shows `character` as picked (selections are reported via character_selected).
func set_character(character: FishCharacter.FishClass) -> void:
	_character = character
	if _meta.has("game/species"):
		_meta["game/species"]["choices"] = _species_choices(character)
	if _rows.has("game/character"):
		_refresh_row("game/character")
	if _rows.has("game/species"):
		_refresh_row("game/species")


## Shows species `species` of the shown character as picked (reported via species_selected).
func set_species(species: int) -> void:
	_species = species
	if _rows.has("game/species"):
		_refresh_row("game/species")
	if _detail_key == "game/species":
		_sync_detail()


## The Species row's choices: `fish_class`'s unlocked species, [name, index].
static func _species_choices(fish_class: FishCharacter.FishClass) -> Array:
	var choices := []
	for i in FishCharacter.species_count(fish_class):
		if FishCharacter.is_species_unlocked(fish_class, i):
			choices.append([FishCharacter.species_name(fish_class, i), i])
	return choices


## The character can only be changed while playing, not during a replay.
func set_character_enabled(enabled: bool) -> void:
	_character_enabled = enabled
	for key: String in ["game/character", "game/species"]:
		if _rows.has(key):
			_refresh_row(key)


## Whether the option `key` ("section/property") can be changed now (not
## locked by an online host, not a disabled one).
func is_editable(key: String) -> bool:
	if _locked.has(key.get_slice("/", 0)):
		return false
	if key in ["game/character", "game/species"]:
		return _character_enabled
	if key in ["game/preset_load", "game/preset_default"]:
		return _locked.is_empty()
	return true


## What a range option allows: {min, max, step, whole, allow_greater, allow_lesser}.
func option_range(key: String) -> Dictionary:
	return _meta.get(key, {})


# --- Building ---------------------------------------------------------------

func _build_ui() -> void:
	_s = UITheme.scale_for(get_viewport())
	var s := _s
	_panel = Control.new()
	_panel.name = "Settings"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.theme = UITheme.theme(s)
	add_child(_panel)
	var ground := ColorRect.new()
	ground.color = UITheme.GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(ground)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		frame.add_theme_constant_override("margin_" + side, roundi(56.0 * s))
	frame.add_theme_constant_override("margin_top", roundi(36.0 * s))
	frame.add_theme_constant_override("margin_bottom", roundi(24.0 * s))
	_panel.add_child(frame)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", roundi(18.0 * s))
	frame.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", roundi(14.0 * s))
	page.add_child(header)
	var heading := UITheme.label("Settings", "display", 30.0, UITheme.INK, s, 600)
	header.add_child(heading)
	var lab := UITheme.label("Tuning lab", "caps", 13.0, UITheme.AQUA, s)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(lab)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", roundi(24.0 * s))
	page.add_child(columns)

	# Sections.
	var rail := PanelContainer.new()
	rail.add_theme_stylebox_override("panel", UITheme.box(UITheme.DEEP, 18.0 * s))
	rail.custom_minimum_size.x = 220.0 * s
	columns.add_child(rail)
	var rail_list := VBoxContainer.new()
	rail_list.add_theme_constant_override("separation", roundi(4.0 * s))
	var rail_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		rail_margin.add_theme_constant_override("margin_" + side, roundi(10.0 * s))
	rail.add_child(rail_margin)
	rail_margin.add_child(rail_list)
	for entry: Array in SECTIONS:
		var button := SectionButton.new()
		button.setup(entry[0], entry[1], s)
		button.focus_entered.connect(_show_section.bind(entry[0]))
		button.pressed.connect(func() -> void: _focus_rows(entry[0]))
		button.panel = self
		rail_list.add_child(button)
		_section_buttons[entry[0]] = button
	# Up/down through the sections only, stopping at the ends (held, it keeps going).
	var buttons: Array = _section_buttons.values()
	for i in buttons.size():
		var button: Button = buttons[i]
		button.focus_neighbor_top = button.get_path_to(buttons[maxi(i - 1, 0)])
		button.focus_neighbor_bottom = button.get_path_to(buttons[mini(i + 1, buttons.size() - 1)])

	# Right of the sections: the title, the tabs (big sections), then the
	# options and the detail pane side by side.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", roundi(4.0 * s))
	columns.add_child(right)
	var title_line := HBoxContainer.new()
	title_line.add_theme_constant_override("separation", roundi(6.0 * s))
	right.add_child(title_line)
	_rows_back = _back_arrow("", s)
	_rows_back.tooltip_text = "Back to the sections"
	_rows_back.pressed.connect(_to_sections)
	title_line.add_child(_rows_back)
	_title = UITheme.label("Game", "display", 34.0, UITheme.INK, s, 600)
	title_line.add_child(_title)
	_subtitle = UITheme.label("", "caps", 13.0, UITheme.AQUA, s)
	right.add_child(_subtitle)
	_build_tab_bar(right)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8.0 * s
	right.add_child(spacer)
	var lower := HBoxContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", roundi(24.0 * s))
	right.add_child(lower)

	# Options.
	var middle := VBoxContainer.new()
	middle.custom_minimum_size.x = 520.0 * s
	lower.add_child(middle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	middle.add_child(scroll)
	var lists := VBoxContainer.new()
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lists)
	for entry: Array in SECTIONS:
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", roundi(6.0 * s))
		list.visible = false
		lists.add_child(list)
		_section_lists[entry[0]] = list
		_tabs[entry[0]] = []
		_tab_at[entry[0]] = 0
		for tab: Array in TABS.get(entry[0], []):
			_new_tab(entry[0], tab[0], tab[1])
	_build_game_options()
	_build_bindings()
	for section: String in _targets:
		_build_section(section, _targets[section])
	_prune_tabs()

	# Detail.
	var detail_box := PanelContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL, 20.0 * s))
	lower.add_child(detail_box)
	var detail_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		detail_margin.add_theme_constant_override("margin_" + side, roundi(24.0 * s))
	detail_box.add_child(detail_margin)
	# Too much to fit (the fish list, a long Sound Board entry) scrolls: a bar
	# that shows on the pane's fill, a gutter so it doesn't sit over the
	# content, and focus moving through the choices keeps them in view.
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.follow_focus = true
	var bar := _detail_scroll.get_v_scroll_bar()
	var track := UITheme.box(Color(UITheme.GROUND, 0.6), 4.0 * s)
	track.set_content_margin_all(0.0)
	track.set_content_margin(SIDE_LEFT, 4.0 * s)  # the theme's bars are 0 wide (an empty track): this one isn't
	track.set_content_margin(SIDE_RIGHT, 4.0 * s)
	bar.add_theme_stylebox_override("scroll", track)
	var grab := UITheme.box(Color(UITheme.AQUA, 0.45), 4.0 * s)
	grab.set_content_margin_all(3.0 * s)
	bar.add_theme_stylebox_override("grabber", grab)
	detail_margin.add_child(_detail_scroll)
	var detail_gutter := MarginContainer.new()
	detail_gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_gutter.add_theme_constant_override("margin_right", roundi(16.0 * s))
	_detail_scroll.add_child(detail_gutter)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", roundi(10.0 * s))
	detail_gutter.add_child(_detail)
	_detail_back = _back_arrow("Back", s)
	_detail_back.tooltip_text = "Back to the options"
	_detail_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_detail_back.pressed.connect(_back)
	_detail.add_child(_detail_back)
	_detail_preview = TextureRect.new()
	_detail_preview.custom_minimum_size.y = 240.0 * s
	_detail_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_detail_preview.visible = false
	_detail.add_child(_detail_preview)
	_detail_group = UITheme.label("", "caps", 13.0, UITheme.AQUA, s)
	_detail.add_child(_detail_group)
	_detail_title = UITheme.label("", "display", 26.0, UITheme.INK, s, 600)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_detail_title)
	_detail_text = UITheme.label("", "body", 16.0, UITheme.INK_SOFT, s)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_detail_text)
	_detail_lock = UITheme.label("", "body", 15.0, UITheme.CORAL, s, 600)
	_detail_lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_detail_lock)
	_detail_control = VBoxContainer.new()
	_detail_control.add_theme_constant_override("separation", roundi(8.0 * s))
	_detail.add_child(_detail_control)
	_detail_default = UITheme.label("", "body", 14.0, UITheme.MUTED, s)
	_detail_default.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_detail_default)

	# Footer: the status line and the hints.
	var footer := HBoxContainer.new()
	page.add_child(footer)
	_status = UITheme.label("", "body", 14.0, UITheme.MUTED, s)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	footer.add_child(_status)
	_hints = ControllerHints.new()
	_hints.s = s
	_hints.hints = [["LB/RB", "Tab"], ["LT/RT", "Section"], ["◀ ▶", "Change"], ["Y", "Default"], ["B", "Back"]]
	footer.add_child(_hints)
	_refresh_visibility()


## A group heading in `list`.
func _heading(list: VBoxContainer, text: String) -> Label:
	var heading := UITheme.label(text, "caps", 12.0, UITheme.MUTED, _s)
	heading.custom_minimum_size.y = 30.0 * _s
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	list.add_child(heading)
	_group_headings[heading] = []
	return heading


## A row for option `key` under `heading` (in the heading's list: its tab's).
func _add_row(key: String, meta: Dictionary, heading: Label) -> Row:
	meta["section"] = key.get_slice("/", 0)
	meta["prop"] = key.get_slice("/", 1)
	_meta[key] = meta
	var row := Row.new()
	row.setup(self, key, _title_of(key), _s)
	if key.begins_with("audio/board:"):
		row.set_meta(&"sfx", "")  # it plays the event itself
	heading.get_parent().add_child(row)
	_rows[key] = row
	_group_headings[heading].append(key)
	_refresh_row(key)
	return row


# --- Tabs ---------------------------------------------------------------------

## The bar of tabs over the options: LB, the tabs (scrolling if they don't
## fit), RB. Hidden for sections with one tab.
func _build_tab_bar(parent: Control) -> void:
	var s := _s
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", roundi(10.0 * s))
	_tab_bar.custom_minimum_size.y = 44.0 * s
	parent.add_child(_tab_bar)
	var left := ControllerHints.new()
	left.s = s
	left.hints = [["LB", ""]]
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tab_bar.add_child(left)
	_tab_scroll = ScrollContainer.new()
	_tab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_tab_bar.add_child(_tab_scroll)
	_tab_strip = HBoxContainer.new()
	_tab_strip.add_theme_constant_override("separation", roundi(4.0 * s))
	_tab_scroll.add_child(_tab_strip)
	var right := ControllerHints.new()
	right.s = s
	right.hints = [["RB", ""]]
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tab_bar.add_child(right)


## A tab for `section` holding export groups `groups`; its list of rows.
func _new_tab(section: String, title: String, groups: Array) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", roundi(6.0 * _s))
	list.visible = false
	_section_lists[section].add_child(list)
	_tabs[section].append({"title": title, "list": list, "groups": groups})
	return list


## The list option `key` (of export group `group`) goes in: its tab's, or the
## section's own list when it has no tabs.
func _list_for(key: String, group: String) -> VBoxContainer:
	var section := key.get_slice("/", 0)
	var tabs: Array = _tabs[section]
	if not TABS.has(section):
		return _section_lists[section]
	var title := _tab_for(key, group)
	for tab: Dictionary in tabs:
		if tab.title == title or (title.is_empty() and group in tab.groups):
			return tab.list
	return _new_tab(section, group if title.is_empty() else title, [group])


## The tab title an option belongs under by rule ("" when TABS decides it by
## its group): Powerups by the rarity of the powerup the group is named for,
## Controls by keyboard or controller.
func _tab_for(key: String, group: String) -> String:
	match key.get_slice("/", 0):
		"controls":
			return "Keyboard & Mouse" if key.begins_with("controls/kb:") else "Controller"
		"audio":
			return "Sound Board" if key.begins_with("audio/board:") else "Sound"
		"powerups":
			if group == "Cursed":
				return "Cursed"
			if group == "Fish attack (weapon)":
				return "Weapons"
			var name := group.trim_suffix(" (boss)")
			for id in Powerup.ids():
				if Powerup.title(id) == name:
					return "Weapons" if Powerup.is_weapon(id) else Rarity.NAMES[Powerup.tier(id)].capitalize()
			return "General"
	return ""


## Drops tabs nothing went in (Powerups has no Epic powerup yet).
func _prune_tabs() -> void:
	for section: String in _tabs:
		var kept := []
		for tab: Dictionary in _tabs[section]:
			if tab.list.get_child_count() > 0:
				kept.append(tab)
			else:
				tab.list.queue_free()
		_tabs[section] = kept


## The list shown for `section` now: its current tab's, or its own.
func _shown_list(section: String) -> VBoxContainer:
	var tabs: Array = _visible_tabs(section)
	if tabs.is_empty():
		return _section_lists[section]
	return tabs[clampi(_tab_at[section], 0, tabs.size() - 1)].list


## Shows tab `index` of `section`, and its tab bar.
func _show_tab(section: String, index: int) -> void:
	var tabs: Array = _visible_tabs(section)
	_tab_at[section] = clampi(index, 0, maxi(tabs.size() - 1, 0))
	for tab: Dictionary in _tabs.get(section, []):
		tab.list.visible = false
	for i in tabs.size():
		tabs[i].list.visible = i == _tab_at[section]
	_tab_bar.visible = tabs.size() > 1
	_refresh_hints()
	for child in _tab_strip.get_children():
		_tab_strip.remove_child(child)
		child.queue_free()
	for i in tabs.size():
		var button := TabButton.new()
		button.setup(tabs[i].title, i == _tab_at[section], _s)
		button.pressed.connect(func() -> void:
			var focus := get_viewport().gui_get_focus_owner()
			_show_tab(section, i)
			if focus is Row:
				_focus_rows(section))
		_tab_strip.add_child(button)
		if i == _tab_at[section]:
			(func() -> void:
				if is_instance_valid(button) and _tab_scroll.is_ancestor_of(button):
					_tab_scroll.ensure_control_visible(button)).call_deferred()
	_link_rows(section)


## The next (+1) or previous (-1) tab of this section, wrapping round. The
## bumpers never leave the section (LT / RT do that); with no tabs they do
## nothing. Focus stays in its column.
func _step_tab(direction: int) -> void:
	var tabs: Array = _visible_tabs(_section)
	if tabs.size() < 2:
		return
	var focus := get_viewport().gui_get_focus_owner()
	_show_tab(_section, posmod(int(_tab_at.get(_section, 0)) + direction, tabs.size()))
	_show_first_detail(_section)
	if focus is Row or (focus != null and _detail.is_ancestor_of(focus)):
		_focus_rows(_section)


func _build_game_options() -> void:
	var heading: Label
	var group := ""
	for key: String in GAME_OPTIONS:
		var info: Array = GAME_OPTIONS[key]
		var list := _list_for(key, info[1])
		if heading == null or info[1] != group or heading.get_parent() != list:
			group = info[1]
			heading = _heading(list, group)
		var meta := {"group": group}
		match key:
			"game/player_name":
				meta["kind"] = "text"
			"game/character":
				meta["kind"] = "enum"
				var choices := []
				for fish_class: FishCharacter.FishClass in FishCharacter.CLASSES:
					choices.append([FishCharacter.display_name(fish_class), fish_class])
				meta["choices"] = choices
			"game/species":
				meta["kind"] = "enum"
				meta["choices"] = _species_choices(_character)  # the shown character's (set_character)
			"controls/profile":
				meta["kind"] = "enum"
				var profiles := []
				for profile: String in Controls.profile_names():
					profiles.append([profile, profile])
				meta["choices"] = profiles
			"audio/profile":
				meta["kind"] = "enum"
				meta["choices"] = Sfx.profile_choices()
			"audio/music_profile":
				meta["kind"] = "enum"
				meta["choices"] = Sfx.music_choices()
			"audio/master_volume", "audio/sfx_volume", "audio/music_volume", "audio/voice_volume":
				meta.merge({"kind": "range", "min": 0.0, "max": 100.0, "step": 5.0, "whole": true,
						"allow_greater": false, "allow_lesser": false})
			"audio/reload", "audio/sheet":
				meta["kind"] = "action"
			_:
				meta["kind"] = "action" if key.begins_with("game/preset_") else "bool"
		_add_row(key, meta, heading)
	_build_sound_board()


## Settings > Audio's Sound Board: a row per sound event (SoundCatalog), under
## its category, saying whether the sound profile has it; A plays it.
func _build_sound_board() -> void:
	for category: String in SoundCatalog.CATEGORIES:
		var ids := SoundCatalog.ids_in(category)
		if ids.is_empty():
			continue
		var group: String = SoundCatalog.CATEGORIES[category]
		var heading := _heading(_list_for("audio/board:" + ids[0], group), group)
		for id in ids:
			_add_row("audio/board:" + id, {"group": group, "kind": "action", "title": id, "event": id}, heading)
	Sfx.profile_loaded.connect(_refresh_audio_rows)


## The Sound Board's rows and the profile pickers, after a profile (re)loads.
func _refresh_audio_rows() -> void:
	if _meta.has("audio/profile"):
		_meta["audio/profile"]["choices"] = Sfx.profile_choices()
		_meta["audio/music_profile"]["choices"] = Sfx.music_choices()
	for key: String in _rows:
		if key.begins_with("audio/"):
			_refresh_row(key)


## The Controls section's rebinds (Controls.REBINDABLE): a row for each
## action's keyboard and mouse binding (its tab) and its controller binding
## (the other, under the controller profile), and a reset for each.
func _build_bindings() -> void:
	for pad: bool in [false, true]:
		var kind := "pad" if pad else "kb"
		var heading: Label
		var group := ""
		for entry: Array in Controls.REBINDABLE:
			var key := "controls/%s:%s" % [kind, entry[0]]
			var list := _list_for(key, entry[2])
			if heading == null or entry[2] != group:
				group = entry[2]
				heading = _heading(list, group)
			_add_row(key, {"group": group, "kind": "binding", "action": entry[0], "pad": pad, "title": entry[1]}, heading)
		var reset_key := "controls/%s:reset_all" % kind
		var reset_heading := _heading(_list_for(reset_key, "Bindings"), "Bindings")
		_add_row(reset_key, {"group": "Bindings", "kind": "action", "pad": pad,
				"title": "Reset all controller bindings" if pad else "Reset all keyboard & mouse bindings"}, reset_heading)
	Controls.bindings_changed.connect(func() -> void:
		for key: String in _rows:
			if key.begins_with("controls/"):
				_refresh_row(key)
		if _detail_key.begins_with("controls/"):
			_show_detail(_detail_key))


func _build_section(section: String, target: Object) -> void:
	var shown_group := "∅"
	var heading: Label
	for property in _tunable_properties(target):
		var prop: String = property.name
		var key := "%s/%s" % [section, prop]
		if heading == null or property.group != shown_group:
			shown_group = property.group
			var group_name: String = shown_group if shown_group else "General"
			heading = _heading(_list_for(key, group_name), group_name)
		var meta := {"group": shown_group if shown_group else "General"}
		if target.has_method("option_title"):  # options made per class (GaitSettings)
			meta["title"] = target.option_title(prop)
		if property.type == TYPE_BOOL:
			meta["kind"] = "bool"
		elif property.hint == PROPERTY_HINT_ENUM:
			meta["kind"] = "enum"
			var choices := []
			var next_value := 0
			for option: String in property.hint_string.split(","):
				var parts := option.split(":")
				var value := parts[1].to_int() if parts.size() > 1 else next_value
				choices.append([parts[0], value])
				next_value = value + 1
			meta["choices"] = choices
		else:
			var range_parts: PackedStringArray = property.hint_string.split(",")
			var whole: bool = property.type == TYPE_INT
			meta["kind"] = "range"
			meta["min"] = range_parts[0].to_float()
			meta["max"] = range_parts[1].to_float()
			meta["whole"] = whole
			meta["step"] = 1.0 if whole else 0.01
			if range_parts.size() > 2 and range_parts[2].is_valid_float():
				meta["step"] = range_parts[2].to_float()
			# "or_greater" / "or_less": a preset's value can lie past the slider's end.
			meta["allow_greater"] = "or_greater" in range_parts
			meta["allow_lesser"] = "or_less" in range_parts
		_add_row(key, meta, heading)


# --- Values -----------------------------------------------------------------

## Option `key`'s value now (a binding's: what it's bound to).
func _value(key: String) -> Variant:
	var section := key.get_slice("/", 0)
	var prop := key.get_slice("/", 1)
	var meta: Dictionary = _meta.get(key, {})
	if meta.get("kind", "") == "binding":
		return Controls.binding_text(meta.action, meta.pad)
	match key:
		"game/character":
			return _character
		"game/species":
			return _species
		"controls/profile":
			return Controls.current_profile
	if section in ["game", "display"]:
		return UISettings.get(prop) if prop in UISettings.KEYS else null
	if section == "audio":
		return Sfx.get(prop) if prop in Sfx.KEYS else null
	return _targets[section].get(prop) if _targets.has(section) else null


## Option `key`'s default.
func _default(key: String) -> Variant:
	var section := key.get_slice("/", 0)
	var prop := key.get_slice("/", 1)
	var meta: Dictionary = _meta.get(key, {})
	if meta.get("kind", "") == "binding":
		return Controls.default_text(meta.action, meta.pad)
	match key:
		"game/player_name":
			return UISettings.DEFAULT_NAME
		"game/character":
			return FishCharacter.FishClass.SKIRMISHER
		"game/species":
			return 0
		"game/goal_replays", "display/fullscreen":
			return true
		"display/show_stats", "display/show_input_overlay":
			return false
		"controls/profile":
			return Controls.DEFAULT_PROFILE
	if section == "audio":
		return Sfx.DEFAULTS.get(prop)
	return _defaults[section].get(prop) if _defaults.has(section) else null


## Sets option `key` to `value`, the way its control would.
func _set_value(key: String, value: Variant) -> void:
	if not is_editable(key):
		return
	var section := key.get_slice("/", 0)
	var prop := key.get_slice("/", 1)
	match key:
		"game/character":
			_character = value
			character_selected.emit(value)
			show_status("Class: %s (remembered on this PC)" % FishCharacter.display_name(value))
		"game/species":
			_species = value
			species_selected.emit(value)
			show_status("Species: %s (remembered on this PC)" % FishCharacter.species_name(_character, value))
		"controls/profile":
			Controls.apply_profile(value)
			show_status("Controller profile: %s (remembered on this PC)" % Controls.current_profile)
		_:
			if section in ["game", "display"]:
				UISettings.set_value(prop, value)
			elif section == "audio":
				Sfx.set_value(prop, roundi(value) if _meta[key].get("whole", false) else value)
				if prop == "profile":
					show_status(Sfx.summary())
			elif _targets.has(section):
				var meta: Dictionary = _meta[key]
				if meta.get("whole", false):
					value = roundi(value)
				_targets[section].set(prop, value)
				tuning_changed.emit()
				if meta.kind != "range":
					_refresh_visibility()
	_refresh_row(key)
	if key == _detail_key:
		_sync_detail()


## Moves option `key` one step (`direction` -1 or 1): a range by its step, a
## bool on/off, an enum to the next choice.
func _step(key: String, direction: int) -> void:
	var meta: Dictionary = _meta.get(key, {})
	var value: Variant = _value(key)
	match meta.get("kind", ""):
		"bool":
			if is_editable(key) and bool(value) != (direction > 0):
				Sfx.ui("ui/toggle_on" if direction > 0 else "ui/toggle_off")
			_set_value(key, direction > 0)
		"enum":
			var choices: Array = meta.choices
			var at := 0
			for i in choices.size():
				if choices[i][1] == value:
					at = i
			if is_editable(key) and choices.size() > 1:
				Sfx.ui("ui/move")
			_set_value(key, choices[posmod(at + direction, choices.size())][1])
		"range":
			var step := _pad_step(meta)
			var low: float = meta.min
			var high: float = maxf(meta.max, value) if meta.allow_greater else meta.max
			if meta.allow_lesser:
				low = minf(low, value)
			var next := clampf(snappedf(float(value) + direction * step, step), low, high)
			if is_editable(key) and next != float(value):
				Sfx.ui("ui/slider", roundi(7.0 * clampf((next - low) / maxf(high - low, 0.0001), 0.0, 1.0)))
			_set_value(key, next)


## How far one left/right press moves a slider: its step, unless that would
## take more than 100 presses to cross it.
func _pad_step(meta: Dictionary) -> float:
	var step: float = meta.step
	var span: float = meta.max - meta.min
	if step <= 0.0:
		step = 0.01
	if span / step > 100.0:
		step = maxf(snappedf(span / 100.0, step), step)
	return step


func _reset_option(key: String) -> void:
	var meta: Dictionary = _meta.get(key, {})
	if meta.get("kind", "") == "action":
		return
	if meta.get("kind", "") == "binding":
		Controls.reset_binding(meta.action, meta.pad)
		show_status("%s back to %s" % [_title_of(key), Controls.default_text(meta.action, meta.pad)])
		return
	var value: Variant = _default(key)
	if value != null:
		_set_value(key, value)
		show_status("%s back to its default" % _title_of(key))


## Runs action `key` (the tuning preset rows, the audio ones).
func _act(key: String) -> void:
	if key.begins_with("audio/"):
		_act_audio(key)
		return
	if not is_editable(key):
		show_status("The host sets the tuning while you're online")
		return
	match key:
		"game/preset_save":
			_pick_preset(true)
		"game/preset_load":
			_pick_preset(false)
		"game/preset_default":
			_restore_defaults()
		"game/preset_copy":
			_copy_to_clipboard()
		"controls/kb:reset_all", "controls/pad:reset_all":
			Controls.reset_all_bindings(key.begins_with("controls/pad:"))
			show_status("Every %s binding back to its default" % ("controller" if key.begins_with("controls/pad:") else "keyboard & mouse"))


func _act_audio(key: String) -> void:
	match key:
		"audio/reload":
			show_status(Sfx.load_profile())
			_show_detail(_detail_key)
		"audio/sheet":
			var path: String = Sfx.write_sheet()
			show_status("Recording sheet: %s" % path if path else "Couldn't write the recording sheet")
		_:
			var id := key.trim_prefix("audio/board:")
			match Sfx.audition(id):
				"profile":
					show_status("%s  ·  %s" % [id, "borrowed: " + SoundCatalog.FALLBACKS[id] if Sfx.status(id) == "borrowed" else "from " + Sfx.active_profile().title])
				"beep":
					show_status("%s  ·  not in this profile: its placeholder beep" % id)


# --- Rebinding ------------------------------------------------------------------

## Whether a rebind is waiting for a key or button (the pause menu leaves all
## input to it then).
func is_capturing() -> bool:
	return not _capture_key.is_empty()


## Option `key` (a binding) waits for the key, mouse button, controller button
## or stick push to use.
func _start_capture(key: String) -> void:
	_capture_key = key
	_capture_age = 0.0
	_repeat_dir = 0
	_refresh_row(key)
	if key == _detail_key:
		_show_detail(key)  # the pane says it's listening too
	var pad: bool = _meta[key].pad
	show_status(("Press the controller button, or push the stick or trigger, for %s  ·  Esc cancels" if pad
			else "Press the key or mouse button for %s  ·  Esc cancels") % _title_of(key))


func _end_capture(event: InputEvent) -> void:
	var key := _capture_key
	_capture_key = ""
	if event:
		var meta: Dictionary = _meta[key]
		var shared := Controls.actions_on(event, meta.action)
		Controls.rebind(meta.action, event)
		show_status("%s: %s%s" % [_title_of(key), Controls.binding_text(meta.action, meta.pad),
				"  ·  also on %s" % ", ".join(shared) if not shared.is_empty() else ""])
	else:
		show_status("Rebind cancelled")
	_refresh_row(key)
	if _rows.has(key):
		(_rows[key] as Row).grab_focus()
	if key == _detail_key:
		_show_detail(key)


## While a rebind waits: the first fitting key / button / push is it; Esc (or
## B on the keyboard tab) cancels. Everything else is swallowed.
func _capture_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if _capture_age < CAPTURE_ARM:
		return
	var pad: bool = _meta[_capture_key].pad
	var key_event := event as InputEventKey
	if key_event and key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_ESCAPE:
		_end_capture(null)
		return
	if pad:
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
			_end_capture(event)
		elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= 0.6:
			_end_capture(event)
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_end_capture(null)
	else:
		if key_event and key_event.pressed and not key_event.echo:
			_end_capture(event)
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_end_capture(event)
		elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed \
				and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
			_end_capture(null)


## What row `key`'s value says, and in what colour.
func _value_text(key: String) -> Array:
	var meta: Dictionary = _meta.get(key, {})
	var value: Variant = _value(key)
	var changed: bool = value != _default(key)
	match meta.get("kind", ""):
		"binding":
			if key == _capture_key:
				var left := ceili(CAPTURE_TIME - _capture_age)
				return [("PRESS A BUTTON…  %d" if meta.pad else "PRESS A KEY…  %d") % left, UITheme.CORAL]
			return [str(value).to_upper(), UITheme.AQUA if Controls.is_rebound(meta.action, meta.pad) else UITheme.INK_SOFT]
		"bool":
			return ["ON", UITheme.AQUA] if value else ["OFF", UITheme.MUTED]
		"enum":
			for choice: Array in meta.choices:
				if choice[1] == value:
					return [str(choice[0]).to_upper(), UITheme.AQUA if changed else UITheme.INK_SOFT]
			return [str(value), UITheme.INK_SOFT]
		"text":
			return [UISettings.display_name(), UITheme.INK_SOFT]
		"action":
			if meta.has("event"):
				match Sfx.status(meta.event):
					"have":
						return ["HAVE ›", UITheme.AQUA]
					"borrowed":
						return ["BORROWED ›", UITheme.INK_SOFT]
					"missing":
						return ["MISSING ›", UITheme.CORAL]
			return ["›", UITheme.MUTED]
		"range":
			return [_format_value(value), UITheme.AQUA if changed else UITheme.INK_SOFT]
	return ["", UITheme.MUTED]


func _refresh_row(key: String) -> void:
	var row: Row = _rows.get(key)
	if row == null:
		return
	var shown := _value_text(key)
	var meta: Dictionary = _meta[key]
	var changed: bool = (meta.kind == "range" and _value(key) != _default(key)) \
			or (meta.kind == "binding" and Controls.is_rebound(meta.action, meta.pad))
	row.set_value(shown[0], shown[1], changed)
	row.modulate.a = 1.0 if is_editable(key) else 0.45


## A slider's value as its row shows it: whole numbers without decimals.
static func _format_value(value: Variant) -> String:
	if value is int:
		return str(value)
	var text := "%.2f" % value
	if absf(value) >= 100.0:
		text = "%.1f" % value
	return text


func _title_of(key: String) -> String:
	if GAME_OPTIONS.has(key):
		return GAME_OPTIONS[key][0]
	if _meta.has(key) and _meta[key].has("title"):
		return _meta[key].title
	return key.get_slice("/", 1).capitalize()


# --- Navigation and the detail pane ------------------------------------------

func _show_section(section: String) -> void:
	_section = section
	for id: String in _section_lists:
		_section_lists[id].visible = id == section
	for id: String in _section_buttons:
		(_section_buttons[id] as SectionButton).current = id == section
	for entry: Array in SECTIONS:
		if entry[0] == section:
			_title.text = entry[1]
	_subtitle.text = ""
	_show_tab(section, _tab_at.get(section, 0))
	_show_first_detail(section)


## The detail pane for the first option shown in `section`.
func _show_first_detail(section: String) -> void:
	var first := _first_row(section)
	if first:
		_show_detail(first.key)


## Focus into `section`'s options (its first one).
func _focus_rows(section: String) -> void:
	_show_section(section)
	var first := _first_row(section)
	if first:
		first.grab_focus()


func _first_row(section: String) -> Row:
	for child in _shown_list(section).get_children():
		if child is Row and child.visible:
			return child
	return null


## Up/down between the shown rows only, stopping at the ends; left/right stay
## put (they change the value).
func _link_rows(section: String) -> void:
	var shown: Array[Row] = []
	for child in _shown_list(section).get_children():
		if child is Row and child.visible:
			shown.append(child)
	for i in shown.size():
		var row := shown[i]
		row.focus_neighbor_top = row.get_path_to(shown[maxi(i - 1, 0)])
		row.focus_neighbor_bottom = row.get_path_to(shown[mini(i + 1, shown.size() - 1)])
		row.focus_neighbor_left = row.get_path_to(row)
		row.focus_neighbor_right = row.get_path_to(row)


## The next (+1) or previous (-1) section (LT / RT), at the tab it was left on.
func _step_section(direction: int) -> void:
	var at := 0
	for i in SECTIONS.size():
		if SECTIONS[i][0] == _section:
			at = i
	for n in SECTIONS.size():
		var next: String = SECTIONS[posmod(at + direction * (n + 1), SECTIONS.size())][0]
		if (_section_buttons[next] as Button).visible:
			_step_section_to(next)
			return


## Over to `section`, focus staying in its column (the section buttons or the options).
func _step_section_to(section: String) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Row or (focus != null and _detail.is_ancestor_of(focus)):
		_focus_rows(section)
	else:
		_show_section(section)
		(_section_buttons[section] as Button).grab_focus()


## Three columns, each a step in: the sections, a section's options, the
## detail pane. A (or right) goes a column in; B goes a column back, and so
## does left from an option (left / right only change a value in the detail
## pane, where it's plain what they're changing).
func _to_sections() -> void:
	(_section_buttons[_section] as Button).grab_focus()


func _in_detail(focus: Control) -> bool:
	return focus != null and _detail.is_ancestor_of(focus)


## Into the detail pane for the shown option, focus on its control: the
## current On / Off, the slider, the name to type, or the dropdown (opened
## straight away when `open_list`). False when the option has nothing there to
## change (an action or a binding: A on its row does it).
func _enter_detail(open_list := true) -> bool:
	var kind: String = _meta.get(_detail_key, {}).get("kind", "")
	var fallback: Control
	for control: Control in _detail_control.find_children("*", "Control", true, false):
		match kind:
			"enum":
				if control is OptionButton:
					control.grab_focus()
					if open_list and not (control as OptionButton).disabled:
						(control as OptionButton).show_popup()
					return true
			"bool":
				if control is ChoiceButton:
					if (control as ChoiceButton).current:
						control.grab_focus()
						return true
					if fallback == null:
						fallback = control
			"range":
				if control is DetailSlider:
					control.grab_focus()
					return true
			"text":
				if control is LineEdit:
					control.grab_focus()
					(control as LineEdit).select_all()
					return true
	if fallback:
		fallback.grab_focus()
		return true
	return false


## The detail pane's controls keep focus in the pane: up / down go nowhere,
## left / right only between controls side by side (On and Off).
func _confine_detail_focus() -> void:
	for control: Control in _detail_control.find_children("*", "Control", true, false):
		if control.focus_mode != Control.FOCUS_ALL:
			continue
		var mates: Array = [control]
		if control.get_parent() is HBoxContainer:
			mates = control.get_parent().get_children().filter(func(other: Node) -> bool:
				return other is Control and (other as Control).focus_mode == Control.FOCUS_ALL)
		var at := mates.find(control)
		control.focus_neighbor_top = control.get_path_to(control)
		control.focus_neighbor_bottom = control.get_path_to(control)
		control.focus_neighbor_left = control.get_path_to(mates[maxi(at - 1, 0)])
		control.focus_neighbor_right = control.get_path_to(mates[mini(at + 1, mates.size() - 1)])
		control.focus_previous = control.focus_neighbor_left
		control.focus_next = control.focus_neighbor_right


## The hints and the back arrows follow the column focus is in.
func _on_focus_changed(_focus: Control) -> void:
	if is_open():
		_refresh_hints()


func _refresh_hints() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var tabs: Array = [["LB/RB", "Tab"]] if _visible_tabs(_section).size() > 1 else []
	var in_detail := _in_detail(focus)
	if in_detail:
		var kind: String = _meta.get(_detail_key, {}).get("kind", "")
		match kind:
			"range":
				_hints.hints = [["◀ ▶", "Adjust"], ["Y", "Default"], ["B", "Back"]]
			"bool":
				_hints.hints = [["◀ ▶", "Choose"], ["A", "Set"], ["Y", "Default"], ["B", "Back"]]
			"enum":
				_hints.hints = [["A", "Choose"], ["Y", "Default"], ["B", "Back"]]
			_:
				_hints.hints = [["B", "Back"]]
	elif focus is Row:
		var verb: String = {"binding": "Rebind", "action": "Select"}.get(_meta.get((focus as Row).key, {}).get("kind", ""), "Change")
		_hints.hints = tabs + [["LT/RT", "Section"], ["A", verb], ["Y", "Default"], ["SELECT", "Debug tweaks"], ["B", "Back"]]
	else:
		_hints.hints = tabs + [["LT/RT", "Section"], ["A", "Open"], ["SELECT", "Debug tweaks"], ["B", "Close"]]
	_show_back(_rows_back, focus is Row or in_detail)
	_show_back(_detail_back, in_detail)


## A back arrow shown or not, keeping its room either way (nothing jumps).
func _show_back(arrow: Button, shown: bool) -> void:
	arrow.modulate.a = 1.0 if shown else 0.0
	arrow.disabled = not shown
	arrow.mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE


## A ‹ button (and `text`) for the mouse, in aqua; controllers use B.
func _back_arrow(text: String, s: float) -> Button:
	var arrow := Button.new()
	arrow.text = "‹  " + text if text else "‹"
	arrow.focus_mode = Control.FOCUS_NONE
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.add_theme_font_override("font", UITheme.body(700))
	arrow.add_theme_font_size_override("font_size", roundi((16.0 if text else 30.0) * s))
	var clear := UITheme.box(Color(0, 0, 0, 0), 10.0 * s)
	var hover := UITheme.box(Color(UITheme.AQUA, 0.14), 10.0 * s)
	for box: StyleBoxFlat in [clear, hover]:
		box.set_content_margin(SIDE_LEFT, 10.0 * s)
		box.set_content_margin(SIDE_RIGHT, 12.0 * s)
		box.set_content_margin(SIDE_TOP, 2.0 * s)
		box.set_content_margin(SIDE_BOTTOM, 2.0 * s)
	for state in ["normal", "disabled", "focus"]:
		arrow.add_theme_stylebox_override(state, clear)
	arrow.add_theme_stylebox_override("hover", hover)
	arrow.add_theme_stylebox_override("pressed", hover)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		arrow.add_theme_color_override(state, UITheme.AQUA)
	return arrow


## The detail pane for option `key`: what it is, its control, its default.
func _show_detail(key: String) -> void:
	if key != _detail_key:
		_detail_scroll.scroll_vertical = 0  # a new option starts at its top
	var refocus := _in_detail(get_viewport().gui_get_focus_owner())  # rebuilt under focus: onto the new control
	_detail_key = key
	var meta: Dictionary = _meta.get(key, {})
	var section := key.get_slice("/", 0)
	var group: String = meta.get("group", "")
	var section_title := ""
	for entry: Array in SECTIONS:
		if entry[0] == section:
			section_title = entry[1]
	_subtitle.text = ("%s · %s" % [section_title, group]).to_upper()
	_detail_group.text = group.to_upper()
	_detail_title.text = _title_of(key)
	var words := ""
	if GAME_OPTIONS.has(key):
		words = GAME_OPTIONS[key][2]
	elif meta.has("event"):
		words = _sound_words(meta.event)
	else:
		words = SettingDocs.DOCS.get(key, "")
	_detail_text.text = words
	_detail_text.visible = not words.is_empty()
	var preview_path := PREVIEW_DIR.path_join(section).path_join(key.get_slice("/", 1) + ".png")
	_detail_preview.visible = ResourceLoader.exists(preview_path)
	_detail_preview.texture = load(preview_path) if _detail_preview.visible else null
	_detail_lock.visible = not is_editable(key)
	_detail_lock.text = (_lock_note if _lock_note else "Locked") if _locked.has(section) else "Not now: close the replay first." \
			if key in ["game/character", "game/species"] else "The host sets the tuning while you're online."
	for child in _detail_control.get_children():
		_detail_control.remove_child(child)  # now: _sync_detail mustn't see the last option's
		child.queue_free()
	_build_detail_control(key, meta)
	var used: String = GAME_OPTIONS[key][3] if GAME_OPTIONS.has(key) else USED_BY.get(section, "")
	var default_value: Variant = _default(key)
	var default_text := ""
	if meta.get("kind", "") != "action" and default_value != null:
		default_text = "Default: %s" % _shown(key, default_value)
	if used:
		default_text += ("  ·  " if default_text else "") + "Used by %s" % used
	_detail_default.text = default_text
	if refocus:
		_enter_detail(false)
	_refresh_hints()


## The Sound Board's words for event `id`: what it's for, how it plays, and the
## sound profile's files for it.
func _sound_words(id: String) -> String:
	var info := SoundCatalog.info(id)
	var kinds := PackedStringArray(["P%d" % info.priority, "3D (record mono)" if info.is_3d else "2D"])
	for flag: String in ["loop", "pitched", "layers"]:
		if info[flag]:
			kinds.append(flag)
	var words := "%s\n\n%s  ·  file: %s.wav" % [info.description, "  ·  ".join(kinds), id]
	var profile: SoundProfile = Sfx.active_profile()
	if profile == null:
		words += "\n\nSound profile None: nothing plays (A plays the placeholder beep)."
	elif profile.has(id) and profile.dir:
		words += "\n\nIn %s: %s" % [profile.title, ", ".join(profile.events[id].files)]
	elif SoundCatalog.FALLBACKS.has(id):
		words += "\n\nWithout its own, it uses %s." % SoundCatalog.FALLBACKS[id]
	return words


## How value `value` of option `key` reads in the pane ("On", "Brawlers", "12.50").
func _shown(key: String, value: Variant) -> String:
	var meta: Dictionary = _meta.get(key, {})
	match meta.get("kind", ""):
		"bool":
			return "On" if value else "Off"
		"enum":
			for choice: Array in meta.choices:
				if choice[1] == value:
					return str(choice[0])
		"range":
			return _format_value(value)
	return str(value)


func _build_detail_control(key: String, meta: Dictionary) -> void:
	var s := _s
	var editable := is_editable(key)
	match meta.get("kind", ""):
		"bool":
			var pair := HBoxContainer.new()
			for on: bool in [true, false]:
				var button := ChoiceButton.new()
				button.setup("On" if on else "Off", s)
				button.custom_minimum_size.x = 110.0 * s
				button.disabled = not editable
				button.pressed.connect(func() -> void: _set_value(key, on))
				button.set_meta(&"sfx", "ui/toggle_on" if on else "ui/toggle_off")
				button.set_meta("value", on)
				pair.add_child(button)
			_detail_control.add_child(pair)
		"enum":
			# One of a list: a dropdown (A on the row opens it).
			var dropdown := OptionButton.new()
			dropdown.custom_minimum_size.y = 48.0 * s
			dropdown.fit_to_longest_item = false
			dropdown.disabled = not editable
			var choices: Array = meta.choices
			for i in choices.size():
				dropdown.add_item(str(choices[i][0]), i)
			dropdown.item_selected.connect(func(index: int) -> void:
				_set_value(key, choices[index][1]))
			var list := dropdown.get_popup()
			list.max_size = Vector2i(0, roundi(get_viewport().get_visible_rect().size.y * 0.6))
			list.add_theme_constant_override("v_separation", roundi(12.0 * s))
			list.add_theme_constant_override("item_start_padding", roundi(14.0 * s))
			list.add_theme_constant_override("item_end_padding", roundi(14.0 * s))
			list.about_to_popup.connect(func() -> void:  # as wide as the dropdown (once it's sized itself)
				(func() -> void:
					list.size.x = maxi(list.size.x, roundi(dropdown.get_global_rect().size.x * dropdown.get_global_transform_with_canvas().get_scale().x))
				).call_deferred())
			_detail_control.add_child(dropdown)
		"range":
			var line := HBoxContainer.new()
			var slider := DetailSlider.new()
			slider.key = key
			slider.panel = self
			slider.min_value = meta.min
			slider.max_value = meta.max
			slider.step = meta.step
			slider.allow_greater = meta.allow_greater
			slider.allow_lesser = meta.allow_lesser
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slider.custom_minimum_size.y = 28.0 * s
			slider.editable = editable
			slider.set_value_no_signal(_value(key))
			slider.value_changed.connect(func(value: float) -> void: _set_value(key, value))
			line.add_child(slider)
			var number := UITheme.label(_format_value(_value(key)), "caps", 18.0, UITheme.AQUA, s, 700)
			number.custom_minimum_size.x = 70.0 * s
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			line.add_child(number)
			_detail_control.add_child(line)
			var ends := UITheme.label("%s – %s%s" % [_format_value(meta.min), _format_value(meta.max), "+" if meta.allow_greater else ""],
					"body", 13.0, UITheme.MUTED, s)
			_detail_control.add_child(ends)
		"text":
			var edit := LineEdit.new()
			edit.text = UISettings.player_name
			edit.placeholder_text = UISettings.DEFAULT_NAME
			edit.max_length = 20
			edit.text_changed.connect(func(text: String) -> void: UISettings.set_value("player_name", text))
			edit.text_submitted.connect(func(_text: String) -> void:
				if _rows.has(key):
					(_rows[key] as Row).grab_focus())
			_detail_control.add_child(edit)
		"action":
			var button := Button.new()
			button.text = _title_of(key)
			button.disabled = not editable
			button.pressed.connect(_act.bind(key))
			_detail_control.add_child(button)
		"binding":
			var listening := key == _capture_key
			var bound_text: String = ("Press a button…" if meta.pad else "Press a key…") if listening else str(_value(key))
			var bound := UITheme.label(bound_text, "caps", 22.0, UITheme.CORAL if listening else UITheme.AQUA, s, 700)
			bound.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detail_control.add_child(bound)
			var row := HBoxContainer.new()
			var rebind := Button.new()
			rebind.text = "Rebind"
			rebind.pressed.connect(_start_capture.bind(key))
			row.add_child(rebind)
			var reset := Button.new()
			reset.text = "Default"
			reset.disabled = not Controls.is_rebound(meta.action, meta.pad)
			reset.pressed.connect(_reset_option.bind(key))
			row.add_child(reset)
			_detail_control.add_child(row)
			var shared := PackedStringArray()
			for event in InputMap.action_get_events(meta.action):
				if Controls._is_pad(event) == meta.pad:
					for other in Controls.actions_on(event, meta.action):
						if other not in shared:
							shared.append(other)
			if not shared.is_empty():
				_detail_control.add_child(UITheme.label("Also on: %s" % ", ".join(shared), "body", 14.0, UITheme.CORAL, s))
	# Plain buttons on the pane's fill: the deep fill, so they show.
	for button in _detail_control.find_children("*", "Button", true, false):
		if not button is ChoiceButton:
			var deep := UITheme.box(UITheme.DEEP, 12.0 * s)
			deep.set_content_margin(SIDE_LEFT, 18.0 * s)
			deep.set_content_margin(SIDE_RIGHT, 18.0 * s)
			deep.set_content_margin(SIDE_TOP, 8.0 * s)
			deep.set_content_margin(SIDE_BOTTOM, 8.0 * s)
			button.add_theme_stylebox_override("normal", deep)
			button.add_theme_stylebox_override("disabled", deep)
	_confine_detail_focus()
	_sync_detail()


## The detail control shows the option's value now (changed from a row).
func _sync_detail() -> void:
	var value: Variant = _value(_detail_key)
	for child in _detail_control.get_children():
		if child is ChoiceButton:
			(child as ChoiceButton).current = child.get_meta("value") == value
		elif child is OptionButton:
			var choices: Array = _meta[_detail_key].choices
			for i in choices.size():
				if choices[i][1] == value:
					(child as OptionButton).select(i)
		elif child is HBoxContainer:
			for inner in child.get_children():
				if inner is ChoiceButton:
					(inner as ChoiceButton).current = inner.get_meta("value") == value
				elif inner is HSlider:
					(inner as HSlider).set_value_no_signal(value)
				elif inner is Label:
					(inner as Label).text = _format_value(value)


## Where focus goes on B: from the detail pane back to its row, from a row to
## its section, from a section closed.
func _back() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and _detail.is_ancestor_of(focus) and _rows.has(_detail_key):
		(_rows[_detail_key] as Row).grab_focus()
	elif focus is Row:
		(_section_buttons[_section] as Button).grab_focus()
	else:
		set_open(false)


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if is_capturing():
		_capture_input(event)
		return
	var focus := get_viewport().gui_get_focus_owner()
	var typing := focus is LineEdit
	if event.is_echo() and (event.is_action("ui_up") or event.is_action("ui_down")) and (focus is Row or focus is SectionButton):
		get_viewport().set_input_as_handled()  # held: _process moves it, at its own pace
		return
	if not typing and ((event is InputEventJoypadButton and event.is_pressed() and (event as InputEventJoypadButton).button_index == JOY_BUTTON_BACK) \
			or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_F2)):
		_toggle_debug_tweaks()
	elif event.is_action_pressed("ui_page_previous") and not typing:
		_step_tab(-1)
	elif event.is_action_pressed("ui_page_next") and not typing:
		_step_tab(1)
	elif event.is_action_pressed("ui_reset") and not typing:
		if focus is Row:
			_reset_option((focus as Row).key)
		elif focus != null and _detail.is_ancestor_of(focus):
			_reset_option(_detail_key)
		else:
			return
	elif event.is_action_pressed("ui_cancel"):
		_back()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open():
		return
	if is_capturing():
		_capture_age += delta
		if _capture_age >= CAPTURE_TIME:
			_end_capture(null)
		else:
			_refresh_row(_capture_key)  # the countdown
		return
	# LT / RT (Home / End): whole sections (the triggers are sticks to Godot, so on their edge).
	var focus := get_viewport().gui_get_focus_owner()
	if not focus is LineEdit:
		for pair: Array in [["ui_section_previous", -1], ["ui_section_next", 1]]:
			if _trigger_pulled(pair[0]):
				_step_section(pair[1])
	_scroll_held_list(delta, get_viewport().gui_get_focus_owner())
	# Left/right on the detail pane's slider: a step as it goes down, then held,
	# it repeats (controllers don't echo). What was held coming onto the slider
	# (right from its row) doesn't count until it's let go.
	var direction := 0
	if focus is DetailSlider:
		direction = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	if focus != _repeat_focus:
		_repeat_focus = focus
		_repeat_dir = direction
		_repeat_time = -REPEAT_DELAY if direction == 0 else -INF
		return
	if direction != _repeat_dir:
		_repeat_dir = direction
		_repeat_time = -REPEAT_DELAY
		if direction != 0:
			_step((focus as DetailSlider).key, direction)
		return
	if direction == 0 and focus is DetailSlider:
		# Down and up again within a frame (a quick tap): still a step.
		var tapped := int(Input.is_action_just_pressed("ui_right")) - int(Input.is_action_just_pressed("ui_left"))
		if tapped != 0:
			_step((focus as DetailSlider).key, tapped)
		return
	if direction == 0:
		return
	_repeat_time += delta
	while _repeat_time >= REPEAT_EVERY:
		_repeat_time -= REPEAT_EVERY
		_step((focus as DetailSlider).key, direction)


## Held up/down on an option or a section: after SCROLL_DELAY focus keeps
## moving that way (the first step is the press itself, Godot's own), quicker
## the longer it's held, stopping at the end of the list.
func _scroll_held_list(delta: float, focus: Control) -> void:
	var direction := 0
	if focus is Row or focus is SectionButton:
		direction = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	if direction == 0 or direction != _scroll_dir:
		_scroll_dir = direction
		_scroll_held = 0.0
		_scroll_time = -SCROLL_DELAY
		return
	_scroll_held += delta
	_scroll_time += delta
	var every := SCROLL_FAST if _scroll_held >= SCROLL_FAST_AFTER else SCROLL_EVERY
	while _scroll_time >= every:
		_scroll_time -= every
		var next := focus.find_valid_focus_neighbor(SIDE_BOTTOM if direction > 0 else SIDE_TOP)
		if next == null or next == focus:
			return  # the end of the list
		next.grab_focus()
		focus = next


var _triggers_held := {}


## Whether `action` (a trigger past half way, or its key) went down since the
## last frame; it has to come back up before it counts again.
func _trigger_pulled(action: String) -> bool:
	var held := Input.is_action_pressed(action)
	var pulled: bool = held and not _triggers_held.get(action, false)
	_triggers_held[action] = held
	return pulled


## Hides options a target says don't apply right now (via an optional
## is_option_active(property) method), and headings left with none.
func _refresh_visibility() -> void:
	var debug := UISettings.show_debug_tweaks
	for key: String in _rows:
		var section := key.get_slice("/", 0)
		var active := true
		if _targets.has(section):
			var target: Object = _targets[section]
			active = not target.has_method("is_option_active") or target.is_option_active(key.get_slice("/", 1))
		_rows[key].visible = active and key not in HIDDEN and (debug or _is_everyday(key))
	for heading: Label in _group_headings:
		heading.visible = _group_headings[heading].any(func(key: String) -> bool: return _rows[key].visible)
	for id: String in _section_buttons:
		(_section_buttons[id] as Button).visible = _section_has_rows(id)
	_link_sections()
	if _section_lists.has(_section):
		if not (_section_buttons[_section] as Button).visible:
			_section = "game"
		_link_rows(_section)


## Whether option `key` shows without Show Debug Tweaks.
func _is_everyday(key: String) -> bool:
	var section := key.get_slice("/", 0)
	return section in ["controls", "camera"] or key in EVERYDAY or (section == "fish" and _meta.get(key, {}).get("group", "") == "Controller")


func _section_has_rows(section: String) -> bool:
	for key: String in _rows:
		if key.get_slice("/", 0) == section and _rows[key].visible:
			return true
	return false


## Up/down through the sections shown only, stopping at the ends (held, it keeps going).
func _link_sections() -> void:
	var shown: Array[Button] = []
	for id: String in _section_buttons:
		if (_section_buttons[id] as Button).visible:
			shown.append(_section_buttons[id])
	for i in shown.size():
		shown[i].focus_neighbor_top = shown[i].get_path_to(shown[maxi(i - 1, 0)])
		shown[i].focus_neighbor_bottom = shown[i].get_path_to(shown[mini(i + 1, shown.size() - 1)])


## The tabs of `section` with something to show.
func _visible_tabs(section: String) -> Array:
	var shown := []
	for tab: Dictionary in _tabs.get(section, []):
		if (tab.list as Control).get_children().any(func(child: Node) -> bool: return child is Row and (child as Row).visible):
			shown.append(tab)
	return shown


## SELECT (or F2) turns Show Debug Tweaks on or off.
func _toggle_debug_tweaks() -> void:
	UISettings.set_value("show_debug_tweaks", not UISettings.show_debug_tweaks)
	_refresh_visibility()
	var focus := get_viewport().gui_get_focus_owner()
	_show_section(_section)
	if focus is Row and not (focus as Row).is_visible_in_tree():
		(_section_buttons[_section] as Button).grab_focus()
	var on := UISettings.show_debug_tweaks
	Sfx.play("ui/toggle_on" if on else "ui/toggle_off")
	show_status("Debug tweaks %s" % ("on: every tuning option shows" if on else "off: only the everyday settings show"))


# --- Tuning model -------------------------------------------------------------

## Script variables exported as a float or int range, a bool or an enum, tagged with their @export_group.
func _tunable_properties(target: Object) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var group := ""
	for property in target.get_property_list():
		if property.usage & PROPERTY_USAGE_GROUP:
			group = property.name
			continue
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (property.usage & PROPERTY_USAGE_EDITOR):
			continue
		var is_range: bool = property.type in [TYPE_FLOAT, TYPE_INT] and property.hint == PROPERTY_HINT_RANGE
		var is_enum: bool = property.type == TYPE_INT and property.hint == PROPERTY_HINT_ENUM
		if is_range or is_enum or property.type == TYPE_BOOL:
			var entry: Dictionary = property.duplicate()
			entry["group"] = group
			result.append(entry)
	return result


func _snapshot(target: Object) -> Dictionary:
	var values := {}
	for property in _tunable_properties(target):
		values[property.name] = target.get(property.name)
	return values


## Puts `values` (property -> value) on `section`'s target, as a preset or a
## restore does (past a slider's end too).
func _apply(section: String, values: Dictionary) -> void:
	var target: Object = _targets[section]
	for prop: String in values:
		var key := "%s/%s" % [section, prop]
		if not _rows.has(key):
			continue
		var value: Variant = values[prop]
		if target.get(prop) is int:
			value = roundi(value)
		target.set(prop, value)
		_refresh_row(key)
	if _detail_key.begins_with(section + "/"):
		_sync_detail()
	tuning_changed.emit()


func _to_config() -> ConfigFile:
	var config := ConfigFile.new()
	config.set_value("meta", "version", TUNING_VERSION)
	for section: String in _targets:
		var values := _snapshot(_targets[section])
		for prop: String in values:
			config.set_value(section, prop, values[prop])
	return config


## Copies the shipped presets into PRESET_DIR (without replacing any there), so
## Load finds them.
func _export_presets() -> void:
	DirAccess.make_dir_recursive_absolute(PRESET_DIR)
	for file in DirAccess.get_files_at(BUNDLED_PRESET_DIR):
		var target := PRESET_DIR.path_join(file)
		if file.get_extension() == "cfg" and not FileAccess.file_exists(target):
			var out := FileAccess.open(target, FileAccess.WRITE)
			if out:
				out.store_string(FileAccess.get_file_as_string(BUNDLED_PRESET_DIR.path_join(file)))


## The preset last saved or loaded, else what Save wrote before presets. Not
## in test probes, which run on the defaults.
func _load_startup_preset() -> void:
	if get_tree().current_scene != get_parent():
		return
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	var path: String = settings.get_value("tuning", "preset", "")
	if path.is_empty() or not FileAccess.file_exists(path):
		path = LEGACY_SAVE_PATH
	if FileAccess.file_exists(path):
		_load_preset(path)


## Save (Save As) or Load a preset file, in a native picker that opens in
## PRESET_DIR.
func _pick_preset(saving: bool) -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.title = "Save tuning preset" if saving else "Load tuning preset"
	dialog.filters = PackedStringArray(["*.cfg ; Tuning presets"])
	dialog.current_dir = ProjectSettings.globalize_path(PRESET_DIR)
	if saving:
		dialog.current_file = "my_preset.cfg"
	dialog.file_selected.connect(func(path: String) -> void:
		if saving:
			_save_preset(path)
		else:
			_load_preset(path)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)


func _save_preset(path: String) -> void:
	var error := _to_config().save(path)
	if error != OK:
		_status.text = "Save failed: %s" % error_string(error)
		return
	_remember_preset(path)
	_status.text = "Saved %s" % path.get_file()


## Defaults first, then the preset's values on top, so a preset only needs to
## list what it changes.
func _load_preset(path: String) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		_status.text = "Couldn't load %s" % path
		return
	for section: String in _targets:
		_apply(section, _defaults[section])
		if config.has_section(section):
			var values := {}
			for prop in config.get_section_keys(section):
				values[prop] = config.get_value(section, prop)
			_apply(section, values)
	_refresh_visibility()
	if not path.begins_with("res://") and path != LEGACY_SAVE_PATH:
		_remember_preset(path)
	_status.text = "Loaded %s" % path.get_file()


## Locks `sections` (shown, not editable) or unlocks them, e.g. an online
## guest's fish and Nature tuning, which are the host's. Loading a preset or
## the defaults would change them too, so those wait until they're unlocked.
func set_sections_locked(sections: Array, locked: bool, note := "") -> void:
	for section: String in sections:
		if locked:
			_locked[section] = true
		else:
			_locked.erase(section)
	if locked and note:
		_lock_note = note
		_status.text = note
	elif _locked.is_empty():
		_lock_note = ""
	for key: String in _rows:
		_refresh_row(key)
	if not _detail_key.is_empty():
		_show_detail(_detail_key)


## Every section's tuning now, for restore_tuning().
func tuning_snapshot() -> Dictionary:
	var snapshot := {}
	for section: String in _targets:
		snapshot[section] = _snapshot(_targets[section])
	return snapshot


func restore_tuning(snapshot: Dictionary) -> void:
	for section: String in snapshot:
		_apply(section, snapshot[section])
	_refresh_visibility()


## A mode's own tuning (e.g. Nature's): for each section the file lists, the
## defaults with its values on top; other sections are left as they are. Not
## remembered for startup.
func load_mode_preset(path: String) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		push_warning("Couldn't load mode preset %s" % path)
		return
	for section: String in _targets:
		if not config.has_section(section):
			continue
		_apply(section, _defaults[section])
		var values := {}
		for prop in config.get_section_keys(section):
			values[prop] = config.get_value(section, prop)
		_apply(section, values)
	_refresh_visibility()
	_status.text = "%s tuning" % path.get_file().get_basename().capitalize()


## Loaded at startup from now on.
func _remember_preset(path: String) -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("tuning", "preset", path)
	settings.save(SETTINGS_PATH)


func _restore_defaults() -> void:
	for section: String in _targets:
		_apply(section, _defaults[section])
	_refresh_visibility()
	_status.text = "Default tuning (not saved)"


func _copy_to_clipboard() -> void:
	DisplayServer.clipboard_set(_to_config().encode_to_text())
	_status.text = "Copied current tuning to clipboard"


## A section in the left column: the current one gets the panel fill and an
## aqua bar on its right edge.
class SectionButton extends Button:
	var id := ""
	var panel: Node
	var current := false:
		set(value):
			current = value
			add_theme_stylebox_override("normal", _current if value else _clear)
			add_theme_color_override("font_color", UITheme.INK if value else UITheme.MUTED)
			_bar.visible = value
	var _clear: StyleBoxFlat
	var _current: StyleBoxFlat
	var _bar := ColorRect.new()

	func setup(section: String, title: String, s: float) -> void:
		id = section
		text = title
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		custom_minimum_size.y = 46.0 * s
		action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		add_theme_font_override("font", UITheme.body(600))
		add_theme_font_size_override("font_size", roundi(17.0 * s))
		_clear = UITheme.box(Color(0, 0, 0, 0), 12.0 * s)
		_current = UITheme.box(UITheme.PANEL, 12.0 * s)
		var hover := UITheme.box(Color(UITheme.PANEL, 0.6), 12.0 * s)
		for box: StyleBoxFlat in [_clear, _current, hover]:
			box.set_content_margin(SIDE_LEFT, 16.0 * s)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", hover)
		add_theme_color_override("font_hover_color", UITheme.INK)
		add_theme_color_override("font_focus_color", UITheme.INK)
		# The current section's 3 px aqua bar on its right edge.
		_bar.color = UITheme.AQUA
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.anchor_left = 1.0
		_bar.anchor_right = 1.0
		_bar.anchor_bottom = 1.0
		_bar.offset_left = -3.0 * s
		_bar.offset_top = 8.0 * s
		_bar.offset_bottom = -8.0 * s
		add_child(_bar)
		current = false

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventJoypadMotion and (event.is_action("ui_left") or event.is_action("ui_right")):
			accept_event()  # the stick stays in the column (a sideways wobble mustn't cross): the d-pad or A
		elif event.is_action_pressed("ui_right"):
			pressed.emit()
			accept_event()


## One option in the middle column: its name on the left, its value on the
## right in condensed caps. A (or right) goes into the detail pane to change
## it (a binding waits for its key, an action runs); left goes back to the sections.
class Row extends Button:
	var key := ""
	var panel: Node
	var _name: Label
	var _value: Label
	var _dot: Control

	func setup(owner_panel: Node, option: String, title: String, s: float) -> void:
		panel = owner_panel
		key = option
		custom_minimum_size.y = 56.0 * s
		action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		var line := HBoxContainer.new()
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 18.0 * s
		line.offset_right = -18.0 * s
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
		_name = UITheme.label(title, "body", 17.0, UITheme.INK, s, 500)
		_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_name.clip_text = true
		line.add_child(_name)
		_dot = ColorRect.new()
		_dot.color = UITheme.CORAL
		_dot.custom_minimum_size = Vector2(6.0, 6.0) * s
		_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dot.visible = false
		line.add_child(_dot)
		_value = Label.new()
		var px := roundi(18.0 * s)
		_value.add_theme_font_override("font", UITheme.caps(px, 600, 0.08))
		_value.add_theme_font_size_override("font_size", px)
		_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(_value)
		focus_entered.connect(func() -> void: panel._show_detail(key))
		mouse_entered.connect(func() -> void:
			if not has_focus():
				grab_focus())
		pressed.connect(_on_accept)

	func set_value(text: String, color: Color, changed: bool) -> void:
		_value.text = text
		_value.add_theme_color_override("font_color", color)
		_dot.visible = changed

	func _on_accept() -> void:
		var kind: String = panel._meta[key].kind
		match kind:
			"binding":
				panel._start_capture(key)
			"action":
				panel._act(key)
			_:
				if not has_focus():
					grab_focus()  # clicked: this row's detail first
				panel._enter_detail()

	## A stick push matches both ui_left and ui_right (the axis, not its sign),
	## so the direction is from is_action_pressed; and the stick never crosses
	## columns (the d-pad does).
	func _gui_input(event: InputEvent) -> void:
		if event.is_action("ui_left") or event.is_action("ui_right"):
			if not event is InputEventJoypadMotion:
				if event.is_action_pressed("ui_left"):
					panel._to_sections()
				elif event.is_action_pressed("ui_right") and panel._meta[key].kind not in ["binding", "action"]:
					panel._enter_detail()
			accept_event()


## The detail pane's slider: left / right (keys, d-pad, stick) step it from the
## panel's _process, which reads the held direction (so a stick pushed left is
## never a step right) and repeats it; the mouse drags it; up / down stay put.
class DetailSlider extends HSlider:
	var key := ""
	var panel: Node

	func _gui_input(event: InputEvent) -> void:
		for action: String in ["ui_left", "ui_right", "ui_up", "ui_down"]:
			if event.is_action(action):
				accept_event()
				return


## A tab in the bar over a big section's options: the current one in aqua,
## underlined. Clicking one shows it (LB / RB step through them).
class TabButton extends Button:
	func setup(title: String, current: bool, s: float) -> void:
		text = title
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size.y = 40.0 * s
		add_theme_font_override("font", UITheme.body(600))
		add_theme_font_size_override("font_size", roundi(16.0 * s))
		var fill := UITheme.box(Color(UITheme.AQUA, 0.12) if current else Color(0, 0, 0, 0), 10.0 * s)
		fill.set_content_margin(SIDE_LEFT, 16.0 * s)
		fill.set_content_margin(SIDE_RIGHT, 16.0 * s)
		var hover := UITheme.box(Color(UITheme.PANEL, 0.8), 10.0 * s)
		hover.set_content_margin(SIDE_LEFT, 16.0 * s)
		hover.set_content_margin(SIDE_RIGHT, 16.0 * s)
		add_theme_stylebox_override("normal", fill)
		add_theme_stylebox_override("hover", hover if not current else fill)
		add_theme_stylebox_override("pressed", fill)
		add_theme_color_override("font_color", UITheme.AQUA if current else UITheme.MUTED)
		add_theme_color_override("font_hover_color", UITheme.AQUA if current else UITheme.INK)
		if current:
			var line := ColorRect.new()
			line.color = UITheme.AQUA
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.anchor_top = 1.0
			line.anchor_right = 1.0
			line.anchor_bottom = 1.0
			line.offset_left = 12.0 * s
			line.offset_right = -12.0 * s
			line.offset_top = -3.0 * s
			add_child(line)


## A choice in the detail pane (On / Off, an enum's options): the current one
## in aqua.
class ChoiceButton extends Button:
	var current := false:
		set(value):
			current = value
			add_theme_color_override("font_color", UITheme.AQUA if value else UITheme.INK_SOFT)
			add_theme_stylebox_override("normal", _on if value else _off)
	var _on: StyleBoxFlat
	var _off: StyleBoxFlat

	func setup(title: String, s: float) -> void:
		text = title
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		custom_minimum_size.y = 44.0 * s
		_off = UITheme.box(UITheme.DEEP, 12.0 * s)
		_on = UITheme.box(Color(UITheme.AQUA, 0.14), 12.0 * s, Color(UITheme.AQUA, 0.6), maxf(1.0, 1.5 * s))
		for box: StyleBoxFlat in [_on, _off]:
			box.set_content_margin(SIDE_LEFT, 16.0 * s)
			box.set_content_margin(SIDE_RIGHT, 16.0 * s)
		current = false
