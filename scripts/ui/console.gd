extends CanvasLayer
## The console (autoloaded as "Console"): ` (the key under Esc) opens it over
## the top of the screen, ` or Esc closes it. There are no commands yet: what's
## typed is echoed back as unknown.
##
## While it's open it has all the input. Every action's bindings are taken off
## the InputMap until it closes (and the held ones let go), so nothing that
## reads the controls (the fish, the menus, split-screen players by device)
## sees a thing; the console reads the raw keys and buttons itself. It pauses
## the game too, as the pause menu does (online, the world carries on, the
## local players just get no input).
##
## It watches for the Konami code (KonamiCode) from a controller (the D-pad or
## the left stick, B, A) or the keyboard (the arrow keys, B, A), with nothing
## on screen until it's in (a line in the log). Entering it sets
## UISettings.konami_entered: the Replays button on the home screen, and SELECT
## in the mode picker showing the hidden modes.

signal opened
signal closed

const MAX_LINES := 200
const HEIGHT := 0.42  # of the screen
## The left stick counts as a D-pad press past PUSH, and again once it's back under REST.
const STICK_PUSH := 0.6
const STICK_REST := 0.3

var _root: Control
var _log: Label
var _line: Label
var _lines: PackedStringArray = []
var _typed := ""
var _konami := KonamiCode.new()
## Every action's events while the console's open (action -> Array[InputEvent]).
var _stashed := {}
var _was_paused := false
## The left stick's push now, per axis ("" when back in the middle).
var _stick := {JOY_AXIS_LEFT_X: "", JOY_AXIS_LEFT_Y: ""}
var _blink := 0.0
var _s := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120  # over everything, the settings and pop-ups included
	visible = false
	_s = UITheme.scale_for(get_viewport())
	var s := _s
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New", "monospace"])

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # no clicks through to the menus under it
	add_child(_root)
	var panel := PanelContainer.new()
	var box := UITheme.box(Color(UITheme.DEEP, 0.94), 0.0, Color(UITheme.AQUA, 0.5), 0.0)
	box.border_width_bottom = maxi(1, roundi(2.0 * s))
	box.set_content_margin_all(18.0 * s)
	panel.add_theme_stylebox_override("panel", box)
	panel.anchor_right = 1.0
	panel.anchor_bottom = HEIGHT
	_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(8.0 * s))
	panel.add_child(column)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", roundi(16.0 * s))
	column.add_child(title_row)
	title_row.add_child(UITheme.label("Console", "caps", 13.0, UITheme.AQUA, s, 700))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	title_row.add_child(UITheme.label("`  or  Esc  to close", "body", 13.0, UITheme.MUTED, s, 500))

	_log = Label.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log.clip_text = true
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.add_theme_font_override("font", mono)
	_log.add_theme_font_size_override("font_size", roundi(16.0 * s))
	_log.add_theme_color_override("font_color", UITheme.INK_SOFT)
	column.add_child(_log)

	_line = Label.new()
	_line.add_theme_font_override("font", mono)
	_line.add_theme_font_size_override("font_size", roundi(18.0 * s))
	_line.add_theme_color_override("font_color", UITheme.INK)
	column.add_child(_line)

	print_line("No commands yet.")
	_refresh_line()


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	# Last of the root's children: the first to see each input event, before the
	# menus' own raw-key checks.
	get_parent().move_child.call_deferred(self, -1)
	visible = true
	_typed = ""
	_konami.clear()
	_stick = {JOY_AXIS_LEFT_X: "", JOY_AXIS_LEFT_Y: ""}
	_take_bindings()
	_was_paused = get_tree().paused
	if not NetSession.is_online():
		get_tree().paused = true
	_refresh_line()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	_give_back_bindings()
	if not NetSession.is_online():
		get_tree().paused = _was_paused
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Adds `text` to the log.
func print_line(text: String) -> void:
	_lines.append(text)
	if _lines.size() > MAX_LINES:
		_lines = _lines.slice(_lines.size() - MAX_LINES)
	if _log:
		_log.text = "\n".join(_lines)


