class_name MarcoPoloSettings
extends Resource
## Marco Polo's own tuning (planning_marco_polo.md): the match and its rounds,
## the hiders' noise and how the seeker sees it (exposure and its layers), the
## sonar, each role's swimming, scoring and the sight cone, the Fake Fish,
## portholes and the bots. Shown in the tuning panel's MARCO POLO section and
## saved with presets ([marco_polo]). One shared copy (shared()) is what the
## panel edits and what MarcoPoloMatch and its helpers read, live.
##
## As with NatureSettings, ranges are wide: 0 switches a feature off and the
## top end is several times the sensible value. Sliders marked or_greater take
## bigger values typed into a preset too.

## What a catch does (plan §1a).
enum Variant {
	## Last Fish Swimming: a caught hider is eliminated and spectates.
	ELIMINATION,
	## Join the Seekers: a caught hider becomes a seeker.
	CONVERSION,
}

## Exposure's layers, from the inside out (plan §3).
enum Layer { NONE, SKELETON, CARDIO, MUSCLE, SKIN, AURA }
## Which rounds come first: the people seeking, or a bot (the people hiding).
enum StartAs { SEEKER, HIDER }

## The variants' names on the match card.
const VARIANT_NAMES := ["Last Fish Swimming", "Join the Seekers"]
## The Start as picker's names on the match card.
const START_AS_NAMES := ["Seeker", "Hider"]
## The arenas the match card offers (main.gd's ENVIRONMENTS names).
const ARENAS := ["Sunken Temple", "Aquarium"]
## The plain Ocean (no walls or portholes, a radius push like Hunt): only for
## test probes; anywhere else it falls back to the first of ARENAS.
const TEST_ARENA := "Ocean"
## The layers' names, for the HUD and the console.
const LAYER_NAMES := ["none", "skeleton", "cardiovascular", "muscular", "skin", "aura"]

static var _shared: MarcoPoloSettings


## The copy the panel edits and Marco Polo reads.
static func shared() -> MarcoPoloSettings:
	if _shared == null:
		_shared = MarcoPoloSettings.new()
	return _shared


@export_group("Match")
## What a catch does: Last Fish Swimming (eliminated, then spectate) or Join
## the Seekers (the caught hider becomes a seeker). Picked on the match card.
@export var variant := Variant.ELIMINATION
## The arena: Sunken Temple or Aquarium. Picked on the match card. (Test
## probes can also play in the plain Ocean, TEST_ARENA.)
@export_enum("Sunken Temple", "Aquarium") var arena := "Sunken Temple"
## Rounds in a match (0: one per human, so every person is seeker once).
@export_range(0, 20, 1, "or_greater") var rounds := 0
## How long the seeker counts (s) while the hiders scatter, held with the view blacked out.
@export_range(0.0, 60.0, 0.5, "or_greater") var hide_time := 10.0
## The round clock (s): the round ends when it runs out, or when every hider's caught.
@export_range(10.0, 900.0, 5.0, "or_greater") var round_time := 180.0
## How long the round's card shows (s) before the next seeker's round.
@export_range(0.0, 30.0, 0.5, "or_greater") var round_over_time := 6.0
## How long the final results show (s) before a new match starts.
@export_range(0.0, 120.0, 1.0, "or_greater") var match_over_time := 20.0
## Seekers at the start of a round.
@export_range(1, 4, 1) var seekers := 1
## Bots fill the match up to this many fish, so one person can play.
@export_range(2, 12, 1, "or_greater") var min_players := 4
## Rounds a bot seeks (the people hiding), on top of one seeker round per
## person (rounds 0), so playing alone you get to hide too. 0: people only.
@export_range(0, 12, 1, "or_greater") var bot_seeker_rounds := 1
## Whether the people's seeker rounds come first (Seeker) or the bots'
## (Hider). Picked on the match card.
@export var start_as := StartAs.SEEKER
## Join the Seekers: a converted hider is held this long (s) while their view
## switches to the scope, so no instant tag of a hider beside them.
@export_range(0.0, 10.0, 0.1, "or_greater") var convert_hold := 1.5
## Last Fish Swimming: an eliminated fish floats up belly-up and fades this long (s).
@export_range(0.0, 10.0, 0.1, "or_greater") var eliminated_float := 2.0
## How fast (m/s) it floats up.
@export_range(0.0, 20.0, 0.1, "or_greater") var eliminated_float_speed := 2.5
## A spectator's view moves on this long (s) after the hider they watch is out.
@export_range(0.0, 10.0, 0.1, "or_greater") var spectate_switch_delay := 1.2
## Holding the camera button (Y) this long (s) opens the watch wheel (a slice
## per fish: the left stick picks, letting go watches them); a shorter tap
## swaps a hider between their own follow cam and watching someone (parked).
@export_range(0.1, 2.0, 0.05) var watch_hold_time := 0.3
## Fish drive on the surfaces they touch (floor, walls, ceiling) the way the
## other modes' fish do (FishController.rl_surface_mechanics). Off: every fish,
## bots too, swims everywhere and never sticks to a surface.
@export var stick_to_surfaces := false
## The Ocean's arena radius (m), round its spawn, pushed back in past it like Hunt.
@export_range(20.0, 500.0, 5.0, "or_greater") var ocean_radius := 90.0
## A hit-stop on a tag (s): everyone holds still a beat.
@export_range(0.0, 2.0, 0.01, "or_greater") var tag_hold := 0.25
## Fish bump into each other (fish-to-fish collision) during the match.
@export var fish_collide := true
## A bump between hiders this fast (m/s closing speed) or faster makes noise.
@export_range(0.0, 30.0, 0.1, "or_greater") var bump_speed := 1.5
## The same two fish bump at most once per this long (s).
@export_range(0.0, 5.0, 0.05, "or_greater") var bump_cooldown := 0.5

