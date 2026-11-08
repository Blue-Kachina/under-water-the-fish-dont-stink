extends Node
## The setup screens (ModeSetup / ModeSetups), headless:
## - every picker mode builds a screen with a fish item and its options;
## - controller navigation: LB/RB (or left/right) the class, down to a row, left/right its
##   value (applied at once), B cancels, A confirms;
## - the stick steps like the D-pad: once per push, not to the end of the list;
## - every Hunter form has its own preview (the boss forms' dressed fish too);
## - roles: Marco Polo's hider (What Stinks?'s hunter and prey) opens on the character
##   last played in the role, switching Start as swaps it; a hunter picks a form; a whale
##   seeker has no fish to pick (the whale card does it, and the pause menu's item is off);
## - Nature, Hunt and 1v1 swap character live, with no restart;
## - the pause menu's Change Character: grayed out in Unnatural, otherwise the current
##   role's screen, Apply plays as the pick and resumes;
## - changing character mid-match plays as the pick at once (a What Stinks? Hunter's form
##   re-dressed, a fish worn now or kept under a Hunter's body);
## - a joining split-screen player gets their own screen on their pad only, the fish
##   waiting until they dive in, Back leaving again.
##   Godot_console.exe --headless --path . res://tests/mode_setup_probe.tscn

var main: Node
var failures := 0
var _saved_cfg := ""
var _saved_marco := [0, 0]
var _saved_stinks := [0, 0, ""]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	await _frames(5)
	_remember()
	await _check_builds()
	await _check_navigation()
	await _check_stick()
	await _check_forms()
	await _check_roles()
	await _check_pause_menu()
	await _check_live_swap()
	await _check_whale_pause()
	await _check_settle()
	await _check_mid_match()
	await _check_join()
	_restore()
	print("mode_setup_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## The settings these change are the player's (and save to this PC): put back after.
func _remember() -> void:
	_saved_cfg = FileAccess.get_file_as_string(RoleCharacters.PATH) if FileAccess.file_exists(RoleCharacters.PATH) else ""
	var mp := MarcoPoloSettings.shared()
	_saved_marco = [int(mp.start_as), int(mp.variant)]
	var ws := WhatStinksSettings.shared()
	_saved_stinks = [int(ws.start_as), int(ws.variant), ws.form]


func _restore() -> void:
	if _saved_cfg == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RoleCharacters.PATH))
	else:
		var file := FileAccess.open(RoleCharacters.PATH, FileAccess.WRITE)
		file.store_string(_saved_cfg)
		file.close()
	MarcoPoloSettings.shared().start_as = _saved_marco[0] as MarcoPoloSettings.StartAs
	MarcoPoloSettings.shared().variant = _saved_marco[1] as MarcoPoloSettings.Variant
	WhatStinksSettings.shared().start_as = _saved_stinks[0] as WhatStinksSettings.StartAs
	WhatStinksSettings.shared().variant = _saved_stinks[1] as WhatStinksSettings.Variant
	WhatStinksSettings.shared().form = _saved_stinks[2]


func _check_builds() -> void:
	print("every mode has a screen:")
	var expected_rows := {ModeSetups.UNNATURAL: 1, ModeSetups.FISH_STICKS: 1, ModeSetups.MARCO_POLO: 3, ModeSetups.WHAT_STINKS: 2}
	for mode: String in ModePicker.PRIMARY + ModePicker.MORE:
		var setup := ModeSetups.build(main, mode)
		var rows: int = expected_rows.get(mode, 0)
		check(not setup.pool.is_empty() and setup.rows.size() == rows and setup.title != "",
				"%s: a fish item and %d option row(s) (%d)" % [mode, rows, setup.rows.size()])
		setup.free()
	var fish_pool := ModeSetup.fish_pool()
	check(fish_pool.size() == FishCharacter.pickable_classes().size(), "the fish pool is every pickable class")
	await _frames(1)


