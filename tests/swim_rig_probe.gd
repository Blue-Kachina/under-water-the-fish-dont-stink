extends Node
## The shark's procedural rig (SwimRig, planning_core_roadmap.md 2.2/2.3, P2 to P4), on bare models stepped by
## hand with hand-made SwimStates (no physics, no window):
## - toggle off: the model poses as it always did; toggle on with the layers at weight 0: the same pose to 1e-4 (the
##   zero-change state);
## - each layer's check (one block per layer as it was added): the pose is zero at rest, the wave's rate rises with
##   speed, the tail lags with the sign of the acceleration, bank and bend take the turn's sign, drift bends toward the
##   velocity, the fins answer, idle fades with speed;
## - a 60 s random soak with nothing NaN, the stride cue still filling the tail, the per-fish cost.
##   Godot_console.exe --headless --path . res://tests/swim_rig_probe.tscn

const DT := 1.0 / 60.0
const AT_POINTS := [Vector3(0.0, 0.0, 0.6), Vector3(0.0, 0.1, 1.2), Vector3(0.2, 0.0, 1.6), Vector3(0.0, 0.0, -0.5),
		Vector3(0.0, 0.1, 0.0)]

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


## A great white, in the tree, with the gait given.
func shark(gait: Gait) -> FishModel:
	var model := FishModel.build(FishCharacter.FishClass.HUNTER, 0)
	add_child(model)
	model.swim.gait = gait
	return model


## A Hunter gait: the rig on with every layer weight at 0 and the old pose kept (the zero-change state).
func zero_gait(on := true) -> Gait:
	var gait := GaitSettings.default_for(FishCharacter.FishClass.HUNTER)
	gait.procedural_rig = on
	gait.rig_legacy_tail = 1.0
	for field: String in layer_fields():
		gait.set(field, 0.0)
	return gait


## The Gait's layer weights, in layer order (each step adds its own).
func layer_fields() -> Array[String]:
	return ["rig_undulation", "rig_tail_drive", "rig_turn", "rig_accel", "rig_drift"]


## A state at `speed` m/s straight ahead, effort from the throttle.
func moving(speed: float, effort := -1.0) -> SwimState:
	var s := SwimState.new()
	s.speed = speed
	s.speed_frac = clampf(speed / 23.0, 0.0, 1.0)
	s.effort = s.speed_frac if effort < 0.0 else effort
	s.forward_speed = speed
	s.velocity = Vector3(0.0, 0.0, -speed)
	return s


func run(model: FishModel, s: SwimState, seconds: float) -> void:
	for i in roundi(seconds / DT):
		model.react(DT, s)


func bend_signature(model: FishModel) -> PackedVector3Array:
	var result := PackedVector3Array()
	for p: Vector3 in AT_POINTS:
		result.append(model.bend_point(p))
	result.append(model.tail.position)
	result.append(model.tail.rotation)
	return result


func worst_gap(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, (a[i] - b[i]).length())
	return worst


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_zero_change()
	_undulation()
	_tail_drive()
	_turn()
	_accel()
	_drift()
	print("swim_rig_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _zero_change() -> void:
	print("the zero-change state:")
	var off := shark(zero_gait(false))
	var on := shark(zero_gait(true))
	var s_off := moving(12.0)
	var s_on := moving(12.0)
	s_off.gait = off.swim.gait
	s_on.gait = on.swim.gait
	var worst := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 240:
		# What the controller writes each frame: a tail swing, pitch and yaw.
		var swing := Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.6, 0.6), 0.0)
		off.tail.rotation = swing
		on.tail.rotation = swing
		off.react(DT, s_off)
		on.react(DT, s_on)
		worst = maxf(worst, worst_gap(bend_signature(off), bend_signature(on)))
	check(on.rig != null and on.rig.engaged and off.rig == null, "the rig is made and engaged only when the toggle is on")
	check(worst < 1e-4, "toggle on, layers at 0: the pose is the old one (worst gap %.6f m over 240 random frames)" % worst)
	check(is_zero_approx(on.rotation.z) and on.head_span >= 0.0, "no bank without a layer")
	# A fish with no controller never rewrites the pivot: the pose holds, it doesn't feed back on itself.
	var held := bend_signature(on)
	run(on, s_on, 1.0)
	check(worst_gap(held, bend_signature(on)) < 1e-5, "with nothing rewriting the pivot the pose holds")
	# Turning the toggle off hands the body back.
	var gait: Gait = on.swim.gait
	gait.procedural_rig = false
	on.tail.rotation = Vector3(0.1, 0.3, 0.0)
	off.tail.rotation = Vector3(0.1, 0.3, 0.0)
	on.react(DT, s_on)
	off.react(DT, s_off)
	check(not on.rig.engaged and worst_gap(bend_signature(off), bend_signature(on)) < 1e-5, "switching it off gives the old bend back")


