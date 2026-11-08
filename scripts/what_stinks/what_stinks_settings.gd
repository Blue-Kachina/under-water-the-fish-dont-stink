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
@export_enum("drowned_shark", "humpback", "orca", "beluga", "sperm", "blue", "king_of_herrings", "gulper_mother", "whale_fall", "lamprey_queen", "fallen_angel", "ember_octopus", "lantern_angler") var form := "drowned_shark"
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
## How hard the Lamprey Queen's corkscrew dash propels her, as a multiple of the old lunge. 1.0 is the old, too-long lunge; 0.55 is about half the travel; 0 switches the lunge off.
@export_range(0.0, 3.0, 0.05, "or_greater") var lamprey_lunge_impulse := 0.55
## ...her body telescopes no longer than this (cap on the spine stretch)...
@export_range(1.0, 4.0, 0.05, "or_greater") var lamprey_telescope_max := 1.9
## ...each unit of disc scale adds this many skin 'disc' units (the lip radius is 1 + 0.4 x disc)...
@export_range(0.0, 6.0, 0.05, "or_greater") var lamprey_disc_flare := 1.35
## ...the teeth spin this many rad/s per unit of spin scale above rest...
@export_range(0.0, 40.0, 0.5, "or_greater") var lamprey_teeth_spin := 7.0
## ...and through the corkscrew dash the body stretches this much more (sustained)...
@export_range(1.0, 2.5, 0.05, "or_greater") var lamprey_dash_stretch := 1.3
## ...the disc flares this much more...
@export_range(1.0, 4.0, 0.05, "or_greater") var lamprey_dash_flare := 1.7
## ...and the teeth spin this many rad/s faster.
@export_range(0.0, 60.0, 0.5, "or_greater") var lamprey_dash_spin := 14.0

@export_group("Exaggeration")
## Master multiplier on how far every Hunter attack part departs from rest (squash, swell, smear, gape); 0 disables all exaggeration, hit-stop and punch, 1 is bold, 2 extreme.
@export_range(0.0, 4.0, 0.05, "or_greater") var hunter_exaggeration := 1.0
## Frames the attacker's rig freezes on a bite landing (scaled by hunter_exaggeration, capped 1.5x).
@export_range(0.0, 12.0, 0.5, "or_greater") var hunter_hit_stop_frames := 2.5
## Base camera punch emitted on a bite landing (x exaggeration).
@export_range(0.0, 5.0, 0.05, "or_greater") var hunter_camera_punch := 0.5
## Depth multiplier on the anticipation squash before the swell.
@export_range(0.0, 3.0, 0.05, "or_greater") var hunter_exaggerate_squash := 1.0
## Smear stretch per unit of scale speed.
@export_range(0.0, 0.5, 0.01, "or_greater") var hunter_exaggerate_smear := 0.05
## Hard cap on any exaggerated part scale (camera and mesh safety).
@export_range(1.0, 8.0, 0.1, "or_greater") var hunter_exaggerate_max_scale := 3.5

@export_group("Shark")
## The Drowned Shark's extra jaw swing in radians per unit of jaw growth.
@export_range(0.0, 3.0, 0.05, "or_greater") var shark_jaw_gape := 1.0
## The Drowned Shark's head thrust in body lengths per unit of head growth.
@export_range(0.0, 0.5, 0.01, "or_greater") var shark_head_thrust := 0.10
## The Drowned Shark's body stretch along its length with the head thrust.
@export_range(0.0, 0.6, 0.01, "or_greater") var shark_body_stretch := 0.12
## Multiplier on the Drowned Shark's tooth growth.
@export_range(0.0, 3.0, 0.05, "or_greater") var shark_teeth_gain := 1.0
## Multiplier on the Drowned Shark's eye growth and glow.
@export_range(0.0, 3.0, 0.05, "or_greater") var shark_eye_flare := 1.0

