class_name MenuNav
extends RefCounted
## Up/down/left/right through a menu, from the D-pad, the left stick or the
## arrow keys, kept inside the menu. Godot's own focus search looks at every
## control in the window, so from a menu it can land on a button on another
## layer (the home screen behind the mode picker, a match card behind the home
## screen) and focus seems to vanish. A menu takes the steps in its _input
## instead, sets the event handled, and moves with step().
##
## The stick steps once per push: it has to come back to the middle before it
## steps again (a held stick sends a stream of motion events). The D-pad and
## keys step on each press, and keys repeat while held.

const DIRECTIONS := {"ui_up": SIDE_TOP, "ui_down": SIDE_BOTTOM, "ui_left": SIDE_LEFT, "ui_right": SIDE_RIGHT}

## The stick's push now (a ui_ direction, or "" when it's back in the middle).
var _stick := ""


## The side `event` steps towards (SIDE_TOP etc.), or -1 if it isn't a step.
## A stick event that isn't a new push is -1, but still one of ours: see is_direction().
func side(event: InputEvent) -> int:
	if event is InputEventJoypadMotion:
		var pushed := ""
		for action: String in DIRECTIONS:
			if event.is_action_pressed(action):
				pushed = action
		var axis_x := (event as InputEventJoypadMotion).axis in [JOY_AXIS_LEFT_X]
		if pushed == "":
			# Back in the middle on this axis: ready to step again.
			if _stick in (["ui_left", "ui_right"] if axis_x else ["ui_up", "ui_down"]):
				_stick = ""
			return -1
		if pushed == _stick:
			return -1
		_stick = pushed
		return DIRECTIONS[pushed]
	for action: String in DIRECTIONS:
		if event.is_action_pressed(action, true):
			return DIRECTIONS[action]
	return -1


## Whether `event` is a ui_ direction at all (pressed or not): a menu that
## steps with this sets all of them handled, so Godot's search never sees one.
static func is_direction(event: InputEvent) -> bool:
	for action: String in DIRECTIONS:
		if event.is_action(action):
			return true
	return false


## Moves focus from `from` one step towards `side`, if the control there is
## inside `inside`. Returns whether it moved.
static func step(from: Control, toward: int, inside: Control) -> bool:
	if from == null:
		return false
	var next := from.find_valid_focus_neighbor(toward as Side)
	if next == null or not inside.is_ancestor_of(next):
		return false
	next.grab_focus()
	return true
