extends Node
## The redesigned menus (UI Redesign Handoff), headless:
## - Hex Badges: every powerup (Powerup.INFO) and every mode tile has a glyph,
##   each parses into strokes inside its 24-unit grid.
## - The home screen: opens paused with Play focused, LB/RB change the fish;
##   Play opens the mode picker with the last mode played featured and every
##   other mode once; X shows a mode's rules; a pick starts the mode straight
##   away (no card) and closes the home screen; B closes the picker.
## - Class details (Y): a panel over the menu, the fish still in view; the
##   menu can't be reached under it, LB/RB still change the fish; it fits
##   every class; B closes it.
## - The settings: right into a section's options, left/right step a value
##   (held, it repeats), Y puts it back, LB/RB change section, B goes back a
##   column then closes; Game's Fish row changes the fish; options a target
##   switches off hide; locked sections can't change.
## - The Gem Frame cards fit their view (a split-screen quarter too).
##   Godot_console.exe --headless --path . res://tests/ui_probe.tscn

var main: Node
var fish: FishController
var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # through the home screen's pause
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	await _frames(5)
	_check_glyphs()
	# Every mode in the picker, the hidden ones too (put back after: it saves to this PC).
	var hidden_before := [UISettings.konami_entered, UISettings.show_hidden_modes]
	UISettings.set_value("konami_entered", true)
	UISettings.set_value("show_hidden_modes", true)
	await _check_home()
	UISettings.set_value("konami_entered", hidden_before[0])
	UISettings.set_value("show_hidden_modes", hidden_before[1])
	await _check_settings()
	UISettings.set_value("show_debug_tweaks", false)  # back as it was (it saves to this PC)
	_check_cards()
	print("ui_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _check_glyphs() -> void:
	print("glyphs:")
	var missing := []
	var bad := []
	var ids: Array = Powerup.ids()
	for mode: String in main.MODE_TILES:
		ids.append(main.MODE_TILES[mode].icon)
	for id: String in ids:
		if not HexBadge.has_glyph(id):
			missing.append(id)
			continue
		var shape := HexBadge.parse(id)
		var inside: bool = not shape.lines.is_empty()
		for line: PackedVector2Array in shape.lines:
			for point in line:
				inside = inside and point.x > -1.0 and point.x < 25.0 and point.y > -1.0 and point.y < 25.0
		if not inside:
			bad.append(id)
	check(missing.is_empty(), "every powerup and mode tile has a glyph (missing: %s)" % [missing])
	check(bad.is_empty(), "each glyph parses into strokes inside its 24-unit grid (off: %s)" % [bad])
	var circle := HexBadge.parse_path("M4 12a8 8 0 1 0 16 0a8 8 0 1 0 -16 0")
	var far := 0.0
	for line: PackedVector2Array in circle.lines:
		for point in line:
			far = maxf(far, absf(point.distance_to(Vector2(12, 12)) - 8.0))
	check(far < 0.05, "arcs land on their circle (off by %.3f)" % far)


func _check_home() -> void:
	print("home screen:")
	main.set_mode(main.HUNT, false)
	await _frames(3)
	var home: HomeScreen = main._home
	check(not home.is_open(), "not shown in probes until asked")
	home.open()
	await _frames(3)
	check(home.is_open() and get_tree().paused, "open: the game paused behind it")
	check(home._play.has_focus(), "Play focused")
	check(home._play_note.text.begins_with("Hunt"), "Play says the last mode played: %s" % home._play_note.text)
	var before: FishCharacter.FishClass = fish.character
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	check(fish.character != before and home._fish_name.text == FishCharacter.display_name(fish.character), "RB: the next fish (%s)" % home._fish_name.text)
	await _button(JOY_BUTTON_LEFT_SHOULDER)
	check(fish.character == before, "LB: back to the first")
	var items := home._menu.get_children()
	await _button(JOY_BUTTON_DPAD_DOWN)
	check(items[1].has_focus(), "D-pad down: Choose mode (focus: %s)" % get_viewport().gui_get_focus_owner())
	await _stick(JOY_AXIS_LEFT_Y, 1.0)
	check(items[2].has_focus(), "stick down: Co-op (focus: %s)" % get_viewport().gui_get_focus_owner())
	await _stick(JOY_AXIS_LEFT_Y, -1.0)
	await _button(JOY_BUTTON_DPAD_UP)
	check(home._play.has_focus(), "stick up, D-pad up: back on Play (focus: %s)" % get_viewport().gui_get_focus_owner())
	await _button(JOY_BUTTON_DPAD_UP)
	check(items[items.size() - 1].has_focus(), "D-pad up from Play wraps to Quit")
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_RIGHT)
	check(fish.character != before and home._play.has_focus(), "D-pad right: the next fish, focus stays on Play")
	await _stick(JOY_AXIS_LEFT_X, -1.0)
	check(fish.character == before, "stick left: back to the first")
	await _check_details(home)

	await _button(JOY_BUTTON_A)
	var picker: ModePicker = home._picker
	check(picker.visible, "A on Play opens the mode picker")
	await _frames(2)
	check(picker._featured.mode == main.HUNT and picker._featured.has_focus(), "the last mode played is featured and focused")
	var shown := [picker._featured.mode]
	for tile: ModePicker.Tile in picker._grid + picker._more:
		if tile.visible and tile.mode:
			shown.append(tile.mode)
	var expected: Array = main.MODE_TILES.keys().filter(func(mode: String) -> bool:
		return mode not in [main.ONE_V_ONE, main.FREE_PLAY, main.FREE_SWIM])  # 1v1 and Free Play are Fish Sticks'; Free Swim's retired
	shown.sort()
	expected.sort()
	check(shown == expected, "every mode once: %s" % [shown])
	var stays := true
	for step: Array in [[JOY_AXIS_LEFT_X, -1.0], [JOY_AXIS_LEFT_X, -1.0], [JOY_AXIS_LEFT_Y, 1.0], [JOY_AXIS_LEFT_Y, 1.0],
			[JOY_AXIS_LEFT_Y, -1.0], [JOY_AXIS_LEFT_Y, -1.0], [JOY_AXIS_LEFT_Y, -1.0], [JOY_AXIS_LEFT_X, 1.0]]:
		await _stick(step[0], step[1])
		var focus := get_viewport().gui_get_focus_owner()
		stays = stays and focus != null and picker.is_ancestor_of(focus)
	for button: JoyButton in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP]:
		await _button(button)
		var focus := get_viewport().gui_get_focus_owner()
		stays = stays and focus != null and picker.is_ancestor_of(focus)
	check(stays, "the stick and D-pad stay in the picker (focus: %s)" % get_viewport().gui_get_focus_owner())
	picker._featured.grab_focus()
	await _button(JOY_BUTTON_X)
	check(picker._rules.visible and picker._rules_text.text.length() > 20, "X: the featured mode's rules")
	await _button(JOY_BUTTON_B)
	check(not picker._rules.visible and picker.visible, "B: rules away, the picker stays")
	await _button(JOY_BUTTON_B)
	check(not picker.visible and home.is_open() and home._play.has_focus(), "B again: back on the menu, Play focused")
	var labels: Array = home._menu.get_children().map(func(button: Button) -> String: return button.text)
	check(not labels.has("Choose mode"), "no Choose mode on the menu (Play opens the picker): %s" % [labels])

	print("mode picker, by controller:")
	home.open_picker()
	await _frames(3)
	var tiles: Array = [picker._featured, picker._close]
	for tile: ModePicker.Tile in picker._grid + picker._more:
		if tile.visible and tile.mode:
			tiles.append(tile)
	# Every tile can be reached from the featured one, and no step leads out of the picker.
	var seen := [picker._featured]
	var queue := [picker._featured]
	var escapes := []
	while not queue.is_empty():
		var at: Control = queue.pop_front()
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var next := at.find_valid_focus_neighbor(side)
			if next == null:
				continue
			if not picker._panel.is_ancestor_of(next):
				escapes.append("%s %d" % [at.get("mode") if at.get("mode") else at.name, side])
			elif next not in seen:
				seen.append(next)
				queue.append(next)
	var unreached := tiles.filter(func(tile: Control) -> bool: return tile not in seen)
	check(unreached.is_empty(), "every tile reachable with the D-pad (not: %s)" % [unreached.map(func(tile: Control) -> String: return str(tile.get("mode")))])
	check(escapes.is_empty(), "no step leads out of the picker (%s)" % [escapes])
	var free_play: ModePicker.Tile
	for tile: ModePicker.Tile in picker._grid:
		if tile.mode == main.OBSTACLE_COURSE:
			free_play = tile
	for button: JoyButton in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN]:
		await _button(button)
	check(get_viewport().gui_get_focus_owner() == free_play, "right, right, down: Obstacle Course")
	await _button(JOY_BUTTON_DPAD_DOWN)
	var focus_more: Control = get_viewport().gui_get_focus_owner()
	check(focus_more in picker._more, "down again: the MORE row (%s)" % focus_more.get("mode"))
	await _button(JOY_BUTTON_DPAD_UP)
	check(get_viewport().gui_get_focus_owner() == free_play, "and up: back to Obstacle Course")
	await _button(JOY_BUTTON_B)
	await _frames(2)

	# Fish Sticks asks which: 1v1 or Free Play.
	home.open_picker()
	await _frames(2)
	var sticks: ModePicker.Tile
	for tile: ModePicker.Tile in picker._grid:
		if tile.mode == ModePicker.FISH_STICKS:
			sticks = tile
	sticks.grab_focus()
	await _button(JOY_BUTTON_A)
	await _frames(2)
	check(picker._variants.visible and picker._variant_buttons[0].has_focus(), "A on Fish Sticks: asks 1v1 or Free Play")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	check(picker._variant_buttons[1].has_focus(), "right: Free Play")
	await _button(JOY_BUTTON_B)
	check(not picker._variants.visible and picker.visible and sticks.has_focus(), "B: back on the Fish Sticks tile")
	await _button(JOY_BUTTON_B)
	await _frames(2)

	home.open_picker()
	await _frames(2)
	var nature: ModePicker.Tile
	for tile: ModePicker.Tile in picker._grid:
		if tile.mode == main.NATURE:
			nature = tile
	nature.grab_focus()
	await _button(JOY_BUTTON_A)
	await _frames(3)
	check(main.current_mode == main.NATURE and main.nature_run != null and main._match_card == null, "a pick starts the mode straight away")
	check(not home.is_open() and not get_tree().paused, "and the home screen's gone, the game running")
	main.set_mode(main.FREE_PLAY, false)
	await _frames(3)


