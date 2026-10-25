class_name RunSummary
extends Control
## Unnatural's results (the HUD redesign, 2026-10-25):
## - mid-run, held on show_scoreboard (D-pad up): the scoreboard alone, in
##   the middle: everyone's level, kills, damage, battered fish, pearls and
##   top speed (most kills first, yours lit);
## - once the run's over: the scoreboard stays up by itself, left of a
##   summary side panel. The summary is one player's run, their name the title
##   (the fish's class and how the run went over it); their level, hp, pearls
##   and time; their weapons and tomes with levels; their stats (the signature
##   in gold); and their damage contribution, a bar for each source (biggest
##   first; weapons blue, items in their rarity's colour, ramming coral), k and
##   M as it grows. It scrolls when it overflows (right stick / IJKL up and
##   down), and in co-op a chip for each player picks whose run shows (right
##   stick / IJKL left and right). It opens on your own.
## Laid out at the design's 1080p size (`_u` design px to a screen px) and
## shrunk to fit the view; each part draws in its own View (the side panel
## clips its scrolling).

## The scoreboard's and the side panel's widths, and their padding (design px).
const BOARD_WIDTH := 712.0
const SIDE_WIDTH := 560.0
const PAD := 20.0
## The side panel's fixed header (its title strip) and the gap round the panels.
const TITLE_HEIGHT := 54.0
const MARGIN := 16.0
## Where the side panel starts: under the HUD's top row (px at the 1280×720
## design's scale, like UnnaturalHud.Bars).
const TOP_ROW := 46.0
## How fast the stick scrolls the side panel (design px a second, full tilt).
const SCROLL_SPEED := 900.0
const MAX_DAMAGE_ROWS := 10
const MAX_STATS := 10
const TAB := Color(70 / 255.0, 214 / 255.0, 1.0)
const LABEL := Color(169 / 255.0, 195 / 255.0, 211 / 255.0)
const MUTED := Color(143 / 255.0, 176 / 255.0, 194 / 255.0)
const RIM := Color(150 / 255.0, 215 / 255.0, 1.0, 0.16)
const ROW := Color(150 / 255.0, 215 / 255.0, 1.0, 0.05)
## The damage bars: a weapon's (the XP blue, clear of the rarities), ramming
## (coral) and a skill's (pale); an item's is its rarity's colour.
const WEAPON_BAR := Color(70 / 255.0, 214 / 255.0, 1.0)
const BATTERED := UITheme.CORAL
const SKILL_BAR := Color(0.8, 0.85, 0.95)
## The stats' icons: the glyph of the common item that adds to each (a tome's
## otherwise), in a pale blue.
const STAT_GLYPHS := {"max_hp": "hermit_shell", "regen": "kelp_wrap", "armour": "barnacle_plating", "damage": "tome_teeth",
		"attack_speed": "fizzy_soda", "crit_chance": "sea_salt", "swim_speed": "speedy_seahorse", "luck": "lucky_sand_dollar",
		"pickup_range": "divers_goggles", "battery_damage": "coral_knuckles"}
const STAT_ICON := Color(155 / 255.0, 203 / 255.0, 1.0)
const SCOREBOARD_HEADINGS := ["LV", "KILLS", "DAMAGE", "BATTERED", "PEARLS", "TOP KM/H"]

var hud: UnnaturalHud
## Whose run the side panel shows: an index in the players.
var page := 0
## How far the side panel's scrolled (design px), and how far it can go.
var scroll := 0.0
var max_scroll := 0.0
## The scoreboard and the side panel (shown once the run's over).
var board := View.new()
var side := View.new()
var _input: PlayerInput
var _flick := 0
## What's being drawn: the View, its design px per screen px and its width (design px).
var _c: CanvasItem
var _o := Vector2.ZERO
var _u := 1.0
var _w := BOARD_WIDTH


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.summary = self
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	side.summary = self
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.clip_contents = true
	side.visible = false
	add_child(side)


## Shows the scoreboard, with the side panel on `input`'s player's own run
## when `with_summary` (the run's over).
func open(input: PlayerInput, with_summary: bool) -> void:
	_input = input
	_flick = 0
	scroll = 0.0
	page = maxi(_players().find(hud.fish), 0)
	side.visible = with_summary
	visible = true
	_layout()


