extends Node
## M0 swim metrics harness (planning_core_roadmap.md §1.3 / §1.5). Nature's
## tuning in the Ocean, 4 s runs from a standstill: the §1.3 scenario table, a
## timing sweep, a turn-radius sweep, held-vs-released distance and the chase
## camera's yaw wobble over a stride chain at the peak. Every number lands in one
## flat dictionary; a normal run diffs it against tests/fixtures/swim_metrics.json
## and exits 1 past tolerance, --record rewrites the fixture. Changes no feel.
##   Godot_console.exe --headless --path . res://tests/swim_metrics_probe.tscn
##   ... res://tests/swim_metrics_probe.tscn -- --record

const RUN_TIME := 4.0
const FIXTURE := "res://tests/fixtures/swim_metrics.json"
const TIMING_STEPS := 10
const TURN_SPEEDS := [5.0, 15.0, 30.0]
const TURN_MAX_TIME := 3.0
## Per-metric tolerance: max(rel * |recorded|, floor), picked by the key's last part.
const REL_TOL := 0.03
const FLOORS := {"speed": 0.3, "peak": 0.3, "flow": 0.05, "strides": 1.0, "travelled": 1.0, "off_line": 1.0,
		"turned": 3.0, "radius": 0.3, "drift": 3.0, "lost": 0.5, "ratio": 0.05, "cam_yaw": 0.3, "fish_yaw": 0.3,
		"interval": 0.001, "catchup": 0.15, "credit": 0.02, "cam_yaw_hf": 0.3, "fish_yaw_hf": 0.3}

var main: Node
var fish: FishController
var input := FishInput.new()
var metrics := {}  # flat: "scenario/field" -> float
var record := false
var record_new := false  # --record-new: add the metrics the fixture lacks, leave the recorded ones


func _ready() -> void:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	record = "--record" in args
	record_new = "--record-new" in args
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean")
	main.get_node("DebugPanel").load_mode_preset(main.NATURE_PRESET)
	fish = main.get_node("Fish")
	fish.controls = input
	_run.call_deferred()


func _run() -> void:
	var peak := fish.stride_peak_time
	var fade := fish.stride_fade_time
	print("Swim metrics (peak %.2fs, fade %.2fs, force %.1f):" % [peak, fade, fish.stride_force])
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if "--options-only" in args:  # iterate on the toggled options without the 4 minute baseline
		await _options(peak, fade)
		get_tree().quit(0)
		return
	if "--camera-sweep" in args:  # try settle numbers: wobble and catch-up for each
		await _camera_sweep(peak)
		get_tree().quit(0)
		return
	print("scenarios:")
	await _scenario("throttle_only", func(_t: float) -> Vector2: return Vector2.ZERO)
	await _scenario("held_sides_at_peak", _flip(Vector2.RIGHT, peak))
	await _scenario("sweep_and_release", _sweep(peak))
	await _scenario("direction_lock", _flip(Vector2.RIGHT, peak), true, true)
	await _scenario("early_half_peak", _flip(Vector2.RIGHT, peak * 0.5))
	await _scenario("late_three_quarter_fade", _flip(Vector2.RIGHT, peak + fade * 0.75))
	await _scenario("mashing_60ms", _flip(Vector2.RIGHT, 0.06))
	await _scenario("up_down_at_peak", _flip(Vector2.DOWN, peak))
	await _scenario("diagonal_at_peak", _flip(Vector2(1, 1).normalized(), peak))
	await _scenario("no_throttle_sides", _flip(Vector2.RIGHT, peak), false)

	print("timing sweep (flip interval -> end speed):")
	for i in TIMING_STEPS:
		var interval := lerpf(peak * 0.5, peak + fade, i / float(TIMING_STEPS - 1))
		await _scenario("timing_%02d" % i, _flip(Vector2.RIGHT, interval), true, false, "t=%.3fs " % interval)
		metrics["timing_%02d/interval" % i] = interval

	print("turn radius sweep (full stick, no throttle):")
	for v: float in TURN_SPEEDS:
		await _turn(v)

	var held: float = metrics["held_sides_at_peak/travelled"]
	var released: float = metrics["sweep_and_release/travelled"]
	metrics["held_vs_released/ratio"] = held / maxf(released, 0.001)
	print("held vs released distance: %.1f m vs %.1f m  (ratio %.3f)" % [held, released, metrics["held_vs_released/ratio"]])

	print("camera over a stride chain at the peak:")
	await _camera_wobble(peak, "camera_wobble", false)
	print("  and with follow_air_rotation on (the view turns with the nose in open water):")
	await _camera_wobble(peak, "camera_wobble_follow", true)

	await _options(peak, fade)
	_finish()


