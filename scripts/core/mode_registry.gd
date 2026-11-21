class_name ModeRegistry
extends RefCounted
## The ordered list of registered GameModes and the one that is playing. Ids
## not listed here fall through to main.gd's own code (modes not migrated yet).
## Registering a mode is one line in scripts().

## The active mode's node, null when none is playing.
var active: GameMode
var _active_id := ""
var _world: ModeWorld


## THE registry: one line per migrated mode.
static func scripts() -> Array[GDScript]:
	return [Match1v1, NatureRun, HuntMatch, UnnaturalRun, TestTankRun, CourseMode, MarcoPoloMatch, WhatStinksMatch]


static func descriptors() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for script: GDScript in scripts():
		out.append(script.call(&"descriptor"))
	return out


## The descriptor of mode `id` ({} when it isn't registered).
static func describe(id: String) -> Dictionary:
	for d in descriptors():
		if d.get("id", "") == id:
			return d
	return {}


static func has_mode(id: String) -> bool:
	return not describe(id).is_empty()


static func script_of(id: String) -> GDScript:
	for script: GDScript in scripts():
		if (script.call(&"descriptor") as Dictionary).get("id", "") == id:
			return script
	return null


## `core` (the ids main.gd still lists itself) with each registered mode
## inserted after its descriptor's "after" id (at the end without one).
## `only` limits it to descriptors with that key set true (e.g. "match").
static func merged(core: Array, only: String = "") -> Array:
	var out := core.duplicate()
	var placing: Array[Dictionary] = []
	for d in descriptors():
		if only == "" or d.get(only, false):
			placing.append(d)
	_place(out, placing, "after", 1)
	return out


## `core` (main.gd's own tiles) with each registered mode's descriptor as a
## tile, inserted before the tile its "tile_before" names (at the end without).
static func merged_tiles(core: Dictionary) -> Dictionary:
	var order: Array = core.keys()
	var tiles := core.duplicate()
	var placing := descriptors()
	for d in placing:
		tiles[d["id"]] = d
	_place(order, placing, "tile_before", 0)
	var out := {}
	for key: String in order:
		out[key] = tiles[key]
	return out


## Inserts each of `descs`' ids into `order` next to the id its `key` names (`offset` 1: after
## it, 0: before it), in registration order; one whose anchor is a registered mode not placed
## yet waits for it, so registration order doesn't matter. Without an anchor: at the end.
static func _place(order: Array, descs: Array[Dictionary], key: String, offset: int) -> void:
	var waiting := descs.duplicate()
	while not waiting.is_empty():
		var pending_ids := waiting.map(func(d: Dictionary) -> String: return d["id"])
		var left: Array[Dictionary] = []
		for d: Dictionary in waiting:
			var anchor: String = d.get(key, "")
			var at := order.find(anchor)
			if at >= 0:
				order.insert(at + offset, d["id"])
			elif anchor in pending_ids and anchor != d["id"]:
				left.append(d)
			else:
				order.append(d["id"])
		if left.size() == waiting.size():  # a loop of anchors: give up on them
			for d: Dictionary in left:
				order.append(d["id"])
			return
		waiting = left


## The body a registered mode builds for class `fish_class` (descriptor "models": a Callable(FishModel)),
## invalid when none does. FishModel.build asks before its own class switch.
static func model_provider(fish_class: int) -> Callable:
	for d in descriptors():
		var models: Dictionary = d.get("models", {})
		if models.has(fish_class):
			return models[fish_class]
	return Callable()


## The registered descriptors with a net adapter (descriptor "net").
static func net_descriptors() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in descriptors():
		if d.has("net"):
			out.append(d)
	return out


## `core` (environment name -> script) plus each registered descriptor's
## "environments" (the arenas that mode builds).
static func merged_environments(core: Dictionary) -> Dictionary:
	var out := core.duplicate()
	for d in descriptors():
		out.merge(d.get("environments", {}))
	return out


## The registered ids whose descriptor tunes with a preset (Nature's tuning).
static func tuned_ids() -> Array:
	var out := []
	for d in descriptors():
		if d.get("tuning_preset", "") != "":
			out.append(d["id"])
	return out


## Starts mode `id` in `world`: the node is made, entered, added under the
## environment, then started. Returns it.
func start(id: String, world: ModeWorld) -> GameMode:
	var script := script_of(id)
	if script == null:
		return null
	_world = world
	active = script.new()
	_active_id = id
	active.name = id
	active.enter(world)
	world.environment.add_child(active)
	active.start()
	return active


## Ends the active mode (end, free, release).
func end() -> void:
	if active == null:
		return
	var node := active
	active = null
	_active_id = ""
	node.end()
	node.queue_free()
	node.release()


func playing() -> bool:
	return active != null and active.playing()


func active_id() -> String:
	return _active_id
