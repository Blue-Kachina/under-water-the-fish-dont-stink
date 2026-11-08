class_name HunterBite
extends Node
## A Hunter's bite (what_stinks.md section 2; two-stage-attack.md): the core verb of every
## form. A child of the Hunter's FishController, driven by a button (a controller or bot
## input: jump, boost, powerslide or air_roll, read off the fish so people and FishInput
## bots bite alike). In `hold` mode (WhatStinksSettings.bite_mode) it is two beats: the
## press opens the jaws (a ChompKit.Bite held open, the shark's own chomp) and they stay
## wide, charging, for as long as the button is down; the release slams them shut. A tap
## (released before they are fully open) strikes at once from the partial open, a snap. In
## `tap` mode the press is the whole bite (the jaws already wide, straight to the strike).
## On the tick they're shut (the contact frame) it emits chomped(): the mouth, reach, radius
## and how many fish it takes. What it eats is the mode's call (the style's catch_rule, see
## HunterAttack); in_bite() says whether a point is inside it.
##
## The bite is a frustum along the nose from the mouth: reach long, half as wide
## as `radius` at the far end and a quarter of that at the mouth. Reach, radius
## and capacity come from HunterSize and the form's sheet, so they follow the size; the
## charge scales reach and capacity per the style. Holding costs: swim speed and turn
## (an open mouth is drag), the schools' alarm (WhatStinksMatch) and a longer cooldown.
## The Hunter's fish ignores jump and dodge (FishController.ignore_jump): a press is only a bite.
## The jaw and the head's lift and saw are the model's (HunterJaw, meta "hunter_jaw").

## The jaws shut on `mouth` (world): `reach` and `radius` m, taking up to `capacity` fish
## (the charge it was released at is strike_charge(), valid inside this signal).
signal chomped(mouth: Vector3, reach: float, radius: float, capacity: int)
## A bite of our own began (the jaws open; online it goes out so everyone sees them open).
signal opened
## Alias of `opened`, for one release.
signal started
## The held bite reached full charge.
signal charged
## The button was let go (or a one-press bite began) at `charge` (0 to 1): the jaws are shutting.
signal released(charge: float)
## The held bite was called off without a strike (knocked out, locked, round over).
signal aborted
## The contact tick, once the match has judged it (HunterBiteFx's cue for the landing's feel): `taken` fish
## went (0 a miss; -1 not known here: a puppet's, or a guest's own bite the host judges).
signal landed(taken: int)

## Seconds a puppet's reported charge may run ahead of what the host saw for it (lag).
const NET_SLACK := 0.3

## The input that bites: "jump", "boost", "powerslide" or "air_roll".
@export_enum("jump", "boost", "powerslide", "air_roll") var button := "jump"
## How much of the chomp's pull-back and lunge moves the whole body (1: as the chomp's head travel).
@export_range(0.0, 3.0, 0.05, "or_greater") var lunge_gain := 0.35
## The camera's punch when the jaws shut (x the chomp's own cam shake).
@export_range(0.0, 3.0, 0.05, "or_greater") var shake := 0.4
## A one-press bite (try_bite) chomps the instant the button is pressed (jaws already wide,
## straight to the strike, the body stays put) instead of winding up with the form's bite_wind.
@export var snap := true

var fish: FishController
var form := HunterForm.SHARK
var size := HunterSize.shared()
var settings := WhatStinksSettings.shared()
## The match this bite belongs to (WhatStinksMatch; null in a probe): the styles that take fish into the mouth read its field.
var world: Node
var attack: HunterAttack = HunterAttack.new()
var bite: ChompKit.Bite
## Seconds until the next bite may start.
var cooldown := 0.0
var bites := 0
## Seconds the jaws have been held open this bite.
var held_for := 0.0
## The host's cap on a guest's reported charge (set when its close arrives; see net_clamp).
var net_cap := 0.0

var _held := false
var _open_held := false
var _landing := false
var _taken := -1
var _fx: HunterBiteFx
var _strike_charge := 0.0
var _next_cooldown := 0.0
var _costed := false
var _cost := Vector2.ONE
var _jaw: HunterJaw
var _model: Node3D


## Fits the bite to `with_fish` (already wearing the form's look) and the form's sheet.
func setup(with_fish: FishController, with_form: Dictionary, with_size: HunterSize = null) -> void:
	fish = with_fish
	form = with_form
	if with_size:
		size = with_size
	attack = HunterAttack.make(str(form.get("attack", "chomp")))
	bite = ChompKit.Bite.new(UnnaturalSettings.shared())
	bite.charged.connect(func() -> void: charged.emit())
	fish.ignore_jump = true
	fish.set_meta("ws_bite", self)
	refresh_model()
	if _fx != null and is_instance_valid(_fx):
		_fx.queue_free()
	_fx = HunterBiteFx.new()
	_fx.name = "HunterBiteFx"
	add_child(_fx)
	_fx.attach(self)


## The Hunter's feel node (HunterBiteFx: sounds, rumble, hit-stop, sparks), made by setup().
func fx() -> HunterBiteFx:
	return _fx


