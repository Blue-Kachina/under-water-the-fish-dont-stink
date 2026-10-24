class_name LevelUpCards
extends Control
## Unnatural's level-up cards (planning_unnatural.md §6, §7, §11, and the
## Playability pass), drawn as Card Type Variations E (Shapes + Pips +
## Materials): a row of cards rimmed in their rarity's colour (Rarity,
## UITheme.RARITY), each in its kind's material round its kind's medallion
## (HexBadge.Shape) and glyph. A level's (CardDeck): a weapon's upgrade (the level it
## reaches, the facets it raises, a milestone if it reaches one), a new
## weapon, a tome (what it gives), or a fallback; level pips along the
## bottom. A chest's: its powerups, which stack each would be, stacks as pips.
## A boss weapon with no slot free: a card per weapon to swap, and one to keep
## yours. Picked with the left stick, A/D
## or the arrow keys and A / Enter / Space, the number keys 1-3, or the mouse.
## Runs while the game's paused (solo, the cards pause it). For the first
## ARM_TIME it ignores the pick button, so a held or mashed A doesn't choose
## blind. `picked` says which.

signal picked(index: int)
## B (or Backspace) on a chest's cards before the first pick: put the chest back.
signal cancelled
## The choice tools (P4): RB (Shift) rerolls, LB (Ctrl) skips, Y banishes the
## focused card, each while its count below is above 0.
signal rerolled
signal skipped
signal banished(index: int)

## At the 1280×720 design's scale (scaled to the view as they draw).
const CARD_SIZE := Vector2(290.0, 410.0)
const FOCUSED_SIZE := Vector2(320.0, 450.0)
const GAP := 28.0
const PIPS := 5
## More level pips than this (a high level cap) and the card shows one bar instead.
const MAX_PIPS := 20
const ARM_TIME := 0.4

## What a card is, which says its material and medallion (Card Type Variations, E).
enum Look { WEAPON, TOME, POWERUP, BONUS }
## A weapon's steel plate.
const STEEL := Color(22 / 255.0, 35 / 255.0, 45 / 255.0)  # #16232D
const STEEL_DARK := Color(12 / 255.0, 22 / 255.0, 29 / 255.0)  # #0C161D bevel, empty pips
const STEEL_LINE := Color(44 / 255.0, 62 / 255.0, 74 / 255.0)  # #2C3E4A the rule above its lines
const RIVET := Color(74 / 255.0, 93 / 255.0, 106 / 255.0)  # #4A5D6A
const RIVET_SHINE := Color(143 / 255.0, 163 / 255.0, 176 / 255.0)  # #8FA3B0
## The kind label on a weapon's and a powerup's card.
const LABEL := Color(143 / 255.0, 179 / 255.0, 194 / 255.0)  # #8FB3C2
## A tome's leather.
const LEATHER := Color(42 / 255.0, 33 / 255.0, 25 / 255.0)  # #2A2119
const LEATHER_DARK := Color(18 / 255.0, 13 / 255.0, 9 / 255.0)  # #120D09 shadow, empty pips
const LEATHER_RULE := Color(94 / 255.0, 78 / 255.0, 58 / 255.0)  # #5E4E3A
const PARCHMENT := Color(239 / 255.0, 228 / 255.0, 204 / 255.0)  # #EFE4CC its text
const GILT := Color(196 / 255.0, 179 / 255.0, 147 / 255.0)  # #C4B393 its labels
const TOME_INK := Color(26 / 255.0, 20 / 255.0, 15 / 255.0)  # #1A140F its glyph

## Each card: a level's (CardDeck), {"powerup", "stacks", "tier"} (a chest's),
## or a swap's {"kind": "swap"/"keep", "weapon", ...} (UnnaturalRun's offer).
var cards: Array = []
## The fish's attack's kind (its weapon card's name and glyph), and the level caps.
var attack_kind := FishAttack.Kind.BITE
var max_levels := Vector2i(10, 10)
## The title ("LEVEL 4", "TREASURE!") and the line under it.
var heading := ""
var line := ""
## Whose controls pick (null: every controller and the keyboard).
var input: PlayerInput
## The game stays paused while they're up (solo): closing the pause menu
## over them doesn't let it run.
var pauses := false
## Whether B puts a chest back (set before open(): a chest's first pick only).
var cancelable := false
## How many rerolls, skips and banishes the player can use on these cards now
## (0: not offered; set before open()).
var rerolls := 0
var skips := 0
var banishes := 0
var selected := 0

