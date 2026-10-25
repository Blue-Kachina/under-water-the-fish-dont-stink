class_name BellPulse
extends RefCounted
## A jellyfish bell's pulsation (JellyModel; FishModel steps it each frame and
## hands it to the jelly's shaders, jelly_pulse.gdshaderinc).
##
## The bell's shape is one signed number: +1 contracted (the power stroke's
## tall, narrow dome, its rim drawn down and in), 0 its rest shape, -1 expanded
## (the recovery stroke's wide, flat umbrella, its rim flaring out). The crown
## and the margin each chase that `target` on their own spring, so the edge
## bends and ripples rather than the whole bell scaling: contracting, the
## margin's ring muscles lead and the crown follows; expanding, the crown's
## elastic jelly springs back first and the margin follows, overshooting into
## a flare that settles (Gait.bell_ripple).
##
## Under Gait.Visual.BELL_PULSE strides drive it (step_strides). Each new stride
## is a power stroke (a quick contraction by its peak) or, under
## Gait.BellRhythm.ALTERNATE when the bell is already shut, a recovery stroke (a
## slower expansion). Between strides the bell relaxes open on its own, then
## glides at rest with a faint idle beat. Without a gait (school fish, the
## home screen, replays, gaits off) it beats on its own with the swim (step_free).

## The rest shape's value: a touch open, as a gliding jelly hangs.
const REST := -0.1
## The idle beat while it glides (of a full pulse), and its period (s).
const IDLE_BEAT := 0.15
const IDLE_PERIOD := 2.6
## Past these the springs' overshoot is cut off.
const MOST_SHUT := 1.3
const MOST_OPEN := -1.5

enum Ease { POWER, RECOVER, RELAX }

## The shape now: the crown's and the margin's (as `target`), and how hard the
## margin is rippling (0..1) and where its ripple wave is (rad).
var crown := REST
var margin := REST
var ripple := 0.0
var ripple_phase := 0.0
## Where the springs are headed.
var target := REST
## Whether the last stride was a power stroke (false: a recovery stroke).
var last_power := false
## Strides seen, and how many were power strokes.
var strides := 0
var power_strokes := 0

var _crown_speed := 0.0
var _margin_speed := 0.0
var _last_target := REST
var _shutting := false  # which way the target last moved
var _last_phase := -1.0
var _idle := 0.0
var _beat_phase := 0.0
# Queued segments, each {to, time, ease}; the first plays from _seg_from.
var _segments: Array[Dictionary] = []
var _seg_from := REST
var _seg_t := 0.0


## Strides drive the bell. `stride_phase` is the current stride's time since it
## began (SwishySwim.phase; negative with none), `peak` and `fade` its timing
## (s), `gait` the class's.
func step_strides(delta: float, stride_phase: float, peak: float, fade: float, gait: Gait) -> void:
	if stride_phase >= 0.0 and (_last_phase < 0.0 or stride_phase < _last_phase):
		_begin_stride(peak, fade, gait)
	_last_phase = stride_phase
	if _segments.is_empty():
		# Gliding: hang at rest with a faint beat, quick in, slow out.
		_idle = fmod(_idle + delta / IDLE_PERIOD, 1.0)
		target = REST + IDLE_BEAT * _beat(_idle)
	else:
		_play(delta)
	_springs(delta, gait.bell_ripple)


## Beats on its own with the swim: `rate` (pulses a second) and `effort` (0..1)
## from how fast it swims.
func step_free(delta: float, rate: float, effort: float) -> void:
	_beat_phase = fmod(_beat_phase + delta * rate, 1.0)
	target = REST + lerpf(0.55, 1.0, effort) * _beat(_beat_phase)
	_springs(delta, 1.0)


## One pulse along `x` (0..1): a quick squeeze to 1 over the first 30%, then a
## slow relax that opens past rest (to -0.6) and eases back.
static func _beat(x: float) -> float:
	if x < 0.3:
		return lerpf(-0.6, 1.0, smoothstep(0.0, 0.3, x))
	var t := (x - 0.3) / 0.7
	return lerpf(1.0, -0.6, 1.0 - pow(1.0 - t, 2.0))


