class_name HunterSize
extends Resource
## The Hunter's size dial (what_stinks.md section 3): one multiplier, size_mult
## (1 the form's natural size), moves everything that must stay consistent. The
## couplings are settings so each can be flattened (exponent 0 = not scaled).
## One shared copy (shared()) is what the panel edits; WhatStinksSettings can
## own it later. A fish's own `size_mult` meta multiplies on top (the reserved
## power-up hook: a timed multiplier), so nothing else has to know.
##
##   model + hitbox          x s          (FishController.body_scale; the Titan model's LODs follow)
##   bite reach, radius      x s^bite_reach_exp
##   bite capacity           x s^bite_capacity_exp
##   top speed, boost push   x s^speed_exp;  thrust x s^accel_exp
##   turn rate               x s^-turn_exp
##   camera distance/height  x s in proportion, cam_frame of the way (frame())
##   school alarm radius     x s^alarm_exp
##   murk sight              x s^sight_exp

## The camera's own size zoom: bodies up to this long (m) are framed as ever,
## and past it the distance grows by the ratio to the power CAM_POWER
## (FollowCamera.BODY_ZOOM_BASE and BODY_ZOOM_POWER).
const CAM_BASE := 1.35
const CAM_POWER := 0.75

static var _shared: HunterSize


static func shared() -> HunterSize:
	if _shared == null:
		_shared = HunterSize.new()
	return _shared


@export_group("Hunter size")
## The Hunter's size: 1 is the form's natural size.
@export_range(0.25, 30.0, 0.05, "or_greater") var size_mult := 1.0
## Top speed and thrust x size^this (0: size does not change them).
@export_range(0.0, 2.0, 0.05, "or_greater") var speed_exp := 0.5
## Acceleration x size^this.
@export_range(0.0, 2.0, 0.05, "or_greater") var accel_exp := 0.5
## Turn rate x size^-this (bigger turns slower).
@export_range(0.0, 2.0, 0.05, "or_greater") var turn_exp := 0.5
## Fish per bite x size^this (bigger mouths eat more than they reach).
@export_range(0.0, 3.0, 0.05, "or_greater") var bite_capacity_exp := 1.5
## Bite reach and radius x size^this (1: in step with the body).
@export_range(0.0, 2.0, 0.05, "or_greater") var bite_reach_exp := 1.0
## How much of the size the camera's distance and height follow (1: framed the same at any size).
@export_range(0.0, 2.0, 0.05, "or_greater") var cam_frame := 1.0
## School alarm radius x size^this.
@export_range(0.0, 2.0, 0.05, "or_greater") var alarm_exp := 1.0
## Murk sight (los_range) x size^this.
@export_range(0.0, 2.0, 0.05, "or_greater") var sight_exp := 0.5


## The size now on `fish`: the panel's size_mult times its own `size_mult` meta, kept in range.
func size_of(fish: Node = null) -> float:
	var own := float(fish.get_meta("size_mult", 1.0)) if fish != null else 1.0
	return clampf(size_mult * own, 0.25, 30.0)


## Puts `form` (a HunterForm sheet) on `fish` at its size: body (model and
## hitbox), speed, acceleration, drag and turn. The fish must already wear the
## form's class and species (FishController.set_look). Returns the size used.
func apply(fish: FishController, form: Dictionary) -> float:
	var s := size_of(fish)
	fish.body_scale = HunterForm.body_scale(form) * s
	fish.top_speed_scale = float(form["speed"]) * pow(s, speed_exp)
	fish.accel_scale = float(form["accel"]) * pow(s, accel_exp)
	fish.boost_scale = pow(s, speed_exp)  # the boost's push, so a big one reaches its higher top speed
	fish.drag_scale = float(form["accel"])  # heavy to start, hard to stop (as the Titans); not with size, or a big one is capped by its own drag
	fish.turn_scale = float(form["turn"]) * pow(s, -turn_exp)
	fish.rl_turn_scale = fish.turn_scale  # the RL air control only honours this one
	rescale_lod(fish)
	return s


## A model's LOD ranges follow the visual root's scale (the Titan model's
## titan_lod_rescale meta; any model that has one, so the boss meshes can join in).
func rescale_lod(fish: FishController) -> void:
	var model: Node = fish.get("_visual")
	if model != null and model.has_meta("titan_lod_rescale"):
		(model.get_meta("titan_lod_rescale") as Callable).call(fish.body_scale)


## The bite's reach (m) from the mouth for `fish`.
func bite_reach(fish: Node, form: Dictionary) -> float:
	return float(form["bite_reach_m"]) * pow(size_of(fish), bite_reach_exp)


## The bite's far half width (m).
func bite_radius(fish: Node, form: Dictionary) -> float:
	return float(form["bite_radius_m"]) * pow(size_of(fish), bite_reach_exp)


## Fish one bite takes (at least 1).
func bite_capacity(fish: Node, form: Dictionary) -> int:
	return maxi(1, roundi(float(form["capacity"]) * pow(size_of(fish), bite_capacity_exp)))


## The radius (m) schools take alarm at, from `base` at size 1.
func alarm_radius(fish: Node, base: float) -> float:
	return base * pow(size_of(fish), alarm_exp)


## The murk sight range (m) from `base` at size 1.
func sight_range(fish: Node, base: float) -> float:
	return base * pow(size_of(fish), sight_exp)


## Frames the Hunter's view (a FollowCamera) so its body looks as big on screen
## at any size. The camera's own zoom grows by the size ratio to CAM_POWER, so
## body_follow is set to make the zoom come out in proportion (cam_frame of the
## way), and the form's own distance/height factors go in extra_*. Returns the
## zoom the camera will have.
func frame(camera: Node, fish: FishController, form: Dictionary = {}) -> float:
	var full := maxf(fish.hitbox_length / CAM_BASE, 1.0)
	var own := pow(full, CAM_POWER)
	var want := lerpf(1.0, full, clampf(cam_frame, 0.0, 2.0))
	var follow := 1.0
	if own > 1.0001:
		follow = (want - 1.0) / (own - 1.0)
	if "body_follow" in camera:
		camera.set("body_follow", follow)
	if "extra_distance" in camera and not form.is_empty():
		var factor: Vector2 = form.get("cam", Vector2.ONE)
		camera.set("extra_distance", float(camera.get("distance")) * (factor.x - 1.0))
		camera.set("extra_height", float(camera.get("height")) * (factor.y - 1.0))
	return lerpf(1.0, own, follow)
