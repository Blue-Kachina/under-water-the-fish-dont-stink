class_name NatureSettings
extends Resource
## Nature's own tuning (schools of fish, and later multis and pearls), shown in
## the tuning panel's NATURE section and saved with presets ([nature] in
## presets/nature.cfg). One shared copy (shared()) is what the panel edits and
## what NatureRun and its schools read, live: most values take effect at once,
## and the school count and size add or take away fish as they change.
##
## Ranges are deliberately wide, from 0 (off) to several times the sensible
## value, so both a light touch and exaggerated play can be tried. Sliders
## marked or_greater take bigger values typed into a preset too.

static var _shared: NatureSettings


## The copy the panel edits and Nature reads.
static func shared() -> NatureSettings:
	if _shared == null:
		_shared = NatureSettings.new()
	return _shared


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
## swims too. On until batteries come to the schools.
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

@export_group("Spawning")
## The first school turns up this far from the player (m), off to one side ahead.
@export_range(0.0, 200.0, 1.0, "or_greater") var first_school_distance := 45.0
## Later schools turn up this far from the player (m).
@export_range(0.0, 300.0, 1.0, "or_greater") var spawn_distance_min := 40.0
@export_range(0.0, 300.0, 1.0, "or_greater") var spawn_distance_max := 70.0
## A school further than this from the player (m) is replaced by a new one nearer.
@export_range(20.0, 1000.0, 5.0, "or_greater") var leash := 150.0
## Seconds before a wiped-out school is replaced.
@export_range(0.0, 30.0, 0.1, "or_greater") var respawn_time := 2.0

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

@export_group("Batteries")
## School fish can be battered (rammed nose first at nature_batter_speed or faster).
@export var school_batteries := true
## The share of the player's speed each school fish battered takes off it (0: none, 1: stops it dead).
@export_range(0.0, 1.0, 0.01) var hit_speed_cost := 0.03
## The speed cost never takes the player below the battering speed, so one hit
## can't end a run of them by itself.
@export var hit_cost_keeps_batter_speed := true
## How big a battered school fish's explosion is (m).
@export_range(0.0, 20.0, 0.1, "or_greater") var fish_explosion := 1.2
## How many sparks it throws, against a full explosion's. Under 1 it's just a
## pop: sparks and a flash, without the shockwave shell and bubble cloud; 1 is
## a full explosion.
@export_range(0.0, 1.0, 0.01) var fish_explosion_particles := 0.3

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

@export_group("Multis & Sprees")
## Batteries this close together (s) chain into a multi: Double Dip, Triple Fry...
@export_range(0.2, 10.0, 0.1, "or_greater") var multi_window := 2.5
## A spree (batteries without slowing down) ends after this long (s) under the battering speed.
@export_range(0.0, 10.0, 0.1, "or_greater") var spree_grace := 1.0
## Every this many batteries in a spree is a milestone: Spring Roll, Riptide...
@export_range(1, 50, 1, "or_greater") var spree_step := 5
## Points for each fish battered.
@export_range(0.0, 1000.0, 5.0, "or_greater") var battery_points := 100.0
## A multi's bonus: this times one more than the chain (+150 for a Double Dip, +200 a Triple Fry...).
@export_range(0.0, 1000.0, 5.0, "or_greater") var multi_bonus := 50.0
## A spree milestone's bonus: this times which milestone it is.
@export_range(0.0, 2000.0, 10.0, "or_greater") var spree_bonus := 250.0
## Every point is multiplied by this.
@export_range(0.0, 10.0, 0.1, "or_greater") var points_scale := 1.0

@export_group("Pearls")
## The chance (0..1) a battered fish leaves a pearl...
@export_range(0.0, 1.0, 0.01) var pearl_chance := 0.2
## ...plus this for each step of a multi past the first (capped at 1).
@export_range(0.0, 1.0, 0.01) var pearl_chance_per_step := 0.15
## Pearls this near the player (m) are drawn to it...
@export_range(0.0, 50.0, 0.5, "or_greater") var magnet_radius := 6.0
## ...this fast at the edge (m/s, on top of keeping up with the player), faster nearer.
@export_range(0.0, 100.0, 0.5, "or_greater") var magnet_strength := 10.0
## Within this (m) of the player's fish, a pearl is absorbed.
@export_range(0.0, 10.0, 0.05, "or_greater") var absorb_radius := 1.2
## How long (s) a pearl waits before fading away.
@export_range(1.0, 120.0, 1.0, "or_greater") var pearl_lifetime := 20.0
## A pearl's radius (m).
@export_range(0.05, 3.0, 0.01, "or_greater") var pearl_size := 0.22

@export_group("Targeting")
## Holding ball cam this long (s) opens the school wheel instead of toggling ball cam.
@export_range(0.1, 2.0, 0.05) var wheel_hold_time := 0.3
## Arrows at the screen's edge point to schools off screen (the target's always shows).
@export var school_arrows := true
