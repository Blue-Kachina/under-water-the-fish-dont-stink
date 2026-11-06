extends Node
## A bare match for ghost_bench.
signal marco_scan_started(origin: Vector3, seeker: Node)
signal round_started(index: int, seeker: Node)
var settings := MarcoPoloSettings.new()


func local_view_role() -> int:
	return 1
