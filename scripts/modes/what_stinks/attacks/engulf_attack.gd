class_name EngulfAttack
extends HunterAttack
## The whales' style (two-stage-attack.md 4b): the press drops a huge hinged jaw (WhaleJaw), and while it is held
## anything that swims into the mouth is held in it. A school fish is held by its school (School.hold: it stops
## being a boid and rides a place in the mouth), a prey player is doomed (controls locked, carried). The mouth takes
## up to engulf_max_mult x the form's capacity; when it is full it stays open but takes no more (a full-mouth strain,
## the lips knock fish away). The release slams it shut and everything held is eaten in one judged bite. No capacity
## roll and no charge scaling: the charge is only how long it was held.
##
## Only the host collects (WhatStinksMatch.authority): it runs the engulf on the Hunter it sees, a guest's too (the
## puppet with its mouth open), and judges the guest's release from that list (net_catch_rule). A guest sees the
## mouth open and the fish eaten when it shuts, not the fish riding in it.

## A puppet's held fish are let go this long (s) after its mouth shut if its guest's bite never reports.
const PUPPET_EXPIRE := 1.5
## Seconds between a full mouth's strain cues.
const STRAIN_EVERY := 0.6
## How fast the throat swells as fish go in (share of full per s).
const SWELL_RATE := 3.0

## What the mouth holds: {"school": School, "index": int} for a school fish, {"prey": FishController, "slot": Vector3 (the
## fish's space), "from": Vector3, "age": float} for a prey player.
var held: Array[Dictionary] = []
## How full the throat is shown (0 to 1), eased.
var fullness := 0.0

var _box := {}
var _wired: HunterBite
var _caught := 0
var _budget := 0.0
var _idle := 0.0
var _strain_t := 0.0
var _expire := 0.0
var _warn_t := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	key = "engulf"
	_rng.randomize()


## How many fish the mouth holds at most: engulf_max_mult x the form's capacity at this size.
func max_held(bite: HunterBite) -> int:
	return maxi(1, roundi(float(bite.size.bite_capacity(bite.fish, bite.form)) * bite.settings.engulf_max_mult))


## Hears the bite's beats once per bite object (the exaggeration's press, release and abort): wired on the first hook
## that runs, before `opened` is emitted for the first press.
func _wire(bite: HunterBite) -> void:
	if _wired == bite:
		return
	_wired = bite
	bite.opened.connect(func() -> void: _jaw_of(bite, &"ex_press"))
	bite.released.connect(func(charge: float) -> void:
		var jaw := bite._jaw as WhaleJaw
		if jaw != null:
			jaw.ex_release(charge))
	bite.aborted.connect(func() -> void: _jaw_of(bite, &"ex_abort"))
	var jaw := bite._jaw as WhaleJaw
	if jaw != null:
		jaw.ex_reset()


func _jaw_of(bite: HunterBite, method: StringName) -> void:
	var jaw := bite._jaw as WhaleJaw
	if jaw != null:
		jaw.call(method)


func on_open(bite: HunterBite) -> void:
	_wire(bite)
	_release_all(bite)
	_box.clear()
	_budget = 1.0
	_idle = 0.0
	_strain_t = 0.0
	_update_box(bite, bite.bite.open)


func on_hold(bite: HunterBite, delta: float) -> void:
	var settings := bite.settings
	var whale := bite._jaw as WhaleJaw
	if whale != null:
		whale.ex_hold(bite.charge())
	_update_box(bite, bite.bite.open)
	_idle += delta
	_strain_t -= delta
	_budget = minf(_budget + settings.engulf_per_s * delta, maxf(settings.engulf_per_s * 0.25, 2.0))
	var world := bite.world
	if world == null or not bool(world.get("authority")) or world.get("phase") != WhatStinksMatch.Phase.LIVE or bite.bite.open < 0.5:
		return
	var field: WhatStinksField = world.get("field")
	if field == null:
		return
	var cap := max_held(bite)
	var mouth := bite.mouth_point()
	var reach_around: float = float(_box["len"]) + float(_box["hw"])
	for school in field.schools:
		if not is_instance_valid(school) or school.alive_count() == 0:
			continue
		if school.middle().distance_to(mouth) > reach_around + school.radius() * 2.0:
			continue
		for i in school.fish_count():
			if not school.is_alive(i) or school.is_claimed(i) or school.is_held(i):
				continue
			var at := school.fish_position(i)
			if not _in_box(bite.fish, _box, at):
				continue
			if held.size() >= cap:
				# A full mouth: the lips knock it away.
				if settings.engulf_bump > 0.0:
					school.nudge(i, (at - mouth).normalized() * settings.engulf_bump)
			elif _budget >= 1.0 and school.hold(i, bite.fish, _slot(bite), settings.engulf_pull_s):
				_budget -= 1.0
				held.append({"school": school, "index": i})
				_took(bite, at)
	if settings.bite_takes_players:
		for prey: FishController in world.call("live_prey"):
			if held.size() >= cap or _budget < 1.0:
				break
			if not is_instance_valid(prey) or _holds_prey(prey) or _joined(field, prey) or not _in_box(bite.fish, _box, prey.global_position):
				continue
			_budget -= 1.0
			held.append({"prey": prey, "slot": bite.fish.to_local(_slot_world(bite)), "from": prey.global_position, "age": 0.0})
			if not prey.puppet:
				prey.controls_locked = true  # doomed once inside
				prey.freeze = true
				prey.linear_velocity = Vector3.ZERO
			_took(bite, prey.global_position)
	if held.size() >= cap and _strain_t <= 0.0:
		_strain_t = STRAIN_EVERY
		bite.fx().strain()


