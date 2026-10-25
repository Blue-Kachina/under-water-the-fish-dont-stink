class_name HomeScreen
extends CanvasLayer
## The home screen the game launches to (UI Redesign Handoff, Home A · Reef
## Console): the title and menu down the left (Play, with the last mode played
## under it; Choose mode, Co-op, Replays, Settings, Quit), the player's fish
## live in 3D on the right (‹ ›, left/right or LB/RB change it; its species under
## its name, the small ‹ › or LT/RT change that; its stat bias under it),
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
signal character_changed(character: FishCharacter.FishClass)
## The species selector (its ‹ ›, or LT/RT, Home/End): wear species `species` of the
## shown fish from now on.
signal species_changed(species: int)

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
var _species_name: Label
var _species_count: Label
## LT / RT as held last frame (triggers are sticks to Godot: species step on the pull).
var _triggers_held := {}
var _chip_name: Label
var _chip_initial: Label
var _hints: ControllerHints
var _picker: ModePicker
var _back: Control
var _konami := KonamiCode.new()
var _replays_button: Button
## The Class details panel down the left (over the title and menu), the dim
## strip at its edge with it; its contents (rebuilt for each fish); the button
## that opens it.
var _details: Control
var _details_body: VBoxContainer
var _details_button: Button
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
	_showcase.offset_bottom = -232.0 * s
	_root.add_child(_showcase)
	var caption := HBoxContainer.new()
	caption.anchor_left = 0.5
	caption.anchor_right = 1.0
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_left = 20.0 * s
	caption.offset_right = -40.0 * s
	caption.offset_top = -228.0 * s
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
	# The species under the name: ‹ name › (LT / RT), and which of how many.
	var species_row := HBoxContainer.new()
	species_row.alignment = BoxContainer.ALIGNMENT_CENTER
	species_row.add_theme_constant_override("separation", roundi(10.0 * s))
	names.add_child(species_row)
	species_row.add_child(_species_arrow("‹", -1))
	var species_text := VBoxContainer.new()
	species_text.alignment = BoxContainer.ALIGNMENT_CENTER
	species_text.custom_minimum_size.x = 250.0 * s
	species_text.add_theme_constant_override("separation", 0)
	species_row.add_child(species_text)
	_species_name = UITheme.label("", "body", 18.0, UITheme.AQUA, s, 600)
	_species_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	species_text.add_child(_species_name)
	_species_count = UITheme.label("", "caps", 11.0, UITheme.MUTED, s, 600)
	_species_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	species_text.add_child(_species_count)
	species_row.add_child(_species_arrow("›", 1))
	_fish_bias = UITheme.label("", "caps", 14.0, UITheme.CORAL, s, 700)
	_fish_bias.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_child(_fish_bias)
	caption.add_child(_arrow("›", 1))
	_details_button = Button.new()
	_details_button.focus_mode = Control.FOCUS_NONE
	_details_button.anchor_left = 0.5
	_details_button.anchor_right = 1.0
	_details_button.anchor_top = 1.0
	_details_button.anchor_bottom = 1.0
	_details_button.offset_left = 190.0 * s
	_details_button.offset_right = -190.0 * s
	_details_button.offset_top = -100.0 * s
	_details_button.offset_bottom = -64.0 * s
	_details_button.add_theme_font_override("font", UITheme.display(500))
	_details_button.add_theme_font_size_override("font_size", roundi(16.0 * s))
	_details_button.add_theme_stylebox_override("hover", UITheme.box(UITheme.PANEL.lightened(0.1), 18.0 * s, UITheme.AQUA, maxf(1.0, 1.5 * s)))
	_details_button.pressed.connect(_toggle_details)
	_root.add_child(_details_button)
	_build_details(s)

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

	_show_replays_button()  # once the Konami code's been entered
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
			_refresh_chip()
		elif key == "konami_entered":
			_show_replays_button())


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
	_set_details(false)
	get_tree().paused = true
	for action: String in ["ui_section_previous", "ui_section_next"]:
		_triggers_held[action] = Input.is_action_pressed(action)  # RT is the throttle: held on the way in doesn't count
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
	_hints.hints = [["A", "Select"], ["LB/RB", "Class"], ["LT/RT", "Species"], ["Y", "Class details"]] +([["B", "Back to game"]] if _can_resume else [])
	_show_fish(_character())
	_refresh_chip()


func _refresh_chip() -> void:
	var player := UISettings.display_name()
	_chip_name.text = player
	_chip_initial.text = player.left(1).to_upper()


