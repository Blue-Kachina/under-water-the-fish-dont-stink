class_name SwishySwim
extends RefCounted
## Extra Swishy swimming (FishController.SwimStyle.EXTRA_SWISHY): the left
## stick is the tail, and sweeping it from one side to the opposite side is a
## stride, like a skater pushing off alternate blades. Any direction counts:
## left/right, up/down or diagonal, as long as each stride sweeps back across
## the middle to roughly the opposite side. Circling the stick doesn't cross the
## middle, so it doesn't stride. With stride_needs_throttle, sweeps only stride
## while the throttle's held; otherwise the stick just steers, as normal.
##
## Each stride pushes through the water along an envelope: its power builds to a
## peak (stride_peak_time), then fades to nothing (stride_fade_time). The push
## is mostly forward with a little sideways away from the sweep, so alternate
## strides weave forward and the sideways parts cancel. Starting the next stride
## cuts the last one off, and how strong the last one was at that moment is the
## new stride's timing (0..1):
## - too early, and it hadn't built up yet;
## - too late, and it had already faded, in proportion to the time since its peak.
## Good timing builds flow, which multiplies every stride's push (up to
## 1 + stride_flow_max); poor timing bleeds flow away. Mashing restarts each
## stride before it builds, so it pushes very little and drains flow.
##
## Tuning lives on the fish (its "Extra Swishy" exports), so the tuning panel
## and presets cover it, and its class's Gait (FishController.gait) shapes it:
## the stride's timing and power, and which way it pushes and kicks. The fish
## calls sample() as it samples input and apply() while swimming off a surface.

## Power from which a stride counts as near its peak (sweetness(), the cues).
const SWEET_SPOT := 0.85

var fish: FishController
## The current stride's power, 0..1 (its envelope now).
var power := 0.0
## Seconds since the current stride began; negative when there's none.
var phase := -1.0
## The compounding multiplier above 1 from well-timed strides (0..stride_flow_max).
var flow := 0.0
## The last stride's timing, 0..1, or -1 if it started fresh (nothing before it).
var last_timing := -1.0
## Whether the last stride began before the one it followed had peaked.
var last_early := false
## Strides in the current chain (since the last fresh start).
var strides := 0
## The current stride's push multiplier from flow and timing (reach_scale() on top).
var strength := 0.0
## The stick as it steers: smoothed over stride_steer_smoothing.
var steer := Vector2.ZERO
## Where the tail is, in the stick's terms (x right, y down), -1..1 each way:
## a stride sweeps it from wherever it was to the side opposite the push,
## arriving at the peak, and it relaxes back to the middle as the stride fades.
var tail_swing := Vector2.ZERO
var _tail_from := Vector2.ZERO

var _dir := Vector2.ZERO  # the current stride's sweep direction (unit stick vector)
var _reach := 0.0  # how far the stick has reached along the current stride's direction
var _crossed := true  # the stick has come back through the middle since the last stride began
var _last_dir := Vector2.ZERO  # last tick's stick direction (for an instant flip, e.g. keys)


func _init(owner: FishController) -> void:
	fish = owner


func reset() -> void:
	power = 0.0
	phase = -1.0
	flow = 0.0
	last_timing = -1.0
	last_early = false
	strides = 0
	strength = 0.0
	steer = Vector2.ZERO
	tail_swing = Vector2.ZERO
	_tail_from = Vector2.ZERO
	_dir = Vector2.ZERO
	_reach = 0.0
	_crossed = true
	_last_dir = Vector2.ZERO


## Seconds from a stride's start to its peak: the fish's, times its gait's stroke time.
func peak_time() -> float:
	return fish.stride_peak_time * fish.gait.stroke_time


## Seconds from a stride's peak until it has faded out (likewise).
func fade_time() -> float:
	return fish.stride_fade_time * fish.gait.stroke_time


## How strong a stride is `t` seconds after it began, 0..1.
func envelope(t: float) -> float:
	if t < 0.0:
		return 0.0
	var peak := maxf(peak_time(), 0.01)
	if t < peak:
		return smoothstep(0.0, peak, t)
	return clampf(1.0 - (t - peak) / maxf(fade_time(), 0.01), 0.0, 1.0)


## Seconds until the current stride peaks (negative once it has), for cues.
func time_to_peak() -> float:
	return peak_time() - phase if phase >= 0.0 else INF


## How close the current stride is to its peak, 0..1: 1 right at it, falling
## to 0 once its power is below SWEET_SPOT either side. The time to sweep back.
func sweetness() -> float:
	return clampf((power - SWEET_SPOT) / (1.0 - SWEET_SPOT), 0.0, 1.0) if phase >= 0.0 else 0.0


