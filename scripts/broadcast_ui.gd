class_name BroadcastUI
extends RefCounted
## The HUD's broadcast-style pieces, after esports overlays (RLCS-style): a
## scoreboard bug at the top, a boost gauge in the bottom right, the goal
## splash, the replay overlay and the 1v1's held-up scoreboard. Slanted dark-navy panels, white score
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


## `text` centred in `rect` (or aligned left/right in it), shrunk to fit its width
## (e.g. a long column heading such as BATTERED FISH).
static func text(canvas: CanvasItem, rect: Rect2, value: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, weight := 700) -> void:
	var f := font(weight)
	while size > 8 and f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x - 4.0:
		size -= 1
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
	var credit_label := "SCORED BY"
	var second_label := "ASSIST"
	var scorer := ""
	var assister := ""
	var speed_text := ""
	var color := Color.WHITE
	var _age := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		visible = false

	## `credit` and `second`: the card's heading over the name and its left
	## column (Hunt's battery replay: "BATTERED BY" and "VICTIM").
	func start(goal_replay: GoalReplay, scorer_name: String, assister_name: String, speed: String, team_color: Color,
			credit := "SCORED BY", second := "ASSIST") -> void:
		replay = goal_replay
		credit_label = credit
		second_label = second
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

		# REPLAY tag, bottom left, with a blinking dot.
		var tag := Rect2(36.0, size.y - bar + 15.0, 150.0, 34.0)
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
		BroadcastUI.text(self, header, credit_label, 13, BroadcastUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 600)
		BroadcastUI.text(self, Rect2(card.position.x + 150.0, card.position.y + 6.0, 300.0, 74.0), scorer.to_upper(), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)
		for side in 2:
			var label := second_label if side == 0 else "SPEED"
			var value := (assister if not assister.is_empty() else "-") if side == 0 else speed_text
			var column := Rect2(card.position.x + (10.0 if side == 0 else card.size.x - 150.0), card.position.y + 14.0, 140.0, 24.0)
			BroadcastUI.text(self, column, label, 12, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 600)
			BroadcastUI.text(self, Rect2(column.position + Vector2(0.0, 24.0), column.size + Vector2(0.0, 8.0)), value.to_upper(), 19, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 700)


