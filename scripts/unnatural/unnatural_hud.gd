class_name UnnaturalHud
extends CanvasLayer
## Unnatural's HUD (planning_unnatural.md §11), over the player's view:
## - a health bar under their fish (it flashes red when hurt);
## - the team's XP bar across the top (the controls hint and stride meter
##   have the bottom), with the level;
## - the stage clock (counting up) under it, with the kills under that;
## - a splash for each level-up, and when the run's over;
## - the results board (BroadcastUI.StatsBoard): held on D-pad up / B, and up
##   by itself once everyone's down. R starts again. Beside it, your own fish:
##   its attack, level and hp, every stat it has, and its powerups (StatsPanel).
## - the minimap (Minimap) in the bottom-right.
## With show_director on, the director's live numbers sit under the clock. In
## the Test Tank a DPS readout (TestTank's numbers) sits on the right.
## - the stage: each event's warning splash, the next one under the kills,
##   and a boss's health bar under the XP bar while it's out; beating the
##   Leviathan puts up STAGE COMPLETE, then the board.

const HP_COLOR := Color(0.9, 0.18, 0.2)
const XP_COLOR := Color(0.55, 0.85, 1.0)
const BOARD_COLOR := Color(0.55, 0.08, 0.1)
const HEADINGS := ["KILLS", "DAMAGE", "ATTACK", "BATTERY", "BATTERED FISH", "PEARLS", "TOP KM/H"]
## How long the run-over splash shows before the board comes up (s).
const OVER_SPLASH := 2.5

var run: UnnaturalRun
var fish: FishController
## The player's camera (a FollowCamera): swapping its survivor cam shows
## FOLLOW CAM or FREE CAM.
var player_camera: Camera3D:
	set(value):
		if is_instance_valid(player_camera) and player_camera.is_connected("survivor_cam_swapped", _show_cam_mode):
			player_camera.disconnect("survivor_cam_swapped", _show_cam_mode)
		player_camera = value
		if is_instance_valid(player_camera) and player_camera.has_signal("survivor_cam_swapped"):
			player_camera.connect("survivor_cam_swapped", _show_cam_mode)

var _bars := Bars.new()
var _minimap := Minimap.new()
var _clock := Label.new()
var _kills := Label.new()
var _director := Label.new()
var _splash := BroadcastUI.Splash.new()
var _board := BroadcastUI.StatsBoard.new()
var _hurt := ColorRect.new()
var _cards := LevelUpCards.new()
var _dps := DpsPanel.new()
var _stats := StatsPanel.new()
var _over_age := -1.0
var _cam_note := Label.new()


