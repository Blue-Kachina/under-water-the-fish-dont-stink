class_name WhatStinksPreyBot
extends WanderBot
## A prey bot for What Stinks? (what_stinks.md section 9). It swims to the school nearest its `home`
## (the match picks that: a random school, or a bait school in Upset Stomach) and the join system
## takes it in once it is within the join radius of a free fish. Joined, it watches its own
## exposure (what a Hunter reads of it: echo and noise, the ring a person sees on their own fish):
## when that has stayed at least prey_bot_exposure for prey_bot_patience seconds it leaves (loudly,
## with the rejoin cooldown) and swims for another school, preferring one far from the Hunter.
## That relocation is the whole trick of the bot. It never reads which school the Hunter is
## working beyond where the Hunter is. Not while baiting in Upset Stomach: there it wants to be
## taken for food. With no school to go to it wanders like a WanderBot.

var game: WhatStinksMatch

## Seconds its exposure has been over the line while joined.
var exposed_for := 0.0
## Times it left a school this round.
var relocations := 0

var _school: School
var _avoid: School
var _grip_s := 0.0
var _will_tear := false
var _turn := 1.0


func _physics_process(delta: float) -> void:
	input.clear()
	if game == null or not is_instance_valid(fish) or fish.battered or game.phase == WhatStinksMatch.Phase.OVER:
		return
	if _struggle(delta):
		return
	if game.join != null and game.join.is_joined(fish):
		if _avoid != null and game.join.school_of(fish) != _avoid:
			_avoid = null  # it found another one
		_watch(delta)
		return  # a joined fish is held in its place (the join system moves it)
	exposed_for = 0.0
	if fish.controls_locked or not game.is_live_prey(fish):
		return
	if _school == null or not is_instance_valid(_school) or _school.nearest_free(fish.global_position) < 0:
		_school = _pick_school()
	if _school == null:
		super._physics_process(delta)  # nothing to join: wander
		return
	var index := _school.nearest_free(fish.global_position)
	var at := _school.fish_position(index)
	LureField.tick(delta)
	var aim := LureField.blend_target(fish, at)  # an Angler's lure bends the swim target toward its light
	_steer_to(aim)
	var gap := fish.global_position.distance_to(at)
	input.forward = 1.0  # a school keeps moving: no cruising up to it
	input.boost = gap > 15.0 and fish.boost_enabled  # it rushes for cover


## Grabbed by an Ember Octopus' arm (GrappleAttack): with grapple_bot_break's chance per grab it tries to tear free after
## grapple_bot_react_s. Joined, it leaves its school (a dash out); free, it dashes and turns hard (both tear the arm off). Returns
## whether it is struggling (then it drives itself this tick).
func _struggle(delta: float) -> bool:
	if not GrappleAttack.gripped_now(fish):
		_grip_s = 0.0
		return false
	var settings := game.settings
	if _grip_s <= 0.0:
		_will_tear = randf() < GrappleAttack.cfg_of(settings, {}, "grapple_bot_break")
		var from_at := GrappleAttack.grip_from(fish)
		_turn = 1.0 if not from_at.is_finite() or (fish.global_position - from_at).dot(fish.global_basis.x) >= 0.0 else -1.0
	_grip_s += delta
	if not _will_tear or _grip_s < GrappleAttack.cfg_of(settings, {}, "grapple_bot_react_s"):
		return false
	if game.join != null and game.join.is_joined(fish):
		_avoid = game.join.school_of(fish)
		if game.join.leave(fish):
			relocations += 1
			_school = _pick_school()
		return true
	input.stick = Vector2(_turn, 0.0)  # a hard turn, one way (away from the arm's side when it was grabbed)
	input.forward = 1.0
	input.boost = fish.boost_enabled
	return true


## Joined: leave once a Hunter has read it long enough.
func _watch(delta: float) -> void:
	var settings := game.settings
	if settings.prey_bot_patience <= 0.0 or game.phase != WhatStinksMatch.Phase.LIVE or (game.stomach() and settings.prey_bot_baits):
		exposed_for = 0.0
		return
	if game.echo != null and game.echo.max_exposure(fish) >= settings.prey_bot_exposure:
		exposed_for += delta
	else:
		exposed_for = maxf(exposed_for - delta, 0.0)
	if exposed_for >= settings.prey_bot_patience:
		_avoid = game.join.school_of(fish)
		if game.join.leave(fish):
			relocations += 1
			exposed_for = 0.0
			_school = _pick_school()


## The school to swim for: the one nearest `home` the first time; after a relocation the free-fish school that
## is nearest it and far from the Hunter, never the one it just left.
func _pick_school() -> School:
	if game.field == null:
		return null
	var best: School
	var best_cost := INF
	var from := fish.global_position
	for school in game.field.schools:
		if school == _avoid or school.alive_count() == 0 or not game.join.eligible(fish, school) or school.nearest_free(from) < 0:
			continue
		var cost := school.middle().distance_to(home if _avoid == null else from)
		if _avoid != null:
			for hunter in game.hunters:
				if is_instance_valid(hunter):
					cost -= school.middle().distance_to(hunter.global_position) * 0.5
		if cost < best_cost:
			best_cost = cost
			best = school
	if best == null and _avoid != null:
		_avoid = null  # only the old one is left
		return _pick_school()
	return best


## Whether it would join `school` now (the join system asks): not the one it just left.
func accepts(school: School) -> bool:
	return school != _avoid
