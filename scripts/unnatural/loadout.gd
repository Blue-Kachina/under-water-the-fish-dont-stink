class_name Loadout
extends RefCounted
## A player's weapons and tomes in Unnatural (planning_unnatural.md,
## "Playability pass" P1, D17): weapon_slots weapons (Weapons; the fish's own
## attack is always the first) and tome_slots tomes (Tomes), each with its
## level. A weapon's level is 1 + the upgrades it's had, and each upgrade
## raised some of its facets (Weapons.roll): facet() is a facet's total.
##
## For testing, PowerupSettings' level override for a weapon (its `stacks`
## setting, or attack_level for the attack) lifts its level: a weapon held
## below it acts at that level, its facets spread evenly over its upgrades.

var weapons: Array[String] = [Weapons.ATTACK]
var tomes: Array[String] = []
## Weapon id -> level (earned), and -> {facet id: total}.
var _levels := {Weapons.ATTACK: 1}
var _facets := {Weapons.ATTACK: {}}
var _tome_levels := {}
## The fish's attack's kind (its facets depend on it).
var attack_kind := FishAttack.Kind.BITE
var powerup_settings := PowerupSettings.shared()
## A powerup weapon held in place of the fish's own attack ("": it has one).
var starting := ""


func reset() -> void:
	var first := starting if starting != "" else Weapons.ATTACK
	weapons = [first]
	tomes = []
	_levels = {first: 1}
	_facets = {first: {}}
	_tome_levels = {}


func has_weapon(id: String) -> bool:
	return id in weapons


func has_tome(id: String) -> bool:
	return id in tomes


## A new weapon at `at_level` (its facets spread evenly over the upgrades below
## it), plus `gains` (facet id -> amount: a new weapon card's rolled rarity).
func add_weapon(id: String, at_level := 1, gains := {}) -> void:
	if not has_weapon(id):
		weapons.append(id)
	_levels[id] = maxi(at_level, 1)
	var held := _spread(id, at_level)
	for facet: String in gains:
		held[facet] = held.get(facet, 0.0) + float(gains[facet])
	_facets[id] = held


## Weapon `id` gone (swapped out for a boss weapon).
func remove_weapon(id: String) -> void:
	if id == Weapons.ATTACK or id == starting:
		return
	weapons.erase(id)
	_levels.erase(id)
	_facets.erase(id)


## Weapon `id` one level up, its facets raised by `gains` (facet id -> amount).
func upgrade_weapon(id: String, gains: Dictionary) -> void:
	if not has_weapon(id):
		add_weapon(id)
		return
	_levels[id] = earned_level(id) + 1
	var held: Dictionary = _facets.get(id, {})
	for facet: String in gains:
		held[facet] = held.get(facet, 0.0) + float(gains[facet])
	_facets[id] = held


func add_tome(id: String) -> void:
	if not has_tome(id):
		tomes.append(id)
	_tome_levels[id] = tome_level(id) + 1


func tome_level(id: String) -> int:
	return _tome_levels.get(id, 0)


## Weapon `id`'s level as earned (0: not held).
func earned_level(id: String) -> int:
	return _levels.get(id, 0) if has_weapon(id) else 0


## Weapon `id`'s level now: earned, or the testing override if that's more.
func level(id: String) -> int:
	return maxi(earned_level(id), override_level(id))


func override_level(id: String) -> int:
	if id == Weapons.ATTACK:
		return powerup_settings.attack_level
	return powerup_settings.stacks_override(id)


## Facet `facet` of weapon `id`: its total from the upgrades (or, under a
## higher testing override, spread evenly).
func facet(id: String, facet_id: String) -> float:
	var override := override_level(id)
	if override > earned_level(id):
		return _spread(id, override).get(facet_id, 0.0)
	return (_facets.get(id, {}) as Dictionary).get(facet_id, 0.0)


## Every facet of weapon `id` with its total.
func facets_of(id: String) -> Dictionary:
	var all := {}
	for entry: Array in Weapons.facets(id, attack_kind):
		all[entry[0]] = facet(id, entry[0])
	return all


## The weapons below the cap, for upgrade cards.
func upgradable_weapons(cap: int) -> Array[String]:
	var list: Array[String] = []
	for id in weapons:
		if earned_level(id) < cap:
			list.append(id)
	return list


func upgradable_tomes(cap: int) -> Array[String]:
	var list: Array[String] = []
	for id in tomes:
		if tome_level(id) < cap:
			list.append(id)
	return list


## Facets for `levels` levels' worth of common upgrades, spread one facet at a
## time in turn (a testing override, or a weapon arriving above Lv 1).
func _spread(id: String, at_level: int) -> Dictionary:
	var list := Weapons.facets(id, attack_kind)
	var spread := {}
	if list.is_empty():
		return spread
	for n in maxi(at_level - 1, 0):
		var entry: Array = list[n % list.size()]
		spread[entry[0]] = spread.get(entry[0], 0.0) + Weapons.step_amount(entry, 1.0, powerup_settings)
	return spread


## The fish starts with weapon `id` (a powerup) instead of an attack of its own.
func start_with(id: String) -> void:
	starting = id
	reset()
