extends CanvasLayer
## Live tuning panel. Lists every @export_range float, @export bool and @export
## enum on the fish, the camera and the ball settings, writes changes to them
## immediately, and saves/loads them as preset files. Add a new export to any of
## them and it appears here, in a collapsible panel for its @export_group (all
## start collapsed). A target can hide options that don't apply with
## is_option_active(). Also picks the mode (main.gd's MODES) and the fish's
## character (FishCharacter), and has the Gameplay and UI settings (UISettings).
##
## Shown from the pause menu's Settings (PauseMenu), so it runs while the game
## is paused. Controls are mouse-only (no keyboard/gamepad focus), so the
## controller stays on the pause menu.

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

@export var fish: FishController
@export var follow_camera: Camera3D
@export var ball_settings: BallSettings

var _targets := {}
var _defaults := {}
var _editors := {}  # "section/property" -> HSlider, CheckBox or OptionButton
var _value_labels := {}  # "section/property" -> a slider's value Label
var _rows := {}  # "section/property" -> the control to hide when the option doesn't apply
var _group_panels := {}  # group's FoldableContainer -> its "section/property" keys
var _panel: PanelContainer
var _status: Label
var _mode_row: HBoxContainer
var _mode_picker: OptionButton
var _character_picker: OptionButton
var _load_button: Button
var _default_button: Button
## Sections someone else sets (an online session's host): shown, not editable.
var _locked := {}

signal mode_selected(mode: String)
signal character_selected(character: FishCharacter.Family)
## Any tuning value changed (a control, a preset, a restore): whatever copies
## the tuning (other local players' fish, an online session) can follow.
signal tuning_changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 7  # over the pause menu's dimming
	_targets = {"fish": fish, "camera": follow_camera, "ball": ball_settings, "nature": NatureSettings.shared()}
	for section: String in _targets:
		_defaults[section] = _snapshot(_targets[section])
	_build_ui()
	_panel.visible = false
	_export_presets()
	_load_startup_preset()


func is_open() -> bool:
	return _panel.visible


func set_open(open: bool) -> void:
	_panel.visible = open


func _build_ui() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.08, 0.88)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 12.0
	_panel.offset_top = 12.0
	_panel.offset_right = 452.0
	_panel.offset_bottom = -48.0
	add_child(_panel)

	var root := VBoxContainer.new()
	_panel.add_child(root)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)

	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	buttons.add_child(_button("Save...", _pick_preset.bind(true)))
	_load_button = _button("Load...", _pick_preset.bind(false))
	buttons.add_child(_load_button)
	_default_button = _button("Default", _restore_defaults)
	buttons.add_child(_default_button)
	buttons.add_child(_button("Copy", _copy_to_clipboard))

	# Hidden for now: just the one profile (Controls.DEFAULT_PROFILE).
	var profile_row := HBoxContainer.new()
	profile_row.visible = false
	root.add_child(profile_row)
	var profile_label := Label.new()
	profile_label.text = "Controller profile"
	profile_row.add_child(profile_label)
	var profiles := OptionButton.new()
	profiles.focus_mode = Control.FOCUS_NONE
	for profile_name: String in Controls.profile_names():
		profiles.add_item(profile_name)
		if profile_name == Controls.current_profile:
			profiles.select(profiles.item_count - 1)
	profiles.item_selected.connect(func(index: int) -> void:
		Controls.apply_profile(profiles.get_item_text(index))
		_status.text = "Controller profile: %s (remembered on this PC)" % Controls.current_profile)
	profile_row.add_child(profiles)

	_mode_row = HBoxContainer.new()  # filled in by set_modes()
	root.add_child(_mode_row)

	var character_row := HBoxContainer.new()
	root.add_child(character_row)
	var character_label := Label.new()
	character_label.text = "Character"
	character_row.add_child(character_label)
	_character_picker = OptionButton.new()
	_character_picker.focus_mode = Control.FOCUS_NONE
	for family: FishCharacter.Family in FishCharacter.CARS:
		_character_picker.add_item(FishCharacter.display_name(family), family)
	_character_picker.item_selected.connect(func(index: int) -> void:
		character_selected.emit(_character_picker.get_item_id(index))
		_status.text = "Character: %s (remembered on this PC)" % _character_picker.get_item_text(index))
	character_row.add_child(_character_picker)

	_status = Label.new()
	_status.modulate = Color(1, 1, 1, 0.6)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	_build_game_section(list)
	for section: String in _targets:
		_build_section(list, section, _targets[section])