@export_group("Noise")
## Swimming slower than this (m/s, horizontal and upward) makes no steady noise.
@export_range(0.0, 40.0, 0.1, "or_greater") var quiet_speed := 4.0
## Steady noise peaks (1) at this speed (m/s).
@export_range(0.1, 80.0, 0.1, "or_greater") var loud_speed := 20.0
## Steady noise at loud_speed: noise holds at this while cruising that fast.
@export_range(0.0, 1.0, 0.01) var steady_noise := 0.7
## How fast noise dies away (per second).
@export_range(0.0, 5.0, 0.01, "or_greater") var noise_decay := 0.35
## A flip's burst.
@export_range(0.0, 1.0, 0.01) var flip_noise := 0.9
## A jump's burst, and a double jump's.
@export_range(0.0, 1.0, 0.01) var jump_noise := 0.5
@export_range(0.0, 1.0, 0.01) var double_jump_noise := 0.7
## A stride's burst at its worst timing: stride_noise x (1 - timing) ^ stride_timing_curve,
## so a perfect stride is nearly silent and a mistimed one is loud.
@export_range(0.0, 1.0, 0.01) var stride_noise := 0.55
@export_range(0.1, 5.0, 0.05, "or_greater") var stride_timing_curve := 1.5
## A missed beat's burst.
@export_range(0.0, 1.0, 0.01) var missed_beat_noise := 0.5
## A bump into another fish, or a knock on scenery or a porthole's rim.
@export_range(0.0, 1.0, 0.01) var bump_noise := 0.7
## Inside a bubble curtain a hider's noise is scaled by this.
@export_range(0.0, 1.0, 0.01) var bubble_mask := 0.4
## A burst this loud or louder pings the seeker's sonar.
@export_range(0.0, 1.0, 0.01) var blip_threshold := 0.2
## Steady noise over blip_threshold pings this often (s).
@export_range(0.05, 10.0, 0.05, "or_greater") var steady_ping_interval := 1.0
## Strides this well timed or better are silent (no stride sound for the seeker; 1: off).
@export_range(0.0, 1.0, 0.01) var silent_good_strides := 1.0

@export_group("Exposure")
## Slower than this (m/s, horizontal) a hider is invisible: exposure 0 ("stationary = invisible").
@export_range(0.0, 10.0, 0.05, "or_greater") var still_speed := 0.6
## Exposure rises at once and falls this fast (per second), so the layers peel away.
@export_range(0.01, 5.0, 0.01, "or_greater") var exposure_fade := 0.1
## Exposure's distance falloff: 1 within near_sight (m), 0.5 at half_sight, 0 at the murk's sight distance.
@export_range(0.0, 100.0, 0.5, "or_greater") var near_sight := 8.0
@export_range(0.0, 200.0, 0.5, "or_greater") var half_sight := 25.0
## The aura falls off no lower than this with distance.
@export_range(0.0, 1.0, 0.01) var aura_min_falloff := 0.5
## "Marco!": every live hider's exposure bumps up to at least this.
@export_range(0.0, 1.0, 0.01) var polo_exposure := 0.3
## Exposure is noise passed through this power (1: as is; under 1 shows more).
@export_range(0.1, 5.0, 0.05, "or_greater") var exposure_curve := 1.0

