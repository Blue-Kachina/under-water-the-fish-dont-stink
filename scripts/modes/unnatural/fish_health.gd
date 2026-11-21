class_name FishHealth
extends RefCounted
## A player's health in Unnatural (planning_unnatural.md §5): max hp grows
## with the team's level, contact damage from zombies then brief i-frames
## (the fish flickers), regen. At 0 hp the fish is down (solo: the run ends).

signal hurt(amount: float)
signal downed

var max_hp := 100.0
var hp := 100.0
## Seconds left that it can't be hurt.
var iframes_left := 0.0
var down := false
## Damage taken this run.
var taken := 0.0


func reset(max_health: float) -> void:
	max_hp = max_health
	hp = max_health
	iframes_left = 0.0
	down = false
	taken = 0.0


## Takes `amount` (unless it's in i-frames or down), then `iframes` s of
## i-frames. Returns whether it hurt.
func take(amount: float, iframes: float, immortal := false) -> bool:
	if down or iframes_left > 0.0 or amount <= 0.0:
		return false
	hp -= amount
	taken += amount
	iframes_left = iframes
	hurt.emit(amount)
	if hp <= 0.0:
		if immortal:
			hp = 1.0
		else:
			hp = 0.0
			down = true
			downed.emit()
	return true


## I-frames for `seconds` (at least), e.g. after a battery at speed.
func shield(seconds: float) -> void:
	iframes_left = maxf(iframes_left, seconds)


## Back up from down (a teammate's revive) with `share` of max hp, and a
## moment's i-frames.
func revive(share: float, iframes := 2.0) -> void:
	down = false
	hp = maxf(max_hp * clampf(share, 0.01, 1.0), 1.0)
	iframes_left = maxf(iframes_left, iframes)


func heal(amount: float) -> void:
	if not down:
		hp = minf(hp + amount, max_hp)


## Max hp to `max_health`, healing by however much it went up.
func set_max(max_health: float) -> void:
	var gain := max_health - max_hp
	max_hp = max_health
	if gain > 0.0:
		heal(gain)
	hp = minf(hp, max_hp)


func update(delta: float, regen: float) -> void:
	iframes_left = maxf(iframes_left - delta, 0.0)
	if regen > 0.0:
		heal(regen * delta)


func share() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
