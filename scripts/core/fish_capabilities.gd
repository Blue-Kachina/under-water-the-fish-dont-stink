class_name FishCapabilities
extends RefCounted
## A fish's capabilities a mode can switch off for a while and get back exactly
## as they were: push("hunt", {"boost": false}) saves the fish's current values
## and applies the new ones; pop("hunt") restores what that push saved. Replaces
## the "boost_before" / "surface_before" metas and ignore_jump pokes. Pops
## should come in reverse order of the pushes (each restores its own save).
##
## Keys: boost (boost_enabled), surface (rl_surface_mechanics), jump (not
## ignore_jump), strokes (swim_strokes).

const PROPERTIES := {"boost": "boost_enabled", "surface": "rl_surface_mechanics", "jump": "ignore_jump", "strokes": "swim_strokes"}

var _fish: FishController
var _saved := {}  # name -> {property -> value before the push}


func _init(fish: FishController) -> void:
	_fish = fish


## Applies `set` ({key: bool}) under `name`. A second push of the same name keeps the first save.
func push(name: String, set: Dictionary) -> void:
	var saved: Dictionary = _saved.get(name, {})
	for key: String in set:
		var property: String = PROPERTIES[key]
		if not saved.has(property):
			saved[property] = _fish.get(property)
		_fish.set(property, (not set[key]) if key == "jump" else set[key])
	_saved[name] = saved


## Puts back what `name`'s push saved.
func pop(name: String) -> void:
	if not _saved.has(name):
		return
	for property: String in _saved[name]:
		_fish.set(property, _saved[name][property])
	_saved.erase(name)


func has(name: String) -> bool:
	return _saved.has(name)