@export_group("Whales")
## The most the exaggerated whale jaw can open (degrees; soft limit: whale_gape_deg x the jaw channel is eased into it).
@export_range(20.0, 180.0, 1.0, "or_greater") var whale_gape_max_deg := 135.0
## How far the shut whale jaw bounces open after the bite lands (degrees; scaled by hunter_exaggeration).
@export_range(0.0, 60.0, 0.5, "or_greater") var whale_rebound_deg := 16.0
## How much the whole whale squashes, swells and lunges on press, charge and release (0: the body is never scaled).
@export_range(0.0, 3.0, 0.05, "or_greater") var whale_body_pulse := 1.0
## How far the throat pleats balloon while the mouth is held open, even empty.
@export_range(0.0, 4.0, 0.05, "or_greater") var whale_throat_balloon := 1.0
## How much baleen plates and teeth grow, and the tongue rises, with the exaggeration (0: no species pop).
@export_range(0.0, 3.0, 0.05, "or_greater") var whale_tooth_pop := 1.0

@export_group("King and Lamprey bodies")
## How stiff the King of Herrings' and Lamprey Queen's bodies are: 0 is the old floppy body, 1 a rigid bar (the default 0.4 keeps 0.6 of the old flex).
@export_range(0.0, 1.0, 0.05) var body_stiffness := 0.4
## The King's tail stretch on the release (the kit adds smear).
@export_range(1.0, 4.0, 0.05, "or_greater") var king_whip_stretch := 1.5
## The King's curl multiplier at full charge.
@export_range(1.0, 3.0, 0.05, "or_greater") var king_coil_tighten := 1.55
## How far the King's tail trails the head's sweep.
@export_range(0.0, 3.0, 0.05, "or_greater") var king_whip_lag := 0.45
## The coil level the press winds the King to at once (share of full).
@export_range(0.0, 0.95, 0.05) var coil_press_floor := 0.4