func _begin_stride(peak: float, fade: float, gait: Gait) -> void:
	strides += 1
	peak = maxf(peak, 0.02)
	fade = maxf(fade, 0.02)
	var power := gait.bell_rhythm == Gait.BellRhythm.EACH_STRIDE or crown < 0.35
	last_power = power
	_segments.clear()
	_seg_from = target
	_seg_t = 0.0
	if not power:
		# Recovery stroke: the bell spreads open, slower than it shut, and
		# hangs there to glide before easing back to rest.
		_segments.append({"to": -1.0, "time": peak * 0.85, "ease": Ease.RECOVER})
		_segments.append({"to": -1.0, "time": fade * 0.5, "ease": Ease.RELAX})
		_segments.append({"to": REST, "time": 1.4, "ease": Ease.RELAX})
		return
	power_strokes += 1
	if gait.bell_rhythm == Gait.BellRhythm.EACH_STRIDE:
		# A whole pulse in one stride: shut by halfway to the peak, open again
		# over the rest of it and the fade.
		_segments.append({"to": 1.0, "time": peak * 0.5, "ease": Ease.POWER})
		_segments.append({"to": -1.0, "time": peak * 0.5 + fade, "ease": Ease.RECOVER})
		_segments.append({"to": REST, "time": 1.2, "ease": Ease.RELAX})
		return
	# Power stroke: shut early (well before the peak, quicker than any
	# recovery) and hold while the push fades, waiting for
	# the recovery stroke; with none, relax open on its own and glide.
	_segments.append({"to": 1.0, "time": peak * 0.5, "ease": Ease.POWER})
	_segments.append({"to": 1.0, "time": peak * 0.5 + fade * 0.4, "ease": Ease.RELAX})
	_segments.append({"to": -0.8, "time": gait.bell_recovery_time, "ease": Ease.RECOVER})
	_segments.append({"to": REST, "time": 1.2, "ease": Ease.RELAX})


func _play(delta: float) -> void:
	_seg_t += delta
	while not _segments.is_empty():
		var segment: Dictionary = _segments[0]
		var time: float = segment["time"]
		var to: float = segment["to"]
		if _seg_t < time:
			var x := _seg_t / time
			var eased: float
			match int(segment["ease"]):
				Ease.POWER:
					eased = x * x * (3.0 - 2.0 * x)
				Ease.RECOVER:
					eased = 0.5 - 0.5 * cos(PI * x)  # elastic, unhurried
				_:
					eased = smoothstep(0.0, 1.0, x)
			target = lerpf(_seg_from, to, eased)
			return
		_seg_t -= time
		_seg_from = to
		target = to
		_segments.pop_front()
	_seg_t = 0.0


## The crown and the margin chase `target`; `lag` (Gait.bell_ripple) is how far
## the margin trails the crown while opening, and how much it overshoots.
## Shutting, the margin chases the target ahead of the crown; opening, it chases
## the crown on a looser spring, so it trails it and then flares past.
func _springs(delta: float, lag: float) -> void:
	if delta <= 0.0:
		return
	var steps := ceili(delta / (1.0 / 120.0))
	var dt := delta / steps
	var bend := clampf(lag, 0.0, 3.0)
	var lead := minf(bend, 1.0)
	if target > _last_target + 1e-5:
		_shutting = true
	elif target < _last_target - 1e-5:
		_shutting = false
	_last_target = target
	for i in steps:
		var crown_rate := 30.0 if _shutting else 20.0
		var margin_rate := lerpf(crown_rate, 40.0, lead) if _shutting else crown_rate / (1.0 + 0.6 * bend)
		var margin_damping := 0.9 if _shutting else lerpf(1.0, 0.35, lead) / (1.0 + 0.3 * maxf(bend - 1.0, 0.0))
		var margin_goal := target if _shutting else lerpf(target, crown, lead)
		_crown_speed += (crown_rate * crown_rate * (target - crown) - 2.0 * crown_rate * _crown_speed) * dt
		crown = clampf(crown + _crown_speed * dt, MOST_OPEN, MOST_SHUT)
		_margin_speed += (margin_rate * margin_rate * (margin_goal - margin) - 2.0 * margin_damping * margin_rate * _margin_speed) * dt
		margin = clampf(margin + _margin_speed * dt, MOST_OPEN, MOST_SHUT)
	ripple = clampf(absf(_margin_speed) / 8.0, 0.0, 1.0) * minf(bend, 1.5)
	ripple_phase = fmod(ripple_phase + delta * (6.0 + 10.0 * ripple), TAU * 100.0)
