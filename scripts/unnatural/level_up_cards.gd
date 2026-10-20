class_name LevelUpCards
extends Control
## Unnatural's level-up cards (planning_unnatural.md §6, §7, §11, and the
## Playability pass), drawn as Gem Frame cards (UI Redesign Handoff): a row of
## cards framed in their rarity's colour (Rarity, UITheme.RARITY), each with a
## glyph (HexBadge). A level's (CardDeck): a weapon's upgrade (the level it
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

## At the 1280×720 design's scale (scaled to the view as they draw).
const CARD_SIZE := Vector2(290.0, 410.0)
const FOCUSED_SIZE := Vector2(320.0, 450.0)
const GAP := 28.0
const PIPS := 5
## More level pips than this (a high level cap) and the card shows one bar instead.
const MAX_PIPS := 20
const ARM_TIME := 0.4

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
var selected := 0

var _age := 0.0
var _stick_was := 0
var _hints := ControllerHints.new()


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
	_hints.hints = [["◀ ▶", "Choose"], ["A", "Take it"]] + ([["B", "Put it back"]] if cancelable else [])
	visible = true
	queue_redraw()


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
## than one. Returns the height they took.
func _draw_lines(area: Rect2, lines: PackedStringArray, font: Font, px: int, color: Color) -> float:
	var used := 0.0
	var bullet := lines.size() > 1
	for text in lines:
		var at := Rect2(area.position.x, area.position.y + used, area.size.x, maxf(area.size.y - used, px))
		var align := HORIZONTAL_ALIGNMENT_LEFT if bullet else HORIZONTAL_ALIGNMENT_CENTER
		used += UITheme.draw_wrapped(self, at, ("• " if bullet else "") + text, font, px, color, align) + (2.0 if bullet else 0.0)
	return used


