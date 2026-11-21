class_name SchoolSettings
extends Resource
## The school kit's tuning (School, SchoolFish, TargetWheel): how schools swim,
## pack, scatter and are drawn, and the target wheel. A mode with schools
## extends it with its own values (Nature's NatureSettings does), so its panel
## section shows these too. shared() is the copy the panel edits: the mode
## with schools registers itself as the provider (NatureSettings.shared()).

## Set by the mode whose settings extend this one: returns its shared copy.
static var provider := Callable()
static var _fallback: SchoolSettings


## The copy the panel edits and the kit reads.
static func shared() -> SchoolSettings:
	if provider.is_valid():
		return provider.call()
	if _fallback == null:
		_fallback = SchoolSettings.new()
	return _fallback


@export_group("Schools")
## How many schools swim around the player at once.
@export_range(0, 40, 1, "or_greater") var school_count := 3
## Fish in each school when it turns up.
@export_range(1, 300, 1, "or_greater") var fish_per_school := 50
## A school fish's size against a playable fish of its kind.
@export_range(0.1, 3.0, 0.05, "or_greater") var fish_scale := 1.0
## How fast a school cruises (m/s).
@export_range(0.0, 40.0, 0.5, "or_greater") var school_speed := 5.5
## How quickly a school turns (degrees per second).
@export_range(0.0, 360.0, 5.0, "or_greater") var school_turn_rate := 30.0
## How far from where it turned up (m) a school roams, across and up/down.
@export_range(0.0, 200.0, 1.0, "or_greater") var roam_radius := 25.0
@export_range(0.0, 60.0, 0.5, "or_greater") var roam_height := 8.0
## Never more nose up or down than this while roaming (degrees).
@export_range(0.0, 89.0, 1.0) var max_climb := 30.0
## The lone target fish from before schools (a calm full-size fish to batter)
## swims too. On until battered fish come to the schools.
@export var lone_target := true

@export_group("Formation")
## The school's half-width and half-height (m): how tightly it packs. Each
## fish has a place in an ellipsoid this size around the school's leader.
@export_range(0.2, 20.0, 0.1, "or_greater") var spread := 2.5
## How much longer the school is (nose to tail) than it is wide.
@export_range(0.2, 5.0, 0.05, "or_greater") var spread_length := 1.5
## How hard each fish steers back to its place (1/s).
@export_range(0.0, 30.0, 0.1, "or_greater") var slot_pull := 3.0
## How much faster than the school a fish may swim to catch up to its place.
@export_range(1.0, 5.0, 0.05, "or_greater") var catch_up := 1.6
## How quickly a fish changes speed and direction (m/s²).
@export_range(0.0, 200.0, 1.0, "or_greater") var fish_accel := 30.0
## Fish closer than this (m) push apart.
@export_range(0.0, 5.0, 0.05, "or_greater") var separation := 0.8
## How hard they push apart (m/s² at contact).
@export_range(0.0, 100.0, 0.5, "or_greater") var separation_strength := 12.0
## How far each fish drifts around its place (m), so the school looks alive.
@export_range(0.0, 5.0, 0.05, "or_greater") var wander := 0.3
## How quickly it drifts (cycles per second).
@export_range(0.0, 5.0, 0.05, "or_greater") var wander_rate := 0.4
## How long (s) a turn takes to reach the back of the school from the front,
## so turns ripple through it.
@export_range(0.0, 3.0, 0.05, "or_greater") var ripple_delay := 0.35
## How much a fish rolls into its turns (0 stays level).
@export_range(0.0, 3.0, 0.05, "or_greater") var bank := 0.6

@export_group("Performance")
## How often schools steer (steps per second). Each frame draws between the
## last two steps, so lower is cheaper and still smooth, just less responsive.
@export_range(5.0, 120.0, 1.0) var sim_rate := 30.0
## How many fish in each school get a full model when near the camera (smooth
## tail and rippling skin); the rest are drawn as one baked mesh per tail pose.
@export_range(0, 60, 1, "or_greater") var detail_fish := 8
## How near the camera (m) a fish must be to get a full model.
@export_range(0.0, 100.0, 1.0, "or_greater") var detail_distance := 14.0
## School fish cast shadows (they cost about as much as the fish themselves).
@export var fish_shadows := false

@export_group("School Reactions")
## A school tightens into a bait ball when the player comes at it within this range (m)...
@export_range(0.0, 100.0, 1.0, "or_greater") var bait_range := 15.0
## ...closing on it at least this fast (m/s).
@export_range(0.0, 60.0, 0.5, "or_greater") var bait_speed := 8.0
## The bait ball's spread, against the school's usual (0.1: packed tight, 1: no change).
@export_range(0.05, 1.0, 0.01) var bait_tighten := 0.6
## How hard a scared school swerves away (degrees per second, on top of its turn rate).
@export_range(0.0, 360.0, 5.0, "or_greater") var bait_swerve := 40.0
## How quickly it tightens and relaxes again (1/s).
@export_range(0.1, 20.0, 0.1, "or_greater") var bait_rate := 3.0
## When a fish is battered, survivors this near it (m)...
@export_range(0.0, 30.0, 0.1, "or_greater") var burst_radius := 4.0
## ...burst away from it this fast (m/s, less further off), then regroup.
@export_range(0.0, 60.0, 0.5, "or_greater") var burst_strength := 6.0

@export_group("Targeting")
## Holding ball cam this long (s) opens the school wheel instead of toggling ball cam.
@export_range(0.1, 2.0, 0.05) var wheel_hold_time := 0.3
## Arrows at the screen's edge point to schools off screen (the target's always shows).
@export var school_arrows := true
