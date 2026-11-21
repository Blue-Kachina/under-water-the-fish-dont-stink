class_name WhatStinksRumble
extends RefCounted
## What Stinks?'s pad rumble (two-stage-attack.md section 3): a pulse on the pad of the player
## playing a fish, nobody else's. The fish's own PlayerInput names its pad (split-screen: each
## player buzzes their own), a lone keyboard-and-any-pad player buzzes every pad. Puppets (a fish
## on another machine) and bots (FishController.controls) feel nothing. Headless runs and probes
## (`record`) log the call instead of vibrating, so the sync check can see it.

## Probes: log every pulse into `calls` instead of vibrating.
static var record := false
## The logged pulses: {fish, strength, seconds, tick, felt (a pad would have buzzed)}.
static var calls: Array = []


## Whether `fish` has a pad to buzz: a local player's fish, not a puppet and not a bot's.
static func felt_by(fish: FishController) -> bool:
	return is_instance_valid(fish) and not fish.puppet and fish.controls == null


## `fish`'s pad rumbles `strength` (0 to 1+; the weak motor a share of it) for `seconds`.
static func pulse(fish: FishController, strength: float, seconds: float) -> void:
	if strength <= 0.0 or seconds <= 0.0 or not is_instance_valid(fish):
		return
	var felt := felt_by(fish)
	if record:
		calls.append({"fish": fish, "strength": strength, "seconds": seconds, "tick": Engine.get_physics_frames(), "felt": felt})
		return
	if not felt or DisplayServer.get_name() == "headless":
		return
	var input: PlayerInput = fish.input_source
	var pads: Array[int] = []
	if input and input.device >= 0:
		pads.append(input.device)
	else:
		pads = Input.get_connected_joypads()
	for pad in pads:
		Input.start_joy_vibration(pad, clampf(strength * 0.6, 0.0, 1.0), clampf(strength, 0.0, 1.0), seconds)


static func reset() -> void:
	record = false
	calls.clear()
