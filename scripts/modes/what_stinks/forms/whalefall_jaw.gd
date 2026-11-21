extends HunterJaw
## The Whale Fall's mouth for HunterBite (meta "hunter_jaw" on the model): the carcass has no hinged jaw to
## move, so pose() only hands the bite's `open` on; WhaleFallRig reads it (the hagfish rear back on the wind-up,
## lash out as the jaws shut and tie themselves in a knot).

## How far open the bite has the mouth (0 shut to 1 gaping).
var opened := 0.0
## The mouth, in the model's space (the fish's visual).
var mouth_at := Vector3.ZERO


func mouth_local() -> Vector3:
	return mouth_at


func pose(jaw: float) -> void:
	opened = jaw