## The toggled-on options (T1 swim: M1 steer cancel, M2 timing curve, M4 settle camera). Each is off in the
## scenarios above, so those keep matching the fixture; here each is switched on, measured, switched off.
func _options(peak: float, fade: float) -> void:
	print("M1 stroke/steer decoupling (stride_steer_cancel 1):")
	fish.stride_steer_cancel = 1.0
	await _scenario("m1_held_sides_at_peak", _flip(Vector2.RIGHT, peak))
	await _scenario("m1_sweep_and_release", _sweep(peak))
	await _scenario("m1_direction_lock", _flip(Vector2.RIGHT, peak), true, true)
	await _scenario("m1_up_down_at_peak", _flip(Vector2.DOWN, peak))
	await _scenario("m1_diagonal_at_peak", _flip(Vector2(1, 1).normalized(), peak))
	metrics["m1_held_vs_released/ratio"] = metrics["m1_held_sides_at_peak/travelled"] / maxf(metrics["m1_sweep_and_release/travelled"], 0.001)
	print("  held vs released distance ratio %.3f" % metrics["m1_held_vs_released/ratio"])
	fish.stride_steer_cancel = 0.5
	await _scenario("m1_half_held_sides_at_peak", _flip(Vector2.RIGHT, peak))
	for cancel in [0.0, 1.0]:
		fish.stride_steer_cancel = cancel
		await _pair_drift("m1_pair_drift_%s" % ("off" if cancel == 0.0 else "on"), peak)
	fish.stride_steer_cancel = 0.0

	print("M2 timing reward (direction lock held, so only the reward differs; late = timing 0.7 on the fade side, early = on the rise):")
	var late := peak + 0.3 * fade
	var early := 0.0
	for i in 200:  # the stroke's rise is a smoothstep: find where it reaches 0.7
		early = peak * i / 200.0
		if smoothstep(0.0, peak, early) >= 0.7:
			break
	var late50 := peak + 0.5 * fade
	var early50 := 0.0
	for i in 200:
		early50 = peak * i / 200.0
		if smoothstep(0.0, peak, early50) >= 0.5:
			break
	for shape in 2:
		fish.stride_timing_shape = shape
		var tag := "today" if shape == 0 else "gentle"
		await _scenario("m2_%s_t50_late" % tag, _flip(Vector2.RIGHT, late50), true, true, "t=%.3fs " % late50)
		await _scenario("m2_%s_t50_early" % tag, _flip(Vector2.RIGHT, early50), true, true, "t=%.3fs " % early50)
		await _scenario("m2_%s_perfect" % tag, _flip(Vector2.RIGHT, peak), true, true)
		await _scenario("m2_%s_t70_late" % tag, _flip(Vector2.RIGHT, late), true, true, "t=%.3fs " % late)
		await _scenario("m2_%s_t70_early" % tag, _flip(Vector2.RIGHT, early), true, true, "t=%.3fs " % early)
	fish.stride_timing_shape = 1
	fish.stride_partial_credit = 1.0
	await _scenario("m2_gentle_credit_t70_late", _flip(Vector2.RIGHT, late), true, true)
	fish.stride_partial_credit = 0.0
	fish.stride_timing_shape = 0
	for tag in ["today", "gentle"]:
		var perfect: float = metrics["m2_%s_perfect/speed" % tag]
		metrics["m2_%s_t70_late/ratio" % tag] = metrics["m2_%s_t70_late/speed" % tag] / maxf(perfect, 0.001)
		metrics["m2_%s_t70_early/ratio" % tag] = metrics["m2_%s_t70_early/speed" % tag] / maxf(perfect, 0.001)
		metrics["m2_%s_t50_late/ratio" % tag] = metrics["m2_%s_t50_late/speed" % tag] / maxf(perfect, 0.001)
		metrics["m2_%s_t50_early/ratio" % tag] = metrics["m2_%s_t50_early/speed" % tag] / maxf(perfect, 0.001)
		print("  %s: a 0.5-timed run reaches %.0f%% (late side) / %.0f%% (rise side)" % [
				tag, metrics["m2_%s_t50_late/ratio" % tag] * 100.0, metrics["m2_%s_t50_early/ratio" % tag] * 100.0])
		print("  %s: a 0.7-timed run reaches %.0f%% (late side) / %.0f%% (rise side) of the perfect run's end speed" % [
				tag, metrics["m2_%s_t70_late/ratio" % tag] * 100.0, metrics["m2_%s_t70_early/ratio" % tag] * 100.0])
	# the credit curves themselves: monotonic, perfect and zero fixed
	var swish := fish.swishy
	for shape in 2:
		fish.stride_timing_shape = shape
		var prev := -1.0
		var mono := 1.0
		for i in 21:
			var c := swish.timing_credit(i / 20.0)
			if c < prev - 0.0001:
				mono = 0.0
			prev = c
		var tag := "today" if shape == 0 else "gentle"
		metrics["m2_%s_curve/monotonic" % tag] = mono
		metrics["m2_%s_curve/credit_at_0_7" % tag] = swish.timing_credit(0.7)
		metrics["m2_%s_curve/credit_at_1" % tag] = swish.timing_credit(1.0)
		print("  %s curve: monotonic %s, credit(0.7) %.2f, credit(1) %.2f" % [tag, mono > 0.5, swish.timing_credit(0.7), swish.timing_credit(1.0)])
	fish.stride_timing_shape = 0

	print("M4 settle camera (Nature, follow_air_rotation on so the view would turn with the nose):")
	var nature := NatureSettings.shared()
	nature.camera_settle = true
	var settle := nature.camera_style()
	nature.camera_settle = false
	# throttle held (the camera reads the action); without M1 the held sweeps also yaw the fish itself
	# (the plain chase camera follows that whole swing), with it the fish holds its line and the camera is the only wobble.
	for cancel in [0.0, 1.0]:
		fish.stride_steer_cancel = cancel
		var tag := "" if cancel == 0.0 else "_m1"
		await _camera_wobble(peak, "m4_camera_wobble_chase%s" % tag, true, null, true)
		await _camera_wobble(peak, "m4_camera_wobble_settle%s" % tag, true, settle, true)
		await _camera_wobble(peak, "m4_camera_wobble_unnatural%s" % tag, true, UnnaturalRun.survivor_style(UnnaturalSettings.new()), true)
	fish.stride_steer_cancel = 0.0
	await _catchup("m4_catchup_nature", settle)
	await _catchup("m4_catchup_unnatural", UnnaturalRun.survivor_style(UnnaturalSettings.new()))
	await _catchup("m4_catchup_chase", null)


