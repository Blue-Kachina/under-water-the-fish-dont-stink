class_name WhatStinksSettings
extends Resource
## What Stinks?'s own tuning (what_stinks.md section 10): the match and its
## rounds, the Hunter's form, the schools and the ocean they roam, the scoring
## and the bots. Shown in the tuning panel's WHAT STINKS? section and saved with
## presets ([what_stinks]). One shared copy (shared()) is what the panel edits
## and what WhatStinksMatch and its helpers read, live. The Hunter's size dial
## and its couplings are HunterSize's (the panel's HUNTER SIZE section).
##
## As in the other settings, ranges are wide: 0 switches a feature off and the
## top end is several times the sensible value. Nothing here is tuned yet (the
## numbers are first guesses; play-test before changing them).

## What a bite does and how a round ends (spec section 1).
enum Variant {
	## Clean Sweep: the Hunter wins by eating every prey player; eaten prey spectate.
	SWEEP,
	## Upset Stomach: the Hunter fills a satiation bar on school fish; a prey player it bites is spat out (the Hunter gets queasy), not eaten.
	STOMACH,
}
## Which rounds come first: the people hunting, or a bot (the people are prey).
enum StartAs { HUNTER, PREY }
## How the bite button works: held open and released shut, or one tap (the snap).
enum BiteMode { HOLD, TAP }

## The variants' names on the match card.
const VARIANT_NAMES := ["Clean Sweep", "Upset Stomach"]
const START_AS_NAMES := ["Hunter", "Prey"]
## The sizes the match card offers (HunterSize.size_mult); the panel takes any.
const SIZE_CHOICES := [0.5, 1.0, 2.0, 3.0, 5.0, 10.0]

static var _shared: WhatStinksSettings


static func shared() -> WhatStinksSettings:
	if _shared == null:
		_shared = WhatStinksSettings.new()
	return _shared


@export_group("Match")
## Clean Sweep or Upset Stomach. Picked on the match card.
@export var variant := Variant.SWEEP
## Rounds in a match (0: one per person, plus the bots' rounds below).
@export_range(0, 20, 1, "or_greater") var rounds := 0
## Whose turn comes first: a person's (Hunter) or a bot's (Prey: the people hide first).
@export var start_as := StartAs.HUNTER
## Rounds a bot hunts (after the people's) so a lone person gets to be prey too.
@export_range(0, 10, 1, "or_greater") var bot_hunter_rounds := 1
## Hunters per round (the match never assumes one; more is the few-vs-many variant).
@export_range(1, 8, 1, "or_greater") var hunters_per_round := 1
## Seats filled with bots up to this many fish.
@export_range(2, 32, 1, "or_greater") var min_players := 5
## How long the Hunter is held (s), view blacked out, while the prey scatter and find a school.
@export_range(0.0, 60.0, 0.5, "or_greater") var hide_time := 12.0
## The round clock (s): the prey win when it runs out.
@export_range(10.0, 900.0, 5.0, "or_greater") var round_time := 180.0
## How long the round's card shows (s) before the next round.
@export_range(0.0, 30.0, 0.5, "or_greater") var round_over_time := 7.0
## How long the match's card shows (s) before a new match starts.
@export_range(0.0, 60.0, 0.5, "or_greater") var match_over_time := 12.0

@export_group("Hunter")
## The form the Hunter takes (a HunterForms key; one that is not ready plays as the Drowned Shark). Picked on the match card.
@export_enum("drowned_shark", "humpback", "orca", "beluga", "sperm", "blue", "king_of_herrings", "gulper_mother", "whale_fall", "lamprey_queen", "fallen_angel") var form := "drowned_shark"
## How long after a bite the Hunter is held (s), chewing: no second bite (on top of the form's bite cooldown).
@export_range(0.0, 10.0, 0.1, "or_greater") var chew_delay := 0.0

