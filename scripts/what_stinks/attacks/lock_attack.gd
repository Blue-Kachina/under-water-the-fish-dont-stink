class_name LockAttack
extends HunterAttack
## The Fallen Angel's style (two-stage-attack.md 4c): the press only takes with a fish ahead, then it is a full lock.
##
## The gate: a school fish or prey player within angel_lock_range x reach of the mouth and inside angel_lock_cone of
## the nose. Otherwise the press is denied (the crown flickers, a sound, no cooldown). The nearest such fish at the
## press is the target and stays the target for the whole hold.
## Held: the angel matches the target's pace, holds a stand-off (angel_standoff x reach) from it and pivots to keep
## facing it. The player does not steer the nose: the stick orbits the angel round the target. AngelRig moves its
## lock-on ring onto the target (with a line from the crown and the count the release would take: "x5").
## The count (D6): capacity x angel_count_mult x how squarely the angel faces the mass of the target's school (and a
## share for the charge), at least the target; the camera's lock-on bite on the same school multiplies on top (D8).
## The fish taken are the target and then the nearest of its school. The lock snaps (angel_break_range, or the target
## eaten): the crown closes empty after angel_break_cooldown.
##
## The owning machine does all of this (a puppet is only the pose); a guest reports its target with the landing
## (net_extra) and the host judges it from that, with its own count (net_catch_rule).

## Seconds since a denied press, and since the lock last snapped / landed (large: not lately).
var denied_age := 99.0
var lost_age := 99.0
var landed_age := 99.0
## Where the target was when the lock last snapped / the lash landed (the ring's burst).
var last_at := Vector3.ZERO
## What the release would take now, and where the fish besides the target are (the rig highlights them).
var count_now := 1
var mates_at := PackedVector3Array()
## Distances (m) from the mouth of the fish the last catch rule took, nearest first (the crunch delays).
var gaps: Array[float] = []

var _school: School
var _index := -1
var _prey: FishController
var _dir := Vector3.BACK
var _dist := 0.0
var _gate := {}
var _refresh := 0.0
var _clock := 0.0


func _init() -> void:
	key = "lock"


## Whether a target is locked now.
func active() -> bool:
	return _school != null or _prey != null


## The target's place now (world), or Vector3.INF when there is none.
func target_at() -> Vector3:
	if _prey != null:
		return _prey.global_position
	if _school != null and is_instance_valid(_school):
		return _school.fish_position(_index)
	return Vector3.INF


## The ring's place: the target while locked, the spot the lash landed on (for a moment), else Vector3.INF.
func ring_at(lash_time: float) -> Vector3:
	if active():
		return target_at()
	if landed_age < lash_time:
		return last_at
	if lost_age < 0.4:
		return last_at
	return Vector3.INF


func can_open(bite: HunterBite) -> bool:
	if bite.world == null or bite.fish.puppet:
		return true  # no field to read (a probe, a puppet's pose): it opens like the chomp, locked on nothing
	_gate = _pick(bite)
	return not _gate.is_empty()


func on_denied(bite: HunterBite) -> void:
	denied_age = 0.0
	bite.fx().denied()


func on_open(bite: HunterBite) -> void:
	_clear()
	if bite.fish.puppet or bite.world == null:
		return
	if _gate.is_empty():
		_gate = _pick(bite)
	if _gate.is_empty():
		return
	_school = _gate.get("school")
	_index = int(_gate.get("index", -1))
	_prey = _gate.get("prey")
	_gate = {}
	var at := target_at()
	var offset := bite.fish.global_position - at
	_dist = maxf(offset.length(), 0.01)
	_dir = offset / _dist if offset.length() > 0.01 else bite.fish.global_basis.z.normalized()
	_refresh = 0.0
	_update_preview(bite)


func on_hold(bite: HunterBite, _delta: float) -> void:
	if not active() or bite.fish.puppet:
		return
	var settings := bite.settings
	var reach := bite.size.bite_reach(bite.fish, bite.form)
	if not _alive(bite) or bite.fish.global_position.distance_to(target_at()) > settings.angel_break_range * reach:
		_snap(bite)


func on_tick(bite: HunterBite, delta: float) -> void:
	denied_age += delta
	lost_age += delta
	landed_age += delta
	_clock += delta
	if not active() or bite.fish.puppet:
		return
	if not _alive(bite):
		return  # held: on_hold snaps the lock; striking: the lash lands on what is left
	_follow(bite, delta)
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.08
		_update_preview(bite)