## The match judged the landing in progress: `taken` fish went (see `landed`). Ignored outside the
## landing tick (a guest's bite the host judges arrives later; its feel already played).
func report_landing(taken: int) -> void:
	if _landing:
		_taken = taken


## Gives the fish back its jump and its speed (the bite is going away, or the round ended).
func release_fish() -> void:
	_apply_costs(false)
	_open_held = false
	attack.on_cancel(self)
	if is_instance_valid(fish) and _owns_fish():
		fish.ignore_jump = false
		fish.remove_meta("ws_bite")


## Whether this is the bite the fish is wearing (a newer one may have replaced it).
func _owns_fish() -> bool:
	return fish.has_meta("ws_bite") and fish.get_meta("ws_bite") == self


func _exit_tree() -> void:
	if is_instance_valid(fish) and _owns_fish():
		release_fish()


## Takes the fish's current model (call it again after a rebuild: set_look).
func refresh_model() -> void:
	_model = fish.get("_visual")
	_jaw = null
	if _model and _model.has_meta("hunter_jaw"):
		_jaw = _model.get_meta("hunter_jaw") as HunterJaw


func reach() -> float:
	return reach_at(effective_charge())


func radius() -> float:
	return size.bite_radius(fish, form)


func capacity() -> int:
	return capacity_at(effective_charge())


## The reach (m) if the bite were released at `at_charge` (the style's say on what holding buys).
func reach_at(at_charge: float) -> float:
	return size.bite_reach(fish, form) * attack.reach_mult_at(self, at_charge)


func capacity_at(at_charge: float) -> int:
	return maxi(1, roundi(size.bite_capacity(fish, form) * attack.capacity_mult_at(self, at_charge)))


## Whether the jaws are held open now (the button is down on a bite).
func holding() -> bool:
	return _open_held


## How charged the held bite is now (0 to 1).
func charge() -> float:
	return bite.charge if _open_held and bite != null else 0.0


## The charge the reach and capacity use now: the live charge while held, the release's while it strikes.
func effective_charge() -> float:
	return charge() if _open_held else _strike_charge


## The charge the bite was released at (valid while it strikes, and inside chomped).
func strike_charge() -> float:
	return _strike_charge


## Where the mouth is now (world).
func mouth_point() -> Vector3:
	if _jaw and is_instance_valid(_model):
		return _model.to_global(_jaw.mouth_local())
	return fish.global_position - fish.global_basis.z * fish.hitbox_length * 0.45


## Whether world point `at` is inside the bite now.
func in_bite(at: Vector3) -> bool:
	return in_frustum(mouth_point(), -fish.global_basis.z.normalized(), reach(), radius(), at)


## The bite's frustum from `mouth` along `forward`: whether `at` is in it (a guest's bite is judged
## on the host from the mouth and heading the guest reports).
static func in_frustum(mouth: Vector3, forward: Vector3, bite_reach: float, bite_radius: float, at: Vector3) -> bool:
	var off := at - mouth
	var along := off.dot(forward)
	if along < -bite_radius * 0.25 or along > bite_reach:
		return false
	var side := (off - forward * along).length()
	return side <= bite_radius * lerpf(0.25, 1.0, clampf(along / maxf(bite_reach, 0.001), 0.0, 1.0))


func busy() -> bool:
	return bite != null and bite.busy()


func _can_start() -> bool:
	return bite != null and not bite.busy() and cooldown <= 0.0 and not fish.battered and not fish.controls_locked


## Hold mode: the press. Opens the jaws if it can (idle, off cooldown, in play, and the style
## allows it). Returns whether it did.
func try_open() -> bool:
	if _open_held or not _can_start():
		return false
	if not attack.can_open(self):
		attack.on_denied(self)  # refused: a beat of its own, and no cooldown
		return false
	_open_held = true
	held_for = 0.0
	_strike_charge = 0.0
	net_cap = 0.0
	bite.open_now(float(form.get("open_s", 0.12)), size.bite_reach(fish, form), float(form.get("charge_s", 1.2)))
	_apply_costs(true)
	attack.on_open(self)
	opened.emit()
	started.emit()
	return true


## Hold mode: the release. Shuts the jaws (from however open they got: a tap strikes from at
## least tap_open_min). Returns whether there was a held bite to shut.
func try_close() -> bool:
	if not _open_held or bite == null:
		return false
	_strike_charge = bite.charge
	if bite.open < settings.tap_open_min:
		bite.open = settings.tap_open_min
	_next_cooldown = minf(float(form["bite_every"]) + settings.hold_cooldown_per_s * held_for, maxf(settings.hold_cooldown_max, float(form["bite_every"])))
	_open_held = false
	_apply_costs(false)
	bite.release()
	released.emit(_strike_charge)
	return true


## Calls a held bite off with no strike.
func abort() -> void:
	if not _open_held:
		return
	_open_held = false
	_apply_costs(false)
	bite.cancel()
	attack.on_cancel(self)
	aborted.emit()