@export_group("Bite")
## Hold: the button opens the jaws and releasing it shuts them (a quick tap is a snap; holding charges the bite). Tap: today's snap, the chomp lands on the press and the release does nothing.
@export var bite_mode := BiteMode.HOLD
## A tap (released before the jaws are fully open) strikes from at least this open (0: from however far they got, 1: as wide as a snap).
@export_range(0.0, 1.0, 0.05) var tap_open_min := 0.6
## While the jaws are held open the Hunter swims at this share of its speed (an open mouth is drag)...
@export_range(0.0, 3.0, 0.05, "or_greater") var hold_speed_mult := 0.8
## ...turns at this share of its turn rate...
@export_range(0.0, 3.0, 0.05, "or_greater") var hold_turn_mult := 0.7
## ...and the schools' alarm radius is x this (a gaping mouth is a tell).
@export_range(0.0, 5.0, 0.05, "or_greater") var hold_alarm_mult := 1.5
## Each second held adds this to the bite's cooldown (on top of the form's bite_every)...
@export_range(0.0, 10.0, 0.05, "or_greater") var hold_cooldown_per_s := 0.5
## ...up to this total (s).
@export_range(0.0, 60.0, 0.5, "or_greater") var hold_cooldown_max := 6.0
## A fully charged chomp takes x this many fish (1: holding buys no capacity)...
@export_range(0.0, 10.0, 0.05, "or_greater") var hold_capacity_mult := 2.5
## ...and reaches x this far.
@export_range(0.0, 5.0, 0.05, "or_greater") var hold_reach_mult := 1.5
## The bite's frustum is drawn faintly on the HUD while the jaws are held open.
@export var bite_frustum_preview := true
## The pad's rumble when the jaws open...
@export_range(0.0, 3.0, 0.05, "or_greater") var rumble_open := 0.3
## ...while held (rising with the charge)...
@export_range(0.0, 3.0, 0.05, "or_greater") var rumble_hold := 0.25
## ...and when the jaws shut on something.
@export_range(0.0, 3.0, 0.05, "or_greater") var rumble_contact := 0.7
## The Hunter freezes this long (ms) when its jaws land (never the global time scale).
@export_range(0.0, 500.0, 5.0, "or_greater") var hitstop_ms := 80.0
## The blood, bubbles and tooth sparks at a landing x this (0: none; the camera punch and sounds stay).
@export_range(0.0, 5.0, 0.05, "or_greater") var bite_fx_mult := 1.0
## A prey player within this many reaches of an open mouth hears the hold louder and feels a slow heartbeat rumble (0: no warning).
@export_range(0.0, 10.0, 0.1, "or_greater") var prey_warn_range := 1.5
## ...of this strength (x rumble_hold; it quickens with the charge)...
@export_range(0.0, 5.0, 0.05, "or_greater") var prey_warn_rumble := 1.5
## ...and a prey player a bite catches feels it: camera punch, rumble and red flush x this (a boss chomp's, 1).
@export_range(0.0, 5.0, 0.05, "or_greater") var prey_impact := 1.0
## A bite's survivors panic: burst strength x this (1: as a battery).
@export_range(0.0, 10.0, 0.1, "or_greater") var eat_burst_mult := 2.5
## ...and burst this far (x burst_radius).
@export_range(0.0, 10.0, 0.1, "or_greater") var eat_radius_mult := 2.5
## Survivors scatter off along this many headings (the school splits in that many groups).
@export_range(1, 8, 1, "or_greater") var eat_groups := 3
## ...and take this long (s) to reform.
@export_range(0.0, 60.0, 0.5, "or_greater") var reform_time := 7.0
## A bite takes prey players in reach as well as school fish (off: only the school's fish).
@export var bite_takes_players := true

