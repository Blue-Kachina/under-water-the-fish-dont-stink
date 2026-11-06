class_name NoiseMeter
extends RefCounted
## One hider's (or Fake Fish's) noise in Marco Polo (planning_marco_polo.md §2):
## `noise` runs 0..1 and dies away at noise_decay per second. Two kinds of
## loudness feed it:
## - steady, every step: from the speed over quiet_speed, up to steady_noise at
##   loud_speed, counting horizontal and upward speed only (sinking and
##   settling are silent), held as noise = max(noise, steady), so cruising
##   holds a level rather than piling up;
## - bursts, on the fish's signals: a flip, a jump or double jump, a stride
##   (louder the worse its timing), a missed beat; and add() for bumps, knocks
##   and porthole exits.
## Inside a bubble curtain (`mask_at`, the arena's bubble_mask_at) both are
## scaled down. A burst over blip_threshold pings (`pinged`), and steady
## noise over it pings every steady_ping_interval.
##
## The match steps it (step()) only while the hider's in play: a hider in a
## porthole is silent.

## A ping: where the noise was and how loud (0..1).
signal pinged(at: Vector3, loudness: float)
## Every burst (before masking): an online guest sends its own to the host.
signal burst(amount: float)

var fish: FishController
var settings: MarcoPoloSettings
## Bubble masking at a point (1: none), the arena's bubble_mask_at; unset: none.
var mask_at: Callable
var noise := 0.0
## The last steady level (0..1, before masking), for the HUD's noise ring.
var steady := 0.0
## Muted: bursts are ignored (a hider in a porthole, or out of the round).
var muted := false
var _steady_ping_left := 0.0


func _init(meter_fish: FishController, meter_settings: MarcoPoloSettings) -> void:
	fish = meter_fish
	settings = meter_settings
	fish.dodged.connect(_on_dodged)
	fish.jumped.connect(_on_jumped)
	fish.double_jumped.connect(_on_double_jumped)
	fish.strode.connect(_on_strode)
	fish.stroke_beat.connect(_on_stroke_beat)


## Lets go of the fish's signals.
func detach() -> void:
	if not is_instance_valid(fish):
		return
	for pair: Array in [[fish.dodged, _on_dodged], [fish.jumped, _on_jumped], [fish.double_jumped, _on_double_jumped],
			[fish.strode, _on_strode], [fish.stroke_beat, _on_stroke_beat]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func reset() -> void:
	noise = 0.0
	steady = 0.0
	_steady_ping_left = 0.0


## The steady noise at `velocity`: speed over quiet_speed, horizontal and up only.
func steady_at(velocity: Vector3) -> float:
	var loud := Vector2(Vector2(velocity.x, velocity.z).length(), maxf(velocity.y, 0.0)).length()
	var span := maxf(settings.loud_speed - settings.quiet_speed, 0.01)
	return settings.steady_noise * clampf((loud - settings.quiet_speed) / span, 0.0, 1.0)


## How much masking there is where the fish is (1: none).
func mask() -> float:
	if mask_at.is_valid() and is_instance_valid(fish):
		return clampf(float(mask_at.call(fish.global_position)), 0.0, 1.0)
	return 1.0


func step(delta: float) -> void:
	noise = maxf(noise - settings.noise_decay * delta, 0.0)
	if muted or not is_instance_valid(fish):
		steady = 0.0
		return
	steady = steady_at(fish.swim_velocity())  # a puppet's too
	var level := steady * mask()
	noise = maxf(noise, level)
	_steady_ping_left -= delta
	if level >= settings.blip_threshold and _steady_ping_left <= 0.0:
		_steady_ping_left = settings.steady_ping_interval
		pinged.emit(fish.global_position, level)


## A burst of `amount` (before masking): added to the noise, and a ping if it's loud enough.
func add(amount: float) -> void:
	if muted or amount <= 0.0 or not is_instance_valid(fish):
		return
	burst.emit(amount)
	var loud := amount * mask()
	noise = minf(noise + loud, 1.0)
	if loud >= settings.blip_threshold:
		pinged.emit(fish.global_position, loud)


## A stride's burst at `timing` (0..1; -1, a fresh start, counts as average).
func stride_noise(timing: float) -> float:
	var t := 0.5 if timing < 0.0 else clampf(timing, 0.0, 1.0)
	return settings.stride_noise * pow(1.0 - t, settings.stride_timing_curve)


func _on_dodged(_direction: Vector3) -> void:
	add(settings.flip_noise)


func _on_jumped() -> void:
	if fish.has_meta(PortholeSystem.JUMP_IN_META):
		return  # jumping into a porthole is quiet
	add(settings.jump_noise)


func _on_double_jumped() -> void:
	add(settings.double_jump_noise)


func _on_strode(timing: float, _flow: float) -> void:
	add(stride_noise(timing))


func _on_stroke_beat(_quality: float, missed: bool) -> void:
	if missed:
		add(settings.missed_beat_noise)
