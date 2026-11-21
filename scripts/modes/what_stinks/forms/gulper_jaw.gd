extends HunterJaw
## The Gulper's mouth for HunterBite (meta "hunter_jaw" on the model): the pouch has no hinged
## jaw, it gapes in the skin shader, so pose() only hands the bite's `open` on to GulperRig.

## How far open the bite has the mouth (0 shut to 1 gaping).
var opened := 0.0
## The mouth's opening, in the model's space.
var mouth_at := Vector3.ZERO


func mouth_local() -> Vector3:
	return mouth_at


func pose(jaw: float) -> void:
	opened = jaw