## The tail's progress-bar cue (FishModel.set_stride_cue): [fill, glow, sweet].
## It fills root to tip as the stride builds, full at the peak, then dims as it
## fades; nothing between strides.
func cue() -> Vector3:
	if phase < 0.0:
		return Vector3.ZERO
	var fill := clampf(phase / maxf(peak_time(), 0.01), 0.0, 1.0)
	var glow := lerpf(0.75, 1.0, fill) if phase <= peak_time() else power
	return Vector3(fill, glow, sweetness())


## Every physics tick, with the processed stick.
func sample(stick: Vector2, delta: float) -> void:
	var striding := fish.input_forward > 0.0 or not fish.stride_needs_throttle
	var smoothing := fish.stride_steer_smoothing
	if striding and smoothing > 0.0:
		steer = steer.lerp(stick, 1.0 - exp(-delta / smoothing))
	else:
		steer = stick  # not striding: plain, direct steering
	if phase >= 0.0:
		phase += delta
		if phase > peak_time() + fade_time():
			# Faded out: the chain's over and the next push starts fresh.
			phase = -1.0
			strides = 0
			_dir = Vector2.ZERO
	power = envelope(phase)
	if phase < 0.0:
		flow = move_toward(flow, 0.0, fish.stride_flow_decay * delta)
	_swing_tail(delta)

	if _dir != Vector2.ZERO:
		_reach = maxf(_reach, stick.dot(_dir))
	var reach := stick.length()
	if reach < fish.stride_threshold:
		_crossed = true
		_last_dir = Vector2.ZERO
		return
	var dir := stick / reach
	var flipped := _last_dir != Vector2.ZERO and dir.dot(_last_dir) < -fish.stride_reversal
	_last_dir = dir
	if not striding:
		return
	if _dir == Vector2.ZERO and (_crossed or flipped):  # a fresh stride needs a fresh sweep
		_start(dir, reach)
	elif dir.dot(_dir) < -fish.stride_reversal and (_crossed or flipped):
		_start(dir, reach)


## A full sweep cuts harder than one that only just reaches stride_threshold:
## 0.6 at the threshold up to 1 at full reach, as far as the stick has gone so far.
func reach_scale() -> float:
	var threshold := fish.stride_threshold
	return lerpf(0.6, 1.0, clampf((_reach - threshold) / maxf(1.0 - threshold, 0.01), 0.0, 1.0))


func _start(dir: Vector2, reach: float) -> void:
	var fresh := phase < 0.0
	var timing := -1.0 if fresh else envelope(phase)
	if fresh:
		strides = 1
		strength = fish.stride_fresh
	else:
		strides += 1
		flow = clampf(flow + fish.stride_flow_gain * (2.0 * timing - 1.0), 0.0, fish.stride_flow_max)
		strength = lerpf(fish.stride_fresh, 1.0, timing) * (1.0 + flow)
	last_timing = timing
	last_early = not fresh and phase < peak_time()
	phase = 0.0
	power = 0.0
	_dir = dir
	_reach = reach
	_crossed = false
	_tail_from = tail_swing
	fish.strode.emit(timing, flow)


## Sweeps the tail across to the side opposite the push by the peak, then
## lets it relax back as the stride fades.
func _swing_tail(delta: float) -> void:
	if phase < 0.0:
		tail_swing = tail_swing.move_toward(Vector2.ZERO, 3.0 * delta)
		return
	var across := -_dir
	if phase < peak_time():
		tail_swing = _tail_from.lerp(across, smoothstep(0.0, peak_time(), phase))
	else:
		tail_swing = across * power


## The stride's push this tick, added to `velocity` (off a surface).
func apply(velocity: Vector3, basis: Basis, dt: float) -> Vector3:
	if power <= 0.0 or strength <= 0.0:
		return velocity
	var forward := -basis.z
	var room := clampf(1.0 - velocity.dot(forward) / maxf(fish.stride_max_speed, 0.1), 0.0, 1.0)
	if room <= 0.0:
		return velocity
	var push := push_direction(basis)
	return velocity + push * fish.stride_force * fish.gait.stroke_power * fish.stride_scale * power * strength * reach_scale() * room * dt


## Which way the current stride pushes (unit, world): along the gait's push
## axis, kicked off it by stride_side_angle along its stroke axis.
func push_direction(basis: Basis) -> Vector3:
	var along := -basis.z  # Gait.PushAxis.NOSE
	# Gait.StrokeAxis.LATERAL: the tail sweeps one way, so the water pushes the
	# body a little the other. Stick x is right, stick y is down (which pitches
	# the nose up).
	var kick := -(basis.x * _dir.x - basis.y * _dir.y).normalized()
	var angle := deg_to_rad(fish.stride_side_angle)
	return along * cos(angle) + kick * sin(angle)