@export_group("Engulf")
## The whales' mouth (two-stage-attack.md 4b): the jaw drops this many degrees (real whales open to about 90; the Bite's fling goes past it)...
@export_range(0.0, 170.0, 1.0, "or_greater") var whale_gape_deg := 80.0
## ...and stretches this many times as long as it opens (1: no stretch; the cartoon gape)...
@export_range(0.25, 4.0, 0.05, "or_greater") var whale_smear := 1.25
## ...and the throat's pleats balloon x this as fish go in (0: they stay flat).
@export_range(0.0, 5.0, 0.05, "or_greater") var engulf_swell := 1.0
## An open mouth holds up to this x the form's capacity of fish (and prey players); when it is full it stays open but takes no more.
@export_range(0.0, 10.0, 0.1, "or_greater") var engulf_max_mult := 2.0
## The mouth takes what swims into a box this x the bite's reach long...
@export_range(0.1, 5.0, 0.05, "or_greater") var engulf_box_len := 1.5
## ...and this x the bite's radius to each side while the jaw is open wide.
@export_range(0.05, 3.0, 0.05, "or_greater") var engulf_box_width := 0.6
## A fish that enters is drawn in to its place in the mouth over this long (s)...
@export_range(0.0, 3.0, 0.05, "or_greater") var engulf_pull_s := 0.35
## ...at most this many fish go in each second...
@export_range(0.5, 200.0, 0.5, "or_greater") var engulf_per_s := 14.0
## ...the pleats squeeze back down over this long (s) after the mouth shuts...
@export_range(0.0, 5.0, 0.05, "or_greater") var engulf_squeeze_s := 0.6
## ...and a fish bumping a full mouth's lips is knocked away at this speed (m/s).
@export_range(0.0, 40.0, 0.5, "or_greater") var engulf_bump := 4.0

@export_group("Suction")
## The Gulper's suction (two-stage-attack.md 4d): while the pouch is held open, school fish in a cone ahead of the mouth are drawn
## toward it at up to this speed (m/s) at full charge (0: no suction)...
@export_range(0.0, 100.0, 0.5, "or_greater") var suck_strength := 16.0
## ...and prey players in the cone are pushed toward the mouth by this much (m/s per s at full charge; they can swim against it)...
@export_range(0.0, 100.0, 0.5, "or_greater") var suck_prey_push := 12.0
## ...the cone is this many degrees either side of the nose...
@export_range(1.0, 180.0, 1.0) var suck_cone := 35.0
## ...it reaches this many times the bite's reach at full charge...
@export_range(0.1, 10.0, 0.05, "or_greater") var suck_reach_mult := 2.5
## ...and this share of that at no charge (the cone grows with the hold)...
@export_range(0.0, 1.0, 0.05) var suck_reach_min := 0.4
## ...and the pull is this share of its strength at no charge.
@export_range(0.0, 1.0, 0.05) var suck_charge_min := 0.35
## The release snaps shut on everything within this many bite radii of the mouth...
@export_range(0.05, 5.0, 0.05, "or_greater") var gulper_mouth_r := 0.7
## ...the belly shows what it took as a lump sliding down it for this long (s)...
@export_range(0.0, 20.0, 0.1, "or_greater") var suck_lump_s := 3.0
## ...and bulges this much (the lump's share of the girth there, scaled by how much was taken; 0: no lump).
@export_range(0.0, 3.0, 0.05, "or_greater") var suck_lump_size := 0.5

@export_group("Lock")
## The Fallen Angel's lock (two-stage-attack.md 4c): a press only takes with a fish within this many reaches of the nose (0: it never takes)...
@export_range(0.0, 10.0, 0.1, "or_greater") var angel_lock_range := 2.0
## ...and within this many degrees of the nose (the cone ahead; 180: all round)...
@export_range(1.0, 180.0, 1.0) var angel_lock_cone := 40.0
## ...then it holds this many reaches from the target (the stand-off)...
@export_range(0.1, 6.0, 0.05, "or_greater") var angel_standoff := 0.7
## ...the stick orbits it round the target this fast (rad/s at full stick)...
@export_range(0.0, 10.0, 0.1, "or_greater") var angel_orbit_speed := 1.6
## ...it closes in on the stand-off at most this fast (m/s)...
@export_range(0.0, 200.0, 0.5, "or_greater") var angel_close_speed := 14.0
## ...and pivots to keep facing the target at most this fast (rad/s)...
@export_range(0.0, 60.0, 0.1, "or_greater") var angel_face_rate := 6.0
## ...the lock snaps if the target gets further than this many reaches (or is eaten)...
@export_range(0.5, 20.0, 0.1, "or_greater") var angel_break_range := 3.5
## ...and the crown waits this long (s) before it opens again...
@export_range(0.0, 10.0, 0.1, "or_greater") var angel_break_cooldown := 1.0
## ...a release takes capacity x this x how squarely it faces the target's school (at least the target)...
@export_range(0.0, 20.0, 0.1, "or_greater") var angel_count_mult := 3.0
## ...of which the charge is this share (0: only the angle counts)...
@export_range(0.0, 1.0, 0.05) var angel_charge_weight := 0.3
## ...and the lash travels this fast (m/s): each fish's crunch plays when it arrives (0: all at once).
@export_range(0.0, 400.0, 1.0, "or_greater") var angel_lash_speed := 40.0

