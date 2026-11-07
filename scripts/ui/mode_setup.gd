class_name ModeSetup
extends CanvasLayer
## The setup screen (mock "E · Rail + Two-Tier Hero"): a rail down the left with
## the mode's name and its setup items, a hero on the right for whichever item
## has focus. The fish item (a pool of classes, each with species) is two-tier:
## LB / RB (or left / right) change the class, LT / RT the species. Every other
## item is a row of values: left / right (or LB / RB) change it. Up / down move
## between items, A confirms, B backs out. Used for a mode's options + character
## (the mode picker), a new player's character (joining a match) and the pause
## menu's Change Character (just the fish item).
##
## Set the fields below, then add it to the tree. It reads input itself (every
## pad, or only `device`'s), so it works while the game's paused and while
## others play on.

signal confirmed
signal cancelled

const PANEL_SIZE := Vector2(1120.0, 640.0)
const RAIL_WIDTH := 330.0

## "Game mode" / "Change character" over the title.
var kicker := "Game mode"
var title := ""
var blurb := ""
var accent := UITheme.AQUA
var confirm_text := "Dive in"
## -1: any controller or the keyboard. A pad's index: only that pad (a joining player's).
var device := -1
## The fish item's pool: [{"name", "line", "character": FishClass or -1, "species":
## [{"name", "note"}]}]. Empty: no fish item.
var pool: Array = []
var pool_label := "Class"
var species_label := "Species"
var pool_index := 0
var species_index := 0
## Called with (pool_index, species_index) when either changes.
var pool_changed := func(_pool: int, _species: int) -> void: pass
## The other items: [{"label", "options": [{"name", "desc"}], "index", "changed": Callable(index)}].
var rows: Array = []

var _s := 1.0
var _focus := 0
var _rail: VBoxContainer
var _pane: VBoxContainer
var _hint: Label
var _dim: ColorRect
var _panel: PanelContainer
var _items: Array[Button] = []
var _showcase: HomeScreen.FishShowcase
var _triggers_held := {}
var _nav := MenuNav.new()
var _done := false


## The fish pool for the fish classes, with their species; each class opens on the
## species `role` last wore it in.
static func fish_pool(role := RoleCharacters.DEFAULT) -> Array:
	var entries := []
	for fish_class: FishCharacter.FishClass in FishCharacter.pickable_classes():
		var species := []
		for i in FishCharacter.species_count(fish_class):
			if FishCharacter.is_species_unlocked(fish_class, i):
				species.append({"name": FishCharacter.species_name(fish_class, i), "note": "", "index": i})
		var entry := {"name": FishCharacter.display_name(fish_class), "line": "", "character": fish_class, "species": species, "slot": 0}
		entry.slot = species_slot(entry, RoleCharacters.species(role, fish_class))
		entries.append(entry)
	return entries


## `pool_index` / `species_index` for the fish `role` last played, for a caller to set.
static func last_pick(entries: Array, role: String) -> Vector2i:
	var fish_class := RoleCharacters.character(role)
	var at := pool_index_of(entries, fish_class)
	return Vector2i(at, int(entries[at].slot))

## The FishCharacter species index behind slot `slot` of pool entry `entry`.
static func species_of(entry: Dictionary, slot: int) -> int:
	return int(entry.species[slot].get("index", slot)) if not entry.species.is_empty() else int(entry.get("preview_species", 0))


## The fish pool's index of `fish_class`.
static func pool_index_of(entries: Array, fish_class: FishCharacter.FishClass) -> int:
	for i in entries.size():
		if int(entries[i].character) == int(fish_class):
			return i
	return 0


