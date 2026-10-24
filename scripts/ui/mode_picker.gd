class_name ModePicker
extends Control
## The mode picker (UI Redesign Handoff, Home A · Play → Mode Picker): a
## pop-up over the home screen, laid out like the Mode Wall. The last mode
## played is the big featured tile (focused on opening, with a LAST PLAYED
## badge, its pitch and how it can be played); four tiles beside it; and a
## MORE row for the less-used modes. A plays the focused mode straight away,
## X shows its rules (the match card's text), B or the close button goes back.
##
## Each tile's title, pitch line, icon and colours come from main.gd's
## MODE_TILES, so the featured tile can show any mode.

signal chosen(mode: String)
signal closed

## The big modes, in order; the featured one comes out of here (or MORE).
const PRIMARY := ["Unnatural", "Fish Sticks", "Hunt", "Nature", "Obstacle Course"]
const MORE := ["Test Tank"]  # (Free Swim is retired: refining_weaponry.md §2.8)
## Fish Sticks is one tile for the ball modes; choosing it asks which: its variants
## (main.gd mode ids).
const FISH_STICKS := "Fish Sticks"
const FISH_STICKS_MODES := ["1v1", "Free Play"]
## Unnatural asks how long a run (P5: UnnaturalSettings.run_length), then plays it.
const UNNATURAL := "Unnatural"
const RUN_LENGTHS := ["Short", "Standard", "Endless"]
const PANEL_SIZE := Vector2(1120.0, 616.0)

var s := 1.0

