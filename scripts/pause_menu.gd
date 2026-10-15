class_name PauseMenu
extends CanvasLayer
## Start (Esc, F1) pauses the game and shows this menu: Resume, the mode's reset
## (Start used to reset; R still does), Settings, which shows the tuning
## panel (only reachable from here), and Exit, which quits the game. Start
## again, B or Resume carries on.
##
## Runs while the tree is paused. Its buttons act on release, so the A press
## that picks Resume is over before the fish runs again (no stray jump).

signal reset_requested

## The tuning panel (DebugPanel): shown by Settings, hidden on resuming.
var settings_panel: Node
## What the reset option says right now, or "" when there's none (Replays, a
## match card). Asked every frame while open, as the mode can change from the
## panel.
var reset_label := func() -> String: return ""

var _menu: PanelContainer
var _resume: Button
var _reset: Button
var _settings: Button
var _focus_before: Control
## B was pressed while open: resume when it's let go.
var _cancel_armed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6  # above the match card and replay bar, under the tuning panel
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.04, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the tuning panel stays clickable
	add_child(dim)

	_menu = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.08, 0.92)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	_menu.add_theme_stylebox_override("panel", style)
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.custom_minimum_size.x = 260.0
	_menu.position.x += 226.0  # centred in the room right of the tuning panel
	add_child(_menu)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_menu.add_child(column)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	_resume = _button(column, "Resume", close)
	_reset = _button(column, "Reset", func() -> void:
		close()
		reset_requested.emit())
	_settings = _button(column, "Settings", func() -> void:
		settings_panel.set_open(not settings_panel.is_open())
		_update_buttons())
	_button(column, "Exit", func() -> void: get_tree().quit())
	var hint := Label.new()
	hint.text = "Start / B: resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	column.add_child(hint)


func is_open() -> bool:
	return visible


## Pauses the game and shows the menu, Resume picked.
func open() -> void:
	if visible:
		return
	_focus_before = get_viewport().gui_get_focus_owner()
	_cancel_armed = false
	get_tree().paused = true
	visible = true
	_update_buttons()
	_resume.grab_focus()


## Hides the menu (and the tuning panel) and carries on.
func close() -> void:
	if not visible:
		return
	if settings_panel:
		settings_panel.set_open(false)
	visible = false
	get_tree().paused = false
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()  # e.g. the match card's Play
	_focus_before = null


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
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
	_settings.text = "Hide settings" if settings_panel and settings_panel.is_open() else "Settings"
	if get_viewport().gui_get_focus_owner() == null:
		_resume.grab_focus()  # e.g. after the focused reset option goes (not off the name field)


func _button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36.0
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