## The species slot of `species` (a FishCharacter species index) in a fish pool entry.
static func species_slot(entry: Dictionary, species: int) -> int:
	for i in entry.species.size():
		if int(entry.species[i].get("index", i)) == species:
			return i
	return 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8  # over the home screen, the pause menu and the match card
	_s = UITheme.scale_for(get_viewport())
	var s := _s
	_dim = ColorRect.new()
	_dim.color = UITheme.DIM
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.theme = UITheme.theme(s)
	_panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.GROUND, 28.0 * s, Color(UITheme.INK, 0.12), maxf(1.0, s)))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = PANEL_SIZE * s
	add_child(_panel)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 0)
	_panel.add_child(split)

	# The rail.
	var rail_box := PanelContainer.new()
	rail_box.custom_minimum_size.x = RAIL_WIDTH * s
	rail_box.add_theme_stylebox_override("panel", UITheme.box(Color(accent, 0.14), 0.0))
	split.add_child(rail_box)
	var rail_margin := MarginContainer.new()
	for side in ["left", "right"]:
		rail_margin.add_theme_constant_override("margin_" + side, roundi(22.0 * s))
	rail_margin.add_theme_constant_override("margin_top", roundi(30.0 * s))
	rail_margin.add_theme_constant_override("margin_bottom", roundi(24.0 * s))
	rail_box.add_child(rail_margin)
	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", roundi(8.0 * s))
	rail_margin.add_child(_rail)
	_rail.add_child(UITheme.label(kicker, "caps", 12.0, accent, s, 600))
	_rail.add_child(UITheme.label(title, "display", 34.0, UITheme.INK, s, 700))
	if blurb != "":
		var line := UITheme.label(blurb, "body", 13.0, UITheme.MUTED, s)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = (RAIL_WIDTH - 44.0) * s
		_rail.add_child(line)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10.0 * s
	_rail.add_child(gap)
	_rail.add_child(UITheme.label("Setup", "caps", 12.0, UITheme.MUTED, s, 600))
	if not pool.is_empty():
		_items.append(_rail_item(0))
	for i in rows.size():
		_items.append(_rail_item(i + (1 if not pool.is_empty() else 0)))

	# The right side: the hero, then the hint line and the buttons.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 0)
	split.add_child(right)
	_pane = VBoxContainer.new()
	_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pane.add_theme_constant_override("separation", roundi(10.0 * s))
	var pane_margin := MarginContainer.new()
	pane_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane_margin.add_theme_constant_override("margin_left", roundi(28.0 * s))
	pane_margin.add_theme_constant_override("margin_right", roundi(28.0 * s))
	pane_margin.add_theme_constant_override("margin_top", roundi(24.0 * s))
	pane_margin.add_theme_constant_override("margin_bottom", roundi(14.0 * s))
	pane_margin.add_child(_pane)
	right.add_child(pane_margin)
	right.add_child(_footer(s))

	if not pool.is_empty():
		_showcase = HomeScreen.FishShowcase.new()
		_showcase.custom_minimum_size = Vector2(300.0, 120.0) * s
		_showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_refresh()


func _footer(s: float) -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UITheme.box(Color(0, 0, 0, 0.2), 0.0))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", roundi(28.0 * s))
	margin.add_theme_constant_override("margin_right", roundi(28.0 * s))
	margin.add_theme_constant_override("margin_top", roundi(14.0 * s))
	margin.add_theme_constant_override("margin_bottom", roundi(14.0 * s))
	bar.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(12.0 * s))
	margin.add_child(row)
	_hint = UITheme.label("", "body", 12.0, UITheme.MUTED, s)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_hint)
	row.add_child(_footer_button("B  Back", false, cancel, s))
	row.add_child(_footer_button("A  " + confirm_text, true, confirm, s))
	return bar


func _footer_button(text: String, primary: bool, on_pressed: Callable, s: float) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150.0 if primary else 120.0, 48.0) * s
	button.add_theme_font_override("font", UITheme.display(600))
	button.add_theme_font_size_override("font_size", roundi(18.0 * s))
	var fill := accent if primary else Color(0, 0, 0, 0)
	var border := accent if primary else Color(UITheme.INK, 0.2)
	button.add_theme_stylebox_override("normal", UITheme.box(fill, 12.0 * s, border, maxf(1.0, s)))
	button.add_theme_stylebox_override("hover", UITheme.box(fill.lightened(0.1), 12.0 * s, border, maxf(1.0, s)))
	button.add_theme_stylebox_override("pressed", UITheme.box(fill.darkened(0.1), 12.0 * s, border, maxf(1.0, s)))
	if primary:
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(state, UITheme.DEEP)
	button.pressed.connect(on_pressed)
	return button


