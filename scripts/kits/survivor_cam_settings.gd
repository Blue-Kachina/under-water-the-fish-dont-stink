class_name SurvivorCamSettings
extends TerrainSettings
## The survivor cam's tuning (SurvivorCam): how the follow camera trails a fish swimming in open water.

static var _fb_cam: SurvivorCamSettings


## The copy the panel edits and the kit reads (the mode's own, once it has registered).
static func shared() -> SurvivorCamSettings:
	var mode_copy = TerrainSettings.provider.call() if TerrainSettings.provider.is_valid() else null
	if mode_copy is SurvivorCamSettings:
		return mode_copy
	if _fb_cam == null:
		_fb_cam = SurvivorCamSettings.new()
	return _fb_cam


@export_group("Camera")
## The survivor cam: it follows the way the fish swims (smoothed), not its
## facing, so stride sweeps don't swing the view. Off: the usual chase camera.
@export var steady_camera := true
## Which survivor cam each player starts with; the ball cam button swaps them.
## Follow turns with the way the fish swims. Free turns only with the right
## stick, and stays where it's put.
@export_enum("Follow", "Free") var camera_mode := 0
## Follow cam's style. Settle: follows slowly while the fish turns, so you see
## it turn, and swings round behind it once it swims straight (camera_settle_*).
## Hold: holds its direction while accelerate, reverse or boost is held, and
## swings round behind once they're let go (camera_swing_rate). Always: always
## turns, at camera_turn_rate.
@export_enum("Settle", "Hold on throttle", "Always") var camera_follow := 0
## Hold: how quickly it swings round behind the fish once accelerate, reverse
## and boost are let go (1/s).
@export_range(0.2, 30.0, 0.1, "or_greater") var camera_swing_rate := 4.0
## Settle: how quickly it swings round behind the fish swimming straight, and
## while it's turning (1/s; 0: holds still while turning).
@export_range(0.1, 30.0, 0.1, "or_greater") var camera_settle_rate := 3.0
@export_range(0.0, 30.0, 0.05, "or_greater") var camera_settle_turning_rate := 0.5
## Settle: the fish's turn rate that counts as fully turning (degrees/s; lower
## and gentle curves count as turns too).
@export_range(5.0, 720.0, 5.0, "or_greater") var camera_settle_turn := 90.0
## Settle: how long the fish's turning is averaged over (s), so a stride's
## sweep one way and back cancels out; longer is calmer but slower to notice a turn.
@export_range(0.0, 3.0, 0.05, "or_greater") var camera_settle_smoothing := 0.3
## Settle: how long its swing round behind takes to build up once a turn ends
## (s; 0: at once).
@export_range(0.0, 5.0, 0.05, "or_greater") var camera_settle_delay := 0.4
## Settle: how far the fish can turn off to the side before the camera turns
## with it (degrees; 180: any way, even facing you).
@export_range(10.0, 180.0, 1.0) var camera_settle_max_angle := 75.0
## Settle: how quickly it swings round behind the fish once accelerate, reverse
## and boost are let go, turning or not (1/s; 0: no faster than swimming), and
## how long that takes to come in (s).
@export_range(0.0, 30.0, 0.1, "or_greater") var camera_settle_coast_rate := 6.0
@export_range(0.0, 2.0, 0.05, "or_greater") var camera_settle_coast_ease := 0.15
## Free cam: how fast the right stick turns it at full tilt (degrees/s), how
## far it can look up or down (degrees), and how quickly it drifts round
## behind the way the fish swims (1/s; 0: never, it stays where it's put).
@export_range(10.0, 720.0, 5.0, "or_greater") var free_cam_speed := 150.0
@export_range(0.0, 89.0, 1.0) var free_cam_pitch := 70.0
@export_range(0.0, 10.0, 0.05, "or_greater") var free_cam_follow := 0.0
## Free cam: down on the right stick looks up, as a flight sim (D11).
@export var free_cam_invert_y := true
## How quickly it turns to the way the fish swims (1/s; lower is calmer).
@export_range(0.1, 20.0, 0.1, "or_greater") var camera_turn_rate := 2.0
## How much of the fish's climb or dive it follows (0: always level).
@export_range(0.0, 1.0, 0.05) var camera_climb := 0.4
## Further back, higher and tilted further down than the tuned chase view
## (m, m, degrees), to see the horde around you.
@export_range(0.0, 40.0, 0.25, "or_greater") var camera_distance := 4.5
@export_range(0.0, 30.0, 0.25, "or_greater") var camera_height := 2.0
@export_range(-60.0, 30.0, 0.5) var camera_tilt := -10.0
