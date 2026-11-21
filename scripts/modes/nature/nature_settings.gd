class_name NatureSettings
extends SchoolSettings
## Nature's own tuning (spawning, battered fish, multis, pearls and the sea floor; the schools' own values are SchoolSettings', which this extends), shown in
## the tuning panel's NATURE section and saved with presets ([nature] in
## presets/nature.cfg). One shared copy (shared()) is what the panel edits and
## what NatureRun and its schools read, live: most values take effect at once,
## and the school count and size add or take away fish as they change.
##
## Ranges are deliberately wide, from 0 (off) to several times the sensible
## value, so both a light touch and exaggerated play can be tried. Sliders
## marked or_greater take bigger values typed into a preset too.

static var _natures: NatureSettings


## Nature's camera as a CameraStyle (the settle style, camera_settle), or null while it is off.
func camera_style() -> CameraStyle:
	if not camera_settle:
		return null
	var style := CameraStyle.settle()
	style.settle_rate = settle_rate
	style.settle_turning_rate = settle_turning_rate
	style.settle_turn_full = deg_to_rad(settle_turn)
	style.settle_smoothing = settle_smoothing
	style.settle_delay = settle_delay
	style.settle_max_angle = deg_to_rad(settle_max_angle)
	style.settle_coast_rate = settle_coast_rate
	style.settle_coast_ease = settle_coast_ease
	style.heading_climb = settle_climb
	return style


## The copy the panel edits and Nature reads.
static func shared() -> NatureSettings:
	if _natures == null:
		_natures = NatureSettings.new()
		SchoolSettings.provider = NatureSettings.shared
	return _natures


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

@export_group("Battered fish")
## School fish can be battered (rammed nose first at nature_batter_speed or faster).
@export var batter_schools := true
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

@export_group("Multis & Sprees")
## Battered fish this close together (s) chain into a multi: Double Dip, Triple Fry...
@export_range(0.2, 10.0, 0.1, "or_greater") var multi_window := 2.5
## A spree (battered fish without slowing down) ends after this long (s) under the battering speed.
@export_range(0.0, 10.0, 0.1, "or_greater") var spree_grace := 1.0
## Every this many battered fish in a spree is a milestone: Spring Roll, Riptide...
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

@export_group("Camera")
## Nature's chase camera in the settle style (CameraStyle, the survivor cam's): it turns by its own
## smoothed heading instead of straight with the nose, so stride sweeps don't swing the view, and swings
## round behind the fish once it swims straight. Off: the usual nose-following chase view. Play-test
## switch: off by default until it has been tried.
@export var camera_settle := false
## How quickly the view swings round behind the fish swimming straight (1/s). Slower than the survivor cam's 3, so a
## stride chain's weave (which M1 keeps small) is not followed: the stride-rate wobble is about 1.4 degrees peak to peak.
@export_range(0.1, 30.0, 0.1, "or_greater") var settle_rate := 1.5
## ...and while it is turning (1/s): lower shows the turn longer.
@export_range(0.0, 30.0, 0.05, "or_greater") var settle_turning_rate := 0.5
## The turn rate (degrees/s) that counts as fully turning.
@export_range(5.0, 720.0, 5.0, "or_greater") var settle_turn := 90.0
## How long (s) the fish's turning is averaged over, so a stride's sweep one way and back cancels out.
@export_range(0.0, 3.0, 0.05, "or_greater") var settle_smoothing := 0.3
## How long (s) the swing round takes to build once a turn ends.
@export_range(0.0, 5.0, 0.05, "or_greater") var settle_delay := 0.4
## How far (degrees) the nose can get off to the side before the view is turned with it (180: any).
@export_range(10.0, 180.0, 1.0) var settle_max_angle := 75.0
## How quickly the view swings round behind while accelerate, reverse and boost are let go (1/s; 0: no faster than swimming).
@export_range(0.0, 30.0, 0.1, "or_greater") var settle_coast_rate := 6.0
## How long (s) that takes to come in once they are.
@export_range(0.0, 2.0, 0.05, "or_greater") var settle_coast_ease := 0.15
## How much of the nose's climb the view follows (0: stays level).
@export_range(0.0, 1.0, 0.05) var settle_climb := 0.4

@export_group("Sea Floor")
## A sea floor (planning_procedural_world.md, phase 8): Nature gets endless terrain far below, streamed round the player;
## Off: open water, as before. (Hunt's own floor switch and depth are in HuntSettings.)
@export var nature_floor := false
@export_range(10.0, 400.0, 1.0, "or_greater") var nature_floor_depth := 60.0
## Hunt's floor: how far above it fish are kept (m), and how hard (m/s² per metre under).
@export_range(0.0, 20.0, 0.1, "or_greater") var floor_clearance := 1.5
@export_range(0.0, 50.0, 0.1, "or_greater") var floor_push := 6.0
