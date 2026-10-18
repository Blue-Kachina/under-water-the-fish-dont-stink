class_name PauseMenu
extends CanvasLayer
## Start (Esc, F1) pauses the game and shows this menu: Resume, the mode's reset
## (Start used to reset; R still does), Settings (the settings screen,
## DebugPanel), Co-op online, Main menu (the home screen) and Quit. Start
## again, B or Resume carries on. In the dark-water look (UITheme).
##
## Runs while the tree is paused. Its buttons act on release, so the A press
## that picks Resume is over before the fish runs again (no stray jump). While
## the settings are open they have B and Esc (back a column); Start still
## closes everything.

signal reset_requested
## The menu opened or closed (online it doesn't pause the game: see `pauses`).
signal opened
signal closed
## Co-op (online) was picked.
signal coop_requested
## Main menu was picked: back to the home screen.
signal main_menu_requested

## The settings screen (DebugPanel): shown by Settings, hidden on resuming.
var settings_panel: Node
## What the reset option says right now, or "" when there's none (Replays, a
## match card). Asked every frame while open, as the mode can change.
var reset_label := func() -> String: return ""
## Whether opening it pauses the game (not in an online session, where the
## world goes on for everyone else).
var pauses := func() -> bool: return true
## Whether Main menu can be picked now (not while online).
var main_menu_allowed := func() -> bool: return true
## Whether Start opens it now (not over the home screen).
var can_open := func() -> bool: return true

var _menu: PanelContainer
var _resume: Button
var _reset: Button
var _settings: Button
var _main_menu: Button
var _hints: ControllerHints
var _focus_before: Control
## B was pressed while open: resume when it's let go.
var _cancel_armed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6  # above the match card and replay bar, under the settings
	visible = false
	var s := UITheme.scale_for(get_viewport())

	var dim := ColorRect.new()
	dim.color = UITheme.DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_menu = PanelContainer.new()
	_menu.theme = UITheme.theme(s)
	_menu.add_theme_stylebox_override("panel", UITheme.box(UITheme.GROUND, 24.0 * s, Color(UITheme.AQUA, 0.25), maxf(1.0, s)))
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.custom_minimum_size.x = 380.0 * s
	add_child(_menu)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, roundi(28.0 * s))
	margin.add_theme_constant_override("margin_top", roundi(24.0 * s))
	margin.add_theme_constant_override("margin_bottom", roundi(20.0 * s))
	_menu.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(8.0 * s))
	margin.add_child(column)
	column.add_child(UITheme.label("Game on hold", "caps", 12.0, UITheme.AQUA, s))
	column.add_child(UITheme.label("Paused", "display", 36.0, UITheme.INK, s, 600))
	var gap := Control.new()
	gap.custom_minimum_size.y = 6.0 * s
	column.add_child(gap)
	_resume = _button(column, "Resume", close, s)
	_reset = _button(column, "Reset", func() -> void:
		close()
		reset_requested.emit(), s)
	_settings = _button(column, "Settings", func() -> void:
		if settings_panel:
			settings_panel.set_open(true)
			_menu.visible = false, s)
	_button(column, "Co-op online", func() -> void: coop_requested.emit(), s)
	_main_menu = _button(column, "Main menu", func() -> void:
		close()
		main_menu_requested.emit(), s)
	var quit := _button(column, "Quit game", func() -> void: get_tree().quit(), s)
	quit.add_theme_color_override("font_color", UITheme.MUTED)
	_hints = ControllerHints.new()
	_hints.s = s
	_hints.hints = [["A", "Select"], ["B", "Resume"]]
	_hints.anchor_left = 1.0
	_hints.anchor_right = 1.0
	_hints.anchor_top = 1.0
	_hints.anchor_bottom = 1.0
	_hints.offset_left = -640.0 * s
	_hints.offset_right = -40.0 * s
	_hints.offset_top = -64.0 * s
	_hints.offset_bottom = -30.0 * s
	add_child(_hints)


## Called once the settings panel's set: back here when it closes.
func _enter_tree() -> void:
	if settings_panel and settings_panel.has_signal("closed") and not settings_panel.closed.is_connected(_on_settings_closed):
		settings_panel.closed.connect(_on_settings_closed)


func _on_settings_closed() -> void:
	if not visible:
		return
	_menu.visible = true
	_settings.grab_focus()


func is_open() -> bool:
	return visible


## Pauses the game and shows the menu, Resume picked.
func open() -> void:
	if visible:
		return
	_focus_before = get_viewport().gui_get_focus_owner()
	_cancel_armed = false
	get_tree().paused = pauses.call()
	visible = true
	_menu.visible = true
	_update_buttons()
	_resume.grab_focus()
	opened.emit()


## Hides the menu (and the settings) and carries on.
func close() -> void:
	if not visible:
		return
	visible = false
	if settings_panel and settings_panel.is_open():
		settings_panel.set_open(false)
	get_tree().paused = false
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()  # e.g. the match card's Play
	_focus_before = null
	closed.emit()


func _settings_open() -> bool:
	return settings_panel != null and settings_panel.is_open()


func _input(event: InputEvent) -> void:
	if not visible and not can_open.call():
		return
	if _settings_open() and settings_panel.is_capturing():
		return  # a rebind is waiting for this key or button
	if event.is_action_pressed("pause") and not event.is_echo():
		if _settings_open() and event is InputEventKey:
			return  # Esc in the settings: back a column (theirs)
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif _settings_open():
		return
	elif visible and event.is_action_pressed("ui_cancel"):
		_cancel_armed = true  # Esc is "pause" too, so this is B
	elif visible and _cancel_armed and event.is_action_released("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		_update_buttons()


func _update_buttons() -> void:
	var text: String = reset_label.call()
	_reset.visible = not text.is_empty()
	_reset.text = text
	_main_menu.disabled = not main_menu_allowed.call()
	_hints.visible = _menu.visible
	if _menu.visible and get_viewport().gui_get_focus_owner() == null:
		_resume.grab_focus()  # e.g. after the focused reset option goes


func _button(parent: Control, text: String, on_pressed: Callable, s: float) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 52.0 * s
	button.add_theme_font_override("font", UITheme.display(500))
	button.add_theme_font_size_override("font_size", roundi(20.0 * s))
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
