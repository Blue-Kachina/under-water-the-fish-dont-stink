class_name HomeScreen
extends CanvasLayer
## The home screen the game launches to (UI Redesign Handoff, Home A · Reef
## Console): the title and menu down the left (Play, with the last mode played
## under it; Choose mode, Co-op, Replays, Settings, Quit), the player's fish
## live in 3D on the right (‹ ›, left/right or LB/RB change it, its stat bias under it),
## the player's name top-right, and a calm reef behind. Play and Choose mode
## open the mode picker (ModePicker) over it; picking a mode starts it.
##
## Pauses the game while it's up (the world behind keeps its place). Opened
## again from the pause menu's Main menu, B goes back to the game.

## A mode was picked in the picker: start it.
signal mode_chosen(mode: String)
signal replays_requested
signal coop_requested
signal settings_requested
## ‹ › or LB/RB: play as `character` from now on.
signal character_changed(character: FishCharacter.Family)

## main.gd: the mode last played (current_mode), each mode's tile (MODE_TILES)
## and its rules (_match_card_text).
var main: Node
## The settings screen (DebugPanel), to come back to the menu when it closes.
var settings_panel: Node

var _root: Control
var _menu: VBoxContainer
var _play: Button
var _play_note: Label
var _showcase: FishShowcase
var _fish_name: Label
var _fish_bias: Label
var _chip_name: Label
var _chip_initial: Label
var _hints: ControllerHints
var _picker: ModePicker
var _back: Control
var _s := 1.0
## B goes back to the game (opened from the pause menu, with a game on).
var _can_resume := false
var _focus_before: Control
var _nav := MenuNav.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6  # over the HUD and the match card, under the settings
	visible = false
	_s = UITheme.scale_for(get_viewport())
	var s := _s
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.theme(s)
	add_child(_root)
	_back = ReefBackdrop.new()
	(_back as ReefBackdrop).s = s
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_back)

	# Left: the title and the menu, 72 px in, 460 px wide.
	var left := VBoxContainer.new()
	left.position = Vector2(72.0, 70.0) * s
	left.custom_minimum_size.x = 460.0 * s
	left.add_theme_constant_override("separation", roundi(4.0 * s))
	_root.add_child(left)
	left.add_child(UITheme.label("Under water", "caps", 14.0, UITheme.AQUA, s, 600))
	var title := UITheme.label("The Fish\nDon't Stink", "display", 54.0, UITheme.INK, s, 700)
	title.add_theme_constant_override("line_spacing", roundi(-10.0 * s))
	left.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size.y = 30.0 * s
	left.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", roundi(10.0 * s))
	left.add_child(_menu)

	_play = Button.new()
	_play.custom_minimum_size.y = 76.0 * s
	_play.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	# A faint aqua rim marks it out; the full one is for focus only.
	var play_box := UITheme.box(UITheme.PANEL, 14.0 * s, Color(UITheme.AQUA, 0.3), 2.0 * s)
	_play.add_theme_stylebox_override("normal", play_box)
	var play_hover := UITheme.box(UITheme.PANEL.lightened(0.08), 14.0 * s, Color(UITheme.AQUA, 0.3), 2.0 * s)
	_play.add_theme_stylebox_override("hover", play_hover)
	_play.add_theme_stylebox_override("focus", UITheme.box(Color(UITheme.AQUA, 0.14), 14.0 * s, UITheme.AQUA, 3.0 * s))
	_play.pressed.connect(_open_picker)
	_menu.add_child(_play)
	var play_text := VBoxContainer.new()
	play_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_text.offset_left = 22.0 * s
	play_text.alignment = BoxContainer.ALIGNMENT_CENTER
	play_text.add_theme_constant_override("separation", 0)
	play_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(play_text)
	play_text.add_child(UITheme.label("Play", "display", 30.0, UITheme.INK, s, 600))
	_play_note = UITheme.label("", "body", 14.0, UITheme.MUTED, s, 500)
	play_text.add_child(_play_note)

	_menu_button("Co-op", func() -> void: coop_requested.emit())
	_menu_button("Replays", func() -> void: replays_requested.emit())
	_menu_button("Settings", func() -> void: settings_requested.emit())
	var quit := _menu_button("Quit", func() -> void: get_tree().quit())
	quit.add_theme_color_override("font_color", UITheme.MUTED)

	# Right: the fish, live, and what it is.
	_showcase = FishShowcase.new()
	_showcase.anchor_left = 0.5
	_showcase.anchor_right = 1.0
	_showcase.anchor_bottom = 1.0
	_showcase.offset_left = 20.0 * s
	_showcase.offset_right = -40.0 * s
	_showcase.offset_top = 96.0 * s
	_showcase.offset_bottom = -200.0 * s
	_root.add_child(_showcase)
	var caption := HBoxContainer.new()
	caption.anchor_left = 0.5
	caption.anchor_right = 1.0
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_left = 20.0 * s
	caption.offset_right = -40.0 * s
	caption.offset_top = -196.0 * s
	caption.offset_bottom = -104.0 * s
	caption.alignment = BoxContainer.ALIGNMENT_CENTER
	caption.add_theme_constant_override("separation", roundi(22.0 * s))
	_root.add_child(caption)
	caption.add_child(_arrow("‹", -1))
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.custom_minimum_size.x = 380.0 * s
	names.add_theme_constant_override("separation", roundi(2.0 * s))
	caption.add_child(names)
	_fish_name = UITheme.label("", "display", 34.0, UITheme.INK, s, 600)
	_fish_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_child(_fish_name)
	_fish_bias = UITheme.label("", "caps", 14.0, UITheme.CORAL, s, 700)
	_fish_bias.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_child(_fish_bias)
	caption.add_child(_arrow("›", 1))

	# Top right: the player chip.
	var chip := PanelContainer.new()
	var chip_box := UITheme.box(Color(UITheme.DEEP, 0.85), 22.0 * s, Color(UITheme.CORAL, 0.6), maxf(1.0, 1.5 * s))
	chip_box.set_content_margin(SIDE_LEFT, 6.0 * s)
	chip_box.set_content_margin(SIDE_RIGHT, 18.0 * s)
	chip_box.set_content_margin(SIDE_TOP, 5.0 * s)
	chip_box.set_content_margin(SIDE_BOTTOM, 5.0 * s)
	chip.add_theme_stylebox_override("panel", chip_box)
	chip.anchor_left = 1.0
	chip.anchor_right = 1.0
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chip.offset_right = -40.0 * s
	chip.offset_top = 36.0 * s
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(chip)
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", roundi(10.0 * s))
	chip.add_child(chip_row)
	var avatar := PanelContainer.new()
	avatar.add_theme_stylebox_override("panel", UITheme.box(UITheme.CORAL, 16.0 * s))
	avatar.custom_minimum_size = Vector2(32.0, 32.0) * s
	chip_row.add_child(avatar)
	_chip_initial = UITheme.label("", "display", 17.0, UITheme.GROUND, s, 700)
	_chip_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(_chip_initial)
	_chip_name = UITheme.label("", "body", 17.0, UITheme.INK, s, 600)
	_chip_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_row.add_child(_chip_name)

	_hints = ControllerHints.new()
	_hints.s = s
	_hints.anchor_left = 1.0
	_hints.anchor_right = 1.0
	_hints.anchor_top = 1.0
	_hints.anchor_bottom = 1.0
	_hints.offset_left = -760.0 * s
	_hints.offset_right = -40.0 * s
	_hints.offset_top = -64.0 * s
	_hints.offset_bottom = -30.0 * s
	_root.add_child(_hints)

	_picker = ModePicker.new()
	_picker.s = s
	_picker.visible = false
	_picker.chosen.connect(func(mode: String) -> void: mode_chosen.emit(mode))
	_picker.closed.connect(func() -> void:
		_menu.modulate.a = 1.0
		_play.grab_focus())
	_root.add_child(_picker)
	UISettings.changed.connect(func(key: String) -> void:
		if key == "player_name":
			_refresh_chip())