## Whether the side panel's showing.
func summary_shown() -> bool:
	return visible and side.visible


## The player whose run the side panel shows (null when it's not showing).
func shown_player() -> FishController:
	var players := _players()
	return players[page] if summary_shown() and page >= 0 and page < players.size() else null


## Steps the side panel to the next player (`step` 1) or the one before (-1).
func flip(step: int) -> void:
	var count := _players().size()
	if count > 0:
		page = posmod(page + step, count)
		scroll = 0.0


func _players() -> Array[FishController]:
	var list: Array[FishController] = []
	if hud and is_instance_valid(hud.run):
		for player in hud.run.players:
			if is_instance_valid(player):
				list.append(player)
	return list


func _process(delta: float) -> void:
	if not visible:
		return
	if side.visible:
		var reader := _input if _input else PlayerInput.everyone()
		var stick := reader.vector("camera_left", "camera_right", "camera_up", "camera_down")
		var step := 1 if stick.x > 0.6 else (-1 if stick.x < -0.6 else 0)
		if step != 0 and step != _flick:
			flip(step)
		_flick = step
		if absf(stick.y) > 0.2:
			scroll += stick.y * SCROLL_SPEED * delta
	if page >= _players().size():
		page = maxi(_players().find(hud.fish), 0)
	_layout()


## Places the scoreboard (in the middle, or left of the side panel) and the
## side panel (down the right).
func _layout() -> void:
	var run := hud.run if hud else null
	if not is_instance_valid(run):
		return
	var room := size.x - MARGIN * 2.0
	# The 1080p design's scale, but no smaller than most of the view's width
	# would give (a split-screen view is short: the side panel scrolls).
	var fit := maxf(size.y / 1080.0, minf(size.x / 1920.0, 2.0) * 0.8)
	if side.visible:
		var side_u := minf(fit, size.x * 0.45 / SIDE_WIDTH)
		# Under the top row (its XP count and pearls stay in sight), as tall as
		# the summary needs, up to the bottom.
		var top := TOP_ROW * maxf(minf(size.x / UITheme.REF_SIZE.x, size.y / UITheme.REF_SIZE.y), 0.75)
		var players := _players()
		var player: FishController = players[page] if page >= 0 and page < players.size() else null
		var needs := (TITLE_HEIGHT + (54.0 if players.size() > 1 else 0.0) + (_summary_height(hud.run, player) if player else 0.0)) * side_u
		side.size = Vector2(roundf(SIDE_WIDTH * side_u), roundf(minf(needs, size.y - top - MARGIN)))
		side.position = Vector2(size.x - MARGIN - side.size.x, roundf(top))
		side.u = side_u
		room = side.position.x - MARGIN * 2.0
	var board_height := _board_height(_players().size())
	var board_u := minf(minf(fit, room / BOARD_WIDTH), (size.y - MARGIN * 2.0) / board_height)
	board.size = (Vector2(BOARD_WIDTH, board_height) * board_u).round()
	board.position = (Vector2(MARGIN + (room - board.size.x) * 0.5, (size.y - board.size.y) * 0.5)).round()
	board.u = board_u
	queue_redraw()
	board.queue_redraw()
	side.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.02, 0.04, 0.45))


## Draws `view` (the scoreboard or the side panel).
func paint(view: View) -> void:
	var run := hud.run if hud else null
	if not is_instance_valid(run):
		return
	_c = view
	_o = Vector2.ZERO
	_u = view.u
	if view == board:
		_w = BOARD_WIDTH
		_paint_board(run)
	else:
		_w = SIDE_WIDTH
		_paint_side(run)


func _paint_board(run: UnnaturalRun) -> void:
	var players := _players()
	var height := _board_height(players.size())
	UITheme.draw_box(_c, _r(0, 0, _w, height), Color(UITheme.GROUND, 0.94), 16.0 * _u, Color(RIM, 0.2), 1.0)
	var status := ("STAGE COMPLETE" if run.stage_complete else "RUN OVER") if run.is_over else "RUN SO FAR"
	_title_strip("SCOREBOARD", status)
	_draw_board(run, players, TITLE_HEIGHT + 10.0)


