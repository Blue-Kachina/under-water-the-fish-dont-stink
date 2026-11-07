class_name WhatStinksField
extends Node3D
## What Stinks?'s fixed arena (what_stinks.md section 8): the schools, placed
## once around the Ocean at a round's start (no respawn relative to the players
## as NatureRun does) and drifting between waypoints inside the murk wall.
## Each is a School with settings of its own (its size is its own
## fish_per_school), so the field is just placement, drift, and the bite's
## picking of which fish go (eat_at). The wall itself is the Ocean's
## boundary_radius (WhatStinksMatch sets it and pushes fish back in).
##
## Everything random comes from `rng`, so the same seed gives the same ocean.

signal school_eaten(school: School, count: int)
## Online (the host's): a school appeared mid-round (a replacement), or went (wiped out).
signal school_added(school: School)
signal school_removed(id: int)

var settings := WhatStinksSettings.shared()
## False on an online guest: its schools follow the host's (leader, fish alive, new and gone ones).
var authority := true
var schools: Array[School] = []
var center := Vector3.ZERO
var rng := RandomNumberGenerator.new()
## What schools take fright of (the Hunter, when it's one).
var threats: Array[FishController] = []
## The schools' alarm range x this (the Hunter's size).
var alarm_scale := 1.0
## The classes the prey play, for build() to make schools of (empty: any class).
var prey_kinds: Array[FishCharacter.FishClass] = []

## Upset Stomach: schools come back steadily (regrow, and replace the wiped-out).
var steady := false

var _next_id := 0
var _regrow := 0.0
## Seconds until each replacement school appears.
var _replacements: Array[float] = []


## Places the schools (replacing any there): `school_count` of them, each
## school_min..school_max fish, a random kind, spread through the arena.
func build(middle: Vector3, rng_seed := -1) -> void:
	clear()
	center = middle
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var kinds := FishCharacter.pickable_classes()
	# Schools of the classes the prey play come first (one each, then round again),
	# up to school_prey_share of them; the rest are filler of any class.
	var prey_schools := ceili(settings.school_count * settings.school_prey_share) if not prey_kinds.is_empty() else 0
	for i in settings.school_count:
		# Spread by area (sqrt) inside 85% of the wall, so none start against it.
		var flat := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * settings.arena_radius * 0.85
		var at := center + Vector3(flat.x, rng.randf_range(-6.0, 6.0), flat.y)
		var heading := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
		var kind: FishCharacter.FishClass = kinds[rng.randi_range(0, kinds.size() - 1)]
		if i < prey_schools:
			kind = prey_kinds[i % prey_kinds.size()]
		var count := rng.randi_range(mini(settings.school_min, settings.school_max), maxi(settings.school_min, settings.school_max))
		add_school(at, heading, kind, count, rng.randi() & 0x7fffffff)


## A guest's schools as the host has them: [[id, seed, class, count, at, heading], ...].
func build_list(middle: Vector3, list: Array) -> void:
	clear()
	center = middle
	for entry: Array in list:
		add_school(entry[4], entry[5], int(entry[2]) as FishCharacter.FishClass, int(entry[3]), int(entry[1]), int(entry[0]))


## A guest: the host's school `id` is gone.
func remove_school(id: int) -> void:
	var school := school_by_id(id)
	if school != null:
		schools.erase(school)
		school.queue_free()


func school_by_id(id: int) -> School:
	for school in schools:
		if is_instance_valid(school) and school.id == id:
			return school
	return null


## One school of `count` fish at `at` (`force_id`: the host's id for it, on a guest).
func add_school(at: Vector3, heading: Vector3, kind: FishCharacter.FishClass, count: int, school_seed: int, force_id := -1) -> School:
	var school_settings: NatureSettings = NatureSettings.shared().duplicate()
	school_settings.fish_per_school = count
	school_settings.roam_radius = settings.school_roam
	school_settings.school_speed = settings.school_speed
	school_settings.fish_scale = settings.fish_scale
	var school := School.new()
	var id := force_id if force_id >= 0 else _next_id
	school.name = "School%d" % id
	school.id = id
	_next_id = maxi(_next_id, id + 1)
	school.threats.assign(threats)
	add_child(school)
	school.set_meta("ws_bait", school_settings.bait_range)
	school_settings.bait_range *= alarm_scale
	school.setup(school_settings, at, heading, kind, school_seed)
	school.set_meta("ws_full", count)
	school.set_meta("ws_at", at)
	school.set_meta("ws_heading", heading)
	schools.append(school)
	return school


