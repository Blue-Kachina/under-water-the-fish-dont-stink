class_name HuntSettings
extends Resource
## Hunt's own tuning, shown in the tuning panel's HUNT section (the descriptor's
## "settings") and saved with presets ([hunt]). One shared copy (shared()) that
## the panel edits and HuntMatch reads. The floor clearance and push it shares
## with Nature stay in NatureSettings (the sea floor kit's values).

static var _shared: HuntSettings


## The copy the panel edits and Hunt reads.
static func shared() -> HuntSettings:
	if _shared == null:
		_shared = HuntSettings.new()
	return _shared


@export_group("Sea Floor")
## A seabed under Hunt's arena (with rock when Unnatural's terrain_enabled is on). Off: open water, as before.
@export var floor_enabled := false
## How far below the arena's centre the floor lies (m).
@export_range(5.0, 200.0, 1.0, "or_greater") var floor_depth := 22.0
