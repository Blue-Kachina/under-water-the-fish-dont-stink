extends HunterJaw
## The King of Herrings' jaw for a Hunter (HunterBite drives it as it does HunterJaw): the lower jaw is part
## of the King's one spine-bent mesh, hinged by the skin's `hinge` uniform, so pose(open) only turns that.
## The attack exaggeration (AttackExaggerate, B5) multiplies the gape: `ex` is the form's kit, refresh() re-applies the
## last pose every frame so the jaw rings out between the bite's ticks.
## Not a class_name: the King form preloads it.

## How far the jaw drops at open 1 (rad: as BloodLeviathan's gape).
const GAPE_ANGLE := 0.55

var rig: Node3D  # king_rig.gd
## The exaggeration kit (set by the form), or null: the gape is then the plain one.
var ex: AttackExaggerate
var _shown_open := -1.0
var _shown_angle := -999.0


## Where the mouth is, in the model's space (the fish's visual): the head's tip, a little under the nose.
func mouth_local() -> Vector3:
	if rig == null or not is_instance_valid(rig.fish):
		return Vector3.ZERO
	var at := Vector3(0.0, -rig.girth * 0.3, -rig.fish.hitbox_length * 0.5 + 0.5 * rig.girth / 6.0)
	var visual: Node3D = rig.get_parent()
	var s := visual.scale
	return Vector3(at.x / s.x, at.y / s.y, at.z / s.z)


func pose(open: float) -> void:
	_shown_open = open
	refresh()


## The hinge for the last pose, with the kit's jaw scale on it (the gape swells with the charge, snaps and rings on release).
func refresh() -> void:
	if rig == null or _shown_open < 0.0:
		return
	var angle := _shown_open * GAPE_ANGLE * (ex.scale_of(&"jaw") if ex != null else 1.0)
	if is_equal_approx(angle, _shown_angle):
		return
	_shown_angle = angle
	rig.set_jaw(angle)