var _tiles: Dictionary = {}
var _rules_for: Callable
var _panel: Control
var _featured: Tile
var _grid: Array[Tile] = []
var _more: Array[Tile] = []
var _close: Button
var _rules: PanelContainer
var _rules_dim: ColorRect
var _rules_title: Label
var _rules_text: Label
var _rules_mode := ""
var _variants: PanelContainer
var _variant_buttons: Array[Button] = []
var _variants_title: Label
var _variants_line: Label
var _variants_row: HBoxContainer
## Which tile's variants are up (FISH_STICKS or UNNATURAL).
var _variants_mode := ""
## What had focus last (in the picker), for the MORE row's way back up.
var _last_focus: Control
var _nav := MenuNav.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UITheme.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_cancel())
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.GROUND, 24.0 * s, Color(UITheme.AQUA, 0.22), maxf(1.0, s)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = PANEL_SIZE * s
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.position = -PANEL_SIZE * s * 0.5
	add_child(panel)
	_panel = Control.new()
	panel.add_child(_panel)

	var pad := 32.0 * s
	var label := UITheme.label("Play", "caps", 13.0, UITheme.AQUA, s, 700)
	label.position = Vector2(pad, 26.0 * s)
	_panel.add_child(label)
	var heading := UITheme.label("Choose a mode", "display", 34.0, UITheme.INK, s, 600)
	heading.position = Vector2(pad, 44.0 * s)
	_panel.add_child(heading)
	_close = Button.new()
	_close.text = "✕"
	_close.custom_minimum_size = Vector2(44.0, 44.0) * s
	_close.size = _close.custom_minimum_size
	_close.position = Vector2(PANEL_SIZE.x * s - pad - 44.0 * s, 30.0 * s)
	_close.add_theme_font_size_override("font_size", roundi(18.0 * s))
	_close.add_theme_stylebox_override("normal", UITheme.box(UITheme.PANEL, 22.0 * s))
	_close.add_theme_stylebox_override("hover", UITheme.box(UITheme.PANEL.lightened(0.1), 22.0 * s))
	_close.add_theme_stylebox_override("focus", UITheme.box(Color(UITheme.AQUA, 0.12), 22.0 * s, UITheme.AQUA, 2.0 * s))
	_close.pressed.connect(_cancel)
	_panel.add_child(_close)

	# The wall: the featured tile over 2×2, four single tiles beside it.
	var top := 106.0 * s
	var gap := 16.0 * s
	var column := ((PANEL_SIZE.x * s - pad * 2.0) - gap * 3.0) / 4.0
	var row := 168.0 * s
	_featured = Tile.new()
	_featured.big = true
	_featured.s = s
	_featured.position = Vector2(pad, top)
	_featured.size = Vector2(column * 2.0 + gap, row * 2.0 + gap)
	_panel.add_child(_featured)
	for i in 4:
		var tile := Tile.new()
		tile.s = s
		tile.position = Vector2(pad + (2 + i % 2) * (column + gap), top + (i / 2) * (row + gap))
		tile.size = Vector2(column, row)
		_panel.add_child(tile)
		_grid.append(tile)

	var more_top := top + row * 2.0 + gap * 2.0 + 8.0 * s
	var more_label := UITheme.label("More", "caps", 12.0, UITheme.MUTED, s, 700)
	more_label.position = Vector2(pad, more_top + 16.0 * s)
	_panel.add_child(more_label)
	var more_width := (PANEL_SIZE.x * s - pad * 2.0 - 90.0 * s - gap * 3.0) / 4.0
	for i in 4:
		var tile := Tile.new()
		tile.slim = true
		tile.s = s
		tile.position = Vector2(pad + 90.0 * s + i * (more_width + gap), more_top)
		tile.size = Vector2(more_width, 52.0 * s)
		_panel.add_child(tile)
		_more.append(tile)
	for tile: Tile in [_featured] + _grid + _more:
		tile.pressed.connect(func() -> void:
			if tile.mode:
				_choose(tile.mode))

	var hints := ControllerHints.new()
	hints.s = s
	hints.hints = [["A", "Play"], ["X", "Mode rules"], ["B", "Back"]]
	hints.position = Vector2(pad, PANEL_SIZE.y * s - 50.0 * s)
	hints.size = Vector2(PANEL_SIZE.x * s - pad * 2.0, 30.0 * s)
	_panel.add_child(hints)

	# X: the focused mode's rules, over the wall (dimmed).
	_rules_dim = ColorRect.new()
	_rules_dim.color = Color(UITheme.GROUND, 0.75)
	_rules_dim.size = PANEL_SIZE * s
	_rules_dim.visible = false
	_panel.add_child(_rules_dim)
	_rules = PanelContainer.new()
	var rules_box := UITheme.box(UITheme.PANEL, 20.0 * s, UITheme.AQUA, 2.0 * s)
	rules_box.set_content_margin_all(28.0 * s)
	_rules.add_theme_stylebox_override("panel", rules_box)
	_rules.position = Vector2(PANEL_SIZE.x * s * 0.5 - 330.0 * s, 120.0 * s)
	_rules.custom_minimum_size = Vector2(660.0 * s, 0.0)
	_rules.visible = false
	_panel.add_child(_rules)
	var rules_column := VBoxContainer.new()
	rules_column.add_theme_constant_override("separation", roundi(10.0 * s))
	_rules.add_child(rules_column)
	rules_column.add_child(UITheme.label("Mode rules", "caps", 12.0, UITheme.AQUA, s, 700))
	_rules_title = UITheme.label("", "display", 30.0, UITheme.INK, s, 600)
	rules_column.add_child(_rules_title)
	_rules_text = UITheme.label("", "body", 17.0, UITheme.INK_SOFT, s)
	_rules_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_column.add_child(_rules_text)
	var rules_hints := ControllerHints.new()
	rules_hints.s = s
	rules_hints.hints = [["A", "Play"], ["B", "Back"]]
	rules_column.add_child(rules_hints)

	# Fish Sticks: which one (1v1 or Free Play), over the wall (dimmed).
	_variants = PanelContainer.new()
	var variants_box := UITheme.box(UITheme.PANEL, 20.0 * s, UITheme.AQUA, 2.0 * s)
	variants_box.set_content_margin_all(28.0 * s)
	_variants.add_theme_stylebox_override("panel", variants_box)
	_variants.position = Vector2(PANEL_SIZE.x * s * 0.5 - 260.0 * s, 170.0 * s)
	_variants.custom_minimum_size = Vector2(520.0 * s, 0.0)
	_variants.visible = false
	_panel.add_child(_variants)
	var variants_column := VBoxContainer.new()
	variants_column.add_theme_constant_override("separation", roundi(12.0 * s))
	_variants.add_child(variants_column)
	_variants_title = UITheme.label("Fish Sticks", "caps", 12.0, UITheme.AQUA, s, 700)
	variants_column.add_child(_variants_title)
	_variants_line = UITheme.label("", "body", 17.0, UITheme.INK_SOFT, s)
	_variants_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	variants_column.add_child(_variants_line)
	_variants_row = HBoxContainer.new()
	_variants_row.add_theme_constant_override("separation", roundi(14.0 * s))
	variants_column.add_child(_variants_row)
	var variants_hints := ControllerHints.new()
	variants_hints.s = s
	variants_hints.hints = [["A", "Play"], ["B", "Back"]]
	variants_column.add_child(variants_hints)


