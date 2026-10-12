class_name BroadcastUI
extends RefCounted
## The HUD's broadcast-style pieces, after esports overlays (RLCS-style): a
## scoreboard bug at the top, a boost gauge in the bottom right, the goal
## splash and the replay overlay. Slanted dark-navy panels, white score
## plates, team colours for accents and gold for labels; bold slanted type.
## Each draws itself (_draw), so it scales cleanly with the window.

const INK := Color(0.035, 0.06, 0.1, 0.94)
const INK_LIGHT := Color(0.09, 0.14, 0.22, 0.94)
const PAPER := Color(0.96, 0.97, 1.0)
const TEXT_DARK := Color(0.05, 0.08, 0.12)
const GOLD := Color(1.0, 0.82, 0.32)
## Boost when the fish has no team colour (Free Play).
const BOOST_COLOR := Color(1.0, 0.6, 0.15)
## How far a panel's top edge leans right of its bottom edge (px).
const SLANT := 14.0

static var _fonts := {}


## Bahnschrift (Windows' sporty face) where there is one, slanted.
static func font(weight := 700) -> Font:
	if not _fonts.has(weight):
		var system := SystemFont.new()
		system.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "Sans-Serif"])
		system.font_weight = weight
		var slanted := FontVariation.new()
		slanted.base_font = system
		slanted.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.18, 1.0), Vector2.ZERO)
		_fonts[weight] = slanted
	return _fonts[weight]


## A slanted panel filling `rect` (top edge shifted right by `slant`).
static func parallelogram(rect: Rect2, slant := SLANT) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(rect.position.x + slant, rect.position.y), Vector2(rect.end.x + slant, rect.position.y),
		Vector2(rect.end.x, rect.end.y), Vector2(rect.position.x, rect.end.y)])


## `text` centred in `rect` (or aligned left/right in it).
static func text(canvas: CanvasItem, rect: Rect2, value: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, weight := 700) -> void:
	var f := font(weight)
	var baseline := rect.position.y + (rect.size.y + f.get_ascent(size) - f.get_descent(size)) / 2.0
	canvas.draw_string(f, Vector2(rect.position.x, baseline), value, align, rect.size.x, size, color)


static func ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


static func clock_text(seconds: float, overtime := false) -> String:
	var whole := ceili(seconds) if not overtime else floori(seconds)
	return "%s%d:%02d" % ["+" if overtime else "", whole / 60, whole % 60]


