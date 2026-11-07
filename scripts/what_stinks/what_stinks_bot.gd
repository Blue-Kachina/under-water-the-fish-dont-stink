class_name WhatStinksBot
extends Node
## A bot Hunter for What Stinks? (what_stinks.md section 9, the Phase 1 version:
## it swims at the nearest fish and bites). It heads for the school with the
## most fish left (it knows the count) while it's far off, then for the fish
## nearest its mouth, boosting when far, and bites when one is inside the
## bite's reach and ahead. It never reads which fish is a player: prey players
## are only ever the fish it happens to be nearest to. Drives its fish through
## FishController.controls, like WanderBot; the bite reads the fish's jump.
##
## Upset Stomach: a prey it can read (echo and noise exposure at least
## hunter_bot_avoid_exposure) is a stinker: it isn't a target, and the bot holds
## its bite while one is in the bite's frustum (a spit costs satiation and makes it queasy).
##
## The prey bot is a WanderBot (the match makes it); this is only the Hunter's.

var fish: FishController
var game: WhatStinksMatch
var input := FishInput.new()

var _bite_held := false


func _ready() -> void:
	process_physics_priority = -10  # before the fish samples its controls
	fish.controls = input


func _physics_process(_delta: float) -> void:
	input.clear()
	var was_held := _bite_held
	_bite_held = false
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
	# Far from any fish: go for the biggest school; close in: the fish itself.
	if gap > bite.reach() * 6.0 and settings.hunter_bot_prefers_big and game.field != null:
		var school := game.field.biggest_school(fish.global_position)
		if school != null:
			aim = school.middle()
			gap = mouth.distance_to(aim)
	_steer_to(aim)
	input.forward = 1.0 if gap > settings.hunter_bot_boost_gap else settings.hunter_bot_stalk
	input.boost = settings.hunter_bot_boost_gap <= 0.0 or gap > settings.hunter_bot_boost_gap
	var ahead := (-fish.global_basis.z).dot((aim - mouth).normalized())
	var close := float(near["gap"]) <= bite.reach() * settings.hunter_bot_bite_share and ahead > 0.4
	# A press, not a hold: released on the tick after, so the next one is a fresh press.
	if close and not was_held and bite.cooldown <= 0.0 and not bite.busy() and not _stinker_in_bite(bite):
		input.jump = true
		_bite_held = true


## The nearest live school fish or prey fish to `from`: {"at": position, "gap": m}.
func _nearest_target(from: Vector3) -> Dictionary:
	var best_at := fish.global_position - fish.global_basis.z * 50.0
	var best_gap := INF
	if game.field != null:
		var found := game.field.nearest_fish(from)
		if not found.is_empty():
			best_at = found[2]
			best_gap = from.distance_to(best_at)
	for prey in game.live_prey():
		if _is_stinker(prey):
			continue
		var gap := from.distance_to(prey.global_position)
		if gap < best_gap:
			best_gap = gap
			best_at = prey.global_position
	return {"at": best_at, "gap": best_gap if best_gap < INF else 1.0e6}


## Whether the bot can read `prey` as a player (Upset Stomach only).
func _is_stinker(prey: FishController) -> bool:
	var floor_read := game.settings.hunter_bot_avoid_exposure
	return game.stomach() and floor_read > 0.0 and game.echo != null and game.echo.exposure(fish, prey) >= floor_read


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