## Shows the wall: `tiles` is main.gd's MODE_TILES, `featured` the mode last
## played, `rules_for` the match card text for a mode.
func open(tiles: Dictionary, featured: String, rules_for: Callable) -> void:
	_tiles = tiles
	_rules_for = rules_for
	if featured in FISH_STICKS_MODES:
		featured = FISH_STICKS
	if not tiles.has(featured):
		featured = PRIMARY[0]
	var singles: Array = PRIMARY.filter(func(mode: String) -> bool: return mode != featured)
	var more: Array = MORE.filter(func(mode: String) -> bool: return mode != featured)
	while singles.size() > 4:
		more.push_front(singles.pop_back())
	_featured.show_mode(featured, tiles.get(featured, {}))
	for i in _grid.size():
		_grid[i].show_mode(singles[i] if i < singles.size() else "", tiles.get(singles[i], {}) if i < singles.size() else {})
	for i in _more.size():
		_more[i].show_mode(more[i] if i < more.size() else "", tiles.get(more[i], {}) if i < more.size() else {})
		_more[i].visible = i < more.size()
	_rules.visible = false
	_variants.visible = false
	_rules_dim.visible = false
	visible = true
	_link()
	_featured.grab_focus.call_deferred()


## Every tile's up / down / left / right neighbour, from where the tiles sit
## (which modes go where depends on the last one played, and the MORE row can
## be short): the wall left to right and top to bottom, the MORE row under it,
## the close button above the right-hand tiles. Nothing leads out of the
## picker to the home menu behind it.
func _link() -> void:
	var more: Array[Tile] = []
	for tile in _more:
		if tile.visible and tile.mode:
			more.append(tile)
	var top_left := _grid[0]
	var top_right := _grid[1]
	var bottom_left := _grid[2]
	var bottom_right := _grid[3]
	_neighbours(_featured, _featured, top_left, _close, more[0] if not more.is_empty() else _featured)
	_neighbours(top_left, _featured, top_right, _close, bottom_left)
	_neighbours(top_right, top_left, top_right, _close, bottom_right)
	_neighbours(bottom_left, _featured, bottom_right, top_left, _below(bottom_left, more))
	_neighbours(bottom_right, bottom_left, bottom_right, top_right, _below(bottom_right, more))
	for i in more.size():
		var above := _above(more[i])
		_neighbours(more[i], more[maxi(i - 1, 0)], more[mini(i + 1, more.size() - 1)], above, more[i])
	_neighbours(_close, top_right, _close, _close, top_right)


func _neighbours(control: Control, left: Control, right: Control, up: Control, down: Control) -> void:
	control.focus_neighbor_left = control.get_path_to(left)
	control.focus_neighbor_right = control.get_path_to(right)
	control.focus_neighbor_top = control.get_path_to(up)
	control.focus_neighbor_bottom = control.get_path_to(down)
	control.focus_next = control.get_path_to(right)
	control.focus_previous = control.get_path_to(left)


