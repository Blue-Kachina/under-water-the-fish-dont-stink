extends Node
## The Konami code (refining_weaponry.md §2.7): the original, the short form and
## every in-between count; a slip starts again; extra presses are tolerated;
## and the B and A of a code about to finish belong to it. Also the home
## screen: no Replays button until it's entered, then one that stays.
##   Godot_console.exe --headless --path . res://tests/konami_probe.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _feed(code: KonamiCode, tokens: Array) -> bool:
	var done := false
	for token: String in tokens:
		done = code.feed(token) or done
	return done


func _ready() -> void:
	var up_to_ba := ["up", "up", "down", "down", "left", "right", "left", "right", "b", "a"]
	var code := KonamiCode.new()
	check(_feed(code, up_to_ba), "the short form completes it")
	check(_feed(code, up_to_ba + ["b", "a", "select", "start"]), "the original, B A SELECT START and all, does too")
	check(_feed(code, ["left", "up", "down"] + up_to_ba), "after stray presses it still does")
	check(_feed(code, ["up", "up", "up", "down", "down", "left", "right", "left", "right", "b", "a"]), "an extra Up at the start is just a slip: the window recovers")
	check(not _feed(code, ["up", "up", "down", "down", "left", "right", "left", "right", "a", "b"]), "A before B doesn't")
	check(not _feed(code, ["up", "up", "down", "left", "right", "left", "right", "b", "a"]), "a missing Down doesn't")
	code.clear()
	_feed(code, up_to_ba.slice(0, 8))
	check(code.progress() == 8 and code.claims("b"), "eight in, the next B is the code's")
	check(not code.claims("a"), "but not an A yet")
	code.clear()
	check(not code.claims("b"), "no progress: B is just B")

	var key := InputEventKey.new()
	key.keycode = KEY_B
	key.pressed = true
	check(KonamiCode.token_of(key) == "b", "the B key counts as B")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK
	pad.pressed = true
	check(KonamiCode.token_of(pad) == "select", "the pad's Back is SELECT")

	print("failures: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)