func _board_height(count: int) -> float:
	return TITLE_HEIGHT + 10.0 + 34.0 + 52.0 * count + 48.0


## The side panel: its title (and the player chips in co-op) fixed at the
## top, the summary scrolling under them, a thin bar showing where it's got to.
func _paint_side(run: UnnaturalRun) -> void:
	var players := _players()
	var player: FishController = players[page] if page >= 0 and page < players.size() else null
	var view_height := side.size.y / maxf(_u, 0.001)
	UITheme.draw_box(_c, _r(0, 0, _w, view_height), Color(UITheme.GROUND, 0.94), 16.0 * _u, Color(RIM, 0.2), 1.0)
	if player == null:
		return
	var header := TITLE_HEIGHT + (54.0 if players.size() > 1 else 0.0)
	var content := _summary_height(run, player)
	max_scroll = maxf(content - (view_height - header), 0.0)
	scroll = clampf(scroll, 0.0, max_scroll)
	# The summary, moved up by the scroll (drawn first: the header covers what's gone past).
	_o = Vector2(0.0, (header - scroll) * _u)
	_draw_summary(run, player, 16.0)
	_o = Vector2.ZERO
	UITheme.draw_box(_c, _r(0, 0, _w, header), Color(UITheme.GROUND, 1.0), 16.0 * _u)
	_c.draw_rect(_r(0, header * 0.5, _w, header * 0.5), Color(UITheme.GROUND, 1.0))
	_title_strip("SUMMARY", "")
	if players.size() > 1:
		_draw_chips(players, TITLE_HEIGHT + 10.0)
	_c.draw_line(_p(0, header), _p(_w, header), RIM, 1.0)
	# Where the scroll's got to, down the right edge.
	if max_scroll > 0.0:
		var track := view_height - header - 24.0
		var thumb := maxf(track * (view_height - header) / content, 30.0)
		var top := header + 12.0 + (track - thumb) * scroll / max_scroll
		UITheme.draw_box(_c, _r(_w - 8.0, header + 12.0, 3, track), Color(RIM, 0.1), 1.5 * _u)
		UITheme.draw_box(_c, _r(_w - 8.0, top, 3, thumb), Color(TAB, 0.7), 1.5 * _u)


## A panel's title strip: `title` lit with an underline, `note` on the right.
func _title_strip(title: String, note: String) -> void:
	var font := UITheme.caps(maxi(roundi(20.0 * _u), 6), 700, 0.12)
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(roundi(20.0 * _u), 6)).x / maxf(_u, 0.001)
	_text(_r(PAD, 0, width + 4.0, TITLE_HEIGHT), title, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 700, 0.12)
	_c.draw_rect(_r(PAD, TITLE_HEIGHT - 3.0, width, 3), TAB)
	if note != "":
		_text(_r(_w - PAD - 300.0, 0, 300, TITLE_HEIGHT), note, 14, LABEL, HORIZONTAL_ALIGNMENT_RIGHT, 600, 0.12)
	_c.draw_line(_p(0, TITLE_HEIGHT), _p(_w, TITLE_HEIGHT), RIM, 1.0)


## A chip for each player (their colour, their name), the one showing lit,
## with chevrons either side: flick to step through them.
func _draw_chips(players: Array[FishController], y: float) -> void:
	var x := PAD + 16.0
	var font := UITheme.condensed(600)
	for way: float in [-1.0, 1.0]:
		var cx := PAD + 4.0 if way < 0.0 else _w - PAD - 4.0
		var tip := _p(cx + way * 4.0, y + 18.0)
		_c.draw_colored_polygon(PackedVector2Array([tip, _p(cx - way * 3.0, y + 12.0), _p(cx - way * 3.0, y + 24.0)]), Color(MUTED, 0.7))
	for n in players.size():
		var player := players[n]
		var on := n == page
		var name_text := _name_of(player, n)
		var width := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 46.0
		var color := _color_of(player)
		UITheme.draw_box(_c, _r(x, y, width, 36), Color(0.59, 0.84, 1.0, 0.1 if on else 0.0), 18.0 * _u,
				color if on else Color(RIM, 0.18), 1.0)
		_diamond(_p(x + 20.0, y + 18.0), 7.0, color)
		_text(_r(x + 32.0, y, width - 36.0, 36), name_text, 17, Color.WHITE if on else LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600)
		x += width + 8.0