func _character() -> FishCharacter.FishClass:
	if main and main.has_node("Fish"):
		return main.get_node("Fish").character
	return FishCharacter.FishClass.SKIRMISHER


## The species `character` is worn in: the player's fish's, if it's that fish.
func _species(character: FishCharacter.FishClass) -> int:
	if main and main.has_node("Fish"):
		var fish: FishController = main.get_node("Fish")
		if fish.character == character:
			return fish.species
	return 0


func _show_fish(character: FishCharacter.FishClass) -> void:
	var species := _species(character)
	_showcase.show_fish(character, species)
	_fish_name.text = FishCharacter.display_name(character)
	_species_name.text = FishCharacter.species_name(character, species)
	_species_count.text = ("Species %d of %d" % [species + 1, FishCharacter.species_count(character)]).to_upper()
	_fish_bias.text = ("%s +  ·  %s" % [StatBlock.title(StatBlock.signature(character)), Traversal.title(character)]).to_upper()
	_refresh_details()


## Shows or hides the Class details panel (the fish's weapon, growth stat,
## twist and skill). While it's up the menu under it is out of reach: left /
## right, LB / RB and LT / RT still change the fish, Y or B close it.
func _toggle_details() -> void:
	_set_details(not _details.visible)


func _set_details(shown: bool) -> void:
	_details.visible = shown
	if _hints:
		_hints.visible = not shown  # the panel has its own
	_details_button.text = "Hide details  (Y)" if shown else "Details  (Y)"
	_details_button.add_theme_stylebox_override("normal", UITheme.box(Color(UITheme.AQUA, 0.14), 18.0 * _s, UITheme.AQUA, maxf(1.0, 1.5 * _s)) if shown
			else UITheme.box(Color(UITheme.PANEL, 0.8), 18.0 * _s, Color(UITheme.MUTED, 0.4), maxf(1.0, _s)))
	_refresh_details()


## The panel down the left, 600 px wide, over the title and the menu, with a
## dim strip past its edge; the fish and its name stay in view on the right.
func _build_details(s: float) -> void:
	_details = Control.new()
	_details.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_details)
	var dim := ColorRect.new()
	dim.color = Color(UITheme.DIM, 0.55)
	dim.anchor_bottom = 1.0
	dim.offset_right = 640.0 * s
	_details.add_child(dim)  # catches clicks meant for the menu
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_right = 600.0 * s
	var box := UITheme.box(UITheme.DEEP, 22.0 * s, Color(UITheme.AQUA, 0.5), maxf(1.0, 1.5 * s))
	box.corner_radius_top_left = 0
	box.corner_radius_bottom_left = 0
	box.border_width_left = 0
	box.border_width_top = 0
	box.border_width_bottom = 0
	box.content_margin_left = 56.0 * s
	box.content_margin_right = 36.0 * s
	box.content_margin_top = 30.0 * s
	box.content_margin_bottom = 22.0 * s
	panel.add_theme_stylebox_override("panel", box)
	_details.add_child(panel)
	_details_body = VBoxContainer.new()
	_details_body.add_theme_constant_override("separation", roundi(11.0 * s))
	panel.add_child(_details_body)
	_set_details(false)


