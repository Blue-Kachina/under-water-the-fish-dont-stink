class_name FishInput
extends RefCounted
## What a fish's controls are doing, for a fish that isn't driven by the
## player's controller (FishController.controls), e.g. a bot. The same meanings
## as the controller's: the stick is after the deadzone (x = right, y = down,
## so -1 tips the nose forward), triggers 0..1, roll + = right.

var forward := 0.0
var reverse := 0.0
var stick := Vector2.ZERO
var roll := 0.0
var air_roll := false
var jump := false
var boost := false
var powerslide := false
var direction_lock := false


func clear() -> void:
	forward = 0.0
	reverse = 0.0
	stick = Vector2.ZERO
	roll = 0.0
	air_roll = false
	jump = false
	boost = false
	powerslide = false
	direction_lock = false