func _enter_tree() -> void:
	if settings_panel and settings_panel.has_signal("closed") and not settings_panel.closed.is_connected(_on_settings_closed):
		settings_panel.closed.connect(_on_settings_closed)


func _on_settings_closed() -> void:
	if visible:
		_refresh()
		if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
			_focus_before.grab_focus()
		else:
			_play.grab_focus()


func is_open() -> bool:
	return visible


## Shows the home screen and pauses the game behind it. `can_resume`: B goes
## back to the game (there's one on).
func open(can_resume := false) -> void:
	_can_resume = can_resume
	visible = true
	_picker.visible = false
	_menu.modulate.a = 1.0
	get_tree().paused = true
	_refresh()
	_play.grab_focus()


## Hides it and lets the game run.
func close() -> void:
	if not visible:
		return
	visible = false
	_picker.visible = false
	get_tree().paused = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus and _root.is_ancestor_of(focus):
		focus.release_focus()


## Opens the mode picker over the menu, the last mode played first.
func open_picker() -> void:
	_open_picker()


func _open_picker() -> void:
	_menu.modulate.a = 0.35
	_picker.open(main.MODE_TILES if main else {}, _last_mode(), func(mode: String) -> String:
		return main._match_card_text(mode) if main else mode)


func _last_mode() -> String:
	var mode: String = main.current_mode if main else ""
	if main and (mode.is_empty() or mode == main.REPLAYS):
		mode = main.get("_mode_before_replays")
	return mode