## Settle numbers tried against the stride chain's wobble and a 90 degree turn's catch-up (tuning aid).
func _camera_sweep(peak: float) -> void:
	var tries := [
		{"settle_rate": 3.0, "settle_smoothing": 0.3},
		{"settle_rate": 1.5, "settle_smoothing": 0.3},
		{"settle_rate": 1.0, "settle_smoothing": 0.3, "settle_turning_rate": 0.3},
		{"settle_rate": 1.0, "settle_smoothing": 0.7, "settle_turning_rate": 0.3},
	]
	fish.stride_steer_cancel = 1.0
	for values: Dictionary in tries:
		var style := CameraStyle.settle()
		for prop: String in values:
			style.set(prop, values[prop])
		print("try %s" % [values])
		await _camera_wobble(peak, "sweep", true, style, true)
		await _catchup("sweep", style)


func _finish() -> void:
	var code := 0
	if record_new:
		var recorded := {}
		if FileAccess.file_exists(FIXTURE):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
			if parsed is Dictionary:
				recorded = parsed
		var added := 0
		for key: String in metrics:
			if not recorded.has(key):
				recorded[key] = metrics[key]
				added += 1
		var out := FileAccess.open(FIXTURE, FileAccess.WRITE)
		out.store_string(JSON.stringify(recorded, "\t", true))
		out.close()
		print("swim_metrics_probe: added %d new metrics to %s (recorded ones untouched)" % [added, FIXTURE])
	elif record:
		var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
		file.store_string(JSON.stringify(metrics, "\t", true))
		file.close()
		print("swim_metrics_probe: recorded %d metrics to %s" % [metrics.size(), FIXTURE])
	else:
		code = _diff()
	get_tree().quit(code)


