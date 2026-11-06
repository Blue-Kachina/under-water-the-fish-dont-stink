class_name HudIcons
extends RefCounted
## The HUD's marker icons (the HUD redesign, 2026-10-25), shared by the
## compass strip, the minimap, the purse and the run summary: the final
## boss's devil head, a shrine's temple in its colour, a chest, a pearl, a
## heart and a teammate's diamond.
## Filled shapes from SVG path data in a 32-unit box, drawn `size` px wide
## round a centre, each with a dark rim so it reads over the water.

const BOSS := Color(1.0, 64 / 255.0, 88 / 255.0)
const BOSS_DARK := Color(42 / 255.0, 0.0, 8 / 255.0)
const BOSS_EYES := Color(1.0, 232 / 255.0, 160 / 255.0)
## A shrine that's been used: its outline, grey.
const SHRINE_USED := Color(111 / 255.0, 132 / 255.0, 148 / 255.0)
const RIM := Color(4 / 255.0, 18 / 255.0, 30 / 255.0, 0.9)
const PEARL_DARK := Color(143 / 255.0, 141 / 255.0, 184 / 255.0)
const PEARL_MID := Color(228 / 255.0, 226 / 255.0, 247 / 255.0)

const _HORN_LEFT := "M8.5 13C7 10 7 6.5 9 4c0 3 1.5 5.5 4 6.5Z"
const _HORN_RIGHT := "M23.5 13C25 10 25 6.5 23 4c0 3-1.5 5.5-4 6.5Z"
const _FACE := "M8 15C8 11 11.5 9 16 9S24 11 24 15C24 21 20 26 16 26S8 21 8 15Z"
const _EYE_LEFT := "M10.5 15.5L14.5 17L11 18.2Z"
const _EYE_RIGHT := "M21.5 15.5L17.5 17L21 18.2Z"
const _MOUTH := "M12.5 21.5l1.2 1 1.1-1 1.2 1 1.2-1 1.1 1 1.2-1"
const _ROOF := "M4 11L16 4L28 11Z"
const _BEAM := "M4 12H28V14.2H4Z"
const _COLUMNS := ["M6.3 15.5H8.7V22.5H6.3Z", "M11.3 15.5H13.7V22.5H11.3Z", "M18.3 15.5H20.7V22.5H18.3Z", "M23.3 15.5H25.7V22.5H23.3Z"]
const _STEP_TOP := "M3.5 23.5H28.5V25.5H3.5Z"
const _STEP_LOW := "M2 26.5H30V28.5H2Z"
const _LID := "M5 13V10.5C5 8 9 6.5 16 6.5S27 8 27 10.5V13Z"
const _BODY := "M5 14H27V25H5Z"
const _LOCK := "M14 12H18V17H14Z"
const _MATE := "M16 3L28 16L16 29L4 16Z"
const _HEART := "M16 27C6 19.5 4.5 13 8 9.5C11 6.5 14.5 8 16 10.5C17.5 8 21 6.5 24 9.5C27.5 13 26 19.5 16 27Z"

## Path data -> its points in the 32-unit box (one outline per path).
static var _shapes := {}


## The final boss: a red devil's head, horned, with a soft red glow.
static func draw_boss(canvas: CanvasItem, centre: Vector2, size: float, glow := true) -> void:
	if glow:
		for n in 3:
			canvas.draw_circle(centre, size * (0.42 + 0.08 * n), Color(BOSS, 0.12 - 0.035 * n))
	var rim := maxf(size / 32.0, 1.0)
	for path: String in [_HORN_LEFT, _HORN_RIGHT, _FACE]:
		_fill(canvas, path, centre, size, BOSS, BOSS_DARK, rim)
	_fill(canvas, _EYE_LEFT, centre, size, BOSS_EYES)
	_fill(canvas, _EYE_RIGHT, centre, size, BOSS_EYES)
	_stroke(canvas, _MOUTH, centre, size, BOSS_DARK, maxf(size * 1.2 / 32.0, 1.0))


