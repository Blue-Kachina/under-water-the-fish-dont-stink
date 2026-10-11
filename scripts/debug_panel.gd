extends CanvasLayer
## Live tuning panel. Lists every @export_range float, @export bool and @export
## enum on the fish, the camera and the ball settings, writes changes to them
## immediately, and saves/loads them. Add a new export to any of them and it
## appears here. A target can hide options that don't apply with is_option_active().
##
## Controls are mouse-only (no keyboard/gamepad focus) so the controller keeps
## flying the fish while you drag sliders.

const SAVE_PATH_EDITOR := "res://tuning.cfg"  # tracked in git while developing
const SAVE_PATH_USER := "user://tuning.cfg"   # exported builds can't write res://
## Each .cfg here is a preset: the values it lists are applied over the defaults
## (which are Rocket League's).
const PRESET_DIR := "res://presets"
const DEFAULT_PRESET := "Rocket League (defaults)"
## Saved tuning carries this; older saves (the underwater tuning from before the
## switch to Rocket League physics) aren't loaded automatically at startup.
const TUNING_VERSION := 2

@export var fish: FishController
@export var follow_camera: Camera3D
@export var ball_settings: BallSettings

var _targets := {}
var _defaults := {}
var _editors := {}  # "section/property" -> HSlider, CheckBox or OptionButton
var _value_labels := {}  # "section/property" -> a slider's value Label
var _rows := {}  # "section/property" -> the control to hide when the option doesn't apply
var _group_labels := {}  # group heading Label -> its "section/property" keys
var _panel: PanelContainer
var _status: Label
var _environment_row: HBoxContainer

signal environment_selected(env_name: String)


func _ready() -> void:
	_targets = {"fish": fish, "camera": follow_camera, "ball": ball_settings}
	for section: String in _targets:
		_defaults[section] = _snapshot(_targets[section])
	_build_ui()
	_load(true)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_panel"):
		_panel.visible = not _panel.visible


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
	title.text = "Movement tuning"
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)

	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	buttons.add_child(_button("Save", _save))
	buttons.add_child(_button("Load", _load))
	buttons.add_child(_button("Defaults", _restore_defaults))
	buttons.add_child(_button("Copy", _copy_to_clipboard))

	var profile_row := HBoxContainer.new()
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
	# Follow profile changes made elsewhere (a preset can pick one).
	Controls.profile_changed.connect(func(profile: String) -> void:
		for i in profiles.item_count:
			if profiles.get_item_text(i) == profile:
				profiles.select(i))
	profile_row.add_child(profiles)

	var preset_row := HBoxContainer.new()
	root.add_child(preset_row)
	var preset_label := Label.new()
	preset_label.text = "Preset"
	preset_row.add_child(preset_label)
	var presets := OptionButton.new()
	presets.focus_mode = Control.FOCUS_NONE
	presets.add_item(DEFAULT_PRESET)
	for preset_name: String in _preset_names():
		presets.add_item(preset_name)
	presets.item_selected.connect(func(index: int) -> void:
		_apply_preset(presets.get_item_text(index)))
	preset_row.add_child(presets)

	_environment_row = HBoxContainer.new()  # filled in by set_environments()
	root.add_child(_environment_row)

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

	for section: String in _targets:
		_build_section(list, section, _targets[section])


## Adds the environment picker; selections are reported via environment_selected.
func set_environments(names: Array, current: String) -> void:
	var label := Label.new()
	label.text = "Environment"
	_environment_row.add_child(label)
	var picker := OptionButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	for env_name: String in names:
		picker.add_item(env_name)
		if env_name == current:
			picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index: int) -> void:
		environment_selected.emit(picker.get_item_text(index))
		_status.text = "Environment: %s (remembered on this PC)" % picker.get_item_text(index))
	_environment_row.add_child(picker)


func _build_section(list: VBoxContainer, section: String, target: Object) -> void:
	var header := Label.new()
	header.text = section.to_upper()
	header.add_theme_font_size_override("font_size", 18)
	list.add_child(header)

	var shown_group := ""
	var group_label: Label
	for property in _tunable_properties(target):
		var prop: String = property.name
		var key := "%s/%s" % [section, prop]
		if property.group != shown_group:
			shown_group = property.group
			group_label = Label.new()
			group_label.text = shown_group
			group_label.modulate = Color(0.55, 0.85, 1.0)
			list.add_child(group_label)
			_group_labels[group_label] = []
		_group_labels[group_label].append(key)

		var editor: Control
		if property.type == TYPE_BOOL:
			var check := CheckBox.new()
			check.text = prop.capitalize()
			check.button_pressed = target.get(prop)
			check.toggled.connect(func(on: bool) -> void:
				target.set(prop, on)
				_refresh_visibility())
			editor = check
			list.add_child(check)
			_rows[key] = check
		elif property.type == TYPE_INT:  # enum
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
				_refresh_visibility())
			row.add_child(picker)
			editor = picker
			list.add_child(row)
			_rows[key] = row
		else:
			var row := HBoxContainer.new()
			var name_label := Label.new()
			name_label.text = prop.capitalize()
			name_label.custom_minimum_size.x = 170.0
			name_label.tooltip_text = prop
			row.add_child(name_label)

			var range_parts: PackedStringArray = property.hint_string.split(",")
			var slider := HSlider.new()
			slider.min_value = range_parts[0].to_float()
			slider.max_value = range_parts[1].to_float()
			slider.step = range_parts[2].to_float() if range_parts.size() > 2 else 0.01
			slider.value = target.get(prop)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(slider)

			var value_label := Label.new()
			value_label.custom_minimum_size.x = 56.0
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value_label.text = "%.2f" % slider.value
			row.add_child(value_label)

			slider.value_changed.connect(func(value: float) -> void:
				target.set(prop, value)
				value_label.text = "%.2f" % value)
			editor = slider
			_value_labels[key] = value_label
			list.add_child(row)
			_rows[key] = row

		editor.focus_mode = Control.FOCUS_NONE
		_editors[key] = editor

	list.add_child(HSeparator.new())
	_refresh_visibility()