func _check_settings() -> void:
	print("debug tweaks:")
	var panel: Node = main._panel
	UISettings.show_debug_tweaks = false
	panel.set_open(true)
	await _frames(3)
	check(not panel._rows["fish/thrust"].visible if panel._rows.has("fish/thrust") else true, "off by default: Fish's tuning options are hidden")
	check(not panel._section_buttons["ball"].visible and not panel._section_buttons["unnatural"].visible and not panel._section_buttons["powerups"].visible,
			"Ball, Nature, Unnatural and Powerups are gone")
	check(panel._section_buttons["game"].visible and panel._section_buttons["controls"].visible and panel._section_buttons["camera"].visible,
			"Game, Controls and Camera stay")
	check(not panel._rows["game/preset_save"].visible and panel._rows["game/player_name"].visible, "presets hide, the player name stays")
	await _button(JOY_BUTTON_BACK)
	check(UISettings.show_debug_tweaks and panel._section_buttons["unnatural"].visible and panel._rows["unnatural/battery_damage"].visible,
			"SELECT: Show Debug Tweaks on, the tuning sections are back")
	check(not panel._rows["fish/rl_tyres"].visible and not panel._rows["camera/roll_with_surface"].visible, "the always-on switches stay hidden")
	print("settings:")
	var focus := get_viewport().gui_get_focus_owner()
	check(panel.is_open() and focus == panel._section_buttons["game"], "open on the sections, Game focused")
	for i in 5:
		await _trigger(JOY_AXIS_TRIGGER_RIGHT)
	check(panel._section == "fish" and panel._title.text == "Fish", "RT ×5: the Fish section")
	var fish_tabs: Array = panel._tabs["fish"].map(func(tab: Dictionary) -> String: return tab.title)
	check(fish_tabs.size() >= 3 and panel._tab_bar.visible, "Fish has tabs across the top: %s" % [fish_tabs])
	check(panel._tabs["game"].is_empty() and not _tab_bar_shown_for(panel, "game"), "Game has none")
	var powerup_tabs: Array = panel._tabs["powerups"].map(func(tab: Dictionary) -> String: return tab.title)
	check(powerup_tabs.has("Cursed") and not powerup_tabs.has("Epic"), "Powerups' tabs by rarity: %s" % [powerup_tabs])
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	check(panel._section == "fish" and panel._tab_at["fish"] == 1, "RB: the next tab (%s)" % fish_tabs[1])
	await _button(JOY_BUTTON_LEFT_SHOULDER)
	check(panel._tab_at["fish"] == 0, "LB: back")
	await _button(JOY_BUTTON_LEFT_SHOULDER)
	check(panel._section == "fish" and panel._tab_at["fish"] == fish_tabs.size() - 1, "LB past the first tab: round to the last, same section")
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	check(panel._section == "fish" and panel._tab_at["fish"] == 0, "RB past the last tab: round to the first, same section")
	await _trigger(JOY_AXIS_TRIGGER_LEFT)
	check(panel._section == "camera", "LT: the section before")
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _button(JOY_BUTTON_LEFT_SHOULDER)
	check(panel._section == "camera", "LB/RB in a section with no tabs: nothing (never another section)")
	await _trigger(JOY_AXIS_TRIGGER_RIGHT)
	check(panel._section == "fish", "RT: back to Fish")
	panel._section_buttons["fish"].grab_focus()
	await _frames(2)
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	check(panel._section == "fish" and panel._tab_at["fish"] == 1, "RB with the sections column focused: still Fish's tabs")
	await _button(JOY_BUTTON_LEFT_SHOULDER)
	await _stick(JOY_AXIS_LEFT_X, 0.9)
	check(get_viewport().gui_get_focus_owner() == panel._section_buttons["fish"], "stick right on a section: stays in the sections")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	focus = get_viewport().gui_get_focus_owner()
	check(focus is Button and panel._section_lists["fish"].is_ancestor_of(focus), "right: into its options")
	await _check_held_scroll(panel)
	var key := "fish/max_speed"
	var row: Button = panel._rows[key]
	row.grab_focus()
	await _frames(2)
	check(panel._detail_title.text == "Max Speed" and not panel._detail_text.text.is_empty(), "the detail pane: its title and doc comment")
	var start: float = fish.max_speed
	await _button(JOY_BUTTON_DPAD_LEFT)
	check(get_viewport().gui_get_focus_owner() == panel._section_buttons["fish"] and is_equal_approx(fish.max_speed, start),
			"left on an option: back to the sections, nothing changed")
	await _button(JOY_BUTTON_A)
	row.grab_focus()
	await _frames(2)
	await _button(JOY_BUTTON_A)
	check(get_viewport().gui_get_focus_owner() is HSlider and is_equal_approx(fish.max_speed, start),
			"A on an option: into the detail pane, on its slider, nothing changed")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	var stepped: float = fish.max_speed
	check(stepped > start, "right: up a step (%.2f -> %.2f)" % [start, stepped])
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_UP)
	check(get_viewport().gui_get_focus_owner() is HSlider, "up / down: still on the slider")
	# A stick pushed left ramps through several events: one step down, never up on the way.
	var before: float = fish.max_speed
	var went_up := false
	for v: float in [-0.3, -0.6, -0.8, -0.95, -0.95, 0.0]:
		var push := InputEventJoypadMotion.new()
		push.device = 0
		push.axis = JOY_AXIS_LEFT_X
		push.axis_value = v
		Input.parse_input_event(push)
		Input.flush_buffered_events()
		await _frames(1)
		went_up = went_up or fish.max_speed > before
	await _frames(2)
	check(not went_up and fish.max_speed < before and before - fish.max_speed <= stepped - start + 0.001,
			"stick left: one step down, never up first (%.2f -> %.2f)" % [before, fish.max_speed])
	var low: float = fish.max_speed
	await _stick(JOY_AXIS_LEFT_X, 0.9)
	check(fish.max_speed > low and fish.max_speed - low <= stepped - start + 0.001, "stick right: one step back up (%.2f)" % fish.max_speed)
	panel._rows[key].grab_focus()
	await _frames(2)
	await _stick(JOY_AXIS_LEFT_X, -0.9)
	await _stick(JOY_AXIS_LEFT_X, 0.9)
	check(get_viewport().gui_get_focus_owner() == panel._rows[key], "stick left / right on an option: stays on it")
	await _button(JOY_BUTTON_A)
	_hold(JOY_BUTTON_DPAD_RIGHT, true)
	await _seconds(0.8)
	_hold(JOY_BUTTON_DPAD_RIGHT, false)
	await _frames(2)
	check(fish.max_speed > stepped + 0.5, "held: it repeats (%.2f)" % fish.max_speed)
	await _button(JOY_BUTTON_Y)
	check(is_equal_approx(fish.max_speed, panel._defaults["fish"]["max_speed"]), "Y: back to the default (%.2f)" % fish.max_speed)
	check(row._value.text == panel._format_value(fish.max_speed), "the row shows it")
	await _button(JOY_BUTTON_B)
	check(get_viewport().gui_get_focus_owner() == row, "B: back to the option")

	fish.bow_wave = false
	panel._refresh_visibility()
	var bow_keys := []
	for option: String in panel._rows:
		if option.begins_with("fish/bow_") and option != "fish/bow_wave":
			bow_keys.append(option)
	check(not bow_keys.is_empty() and bow_keys.all(func(option: String) -> bool: return not panel._rows[option].visible),
			"options switched off hide (Bow Wave's, with it off)")
	panel._apply("fish", {"bow_wave": true})
	panel._refresh_visibility()
	check(panel._rows[bow_keys[0]].visible, "and show again")

	panel.set_sections_locked(["fish"], true, "Tuned by the host")
	var locked_speed: float = fish.max_speed
	panel._step(key, 1)
	check(is_equal_approx(fish.max_speed, locked_speed) and not panel.is_editable(key) and panel.is_editable("camera/distance"),
			"a locked section can't change; others can")
	panel.set_sections_locked(["fish"], false)

	panel._focus_rows("game")
	await _frames(2)
	var character_row: Button = panel._rows["game/character"]
	character_row.grab_focus()
	await _frames(2)
	var was: FishCharacter.FishClass = fish.character
	await _button(JOY_BUTTON_A)
	await _frames(2)
	var dropdown := get_viewport().gui_get_focus_owner() as OptionButton
	check(dropdown != null and dropdown.get_popup().visible and fish.character == was, "A on Game's Fish row: its dropdown, open")
	if dropdown:
		await _button(JOY_BUTTON_B)
		await _frames(2)
		check(not dropdown.get_popup().visible and get_viewport().gui_get_focus_owner() == dropdown and fish.character == was,
				"B with it open: just closes it")
		await _button(JOY_BUTTON_A)
		await _frames(2)
		await _button(JOY_BUTTON_DPAD_DOWN)
		await _button(JOY_BUTTON_A)
		await _frames(2)
		check(fish.character != was and not dropdown.get_popup().visible, "A, down, A: another fish (%s)" % fish.character)
		check(panel._in_detail(get_viewport().gui_get_focus_owner()), "still in the detail pane")
	await _button(JOY_BUTTON_Y)
	check(fish.character == FishCharacter.FishClass.SKIRMISHER, "Y: back to the first fish")
	await _button(JOY_BUTTON_B)
	check(get_viewport().gui_get_focus_owner() == character_row, "B: back to the Fish row")
	main.set_character(was)

	await _check_rebinding(panel)

	await _button(JOY_BUTTON_B)
	check(get_viewport().gui_get_focus_owner() == panel._section_buttons["controls"], "B: back to the sections")
	await _button(JOY_BUTTON_B)
	check(not panel.is_open(), "B again: closed")