@export_group("Coil")
## The King's coil-whip (two-stage-attack.md 4e): a release sweeps a flat sector round the nose. Its width is this many degrees
## (all the way across) at no charge...
@export_range(1.0, 360.0, 1.0) var coil_arc_min := 45.0
## ...growing to this many degrees at full charge (the coil tightens as it is held)...
@export_range(1.0, 360.0, 1.0) var coil_arc_max := 160.0
## ...the whip pivots this share of the bite's reach behind the mouth, and the sector reaches a reach beyond the mouth from there...
@export_range(0.0, 3.0, 0.05, "or_greater") var coil_pivot := 0.45
## ...it is this many reaches thick, up and down (flat: a thin one only takes what is level with the head)...
@export_range(0.05, 5.0, 0.05, "or_greater") var coil_thick := 0.5
## ...a release at full charge takes this x the form's capacity (1: the charge only widens the arc)...
@export_range(0.0, 10.0, 0.1, "or_greater") var coil_capacity_mult := 1.5
## ...and the body curls through this many degrees round itself at full charge (0: it stays straight).
@export_range(0.0, 720.0, 5.0, "or_greater") var coil_curl_deg := 300.0

@export_group("Drill")
## The Lamprey Queen's drill (two-stage-attack.md 4f): a release dashes forward corkscrewing at this x her top speed at full
## charge (x the charge; 0: no dash, the plain bite)...
@export_range(0.0, 10.0, 0.05, "or_greater") var drill_dash := 2.0
## ...for this long (s)...
@export_range(0.0, 5.0, 0.05, "or_greater") var drill_time := 0.6
## ...taking what the disc passes through, up to the form's capacity x this at full charge (x the charge)...
@export_range(0.0, 30.0, 0.1, "or_greater") var drill_capacity_mult := 6.0
## ...in a tube this x the bite's radius across...
@export_range(0.1, 5.0, 0.05, "or_greater") var drill_radius_mult := 1.5
## ...a hold shorter than this share of the charge does not dash (the plain bite)...
@export_range(0.0, 1.0, 0.05) var drill_min_charge := 0.2
## ...and at full charge the first prey player the disc meets is latched: the dash ends and she rolls on it.
@export var drill_latch := true