func clear() -> void:
	for school in schools:
		if is_instance_valid(school):
			school.queue_free()
	schools.clear()
	_replacements.clear()
	_regrow = 0.0
	_next_id = 0


## Makes `fish` what the schools fear (the Hunter); an empty list: nothing.
func set_threats(fish: Array[FishController]) -> void:
	threats.assign(fish)
	for school in schools:
		school.threats.assign(threats)


## The schools' alarm range x `scale` (the Hunter's size, HunterSize.alarm_radius); new schools take it too.
func set_alarm_scale(scale: float) -> void:
	alarm_scale = scale
	for school in schools:
		school.settings.bait_range = float(school.get_meta("ws_bait", school.settings.bait_range)) * scale


func _physics_process(delta: float) -> void:
	if not authority:
		return
	if steady:
		_respawn(delta)
	for school in schools:
		if school.alive_count() == 0:
			continue
		# Drift: each time the leader reaches its spot around home, home moves on
		# to a new waypoint inside the wall, and a spot around that is picked.
		if school.leader_position.distance_to(school.home) < maxf(school.radius(), 12.0):
			school.home = _waypoint(school.home)
			school.pick_spot()


## Steady respawn (Upset Stomach): schools below their first size gain respawn_batch
## fish every respawn_every s (swimming with the school), and a school wiped out is
## replaced, after respawn_school_delay, by a new one away from the Hunters.
func _respawn(delta: float) -> void:
	if settings.respawn_every <= 0.0:
		return
	for i in range(schools.size() - 1, -1, -1):
		if schools[i].alive_count() == 0 and schools[i].claimed_count() == 0:
			var gone_id := schools[i].id
			schools[i].queue_free()
			schools.remove_at(i)
			school_removed.emit(gone_id)
			_replacements.append(settings.respawn_school_delay)
	for i in range(_replacements.size() - 1, -1, -1):
		_replacements[i] -= delta
		if _replacements[i] <= 0.0:
			_replacements.remove_at(i)
			_replace_school()
	_regrow += delta
	if _regrow < settings.respawn_every:
		return
	_regrow = 0.0
	for school in schools:
		var room := int(school.get_meta("ws_full", school.alive_count())) - school.alive_count()
		var add := mini(settings.respawn_batch, room)
		if add > 0 and school.alive_count() > 0:
			school.settings.fish_per_school = school.fish_count() + add


## A new school, as build() makes them, at least respawn_school_gap from every threat.
func _replace_school() -> void:
	var at := center
	for attempt in 12:
		var flat := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * settings.arena_radius * 0.85
		at = center + Vector3(flat.x, rng.randf_range(-6.0, 6.0), flat.y)
		var clear := true
		for threat in threats:
			if is_instance_valid(threat) and threat.global_position.distance_to(at) < settings.respawn_school_gap:
				clear = false
		if clear:
			break
	var kinds := FishCharacter.pickable_classes()
	var kind: FishCharacter.FishClass = kinds[rng.randi_range(0, kinds.size() - 1)]
	if not prey_kinds.is_empty() and rng.randf() < settings.school_prey_share:
		kind = prey_kinds[rng.randi_range(0, prey_kinds.size() - 1)]
	var heading := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
	var count := rng.randi_range(mini(settings.school_min, settings.school_max), maxi(settings.school_min, settings.school_max))
	school_added.emit(add_school(at, heading, kind, count, rng.randi() & 0x7fffffff))


## What one fish of `school` is worth to a Hunter's stomach (1: a fish of satiation_ref_length).
func fish_mass(school: School) -> float:
	var length := FishCharacter.hitbox_size(school.character).z
	var mass := pow(length / maxf(settings.satiation_ref_length, 0.001), settings.satiation_size_exp)
	if settings.satiation_uses_fish_scale:
		mass *= school.settings.fish_scale
	return mass


func _waypoint(from: Vector3) -> Vector3:
	var flat := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 1.0) * maxf(settings.school_roam, 10.0) * 1.5
	var at := from + Vector3(flat.x, rng.randf_range(-4.0, 4.0), flat.y)
	var out := Vector2(at.x - center.x, at.z - center.z)
	var limit := settings.arena_radius * 0.8
	if out.length() > limit:
		out = out.normalized() * limit
	return Vector3(center.x + out.x, clampf(at.y, center.y - 12.0, center.y + 12.0), center.z + out.y)


