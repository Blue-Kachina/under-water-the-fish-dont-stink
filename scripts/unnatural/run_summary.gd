class_name RunSummary
extends Control
## Unnatural's run summary (the HUD redesign, 2026-10-25), held up on
## show_scoreboard and up by itself once the run's over. One panel, two pages:
## - SUMMARY: one player's run, their name the title (the fish's class and
##   how the run went over it); their level, hp, pearls and time; their
##   weapons and tomes with levels; their stats (the signature in gold); and
##   their damage contribution, a bar for each source (biggest first; weapons
##   gold, items in their rarity's colour, ramming grey), k and M as it grows;
## - SCOREBOARD: everyone's kills, damage, battered fish, pearls and top speed.
## In co-op, a chip for each player picks whose summary shows. Flicking the
## right stick (or IJKL) left and right steps through each player's summary,
## then the scoreboard. It opens on your own summary.
## Laid out at the design's 1080p size (`_u` design px to a screen px) and
## shrunk to fit the view.

## The panel's width and its padding (design px).
const WIDTH := 712.0
const PAD := 20.0
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
## The page showing: a player's index in run.players for their summary, or
## -1 for the scoreboard.
var page := 0
var _input: PlayerInput
var _flick := 0
## This frame's layout: the panel's top-left (screen px) and design px per screen px.
var _o := Vector2.ZERO
var _u := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows it, on `input`'s player's own summary.
func open(input: PlayerInput) -> void:
	_input = input
	_flick = 0
	page = maxi(_players().find(hud.fish), 0)
	visible = true
	queue_redraw()


## The player whose summary shows (null on the scoreboard).
func shown_player() -> FishController:
	var players := _players()
	return players[page] if page >= 0 and page < players.size() else null


## Steps to the next page (`step` 1) or the one before (-1): each player's
## summary, then the scoreboard.
func flip(step: int) -> void:
	var count := _players().size() + 1
	var at := page if page >= 0 else count - 1
	at = posmod(at + step, count)
	page = -1 if at == count - 1 else at


func _players() -> Array[FishController]:
	var list: Array[FishController] = []
	if hud and is_instance_valid(hud.run):
		for player in hud.run.players:
			if is_instance_valid(player):
				list.append(player)
	return list


func _process(_delta: float) -> void:
	if not visible:
		return
	var reader := _input if _input else PlayerInput.everyone()
	var stick := reader.vector("camera_left", "camera_right", "camera_up", "camera_down").x
	var step := 1 if stick > 0.6 else (-1 if stick < -0.6 else 0)
	if step != 0 and step != _flick:
		flip(step)
	_flick = step
	if page >= _players().size():
		page = maxi(_players().find(hud.fish), 0)
	queue_redraw()


func _draw() -> void:
	var run := hud.run if hud else null
	if not is_instance_valid(run):
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.02, 0.04, 0.45))
	var players := _players()
	var player := shown_player()
	var height := _height(run, player, players.size())
	_u = minf(minf(size.y / 1080.0, (size.x - 24.0) / WIDTH), (size.y - 24.0) / height)
	_o = ((size - Vector2(WIDTH, height) * _u) * 0.5).round()
	UITheme.draw_box(self, _r(0, 0, WIDTH, height), Color(UITheme.GROUND, 0.94), 16.0 * _u, Color(RIM, 0.2), 1.0)
	_draw_tabs()
	var y := 54.0
	if players.size() > 1:
		y = _draw_chips(players, y + 14.0) + 4.0
	if player:
		_draw_summary(run, player, y + 16.0)
	else:
		_draw_board(run, players, y + 10.0)


## The panel's height (design px) for what shows.
func _height(run: UnnaturalRun, player: FishController, count: int) -> float:
	var height := 54.0 + (54.0 if count > 1 else 0.0) + 16.0
	if player == null:
		return height + 34.0 + 52.0 * count + 44.0
	var loadout := run.loadout_of(player)
	var slots := maxi(maxi(loadout.weapons.size(), loadout.tomes.size()), 1)
	height += 124.0 + 18.0 + 22.0 + slots * 46.0 + 18.0
	height += 22.0 + ceili(_stats(run, player).size() / 2.0) * 32.0 + 18.0
	var sources := mini(run.stats_of(player).by_source.size(), MAX_DAMAGE_ROWS)
	if sources > 0:
		height += 24.0 + sources * 27.0 + 30.0
	return height + PAD


