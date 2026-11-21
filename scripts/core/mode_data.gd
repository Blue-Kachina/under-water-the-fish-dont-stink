class_name ModeData
extends RefCounted
## A mode's own notes on a core node (a fish): one Dictionary per mode id,
## kept behind the single meta key "mode_data" so a mode never tags a core
## node with keys of its own (planning_core_roadmap.md 3.2: ModeData replaces
## the ws_* / mp_* / coop_index metas). Works for any fish, slot-owned or not
## (bots, puppets); PlayerSlot.mode_data(mode_id) is the same dictionary for its fish.
##   ModeData.set_value(fish, "what_stinks", "bite", bite)
##   ModeData.get_value(fish, "what_stinks", "bite")
##
## Convention for a mode that puts a fish in another body (Marco Polo's whale,
## What Stinks?'s Hunter): set "swapped" true and "base_look" to the fish's own
## [class, species, ...] first. Core then finds the player's own look with
## swapped_look() without naming any mode (Change Character, the online roster).

const META := "mode_data"


## `node`'s whole bag: mode id -> Dictionary (made when `create`).
static func bag(node: Object, create := false) -> Dictionary:
	if node == null:
		return {}
	if node.has_meta(META):
		return node.get_meta(META)
	var fresh := {}
	if create:
		node.set_meta(META, fresh)
	return fresh


## The dictionary of mode `id` on `node` (made on first use).
static func of(node: Object, id: String) -> Dictionary:
	return bag(node, true).get_or_add(id, {})


static func has_value(node: Object, id: String, key: String) -> bool:
	return (bag(node).get(id, {}) as Dictionary).has(key)


static func get_value(node: Object, id: String, key: String, default: Variant = null) -> Variant:
	return (bag(node).get(id, {}) as Dictionary).get(key, default)


static func set_value(node: Object, id: String, key: String, value: Variant) -> void:
	of(node, id)[key] = value


static func erase(node: Object, id: String, key: String) -> void:
	(bag(node).get(id, {}) as Dictionary).erase(key)


## Same as erase().
static func erase_value(node: Object, id: String, key: String) -> void:
	erase(node, id, key)


## Drops everything `id` kept on `node`.
static func clear(node: Object, id: String) -> void:
	bag(node).erase(id)


## The id of the first mode whose dictionary on `node` has `key` set true ("" when none): the
## core asks "is a mode holding this fish in another body" without naming modes. The keys
## the core reads: "swapped" (true while the mode has the player in another body) and
## "base_look" ([class, species, skin] of their own).
static func mode_with(node: Object, key: String) -> String:
	var all := bag(node)
	for id: String in all:
		if bool((all[id] as Dictionary).get(key, false)):
			return id
	return ""


## The id of the mode that has `fish` in another body ("" when it wears its own).
static func swapped_owner(fish: Object) -> String:
	return mode_with(fish, "swapped")


## The look `fish` wore before the mode swapped its body ([class, species, ...]),
## or an empty array.
static func swapped_look(fish: Object) -> Array:
	var owner_id := swapped_owner(fish)
	if owner_id == "":
		return []
	return (bag(fish)[owner_id] as Dictionary).get("base_look", [])