@export_group("Stomach")
## Upset Stomach (what_stinks.md 1b). The satiation bar's size (the Hunter wins by filling it)...
@export_range(1.0, 1000.0, 1.0, "or_greater") var satiation_max := 100.0
## ...where it starts (share of full)...
@export_range(0.0, 1.0, 0.01) var satiation_start := 0.25
## ...how fast hunger drains it (per s; the Hunter can't idle)...
@export_range(0.0, 20.0, 0.1, "or_greater") var satiation_decay := 0.5
## ...what a school fish adds (x its size, below)...
@export_range(0.0, 100.0, 0.5, "or_greater") var satiation_per_fish := 4.0
## ...where size is the fish's body length over this (m), to this power (0: every fish is worth the same; 1: by length)...
@export_range(0.05, 10.0, 0.05, "or_greater") var satiation_ref_length := 0.8
@export_range(0.0, 4.0, 0.05, "or_greater") var satiation_size_exp := 1.0
## ...and the fish's own size dial (x fish_scale) counts too.
@export var satiation_uses_fish_scale := true
## A prey player in the bite costs the Hunter this much satiation (spat out)...
@export_range(0.0, 1000.0, 1.0, "or_greater") var spit_satiation_loss := 15.0
## ...makes it this queasy (the queasy bar is queasy_max long; 3 spits by default)...
@export_range(0.0, 100.0, 0.1, "or_greater") var queasy_per_spit := 1.0
@export_range(0.1, 100.0, 0.1, "or_greater") var queasy_max := 3.0
## ...the queasiness settles at this rate (per s)...
@export_range(0.0, 5.0, 0.01, "or_greater") var queasy_decay := 0.01
## ...and the Hunter can't bite for this long (s) after a spit.
@export_range(0.0, 60.0, 0.1, "or_greater") var spit_cooldown := 3.0
## The spat-out prey is flung this fast (m/s) away from the Hunter's mouth...
@export_range(0.0, 100.0, 0.5, "or_greater") var spit_speed := 22.0
## ...and is dazed this long (s): no boost, no joining a school.
@export_range(0.0, 60.0, 0.1, "or_greater") var spit_daze := 4.0
## Schools come back steadily: every this many seconds (0: off) each school below its first size gains...
@export_range(0.0, 120.0, 0.5, "or_greater") var respawn_every := 6.0
## ...this many fish (swimming with it)...
@export_range(0, 50, 1, "or_greater") var respawn_batch := 3
## ...and a school wiped out is replaced by a new one this many seconds later, this far (m) from every Hunter.
@export_range(0.0, 120.0, 0.5, "or_greater") var respawn_school_delay := 10.0
@export_range(0.0, 500.0, 1.0, "or_greater") var respawn_school_gap := 80.0
## Upset Stomach scoring: the Hunter's points per satiation it earns (fish eaten; hunger and spits don't take them back)...
@export_range(0.0, 100.0, 0.1, "or_greater") var satiation_points := 1.0
## ...a prey's points for each spit it caused (the one it was spat out of)...
@export_range(0.0, 1000.0, 1.0, "or_greater") var spit_points := 60.0
## ...and a Hunter that hurls is out for the round (it stays held until the next).

@export_group("Schools")
## Schools placed once at the round's start (the ocean never respawns them).
@export_range(0, 60, 1, "or_greater") var school_count := 14
## A school's fish, at least...
@export_range(1, 300, 1, "or_greater") var school_min := 20
## ...and at most.
@export_range(1, 300, 1, "or_greater") var school_max := 60
## How far from its home a school roams (m).
@export_range(0.0, 400.0, 1.0, "or_greater") var school_roam := 45.0
## A school's cruise (m/s).
@export_range(0.0, 40.0, 0.5, "or_greater") var school_speed := 5.5
## A school fish's size (x the usual).
@export_range(0.1, 5.0, 0.05, "or_greater") var fish_scale := 1.0
## The share of the schools made of the classes the prey are playing (the rest: any class). Each class played gets one first.
@export_range(0.0, 1.0, 0.05) var school_prey_share := 0.7

@export_group("Join")
## A prey fish within this far (m) of a school's fish can join it.
@export_range(0.0, 60.0, 0.5, "or_greater") var join_radius := 4.0
## Joining eases the player into their place over this long (s); 0: at once.
@export_range(0.0, 10.0, 0.05, "or_greater") var join_ease := 0.6
## Join anything (on), or only a school of your own class (off: find your own kind).
@export var join_any_class := false
## How far (m) the stick leans a joined player's place in the school.
@export_range(0.0, 10.0, 0.1, "or_greater") var join_lean := 1.2
## After leaving, this long (s) before the player can join a school again.
@export_range(0.0, 60.0, 0.5, "or_greater") var rejoin_cooldown := 3.0
## Leaving dashes out of the school at this speed (m/s over the school's)...
@export_range(0.0, 80.0, 0.5, "or_greater") var leave_speed := 14.0
## ...and is this loud (0..1 of the noise meter; a jump's worth).
@export_range(0.0, 1.0, 0.05) var leave_noise := 0.7
## Spooks each prey player has per round (they startle the school they're in).
@export_range(0, 10, 1, "or_greater") var spook_charges := 1
## A spook bursts every fish in the school this hard (x the usual burst)...
@export_range(0.0, 20.0, 0.1, "or_greater") var spook_strength := 2.5
## ...along this many headings...
@export_range(1, 8, 1, "or_greater") var spook_groups := 3
## ...and the school takes this long (s) to re-form.
@export_range(0.0, 60.0, 0.5, "or_greater") var spook_reform := 4.0
## Joined prey show to the other prey as ally markers (and to themselves).
@export var ally_markers := true
## Prey bots join a school they come within the join radius of.
@export var bots_join := true
## Button that joins a school.
@export_enum("jump", "boost", "powerslide", "air_roll") var join_button := "jump"
## Button that leaves it.
@export_enum("boost", "jump", "powerslide", "air_roll") var leave_button := "boost"
## Button that spooks it.
@export_enum("powerslide", "air_roll", "jump", "boost") var spook_button := "powerslide"