@export_group("Layers")
## Where each layer starts (exposure 0..1): skeleton, cardiovascular, muscular, skin, aura.
@export_range(0.0, 1.0, 0.01) var layer_skeleton := 0.08
@export_range(0.0, 1.0, 0.01) var layer_cardio := 0.25
@export_range(0.0, 1.0, 0.01) var layer_muscle := 0.45
@export_range(0.0, 1.0, 0.01) var layer_skin := 0.65
@export_range(0.0, 1.0, 0.01) var layer_aura := 0.85
## The seeker hears a faint heartbeat (mp/heartbeat) from a hider showing at
## the cardiovascular layer, once per this many seconds. 0: no heartbeat.
@export_range(0.0, 5.0, 0.05, "or_greater") var heartbeat_interval := 0.9

@export_group("Sonar")
## A blip fades over this long (s).
@export_range(0.1, 30.0, 0.1, "or_greater") var blip_life := 3.0
## A blip lands within blip_fuzz x distance of the real spot.
@export_range(0.0, 1.0, 0.01, "or_greater") var blip_fuzz := 0.15
## A "Polo!" answer's blur, times blip_fuzz.
@export_range(1.0, 10.0, 0.1, "or_greater") var polo_fuzz := 2.5
## "Marco!"'s cooldown (s).
@export_range(0.0, 120.0, 0.5, "or_greater") var marco_cooldown := 20.0
## After a "Marco!" the hiders see a ring round the seeker this long (s).
@export_range(0.0, 10.0, 0.1, "or_greater") var marco_reveal_time := 2.0
## Pings kept per seeker (the newest).
@export_range(4, 256, 1, "or_greater") var max_pings := 48

@export_group("Marco! scan")
## How long the "Marco!" pulse takes to spread from the seeker to the arena's far corner (s).
@export_range(0.2, 10.0, 0.1, "or_greater") var marco_scan_time := 2.0
## The brightness of the pulse shell.
@export_range(0.0, 4.0, 0.05, "or_greater") var scan_glow := 1.0
## Once the pulse reaches a fish, how long its movement keeps being recorded
## (s): a longer window, longer streaks.
@export_range(0.05, 6.0, 0.05, "or_greater") var ghost_window := 1.5
## A fish slower than this leaves no ghost (m/s).
@export_range(0.0, 5.0, 0.05, "or_greater") var ghost_min_speed := 0.25
## Glow added per metre a fish moves through a spot.
@export_range(0.0, 50.0, 0.1, "or_greater") var ghost_intensity_scale := 2.5
## The glow that counts as full brightness (and gets the longest fade).
@export_range(0.05, 20.0, 0.05, "or_greater") var ghost_full := 1.5
## How long the faintest ghost spot takes to fade (s).
@export_range(0.0, 20.0, 0.1, "or_greater") var ghost_fade_min := 3.0
## How long the brightest ghost spot takes to fade (s).
@export_range(0.0, 30.0, 0.1, "or_greater") var ghost_fade_max := 8.0
## A ghost "pixel"'s size (m).
@export_range(0.03, 1.0, 0.01, "or_greater") var ghost_cell := 0.15
## How much of a ghost shows through walls (0 none, 1 all).
@export_range(0.0, 1.0, 0.05, "or_greater") var ghost_through_walls := 0.6
## The cap on live ghost spots.
@export_range(100, 100000, 100, "or_greater") var ghost_max_cells := 16000
## How strong the faint body echo is that a hider leaves where the pulse front
## reaches it, moving or not (0 off: only movement leaves ghosts, as before).
@export_range(0.0, 2.0, 0.01, "or_greater") var ghost_still_echo := 0.3
## The streaks' own colour (not the pulse's mint): the old end of a streak.
@export var ghost_color := Color(0.35, 0.62, 1.0)
## The head of a streak, its newest end (white-hot).
@export var ghost_head_color := Color(0.9, 0.97, 1.0)
## How long a streak's newest cells keep the head colour (s).
@export_range(0.05, 5.0, 0.05, "or_greater") var ghost_head_time := 0.6
## Brightness of the streaks (1 is the base glow).
@export_range(0.0, 10.0, 0.05, "or_greater") var ghost_glow := 0.8
## A streak point's size against the cell (1 is the cell).
@export_range(0.2, 8.0, 0.05, "or_greater") var ghost_point_scale := 1.5
## Streaks stay hidden this long after the pulse front reaches a fish (s), so the
## pulse doesn't drown them.
@export_range(0.0, 3.0, 0.05, "or_greater") var ghost_show_delay := 0.3
## The wake: a thin ring is shed every this many metres along a hider's path (m);
## it widens at ghost_ripple_speed (m/s) from ghost_ripple_start (m radius) and fades
## over ghost_ripple_life (s). Rings shed along a path pile up into a V-shaped wake and
## cross each other. 0 glow turns them off.
@export_range(0.05, 5.0, 0.05, "or_greater") var ghost_ripple_gap := 0.5
@export_range(0.2, 15.0, 0.1, "or_greater") var ghost_ripple_life := 4.5
@export_range(0.0, 20.0, 0.1, "or_greater") var ghost_ripple_speed := 0.6
@export_range(0.0, 3.0, 0.05, "or_greater") var ghost_ripple_start := 0.25
@export_range(0.0, 10.0, 0.05, "or_greater") var ghost_ripple_glow := 1.5
@export_range(0.01, 0.5, 0.01) var ghost_ripple_width := 0.09
@export_range(10, 20000, 10, "or_greater") var ghost_ripple_max := 3000
## Each streak's head drops a blip on the seeker's scope for this long (s).
@export_range(0.0, 20.0, 0.1, "or_greater") var ghost_scope_blip := 3.0
## The blips' strength (0 none).
@export_range(0.0, 2.0, 0.05, "or_greater") var ghost_scope_strength := 1.0