## A shrine: a Greek temple in `tint` (the shrine's own colour), its outline
## alone in grey once `used`; pulsing while its Tide runs.
static func draw_shrine(canvas: CanvasItem, centre: Vector2, size: float, tint: Color, used := false, pulse := false) -> void:
	var s := size * (1.0 + (0.12 * sin(Time.get_ticks_msec() / 120.0) if pulse else 0.0))
	var parts: Array = [_ROOF, _BEAM] + _COLUMNS + [_STEP_TOP, _STEP_LOW]
	if used:
		for path: String in parts:
			_outline(canvas, path, centre, s, SHRINE_USED, maxf(s / 24.0, 1.0))
		return
	for path: String in parts:
		_outline(canvas, path, centre, s, RIM, maxf(s / 12.0, 1.5))
	for path: String in parts:
		_fill(canvas, path, centre, s, tint)


## A chest: lid, body and a dark lock, in `tint` (gold, cursed red, boss blue).
static func draw_chest(canvas: CanvasItem, centre: Vector2, size: float, tint: Color) -> void:
	for path: String in [_LID, _BODY]:
		_outline(canvas, path, centre, size, RIM, maxf(size / 12.0, 1.5))
	_fill(canvas, _LID, centre, size, tint)
	_fill(canvas, _BODY, centre, size, tint)
	_fill(canvas, _LOCK, centre, size, tint.darkened(0.72))


## A pearl: a pale disc shaded down to lavender, with a highlight.
static func draw_pearl(canvas: CanvasItem, centre: Vector2, size: float) -> void:
	var r := size * 12.0 / 32.0
	canvas.draw_circle(centre, r, PEARL_DARK, true, -1.0, true)
	canvas.draw_circle(centre - Vector2(r, r) * 0.12, r * 0.8, PEARL_MID.lerp(PEARL_DARK, 0.35), true, -1.0, true)
	canvas.draw_circle(centre - Vector2(r, r) * 0.2, r * 0.6, PEARL_MID, true, -1.0, true)
	canvas.draw_circle(centre - Vector2(r, r) * 0.3, r * 0.32, Color(1, 1, 1, 0.75), true, -1.0, true)
	canvas.draw_circle(centre - Vector2(r * 0.33, r * 0.38), r * 0.2, Color.WHITE, true, -1.0, true)


## A heart (hp), in `tint`.
static func draw_heart(canvas: CanvasItem, centre: Vector2, size: float, tint: Color) -> void:
	_fill(canvas, _HEART, centre, size, tint)


## A teammate: a diamond in their colour, dark-rimmed.
static func draw_mate(canvas: CanvasItem, centre: Vector2, size: float, tint: Color) -> void:
	_fill(canvas, _MATE, centre, size, tint, RIM, maxf(size / 16.0, 1.0))


## Marco Polo's layers (planning_marco_polo.md §3), 1 skeleton .. 5 aura, for
## the hider's layer pip: a bone, a heart, a muscle's blocks, scales and a glow,
## in their own colour when `lit`, a dim outline of it when not.
const LAYER_COLORS := [Color.WHITE, Color(0.93, 0.9, 0.82), Color(1.0, 0.25, 0.3), Color(0.85, 0.3, 0.25),
		Color(1.0, 0.62, 0.3), Color(1.0, 0.92, 0.45)]
## Marco Polo's mode tile glyph (24-unit stroke path, HexBadge style): a sonar
## ring with its sweep line and a blip.
const MARCO_POLO_GLYPH := "M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M7.5 12a4.5 4.5 0 1 0 9 0a4.5 4.5 0 1 0-9 0M12 12l6.4-6.4M15.5 15.6a1.1 1.1 0 1 0 2.2 0a1.1 1.1 0 1 0-2.2 0"


