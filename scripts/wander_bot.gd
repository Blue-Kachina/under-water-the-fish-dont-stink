class_name WanderBot
extends Node
## A calm, harmless fish for Nature (NatureRun): it cruises between random
## spots around `home` at an easy pace, staying upright, and never goes after
## anyone. With `skittish` on it also turns away from a fish rushing at it.
## Drives its fish through FishController.controls, like FishBot.

## How far from home (m) it picks spots to swim to, across and up/down.
const ROAM_RADIUS := 25.0
const ROAM_HEIGHT := 8.0
## Close enough to a spot (m) to pick the next.
const ARRIVED := 4.0
## Within this (m) of a fish going at least SPOOK_SPEED towards it, a skittish one turns away.
const SPOOK_RANGE := 12.0
const SPOOK_SPEED := 12.0

var fish: FishController
## The middle of where it roams.
var home := Vector3.ZERO
## Throttle while cruising, 0..1.
var pace := 0.45
## Turns away from rushing fish (off: it just swims its route).
var skittish := false
## Fish that can spook it (the player's).
var threat: FishController

var input := FishInput.new()
var _spot := Vector3.ZERO


func _ready() -> void:
	process_physics_priority = -10  # before the fish samples its controls
	fish.controls = input
	pick_spot()


## A new spot to head for, around home.
func pick_spot() -> void:
	var flat := Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * ROAM_RADIUS
	_spot = home + Vector3(flat.x, randf_range(-ROAM_HEIGHT, ROAM_HEIGHT), flat.y)


func _physics_process(_delta: float) -> void:
	input.clear()
	if not is_instance_valid(fish) or fish.battered or fish.controls_locked:
		return
	var me := fish.global_position
	if me.distance_to(_spot) < ARRIVED:
		pick_spot()
	var target := _spot
	var throttle := pace
	if skittish and is_instance_valid(threat) and not threat.battered:
		var from_threat := me - threat.global_position
		if from_threat.length() < SPOOK_RANGE and threat.linear_velocity.dot(from_threat.normalized()) > SPOOK_SPEED:
			target = me + from_threat.normalized() * 10.0
			throttle = 1.0
	_steer_to(target)
	input.forward = throttle


func _steer_to(target: Vector3) -> void:
	var basis := fish.global_basis.orthonormalized()
	var local := basis.inverse() * (target - fish.global_position)
	var yaw := atan2(local.x, -local.z)  # + = to the right
	var pitch := atan2(local.y, Vector2(local.x, local.z).length())  # + = above
	input.stick.x = clampf(yaw * 1.5, -1.0, 1.0)
	input.stick.y = clampf(pitch * 1.5, -1.0, 1.0)  # stick down lifts the nose
	input.roll = clampf(basis.x.y * 3.0, -1.0, 1.0)  # right side high: roll right, back upright