@export_group("Titan view")
## A whale seeker's own view gets thicker murk (whale_murk times the arena's fog
## density); it eases in and out over this long (s).
@export_range(0.0, 5.0, 0.05, "or_greater") var titan_view_fade := 0.6
## Its fog colour is pulled toward this, by titan_view_color_mix (0: the arena's own).
@export var titan_view_color := Color(0.02, 0.07, 0.08)
@export_range(0.0, 1.0, 0.01) var titan_view_color_mix := 0.0
## whale_blur's depth-of-field starts at this share of the whale's sight range (the
## far blur's distance) and its transition is this share of it.
@export_range(0.0, 2.0, 0.01, "or_greater") var titan_view_blur_start := 0.5
@export_range(0.05, 4.0, 0.05, "or_greater") var titan_view_blur_span := 1.0
## The whale pick card: how fast the model turns (deg/s), and its size on screen
## (share of the screen's height).
@export_range(0.0, 360.0, 1.0, "or_greater") var pick_card_spin := 28.0
@export_range(0.2, 1.0, 0.01) var pick_card_height := 0.62
## The beat pip on a whale's HUD fills toward the next auto "Marco!"; this is how
## long (s) it flashes when the call goes out.
@export_range(0.0, 2.0, 0.05, "or_greater") var beat_pip_flash := 0.35
## The water a whale's tail pushes (power stroke): the vortex ring, silt, floor
## cloud, roof boil and bubbles. Off, or capped at this many live effects at once.
@export var wake_fx := true
@export_range(1, 200, 1, "or_greater") var wake_fx_max := 24
## The ring: how long it lives (s), how far it drifts back (m) and its size against the whale's width.
@export_range(0.2, 10.0, 0.1, "or_greater") var wake_ring_life := 1.8
@export_range(0.0, 20.0, 0.1, "or_greater") var wake_ring_drift := 2.5
@export_range(0.1, 4.0, 0.05, "or_greater") var wake_ring_size := 0.7
## The silt puffs: particles per stroke, how long they hang (s).
@export_range(0, 200, 1, "or_greater") var wake_silt_amount := 36
@export_range(0.2, 10.0, 0.1, "or_greater") var wake_silt_life := 2.4
## How far from the flukes the floor kicks up silt and the roof boils (m).
@export_range(0.0, 40.0, 0.5, "or_greater") var wake_floor_reach := 9.0
@export_range(0.0, 40.0, 0.5, "or_greater") var wake_roof_reach := 9.0
## Strokes at or over this strength blow bubbles from the fluke tips.
@export_range(0.0, 1.0, 0.01) var wake_bubble_strength := 0.75
## The vortex ring swirl sound plays when the listener is this near (m).
@export_range(0.0, 100.0, 0.5, "or_greater") var wake_swirl_reach := 14.0