func _refresh() -> void:
	var last := _last_mode()
	var tile: Dictionary = main.MODE_TILES.get(last, {}) if main else {}
	_play_note.text = "%s · last played" % tile.get("title", last) if last else "Pick a mode"
	_hints.hints = [["A", "Select"], ["LB/RB", "Fish"]] + ([["B", "Back to game"]] if _can_resume else [])
	_show_fish(_character())
	_refresh_chip()


func _refresh_chip() -> void:
	var player := UISettings.display_name()
	_chip_name.text = player
	_chip_initial.text = player.left(1).to_upper()


func _character() -> FishCharacter.Family:
	if main and main.has_node("Fish"):
		return main.get_node("Fish").character
	return FishCharacter.Family.OCTANE


func _show_fish(character: FishCharacter.Family) -> void:
	_showcase.show_fish(character)
	_fish_name.text = FishCharacter.CARS[character].fish
	_fish_bias.text = "%s body  ·  %s +" % [FishCharacter.CARS[character].car, StatBlock.title(StatBlock.signature(character))]
	_fish_bias.text = _fish_bias.text.to_upper()


## The next (+1) or previous (-1) fish.
func _cycle_fish(direction: int) -> void:
	var families := FishCharacter.CARS.keys()
	var at := families.find(_character())
	var next: FishCharacter.Family = families[posmod(at + direction, families.size())]
	character_changed.emit(next)
	_show_fish(next)


func _input(event: InputEvent) -> void:
	if not visible or (settings_panel and settings_panel.is_open()) or _coop_open():
		return
	if _picker.visible:
		return  # the picker's own
	if MenuNav.is_direction(event):
		# Up/down along the menu (wrapping), left/right the fish, like ‹ ›.
		match _nav.side(event):
			SIDE_TOP:
				_menu_step(-1)
			SIDE_BOTTOM:
				_menu_step(1)
			SIDE_LEFT:
				_cycle_fish(-1)
			SIDE_RIGHT:
				_cycle_fish(1)
	elif event.is_action_pressed("ui_page_previous"):
		_cycle_fish(-1)
	elif event.is_action_pressed("ui_page_next"):
		_cycle_fish(1)
	elif event.is_action_pressed("ui_cancel") and _can_resume:
		close()
	else:
		return
	get_viewport().set_input_as_handled()


## Focus the menu button `step` along from the focused one, wrapping round.
func _menu_step(step: int) -> void:
	var buttons := _menu.get_children()
	var at := buttons.find(get_viewport().gui_get_focus_owner())
	(buttons[posmod(at + step, buttons.size()) if at >= 0 else 0] as Control).grab_focus()


func _process(_delta: float) -> void:
	if not visible:
		return
	if NetSession.is_online():
		close()  # joined or hosting from Co-op: into the game
		return
	if get_viewport().gui_get_focus_owner() == null and not _picker.visible and not _coop_open() \
			and not (settings_panel and settings_panel.is_open()):
		_play.grab_focus()


func _coop_open() -> bool:
	return main != null and main.has_node("CoopMenu")


## Remembers what had focus (to come back to after Settings).
func remember_focus() -> void:
	_focus_before = get_viewport().gui_get_focus_owner()


func _menu_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 52.0 * _s
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.add_theme_font_override("font", UITheme.display(500))
	button.add_theme_font_size_override("font_size", roundi(21.0 * _s))
	var clear := UITheme.box(Color(UITheme.PANEL, 0.8), 12.0 * _s)
	clear.set_content_margin(SIDE_LEFT, 22.0 * _s)
	button.add_theme_stylebox_override("normal", clear)
	button.pressed.connect(on_pressed)
	_menu.add_child(button)
	return button


func _arrow(glyph: String, direction: int) -> Button:
	var button := Button.new()
	button.text = glyph
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(48.0, 48.0) * _s
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", UITheme.display(600))
	button.add_theme_font_size_override("font_size", roundi(28.0 * _s))
	button.add_theme_stylebox_override("normal", UITheme.box(Color(UITheme.PANEL, 0.8), 24.0 * _s, Color(UITheme.MUTED, 0.4), maxf(1.0, _s)))
	button.add_theme_stylebox_override("hover", UITheme.box(UITheme.PANEL.lightened(0.1), 24.0 * _s, UITheme.AQUA, maxf(1.0, 1.5 * _s)))
	button.pressed.connect(_cycle_fish.bind(direction))
	return button


