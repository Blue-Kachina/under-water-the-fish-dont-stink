class_name WhatStinksBot
extends Node
## A bot Hunter for What Stinks? (what_stinks.md section 9). It heads for the school with the
## most fish left (it knows the count) while it's far off, then for the fish
## nearest its mouth, boosting when far, and bites when one is inside the
## bite's reach and ahead (the bite's style says when to press and let go: HunterAttack.bot_plan).
## It never reads which fish is a player directly. What it does read is the echo, like a person:
## in Clean Sweep a prey whose exposure is at least hunter_bot_read_exposure is a target it
## prefers (a loner it can't read isn't one), it Clicks when the Click is ready and nothing is
## readable, and it sniffs while it works a school it has found no prey in (hunter_bot_sniff_s
## per school, then it heads for another). Drives its fish through FishController.controls, like
## WanderBot; the bite reads the fish's jump, the echo its Click and Sniff buttons.
##
## Upset Stomach: a prey it can read (echo and noise exposure at least
## hunter_bot_avoid_exposure) is a stinker: it isn't a target, and the bot holds
## its bite while one is in the bite's frustum (a spit costs satiation and makes it queasy).
##
## The prey bot is WhatStinksPreyBot (the match makes it); this is only the Hunter's.

## Ticks a Click or Sniff press is held: the echo reads the fish's buttons on its own tick, which can come first.
const CLICK_TICKS := 3
## Ticks a bite press is kept down while the jaws have not opened yet (the bite reads the button a tick late).
const PRESS_TICKS := 2

var fish: FishController
var game: WhatStinksMatch
var input := FishInput.new()

## What the bite's style (HunterAttack.bot_plan) reads: the nearest fish's place, its gap from the mouth now and last tick,
## how squarely the nose points at it, and whether an Upset Stomach stinker is in the bite.
var target_at := Vector3.ZERO
var target_gap := 1.0e6
var target_prev_gap := 1.0e6
var target_ahead := 0.0
var stinker_blocks := false
## The target is a prey the bot reads through the echo (Clean Sweep).
var target_readable := false
## Seconds spent sniffing at each school, and whether it sniffs now.
var scanned := {}
var sniffing := false
## Clicks made this round.
var clicks := 0

var _was_down := false
var _click_ticks := 0
var _wait := 0


func _ready() -> void:
	process_physics_priority = -10  # before the fish samples its controls
	fish.controls = input


func _physics_process(delta: float) -> void:
	input.clear()
	sniffing = false
	if not is_instance_valid(fish) or fish.battered or fish.controls_locked or game == null or game.phase != WhatStinksMatch.Phase.LIVE:
		return
	var bite: HunterBite = game.bites.get(fish)
	if bite == null:
		return
	var settings := game.settings
	var mouth := bite.mouth_point()
	var near := _nearest_target(mouth)
	var aim := near["at"] as Vector3
	var gap := mouth.distance_to(aim)
	var readable := bool(near["readable"])
	var work := _school_to_work(fish.global_position)
	# Far from any fish: go for the biggest school; close in: the fish itself.
	if gap > bite.reach() * 6.0 and settings.hunter_bot_prefers_big and work != null:
		aim = work.middle()
		gap = mouth.distance_to(aim)
	_steer_to(aim)
	input.forward = 1.0 if gap > settings.hunter_bot_boost_gap else settings.hunter_bot_stalk
	input.boost = settings.hunter_bot_boost_gap <= 0.0 or gap > settings.hunter_bot_boost_gap
	var ahead := (-fish.global_basis.z).dot((aim - mouth).normalized())
	target_prev_gap = target_gap
	target_at = near["at"]
	target_gap = float(near["gap"])
	target_ahead = ahead
	target_readable = readable
	stinker_blocks = _stinker_in_bite(bite)
	# The bite's style says when to press and when to let go. The bite reads the button a tick after
	# the bot sets it, so a press is kept down until the jaws are open (a tick or two) or it was refused;
	# a tap-mode press is released on the tick after, so the next one is a fresh press.
	var plan := bite.attack.bot_plan(self, bite)
	if bite.holding():
		_wait = 0
		input.jump = bool(plan["hold"])
	elif _was_down and _wait < PRESS_TICKS and settings.bite_mode == WhatStinksSettings.BiteMode.HOLD:
		_wait += 1
		input.jump = true
	else:
		_wait = 0
		input.jump = bool(plan["press"]) and not _was_down
	_was_down = input.jump
	_listen(bite, work, readable, delta)