func _exit_tree() -> void:
	_give_back_bindings()


func _process(delta: float) -> void:
	if not visible:
		return
	_blink += delta
	_refresh_line()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and (key.physical_keycode == KEY_QUOTELEFT or key.keycode == KEY_QUOTELEFT):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	get_viewport().set_input_as_handled()  # everything's the console's while it's open
	if key:
		_on_key(key)
	elif event is InputEventJoypadButton and event.is_pressed():
		_feed_konami(_pad_token((event as InputEventJoypadButton).button_index))
	elif event is InputEventJoypadMotion:
		_on_stick(event as InputEventJoypadMotion)


func _on_key(key: InputEventKey) -> void:
	if not key.pressed:
		return
	match key.keycode:
		KEY_ESCAPE:
			if not key.echo:
				close()
			return
		KEY_ENTER, KEY_KP_ENTER:
			_submit()
			return
		KEY_BACKSPACE:
			_typed = _typed.left(-1) if not key.ctrl_pressed else ""
			_refresh_line()
			return
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			if not key.echo:
				_feed_konami({KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right"}[key.keycode])
			return
	if key.unicode >= 32 and not key.ctrl_pressed and not key.alt_pressed:
		_typed += char(key.unicode)
		_refresh_line()
	if not key.echo and key.keycode in [KEY_A, KEY_B]:
		_feed_konami(KonamiCode.token_of(key))


## The D-pad's directions, B and A (Nintendo's, as KonamiCode.token_of: the bottom
## face button is B, the right one A) and SELECT and START (the long form's end).
static func _pad_token(button: JoyButton) -> String:
	match button:
		JOY_BUTTON_DPAD_UP:
			return "up"
		JOY_BUTTON_DPAD_DOWN:
			return "down"
		JOY_BUTTON_DPAD_LEFT:
			return "left"
		JOY_BUTTON_DPAD_RIGHT:
			return "right"
		JOY_BUTTON_A:
			return "b"
		JOY_BUTTON_B:
			return "a"
		JOY_BUTTON_BACK:
			return "select"
		JOY_BUTTON_START:
			return "start"
	return ""


## The left stick as a D-pad: a push counts once, and again only after it comes back.
func _on_stick(motion: InputEventJoypadMotion) -> void:
	if motion.axis not in _stick:
		return
	var value := motion.axis_value
	if absf(value) < STICK_REST:
		_stick[motion.axis] = ""
		return
	if absf(value) < STICK_PUSH or _stick[motion.axis] != "":
		return
	var token: String
	if motion.axis == JOY_AXIS_LEFT_X:
		token = "right" if value > 0.0 else "left"
	else:
		token = "down" if value > 0.0 else "up"
	_stick[motion.axis] = token
	_feed_konami(token)


func _feed_konami(token: String) -> void:
	if token.is_empty():
		return
	if _konami.feed(token):
		if UISettings.konami_entered:
			print_line("Konami code: already entered.")
		else:
			UISettings.set_value("konami_entered", true)
			print_line("Konami code entered: the Replays button is on the home screen, and SELECT in the mode picker shows the hidden modes.")
		Sfx.play("ui/mode_chosen")


func _submit() -> void:
	var command := _typed.strip_edges()
	_typed = ""
	_refresh_line()
	if command.is_empty():
		return
	print_line("> " + command)
	print_line("Unknown command: %s (there are no commands yet)" % command.get_slice(" ", 0))


func _refresh_line() -> void:
	if _line:
		_line.text = "> " + _typed + ("_" if fmod(_blink, 1.0) < 0.55 else " ")


## Every action's bindings off the InputMap (kept to give back), and the held ones let go.
func _take_bindings() -> void:
	if not _stashed.is_empty():
		return
	for action: StringName in InputMap.get_actions():
		_stashed[action] = InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
		Input.action_release(action)


func _give_back_bindings() -> void:
	for action: StringName in _stashed:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event: InputEvent in _stashed[action]:
			InputMap.action_add_event(action, event)
	_stashed.clear()