## Gameplay and display preferences (UISettings): saved on this PC as they
## change, not with the tuning.
func _build_game_section(list: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "GAME"
	header.add_theme_font_size_override("font_size", 18)
	list.add_child(header)

	var gameplay := _foldable(list, "Gameplay")
	var checks := {}
	checks["goal_replays"] = _ui_check(gameplay, "goal_replays", "Goal replays (1v1)")
	var name_row := HBoxContainer.new()
	gameplay.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Player name"
	name_label.custom_minimum_size.x = 170.0
	name_row.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.text = UISettings.player_name
	name_edit.placeholder_text = UISettings.DEFAULT_NAME
	name_edit.max_length = 20
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(text: String) -> void: UISettings.set_value("player_name", text))
	name_edit.text_submitted.connect(func(_text: String) -> void: name_edit.release_focus())
	name_row.add_child(name_edit)

	var ui := _foldable(list, "UI")
	for entry: Array in [["show_stats", "Show stats panel (speed, drift, ...)"],
			["show_input_overlay", "Show controller overlay"],
			["fullscreen", "Fullscreen (F11)"]]:
		checks[entry[0]] = _ui_check(ui, entry[0], entry[1])
	# Follow changes made elsewhere (F11).
	UISettings.changed.connect(func(key: String) -> void:
		if checks.has(key):
			checks[key].set_pressed_no_signal(UISettings.get(key)))
	list.add_child(HSeparator.new())