## The echo: Click when it is ready and nothing is readable, sniff over a school with no prey found in it.
func _listen(bite: HunterBite, work: School, readable: bool, delta: float) -> void:
	var settings := game.settings
	var echo := game.echo
	if echo == null:
		return
	var at_rest := not bite.holding() and not bite.busy()
	if _click_ticks > 0:
		_click_ticks -= 1
		_set_button(settings.click_button, true)
	elif settings.hunter_bot_click and not settings.click_auto and at_rest and not readable and echo.click_ready_in(fish) <= 0.0:
		_click_ticks = CLICK_TICKS
		clicks += 1
		_set_button(settings.click_button, true)
	if settings.hunter_bot_sniff_s <= 0.0 or game.stomach() or not at_rest or readable or work == null:
		return
	if fish.global_position.distance_to(work.middle()) > work.radius() + bite.reach() * 3.0:
		return
	if float(scanned.get(work, 0.0)) >= settings.hunter_bot_sniff_s:
		return
	sniffing = true
	scanned[work] = float(scanned.get(work, 0.0)) + delta
	_set_button(settings.sniff_button, true)


## Holds `button` (a setting's name for it) on the bot's input. The bite's own button is the bite's, not a click's.
func _set_button(button: String, down: bool) -> void:
	match button:
		"air_roll":
			input.air_roll = input.air_roll or down
		"powerslide":
			input.powerslide = input.powerslide or down
		"boost":
			input.boost = input.boost or down


## The school it works: most fish left, nearer on a tie, skipping the ones it has sniffed out
## (unless there are no others).
func _school_to_work(point: Vector3) -> School:
	if game.field == null:
		return null
	var limit := game.settings.hunter_bot_sniff_s
	var best: School
	var best_score := -INF
	for skip_done in [true, false]:
		for school in game.field.schools:
			var alive := school.alive_count()
			if alive == 0 or (skip_done and limit > 0.0 and float(scanned.get(school, 0.0)) >= limit):
				continue
			var score := float(alive) - school.middle().distance_to(point) * 0.05
			if score > best_score:
				best_score = score
				best = school
		if best != null:
			break
	return best


## The fish it goes for from `from`: {"at": position, "gap": m, "readable": whether it is a prey it reads}. The nearest
## live school fish or prey fish, except that in Clean Sweep a readable prey counts as half as far and a loner it can't read isn't one.
func _nearest_target(from: Vector3) -> Dictionary:
	var best_at := fish.global_position - fish.global_basis.z * 50.0
	var best_gap := INF
	var best_score := INF
	var best_readable := false
	if game.field != null:
		var found := game.field.nearest_fish(from)
		if not found.is_empty():
			best_at = found[2]
			best_gap = from.distance_to(best_at)
			best_score = best_gap
	var floor_read := game.settings.hunter_bot_read_exposure
	var reads := not game.stomach() and floor_read > 0.0 and game.echo != null
	for prey in game.live_prey():
		if _is_stinker(prey):
			continue
		var gap := from.distance_to(prey.global_position)
		var score := gap
		var seen := false
		if reads:
			seen = game.echo.exposure(fish, prey) >= floor_read
			if seen:
				score *= 0.5
			elif not (game.join != null and game.join.is_joined(prey)):
				continue  # a loner it can't read is not on its screen
		if score < best_score:
			best_score = score
			best_gap = gap
			best_at = prey.global_position
			best_readable = seen
	return {"at": best_at, "gap": best_gap if best_gap < INF else 1.0e6, "readable": best_readable}


## Whether the bot can read `prey` as a player (Upset Stomach only).
func _is_stinker(prey: FishController) -> bool:
	var floor_read := game.settings.hunter_bot_avoid_exposure
	return game.stomach() and floor_read > 0.0 and game.echo != null and game.echo.exposure(fish, prey) >= floor_read


## The same, for a style that picks its own target (the Angel's lock).
func reads_as_stinker(prey: FishController) -> bool:
	return _is_stinker(prey)


func _stinker_in_bite(bite: HunterBite) -> bool:
	if not game.stomach():
		return false
	for prey in game.live_prey():
		if _is_stinker(prey) and bite.in_bite(prey.global_position):
			return true
	return false


func _steer_to(target: Vector3) -> void:
	var basis := fish.global_basis.orthonormalized()
	var local := basis.inverse() * (target - fish.global_position)
	var yaw := atan2(local.x, -local.z)  # + = to the right
	var pitch := atan2(local.y, Vector2(local.x, local.z).length())  # + = above
	input.stick.x = clampf(yaw * 1.5, -1.0, 1.0)
	input.stick.y = clampf(pitch * 1.5, -1.0, 1.0)  # stick down lifts the nose
	input.roll = clampf(basis.x.y * 3.0, -1.0, 1.0)  # right side high: roll right, back upright
