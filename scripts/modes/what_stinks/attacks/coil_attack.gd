class_name CoilAttack
extends HunterAttack
## The King of Herrings' style (two-stage-attack.md 4e): the press draws the head back and starts the body coiling, the hold tightens
## the coil, the release is the whip. The head sweeps through an arc round a pivot behind the mouth; the arc is as wide as the coil
## was tight (coil_arc_min to coil_arc_max degrees with the charge), and the catch is that arc, a wide flat sector, not the frustum.
## Contact is the head crossing the arc's middle, straight ahead: the catch is judged there, over the whole sector.
##
## The sector's apex is the pivot, coil_pivot x the reach behind the mouth; it reaches the mouth's distance plus one reach, and is
## coil_thick x the reach thick up and down. The charge widens the arc and lifts the capacity (coil_capacity_mult); the reach is
## the form's own. KingRig reads sweep_at() (the head's yaw round the pivot) and coil_target() (how tight the body curls).
##
## The owning machine does all of this (a puppet is only the pose); a guest's landing carries its mouth, heading and charge, and
## the host judges the same sector from those (net_catch_rule), flat to its own view of that Hunter's up.


## How open the jaws were when the release began, and half the sweep's width then (rad): the pose's.
var _open0 := 1.0
var _half := 0.0
## The coil the release began at (share of full), for _unwind.
var _level := 0.0
## Whether the current bite was a held one (its press wound the coil).
var _wound := false


func _init() -> void:
	key = "coil"


func on_open(_bite: HunterBite) -> void:
	_wound = true


func capacity_mult_at(bite: HunterBite, charge: float) -> float:
	return lerpf(1.0, bite.settings.coil_capacity_mult, charge)


## Half the arc (rad) a release at `charge` sweeps.
func half_at(bite: HunterBite, charge: float) -> float:
	var settings := bite.settings
	return deg_to_rad(lerpf(settings.coil_arc_min, settings.coil_arc_max, clampf(charge, 0.0, 1.0)) * 0.5)


## How far behind the mouth the whip pivots (m).
func pivot_back(bite: HunterBite) -> float:
	return bite.size.bite_reach(bite.fish, bite.form) * bite.settings.coil_pivot


## How tight the body should be coiled now (0 straight, 1 fully curled): started by the press (a quick winding to coil_press_floor, B5: it
## reads as a wind on the press itself), tightening with the charge. coil_press_floor is a panel setting once registered (0.4 until then).
func coil_target(bite: HunterBite) -> float:
	if not bite.holding():
		return _unwind(bite)
	var floor_share := clampf(_press_floor(bite), 0.0, 0.95)
	return floor_share + (1.0 - floor_share) * bite.charge()


## After the release the coil does not drop away in a few frames (the strike is 0.07 s): it unwinds over the strike and the shake, so the whip
## reads (B5). Zero once the shake is over, or for a bite that was not a held one.
func _unwind(bite: HunterBite) -> float:
	var b := bite.bite
	if b == null or _level <= 0.0:
		return 0.0
	var strike := maxf(b.duration(ChompKit.Phase.STRIKE), 0.0001)
	var shake := maxf(b.duration(ChompKit.Phase.SHAKE), 0.0001)
	var elapsed := -1.0
	match b.phase:
		ChompKit.Phase.STRIKE:
			elapsed = b.t
		ChompKit.Phase.SHAKE:
			elapsed = strike + b.t
	if elapsed < 0.0:
		return 0.0
	return _level * (1.0 - smoothstep(0.0, 1.0, elapsed / (strike + shake)))


## The coil the press winds to at once (share of full), a panel setting (coil_press_floor) once registered.
func _press_floor(bite: HunterBite) -> float:
	var got: Variant = bite.settings.get("coil_press_floor")
	return float(got) if got != null else 0.4


## The head's yaw round the pivot now (rad, positive: to the side it was drawn back to): cocked aside while the coil is held, back
## through straight ahead at the contact, on out to the far side, then home. Zero at rest.
func sweep_at(bite: HunterBite) -> float:
	var b := bite.bite
	if b == null:
		return 0.0
	match b.phase:
		ChompKit.Phase.ANTICIPATE, ChompKit.Phase.GAPE, ChompKit.Phase.HOLD:
			return half_at(bite, b.charge) * smoothstep(0.0, 1.0, b.open)
		ChompKit.Phase.STRIKE:
			var shut := 1.0 - b.settings.chomp_contact  # the open it has when the jaws land: the middle of the arc
			var length := maxf(b.duration(ChompKit.Phase.STRIKE), 0.0001)
			if not b.landed:
				var span := _open0 - shut
				return _half * (clampf((b.open - shut) / span, 0.0, 1.0) if span > 0.001 else 0.0)
			var landed_at := sqrt(maxf(1.0 - shut / maxf(_open0, 0.001), 0.0))
			var past := clampf((b.t / length - landed_at) / maxf(1.0 - landed_at, 0.001), 0.0, 1.0)
			return -_half * 0.5 * past
		ChompKit.Phase.SHAKE:
			return -_half * (0.5 + 0.5 * clampf(b.t / maxf(b.duration(ChompKit.Phase.SHAKE), 0.0001), 0.0, 1.0))
		ChompKit.Phase.RECOVER:
			return -_half * (1.0 - smoothstep(0.0, 1.0, clampf(b.t / maxf(b.duration(ChompKit.Phase.RECOVER), 0.0001), 0.0, 1.0)))
	return 0.0