## A rail button for item `at` (0 is the fish when there is one). Pressing it focuses it.
func _rail_item(at: int) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = (88.0 if _is_fish(at) else 58.0) * _s
	button.add_theme_font_override("font", UITheme.display(600))
	button.add_theme_font_size_override("font_size", roundi(17.0 * _s))
	button.pressed.connect(func() -> void:
		_focus = at
		_refresh())
	_rail.add_child(button)
	return button


func _is_fish(at: int) -> bool:
	return at == 0 and not pool.is_empty()


func _row_of(at: int) -> Dictionary:
	return rows[at - (1 if not pool.is_empty() else 0)]


## Everything redrawn: the rail's buttons and the hero.
func _refresh() -> void:
	var s := _s
	for at in _items.size():
		var on := at == _focus
		var button := _items[at]
		if _is_fish(at):
			var entry: Dictionary = pool[pool_index]
			button.text = "%s\n%s" % [str(entry.name), _species_name()] if not entry.species.is_empty() else str(entry.name)
		else:
			var row := _row_of(at)
			button.text = "%s\n%s" % [str(row.label), str(row.options[int(row.index)].name)]
		var fill := Color(UITheme.INK, 0.09 if on else 0.03)
		var border := accent if on else Color(UITheme.INK, 0.08)
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := UITheme.box(fill, 14.0 * s, border, maxf(1.0, s) * (2.0 if on else 1.0))
			box.content_margin_left = 16.0 * s
			box.content_margin_right = 12.0 * s
			button.add_theme_stylebox_override(state, box)
	if _showcase and _showcase.get_parent():
		_showcase.get_parent().remove_child(_showcase)  # kept: the hero's rebuilt round it
	for child in _pane.get_children():
		child.queue_free()
	if _is_fish(_focus):
		_build_fish_pane()
		var parts: Array[String] = []
		if pool.size() > 1:
			parts.append("LB / RB  %s" % pool_label.to_lower())
		if not pool[pool_index].species.is_empty():
			parts.append("LT / RT  %s" % species_label.to_lower())
		if _items.size() > 1:
			parts.append("D-pad up / down  setting")
		_hint.text = "   ·   ".join(parts)
	else:
		_build_row_pane(_row_of(_focus))
		_hint.text = "LB / RB or left / right  change the value   ·   D-pad up / down  setting"


## Redraws after the caller changed the pool or the rows (e.g. a role switch).
func refresh() -> void:
	if _pane:
		_refresh()


func _species_name() -> String:
	var entry: Dictionary = pool[pool_index]
	return str(entry.species[clampi(species_index, 0, entry.species.size() - 1)].name) if not entry.species.is_empty() else ""


func _pane_header(left: String, right: String, size := 20.0) -> void:
	var row := HBoxContainer.new()
	var title_label := UITheme.label(left, "display", size, UITheme.INK, _s, 700)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	row.add_child(UITheme.label(right, "body", 12.0, UITheme.MUTED, _s))
	_pane.add_child(row)


func _arrow(glyph: String, tag: String, on_pressed: Callable, height: float) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [tag, glyph]
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(52.0, height) * _s
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", roundi(16.0 * _s))
	button.pressed.connect(on_pressed)
	return button


