class_name MatchCard
extends CanvasLayer
## The card shown on going into a match mode, before the match starts: what
## the mode is, and Play. Sits along the bottom of the screen. The home
## screen's mode picker starts matches straight away (ModePicker, whose X
## shows this card's text as the mode's rules), so this mostly shows when a
## mode's picked some other way.

signal play_requested

## What the mode is, set before adding the card.
var message := ""

var _play: Button


func _ready() -> void:
	layer = 5
	var s := UITheme.scale_for(get_viewport())
	var panel := PanelContainer.new()
	panel.theme = UITheme.theme(s)
	var style := UITheme.box(Color(UITheme.GROUND, 0.94), 20.0 * s, Color(UITheme.AQUA, 0.25), maxf(1.0, s))
	style.set_content_margin_all(18.0 * s)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -440.0 * s
	panel.offset_right = 440.0 * s
	panel.offset_top = -170.0 * s
	panel.offset_bottom = -56.0 * s  # above the hint line
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(18.0 * s))
	panel.add_child(row)
	var label := UITheme.label(message, "body", 16.0, UITheme.INK_SOFT, s)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	_play = Button.new()
	_play.text = "Play"
	_play.tooltip_text = "Start the match  Enter / A"
	_play.custom_minimum_size = Vector2(130.0, 60.0) * s
	_play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_play.add_theme_font_override("font", UITheme.display(600))
	_play.add_theme_font_size_override("font_size", roundi(24.0 * s))
	_play.add_theme_stylebox_override("normal", UITheme.box(UITheme.PANEL, 14.0 * s, UITheme.AQUA, 2.0 * s))
	_play.pressed.connect(func() -> void: play_requested.emit())
	row.add_child(_play)
	_play.grab_focus.call_deferred()  # so Enter / A presses it
