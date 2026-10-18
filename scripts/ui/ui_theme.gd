class_name UITheme
## The menus' dark-water look (UI Redesign Handoff): the colour tokens, the
## three fonts (Fredoka for titles and big buttons, Barlow for body text, Barlow
## Condensed caps for small labels), one Godot Theme every menu uses, and
## helpers for the screens that draw themselves (the powerup cards, the HUD's
## badges).
##
## The designs are drawn at 1280×720 (REF_SIZE). Rather than scaling nodes
## (which blurs text), every size is multiplied by scale_for() as it's built,
## so text renders at its real size.

const REF_SIZE := Vector2(1280.0, 720.0)

const GROUND := Color(6 / 255.0, 24 / 255.0, 38 / 255.0)  # #061826 screen background
const DEEP := Color(4 / 255.0, 17 / 255.0, 28 / 255.0)  # #04111C rails, inputs, the darkest panels
const PANEL := Color(11 / 255.0, 37 / 255.0, 54 / 255.0)  # #0B2536 rows and cards on the ground
const CARD := Color(11 / 255.0, 31 / 255.0, 46 / 255.0)  # #0B1F2E a powerup card's fill
const INK := Color(232 / 255.0, 244 / 255.0, 248 / 255.0)  # #E8F4F8 main text
const INK_SOFT := Color(207 / 255.0, 227 / 255.0, 234 / 255.0)  # #CFE3EA body text on cards
const MUTED := Color(143 / 255.0, 179 / 255.0, 194 / 255.0)  # #8FB3C2 hints, secondary labels
const AQUA := Color(55 / 255.0, 226 / 255.0, 213 / 255.0)  # #37E2D5 focus, selected, section labels
const CORAL := Color(1.0, 138 / 255.0, 91 / 255.0)  # #FF8A5B player chip, warnings, changed values
const GOLD := Color(1.0, 194 / 255.0, 51 / 255.0)  # #FFC233 (legendary) chest labels
const DIM := Color(2 / 255.0, 10 / 255.0, 18 / 255.0, 0.72)  # #020A12 at 72%, behind pop-ups
## The HUD badges' fill: the ground at 88%.
const HUD_FILL := Color(6 / 255.0, 24 / 255.0, 38 / 255.0, 0.88)
## A badge's fill in menus.
const BADGE_FILL := Color(13 / 255.0, 43 / 255.0, 61 / 255.0)  # #0D2B3D

## Rarity.Tier -> its colour on navy (Rarity.COLORS lifted for contrast).
const RARITY := [
	Color(158 / 255.0, 163 / 255.0, 168 / 255.0),  # common #9EA3A8
	Color(77 / 255.0, 204 / 255.0, 89 / 255.0),  # uncommon #4DCC59
	Color(64 / 255.0, 140 / 255.0, 1.0),  # rare #408CFF
	Color(173 / 255.0, 82 / 255.0, 242 / 255.0),  # epic #AD52F2
	Color(1.0, 194 / 255.0, 51 / 255.0),  # legendary #FFC233
	Color(115 / 255.0, 191 / 255.0, 230 / 255.0),  # boss #73BFE6
	Color(232 / 255.0, 50 / 255.0, 60 / 255.0),  # cursed #E8323C
]

## Controller face buttons' badge colours (ControllerHints).
const FACE_COLORS := {
	"A": Color(0.33, 0.78, 0.36), "B": Color(0.93, 0.3, 0.3), "X": Color(0.27, 0.55, 0.98), "Y": Color(1.0, 0.8, 0.22),
}

const _FREDOKA := preload("res://assets/fonts/Fredoka-Variable.ttf")
const _BARLOW := {
	400: preload("res://assets/fonts/Barlow-Regular.ttf"),
	500: preload("res://assets/fonts/Barlow-Medium.ttf"),
	600: preload("res://assets/fonts/Barlow-SemiBold.ttf"),
}
const _CONDENSED := {
	600: preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf"),
	700: preload("res://assets/fonts/BarlowCondensed-Bold.ttf"),
}

static var _fonts := {}
static var _themes := {}
static var _boxes := {}


## Rarity.Tier's colour.
static func rarity(tier: int) -> Color:
	return RARITY[clampi(tier, 0, RARITY.size() - 1)]


## How much bigger than the 1280×720 designs `viewport` shows things.
static func scale_for(viewport: Viewport) -> float:
	if viewport == null:
		return 1.0
	var shown := viewport.get_visible_rect().size
	return maxf(minf(shown.x / REF_SIZE.x, shown.y / REF_SIZE.y), 0.25)


## Fredoka at `weight` (titles, big buttons).
static func display(weight := 600) -> Font:
	var key := "display%d" % weight
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = _FREDOKA
		var server := TextServerManager.get_primary_interface()
		variation.variation_opentype = {server.name_to_tag("wght"): weight}
		_fonts[key] = variation
	return _fonts[key]


