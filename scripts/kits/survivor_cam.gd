class_name SurvivorCam
extends RefCounted
## The survivor cam (SurvivorCamSettings' Camera group) as a core CameraStyle (M4): the follow camera
## trailing the way a fish swims in open water, pushed onto a FollowCamera under one key. Unnatural,
## Marco Polo, What Stinks and the Obstacle Course all use it.

const KEY := &"unnatural"


## Puts the survivor cam on `camera` (a FollowCamera), or takes it off (`on` false: the usual
## chase view). Called every frame, live from the panel: camera_mode only sets the follow or free
## cam when it's put on, or when the setting changes, so the camera's own swap button sticks in
## between. `pull`: m further back on top (a run's camera_pull_of()).
static func apply(camera: Node, on: bool, from: SurvivorCamSettings, pull := 0.0) -> void:
	if not is_instance_valid(camera):
		return
	if on and from.steady_camera:
		camera.push_style(KEY, style(from, pull))
	else:
		camera.pop_style(KEY)


## The survivor cam as a CameraStyle.
static func style(from: SurvivorCamSettings, pull := 0.0) -> CameraStyle:
	var style := CameraStyle.new()
	style.view_mode = from.camera_mode
	style.follow_style = from.camera_follow
	style.swing_rate = from.camera_swing_rate
	style.settle_rate = from.camera_settle_rate
	style.settle_turning_rate = from.camera_settle_turning_rate
	style.settle_turn_full = deg_to_rad(from.camera_settle_turn)
	style.settle_smoothing = from.camera_settle_smoothing
	style.settle_delay = from.camera_settle_delay
	style.settle_max_angle = deg_to_rad(from.camera_settle_max_angle)
	style.settle_coast_rate = from.camera_settle_coast_rate
	style.settle_coast_ease = from.camera_settle_coast_ease
	style.free_turn_speed = deg_to_rad(from.free_cam_speed)
	style.free_pitch_limit = deg_to_rad(from.free_cam_pitch)
	style.free_follow_rate = from.free_cam_follow
	style.free_invert_y = from.free_cam_invert_y
	style.heading_rate = from.camera_turn_rate
	style.heading_climb = from.camera_climb
	style.extra_distance = from.camera_distance + pull
	style.extra_height = from.camera_height + pull * 0.3
	style.extra_angle = from.camera_tilt
	return style