func catch_rule(bite: HunterBite) -> Dictionary:
	gaps.clear()
	var forward := -bite.fish.global_basis.z.normalized()
	if not active() or not _alive(bite):
		return frustum_rule(bite, bite.mouth_point(), forward, bite.strike_charge())
	return _build(bite, _school, _index, _prey, bite.mouth_point(), forward, bite.strike_charge())


## The host: the guest's target from what it reported (net_extra), else the plain cone.
func net_catch_rule(bite: HunterBite, mouth: Vector3, forward: Vector3, charge: float, extra: Dictionary) -> Dictionary:
	gaps.clear()
	var field: WhatStinksField = bite.world.get("field") if bite.world != null else null
	if field != null:
		var reach := bite.size.bite_reach(bite.fish, bite.form)
		var span := bite.settings.angel_break_range * reach
		if extra.has("school"):
			var school := field.school_by_id(int(extra["school"]))
			var index := int(extra.get("index", -1))
			if school != null and index >= 0 and index < school.fish_count() and school.is_alive(index) and not school.is_claimed(index) \
					and school.fish_position(index).distance_to(mouth) <= span:
				return _build(bite, school, index, null, mouth, forward, charge)
		elif extra.has("prey_at") and extra["prey_at"] is Vector3:
			var best: FishController
			var best_gap := 4.0
			for victim: FishController in bite.world.call("live_prey"):
				var gap := victim.global_position.distance_to(extra["prey_at"] as Vector3)
				if victim != bite.fish and gap < best_gap and victim.global_position.distance_to(mouth) <= span:
					best = victim
					best_gap = gap
			if best != null:
				return _build(bite, null, -1, best, mouth, forward, charge)
	return frustum_rule(bite, mouth, forward, charge)


func net_extra(_bite: HunterBite) -> Dictionary:
	if _school != null and is_instance_valid(_school):
		return {"school": _school.id, "index": _index}
	if _prey != null and is_instance_valid(_prey):
		return {"prey_at": _prey.global_position}
	return {}


func on_landed(bite: HunterBite) -> void:
	if active():
		last_at = target_at() if target_at().is_finite() else bite.mouth_point()
		landed_age = 0.0
	_clear()


func on_cancel(_bite: HunterBite) -> void:
	_clear()
	mates_at = PackedVector3Array()


func ring_count(bite: HunterBite) -> int:
	return count_now if bite.holding() and active() else bite.capacity()


## The lash's crunches travel: the delay (s) of the `i`th fish's crunch after the first (0: all together).
func crunch_delay(bite: HunterBite, i: int) -> float:
	var speed := bite.settings.angel_lash_speed
	if speed <= 0.0 or gaps.is_empty():
		return super.crunch_delay(bite, i)
	var at := mini(i, gaps.size() - 1)
	return maxf(gaps[at] - gaps[0], 0.0) / speed + (i - at) * HunterBiteFx.CRUNCH_GAP


## Tap mode: close enough, press once. Hold mode: press when the gate passes, let go once the line-up is good.
func bot_plan(bot: WhatStinksBot, bite: HunterBite) -> Dictionary:
	var settings := bite.settings
	var ready := bite.cooldown <= 0.0 and not bite.busy() and not bot.stinker_blocks
	if settings.bite_mode == WhatStinksSettings.BiteMode.TAP:
		return {"press": ready and bot.target_ahead > 0.4 and bot.target_gap <= bite.reach() * settings.hunter_bot_bite_share, "hold": false}
	if not bite.holding():
		var pick := _pick(bite)
		var stinker: bool = pick.has("prey") and bot.reads_as_stinker(pick["prey"] as FishController)  # Upset Stomach: it won't lock on a prey it can read
		return {"press": ready and not pick.is_empty() and not stinker, "hold": false}
	var lined_up := _share(bite, _school, bite.mouth_point(), -bite.fish.global_basis.z, bite.charge()) >= settings.hunter_bot_lock_align
	return {"press": false, "hold": active() and not lined_up and bite.held_for < 6.0}


# --- Targets ------------------------------------------------------------------------------

