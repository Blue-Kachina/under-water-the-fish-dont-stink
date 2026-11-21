class_name WatchWheel
extends CanvasLayer
## Marco Polo's watch wheel: holding the camera button (Y) as a hider or a
## spectator opens a pie with a slice per fish (MarcoPoloMatch._watch_button):
## the hider's own first (back to its own cam), then everyone still in the
## round. The left stick points at a slice; letting go of Y watches that fish.
## With the stick left alone, it stays on the slice it opened on. The game
## keeps going while it's open (it's online), and the hider's fish holds still.

const RADIUS := 190.0
const HOLE := 58.0
const STICK_DEADZONE := 0.5
const SEEKER_COLOR := Color(0.4, 1.0, 0.7)

var match_node: MarcoPoloMatch
var is_open := false
## The slices' fish, and the one picked.
var entries: Array[FishController] = []
var picked: FishController

var _input: PlayerInput
var _canvas := Control.new()


func _ready() -> void:
	layer = 7
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_wheel)
	add_child(_canvas)


## Opens on `fish_list`, starting on `current`, picked with `input`'s left stick.
func open(fish_list: Array[FishController], current: FishController, input: PlayerInput = null) -> void:
	entries = fish_list.duplicate()
	picked = current if entries.has(current) else (entries[0] if not entries.is_empty() else null)
	_input = input
	is_open = true
	_canvas.queue_redraw()


## Closes, returning the fish picked (null if none).
func close() -> FishController:
	is_open = false
	_canvas.queue_redraw()
	var out := picked if is_instance_valid(picked) else null
	picked = null
	return out


## Slice `i`'s middle (rad, screen space: 0 right, -PI/2 up), the first at the top, then clockwise.
func slice_angle(i: int) -> float:
	return -PI / 2.0 + TAU * i / maxi(entries.size(), 1)


func _stick() -> Vector2:
	var source := _input if _input else PlayerInput.everyone()
	return source.vector(&"stick_left", &"stick_right", &"stick_up", &"stick_down")


func _process(_delta: float) -> void:
	if not is_open:
		return
	for i in range(entries.size() - 1, -1, -1):
		if not is_instance_valid(entries[i]):
			entries.remove_at(i)
	var stick := _stick()
	if stick.length() >= STICK_DEADZONE and not entries.is_empty():
		var best := INF
		for i in entries.size():
			var off := absf(angle_difference(slice_angle(i), stick.angle()))
			if off < best:
				best = off
				picked = entries[i]
	_canvas.queue_redraw()


func _draw_wheel() -> void:
	if not is_open or entries.is_empty() or not is_instance_valid(match_node):
		return
	var s := UITheme.scale_for(_canvas.get_viewport())
	var middle := _canvas.size / 2.0
	var outer := RADIUS * s
	var inner := HOLE * s
	var me := match_node.local_fish()
	var n := entries.size()
	var span := TAU / n
	_canvas.draw_circle(middle, outer + 14.0 * s, Color(UITheme.DEEP, 0.7))
	for i in n:
		var fish := entries[i]
		var chosen := fish == picked
		var tint := _tint(fish, me)
		var from := slice_angle(i) - span * 0.5
		var points := PackedVector2Array()
		var steps := maxi(ceili(48.0 / n), 6)
		for k in steps + 1:
			points.append(middle + Vector2.from_angle(from + span * k / steps) * (outer + (8.0 * s if chosen else 0.0)))
		for k in range(steps, -1, -1):
			points.append(middle + Vector2.from_angle(from + span * k / steps) * inner)
		_canvas.draw_colored_polygon(points, Color(tint, 0.62 if chosen else 0.22))
		if n > 1:
			_canvas.draw_line(middle + Vector2.from_angle(from) * inner, middle + Vector2.from_angle(from) * outer, Color(UITheme.DEEP, 0.9), 2.0 * s)
		# The name, the role and how far, in the slice's middle.
		var at := middle + Vector2.from_angle(slice_angle(i)) * (inner + outer) * 0.5
		var label := Rect2(at - Vector2(90.0, 22.0) * s, Vector2(180.0, 24.0) * s)
		var name_text := "YOU" if fish == me else MarcoPoloHud.name_of(fish).to_upper()
		UITheme.draw_text(_canvas, label, name_text, UITheme.condensed(800), roundi((18.0 if chosen else 15.0) * s),
				UITheme.INK if chosen else Color(UITheme.INK, 0.8))
		var detail := "YOUR VIEW" if fish == me else "%s  ·  %d m" % [_role_name(fish), roundi(fish.global_position.distance_to(me.global_position))]
		UITheme.draw_text(_canvas, Rect2(label.position + Vector2(0.0, 22.0 * s), label.size), detail, UITheme.condensed(700),
				roundi(12.0 * s), Color(tint, 0.95))
	_canvas.draw_arc(middle, outer, 0.0, TAU, 96, Color(1, 1, 1, 0.25), 1.5 * s)
	_canvas.draw_circle(middle, inner - 4.0 * s, Color(UITheme.DEEP, 0.9))
	UITheme.draw_text(_canvas, Rect2(middle - Vector2(60.0, 18.0) * s, Vector2(120.0, 20.0) * s), "WATCH", UITheme.condensed(800),
			roundi(17.0 * s), UITheme.AQUA)
	UITheme.draw_text(_canvas, Rect2(middle - Vector2(60.0, -2.0) * s, Vector2(120.0, 18.0) * s), "let go of Y", UITheme.condensed(600),
			roundi(12.0 * s), UITheme.MUTED)
	var stick := _stick()
	if stick.length() >= STICK_DEADZONE:
		_canvas.draw_line(middle + stick.normalized() * inner, middle + stick.normalized() * (outer - 6.0 * s), Color(UITheme.GOLD, 0.7), 3.0 * s)


func _tint(fish: FishController, me: FishController) -> Color:
	if fish == me:
		return UITheme.GOLD
	return SEEKER_COLOR if match_node.role_of(fish) == MarcoPoloMatch.Role.SEEKER else UITheme.AQUA


func _role_name(fish: FishController) -> String:
	return "SEEKER" if match_node.role_of(fish) == MarcoPoloMatch.Role.SEEKER else "HIDER"