func _check_rebinding(panel: Node) -> void:
	print("rebinding:")
	Controls.reset_all_bindings(false)
	Controls.reset_all_bindings(true)
	panel._tab_at["controls"] = 0
	panel._focus_rows("controls")
	await _frames(2)
	var kb_row: Button = panel._rows["controls/kb:jump"]
	check(kb_row.is_visible_in_tree() and panel._tabs["controls"][0].title == "Keyboard & Mouse", "Controls: the keyboard & mouse tab, Jump's row")
	check(kb_row._value.text == "SPACE", "Jump's on Space (%s)" % kb_row._value.text)
	kb_row.grab_focus()
	await _button(JOY_BUTTON_A)
	check(panel.is_capturing() and kb_row._value.text.begins_with("PRESS A KEY"), "A: waiting for a key")
	await _frames(30)  # past the arm time
	await _key(KEY_K)
	check(not panel.is_capturing() and Controls.binding_text("jump", false) == "K", "K pressed: Jump's on K (%s)" % Controls.binding_text("jump", false))
	var pressed_k := InputEventKey.new()
	pressed_k.physical_keycode = KEY_K
	pressed_k.pressed = true
	Input.parse_input_event(pressed_k)
	Input.flush_buffered_events()
	check(Input.is_action_pressed("jump"), "and K jumps")
	var released_k := InputEventKey.new()
	released_k.physical_keycode = KEY_K
	Input.parse_input_event(released_k)
	Input.flush_buffered_events()
	check(Controls.binding_text("jump", true) == "A", "the controller's Jump is untouched (A)")
	var saved := ConfigFile.new()
	saved.load(Controls.SETTINGS_PATH)
	check(saved.has_section_key("bindings", "kb__jump"), "remembered on this PC")
	kb_row.grab_focus()
	await _button(JOY_BUTTON_Y)
	check(Controls.binding_text("jump", false) == "Space" and not Controls.is_rebound("jump", false), "Y: back to Space")

	kb_row.grab_focus()
	await _button(JOY_BUTTON_A)
	await _frames(30)
	await _key(KEY_ESCAPE)
	check(not panel.is_capturing() and Controls.binding_text("jump", false) == "Space", "Esc cancels a rebind")

	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	check(panel._tab_at["controls"] == 1, "RB: the controller tab")
	var pad_row: Button = panel._rows["controls/pad:thrust_forward"]
	pad_row.grab_focus()
	await _button(JOY_BUTTON_A)
	await _frames(30)
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -0.9
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	await _frames(2)
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	check(Controls.binding_text("thrust_forward", true) == "Left stick ↑", "a stick pushed: Throttle's on it (%s)" % Controls.binding_text("thrust_forward", true))
	check(Controls.binding_text("thrust_forward", false) == "W", "its key's untouched (W)")
	var boost_row: Button = panel._rows["controls/pad:boost"]
	boost_row.grab_focus()
	await _button(JOY_BUTTON_A)
	await _frames(30)
	await _button(JOY_BUTTON_B)
	check(Controls.binding_text("boost", true) == "B", "on the controller tab B is a button to bind (Boost on B)")
	Controls.apply_profile(Controls.current_profile, false)
	check(Controls.binding_text("boost", true) == "B", "rebinds stay over the profile when it's applied again")
	Controls.reset_all_bindings(true)
	check(Controls.binding_text("boost", true) == "RB" and Controls.binding_text("thrust_forward", true) == "RT", "reset all: the controller's defaults back")
	var after := ConfigFile.new()
	after.load(Controls.SETTINGS_PATH)
	check(not after.has_section("bindings"), "and nothing left saved (%s)" % [after.get_sections()])
	pad_row.grab_focus()
	await _frames(2)