@export_group("Echo")
## How the Hunter's picture of a prey player builds (what_stinks.md section 4b). A
## prey inside the echo cone gains this much echo per second (0..1; at the near
## range, still, a loner): 0.13 reaches the skin layer (0.65) in 5 s.
@export_range(0.0, 2.0, 0.005, "or_greater") var echo_build := 0.13
## The echo fades this fast (per s) outside the cone, and in an echo shadow, as well as the build there.
@export_range(0.0, 2.0, 0.005, "or_greater") var echo_decay := 0.1
## The cone's half angle (degrees) round the Hunter's nose.
@export_range(1.0, 180.0, 1.0) var echo_cone_deg := 35.0
## The cone's range (m) at size 1: echo builds at full inside the near share and fades to nothing at the range.
@export_range(1.0, 1000.0, 1.0, "or_greater") var echo_range := 60.0
## ...the full-build distance (m) at size 1.
@export_range(0.0, 500.0, 1.0, "or_greater") var echo_near := 10.0
## Range and near x Hunter size^this (the murk sight's 0.5: a bigger monster listens further).
@export_range(0.0, 2.0, 0.05, "or_greater") var echo_size_exp := 0.5
## A fast prey is a smeared echo: the build falls to smear_floor (share of full) at this speed (m/s) or more...
@export_range(0.1, 100.0, 0.1, "or_greater") var smear_speed := 8.0
@export_range(0.0, 1.0, 0.01) var smear_floor := 0.25
## ...along this curve (1: a straight line; higher: it falls fast, then levels off).
@export_range(0.1, 10.0, 0.1, "or_greater") var smear_curve := 3.0
## Echo shadows (kelp stands, rock arches) multiply the build by this (0: none).
@export_range(0.0, 1.0, 0.01) var shadow_mult := 0.2
## A school member's echo builds this much as fast (the crowd's clutter).
@export_range(0.0, 1.0, 0.01) var blend_echo_mult := 0.1
## Echo shadows placed per round (kelp stands and rock arches, alternating)...
@export_range(0, 60, 1, "or_greater") var shadow_count := 10
## ...and their radius (m).
@export_range(1.0, 100.0, 0.5, "or_greater") var shadow_radius := 9.0
## Noise (NoiseMeter, Marco Polo's loud swimming and strides) is seen out to this far (m) at size 1, x size^echo_size_exp...
@export_range(1.0, 1000.0, 1.0, "or_greater") var noise_sight := 60.0
## ...fully within this share of it, half way out at the other share.
@export_range(0.0, 1.0, 0.01) var noise_near_share := 0.15
@export_range(0.0, 1.0, 0.01) var noise_half_share := 0.45
## Click: an instant echo of this much to every prey in the cone (a school member's x blend_echo_mult).
@export_range(0.0, 1.0, 0.01) var click_gain := 0.4
## Seconds between Clicks.
@export_range(0.1, 60.0, 0.1, "or_greater") var click_cooldown := 3.0
## The Hunter clicks by itself when ready (the Titan's auto Marco); off: only on click_button.
@export var click_auto := false
## A Click draws an expanding sonar ring in the water (the Hunter's own view).
@export var click_ring := false
@export_enum("air_roll", "powerslide", "jump", "boost") var click_button := "air_roll"
## Sniff (hold): the cone narrows to this share, echo builds x sniff_mult, and the Hunter swims at sniff_speed of its speed.
@export_range(0.05, 1.0, 0.01) var sniff_cone_mult := 0.4
@export_range(0.0, 20.0, 0.1, "or_greater") var sniff_mult := 2.0
@export_range(0.0, 1.0, 0.01) var sniff_speed := 0.5
@export_enum("powerslide", "air_roll", "jump", "boost") var sniff_button := "powerslide"
## The Hunter sees only what its echo and the noise show (a prey below the skeleton layer is not drawn). Off: everyone is drawn as ever.
@export var hunter_blind := true