func _check_navigation() -> void:
	print("navigation:")
	var setup := ModeSetups.build(main, ModeSetups.UNNATURAL)
	var us := UnnaturalSettings.shared()
	var run_length_before := us.run_length
	var confirmed := []
	var cancelled := []
	setup.confirmed.connect(func() -> void: confirmed.append(true))
	setup.cancelled.connect(func() -> void: cancelled.append(true))
	main.add_child(setup)
	await _frames(3)
	var at := setup.pool_index
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	check(setup.pool_index == posmod(at + 1, setup.pool.size()), "RB: the next class")
	await _button(JOY_BUTTON_DPAD_LEFT)
	check(setup.pool_index == at, "left: back a class")
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_RIGHT)
	check(us.run_length == posmod(run_length_before + 1, 3), "down then right: Run length steps (and applies at once)")
	await _button(JOY_BUTTON_DPAD_LEFT)
	check(us.run_length == run_length_before, "left: and back")
	await _button(JOY_BUTTON_B)
	check(cancelled.size() == 1 and confirmed.is_empty(), "B cancels")
	await _frames(2)
	check(not is_instance_valid(setup), "and the screen goes")
	setup = ModeSetups.build(main, ModeSetups.UNNATURAL)
	setup.confirmed.connect(func() -> void: confirmed.append(true))
	main.add_child(setup)
	await _frames(3)
	await _button(JOY_BUTTON_A)
	check(confirmed.size() == 1, "A confirms")
	await _frames(2)


func _check_stick() -> void:
	print("the stick:")
	var setup := ModeSetups.build(main, ModeSetups.WHAT_STINKS)
	main.add_child(setup)
	await _frames(3)
	for value in [1.0, 1.0, 1.0, 0.9, 1.0]:  # one push: a stream of motion events
		await _axis(JOY_AXIS_LEFT_Y, value)
	check(setup._focus == 1, "a held stick down steps one item, not to the bottom (%d)" % setup._focus)
	await _axis(JOY_AXIS_LEFT_Y, 0.0)
	await _axis(JOY_AXIS_LEFT_Y, 1.0)
	check(setup._focus == 2, "back to the middle and pushed again: the next (%d)" % setup._focus)
	await _axis(JOY_AXIS_LEFT_Y, 0.0)
	var was: int = int(setup.rows[0].index)
	setup._focus = 1
	await _axis(JOY_AXIS_LEFT_X, 1.0)
	await _axis(JOY_AXIS_LEFT_X, 1.0)
	await _axis(JOY_AXIS_LEFT_X, 0.0)
	check(int(setup.rows[0].index) == posmod(was + 1, 2), "a held stick right steps a value once")
	setup.cancel()
	await _frames(2)


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)


func _check_forms() -> void:
	print("hunter form previews:")
	var showcase := HomeScreen.FishShowcase.new()
	main.add_child(showcase)
	showcase.size = Vector2(300.0, 200.0)
	await _frames(2)
	var looks := {}
	for key: String in HunterForms.ready_keys():
		showcase.show_form(key)
		await _frames(3)
		check(showcase._fish != null and showcase._preview != null, "%s: a preview is built (the form's own fish, swimming)" % key)  # every form is a dressed fish now (HunterPreview)
		looks[key] = showcase._fish.get_instance_id()
	check(looks.values().size() == looks.keys().size(), "one model each")
	showcase.queue_free()
	await _frames(2)


