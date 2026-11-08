class_name DrillAttack
extends ChompAttack
## The Lamprey Queen's style (two-stage-attack.md 4f): the press flares the oral disc and the rasp spins up, the hold speeds it up and
## winds her body back, the release is a corkscrew dash. She drives forward at drill_dash x her top speed x the charge for drill_time
## seconds, rolling at lamprey_spin, and every fish the disc passes through is taken, up to the form's capacity x the charge
## (capacity_mult_at, drill_capacity_mult at full). The landing at the contact tick is the plain cone (the first of it); the dash then
## judges the tube the disc swept each tick (WhatStinksMatch.judge_drill) until the budget is spent or the time is. A hold shorter than
## drill_min_charge does not dash (a tap is the plain bite and the old latch roll). At full charge the first prey player the disc
## meets is latched: the dash ends there and LampreyRig rolls on it (consume_latch).
##
## Only the host judges (WhatStinksMatch.authority). It runs the dash's eating on a guest's Hunter too, on the puppet's synced
## position (as the engulf does), from the release the puppet is told of; the guest's own landing report judges the plain cone as
## ever (net_catch_rule), and the budget is shared, so nothing is eaten twice.

## What is left to take, the dash's seconds left and its speed (m/s), and how fast the top speed was raised for it.
var budget := 0
var dash_left := 0.0
var speed := 0.0
## Seconds into the dash (the rig's roll), and whether a latch is waiting for the rig to take it.
var dash_age := 0.0

var _raised := 1.0
var _prev := Vector3.ZERO
var _latch_ok := false
var _latch := false
var _taken := 0
var _total := 0
var _on := false


## The default lunge scale: the dash was too far (A3 feedback), this is about 55 percent of the travel it had.
const LUNGE_IMPULSE_DEFAULT := 0.55


func _init() -> void:
	key = "drill"


## lamprey_lunge_impulse: scales the dash's speed, and so how far the lunge (and its coast) carries her. 1.0 is the old,
## too-long lunge. Read from the panel setting; until the setting is registered a meta of the same name on the settings
## object stands in (the probe's override), then the default.
static func lunge_impulse(settings: Object) -> float:
	if settings == null:
		return LUNGE_IMPULSE_DEFAULT
	var v: Variant = settings.get("lamprey_lunge_impulse")
	if v == null and settings.has_meta("lamprey_lunge_impulse"):
		v = settings.get_meta("lamprey_lunge_impulse")
	return maxf(float(v), 0.0) if v != null else LUNGE_IMPULSE_DEFAULT


func reach_mult_at(_bite: HunterBite, _charge: float) -> float:
	return 1.0


func capacity_mult_at(bite: HunterBite, charge: float) -> float:
	return lerpf(1.0, bite.settings.drill_capacity_mult, charge)


## Whether the dash is on.
func active() -> bool:
	return dash_left > 0.0


## The dash's envelope for the exaggeration (0..1): up over the first 0.08 s, down over the last 0.25 s, 0 when it is not on. LampreyExaggerate
## eases the body's telescope, the disc's flare and the teeth's spin by it, so none of them pops when the dash starts or ends.
func dash_envelope() -> float:
	if dash_left <= 0.0:
		return 0.0
	return minf(smoothstep(0.0, 0.08, dash_age), smoothstep(0.0, 0.25, dash_left))


## The rig's: whether a latch has come up since it last asked (it then rolls on her prey for her latch time).
func consume_latch() -> bool:
	var was := _latch
	_latch = false
	return was


## How wound back the body is, from the charge (0 to 1): the hold winds her up, the release lets it go into the roll.
func wind_now(bite: HunterBite) -> float:
	return bite.charge() if bite.holding() else 0.0


func on_tick(bite: HunterBite, delta: float) -> void:
	var b := bite.bite
	if b != null and b.phase == ChompKit.Phase.STRIKE and b.t == 0.0 and dash_left <= 0.0:
		_start(bite)
	if dash_left > 0.0:
		_dash(bite, delta)