## The MORE tile most nearly under `tile` (itself when there's no MORE row).
func _below(tile: Tile, more: Array[Tile]) -> Control:
	var best: Control = tile
	var gap := INF
	for other in more:
		var apart := absf(other.position.x + other.size.x * 0.5 - (tile.position.x + tile.size.x * 0.5))
		if apart < gap:
			gap = apart
			best = other
	return best


## Down into the MORE row from a wall tile: up from there goes back to it
## (two wall tiles can sit over one MORE tile).
func _on_focus_changed(focus: Control) -> void:
	if not visible:
		return
	var wall := [_featured] + _grid
	if focus in _more and _last_focus in wall:
		focus.focus_neighbor_top = focus.get_path_to(_last_focus)
	_last_focus = focus


## The wall tile most nearly over MORE tile `tile`: the featured tile on the
## left half, else the bottom single tile above it.
func _above(tile: Tile) -> Control:
	var middle := tile.position.x + tile.size.x * 0.5
	if middle < _featured.position.x + _featured.size.x:
		return _featured
	return _grid[2] if middle < _grid[3].position.x else _grid[3]


## Plays `mode`; Fish Sticks first asks which of its two, and Unnatural how
## long a run (P5).
func _choose(mode: String) -> void:
	if mode == FISH_STICKS or mode == UNNATURAL:
		_rules.visible = false
		_build_variants(mode)
		_variants.visible = true
		_rules_dim.visible = true
		var first := _variant_buttons[clampi(UnnaturalSettings.shared().run_length, 0, 2)] if mode == UNNATURAL else _variant_buttons[0]
		first.grab_focus.call_deferred()
	else:
		chosen.emit(mode)


## The variants pop-up's buttons for `mode`: Fish Sticks' two modes, or
## Unnatural's run lengths (setting run_length, then playing Unnatural).
func _build_variants(mode: String) -> void:
	_variants_mode = mode
	for button in _variant_buttons:
		button.queue_free()
	_variant_buttons.clear()
	var options := []  # [label, what pressing it does]
	if mode == UNNATURAL:
		_variants_title.text = "Unnatural"
		_variants_line.text = "Survive the blood moon. How long a night?"
		var labels := ["Short  ·  1 stage", "Standard  ·  %d stages" % UnnaturalSettings.shared().standard_stages, "Endless"]
		for n in RUN_LENGTHS.size():
			options.append([labels[n], func() -> void:
				UnnaturalSettings.shared().run_length = n
				chosen.emit(UNNATURAL)])
	else:
		_variants_title.text = "Fish Sticks"
		_variants_line.text = "Fish-ball in the aquarium arena. How do you want to play?"
		for variant: String in FISH_STICKS_MODES:
			options.append(["1v1 against a bot" if variant == "1v1" else "Free Play", func() -> void: chosen.emit(variant)])
	var width := (520.0 if options.size() <= 2 else 660.0) * s
	_variants.custom_minimum_size = Vector2(width, 0.0)
	_variants.size = Vector2(width, 0.0)
	_variants.position = Vector2(PANEL_SIZE.x * s * 0.5 - width * 0.5, 170.0 * s)
	for option: Array in options:
		var button := Button.new()
		button.text = option[0]
		button.custom_minimum_size = Vector2(180.0 if options.size() > 2 else 230.0, 64.0) * s
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", UITheme.display(600))
		button.add_theme_font_size_override("font_size", roundi((18.0 if options.size() > 2 else 20.0) * s))
		button.add_theme_stylebox_override("normal", UITheme.box(UITheme.GROUND, 14.0 * s, Color(UITheme.MUTED, 0.4), maxf(1.0, s)))
		button.add_theme_stylebox_override("hover", UITheme.box(UITheme.GROUND.lightened(0.08), 14.0 * s, UITheme.AQUA, maxf(1.0, 1.5 * s)))
		button.add_theme_stylebox_override("focus", UITheme.box(Color(UITheme.AQUA, 0.14), 14.0 * s, UITheme.AQUA, 3.0 * s))
		var act: Callable = option[1]
		button.pressed.connect(func() -> void:
			_hide_variants(false)
			act.call())
		_variants_row.add_child(button)
		_variant_buttons.append(button)


