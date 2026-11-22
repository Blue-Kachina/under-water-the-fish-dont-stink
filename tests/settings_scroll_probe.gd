extends Node
## The settings' options column keeps the focused row on screen: one step a
## frame, several steps in one frame (held, fast), a jump to the far end, and
## a new tab, in a 1080p window. The screen fits the window too: 17 sections
## once made the page taller than it, so the options' bottom rows (which their
## own scroll thought shown) were off the window, picked unseen.
##   Godot_console.exe --headless --path . res://tests/settings_scroll_probe.tscn

var main: Node
var panel: Node
var failures := 0


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	panel = main.get_node("DebugPanel")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shown_rows(section: String) -> Array[Control]:
	var rows: Array[Control] = []
	for child in panel._shown_list(section).get_children():
		if child is Button and child.visible and panel._rows.values().has(child):
			rows.append(child)
	return rows


func _in_view(row: Control, scroll: ScrollContainer = null) -> bool:
	if scroll == null:
		scroll = panel._rows_scroll
	var view: Rect2 = scroll.get_global_rect().intersection(get_viewport().get_visible_rect())
	var rect := row.get_global_rect()
	return rect.position.y >= view.position.y - 0.5 and rect.end.y <= view.end.y + 0.5


func _on_window(control: Control) -> bool:
	return control.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y + 0.5


func _run() -> void:
	await _frames(10)
	panel.set_open(true)
	var tweaks_were_on: bool = UISettings.show_debug_tweaks
	if not tweaks_were_on:
		panel._toggle_debug_tweaks()
	await _frames(3)
	# The section whose shown list is longest.
	var best := ""
	var most := 0
	for section: String in panel._section_lists:
		panel._show_section(section)
		var n := _shown_rows(section).size()
		if n > most:
			most = n
			best = section
	print("longest list: %s (%d rows), view %.0f px" % [best, most, panel._rows_scroll.size.y])
	panel._focus_rows(best)
	await _frames(3)
	var rows := _shown_rows(best)
	check(_on_window(panel._rows_scroll), "the options column ends on the window (%.0f of %.0f)" % [panel._rows_scroll.get_global_rect().end.y, get_viewport().get_visible_rect().end.y])
	check(_on_window(panel._rail_scroll), "the sections column ends on the window")
	check(_on_window(panel._detail_scroll), "the detail pane ends on the window")
	check(rows.size() > 12, "a list long enough to scroll")

	var unseen := 0
	for i in range(1, rows.size()):
		rows[i].grab_focus()
		await _frames(1)
		if not _in_view(rows[i]):
			unseen += 1
	check(unseen == 0, "one step a frame down: focused row always in view (%d not)" % unseen)

	unseen = 0
	for i in range(rows.size() - 1, -1, -3):
		rows[i].grab_focus()
		rows[maxi(i - 1, 0)].grab_focus()
		rows[maxi(i - 2, 0)].grab_focus()
		await _frames(1)
		if not _in_view(rows[maxi(i - 2, 0)]):
			unseen += 1
	check(unseen == 0, "three steps a frame up: focused row in view (%d not)" % unseen)

	unseen = 0
	for i in range(0, rows.size(), 4):
		for j in range(i, mini(i + 4, rows.size())):
			rows[j].grab_focus()
		await _frames(1)
		if not _in_view(rows[mini(i + 3, rows.size() - 1)]):
			unseen += 1
	check(unseen == 0, "four steps a frame down: focused row in view (%d not)" % unseen)

	rows[0].grab_focus()
	await _frames(2)
	rows[rows.size() - 1].grab_focus()
	await _frames(2)
	check(_in_view(rows[rows.size() - 1]), "jump to the last row: in view")
	check(panel._rows_scroll.scroll_vertical > 0, "the list scrolled")

	# Lead: a row's worth of the list past the focused one when there's more.
	rows[0].grab_focus()
	await _frames(2)
	var mid := rows.size() / 2
	for i in range(1, mid + 1):
		rows[i].grab_focus()
		await _frames(1)
	var next_row := rows[mid + 1]
	check(_in_view(next_row), "the row after the focused one shows too")

	# A new tab: the first row focused, the list back at its top.
	var tabs: Array = panel._visible_tabs(best)
	if tabs.size() > 1:
		panel._step_tab(1)
		await _frames(3)
		var focus: Control = panel.get_viewport().gui_get_focus_owner()
		check(focus != null and _in_view(focus), "after a tab change the focused row is in view")

	if not tweaks_were_on:
		panel._toggle_debug_tweaks()
	# The sections: more than fit, each one shown as focus reaches it.
	var buttons: Array = panel._section_buttons.values().filter(func(b: Control) -> bool: return b.visible)
	unseen = 0
	for b: Control in buttons:
		b.grab_focus()
		await _frames(1)
		if not _in_view(b, panel._rail_scroll):
			unseen += 1
	check(unseen == 0, "down the %d sections: each in view (%d not)" % [buttons.size(), unseen])
	buttons[0].grab_focus()
	await _frames(2)
	check(_in_view(buttons[0], panel._rail_scroll), "back to the first section: in view")

	panel.set_open(false)
	print("settings_scroll_probe: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)
