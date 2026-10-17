class_name Powerups
extends RefCounted
## A player's powerups in Unnatural (planning_unnatural.md §7): each one held
## (Powerup) with its stacks, and the hooks fired on them all. Its stacks are
## what chests gave, or PowerupSettings' testing override if that's more.

var run: UnnaturalRun
var fish: FishController
var settings := PowerupSettings.shared()
## Id -> Powerup, in the order they were got.
var held := {}
## Id -> stacks got from chests.
var _earned := {}


func _init(owner_run: UnnaturalRun, owner_fish: FishController) -> void:
	run = owner_run
	fish = owner_fish


## One more stack of `id`.
func add(id: String) -> void:
	_earned[id] = _earned.get(id, 0) + 1
	refresh()


func stacks(id: String) -> int:
	var powerup: Powerup = held.get(id)
	return powerup.stacks if powerup else 0


## Every powerup with its stacks, in order: [[id, stacks], ...].
func list() -> Array:
	var all := []
	for id: String in held:
		all.append([id, (held[id] as Powerup).stacks])
	return all


## Stacks from what was earned and the testing override; makes, updates or
## drops powerups to match.
func refresh() -> void:
	for id in Powerup.ids():
		var wanted := maxi(_earned.get(id, 0), settings.stacks_override(id))
		var powerup: Powerup = held.get(id)
		if wanted <= 0:
			if powerup:
				powerup.on_removed()
				held.erase(id)
			continue
		if powerup == null:
			powerup = Powerup.create(id)
			powerup.run = run
			powerup.fish = fish
			powerup.settings = settings
			held[id] = powerup
		if powerup.stacks != wanted:
			powerup.stacks = wanted
			powerup.on_stacks_changed()


## Everything gone (a restart, the run's end).
func clear() -> void:
	for id: String in held:
		(held[id] as Powerup).on_removed()
	held.clear()
	_earned.clear()


func on_hit(index: int, damage: float, source: String, proc: float, chain: Array) -> void:
	for id: String in held:
		if id not in chain:
			(held[id] as Powerup).on_hit(index, damage, source, proc, chain)


func on_kill(at: Vector3, source: String) -> void:
	for id: String in held:
		(held[id] as Powerup).on_kill(at, source)


func on_battery(index: int) -> void:
	for id: String in held:
		(held[id] as Powerup).on_battery(index)


func on_tick(delta: float) -> void:
	for id: String in held:
		(held[id] as Powerup).on_tick(delta)


func on_stride(timing: float) -> void:
	for id: String in held:
		(held[id] as Powerup).on_stride(timing)


## The battering speed's share with Bow Grow Bow's low-speed batteries (1 without).
func batter_speed_share() -> float:
	var bow: Powerup = held.get("bow_grow_bow")
	if bow and bow.stacks >= settings.bow_low_speed_stacks:
		return settings.bow_low_speed
	return 1.0