func _draw_tabs() -> void:
	var half := WIDTH * 0.5
	for n in 2:
		var on := (page >= 0) == (n == 0)
		var rect := _r(n * half, 0, half, 54)
		if on:
			draw_rect(rect, Color(TAB, 0.08))
			draw_rect(_r(n * half, 51, half, 3), TAB)
		_text(rect, "SUMMARY" if n == 0 else "SCOREBOARD", 20, Color.WHITE if on else MUTED, HORIZONTAL_ALIGNMENT_CENTER, 700, 0.12)
	# Chevrons at the ends: flick to turn the page.
	for side: float in [-1.0, 1.0]:
		var x := 16.0 if side < 0.0 else WIDTH - 16.0
		var tip := _p(x - side * 4.0, 27)
		draw_colored_polygon(PackedVector2Array([tip, _p(x + side * 3.0, 21), _p(x + side * 3.0, 33)]), Color(MUTED, 0.7))
	draw_line(_p(0, 54), _p(WIDTH, 54), RIM, 1.0)


## A chip for each player (their colour, their name), the one showing lit.
## Returns the row's bottom.
func _draw_chips(players: Array[FishController], y: float) -> float:
	var x := PAD
	var font := UITheme.condensed(600)
	for n in players.size():
		var player := players[n]
		var on := n == page
		var name_text := _name_of(player, n)
		var width := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 46.0
		var color := _color_of(player)
		UITheme.draw_box(self, _r(x, y, width, 36), Color(0.59, 0.84, 1.0, 0.1 if on else 0.0), 18.0 * _u,
				color if on else Color(RIM, 0.18), 1.0)
		_diamond(_p(x + 20.0, y + 18.0), 7.0, color)
		_text(_r(x + 32.0, y, width - 36.0, 36), name_text, 17, Color.WHITE if on else LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600)
		x += width + 8.0
	return y + 36.0