func _refresh_details() -> void:
	for child in _details_body.get_children():
		_details_body.remove_child(child)
		child.queue_free()
	if not _details.visible:
		return
	var s := _s
	var character := _character()
	var info := FishDetails.details(character)

	# The class's name, the species shown, and a way out.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", roundi(16.0 * s))
	_details_body.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", roundi(2.0 * s))
	header.add_child(titles)
	titles.add_child(UITheme.label("Class details", "caps", 13.0, UITheme.AQUA, s, 600))
	titles.add_child(UITheme.label(FishCharacter.display_name(character), "display", 40.0, UITheme.INK, s, 700))
	var playing := RichTextLabel.new()
	playing.bbcode_enabled = true
	playing.fit_content = true
	playing.scroll_active = false
	playing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	playing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	playing.add_theme_font_override("normal_font", UITheme.body(500))
	playing.add_theme_font_override("bold_font", UITheme.body(600))
	playing.add_theme_font_size_override("normal_font_size", roundi(15.0 * s))
	playing.add_theme_font_size_override("bold_font_size", roundi(15.0 * s))
	playing.add_theme_color_override("default_color", UITheme.MUTED)
	playing.text = "Playing as the [b][color=#%s]%s[/color][/b]." % [UITheme.AQUA.to_html(false), FishCharacter.species_name(character, _species(character))]
	titles.add_child(playing)
	var close_button := Button.new()
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.add_theme_stylebox_override("normal", UITheme.box(UITheme.PANEL, 22.0 * s, Color(UITheme.MUTED, 0.4), maxf(1.0, s)))
	close_button.add_theme_stylebox_override("hover", UITheme.box(UITheme.PANEL.lightened(0.08), 22.0 * s, UITheme.AQUA, maxf(1.0, 1.5 * s)))
	close_button.add_theme_stylebox_override("pressed", UITheme.box(UITheme.DEEP, 22.0 * s, UITheme.AQUA, maxf(1.0, 1.5 * s)))
	close_button.pressed.connect(_set_details.bind(false))
	header.add_child(close_button)
	var close_hint := ControllerHints.new()
	close_hint.s = s
	close_hint.hints = [["B", "Close"]]
	close_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_hint.offset_right = -16.0 * s
	close_button.custom_minimum_size = Vector2(close_hint.custom_minimum_size.x + 26.0 * s, 44.0 * s)
	close_button.add_child(close_hint)

	# Base stats, and the stat it grows by itself (wider, in coral).
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", roundi(10.0 * s))
	_details_body.add_child(tiles)
	tiles.add_child(_detail_tile("Health", str(info.hp), "HP", false))
	tiles.add_child(_detail_tile("Hit i-frames", "%.1f" % info.iframes, "s", false))
	var grows := _detail_tile("Grows each level", info.signature_amount, info.signature, true)
	grows.size_flags_stretch_ratio = 1.6
	tiles.add_child(grows)

	# Starting weapon: what it does and two tags.
	var weapon := _detail_card(info.weapon_id, HexBadge.Shape.DIAMOND, info.weapon, "Starting weapon")
	weapon.column.add_child(_detail_text(info.blurb))
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", roundi(6.0 * s))
	tags.add_theme_constant_override("v_separation", roundi(6.0 * s))
	for tag: String in info.tags:
		var chip := PanelContainer.new()
		var chip_box := UITheme.box(UITheme.DEEP, 10.0 * s)
		chip_box.set_content_margin(SIDE_LEFT, 10.0 * s)
		chip_box.set_content_margin(SIDE_RIGHT, 10.0 * s)
		chip_box.set_content_margin(SIDE_TOP, 3.0 * s)
		chip_box.set_content_margin(SIDE_BOTTOM, 3.0 * s)
		chip.add_theme_stylebox_override("panel", chip_box)
		chip.add_child(UITheme.label(tag, "body", 13.0, UITheme.INK_SOFT, s, 600))
		tags.add_child(chip)
	weapon.column.add_child(tags)

	# Passive: its headline number big on the right.
	var passive := _detail_card("detail_passive", HexBadge.Shape.CIRCLE, info.passive, "Passive")
	passive.column.add_child(_detail_text(info.passive_text))
	var passive_stat: Array = info.passive_stat
	if not passive_stat.is_empty():
		var headline := VBoxContainer.new()
		headline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		headline.add_theme_constant_override("separation", 0)
		var value := UITheme.label(passive_stat[0], "display", 26.0, UITheme.AQUA, s, 600)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		headline.add_child(value)
		var label := UITheme.label(passive_stat[1], "caps", 12.0, UITheme.MUTED, s, 600)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		headline.add_child(label)
		passive.row.add_child(headline)

	# Mobility: its numbers in a row of three.
	var skill := _detail_card("detail_skill", HexBadge.Shape.CIRCLE, info.skill, "Mobility", "RB")
	skill.column.add_child(_detail_text(info.skill_text))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", roundi(6.0 * s))
	var skill_stats: Array = info.skill_stats
	for n in 3:
		if n >= skill_stats.size():
			var filler := Control.new()
			filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stats.add_child(filler)
			continue
		var stat: Array = skill_stats[n]
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cell_box := UITheme.box(UITheme.DEEP, 10.0 * s)
		cell_box.set_content_margin(SIDE_LEFT, 10.0 * s)
		cell_box.set_content_margin(SIDE_RIGHT, 10.0 * s)
		cell_box.set_content_margin(SIDE_TOP, 4.0 * s)
		cell_box.set_content_margin(SIDE_BOTTOM, 5.0 * s)
		cell.add_theme_stylebox_override("panel", cell_box)
		var cell_text := VBoxContainer.new()
		cell_text.add_theme_constant_override("separation", 0)
		cell.add_child(cell_text)
		cell_text.add_child(UITheme.label(stat[0], "display", 17.0, UITheme.INK, s, 600))
		cell_text.add_child(UITheme.label(stat[1], "body", 12.0, UITheme.MUTED, s, 500))
		stats.add_child(cell)
	skill.column.add_child(stats)

	# Footnote and the panel's own controls, at the bottom.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_body.add_child(spacer)
	var note := _detail_text("Every class starts on the same base stats, and its species only change its looks.")
	note.add_theme_font_size_override("font_size", roundi(13.0 * s))
	note.add_theme_color_override("font_color", UITheme.MUTED)
	_details_body.add_child(note)
	var hints := ControllerHints.new()
	hints.s = s
	hints.hints = [["LB/RB", "Class"], ["LT/RT", "Species"], ["Y", "Hide"], ["B", "Close"]]
	hints.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_details_body.add_child(hints)