func on_tick(bite: HunterBite, delta: float) -> void:
	var settings := bite.settings
	_wire(bite)
	var whale := bite._jaw as WhaleJaw
	if whale != null:
		whale.step(delta)  # the exaggeration's springs, before the jaw is posed this tick
	var cap := max_held(bite)
	# Prey in the mouth ride it: drawn in, then carried, with the dark-pink flush and a heartbeat on their own view.
	_warn_t -= delta
	for h in held:
		var prey := h.get("prey") as FishController
		if prey == null or not is_instance_valid(prey):
			continue
		h["age"] = float(h["age"]) + delta
		if prey.puppet:
			continue
		var share := 1.0 if settings.engulf_pull_s <= 0.0 else smoothstep(0.0, 1.0, clampf(float(h["age"]) / settings.engulf_pull_s, 0.0, 1.0))
		prey.global_position = (h["from"] as Vector3).lerp(bite.fish.to_global(h["slot"]), share)
		prey.linear_velocity = Vector3.ZERO
		if _warn_t <= 0.0 and prey.controls == null:
			HunterBiteFx.flash_hud(prey, 0.3)
			WhatStinksRumble.pulse(prey, settings.prey_warn_rumble * settings.rumble_hold * 2.0, 0.09)
	if _warn_t <= 0.0:
		_warn_t = 0.35
	# The throat fills as fish go in and squeezes back down after the mouth shuts.
	var want := clampf(float(held.size()) / cap, 0.0, 1.0)
	if want > fullness:
		fullness = minf(fullness + SWELL_RATE * delta, want)
	else:
		fullness = maxf(fullness - delta / maxf(settings.engulf_squeeze_s, 0.01), want if bite.holding() else 0.0)
	var jaw := bite._jaw as WhaleJaw
	if jaw != null:
		jaw.fullness = fullness
	# A guest's Hunter (a puppet) lets go if its bite is never reported.
	if _expire > 0.0:
		_expire -= delta
		if _expire <= 0.0:
			_release_all(bite)


## What a release takes: the held fish and prey, plus whatever else sits in the mouth, up to the mouth's limit.
func catch_rule(bite: HunterBite) -> Dictionary:
	if _box.is_empty():
		_update_box(bite, 1.0)
	var prey: Array = []
	for h in held:
		var fish := h.get("prey") as FishController
		if fish != null and is_instance_valid(fish):
			prey.append(fish)
	var box := _box.duplicate()
	var fish := bite.fish
	return {
		"point": bite.mouth_point(), "capacity": max_held(bite), "only": null, "extra": prey, "frustum": false,
		"inside": func(at: Vector3) -> bool: return _in_box(fish, box, at),
	}


func net_catch_rule(bite: HunterBite, _mouth: Vector3, _forward: Vector3, _charge: float, _extra: Dictionary) -> Dictionary:
	return catch_rule(bite)


func on_close(bite: HunterBite, _taken: Dictionary) -> void:
	_caught = held.size()
	_release_all(bite)


func on_landed(bite: HunterBite) -> void:
	_wire(bite)
	var whale := bite._jaw as WhaleJaw
	if whale != null:
		# What the mouth held when it shut is what the bite caught (a miss still slams, smaller).
		var caught := maxi(_caught, held.size())
		_caught = 0
		whale.ex_contact(clampf(float(caught) / maxf(float(max_held(bite)) * 0.5, 1.0), 0.0, 1.0) if caught > 0 else 0.25)
	bite.fx().spray()
	if bite.fish.puppet:
		_expire = PUPPET_EXPIRE  # its guest's report may still come: judge_net_bite uses the list
	else:
		_release_all(bite)