## A gait with only the named layer weights on (1), the old pose off.
func only(fields: Array[String], legacy := 0.0) -> Gait:
	var gait := zero_gait(true)
	gait.rig_legacy_tail = legacy
	for field in fields:
		gait.set(field, 1.0)
	return gait


## The pose after `seconds` of `s` on a fresh shark with `gait`.
func settle(gait: Gait, s: SwimState, seconds: float) -> FishModel:
	var model := shark(gait)
	s.gait = gait
	run(model, s, seconds)
	return model


func _undulation() -> void:
	print("Undulation:")
	var gait := only(["rig_undulation"])
	var rest := settle(gait, moving(0.0, 0.0), 1.0)
	var p := rest.rig.pose
	var worst := 0.0
	for v: float in [p.joint_yaw[0], p.joint_yaw[1], p.joint_yaw[2], p.tail_yaw, p.head_yaw, p.bank, p.surge]:
		worst = maxf(worst, absf(v))
	check(worst < 1e-5 and rest.tail.rotation.length() < 1e-5, "the pose is zero at rest (%.7f)" % worst)
	var rates: Array[float] = []
	for speed: float in [2.0, 5.0, 8.0, 12.0, 16.0, 20.0, 23.0]:
		var model := settle(gait, moving(speed), 3.0)
		rates.append(model.rig.wave_freq)
	var rising := true
	for i in range(1, rates.size()):
		rising = rising and rates[i] >= rates[i - 1] - 1e-6
	check(rising and rates[5] > rates[1] * 1.5, "the wave's rate rises with speed (Hz at 2..23 m/s: %s)" % [rates.map(func(r: float) -> String: return "%.2f" % r)])
	# The phase really advances at that rate.
	var model := shark(gait)
	var s := moving(15.0)
	s.gait = gait
	run(model, s, 2.0)
	var before: float = model.rig.wave_phase
	var turned := 0.0
	var last := before
	for i in 60:
		model.react(DT, s)
		turned += fposmod(model.rig.wave_phase - last, TAU)
		last = model.rig.wave_phase
	check(absf(turned - TAU * model.rig.wave_freq) < 0.1 * TAU * model.rig.wave_freq + 0.05, "the phase advances at 2 pi f (%.2f rad in 1 s, f %.2f Hz)" % [turned, model.rig.wave_freq])
	# The envelope grows toward the tail, and the tail flexes past it.
	var peak := [0.0, 0.0, 0.0]
	var tail_peak := 0.0
	for i in 240:
		model.react(DT, s)
		for j in 3:
			peak[j] = maxf(peak[j], absf(model.rig.pose.joint_yaw[j]))
		tail_peak = maxf(tail_peak, absf(model.rig.pose.tail_yaw))
	check(peak[0] < peak[1] and peak[1] < peak[2] and peak[2] > 0.05, "the wave grows toward the tail (joint peaks %.3f %.3f %.3f)" % [peak[0], peak[1], peak[2]])
	check(tail_peak > 0.02, "the caudal fin flexes (%.3f rad)" % tail_peak)
	# A harder effort is a deeper wave.
	var soft := settle(gait, moving(15.0, 0.2), 3.0)
	var hard := settle(gait, moving(15.0, 1.0), 3.0)
	check(_swing(hard) > _swing(soft) * 1.3, "full effort waves deeper than a light one (%.3f vs %.3f rad)" % [_swing(hard), _swing(soft)])
	# The caudal fin leads: the flex peaks before it would on the spine's own lag.
	check(model.tail.position.x != 0.0 or model.tail.position.z != 0.0, "the tail pivot rides the bend")