func on_close(bite: HunterBite, taken: Dictionary) -> void:
	var prey := taken.get("fish", []) as Array
	var count := int(taken.get("school_fish", 0)) + prey.size()
	budget = maxi(budget - count, 0)
	_taken += count
	_total += count
	if _on and _latch_ok and not prey.is_empty():
		_latch = true  # full charge and a prey player in the disc, at the contact or on the run: she latches, the dash ends
		_end(bite)


## The dash takes capacity x charge and no more, so the body ram (which would also take what her length touches) waits.
func suppresses_ram(_bite: HunterBite) -> bool:
	return dash_left > 0.0


func on_cancel(bite: HunterBite) -> void:
	_end(bite)


# --- The dash -----------------------------------------------------------------------------

func _start(bite: HunterBite) -> void:
	var settings := bite.settings
	var charge := bite.strike_charge()
	if charge < settings.drill_min_charge or settings.drill_dash <= 0.0 or settings.drill_time <= 0.0:
		return
	var fish := bite.fish
	_on = true
	dash_left = settings.drill_time
	dash_age = 0.0
	budget = bite.capacity_at(charge)
	_taken = 0
	_total = 0
	_latch = false
	_latch_ok = settings.drill_latch and charge >= 0.999
	_prev = bite.mouth_point()
	var base := fish.max_boost_speed * fish.top_speed_scale
	speed = base * settings.drill_dash * charge * lunge_impulse(settings)
	if not fish.puppet:
		_raised = maxf(speed / maxf(base, 0.001), 1.0)
		fish.top_speed_scale *= _raised  # the integrator caps a fish at its top speed: lift it for the dash


func _end(bite: HunterBite) -> void:
	if _raised != 1.0 and is_instance_valid(bite.fish):
		bite.fish.top_speed_scale /= _raised
	_raised = 1.0
	if _on and _taken > 0:
		bite.cooldown += bite.settings.chew_delay  # one chew for the whole run, not one per tick
	_on = false
	dash_left = 0.0
	_taken = 0


func _dash(bite: HunterBite, delta: float) -> void:
	var fish := bite.fish
	dash_left -= delta
	dash_age += delta
	var forward := -fish.global_basis.z.normalized()
	if not fish.puppet:
		fish.linear_velocity = forward * speed
	var mouth := bite.mouth_point()
	var from := _prev
	_prev = mouth
	var world := bite.world
	if budget > 0 and world != null and bool(world.get("authority")) and world.get("phase") == WhatStinksMatch.Phase.LIVE and from.distance_to(mouth) > 0.0001:
		var tube := bite.radius() * bite.settings.drill_radius_mult
		var inside := func(at: Vector3) -> bool: return Geometry3D.get_closest_point_to_segment(at, from, mouth).distance_to(at) <= tube
		if _anything_in(bite, inside, from.lerp(mouth, 0.5), from.distance_to(mouth) * 0.5 + tube):
			var before := _total
			world.call("judge_drill", fish, bite, from.lerp(mouth, 0.5), budget, inside)  # on_close counts what went (and latches on prey)
			if _total > before:
				bite.fx().drilled(_total, mouth)
	if dash_left <= 0.0:
		_end(bite)


## Whether a fish (or a prey player, if bites take them) is in the tube `inside` tests, `around` m of `mid`.
func _anything_in(bite: HunterBite, inside: Callable, mid: Vector3, around: float) -> bool:
	var world := bite.world
	var field: WhatStinksField = world.get("field")
	if field == null:
		return false
	for school in field.schools:
		if not is_instance_valid(school) or school.alive_count() == 0 or school.middle().distance_to(mid) > around + school.radius() * 2.0:
			continue
		for i in school.fish_count():
			if school.is_alive(i) and not school.is_claimed(i) and inside.call(school.fish_position(i)):
				return true
	if bite.settings.bite_takes_players:
		for prey: FishController in world.call("live_prey"):
			if is_instance_valid(prey) and prey != bite.fish and inside.call(prey.global_position):
				return true
	return false