@export_group("Whale")
## The seeker is an adult whale (a Titan, planning_marco_whales.md): on = the
## seeker's fish becomes the Titans class for its round, off = it stays the
## player's own fish with the Seeker values below.
@export var whale_seeker := true
## The whale's body length (m): its hitbox and model are scaled to it. 0 takes
## the class's own size (FishCharacter TITAN, five times the longest hider).
@export_range(0.0, 60.0, 0.1, "or_greater") var whale_length := 0.0
## A further multiplier on the whale's collision box alone, so its tag reach
## (any contact tags) grows or shrinks without the model.
@export_range(0.1, 3.0, 0.05, "or_greater") var whale_hitbox_scale := 1.0
## The whale's speed against a hider's: cruising speed, and the cap on speed.
@export_range(0.1, 5.0, 0.05, "or_greater") var whale_speed_scale := 1.3
## The whale's boost push and its top boost speed, against a fish's.
@export_range(0.1, 5.0, 0.05, "or_greater") var whale_boost_scale := 1.3
## Slower yaw and pitch (under 1): the trade for size and speed, so hiders can
## juke a whale that has committed.
@export_range(0.05, 3.0, 0.05, "or_greater") var whale_turn_scale := 0.55
## Thrust and brake against a fish's (under 1: heavy to get going, and with it
## less water drag, so hard to stop).
@export_range(0.05, 3.0, 0.05, "or_greater") var whale_accel_scale := 0.7
## Which part of the whale tags: the whole body (any contact, as a fish's bow) or
## only the mouth (the front third of its body: "eat").
@export_enum("Body", "Mouth") var whale_tag_zone := 0
## Each fluke down-stroke pushes hiders within whale_wake_radius (m) away along
## the stroke, up to this speed (m/s) at the whale's side, and less further out.
@export_range(0.0, 40.0, 0.1, "or_greater") var whale_wake_push := 4.0
@export_range(0.0, 100.0, 0.5, "or_greater") var whale_wake_radius := 18.0
## A tail stroke's gap (s) while the whale has no animation signal yet (a stand-in
## for FishModel.power_stroke), and the strokes' strength scale.
@export_range(0.1, 10.0, 0.1, "or_greater") var whale_stroke_gap := 1.0
## How much of the whale's size the follow camera keeps its distance for (1: it
## sits back in proportion, 0: as for a fish).
@export_range(0.0, 1.5, 0.05) var whale_cam_follow := 1.0
## The whale's eyesight (applies to bots and people alike): the murk in its view
## is this many times as thick, which divides the arena's sight range (the
## sight cone's reach and every number below). 1: no extra murk (the default;
## the whale was too hard to see with).
@export_range(1.0, 20.0, 0.05, "or_greater") var whale_murk := 1.0
## Full exposure (near) and half exposure (half) fall at these shares of the
## whale's own sight range (the arena's divided by whale_murk).
@export_range(0.0, 1.0, 0.01) var whale_near_share := 0.22
@export_range(0.0, 1.0, 0.01) var whale_half_share := 0.65
## Past near sight, layers below this one don't show at all (Layer: 0 none,
## 1 skeleton, 2 cardiovascular ...): so a faint skeleton is only seen up close.
@export_range(0, 5, 1) var whale_layer_floor := 2
## "Marco!" bumps every hider's exposure in the whale's view up to this, times
## its eyesight falloff (so only the near ones show).
@export_range(0.0, 1.0, 0.01) var whale_polo_exposure := 0.35
## The whale's sight cone's full angle (degrees).
@export_range(10.0, 180.0, 1.0) var whale_cone_angle := 70.0
## Extras on the whale's view (0: off): depth-of-field blur and grey-out (read by the Titan view).
@export_range(0.0, 1.0, 0.01) var whale_blur := 0.0
@export_range(0.0, 1.0, 0.01) var whale_desaturate := 0.0
## The whale calls "Marco!" by itself, this often (s) from the moment the round
## goes live. Off: the seeker calls it with its button (with marco_cooldown).
@export var marco_auto := true
@export_range(0.2, 60.0, 0.1, "or_greater") var marco_auto_interval := 3.0
## Each call comes up to this much of the interval early or late (0: a steady beat).
@export_range(0.0, 1.0, 0.01) var marco_auto_jitter := 0.0
## A warning (s) before each call, such as bubbles from the blowhole (0: none).
@export_range(0.0, 3.0, 0.05, "or_greater") var marco_tell_time := 0.0
## A caught hider growing into a Titan (convert variant): the grow tween's length (s). 0 is instant.
@export_range(0.0, 5.0, 0.05, "or_greater") var whale_grow_time := 0.6
## Join the Seekers: a caught hider waits this long (s) before it grows into a
## whale, and picks its whale during it (a person's pick card shows).
@export_range(0.0, 30.0, 0.5, "or_greater") var whale_join_hold := 5.0
## Bots and the pick card's default: the species a whale starts as is chosen at
## random for bots; people's last pick is remembered (this holds it: -1 none).
@export_range(-1, 4, 1) var whale_last_pick := -1
@export_range(0, 9, 1) var whale_last_skin := 0

