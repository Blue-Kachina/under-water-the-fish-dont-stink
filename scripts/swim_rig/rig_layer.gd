class_name RigLayer
extends RefCounted
## One layer of a SwimRig (planning_core_roadmap.md 2.2): reads the SwimState and
## the class's Gait and adds into the shared SwimPose. Layers hold only their own
## springs and clocks (preallocated); every number comes from the Gait.


## This layer's weight in `gait` (0 skips it).
func weight(_gait: Gait) -> float:
	return 0.0


func evaluate(_rig: SwimRig, _state: SwimState, _gait: Gait, _dt: float, _pose: SwimPose) -> void:
	pass


## Forgets springs and history (the layer was off, or the fish was cut).
func reset() -> void:
	pass