## Barlow at `weight` (400, 500 or 600): body text.
static func body(weight := 400) -> Font:
	return _BARLOW.get(weight, _BARLOW[400])


## Barlow Condensed (600 or 700), letter-spaced for small caps labels at
## `size` px: RARE, TUNING LAB. `spacing` is in em.
static func caps(size: int, weight := 600, spacing := 0.2) -> Font:
	var gap := roundi(size * spacing)
	var key := "caps%d_%d" % [weight, gap]
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = _CONDENSED.get(weight, _CONDENSED[600])
		variation.spacing_glyph = gap
		_fonts[key] = variation
	return _fonts[key]


## Barlow Condensed with no extra spacing (numbers, values).
static func condensed(weight := 600) -> Font:
	return _CONDENSED.get(weight, _CONDENSED[600])


## The Theme every menu uses, its sizes at `s` (scale_for()).
static func theme(s: float) -> Theme:
	var key := snappedf(s, 0.01)
	if _themes.has(key):
		return _themes[key]
	var t := Theme.new()
	t.default_font = body(500)
	t.default_font_size = roundi(17.0 * s)

	t.set_color("font_color", "Label", INK)

	var normal := _flat(PANEL, 13.0 * s)
	normal.set_content_margin(SIDE_LEFT, 18.0 * s)
	normal.set_content_margin(SIDE_RIGHT, 18.0 * s)
	normal.set_content_margin(SIDE_TOP, 8.0 * s)
	normal.set_content_margin(SIDE_BOTTOM, 8.0 * s)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = PANEL.lightened(0.08)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = DEEP
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(PANEL, 0.5)
	var focus := _flat(Color(AQUA, 0.12), 13.0 * s, AQUA, 2.0 * s)
	for type: String in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_font("font", type, body(600))
		t.set_font_size("font_size", type, roundi(18.0 * s))
		t.set_color("font_color", type, INK)
		t.set_color("font_hover_color", type, INK)
		t.set_color("font_focus_color", type, INK)
		t.set_color("font_pressed_color", type, AQUA)
		t.set_color("font_hover_pressed_color", type, AQUA)
		t.set_color("font_disabled_color", type, Color(MUTED, 0.6))

	var field := _flat(DEEP, 12.0 * s, Color(MUTED, 0.3), maxf(1.0, s))
	field.set_content_margin(SIDE_LEFT, 14.0 * s)
	field.set_content_margin(SIDE_RIGHT, 14.0 * s)
	field.set_content_margin(SIDE_TOP, 8.0 * s)
	field.set_content_margin(SIDE_BOTTOM, 8.0 * s)
	var field_focus := _flat(Color(0, 0, 0, 0), 12.0 * s, AQUA, 2.0 * s)
	var field_off := field.duplicate() as StyleBoxFlat
	field_off.bg_color = Color(DEEP, 0.5)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", field_off)
	t.set_font("font", "LineEdit", body(500))
	t.set_font_size("font_size", "LineEdit", roundi(18.0 * s))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.6))
	t.set_color("font_uneditable_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", AQUA)
	t.set_color("selection_color", "LineEdit", Color(AQUA, 0.35))

	var track := _flat(DEEP, 6.0 * s, Color(MUTED, 0.25), maxf(1.0, s))
	track.set_content_margin(SIDE_TOP, 4.0 * s)
	track.set_content_margin(SIDE_BOTTOM, 4.0 * s)
	var filled := _flat(AQUA, 6.0 * s)
	filled.set_content_margin(SIDE_TOP, 4.0 * s)
	filled.set_content_margin(SIDE_BOTTOM, 4.0 * s)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var grabber := _disc(roundi(11.0 * s), INK, AQUA)
	t.set_icon("grabber", "HSlider", grabber)
	t.set_icon("grabber_highlight", "HSlider", grabber)
	t.set_icon("grabber_disabled", "HSlider", _disc(roundi(11.0 * s), MUTED, DEEP))

	t.set_stylebox("panel", "PanelContainer", _flat(PANEL, 20.0 * s))
	t.set_stylebox("panel", "PopupMenu", _flat(DEEP, 12.0 * s, Color(AQUA, 0.4), maxf(1.0, s)))
	t.set_stylebox("hover", "PopupMenu", _flat(Color(AQUA, 0.18), 8.0 * s))
	t.set_font("font", "PopupMenu", body(500))
	t.set_font_size("font_size", "PopupMenu", roundi(17.0 * s))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", AQUA)
	t.set_stylebox("panel", "TooltipPanel", _flat(DEEP, 8.0 * s, Color(AQUA, 0.4), maxf(1.0, s)))
	t.set_color("font_color", "TooltipLabel", INK)

	var empty := StyleBoxEmpty.new()
	var bar_grab := _flat(Color(MUTED, 0.4), 4.0 * s)
	bar_grab.set_content_margin_all(3.0 * s)
	var bar_grab_hot := _flat(Color(AQUA, 0.7), 4.0 * s)
	bar_grab_hot.set_content_margin_all(3.0 * s)
	for bar: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, empty)
		t.set_stylebox("scroll_focus", bar, empty)
		t.set_stylebox("grabber", bar, bar_grab)
		t.set_stylebox("grabber_highlight", bar, bar_grab_hot)
		t.set_stylebox("grabber_pressed", bar, bar_grab_hot)
	t.set_stylebox("panel", "ScrollContainer", empty)
	t.set_stylebox("focus", "ScrollContainer", empty)
	t.set_constant("separation", "VBoxContainer", roundi(8.0 * s))
	t.set_constant("separation", "HBoxContainer", roundi(10.0 * s))
	_themes[key] = t
	return t


