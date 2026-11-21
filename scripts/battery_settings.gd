class_name BatterySettings
extends Resource
## The Battery kit's tuning, shown in the tuning panel's BATTERY section and
## saved with presets ([battery]). One shared copy (shared()) that Nature, Hunt,
## the 1v1 and Unnatural's ram all read, live. It used to be the fish's
## nature_batter_speed (which still reads and writes this, for old callers).

static var _shared: BatterySettings


## The copy the panel edits and the modes read.
static func shared() -> BatterySettings:
	if _shared == null:
		_shared = BatterySettings.new()
	return _shared


@export_group("Battering")
## The slowest ram that batters (m/s): Nature's target fish, Hunt's opponent, a 1v1 rival and Unnatural's zombies. RL's supersonic: 22.
@export_range(0.0, 200.0, 0.5, "or_greater") var batter_speed := 22.0
