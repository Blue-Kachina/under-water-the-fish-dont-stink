class_name CameraStyle
extends Resource
## How a mode wants the chase camera to behave (M4, planning_core_roadmap.md):
## a bundle of FollowCamera's steady-heading tuning that a mode pushes with
## FollowCamera.push_style(key, style) and takes off with pop_style(key). The
## newest pushed style wins; with none pushed the camera is the plain chase
## view (it turns straight with the fish's nose).
##
## A steady style turns the view by its own smoothed heading instead of the
## nose, so stride sweeps don't swing it. Its follow_style is one of
## FollowCamera.FOLLOW_SETTLE (follows slowly while the fish turns, swings
## round behind it once it swims straight), FOLLOW_HOLD or FOLLOW_ALWAYS.
## Values are plain units (angles in radians), as the camera reads them.

## Off: a style that only moves the camera back and up (extra_*), nose-following.
@export var steady := true
## -1: leave the follow / free swap as it is; 0: follow cam; 1: free cam. Applied
## when the style is first pushed or this value changes, so the view's own swap
## button sticks in between.
@export var view_mode := 0
## Whether the ball cam button swaps follow and free cam (the survivor cam). Off:
## the button does what it always did there (ball cam, or a target wheel).
@export var button_swaps_view := true
@export var follow_style := 0
@export var swing_rate := 4.0
## Settle (the numbers behind FollowCamera's settle_* fields).
@export var settle_rate := 3.0
@export var settle_turning_rate := 0.5
@export var settle_turn_full := 1.5707964  # 90 degrees
@export var settle_smoothing := 0.3
@export var settle_delay := 0.4
@export var settle_max_angle := 1.3089969  # 75 degrees
@export var settle_coast_rate := 6.0
@export var settle_coast_ease := 0.15
## Free cam.
@export var free_turn_speed := 2.6179939  # 150 degrees/s
@export var free_pitch_limit := 1.2217305  # 70 degrees
@export var free_follow_rate := 0.0
@export var free_invert_y := true
## Heading: how fast the always style turns (1/s), and how much of the nose's
## climb it follows.
@export var heading_rate := 2.0
@export var heading_climb := 0.4
## Further back (m), higher (m) and more tilted (radians) than the tuned view.
@export var extra_distance := 0.0
@export var extra_height := 0.0
@export var extra_angle := 0.0


## The settle style at the survivor cam's numbers, no extra distance and no view swap:
## what a swim mode with the plain chase view picks (Nature's camera_settle).
static func settle() -> CameraStyle:
	var style := CameraStyle.new()
	style.button_swaps_view = false
	return style
