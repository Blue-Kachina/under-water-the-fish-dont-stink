class_name RaceHud
extends ModeHud
## Fin-ish Line's HUD for one local player (a ModeHud given to that player's hud.set_mode_hud): the position
## ("3rd / 8"), lap and times, a track minimap with every racer, the 3-2-1-GO text, FINAL LAP / WRONG WAY / RESCUED
## banners, the finish clock, the rescue fade, the skill button and, once the race is over, the results panel. The
## widget is one Control added to the player's hud and drawn with BroadcastUI's text; the held scoreboard lists the
## standings. One per view, so split-screen players each see their own.

const HEADINGS := ["TIME", "BEST LAP", "LAPS", "RESCUES", "", "", ""]
const BOARD_COLOR := Color(0.12, 0.5, 0.62)
const GOLD := Color(1.0, 0.82, 0.3)
const RED := Color(1.0, 0.3, 0.25)

var race: RaceMatch
var fish: FishController
var _hud: Node
var _widget: Widget
var _skill: UnnaturalHud.SkillButton
var _banner_serial := -1


func _init(match_node: RaceMatch, local_fish: FishController) -> void:
	race = match_node
	fish = local_fish
	restart_hint = "restart race"
	camera_word = "fish"
	has_board = true
	joined_hint = "Hold D-pad up: standings    Hold Ctrl / LB: rescue    Hold Back/View: leave"
	join_hint = "Back/View on another controller: join    "


func attach(hud: Node) -> void:
	_hud = hud
	_widget = Widget.new()
	_widget.race = race
	_widget.fish = fish
	_widget.name = "RaceWidget"
	hud.add_child(_widget)
	_skill = UnnaturalHud.SkillButton.new()
	_skill.anchor_left = 0.5
	_skill.anchor_right = 0.5
	_skill.anchor_top = 1.0
	_skill.anchor_bottom = 1.0
	_skill.offset_left = -UnnaturalHud.SkillButton.SIZE.x * 0.5
	_skill.offset_right = UnnaturalHud.SkillButton.SIZE.x * 0.5
	_skill.visible = false
	hud.add_child(_skill)


func detach() -> void:
	if is_instance_valid(_widget):
		_widget.queue_free()
	if is_instance_valid(_skill):
		_skill.queue_free()
	_widget = null
	_skill = null


func live() -> bool:
	return is_instance_valid(race)


func update_slots(hud: Node) -> void:
	hud.course_text = ""
	var r := race.racer_of(fish)
	if r != null and r.banner_serial != _banner_serial:
		_banner_serial = r.banner_serial
		if r.banner != "" and r.banner != "WRONG WAY":
			hud.show_banner(r.banner, maxf(r.banner_left, 0.5))
	_place_skill(r)


func countdown_text() -> String:
	return race.countdown_text()


## The skill's button over the stride meter, as on the Obstacle Course (CourseSkill): its title while it has one.
func _place_skill(r: RaceMatch.Racer) -> void:
	if _skill == null:
		return
	var twist: Traversal = r.traversal if r != null else null
	var title := twist.skill_title_now() if twist != null else ""
	_skill.twist = twist
	_skill.visible = title != "" and race.settings.skills
	if not _skill.visible:
		return
	_skill.title = title.to_upper()
	var meter := fish.swim_strokes and fish.swim_style == FishController.SwimStyle.EXTRA_SWISHY
	_skill.offset_bottom = -118.0 if meter else -28.0
	_skill.offset_top = _skill.offset_bottom - UnnaturalHud.SkillButton.SIZE.y


