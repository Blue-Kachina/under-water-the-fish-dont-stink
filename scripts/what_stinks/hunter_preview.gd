class_name HunterPreview
extends Node3D
## A Hunter form swimming in place for the card's showcase (HomeScreen.FishShowcase.show_form): the form's own
## FishController dressed exactly as a match dresses it (look, HunterSize at 1x, the form's dress hook), then driven
## the way the match drives it, so the gait is the real one (FishController._process: swim phase, tail, fins, the
## model's react / Titan swim; the rigs' trail, wave and bite pose) and a change to a form shows here too:
##   - it really swims: a gentle synthetic throttle (input_forward, linear_velocity along its heading) and a
##     wandering yaw and pitch (angular_velocity set to match), moved in _physics_process as a match moves a fish,
##     so get_global_transform_interpolated (what the spine rigs follow) is smooth at any frame rate;
##   - the camera follows (focus()), so it stays "in place" on screen while the world slides past, with a heading
##     it takes slowly (camera_heading()), so the fish's own wander shows against it;
##   - the body is pre-rolled once at show time (a rig's trail needs a body-length of swimming behind the head before
##     the tail has anything to follow; empty, the tail is a straight stub that snaps at every new trail point).
## Cheap: one frozen controller, no collision (layers 0), and nothing runs while the showcase is hidden.
## Every value is a WhatStinksSettings value (preview_*), with these as the defaults until the panel has them.

## Share of full throttle, and the speed at full throttle as a share of the body's length per second.
const THROTTLE := 0.75
const SPEED_PER_LENGTH := 0.32
## The yaw and pitch wander (rad) and how fast it goes (rad/s of the slowest wave): gentle S-curves and bobs.
const YAW_WANDER := 0.42
const PITCH_WANDER := 0.10
const WANDER_RATE := 0.34
## The camera's slow orbit round the fish (rad/s), on top of its own heading.
const ORBIT_RATE := 0.22
## Seconds the camera takes to settle on the fish's heading.
const HEADING_EASE := 3.0
## Pre-roll step (s) and the body lengths of trail it lays (a rig keeps length + 4 m).
const PREROLL_STEP := 1.0 / 30.0
## Past this far from the origin everything is carried back (float precision for the shader's world positions).
const RECENTER_AT := 300.0

var key := ""
var fish: FishController
## The body's length now (m), for the camera.
var length := 1.0
var throttle := THROTTLE
var speed := 1.0
var _t := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _heading := 0.0
var _bodies: Array[Node] = []


## Dresses a fresh controller as form `form_key` (a HunterForms key) and starts it swimming.
func setup(form_key: String) -> void:
	key = form_key
	var form := HunterForms.sheet(form_key)
	fish = load("res://scenes/fish.tscn").instantiate()
	fish.set("controls", null)
	fish.set("freeze", true)
	fish.collision_layer = 0
	fish.collision_mask = 0
	add_child(fish)
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.new().apply(fish, form)  # a fresh one: 1x, not the size picked for the match
	HunterForms.dress(fish, form_key)
	length = maxf(fish.hitbox_length, 1.0)
	_read_settings()
	_bodies = _find_bodies()
	_preroll()


func _read_settings() -> void:
	var settings := WhatStinksSettings.shared()
	throttle = _setting(settings, "preview_throttle", THROTTLE)
	speed = length * SPEED_PER_LENGTH * _setting(settings, "preview_speed", 1.0) * throttle


static func _setting(settings: Object, id: String, fallback: float) -> float:
	var value: Variant = settings.get(id)
	return float(value) if value != null else fallback


## The point the camera looks at (the fish, as it is drawn this frame).
func focus() -> Vector3:
	if not is_instance_valid(fish):
		return Vector3.ZERO
	return fish.get_global_transform_interpolated().origin


## The yaw the camera takes (rad): the fish's heading, slowly, so its wander reads against it.
func camera_heading() -> float:
	return _heading


func _physics_process(delta: float) -> void:
	if not is_instance_valid(fish) or not is_visible_in_tree():
		return
	_step(delta)


## One tick of the swim: the wander, then the fish moved along its heading with the throttle and velocities a match would show.
func _step(delta: float) -> void:
	var settings := WhatStinksSettings.shared()
	var wander := _setting(settings, "preview_wander", 1.0)
	_t += delta
	var rate := WANDER_RATE
	var yaw_amp := YAW_WANDER * wander
	var pitch_amp := PITCH_WANDER * wander
	_yaw = yaw_amp * (sin(_t * rate) + 0.45 * sin(_t * rate * 2.37 + 1.3))
	var yaw_rate := yaw_amp * rate * (cos(_t * rate) + 0.45 * 2.37 * cos(_t * rate * 2.37 + 1.3))
	_pitch = pitch_amp * sin(_t * rate * 0.83 + 0.5)
	var pitch_rate := pitch_amp * rate * 0.83 * cos(_t * rate * 0.83 + 0.5)
	var basis := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var forward := -basis.z
	var origin := fish.global_position + forward * speed * delta
	fish.global_transform = Transform3D(basis, origin)
	fish.linear_velocity = forward * speed
	fish.angular_velocity = Vector3.UP * yaw_rate + basis.x * pitch_rate
	fish.input_forward = throttle
	_heading = lerp_angle(_heading, _yaw, 1.0 - exp(-delta / HEADING_EASE))
	if origin.length_squared() > RECENTER_AT * RECENTER_AT:
		_recenter(origin)


## Everything carried back by `by` (the spine rigs' trails with it, or they would stretch back to where they were).
func _recenter(by: Vector3) -> void:
	fish.global_position -= by
	fish.reset_physics_interpolation()
	for node in _bodies:
		var trail: Variant = node.get("_trail")
		if trail is PackedVector3Array:
			var moved := PackedVector3Array()
			for p in (trail as PackedVector3Array):
				moved.append(p - by)
			node.set("_trail", moved)
	for node in _bodies:
		node.call("_process", 0.0)


## The nodes under the fish that follow its head along a trail (the King's, the Lamprey's, ... rigs).
func _find_bodies() -> Array[Node]:
	var out: Array[Node] = []
	for node in fish.find_children("*", "Node3D", true, false):
		if node.get("rig") is SpineRig and node.has_method("_process"):
			out.append(node)
	return out


## The swim up to now laid behind the head: the fish stepped back through a body's worth of swimming (and a bit), each
## step run through the trail rigs, then on to the start (so the first drawn frame already has its body).
func _preroll() -> void:
	if _bodies.is_empty():
		return
	var steps := ceili((length + 6.0) / maxf(speed * PREROLL_STEP, 0.001))
	steps = clampi(steps, 8, 600)
	# Start the tape `steps` back and play it forward: the same _step the physics tick runs, on a fake clock.
	_t = -float(steps) * PREROLL_STEP
	var start := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	fish.global_transform = start
	fish.reset_physics_interpolation()
	for node in _bodies:
		node.set("_trail", PackedVector3Array())
	for i in steps:
		_step(PREROLL_STEP)
		fish.reset_physics_interpolation()  # the interpolated transform is the current one: no tick has passed
		for node in _bodies:
			node.call("_process", PREROLL_STEP)