@export_group("Lantern Angler")
## The Lantern Angler's Lure: how far the esca's light reaches (m)...
@export_range(5.0, 120.0, 1.0, "or_greater") var lure_radius := 42.0
## ...the half angle of the light cone about where the Angler faces (degrees)...
@export_range(10.0, 180.0, 1.0) var lure_cone := 75.0
## ...the acceleration drawing a fish toward the esca at full ramp, next to it (m/s^2)...
@export_range(0.0, 30.0, 0.1, "or_greater") var lure_pull := 7.0
## ...the hardest any fish is ever drawn (m/s^2)...
@export_range(0.0, 40.0, 0.1, "or_greater") var lure_cap := 11.0
## ...the share of the pull a person cancels by swimming straight away from the light...
@export_range(0.0, 1.0, 0.01) var lure_resist := 0.9
## ...the same for a bot (which also has a steering bias toward the light)...
@export_range(0.0, 1.0, 0.01) var lure_bot_resist := 0.35
## ...the share of the pull a dash cancels...
@export_range(0.0, 1.0, 0.01) var lure_dash_cancel := 1.0
## ...the seconds of immunity after a dash breaks the hold...
@export_range(0.0, 5.0, 0.05, "or_greater") var lure_break_s := 1.2
## ...the seconds of holding to full attraction...
@export_range(0.05, 8.0, 0.05, "or_greater") var lure_ramp_s := 2.0
## ...the extra cooldown after the snap (s)...
@export_range(0.0, 10.0, 0.1, "or_greater") var lure_cooldown := 1.5
## ...the multiplier on the pull on school fish (0 off)...
@export_range(0.0, 4.0, 0.05, "or_greater") var lure_school_pull := 1.0
## ...how far a bot's swim target bends toward the lure at full hold...
@export_range(0.0, 1.0, 0.01) var lure_bot_bias := 0.8
## ...the distance (m) from where it is aiming at which the pull eases off, so nothing jitters at the mouth...
@export_range(0.1, 10.0, 0.1, "or_greater") var lure_fade_m := 1.5
## ...the esca's flicker rate with nothing near (Hz)...
@export_range(0.5, 20.0, 0.1, "or_greater") var lure_flicker_min := 2.5
## ...and with prey at the mouth (Hz)...
@export_range(2.0, 40.0, 0.1, "or_greater") var lure_flicker_max := 14.0
## ...the esca's brightness while held (1 is normal)...
@export_range(1.0, 6.0, 0.05, "or_greater") var lure_flare := 2.6
## ...and the jaw's opening multiplier while the lure is held.
@export_range(1.0, 2.5, 0.05, "or_greater") var lure_gape := 1.35
## The Angler's body: the stiffness of the lure stalk's spring (pull back to rest)...
@export_range(5.0, 120.0, 1.0, "or_greater") var angler_stalk_stiffness := 38.0
## ...its damping...
@export_range(1.0, 20.0, 0.1, "or_greater") var angler_stalk_damping := 5.5
## ...the idle sway of the esca...
@export_range(0.0, 3.0, 0.05, "or_greater") var angler_stalk_sway := 0.5
## ...the most point lights the esca may use (0 is halo only; the murk can lower it)...
@export_range(0, 32, 1) var angler_esca_light_cap := 6
## ...how rigid the body is (1 is a plank)...
@export_range(0.2, 1.0, 0.01) var angler_body_stiffness := 0.85
## ...the idle body sway (degrees)...
@export_range(0.0, 30.0, 0.5) var angler_sway_deg := 9.0
## ...the tail's peak angle in a lunge snap (degrees)...
@export_range(0.0, 90.0, 1.0) var angler_tail_snap_deg := 40.0
## ...the tail's ringing frequency after a snap (Hz)...
@export_range(0.5, 4.0, 0.05) var angler_tail_hz := 1.6
## ...the damping of that ringing...
@export_range(0.1, 1.0, 0.01) var angler_tail_zeta := 0.3
## ...the forward acceleration at 6 m that fires a tail-snap lunge (scaled with the square root of size)...
@export_range(2.0, 40.0, 0.5, "or_greater") var angler_burst_accel := 9.0
## ...the pectoral fins' scull rate (Hz)...
@export_range(0.2, 3.0, 0.05) var angler_pectoral_hz := 0.8
## ...and their sweep (degrees).
@export_range(0.0, 70.0, 1.0) var angler_pectoral_deg := 28.0
## Extra Swishy strides: how far the tail sweeps to each side on a stride, following the stick (degrees at the tip)...
@export_range(0.0, 120.0, 1.0, "or_greater") var angler_stride_tail_deg := 55.0
## ...and how much each stride exaggerates (the tail rings past its sweep and grows with flow, the stalk whips, the fins tuck; 0: none).
@export_range(0.0, 3.0, 0.05, "or_greater") var angler_stride_pop := 1.0