## One Gem Frame card (UI Redesign Handoff, Cards A): the rarity frame and
## its ribbon, the hexagon medallion, the name, which stack, what it does, and
## the stack pips. A level's stat card shows its amount in the medallion.
func _draw_card(i: int) -> void:
	var card: Dictionary = cards[i]
	var chosen := i == selected
	var rect := _card_rect(i)
	var g := rect.size.x / CARD_SIZE.x  # this card's scale (k, or more when focused)
	var powerup: String = card.get("powerup", "")
	var tier: int = card.get("tier", Powerup.tier(powerup) if powerup else Rarity.Tier.COMMON)
	var rim := UITheme.rarity(tier)
	var fade := 1.0 if chosen else 0.86
	var a := func(color: Color) -> Color: return Color(color, color.a * fade)

	if chosen:
		UITheme.draw_box(self, Rect2(rect.position + Vector2(0.0, 12.0 * g), rect.size).grow(4.0 * g), Color(0, 0, 0, 0.4), 24.0 * g)
		var pulse := 0.12 + 0.02 * sin(_age * 4.0)
		UITheme.draw_box(self, rect.grow(6.0 * g), Color(rim, pulse), 26.0 * g)
	UITheme.draw_box(self, rect, a.call(UITheme.CARD), 20.0 * g, a.call(rim), (3.0 if chosen else 2.0) * g)

	# The ribbon hanging from the top edge, the tier on it.
	var tier_px := roundi(14.0 * g)
	var tier_font := UITheme.caps(tier_px, 700, 0.22)
	var tier_name: String = Rarity.NAMES[tier]
	var ribbon_width := tier_font.get_string_size(tier_name, HORIZONTAL_ALIGNMENT_LEFT, -1, tier_px).x + 30.0 * g
	var ribbon := Rect2(rect.position.x + (rect.size.x - ribbon_width) * 0.5, rect.position.y, ribbon_width, 30.0 * g)
	UITheme.draw_box(self, ribbon, a.call(rim), 8.0 * g)
	draw_rect(Rect2(ribbon.position, Vector2(ribbon.size.x, 10.0 * g)), a.call(rim))
	UITheme.draw_text(self, ribbon, tier_name, tier_font, tier_px, a.call(UITheme.GROUND))

	# The medallion: the powerup's glyph, or the stat's amount.
	var medal := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 128.0 * g)
	HexBadge.draw_hex(self, medal, 132.0 * g, a.call(UITheme.CARD.lerp(rim, 0.18)), a.call(rim), 3.0 * g)
	var name_text := ""
	var stack_text := ""
	## What it does, one effect a line (bulleted when there's more than one),
	## and a curse's downsides likewise.
	var lines := PackedStringArray()
	var curses := PackedStringArray()
	var milestone := ""
	## Level pips: [held, this pick's, cap] (cap 0: the chest's stack pips instead).
	var pips := Vector3i(0, 0, 0)
	var kind: String = card.get("kind", "")
	if powerup:
		HexBadge.draw_glyph(self, powerup, medal, 60.0 * g, a.call(rim), 1.8)
		name_text = Powerup.title(powerup)
		var stacks: int = card.get("stacks", 1)
		stack_text = "NEW" if stacks <= 1 else "STACK %d → %d" % [stacks - 1, stacks]
		lines = Powerup.blurb_lines(powerup)
		curses = Powerup.curse_lines(powerup)
		if Powerup.is_weapon(powerup):
			stack_text = "BOSS WEAPON"
	elif kind in ["weapon", "new_weapon", "swap", "keep"]:
		var id: String = card.weapon
		HexBadge.draw_glyph(self, Weapons.glyph(id, attack_kind), medal, 60.0 * g, a.call(rim), 1.8)
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
				lines = Powerup.blurb_lines(id)
				lines.append_array(Weapons.describe_all(id, card.get("gains", {}), attack_kind))
				pips = Vector3i(0, 1, max_levels.x)
			"swap":
				stack_text = "SWAP OUT  ·  LV %d" % level
				lines = PackedStringArray(["Drop it for %s." % Powerup.title(card.incoming)])
			"keep":
				name_text = "Keep yours"
				stack_text = "NO SWAP"
				lines = PackedStringArray(["Leave %s behind." % Powerup.title(id)])
	elif kind in ["tome", "new_tome"]:
		var id: String = card.tome
		HexBadge.draw_glyph(self, Tomes.glyph(id), medal, 60.0 * g, a.call(rim), 1.8)
		name_text = Tomes.title(id)
		var level: int = card.get("level", 1)
		stack_text = "NEW TOME" if kind == "new_tome" else "LV %d → %d" % [level - 1, level]
		lines = Tomes.describe(card.gives)
		pips = Vector3i(level - 1, 1, max_levels.y)
	elif kind == "fallback":
		var pearls: bool = card.what == "pearls"
		var amount := ("+%d" % card.amount) if pearls else ("+%d%%" % roundi(card.amount * 100.0))
		UITheme.draw_text(self, Rect2(medal - Vector2(54.0, 26.0) * g, Vector2(108.0, 52.0) * g), amount, UITheme.display(700),
				roundi(34.0 * g), a.call(rim.lightened(0.15)))
		name_text = "Pearl Purse" if pearls else "Second Wind"
		stack_text = "NOTHING LEFT TO LEARN"
		lines = PackedStringArray(["%d pearls to spend on chests." % card.amount if pearls else "Heals the whole team."])
	UITheme.draw_text(self, Rect2(rect.position.x + 12.0 * g, rect.position.y + 204.0 * g, rect.size.x - 24.0 * g, 36.0 * g), name_text,
			UITheme.display(600), roundi(26.0 * g), a.call(UITheme.INK))
	var stack_px := roundi(14.0 * g)
	UITheme.draw_text(self, Rect2(rect.position.x, rect.position.y + 242.0 * g, rect.size.x, 20.0 * g), stack_text,
			UITheme.caps(stack_px, 700, 0.2), stack_px, a.call(rim.lightened(0.1)))
	var text_rect := Rect2(rect.position.x + 22.0 * g, rect.position.y + 276.0 * g, rect.size.x - 44.0 * g, 80.0 * g)
	var text_px := roundi((16.0 if lines.size() <= 3 else 14.0) * g)
	var used := _draw_lines(text_rect, lines, UITheme.body(400), text_px, a.call(UITheme.INK_SOFT))
	if milestone:
		var gold := UITheme.GOLD
		var mile_px := roundi(15.0 * g)
		UITheme.draw_wrapped(self, Rect2(text_rect.position.x, text_rect.position.y + used + 6.0 * g, text_rect.size.x, 60.0 * g),
				"New: " + milestone, UITheme.body(600), mile_px, a.call(gold))
	if not curses.is_empty():
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
		UITheme.draw_box(self, strip, a.call(Color(red, 0.18)), 8.0 * g)
		var inner := strip.grow_individual(-8.0 * g, -5.0 * g, -8.0 * g, 0.0)
		if shown.size() > 1:
			UITheme.draw_wrapped(self, inner, "Curse:", UITheme.body(700), curse_px, a.call(red.lightened(0.35)), HORIZONTAL_ALIGNMENT_LEFT)
			inner = inner.grow_individual(0.0, -curse_px * 1.25, 0.0, 0.0)
		_draw_lines(inner, shown, UITheme.body(600), curse_px, a.call(red.lightened(0.35)))

	# Level pips: held levels in the rarity's colour, this pick's in white, the rest dark.
	# Past MAX_PIPS (a high cap) one bar instead, filled the same way.
	if pips.z > MAX_PIPS:
		var bar := Rect2(rect.position.x + 30.0 * g, rect.end.y - 28.0 * g, rect.size.x - 60.0 * g, 6.0 * g)
		UITheme.draw_box(self, bar, a.call(Color(UITheme.GROUND, 0.9)), 3.0 * g)
		var held := bar.size.x * pips.x / pips.z
		var this_pick := maxf(bar.size.x * pips.y / pips.z, 4.0 * g)
		UITheme.draw_box(self, Rect2(bar.position, Vector2(held + this_pick, bar.size.y)), a.call(UITheme.INK), 3.0 * g)
		if held > 0.0:
			UITheme.draw_box(self, Rect2(bar.position, Vector2(held, bar.size.y)), a.call(rim), 3.0 * g)
	elif pips.z > 0:
		var pip := Vector2(minf(22.0, (rect.size.x / g - 60.0) / pips.z - 4.0), 6.0) * g
		var gap := 4.0 * g
		var left := rect.position.x + (rect.size.x - (pips.z * pip.x + (pips.z - 1) * gap)) * 0.5
		var y := rect.end.y - 28.0 * g
		for n in pips.z:
			var color := Color(UITheme.GROUND, 0.9)
			if n < pips.x:
				color = rim
			elif n < pips.x + pips.y:
				color = UITheme.INK
			UITheme.draw_box(self, Rect2(left + n * (pip.x + gap), y, pip.x, pip.y), a.call(color), 3.0 * g)
	# Pips: held stacks in the rarity's colour, this pick's in white, the rest dark.
	if powerup:
		var stacks: int = card.get("stacks", 1)
		var pip := Vector2(22.0, 6.0) * g
		var gap := 6.0 * g
		var left := rect.position.x + (rect.size.x - (PIPS * pip.x + (PIPS - 1) * gap)) * 0.5
		var y := rect.end.y - 28.0 * g
		for n in PIPS:
			var color := Color(UITheme.GROUND, 0.9)
			if n < stacks - 1:
				color = rim
			elif n == stacks - 1:
				color = UITheme.INK
			UITheme.draw_box(self, Rect2(left + n * (pip.x + gap), y, pip.x, pip.y), a.call(color), 3.0 * g)