func _build_fish_pane() -> void:
	var s := _s
	var count := pool.size()
	_pane_header(pool_label, "%d of %d" % [pool_index + 1, count])
	# Tier 1: the class strip, the one picked in the middle.
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", roundi(8.0 * s))
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	if count > 1:
		strip.add_child(_arrow("‹", "LB", cycle_pool.bind(-1), 64.0))
	var chips := HBoxContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", roundi(8.0 * s))
	var reach := mini(2, (count - 1) / 2)
	for d in range(-reach, reach + 1):
		var chip := Button.new()
		chip.focus_mode = Control.FOCUS_NONE
		var mid := d == 0
		chip.text = str(pool[posmod(pool_index + d, count)].name)
		chip.custom_minimum_size = Vector2((170.0 if mid else 110.0), 64.0) * s
		chip.clip_text = true
		chip.modulate.a = 1.0 if mid else (0.7 if absi(d) == 1 else 0.4)
		chip.add_theme_font_size_override("font_size", roundi((17.0 if mid else 13.0) * s))
		var border := accent if mid else Color(UITheme.INK, 0.1)
		for state in ["normal", "hover", "pressed"]:
			chip.add_theme_stylebox_override(state, UITheme.box(Color(UITheme.INK, 0.1 if mid else 0.04), 14.0 * s, border, maxf(1.0, s) * (2.0 if mid else 1.0)))
		chip.pressed.connect(cycle_pool.bind(d))
		chips.add_child(chip)
	strip.add_child(chips)
	if count > 1:
		strip.add_child(_arrow("›", "RB", cycle_pool.bind(1), 64.0))
	_pane.add_child(strip)
	var entry: Dictionary = pool[pool_index]
	if entry.species.is_empty():
		var line := UITheme.label(str(entry.line), "body", 14.0, UITheme.MUTED, s)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pane.add_child(line)
	else:
		# Tier 2: species, over the fish itself.
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 6.0 * s
		_pane.add_child(spacer)
		_pane_header("%s  ·  %s" % [species_label, str(entry.name)], "%d of %d" % [species_index + 1, entry.species.size()])
	var hero := HBoxContainer.new()
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.add_theme_constant_override("separation", roundi(12.0 * s))
	var has_tier: bool = entry.species.size() > 1
	if has_tier:
		hero.add_child(_arrow("‹", "LT", cycle_species.bind(-1), 120.0))
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", roundi(4.0 * s))
	if _showcase and int(entry.character) >= 0:
		card.add_child(_showcase)
	var name_label := UITheme.label(_species_name() if not entry.species.is_empty() else str(entry.name), "display", 30.0, UITheme.INK, s, 700)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)
	if not entry.species.is_empty():
		var note: String = str(entry.species[species_index].note)
		if note != "":
			var note_label := UITheme.label(note, "body", 13.0, UITheme.MUTED, s)
			note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(note_label)
	hero.add_child(card)
	if has_tier:
		hero.add_child(_arrow("›", "RT", cycle_species.bind(1), 120.0))
	_pane.add_child(hero)
	if _showcase and _showcase.get_parent() == card:
		# Only now in the tree: it places its camera as it shows the fish.
		if entry.has("form"):
			_showcase.show_form(entry.form)
		else:
			_showcase.show_fish(entry.character, species_of(entry, species_index))


func _build_row_pane(row: Dictionary) -> void:
	var s := _s
	var options: Array = row.options
	var at: int = int(row.index)
	_pane_header(str(row.label), "%d of %d" % [at + 1, options.size()], 24.0)
	var line := HBoxContainer.new()
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", roundi(16.0 * s))
	line.add_child(_arrow("‹", "LB", cycle_row.bind(-1), 96.0))
	var cards := HBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", roundi(14.0 * s))
	var reach := mini(1, (options.size() - 1) / 2)
	for d in range(-reach, reach + 1):
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var mid := d == 0
		var option: Dictionary = options[posmod(at + d, options.size())]
		card.text = "%s\n%s" % [str(option.name), str(option.get("desc", ""))] if mid else str(option.name)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.clip_text = true
		card.custom_minimum_size = (Vector2(250.0, 230.0) if mid else Vector2(140.0, 160.0)) * s
		card.modulate.a = 1.0 if mid else 0.5
		card.add_theme_font_size_override("font_size", roundi((22.0 if mid else 16.0) * s))
		var border := accent if mid else Color(UITheme.INK, 0.1)
		for state in ["normal", "hover", "pressed"]:
			card.add_theme_stylebox_override(state, UITheme.box(Color(UITheme.INK, 0.1 if mid else 0.04), 20.0 * s, border, maxf(1.0, s) * (2.0 if mid else 1.0)))
		card.pressed.connect(cycle_row.bind(d))
		cards.add_child(card)
	line.add_child(cards)
	line.add_child(_arrow("›", "RB", cycle_row.bind(1), 96.0))
	_pane.add_child(line)


