extends CanvasLayer
## Speed, orientation and course readouts plus a live controller-input display.

@export var fish: FishController
@export var arena: Arena

var _stats: Label
var _speed_bar: ProgressBar
var _boost_bar: ProgressBar
var _course: Label
var _banner: Label
var _banner_time_left := 0.0


func _ready() -> void:
	var panel := _make_panel()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -290.0
	panel.offset_right = -16.0
	panel.offset_top = 16.0
	add_child(panel)

	var column := VBoxContainer.new()
	panel.add_child(column)
	_stats = Label.new()
	column.add_child(_stats)
	column.add_child(_caption("Speed"))
	_speed_bar = _bar(Color(0.3, 0.8, 1.0))
	column.add_child(_speed_bar)
	column.add_child(_caption("Boost"))
	_boost_bar = _bar(Color(1.0, 0.6, 0.15))
	column.add_child(_boost_bar)

	_course = _centred_label(16.0, 28)
	add_child(_course)
	_banner = _centred_label(64.0, 36)
	_banner.modulate = Color(1.0, 0.9, 0.3)
	add_child(_banner)

	var viz := InputViz.new()
	viz.fish = fish
	viz.anchor_left = 1.0
	viz.anchor_right = 1.0
	viz.anchor_top = 1.0
	viz.anchor_bottom = 1.0
	viz.offset_left = -300.0
	viz.offset_top = -130.0
	viz.offset_right = -16.0
	viz.offset_bottom = -16.0
	add_child(viz)

	var hint := Label.new()
	hint.text = "View/F1: tuning panel    Start/R: reset    Right stick/IJKL: look around"
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 16.0
	hint.offset_top = -36.0
	hint.modulate = Color(1, 1, 1, 0.6)
	add_child(hint)

	if arena:
		arena.course_finished.connect(_on_course_finished)


func _process(delta: float) -> void:
	if fish == null:
		return

	var jump_names := ["READY", "DOUBLE JUMP / DODGE", "cooldown"]
	var pad := Input.get_connected_joypads()
	_stats.text = "\n".join([
		"Speed     %5.1f m/s" % fish.speed,
		"Forward   %5.1f m/s" % fish.forward_speed,
		"Drift     %5.0f°" % fish.drift_angle,
		"Spin      %5.2f rad/s" % fish.angular_speed,
		"Jump      %s" % jump_names[fish.jump_state],
		"Pad       %s" % (Input.get_joy_name(pad[0]) if not pad.is_empty() else "none (keyboard)"),
	])
	_speed_bar.max_value = fish.max_boost_speed
	_speed_bar.value = fish.speed
	_boost_bar.value = 100.0 if fish.boost_unlimited else fish.boost_amount

	if arena:
		var best := "--" if is_inf(arena.best_time) else "%.2f" % arena.best_time
		if arena.running:
			_course.text = "Hoop %d / %d    %.2f s    best %s" % [arena.next_hoop + 1, arena.hoops.size(), arena.course_time, best]
		else:
			_course.text = "Swim through the yellow hoop to start    best %s" % best

	_banner_time_left -= delta
	if _banner_time_left <= 0.0:
		_banner.text = "TORPEDO!" if fish.is_boosting and fish.speed > fish.max_speed else ""


func _on_course_finished(time: float, is_best: bool) -> void:
	_banner.text = "Course complete: %.2f s%s" % [time, "  NEW BEST!" if is_best else ""]
	_banner_time_left = 3.0


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.1, 0.75)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.6)
	return label


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _centred_label(top: float, font_size: int) -> Label:
	var label := Label.new()
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -400.0
	label.offset_right = 400.0
	label.offset_top = top
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


## Draws the left stick, triggers and held buttons so you can see exactly what
## the fish is receiving while tuning.
class InputViz extends Control:
	var fish: FishController

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if fish == null:
			return
		var font := ThemeDB.fallback_font
		var dim := Color(1, 1, 1, 0.35)
		var radius := 45.0
		var centre := Vector2(radius + 4.0, size.y / 2.0)
		draw_arc(centre, radius, 0.0, TAU, 48, dim, 2.0)
		draw_circle(centre + fish.input_stick * radius, 8.0, Color.WHITE)

		_trigger(Vector2(120, 8), "LT", fish.input_reverse, Color(1.0, 0.4, 0.4))
		_trigger(Vector2(150, 8), "RT", fish.input_forward, Color(0.4, 1.0, 0.5))

		var buttons := [
			["BOOST", fish.boost_held],
			["AIR ROLL", fish.air_roll_held],
			["POWERSLIDE", fish.is_powersliding],
			["ROLL %+.0f" % fish.input_roll, fish.input_roll != 0.0],
		]
		var y := 16.0
		for entry: Array in buttons:
			draw_string(font, Vector2(190, y), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE if entry[1] else dim)
			y += 20.0

	func _trigger(pos: Vector2, label: String, amount: float, color: Color) -> void:
		var bar := Rect2(pos, Vector2(18, size.y - 32.0))
		draw_rect(bar, Color(1, 1, 1, 0.35), false, 1.5)
		var fill_height := bar.size.y * amount
		draw_rect(Rect2(pos.x, bar.end.y - fill_height, bar.size.x, fill_height), color)
		draw_string(ThemeDB.fallback_font, Vector2(pos.x, bar.end.y + 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