func on_tick(bite: HunterBite, _delta: float) -> void:
	var b := bite.bite
	if b != null and b.phase == ChompKit.Phase.STRIKE and b.t == 0.0:
		_open0 = maxf(b.open, 0.001)  # the release's first tick: the sweep's start
		_half = half_at(bite, bite.strike_charge())
		var floor_share := clampf(_press_floor(bite), 0.0, 0.95)
		_level = (floor_share + (1.0 - floor_share) * bite.strike_charge()) if _wound else 0.0  # a tap never wound it
		_wound = false


## The sector from the pivot behind `mouth`, along `forward`, flat in the plane `up` is the normal of.
func sector_rule(bite: HunterBite, mouth: Vector3, forward: Vector3, up: Vector3, charge: float) -> Dictionary:
	var reach := bite.size.bite_reach(bite.fish, bite.form)
	var back := reach * bite.settings.coil_pivot
	var apex := mouth - forward * back
	var half := half_at(bite, charge)
	var radius := back + reach
	var thick := reach * bite.settings.coil_thick
	return {
		"point": mouth + forward * reach * 0.5, "capacity": bite.capacity_at(charge), "only": null, "extra": [], "frustum": false,
		"inside": func(at: Vector3) -> bool: return in_sector(apex, forward, up, half, radius, thick, at),
	}


func catch_rule(bite: HunterBite) -> Dictionary:
	return sector_rule(bite, bite.mouth_point(), -bite.fish.global_basis.z.normalized(), bite.fish.global_basis.y.normalized(), bite.strike_charge())


func net_catch_rule(bite: HunterBite, mouth: Vector3, forward: Vector3, charge: float, _extra: Dictionary) -> Dictionary:
	return sector_rule(bite, mouth, forward, bite.fish.global_basis.y.normalized(), charge)


## Whether `at` is in the flat sector: within `radius` of `apex` on the plane of `forward` and `up`'s right, within `half` rad of
## `forward` there, and no more than `thick` above or below the plane.
static func in_sector(apex: Vector3, forward: Vector3, up: Vector3, half: float, radius: float, thick: float, at: Vector3) -> bool:
	var normal := up.normalized()
	var off := at - apex
	var height := off.dot(normal)
	if absf(height) > thick:
		return false
	var flat := off - normal * height
	var length := flat.length()
	if length > radius:
		return false
	if length < 0.0001 or half >= PI:
		return true
	var ahead := forward - normal * forward.dot(normal)
	if ahead.length_squared() < 0.0001:
		return true
	return flat.angle_to(ahead) <= half


## Open once a fish is near, let go when one is in the sector the coil has now and it is charged (or it is getting away).
func bot_plan(bot: WhatStinksBot, bite: HunterBite) -> Dictionary:
	var settings := bite.settings
	var gap := bot.target_gap
	var ready := bite.cooldown <= 0.0 and not bite.busy() and bot.target_ahead > 0.4 and not bot.stinker_blocks
	if settings.bite_mode == WhatStinksSettings.BiteMode.TAP:
		return {"press": ready and gap <= bite.reach() * settings.hunter_bot_bite_share, "hold": false}
	if not bite.holding():
		return {"press": ready and gap <= bite.reach() * settings.hunter_bot_open_gap, "hold": false}
	var rule := sector_rule(bite, bite.mouth_point(), -bite.fish.global_basis.z.normalized(), bite.fish.global_basis.y.normalized(), bite.charge())
	var in_arc: bool = (rule["inside"] as Callable).call(bot.target_at)
	var getting_away := gap > bot.target_prev_gap + 0.001 and gap <= bite.reach() * 1.2
	var gave_up := gap > bite.reach() * settings.hunter_bot_open_gap * 2.0
	var release := (in_arc and bite.charge() >= settings.hunter_bot_charge) or getting_away or gave_up
	if bot.stinker_blocks and not gave_up:
		release = false
	return {"press": false, "hold": not release}