func _ready() -> void:
	layer = 2
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt.color = Color(0.8, 0.0, 0.05, 0.0)
	add_child(_hurt)
	_bars.hud = self
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bars)
	_minimap.hud = self
	add_child(_minimap)
	for label: Label in [_clock, _kills, _director]:
		label.anchor_left = 0.5
		label.anchor_right = 0.5
		label.offset_left = -300.0
		label.offset_right = 300.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", BroadcastUI.font(800))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", 6)
		add_child(label)
	_clock.offset_top = 22.0
	_clock.add_theme_font_size_override("font_size", 40)
	_kills.offset_top = 70.0
	_kills.add_theme_font_size_override("font_size", 20)
	_kills.add_theme_color_override("font_color", Color(1.0, 0.75, 0.7))
	_director.offset_top = 98.0
	_director.add_theme_font_size_override("font_size", 14)
	_director.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_cam_note.anchor_left = 0.5
	_cam_note.anchor_right = 0.5
	_cam_note.anchor_top = 0.62
	_cam_note.anchor_bottom = 0.62
	_cam_note.offset_left = -300.0
	_cam_note.offset_right = 300.0
	_cam_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cam_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cam_note.add_theme_font_override("font", BroadcastUI.font(800))
	_cam_note.add_theme_font_size_override("font_size", 26)
	_cam_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_cam_note.add_theme_constant_override("outline_size", 6)
	_cam_note.modulate.a = 0.0
	add_child(_cam_note)
	_splash.visible = false
	add_child(_splash)
	_dps.hud = self
	_dps.anchor_left = 1.0
	_dps.anchor_right = 1.0
	_dps.offset_left = -DpsPanel.WIDTH - 16.0
	_dps.offset_right = -16.0
	_dps.offset_top = 140.0
	_dps.offset_bottom = 520.0
	add_child(_dps)
	_stats.hud = self
	_stats.anchor_left = 1.0
	_stats.anchor_right = 1.0
	_stats.offset_left = -StatsPanel.WIDTH - 16.0
	_stats.offset_right = -16.0
	_stats.offset_top = 120.0
	_stats.offset_bottom = 900.0
	_stats.visible = false
	add_child(_stats)
	add_child(_cards)
	add_child(_board)
	_board.headings = HEADINGS
	if run:
		run.leveled_up.connect(func(level: int) -> void:
			if run.settings.card_choices <= 0:
				_splash.play("LEVEL UP", "LEVEL %d" % level, "+%d MAX HP" % roundi(run.settings.hp_per_level), XP_COLOR, 1.8))
		run.cards_offered.connect(func(for_fish: FishController, cards: Array, heading: String, line: String) -> void:
			if for_fish == fish:
				_cards.pauses = run.cards_pause_game()
				_cards.open(cards, heading, line, fish.input_source))
		_cards.picked.connect(func(index: int) -> void: run.pick(fish, index))
		run.card_picked.connect(func(for_fish: FishController, _card: Dictionary) -> void:
			if for_fish == fish and not run.is_picking(fish):
				_cards.close())
		run.player_hurt.connect(func(hurt_fish: FishController, _amount: float) -> void:
			if hurt_fish == fish:
				_hurt.color.a = 0.32)
		run.run_over.connect(func() -> void:
			_over_age = 0.0
			_splash.play("THE BLOOD MOON WINS", "OVERRUN", "SURVIVED %s  ·  %d KILLS" % [_time_text(run.elapsed), run.kills],
					HP_COLOR, OVER_SPLASH))
		run.stage_warned.connect(func(event: String) -> void:
			_splash.play(StageTimeline.headline(event), "WARNING", StageTimeline.line(event), HP_COLOR, 2.4))
		run.boss_defeated.connect(func(boss: Boss, by: FishController) -> void:
			if boss is DrownedShark:
				_splash.play("DROWNED SHARK BEATEN", "MINI-BOSS DOWN", "%s  ·  IT DROPPED A BOSS CHEST" % (by.display_name.to_upper() if is_instance_valid(by) and by.display_name else "SURVIVORS"),
						TreasureChest.STEEL, 2.4))
		run.boss_enraged.connect(func(_boss: Boss) -> void:
			_splash.play("THE LEVIATHAN ENRAGES", "NO TIME LIMIT", "AND THE DEAD KEEP COMING", HP_COLOR, 2.4))
		run.stage_completed.connect(func() -> void:
			_over_age = 0.0
			_splash.play("STAGE COMPLETE", "THE NIGHT IS OVER", "%s  ·  %d KILLS" % [_time_text(run.elapsed), run.kills], TreasureChest.GOLD, OVER_SPLASH))
		run.drop_taken.connect(_show_drop)
		run.powerup_lost.connect(func(whose: FishController, id: String) -> void:
			if whose == fish:
				_note("THE SUNKEN IDOL TAKES YOUR %s" % Powerup.title(id).to_upper(), TreasureChest.BLOOD))
		run.restarted.connect(func() -> void:
			_over_age = -1.0
			_cards.close()
			_splash.hide_now())


func _show_cam_mode(free: bool) -> void:
	_note(("FREE CAM  ·  RIGHT STICK AIMS" if free else "FOLLOW CAM") + "  ·  Y SWAPS", Color.WHITE)


