class_name CameraClaim
extends RefCounted
## What a mode asks of the follow camera that is not a CameraStyle (M4): a
## porthole's whole-view override, taking the ball cam button, scaling the view
## with the body, following another fish (spectating). A mode makes one,
## FollowCamera.push_claim(key, claim)s it and pop_claim(key)s it on the way
## out; changing a field after the push goes straight to the camera. The newest
## claim pushed is the one in effect. Replaces the mode setting
## camera.pose_override / button_taken / body_follow / target by name.

## Called with what the camera follows; returns the camera's whole Transform3D
## (no wall pull-in) or null to follow as usual. Empty: none.
var pose_override := Callable():
	set(value):
		pose_override = value
		_push()
## The mode reads the ball cam button itself, so the camera ignores it.
var button_taken := false:
	set(value):
		button_taken = value
		_push()
## How much of the followed fish's size the view follows (1 = in full).
var body_follow := 1.0:
	set(value):
		body_follow = value
		_push()
## Ball cam off and no target wheel while the claim is in (the claim's own view
## swaps are the mode's business).
var ball_cam := false
var wheel := false

var _camera: Node


## Called by FollowCamera.push_claim / pop_claim.
func attach(camera: Node) -> void:
	_camera = camera
	_push()


func detach() -> void:
	_camera = null


enum Snap { NONE, NOW, DEFERRED }


## Follows `subject` instead of the camera's own fish (null: back to it) and snaps
## the view to it (at once, at the end of the frame, or not at all).
func follow(subject: Node3D, snap := Snap.NOW) -> void:
	if not is_instance_valid(_camera):
		return
	_camera.set("target", subject)
	if snap == Snap.NOW:
		_camera.call("snap")
	elif snap == Snap.DEFERRED:
		_camera.call_deferred("snap")


## The survivor cam's follow view (not its free cam), e.g. where Y now watches instead.
func show_follow_cam() -> void:
	if is_instance_valid(_camera):
		_camera.set("free_cam", false)


## Writes the claim's fields onto the camera (the newest claim only).
func _push() -> void:
	if is_instance_valid(_camera) and _camera.has_method("apply_claims"):
		_camera.call("apply_claims")