func _check_roles() -> void:
	print("roles:")
	var seeker: FishCharacter.FishClass = FishCharacter.pickable_classes()[1]
	var hider: FishCharacter.FishClass = FishCharacter.pickable_classes()[2]
	RoleCharacters.store("seeker", seeker, 0)
	RoleCharacters.store("hider", hider, 0)
	check(RoleCharacters.character("seeker") == seeker and RoleCharacters.character("hider") == hider, "each role keeps its own character")
	var mp := MarcoPoloSettings.shared()
	mp.start_as = MarcoPoloSettings.StartAs.SEEKER
	var setup := ModeSetups.build(main, ModeSetups.MARCO_POLO)
	main.add_child(setup)
	await _frames(3)
	check(setup.pool.size() == 1 and setup.pool[0].has("whale") and setup.pool_label == "Whale",
			"Marco Polo as Seeker: no fish to pick, the whale card does it")
	var seeker_before := RoleCharacters.character("seeker")
	setup._focus = 2  # Start as (fish, Variant, Start as, Arena)
	await _button(JOY_BUTTON_DPAD_RIGHT)
	check(mp.start_as == MarcoPoloSettings.StartAs.HIDER and setup.pool[setup.pool_index].character == hider,
			"Start as Hider: the last hider")
	var hider2: FishCharacter.FishClass = FishCharacter.pickable_classes()[3]
	setup.pool_index = ModeSetup.pool_index_of(setup.pool, hider2)
	var to_start := ModeSetups.apply(main, setup)
	check(to_start == ModeSetups.MARCO_POLO and RoleCharacters.character("hider") == hider2 and RoleCharacters.character("seeker") == seeker_before,
			"applying remembers the hider only")
	# A whale seeker applying wears the hider's last fish and remembers no seeker fish.
	mp.start_as = MarcoPoloSettings.StartAs.SEEKER
	var whale := ModeSetups.build(main, ModeSetups.MARCO_POLO)
	ModeSetups.apply(main, whale)
	var fish: FishController = main.get_node("Fish")
	check(fish.character == hider2 and RoleCharacters.character("seeker") == seeker_before, "a whale seeker wears the hider's fish under its whale")
	whale.free()
	mp.whale_seeker = false
	var plain := ModeSetups.build(main, ModeSetups.MARCO_POLO)
	check(plain.pool.size() > 1 and not plain.pool[0].has("whale"), "with whales off a seeker picks a fish again")
	plain.free()
	mp.whale_seeker = true
	setup.free()
	# What Stinks?: a hunter picks a form, prey a fish.
	var ws := WhatStinksSettings.shared()
	ws.start_as = WhatStinksSettings.StartAs.HUNTER
	var stinks := ModeSetups.build(main, ModeSetups.WHAT_STINKS)
	check(stinks.pool.size() == HunterForms.ready_keys().size() and stinks.pool[0].has("form"), "What Stinks? as Hunter offers the Hunter forms")
	check(stinks.rows.size() == 2, "What Stinks? has Variant and Start as (the Hunter size is locked, a panel option)")
	stinks.pool_index = mini(1, stinks.pool.size() - 1)
	ModeSetups.apply(main, stinks)
	check(ws.form == stinks.pool[stinks.pool_index].form, "applying sets the Hunter form")
	stinks.free()
	ws.start_as = WhatStinksSettings.StartAs.PREY
	var prey := ModeSetups.build(main, ModeSetups.WHAT_STINKS)
	check(not prey.pool[0].has("form"), "as Prey: fish again")
	prey.free()
	await _frames(1)


func _check_settle() -> void:
	print("picks survive entering the mode:")
	var ws := WhatStinksSettings.shared()
	var fish: FishController = main.get_node("Fish")
	ws.start_as = WhatStinksSettings.StartAs.PREY
	main.set_mode(main.WHAT_STINKS)
	await _frames(3)
	main.set_mode(main.FREE_PLAY, false)  # leaves Prey stored in Nature's tuning
	await _frames(3)
	var setup := ModeSetups.build(main, ModeSetups.WHAT_STINKS)
	setup._focus = 2  # Start as
	setup.cycle_row(1)
	setup.pool_index = setup.pool.find_custom(func(entry: Dictionary) -> bool: return entry.form == "humpback")
	var to_start := ModeSetups.apply(main, setup)
	main.start_mode(to_start, ModeSetups.settle.bind(setup))
	await _frames(10)
	var game: WhatStinksMatch = main.what_stinks
	check(game != null and game.is_hunter(fish) and ws.form == "humpback", "Start as Hunter and the Humpback survive Nature's tuning restore")
	setup.free()
	main.set_mode(main.FREE_PLAY, false)
	await _frames(3)


