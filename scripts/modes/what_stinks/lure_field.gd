class_name LureField
extends RefCounted
## The Lantern Angler's attraction field (planning_new_hunters.md D3). While an Angler holds its lure bite, a Source is
## registered here: the esca's point, the way the light faces, a radius and a cone. Anything that wants to know whether it is
## being drawn asks this class, so the pull is one rule used by every path:
##
##   LureField.captivated(fish)            0..1 how held the fish is (the HUD's vignette; eased, drops while it resists)
##   LureField.blend_target(fish, target)  a bot's swim target bent toward the lure (WhatStinksPreyBot steering bias)
##   LureField.bias_weight(fish)           the same weight alone (0..1)
##   LureField.active()                    the live sources
##   Source.accel_on(...)                  one fish's acceleration this tick (LureAttack applies it with apply_push)
##
## The pull is a drift, never a lock: it ramps up with the hold, is strongest near the esca and fades to nothing at the radius
## and the edge of the cone, is capped, and is always breakable. Thrust away from the lure resists it (people most, bots less),
## and a dash (boost) cancels it and grants a short immunity so it cannot snap back the moment the dash ends.
## Every number is a WhatStinksSettings property named in DEFAULTS (read with cfg(), which falls back to the default when the
## settings object is null or lacks the property, so the field works before the settings are registered).

## Setting id -> default. The panel specs (ranges, docs) are in the D3 registrations.
const DEFAULTS := {
	"lure_radius": 42.0,        # m, how far the light reaches
	"lure_cone": 75.0,          # degrees, half angle of the cone about where the Angler faces
	"lure_pull": 7.0,           # m/s^2 at full ramp, next to the esca
	"lure_cap": 11.0,           # m/s^2, no fish is ever drawn harder than this
	"lure_resist": 0.9,         # share of the pull a person cancels by swimming straight away
	"lure_bot_resist": 0.35,    # the same for a bot (it also has the steering bias)
	"lure_dash_cancel": 1.0,    # share of the pull a dash (boost) cancels
	"lure_break_s": 1.2,        # s of immunity after a dash breaks the hold
	"lure_ramp_s": 2.0,         # s of holding to full attraction
	"lure_cooldown": 1.5,       # s extra cooldown after the snap
	"lure_school_pull": 1.0,    # x the pull on school fish (0 off)
	"lure_bot_bias": 0.8,       # how far a bot's target bends toward the lure at full hold
	"lure_fade_m": 1.5,         # m, the pull eases off this close to where it is aiming (no jitter at the mouth)
	"lure_flicker_min": 2.5,    # Hz, the esca's flicker with nothing near
	"lure_flicker_max": 14.0,   # Hz, with prey at the mouth
	"lure_flare": 2.6,          # esca brightness while held (1 is normal)
	"lure_gape": 1.35,          # x the jaw's opening while held (the jaw wrapper's gape_mult)
}

## Fish seconds held / dashes that broke a hold, for the run stats ("always breakable, logged").
static var stats := {"holds": 0, "captive_s": 0.0, "breaks": 0}
static var _sources: Array = []
## Sources that just stopped: their captivated levels ease out (the vignette fades, it does not pop).
static var _fading: Array = []
static var _tick_frame := -1


static func cfg(settings: Object, key: String) -> float:
	if settings != null:
		var v: Variant = settings.get(key)
		if v != null:
			return float(v)
	return float(DEFAULTS[key])


static func register(src: Source) -> void:
	if not _sources.has(src):
		_sources.append(src)


static func unregister(src: Source) -> void:
	_sources.erase(src)


## The live sources (dead ones pruned).
static func active() -> Array:
	var keep: Array = []
	for src: Source in _sources:
		if src.active and src.alive():
			keep.append(src)
	_sources = keep
	return keep


