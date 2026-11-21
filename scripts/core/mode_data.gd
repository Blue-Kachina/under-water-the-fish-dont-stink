class_name ModeData
extends RefCounted
## A mode's own notes on a core node (a fish): one Dictionary per mode id,
## kept behind the single meta key "mode_data" so a mode never tags a core
## node with keys of its own (planning_core_roadmap.md 3.2: ModeData replaces
## the ws_* / mp_* / coop_index metas). Works for any fish, slot-owned or not
## (bots, puppets); PlayerSlot.data(mode_id) is the same dictionary for its fish.
##   ModeData.set_value(fish, "what_stinks", "bite", bite)
##   ModeData.get_value(fish, "what_stinks", "bite")

const META := "mode_data"


## The dictionary of mode `id` on `node` (made on first use).
static func of(node: Object, id: String) -> Dictionary:
	var all: Dictionary
	if node.has_meta(META):
		all = node.get_meta(META)
	else:
		all = {}
		node.set_meta(META, all)
	if not all.has(id):
		all[id] = {}
	return all[id]


static func has_value(node: Object, id: String, key: String) -> bool:
	return node.has_meta(META) and (node.get_meta(META) as Dictionary).get(id, {}).has(key)


static func get_value(node: Object, id: String, key: String, default: Variant = null) -> Variant:
	if not node.has_meta(META):
		return default
	return (node.get_meta(META) as Dictionary).get(id, {}).get(key, default)


static func set_value(node: Object, id: String, key: String, value: Variant) -> void:
	of(node, id)[key] = value


static func erase(node: Object, id: String, key: String) -> void:
	if node.has_meta(META):
		((node.get_meta(META) as Dictionary).get(id, {}) as Dictionary).erase(key)


## The id of the first mode whose dictionary on `node` has `key` set true ("" when none): the
## core asks "is a mode holding this fish in another body" without naming modes. The keys
## the core reads: "swapped" (true while the mode has the player in another body) and
## "base_look" ([class, species, skin] of their own).
static func mode_with(node: Object, key: String) -> String:
	if not node.has_meta(META):
		return ""
	var all: Dictionary = node.get_meta(META)
	for id: String in all:
		if bool((all[id] as Dictionary).get(key, false)):
			return id
	return ""