func _hide_variants(refocus := true) -> void:
	_variants.visible = false
	_rules_dim.visible = false
	if refocus:
		for tile: Tile in [_featured] + _grid + _more:
			if tile.mode == _variants_mode:
				tile.grab_focus()


func _cancel() -> void:
	if _variants.visible:
		_hide_variants()
		return
	if _rules.visible:
		_hide_rules()
		return
	visible = false
	closed.emit()


func _show_rules(mode: String) -> void:
	_rules_mode = mode
	_rules_title.text = _tiles.get(mode, {}).get("title", mode)
	var text: String = _rules_for.call(mode) if _rules_for.is_valid() else ""
	if text == mode:  # not a match mode: its pitch instead
		text = _tiles.get(mode, {}).get("pitch", "")
	for prefix: String in [mode + ": ", _rules_title.text + ": "]:
		text = text.trim_prefix(prefix)  # "Hunt: 1v1 in open water..." under the title Hunt
	_rules_text.text = text[0].to_upper() + text.substr(1) if text else ""
	_rules.visible = true
	_rules_dim.visible = true


func _hide_rules() -> void:
	_rules.visible = false
	_rules_dim.visible = false
	for tile: Tile in [_featured] + _grid + _more:
		if tile.mode == _rules_mode:
			tile.grab_focus()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if MenuNav.is_direction(event):
		# Round the wall only, never out to the menu behind it (nor under the rules).
		var toward := _nav.side(event)
		if toward >= 0 and _variants.visible:
			var at := _variant_buttons.find(get_viewport().gui_get_focus_owner() as Button)
			if toward == SIDE_LEFT:
				_variant_buttons[maxi(at - 1, 0)].grab_focus()
			elif toward == SIDE_RIGHT:
				_variant_buttons[mini(at + 1, _variant_buttons.size() - 1)].grab_focus()
		elif toward >= 0 and not _rules.visible:
			MenuNav.step(get_viewport().gui_get_focus_owner(), toward, _panel)
		get_viewport().set_input_as_handled()
		return
	if _variants.visible:
		if event.is_action_pressed("ui_cancel"):
			_hide_variants()
			get_viewport().set_input_as_handled()
		return  # A: the focused button's own
	if _rules.visible:
		if event.is_action_pressed("ui_accept"):
			_choose(_rules_mode)
		elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_rules"):
			_hide_rules()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel()
	elif event.is_action_pressed("ui_rules"):
		var focus := get_viewport().gui_get_focus_owner()
		if focus is Tile and (focus as Tile).mode:
			_show_rules((focus as Tile).mode)
	else:
		return
	get_viewport().set_input_as_handled()


