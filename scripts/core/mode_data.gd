class_name ModeData
extends RefCounted
## Per-fish scratch data a mode keeps about a player or bot, keyed by the mode's
## id (planning_core_roadmap.md 3.2: replaces the mp_* / ws_* set_meta keys on
## core nodes). The one core-owned tag is META on the fish; a mode reads and
## writes only its own id's bag. PlayerSlot.mode_data() is the same bag from a
## local player's slot.
##
## Convention for a mode that puts a fish in another body (Marco Polo's whale,
## What Stinks?'s Hunter): set "swapped" true and "base_look" to the fish's own
## [class, species, ...] first. Core then finds the player's own look with
## swapped_look() without naming any mode (Change Character, the online roster).

const META := &"mode_data"


## `fish`'s whole bag: mode id -> Dictionary (made when `create`).
static func bag(fish: Object, create := false) -> Dictionary:
	if fish == null:
		return {}
	if fish.has_meta(META):
		return fish.get_meta(META)
	var fresh := {}
	if create:
		fish.set_meta(META, fresh)
	return fresh


static func get_value(fish: Object, mode_id: String, key: String, default: Variant = null) -> Variant:
	var mine: Dictionary = bag(fish).get(mode_id, {})
	return mine.get(key, default)


static func has_value(fish: Object, mode_id: String, key: String) -> bool:
	var mine: Dictionary = bag(fish).get(mode_id, {})
	return mine.has(key)


static func set_value(fish: Object, mode_id: String, key: String, value: Variant) -> void:
	var all := bag(fish, true)
	if not all.has(mode_id):
		all[mode_id] = {}
	(all[mode_id] as Dictionary)[key] = value


static func erase_value(fish: Object, mode_id: String, key: String) -> void:
	var mine: Dictionary = bag(fish).get(mode_id, {})
	mine.erase(key)


## Drops everything `mode_id` kept on `fish`.
static func clear(fish: Object, mode_id: String) -> void:
	bag(fish).erase(mode_id)


## The id of the mode that has `fish` in another body ("" when it wears its own).
static func swapped_owner(fish: Object) -> String:
	for mode_id: String in bag(fish):
		if bool((bag(fish)[mode_id] as Dictionary).get("swapped", false)):
			return mode_id
	return ""


## The look `fish` wore before the mode swapped its body ([class, species, ...]),
## or an empty array.
static func swapped_look(fish: Object) -> Array:
	var owner_id := swapped_owner(fish)
	if owner_id == "":
		return []
	return (bag(fish)[owner_id] as Dictionary).get("base_look", [])