## The summary's height (design px) for `player`, from its top padding.
func _summary_height(run: UnnaturalRun, player: FishController) -> float:
	var loadout := run.loadout_of(player)
	var slots := maxi(maxi(loadout.weapons.size(), loadout.tomes.size()), 1)
	var height := 16.0 + 124.0 + 18.0 + 22.0 + slots * 46.0 + 18.0
	height += 22.0 + maxf(ceili(_stats(run, player).size() / 2.0), 1.0) * 32.0 + 18.0
	var sources := mini(run.stats_of(player).by_source.size(), MAX_DAMAGE_ROWS)
	if sources > 0:
		height += 24.0 + sources * 27.0 + 30.0
	return height + PAD


func _draw_summary(run: UnnaturalRun, player: FishController, y: float) -> void:
	var stats := run.stats_of(player)
	var health := run.health_of(player)
	# The hero card: what happened, the name, then level, hp, pearls and time.
	UITheme.draw_box(_c, _r(PAD, y, _w - PAD * 2.0, 124), Color(UITheme.DEEP, 0.7), 12.0 * _u, RIM, 1.0)
	var status := ("STAGE COMPLETE" if run.stage_complete else "RUN OVER") if run.is_over else "RUN SO FAR"
	_text(_r(PAD + 20.0, y + 10.0, _w - PAD * 2.0 - 40.0, 22), "%s  ·  %s" % [FishCharacter.display_name(player.character).to_upper(), status], 14, LABEL,
			HORIZONTAL_ALIGNMENT_LEFT, 600, 0.12)
	_text(_r(PAD + 20.0, y + 30.0, _w - PAD * 2.0 - 40.0, 52), _name_of(player, page), 44, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 700)
	var x := PAD + 20.0
	var line := y + 86.0
	x = _pair(x, line, "Lv", str(run.levels.level), UnnaturalHud.LEVEL_COLOR)
	if health:
		HudIcons.draw_heart(_c, _p(x + 9.0, line + 13.0), 22.0 * _u, UnnaturalHud.HP_COLOR)
		x = _pair(x + 20.0, line, "", "%d / %d" % [ceili(health.hp), roundi(health.max_hp)], Color.WHITE)
	HudIcons.draw_pearl(_c, _p(x + 10.0, line + 13.0), 22.0 * _u)
	x = _pair(x + 22.0, line, "", UnnaturalHud.thousands(run.purse_of(player)), Color.WHITE)
	_pair(x, line, "Time", UnnaturalHud._time_text(run.elapsed), Color.WHITE)
	y += 124.0 + 18.0
	# Weapons and tomes, side by side.
	var loadout := run.loadout_of(player)
	var attack := run.attack_of(player)
	var kind := attack.kind if attack else FishAttack.Kind.BITE
	var column := (_w - PAD * 2.0 - 16.0) * 0.5
	_heading(PAD, y, "WEAPONS", "%d/%d" % [loadout.weapons.size(), run.settings.weapon_slots])
	_heading(PAD + column + 16.0, y, "TOMES", "%d/%d" % [loadout.tomes.size(), run.settings.tome_slots])
	var rows := maxi(maxi(loadout.weapons.size(), loadout.tomes.size()), 1)
	for n in loadout.weapons.size():
		var id := loadout.weapons[n]
		var tint := UITheme.rarity(Rarity.Tier.BOSS) if id in Weapons.BOSS_ONLY else UnnaturalHud.LEVEL_COLOR
		_loadout_row(PAD, y + 22.0 + n * 46.0, column, HexBadge.Shape.DIAMOND, Weapons.glyph(id, kind), Weapons.title(id, kind), loadout.level(id), tint)
	for n in loadout.tomes.size():
		var id := loadout.tomes[n]
		_loadout_row(PAD + column + 16.0, y + 22.0 + n * 46.0, column, HexBadge.Shape.SQUARE, Tomes.glyph(id), Tomes.title(id),
				loadout.tome_level(id), Tomes.color(id))
	y += 22.0 + rows * 46.0 + 18.0
	# Stats, two columns.
	_heading(PAD, y, "STATS", "")
	var list := _stats(run, player)
	var half := (_w - PAD * 2.0 - 28.0) * 0.5
	for n in list.size():
		var entry: Array = list[n]
		var sx := PAD + (n % 2) * (half + 28.0)
		var sy := y + 22.0 + (n / 2) * 32.0
		var signature: bool = entry[3]
		var tint: Color = UnnaturalHud.LEVEL_COLOR if signature else entry[4]
		HexBadge.draw_glyph(_c, entry[0], _p(sx + 10.0, sy + 15.0), 18.0 * _u, tint, 2.0)
		_text(_r(sx + 28.0, sy, half - 100.0, 30), entry[1] + ("  ·  Signature" if signature else ""), 15,
				UnnaturalHud.LEVEL_COLOR if signature else UITheme.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, 600)
		_text(_r(sx + half - 72.0, sy, 72, 30), entry[2], 17, UnnaturalHud.LEVEL_COLOR if signature else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 600)
		_c.draw_line(_p(sx, sy + 31.0), _p(sx + half, sy + 31.0), Color(RIM, 0.08), 1.0)
	if list.is_empty():
		_text(_r(PAD, y + 22.0, 300, 30), "None yet", 15, MUTED, HORIZONTAL_ALIGNMENT_LEFT, 600)
	y += 22.0 + maxf(ceili(list.size() / 2.0), 1.0) * 32.0 + 18.0
	_draw_damage(stats.by_source, y)


