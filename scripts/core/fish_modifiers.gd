class_name FishModifiers
extends RefCounted
## A fish's named multiplicative modifiers: a mode pushes a set under its own
## name (push("unnatural.size", {"speed": 1.2, "stride": 1.3})) and pops it when
## done. Each key's product over every pushed set is written to the fish's
## matching `<key>_scale` field (speed, stride, bow, body, hitbox, top_speed,
## boost, accel, turn, rl_turn, drag), which stay the read-out the fish's code
## uses. A key nobody has pushed is left to whoever writes the field directly
## (modes not migrated yet); after a push and the matching pop it is 1.0 again.

var _fish: FishController
var _sets := {}  # name -> {key -> factor}


func _init(fish: FishController) -> void:
	_fish = fish


## Pushes (or replaces) the set `name`.
func push(name: String, factors: Dictionary) -> void:
	var touched := {}
	if _sets.has(name):
		for key: String in _sets[name]:
			touched[key] = true
	_sets[name] = factors.duplicate()
	for key: String in factors:
		touched[key] = true
	_apply(touched.keys())


## Removes the set `name` (no-op when it isn't pushed).
func pop(name: String) -> void:
	if not _sets.has(name):
		return
	var touched: Array = (_sets[name] as Dictionary).keys()
	_sets.erase(name)
	_apply(touched)


func has(name: String) -> bool:
	return _sets.has(name)


## The product of every pushed factor for `key` (1.0 with none).
func factor(key: String) -> float:
	var product := 1.0
	for factors: Dictionary in _sets.values():
		product *= float(factors.get(key, 1.0))
	return product


func _apply(keys: Array) -> void:
	for key: String in keys:
		_fish.set(key + "_scale", factor(key))