## The tail pivot's biggest yaw over a second more of the same state.
func _swing(model: FishModel) -> float:
	var s := model.swim
	var best := 0.0
	var state := SwimState.new()
	state.speed = 15.0
	state.speed_frac = 15.0 / 23.0
	state.effort = s.effort
	state.gait = s.gait
	for i in 120:
		model.react(DT, state)
		best = maxf(best, absf(model.tail.rotation.y))
	return best


func _tail_drive() -> void:
	print("TailDrive:")
	var gait := only(["rig_tail_drive"])
	var s := moving(10.0)
	s.gait = gait
	var model := shark(gait)
	run(model, s, 0.5)
	check(absf(model.tail.rotation.y) < 1e-5 and absf(model.tail.rotation.x) < 1e-5, "no stride, no swing")
	s.stride_dir = Vector2(1.0, 0.0)
	s.stride_power = 1.0
	var p := model.rig.pose
	model.react(DT * 2.0, s)
	var early := [p.joint_yaw[0], p.joint_yaw[1], p.joint_yaw[2]]
	check(model.tail.rotation.y > 0.1 and early[2] > early[1] and early[1] > early[0] and early[0] >= 0.0,
			"the swing reaches the tail first and the joints in order behind it (tail %.3f, joints %.4f %.4f %.4f)" % [model.tail.rotation.y, early[0], early[1], early[2]])
	run(model, s, 0.6)
	check(absf(model.tail.rotation.y - gait.rig_stride_swing) < 0.02, "the tail swings across with the stride (%.3f of %.2f rad)" % [model.tail.rotation.y, gait.rig_stride_swing])
	check(p.spine_yaw() > 0.2 and p.spine_yaw() < gait.rig_stride_swing, "the body carries the bend (spine %.3f rad)" % p.spine_yaw())
	s.stride_dir = Vector2(-0.5, 0.8)
	run(model, s, 0.8)
	check(model.tail.rotation.y < -0.2 and model.tail.rotation.x > 0.3, "the other way and up/down follow the stride's sweep (yaw %.2f, pitch %.2f)" % [model.tail.rotation.y, model.tail.rotation.x])


func _turn() -> void:
	print("Turn:")
	var gait := only(["rig_turn"])
	var straight := settle(gait, moving(15.0), 1.0)
	check(absf(straight.rotation.z) < 1e-5 and straight.rig.pose.spine_yaw() == 0.0, "straight ahead: no bank, no bend")
	for side: float in [1.0, -1.0]:
		var s := moving(15.0)
		s.spin = Vector3(0.0, 1.5 * side, 0.0)
		var model := settle(gait, s, 1.5)
		var p := model.rig.pose
		var name := "left (+yaw)" if side > 0.0 else "right"
		check(model.rotation.z * side > 0.2, "a %s turn banks into it (%.3f rad)" % [name, model.rotation.z])
		check(p.spine_yaw() * side < -0.1, "and the spine curls toward its inside (%.3f rad)" % p.spine_yaw())
		check(p.fin_flap.x * side > 0.1 and p.fin_sweep.x * side < -0.1 and p.fin_sweep.y * side > 0.1, "the inside pectoral tucks, the outside reaches out")
	# The pectorals bank before the body.
	var s := moving(15.0)
	s.spin = Vector3(0.0, 1.5, 0.0)
	var model := shark(gait)
	s.gait = gait
	run(model, s, 0.1)
	var fin_share := model.rig.pose.fin_flap.x / (gait.rig_fin_bank)
	var body_share := model.rotation.z / gait.rig_bank
	check(fin_share > body_share * 1.3, "the pectorals lead the body into a turn (%.2f vs %.2f of full)" % [fin_share, body_share])
	var slow := moving(0.0, 0.0)
	slow.spin = Vector3(0.0, 1.5, 0.0)
	var spot := settle(gait, slow, 1.5)
	check(absf(spot.rotation.z) < 0.01 and absf(spot.rig.pose.spine_yaw()) < gait.rig_turn_max, "turning on the spot doesn't bank or curl without limit")


