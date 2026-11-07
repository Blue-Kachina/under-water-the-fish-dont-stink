extends HunterJaw
## The Fallen Angel's mouth for HunterBite (meta "hunter_jaw" on the model): it has no hinged jaw, the crown of
## tentacles opens out of the top of its head, so pose() only hands the bite's `open` on to AngelRig.

## How far open the bite has the crown (0 shut to 1 splayed).
var opened := 0.0
## The crown's base, in the model's space.
var mouth_at := Vector3.ZERO


func mouth_local() -> Vector3:
	return mouth_at


func pose(jaw: float) -> void:
	opened = jaw
