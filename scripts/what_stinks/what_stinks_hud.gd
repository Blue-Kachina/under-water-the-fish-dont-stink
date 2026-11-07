class_name WhatStinksHud
extends CanvasLayer
## What Stinks?'s HUD basics (what_stinks.md section 7): for everyone the round
## clock and the prey still swimming; for the Hunter a ring that fills as its
## bite comes ready (and the view blacked out through the countdown); for prey
## their role line and a prompt to find a school; for the eaten who they're
## watching; and the round's and the match's cards. Built in code, drawn by one
## Control, and kept to the basics: the maps, echo ring and murk view are later.

const INK := Color(0.93, 0.97, 1.0)
const SHADOW := Color(0.0, 0.0, 0.0, 0.7)
const RING := Color(1.0, 0.45, 0.35)
const ECHO := Color(0.45, 0.85, 1.0)
const NOISE := Color(1.0, 0.7, 0.3)
const BELLY := Color(0.55, 0.9, 0.4)
const QUEASY := Color(0.75, 0.85, 0.2)

var game: WhatStinksMatch
var _canvas: Control
var _font: Font


func bind(match_node: WhatStinksMatch) -> void:
	game = match_node
	layer = 5
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func _process(_delta: float) -> void:
	if _canvas:
		_canvas.queue_redraw()


## The line a phase shows at the top (also what the probe reads).
func headline() -> String:
	if game == null:
		return ""
	match game.phase:
		WhatStinksMatch.Phase.COUNTDOWN:
			if game.local_view_role() == WhatStinksMatch.Role.HUNTER:
				return "Hunting in %d" % ceili(game.phase_left)
			return "Find a school: %d" % ceili(game.phase_left)
		WhatStinksMatch.Phase.LIVE:
			if game.stomach():
				return "Prey spat out %d     %s" % [game.round_spat, _clock(game.time_left)]
			return "Prey left %d     %s" % [game.live_prey().size(), _clock(game.time_left)]
		WhatStinksMatch.Phase.ROUND_OVER:
			return "Round over"
		WhatStinksMatch.Phase.OVER:
			return "Match over"
	return ""


## The role line under it.
func role_line() -> String:
	if game == null:
		return ""
	if game.is_spectating():
		var watched := game.spectate_target()
		return "Eaten. Watching %s (left / right)" % (watched.display_name if is_instance_valid(watched) else "no one")
	if game.local_view_role() == WhatStinksMatch.Role.HUNTER:
		if game.stomach():
			return "You are the Hunter: eat school fish to fill your belly, and spit out the stinkers (they make you queasy)"
		return "You are the Hunter: bite (jump) to eat the fish at your mouth"
	if game.stomach():
		return "You are prey: be mistaken for food. A bite spits you out and upsets the Hunter's stomach"
	return "You are prey: join a school and swim with it"


## The Hunter whose bars show: the local one, else the first (prey watch it too).
func bars_hunter() -> FishController:
	if game == null or not game.stomach() or game.hunters.is_empty():
		return null
	var local := game.local_fish()
	return local if game.hunters.has(local) else game.hunters[0]


## The prey's prompt (what the join, leave and spook buttons do now); "" for the Hunter and the eaten.
func prompt() -> String:
	if game == null or game.join == null or game.is_spectating() or game.local_view_role() != WhatStinksMatch.Role.PREY:
		return ""
	return game.join.prompt_for(game.local_fish())


## Whether the Hunter's view is blacked out (its countdown).
func blackout() -> bool:
	return game != null and game.phase == WhatStinksMatch.Phase.COUNTDOWN and game.local_view_role() == WhatStinksMatch.Role.HUNTER


func _clock(seconds: float) -> String:
	var whole := maxi(ceili(seconds), 0)
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]