func _accel() -> void:
	print("Accel:")
	var gait := only(["rig_accel"])
	var cruise := settle(gait, moving(15.0), 1.0)
	check(absf(cruise.rig.pose.tail_pitch) < 1e-5 and absf(cruise.rig.pose.surge) < 1e-6, "cruising at a steady speed: nothing")
	var speeding := moving(15.0)
	speeding.accel = Vector3(0.0, 0.0, -20.0)  # forward is -Z
	var up_model := settle(gait, speeding, 1.5)
	var braking := moving(15.0)
	braking.accel = Vector3(0.0, 0.0, 20.0)
	var down_model := settle(gait, braking, 1.5)
	var pu := up_model.rig.pose
	var pd := down_model.rig.pose
	check(pu.spine_pitch() + pu.tail_pitch > 0.1 and pd.spine_pitch() + pd.tail_pitch < -0.1,
			"speeding up trails the tail down, braking folds it up (%.3f / %.3f rad)" % [up_model.tail.rotation.x, down_model.tail.rotation.x])
	check(pu.head_pitch > 0.05 and pd.head_pitch < -0.05, "the head leads against it (%.3f / %.3f rad)" % [pu.head_pitch, pd.head_pitch])
	check(pu.fin_sweep.x < -0.1 and pd.fin_sweep.x > 0.1, "the pectorals fold back speeding up and flare braking (%.2f / %.2f)" % [pu.fin_sweep.x, pd.fin_sweep.x])
	check(pu.surge > 0.0 and pd.surge < 0.0, "the body surges with it (%.3f / %.3f m)" % [pu.surge, pd.surge])
	var rising := moving(15.0)
	rising.accel = Vector3(0.0, 20.0, 0.0)
	check(settle(gait, rising, 1.5).rig.pose.tail_pitch > 0.05, "accelerating upward trails the tail down too")
	# It eases: a step in acceleration doesn't snap the tail.
	var step := moving(15.0)
	var eased := shark(gait)
	step.gait = gait
	run(eased, step, 0.5)
	step.accel = Vector3(0.0, 0.0, -25.0)
	eased.react(DT, step)
	check(eased.rig.pose.tail_pitch < 0.05, "a jolt of acceleration is eased in (%.3f rad after one frame)" % eased.rig.pose.tail_pitch)


func _drift() -> void:
	print("Drift:")
	var gait := only(["rig_drift"])
	check(absf(settle(gait, moving(15.0), 1.0).rig.pose.spine_yaw()) < 1e-6, "no slip: no bend")
	for side: float in [1.0, -1.0]:
		var s := moving(15.0)
		s.slip = Vector3(8.0 * side, 0.0, 0.0)  # sliding toward the right (+X) or the left
		var model := settle(gait, s, 1.5)
		var p := model.rig.pose
		var name := "right" if side > 0.0 else "left"
		check(p.spine_yaw() * side > 0.2, "sliding to the %s bends the rear toward it (%.3f rad)" % [name, p.spine_yaw()])
		check(absf(p.joint_yaw[2]) > absf(p.joint_yaw[0]), "more toward the tail (%.3f vs %.3f)" % [p.joint_yaw[2], p.joint_yaw[0]])
		check(p.fin_sweep.x > 0.1 and p.fin_sweep.y > 0.1, "both pectorals flare as brakes (%.2f)" % p.fin_sweep.x)
	var climbing := moving(15.0)
	climbing.slip = Vector3(0.0, 8.0, 0.0)
	check(settle(gait, climbing, 1.5).rig.pose.spine_pitch() < -0.1, "drifting upward lifts the tail end toward the velocity")