@export_group("Seeker")
## The seeker's bow wave is this many times as big: their reach.
@export_range(0.5, 6.0, 0.05, "or_greater") var seeker_bow_scale := 2.0
## The seeker's buoyancy (m/s² up; 0 neutral).
@export_range(-5.0, 5.0, 0.05) var seeker_buoyancy := 0.0
## The seeker has boost (hiders never do).
@export var seeker_boost := true
## The seeker's swimming speed against a hider's (FishController.speed_scale).
@export_range(0.1, 3.0, 0.05, "or_greater") var seeker_speed_scale := 1.0

@export_group("Hider")
## Hiders sink a little (m/s² up; negative sinks), so staying high costs strides.
@export_range(-5.0, 0.0, 0.05) var hider_buoyancy := -0.8
## Hiders' sounds in a seeker's view play at this volume (1: as is).
@export_range(0.0, 1.0, 0.01) var hider_sfx_in_seeker_view := 1.0
## A seen hider at muscular or above this close (m) who isn't tagged is a close call.
@export_range(0.0, 30.0, 0.5, "or_greater") var close_call_range := 5.0

@export_group("Self view")
## A hider sees their own fish as the seekers see it (the layers, at the most
## any seeker sees), so they know how hidden they are. Off: their real fish.
@export var self_view := true
## Once they're less than fully visible, a dashed outline keeps them in their
## own sight, like a sketch about to be drawn: its opacity (0: none).
@export_range(0.0, 1.0, 0.01) var self_outline := 0.85
## The outline's dashes per metre, and how fast they march along (per second).
@export_range(1.0, 60.0, 0.5, "or_greater") var self_outline_dashes := 12.0
@export_range(0.0, 10.0, 0.05, "or_greater") var self_outline_march := 0.6
## How much of the body's edge the outline covers (0..1 of the rim).
@export_range(0.02, 1.0, 0.01) var self_outline_width := 0.28

@export_group("Scoring")
## A hider's points per second in a seeker's line of sight, by the layer that
## seeker sees: none (invisible, in plain view), skeleton, cardiovascular,
## muscular, skin, aura.
@export_range(0.0, 50.0, 0.1, "or_greater") var seen_points_none := 1.0
@export_range(0.0, 50.0, 0.1, "or_greater") var seen_points_skeleton := 2.0
@export_range(0.0, 50.0, 0.1, "or_greater") var seen_points_cardio := 3.0
@export_range(0.0, 50.0, 0.1, "or_greater") var seen_points_muscle := 4.0
@export_range(0.0, 50.0, 0.1, "or_greater") var seen_points_skin := 5.0
@export_range(0.0, 50.0, 0.1, "or_greater") var seen_points_aura := 5.0
## The sight cone's full angle (degrees), round the seeker camera's forward.
@export_range(10.0, 180.0, 1.0) var los_cone_angle := 70.0
## A separate vertical angle (degrees; 0: the same as los_cone_angle).
@export_range(0.0, 180.0, 1.0) var los_cone_vertical := 0.0
## The cone's length (m; 0: the arena's murk sight distance).
@export_range(0.0, 300.0, 1.0, "or_greater") var los_range := 0.0
## The murk's sight distance where the arena gives none (the Ocean), m.
@export_range(5.0, 300.0, 1.0, "or_greater") var default_sight_range := 45.0
## The rate tapers toward the cone's edge and far end (dead centre close up pays the most).
@export var los_falloff := false
## A hider still in at the round's end gets this.
@export_range(0.0, 200.0, 1.0, "or_greater") var survive_bonus := 15.0
## Join the Seekers: the last hider standing, if they survive the clock, gets survive_bonus times this.
@export_range(0.0, 10.0, 0.1, "or_greater") var last_fish_scale := 2.0
## A seeker's points per tag.
@export_range(0.0, 200.0, 1.0, "or_greater") var tag_points := 20.0
## The starting seeker's bonus for catching everyone before the clock: up to
## this, times the share of the round left.
@export_range(0.0, 200.0, 1.0, "or_greater") var clear_bonus_max := 30.0
## DEBUG (gives everything away): draws the sight cone, each hider's sight ray
## (green counts, red blocked, grey outside) and "+n/s" over scoring hiders.
@export var debug_show_los_cone := false