func _draw_summary(run: UnnaturalRun, player: FishController, y: float) -> void:
	var stats := run.stats_of(player)
	var health := run.health_of(player)
	# The hero card: what happened, the name, then level, hp, pearls and time.
	UITheme.draw_box(self, _r(PAD, y, WIDTH - PAD * 2.0, 124), Color(UITheme.DEEP, 0.7), 12.0 * _u, RIM, 1.0)
	var status := ("STAGE COMPLETE" if run.stage_complete else "RUN OVER") if run.is_over else "RUN SO FAR"
	_text(_r(PAD + 20.0, y + 10.0, 500, 22), "%s  ·  %s" % [FishCharacter.display_name(player.character).to_upper(), status], 14, LABEL,
			HORIZONTAL_ALIGNMENT_LEFT, 600, 0.12)
	_text(_r(PAD + 20.0, y + 30.0, WIDTH - PAD * 2.0 - 40.0, 52), _name_of(player, page), 44, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 700)
	var x := PAD + 20.0
	var line := y + 86.0
	x = _pair(x, line, "Lv", str(run.levels.level), UnnaturalHud.LEVEL_COLOR)
	if health:
		HudIcons.draw_heart(self, _p(x + 9.0, line + 13.0), 22.0 * _u, UnnaturalHud.HP_COLOR)
		x = _pair(x + 20.0, line, "", "%d / %d" % [ceili(health.hp), roundi(health.max_hp)], Color.WHITE)
	HudIcons.draw_pearl(self, _p(x + 10.0, line + 13.0), 22.0 * _u)
	x = _pair(x + 22.0, line, "", UnnaturalHud.thousands(run.purse_of(player)), Color.WHITE)
	_pair(x, line, "Time", UnnaturalHud._time_text(run.elapsed), Color.WHITE)
	y += 124.0 + 18.0
	# Weapons and tomes, side by side.
	var loadout := run.loadout_of(player)
	var attack := run.attack_of(player)
	var kind := attack.kind if attack else FishAttack.Kind.BITE
	var column := (WIDTH - PAD * 2.0 - 16.0) * 0.5
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
	var half := (WIDTH - PAD * 2.0 - 28.0) * 0.5
	for n in list.size():
		var entry: Array = list[n]
		var sx := PAD + (n % 2) * (half + 28.0)
		var sy := y + 22.0 + (n / 2) * 32.0
		var signature: bool = entry[3]
		var tint: Color = UnnaturalHud.LEVEL_COLOR if signature else entry[4]
		HexBadge.draw_glyph(self, entry[0], _p(sx + 10.0, sy + 15.0), 18.0 * _u, tint, 2.0)
		_text(_r(sx + 28.0, sy, half - 110.0, 30), entry[1] + ("  ·  Signature" if signature else ""), 15,
				UnnaturalHud.LEVEL_COLOR if signature else UITheme.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, 600)
		_text(_r(sx + half - 90.0, sy, 90, 30), entry[2], 17, UnnaturalHud.LEVEL_COLOR if signature else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 600)
		draw_line(_p(sx, sy + 31.0), _p(sx + half, sy + 31.0), Color(RIM, 0.08), 1.0)
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
	_text(_r(WIDTH - PAD - 200.0, y, 200, 20), "Total %s" % UnnaturalHud.compact(total), 15, UITheme.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT, 600)
	y += 24.0
	var kinds := {}
	var bar_left := PAD + 22.0 + 10.0 + 168.0 + 10.0
	var bar_width := WIDTH - PAD - 64.0 - 44.0 - 20.0 - bar_left
	for n in mini(rows.size(), MAX_DAMAGE_ROWS):
		var source: String = rows[n][0]
		var amount: float = rows[n][1]
		var look := source_look(source)
		kinds[look[2]] = look[1]
		var ry := y + n * 27.0
		HexBadge.draw_glyph(self, look[0], _p(PAD + 10.0, ry + 13.5), 18.0 * _u, look[1], 2.0)
		_text(_r(PAD + 32.0, ry, 168, 27), UnnaturalHud.source_title(source), 15, UITheme.INK, HORIZONTAL_ALIGNMENT_LEFT, 600)
		var track := _r(bar_left, ry + 8.5, bar_width, 10)
		UITheme.draw_box(self, track, Color(RIM, 0.08), 5.0 * _u)
		var share := maxf(amount / maxf(most, 1.0), 0.015)
		UITheme.draw_box(self, Rect2(track.position, Vector2(maxf(track.size.x * share, track.size.y), track.size.y)), look[1], 5.0 * _u)
		_text(_r(bar_left + bar_width + 10.0, ry, 64, 27), UnnaturalHud.compact(amount), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 600)
		_text(_r(WIDTH - PAD - 44.0, ry, 44, 27), "%d%%" % roundi(amount / total * 100.0), 16, LABEL, HORIZONTAL_ALIGNMENT_RIGHT, 600)
	y += mini(rows.size(), MAX_DAMAGE_ROWS) * 27.0 + 8.0
	# What the bar colours mean (only those showing).
	var x := PAD
	var font := UITheme.condensed(600)
	for kind_name: String in ["Weapon", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Boss", "Cursed", "Skill", "Battered"]:
		if not kinds.has(kind_name):
			continue
		UITheme.draw_box(self, _r(x, y + 6.0, 10, 10), kinds[kind_name], 2.0 * _u)
		_text(_r(x + 16.0, y, 120, 22), kind_name, 13, LABEL, HORIZONTAL_ALIGNMENT_LEFT, 500)
		x += 16.0 + font.get_string_size(kind_name, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(roundi(13.0 * _u), 6)).x / maxf(_u, 0.01) + 18.0


## How a damage source shows: [glyph, colour, legend name]. A fish's attack
## is a weapon (gold), an item its rarity's colour, ramming grey, a skill aqua.
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


## The scoreboard: a row per player (most kills first), the one showing lit.
func _draw_board(run: UnnaturalRun, players: Array[FishController], y: float) -> void:
	var widths := [54.0, 84.0, 96.0, 92.0, 76.0, 86.0]
	var right := WIDTH - PAD
	var name_width := right - PAD
	for w: float in widths:
		name_width -= w + 10.0
	_text(_r(PAD, y, name_width, 34), "PLAYER", 14, LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600, 0.1)
	var x := PAD + name_width
	for n in widths.size():
		x += 10.0
		_text(_r(x, y, widths[n], 34), SCOREBOARD_HEADINGS[n], 14, LABEL, HORIZONTAL_ALIGNMENT_RIGHT, 600, 0.1)
		x += widths[n]
	draw_line(_p(PAD, y + 34.0), _p(right, y + 34.0), RIM, 1.0)
	y += 34.0
	var order := range(players.size())
	order.sort_custom(func(a: int, b: int) -> bool: return run.stats_of(players[a]).kills > run.stats_of(players[b]).kills)
	for index: int in order:
		var player := players[index]
		var stats := run.stats_of(player)
		if player == hud.fish:
			draw_rect(_r(PAD - 6.0, y, right - PAD + 12.0, 52), ROW)
		_diamond(_p(PAD + 8.0, y + 26.0), 7.0, _color_of(player))
		_text(_r(PAD + 22.0, y, name_width - 22.0, 52), _name_of(player, index), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 700)
		var cells := [str(run.levels.level), UnnaturalHud.compact(stats.kills), UnnaturalHud.compact(stats.damage),
				UnnaturalHud.thousands(stats.battered), UnnaturalHud.thousands(stats.pearls), str(roundi(stats.top_speed * 3.6))]
		x = PAD + name_width
		for n in widths.size():
			x += 10.0
			_text(_r(x, y, widths[n], 52), cells[n], 20, UnnaturalHud.LEVEL_COLOR if n == 0 else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 700)
			x += widths[n]
		draw_line(_p(PAD, y + 52.0), _p(right, y + 52.0), Color(RIM, 0.08), 1.0)
		y += 52.0
	var footer := "TIME  %s    ·    LEVEL  %d" % [UnnaturalHud._time_text(run.elapsed), run.levels.level]
	if run.stage > 1 or run.settings.stages_in_run() != 1:
		footer += "    ·    STAGE  %d%s" % [run.stage, "" if run.settings.stages_in_run() <= 0 else " / %d" % run.settings.stages_in_run()]
	if run.is_over:
		footer += "    ·    R  TRY AGAIN"
	_text(_r(PAD, y + 12.0, WIDTH - PAD * 2.0, 24), footer, 14, LABEL, HORIZONTAL_ALIGNMENT_CENTER, 600, 0.08)


func _heading(x: float, y: float, title: String, count: String) -> void:
	var font := UITheme.caps(roundi(14.0 * _u), 600, 0.12)
	_text(_r(x, y, 300, 20), title, 14, LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600, 0.12)
	if count != "":
		var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(14.0 * _u)).x / _u
		_text(_r(x + width + 8.0, y, 60, 20), count, 14, UITheme.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, 600)