## A whole bite in one call (tap mode's press; the probes and tools): starts one if it can.
## Snap: the jaws already wide and straight to the strike; otherwise the form's wind-up chomp.
func try_bite() -> bool:
	if _open_held or not _can_start():
		return false
	_begin()
	opened.emit()
	started.emit()
	if snap:
		released.emit(0.0)
	return true


## Online: the jaws open for a bite of a player on another machine (what that machine reported):
## the pose only, it judges nothing (its landing is the host's to judge, from the guest's report).
func net_open() -> void:
	if bite == null or _open_held or bite.busy() or not fish.puppet:
		return
	_open_held = true
	held_for = 0.0
	_strike_charge = 0.0
	net_cap = 0.0
	_next_cooldown = float(form["bite_every"])
	bite.open_now(float(form.get("open_s", 0.12)), size.bite_reach(fish, form), float(form.get("charge_s", 1.2)))
	attack.on_open(self)
	opened.emit()


## Online: the jaws shut on a player on another machine, at `at_charge` (already clamped by the
## host, see net_clamp); a negative one calls the bite off. Pose only.
func net_close(at_charge: float) -> void:
	if bite == null or not _open_held or not fish.puppet:
		return
	if at_charge < 0.0:
		abort()
		return
	_strike_charge = clampf(at_charge, 0.0, 1.0)
	net_cap = _strike_charge
	_open_held = false
	if bite.open < settings.tap_open_min:
		bite.open = settings.tap_open_min
	bite.release()
	released.emit(_strike_charge)


## The host: a guest's reported charge capped to what its puppet here has seen (its own hold
## clock plus the lag allowance), so a guest can't claim a charge it didn't hold.
func net_clamp(reported: float) -> float:
	if reported < 0.0:
		return reported
	var seen := bite.charge if bite != null else 0.0
	var allowed := minf(1.0, seen + NET_SLACK / maxf(float(form.get("charge_s", 1.2)), 0.001))
	return clampf(reported, 0.0, allowed)


## The chomp's first beat for a one-press bite: the jaws wide at once and straight to the
## strike (snap), or the form's wind-up.
func _begin() -> void:
	_strike_charge = 0.0
	_next_cooldown = float(form["bite_every"])
	if snap:
		bite.open = 1.0
		bite.lift = 0.7
		bite.strike_now(reach())
	else:
		bite.start(float(form["bite_wind"]), reach())


func _physics_process(delta: float) -> void:
	if bite == null or not is_instance_valid(fish):
		return
	cooldown = maxf(cooldown - delta, 0.0)
	var down := _pressed()
	if not fish.puppet:
		if settings.bite_mode == WhatStinksSettings.BiteMode.TAP:
			if _open_held:
				try_close()  # switched to tap while the jaws were open
			elif down and not _held:
				try_bite()
		elif down and not _held:
			try_open()
		elif not down and _held:
			try_close()
	_held = down
	if _open_held:
		held_for += delta
		attack.on_hold(self, delta)
		if not fish.puppet and (fish.battered or fish.controls_locked):
			abort()
	attack.on_tick(self, delta)
	var landed := bite.update(delta)
	if _jaw:
		_jaw.set_overshoot(bite.over)  # the gape's fling past wide (forms with their own jaws ignore it)
		_jaw.pose(bite.open)
	if is_instance_valid(_model):
		var chomp_settings := UnnaturalSettings.shared()
		_model.rotation = Vector3(bite.lift * chomp_settings.chomp_lift, bite.saw * chomp_settings.chomp_saw, 0.0)
	if bite.step != 0.0 and not snap and not fish.puppet and delta > 0.0:
		fish.apply_push(-fish.global_basis.z * bite.step / delta * lunge_gain * pow(size.size_of(fish), size.speed_exp))
	if landed:
		_land()


func _pressed() -> bool:
	match button:
		"boost":
			return fish.boost_held
		"powerslide":
			return fish.powerslide_held
		"air_roll":
			return fish.air_roll_held
	return fish.jump_held


## Swim speed and turn x the hold multipliers while the jaws are open (an open mouth is drag).
func _apply_costs(on: bool) -> void:
	if on == _costed or not is_instance_valid(fish):
		return
	if on:
		_cost = Vector2(maxf(settings.hold_speed_mult, 0.01), maxf(settings.hold_turn_mult, 0.01))
		fish.speed_scale *= _cost.x
		fish.top_speed_scale *= _cost.x
		fish.turn_scale *= _cost.y
		fish.rl_turn_scale *= _cost.y
	else:
		fish.speed_scale /= _cost.x
		fish.top_speed_scale /= _cost.x
		fish.turn_scale /= _cost.y
		fish.rl_turn_scale /= _cost.y
	_costed = on


func _land() -> void:
	cooldown = _next_cooldown
	bites += 1
	var at := mouth_point()
	_landing = true
	_taken = -1
	chomped.emit(at, reach(), radius(), capacity())  # the match judges it and report_landing()s
	_landing = false
	landed.emit(_taken)  # the feel: sounds, rumble, hit-stop, the camera's punch (HunterBiteFx)
	attack.on_landed(self)
	_strike_charge = 0.0