## Each damage source's bar, biggest first, with its total and share.
func _draw_damage(by: Dictionary, y: float) -> void:
	var rows := []
	var total := 0.0
	for source: String in by:
		var amount := float(by[source])
		if amount > 0.0:
			rows.append([source, amount])
			total += amount
	if rows.is_empty():
		return
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var most: float = rows[0][1]
	_heading(PAD, y, "DAMAGE CONTRIBUTION", "")
	_text(_r(_w - PAD - 200.0, y, 200, 20), "Total %s" % UnnaturalHud.compact(total), 15, UITheme.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT, 600)
	y += 24.0
	var kinds := {}
	var name_width := 150.0
	var bar_left := PAD + 22.0 + 10.0 + name_width + 10.0
	var bar_width := _w - PAD - 60.0 - 40.0 - 20.0 - bar_left
	for n in mini(rows.size(), MAX_DAMAGE_ROWS):
		var source: String = rows[n][0]
		var amount: float = rows[n][1]
		var look := source_look(source)
		kinds[look[2]] = look[1]
		var ry := y + n * 27.0
		HexBadge.draw_glyph(_c, look[0], _p(PAD + 10.0, ry + 13.5), 18.0 * _u, look[1], 2.0)
		_text(_r(PAD + 32.0, ry, name_width, 27), UnnaturalHud.source_title(source), 15, UITheme.INK, HORIZONTAL_ALIGNMENT_LEFT, 600)
		var track := _r(bar_left, ry + 8.5, bar_width, 10)
		UITheme.draw_box(_c, track, Color(RIM, 0.08), 5.0 * _u)
		var share := maxf(amount / maxf(most, 1.0), 0.015)
		UITheme.draw_box(_c, Rect2(track.position, Vector2(maxf(track.size.x * share, track.size.y), track.size.y)), look[1], 5.0 * _u)
		_text(_r(bar_left + bar_width + 10.0, ry, 60, 27), UnnaturalHud.compact(amount), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 600)
		_text(_r(_w - PAD - 40.0, ry, 40, 27), "%d%%" % roundi(amount / total * 100.0), 16, LABEL, HORIZONTAL_ALIGNMENT_RIGHT, 600)
	y += mini(rows.size(), MAX_DAMAGE_ROWS) * 27.0 + 8.0
	# What the bar colours mean (only those showing).
	var x := PAD
	var font := UITheme.condensed(600)
	for kind_name: String in ["Weapon", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Boss", "Cursed", "Skill", "Battered"]:
		if not kinds.has(kind_name):
			continue
		UITheme.draw_box(_c, _r(x, y + 6.0, 10, 10), kinds[kind_name], 2.0 * _u)
		_text(_r(x + 16.0, y, 120, 22), kind_name, 13, LABEL, HORIZONTAL_ALIGNMENT_LEFT, 500)
		x += 16.0 + font.get_string_size(kind_name, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(roundi(13.0 * _u), 6)).x / maxf(_u, 0.01) + 18.0


## How a damage source shows: [glyph, colour, legend name]. A fish's attack
## is a weapon (blue), an item its rarity's colour, ramming coral, a skill pale.
static func source_look(source: String) -> Array:
	if source in FishAttack.sources():
		return ["attack_" + source, WEAPON_BAR, "Weapon"]
	if Powerup.ids().has(source):
		if Powerup.is_weapon(source):
			return [source, WEAPON_BAR, "Weapon"]
		var tier := Powerup.tier(source)
		return [source if HexBadge.has_glyph(source) else "sea_salt", UITheme.rarity(tier), Rarity.Tier.keys()[tier].capitalize()]
	if source == "battery":
		return ["tome_ram", BATTERED, "Battered"]
	return ["tome_fins", SKILL_BAR, "Skill"]


## The stats `player` has (not zero), signature first: [glyph, name, value
## text, signature, colour], at most MAX_STATS.
func _stats(run: UnnaturalRun, player: FishController) -> Array:
	var block := run.block_of(player)
	var signature := StatBlock.signature(player.character)
	var list := []
	for id: String in StatBlock.STATS:
		var value := StatBlock.shown(id, block.value(id))
		if absf(value) < 0.0001:
			continue
		var tome := _tome_of(id)
		var percent: bool = StatBlock.STATS[id][2]
		var amount := value * 100.0 if percent else value
		var text := ("+" if amount >= 0.0 else "") + (str(roundi(amount)) if absf(amount - roundf(amount)) < 0.05 else "%.1f" % amount) + ("%" if percent else "")
		var glyph: String = STAT_GLYPHS.get(id, "tome_" + tome if tome != "" else "sea_salt")
		var entry := [glyph, StatBlock.title(id), text, id == signature, STAT_ICON]
		if id == signature:
			list.push_front(entry)
		else:
			list.append(entry)
	return list.slice(0, MAX_STATS)


static func _tome_of(stat: String) -> String:
	for id: String in Tomes.TOMES:
		if stat in Tomes.stats(id):
			return id
	return ""


## The scoreboard's rows: a row per player (most kills first), yours lit.
func _draw_board(run: UnnaturalRun, players: Array[FishController], y: float) -> void:
	var widths := [54.0, 84.0, 96.0, 92.0, 76.0, 86.0]
	var right := _w - PAD
	var name_width := right - PAD
	for w: float in widths:
		name_width -= w + 10.0
	_text(_r(PAD, y, name_width, 34), "PLAYER", 14, LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600, 0.1)
	var x := PAD + name_width
	for n in widths.size():
		x += 10.0
		_text(_r(x, y, widths[n], 34), SCOREBOARD_HEADINGS[n], 14, LABEL, HORIZONTAL_ALIGNMENT_RIGHT, 600, 0.1)
		x += widths[n]
	_c.draw_line(_p(PAD, y + 34.0), _p(right, y + 34.0), RIM, 1.0)
	y += 34.0
	var order := range(players.size())
	order.sort_custom(func(a: int, b: int) -> bool: return run.stats_of(players[a]).kills > run.stats_of(players[b]).kills)
	for index: int in order:
		var player := players[index]
		var stats := run.stats_of(player)
		if player == hud.fish:
			_c.draw_rect(_r(PAD - 6.0, y, right - PAD + 12.0, 52), ROW)
		_diamond(_p(PAD + 8.0, y + 26.0), 7.0, _color_of(player))
		_text(_r(PAD + 22.0, y, name_width - 22.0, 52), _name_of(player, index), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 700)
		var cells := [str(run.levels.level), UnnaturalHud.compact(stats.kills), UnnaturalHud.compact(stats.damage),
				UnnaturalHud.thousands(stats.battered), UnnaturalHud.thousands(stats.pearls), str(roundi(stats.top_speed * 3.6))]
		x = PAD + name_width
		for n in widths.size():
			x += 10.0
			_text(_r(x, y, widths[n], 52), cells[n], 20, UnnaturalHud.LEVEL_COLOR if n == 0 else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 700)
			x += widths[n]
		_c.draw_line(_p(PAD, y + 52.0), _p(right, y + 52.0), Color(RIM, 0.08), 1.0)
		y += 52.0
	var footer := "TIME  %s    ·    LEVEL  %d" % [UnnaturalHud._time_text(run.elapsed), run.levels.level]
	if run.stage > 1 or run.settings.stages_in_run() != 1:
		footer += "    ·    STAGE  %d%s" % [run.stage, "" if run.settings.stages_in_run() <= 0 else " / %d" % run.settings.stages_in_run()]
	if run.is_over:
		footer += "    ·    R  TRY AGAIN"
	_text(_r(PAD, y + 12.0, _w - PAD * 2.0, 24), footer, 14, LABEL, HORIZONTAL_ALIGNMENT_CENTER, 600, 0.08)


func _heading(x: float, y: float, title: String, count: String) -> void:
	var font := UITheme.caps(maxi(roundi(14.0 * _u), 6), 600, 0.12)
	_text(_r(x, y, 300, 20), title, 14, LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600, 0.12)
	if count != "":
		var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(roundi(14.0 * _u), 6)).x / maxf(_u, 0.001)
		_text(_r(x + width + 8.0, y, 60, 20), count, 14, UITheme.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, 600)


