class_name Gait
extends Resource
## How a class's strides move its body and how they look (big_changes.md §6).
## Every class strides with the same controls (sweep the stick, chain at the
## peak, SwishySwim); its gait sits on top of the fish's stride tuning and
## changes what a stride does with the body. One per class, kept in
## GaitSettings, which the tuning panel's GAITS section edits.
##
## The defaults are today's fish: a lateral tail stroke pushing along the nose,
## at the fish's own stride timing and drag. A gait left at its defaults changes
## nothing (gait_probe checks this).
##
## The enums only list what's built. Later phases add values at the end (the
## whales' vertical stroke, the jellies' bell push, crawling on a surface...),
## and a value is stored by its index, so they're never reordered. The panel
## shows an enum once it has more than one value (GaitSettings).

## Which way a stride's side kick and the body's bend go. LATERAL: away from the
## stick's sweep, the tail bending across it (every fish today). FLAP: up, as
## a wingbeat lifts (the sea hare's parapodia), whichever way the stick swept.
## VERTICAL: up and down, as a whale's flukes beat (the Breachers): an up or
## down sweep kicks the way the stick went, a sideways one alternates up, down.
## RADIAL: none, the push is even all round (a jelly's bell squeezing).
enum StrokeAxis { LATERAL, FLAP, VERTICAL, RADIAL }
## What a stride pushes along. NOSE: where the fish faces. BELL: along the
## bell's axis, which stands upright at rest and leans toward the nose as it
## swims (bell_lean_max, FishController.bell_lean): the Drifters.
enum PushAxis { NOSE, BELL }
## What a stride does on a surface. NONE: nothing (strides only push in open water).
enum SurfaceMode { NONE }
## What the model plays for a stride. TAIL_BEND: the tail sweeps across and back.
## FLAP: the side flaps (fin pivots) beat down with the push and lift back up.
## FLUKE: the tail beats up and down (the body bends in its vertical plane),
## opposite to the stroke's kick, whichever way the stick swept.
## BELL_PULSE: strides contract and expand the bell (BellPulse, bell_rhythm),
## the tail pivot (oral arms) trailing rather than beating, and the model leans
## with the bell's axis (PushAxis.BELL).
enum Visual { TAIL_BEND, FLAP, FLUKE, BELL_PULSE }
## Bell pulse only: how strides drive the bell (BellPulse). ALTERNATE: strides
## take turns, one the power stroke (a quick contraction), the next the
## recovery stroke (a slower expansion). EACH_STRIDE: every stride is a whole
## pulse, contracting by its peak and re-opening as it fades.
enum BellRhythm { ALTERNATE, EACH_STRIDE }