@export_group("Fake Fish")
## Fake Fish each hider can throw per round.
@export_range(0, 5, 1, "or_greater") var fake_charges := 1
## How fast it swims off (m/s throttle target).
@export_range(0.0, 40.0, 0.5, "or_greater") var fake_speed := 14.0
## How long it lasts (s) before it bursts into bubbles.
@export_range(0.5, 30.0, 0.5, "or_greater") var fake_life := 6.0
## "FOOLED!": tagging one holds the seeker this long (s).
@export_range(0.0, 5.0, 0.05, "or_greater") var fooled_hold := 0.5

@export_group("Portholes")
## A porthole's opening is the hider's hitbox half width times this.
@export_range(0.5, 4.0, 0.05, "or_greater") var porthole_radius_scale := 1.25
## Entry: nose first within this angle (degrees) of the porthole's axis...
@export_range(1.0, 90.0, 1.0) var porthole_entry_angle := 20.0
## ...and slower than this (m/s), and not mid-flip.
@export_range(0.1, 30.0, 0.1, "or_greater") var porthole_entry_speed := 4.0
## Inside, the fish turns round to face out over this long (s).
@export_range(0.0, 3.0, 0.05, "or_greater") var porthole_turn_time := 0.4
## Jump shoots it out along the axis at this speed (m/s), with this loud a burst.
@export_range(0.0, 40.0, 0.5, "or_greater") var porthole_exit_speed := 10.0
@export_range(0.0, 1.0, 0.01) var porthole_exit_noise := 0.6
## Jump slips a live hider into a free porthole whose mouth is within
## porthole_jump_range, from any angle or speed (a quiet jump: no noise). Off:
## only swimming in nose first by the entry rules above, knocking off the rim otherwise.
@export var porthole_jump_entry := true
## How close (m, from the fish to the mouth, in front of the wall) Jump reaches a porthole.
@export_range(0.5, 10.0, 0.1, "or_greater") var porthole_jump_range := 3.0
## Out of Water: the gauge fills over this long (s) inside; full is caught.
@export_range(0.5, 60.0, 0.5, "or_greater") var porthole_time := 8.0
## Outside, it drains at this share of the fill rate.
@export_range(0.0, 5.0, 0.01, "or_greater") var porthole_recovery := 0.333

@export_group("Hideaways")
## Hideaways on (spaces a whale can't reach, set by the arena: planning_marco_whales.md §8).
@export var hideaways_on := true
## How many hiders one hideaway hides at once.
@export_range(1, 12, 1, "or_greater") var hideaway_capacity := 2
## A hider's middle stays this long (s) inside a hideaway's sphere before it's hidden.
@export_range(0.0, 5.0, 0.05, "or_greater") var hideaway_settle := 0.6
## Stale Water: the gauge fills over this long (s) hidden, and drains at hideaway_recovery of that rate outside.
@export_range(0.5, 120.0, 0.5, "or_greater") var hideaway_time := 14.0
@export_range(0.0, 5.0, 0.01, "or_greater") var hideaway_recovery := 0.6
## Flushed out when the gauge is full: the noise burst (0..1), the speed away (m/s) and the wait (s) before it can hide again.
@export_range(0.0, 1.0, 0.01) var hideaway_exit_noise := 0.8
@export_range(0.0, 30.0, 0.1, "or_greater") var hideaway_exit_speed := 5.0
@export_range(0.0, 30.0, 0.1, "or_greater") var hideaway_cooldown := 4.0
## Scales every hideaway sphere's radius from what the arena set.
@export_range(0.2, 4.0, 0.05, "or_greater") var hideaway_radius_scale := 1.0

