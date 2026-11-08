extends HunterJaw
## The Lamprey Queen's mouth for a Hunter (HunterBite drives it as it does HunterJaw): she has no hinged jaw,
## the oral disc flares in the skin shader, so pose(open) only hands the bite's `open` on to the rig.
## The first pose also seats the drill's exaggeration (lamprey_exaggerate.gd: disc flare, teeth spin-up, body telescope) beside the rig.
## Not a class_name: the Lamprey form preloads it.

const Exaggerate := preload("res://scripts/what_stinks/forms/lamprey_exaggerate.gd")

var rig: Node3D  # lamprey_rig.gd
var _shown_open := -1.0
var _exaggerate: Node


## Where the disc is, in the model's space (the fish's visual): the head's tip.
func mouth_local() -> Vector3:
	if rig == null or not is_instance_valid(rig.fish):
		return Vector3.ZERO
	var at := Vector3(0.0, 0.0, -rig.fish.hitbox_length * 0.5 + rig.radius * 0.3)
	var visual: Node3D = rig.get_parent()
	var s := visual.scale
	return Vector3(at.x / s.x, at.y / s.y, at.z / s.z)


func pose(open: float) -> void:
	if rig == null:
		return
	if _exaggerate == null or not is_instance_valid(_exaggerate):
		_exaggerate = rig.get_node_or_null("LampreyExaggerate")
		if _exaggerate == null:
			_exaggerate = Exaggerate.new()
			_exaggerate.set("rig", rig)
			rig.add_child(_exaggerate)
	if is_equal_approx(open, _shown_open):
		return
	_shown_open = open
	rig.set_disc(open)


## The drill's exaggeration (LampreyExaggerate), for cameras and probes; null before the first pose.
func exaggeration() -> Node:
	return _exaggerate if is_instance_valid(_exaggerate) else null


## A camera collision radius padded for the exaggeration now (the disc flared, the body stretched).
func camera_margin(radius: float) -> float:
	var e := exaggeration()
	return e.call("camera_margin", radius) if e != null else radius
