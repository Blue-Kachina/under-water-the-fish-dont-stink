class_name SuctionAttack
extends HunterAttack
## The Gulper Mother's style (two-stage-attack.md 4d): the press balloons the pouch open, and while it is held a
## cone of suction ahead of the mouth draws school fish in (School.pull, a force on the boids) and shoves prey
## players toward it (apply_push: they can swim against it). Both grow with the charge, in strength and in reach.
## The release snaps the pouch shut on everything within gulper_mouth_r bite radii of the mouth, and the belly
## shows what it took: it fills while fish crowd the mouth, and a lump slides down it after the snap.
##
## Nothing is held in the mouth and nothing is sent: the pull is a pure function of where the open mouth is, so
## every machine runs it for the Hunter it sees (a puppet with its jaws open from the open message), the host
## judges the release from the mouth the guest reports, and the lump is a pose each machine works out itself.
## In tap mode the style plays as the chomp's frustum (the snap).

## How often (s) the fish crowding the mouth are counted (for the belly and the bot).
const SCAN_EVERY := 0.1
## How fast the belly fills as fish gather at the mouth (share of full per s).
const FILL_RATE := 2.5
## The lump's length along the belly (the shader's m).
const LUMP_LEN := 5.0

## Fish and prey players within the snap's reach of the mouth, as of the last scan.
var in_mouth := 0
## How full the belly shows (0 to 1), eased.
var fullness := 0.0
## Seconds since the crowd at the mouth last grew (the bot's cue that the pull has run dry).
var idle := 0.0

var _scan := 0.0
var _lump_left := 0.0
var _lump_load := 0.0
var _judged := false
var _pulled: Array[School] = []


func _init() -> void:
	key = "suction"


## How far (m) the suction reaches at a charge: suck_reach_mult x the bite's reach, growing from suck_reach_min of it.
func pull_reach(bite: HunterBite, at_charge: float) -> float:
	var s := bite.settings
	return bite.size.bite_reach(bite.fish, bite.form) * s.suck_reach_mult * lerpf(s.suck_reach_min, 1.0, at_charge)


## The speed (m/s) a school fish is drawn at, at a charge.
func pull_speed(bite: HunterBite, at_charge: float) -> float:
	return bite.settings.suck_strength * lerpf(bite.settings.suck_charge_min, 1.0, at_charge)


## The snap's reach (m): gulper_mouth_r bite radii around the mouth.
func mouth_radius(bite: HunterBite) -> float:
	return bite.radius() * bite.settings.gulper_mouth_r


func on_open(bite: HunterBite) -> void:
	_stop_pulls(bite)
	in_mouth = 0
	idle = 0.0
	_scan = 0.0
	_judged = false


func on_hold(bite: HunterBite, delta: float) -> void:
	var settings := bite.settings
	var world := bite.world
	var open := bite.bite.open
	if world == null or not is_instance_valid(world) or world.get("phase") != WhatStinksMatch.Phase.LIVE or open < 0.3:
		return
	var field: WhatStinksField = world.get("field")
	if field == null:
		return
	var at_charge := bite.charge()
	var mouth := bite.mouth_point()
	var dir := -bite.fish.global_basis.z.normalized()
	var reach := pull_reach(bite, at_charge)
	var speed := pull_speed(bite, at_charge) * clampf(open, 0.0, 1.0)  # the pouch has to be open to suck
	var mouth_r := mouth_radius(bite)
	var count := _scan <= 0.0
	var crowd := 0
	_pulled.clear()
	for school in field.schools:
		if not is_instance_valid(school) or school.alive_count() == 0:
			continue
		if school.middle().distance_to(mouth) > reach + school.radius() * 2.0:
			continue
		school.pull(bite, mouth, dir, settings.suck_cone, speed, reach, mouth_r)
		_pulled.append(school)
		if count:
			for i in school.fish_count():
				if school.is_alive(i) and not school.is_claimed(i) and school.fish_position(i).distance_to(mouth) <= mouth_r:
					crowd += 1
	var push := settings.suck_prey_push * lerpf(settings.suck_charge_min, 1.0, at_charge) * clampf(open, 0.0, 1.0) * delta
	if settings.bite_takes_players:
		for prey: FishController in world.call("live_prey"):
			if not is_instance_valid(prey) or prey == bite.fish:
				continue
			var off := mouth - prey.global_position
			var gap := off.length()
			if count and gap <= mouth_r:
				crowd += 1
			if gap >= reach or gap < 0.001 or prey.puppet or push <= 0.0:
				continue  # a puppet is pushed on its own machine
			if (-off / gap).dot(dir) < cos(deg_to_rad(settings.suck_cone)):
				continue
			prey.apply_push(off / gap * push * (1.0 - gap / reach))
	if count:
		_scan = SCAN_EVERY
		if crowd > in_mouth:
			idle = 0.0
		in_mouth = crowd
	else:
		_scan -= delta
		idle += delta