## Class (or hunter form...) `step` along.
func cycle_pool(step: int) -> void:
	if pool.is_empty() or step == 0:
		return
	pool_index = posmod(pool_index + step, pool.size())
	species_index = clampi(_remembered_slot(), 0, maxi(pool[pool_index].species.size() - 1, 0))
	pool_changed.call(pool_index, species_index)
	refresh()


## The species slot to open a newly shown class on: its owner's say (pool entry "slot"), else the first.
func _remembered_slot() -> int:
	return int(pool[pool_index].get("slot", 0))


func cycle_species(step: int) -> void:
	if pool.is_empty():
		return
	var count: int = pool[pool_index].species.size()
	if count <= 1:
		return
	species_index = posmod(species_index + step, count)
	pool_changed.call(pool_index, species_index)
	refresh()


func cycle_row(step: int) -> void:
	if _is_fish(_focus) or step == 0:
		return
	var row := _row_of(_focus)
	var count: int = row.options.size()
	row.index = posmod(int(row.index) + step, count)
	var changed: Callable = row.changed
	changed.call(int(row.index))
	refresh()


## Every option's setting again, as picked (a mode's entering can restore stored tuning
## over them, so the caller re-applies once it's in).
func reapply() -> void:
	for row: Dictionary in rows:
		var setter: Callable = row.set
		setter.call(int(row.index))


func confirm() -> void:
	_finish(true)


func cancel() -> void:
	_finish(false)


func _finish(accepted: bool) -> void:
	if _done:
		return
	_done = true
	if _showcase and _showcase.get_parent() == null:
		_showcase.queue_free()
	visible = false
	if accepted:
		confirmed.emit()
	else:
		cancelled.emit()
	queue_free()


## Whether `event` is this screen's to read (`device`'s pad only, when it's one's).
func _mine(event: InputEvent) -> bool:
	if device < 0:
		return true
	return (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device == device


func _input(event: InputEvent) -> void:
	if _done or not _mine(event):
		return
	if event.is_action_pressed("ui_cancel"):
		cancel()
	elif event.is_action_pressed("ui_accept"):
		confirm()
	elif MenuNav.is_direction(event):
		# The stick counts as the D-pad: one step per push, back to the middle between.
		match _nav.side(event):
			SIDE_TOP:
				_focus = maxi(_focus - 1, 0)
				_refresh()
			SIDE_BOTTOM:
				_focus = mini(_focus + 1, _items.size() - 1)
				_refresh()
			SIDE_LEFT:
				_step(-1)
			SIDE_RIGHT:
				_step(1)
	elif event.is_action_pressed("ui_page_previous"):
		_step(-1)
	elif event.is_action_pressed("ui_page_next"):
		_step(1)
	elif event.is_action_pressed("ui_section_previous") and not _is_pad_trigger(event):
		cycle_species(-1)
	elif event.is_action_pressed("ui_section_next") and not _is_pad_trigger(event):
		cycle_species(1)
	else:
		if device < 0 and (event is InputEventKey or event is InputEventJoypadButton):
			get_viewport().set_input_as_handled()  # the screens under it (the picker's X rules...) stay out of it
		return
	get_viewport().set_input_as_handled()


## Left / right: the class on the fish item, the value on the others.
func _step(direction: int) -> void:
	if _is_fish(_focus):
		cycle_pool(direction)
	else:
		cycle_row(direction)


## The triggers are axes: _process reads them on the pull instead (so a held one fires once).
func _is_pad_trigger(event: InputEvent) -> bool:
	return event is InputEventJoypadMotion


func _process(_delta: float) -> void:
	if _done:
		return
	for pair: Array in [[JOY_AXIS_TRIGGER_LEFT, "ui_section_previous", -1], [JOY_AXIS_TRIGGER_RIGHT, "ui_section_next", 1]]:
		var axis: int = pair[0]
		var action: String = pair[1]
		var held: bool = Input.get_joy_axis(device, axis) > 0.5 if device >= 0 else Input.is_action_pressed(action)
		var pulled: bool = held and not _triggers_held.get(action, false)
		_triggers_held[action] = held
		if pulled and _is_fish(_focus):
			cycle_species(pair[2])