## A short note in the middle of the view that holds a moment, then fades.
func _note(text: String, color: Color) -> void:
	_cam_note.text = text
	_cam_note.add_theme_color_override("font_color", color)
	_cam_note.modulate.a = 1.6


## A drop taken: what it did (a heart heals the whole team).
func _show_drop(kind: int, by: FishController) -> void:
	var color: Color = Pickup.COLORS[kind]
	match kind:
		Pickup.Kind.HEART:
			_note("HEART  ·  +%d%% HP%s" % [roundi(run.settings.heart_heal * 100.0), "" if run.players.size() <= 1 else " FOR THE TEAM"], color)
		Pickup.Kind.MAGNET:
			_note("MAGNET  ·  EVERY PEARL TO %s" % ("YOU" if by == fish else (by.display_name.to_upper() if is_instance_valid(by) and by.display_name else "A FRIEND")), color)
		Pickup.Kind.HOURGLASS:
			_note("HOURGLASS  ·  THE DEAD STAND STILL  ·  %d S" % roundi(run.settings.hourglass_time), color)


func _process(delta: float) -> void:
	if not is_instance_valid(run):
		return
	_hurt.color.a = move_toward(_hurt.color.a, 0.0, delta * 0.9)
	_cam_note.modulate.a = move_toward(_cam_note.modulate.a, 0.0, delta * 0.8)
	_clock.text = _time_text(run.elapsed)
	_kills.text = "%d KILLS" % run.kills
	var next := run.timeline.next_event() if run.timeline and not run.tank else {}
	if not next.is_empty() and not run.is_over:
		_kills.text += "    ·    %s IN %s" % [StageTimeline.headline(next.id).trim_prefix("THE "), _time_text(maxf(next.time - run.elapsed, 0.0))]
	_director.visible = run.settings.show_director
	if _director.visible:
		var director := run.director
		_director.text = "DIRECTOR  alive %d / %d  ·  pressure x%.2f  ·  intensity %.2f%s  ·  kills/s %.1f  ·  pack %d  ·  elite %d%%  ·  difficulty %.1f" % [
				run.horde.alive_count(), director.target_alive(), director.pressure, director.intensity,
				"  ·  BREATHER %.0f s" % director.relief_left if director.in_relief() else "", director.kill_rate(),
				director.swarm_size(), roundi(director.elite_chance() * 100.0), run.difficulty()]
	if _over_age >= 0.0:
		_over_age += delta
	_update_board()