## The player's fish, live in its own little world: turning slowly, swimming
## gently, lit like the menus.
class FishShowcase extends SubViewportContainer:
	var _view := SubViewport.new()
	var _pivot := Node3D.new()
	var _camera := Camera3D.new()
	var _model: FishModel
	var _shown := -1
	var _time := 0.0

	func _init() -> void:
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS
		_view.own_world_3d = true
		_view.transparent_bg = true
		_view.msaa_3d = Viewport.MSAA_4X
		_view.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_view)
		var environment := Environment.new()
		environment.background_mode = Environment.BG_CLEAR_COLOR
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.55, 0.78, 0.86)
		environment.ambient_light_energy = 0.75
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var world := WorldEnvironment.new()
		world.environment = environment
		_view.add_child(world)
		var key := DirectionalLight3D.new()
		key.rotation = Vector3(-0.9, 0.7, 0.0)
		key.light_energy = 1.3
		_view.add_child(key)
		var rim := DirectionalLight3D.new()
		rim.rotation = Vector3(-0.3, -2.6, 0.0)
		rim.light_color = Color(0.4, 0.95, 0.9)
		rim.light_energy = 0.9
		_view.add_child(rim)
		_view.add_child(_pivot)
		_camera.fov = 32.0
		_view.add_child(_camera)

	func show_fish(character: FishCharacter.Family) -> void:
		if character == _shown:
			return
		_shown = character
		if _model:
			_model.queue_free()
		_model = FishModel.build(character)
		_pivot.add_child(_model)
		var reach := _model._size.length() * 1.85
		_camera.position = Vector3(-0.55, 0.32, -1.0).normalized() * reach
		_camera.look_at(Vector3.ZERO, Vector3.UP)

	func _process(delta: float) -> void:
		if not is_visible_in_tree() or _model == null:
			return
		_time += delta
		_pivot.rotation.y = _time * 0.35
		_pivot.position.y = sin(_time * 1.3) * 0.04
		_model.react(delta, _model.global_basis * Vector3(0.0, 0.0, -3.0))


## The calm reef behind the home screen: deep water, slanted light shafts
## that sway gently, a seabed silhouette with kelp, and a few rising bubbles.
class ReefBackdrop extends Control:
	var s := 1.0
	var _time := 0.0
	var _bubbles: Array[Vector3] = []  # x share, start phase, radius

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 16:
			_bubbles.append(Vector3(rng.randf_range(0.05, 0.95), rng.randf(), rng.randf_range(2.0, 6.0)))

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_time += delta
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var top := Color(0.04, 0.16, 0.24)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([top, top, UITheme.DEEP, UITheme.DEEP]))
		# Light shafts, slanted, faint, from the surface.
		for i in 6:
			var x := w * (0.28 + i * 0.13) + sin(_time * 0.25 + i * 1.7) * 18.0 * s
			var width := (60.0 + (i % 3) * 38.0) * s
			var lean := h * 0.42
			var alpha := 0.035 + 0.02 * sin(_time * 0.4 + i * 2.1)
			draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + width, 0), Vector2(x + width - lean, h * 0.95), Vector2(x - lean * 0.9, h * 0.95)]),
					PackedColorArray([Color(0.7, 1.0, 0.95, alpha), Color(0.7, 1.0, 0.95, alpha), Color(0.7, 1.0, 0.95, 0.0), Color(0.7, 1.0, 0.95, 0.0)]))
		# Bubbles, rising and wobbling.
		for bubble in _bubbles:
			var rise := fmod(bubble.y + _time * 0.035 * (1.0 + bubble.z * 0.1), 1.0)
			var at := Vector2(w * bubble.x + sin(_time * 1.5 + bubble.y * 9.0) * 6.0 * s, h * (1.05 - rise * 1.15))
			draw_arc(at, bubble.z * s, 0.0, TAU, 16, Color(UITheme.INK, 0.22 * (1.0 - rise * 0.6)), maxf(1.0, s), true)
		# The seabed: a far ridge, then the near one, kelp between.
		_seabed(h - 150.0 * s, 26.0 * s, 0.0021, Color(0.03, 0.12, 0.18))
		for i in 7:
			var root := Vector2(w * (0.08 + i * 0.145), h - 92.0 * s)
			var points := PackedVector2Array()
			for n in 9:
				var t := n / 8.0
				points.append(root + Vector2(sin(_time * 0.8 + i + t * 3.0) * 10.0 * s * t, -t * (90.0 + (i % 3) * 40.0) * s))
			draw_polyline(points, Color(0.05, 0.2, 0.22, 0.9), 5.0 * s, true)
		_seabed(h - 92.0 * s, 18.0 * s, 0.004, UITheme.DEEP)

	func _seabed(line: float, bumps: float, frequency: float, color: Color) -> void:
		var points := PackedVector2Array([Vector2(0, size.y)])
		var steps := 40
		for i in steps + 1:
			var x := size.x * i / steps
			points.append(Vector2(x, line + sin(x * frequency) * bumps + sin(x * frequency * 2.7 + 1.3) * bumps * 0.4))
		points.append(Vector2(size.x, size.y))
		draw_colored_polygon(points, color)