## The nearest fish that passes the gate now: {"school": School, "index": int} or {"prey": FishController}, or {}.
func _pick(bite: HunterBite) -> Dictionary:
	var world := bite.world
	var field: WhatStinksField = world.get("field") if world != null else null
	if field == null:
		return {}
	var settings := bite.settings
	var reach := bite.size.bite_reach(bite.fish, bite.form)
	var span := settings.angel_lock_range * reach
	if span <= 0.0:
		return {}
	var mouth := bite.mouth_point()
	var forward := -bite.fish.global_basis.z.normalized()
	var cone := cos(deg_to_rad(clampf(settings.angel_lock_cone, 1.0, 180.0)))
	var best := {}
	var best_gap := INF
	for school in field.schools:
		if not is_instance_valid(school) or school.alive_count() == 0 or school.middle().distance_to(mouth) > span + school.radius() * 2.0:
			continue
		for i in school.fish_count():
			if not school.is_alive(i) or school.is_claimed(i):
				continue
			var at := school.fish_position(i)
			var gap := at.distance_to(mouth)
			if gap < best_gap and gap <= span and _in_cone(forward, at - mouth, cone):
				best_gap = gap
				best = {"school": school, "index": i}
	if settings.bite_takes_players:
		for prey: FishController in world.call("live_prey"):
			if prey == bite.fish or not is_instance_valid(prey):
				continue
			var gap := prey.global_position.distance_to(mouth)
			if gap < best_gap and gap <= span and _in_cone(forward, prey.global_position - mouth, cone):
				best_gap = gap
				best = {"prey": prey}
	return best


static func _in_cone(forward: Vector3, offset: Vector3, cone_cos: float) -> bool:
	return offset.length_squared() < 0.0001 or forward.dot(offset.normalized()) >= cone_cos


## Whether the target is still there to be taken.
func _alive(bite: HunterBite) -> bool:
	if _prey != null:
		return is_instance_valid(_prey) and not _prey.battered and bite.world != null and bool(bite.world.call("is_live_prey", _prey))
	return _school != null and is_instance_valid(_school) and _school.is_alive(_index) and not _school.is_claimed(_index)


## The school whose mass the angle is judged against: the target's, or the one a joined player is a place in.
func _mass_of(school: School, prey: FishController, bite: HunterBite) -> School:
	if school != null:
		return school
	if prey != null and bite.world != null:
		var field: WhatStinksField = bite.world.get("field")
		if field != null:
			for candidate in field.schools:
				if is_instance_valid(candidate) and candidate.claim_of(prey) >= 0:
					return candidate
	return null


func _snap(bite: HunterBite) -> void:
	var at := target_at()
	last_at = at if at.is_finite() else bite.mouth_point()
	lost_age = 0.0
	bite.fx().lost(last_at)
	bite.abort()
	bite.cooldown = maxf(bite.cooldown, bite.settings.angel_break_cooldown)


func _clear() -> void:
	_school = null
	_index = -1
	_prey = null
	_gate = {}
	count_now = 1


# --- Holding the lock ---------------------------------------------------------------------

## Matches the target's pace, holds the stand-off, orbits with the stick and pivots to face it.
func _follow(bite: HunterBite, delta: float) -> void:
	var fish := bite.fish
	var settings := bite.settings
	var reach := bite.size.bite_reach(fish, bite.form)
	var at := target_at()
	var velocity := _target_velocity()
	var orbit := _orbit_input(bite, at) if bite.holding() else Vector2.ZERO
	if orbit != Vector2.ZERO:
		var yaw := atan2(_dir.x, _dir.z) + orbit.x * settings.angel_orbit_speed * delta
		var lift := clampf(asin(clampf(_dir.y, -1.0, 1.0)) + orbit.y * settings.angel_orbit_speed * 0.6 * delta, -1.2, 1.2)
		_dir = Vector3(sin(yaw) * cos(lift), sin(lift), cos(yaw) * cos(lift))
	_dist = move_toward(_dist, settings.angel_standoff * reach, settings.angel_close_speed * delta)
	var want := at + _dir * _dist
	var pull := ((want - fish.global_position) * 4.0).limit_length(settings.angel_close_speed)
	fish.linear_velocity = fish.linear_velocity.lerp(velocity + pull, 1.0 - exp(-10.0 * delta))
	# Face it: the shortest turn from the nose to the target, at most angel_face_rate.
	var forward := -fish.global_basis.z.normalized()
	var wanted := (at - fish.global_position).normalized()
	if wanted.is_finite() and wanted.length_squared() > 0.5:
		var angle := forward.angle_to(wanted)
		var axis := forward.cross(wanted)
		if angle > 0.0001 and axis.length_squared() > 1.0e-10:
			var step := minf(angle, settings.angel_face_rate * delta)
			fish.global_basis = Basis(axis.normalized(), step) * fish.global_basis
	fish.angular_velocity = Vector3.ZERO


func _target_velocity() -> Vector3:
	if _prey != null:
		return _prey.swim_velocity()
	return _school.fish_velocity(_index)


