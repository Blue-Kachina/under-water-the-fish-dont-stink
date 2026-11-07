class_name HunterBite
extends Node
## A Hunter's bite (what_stinks.md section 2): the core verb of every form. A
## child of the Hunter's FishController. A press of `button` (a controller or
## bot input: jump, boost, powerslide or air_roll, read off the fish so people
## and FishInput bots bite alike) starts a ChompKit.Bite, the shark's own chomp:
## the head pulls back and the jaw gapes open, holds wide, then the head lunges
## and the jaws slam shut. On the tick they're shut (the contact frame) it
## emits chomped(): the mouth, reach, radius and how many fish it takes. What
## it eats is the mode's call (School.eat in Phase 1); in_bite() says whether
## a point is inside it.
##
## The bite is a frustum along the nose from the mouth: reach long, half as wide
## as `radius` at the far end and a quarter of that at the mouth. Reach, radius
## and capacity come from HunterSize and the form's sheet, so they follow the size.
## The jaw and the head's lift and saw are the model's (HunterJaw, meta "hunter_jaw").

## The jaws shut on `mouth` (world): `reach` and `radius` m, taking up to `capacity` fish.
signal chomped(mouth: Vector3, reach: float, radius: float, capacity: int)
## A bite of our own began (the wind-up; online it goes out so everyone sees the jaws open).
signal started

## The input that bites: "jump", "boost", "powerslide" or "air_roll".
@export_enum("jump", "boost", "powerslide", "air_roll") var button := "jump"
## How much of the chomp's pull-back and lunge moves the whole body (1: as the chomp's head travel).
@export_range(0.0, 3.0, 0.05, "or_greater") var lunge_gain := 0.35
## The camera's punch when the jaws shut (x the chomp's own cam shake).
@export_range(0.0, 3.0, 0.05, "or_greater") var shake := 0.4
## Chomps the instant the button is pressed (jaws already wide, straight to the strike, the body
## stays put) instead of winding up (WhatStinksSettings.bite_snap sets it).
@export var snap := true

var fish: FishController
var form := HunterForm.SHARK
var size := HunterSize.shared()
var bite: ChompKit.Bite
## Seconds until the next bite may start.
var cooldown := 0.0
var bites := 0

var _held := false
var _jaw: HunterJaw
var _model: Node3D


## Fits the bite to `with_fish` (already wearing the form's look) and the form's sheet.
func setup(with_fish: FishController, with_form: Dictionary, with_size: HunterSize = null) -> void:
	fish = with_fish
	form = with_form
	if with_size:
		size = with_size
	bite = ChompKit.Bite.new(UnnaturalSettings.shared())
	refresh_model()


## Takes the fish's current model (call it again after a rebuild: set_look).
func refresh_model() -> void:
	_model = fish.get("_visual")
	_jaw = null
	if _model and _model.has_meta("hunter_jaw"):
		_jaw = _model.get_meta("hunter_jaw") as HunterJaw


func reach() -> float:
	return size.bite_reach(fish, form)


func radius() -> float:
	return size.bite_radius(fish, form)


func capacity() -> int:
	return size.bite_capacity(fish, form)


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


## Starts a bite if it can (idle, off cooldown, in play). Returns whether it did.
func try_bite() -> bool:
	if bite == null or bite.busy() or cooldown > 0.0 or fish.battered or fish.controls_locked:
		return false
	_begin()
	started.emit()
	return true


## Online: the jaws open for a bite of a player on another machine (what that machine reported):
## the pose only, it judges nothing (its landing is the host's to judge, from the guest's report).
func net_start() -> void:
	if bite == null or bite.busy() or not fish.puppet:
		return
	_begin()


## The chomp's first beat: the form's wind-up, or (snap) the jaws wide at once and straight to the strike.
func _begin() -> void:
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
	var held := _pressed()
	if held and not _held and not fish.puppet:
		try_bite()
	_held = held
	var landed := bite.update(delta)
	if _jaw:
		_jaw.set_overshoot(bite.over)  # the gape's fling past wide (forms with their own jaws ignore it)
		_jaw.pose(bite.open)
	if is_instance_valid(_model):
		var settings := UnnaturalSettings.shared()
		_model.rotation = Vector3(bite.lift * settings.chomp_lift, bite.saw * settings.chomp_saw, 0.0)
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


func _land() -> void:
	cooldown = float(form["bite_every"])
	bites += 1
	var at := mouth_point()
	if not fish.puppet:
		for node in get_tree().get_nodes_in_group(ChompKit.CAMERAS):
			if node.get("fish") == fish and node.has_method("punch"):
				node.call("punch", UnnaturalSettings.shared().chomp_cam_shake * shake, Vector3.ZERO)
	chomped.emit(at, reach(), radius(), capacity())