var _age := 0.0
var _stick_was := 0
var _hints := ControllerHints.new()
## The card being drawn's fade (_a()).
var _fade := 1.0
static var _italic_font: FontVariation


## A card's corner radius, by its look.
static func _corner(look: Look) -> float:
	match look:
		Look.WEAPON:
			return 10.0
		Look.TOME:
			return 14.0
	return 30.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_hints.hints = [["◀ ▶", "Choose"], ["A", "Take it"]]
	_hints.visible = false
	add_child(_hints)


## Shows `offer`, under `title` and `subtitle`.
func open(offer: Array, title: String, subtitle: String, player_input: PlayerInput) -> void:
	cards = offer
	heading = title
	line = subtitle
	input = player_input
	selected = 0
	_age = 0.0
	_stick_was = 0
	_hints.hints = _hint_list()
	visible = true
	queue_redraw()


## The controls along the bottom: choose, take, and the choice tools there are.
func _hint_list() -> Array:
	var list: Array = [["◀ ▶", "Choose"], ["A", "Take it"]]
	if rerolls > 0:
		list.append(["RB", "Reroll (%d)" % rerolls])
	if skips > 0:
		list.append(["LB", "Skip (%d)" % skips])
	if banishes > 0:
		list.append(["Y", "Banish (%d)" % banishes])
	if cancelable:
		list.append(["B", "Put it back"])
	return list


func close() -> void:
	visible = false
	cards = []


func is_open() -> bool:
	return visible and not cards.is_empty()


func _process(delta: float) -> void:
	if not is_open():
		return
	_age += delta
	if pauses and not get_tree().paused:
		get_tree().paused = true
	var reader := input if input else PlayerInput.everyone()
	var stick := reader.vector("stick_left", "stick_right", "stick_up", "stick_down").x
	var step := 0
	if stick > 0.6:
		step = 1
	elif stick < -0.6:
		step = -1
	if step != 0 and step != _stick_was:
		selected = posmod(selected + step, cards.size())
	_stick_was = step
	if _age >= ARM_TIME:
		for n in mini(cards.size(), 3):
			if Input.is_key_pressed(KEY_1 + n):
				_pick(n)
				return
		if reader.just_pressed("ui_accept") or reader.just_pressed("jump"):
			_pick(selected)
			return
		if rerolls > 0 and reader.just_pressed("boost"):
			rerolled.emit()
			return
		if skips > 0 and reader.just_pressed("powerslide"):
			close()
			skipped.emit()
			return
		if banishes > 0 and reader.just_pressed("ball_cam"):
			banished.emit(selected)
			return
		# B puts a chest back (Esc is the pause menu's).
		if cancelable and ((reader.just_pressed("ui_cancel") and not Input.is_key_pressed(KEY_ESCAPE)) or Input.is_action_just_pressed("ui_text_backspace")):
			close()
			cancelled.emit()
			return
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventMouseMotion:
		var over := _card_at((event as InputEventMouseMotion).position)
		if over >= 0:
			selected = over
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and _age >= ARM_TIME:
		var at := _card_at((event as InputEventMouseButton).position)
		if at >= 0:
			_pick(at)


func _pick(index: int) -> void:
	if index < 0 or index >= cards.size():
		return
	close()
	picked.emit(index)


## How much bigger than the 1280×720 design the cards draw here: the view's
## scale, shrunk if the row of cards wouldn't fit across (a split-screen view).
func _scale() -> float:
	var k := minf(size.x / UITheme.REF_SIZE.x, size.y / UITheme.REF_SIZE.y)
	var row := cards.size() * CARD_SIZE.x + (cards.size() - 1) * GAP + (FOCUSED_SIZE.x - CARD_SIZE.x)
	k = minf(k, size.x * 0.96 / maxf(row, 1.0))
	return maxf(k, 0.2)


## Where the cards' row is centred (the heading sits above it).
func _row_centre() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5 + 34.0 * _scale())


func _card_rect(index: int) -> Rect2:
	var k := _scale()
	var pitch := (CARD_SIZE.x + GAP) * k
	var centre := _row_centre() + Vector2((index - (cards.size() - 1) * 0.5) * pitch, 0.0)
	var card_size := (FOCUSED_SIZE if index == selected else CARD_SIZE) * k
	return Rect2(centre - card_size * 0.5, card_size)