## One of the stat tiles under the class's name: a caps caption over a big
## value and its unit. `accent`: the class's own (coral, rimmed).
func _detail_tile(caption: String, value: String, unit: String, accent: bool) -> PanelContainer:
	var s := _s
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UITheme.box(Color(UITheme.CORAL, 0.1), 12.0 * s, Color(UITheme.CORAL, 0.45), maxf(1.0, s)) if accent \
			else UITheme.box(UITheme.PANEL, 12.0 * s)
	box.set_content_margin(SIDE_LEFT, 14.0 * s)
	box.set_content_margin(SIDE_RIGHT, 14.0 * s)
	box.set_content_margin(SIDE_TOP, 9.0 * s)
	box.set_content_margin(SIDE_BOTTOM, 8.0 * s)
	tile.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	tile.add_child(column)
	column.add_child(UITheme.label(caption, "caps", 12.0, UITheme.CORAL if accent else UITheme.MUTED, s, 700 if accent else 600))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(5.0 * s))
	column.add_child(row)
	row.add_child(UITheme.label(value, "display", 26.0, UITheme.INK, s, 600))
	var unit_label := UITheme.label(unit, "display", 15.0, UITheme.CORAL.lightened(0.35) if accent else UITheme.MUTED, s, 500)
	unit_label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(unit_label)
	return tile


## A card in the panel: its badge (`glyph` in `shape`), its name, what kind of
## thing it is (and the button it's on) top-right. Returns the row (for
## anything on the right) and the text column (for its body).
func _detail_card(glyph: String, shape: HexBadge.Shape, title: String, kind: String, button := "") -> Dictionary:
	var s := _s
	var card := PanelContainer.new()
	var box := UITheme.box(UITheme.PANEL, 14.0 * s)
	box.set_content_margin(SIDE_LEFT, 16.0 * s)
	box.set_content_margin(SIDE_RIGHT, 16.0 * s)
	box.set_content_margin(SIDE_TOP, 11.0 * s)
	box.set_content_margin(SIDE_BOTTOM, 11.0 * s)
	card.add_theme_stylebox_override("panel", box)
	_details_body.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(14.0 * s))
	card.add_child(row)
	var badge := DetailBadge.new()
	badge.glyph = glyph
	badge.shape = shape
	badge.custom_minimum_size = Vector2(48.0, 48.0) * s
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(badge)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", roundi(4.0 * s))
	row.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", roundi(8.0 * s))
	column.add_child(top)
	var name_label := UITheme.label(title, "display", 21.0, UITheme.INK, s, 600)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var kind_label := UITheme.label(kind, "caps", 12.0, UITheme.AQUA, s, 700)
	kind_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(kind_label)
	if button:
		var pill := PanelContainer.new()
		var pill_box := UITheme.box(UITheme.INK, 5.0 * s)
		pill_box.set_content_margin(SIDE_LEFT, 6.0 * s)
		pill_box.set_content_margin(SIDE_RIGHT, 6.0 * s)
		pill.add_theme_stylebox_override("panel", pill_box)
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key := UITheme.label(button, "body", 12.0, UITheme.GROUND, s, 600)
		key.add_theme_font_override("font", UITheme.condensed(700))
		pill.add_child(key)
		top.add_child(pill)
	return {"row": row, "column": column}


## A wrapping line of body text in the panel.
func _detail_text(text: String) -> Label:
	var label := UITheme.label(text, "body", 15.0, UITheme.INK_SOFT, _s, 400)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## The next (+1) or previous (-1) fish.
