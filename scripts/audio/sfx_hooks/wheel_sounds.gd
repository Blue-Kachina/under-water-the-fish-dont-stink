class_name WheelSounds
extends Node
## The target wheel's sounds (planning_audio.md §3.6): a quiet tick as the
## stick moves from one slice to the next, and a lock when it closes on one.
## SfxHooks adds one to every TargetWheel.

var wheel: TargetWheel

var _was_open := false
var _picked: Node3D


func _ready() -> void:
	wheel = get_parent() as TargetWheel


func _process(_delta: float) -> void:
	var picked: Node3D = null
	if wheel.is_open and not wheel.picked.is_empty() and is_instance_valid(wheel.picked[0]):
		picked = wheel.picked[0]
	if wheel.is_open and _was_open and picked != null and picked != _picked:
		Sfx.play("nature/target_cycle")
	if _was_open and not wheel.is_open and _picked != null:
		Sfx.play("nature/target_lock")
	_was_open = wheel.is_open
	_picked = picked