func _card_at(point: Vector2) -> int:
	for i in cards.size():
		if _card_rect(i).has_point(point):
			return i
	return -1


func _draw() -> void:
	if not is_open():
		return
	var k := _scale()
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.DIM)
	var top := _row_centre().y - FOCUSED_SIZE.y * 0.5 * k
	var chest: bool = not cards.is_empty() and cards[0].has("powerup")
	var swap: bool = not cards.is_empty() and cards[0].get("kind", "") in ["swap", "keep"]
	var cursed := heading.begins_with("CURSED")
	var label_px := roundi(16.0 * k)
	UITheme.draw_text(self, Rect2(0.0, top - 132.0 * k, size.x, 24.0 * k), heading.to_upper(), UITheme.caps(label_px, 700, 0.3), label_px,
			UITheme.rarity(Rarity.Tier.CURSED) if cursed else UITheme.GOLD)
	var ask := "Swap a weapon?" if swap else ("Pick a powerup" if chest else "Pick an upgrade")
	UITheme.draw_text(self, Rect2(0.0, top - 106.0 * k, size.x, 50.0 * k), ask, UITheme.display(600), roundi(40.0 * k), UITheme.INK)
	if line:
		var line_px := roundi(14.0 * k)
		UITheme.draw_text(self, Rect2(0.0, top - 54.0 * k, size.x, 22.0 * k), line.to_upper(), UITheme.caps(line_px, 600, 0.18), line_px,
				UITheme.MUTED)
	for i in cards.size():
		if i != selected:
			_draw_card(i)
	if selected >= 0 and selected < cards.size():
		_draw_card(selected)  # on top
	_hints.s = k
	_hints.size = _hints.custom_minimum_size
	_hints.position = Vector2((size.x - _hints.size.x) * 0.5, top + FOCUSED_SIZE.y * k + 26.0 * k)
	_hints.visible = true


## What weapon `id` gains reaching `level`, if that's a milestone ("" if not).
func _milestone_line(id: String, level: int) -> String:
	var lines := Weapons.milestones(id, attack_kind)
	var settings := UnnaturalSettings.shared()
	for n in mini(lines.size(), 4):
		if level == settings.milestone_level(n + 1):
			return lines[n]
	return ""


## `lines` down from the top of `area`, wrapped: bulleted when there's more
## than one (or `bullets`). Returns the height they took.
func _draw_lines(area: Rect2, lines: PackedStringArray, font: Font, px: int, color: Color, bullets := false) -> float:
	var used := 0.0
	var bullet := bullets or lines.size() > 1
	for text in lines:
		var at := Rect2(area.position.x, area.position.y + used, area.size.x, maxf(area.size.y - used, px))
		var align := HORIZONTAL_ALIGNMENT_LEFT if bullet else HORIZONTAL_ALIGNMENT_CENTER
		used += UITheme.draw_wrapped(self, at, ("• " if bullet else "") + text, font, px, color, align) + (2.0 if bullet else 0.0)
	return used


## `color` at this card's fade (the cards not focused are dimmed).
func _a(color: Color) -> Color:
	return Color(color, color.a * _fade)


