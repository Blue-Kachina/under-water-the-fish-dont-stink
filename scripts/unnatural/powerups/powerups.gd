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
## drops powerups to match. Their stats (Powerup.stat_bonus()) go on the
## player's StatBlock when anything changed.
func refresh() -> void:
	var changed := false
	for id in Powerup.ids():
		var wanted := maxi(_earned.get(id, 0), settings.stacks_override(id))
		var powerup: Powerup = held.get(id)
		if wanted <= 0:
			if powerup:
				powerup.on_removed()
				powerup.take_off()
				held.erase(id)
				changed = true
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
			powerup.wear()  # every powerup is worn on the fish
			changed = true
	if changed:
		_update_bonus()


## The stats every powerup held gives, on the player's StatBlock (and on their
## attack, swim and max hp).
func _update_bonus() -> void:
	var bonus := {}
	for id: String in held:
		var gives := (held[id] as Powerup).stat_bonus()
		for stat: String in gives:
			bonus[stat] = bonus.get(stat, 0.0) + gives[stat]
	if bonus.is_empty() and not run._blocks.has(fish):
		return  # gone (the player left): nothing to take off
	var block := run.block_of(fish)
	if block.bonus != bonus:
		block.bonus = bonus
		run._apply_stats(fish)


## Everything gone (a restart, the run's end).
func clear() -> void:
	for id: String in held:
		(held[id] as Powerup).on_removed()
		(held[id] as Powerup).take_off()
	held.clear()
	_earned.clear()
	_update_bonus()


## Whether a powerup takes this hit instead of the fish (Bubble Wrap): the
## first that can, does.
func blocks_hit(amount: float) -> bool:
	for id: String in held:
		if (held[id] as Powerup).blocks_hit(amount):
			return true
	return false


## The fish was hurt by `amount`, by zombie `from` (-1: not a zombie's touch).
func on_hurt(amount: float, from: int) -> void:
	for id: String in held:
		(held[id] as Powerup).on_hurt(amount, from)


## A stage event started (a swarm, a boss).
func on_stage_event(event: String) -> void:
	for id: String in held.keys():
		if held.has(id):
			(held[id] as Powerup).on_stage_event(event)


## What the damage the fish takes is multiplied by (Blood Moon Shard).
func taken_scale() -> float:
	var scale := 1.0
	for id: String in held:
		scale *= (held[id] as Powerup).taken_factor()
	return scale


## What the fish's max hp is multiplied by (Glass Coral).
func max_hp_scale() -> float:
	var scale := 1.0
	for id: String in held:
		scale *= (held[id] as Powerup).max_hp_factor()
	return scale


## How many more zombies come for this player's sake (Siren's Song).
func horde_scale() -> float:
	var scale := 1.0
	for id: String in held:
		scale *= (held[id] as Powerup).horde_factor()
	return scale


## One stack of `id` gone (Sunken Idol's toll). Testing overrides still hold.
func remove_stack(id: String) -> void:
	if _earned.get(id, 0) > 0:
		_earned[id] -= 1
		if _earned[id] <= 0:
			_earned.erase(id)
	refresh()


## The powerups earned from chests (ids), for something to take one of.
func earned() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _earned:
		ids.append(id)
	return ids


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