func _text(at: Vector2, text: String, font_size: int, centered := true, color := INK) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var origin := at - Vector2(width * 0.5 if centered else 0.0, 0.0)
	_canvas.draw_string(_font, origin + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, SHADOW)
	_canvas.draw_string(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_hud() -> void:
	if game == null or not is_instance_valid(game):
		return
	var area := _canvas.size
	if blackout():
		_canvas.draw_rect(Rect2(Vector2.ZERO, area), Color.BLACK)
	_text(Vector2(area.x * 0.5, 44.0), headline(), 28)
	_text(Vector2(area.x * 0.5, 74.0), role_line(), 16)
	if not blackout() and game.phase in [WhatStinksMatch.Phase.COUNTDOWN, WhatStinksMatch.Phase.LIVE]:
		_draw_stomach_bars(Vector2(area.x * 0.5, 104.0))
	var local := game.local_fish()
	var line := prompt()
	if line != "" and not blackout():
		_text(Vector2(area.x * 0.5, area.y - 90.0), line, 22)
	if game.phase == WhatStinksMatch.Phase.LIVE and game.local_view_role() == WhatStinksMatch.Role.HUNTER and game.bites.has(local):
		_draw_bite_ring(Vector2(area.x * 0.5, area.y - 90.0), game.bites[local] as HunterBite)
	if game.phase == WhatStinksMatch.Phase.LIVE and game.local_view_role() == WhatStinksMatch.Role.HUNTER and game.echo != null and game.hunters.has(local):
		_draw_hunter_senses(Vector2(area.x * 0.5, area.y - 90.0), local)
	if not blackout() and game.local_view_role() == WhatStinksMatch.Role.PREY and not game.is_spectating() and game.phase != WhatStinksMatch.Phase.OVER:
		_draw_prey_panel(area, local)
	if game.phase == WhatStinksMatch.Phase.ROUND_OVER:
		_draw_round_card(area)
	elif game.phase == WhatStinksMatch.Phase.OVER:
		_draw_match_card(area)


## Upset Stomach's two bars under the headline: the Hunter's belly (satiation) and its queasiness.
func _draw_stomach_bars(at: Vector2) -> void:
	var hunter := bars_hunter()
	if hunter == null:
		return
	var width := 260.0
	var belly := Rect2(at + Vector2(-width * 0.5, 0.0), Vector2(width, 14.0))
	_bar(belly, game.satiation_share(hunter), BELLY)
	_text(at + Vector2(-width * 0.5 - 10.0, 12.0), "Belly", 14, false)
	var queasy := Rect2(at + Vector2(-width * 0.5, 22.0), Vector2(width, 10.0))
	_bar(queasy, game.queasy_share(hunter), QUEASY)
	var strikes := maxf(game.settings.queasy_max / maxf(game.settings.queasy_per_spit, 0.001), 1.0)
	for i in range(1, int(strikes)):
		var x := queasy.position.x + queasy.size.x * float(i) / strikes
		_canvas.draw_line(Vector2(x, queasy.position.y), Vector2(x, queasy.end.y), Color(0, 0, 0, 0.6), 2.0)
	_text(at + Vector2(width * 0.5 + 12.0, 32.0), "Hurled" if game.hurled_out.has(hunter) else "Queasy", 14, false)


func _bar(rect: Rect2, share: float, color: Color) -> void:
	_canvas.draw_rect(rect, Color(0, 0, 0, 0.55))
	_canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(share, 0.0, 1.0), rect.size.y)), color)
	_canvas.draw_rect(rect, Color(1, 1, 1, 0.5), false, 1.5)


## A ring that fills as the bite comes ready; full and bright when it can bite.
func _draw_bite_ring(at: Vector2, bite: HunterBite) -> void:
	var every := maxf(float(bite.form["bite_every"]), 0.01)
	var ready_share := 1.0 if bite.busy() else clampf(1.0 - bite.cooldown / every, 0.0, 1.0)
	_canvas.draw_arc(at, 34.0, 0.0, TAU, 48, Color(1, 1, 1, 0.2), 6.0, true)
	_canvas.draw_arc(at, 34.0, -PI * 0.5, -PI * 0.5 + TAU * ready_share, 48, RING if ready_share >= 1.0 else RING.darkened(0.35), 6.0, true)
	_text(at + Vector2(0, 8), "%d" % bite.capacity(), 22)


## The Hunter's Click (a ring that fills over its cooldown) and Sniff (lit while held), either side of the bite ring.
func _draw_hunter_senses(at: Vector2, hunter: FishController) -> void:
	var echo := game.echo
	var wait := echo.click_ready_in(hunter)
	var share := 1.0 - clampf(wait / maxf(game.settings.click_cooldown, 0.01), 0.0, 1.0)
	var click_at := at + Vector2(-78.0, 0.0)
	_canvas.draw_arc(click_at, 22.0, 0.0, TAU, 40, Color(1, 1, 1, 0.2), 5.0, true)
	_canvas.draw_arc(click_at, 22.0, -PI * 0.5, -PI * 0.5 + TAU * share, 40, ECHO if share >= 1.0 else ECHO.darkened(0.4), 5.0, true)
	_text(click_at + Vector2(0, 40), "Click", 14)
	var sniff_at := at + Vector2(78.0, 0.0)
	_canvas.draw_arc(sniff_at, 22.0, 0.0, TAU, 40, ECHO if echo.is_sniffing(hunter) else Color(1, 1, 1, 0.2), 5.0, true)
	_text(sniff_at + Vector2(0, 40), "Sniff", 14)