## One card (Card Type Variations, E: Shapes + Pips + Materials). Its kind
## says its material and its medallion's shape: a weapon's a riveted steel
## plate round a diamond, a tome's tooled leather round a square, a
## powerup's a glass bubble round a hexagon (a bonus's round a pearl). Along
## the top its kind and rarity; then the name, which level or stack, a
## weapon's description, what it does, and the level or stack pips.
func _draw_card(i: int) -> void:
	var card: Dictionary = cards[i]
	var chosen := i == selected
	var rect := _card_rect(i)
	var g := rect.size.x / CARD_SIZE.x  # this card's scale (k, or more when focused)
	var powerup: String = card.get("powerup", "")
	var tier: int = card.get("tier", Powerup.tier(powerup) if powerup else Rarity.Tier.COMMON)
	var rim := UITheme.rarity(tier)
	_fade = 1.0 if chosen else 0.86

	var look := Look.BONUS
	var glyph := ""
	var name_text := ""
	var stack_text := ""
	## A new weapon's description: a paragraph above its bullets.
	var intro := ""
	## What it does, one effect a line (bulleted when there's more than one),
	## and a curse's downsides likewise.
	var lines := PackedStringArray()
	var curses := PackedStringArray()
	var milestone := ""
	## Level pips: [held, this pick's, cap] (cap 0: none).
	var pips := Vector3i(0, 0, 0)
	## A bonus's amount, in its pearl.
	var amount := ""
	var kind: String = card.get("kind", "")
	if powerup:
		look = Look.WEAPON if Powerup.is_weapon(powerup) else Look.POWERUP
		glyph = powerup
		name_text = Powerup.title(powerup)
		var stacks: int = card.get("stacks", 1)
		stack_text = "NEW" if stacks <= 1 else "STACK %d → %d" % [stacks - 1, stacks]
		lines = Powerup.blurb_lines(powerup)
		curses = Powerup.curse_lines(powerup)
		pips = Vector3i(stacks - 1, 1, PIPS)
		if look == Look.WEAPON:
			stack_text = "BOSS WEAPON"
	elif kind in ["weapon", "new_weapon", "swap", "keep"]:
		look = Look.WEAPON
		var id: String = card.weapon
		glyph = Weapons.glyph(id, attack_kind)
		name_text = Weapons.title(id, attack_kind)
		var level: int = card.get("level", 1)
		match kind:
			"weapon":
				stack_text = "LV %d → %d" % [level - 1, level]
				lines = Weapons.describe_all(id, card.gains, attack_kind)
				milestone = _milestone_line(id, level)
				pips = Vector3i(level - 1, 1, max_levels.x)
			"new_weapon":
				stack_text = "NEW WEAPON"
				intro = " ".join(Powerup.blurb_lines(id))
				lines = Weapons.describe_all(id, card.get("gains", {}), attack_kind)
				pips = Vector3i(0, 1, max_levels.x)
			"swap":
				stack_text = "SWAP OUT  ·  LV %d" % level
				lines = PackedStringArray(["Drop it for %s." % Powerup.title(card.incoming)])
			"keep":
				name_text = "Keep yours"
				stack_text = "NO SWAP"
				lines = PackedStringArray(["Leave %s behind." % Powerup.title(id)])
	elif kind in ["tome", "new_tome"]:
		look = Look.TOME
		var id: String = card.tome
		glyph = Tomes.glyph(id)
		name_text = Tomes.title(id)
		var level: int = card.get("level", 1)
		stack_text = "NEW TOME" if kind == "new_tome" else "LV %d → %d" % [level - 1, level]
		lines = Tomes.describe(card.gives)
		pips = Vector3i(level - 1, 1, max_levels.y)
	elif kind == "fallback":
		var pearls: bool = card.what == "pearls"
		amount = ("+%d" % card.amount) if pearls else ("+%d%%" % roundi(card.amount * 100.0))
		name_text = "Pearl Purse" if pearls else "Second Wind"
		stack_text = "NOTHING LEFT TO LEARN"
		lines = PackedStringArray(["%d pearls to spend on chests." % card.amount if pearls else "Heals the whole team."])

	var radius := _corner(look) * g
	if chosen:
		UITheme.draw_box(self, Rect2(rect.position + Vector2(0.0, 12.0 * g), rect.size).grow(4.0 * g), Color(0, 0, 0, 0.4), radius + 4.0 * g)
		var pulse := 0.12 + 0.02 * sin(_age * 4.0)
		UITheme.draw_box(self, rect.grow(6.0 * g), Color(rim, pulse), radius + 6.0 * g)
	var rim_width := (3.0 if chosen else 2.0) * g
	var tier_name: String = Rarity.NAMES[tier]
	var medal := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 112.0 * g)
	var text_color := UITheme.INK_SOFT
	var text_rect := Rect2(rect.position.x + 30.0 * g, rect.position.y + 256.0 * g, rect.size.x - 60.0 * g, 100.0 * g)
	var pip_empty := UITheme.GROUND
	var pip_fresh := UITheme.INK
	match look:
		Look.WEAPON:
			_draw_plate(rect, g, rim, rim_width + 1.0 * g)
			_draw_header(rect, g, "WEAPON", tier_name, LABEL, rim, rim, true)
			HexBadge.draw_shape(self, HexBadge.Shape.DIAMOND, medal, 140.0 * g, _a(rim), rim, 0.0)
			HexBadge.draw_shape(self, HexBadge.Shape.DIAMOND, medal, 129.0 * g, _a(STEEL_DARK), rim, 0.0)
			HexBadge.draw_glyph(self, glyph, medal, 54.0 * g, _a(rim), 1.9)
			UITheme.draw_text(self, Rect2(rect.position.x + 14.0 * g, rect.position.y + 186.0 * g, rect.size.x - 28.0 * g, 36.0 * g),
					name_text.to_upper(), UITheme.caps(roundi(32.0 * g), 700, 0.06), roundi(32.0 * g), _a(UITheme.INK))
			_draw_stack_line(rect, g, 222.0, stack_text, rim.lightened(0.1))
			var rule_y := rect.position.y + 250.0 * g
			draw_line(Vector2(medal.x - 118.0 * g, rule_y), Vector2(medal.x + 118.0 * g, rule_y), _a(STEEL_LINE), maxf(1.0 * g, 1.0))
			text_rect = Rect2(rect.position.x + 27.0 * g, rect.position.y + 260.0 * g, rect.size.x - 54.0 * g, 100.0 * g)
			pip_empty = STEEL_DARK
		Look.TOME:
			_draw_leather(rect, g, rim, rim_width)
			_draw_header(rect, g, "TOME", tier_name, GILT, GILT, rim, false)
			var square := 144.0 * g
			HexBadge.draw_shape(self, HexBadge.Shape.SQUARE, medal + Vector2(3.0, 4.0) * g, square, _a(rim.lerp(LEATHER_DARK, 0.6)), rim, 0.0)
			HexBadge.draw_shape(self, HexBadge.Shape.SQUARE, medal, square, _a(rim), rim, 0.0)
			# A tooled border: dashes round the cover.
			var half := 46.0 * g
			var dash := _a(rim.lerp(LEATHER_DARK, 0.55))
			var corners := [medal + Vector2(-half, -half), medal + Vector2(half, -half), medal + Vector2(half, half), medal + Vector2(-half, half)]
			for n in 4:
				var from: Vector2 = corners[n]
				var to: Vector2 = corners[(n + 1) % 4]
				draw_dashed_line(from, to, dash, 2.0 * g, 5.0 * g, true, true)
			HexBadge.draw_glyph(self, glyph, medal, 50.0 * g, _a(TOME_INK), 1.9)
			UITheme.draw_text(self, Rect2(rect.position.x + 14.0 * g, rect.position.y + 188.0 * g, rect.size.x - 28.0 * g, 36.0 * g),
					name_text, _italic(), roundi(26.0 * g), _a(PARCHMENT))
			_draw_stack_line(rect, g, 222.0, stack_text, GILT)
			text_color = PARCHMENT
			pip_empty = LEATHER_DARK
			pip_fresh = PARCHMENT
		_:
			_draw_bubble(rect, g, rim, rim_width)
			_draw_header(rect, g, "BONUS" if look == Look.BONUS else "POWER-UP", tier_name, LABEL, rim, rim, false)
			_draw_glass_medal(HexBadge.Shape.CIRCLE if look == Look.BONUS else HexBadge.Shape.HEX, medal, 140.0 * g, rim)
			if look == Look.BONUS:
				UITheme.draw_text(self, Rect2(medal - Vector2(54.0, 26.0) * g, Vector2(108.0, 52.0) * g), amount, UITheme.display(700),
						roundi(34.0 * g), _a(UITheme.INK))
			else:
				HexBadge.draw_glyph(self, glyph, medal, 58.0 * g, _a(UITheme.INK), 1.8)
			UITheme.draw_text(self, Rect2(rect.position.x + 14.0 * g, rect.position.y + 188.0 * g, rect.size.x - 28.0 * g, 36.0 * g),
					name_text, UITheme.display(600), roundi(26.0 * g), _a(UITheme.INK))
			_draw_stack_line(rect, g, 222.0, stack_text, rim.lightened(0.1))

	# The description, then what it does.
	var count := lines.size() + (2 if intro else 0)
	var text_px := roundi((16.0 if count <= 3 else 14.0) * g)
	var used := 0.0
	if intro:
		used += UITheme.draw_wrapped(self, text_rect, intro, UITheme.body(400), text_px, _a(text_color)) + 6.0 * g
	var area := Rect2(text_rect.position + Vector2(0.0, used), text_rect.size - Vector2(0.0, used))
	if look == Look.TOME and not intro and lines.size() == 1 and _fits(lines[0], UITheme.body(600), roundi(17.0 * g), text_rect.size.x - 40.0 * g):
		used += _draw_ruled(area, lines[0], g)
	else:
		used += _draw_lines(area, lines, UITheme.body(400), text_px, _a(text_color), not intro.is_empty())
	if milestone:
		var mile_px := roundi(15.0 * g)
		UITheme.draw_wrapped(self, Rect2(text_rect.position.x, text_rect.position.y + used + 6.0 * g, text_rect.size.x, 60.0 * g),
				"New: " + milestone, UITheme.body(600), mile_px, _a(UITheme.GOLD))
	if not curses.is_empty():
		_draw_curses(text_rect, used, curses, g)

	# Pips: held levels (or stacks) in the rarity's colour, this pick's in
	# white, the rest dark. Past MAX_PIPS (a high cap) one bar instead.
	var pip_y := rect.end.y - 34.0 * g
	if pips.z > MAX_PIPS:
		var bar := Rect2(rect.position.x + 30.0 * g, pip_y, rect.size.x - 60.0 * g, 6.0 * g)
		UITheme.draw_box(self, bar, _a(Color(pip_empty, 0.9)), 3.0 * g)
		var held := bar.size.x * pips.x / pips.z
		var this_pick := maxf(bar.size.x * pips.y / pips.z, 4.0 * g)
		UITheme.draw_box(self, Rect2(bar.position, Vector2(held + this_pick, bar.size.y)), _a(pip_fresh), 3.0 * g)
		if held > 0.0:
			UITheme.draw_box(self, Rect2(bar.position, Vector2(held, bar.size.y)), _a(rim), 3.0 * g)
	elif pips.z > 0:
		var pip := Vector2(minf(22.0, (rect.size.x / g - 60.0) / pips.z - 4.0), 6.0) * g
		var gap := 4.0 * g
		var left := rect.position.x + (rect.size.x - (pips.z * pip.x + (pips.z - 1) * gap)) * 0.5
		for n in pips.z:
			var color := Color(pip_empty, 0.9)
			if n < pips.x:
				color = rim
			elif n < pips.x + pips.y:
				color = pip_fresh
			UITheme.draw_box(self, Rect2(left + n * (pip.x + gap), pip_y, pip.x, pip.y), _a(color), 3.0 * g)