func _loadout_row(x: float, y: float, width: float, shape: HexBadge.Shape, glyph: String, title: String, level: int, tint: Color) -> void:
	UITheme.draw_box(_c, _r(x, y, width, 40), ROW, 8.0 * _u, Color(RIM, 0.12), 1.0)
	var box := 30.0 if shape == HexBadge.Shape.DIAMOND else 36.0
	UnnaturalHud.draw_slot(_c, shape, _p(x + 22.0, y + 20.0), box * _u, glyph, tint, _u)
	_text(_r(x + 44.0, y, width - 104.0, 40), title, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 600)
	_text(_r(x + width - 60.0, y, 50, 40), "Lv %d" % level, 16, tint.lerp(Color.WHITE, 0.2), HORIZONTAL_ALIGNMENT_RIGHT, 600)


## A label then a value on the hero card's line; returns the x after them.
func _pair(x: float, y: float, label: String, value: String, color: Color) -> float:
	var font := UITheme.condensed(600)
	if label != "":
		_text(_r(x, y, 60, 26), label, 20, LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600)
		x += font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 6.0
	_text(_r(x, y, 140, 26), value, 20, color, HORIZONTAL_ALIGNMENT_LEFT, 600)
	return x + font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 20.0


func _diamond(centre: Vector2, half: float, color: Color) -> void:
	var h := half * _u
	_c.draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -h), centre + Vector2(h, 0), centre + Vector2(0, h), centre + Vector2(-h, 0)]), color)


func _name_of(player: FishController, index: int) -> String:
	return player.display_name if player.display_name else "Player %d" % (index + 1)


static func _color_of(player: FishController) -> Color:
	var color := player.body_color()
	color.a = 1.0
	return color


## A rect / point in design px, placed in the view being drawn.
func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(_o + Vector2(x, y) * _u, Vector2(w, h) * _u)


func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _u


## Text in Barlow Condensed (`spacing` > 0: letter-spaced caps) at `px` design px.
func _text(rect: Rect2, value: String, px: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, weight := 600, spacing := 0.0) -> void:
	var size_px := maxi(roundi(px * _u), 6)
	var font := UITheme.caps(size_px, 700 if weight >= 700 else 600, spacing) if spacing > 0.0 else UITheme.condensed(700 if weight >= 700 else 600)
	UITheme.draw_text(_c, rect, value, font, size_px, color, align)


## One part of the results (the scoreboard or the side panel): RunSummary
## lays it out and draws it.
class View extends Control:
	var summary: RunSummary
	## Design px to a screen px.
	var u := 1.0

	func _draw() -> void:
		summary.paint(self)
