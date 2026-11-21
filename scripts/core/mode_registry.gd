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
	return [NatureRun, HuntMatch]


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
	for d in descriptors():
		if only != "" and not d.get(only, false):
			continue
		var at: int = out.find(d.get("after", ""))
		if at < 0:
			out.append(d["id"])
		else:
			out.insert(at + 1, d["id"])
	return out


## `core` (main.gd's own tiles) with each registered mode's descriptor as a
## tile, inserted before the tile its "tile_before" names (at the end without).
static func merged_tiles(core: Dictionary) -> Dictionary:
	var order: Array = core.keys()
	var tiles := core.duplicate()
	for d in descriptors():  # in registration order: a "tile_before" may name an earlier registered mode
		var at: int = order.find(d.get("tile_before", ""))
		if at < 0:
			order.append(d["id"])
		else:
			order.insert(at, d["id"])
		tiles[d["id"]] = d
	var out := {}
	for key: String in order:
		out[key] = tiles[key]
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