## The kind and rarity along the card's top ("WEAPON ◆ RARE"), `mark` the
## colour of the mark between (a diamond for a weapon, else a dot).
func _draw_header(rect: Rect2, g: float, label: String, tier_name: String, label_color: Color, mark: Color, rim: Color,
		diamond: bool) -> void:
	var px := roundi(13.0 * g)
	var font := UITheme.caps(px, 700, 0.24)
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 2.0
	var tier_width := font.get_string_size(tier_name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 2.0
	var dot := 4.0 * g
	var gap := 8.0 * g
	var x := rect.position.x + (rect.size.x - (label_width + dot + tier_width + gap * 2.0)) * 0.5
	var row := Rect2(x, rect.position.y + 16.0 * g, label_width, 16.0 * g)
	UITheme.draw_text(self, row, label, font, px, _a(label_color), HORIZONTAL_ALIGNMENT_LEFT)
	var at := Vector2(x + label_width + gap + dot * 0.5, row.get_center().y)
	if diamond:
		draw_colored_polygon(HexBadge.outline(HexBadge.Shape.DIAMOND, at, dot * 1.5), _a(mark))
	else:
		draw_circle(at, dot * 0.5, _a(mark), true, -1.0, true)
	UITheme.draw_text(self, Rect2(at.x + dot * 0.5 + gap, row.position.y, tier_width, row.size.y), tier_name, font, px, _a(rim),
			HORIZONTAL_ALIGNMENT_LEFT)


## The level or stack line under the name, `top` px down the card.
func _draw_stack_line(rect: Rect2, g: float, top: float, text: String, color: Color) -> void:
	var px := roundi(14.0 * g)
	UITheme.draw_text(self, Rect2(rect.position.x, rect.position.y + top * g, rect.size.x, 20.0 * g), text,
			UITheme.caps(px, 700, 0.2), px, _a(color))


## A weapon's card: a steel plate, brushed corner to corner, its rim in the
## rarity's colour, a dark bevel inside it, and a rivet in each corner.
func _draw_plate(rect: Rect2, g: float, rim: Color, rim_width: float) -> void:
	UITheme.draw_box(self, rect, _a(STEEL), _corner(Look.WEAPON) * g, _a(rim), rim_width)
	var inner := rect.grow(-8.0 * g)
	var step := 10.0 * sqrt(2.0) * g
	var shade := _a(Color(1, 1, 1, 0.035))
	var c := step
	while c < inner.size.x + inner.size.y:
		var x0 := maxf(0.0, c - inner.size.y)
		var x1 := minf(inner.size.x, c)
		draw_line(inner.position + Vector2(x0, c - x0), inner.position + Vector2(x1, c - x1), shade, 2.0 * g)
		c += step
	UITheme.draw_box(self, rect.grow(-rim_width), Color(0, 0, 0, 0), 7.0 * g, _a(STEEL_DARK), 5.0 * g)
	var inset := 16.5 * g
	for at: Vector2 in [rect.position + Vector2(inset, inset), Vector2(rect.end.x - inset, rect.position.y + inset),
			rect.end - Vector2(inset, inset), Vector2(rect.position.x + inset, rect.end.y - inset)]:
		draw_circle(at, 4.5 * g, _a(RIVET), true, -1.0, true)
		draw_arc(at, 3.4 * g, PI, PI * 1.5, 6, _a(RIVET_SHINE), maxf(1.2 * g, 1.0), true)


## A tome's card: tooled leather, finely lined, its rim in the rarity's
## colour and two stitched rules inside it.
func _draw_leather(rect: Rect2, g: float, rim: Color, rim_width: float) -> void:
	UITheme.draw_box(self, rect, _a(LEATHER), _corner(Look.TOME) * g, _a(rim), rim_width)
	var inner := rect.grow(-4.0 * g)
	var grain := _a(Color(PARCHMENT, 0.035))
	var y := inner.position.y + 6.0 * g
	while y < inner.end.y:
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), grain, maxf(1.0 * g, 1.0))
		y += 6.0 * g
	UITheme.draw_box(self, rect.grow(-7.0 * g), Color(0, 0, 0, 0), 9.0 * g, _a(rim.lerp(LEATHER, 0.5)), maxf(1.0 * g, 1.0))
	UITheme.draw_box(self, rect.grow(-11.0 * g), Color(0, 0, 0, 0), 6.0 * g, _a(rim.lerp(LEATHER, 0.75)), maxf(1.0 * g, 1.0))