## Held up/down keeps moving through the options (and stops at the end), and
## through the sections.
func _check_held_scroll(panel: Node) -> void:
	var rows: Array = panel._shown_list("fish").get_children().filter(func(child: Node) -> bool: return child is Button and child.visible)
	rows[0].grab_focus()
	await _frames(2)
	_hold(JOY_BUTTON_DPAD_DOWN, true)
	await _seconds(0.9)
	_hold(JOY_BUTTON_DPAD_DOWN, false)
	await _frames(2)
	var at: int = rows.find(get_viewport().gui_get_focus_owner())
	check(at >= 4, "held down: it keeps going (row %d of %d)" % [at, rows.size()])
	_hold(JOY_BUTTON_DPAD_DOWN, true)
	await _seconds(3.0)
	_hold(JOY_BUTTON_DPAD_DOWN, false)
	await _frames(2)
	check(get_viewport().gui_get_focus_owner() == rows[-1], "held on: it stops at the last option")
	_hold(JOY_BUTTON_DPAD_UP, true)
	await _seconds(3.0)
	_hold(JOY_BUTTON_DPAD_UP, false)
	await _frames(2)
	check(get_viewport().gui_get_focus_owner() == rows[0], "held up: back to the first")
	panel._section_buttons["game"].grab_focus()
	await _frames(2)
	_hold(JOY_BUTTON_DPAD_DOWN, true)
	await _seconds(2.5)
	_hold(JOY_BUTTON_DPAD_DOWN, false)
	await _frames(2)
	check(get_viewport().gui_get_focus_owner() == panel._section_buttons["powerups"], "held down the sections: to the last, no further")
	panel._section_buttons["fish"].grab_focus()
	await _frames(2)
	rows[0].grab_focus()
	await _frames(2)