## The stick (x: round to the right, y: up) that orbits it. A bot has no stick worth reading: it
## swings round to the far side of the school, where the line-up is best.
func _orbit_input(bite: HunterBite, at: Vector3) -> Vector2:
	var fish := bite.fish
	if bite.world == null or not (bite.world.get("bots") as Dictionary).has(fish):
		return fish.input_stick
	var mass := _mass_of(_school, _prey, bite)
	if mass == null:
		return Vector2.ZERO
	var away := at - mass.middle()
	if away.length_squared() < 0.01:
		return Vector2.ZERO
	away = away.normalized()
	var diff := wrapf(atan2(away.x, away.z) - atan2(_dir.x, _dir.z), -PI, PI)
	var lift := asin(clampf(away.y, -1.0, 1.0)) - asin(clampf(_dir.y, -1.0, 1.0))
	return Vector2(clampf(diff * 2.0, -1.0, 1.0), clampf(lift * 2.0, -1.0, 1.0))


# --- The count ----------------------------------------------------------------------------

## How squarely `forward` from `mouth` faces the mass of `school` (0 to 1, as the lock-on bite maps it), plus the charge.
func _share(bite: HunterBite, school: School, mouth: Vector3, forward: Vector3, charge: float) -> float:
	var weight := bite.settings.angel_charge_weight
	if school == null:
		return 1.0
	var line := school.middle() - mouth
	var facing := 1.0
	if line.length_squared() > 0.0001:
		facing = clampf((forward.normalized().dot(line.normalized()) - 0.2) / 0.8, 0.0, 1.0)
	return clampf(facing * (1.0 - weight) + charge * weight, 0.0, 1.0)


## What a release from here at `charge` takes: capacity x angel_count_mult x share x the camera lock-on's bonus, at least 1.
func _count(bite: HunterBite, school: School, prey: FishController, mouth: Vector3, forward: Vector3, charge: float) -> int:
	var mass := _mass_of(school, prey, bite)
	if mass == null:
		return 1
	var count := float(bite.capacity_at(0.0)) * bite.settings.angel_count_mult * _share(bite, mass, mouth, forward, charge)
	if bite.world != null and bite.world.has_method("lock_stack_mult"):
		count *= float(bite.world.call("lock_stack_mult", bite.fish, bite, mass))
	return maxi(1, roundi(count))


## The target and then the nearest of its school, as [{at, gap-from-the-target}] sorted by that gap, `count` of them at most.
func _group(bite: HunterBite, school: School, index: int, prey: FishController, count: int) -> Array:
	var centre := prey.global_position if prey != null else school.fish_position(index)
	var mass := _mass_of(school, prey, bite)
	var mates: Array = []
	if mass != null and count > 1:
		for i in mass.fish_count():
			if (mass == school and i == index) or not mass.is_alive(i) or mass.is_claimed(i):
				continue
			var at := mass.fish_position(i)
			mates.append([at.distance_to(centre), at])
		mates.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return mates.slice(0, maxi(count - 1, 0))


func _update_preview(bite: HunterBite) -> void:
	if not active():
		return
	var mouth := bite.mouth_point()
	var forward := -bite.fish.global_basis.z.normalized()
	var wanted := _count(bite, _school, _prey, mouth, forward, bite.charge())
	var mates := _group(bite, _school, _index, _prey, wanted)
	count_now = 1 + mates.size()
	mates_at = PackedVector3Array()
	for mate: Array in mates:
		mates_at.append(mate[1])


## The rule for a release: the target (nearest the point, so first) and its nearest schoolmates, up to the count.
func _build(bite: HunterBite, school: School, index: int, prey: FishController, mouth: Vector3, forward: Vector3, charge: float) -> Dictionary:
	var centre := prey.global_position if prey != null else school.fish_position(index)
	var wanted := _count(bite, school, prey, mouth, forward, charge)
	var mates := _group(bite, school, index, prey, wanted)
	var radius := 0.05
	var picks: Array[float] = [mouth.distance_to(centre)]
	if not mates.is_empty():
		radius = maxf(float((mates[-1] as Array)[0]), 0.0) + 0.05
		for mate: Array in mates:
			picks.append(mouth.distance_to(mate[1] as Vector3))
	picks.sort()
	gaps = picks
	return {
		"point": centre, "capacity": 1 + mates.size(), "only": _mass_of(school, prey, bite),
		"extra": [], "frustum": false,
		"inside": func(at: Vector3) -> bool: return at.distance_to(centre) <= radius,
	}
