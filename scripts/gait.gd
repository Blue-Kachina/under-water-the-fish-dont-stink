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
enum StrokeAxis { LATERAL, FLAP }
## What a stride pushes along. NOSE: where the fish faces.
enum PushAxis { NOSE }
## What a stride does on a surface. NONE: nothing (strides only push in open water).
enum SurfaceMode { NONE }
## What the model plays for a stride. TAIL_BEND: the tail sweeps across and back.
## FLAP: the side flaps (fin pivots) beat down with the push and lift back up.
enum Visual { TAIL_BEND, FLAP }

## Which way a stride's side kick and the body's bend go. Lateral: away from
## the stick's sweep, as fish swim. Flap: up, as a wingbeat lifts.
@export var stroke_axis := StrokeAxis.LATERAL
## What a stride pushes along. Nose: where the fish faces.
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
## back. Flap: the side flaps beat down with the push.
@export var visual := Visual.TAIL_BEND


## Whether this gait changes nothing (today's fish).
func is_default() -> bool:
	return stroke_axis == StrokeAxis.LATERAL and push_axis == PushAxis.NOSE and stroke_time == 1.0 \
			and stroke_power == 1.0 and coast_drag == 1.0 and coast_buoyancy == 0.0 \
			and surface_mode == SurfaceMode.NONE and visual == Visual.TAIL_BEND