## A powerup's card: a glass bubble lit from its top-left in the rarity's
## colour, a glare across the top and a few bubbles rising in it.
func _draw_bubble(rect: Rect2, g: float, rim: Color, rim_width: float) -> void:
	var radius := _corner(Look.POWERUP) * g
	var focus := rect.position + rect.size * Vector2(0.3, 0.18)
	_radial(HexBadge.rounded_rect(rect, radius, 8), focus, _a(rim.lerp(UITheme.CARD, 0.74)), _a(UITheme.CARD),
			0.72 * focus.distance_to(rect.end))
	var glare := PackedVector2Array()
	var centre := rect.position + Vector2(72.0, 45.0) * g
	for n in 17:
		var angle := lerpf(-PI * 0.86, -PI * 0.2, n / 16.0)
		glare.append(centre + (Vector2(cos(angle) * 60.0, sin(angle) * 35.0) * g).rotated(deg_to_rad(-18.0)))
	draw_polyline(glare, _a(Color(UITheme.INK, 0.28)), 3.0 * g, true)
	var foam := _a(Color(UITheme.INK, 0.3))
	for bubble: Vector3 in [Vector3(rect.size.x / g - 33.0, 127.0, 7.0), Vector3(rect.size.x / g - 43.5, 149.5, 3.5), Vector3(26.0, 318.0, 5.0)]:
		draw_arc(rect.position + Vector2(bubble.x, bubble.y) * g, bubble.z * g, 0.0, TAU, 20, foam, 1.5 * g, true)
	UITheme.draw_box(self, rect, Color(0, 0, 0, 0), radius, _a(rim), rim_width)