## Which way a stride's side kick and the body's bend go. Lateral: away from
## the stick's sweep, as fish swim. Flap: up, as a wingbeat lifts. Vertical: up
## and down, as a whale's flukes beat. Radial: no kick, an even squeeze.
@export var stroke_axis := StrokeAxis.LATERAL
## What a stride pushes along. Nose: where the fish faces. Bell: along the
## bell, upright at rest and leaning toward the nose as it swims.
@export var push_axis := PushAxis.NOSE
## How long this class's strides take, times the fish's stride peak and fade
## times. Above 1: slow, heavy strokes. Below 1: fast flicks. The sweet spot
## moves with it.
@export_range(0.1, 4.0, 0.05, "or_greater") var stroke_time := 1.0
## How hard this class's strides push, times the fish's stride force.
@export_range(0.0, 4.0, 0.05, "or_greater") var stroke_power := 1.0
## The water's drag between strides, times the fish's linear drag. Above 1: it
## slows down when it stops stroking (a jelly). Below 1: it coasts on (a ray).
## 0: no drag while coasting.
@export_range(0.0, 10.0, 0.05, "or_greater") var coast_drag := 1.0
## Extra lift between strides (m/s², on top of the fish's buoyancy). Negative
## sinks it while it isn't stroking, positive floats it up.
@export_range(-20.0, 20.0, 0.1, "or_greater", "or_less") var coast_buoyancy := 0.0
## What a stride does on a surface. None: nothing; strides only push in open water.
@export var surface_mode := SurfaceMode.NONE
## The model's animation for each stride. Tail bend: the tail sweeps across and
## back. Flap: the side flaps beat down with the push. Fluke: the tail beats up
## and down. Bell pulse: the bell contracts and expands with strides (no tail
## beat) and leans as it swims.
@export var visual := Visual.TAIL_BEND
## Bell push only: how far the bell leans from upright toward the nose when
## swimming flat out (degrees). 90: level, nose-first; 0: always upright.
@export_range(0.0, 90.0, 1.0) var bell_lean_max := 75.0
## Bell push only: the speed (m/s) at which a coasting bell is fully leaned.
## Holding the throttle or striding leans it fully whatever the speed.
@export_range(0.5, 40.0, 0.5, "or_greater") var bell_full_speed := 6.0
## Bell push only: how quickly the bell leans to where it's heading (1/s).
@export_range(0.1, 30.0, 0.1, "or_greater") var bell_lean_rate := 4.0
## Bell pulse only: how strides drive the bell. Alternate: one stride contracts
## it (power stroke), the next expands it (recovery stroke). Each stride: every
## stride contracts it and lets it re-open.
@export var bell_rhythm := BellRhythm.ALTERNATE
## Bell pulse only: how hard the power stroke squeezes the bell into a tall,
## narrow dome. 0: it doesn't contract.
@export_range(0.0, 3.0, 0.05, "or_greater") var bell_squeeze := 1.0
## Bell pulse only: how wide and flat the recovery stroke spreads the bell,
## its rim flaring out like an umbrella. 0: it doesn't open past its rest shape.
@export_range(0.0, 3.0, 0.05, "or_greater") var bell_flatten := 1.0
## Bell pulse only: how much the bell's margin lags its crown and ripples, so
## the edge bends rather than the whole bell scaling. 0: the bell moves as one.
@export_range(0.0, 3.0, 0.05, "or_greater") var bell_ripple := 1.0
## Bell pulse only: how long the bell takes to relax open on its own after a
## power stroke that no recovery stroke follows (s).
@export_range(0.1, 5.0, 0.05, "or_greater") var bell_recovery_time := 0.9
## Titans only (the adult whales' models): how much bigger each fluke beat is
## than the swim's own, so a big tail moves a lot of water. 1: as the swim sets it.
@export_range(0.0, 3.0, 0.05, "or_greater") var fluke_amplitude := 1.3
## Titans only: how many times slower the up-stroke (recovery) is than the
## down-stroke (power). 1: the same speed both ways.
@export_range(1.0, 6.0, 0.05, "or_greater") var fluke_power_ratio := 2.2
## Titans only: how quickly the flukes follow the swim's beat on the power
## stroke (1/s; the recovery follows fluke_power_ratio times slower). Lower: a
## softer, rounder beat that doesn't reach as far.
@export_range(1.0, 60.0, 0.5, "or_greater") var fluke_snap := 14.0
## Titans only: how many joints the body bends at behind its middle, so each
## beat travels down it as a wave (1: one even curve, as the other fish).
@export_range(1, 3, 1) var bend_segments := 3
## Titans only: how long the beat takes to pass from each joint to the one
## behind it (s): the wave's travel down the body. Longer: a lazier, more
## whip-like beat. 0: the whole body bends at once.
@export_range(0.0, 0.5, 0.005, "or_greater") var bend_lag := 0.12
## Titans only: how much the head pitches against each beat, of the body's
## bend (the nose lifts as the flukes drive down). 0: the head stays still.
@export_range(0.0, 1.0, 0.01) var head_counter := 0.25
## Titans only: how far the whole body surges forward on a power stroke and
## eases back, of its length.
@export_range(0.0, 0.1, 0.001, "or_greater") var body_surge := 0.012
## Titans only: how far the flippers trim against the beat and bank in turns
## (0: they hold still, besides the swim's own flutter).
@export_range(0.0, 3.0, 0.05, "or_greater") var flipper_trim := 1.0
## Titans only: how far the body rolls into a turn at full turn (rad).
@export_range(0.0, 1.2, 0.01) var turn_bank := 0.25
## Titans only: the fluke speed (rad/s) that counts as a full-strength power
## stroke (FishModel.power_stroke's strength 1; the wake, FX and sound scale
## with it).
@export_range(0.1, 20.0, 0.1, "or_greater") var power_stroke_speed := 3.0