func _cycle_fish(direction: int) -> void:
	var fish_classes := FishCharacter.CLASSES.keys()
	var at := fish_classes.find(_character())
	var next: FishCharacter.FishClass = fish_classes[posmod(at + direction, fish_classes.size())]
	character_changed.emit(next)
	_show_fish(next)


## The shown fish's next (+1) or previous (-1) unlocked species, wrapping round.
func _cycle_species(direction: int) -> void:
	var character := _character()
	var count := FishCharacter.species_count(character)
	var species := _species(character)
	for i in count:
		species = posmod(species + direction, count)
		if FishCharacter.is_species_unlocked(character, species):
			break
	species_changed.emit(species)
	_show_fish(character)


func _input(event: InputEvent) -> void:
	if not visible or (settings_panel and settings_panel.is_open()) or _coop_open():
		return
	if _picker.visible:
		return  # the picker's own
	if _watch_konami(event):
		get_viewport().set_input_as_handled()
		return
	if _details.visible:
		# The menu's under the panel: only the fish changes, and Y or B close it.
		if MenuNav.is_direction(event):
			match _nav.side(event):
				SIDE_LEFT:
					_cycle_fish(-1)
				SIDE_RIGHT:
					_cycle_fish(1)
		elif event.is_action_pressed("ui_page_previous"):
			_cycle_fish(-1)
		elif event.is_action_pressed("ui_page_next"):
			_cycle_fish(1)
		elif _is_details_key(event) or event.is_action_pressed("ui_cancel"):
			_set_details(false)
		elif not event.is_action("ui_accept"):
			return
		get_viewport().set_input_as_handled()
		return
	if MenuNav.is_direction(event):
		# Up/down along the menu (wrapping), left/right the fish, like ‹ ›.
		match _nav.side(event):
			SIDE_TOP:
				_feed_konami("up")
				_menu_step(-1)
			SIDE_BOTTOM:
				_feed_konami("down")
				_menu_step(1)
			SIDE_LEFT:
				_feed_konami("left")
				_cycle_fish(-1)
			SIDE_RIGHT:
				_feed_konami("right")
				_cycle_fish(1)
	elif event.is_action_pressed("ui_page_previous"):
		_cycle_fish(-1)
	elif event.is_action_pressed("ui_page_next"):
		_cycle_fish(1)
	elif _is_details_key(event):
		_toggle_details()
	elif event.is_action_pressed("ui_cancel") and _can_resume:
		close()
	else:
		return
	get_viewport().set_input_as_handled()


## Y on a pad, I on the keyboard: the Class details panel.
static func _is_details_key(event: InputEvent) -> bool:
	return (event is InputEventJoypadButton and event.is_pressed() and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y) \
			or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_I)


## Feeds the Konami code (directions as the menu reads them, B, A, SELECT, START).
## True when `event` is a B or A that belongs to a code about to finish, so it
## doesn't also press a button. Left and right still cycle the fish meanwhile.
func _watch_konami(event: InputEvent) -> bool:
	var token := KonamiCode.token_of(event)
	if token.is_empty():
		return false
	var claimed := _konami.claims(token)
	_feed_konami(token)
	return claimed


func _feed_konami(token: String) -> void:
	if _konami.feed(token):
		_unlock_replays()


## The Konami code was entered: the Replays button shows from now on (and is
## remembered). The console takes it too, without the menu moving meanwhile.
func _unlock_replays() -> void:
	if UISettings.konami_entered:
		return
	UISettings.set_value("konami_entered", true)  # which shows the Replays button
	Sfx.play("ui/mode_chosen")


func _show_replays_button() -> void:
	if _replays_button != null or not UISettings.konami_entered:
		return
	_replays_button = _menu_button("Replays", func() -> void: replays_requested.emit())
	_menu.move_child(_replays_button, _menu.get_child_count() - 3)  # above Settings and Quit


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
	var menu_up: bool = not _picker.visible and not _coop_open() and not (settings_panel and settings_panel.is_open())
	if get_viewport().gui_get_focus_owner() == null and menu_up:
		_play.grab_focus()
	# LT / RT (Home / End): the species, on the pull (each has to come back up first).
	for pair: Array in [["ui_section_previous", -1], ["ui_section_next", 1]]:
		var action: String = pair[0]
		var held := Input.is_action_pressed(action)
		var pulled: bool = held and not _triggers_held.get(action, false)
		_triggers_held[action] = held
		if pulled and menu_up:
			_cycle_species(pair[1])


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