## A CheckBox in `parent` for the UISettings bool `key`.
func _ui_check(parent: Control, key: String, text: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.focus_mode = Control.FOCUS_NONE
	check.button_pressed = UISettings.get(key)
	check.toggled.connect(func(on: bool) -> void: UISettings.set_value(key, on))
	parent.add_child(check)
	return check


## A collapsible (and collapsed) panel titled `title` in `list`; returns the
## list to fill it with.
func _foldable(list: VBoxContainer, title: String) -> VBoxContainer:
	var panel := FoldableContainer.new()
	panel.title = title
	panel.folded = true
	panel.focus_mode = Control.FOCUS_NONE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(panel)
	var contents := VBoxContainer.new()
	panel.add_child(contents)
	return contents


func show_status(text: String) -> void:
	_status.text = text


## Shows `character` as picked in the Character row (selections are reported
## via character_selected).
func set_character(character: FishCharacter.Family) -> void:
	_character_picker.select(_character_picker.get_item_index(character))


## The character can only be changed while playing, not during a replay.
func set_character_enabled(enabled: bool) -> void:
	_character_picker.disabled = not enabled
	_character_picker.tooltip_text = "" if enabled else "Close the replay to change character"


## Adds the mode picker; selections are reported via mode_selected.
func set_modes(names: Array, current: String) -> void:
	var label := Label.new()
	label.text = "Mode"
	_mode_row.add_child(label)
	_mode_picker = OptionButton.new()
	_mode_picker.focus_mode = Control.FOCUS_NONE
	for mode: String in names:
		_mode_picker.add_item(mode)
	set_mode(current)
	_mode_picker.item_selected.connect(func(index: int) -> void:
		var mode := _mode_picker.get_item_text(index)
		mode_selected.emit(mode)
		_status.text = "Mode: %s" % mode)
	_mode_row.add_child(_mode_picker)


## Shows `mode` as picked (selections are reported via mode_selected).
func set_mode(mode: String) -> void:
	if _mode_picker == null:
		return
	for i in _mode_picker.item_count:
		if _mode_picker.get_item_text(i) == mode:
			_mode_picker.select(i)


func _build_section(list: VBoxContainer, section: String, target: Object) -> void:
	var header := Label.new()
	header.text = section.to_upper()
	header.add_theme_font_size_override("font_size", 18)
	list.add_child(header)

	var shown_group := ""
	var group_panel: FoldableContainer
	var group_list: VBoxContainer
	for property in _tunable_properties(target):
		var prop: String = property.name
		var key := "%s/%s" % [section, prop]
		if group_panel == null or property.group != shown_group:
			shown_group = property.group
			group_list = _foldable(list, shown_group if shown_group else "General")
			group_panel = group_list.get_parent()
			_group_panels[group_panel] = []
		_group_panels[group_panel].append(key)

		var editor: Control
		if property.type == TYPE_BOOL:
			var check := CheckBox.new()
			check.text = prop.capitalize()
			check.button_pressed = target.get(prop)
			check.toggled.connect(func(on: bool) -> void:
				target.set(prop, on)
				tuning_changed.emit()
				_refresh_visibility())
			editor = check
			group_list.add_child(check)
			_rows[key] = check
		elif property.hint == PROPERTY_HINT_ENUM:
			var row := HBoxContainer.new()
			var name_label := Label.new()
			name_label.text = prop.capitalize()
			name_label.custom_minimum_size.x = 170.0
			name_label.tooltip_text = prop
			row.add_child(name_label)
			var picker := OptionButton.new()
			for option: String in property.hint_string.split(","):
				var parts := option.split(":")
				picker.add_item(parts[0], parts[1].to_int() if parts.size() > 1 else picker.item_count)
			picker.select(picker.get_item_index(target.get(prop)))
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			picker.item_selected.connect(func(index: int) -> void:
				target.set(prop, picker.get_item_id(index))
				tuning_changed.emit()
				_refresh_visibility())
			row.add_child(picker)
			editor = picker
			group_list.add_child(row)
			_rows[key] = row
		else:
			var row := HBoxContainer.new()
			var name_label := Label.new()
			name_label.text = prop.capitalize()
			name_label.custom_minimum_size.x = 170.0
			name_label.tooltip_text = prop
			row.add_child(name_label)

			var range_parts: PackedStringArray = property.hint_string.split(",")
			var whole: bool = property.type == TYPE_INT
			var slider := HSlider.new()
			slider.min_value = range_parts[0].to_float()
			slider.max_value = range_parts[1].to_float()
			slider.step = 1.0 if whole else 0.01
			if range_parts.size() > 2 and range_parts[2].is_valid_float():
				slider.step = range_parts[2].to_float()
			# "or_greater" / "or_less": a preset's value can lie past the slider's end.
			slider.allow_greater = "or_greater" in range_parts
			slider.allow_lesser = "or_less" in range_parts
			slider.value = target.get(prop)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(slider)

			var value_label := Label.new()
			value_label.custom_minimum_size.x = 56.0
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value_label.text = _format_value(target.get(prop))
			row.add_child(value_label)

			slider.value_changed.connect(func(value: float) -> void:
				target.set(prop, roundi(value) if whole else value)
				tuning_changed.emit()
				value_label.text = _format_value(target.get(prop)))
			editor = slider
			_value_labels[key] = value_label
			group_list.add_child(row)
			_rows[key] = row

		editor.focus_mode = Control.FOCUS_NONE
		_editors[key] = editor

	list.add_child(HSeparator.new())
	_refresh_visibility()


## Hides options a target says don't apply right now (via an optional
## is_option_active(property) method), and group panels left empty.
func _refresh_visibility() -> void:
	for key: String in _rows:
		var parts := key.split("/")
		var target: Object = _targets[parts[0]]
		_rows[key].visible = not target.has_method("is_option_active") or target.is_option_active(parts[1])
	for group_panel: FoldableContainer in _group_panels:
		group_panel.visible = _group_panels[group_panel].any(func(key: String) -> bool: return _rows[key].visible)


## A slider's value as its label shows it: whole numbers without decimals.
static func _format_value(value: Variant) -> String:
	return str(value) if value is int else "%.2f" % value


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


func _apply(section: String, values: Dictionary) -> void:
	for prop: String in values:
		var key := "%s/%s" % [section, prop]
		var editor: Control = _editors.get(key)
		if editor is HSlider:
			# Set the target directly: the slider would round to its step (33.33 -> 33.5).
			var value: Variant = values[prop]
			if _targets[section].get(prop) is int:
				value = roundi(value)
			_targets[section].set(prop, value)
			(editor as HSlider).set_value_no_signal(value)
			_value_labels[key].text = _format_value(_targets[section].get(prop))
		elif editor is CheckBox:
			(editor as CheckBox).button_pressed = values[prop]
		elif editor is OptionButton:
			var picker := editor as OptionButton
			picker.select(picker.get_item_index(values[prop]))
			picker.item_selected.emit(picker.selected)  # select() doesn't emit it
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
	for key: String in _editors:
		var editor: Control = _editors[key]
		var off: bool = _locked.has(key.get_slice("/", 0))
		if editor is BaseButton:
			(editor as BaseButton).disabled = off
		elif editor is Range:
			(editor as Range).editable = not off
	_load_button.disabled = not _locked.is_empty()
	_default_button.disabled = not _locked.is_empty()
	if locked and note:
		_status.text = note


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


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button
