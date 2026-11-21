extends Node
## SwimState (planning_core_roadmap.md M5), on Nature's tuning in the Ocean:
## - the controller fills it every tick with sane numbers: speed, speed_frac,
##   effort (throttle, boost or stride power), acceleration with the right sign
##   speeding up and braking, slip and drift in a hard turn, nothing NaN;
## - a puppet (set_net_state) and SwimState.from_velocity_history rebuild the
##   same motion from velocities and facings alone: the states they make match
##   the controller's on the same run;
## - replay_fx() still comes out in the 19-float layout, from the state.
##   Godot_console.exe --headless --path . res://tests/swim_state_probe.tscn

const TICK := 1.0 / 120.0

var main: Node
var fish: FishController
var puppet: FishController
var input := FishInput.new()
var failures := 0

## Every tick of the current run, captured as the next tick starts (when the
## fish's swim_state still holds the tick before's): the controller's state, the
## state a puppet made from the same velocity and facing, and the history.
var _basis := Basis.IDENTITY
var _have_basis := false
var _ticks: Array[Dictionary] = []
var _velocities := PackedVector3Array()
var _bases: Array[Basis] = []
var _capturing := false
var _non_finite := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean")
	main.get_node("DebugPanel").load_mode_preset(main.NATURE_PRESET)
	fish = main.get_node("Fish")
	fish.controls = input
	puppet = load("res://scenes/fish.tscn").instantiate()
	main.add_child(puppet)
	puppet.make_puppet()
	puppet.position = Vector3(500.0, 500.0, 500.0)
	fish.physics_tick.connect(_on_tick)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _on_tick(state: PhysicsDirectBodyState3D) -> void:
	if _capturing and _have_basis:
		# The previous tick's end: its state, its velocity, the facing it was made with.
		var s := fish.swim_state
		var velocity := fish._step_velocity
		puppet.set_net_state(Transform3D(_basis, Vector3(500.0, 500.0, 500.0)), velocity, fish.replay_fx(), TICK)
		_velocities.append(velocity)
		_bases.append(_basis)
		_ticks.append({
			"speed": s.speed, "speed_frac": s.speed_frac, "effort": s.effort, "accel": s.accel, "spin": s.spin,
			"slip": s.slip, "drift": s.drift_angle, "stride_power": s.stride_power, "boosting": s.boosting,
			"puppet": _copy(puppet.swim_state),
		})
		if not _finite(s):
			_non_finite += 1
	_basis = state.transform.basis.orthonormalized()
	_have_basis = true


func _copy(s: SwimState) -> Dictionary:
	return {"speed": s.speed, "speed_frac": s.speed_frac, "accel": s.accel, "spin": s.spin, "slip": s.slip,
			"drift": s.drift_angle, "stride_power": s.stride_power, "effort": s.effort}


func _finite(s: SwimState) -> bool:
	for value: Variant in [s.speed, s.speed_frac, s.effort, s.forward_speed, s.accel, s.spin, s.slip, s.drift_angle,
			s.stride_phase, s.stride_power, s.stride_dir, s.stride_fluke, s.stride_peak, s.stride_fade, s.stride_timing,
			s.stride_flow, s.stride_sweet, s.stride_cue, s.surface_normal, s.bell_lean, s.velocity]:
		if value is float and not is_finite(value):
			return false
		if value is Vector2 and not (is_finite(value.x) and is_finite(value.y)):
			return false
		if value is Vector3 and not (is_finite(value.x) and is_finite(value.y) and is_finite(value.z)):
			return false
	return true


## Runs `ticks` physics ticks, each fed by `drive(tick)` (sets the input), and
## returns what _on_tick captured.
func _run_ticks(ticks: int, drive: Callable) -> Array[Dictionary]:
	input.clear()
	fish.request_reset()
	for i in 5:
		await get_tree().physics_frame
	_ticks.clear()
	_velocities.clear()
	_bases.clear()
	_have_basis = false
	_capturing = true
	for tick in ticks:
		drive.call(tick)
		await get_tree().physics_frame
	_capturing = false
	input.clear()
	return _ticks.duplicate()


func _mean(ticks: Array[Dictionary], key: String, from: int, to: int) -> float:
	var total := 0.0
	for i in range(from, mini(to, ticks.size())):
		total += float(ticks[i][key])
	return total / maxf(mini(to, ticks.size()) - from, 1)