## A rounded box (filled, with an optional border).
static func _flat(fill: Color, radius: float, border := Color(0, 0, 0, 0), border_width := 0.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(roundi(radius))
	box.corner_detail = 8
	box.anti_aliasing = true
	if border_width > 0.0:
		box.border_color = border
		box.set_border_width_all(maxi(roundi(border_width), 1))
	return box


## A stylebox for a Control's "panel" (or a Button's states).
static func box(fill: Color, radius: float, border := Color(0, 0, 0, 0), border_width := 0.0) -> StyleBoxFlat:
	return _flat(fill, radius, border, border_width)


## A slider grabber: a disc with a ring.
static func _disc(radius: int, fill: Color, ring: Color) -> ImageTexture:
	var size := radius * 2 + 2
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var centre := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(centre)
			var alpha := clampf(radius + 0.5 - d, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var color := ring if d > radius - maxf(radius * 0.28, 2.0) else fill
			image.set_pixel(x, y, Color(color, alpha))
	return ImageTexture.create_from_image(image)


## Draws a rounded box into `canvas` (cached styleboxes, so it's cheap every frame).
static func draw_box(canvas: CanvasItem, rect: Rect2, fill: Color, radius: float, border := Color(0, 0, 0, 0), border_width := 0.0) -> void:
	var key := "%s|%.1f|%s|%.1f" % [fill.to_html(), radius, border.to_html(), border_width]
	if not _boxes.has(key):
		if _boxes.size() > 512:
			_boxes.clear()
		_boxes[key] = _flat(fill, radius, border, border_width)
	(_boxes[key] as StyleBoxFlat).draw(canvas.get_canvas_item(), rect)


## `value` in `font` at `size`, vertically centred in `rect` and aligned in it,
## shrunk until it fits the rect's width.
static func draw_text(canvas: CanvasItem, rect: Rect2, value: String, font: Font, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	while size > 6 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x:
		size -= 1
	var baseline := rect.position.y + (rect.size.y + font.get_ascent(size) - font.get_descent(size)) / 2.0
	canvas.draw_string(font, Vector2(rect.position.x, baseline), value, align, rect.size.x, size, color)


## `value` wrapped to `rect`'s width from its top, in `font` at `size`. Returns
## the height it took.
static func draw_wrapped(canvas: CanvasItem, rect: Rect2, value: String, font: Font, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, line_spacing := 1.25) -> float:
	var lines := wrap_lines(value, font, size, rect.size.x)
	var step := size * line_spacing
	var y := rect.position.y + font.get_ascent(size)
	for line in lines:
		canvas.draw_string(font, Vector2(rect.position.x, y), line, align, rect.size.x, size, color)
		y += step
	return lines.size() * step


## `value` broken into lines no wider than `width`.
static func wrap_lines(value: String, font: Font, size: int, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var current := ""
	for word in value.split(" ", false):
		var tried := word if current.is_empty() else current + " " + word
		if current.is_empty() or font.get_string_size(tried, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			current = tried
		else:
			lines.append(current)
			current = word
	if not current.is_empty():
		lines.append(current)
	return lines


## A Label in one of the type styles: "display" (Fredoka), "body" (Barlow),
## "caps" (Barlow Condensed caps, letter-spaced).
static func label(text: String, style: String, size: float, color: Color, s: float, weight := 0) -> Label:
	var made := Label.new()
	made.text = text.to_upper() if style == "caps" else text
	var px := roundi(size * s)
	match style:
		"display":
			made.add_theme_font_override("font", display(weight if weight else 600))
		"caps":
			made.add_theme_font_override("font", caps(px, weight if weight else 600, 0.22))
		_:
			made.add_theme_font_override("font", body(weight if weight else 400))
	made.add_theme_font_size_override("font_size", px)
	made.add_theme_color_override("font_color", color)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made