## Whether this gait changes nothing (today's fish).
func is_default() -> bool:
	return stroke_axis == StrokeAxis.LATERAL and push_axis == PushAxis.NOSE and stroke_time == 1.0 \
			and stroke_power == 1.0 and coast_drag == 1.0 and coast_buoyancy == 0.0 \
			and surface_mode == SurfaceMode.NONE and visual == Visual.TAIL_BEND


# --- The procedural rig (SwimRig, planning_core_roadmap.md 2.2/2.3) ---------------
# Only the Hunter class's shark has one so far. Every number is a field here so the
# GAITS panel tunes it live. A layer with weight 0 adds nothing.

## Shark only: animate the body with the procedural SwimRig (layers that read how
## the fish is moving) instead of the controller's tail pose. Off: the pose as it
## always was. With every layer weight at 0 and rig_legacy_tail at 1 the rig
## poses exactly as the old pose does.
@export var procedural_rig := false
## Rig: how much of the controller's own tail pose (its swim stroke and stride swing) is kept. 1: all of it (the old
## pose). 0: none, the layers move the tail.
@export_range(0.0, 2.0, 0.05, "or_greater") var rig_legacy_tail := 1.0
## Rig: how far in front of the bend the head bends the other way, as a fraction of the body's length. 0: the head
## is rigid.
@export_range(0.0, 0.6, 0.01, "or_greater") var rig_head_span := 0.3

## Rig, Undulation layer: its weight (0 off). A travelling wave runs down the spine, deeper with effort, quicker with
## speed, growing toward the tail.
@export_range(0.0, 2.0, 0.05, "or_greater") var rig_undulation := 0.0
## Rig, Undulation: the wave's biggest total turn of the spine (rad) at full effort.
@export_range(0.0, 3.0, 0.01, "or_greater") var rig_amplitude := 0.6
## Rig, Undulation: how far behind each joint's beat is the one in front (rad of wave phase). More: a longer, lazier
## wave. 0: the whole spine swings as one.
@export_range(0.0, 3.2, 0.05, "or_greater") var rig_wave_lag := 1.0
## Rig, Undulation: the Strouhal number: wave rate = this x speed / the tail's reach. More: a faster wave at any speed.
@export_range(0.01, 2.0, 0.01, "or_greater") var rig_strouhal := 0.04
## Rig, Undulation: the slowest the wave beats (Hz), at rest or crawling.
@export_range(0.0, 10.0, 0.05, "or_greater") var rig_freq_min := 0.5
## Rig, Undulation: the fastest the wave beats (Hz).
@export_range(0.1, 20.0, 0.1, "or_greater") var rig_freq_max := 3.5
## Rig, Undulation: how much of its top speed's wave a coasting fish keeps (0: it stops waving when the throttle is
## off, 1: it waves as hard as its speed says).
@export_range(0.0, 1.0, 0.05, "or_greater") var rig_coast_wave := 0.5
## Rig, Undulation: how much of the wave's size sits at the tail. 1: the joints beat 1 : 4 : 9 (the tail most). 0: the
## three alike.
@export_range(0.0, 2.0, 0.05, "or_greater") var rig_envelope := 1.0
## Rig, Undulation: how far the head swings against the body's wave, of the wave's size.
@export_range(0.0, 2.0, 0.05, "or_greater") var rig_head_sway := 0.25
## Rig, Undulation: how far the caudal fin flexes past the end of the spine, of the wave's size.
@export_range(0.0, 3.0, 0.05, "or_greater") var rig_caudal_flex := 0.5
## Rig, Undulation: how many degrees the caudal fin's flex runs ahead of the spine's own wave (the fin bends before the
## stalk does).
@export_range(0.0, 90.0, 1.0, "or_greater") var rig_caudal_lead := 8.0
## Rig, Undulation: how much a stride's power deepens the wave (0: not at all), so a stride's timing shows on the
## whole body.
@export_range(0.0, 3.0, 0.05, "or_greater") var rig_cue_amp := 0.5
## Rig: how quickly the layers' own smoothed values (the wave's size and rate) follow their targets (1/s).
@export_range(0.5, 60.0, 0.5, "or_greater") var rig_ease := 5.0