@export_group("Octopus lash")
## The Ember Octopus's Tendril Lash: a press rears the arms into a crown and locks them on prey; the release whips them out. At most this many arms lock on (one prey each).
@export_range(0, 8, 1) var whip_arms := 8
## An arm locks on prey within this many bite reaches of the mouth (x the charge's reach, below)...
@export_range(0.2, 5.0, 0.05, "or_greater") var whip_range := 1.15
## ...inside a cone this wide (degrees, the half angle) round the nose...
@export_range(5.0, 180.0, 1.0) var whip_cone := 75.0
## ...a lock already made is kept until its prey leaves the cone by this much (x the cone)...
@export_range(1.0, 3.0, 0.05, "or_greater") var whip_cone_slack := 1.2
## ...or the range by this much (x the range).
@export_range(1.0, 3.0, 0.05, "or_greater") var whip_range_slack := 1.25
## How much a target's angle off the nose counts against its distance when arms pick prey (0: nearest first).
@export_range(0.0, 4.0, 0.05, "or_greater") var whip_angle_weight := 0.6
## Free arms look for new prey this often (s) while the press is held (0: arms lock only at the press).
@export_range(0.0, 3.0, 0.05, "or_greater") var whip_refill_s := 0.25
## How hard a lashing arm steers after a moving target (0: a straight line to where it was, 1: fully homing).
@export_range(0.0, 1.0, 0.01) var whip_homing := 0.8
## How long (s) an arm takes to fly to its target.
@export_range(0.03, 1.5, 0.01, "or_greater") var whip_fly_s := 0.14
## Arms leave this soon after each other on the release (s, the least and the most).
@export_range(0.0, 0.5, 0.005, "or_greater") var whip_stagger_min := 0.03
@export_range(0.0, 0.5, 0.005, "or_greater") var whip_stagger_max := 0.06
## Fish each arm that lands takes (at the plain bite)...
@export_range(0, 10, 1, "or_greater") var whip_per_arm := 1
## ...and how many times that a full charge takes.
@export_range(0, 20, 1, "or_greater") var whip_charge_capacity := 2
## A full charge's reach (x the plain bite's) and, with it, the lock range.
@export_range(1.0, 4.0, 0.05, "or_greater") var whip_charge_reach := 1.4
## In the tap bite mode, the share of the locked arms a tap lashes.
@export_range(0.0, 1.0, 0.01) var whip_tap_share := 0.5
## How wide a lashing arm's hit is (x the bite's radius).
@export_range(0.1, 4.0, 0.05, "or_greater") var whip_hit_radius := 0.55
## The push the octopus takes (m/s) for each arm that lands, away from the prey...
@export_range(0.0, 30.0, 0.1, "or_greater") var whip_recoil := 2.2
## ...the share of that an arm that misses gives...
@export_range(0.0, 2.0, 0.01) var whip_miss_recoil := 0.35
## ...and the most one lash pushes it (m/s).
@export_range(0.0, 60.0, 0.5, "or_greater") var whip_recoil_cap := 7.0
## How wide the crown flares on the press (degrees from the nose).
@export_range(10.0, 170.0, 1.0) var whip_flare := 75.0
## How far an arm curls in its cocked coil: the least and the most (degrees, more with the charge).
@export_range(0.0, 540.0, 1.0) var whip_sweep_min := 140.0
@export_range(0.0, 720.0, 1.0) var whip_sweep_max := 290.0
## The most an arm may lengthen to reach a target (x its length).
@export_range(1.0, 4.0, 0.05, "or_greater") var whip_stretch := 1.6
## The crack that runs down a lashing arm: its size.
@export_range(0.0, 0.5, 0.005, "or_greater") var whip_wave := 0.07
## The crown takes this long (s) to open on the press...
@export_range(0.02, 2.0, 0.01, "or_greater") var whip_flare_s := 0.2
## ...arms reel in this long (s) after a lash that landed...
@export_range(0.05, 3.0, 0.01, "or_greater") var whip_retract_s := 0.4
## ...and after one that missed.
@export_range(0.05, 3.0, 0.01, "or_greater") var whip_miss_retract_s := 0.22
## A lash with no prey in reach still whips this many of the front arms into the water.
@export_range(0, 8, 1) var whip_whiff_arms := 4
## The strike waits this long (s) for the first arm to land before it goes on.
@export_range(0.02, 2.0, 0.01, "or_greater") var whip_stall_max := 0.45
## The lunge forward while the press is held (the bite's lunge gain; 0: none).
@export_range(0.0, 3.0, 0.05, "or_greater") var whip_lunge := 0.0
## The targeting aura sweeping the cone while held (0: off, 1: on).
@export_range(0.0, 1.0, 1.0) var whip_aura := 1.0