func _update_board() -> void:
	var input: PlayerInput = fish.input_source if fish and fish.input_source else PlayerInput.everyone()
	_board.shown = input.pressed("show_scoreboard") or _over_age >= OVER_SPLASH
	_stats.visible = _board.shown and is_instance_valid(fish)
	if not _board.shown:
		return
	_stats.queue_redraw()
	_board.title = ("STAGE COMPLETE" if run.stage_complete else "RUN OVER") if run.is_over else "RUN STATS"
	var footer := "TIME  %s    ·    LEVEL  %d" % [_time_text(run.elapsed), run.levels.level]
	if run.is_over:
		footer += "    ·    R: TRY AGAIN"
	_board.footer = footer
	var rows := []
	for player: FishController in run.players:
		if not is_instance_valid(player):
			continue
		var stats := run.stats_of(player)
		var by: Dictionary = stats.by_source
		rows.append({"name": player.display_name if player.display_name else "Player", "focus": player == fish, "values": [
			stats.kills, roundi(stats.damage), roundi(_attack_damage(by)), roundi(by.get("battery", 0.0)), stats.battered,
			stats.pearls, roundi(stats.top_speed * 3.6)]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.values[0] > b.values[0])
	_board.teams = [{"name": "Survivors" if rows.size() > 1 else "Survivor", "score": run.kills, "color": BOARD_COLOR, "rows": rows}]


## Damage by any fish's auto-attack (a player may have had more than one, via the panel).
static func _attack_damage(by: Dictionary) -> float:
	var total := 0.0
	for source in FishAttack.sources():
		total += by.get(source, 0.0)
	return total


static func _time_text(seconds: float) -> String:
	var whole := floori(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


## The Test Tank's DPS readout: each damage source's damage, DPS (recent
## and overall), hits and the kills it would have scored.
class DpsPanel extends Control:
	const WIDTH := 430.0
	const ROW := 26.0
	const COLUMNS := [["SOURCE", 110.0], ["DAMAGE", 70.0], ["DPS 5S", 66.0], ["DPS", 60.0], ["HITS", 56.0], ["KILLS", 56.0]]

	var hud: UnnaturalHud

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		visible = is_instance_valid(hud.run) and hud.run.tank != null
		if visible:
			queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(hud.run) or hud.run.tank == null:
			return
		var tank := hud.run.tank
		var rows := tank.sources()
		var height := ROW * (rows.size() + 2)
		draw_rect(Rect2(0.0, 0.0, WIDTH, height), Color(BroadcastUI.INK, 0.8))
		BroadcastUI.text(self, Rect2(10.0, 0.0, WIDTH - 20.0, ROW), "TEST TANK  ·  %s  ·  LV %d  ·  R: RESET" % [UnnaturalHud._time_text(tank.elapsed), hud.run.levels.level],
				14, BroadcastUI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 800)
		_row(ROW, COLUMNS.map(func(c: Array) -> String: return c[0]), Color(1, 1, 1, 0.6), 12)
		for i in rows.size():
			var r: Dictionary = rows[i]
			var total: bool = r.source == "total"
			_row(ROW * (i + 2), [str(r.source).to_upper(), str(roundi(r.damage)), "%.0f" % r.dps, "%.0f" % r.overall, str(r.hits), str(r.kills)],
					BroadcastUI.GOLD if total else Color.WHITE, 15)

	func _row(y: float, cells: Array, color: Color, size_px: int) -> void:
		var x := 10.0
		for c in cells.size():
			var width: float = COLUMNS[c][1]
			BroadcastUI.text(self, Rect2(x, y, width, ROW), cells[c], size_px, color,
					HORIZONTAL_ALIGNMENT_LEFT if c == 0 else HORIZONTAL_ALIGNMENT_RIGHT, 700)
			x += width


## Your own fish beside the results board: your fish and its attack, your
## level and hp, every stat you have (the signature marked), and your
## powerups with their stacks, each in its rarity's colour.
class StatsPanel extends Control:
	const WIDTH := 360.0
	const ROW := 22.0

	var hud: UnnaturalHud

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var run := hud.run
		var fish := hud.fish
		if not is_instance_valid(run) or not is_instance_valid(fish) or run.health_of(fish) == null:
			return
		var lines := []  # [text, colour, size]
		var attack := run.attack_of(fish)
		lines.append(["%s  ·  %s" % [FishCharacter.display_name(fish.character).to_upper(),
				FishAttack.title(attack.kind).to_upper() if attack else "?"], BroadcastUI.GOLD, 16])
		var health := run.health_of(fish)
		lines.append(["LEVEL %d    ·    HP %d / %d" % [run.levels.level, roundi(health.hp), roundi(health.max_hp)], Color.WHITE, 15])
		lines.append(["", Color.WHITE, 8])
		lines.append(["STATS", Color(1, 1, 1, 0.6), 12])
		var block := run.block_of(fish)
		var signature := StatBlock.signature(fish.character)
		var any := false
		for id: String in StatBlock.STATS:
			var value := block.value(id)
			if absf(value) < 0.0001:
				continue
			any = true
			lines.append([StatBlock.describe(id, value) + ("   (SIGNATURE)" if id == signature else ""),
					BroadcastUI.GOLD if id == signature else Color.WHITE, 14])
		if not any:
			lines.append(["none yet", Color(1, 1, 1, 0.5), 14])
		lines.append(["", Color.WHITE, 8])
		lines.append(["POWERUPS", Color(1, 1, 1, 0.6), 12])
		var held := run.powerups_of(fish).list()
		for entry: Array in held:
			var id: String = entry[0]
			lines.append(["%s  x%d   ·   %s" % [Powerup.title(id), entry[1], Rarity.NAMES[Powerup.tier(id)]],
					Rarity.COLORS[Powerup.tier(id)].lightened(0.25), 14])
		if held.is_empty():
			lines.append(["none yet", Color(1, 1, 1, 0.5), 14])
		var height := 0.0
		for line: Array in lines:
			height += ROW if line[2] > 8 else 8.0
		draw_rect(Rect2(0.0, 0.0, WIDTH, height + 20.0), Color(BroadcastUI.INK, 0.85))
		draw_rect(Rect2(0.0, 0.0, 4.0, height + 20.0), BroadcastUI.GOLD)
		var y := 10.0
		for line: Array in lines:
			var tall: float = ROW if line[2] > 8 else 8.0
			if line[0] != "":
				BroadcastUI.text(self, Rect2(16.0, y, WIDTH - 28.0, tall), line[0], line[2], line[1], HORIZONTAL_ALIGNMENT_LEFT, 700)
			y += tall


## The health bar under the fish and the XP bar along the top; the player's
## powerups (with their stacks) down the left; a ping on each shut chest
## within chest_sense_range (at the screen's edge if it's off screen), and a
## ring filling round the fish while it opens one by holding still.
class Bars extends Control:
	const HP_WIDTH := 96.0
	const HP_HEIGHT := 9.0
	const XP_HEIGHT := 10.0

	var hud: UnnaturalHud
	var _shown_hp := 1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var run := hud.run
		if not is_instance_valid(run):
			return
		# XP: across the top, the level at its left.
		var bar := Rect2(110.0, 10.0, size.x - 140.0, XP_HEIGHT)
		draw_rect(bar.grow(2.0), Color(BroadcastUI.INK, 0.8))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * run.levels.progress(), bar.size.y)), XP_COLOR)
		BroadcastUI.text(self, Rect2(bar.position.x - 90.0, bar.position.y - 8.0, 80.0, 26.0), "LV %d" % run.levels.level, 20,
				BroadcastUI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 800)
		_draw_boss(run)
		_draw_downed(run)
		var fish := hud.fish
		if is_instance_valid(fish):
			_draw_powerups(run, fish)
			_draw_chests(run, fish)
		# Health: under the fish, where the camera sees it.
		var health := run.health_of(fish) if is_instance_valid(fish) else null
		var camera := get_viewport().get_camera_3d()
		if health == null or camera == null or camera.is_position_behind(fish.global_position):
			return
		var at := camera.unproject_position(fish.global_position - camera.global_basis.y * 0.9)
		var rect := Rect2(at.x - HP_WIDTH * 0.5, at.y + 18.0, HP_WIDTH, HP_HEIGHT)
		_shown_hp = move_toward(_shown_hp, health.share(), get_process_delta_time() * 0.6)
		draw_rect(rect.grow(2.0), Color(BroadcastUI.INK, 0.8))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * _shown_hp, rect.size.y)), Color(1.0, 0.85, 0.8, 0.6))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * health.share(), rect.size.y)), HP_COLOR)
		BroadcastUI.text(self, Rect2(rect.position.x, rect.end.y + 2.0, rect.size.x, 16.0),
				"%d / %d" % [ceili(health.hp), roundi(health.max_hp)], 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 700)

	## Co-op (D7): a marker over each downed player, its revive filling; and
	## a line for this player while they're down.
	func _draw_downed(run: UnnaturalRun) -> void:
		var camera := get_viewport().get_camera_3d()
		if camera == null or run.players.size() < 2:
			return
		for player in run.players:
			var health := run.health_of(player)
			if not is_instance_valid(player) or health == null or not health.down:
				continue
			if player == hud.fish:
				BroadcastUI.text(self, Rect2(0.0, size.y * 0.62, size.x, 30.0), "YOU'RE DOWN  ·  A TEAMMATE CAN REVIVE YOU", 22, HP_COLOR,
						HORIZONTAL_ALIGNMENT_CENTER, 800)
			var at := player.global_position + Vector3.UP * 1.4
			if camera.is_position_behind(at):
				continue
			var spot := camera.unproject_position(at)
			draw_circle(spot, 20.0, Color(BroadcastUI.INK, 0.7))
			draw_arc(spot, 20.0, -PI / 2.0, -PI / 2.0 + TAU * run.revive_progress(player), 32, Color(0.5, 1.0, 0.6), 4.0)
			BroadcastUI.text(self, Rect2(spot.x - 60.0, spot.y - 9.0, 120.0, 18.0), "DOWN", 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)

	## The boss out now: its name and health across the top, under the XP bar.
	func _draw_boss(run: UnnaturalRun) -> void:
		var boss := run.current_boss()
		if boss == null:
			return
		var width := minf(size.x * 0.5, 720.0)
		var bar := Rect2((size.x - width) * 0.5, 128.0, width, 14.0)
		draw_rect(bar.grow(3.0), Color(BroadcastUI.INK, 0.85))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * boss.share(), bar.size.y)), Color(1.0, 0.4, 0.2) if boss.enraged else HP_COLOR)
		var name_line := boss.title + ("  ·  ENRAGED" if boss.enraged else "")
		BroadcastUI.text(self, Rect2(bar.position.x, bar.position.y - 26.0, bar.size.x, 24.0), name_line, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)

	func _draw_powerups(run: UnnaturalRun, fish: FishController) -> void:
		var y := 150.0
		for entry: Array in run.powerups_of(fish).list():
			var id: String = entry[0]
			var color := Powerup.color(id)
			var box := Rect2(16.0, y, 46.0, 46.0)
			draw_rect(box, Color(BroadcastUI.INK, 0.85))
			draw_rect(box, color, false, 3.0)
			BroadcastUI.text(self, box, Powerup.tag(id), 18, color.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, 800)
			BroadcastUI.text(self, Rect2(box.end.x + 6.0, y + 10.0, 60.0, 26.0), "x%d" % entry[1], 18, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 800)
			y += 54.0

	func _draw_chests(run: UnnaturalRun, fish: FishController) -> void:
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			return
		var view := Rect2(Vector2.ZERO, size).grow(-40.0)
		for chest in run.shut_chests_for(fish):
			var at := chest.global_position + Vector3.UP
			var gap := at.distance_to(fish.global_position)
			if gap > run.settings.chest_sense_range:
				continue
			var spot: Vector2
			var behind := camera.is_position_behind(at)
			spot = camera.unproject_position(at)
			if behind:
				spot = size - spot  # mirrored: it's behind
			var inside := view.has_point(spot) and not behind
			if not inside:
				var middle := size * 0.5
				var direction := (spot - middle).normalized()
				var reach := minf(absf(view.size.x * 0.5 / direction.x) if absf(direction.x) > 0.001 else INF,
						absf(view.size.y * 0.5 / direction.y) if absf(direction.y) > 0.001 else INF)
				spot = middle + direction * reach
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0)
			var diamond := PackedVector2Array([spot + Vector2(0, -12), spot + Vector2(10, 0), spot + Vector2(0, 12), spot + Vector2(-10, 0)])
			var tint := chest.tint()
			draw_colored_polygon(diamond, Color(tint, 0.5 + 0.4 * pulse))
			BroadcastUI.text(self, Rect2(spot.x - 40.0, spot.y + 12.0, 80.0, 18.0), "%d M" % roundi(gap), 13, tint,
					HORIZONTAL_ALIGNMENT_CENTER, 700)
			if chest.progress_of(fish) > 0.0 and inside:
				draw_arc(spot, 22.0, -PI / 2.0, -PI / 2.0 + TAU * chest.progress_of(fish), 32, tint, 4.0)
