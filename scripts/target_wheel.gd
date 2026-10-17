class_name TargetWheel
extends CanvasLayer
## Nature's targeting, on screen: the school wheel and the edge arrows.
##
## Hold ball cam (FollowCamera.hold_opens_wheel, wheel_hold_time) and the
## wheel opens: one slice for each thing ball cam can look at (the lone fish
## and the schools, NatureRun.targets()), placed in its direction from the
## camera, so the wheel doubles as a radar, with its name, the fish left and
## how far. The right stick (IJKL) picks one; letting go of ball cam looks at it.
## With the stick left alone, it stays on what it was on. The game keeps going
## while the wheel's open: there's no slow-motion (co-op is coming).
##
## Arrows at the screen's edge point to the target when it's off screen, and
## to other schools too (settings.school_arrows), fainter.

const RADIUS := 170.0
const STICK_DEADZONE := 0.5
const GOLD := Color(1.0, 0.82, 0.3)
const EDGE_INSET := 46.0

var camera: Camera3D
var run: NatureRun
## Whose wheel it is (their fish): the run's first player if not set.
var fish: FishController
var settings := NatureSettings.shared()
## Open now, and the slice it's on ([node, name, fish left], or empty).
var is_open := false
var picked: Array = []

var _canvas := Control.new()


func _ready() -> void:
	layer = 5
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)


## The camera's player's controls (FollowCamera.input), or everyone's.
func _player_input() -> PlayerInput:
	var own: Variant = camera.get("input") if camera else null
	return own if own else PlayerInput.everyone()


func open() -> void:
	is_open = true
	picked = []
	for entry: Array in run.targets():
		if entry[0] == run.focus_of(_fish()):
			picked = entry


## Closes the wheel, looking at what it was on (ball cam on).
func close() -> void:
	if not is_open:
		return
	is_open = false
	if not picked.is_empty() and is_instance_valid(picked[0]):
		run.set_focus(picked[0], _fish())
		if camera.has_method("set_ball_cam"):
			camera.set_ball_cam(true)


func _process(_delta: float) -> void:
	if camera == null or not is_instance_valid(run):
		return
	camera.wheel_hold_time = settings.wheel_hold_time
	if is_open:
		var stick := _player_input().vector("camera_left", "camera_right", "camera_up", "camera_down")
		if stick.length() >= STICK_DEADZONE:
			var best := INF
			for entry: Array in run.targets():
				var off := absf(angle_difference(_direction_of(entry[0]).angle(), stick.angle()))
				if off < best:
					best = off
					picked = entry
	_canvas.queue_redraw()


## Which way `node` is from the middle of the screen (unit, screen space: y down).
func _direction_of(node: Node3D) -> Vector2:
	var local := camera.global_basis.inverse() * (node.global_position - camera.global_position)
	var flat := Vector2(local.x, -local.y)
	if flat.length() < 0.001:
		return Vector2.UP  # dead ahead
	return flat.normalized()


func _draw_canvas() -> void:
	if camera == null or not is_instance_valid(run):
		return
	_draw_arrows()
	if is_open:
		_draw_wheel()


func _draw_wheel() -> void:
	var middle := _canvas.size / 2.0
	_canvas.draw_circle(middle, RADIUS + 70.0, Color(0.02, 0.06, 0.1, 0.55))
	_canvas.draw_arc(middle, RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.25), 2.0)
	BroadcastUI.text(_canvas, Rect2(middle - Vector2(120, 14), Vector2(240, 28)), "PICK A SCHOOL", 18, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 800)
	var stick := _player_input().vector("camera_left", "camera_right", "camera_up", "camera_down")
	if stick.length() >= STICK_DEADZONE:
		_canvas.draw_line(middle, middle + stick.normalized() * (RADIUS - 20.0), Color(GOLD, 0.6), 3.0)
	for entry: Array in run.targets():
		var node: Node3D = entry[0]
		var chosen: bool = not picked.is_empty() and picked[0] == node
		var at := middle + _direction_of(node) * RADIUS
		var color := GOLD if chosen else Color(1, 1, 1, 0.85)
		_canvas.draw_circle(at, 13.0 if chosen else 8.0, color)
		var distance := node.global_position.distance_to(_fish().global_position)
		var detail := "%d fish · %d m" % [entry[2], roundi(distance)]
		var box := Rect2(at + Vector2(-110, 16), Vector2(220, 44))
		BroadcastUI.text(_canvas, Rect2(box.position, Vector2(box.size.x, 22)), str(entry[1]).to_upper(), 16 if chosen else 14, color, HORIZONTAL_ALIGNMENT_CENTER, 800)
		BroadcastUI.text(_canvas, Rect2(box.position + Vector2(0, 20), Vector2(box.size.x, 20)), detail, 13, Color(color, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 600)


## An arrow at the screen's edge toward each target that's off screen.
func _draw_arrows() -> void:
	var rect := Rect2(Vector2.ZERO, _canvas.size).grow(-EDGE_INSET)
	for entry: Array in run.targets():
		var node: Node3D = entry[0]
		var is_focus: bool = node == run.focus_of(_fish()) and camera.get("ball_cam") == true
		if not is_focus and not settings.school_arrows:
			continue
		var at := node.global_position
		if not camera.is_position_behind(at) and rect.has_point(camera.unproject_position(at)):
			continue  # on screen
		var direction := _direction_of(node)
		var middle := _canvas.size / 2.0
		# Out from the middle along `direction` until the inset edge.
		var reach := INF
		if absf(direction.x) > 0.0001:
			reach = minf(reach, (rect.size.x / 2.0) / absf(direction.x))
		if absf(direction.y) > 0.0001:
			reach = minf(reach, (rect.size.y / 2.0) / absf(direction.y))
		var tip := middle + direction * reach
		var color := GOLD if is_focus else Color(1, 1, 1, 0.45)
		var size := 18.0 if is_focus else 12.0
		var side := direction.orthogonal()
		_canvas.draw_colored_polygon(PackedVector2Array([tip + direction * size, tip + side * size * 0.6, tip - side * size * 0.6]), color)
		if is_focus:
			var distance := roundi(at.distance_to(_fish().global_position))
			BroadcastUI.text(_canvas, Rect2(tip - direction * 30.0 - Vector2(40, 10), Vector2(80, 20)), "%d m" % distance, 14, color, HORIZONTAL_ALIGNMENT_CENTER, 700)


func _fish() -> FishController:
	return fish if is_instance_valid(fish) else run.player
