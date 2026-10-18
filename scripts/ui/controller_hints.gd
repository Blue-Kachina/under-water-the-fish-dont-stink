class_name ControllerHints
extends Control
## The controller hints along a screen's bottom-right (UI Redesign Handoff):
## round face-button badges (A green, B red, X blue, Y yellow) and outlined
## LB / RB pills, each followed by a verb. Sizes itself to fit, so it can sit
## in a container or be anchored to a corner.

## [[button, verb], ...]: button "A", "B", "X", "Y", "LB", "RB", "LB/RB" or
## anything else (shown in a pill, e.g. "◀ ▶").
var hints: Array = []:
	set(value):
		hints = value
		_resize()
## The screen's scale (UITheme.scale_for()).
var s := 1.0:
	set(value):
		s = value
		_resize()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


func _resize() -> void:
	custom_minimum_size = Vector2(_width(), 30.0 * s)
	queue_redraw()


func _width() -> float:
	var total := 0.0
	for hint: Array in hints:
		total += _badge_width(hint[0]) + 8.0 * s + _verb_font().get_string_size(str(hint[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, _verb_size()).x
	return total + maxf(hints.size() - 1, 0) * 22.0 * s


func _badge_width(button: String) -> float:
	if UITheme.FACE_COLORS.has(button):
		return 26.0 * s
	return UITheme.condensed(700).get_string_size(button, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(13.0 * s)).x + 18.0 * s


func _verb_font() -> Font:
	return UITheme.body(600)


func _verb_size() -> int:
	return roundi(15.0 * s)


func _draw() -> void:
	var x := size.x - _width()  # right-aligned
	var middle := size.y * 0.5
	for hint: Array in hints:
		var button: String = hint[0]
		var width := _badge_width(button)
		if UITheme.FACE_COLORS.has(button):
			var centre := Vector2(x + width * 0.5, middle)
			draw_circle(centre, 13.0 * s, UITheme.FACE_COLORS[button], true, -1.0, true)
			UITheme.draw_text(self, Rect2(centre - Vector2(13, 13) * s, Vector2(26, 26) * s), button, UITheme.condensed(700),
					roundi(16.0 * s), UITheme.GROUND)
		else:
			var pill := Rect2(x, middle - 12.0 * s, width, 24.0 * s)
			UITheme.draw_box(self, pill, Color(0, 0, 0, 0), 12.0 * s, UITheme.INK_SOFT, maxf(1.5 * s, 1.0))
			UITheme.draw_text(self, pill, button, UITheme.condensed(700), roundi(13.0 * s), UITheme.INK_SOFT)
		x += width + 8.0 * s
		var verb := str(hint[1])
		var verb_width := _verb_font().get_string_size(verb, HORIZONTAL_ALIGNMENT_LEFT, -1, _verb_size()).x
		UITheme.draw_text(self, Rect2(x, 0.0, verb_width + 2.0, size.y), verb, _verb_font(), _verb_size(), UITheme.INK_SOFT,
				HORIZONTAL_ALIGNMENT_LEFT)
		x += verb_width + 22.0 * s