## One team's players down a top corner: name, boost and a boost bar each,
## and a badge beside a player for a moment when they do something (pop()).
## Blue's list sits top left, Orange's top right, mirrored.
class PlayerList extends Control:
	const ROW_WIDTH := 230.0
	const ROW_HEIGHT := 38.0
	const GAP := 6.0
	const BADGE := 30.0
	const BADGE_TIME := 3.5
	const LABELS := {"goal": "GOAL", "assist": "ASSIST", "save": "SAVE", "shot": "SHOT", "battery": "BATTERED", "demo": "DEMO"}

	var team := 0
	## Each: "name", "boost" (0-100), "present" (false: dimmed, e.g. battered)
	## and "focus" (outlined: the player being watched).
	var rows: Array[Dictionary] = []
	## Row -> [type, age] of its badge.
	var _badges := {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var right := team == 1
		anchor_left = 1.0 if right else 0.0
		anchor_right = anchor_left
		offset_left = -ROW_WIDTH - 140.0 - 16.0 if right else 16.0
		offset_right = -16.0 if right else ROW_WIDTH + 140.0 + 16.0
		offset_top = 14.0
		offset_bottom = 14.0 + 3.0 * (ROW_HEIGHT + GAP)

	## Shows `type`'s badge (a MatchStats event type) beside row `row`.
	func pop(row: int, type: String) -> void:
		if LABELS.has(type):
			_badges[row] = [type, 0.0]

	func clear_badges() -> void:
		_badges.clear()

	func _process(delta: float) -> void:
		for row: int in _badges.keys():
			_badges[row][1] += delta
			if _badges[row][1] > BADGE_TIME:
				_badges.erase(row)
		queue_redraw()

	func _draw() -> void:
		var right := team == 1
		var color: Color = AquariumArena.TEAM_COLORS[team]
		var x := size.x - ROW_WIDTH if right else 0.0
		for i in rows.size():
			var row := rows[i]
			var y := i * (ROW_HEIGHT + GAP)
			var alpha := 1.0 if row.get("present", true) else 0.45
			var panel := Rect2(x, y, ROW_WIDTH, ROW_HEIGHT)
			draw_colored_polygon(BroadcastUI.parallelogram(panel, 8.0), Color(BroadcastUI.INK, BroadcastUI.INK.a * alpha))
			if row.get("focus", false):
				var outline := BroadcastUI.parallelogram(panel, 8.0)
				outline.append(outline[0])
				draw_polyline(outline, Color(BroadcastUI.GOLD, 0.9), 2.0, true)
			# Team colour edge on the outer side.
			draw_colored_polygon(BroadcastUI.parallelogram(Rect2(x + (ROW_WIDTH - 5.0 if right else 0.0), y, 5.0, ROW_HEIGHT), 8.0), color)
			var text_row := Rect2(x + 14.0, y + 2.0, ROW_WIDTH - 28.0, 24.0)
			var boost: float = row.get("boost", 0.0)
			BroadcastUI.text(self, text_row, str(row.get("name", "")).to_upper(), 16, Color(1, 1, 1, alpha),
					HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT, 700)
			BroadcastUI.text(self, text_row, str(roundi(boost)) if row.get("present", true) else "-", 15, Color(BroadcastUI.GOLD, alpha),
					HORIZONTAL_ALIGNMENT_LEFT if right else HORIZONTAL_ALIGNMENT_RIGHT, 700)
			# The boost bar, filling from the outer side.
			var track := Rect2(x + 12.0, y + ROW_HEIGHT - 11.0, ROW_WIDTH - 26.0, 6.0)
			draw_rect(track, Color(1, 1, 1, 0.12 * alpha))
			var fill := track.size.x * clampf(boost / 100.0, 0.0, 1.0)
			draw_rect(Rect2(track.end.x - fill if right else track.position.x, track.position.y, fill, track.size.y), Color(color.lightened(0.15), alpha))
			if _badges.has(i):
				_draw_badge(i, Vector2(x - 10.0 - BADGE if right else x + ROW_WIDTH + 10.0, y + (ROW_HEIGHT - BADGE) / 2.0), right, color)

	func _draw_badge(row: int, at: Vector2, right: bool, color: Color) -> void:
		var type: String = _badges[row][0]
		var age: float = _badges[row][1]
		var pop_in := BroadcastUI.ease_out(age / 0.25)
		var fade := clampf((BADGE_TIME - age) / 0.4, 0.0, 1.0)
		var grow := 0.6 + 0.4 * pop_in + 0.15 * sin(clampf(age / 0.25, 0.0, 1.0) * PI)
		var centre := at + Vector2(BADGE, BADGE) / 2.0
		var half := BADGE / 2.0 * grow
		var plate := type == "goal"
		draw_rect(Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0), Color(color if plate else BroadcastUI.INK, fade))
		draw_rect(Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0), Color(color, fade), false, 2.0)
		_draw_glyph(type, centre, half * 0.62, Color(1, 1, 1, fade))
		var label := Rect2(at.x - 90.0 if right else at.x + BADGE + 6.0, at.y, 84.0, BADGE)
		BroadcastUI.text(self, label, LABELS[type], 14, Color(BroadcastUI.GOLD, fade * pop_in),
				HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT, 800)

	## Small white pictograms: a ball in a net, a pass, a shield, a target, a burst.
	func _draw_glyph(type: String, c: Vector2, r: float, ink: Color) -> void:
		match type:
			"goal":
				draw_polyline(PackedVector2Array([c + Vector2(-r, r), c + Vector2(-r, -r * 0.7), c + Vector2(r, -r * 0.7), c + Vector2(r, r)]), ink, 2.0, true)
				draw_circle(c + Vector2(0.0, r * 0.35), r * 0.45, ink)
			"assist":
				for k in 2:
					var o := Vector2(-r * 0.45 + k * r * 0.75, 0.0)
					draw_polyline(PackedVector2Array([c + o + Vector2(-r * 0.4, -r * 0.7), c + o + Vector2(r * 0.3, 0.0), c + o + Vector2(-r * 0.4, r * 0.7)]), ink, 2.5, true)
			"save":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.8, 0.0),
						c + Vector2(0.0, r), c + Vector2(-r * 0.8, 0.0)]), ink)
			"shot":
				draw_arc(c, r * 0.8, 0.0, TAU, 24, ink, 2.0, true)
				draw_circle(c, r * 0.25, ink)
				for a in 4:
					var d := Vector2.from_angle(a * PI / 2.0)
					draw_line(c + d * r * 0.5, c + d * r * 1.1, ink, 2.0, true)
			"battery", "demo":
				var points := PackedVector2Array()
				for k in 16:
					points.append(c + Vector2.from_angle(k * TAU / 16.0 - PI / 2.0) * (r if k % 2 == 0 else r * 0.45))
				draw_colored_polygon(points, ink)