func on_tick(bite: HunterBite, delta: float) -> void:
	# The belly fills while fish crowd the mouth, and after a snap holds what it took while the lump slides down.
	var cap := float(maxi(bite.capacity(), 1))
	var want := clampf(float(in_mouth) / cap, 0.0, 1.0) if bite.holding() else 0.0
	if _lump_left > 0.0:
		_lump_left = maxf(_lump_left - delta, 0.0)
		var share := _lump_left / maxf(bite.settings.suck_lump_s, 0.01)
		fullness = maxf(fullness - delta / maxf(bite.settings.suck_lump_s, 0.01), _lump_load * share)
	elif want > fullness:
		fullness = minf(fullness + FILL_RATE * delta, want)
	else:
		fullness = maxf(fullness - delta, want)


## What the release catches: in tap mode the frustum (the snap); held, everything round the mouth within gulper_mouth_r bite radii.
func catch_rule(bite: HunterBite) -> Dictionary:
	if bite.settings.bite_mode == WhatStinksSettings.BiteMode.TAP:
		return super.catch_rule(bite)
	return _sphere_rule(bite, bite.mouth_point(), bite.strike_charge())


func net_catch_rule(bite: HunterBite, mouth: Vector3, forward: Vector3, charge: float, extra: Dictionary) -> Dictionary:
	if bite.settings.bite_mode == WhatStinksSettings.BiteMode.TAP:
		return super.net_catch_rule(bite, mouth, forward, charge, extra)
	return _sphere_rule(bite, mouth, charge)


func _sphere_rule(bite: HunterBite, mouth: Vector3, charge: float) -> Dictionary:
	var r := mouth_radius(bite)
	return {
		"point": mouth, "capacity": bite.capacity_at(charge), "only": null, "extra": [], "frustum": false,
		"inside": func(at: Vector3) -> bool: return at.distance_to(mouth) <= r,
	}


## The snap judged: the lump is what it took (the host's count).
func on_close(bite: HunterBite, taken: Dictionary) -> void:
	_judged = true
	_lump(bite, int(taken.get("school_fish", 0)) + (taken.get("fish", []) as Array).size())


func on_landed(bite: HunterBite) -> void:
	if not _judged:
		_lump(bite, in_mouth)  # not judged here (a puppet, a guest): what was crowding the mouth
	_judged = false
	_stop_pulls(bite)
	in_mouth = 0


func on_cancel(bite: HunterBite) -> void:
	_stop_pulls(bite)
	in_mouth = 0


func ring_count(bite: HunterBite) -> int:
	return mini(in_mouth, bite.capacity()) if bite.holding() else bite.capacity()


## The lump the belly shows as a shader vector (x: where along the body in the shader's m, y: its length, z: how far it presses out; z 0: none).
func lump_vec(bite: HunterBite, belly: Vector2) -> Vector3:
	var s := bite.settings
	if _lump_left <= 0.0 or s.suck_lump_size <= 0.0 or s.suck_lump_s <= 0.0:
		return Vector3.ZERO
	var along := 1.0 - _lump_left / s.suck_lump_s
	var fade := smoothstep(0.0, 0.1, _lump_left / s.suck_lump_s)  # it eases out at the end of the belly
	return Vector3(lerpf(belly.x, belly.y, along), LUMP_LEN, s.suck_lump_size * _lump_load * fade)


## Seconds the lump has left to slide (0: none showing).
func lump_left() -> float:
	return _lump_left


## Open on a school ahead; shut when the mouth is crowded, the pull has run dry or the school has passed.
func bot_plan(bot: WhatStinksBot, bite: HunterBite) -> Dictionary:
	var settings := bite.settings
	var gap := bot.target_gap
	var ready := bite.cooldown <= 0.0 and not bite.busy() and bot.target_ahead > 0.4 and not bot.stinker_blocks
	if settings.bite_mode == WhatStinksSettings.BiteMode.TAP:
		return {"press": ready and gap <= bite.reach() * settings.hunter_bot_bite_share, "hold": false}
	if not bite.holding():
		return {"press": ready and gap <= pull_reach(bite, 1.0) * settings.hunter_bot_open_gap, "hold": false}
	var crowded := in_mouth >= maxi(1, bite.capacity())
	var dry := in_mouth > 0 and idle > 0.6
	var passed := in_mouth == 0 and (bot.target_ahead < 0.0 or gap > pull_reach(bite, 1.0) * 1.2)
	var release := crowded or dry or passed or bite.held_for > 6.0
	if bot.stinker_blocks and not passed:
		release = false
	return {"press": false, "hold": not release}


func _lump(bite: HunterBite, count: int) -> void:
	var cap := float(maxi(bite.capacity(), 1))
	_lump_load = clampf(float(count) / cap, 0.0, 1.0)
	_lump_left = bite.settings.suck_lump_s if count > 0 else 0.0
	fullness = maxf(fullness, _lump_load)


func _stop_pulls(bite: HunterBite) -> void:
	for school in _pulled:
		if is_instance_valid(school):
			school.end_pull(bite)
	_pulled.clear()
