class_name KonamiCode
extends RefCounted
## The Konami code, watched in the console (Console) and on the home screen: Up Up Down Down Left Right Left
## Right B A (then B A SELECT START in the original; those can follow, or be
## left off). It reveals the Replays button (refining_weaponry.md §2.7) and lets
## SELECT show the mode picker's hidden modes (UISettings.konami_entered).
##
## Feed it each press as a token ("up", "down", "left", "right", "b", "a",
## "select", "start"). It keeps a rolling window, so a slip just means starting
## again, and it completes the moment the window ends on the core code, so the
## short version (…B A), the long one (…B A B A SELECT START) and every one in
## between all count.

const CODE: Array[String] = ["up", "up", "down", "down", "left", "right", "left", "right", "b", "a"]

var _recent: Array[String] = []


## Records `token`; true when it completes the code.
func feed(token: String) -> bool:
	_recent.append(token)
	if _recent.size() > CODE.size():
		_recent = _recent.slice(_recent.size() - CODE.size())
	if _recent == CODE:
		_recent.clear()
		return true
	return false


func clear() -> void:
	_recent.clear()


## How much of the code the latest presses spell (0 to 9).
func progress() -> int:
	for n in range(mini(_recent.size(), CODE.size() - 1), 0, -1):
		if _recent.slice(_recent.size() - n) == CODE.slice(0, n):
			return n
	return 0


## Whether `token` is the next press of a code that's all but done (the B and A
## then belong to it, not to the buttons they'd press).
func claims(token: String) -> bool:
	var at := progress()
	return at >= CODE.size() - 2 and token == CODE[at]


## The token a button press means, or "" (B and A: on a pad, Nintendo's B and A:
## the bottom face button is B and the right one A, so Xbox's A then B; or the
## B and A keys; SELECT and START: the pad's Back and Start).
static func token_of(event: InputEvent) -> String:
	if event is InputEventJoypadButton and event.is_pressed():
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				return "b"
			JOY_BUTTON_B:
				return "a"
			JOY_BUTTON_BACK:
				return "select"
			JOY_BUTTON_START:
				return "start"
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).keycode:
			KEY_B:
				return "b"
			KEY_A:
				return "a"
			KEY_BACKSPACE:
				return "select"
			KEY_ENTER, KEY_KP_ENTER:
				return "start"
	return ""