func _tab_bar_shown_for(panel: Node, section: String) -> bool:
	return panel._tabs[section].size() > 1


func _trigger(axis: JoyAxis) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	for value: float in [1.0, 0.0]:
		event.axis_value = value
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(3)


func _check_details(home: HomeScreen) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	await _button(JOY_BUTTON_Y)
	check(home._details.visible and not home._hints.visible, "Y: the Class details panel (the menu's hints hidden)")
	var panel := home._details.get_child(1) as Control
	var rect := panel.get_global_rect()
	check(rect.encloses(home._menu.get_global_rect()), "the panel covers the menu")
	check(not rect.intersects(home._showcase.get_global_rect()) and not rect.intersects(home._fish_name.get_global_rect()),
			"the fish and its name stay in view")
	await _button(JOY_BUTTON_DPAD_DOWN)
	check(get_viewport().gui_get_focus_owner() == focus, "D-pad down: the menu doesn't move under it")
	await _button(JOY_BUTTON_A)
	check(not home._picker.visible and home._details.visible, "A: nothing under it pressed")
	var before: FishCharacter.FishClass = fish.character
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(2)
	check(fish.character != before and home._details.visible and _details_say(home, FishCharacter.display_name(fish.character)),
			"RB: the next fish, the panel up and showing it")
	fish.character = before
	await _button(JOY_BUTTON_B)
	check(not home._details.visible and home._hints.visible and home.is_open(), "B: closes the panel, not the home screen")
	home._show_fish(before)