## Hides options a target says don't apply right now (via an optional
## is_option_active(property) method), and group headings left empty.
func _refresh_visibility() -> void:
	for key: String in _rows:
		var parts := key.split("/")
		var target: Object = _targets[parts[0]]
		_rows[key].visible = not target.has_method("is_option_active") or target.is_option_active(parts[1])
	for label: Label in _group_labels:
		label.visible = _group_labels[label].any(func(key: String) -> bool: return _rows[key].visible)


## Script variables exported as a float range, a bool or an enum, tagged with their @export_group.
func _tunable_properties(target: Object) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var group := ""
	for property in target.get_property_list():
		if property.usage & PROPERTY_USAGE_GROUP:
			group = property.name
			continue
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (property.usage & PROPERTY_USAGE_EDITOR):
			continue
		var is_range: bool = property.type == TYPE_FLOAT and property.hint == PROPERTY_HINT_RANGE
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
			_targets[section].set(prop, values[prop])
			(editor as HSlider).set_value_no_signal(values[prop])
			_value_labels[key].text = "%.2f" % values[prop]
		elif editor is CheckBox:
			(editor as CheckBox).button_pressed = values[prop]
		elif editor is OptionButton:
			var picker := editor as OptionButton
			picker.select(picker.get_item_index(values[prop]))
			picker.item_selected.emit(picker.selected)  # select() doesn't emit it


func _to_config() -> ConfigFile:
	var config := ConfigFile.new()
	config.set_value("meta", "version", TUNING_VERSION)
	for section: String in _targets:
		var values := _snapshot(_targets[section])
		for prop: String in values:
			config.set_value(section, prop, values[prop])
	return config


func _save_path() -> String:
	return SAVE_PATH_EDITOR if OS.has_feature("editor") else SAVE_PATH_USER


func _save() -> void:
	var error := _to_config().save(_save_path())
	_status.text = "Saved to %s" % _save_path() if error == OK else "Save failed: %s" % error_string(error)


func _load(quiet := false) -> void:
	# Exported builds fall back to the tuning that shipped with the project.
	var path := _save_path()
	if not FileAccess.file_exists(path):
		path = SAVE_PATH_EDITOR
	var config := ConfigFile.new()
	if config.load(path) != OK:
		if not quiet:
			_status.text = "No saved tuning at %s" % _save_path()
		return
	if quiet and int(config.get_value("meta", "version", 1)) < TUNING_VERSION:
		_status.text = "Skipped saved tuning from before Rocket League physics (%s). Press Load to use it anyway." % path
		return
	for section: String in _targets:
		if not config.has_section(section):
			continue
		var values := {}
		for prop in config.get_section_keys(section):
			values[prop] = config.get_value(section, prop)
		_apply(section, values)
	_status.text = "Loaded %s" % path


func _preset_names() -> PackedStringArray:
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(PRESET_DIR):
		if file.get_extension() == "cfg":
			names.append(file.get_basename().capitalize())
	return names


## Defaults first, then the preset file's values on top, so a preset only needs
## to list what it changes.
func _apply_preset(preset_name: String) -> void:
	for section: String in _targets:
		_apply(section, _defaults[section])
	if preset_name != DEFAULT_PRESET:
		var config := ConfigFile.new()
		var path := "%s/%s.cfg" % [PRESET_DIR, preset_name.to_snake_case()]
		if config.load(path) != OK:
			_status.text = "Couldn't load preset %s" % path
			return
		for section: String in _targets:
			if config.has_section(section):
				var values := {}
				for prop in config.get_section_keys(section):
					values[prop] = config.get_value(section, prop)
				_apply(section, values)
		if config.has_section_key("controls", "profile"):
			Controls.apply_profile(config.get_value("controls", "profile"))
	_refresh_visibility()
	_status.text = "Preset: %s (not saved)" % preset_name


func _restore_defaults() -> void:
	for section: String in _targets:
		_apply(section, _defaults[section])
	_status.text = "Restored defaults (not saved)"


func _copy_to_clipboard() -> void:
	DisplayServer.clipboard_set(_to_config().encode_to_text())
	_status.text = "Copied current tuning to clipboard"


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button
