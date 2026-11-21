class_name ChompSettings
extends TraversalSettings
## The chomp kit's tuning (ChompKit): a jawed hunter's bite beats, hit-stop, shake and rumble.

static var _fb_chomp: ChompSettings


## The copy the panel edits and the kit reads (the mode's own, once it has registered).
static func shared() -> ChompSettings:
	var mode_copy = TerrainSettings.provider.call() if TerrainSettings.provider.is_valid() else null
	if mode_copy is ChompSettings:
		return mode_copy
	if _fb_chomp == null:
		_fb_chomp = ChompSettings.new()
	return _fb_chomp


@export_group("Chomps")
## Every jawed boss's chomp (ChompKit) as a real bite's beats: the head pulls
## back (chomp_pull times its bite's reach) and the snout lifts (chomp_lift
## rad) over chomp_anticipate s, the jaw drops open (fast, then slowing) over
## chomp_gape s and holds wide for chomp_hold s; these three are scaled
## together to fit each boss's own chomp wind (shark_chomp_wind,
## king_chomp_wind). Then the strike: the head lunges chomp_lunge times the
## reach as the jaws slam shut over chomp_strike s; it saws side to side
## (chomp_saw rad) for chomp_shake s, and settles over chomp_recover s.
@export_range(0.0, 2.0, 0.01, "or_greater") var chomp_anticipate := 0.12
@export_range(0.0, 2.0, 0.01, "or_greater") var chomp_gape := 0.2
@export_range(0.0, 2.0, 0.01, "or_greater") var chomp_hold := 0.2
@export_range(0.01, 1.0, 0.01, "or_greater") var chomp_strike := 0.07
@export_range(0.0, 2.0, 0.01, "or_greater") var chomp_shake := 0.3
@export_range(0.0, 2.0, 0.01, "or_greater") var chomp_recover := 0.25
@export_range(0.0, 3.0, 0.05, "or_greater") var chomp_pull := 0.15
@export_range(0.0, 4.0, 0.05, "or_greater") var chomp_lunge := 0.8
@export_range(0.0, 1.0, 0.01, "or_greater") var chomp_lift := 0.15
@export_range(0.0, 1.0, 0.01, "or_greater") var chomp_saw := 0.12
## The bite lands on the tick the jaws are this shut (0.9: 90%), from where the
## mouth is then: the lunge counts, and a side-step during the hold dodges it.
@export_range(0.5, 1.0, 0.01) var chomp_contact := 0.9
## The Drowned Shark's chomp drawn Battletoads style (ChompKit.Bite.smear): how much
## its body squashes and stretches with the beats (0: not at all, 1: swelling as it
## winds up, tall as the jaw drops, wrung long in the lunge, slammed flat on impact).
@export_range(0.0, 2.0, 0.05) var chomp_smear := 1.0
## The pad's rumble on the chomp's beats (times chomp_rumble): a growl building through
## the wind-up and hold, a thump as the jaws drop and a rolling shudder as it saws.
## The landing's own impact is chomp_rumble. 0: only the landing.
@export_range(0.0, 2.0, 0.05) var chomp_cue_rumble := 0.5
## A chomp that lands, on the victim: their camera shakes chomp_cam_shake m (at
## chomp_damage_ref damage; more for more, up to twice) and kicks chomp_cam_kick
## m toward the boss; the boss and the victim freeze for chomp_hit_stop s (no
## global slow-down) as their fish squashes by chomp_squash; they're knocked
## chomp_knockback m/s from the mouth; the red vignette flushes chomp_vignette
## strong; their pad rumbles chomp_rumble (0 to 1) for chomp_rumble_time s; its
## damage number is chomp_number_scale times bigger, in red.
@export_range(0.0, 5.0, 0.05, "or_greater") var chomp_cam_shake := 0.5
@export_range(0.0, 5.0, 0.05, "or_greater") var chomp_cam_kick := 0.6
@export_range(1.0, 500.0, 1.0, "or_greater") var chomp_damage_ref := 30.0
@export_range(0.0, 0.5, 0.01, "or_greater") var chomp_hit_stop := 0.07
@export_range(0.0, 0.9, 0.05) var chomp_squash := 0.3
@export_range(0.0, 100.0, 0.5, "or_greater") var chomp_knockback := 14.0
@export_range(0.0, 4.0, 0.05, "or_greater") var chomp_vignette := 1.6
@export_range(0.0, 1.0, 0.05) var chomp_rumble := 1.0
@export_range(0.0, 2.0, 0.05, "or_greater") var chomp_rumble_time := 0.25
@export_range(1.0, 5.0, 0.05, "or_greater") var chomp_number_scale := 1.8
## A chomp that misses still clacks: players within chomp_miss_range times its
## reach of the mouth feel chomp_miss_shake of a hit's shake and rumble.
@export_range(0.0, 10.0, 0.25, "or_greater") var chomp_miss_range := 2.0
@export_range(0.0, 2.0, 0.05, "or_greater") var chomp_miss_shake := 0.35
## The grabs' impact (the Gulper's snap, the Lamprey's latch, a hagfish's
## bite), times a chomp's.
@export_range(0.0, 3.0, 0.05, "or_greater") var grab_impact := 0.8
## A zombie's lunge (or punch) landing gives a light impact: a camera tick of
## lunge_impact_shake times a chomp's, a rim flash of lunge_impact_flash, a
## knock of lunge_impact_knock m/s, a rumble of lunge_impact_rumble and a bubble
## puff; at most one per player every lunge_impact_every s (a swarm reads as a
## steady rattle, not a constant shake, and costs the same as one lunge).
@export var lunge_impact := true
@export_range(0.0, 2.0, 0.05, "or_greater") var lunge_impact_shake := 0.25
@export_range(0.0, 3.0, 0.05, "or_greater") var lunge_impact_flash := 0.35
@export_range(0.0, 30.0, 0.25, "or_greater") var lunge_impact_knock := 3.0
@export_range(0.0, 1.0, 0.05) var lunge_impact_rumble := 0.3
@export_range(0.0, 2.0, 0.01, "or_greater") var lunge_impact_every := 0.15