@export_group("Arena")
## The ocean's soft murk wall (m from the middle): past it the water thickens and pushes back.
@export_range(30.0, 2000.0, 5.0, "or_greater") var arena_radius := 220.0
## Prey start between this share and...
@export_range(0.0, 1.0, 0.01) var prey_spawn_min := 0.25
## ...this share of the arena's radius from the Hunter.
@export_range(0.0, 1.0, 0.01) var prey_spawn_max := 0.7
## The wall's push back in (1/s per m past it).
@export_range(0.0, 20.0, 0.1, "or_greater") var wall_stiffness := 2.0
## ...and against a fish swimming out (x its outward speed).
@export_range(0.0, 20.0, 0.1, "or_greater") var wall_outward := 2.0
## The most the wall pushes (m/s^2).
@export_range(0.0, 200.0, 1.0, "or_greater") var wall_max := 40.0

@export_group("Scoring")
## The Hunter's points per prey eaten.
@export_range(0.0, 1000.0, 1.0, "or_greater") var tag_points := 100.0
## ...and for finishing early: up to this many, by the share of the clock left.
@export_range(0.0, 2000.0, 1.0, "or_greater") var time_bonus := 150.0
## Prey's points per second alive.
@export_range(0.0, 100.0, 0.1, "or_greater") var survive_points := 2.0
## ...and the last prey standing's bonus.
@export_range(0.0, 1000.0, 1.0, "or_greater") var last_fish_bonus := 100.0
## ...and every prey left when the clock runs out.
@export_range(0.0, 1000.0, 1.0, "or_greater") var survivor_bonus := 150.0

@export_group("Bots")
## A prey bot's cruise (throttle, 0..1).
@export_range(0.0, 1.0, 0.05) var prey_bot_pace := 0.5
## A Hunter bot's stalk throttle while it has no fish close.
@export_range(0.0, 1.0, 0.05) var hunter_bot_stalk := 0.7
## ...and it boosts to a fish at least this far off (m; 0: always).
@export_range(0.0, 200.0, 1.0, "or_greater") var hunter_bot_boost_gap := 25.0
## ...and bites when a fish is within this share of the bite's reach.
@export_range(0.1, 2.0, 0.05) var hunter_bot_bite_share := 0.8
## A Hunter bot opens its jaws when a fish is within this share of the bite's reach (more than the bite share: it opens on the way in)...
@export_range(0.1, 4.0, 0.05, "or_greater") var hunter_bot_open_gap := 1.6
## ...and shuts them once the charge is at least this (or at once if the fish is getting away).
@export_range(0.0, 1.0, 0.05) var hunter_bot_charge := 0.5
## Fallen Angel bot: lets the lash go once the facing share is at least this (or the hold runs long).
@export_range(0.0, 1.0, 0.05) var hunter_bot_lock_align := 0.6
## Upset Stomach: a Hunter bot won't bite while a prey it can read (exposure at least this) is in its bite or is the nearest fish (0: reads nothing).
@export_range(0.0, 1.0, 0.01) var hunter_bot_avoid_exposure := 0.3
## ...and a prey bot heads for the school nearest the Hunter (bait: it wants to be taken for food).
@export var prey_bot_baits := true
## A bot Hunter picks the school with the most fish left (it knows the count), not just the nearest fish.
@export var hunter_bot_prefers_big := true
## Clean Sweep: a Hunter bot goes for a prey it can read (exposure at least this) before plain fish, and a loner it can't read isn't a target (0: it never reads, every prey is just the nearest fish).
@export_range(0.0, 1.0, 0.01) var hunter_bot_read_exposure := 0.25
## A Hunter bot Clicks when the Click is ready and no prey is readable (off: it never clicks).
@export var hunter_bot_click := true
## Clean Sweep: a Hunter bot sniffs while it works a school it has found no prey in, for this long (s) per school, then heads for another (0: it never sniffs).
@export_range(0.0, 60.0, 0.5, "or_greater") var hunter_bot_sniff_s := 4.0
## A prey bot that is joined leaves and heads for another school when a Hunter reads it at least this much (exposure)...
@export_range(0.0, 1.0, 0.01) var prey_bot_exposure := 0.45
## ...for this long (s) (0: it never relocates; it doesn't while baiting in Upset Stomach either).
@export_range(0.0, 30.0, 0.1, "or_greater") var prey_bot_patience := 2.5