## Name plates over the other fish in live play: a slanted tab with the
## player's name and their team's colour under it, pointing down at the fish.
## A teammate's plate also shows their boost as a circle that fills like a pie
## (a solid disc at full boost, as in Rocket League); an opponent's never does.
class NamePlates extends Control:
	const HEIGHT := 26.0
	const DISC := 9.0

	## Each: "at" (screen point above the fish), "name", "color", "boost"
	## (0-100, or negative to hide it) and "scale" (smaller when far away).
	var plates: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		# Nearer plates last, so they sit on top.
		var order := plates.duplicate()
		order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.scale < b.scale)
		for plate: Dictionary in order:
			_draw_plate(plate)

	func _draw_plate(plate: Dictionary) -> void:
		var s: float = plate.scale
		var size_px := roundi(15.0 * s)
		var label := str(plate.name).to_upper()
		var f := BroadcastUI.font(700)
		var text_width := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var boost: float = plate.boost
		var disc := DISC * s
		var pad := 12.0 * s
		var width := text_width + 2.0 * pad + (2.0 * disc + 6.0 * s if boost >= 0.0 else 0.0)
		var height := HEIGHT * s
		var at: Vector2 = plate.at
		var rect := Rect2(at.x - width / 2.0, at.y - height - 7.0 * s, width, height)
		var color: Color = plate.color
		draw_colored_polygon(BroadcastUI.parallelogram(rect, 6.0 * s), BroadcastUI.INK)
		draw_colored_polygon(BroadcastUI.parallelogram(Rect2(rect.position.x, rect.end.y - 3.0 * s, rect.size.x, 3.0 * s), 0.7 * s), color)
		draw_colored_polygon(PackedVector2Array([Vector2(at.x - 6.0 * s, rect.end.y), Vector2(at.x + 6.0 * s, rect.end.y),
				Vector2(at.x, rect.end.y + 7.0 * s)]), color)
		var text_rect := Rect2(rect.position.x + pad, rect.position.y, text_width + 4.0, height - 3.0 * s)
		if boost >= 0.0:
			var centre := Vector2(rect.position.x + pad + disc, rect.position.y + (height - 3.0 * s) / 2.0)
			_draw_boost(centre, disc, boost, color)
			text_rect.position.x += 2.0 * disc + 6.0 * s
		BroadcastUI.text(self, text_rect, label, size_px, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 700)

	## A pie from twelve o'clock, clockwise; full boost is a solid disc.
	func _draw_boost(centre: Vector2, r: float, boost: float, color: Color) -> void:
		var fill := clampf(boost / 100.0, 0.0, 1.0)
		var bright := color.lightened(0.3)
		draw_circle(centre, r, Color(1, 1, 1, 0.12))
		if fill >= 0.995:
			draw_circle(centre, r, bright)
		elif fill > 0.005:
			var points := PackedVector2Array([centre])
			var steps := maxi(ceili(fill * 32.0), 2)
			for k in steps + 1:
				points.append(centre + Vector2.from_angle(-PI / 2.0 + TAU * fill * k / steps) * r)
			draw_colored_polygon(points, bright)
		draw_arc(centre, r, 0.0, TAU, 24, Color(1, 1, 1, 0.7), maxf(1.0, 1.5 * r / DISC), true)


