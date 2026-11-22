class_name RaceSettings
extends Resource
## Fin-ish Line's own tuning (planning_race.md sections 3, 6, 7, 8, 9): the match, the one shared speed every racer
## swims at, rescue rules, the track's currents and the bots. Shown in the tuning panel's RACE section and saved
## with presets ([race]). One shared copy (shared()) is what the panel edits and what RaceMatch and its helpers read,
## live. As in the other settings, ranges are wide: 0 switches a feature off and the top end is several times the
## sensible value. Nothing here is tuned yet beyond Phase 0's measurements (play-test before changing them).

## How hard the bots race (BotDifficulty tiers; the rubber band is on at EASY, off at HARD).
enum Bots { EASY, NORMAL, HARD }

## The bot tiers' names on the match card.
const BOT_NAMES := ["Easy", "Normal", "Hard"]
## The tracks the card offers (name -> script with a static data(): RaceTrack's dictionary).
const TRACKS := ["Canyon Reef Circuit", "Grey Box"]
## The mode's settings key in the tuning panel and presets.
const KEY := "race"
## Measured in Phase 0 (race_phase0.md): in Nature's swimming a perfect stride chain settles at about
## STRIDE_SLOPE x the stroke cap + STRIDE_BASE (m/s). stroke_cap() inverts that.
const STRIDE_SLOPE := 1.5
const STRIDE_BASE := 0.5

static var _shared: RaceSettings


## The copy the panel edits and the match reads.
static func shared() -> RaceSettings:
	if _shared == null:
		_shared = RaceSettings.new()
	return _shared


# --- Match card ---------------------------------------------------------------------------------------------

@export_group("Match")
## Laps in a race (the card's Laps).
@export_range(1, 20, 1, "or_greater") var laps := 3
## Racers, humans and bots together (the card's Field; bots fill the empty seats). D2: 8.
@export_range(2, 16, 1, "or_greater") var field_size := 8
## The bot tier (the card's Bots).
@export var bot_difficulty: Bots = Bots.NORMAL
## The track (the card's Track): one of TRACKS.
@export var track := "Canyon Reef Circuit"
## Slipstream on or off (the card's toggle).
@export var slipstream := true
## Each class's mobility skill on or off (the card's toggle; D5).
@export var skills := true
## Racers push each other with weight (D4); off: they pass through each other.
@export var bumps := true
## Seconds of the 3-2-1-GO countdown.
@export_range(0.0, 20.0, 0.5, "or_greater") var countdown := 3.0
## Seconds the others get to finish once the first human has (D8); 0 ends the race at once.
@export_range(0.0, 300.0, 1.0, "or_greater") var finish_clock := 30.0
## How long (s) contact stays off after a rescue or at the start of the race.
@export_range(0.0, 10.0, 0.1, "or_greater") var ghost_time := 1.5

# --- The shared speed (section 3) ----------------------------------------------------------------------------

@export_group("Shared speed")
## Every racer's steady speed on a perfect stride chain (m/s): the same for all of them. Applied as a top_speed
## modifier (stroke_cap() over the fish's own stroke_max_speed). Phase 0: 20 m/s gives a lap of about 40-45 s on 720 m.
@export_range(4.0, 80.0, 0.5, "or_greater") var race_top_speed := 20.0
## Every racer's acceleration, a factor on the Nature preset's (the "accel" modifier).
@export_range(0.1, 4.0, 0.05, "or_greater") var race_accel := 1.0
## Every racer's stride push, a factor on the Nature preset's (the "stride" modifier).
@export_range(0.1, 4.0, 0.05, "or_greater") var race_stride_gain := 1.0
## The start surge (D6): extra speed (m/s) for a stride timed on GO; 0 turns it off.
@export_range(0.0, 20.0, 0.25, "or_greater") var start_surge := 3.0
## How close to GO (s) the stride has to start for the surge.
@export_range(0.0, 1.0, 0.01, "or_greater") var start_window := 0.25

# --- Size cap (D3) ---------------------------------------------------------------------------------------------

@export_group("Size")
## The longest body allowed (m): a bigger model is scaled down to it, hitbox too. About 2x a Skirmisher (1.2 m).
## 0 turns the cap off (true scale).
@export_range(0.0, 60.0, 0.1, "or_greater") var race_size_cap := 2.4
## Bump weight of every racer, a factor on RaceHandling's `weight` (the weight is kept at true size, not the cap's).
@export_range(0.0, 5.0, 0.05, "or_greater") var bump_strength := 1.0

# --- Streams and slipstream (section 8) ----------------------------------------------------------------------

@export_group("Currents")
## A bubble stream's push on a racer at its core (m/s^2), times the racer's stream_grip.
@export_range(0.0, 100.0, 0.5, "or_greater") var stream_push := 14.0
## The most speed (m/s over the racer's own) a stream may add.
@export_range(0.0, 60.0, 0.5, "or_greater") var stream_max_gain := 8.0
## Slipstream: extra top speed (m/s) a racer gets after sitting in a wake, times its slip_gain.
@export_range(0.0, 30.0, 0.25, "or_greater") var slip_gain := 3.0
## Seconds in a wake before it counts.
@export_range(0.0, 5.0, 0.05, "or_greater") var slip_delay := 0.5
## The wake cone's length in body lengths, and its half angle (degrees).
@export_range(0.5, 40.0, 0.5, "or_greater") var slip_length := 8.0
@export_range(2.0, 60.0, 1.0) var slip_angle := 14.0
## Seconds the gain fades after leaving the wake.
@export_range(0.0, 10.0, 0.1, "or_greater") var slip_fade := 1.0