## Print the delta of every metric against the fixture; 1 if any is out of tolerance.
func _diff() -> int:
	if not FileAccess.file_exists(FIXTURE):
		print("swim_metrics_probe: no fixture, run with --record")
		return 1
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not parsed is Dictionary:
		print("swim_metrics_probe: fixture unreadable")
		return 1
	var recorded: Dictionary = parsed
	var bad := 0
	var keys := metrics.keys()
	keys.sort()
	for key: String in keys:
		if not recorded.has(key):
			print("  NEW   %-40s %9.3f" % [key, metrics[key]])
			bad += 1
			continue
		var was: float = recorded[key]
		var now: float = metrics[key]
		var tol := maxf(absf(was) * REL_TOL, float(FLOORS.get(key.get_slice("/", 1), 0.05)))
		var delta := now - was
		if absf(delta) > tol:
			print("  FAIL  %-40s %9.3f -> %9.3f  (%+.3f, tol %.3f)" % [key, was, now, delta, tol])
			bad += 1
		elif absf(delta) > 0.0005:
			print("  ok    %-40s %9.3f -> %9.3f  (%+.3f)" % [key, was, now, delta])
	for key: String in recorded:
		if not metrics.has(key):
			print("  GONE  %s" % key)
			bad += 1
	print("swim_metrics_probe: %s" % ("within tolerance (%d metrics)" % keys.size() if bad == 0 else "%d out of tolerance" % bad))
	return 1 if bad else 0


## The stick held to one side, flipped to the other every `interval`.
func _flip(side: Vector2, interval: float) -> Callable:
	return func(t: float) -> Vector2: return side * (1.0 if int(t / interval) % 2 == 0 else -1.0)


## A sweep to one side, held briefly, back to the middle, then the other side.
func _sweep(interval: float) -> Callable:
	return func(t: float) -> Vector2:
		var into := fmod(t, interval)
		var side := 1.0 if int(t / interval) % 2 == 0 else -1.0
		return Vector2(side, 0.0) if into < interval * 0.6 else Vector2.ZERO


## Throttle held unless `throttle` is false (strides need it).
func _scenario(label: String, stick_at: Callable, throttle := true, lock := false, note := "") -> void:
	input.clear()
	fish.request_reset()
	await _ticks(5)
	var start := fish.global_position
	var heading := -fish.global_basis.z
	var strides := [0]  # an array: a lambda can't assign the locals it captures
	var count := func(_timing: float, _flow: float) -> void: strides[0] += 1
	fish.strode.connect(count)
	var t := 0.0
	var peak := 0.0
	var max_flow := 0.0
	while t < RUN_TIME:
		input.stick = stick_at.call(t)
		input.forward = 1.0 if throttle else 0.0
		input.direction_lock = lock
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		peak = maxf(peak, fish.speed)
		max_flow = maxf(max_flow, fish.swishy.flow)
	fish.strode.disconnect(count)
	var moved := fish.global_position - start
	var side := (moved - heading * moved.dot(heading)).length()
	var turned := rad_to_deg(heading.angle_to(-fish.global_basis.z))
	metrics[label + "/speed"] = fish.speed
	metrics[label + "/peak"] = peak
	metrics[label + "/flow"] = max_flow
	metrics[label + "/strides"] = float(strides[0])
	metrics[label + "/travelled"] = moved.length()
	metrics[label + "/off_line"] = side
	metrics[label + "/turned"] = turned
	print("  %-26s %sspeed %5.1f  peak %5.1f  flow %4.2f  strides %3d  travelled %5.1f m  off line %5.1f m  turned %3.0f°" % [
			label, note, fish.speed, peak, max_flow, strides[0], moved.length(), side, turned])
	input.clear()