## Fish left across every school.
func alive_total() -> int:
	var total := 0
	for school in schools:
		total += school.alive_count()
	return total


## The live school fish nearest `point` as [school, index, position], or [] with none.
func nearest_fish(point: Vector3) -> Array:
	var best := []
	var best_gap := INF
	for school in schools:
		if school.alive_count() == 0:
			continue
		for i in school.fish_count():
			if not school.is_alive(i):
				continue
			var at := school.fish_position(i)
			var gap := at.distance_squared_to(point)
			if gap < best_gap:
				best_gap = gap
				best = [school, i, at]
	return best


## The school with the most fish left whose middle is nearest `point` among ties
## (null with none): what a bot Hunter heads for.
func biggest_school(point: Vector3) -> School:
	var best: School
	var best_score := -INF
	for school in schools:
		var alive := school.alive_count()
		if alive == 0:
			continue
		var score := float(alive) - school.middle().distance_to(point) * 0.05
		if score > best_score:
			best_score = score
			best = school
	return best


## A bite at `bite_point` (world) takes up to `capacity` of the fish `inside`
## says are in it (a Callable(position) -> bool), the nearest `bite_point` first
## (ties random). `extra` (prey players' fish) compete with the school fish for
## the places, by their own distance. Eats the school fish it picked (School.eat,
## the survivors panic and scatter) and returns what went:
## {"fish": [FishController...], "school_fish": int, "mass": float (their size worth), "spots": PackedVector3Array}.
func eat_at(bite_point: Vector3, capacity: int, inside: Callable, extra: Array = []) -> Dictionary:
	var found: Array = []  # [gap, school (or null), index, fish (or null)]
	for school in schools:
		for i in school.fish_count():
			# A joined player's place is the player's fish (in `extra`), not a school fish.
			if not school.is_alive(i) or school.is_claimed(i):
				continue
			var at := school.fish_position(i)
			if inside.call(at):
				found.append([at.distance_to(bite_point) + rng.randf() * 0.001, school, i, null])
	for fish: Variant in extra:
		var prey := fish as FishController
		if prey and is_instance_valid(prey) and not prey.battered and inside.call(prey.global_position):
			found.append([prey.global_position.distance_to(bite_point) + rng.randf() * 0.001, null, -1, prey])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var taken: Dictionary = {}  # school -> [indices]
	var players: Array[FishController] = []
	var placed := 0  # joined players eaten with their places
	var mass := 0.0  # what the school fish taken are worth to a stomach
	for entry in found.slice(0, maxi(capacity, 0)):
		if entry[3] != null:
			players.append(entry[3])
			# A joined player goes with its place (the school's fish goes too, and its survivors panic).
			for school in schools:
				var place := school.claim_of(entry[3])
				if place >= 0:
					var held: Array = taken.get(school, [])
					held.append(place)
					taken[school] = held
					placed += 1
		else:
			var list: Array = taken.get(entry[1], [])
			list.append(entry[2])
			taken[entry[1]] = list
			mass += fish_mass(entry[1])
	var spots := PackedVector3Array()
	var count := 0
	var by_id := {}  # school id -> [indices, the school's rng state], for a guest to eat the same
	for school: School in taken:
		var list: Array = taken[school]
		by_id[school.id] = [list.duplicate(), school.rng.state]  # the state too: the survivors scatter the same way on a guest
		spots.append_array(school.eat(list, settings.eat_burst_mult, settings.eat_radius_mult, settings.eat_groups, settings.reform_time))
		count += list.size()
		school_eaten.emit(school, list.size())
	return {"fish": players, "school_fish": count - placed, "mass": mass, "spots": spots, "taken": by_id}

## A guest eats what the host's bite took (the same indices): `by_id` is eat_at's "taken".
func eat_taken(by_id: Dictionary) -> void:
	for id: Variant in by_id:
		var school := school_by_id(int(id))
		if school == null:
			continue
		var list: Array = (by_id[id] as Array)[0]
		school.rng.state = int((by_id[id] as Array)[1])
		school.eat(list, settings.eat_burst_mult, settings.eat_radius_mult, settings.eat_groups, settings.reform_time)
		school_eaten.emit(school, list.size())