## The scoreboard: team panels either side of the score plates and the clock,
## a caption tab under the clock and each team's player names under its panel.
class ScoreBug extends Control:
	const PANEL_WIDTH := 230.0
	const SCORE_WIDTH := 58.0
	const CLOCK_WIDTH := 132.0
	const HEIGHT := 46.0
	const FLASH_TIME := 1.6

	var team_names := ["BLUE", "ORANGE"]
	var team_colors: Array = AquariumArena.TEAM_COLORS
	var scores := [0, 0]
	var players := ["", ""]
	var clock := "5:00"
	var clock_color := Color.WHITE
	var caption := ""
	var _flash := [0.0, 0.0]

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var width := 2.0 * (PANEL_WIDTH + SCORE_WIDTH) + CLOCK_WIDTH
		anchor_left = 0.5
		anchor_right = 0.5
		offset_left = -width / 2.0
		offset_right = width / 2.0
		offset_top = 14.0
		offset_bottom = 14.0 + HEIGHT + 30.0

	## A team's score plate lights up in its colour for a moment.
	func flash(team: int) -> void:
		_flash[team] = FLASH_TIME

	func _process(delta: float) -> void:
		for team in 2:
			_flash[team] = maxf(_flash[team] - delta, 0.0)
		queue_redraw()

	func _draw() -> void:
		var x := 0.0
		for team in 2:
			var color: Color = team_colors[team]
			var panel := Rect2(0.0 if team == 0 else size.x - PANEL_WIDTH, 0.0, PANEL_WIDTH, HEIGHT)
			draw_colored_polygon(BroadcastUI.parallelogram(panel), BroadcastUI.INK)
			# The team's colour along the bottom, and a chevron at the outer end.
			draw_colored_polygon(BroadcastUI.parallelogram(Rect2(panel.position.x, HEIGHT - 5.0, PANEL_WIDTH, 5.0), 1.5), color)
			var outer := panel.position.x + (24.0 if team == 0 else PANEL_WIDTH - 12.0)
			var dir := 1.0 if team == 0 else -1.0
			draw_colored_polygon(PackedVector2Array([Vector2(outer - 8.0 * dir + 3.0, 10.0), Vector2(outer + 6.0 * dir + 3.0, 10.0),
					Vector2(outer + 14.0 * dir, 23.0), Vector2(outer + 6.0 * dir - 3.0, 36.0), Vector2(outer - 8.0 * dir - 3.0, 36.0),
					Vector2(outer, 23.0)]), color)
			var name_rect := Rect2(panel.position.x + (44.0 if team == 0 else 18.0), 0.0, PANEL_WIDTH - 66.0, HEIGHT - 4.0)
			BroadcastUI.text(self, name_rect, team_names[team], 24, Color.WHITE,
					HORIZONTAL_ALIGNMENT_LEFT if team == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
			# Player names on a tab under the panel.
			if not str(players[team]).is_empty():
				var tab := Rect2(panel.position.x + (10.0 if team == 0 else 18.0), HEIGHT, PANEL_WIDTH - 28.0, 22.0)
				draw_colored_polygon(BroadcastUI.parallelogram(tab, -6.0), BroadcastUI.INK_LIGHT)
				BroadcastUI.text(self, tab.grow_individual(-14.0, 0.0, -14.0, 0.0), str(players[team]).to_upper(), 13,
						Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT if team == 0 else HORIZONTAL_ALIGNMENT_RIGHT, 600)

			var plate := Rect2(PANEL_WIDTH if team == 0 else size.x - PANEL_WIDTH - SCORE_WIDTH, 0.0, SCORE_WIDTH, HEIGHT)
			var lit: float = _flash[team] / FLASH_TIME
			draw_colored_polygon(BroadcastUI.parallelogram(plate), BroadcastUI.PAPER.lerp(color, minf(lit * 2.0, 1.0)))
			BroadcastUI.text(self, plate, str(scores[team]), 34, BroadcastUI.TEXT_DARK.lerp(Color.WHITE, minf(lit * 2.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, 800)

		var clock_rect := Rect2(PANEL_WIDTH + SCORE_WIDTH, 0.0, CLOCK_WIDTH, HEIGHT)
		draw_colored_polygon(BroadcastUI.parallelogram(clock_rect), Color(0.02, 0.035, 0.06, 0.97))
		BroadcastUI.text(self, clock_rect, clock, 30, clock_color, HORIZONTAL_ALIGNMENT_CENTER, 700)
		if not caption.is_empty():
			var tab := Rect2(clock_rect.position.x + 6.0, HEIGHT, CLOCK_WIDTH - 12.0, 20.0)
			draw_colored_polygon(PackedVector2Array([tab.position, Vector2(tab.end.x, tab.position.y),
					Vector2(tab.end.x - 8.0, tab.end.y), Vector2(tab.position.x + 8.0, tab.end.y)]), BroadcastUI.INK)
			BroadcastUI.text(self, tab, caption, 12, BroadcastUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 600)


## The boost meter: a ring that fills clockwise from the bottom left, the
## amount in the middle.
class BoostGauge extends Control:
	const RADIUS := 74.0
	const START := deg_to_rad(135.0)
	const SWEEP := deg_to_rad(270.0)

	var amount := 0.0
	var color := BroadcastUI.BOOST_COLOR
	var boosting := false
	var _shown := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		anchor_left = 1.0
		anchor_right = 1.0
		anchor_top = 1.0
		anchor_bottom = 1.0
		offset_left = -2.0 * RADIUS - 70.0
		offset_top = -2.0 * RADIUS - 56.0
		offset_right = -34.0
		offset_bottom = -34.0

	func _process(delta: float) -> void:
		_shown = lerpf(_shown, amount, 1.0 - exp(-14.0 * delta))
		queue_redraw()

	func _draw() -> void:
		var centre := size - Vector2(RADIUS + 12.0, RADIUS + 12.0)
		draw_circle(centre, RADIUS + 10.0, Color(0.0, 0.0, 0.0, 0.25))
		draw_circle(centre, RADIUS, BroadcastUI.INK)
		draw_arc(centre, RADIUS - 9.0, START, START + SWEEP, 64, Color(1, 1, 1, 0.1), 10.0, true)
		for i in 11:  # ticks every 10
			var angle := START + SWEEP * i / 10.0
			var along := Vector2.from_angle(angle)
			draw_line(centre + along * (RADIUS + 2.0), centre + along * (RADIUS + (8.0 if i % 5 == 0 else 5.0)), Color(1, 1, 1, 0.35), 2.0, true)
		var fraction := clampf(_shown / 100.0, 0.0, 1.0)
		if fraction > 0.002:
			var end := START + SWEEP * fraction
			var glow := Color(color, 0.55 if boosting else 0.3)
			draw_arc(centre, RADIUS - 9.0, START, end, 64, glow, 18.0, true)
			draw_arc(centre, RADIUS - 9.0, START, end, 64, color.lightened(0.15), 10.0, true)
			draw_circle(centre + Vector2.from_angle(end) * (RADIUS - 9.0), 6.0, Color.WHITE)
		BroadcastUI.text(self, Rect2(centre.x - RADIUS, centre.y - 40.0, 2.0 * RADIUS, 64.0), str(roundi(_shown)), 60, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)
		BroadcastUI.text(self, Rect2(centre.x - RADIUS, centre.y + 20.0, 2.0 * RADIUS, 20.0), "BOOST", 14, BroadcastUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 600)


## A big announcement across the middle of the screen: a title band in a team
## colour ("GOAL!"), a name under it, a detail line under that. Slides in,
## holds, slides out.
class Splash extends Control:
	const IN_TIME := 0.35
	const OUT_TIME := 0.35

	var title := ""
	var headline := ""
	var detail := ""
	var color := Color.WHITE
	var duration := 0.0
	var age := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func play(new_title: String, new_headline: String, new_detail: String, new_color: Color, time: float) -> void:
		title = new_title
		headline = new_headline
		detail = new_detail
		color = new_color
		duration = time
		age = 0.0
		visible = true

	func hide_now() -> void:
		duration = 0.0
		visible = false

	func _process(delta: float) -> void:
		if not visible:
			return
		age += delta
		if age >= duration:
			visible = false
		queue_redraw()

	func _draw() -> void:
		var out := BroadcastUI.ease_out((age - (duration - OUT_TIME)) / OUT_TIME)
		var width := size.x
		var y := size.y * 0.27
		# Title band: from the left, a team-colour slab with a darker tail.
		var t1 := BroadcastUI.ease_out(age / IN_TIME)
		var band := Rect2(width * 0.5 - 470.0 + lerpf(-width, 0.0, t1) + out * width, y, 940.0, 118.0)
		var points := BroadcastUI.parallelogram(band, 34.0)
		var dark := color.darkened(0.45)
		draw_polygon(points, PackedColorArray([dark, color, color.lightened(0.1), dark]))
		draw_colored_polygon(BroadcastUI.parallelogram(Rect2(band.position.x - 30.0, band.end.y + 4.0, band.size.x * 0.6, 5.0), 2.0), Color(color, 0.8))
		BroadcastUI.text(self, Rect2(band.position + Vector2(4.0, 4.0), band.size), title, 100, Color(0, 0, 0, 0.35), HORIZONTAL_ALIGNMENT_CENTER, 800)
		BroadcastUI.text(self, band, title, 100, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)
		# The name: from the right, a little behind.
		if not headline.is_empty():
			var t2 := BroadcastUI.ease_out((age - 0.12) / IN_TIME)
			var plate := Rect2(width * 0.5 - 330.0 + lerpf(width, 0.0, t2) - out * width, band.end.y + 16.0, 660.0, 66.0)
			draw_colored_polygon(BroadcastUI.parallelogram(plate, 20.0), BroadcastUI.INK)
			draw_colored_polygon(BroadcastUI.parallelogram(Rect2(plate.position.x, plate.position.y, 8.0, plate.size.y), 20.0), color)
			BroadcastUI.text(self, plate, headline.to_upper(), 42, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)
			if not detail.is_empty():
				var t3 := BroadcastUI.ease_out((age - 0.22) / IN_TIME)
				var strip := Rect2(width * 0.5 - 250.0, plate.end.y + 8.0, 500.0, 30.0)
				draw_colored_polygon(BroadcastUI.parallelogram(strip, 10.0), Color(BroadcastUI.INK_LIGHT, t3 * (1.0 - out)))
				BroadcastUI.text(self, strip, detail.to_upper(), 17, Color(BroadcastUI.GOLD, t3 * (1.0 - out)), HORIZONTAL_ALIGNMENT_CENTER, 600)


## Over a goal replay: letterbox bars, a REPLAY tag, the "scored by" card and
## a progress line along the bottom.
class ReplayOverlay extends Control:
	const BAR := 64.0

	var replay: GoalReplay
	var scorer := ""
	var assister := ""
	var speed_text := ""
	var color := Color.WHITE
	var _age := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		visible = false

	func start(goal_replay: GoalReplay, scorer_name: String, assister_name: String, speed: String, team_color: Color) -> void:
		replay = goal_replay
		scorer = scorer_name
		assister = assister_name
		speed_text = speed
		color = team_color
		_age = 0.0
		visible = true

	func stop() -> void:
		replay = null
		visible = false

	func _process(delta: float) -> void:
		if not visible:
			return
		_age += delta
		queue_redraw()

	func _draw() -> void:
		var t := BroadcastUI.ease_out(_age / 0.4)
		var bar := BAR * t
		draw_rect(Rect2(0.0, 0.0, size.x, bar), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(0.0, size.y - bar, size.x, bar), Color(0, 0, 0, 0.85))
		if is_instance_valid(replay) and replay.data.duration > 0.0:
			draw_rect(Rect2(0.0, size.y - bar, size.x * clampf(replay.time / replay.data.duration, 0.0, 1.0), 3.0), color)

		# REPLAY tag, top left, with a blinking dot.
		var tag := Rect2(36.0, 16.0, 150.0, 34.0)
		draw_colored_polygon(BroadcastUI.parallelogram(tag, 10.0), BroadcastUI.GOLD)
		if fmod(_age, 1.0) < 0.6:
			draw_circle(tag.position + Vector2(24.0, 17.0), 6.0, Color(0.85, 0.1, 0.1))
		BroadcastUI.text(self, tag.grow_side(SIDE_LEFT, -20.0), "REPLAY", 22, BroadcastUI.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER, 800)
		BroadcastUI.text(self, Rect2(size.x - 280.0, size.y - bar, 250.0, BAR), "JUMP / START   SKIP", 15, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, 600)

		# The card: SCORED BY over the name, assist and speed either side.
		var card := Rect2(size.x * 0.5 - 300.0, size.y - bar - 92.0 + (1.0 - t) * 40.0, 600.0, 84.0)
		draw_rect(card, BroadcastUI.INK)
		draw_rect(Rect2(card.position, Vector2(card.size.x, 4.0)), color)
		var header := Rect2(card.position.x + card.size.x * 0.5 - 80.0, card.position.y - 20.0, 160.0, 22.0)
		draw_colored_polygon(PackedVector2Array([header.position + Vector2(10.0, 0.0), Vector2(header.end.x - 10.0, header.position.y),
				Vector2(header.end.x, header.end.y), Vector2(header.position.x, header.end.y)]), BroadcastUI.INK)
		BroadcastUI.text(self, header, "SCORED BY", 13, BroadcastUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 600)
		BroadcastUI.text(self, Rect2(card.position.x + 150.0, card.position.y + 6.0, 300.0, 74.0), scorer.to_upper(), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)
		for side in 2:
			var label := "ASSIST" if side == 0 else "SPEED"
			var value := (assister if not assister.is_empty() else "-") if side == 0 else speed_text
			var column := Rect2(card.position.x + (10.0 if side == 0 else card.size.x - 150.0), card.position.y + 14.0, 140.0, 24.0)
			BroadcastUI.text(self, column, label, 12, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 600)
			BroadcastUI.text(self, Rect2(column.position + Vector2(0.0, 24.0), column.size + Vector2(0.0, 8.0)), value.to_upper(), 19, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 700)