func _loadout_row(x: float, y: float, width: float, shape: HexBadge.Shape, glyph: String, title: String, level: int, tint: Color) -> void:
	UITheme.draw_box(self, _r(x, y, width, 40), ROW, 8.0 * _u, Color(RIM, 0.12), 1.0)
	var box := 30.0 if shape == HexBadge.Shape.DIAMOND else 36.0
	UnnaturalHud.draw_slot(self, shape, _p(x + 22.0, y + 20.0), box * _u, glyph, tint, _u)
	_text(_r(x + 44.0, y, width - 110.0, 40), title, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 600)
	_text(_r(x + width - 70.0, y, 58, 40), "Lv %d" % level, 16, tint.lerp(Color.WHITE, 0.2), HORIZONTAL_ALIGNMENT_RIGHT, 600)


## A label then a value on the hero card's line; returns the x after them.
func _pair(x: float, y: float, label: String, value: String, color: Color) -> float:
	var font := UITheme.condensed(600)
	if label != "":
		_text(_r(x, y, 60, 26), label, 20, LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600)
		x += font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 6.0
	_text(_r(x, y, 140, 26), value, 20, color, HORIZONTAL_ALIGNMENT_LEFT, 600)
	return x + font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 24.0


func _diamond(centre: Vector2, half: float, color: Color) -> void:
	var h := half * _u
	draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -h), centre + Vector2(h, 0), centre + Vector2(0, h), centre + Vector2(-h, 0)]), color)


func _name_of(player: FishController, index: int) -> String:
	return player.display_name if player.display_name else "Player %d" % (index + 1)


static func _color_of(player: FishController) -> Color:
	var color := player.body_color()
	color.a = 1.0
	return color


## A rect / point in design px, placed on the screen.
func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(_o + Vector2(x, y) * _u, Vector2(w, h) * _u)


func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _u


## Text in Barlow Condensed (`spacing` > 0: letter-spaced caps) at `px` design px.
func _text(rect: Rect2, value: String, px: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, weight := 600, spacing := 0.0) -> void:
	var size_px := maxi(roundi(px * _u), 6)
	var font := UITheme.caps(size_px, 700 if weight >= 700 else 600, spacing) if spacing > 0.0 else UITheme.condensed(700 if weight >= 700 else 600)
	UITheme.draw_text(self, rect, value, font, size_px, color, align)