@export_group("Octopus grapple")
## The Ember Octopus's grapple: a press shoots one arm out to the nearest fish in reach and latches on; while held, free arms grab more fish that come in reach and the octopus is towed behind them; the release reels everything held into the beak at once. At most this many arms hold fish (one each).
@export_range(0, 8, 1) var grapple_arms := 8
## How far ahead of the beak a free arm reaches for a fish (x an arm's length)...
@export_range(0.2, 4.0, 0.05, "or_greater") var grapple_reach := 1.35
## ...the share of that reach left straight behind the beak (the reach sphere sits forward; 1 is a plain sphere)...
@export_range(0.0, 1.0, 0.01) var grapple_behind := 0.45
## ...and how much squareness to the nose counts against distance when picking a fish (0: the nearest wins).
@export_range(0.0, 4.0, 0.05, "or_greater") var grapple_front_bias := 0.6
## Seconds an arm takes to shoot out to a fish at full reach (nearer is quicker)...
@export_range(0.03, 1.5, 0.01, "or_greater") var grapple_latch_s := 0.16
## ...and seconds between grabs while the button is held.
@export_range(0.0, 3.0, 0.05, "or_greater") var grapple_regrab_s := 0.3
## The tow: the rope's length, the gap the octopus trails behind what it holds at (x arm length)...
@export_range(0.1, 4.0, 0.05, "or_greater") var grapple_tow_length := 0.9
## ...the share of that length inside which the rope is slack (no tow)...
@export_range(0.0, 0.99, 0.01) var grapple_tow_slack := 0.6
## ...how hard a taut rope closes a stretch past its length (m/s per m)...
@export_range(0.0, 30.0, 0.1, "or_greater") var grapple_tow_stiffness := 4.0
## ...the share of the fish's sideways speed a taut rope matches...
@export_range(0.0, 1.0, 0.01) var grapple_tow_follow := 0.9
## ...how fast the tow brings the octopus's velocity round (per s)...
@export_range(0.0, 60.0, 0.5, "or_greater") var grapple_tow_response := 10.0
## ...and the octopus's own jet while it holds a fish (x; its swim then only adds a little steering).
@export_range(0.01, 2.0, 0.01, "or_greater") var grapple_tow_thrust := 0.35
## A fish further than this from its arm's base tears loose and the arm snaps back (x arm length).
@export_range(1.0, 6.0, 0.05, "or_greater") var grapple_max_stretch := 2.2
## A prey player's weight in the tow's pull (a school fish is 1).
@export_range(0.0, 10.0, 0.1, "or_greater") var grapple_prey_weight := 2.0
## Breaking free: 1 lets a grabbed prey's dash (boost, or leaving its school) tear the arm off (0: it does not)...
@export_range(0.0, 1.0, 1.0) var grapple_break_dash := 1.0
## ...a prey on another machine counts as dashing when it pulls away this much faster than the octopus (m/s)...
@export_range(0.5, 40.0, 0.5, "or_greater") var grapple_break_rel := 9.0
## ...a prey turning at least this fast is counter-steering (degrees per s)...
@export_range(10.0, 720.0, 5.0, "or_greater") var grapple_break_turn := 120.0
## ...and tears free after this long of it (s; 0: steering never frees it)...
@export_range(0.0, 5.0, 0.05, "or_greater") var grapple_break_steer_s := 0.5
## ...and a prey that tore free cannot be grabbed again for this long (s).
@export_range(0.0, 10.0, 0.1, "or_greater") var grapple_break_immune_s := 1.2
## Fish each held arm eats on the release...
@export_range(1, 10, 1, "or_greater") var grapple_per_arm := 1
## ...and the reach round each held fish its arm also eats from (x bite radius; with more than one per arm).
@export_range(0.0, 2.0, 0.01, "or_greater") var grapple_eat_radius := 0.0
## Seconds from the release to the beak's snap (the held arms yank taut first)...
@export_range(0.0, 1.0, 0.01, "or_greater") var grapple_yank_s := 0.1
## ...the most the snap waits for an arm still reaching for its fish...
@export_range(0.02, 2.0, 0.01, "or_greater") var grapple_stall_max := 0.35
## ...seconds an arm takes to reel its catch in to the beak...
@export_range(0.05, 2.0, 0.01, "or_greater") var grapple_reel_s := 0.32
## ...seconds an arm takes to settle back after letting go...
@export_range(0.05, 2.0, 0.01, "or_greater") var grapple_retract_s := 0.3
## ...and seconds a tap with nothing in reach takes to flick one arm out and back.
@export_range(0.05, 2.0, 0.01, "or_greater") var grapple_whiff_s := 0.3
## How much a slack arm sags (1: it keeps its full length)...
@export_range(0.0, 1.5, 0.01) var grapple_sag := 0.55
## ...and how much a taut arm trembles (x arm length).
@export_range(0.0, 0.2, 0.005, "or_greater") var grapple_tremble := 0.025
## How much of the bite's lunge moves the body while grappling (HunterBite.lunge_gain).
@export_range(0.0, 3.0, 0.05, "or_greater") var grapple_lunge := 0.0
## A Hunter bot lets go once it holds this many fish...
@export_range(1, 8, 1) var grapple_bot_want := 4
## ...or once it has held something this long (s).
@export_range(0.2, 10.0, 0.1, "or_greater") var grapple_bot_hold_s := 2.5
## A grabbed prey bot tries to tear free with this chance...
@export_range(0.0, 1.0, 0.01) var grapple_bot_break := 0.65
## ...after this long (s).
@export_range(0.0, 3.0, 0.05, "or_greater") var grapple_bot_react_s := 0.4