## A powerup's medallion: `shape` (`size` wide) rimmed in the rarity's
## colour, glass inside it lit from its top-left, and a glint.
func _draw_glass_medal(shape: HexBadge.Shape, centre: Vector2, size: float, rim: Color) -> void:
	HexBadge.draw_shape(self, shape, centre, size, _a(rim), rim, 0.0)
	var inner := size * 0.93
	var box := Vector2(0.8, 0.92) * inner if shape == HexBadge.Shape.HEX else Vector2(0.92, 0.92) * inner
	var focus := centre + box * Vector2(-0.15, -0.2)
	_radial(HexBadge.outline(shape, centre, inner), focus, _a(rim.lerp(UITheme.CARD, 0.62)), _a(rim.lerp(UITheme.CARD, 0.9)),
			0.7 * focus.distance_to(centre + box * 0.5))
	var glint := PackedVector2Array()
	var at := centre + box * Vector2(-0.16, -0.32)
	for n in 16:
		glint.append(at + (Vector2.from_angle(TAU * n / 16.0) * Vector2(0.1, 0.05) * inner).rotated(deg_to_rad(-25.0)))
	draw_colored_polygon(glint, _a(Color(UITheme.INK, 0.4)))


## `outline` (convex, round `focus`) filled `inner` at `focus` fading to
## `outer` at `reach` px out, flat past it.
func _radial(outline: PackedVector2Array, focus: Vector2, inner: Color, outer: Color, reach: float) -> void:
	var none := PackedVector2Array()
	for n in outline.size():
		var p: Vector2 = outline[n]
		var q: Vector2 = outline[(n + 1) % outline.size()]
		var p_mid := focus + (p - focus) * minf(reach / maxf(focus.distance_to(p), 0.001), 1.0)
		var q_mid := focus + (q - focus) * minf(reach / maxf(focus.distance_to(q), 0.001), 1.0)
		var p_color := inner.lerp(outer, minf(focus.distance_to(p_mid) / reach, 1.0))
		var q_color := inner.lerp(outer, minf(focus.distance_to(q_mid) / reach, 1.0))
		draw_primitive(PackedVector2Array([focus, p_mid, q_mid]), PackedColorArray([inner, p_color, q_color]), none)
		if p_mid != p or q_mid != q:
			draw_primitive(PackedVector2Array([p_mid, p, q, q_mid]), PackedColorArray([p_color, outer, outer, q_color]), none)