# --- Keeping racers on the track (section 6, 7) ----------------------------------------------------------------

@export_group("Rescue")
## Seconds outside the channel before a rescue (race_oob_time).
@export_range(0.0, 30.0, 0.5, "or_greater") var race_oob_time := 3.0
## Seconds facing against the track before the WRONG WAY banner.
@export_range(0.0, 10.0, 0.1, "or_greater") var wrong_way_banner := 1.5
## Seconds against the track before a rescue (race_wrong_way_time).
@export_range(0.0, 60.0, 0.5, "or_greater") var race_wrong_way_time := 6.0
## Seconds nearly still before a rescue.
@export_range(0.0, 30.0, 0.5, "or_greater") var stuck_time := 4.0
## Speed (m/s) under which a racer counts as still.
@export_range(0.0, 10.0, 0.1, "or_greater") var stuck_speed := 1.0
## The rescue button's cooldown (s).
@export_range(0.0, 60.0, 0.5, "or_greater") var rescue_cooldown := 8.0
## Seconds the fade out and the fade in each take.
@export_range(0.0, 3.0, 0.05, "or_greater") var rescue_fade := 0.4
## The soft ceiling: height (m) above the channel's rim where a downward current starts, and its push (m/s^2) per
## metre over it.
@export_range(0.0, 100.0, 1.0, "or_greater") var ceiling_margin := 6.0
@export_range(0.0, 20.0, 0.1, "or_greater") var ceiling_push := 2.0

# --- Skills (D5) -----------------------------------------------------------------------------------------------

@export_group("Skills")
## A factor on every mobility skill's own cooldown while racing.
@export_range(0.1, 10.0, 0.1, "or_greater") var skill_cooldown_scale := 1.5

# --- Bots (section 9) ------------------------------------------------------------------------------------------

@export_group("Camera")
## Extra chase distance (m) per body length over a Skirmisher's (a 2.4 m racer is 2x).
@export_range(0.0, 20.0, 0.1, "or_greater") var cam_size_back := 2.0
## Extra chase height (m) per body length over a Skirmisher's.
@export_range(0.0, 10.0, 0.1, "or_greater") var cam_size_up := 0.6
## Extra chase distance (m) per m/s of speed (the view opens up as you go fast).
@export_range(0.0, 1.0, 0.01, "or_greater") var cam_speed_back := 0.08
## Extra distance (m) of the wide view on the grid, easing out 1.5 s after GO.
@export_range(0.0, 60.0, 0.5, "or_greater") var cam_grid_back := 8.0
## Extra height (m) of the wide view on the grid.
@export_range(0.0, 30.0, 0.5, "or_greater") var cam_grid_up := 3.0

@export_group("Bots")
## The rubber band: how much (0..1) a bot behind the leader gains / a bot far ahead loses (a factor on speed). EASY
## uses rubber_easy, NORMAL rubber_normal, HARD rubber_hard.
@export_range(0.0, 0.5, 0.005, "or_greater") var rubber_easy := 0.06
@export_range(0.0, 0.5, 0.005, "or_greater") var rubber_normal := 0.03
@export_range(0.0, 0.5, 0.005, "or_greater") var rubber_hard := 0.0
## The gap (m) behind the leader where the rubber band is at full strength.
@export_range(1.0, 500.0, 1.0, "or_greater") var rubber_gap := 60.0
## How far ahead (s of travel) bots aim on the racing line, and the least (m).
@export_range(0.1, 5.0, 0.05, "or_greater") var bot_lookahead := 0.8
@export_range(1.0, 100.0, 0.5, "or_greater") var bot_lookahead_min := 8.0
## Steering noise (degrees) at EASY, NORMAL, HARD.
@export_range(0.0, 45.0, 0.5, "or_greater") var bot_noise_easy := 7.0
@export_range(0.0, 45.0, 0.5, "or_greater") var bot_noise_normal := 3.5
@export_range(0.0, 45.0, 0.5, "or_greater") var bot_noise_hard := 1.0


# --- Derived values ----------------------------------------------------------------------------------------------

## The stroke cap (m/s) that makes a perfect stride chain settle at `race_top_speed` (Phase 0's measured relation).
func stroke_cap() -> float:
	return maxf((race_top_speed - STRIDE_BASE) / STRIDE_SLOPE, 1.0)


## The shared FishModifiers set every racer gets (push under RaceMatch.MODS_SHARED): same top speed, accel and stride
## push for everyone. `stroke_max_speed` is the fish's own (FishController.stroke_max_speed).
func shared_modifiers(stroke_max_speed: float) -> Dictionary:
	return {"top_speed": stroke_cap() / maxf(stroke_max_speed, 0.1), "accel": race_accel, "stride": race_stride_gain}


## The rubber band for the current bot tier (0 = none).
func rubber_for(tier: Bots = bot_difficulty) -> float:
	return [rubber_easy, rubber_normal, rubber_hard][tier]


## Steering noise (degrees) for the current bot tier.
func noise_for(tier: Bots = bot_difficulty) -> float:
	return [bot_noise_easy, bot_noise_normal, bot_noise_hard][tier]