func _run() -> void:
	var peak_ticks := maxi(roundi(fish.swishy.peak_time() * 120.0), 1)
	print("the controller's state:")
	_non_finite = 0
	var swim := await _run_ticks(360, func(tick: int) -> void:
		input.forward = 1.0
		input.stick = Vector2.RIGHT * (1.0 if floori(float(tick) / peak_ticks) % 2 == 0 else -1.0))
	var fast := swim.back() as Dictionary
	check(fast.speed > 5.0 and fast.speed <= fish.max_boost_speed * fish.top_speed_scale + 0.1, "it speeds up and stays under the cap (%.1f m/s)" % fast.speed)
	check(fast.speed_frac > 0.2 and fast.speed_frac <= 1.0, "speed_frac is its share of cruise speed (%.2f)" % fast.speed_frac)
	check(is_equal_approx(float(fast.effort), 1.0), "throttle held: effort 1")
	var accel_z := 0.0
	for i in range(5, 65):
		accel_z += -(swim[i].accel as Vector3).z
	check(accel_z / 60.0 > 0.5, "speeding up, acceleration is forward (%.1f m/s^2 mean over 0.5 s)" % (accel_z / 60.0))
	check(_non_finite == 0, "no field is ever NaN or infinite")
	check(_mean(swim, "stride_power", 0, 360) > 0.05, "strides show in stride_power (mean %.2f)" % _mean(swim, "stride_power", 0, 360))

	var coast := await _run_ticks(480, func(tick: int) -> void:
		input.forward = 1.0 if tick < 240 else 0.0
		input.reverse = 0.0 if tick < 240 else 1.0)
	var braking := 0.0
	for i in range(250, 290):
		braking += -(coast[i].accel as Vector3).z
	check(braking / 40.0 < -0.5, "reversing the throttle, acceleration is backward (%.1f m/s^2)" % (braking / 40.0))
	check(float(coast[239].speed) > float(coast.back().speed) or float(coast.back().speed) < 1.0, "and it slows (%.1f to %.1f m/s)" % [coast[239].speed, coast.back().speed])
	var idle := await _run_ticks(120, func(_tick: int) -> void: pass)
	check(float(idle.back().effort) == 0.0 and float(idle.back().speed) < 2.0, "idle: effort 0, nearly still")

	var turn := await _run_ticks(480, func(tick: int) -> void:
		input.forward = 1.0
		input.stick = Vector2.RIGHT if tick > 150 else Vector2.ZERO)
	var worst_drift := 0.0
	var worst_slip := 0.0
	var worst_spin := 0.0
	for i in range(160, turn.size()):
		worst_drift = maxf(worst_drift, turn[i].drift)
		worst_slip = maxf(worst_slip, absf((turn[i].slip as Vector3).x))
		worst_spin = maxf(worst_spin, absf((turn[i].spin as Vector3).y))
	check(worst_spin > 1.0, "turning, it yaws (%.1f rad/s about its up)" % worst_spin)
	check(worst_drift > 1.0 and worst_slip > 0.1, "and slips sideways (drift %.1f degrees, %.2f m/s)" % [worst_drift, worst_slip])
	check(_non_finite == 0, "still nothing NaN")

	print("a puppet and the velocity history rebuild it:")
	# The turn run is the replayed one: its velocities and facings, one per tick.
	var worst_accel := 0.0
	var worst_slip_gap := 0.0
	var worst_speed_gap := 0.0
	var spin_gap := 0.0
	var spin_worst := 0.0
	var count := 0
	for i in range(3, turn.size()):
		var then: Dictionary = turn[i]
		var made: Dictionary = then.puppet
		worst_accel = maxf(worst_accel, ((then.accel as Vector3) - (made.accel as Vector3)).length())
		worst_slip_gap = maxf(worst_slip_gap, ((then.slip as Vector3) - (made.slip as Vector3)).length())
		worst_speed_gap = maxf(worst_speed_gap, absf(float(then.speed) - float(made.speed)))
		var gap := ((then.spin as Vector3) - (made.spin as Vector3)).length()
		spin_gap += gap
		spin_worst = maxf(spin_worst, gap)
		count += 1
	check(worst_speed_gap < 0.01 and worst_slip_gap < 0.01, "the puppet's speed and slip are the controller's (%.4f m/s, %.4f m/s)" % [worst_speed_gap, worst_slip_gap])
	check(worst_accel < 0.5, "its acceleration too (worst gap %.3f m/s^2)" % worst_accel)
	check(spin_gap / count < 0.2 and spin_worst < 1.5, "its spin follows within a tick of the controller's (mean gap %.3f, worst %.2f rad/s)" % [spin_gap / count, spin_worst])
	var history := SwimState.from_velocity_history(_velocities, _bases, TICK, fish.max_speed * fish.speed_scale)
	var last: Dictionary = turn.back()
	check(absf(history.speed - float(last.speed)) < 0.05 and (history.slip - (last.slip as Vector3)).length() < 0.05, "from_velocity_history ends where the controller did")
	check((history.accel - (last.accel as Vector3)).length() < 0.5, "and with its acceleration (%s vs %s)" % [history.accel, last.accel])

	print("the wire format:")
	var fx := fish.replay_fx()
	check(fx.size() == ReplayData.FX_SIZE, "replay_fx() is %d floats" % fx.size())
	var all_finite := true
	for value in fx:
		all_finite = all_finite and is_finite(value)
	check(all_finite, "all of them finite")
	var back := puppet.replay_fx()
	check(back.size() == ReplayData.FX_SIZE, "a puppet sends its looks on as it got them")

	print("swim_state_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)