## Whether `text` fits on one line `width` wide.
func _fits(text: String, font: Font, px: int, width: float) -> bool:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width


## A tome's one line, between rules. Returns the height it took.
func _draw_ruled(area: Rect2, text: String, g: float) -> float:
	var px := roundi(17.0 * g)
	var font := UITheme.body(600)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var mid := area.position.x + area.size.x * 0.5
	var row := Rect2(area.position.x, area.position.y, area.size.x, px * 1.4)
	UITheme.draw_text(self, row, text, font, px, _a(PARCHMENT))
	var y := row.get_center().y
	var rule := _a(LEATHER_RULE)
	draw_line(Vector2(area.position.x, y), Vector2(mid - width * 0.5 - 10.0 * g, y), rule, maxf(1.0 * g, 1.0))
	draw_line(Vector2(mid + width * 0.5 + 10.0 * g, y), Vector2(area.end.x, y), rule, maxf(1.0 * g, 1.0))
	return row.size.y


## A curse's downsides in a red strip under what it does (`used` px down `text_rect`).
func _draw_curses(text_rect: Rect2, used: float, curses: PackedStringArray, g: float) -> void:
	var red := UITheme.rarity(Rarity.Tier.CURSED)
	var curse_px := roundi(15.0 * g)
	var shown := PackedStringArray()
	for text in curses:
		shown.append(("Curse: " if curses.size() == 1 else "") + text)
	var rows := 0
	for text in shown:
		rows += UITheme.wrap_lines(("• " if shown.size() > 1 else "") + text, UITheme.body(600), curse_px, text_rect.size.x - 16.0 * g).size()
	if shown.size() > 1:
		rows += 1  # the "Curse:" heading
	var strip := Rect2(text_rect.position.x - 6.0 * g, text_rect.position.y + used + 6.0 * g, text_rect.size.x + 12.0 * g,
			rows * curse_px * 1.25 + 10.0 * g)
	UITheme.draw_box(self, strip, _a(Color(red, 0.18)), 8.0 * g)
	var inner := strip.grow_individual(-8.0 * g, -5.0 * g, -8.0 * g, 0.0)
	if shown.size() > 1:
		UITheme.draw_wrapped(self, inner, "Curse:", UITheme.body(700), curse_px, _a(red.lightened(0.35)), HORIZONTAL_ALIGNMENT_LEFT)
		inner = inner.grow_individual(0.0, -curse_px * 1.25, 0.0, 0.0)
	_draw_lines(inner, shown, UITheme.body(600), curse_px, _a(red.lightened(0.35)))


## Fredoka slanted (a tome's name).
static func _italic() -> Font:
	if _italic_font == null:
		_italic_font = FontVariation.new()
		_italic_font.base_font = UITheme.display(600)
		_italic_font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.2, 1.0), Vector2.ZERO)
	return _italic_font