## The scoreboard held up during a 1v1 (as RL's): under the score bug, a block
## per team, its score on a plate in its colour, its name, then RL's columns
## along a strip in its colour, and a row per player. Under them, side by side,
## bars splitting a team stat between Blue (left) and Orange (right), and a
## footer line if there's one. See-through enough to keep the play in view
## behind it; the type stays solid to read.
class StatsBoard extends Control:
	const HEADINGS := ["SCORE", "GOALS", "SHOTS", "ASSISTS", "SAVES", "BATTERED FISH", "TOUCHES"]
	const PLATE_WIDTH := 52.0
	const NAME_WIDTH := 236.0
	const COLUMN_WIDTH := 76.0
	const HEADER_HEIGHT := 34.0
	const ROW_HEIGHT := 30.0
	const TITLE_HEIGHT := 26.0
	const GAP := 10.0
	const FADE_TIME := 0.12
	const BAR_LABEL_HEIGHT := 20.0
	const BAR_HEIGHT := 22.0
	const FOOTER_HEIGHT := 26.0
	## How much of the play shows through the panels.
	const SHADE := 0.62

	## Each team: "name", "score", "color" and "rows", each row "name", "values"
	## (one per headings) and "focus" (the player's own row).
	var teams: Array = []
	## Each: "label", "share" (Blue's, 0-1) and "text" (what to write at each end).
	var bars: Array = []
	## The column headings (always as many as HEADINGS, which sets the width).
	var headings: Array = HEADINGS
	var title := "MATCH STATS"
	var footer := ""
	## Whether it's held up; it fades in and out.
	var shown := false
	var _fade := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var width := PLATE_WIDTH + NAME_WIDTH + COLUMN_WIDTH * HEADINGS.size()
		anchor_left = 0.5
		anchor_right = 0.5
		offset_left = -width / 2.0
		offset_right = width / 2.0
		offset_top = 112.0  # under the score bug
		modulate.a = 0.0
		visible = false

	func _process(delta: float) -> void:
		_fade = move_toward(_fade, 1.0 if shown else 0.0, delta / FADE_TIME)
		modulate.a = _fade
		visible = _fade > 0.0
		offset_bottom = offset_top + _height()
		if visible:
			queue_redraw()

	func _height() -> float:
		var height := TITLE_HEIGHT
		for team: Dictionary in teams:
			height += GAP + HEADER_HEIGHT + ROW_HEIGHT * team.rows.size()
		if not bars.is_empty():
			height += GAP + BAR_LABEL_HEIGHT + BAR_HEIGHT
		if not footer.is_empty():
			height += GAP + FOOTER_HEIGHT
		return height

	func _draw() -> void:
		var shade := Color(BroadcastUI.INK, SHADE)
		var tab := Rect2(PLATE_WIDTH, 0.0, NAME_WIDTH, TITLE_HEIGHT)
		draw_colored_polygon(BroadcastUI.parallelogram(tab, 8.0), shade)
		BroadcastUI.text(self, tab, title, 14, BroadcastUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 700)
		var y := TITLE_HEIGHT
		var columns_x := PLATE_WIDTH + NAME_WIDTH
		for team: Dictionary in teams:
			y += GAP
			var color: Color = team.color
			var name_rect := Rect2(PLATE_WIDTH, y, NAME_WIDTH, HEADER_HEIGHT)
			draw_rect(name_rect, shade)
			var plate := Rect2(0.0, y, PLATE_WIDTH, HEADER_HEIGHT)
			draw_colored_polygon(BroadcastUI.parallelogram(plate, 8.0), color)
			BroadcastUI.text(self, plate, str(team.score), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)
			BroadcastUI.text(self, name_rect.grow_individual(-14.0, 0.0, 0.0, 0.0), str(team.name).to_upper(), 18, Color.WHITE,
					HORIZONTAL_ALIGNMENT_LEFT, 700)
			var strip := Rect2(columns_x, y, size.x - columns_x, HEADER_HEIGHT)
			draw_rect(strip, Color(color, 0.82))
			for i in headings.size():
				BroadcastUI.text(self, Rect2(columns_x + i * COLUMN_WIDTH, y, COLUMN_WIDTH, HEADER_HEIGHT), headings[i], 12,
						Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 700)
			y += HEADER_HEIGHT
			var striped := false
			for row: Dictionary in team.rows:
				var rect := Rect2(PLATE_WIDTH, y, size.x - PLATE_WIDTH, ROW_HEIGHT)
				draw_rect(rect, Color(BroadcastUI.INK_LIGHT if striped else BroadcastUI.INK, SHADE))
				if row.get("focus", false):
					draw_rect(Rect2(rect.position.x, y, 4.0, ROW_HEIGHT), BroadcastUI.GOLD)
				BroadcastUI.text(self, Rect2(PLATE_WIDTH + 14.0, y, NAME_WIDTH - 14.0, ROW_HEIGHT), str(row.name).to_upper(), 16,
						Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 600)
				var values: Array = row["values"]
				for i in values.size():
					BroadcastUI.text(self, Rect2(columns_x + i * COLUMN_WIDTH, y, COLUMN_WIDTH, ROW_HEIGHT), str(values[i]), 18,
							BroadcastUI.GOLD if i == 0 else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 700)
				y += ROW_HEIGHT
				striped = not striped
		if not bars.is_empty():
			y += GAP
			_draw_bars(y)
			y += BAR_LABEL_HEIGHT + BAR_HEIGHT
		if not footer.is_empty():
			y += GAP
			var rect := Rect2(PLATE_WIDTH, y, size.x - PLATE_WIDTH, FOOTER_HEIGHT)
			draw_rect(rect, shade)
			BroadcastUI.text(self, rect, footer, 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 700)

	func _draw_bars(y: float) -> void:
		var colors: Array = AquariumArena.TEAM_COLORS
		var left := PLATE_WIDTH
		var width := (size.x - left - GAP * (bars.size() - 1)) / bars.size()
		for i in bars.size():
			var bar: Dictionary = bars[i]
			var x := left + i * (width + GAP)
			var label := Rect2(x, y, width, BAR_LABEL_HEIGHT)
			draw_rect(label, Color(BroadcastUI.INK, SHADE))
			BroadcastUI.text(self, label, bar.label, 12, BroadcastUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 700)
			var split := width * clampf(bar.share, 0.0, 1.0)
			var top := y + BAR_LABEL_HEIGHT
			draw_rect(Rect2(x, top, split, BAR_HEIGHT), Color(colors[0], 0.85))
			draw_rect(Rect2(x + split, top, width - split, BAR_HEIGHT), Color(colors[1], 0.85))
			var ends := Rect2(x + 8.0, top, width - 16.0, BAR_HEIGHT)
			BroadcastUI.text(self, ends, bar.text[0], 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 700)
			BroadcastUI.text(self, ends, bar.text[1], 14, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 700)