## The held standings: every racer by position, with their time and best lap.
func update_board(hud: Node) -> void:
	var board: Node = hud.board
	var input: PlayerInput = fish.input_source if fish and fish.input_source else PlayerInput.everyone()
	board.shown = not is_instance_valid(hud.replay) and input.pressed("show_scoreboard")
	if not board.shown:
		return
	board.headings = HEADINGS
	board.title = "STANDINGS"
	board.bars = []
	board.footer = "%s    ·    %d laps" % [race.track.track_name, race.settings.laps]
	var rows := []
	for r in race.racers:
		if not is_instance_valid(r.fish):
			continue
		var time_text := RaceBest.clock(r.finish_time) if r.finished else (RaceBest.clock(race.race_time) if race.phase == RaceMatch.Phase.RACING else "--")
		rows.append({"name": "%d  %s" % [r.place, r.name], "focus": r.fish == fish, "place": r.place, "values": [
			time_text, RaceBest.clock(r.best_lap), "%d / %d" % [mini(r.laps + 1, race.settings.laps), race.settings.laps], r.rescues, "", "", ""]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["place"] < b["place"])
	board.teams = [{"name": "Race", "score": race.racers.size(), "color": BOARD_COLOR, "rows": rows}]


## The one Control the HUD gets: everything drawn by hand.
class Widget extends Control:
	const MAP_STEP := 6.0

	var race: RaceMatch
	var fish: FishController
	var _outline := PackedVector2Array()
	var _bounds := Rect2()
	var _built_for: RaceTrack

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(race) or not is_instance_valid(fish):
			return
		var r := race.racer_of(fish)
		if r == null:
			return
		var s := clampf(size.y / 720.0, 0.6, 1.6)
		_draw_standing(r, s)
		_draw_map(r, s)
		_draw_clock(r, s)
		_draw_warnings(r, s)
		if race.phase == RaceMatch.Phase.OVER:
			_draw_results(s)
		var fade := race.fade_of(fish)
		if fade > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.02, 0.05, fade))

	## Position, lap and times, top left.
	func _draw_standing(r: RaceMatch.Racer, s: float) -> void:
		var place := maxi(r.place, 1)
		var ordinal := RaceMatch._ordinal(place)
		var digits := ordinal.substr(0, ordinal.length() - 2)
		var suffix := ordinal.substr(ordinal.length() - 2)
		var x := 24.0 * s
		var y := 18.0 * s
		var color := GOLD if place == 1 else Color.WHITE
		BroadcastUI.text(self, Rect2(x, y, 90.0 * s, 70.0 * s), digits, int(64.0 * s), color, HORIZONTAL_ALIGNMENT_LEFT, 800)
		var digit_width := BroadcastUI.font(800).get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, int(64.0 * s)).x
		BroadcastUI.text(self, Rect2(x + digit_width + 2.0, y + 8.0 * s, 40.0 * s, 28.0 * s), suffix, int(26.0 * s), color, HORIZONTAL_ALIGNMENT_LEFT, 800)
		BroadcastUI.text(self, Rect2(x + digit_width + 2.0, y + 36.0 * s, 70.0 * s, 28.0 * s), "/ %d" % race.racers.size(), int(22.0 * s),
				Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT, 700)
		var laps_total := race.settings.laps
		var lap_now := mini(r.laps + 1, laps_total)
		var lines: Array[String] = ["LAP  %d / %d" % [lap_now, laps_total]]
		if race.phase != RaceMatch.Phase.COUNTDOWN:
			lines.append("TIME  %s" % RaceBest.clock(r.finish_time if r.finished else race.race_time))
			lines.append("LAP  %s" % RaceBest.clock(race.lap_time_of(fish)))
		var best := r.best_lap if not is_inf(r.best_lap) else RaceBest.lap(race.track.track_name, laps_total)
		lines.append("BEST  %s" % RaceBest.clock(best))
		for i in lines.size():
			BroadcastUI.text(self, Rect2(x, y + (76.0 + 26.0 * float(i)) * s, 240.0 * s, 26.0 * s), lines[i], int(20.0 * s),
					Color(1, 1, 1, 0.9 if i == 0 else 0.75), HORIZONTAL_ALIGNMENT_LEFT, 700)

	## The track from above, racers as dots (the local one big and white, the leader ringed in gold).
	func _draw_map(r: RaceMatch.Racer, s: float) -> void:
		if race.track == null:
			return
		if _built_for != race.track:
			_build_map()
		var box := 190.0 * s
		var origin := Vector2(size.x - box - 22.0 * s, 20.0 * s)
		draw_rect(Rect2(origin, Vector2(box, box)), Color(0.0, 0.05, 0.08, 0.45))
		var pad := 10.0 * s
		var scale_by := (box - pad * 2.0) / maxf(maxf(_bounds.size.x, _bounds.size.y), 1.0)
		var shift := origin + Vector2(box, box) * 0.5 - (_bounds.position + _bounds.size * 0.5) * scale_by
		var line := PackedVector2Array()
		for p in _outline:
			line.append(p * scale_by + shift)
		if line.size() > 1:
			line.append(line[0])
			draw_polyline(line, Color(0.55, 0.75, 0.85, 0.7), maxf(2.0 * s, 1.5), true)
		var start := _to_map(race.track.sample(0.0).pos, scale_by, shift)
		draw_circle(start, 3.5 * s, GOLD)
		var leader: RaceMatch.Racer = null
		for other in race.racers:
			if other.place == 1:
				leader = other
		for other in race.racers:
			if not is_instance_valid(other.fish) or other.fish == fish:
				continue
			var at := _to_map(other.fish.global_position, scale_by, shift)
			draw_circle(at, 3.2 * s, other.color)
			if other == leader:
				draw_arc(at, 5.5 * s, 0.0, TAU, 14, GOLD, maxf(1.5 * s, 1.0))
		var me := _to_map(fish.global_position, scale_by, shift)
		draw_circle(me, 5.2 * s, Color.WHITE)
		draw_arc(me, 7.0 * s, 0.0, TAU, 16, Color(0.2, 0.9, 1.0), maxf(2.0 * s, 1.5))

	func _build_map() -> void:
		_built_for = race.track
		_outline = PackedVector2Array()
		var d := 0.0
		while d < race.track.lap_length:
			var p := race.track.sample(d).pos
			_outline.append(Vector2(p.x, p.z))
			d += MAP_STEP
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in _outline:
			lo = lo.min(p)
			hi = hi.max(p)
		_bounds = Rect2(lo, hi - lo)

	func _to_map(world: Vector3, scale_by: float, shift: Vector2) -> Vector2:
		return Vector2(world.x, world.z) * scale_by + shift

	## The finish clock, under the top middle.
	func _draw_clock(_r: RaceMatch.Racer, s: float) -> void:
		if race.clock_left >= 0.0 and race.phase == RaceMatch.Phase.RACING:
			BroadcastUI.text(self, Rect2(size.x * 0.5 - 200.0 * s, 14.0 * s, 400.0 * s, 40.0 * s), "FINISH CLOCK  %d" % ceili(race.clock_left), int(30.0 * s),
					RED if race.clock_left < 10.0 else GOLD, HORIZONTAL_ALIGNMENT_CENTER, 800)

	## WRONG WAY, and the rescue button's hold.
	func _draw_warnings(r: RaceMatch.Racer, s: float) -> void:
		if r.banner == "WRONG WAY" and r.banner_left > 0.0:
			BroadcastUI.text(self, Rect2(size.x * 0.5 - 300.0 * s, size.y * 0.2, 600.0 * s, 70.0 * s), "WRONG WAY", int(56.0 * s), RED, HORIZONTAL_ALIGNMENT_CENTER, 800)
			BroadcastUI.text(self, Rect2(size.x * 0.5 - 300.0 * s, size.y * 0.2 + 66.0 * s, 600.0 * s, 40.0 * s), "turn round", int(26.0 * s), Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 700)
		if r.hold_t > 0.05:
			var width := 220.0 * s
			var box := Rect2(size.x * 0.5 - width * 0.5, size.y * 0.74, width, 12.0 * s)
			draw_rect(box, Color(0, 0, 0, 0.5))
			draw_rect(Rect2(box.position, Vector2(width * clampf(r.hold_t / RaceMatch.RESCUE_HOLD, 0.0, 1.0), box.size.y)), GOLD)
			BroadcastUI.text(self, Rect2(box.position.x, box.position.y - 28.0 * s, width, 26.0 * s), "RESCUE", int(20.0 * s), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)

	## The results once everyone is home or the clock has run out.
	func _draw_results(s: float) -> void:
		var rows := race.results
		var row_h := 32.0 * s
		var width := 560.0 * s
		var height := 120.0 * s + row_h * float(rows.size())
		var box := Rect2((size.x - width) * 0.5, maxf((size.y - height) * 0.5, 10.0 * s), width, height)
		draw_rect(box, Color(0.0, 0.06, 0.1, 0.82))
		BroadcastUI.text(self, Rect2(box.position.x, box.position.y + 8.0 * s, width, 44.0 * s), "RESULTS", int(34.0 * s), GOLD, HORIZONTAL_ALIGNMENT_CENTER, 800)
		BroadcastUI.text(self, Rect2(box.position.x + 60.0 * s, box.position.y + 56.0 * s, 240.0 * s, 24.0 * s), "RACER", int(14.0 * s), Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_LEFT, 700)
		BroadcastUI.text(self, Rect2(box.position.x + 330.0 * s, box.position.y + 56.0 * s, 100.0 * s, 24.0 * s), "TIME", int(14.0 * s), Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_RIGHT, 700)
		BroadcastUI.text(self, Rect2(box.position.x + 440.0 * s, box.position.y + 56.0 * s, 100.0 * s, 24.0 * s), "BEST LAP", int(14.0 * s), Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_RIGHT, 700)
		for i in rows.size():
			var row: Dictionary = rows[i]
			var y := box.position.y + 84.0 * s + row_h * float(i)
			var mine: bool = row["fish"] == fish
			if mine:
				draw_rect(Rect2(box.position.x + 8.0 * s, y, width - 16.0 * s, row_h - 2.0 * s), Color(0.2, 0.7, 0.9, 0.25))
			var color := GOLD if int(row["place"]) == 1 else Color.WHITE
			BroadcastUI.text(self, Rect2(box.position.x + 14.0 * s, y, 40.0 * s, row_h), str(row["place"]), int(22.0 * s), color, HORIZONTAL_ALIGNMENT_CENTER, 800)
			BroadcastUI.text(self, Rect2(box.position.x + 60.0 * s, y, 270.0 * s, row_h), "%s  (%s)" % [row["name"], row["entry"]], int(18.0 * s), color, HORIZONTAL_ALIGNMENT_LEFT, 700)
			var time_text := RaceBest.clock(float(row["time"])) if row["finished"] else "DNF"
			BroadcastUI.text(self, Rect2(box.position.x + 330.0 * s, y, 100.0 * s, row_h), time_text, int(18.0 * s), color, HORIZONTAL_ALIGNMENT_RIGHT, 700)
			BroadcastUI.text(self, Rect2(box.position.x + 440.0 * s, y, 100.0 * s, row_h), RaceBest.clock(float(row["best_lap"])), int(18.0 * s), Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 700)
		var beat: Dictionary = race.personal_bests.get(fish, {})
		var note := "R: rematch    Esc: menu"
		if beat.get("total", false):
			note = "NEW PERSONAL BEST  ·  " + note
		elif beat.get("lap", false):
			note = "NEW BEST LAP  ·  " + note
		BroadcastUI.text(self, Rect2(box.position.x, box.end.y - 30.0 * s, width, 24.0 * s), note, int(16.0 * s), Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 700)
