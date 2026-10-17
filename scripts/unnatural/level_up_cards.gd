class_name LevelUpCards
extends Control
## Unnatural's level-up cards (planning_unnatural.md §6, §7, §11): a row of
## cards, each a stat upgrade framed in its rarity's colour (Rarity), the
## rarer the bolder (a glow, and a pulse for legendary); or a chest's
## powerups, each in its own colour, saying which stack it would be. Picked with the left stick, A/D
## or the arrow keys and A / Enter / Space, the number keys 1-3, or the mouse.
## Runs while the game's paused (solo, the cards pause it). For the first
## ARM_TIME it ignores the pick button, so a held or mashed A doesn't choose
## blind. `picked` says which.

signal picked(index: int)

const CARD_SIZE := Vector2(250.0, 330.0)
const GAP := 28.0
const ARM_TIME := 0.4

## Each card: {"stat", "tier", "amount"} or {"powerup", "stacks"} (UnnaturalRun's offer).
var cards: Array = []
## The title ("LEVEL 4", "TREASURE!") and the line under it.
var heading := ""
var line := ""
## Whose controls pick (null: every controller and the keyboard).
var input: PlayerInput
## The game stays paused while they're up (solo): closing the pause menu
## over them doesn't let it run.
var pauses := false
var selected := 0

var _age := 0.0
var _stick_was := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


## Shows `offer`, under `title` and `subtitle`.
func open(offer: Array, title: String, subtitle: String, player_input: PlayerInput) -> void:
	cards = offer
	heading = title
	line = subtitle
	input = player_input
	selected = 0
	_age = 0.0
	_stick_was = 0
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


func _card_rect(index: int) -> Rect2:
	var total := cards.size() * CARD_SIZE.x + (cards.size() - 1) * GAP
	var left := (size.x - total) / 2.0
	var top := size.y * 0.5 - CARD_SIZE.y * 0.45
	return Rect2(Vector2(left + index * (CARD_SIZE.x + GAP), top), CARD_SIZE)


func _card_at(point: Vector2) -> int:
	for i in cards.size():
		if _card_rect(i).has_point(point):
			return i
	return -1


func _draw() -> void:
	if not is_open():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.45))
	var head := Rect2(0.0, _card_rect(0).position.y - 118.0, size.x, 52.0)
	BroadcastUI.text(self, head, heading, 44, BroadcastUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 800)
	if line:
		BroadcastUI.text(self, Rect2(0.0, head.end.y, size.x, 28.0), line, 18, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 700)
	for i in cards.size():
		_draw_card(i)
	var hint := Rect2(0.0, _card_rect(0).end.y + 24.0, size.x, 24.0)
	BroadcastUI.text(self, hint, "◀ ▶ CHOOSE    ·    A / ENTER PICK    ·    1 2 3", 16, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 700)


func _draw_card(i: int) -> void:
	var card: Dictionary = cards[i]
	if card.has("powerup"):
		_draw_powerup(i, card)
		return
	var tier: int = card.tier
	var color: Color = Rarity.COLORS[tier]
	var rect := _card_rect(i)
	var chosen := i == selected
	if chosen:
		rect = rect.grow(10.0)
	var glow := 0.0
	if tier >= Rarity.Tier.RARE:
		glow = 0.25 * (tier - 1)
	if tier == Rarity.Tier.LEGENDARY:
		glow += 0.25 * (0.5 + 0.5 * sin(_age * 6.0))
	if glow > 0.0:
		for ring in 4:
			draw_rect(rect.grow(6.0 + ring * 6.0), Color(color, glow * (0.3 - ring * 0.06)))
	draw_rect(rect, Color(BroadcastUI.INK, 0.95))
	draw_rect(rect, color, false, 6.0 if chosen else 3.0)
	var band := Rect2(rect.position, Vector2(rect.size.x, 40.0))
	draw_rect(band, Color(color, 0.85))
	BroadcastUI.text(self, band, Rarity.NAMES[tier], 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)
	var id: String = card.stat
	BroadcastUI.text(self, Rect2(rect.position + Vector2(10.0, 70.0), Vector2(rect.size.x - 20.0, 40.0)), StatBlock.title(id).to_upper(), 24,
			Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)
	BroadcastUI.text(self, Rect2(rect.position + Vector2(10.0, 150.0), Vector2(rect.size.x - 20.0, 60.0)), StatBlock.describe(id, card.amount), 30,
			color.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, 800)
	BroadcastUI.text(self, Rect2(rect.position + Vector2(0.0, rect.size.y - 46.0), Vector2(rect.size.x, 30.0)), str(i + 1), 20,
			Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 700)


## A chest's powerup card: its colour, name, which stack, what it does.
func _draw_powerup(i: int, card: Dictionary) -> void:
	var id: String = card.powerup
	var color := Powerup.color(id)
	var rect := _card_rect(i)
	var chosen := i == selected
	if chosen:
		rect = rect.grow(10.0)
	for ring in 3:
		draw_rect(rect.grow(6.0 + ring * 6.0), Color(color, (0.2 - ring * 0.06) * (0.6 + 0.4 * sin(_age * 4.0))))
	draw_rect(rect, Color(BroadcastUI.INK, 0.95))
	draw_rect(rect, color, false, 6.0 if chosen else 3.0)
	var band := Rect2(rect.position, Vector2(rect.size.x, 40.0))
	draw_rect(band, Color(color, 0.85))
	var stacks: int = card.stacks
	BroadcastUI.text(self, band, "NEW" if stacks <= 1 else "STACK %d" % stacks, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)
	var badge := Rect2(rect.position + Vector2(rect.size.x * 0.5 - 34.0, 56.0), Vector2(68.0, 68.0))
	draw_rect(badge, Color(color, 0.3))
	draw_rect(badge, color, false, 3.0)
	BroadcastUI.text(self, badge, Powerup.tag(id), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)
	BroadcastUI.text(self, Rect2(rect.position + Vector2(8.0, 134.0), Vector2(rect.size.x - 16.0, 34.0)), Powerup.title(id).to_upper(), 20,
			Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 800)
	var words := Powerup.blurb(id).split(" ")
	var rows: Array[String] = [""]
	for word in words:
		if (rows[-1] + " " + word).length() > 26:
			rows.append(word)
		else:
			rows[-1] = (rows[-1] + " " + word).strip_edges()
	for r in rows.size():
		BroadcastUI.text(self, Rect2(rect.position + Vector2(10.0, 182.0 + r * 24.0), Vector2(rect.size.x - 20.0, 24.0)), rows[r], 15,
				Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 600)
	BroadcastUI.text(self, Rect2(rect.position + Vector2(0.0, rect.size.y - 46.0), Vector2(rect.size.x, 30.0)), str(i + 1), 20,
			Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 700)
