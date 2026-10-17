class_name CoopRules
extends RefCounted
## Nature's shared tally, for one player or several (local split-screen or
## online co-op): the fish battered and pearls collected by the whole team, and
## each player's share. A battery two players land on the same fish at once
## (NatureRun.SHARE_WINDOW) is one fish for the team but credits both: a
## shared battery, the first of the team moments (tandems, school formation)
## this is where they'll be scored.
##
## Fed only with confirmed events (NatureRun: the host's say in online co-op),
## so every machine keeps the same numbers. Each player's own points, multis
## and sprees are their NatureScore's, not this.

signal changed

## Fish battered by the team (each fish once, however many hit it).
var team_battered_fish := 0
## Pearls collected by the team.
var team_pearls := 0
## Batteries with more than one player's credit.
var shared_batteries := 0
## Per player (their fish): fish battered (shared ones count for each) and pearls.
var _battered := {}
var _pearls := {}


func reset() -> void:
	team_battered_fish = 0
	team_pearls = 0
	shared_batteries = 0
	_battered.clear()
	_pearls.clear()
	changed.emit()


## A fish battered, credited to `attackers` (one, or more for a shared battery).
func on_battery(attackers: Array) -> void:
	team_battered_fish += 1
	for fish in attackers:
		_battered[fish] = _battered.get(fish, 0) + 1
	if attackers.size() > 1:
		shared_batteries += 1
	changed.emit()


## `attacker` shares a battery already counted (it hit the same fish at once).
func on_shared(attacker: Object) -> void:
	_battered[attacker] = _battered.get(attacker, 0) + 1
	shared_batteries += 1
	changed.emit()


func on_pearl(by: Object) -> void:
	team_pearls += 1
	_pearls[by] = _pearls.get(by, 0) + 1
	changed.emit()


func battered_by(fish: Object) -> int:
	return _battered.get(fish, 0)


func pearls_of(fish: Object) -> int:
	return _pearls.get(fish, 0)


## Everything, for a guest joining late (`key_of` names a player: their fish ->
## a key that travels, e.g. their player id).
func save(key_of: Callable) -> Dictionary:
	var battered := {}
	var pearls := {}
	for fish: Variant in _battered:
		if is_instance_valid(fish):
			battered[key_of.call(fish)] = _battered[fish]
	for fish: Variant in _pearls:
		if is_instance_valid(fish):
			pearls[key_of.call(fish)] = _pearls[fish]
	return {"team": team_battered_fish, "pearls": team_pearls, "shared": shared_batteries, "battered": battered, "pearl_by": pearls}


## save()'s counts, here (`fish_of` turns a key back into a player's fish, or null).
func restore(saved: Dictionary, fish_of: Callable) -> void:
	team_battered_fish = saved.get("team", 0)
	team_pearls = saved.get("pearls", 0)
	shared_batteries = saved.get("shared", 0)
	_battered.clear()
	_pearls.clear()
	for key: Variant in saved.get("battered", {}):
		var fish: Variant = fish_of.call(key)
		if fish:
			_battered[fish] = saved.battered[key]
	for key: Variant in saved.get("pearl_by", {}):
		var fish: Variant = fish_of.call(key)
		if fish:
			_pearls[fish] = saved.pearl_by[key]
	changed.emit()


## A player has left: their share stays in the team's totals.
func forget(fish: Object) -> void:
	_battered.erase(fish)
	_pearls.erase(fish)
