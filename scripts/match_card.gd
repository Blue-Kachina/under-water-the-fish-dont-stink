class_name MatchCard
extends CanvasLayer
## The card shown on going into a match mode, before the match starts: what
## the mode is, and Play. Sits where the replay bar does.

signal play_requested

## What the mode is, set before adding the card.
var message := ""

var _play: Button


func _ready() -> void:
	layer = 5
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.08, 0.85)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 470.0  # clear of the tuning panel
	panel.offset_right = -320.0  # and of the input display
	panel.offset_top = -132.0
	panel.offset_bottom = -44.0  # above the hint line
	add_child(panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	var label := Label.new()
	label.text = message
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	_play = Button.new()
	_play.text = "Play"
	_play.tooltip_text = "Start the match  Enter / A"
	_play.custom_minimum_size.x = 80.0
	_play.pressed.connect(func() -> void: play_requested.emit())
	row.add_child(_play)
	_play.grab_focus.call_deferred()  # so Enter / A presses it