## Whether the details panel shows `text` in a label somewhere.
func _details_say(home: HomeScreen, text: String) -> bool:
	for node in home._details_body.find_children("*", "Label", true, false):
		if (node as Label).text == text:
			return true
	return false


func _key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(2)


func _check_cards() -> void:
	print("cards:")
	var cards := LevelUpCards.new()
	cards.set_anchors_preset(Control.PRESET_TOP_LEFT)  # sized by hand below
	add_child(cards)
	var offer := [{"powerup": "chain_lightning", "stacks": 3, "tier": Rarity.Tier.UNCOMMON},
			{"powerup": "torpedo", "stacks": 1, "tier": Rarity.Tier.RARE}, {"powerup": "glass_coral", "stacks": 1, "tier": Rarity.Tier.CURSED}]
	for view: Vector2 in [Vector2(1600, 900), Vector2(800, 450), Vector2(640, 900)]:
		cards.size = view
		cards.open(offer, "RARE TREASURE!", "", null)
		var area := Rect2(Vector2.ZERO, view)
		var fits := true
		for i in offer.size():
			fits = fits and area.encloses(cards._card_rect(i))
			if i > 0:
				fits = fits and not cards._card_rect(i).intersects(cards._card_rect(i - 1))
		check(fits, "%dx%d: the cards fit, apart" % [view.x, view.y])
	cards.selected = 1
	check(cards._card_rect(1).size.x > cards._card_rect(0).size.x, "the focused card's bigger")
	cards.queue_free()


func _button(button: JoyButton) -> void:
	_hold(button, true)
	await _frames(2)
	_hold(button, false)
	await _frames(2)


## The left stick pushed to `value` on `axis`, then let go.
func _stick(axis: JoyAxis, value: float) -> void:
	for v: float in [value, 0.0]:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis
		event.axis_value = v
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(2)


func _hold(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(time: float) -> void:
	await get_tree().create_timer(time).timeout