## Eases the stopped sources' levels out. Anything may call it every tick; it advances once per physics frame.
static func tick(delta: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _tick_frame:
		return
	_tick_frame = frame
	var keep: Array = []
	for src: Source in _fading:
		for id: Variant in src.captive.keys():
			src._ease(int(id), 0.0, delta)
		if not src.captive.is_empty():
			keep.append(src)
	_fading = keep


static func reset() -> void:
	_sources.clear()
	_fading.clear()
	_tick_frame = -1
	stats = {"holds": 0, "captive_s": 0.0, "breaks": 0}


## How held `fish` is by the strongest source on it (0 free to 1 fully drawn).
static func captivated(fish: Object) -> float:
	if fish == null:
		return 0.0
	var best := 0.0
	var id := fish.get_instance_id()
	for src: Source in _sources:
		best = maxf(best, float(src.captive.get(id, 0.0)))
	for src: Source in _fading:
		best = maxf(best, float(src.captive.get(id, 0.0)))
	return best


## 0..1 how hard the lure bends a bot's steering at `fish` now (geometry and ramp; a dash or the immunity turns it off).
static func bias_weight(fish: FishController) -> float:
	if fish == null or not is_instance_valid(fish):
		return 0.0
	var best := 0.0
	var id := fish.get_instance_id()
	for src: Source in active():
		if src.owner_id == id:
			continue
		best = maxf(best, src.bias_at(fish.global_position, id) * src.bot_bias)
	return best


## A bot's swim `target` bent toward the strongest lure on it (the target itself when nothing draws it).
static func blend_target(fish: FishController, target: Vector3) -> Vector3:
	if fish == null or not is_instance_valid(fish) or fish.controls == null:
		return target
	var best_w := 0.0
	var best_at := target
	var id := fish.get_instance_id()
	for src: Source in active():
		if src.owner_id == id:
			continue
		var w := src.bias_at(fish.global_position, id) * src.bot_bias
		if w > best_w:
			best_w = w
			best_at = src.pull_target(fish.global_position)
	return target.lerp(best_at, clampf(best_w, 0.0, 1.0))


## A person (their own controller), as opposed to a bot or a puppet.
static func is_human(fish: FishController) -> bool:
	return fish.controls == null and not fish.puppet


## Where `fish` is trying to go as a world vector, length 0..1: thrust along its heading (reverse backs it).
static func intent_of(fish: FishController) -> Vector3:
	var thrust := clampf(fish.input_forward - fish.input_reverse, -1.0, 1.0)
	return -fish.global_basis.z * thrust


## Whether `fish` is dashing (prey's boost).
static func dashing(fish: FishController) -> bool:
	return fish.boost_held or (fish.has_meta("ws_dashing") and bool(fish.get_meta("ws_dashing")))


## One angler's field: where the light is and how hard it draws.
class Source:
	extends RefCounted

	var owner_ref: WeakRef
	var owner_id := 0
	var active := false
	## World: the esca, the mouth the prey are drawn to, the way the light faces (unit), the bite's reach.
	var esca := Vector3.ZERO
	var mouth := Vector3.ZERO
	var axis := Vector3.FORWARD
	var reach := 6.0
	## 0..1, the hold's build-up.
	var ramp := 0.0
	var radius := 42.0
	var cone_deg := 75.0
	var pull := 7.0
	var cap := 11.0
	var resist := 0.9
	var bot_resist := 0.35
	var dash_cancel := 1.0
	var break_s := 1.2
	var ramp_s := 2.0
	var fade_m := 1.5
	var bot_bias := 0.8
	## Fish instance id -> eased captivated level; -> seconds of break immunity left.
	var captive := {}
	var immune := {}


	func _init(owner: Object = null, settings: Object = null) -> void:
		if owner != null:
			owner_ref = weakref(owner)
			owner_id = owner.get_instance_id()
		configure(settings)


	func configure(settings: Object) -> void:
		radius = maxf(LureField.cfg(settings, "lure_radius"), 0.1)
		cone_deg = clampf(LureField.cfg(settings, "lure_cone"), 1.0, 180.0)
		pull = maxf(LureField.cfg(settings, "lure_pull"), 0.0)
		cap = maxf(LureField.cfg(settings, "lure_cap"), 0.0)
		resist = clampf(LureField.cfg(settings, "lure_resist"), 0.0, 1.0)
		bot_resist = clampf(LureField.cfg(settings, "lure_bot_resist"), 0.0, 1.0)
		dash_cancel = clampf(LureField.cfg(settings, "lure_dash_cancel"), 0.0, 1.0)
		break_s = maxf(LureField.cfg(settings, "lure_break_s"), 0.0)
		ramp_s = maxf(LureField.cfg(settings, "lure_ramp_s"), 0.05)
		fade_m = maxf(LureField.cfg(settings, "lure_fade_m"), 0.01)
		bot_bias = clampf(LureField.cfg(settings, "lure_bot_bias"), 0.0, 1.0)


	func alive() -> bool:
		return owner_ref == null or owner_ref.get_ref() != null


	func start() -> void:
		active = true
		ramp = 0.0
		captive.clear()
		immune.clear()
		LureField.stats["holds"] = int(LureField.stats["holds"]) + 1
		LureField.register(self)


	func stop() -> void:
		active = false
		immune.clear()
		LureField.unregister(self)
		if not captive.is_empty() and not LureField._fading.has(self):
			LureField._fading.append(self)


	func place(at_esca: Vector3, at_mouth: Vector3, facing: Vector3, bite_reach: float) -> void:
		esca = at_esca
		mouth = at_mouth
		axis = facing.normalized() if facing.length_squared() > 0.0001 else axis
		reach = maxf(bite_reach, 0.1)


	## The hold goes on: the ramp builds, break immunities run down.
	func advance(delta: float) -> void:
		ramp = minf(ramp + delta / ramp_s, 1.0)
		for id: Variant in immune.keys():
			var left: float = float(immune[id]) - delta
			if left <= 0.0:
				immune.erase(id)
			else:
				immune[id] = left


	## The ramp's eased curve (0..1).
	func strength() -> float:
		return smoothstep(0.0, 1.0, ramp)


	## 0..1 geometry: 1 beside the esca, fading to 0 at the radius and at the edge of the cone.
	func reach_weight(pos: Vector3) -> float:
		var off := pos - esca
		var d := off.length()
		if d >= radius:
			return 0.0
		var falloff := 1.0 - d / radius
		if d < radius * 0.2 or cone_deg >= 179.0:
			return falloff
		var ang := rad_to_deg(acos(clampf(axis.dot(off / d), -1.0, 1.0)))
		return falloff * (1.0 - smoothstep(cone_deg * 0.8, cone_deg, ang))


	## Where a fish at `pos` is drawn to: the esca from afar, easing to the open mouth (a little ahead of it) as it nears.
	func pull_target(pos: Vector3) -> Vector3:
		var near := mouth + axis * reach * 0.4
		var w := 1.0 - smoothstep(reach * 1.2, reach * 3.0, pos.distance_to(mouth))
		return esca.lerp(near, w)


	## The bot steering weight at `pos` for fish `id` (0..1): reach x ramp, 0 under break immunity.
	func bias_at(pos: Vector3, id: int) -> float:
		var imm := minf(float(immune.get(id, 0.0)) / 0.4, 1.0)
		return reach_weight(pos) * strength() * (1.0 - imm)


	## The acceleration (world, m/s^2) on a fish at `pos` this tick, and its captivated level updated.
	## `intent` is where it is trying to go (world, length 0..1), `human` picks the resist, `dashing` cancels and grants immunity.
	func accel_on(id: int, pos: Vector3, intent: Vector3, human: bool, dashing: bool, delta: float) -> Vector3:
		var field := reach_weight(pos) * strength()
		var to := pull_target(pos) - pos
		var d := to.length()
		if field <= 0.0 or d < 0.001:
			_ease(id, 0.0, delta)
			return Vector3.ZERO
		var dir := to / d
		var away := clampf(-intent.dot(dir), 0.0, 1.0)
		var side := (intent - dir * intent.dot(dir)).length()
		var res := clampf(away + side * 0.35, 0.0, 1.0)
		var mult := 1.0 - res * (resist if human else bot_resist)
		if dashing and dash_cancel > 0.0:
			mult *= 1.0 - dash_cancel
			if break_s > 0.0 and dash_cancel >= 0.5:
				if float(captive.get(id, 0.0)) > 0.15 and not immune.has(id):
					LureField.stats["breaks"] = int(LureField.stats["breaks"]) + 1
				immune[id] = break_s
		if immune.has(id):
			mult *= 1.0 - minf(float(immune[id]) / 0.4, 1.0)
		var edge := smoothstep(0.0, fade_m, d)
		var accel := dir * pull * field * mult * edge
		if accel.length() > cap:
			accel = accel.normalized() * cap
		_ease(id, field * edge * (0.35 + 0.65 * mult), delta)
		if float(captive.get(id, 0.0)) > 0.05:
			LureField.stats["captive_s"] = float(LureField.stats["captive_s"]) + delta
		return accel


	func _ease(id: int, target: float, delta: float) -> void:
		var cur: float = float(captive.get(id, 0.0))
		cur = move_toward(cur, target, delta * (4.0 if target > cur else 3.0))
		if cur <= 0.001 and target <= 0.0:
			captive.erase(id)
		else:
			captive[id] = cur