## Rig, TailDrive layer: its weight (0 off). A stride's swing (SwishySwim.tail_swing) drives the caudal fin at once, and
## the bend is carried forward up the body behind it, each joint a moment later than the one behind.
@export_range(0.0, 2.0, 0.05, "or_greater") var rig_tail_drive := 0.0
## Rig, TailDrive: how far a full stride swings the tail (rad), across and up/down.
@export_range(0.0, 3.0, 0.01, "or_greater") var rig_stride_swing := 0.6
## Rig, TailDrive: how quickly the caudal fin follows the swing (1/s).
@export_range(1.0, 120.0, 0.5, "or_greater") var rig_tail_snap := 40.0
## Rig, TailDrive: how quickly each joint follows the one behind it (1/s). Lower: a lazier, more whip-like carry up the
## body.
@export_range(1.0, 120.0, 0.5, "or_greater") var rig_stride_follow := 14.0

## Rig, Turn layer: its weight (0 off). The spine bends into a turn by the turn's curvature (yaw rate over speed), the
## body banks into it, the pectorals bank first and the inside one tucks while the outside one reaches out.
@export_range(0.0, 2.0, 0.05, "or_greater") var rig_turn := 0.0
## Rig, Turn: how much the spine bends into a turn, times the turn's own curvature over its length. 1: as much as the
## path curves; more: a more dramatic curl.
@export_range(0.0, 10.0, 0.1, "or_greater") var rig_turn_bend := 6.0
## Rig, Turn: the most the spine curls into a turn (rad, all joints together).
@export_range(0.0, 3.0, 0.01, "or_greater") var rig_turn_max := 0.9
## Rig, Turn: the yaw rate (rad/s) that counts as a full turn for the bank and the pectorals.
@export_range(0.1, 10.0, 0.05, "or_greater") var rig_turn_ref := 1.5
## Rig, Turn: the speed (m/s) below which a turn's curvature is worked out as if the fish were going this fast, so a
## fish turning on the spot doesn't curl without limit; the bank also fades in over twice this.
@export_range(0.1, 20.0, 0.1, "or_greater") var rig_turn_min_speed := 3.0
## Rig, Turn: how far the body rolls into a full turn (rad).
@export_range(0.0, 1.5, 0.01, "or_greater") var rig_bank := 0.35
## Rig, Turn: how quickly the spine's curl and the bank follow the turn (1/s).
@export_range(0.5, 60.0, 0.5, "or_greater") var rig_turn_rate := 6.0
## Rig, Turn: how far the pectorals roll into a full turn (rad), ahead of the body.
@export_range(0.0, 1.5, 0.01, "or_greater") var rig_fin_bank := 0.5
## Rig, Turn: how quickly the pectorals follow the turn (1/s); more than rig_turn_rate and they bank first.
@export_range(0.5, 120.0, 0.5, "or_greater") var rig_fin_rate := 18.0
## Rig, Turn: how far the inside pectoral tucks in and the outside one reaches out in a full turn (rad).
@export_range(0.0, 1.5, 0.01, "or_greater") var rig_fin_tuck := 0.4

## Rig, Accel layer: its weight (0 off). Speeding up trails the tail down and lifts the nose, folds the pectorals back
## and surges the body ahead; braking does the opposite (the tail folds up, the pectorals flare as brakes).
@export_range(0.0, 2.0, 0.05, "or_greater") var rig_accel := 0.0
## Rig, Accel: the acceleration (m/s squared, along the nose or up) that counts as full.
@export_range(1.0, 200.0, 1.0, "or_greater") var rig_accel_ref := 25.0
## Rig, Accel: how far the tail trails at full acceleration (rad of pitch at its end, + tip down when speeding up).
@export_range(0.0, 2.0, 0.01, "or_greater") var rig_accel_tail := 0.5
## Rig, Accel: how far the head lifts against the trailing tail at full acceleration (rad).
@export_range(0.0, 1.0, 0.01, "or_greater") var rig_accel_head := 0.2
## Rig, Accel: how far the pectorals fold back at full acceleration and flare at full braking (rad).
@export_range(0.0, 1.5, 0.01, "or_greater") var rig_accel_fins := 0.5
## Rig, Accel: how far the whole body surges ahead at full acceleration (of its length).
@export_range(0.0, 0.2, 0.001, "or_greater") var rig_accel_surge := 0.03
## Rig, Accel: how quickly all of that follows the acceleration (1/s).
@export_range(0.5, 60.0, 0.5, "or_greater") var rig_accel_rate := 6.0