@export_group("Camera")
## The view is the follow cam (Unnatural's Settle style, from its panel) and the ball cam button locks on a school: a tap toggles lock-on and looks at the nearest school ahead, holding opens the school wheel. Off: the follow cam only.
@export var lock_on := true
## Ramming: a Hunter at ram_speed (m/s at size 1, x its size's speed) or faster takes what its front touches, up to
## capacity x ram_capacity_mult fish, no more than every ram_cooldown s; ram_width is the reach to the side (x its length).
@export var ram := true
@export_range(1.0, 200.0, 0.5, "or_greater") var ram_speed := 14.0
@export_range(0.1, 10.0, 0.1, "or_greater") var ram_capacity_mult := 1.5
@export_range(0.0, 5.0, 0.05, "or_greater") var ram_cooldown := 0.4
@export_range(0.05, 2.0, 0.05, "or_greater") var ram_width := 0.5
## A bite while locked on a school takes its fish from that school alone (the locked Hunter's bite), up to capacity x lock_bite_mult x its line-up...
@export var lock_bite := true
@export_range(0.1, 10.0, 0.1, "or_greater") var lock_bite_mult := 3.0
## ...reaching this many bite reaches from the mouth (further: the plain bite)...
@export_range(0.5, 5.0, 0.1, "or_greater") var lock_bite_range := 1.5
## ...the share a poor line-up still takes (0: could take none, but a bite takes at least 1)...
@export_range(0.0, 1.0, 0.01) var lock_bite_floor := 0.25
## ...and how much the line-up counts each of: facing the school, being close, rushing at it.
@export_range(0.0, 5.0, 0.05, "or_greater") var lock_w_angle := 0.4
@export_range(0.0, 5.0, 0.05, "or_greater") var lock_w_close := 0.3
@export_range(0.0, 5.0, 0.05, "or_greater") var lock_w_speed := 0.3
## Prey get the lock-on and the school wheel too (to pick a school to head for). Off: the Hunter only.
@export var lock_on_prey := true
## How long (s) the ball cam button is held to open the school wheel.
@export_range(0.05, 3.0, 0.05, "or_greater") var wheel_hold_time := 0.3
## Arrows at the screen's edge point to the schools that are off screen (the locked one in gold).
@export var school_arrows := true
## A tap looks at the school with the least distance x (this - how far ahead it is): 1 is the nearest ahead only, higher counts a school behind as that much further off.
@export_range(1.0, 10.0, 0.05, "or_greater") var lock_behind_cost := 1.5
## A tap only picks schools within this range (m; 0: any).
@export_range(0.0, 2000.0, 5.0, "or_greater") var lock_range := 0.0
## How quickly the view swings onto a school as lock-on goes on or off (the camera's transition speed).
@export_range(0.1, 6.0, 0.05, "or_greater") var lock_swing := 1.2

## The sheet of the form picked.
func form_sheet() -> Dictionary:
	return HunterForms.sheet(HunterForms.playable(form))