## Full stick to one side with no throttle, from `v` m/s straight ahead, until the
## nose has turned 90 degrees: the path's radius, the drift angle (velocity vs
## nose) at its worst, and the speed lost over the quarter turn.
func _turn(v: float) -> void:
	input.clear()
	fish.request_reset()
	await _ticks(5)
	var heading := -fish.global_basis.z
	fish.linear_velocity = heading * v
	await _ticks(1)
	var v0 := fish.linear_velocity.length()
	var last := fish.global_position
	var path := 0.0
	var t := 0.0
	var max_drift := 0.0
	var turned := 0.0
	while t < TURN_MAX_TIME and turned < PI * 0.5:
		input.stick = Vector2.RIGHT
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		path += fish.global_position.distance_to(last)
		last = fish.global_position
		turned = absf(heading.signed_angle_to(-fish.global_basis.z, Vector3.UP))
		var vel := fish.linear_velocity
		if vel.length() > 0.5:
			max_drift = maxf(max_drift, absf(rad_to_deg(vel.angle_to(-fish.global_basis.z))))
	var key := "turn_%d" % int(v)
	var radius := path / maxf(turned, 0.01)
	var lost := (v0 - fish.linear_velocity.length()) * (PI * 0.5 / maxf(turned, 0.01))
	metrics[key + "/radius"] = radius
	metrics[key + "/drift"] = max_drift
	metrics[key + "/lost"] = lost
	metrics[key + "/turned"] = rad_to_deg(turned)
	print("  %2.0f m/s: turned %3.0f° in %.2fs  radius %5.2f m  drift %4.0f°  speed lost per 90° %5.2f m/s" % [
			v, rad_to_deg(turned), t, radius, max_drift, lost])
	input.clear()


## A locked stride chain (strokes at the peak, the stick held to each side, no
## direction lock: Nature's own way to swim), the FollowCamera's yaw and the
## fish's sampled every rendered frame once the chain has settled. The slow
## drift of the heading is removed (least-squares line), then half the
## peak-to-peak swing of what's left is the wobble, in degrees.
func _camera_wobble(peak: float, key: String, follow_air: bool, style: CameraStyle = null, throttle_action := false) -> void:
	var camera: Camera3D = main.get_node("FollowCamera")
	camera.set("follow_air_rotation", follow_air)
	if style:
		camera.call("push_style", &"probe", style)
	if throttle_action:
		# the camera (settle's coast swing) reads the throttle action, not the probe's FishInput
		Input.action_press("thrust_forward")
	input.clear()
	fish.request_reset()
	await _ticks(5)
	var flip := _flip(Vector2.RIGHT, peak)
	var t := 0.0
	var times := PackedFloat64Array()
	var cam_yaws := PackedFloat64Array()
	var fish_yaws := PackedFloat64Array()
	var prev_cam := NAN
	var prev_fish := NAN
	var cam_total := 0.0
	var fish_total := 0.0
	while t < 3.0:
		input.forward = 1.0
		input.stick = flip.call(t)
		await get_tree().physics_frame
		await get_tree().process_frame  # the camera updates per frame
		t += get_physics_process_delta_time()
		if t < 1.0:
			continue
		var cam_yaw := _yaw(-camera.global_basis.z)
		var fish_yaw := _yaw(-fish.global_basis.z)
		# unwrapped: a held stick can swing the nose through the seam
		if not is_nan(prev_cam):
			cam_total += wrapf(cam_yaw - prev_cam, -PI, PI)
			fish_total += wrapf(fish_yaw - prev_fish, -PI, PI)
		prev_cam = cam_yaw
		prev_fish = fish_yaw
		times.append(t)
		cam_yaws.append(rad_to_deg(cam_total))
		fish_yaws.append(rad_to_deg(fish_total))
	metrics[key + "/cam_yaw"] = _wobble(times, cam_yaws)
	metrics[key + "/fish_yaw"] = _wobble(times, fish_yaws)
	# the stride-rate part alone: what's left once a moving average over one stride pair is taken out
	metrics[key + "/cam_yaw_hf"] = _wobble_hf(times, cam_yaws, peak * 2.0)
	metrics[key + "/fish_yaw_hf"] = _wobble_hf(times, fish_yaws, peak * 2.0)
	camera.set("follow_air_rotation", false)
	camera.call("pop_style", &"probe")
	Input.action_release("thrust_forward")
	print("  camera yaw amplitude %.2f°, fish yaw amplitude %.2f° (%d frames); at the stride rate (hf): camera %.2f°, fish %.2f°" % [
			metrics[key + "/cam_yaw"], metrics[key + "/fish_yaw"], times.size(), metrics[key + "/cam_yaw_hf"], metrics[key + "/fish_yaw_hf"]])
	input.clear()