func _check_mid_match() -> void:
	print("mid-match character changes:")
	var ws := WhatStinksSettings.shared()
	var fish: FishController = main.get_node("Fish")
	ws.start_as = WhatStinksSettings.StartAs.HUNTER
	ws.form = "king_of_herrings"
	ws.arena_radius = 90.0  # a small, quick match, as what_stinks_probe plays
	ws.school_count = 4
	ws.school_min = 12
	ws.school_max = 16
	ws.min_players = 4
	ws.bot_hunter_rounds = 1
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	check(main._match_card != null, "What Stinks? waits on its card")
	ws.start_as = WhatStinksSettings.StartAs.HUNTER  # (entering the mode applies Nature's tuning, which resets it)
	ws.form = "king_of_herrings"
	main.play_match()
	await _frames(10)
	var game: WhatStinksMatch = main.what_stinks
	check(game != null, "Play starts the match")
	if game == null:
		return
	check(game.is_hunter(fish), "playing it as the Hunter (start_as %s, hunters %s, local %s, fish %s, phase %s)" % [ws.start_as, game.hunters, game.local_fish(), fish, game.phase])
	check(fish.get("_visual").get_node_or_null("KingRig") != null, "wearing the King of Herrings")
	var setup := ModeSetups.build_character(main, ModeSetups.current_role(main))
	check(setup.get_meta("role") == "hunter" and setup.pool[setup.pool_index].form == "king_of_herrings", "the screen opens on the form worn")
	setup.pool_index = setup.pool.find_custom(func(entry: Dictionary) -> bool: return entry.form == "gulper_mother")
	ModeSetups.apply_character(main, setup)
	await _frames(5)
	check(ws.form == "gulper_mother" and fish.get("_visual").get_node_or_null("KingRig") == null,
			"a new form is worn at once, the King's body gone")
	setup.free()
	# As prey a new fish is worn at once too, and kept under a Hunter's body for later.
	var other: FishCharacter.FishClass = FishCharacter.pickable_classes()[5]
	var kept := ModeSetups.build_character(main, "prey")
	kept.pool_index = ModeSetup.pool_index_of(kept.pool, other)
	ModeSetups.apply_character(main, kept)
	await _frames(3)
	check(fish.get_meta("ws_base_look")[0] == int(other) and fish.character != other, "a Hunter's pick of a fish waits under its body")
	game.apply_role(fish, WhatStinksMatch.Role.PREY)
	await _frames(3)
	check(fish.character == other, "and is worn once it's prey")
	var third: FishCharacter.FishClass = FishCharacter.pickable_classes()[6]
	var now := ModeSetups.build_character(main, "prey")
	now.pool_index = ModeSetup.pool_index_of(now.pool, third)
	ModeSetups.apply_character(main, now)
	await _frames(3)
	check(fish.character == third and game.players.has(fish) and main.what_stinks == game, "as prey, mid-round: worn at once, the match goes on")
	kept.free()
	now.free()
	main.set_mode(main.FREE_PLAY, false)
	await _frames(3)


## Nature, Hunt and 1v1 keep nothing of the class: a swap is worn where the fish is, no restart.
func _check_live_swap() -> void:
	print("live swaps (no restart):")
	var fish: FishController = main.get_node("Fish")
	var classes := FishCharacter.pickable_classes()
	for mode: String in [main.NATURE, main.HUNT, main.ONE_V_ONE]:
		main.start_mode(mode)
		await _frames(10)
		var elsewhere := fish.global_position + Vector3(25.0, 0.0, 25.0)
		fish.global_position = elsewhere
		await _frames(1)
		var next: FishCharacter.FishClass = classes[(classes.find(fish.character) + 1) % classes.size()]
		var match_before: Object = main.nature_run if mode == main.NATURE else (main.hunt_match if mode == main.HUNT else main.match_1v1)
		main.set_character(next)
		await _frames(3)
		var match_now: Object = main.nature_run if mode == main.NATURE else (main.hunt_match if mode == main.HUNT else main.match_1v1)
		check(fish.character == next and match_before != null and match_now == match_before, "%s: worn at once, the same match" % mode)
		check(fish.global_position.distance_to(elsewhere) < 8.0, "%s: no respawn (%.1f m from where it was)" % [mode, fish.global_position.distance_to(elsewhere)])
	main.set_mode(main.FREE_PLAY, false)
	await _frames(3)