## The prey's map (the arena from above, north up: schools, allies, you, the Hunter's arrow) and the two
## rings under it: how loud you are (noise) and how clear the Hunter's picture of you is (echo).
func _draw_prey_panel(area: Vector2, me: FishController) -> void:
	var radius := 84.0
	var middle := Vector2(area.x - radius - 24.0, radius + 110.0)
	var arena := maxf(game.settings.arena_radius, 1.0)
	_canvas.draw_circle(middle, radius, Color(0.02, 0.1, 0.14, 0.55))
	_canvas.draw_arc(middle, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.35), 2.0, true)
	if game.field != null:
		for school in game.field.schools:
			if school.alive_count() > 0:
				var dot := _map_point(school.middle(), middle, radius, arena)
				_canvas.draw_circle(dot, clampf(2.0 + sqrt(float(school.alive_count())) * 0.45, 2.0, 6.0), Color(0.5, 0.8, 1.0, 0.8))
	if game.shadows != null:
		for spot in game.shadows.spots:
			_canvas.draw_arc(_map_point(spot["position"] as Vector3, middle, radius, arena), 3.0, 0.0, TAU, 12, Color(0.5, 0.9, 0.5, 0.7), 1.5, true)
	for fish in game.live_prey():
		if fish != me and game.join != null and game.join.is_joined(fish) and game.settings.ally_markers:
			_canvas.draw_circle(_map_point(fish.global_position, middle, radius, arena), 3.0, WhatStinksJoin.MARKER_ALLY)
	_canvas.draw_circle(_map_point(me.global_position, middle, radius, arena), 4.0, WhatStinksJoin.MARKER_OWN)
	for hunter in game.hunters:
		if not is_instance_valid(hunter):
			continue
		var tip := _map_point(hunter.global_position, middle, radius, arena)
		var heading := Vector2(-hunter.global_basis.z.x, -hunter.global_basis.z.z).normalized()
		var side := Vector2(-heading.y, heading.x)
		_canvas.draw_colored_polygon(PackedVector2Array([tip + heading * 8.0, tip - heading * 5.0 + side * 5.0, tip - heading * 5.0 - side * 5.0]), RING)
	if game.echo == null:
		return
	var ring_y := middle.y + radius + 46.0
	_draw_meter(Vector2(middle.x - 44.0, ring_y), game.echo.noise_of(me), "noise", NOISE)
	_draw_meter(Vector2(middle.x + 44.0, ring_y), game.echo.echo_max(me), "echo", ECHO)


func _map_point(world: Vector3, middle: Vector2, radius: float, arena: float) -> Vector2:
	var off := Vector2(world.x - game.center.x, world.z - game.center.z) / arena * radius * 0.92
	return middle + off.limit_length(radius)


func _draw_meter(at: Vector2, value: float, label: String, color: Color) -> void:
	_canvas.draw_arc(at, 22.0, 0.0, TAU, 40, Color(1, 1, 1, 0.2), 5.0, true)
	if value > 0.005:
		_canvas.draw_arc(at, 22.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(value, 0.0, 1.0), 40, color, 5.0, true)
	_text(at + Vector2(0, 40), label, 14)


func _draw_round_card(area: Vector2) -> void:
	var results := game.last_results
	if results.is_empty():
		return
	var middle := area * 0.5
	var title := "The Hunter ate everyone" if bool(results["hunters_won"]) else "The prey got away"
	var count := "Eaten %d" % int(results["eaten"])
	match String(results.get("reason", "")):
		"full":
			title = "The Hunter ate its fill"
		"hurled":
			title = "The Hunter hurled"
		"hungry":
			title = "Time's up, still hungry"
	if game.stomach():
		count = "Spat out %d" % int(results.get("spat", 0))
	_text(middle + Vector2(0, -60), title, 36)
	_text(middle + Vector2(0, -20), count, 22)
	var points: Dictionary = results["points"]
	var local := game.local_fish()
	if points.has(local):
		_text(middle + Vector2(0, 20), "You scored %d" % roundi(float(points[local])), 22)
	_text(middle + Vector2(0, 60), "Next round in %d" % ceili(game.phase_left), 18)


func _draw_match_card(area: Vector2) -> void:
	var middle := area * 0.5
	var best := game.winner
	_text(middle + Vector2(0, -40), "%s wins the match" % (best.display_name if is_instance_valid(best) else "No one"), 36)
	var local := game.local_fish()
	_text(middle + Vector2(0, 4), "You have %d" % roundi(float(game.match_totals.get(local, 0.0))), 22)