## The species selector's smaller ‹ / ›, like the fish's.
func _species_arrow(glyph: String, direction: int) -> Button:
	var button := Button.new()
	button.text = glyph
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Previous species  (LT / Home)" if direction < 0 else "Next species  (RT / End)"
	button.custom_minimum_size = Vector2(34.0, 34.0) * _s
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", UITheme.display(600))
	button.add_theme_font_size_override("font_size", roundi(20.0 * _s))
	button.add_theme_stylebox_override("normal", UITheme.box(Color(UITheme.PANEL, 0.8), 17.0 * _s, Color(UITheme.MUTED, 0.4), maxf(1.0, _s)))
	button.add_theme_stylebox_override("hover", UITheme.box(UITheme.PANEL.lightened(0.1), 17.0 * _s, UITheme.AQUA, maxf(1.0, 1.5 * _s)))
	button.pressed.connect(_cycle_species.bind(direction))
	return button


## The player's fish, live in its own little world: turning slowly, swimming
## gently, lit like the menus. The right stick orbits the camera round it
## (the turning waits while it's steered, and a moment after).
class FishShowcase extends SubViewportContainer:
	## Where the camera looks from before it's steered.
	const VIEW_FROM := Vector3(-0.55, 0.32, -1.0)
	## Radians a second at full tilt: round, and up / down.
	const ORBIT_YAW_SPEED := 2.4
	const ORBIT_PITCH_SPEED := 1.6
	## How far over the top / under the belly the camera can go.
	const ORBIT_PITCH_LIMIT := 1.35
	## Seconds after the stick is let go before the fish turns again.
	const SPIN_RESUME_DELAY := 2.0
	const STICK_DEADZONE := 0.15

	var _view := SubViewport.new()
	var _pivot := Node3D.new()
	var _camera := Camera3D.new()
	var _model: FishModel
	var _shown := -1
	var _shown_species := -1
	var _time := 0.0
	var _spin := 0.0
	var _reach := 1.0
	var _yaw := atan2(VIEW_FROM.x, VIEW_FROM.z)
	var _pitch := asin(VIEW_FROM.normalized().y)
	var _since_steered := SPIN_RESUME_DELAY

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

	func show_fish(character: FishCharacter.FishClass, species := 0) -> void:
		if character == _shown and species == _shown_species:
			return
		_shown = character
		_shown_species = species
		if _model:
			_model.queue_free()
		_model = FishModel.build(character, species)
		_pivot.add_child(_model)
		_reach = _model._size.length() * 1.85
		_place_camera()

	func _process(delta: float) -> void:
		if not is_visible_in_tree() or _model == null:
			return
		_time += delta
		steer(_right_stick(), delta)
		_pivot.position.y = sin(_time * 1.3) * 0.04
		_model.react(delta, _model.global_basis * Vector3(0.0, 0.0, -3.0))

	## One frame of the right stick (x right, y down, as the pads read): orbits
	## the camera, or lets the fish turn once it's been left alone a moment.
	func steer(stick: Vector2, delta: float) -> void:
		if stick != Vector2.ZERO:
			_since_steered = 0.0
			_yaw -= stick.x * ORBIT_YAW_SPEED * delta
			_pitch = clampf(_pitch - stick.y * ORBIT_PITCH_SPEED * delta, -ORBIT_PITCH_LIMIT, ORBIT_PITCH_LIMIT)
			_place_camera()
		else:
			_since_steered += delta
		if _since_steered >= SPIN_RESUME_DELAY:
			_spin += delta * 0.35
		_pivot.rotation.y = _spin

	func _place_camera() -> void:
		var from := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
		_camera.position = from * _reach
		_camera.look_at(Vector3.ZERO, Vector3.UP)

	## Any controller's right stick (past its deadzone, rescaled to start at 0).
	## Read straight off the pads: the keys on camera_* (I, K) mean other things here.
	static func _right_stick() -> Vector2:
		var stick := Vector2.ZERO
		for pad in Input.get_connected_joypads():
			stick += Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
		var tilt := minf(stick.length(), 1.0)
		if tilt < STICK_DEADZONE:
			return Vector2.ZERO
		return stick.normalized() * (tilt - STICK_DEADZONE) / (1.0 - STICK_DEADZONE)


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


## A Class details card's badge: `glyph` in `shape`, rimmed aqua, as wide as it is.
class DetailBadge extends Control:
	var glyph := ""
	var shape := HexBadge.Shape.CIRCLE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		HexBadge.draw_badge(self, size * 0.5, minf(size.x, size.y), glyph, UITheme.AQUA, false, UITheme.BADGE_FILL, shape)