## A mode's tile: its colours, line icon, name and pitch. The featured one
## (big) also has a LAST PLAYED badge and how the mode can be played; the
## MORE row's (slim) are a pill with an icon and a name.
class Tile extends Button:
	var mode := ""
	var big := false
	var slim := false
	var s := 1.0
	var _info := {}

	func _init() -> void:
		action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(func() -> void:
			grab_focus())

	func show_mode(new_mode: String, info: Dictionary) -> void:
		mode = new_mode
		_info = info
		disabled = new_mode.is_empty()
		queue_redraw()

	func _draw() -> void:
		if mode.is_empty():
			return
		var rect := Rect2(Vector2.ZERO, size)
		var colors: Array = _info.get("colors", [UITheme.PANEL, UITheme.AQUA])
		var deep: Color = colors[0]
		var accent: Color = colors[1]
		var radius := (14.0 if slim else 20.0) * s
		var lit := has_focus()
		UITheme.draw_box(self, rect, deep, radius)
		if not slim:
			# A soft glow of the mode's colour from the top-right corner, following
			# the tile's rounded corner so nothing shows past it.
			var glow := PackedVector2Array([Vector2(size.x * 0.3, 0.0)])
			var tints := PackedColorArray([Color(accent, 0.0)])
			var centre := Vector2(size.x - radius, radius)
			for n in 7:
				var angle := -PI * 0.5 + n * PI * 0.5 / 6.0
				glow.append(centre + Vector2(cos(angle), sin(angle)) * radius)
				tints.append(Color(accent, 0.2))
			glow.append(Vector2(size.x, size.y * 0.8))
			tints.append(Color(accent, 0.0))
			glow.append(Vector2(size.x * 0.62, size.y * 0.45))
			tints.append(Color(accent, 0.0))
			draw_polygon(glow, tints)
		var title: String = _info.get("title", mode)
		var icon: String = _info.get("icon", "")
		if slim:
			HexBadge.draw_glyph(self, icon, Vector2(26.0 * s, size.y * 0.5), 24.0 * s, accent, 2.0)
			UITheme.draw_text(self, Rect2(48.0 * s, 0.0, size.x - 56.0 * s, size.y), title, UITheme.body(600), roundi(17.0 * s), UITheme.INK,
					HORIZONTAL_ALIGNMENT_LEFT)
		elif big:
			HexBadge.draw_glyph(self, icon, Vector2(size.x - 120.0 * s, 120.0 * s), 150.0 * s, Color(accent, 0.85), 1.4)
			var badge_px := roundi(12.0 * s)
			var badge_font := UITheme.caps(badge_px, 700, 0.22)
			var badge_text := "LAST PLAYED"
			var badge_width := badge_font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_px).x + 24.0 * s
			var badge := Rect2(28.0 * s, 28.0 * s, badge_width, 26.0 * s)
			UITheme.draw_box(self, badge, UITheme.CORAL, 13.0 * s)
			UITheme.draw_text(self, badge, badge_text, badge_font, badge_px, UITheme.GROUND)
			UITheme.draw_text(self, Rect2(28.0 * s, size.y - 196.0 * s, size.x - 56.0 * s, 64.0 * s), title, UITheme.display(700),
					roundi(52.0 * s), UITheme.INK, HORIZONTAL_ALIGNMENT_LEFT)
			UITheme.draw_wrapped(self, Rect2(28.0 * s, size.y - 124.0 * s, size.x - 80.0 * s, 52.0 * s), _info.get("pitch", ""),
					UITheme.body(500), roundi(17.0 * s), UITheme.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
			var x := 28.0 * s
			for chip: String in _info.get("play", ["Solo"]):
				var chip_px := roundi(14.0 * s)
				var chip_font := UITheme.body(600)
				var chip_width := chip_font.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, chip_px).x + 28.0 * s
				var chip_rect := Rect2(x, size.y - 56.0 * s, chip_width, 30.0 * s)
				UITheme.draw_box(self, chip_rect, Color(UITheme.GROUND, 0.55), 15.0 * s, Color(accent, 0.7), maxf(1.0, 1.5 * s))
				UITheme.draw_text(self, chip_rect, chip, chip_font, chip_px, UITheme.INK)
				x += chip_width + 10.0 * s
		else:
			HexBadge.draw_glyph(self, icon, Vector2(42.0 * s, 44.0 * s), 40.0 * s, accent, 1.8)
			UITheme.draw_text(self, Rect2(22.0 * s, size.y - 78.0 * s, size.x - 44.0 * s, 34.0 * s), title, UITheme.display(600),
					roundi(25.0 * s), UITheme.INK, HORIZONTAL_ALIGNMENT_LEFT)
			var line: String = _info.get("short", _info.get("pitch", ""))
			var line_px := roundi(14.0 * s)
			UITheme.draw_text(self, Rect2(22.0 * s, size.y - 44.0 * s, size.x - 44.0 * s, 22.0 * s), line, UITheme.body(400), line_px,
					UITheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		if lit:
			UITheme.draw_box(self, rect, Color(UITheme.AQUA, 0.12), radius, UITheme.AQUA, 2.0 * s)