@export_group("Bots")
## How well bots time their strides (0 always off, 1 always perfect).
@export_range(0.0, 1.0, 0.01) var bot_stride_skill := 0.7
## How boldly hider bots edge into the seeker's view to score (0 never).
@export_range(0.0, 1.0, 0.01) var bot_boldness := 0.4
## A seeker this close (m) and heading its way makes a hider bot stop and settle on the floor.
@export_range(0.0, 60.0, 0.5, "or_greater") var bot_settle_range := 16.0
## A seeker's bow this close (m), nose on, makes a hider bot flip away.
@export_range(0.0, 20.0, 0.1, "or_greater") var bot_flip_range := 4.5
## A seeker this close (m), coming and with the hider in sight, makes a hider bot throw its Fake Fish.
@export_range(0.0, 60.0, 0.5, "or_greater") var bot_throw_range := 14.0
## The chance a hider bot's next spot is a free porthole (plus bot_boldness x 0.3).
@export_range(0.0, 1.0, 0.01) var bot_porthole_chance := 0.35
## The Out of Water gauge at which a hider bot leaves its porthole (scaled
## 0.8-1.2 by boldness; it always goes by 0.92).
@export_range(0.05, 1.0, 0.01) var bot_porthole_leave := 0.7
## How far out on a porthole's axis (m) a hider bot lines up before going in nose first.
@export_range(1.0, 15.0, 0.1, "or_greater") var bot_line_up := 4.5
## The chance per look that a seeker bot notices a hider showing only a faint
## skeleton (below layer_cardio). From cardio up it always notices.
@export_range(0.0, 1.0, 0.01) var bot_notice_chance := 0.25
## How often a seeker bot looks round its view (s).
@export_range(0.02, 1.0, 0.01, "or_greater") var bot_look_every := 0.1
## How long a seeker bot goes with nothing seen or heard before it calls Marco (s).
@export_range(0.0, 60.0, 0.5, "or_greater") var bot_marco_quiet := 7.0
## The chance a seeker bot's next sweep stop is waiting outside a porthole.
@export_range(0.0, 1.0, 0.01) var bot_porthole_wait_chance := 0.2
## How long a seeker bot waits outside a porthole (s).
@export_range(0.0, 30.0, 0.5, "or_greater") var bot_porthole_wait := 4.0
## Blips this close (m) to one another bot seeker is heading for are left to it, so seekers spread out.
@export_range(0.0, 50.0, 0.5, "or_greater") var bot_claim_radius := 10.0
## How long a bot tries to move while nearly still before it picks something else (s).
@export_range(0.2, 10.0, 0.1, "or_greater") var bot_stuck_time := 2.0
## Hider bots against a whale's automatic Marco!: they hold still this long (s)
## before each call (on top of marco_tell_time) and this long after it, while
## the pulse and its streaks are recording, and swim in the time between.
@export_range(0.0, 5.0, 0.05, "or_greater") var bot_freeze_before := 0.8
@export_range(0.0, 5.0, 0.05, "or_greater") var bot_freeze_after := 1.0
## A whale bot follows a streak head ahead along its heading at this speed (m/s) times its age.
@export_range(0.0, 30.0, 0.1, "or_greater") var bot_streak_lead := 4.0
## A whale bot gives up on a streak it has reached for this long (s), and on one older than bot_streak_age.
@export_range(0.0, 20.0, 0.1, "or_greater") var bot_streak_visit := 4.0
@export_range(0.5, 30.0, 0.1, "or_greater") var bot_streak_age := 6.0
## A whale bot boosts toward what it's chasing within this many metres.
@export_range(0.0, 200.0, 0.5, "or_greater") var bot_whale_boost_range := 30.0
## A hider bot picks a hideaway for its spot this often (more against a whale), and leaves it at this much Stale Water.
@export_range(0.0, 1.0, 0.01) var bot_hideaway_chance := 0.3
@export_range(0.1, 1.0, 0.01) var bot_hideaway_leave := 0.85


## The layer seen at `exposure` (Layer: 0 none ... 5 aura).
func layer_for(exposure: float) -> int:
	if exposure >= layer_aura:
		return Layer.AURA
	if exposure >= layer_skin:
		return Layer.SKIN
	if exposure >= layer_muscle:
		return Layer.MUSCLE
	if exposure >= layer_cardio:
		return Layer.CARDIO
	if exposure >= layer_skeleton:
		return Layer.SKELETON
	return Layer.NONE


## Points per second in sight at `layer`.
func seen_points(layer: int) -> float:
	return [seen_points_none, seen_points_skeleton, seen_points_cardio, seen_points_muscle, seen_points_skin,
			seen_points_aura][clampi(layer, 0, 5)]