func on_cancel(bite: HunterBite) -> void:
	var whale := bite._jaw as WhaleJaw
	if whale != null and whale.ex != null:
		whale.ex_abort()
	_release_all(bite)
	_box.clear()


func ring_count(bite: HunterBite) -> int:
	return held.size() if bite.holding() else bite.capacity()


## Open on a school ahead; shut when the mouth is full, the fish stopped coming in, the school has passed or it was held too long.
func bot_plan(bot: WhatStinksBot, bite: HunterBite) -> Dictionary:
	var settings := bite.settings
	var gap := bot.target_gap
	var ready := bite.cooldown <= 0.0 and not bite.busy() and bot.target_ahead > 0.4 and not bot.stinker_blocks
	if settings.bite_mode == WhatStinksSettings.BiteMode.TAP:
		return {"press": ready and gap <= bite.reach() * settings.hunter_bot_bite_share, "hold": false}
	if not bite.holding():
		return {"press": ready and gap <= bite.reach() * settings.hunter_bot_open_gap, "hold": false}
	var full := held.size() >= max_held(bite)
	var spent := not held.is_empty() and _idle > 0.8
	var passed := held.is_empty() and (bot.target_ahead < 0.0 or gap > bite.reach() * settings.hunter_bot_open_gap * 2.5)
	var release := full or spent or passed or bite.held_for > 7.0
	return {"press": false, "hold": not release}


func _holds_prey(prey: FishController) -> bool:
	for h in held:
		if h.get("prey") == prey:
			return true
	return false


## Whether a joined player (its fish is a place in a school): the school's own fish is what the box sees.
func _joined(field: WhatStinksField, prey: FishController) -> bool:
	for school in field.schools:
		if is_instance_valid(school) and school.claim_of(prey) >= 0:
			return true
	return false


func _took(bite: HunterBite, at: Vector3) -> void:
	_idle = 0.0
	bite.fx().engulf(held.size(), at)


## The mouth's box, in the fish's axes: where the lips are (`rel`), how long it reaches ahead and how wide and tall it is
## (it follows how open the jaw is).
func _update_box(bite: HunterBite, open: float) -> void:
	var b := bite.fish.global_basis.orthonormalized()
	var width := bite.radius() * bite.settings.engulf_box_width
	_box = {"rel": b.inverse() * (bite.mouth_point() - bite.fish.global_position), "len": bite.reach() * bite.settings.engulf_box_len,
			"hw": width * maxf(clampf(open, 0.0, 1.0), 0.15), "hh": width * 0.8 * maxf(clampf(open, 0.0, 1.0), 0.15)}


## Whether world point `at` is inside `box` on `fish` now: from just behind the lips to `len` ahead, `hw` to each side and `hh` up and down.
static func _in_box(fish: FishController, box: Dictionary, at: Vector3) -> bool:
	if box.is_empty():
		return false
	var b := fish.global_basis.orthonormalized()
	var local := b.inverse() * (at - fish.global_position) - (box["rel"] as Vector3)
	var length: float = box["len"]
	return local.z <= length * 0.12 and local.z >= -length and absf(local.x) <= float(box["hw"]) and absf(local.y) <= float(box["hh"])


## A place to ride in the mouth (world): well inside the box.
func _slot_world(bite: HunterBite) -> Vector3:
	var b := bite.fish.global_basis.orthonormalized()
	var rel: Vector3 = _box["rel"]
	var at := rel + Vector3(_rng.randf_range(-0.4, 0.4) * float(_box["hw"]), _rng.randf_range(-0.35, 0.25) * float(_box["hh"]), -float(_box["len"]) * _rng.randf_range(0.12, 0.5))
	return bite.fish.global_position + b * at


## The same place in the fish's space (School.hold takes the holder's space).
func _slot(bite: HunterBite) -> Vector3:
	return bite.fish.to_local(_slot_world(bite))


## Lets go of everything held: school fish back to their boids (those eaten are gone already), prey players free.
func _release_all(bite: HunterBite) -> void:
	for h in held:
		var school := h.get("school") as School
		if school != null and is_instance_valid(school):
			school.release_hold(int(h["index"]))
		var prey := h.get("prey") as FishController
		if prey != null and is_instance_valid(prey) and not prey.puppet:
			var eaten := false
			if bite.world != null and is_instance_valid(bite.world):
				eaten = (bite.world.get("eaten") as Dictionary).has(prey)
			if not eaten:
				prey.freeze = false
				prey.controls_locked = false
	held.clear()
	_expire = 0.0
