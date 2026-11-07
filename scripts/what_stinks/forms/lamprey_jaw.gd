extends HunterJaw
## The Lamprey Queen's mouth for a Hunter (HunterBite drives it as it does HunterJaw): she has no hinged jaw,
## the oral disc flares in the skin shader, so pose(open) only hands the bite's `open` on to the rig.
## Not a class_name: the Lamprey form preloads it.

var rig: Node3D  # lamprey_rig.gd
var _shown_open := -1.0


## Where the disc is, in the model's space (the fish's visual): the head's tip.
func mouth_local() -> Vector3:
	if rig == null or not is_instance_valid(rig.fish):
		return Vector3.ZERO
	var at := Vector3(0.0, 0.0, -rig.fish.hitbox_length * 0.5 + rig.radius * 0.3)
	var visual: Node3D = rig.get_parent()
	var s := visual.scale
	return Vector3(at.x / s.x, at.y / s.y, at.z / s.z)


func pose(open: float) -> void:
	if rig == null or is_equal_approx(open, _shown_open):
		return
	_shown_open = open
	rig.set_disc(open)