func _check_whale_pause() -> void:
	print("whale seeker pause menu:")
	var mp := MarcoPoloSettings.shared()
	var pause: PauseMenu = main._pause_menu
	main.set_mode(main.MARCO_POLO, false)
	await _frames(3)
	mp.start_as = MarcoPoloSettings.StartAs.SEEKER
	pause.open()
	await _frames(2)
	check(pause._change_character.disabled, "Change Character is grayed out for a whale seeker (its card picks)")
	pause.close()
	mp.start_as = MarcoPoloSettings.StartAs.HIDER
	pause.open()
	await _frames(2)
	check(not pause._change_character.disabled, "and available to a hider")
	pause.close()
	main.set_mode(main.FREE_PLAY, false)
	await _frames(3)


func _check_pause_menu() -> void:
	print("pause menu:")
	var pause: PauseMenu = main._pause_menu
	main.set_mode(main.UNNATURAL, false)
	await _frames(3)
	pause.open()
	await _frames(2)
	check(pause._change_character.disabled, "Change Character is grayed out in Unnatural")
	pause.close()
	main.set_mode(main.NATURE, false)
	await _frames(3)
	pause.open()
	await _frames(2)
	check(not pause._change_character.disabled, "and available in Nature")
	pause._change_character.pressed.emit()
	await _frames(3)
	var setup: ModeSetup = main.get_node_or_null("ModeSetup")
	check(setup != null and setup.rows.is_empty() and setup.confirm_text == "Apply", "it opens the character screen (no options)")
	var other: FishCharacter.FishClass = FishCharacter.pickable_classes()[4]
	setup.pool_index = ModeSetup.pool_index_of(setup.pool, other)
	await _button(JOY_BUTTON_A)
	await _frames(3)
	var fish: FishController = main.get_node("Fish")
	check(fish.character == other and RoleCharacters.character(RoleCharacters.DEFAULT) == other, "Apply plays as the pick and remembers it")
	check(not pause.is_open(), "and resumes")
	main.set_mode(main.FREE_PLAY, false)
	await _frames(3)


func _check_join() -> void:
	print("joining:")
	main.start_mode(main.NATURE)
	await _frames(5)
	var local: LocalCoop = main._local
	var slot := local.join(7, true)
	await _frames(3)
	check(slot != null and slot.fish.controls_locked and not slot.fish.has_meta("entered_run"), "the joiner's fish waits on their screen")
	var screens := main.find_children("*", "ModeSetup", false, false)
	check(screens.size() == 1 and (screens[0] as ModeSetup).device == 7, "their screen answers their pad only")
	var screen: ModeSetup = screens[0]
	var first_before := screen.pool_index
	await _button(JOY_BUTTON_RIGHT_SHOULDER, 0)  # the first player's pad
	check(screen.pool_index == first_before, "another pad does nothing")
	await _button(JOY_BUTTON_RIGHT_SHOULDER, 7)
	check(screen.pool_index != first_before, "their RB changes their class")
	var picked: FishCharacter.FishClass = screen.pool[screen.pool_index].character
	await _button(JOY_BUTTON_A, 7)
	await _frames(3)
	check(slot.fish.character == picked and not slot.fish.controls_locked and slot.fish.has_meta("entered_run"),
			"Dive in: they wear it and join the run")
	var second := local.join(8, true)
	await _frames(3)
	await _button(JOY_BUTTON_B, 8)
	await _frames(3)
	check(not local.slots.has(second), "Back leaves again")
	local.leave(slot)
	main.set_mode(main.FREE_PLAY, false)
	await _frames(3)


func _button(button: JoyButton, device := 0) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = device
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