## How far the nose's heading moves over one symmetric held pair (the stick held right for one peak time, then
## left for one) once a stride chain is going: a held stroke should cancel itself out. Degrees.
func _pair_drift(key: String, peak: float) -> void:
	input.clear()
	fish.request_reset()
	await _ticks(5)
	var flip := _flip(Vector2.RIGHT, peak)
	var t := 0.0
	var yaw0 := NAN
	var yaw1 := NAN
	while t < peak * 10.0:
		input.forward = 1.0
		input.stick = flip.call(t)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if is_nan(yaw0) and t >= peak * 8.0:
			yaw0 = _yaw(-fish.global_basis.z)
		if is_nan(yaw1) and t >= peak * 10.0 - 0.001:
			yaw1 = _yaw(-fish.global_basis.z)
	if is_nan(yaw1):
		yaw1 = _yaw(-fish.global_basis.z)
	var drift := absf(rad_to_deg(wrapf(yaw1 - yaw0, -PI, PI)))
	metrics[key + "/turned"] = drift
	print("  %-22s heading moves %.1f° over one symmetric held pair" % [key, drift])
	input.clear()


## Seconds the camera takes to be back within 5 degrees of the nose after a 90 degree turn (full stick, no
## throttle) ends and the stick is let go; with `style` pushed (null: the plain chase view).
func _catchup(key: String, style: CameraStyle) -> void:
	var camera: Camera3D = main.get_node("FollowCamera")
	camera.set("follow_air_rotation", true)
	if style:
		camera.call("push_style", &"probe", style)
	input.clear()
	fish.request_reset()
	await _ticks(5)
	for i in 60:
		await get_tree().process_frame
	var heading := -fish.global_basis.z
	var turned := 0.0
	var guard := 0
	while turned < PI * 0.5 and guard < 240:
		input.stick = Vector2.RIGHT
		await get_tree().physics_frame
		await get_tree().process_frame
		turned = absf(heading.signed_angle_to(-fish.global_basis.z, Vector3.UP))
		guard += 1
	input.clear()
	var t := 0.0
	var gap := 99.0
	while t < 6.0:
		await get_tree().physics_frame
		await get_tree().process_frame
		t += get_physics_process_delta_time()
		gap = absf(rad_to_deg(wrapf(_yaw(-camera.global_basis.z) - _yaw(-fish.global_basis.z), -PI, PI)))
		if gap < 5.0:
			break
	metrics[key + "/catchup"] = t
	print("  %-22s turned %3.0f°, view within 5° of the nose %.2fs after the stick is let go" % [key, rad_to_deg(turned), t])
	camera.set("follow_air_rotation", false)
	camera.call("pop_style", &"probe")


## Half the peak-to-peak of `ys` once its least-squares line over `xs` is taken out.
func _wobble(xs: PackedFloat64Array, ys: PackedFloat64Array) -> float:
	var n := float(xs.size())
	if n < 3.0:
		return 0.0
	var mx := 0.0
	var my := 0.0
	for i in xs.size():
		mx += xs[i]
		my += ys[i]
	mx /= n
	my /= n
	var sxy := 0.0
	var sxx := 0.0
	for i in xs.size():
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
	var slope := sxy / maxf(sxx, 0.000001)
	var lo := INF
	var hi := -INF
	for i in xs.size():
		var r := ys[i] - (my + slope * (xs[i] - mx))
		lo = minf(lo, r)
		hi = maxf(hi, r)
	return (hi - lo) * 0.5


## Half the peak-to-peak of `ys` minus its moving average over `window` s (samples nearer the ends than half the
## window are left out): the swing at the stride rate, without the slow drift of the heading.
func _wobble_hf(xs: PackedFloat64Array, ys: PackedFloat64Array, window: float) -> float:
	var lo := INF
	var hi := -INF
	var half := window * 0.5
	for i in xs.size():
		if xs[i] - xs[0] < half or xs[xs.size() - 1] - xs[i] < half:
			continue
		var sum := 0.0
		var n := 0
		for j in xs.size():
			if absf(xs[j] - xs[i]) <= half:
				sum += ys[j]
				n += 1
		var r := ys[i] - sum / maxf(n, 1)
		lo = minf(lo, r)
		hi = maxf(hi, r)
	return (hi - lo) * 0.5 if hi > lo else 0.0


func _yaw(forward: Vector3) -> float:
	return atan2(-forward.x, -forward.z)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
