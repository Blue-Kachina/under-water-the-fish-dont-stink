extends Node
## Extra Swishy strides on Nature's tuning, in the Ocean: stick patterns fed
## through the fish's controls (FishInput) for RUN_TIME each, from a standstill,
## with throttle held (strides need it) unless a scenario says otherwise.
## Strides timed at the peak should beat early, late and mashed ones; up/down
## and diagonal sweeps stride too; circling the stick doesn't; the weave
## cancels out sideways; and boost does nothing.
##   Godot_console.exe --headless --path . res://tests/swishy_probe.tscn

const RUN_TIME := 4.0

var main: Node
var fish: FishController
var input := FishInput.new()
var failures := 0
var results := {}


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean")
	main.get_node("DebugPanel").load_mode_preset(main.NATURE_PRESET)
	fish = main.get_node("Fish")
	fish.controls = input
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	var peak := fish.stride_peak_time
	var fade := fish.stride_fade_time
	print("Extra Swishy (peak %.2fs, fade %.2fs, force %.1f):" % [peak, fade, fish.stride_force])
	await _scenario("throttle only", func(_t: float) -> Vector2: return Vector2.ZERO)
	await _scenario("no throttle, side to side at the peak", _flip(Vector2.RIGHT, peak), false)
	await _scenario("one stride, then nothing", func(t: float) -> Vector2: return Vector2.RIGHT if t < 0.2 else Vector2.ZERO)
	await _scenario("side to side at the peak", _flip(Vector2.RIGHT, peak))
	await _scenario("side to side early (half the peak)", _flip(Vector2.RIGHT, peak * 0.5))
	await _scenario("side to side late (peak + 3/4 fade)", _flip(Vector2.RIGHT, peak + fade * 0.75))
	await _scenario("mashing (0.06s)", _flip(Vector2.RIGHT, 0.06))
	await _scenario("up and down at the peak", _flip(Vector2.DOWN, peak))
	await _scenario("diagonal at the peak", _flip(Vector2(1, 1).normalized(), peak))
	await _scenario("circling the stick (2 turns/s)", func(t: float) -> Vector2: return Vector2.from_angle(t * TAU * 2.0))
	await _scenario("sweep and let go, at the peak", _sweep(peak))
	await _scenario("smooth analog sweeps, at the peak", func(t: float) -> Vector2: return Vector2(sin(PI * t / peak), 0.0))
	await _scenario("at the peak, direction lock", _flip(Vector2.RIGHT, peak), true, true)

	var on_peak: Dictionary = results["side to side at the peak"]
	check(on_peak.speed > results["throttle only"].speed * 1.5, "strides at the peak beat throttle")
	check(on_peak.speed > results["side to side early (half the peak)"].speed * 1.3, "at the peak beats early")
	check(on_peak.speed > results["side to side late (peak + 3/4 fade)"].speed * 1.3, "at the peak beats late")
	check(results["mashing (0.06s)"].speed < results["throttle only"].speed + 2.0, "mashing gives little over throttle")
	check(results["no throttle, side to side at the peak"].strides == 0, "no strides without throttle")
	check(results["no throttle, side to side at the peak"].speed < 1.0, "sweeping without throttle just steers")
	check(on_peak.flow > 1.0, "good timing builds flow (%.2f)" % on_peak.flow)
	check(results["up and down at the peak"].speed > on_peak.speed * 0.7, "up and down strides too")
	check(results["diagonal at the peak"].speed > on_peak.speed * 0.7, "diagonals stride too")
	check(results["smooth analog sweeps, at the peak"].speed > on_peak.speed * 0.8, "smooth analog sweeps stride as well as flicks")
	check(results["circling the stick (2 turns/s)"].strides <= 2, "circling doesn't stride (%d)" % results["circling the stick (2 turns/s)"].strides)
	check(results["at the peak, direction lock"].side < 2.0, "the weave cancels sideways under a lock (%.2f m off the line)" % results["at the peak, direction lock"].side)
	check(on_peak.peak >= fish.nature_demo_speed, "good strides reach demo speed (%.1f of %.1f)" % [on_peak.peak, fish.nature_demo_speed])

	print("tail:")
	input.clear()
	fish.request_reset()
	await _ticks(5)
	input.forward = 1.0
	var swings := []
	for side: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		input.stick = side
		for i in roundi(peak * 120.0):
			await get_tree().physics_frame
		swings.append(fish.swishy.tail_swing)
	check(swings[0].x < -0.9, "push right: the tail swings to the left by the peak (%.2f)" % swings[0].x)
	check(swings[1].x > 0.9, "then push left: it swings back across to the right (%.2f)" % swings[1].x)
	check(swings[3].y < -0.9 and absf(swings[3].x) < 0.1, "up, then down: it swings up (%s)" % swings[3])
	input.clear()
	for i in roundi((peak + fade + 0.5) * 120.0):
		await get_tree().physics_frame
	check(fish.swishy.tail_swing.length() < 0.05, "it relaxes back to the middle after a stride")

	print("arcade:")
	var camera: Camera3D = main.get_node("FollowCamera")
	input.clear()
	fish.request_reset()
	await _ticks(5)
	var flip := _flip(Vector2.RIGHT, peak)
	var t := 0.0
	while t < 3.0:
		input.forward = 1.0
		input.stick = flip.call(t)
		await get_tree().physics_frame
		await get_tree().process_frame  # the tail and camera update per frame
		t += get_physics_process_delta_time()
	var poured: int = fish.get_node("StrideStream").count()
	var tail_size: float = fish._tail.scale.x
	var zoom: float = camera.zoom
	check(tail_size > 1.8, "the tail grows with flow (x%.2f at flow %.2f)" % [tail_size, fish.swishy.flow])
	check(poured >= 20, "strides pour a stream of bubbles (%d out)" % poured)
	check(zoom < 0.95, "the view closes in (zoom %.3f)" % zoom)
	input.clear()
	for i in 480:
		await get_tree().process_frame
	check(fish._tail.scale.x < 1.05 and camera.zoom > 0.995, "all back to normal after (tail x%.2f, zoom %.3f)" % [fish._tail.scale.x, camera.zoom])
	check(fish.get_node("StrideStream").count() == 0, "out of stride: the stream stops and its bubbles fade away")

	print("boost:")
	fish.request_reset()
	await _ticks(5)
	input.boost = true
	var boosted := false
	for i in 120:
		await get_tree().physics_frame
		boosted = boosted or fish.is_boosting
	input.boost = false
	check(not boosted and fish.speed < 1.0, "boost does nothing while boost_enabled is off")

	print("swishy_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## The stick held to one side, flipped to the other every `interval`.
func _flip(side: Vector2, interval: float) -> Callable:
	return func(t: float) -> Vector2: return side * (1.0 if int(t / interval) % 2 == 0 else -1.0)


## A sweep to one side, held briefly, back to the middle, then the other side;
## a new side every `interval`.
func _sweep(interval: float) -> Callable:
	return func(t: float) -> Vector2:
		var into := fmod(t, interval)
		var side := 1.0 if int(t / interval) % 2 == 0 else -1.0
		return Vector2(side, 0.0) if into < interval * 0.6 else Vector2.ZERO


## Throttle held unless `throttle` is false (strides need it).
func _scenario(label: String, stick_at: Callable, throttle := true, lock := false) -> void:
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
	results[label] = {"speed": fish.speed, "peak": peak, "flow": max_flow, "strides": strides[0], "side": side}
	print("  %-38s speed %5.1f m/s  peak %5.1f  flow max %4.2f  strides %3d  travelled %5.1f m  off line %5.1f m  turned %3.0f°" % [
			label, fish.speed, peak, max_flow, strides[0], moved.length(), side, rad_to_deg(heading.angle_to(-fish.global_basis.z))])
	input.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