@export_group("Octopus body")
## The Ember Octopus's swim: seconds per jet pulse at idle throttle (shorter at speed, x0.62 on a dash)...
@export_range(0.3, 4.0, 0.05, "or_greater") var octopus_jet_period := 1.1
## ...the share of each pulse that is the power stroke (the mantle squeezes and the jet fires)...
@export_range(0.08, 0.8, 0.01) var octopus_jet_power := 0.3
## ...the thrust at the peak of a power stroke (m/s^2)...
@export_range(0.0, 80.0, 0.5, "or_greater") var octopus_jet_accel := 14.0
## ...and the thrust multiplier of a boost (dash) pulse.
@export_range(1.0, 5.0, 0.05, "or_greater") var octopus_dash_mult := 1.8
## How far the siphon swivels at full stick (rad): it steers the jet...
@export_range(0.0, 1.4, 0.01, "or_greater") var octopus_jet_vector := 0.6
## ...how much the siphon's off-centre thrust turns the body...
@export_range(0.0, 3.0, 0.05, "or_greater") var octopus_jet_torque := 0.5
## ...and how much the drag of asymmetrically flared arms turns it.
@export_range(0.0, 3.0, 0.05, "or_greater") var octopus_flare_torque := 0.5
## How far each arm trails behind the one before it along its length (follow the leader)...
@export_range(0.0, 1.5, 0.01, "or_greater") var octopus_arm_lag := 0.55
## ...the arm spring's stiffness...
@export_range(4.0, 80.0, 0.5, "or_greater") var octopus_arm_stiffness := 26.0
## ...and its damping ratio.
@export_range(0.2, 2.0, 0.01, "or_greater") var octopus_arm_damping := 0.8
## How much the arms keep their world direction when the body turns or rolls (they swing wide).
@export_range(0.0, 1.5, 0.01, "or_greater") var octopus_inertia := 0.9
## How far the flow bends the arm tips back at speed.
@export_range(0.0, 2.0, 0.01, "or_greater") var octopus_drag_bend := 0.8
## The cruise scull's undulation size and its frequency (Hz).
@export_range(0.0, 3.0, 0.05, "or_greater") var octopus_scull_amp := 1.0
@export_range(0.2, 4.0, 0.05, "or_greater") var octopus_scull_hz := 1.3
## The lazy arm sway at rest.
@export_range(0.0, 3.0, 0.05, "or_greater") var octopus_idle_sway := 1.0
## How much slack arms hang toward the world's down...
@export_range(0.0, 1.0, 0.01) var octopus_droop := 0.35
## ...and how far the arm tips curl toward the sucker side.
@export_range(0.0, 1.0, 0.01) var octopus_tip_curl := 0.3
## The swim (mantle first, arms trailing in a delta): how much the delta narrows on a jet's power stroke (1: bundled tight)...
@export_range(0.0, 1.0, 0.01) var octopus_jet_narrow := 0.45
## ...how much it re-spreads on the recovery...
@export_range(0.0, 1.0, 0.01) var octopus_jet_respread := 0.35
## ...the size of the wave each jet sends down the arms (0: none)...
@export_range(0.0, 1.0, 0.01, "or_greater") var octopus_jet_wave := 0.22
## ...and how far a turn or roll banks the delta like a wing (rad at full stick).
@export_range(0.0, 1.5, 0.01, "or_greater") var octopus_bank := 0.45
## The crawl: within this many body lengths of a floor the arms plant and walk (0: no crawl)...
@export_range(0.0, 2.0, 0.05, "or_greater") var octopus_crawl_range := 0.8
## ...seconds per arm step...
@export_range(0.1, 1.5, 0.01, "or_greater") var octopus_crawl_step_time := 0.42
## ...how far a foot may lag its home before the arm steps (share of the arm's length)...
@export_range(0.05, 1.0, 0.01) var octopus_crawl_step_len := 0.3
## ...how high a step arcs and the elbows arch...
@export_range(0.0, 1.5, 0.01, "or_greater") var octopus_crawl_lift := 0.4
## ...how fast the crawl blends in and out (per s)...
@export_range(0.5, 10.0, 0.1, "or_greater") var octopus_crawl_blend_rate := 2.5
## ...the height (share of its length) it settles to over a floor with no throttle (0: off)...
@export_range(0.0, 1.0, 0.01) var octopus_crawl_height := 0.3
## ...and how fast it settles there.
@export_range(0.0, 10.0, 0.1, "or_greater") var octopus_crawl_pull := 2.5
## Extra Swishy strides: 1 makes each stride fire the jet on the input (the mantle swells at once, squeezes as the stride peaks) instead of the free-running beat; 0 keeps the beat...
@export_range(0.0, 1.0, 1.0) var octopus_stride_sync := 1.0
## ...how far each stride exaggerates the jet (the mantle pops past its swell and rings, the arms flare then snap tight; 0: none)...
@export_range(0.0, 3.0, 0.05, "or_greater") var octopus_stride_pop := 1.0
## ...and how tightly speed pulls the arms into a streamlined bundle (1: fully bundled at full speed).
@export_range(0.0, 1.5, 0.01, "or_greater") var octopus_speed_tuck := 0.6
## The skin's glow.
@export_range(0.0, 3.0, 0.05, "or_greater") var octopus_glow := 1.0
## Suckers draw at full detail within this many body lengths, and at all within the second (0: no limit).
@export_range(0.0, 12.0, 0.1, "or_greater") var octopus_sucker_hi_range := 3.0
@export_range(0.0, 30.0, 0.1, "or_greater") var octopus_sucker_range := 7.0

@export_group("Preview")
## The card's Hunter preview: share of full throttle it swims at.
@export_range(0.0, 1.0, 0.05) var preview_throttle := 0.75
## ...its speed as a multiple of the default (a share of its body length a second).
@export_range(0.0, 5.0, 0.05, "or_greater") var preview_speed := 1.0
## ...and how far it wanders in yaw and pitch (1 the default gentle S-curves, 0 straight).
@export_range(0.0, 4.0, 0.05, "or_greater") var preview_wander := 1.0

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