static func draw_layer(canvas: CanvasItem, layer: int, centre: Vector2, size: float, lit: bool) -> void:
	var tint: Color = LAYER_COLORS[clampi(layer, 1, 5)]
	if not lit:
		tint = Color(tint.darkened(0.55), 0.55)
	var r := size * 0.5
	var width := maxf(size / 9.0, 1.5)
	if lit:
		canvas.draw_circle(centre, r, Color(RIM, 0.75), true, -1.0, true)
	match layer:
		1:  # a bone, corner to corner
			var a := centre + Vector2(-r, r) * 0.48
			var b := centre + Vector2(r, -r) * 0.48
			canvas.draw_line(a, b, tint, width * 1.6, true)
			for end: Vector2 in [a, b]:
				var side := (b - a).normalized().orthogonal() * r * 0.17
				canvas.draw_circle(end + side, r * 0.19, tint, true, -1.0, true)
				canvas.draw_circle(end - side, r * 0.19, tint, true, -1.0, true)
		2:
			_fill(canvas, _HEART, centre, size * 0.9, tint)
		3:  # a muscle: a lozenge of W-shaped blocks
			var points := PackedVector2Array()
			for n in 20:
				var t := TAU * n / 20.0
				points.append(centre + Vector2(cos(t) * r * 0.78, sin(t) * r * 0.48))
			canvas.draw_colored_polygon(points, tint)
			var septum := RIM if lit else Color(RIM, 0.4)
			for k in 3:
				var x := centre.x + (k - 1) * r * 0.42
				canvas.draw_polyline(PackedVector2Array([Vector2(x + r * 0.12, centre.y - r * 0.4), Vector2(x - r * 0.08, centre.y),
						Vector2(x + r * 0.12, centre.y + r * 0.4)]), septum, maxf(width * 0.6, 1.0), true)
		4:  # scales: three rows of arcs
			for row in 3:
				for k in 3 - row % 2:
					var at := centre + Vector2((k - (1.0 if row % 2 == 0 else 0.5)) * r * 0.55, (row - 1) * r * 0.42)
					canvas.draw_arc(at, r * 0.3, 0.0, PI, 10, tint, width, true)
		5:  # the aura: a glow with rays
			canvas.draw_circle(centre, r * 0.36, tint, true, -1.0, true)
			for n in 8:
				var way := Vector2.from_angle(TAU * n / 8.0)
				canvas.draw_line(centre + way * r * 0.52, centre + way * r * (0.85 if n % 2 == 0 else 0.72), tint, width, true)


static func _shape(path: String) -> PackedVector2Array:
	if _shapes.has(path):
		return _shapes[path]
	var points := PackedVector2Array()
	for line: PackedVector2Array in HexBadge.parse_path(path).lines:
		for point in line:
			if points.is_empty() or points[points.size() - 1].distance_to(point) > 0.001:
				points.append(point)
	if points.size() > 2 and points[0].distance_to(points[points.size() - 1]) < 0.001:
		points.remove_at(points.size() - 1)
	_shapes[path] = points
	return points


static func _placed(path: String, centre: Vector2, size: float) -> PackedVector2Array:
	var source := _shape(path)
	var unit := size / 32.0
	var origin := centre - Vector2(16.0, 16.0) * unit
	var points := PackedVector2Array()
	points.resize(source.size())
	for i in source.size():
		points[i] = origin + source[i] * unit
	return points


static func _fill(canvas: CanvasItem, path: String, centre: Vector2, size: float, color: Color,
		rim := Color(0, 0, 0, 0), rim_width := 0.0) -> void:
	var points := _placed(path, centre, size)
	if points.size() < 3:
		return
	if rim_width > 0.0:
		var ring := points.duplicate()
		ring.append(points[0])
		canvas.draw_polyline(ring, rim, rim_width * 2.0, true)
	canvas.draw_colored_polygon(points, color)


static func _outline(canvas: CanvasItem, path: String, centre: Vector2, size: float, color: Color, width: float) -> void:
	var points := _placed(path, centre, size)
	if points.size() < 2:
		return
	points.append(points[0])
	canvas.draw_polyline(points, color, width, true)


static func _stroke(canvas: CanvasItem, path: String, centre: Vector2, size: float, color: Color, width: float) -> void:
	var points := _placed(path, centre, size)
	if points.size() >= 2:
		canvas.draw_polyline(points, color, width, true)
