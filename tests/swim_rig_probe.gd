extends Node
## The procedural rig (SwimRig, planning_core_roadmap.md 2.2/2.3, P2 to P4 on the shark, P5 on the Drowned Shark form,
## the clownfish and the swordfish: every block below runs once per rolled-out class), on bare models stepped by
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

## The classes with a rig (P5): the shark first, then the rest.
const CLASSES := [FishCharacter.FishClass.HUNTER, FishCharacter.FishClass.MONSTER, FishCharacter.FishClass.SKIRMISHER, FishCharacter.FishClass.LANCER,
		FishCharacter.FishClass.CHARMER, FishCharacter.FishClass.BULWARK, FishCharacter.FishClass.SCORCHER, FishCharacter.FishClass.BREACHER,
		FishCharacter.FishClass.GLIDER, FishCharacter.FishClass.BRAWLER]

var failures := 0
## The class the blocks below build (set by _run, one pass each).
var fish_class := FishCharacter.FishClass.HUNTER


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


## A model of the class under test (a great white first), in the tree, with the gait given.
func shark(gait: Gait) -> FishModel:
	var model := FishModel.build(fish_class, 0)
	add_child(model)
	model.swim.gait = gait
	return model


## The class's gait: the rig on with every layer weight at 0 and the old pose kept (the zero-change state).
func zero_gait(on := true) -> Gait:
	var gait := GaitSettings.default_for(fish_class)
	gait.procedural_rig = on
	gait.rig_bell_flap = false  # its own probe (rig_rest_probe); on by default, it makes a rig too
	gait.rig_legacy_tail = 1.0
	for field: String in layer_fields():
		gait.set(field, 0.0)
	return gait


## The Gait's layer weights, in layer order (each step adds its own).
func layer_fields() -> Array[String]:
	var fields: Array[String] = ["rig_undulation", "rig_tail_drive", "rig_turn", "rig_accel", "rig_drift", "rig_fin_stabilizer", "rig_idle",
			"rig_wing_beat"]
	return fields


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
	_defaults()
	for rigged: FishCharacter.FishClass in CLASSES:
		fish_class = rigged
		print("=== %s ===" % FishCharacter.CLASSES[rigged]["key"])
		_blocks()
	fish_class = FishCharacter.FishClass.HUNTER
	_differences()
	_bench()
	print("swim_rig_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _blocks() -> void:
	_zero_change()
	_undulation()
	_tail_drive()
	_turn()
	_accel()
	_drift()
	_fin_stabilizer()
	_idle()
	_wing_beat()
	_stride_cue()
	_soak()


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
			peak[j] = maxf(peak[j], maxf(absf(model.rig.pose.joint_yaw[j]), absf(model.rig.pose.joint_pitch[j])))
		tail_peak = maxf(tail_peak, maxf(absf(model.rig.pose.tail_yaw), absf(model.rig.pose.tail_pitch)))
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
		best = maxf(best, maxf(absf(model.tail.rotation.y), absf(model.tail.rotation.x)))
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
		check(model.rotation.z * side > 0.5 * gait.rig_bank, "a %s turn banks into it (%.3f rad)" % [name, model.rotation.z])
		check(p.spine_yaw() * side < -0.01, "and the spine curls toward its inside (%.3f rad)" % p.spine_yaw())
		check(p.fin_flap.x * side > 0.5 * gait.rig_fin_bank and p.fin_sweep.x * side < -0.5 * gait.rig_fin_tuck and p.fin_sweep.y * side > 0.5 * gait.rig_fin_tuck,
				"the inside pectoral tucks, the outside reaches out (flap %.3f, sweep %.3f)" % [p.fin_flap.x, p.fin_sweep.x])
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
	if gait.rig_accel_head > 0.0:
		check(pu.head_pitch > 0.05 * gait.rig_accel_head / 0.2 and pd.head_pitch < -0.05 * gait.rig_accel_head / 0.2, "the head leads against it (%.3f / %.3f rad)" % [pu.head_pitch, pd.head_pitch])
	else:
		check(pu.head_pitch == 0.0 and pd.head_pitch == 0.0, "a class with a rigid head keeps it still (%.3f rad)" % pu.head_pitch)
	check(pu.fin_sweep.x < -0.1 and pd.fin_sweep.x > 0.1, "the pectorals fold back speeding up and flare braking (%.2f / %.2f)" % [pu.fin_sweep.x, pd.fin_sweep.x])
	if gait.rig_accel_surge > 0.0:
		check(pu.surge > 0.0 and pd.surge < 0.0, "the body surges with it (%.3f / %.3f m)" % [pu.surge, pd.surge])
	else:
		check(pu.surge == 0.0 and pd.surge == 0.0, "a class with a rigid shell does not surge")
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


func _fin_stabilizer() -> void:
	print("FinStabilizer:")
	var gait := only(["rig_fin_stabilizer"])
	var still := settle(gait, moving(0.0, 0.0), 1.0)
	check(absf(still.rig.pose.fin_flap.x) < 1e-5 and absf(still.rig.pose.fin_pitch.x) < 1e-5, "at rest the fins hold still")
	var rolling := moving(15.0)
	rolling.spin = Vector3(0.0, 0.0, 1.0)  # rolling to its left
	var p := settle(gait, rolling, 1.0).rig.pose
	check(p.fin_flap.x < 0.0 or p.fin_flap.y > 0.0, "rolling left, the ailerons answer against it (flaps %.3f / %.3f)" % [p.fin_flap.x, p.fin_flap.y])
	var counter := (p.fin_flap.y - p.fin_flap.x) * 0.5
	check(counter > 0.05, "left fin up, right fin down (%.3f)" % counter)
	var pitching := moving(15.0)
	pitching.spin = Vector3(1.0, 0.0, 0.0)  # the nose rising
	check(settle(gait, pitching, 1.0).rig.pose.fin_pitch.x < -0.05, "a nose-up rate drops the leading edges")
	var climbing := moving(15.0)
	climbing.slip = Vector3(0.0, 6.0, 0.0)
	check(settle(gait, climbing, 1.0).rig.pose.fin_pitch.x > 0.05, "a climb trims the fins")
	# Flutter: amplitude follows speed, and the layer's own clock keeps it moving.
	var amps: Array[float] = []
	for speed: float in [3.0, 23.0]:
		var model := settle(gait, moving(speed), 0.3)
		var s := model.swim
		var best := 0.0
		for i in 60:
			model.react(DT, s)
			best = maxf(best, absf(model.rig.pose.fin_flap.x))
		amps.append(best)
	if gait.rig_fin_flutter > 0.0:
		check(amps[1] > amps[0] * 3.0 and amps[1] > 0.03, "the pectorals flutter more at speed (%.3f vs %.3f rad)" % [amps[1], amps[0]])
	else:
		check(amps[1] < 1e-6, "a class with no flutter (the mantis's claws) keeps its fins still at speed (%.4f rad)" % amps[1])


func _defaults() -> void:
	print("the toggle:")
	var any_on := true
	for fc: FishCharacter.FishClass in FishCharacter.FishClass.values():
		any_on = any_on and GaitSettings.default_for(fc).procedural_rig
	check(any_on, "procedural_rig is on by default (core roadmap defaults, 2026-11-21)")
	var capable := true
	var others_not := true
	for fc: FishCharacter.FishClass in FishCharacter.FishClass.values():
		var has := FishModel.build(fc, 0).rig_capable
		if fc in CLASSES:
			capable = capable and has
		else:
			others_not = others_not and not has
	check(capable and others_not, "only the rolled-out classes (shark, Drowned Shark form, clownfish, swordfish, koi, boxfish, lionfish, whale calf, ray, mantis) can have a rig")
	check(GaitSettings.shared().for_class(FishCharacter.FishClass.MONSTER).rig_undulation == 1.0, "the Drowned Shark form's gait has the layers on (the toggle waits)")


## P5: a class is a parameter set on the same layers: the clownfish and the swordfish differ from the shark in numbers, not code.
func _differences() -> void:
	print("per-class parameter sets:")
	var shark_gait := GaitSettings.default_for(FishCharacter.FishClass.HUNTER)
	var monster := GaitSettings.default_for(FishCharacter.FishClass.MONSTER)
	check(monster.rig_amplitude == shark_gait.rig_amplitude and monster.rig_strouhal == shark_gait.rig_strouhal, "the Drowned Shark form takes the shark's numbers")
	for rigged: FishCharacter.FishClass in CLASSES.slice(2):
		var g := GaitSettings.default_for(rigged)
		check(g.rig_amplitude != shark_gait.rig_amplitude and (g.rig_head_span != shark_gait.rig_head_span or g.rig_wave_lag != shark_gait.rig_wave_lag) and g.rig_undulation == 1.0,
				"%s has its own amplitude / head span (%.2f / %.2f) on the same layers" % [FishCharacter.CLASSES[rigged]["key"], g.rig_amplitude, g.rig_head_span])


func _idle() -> void:
	print("Idle:")
	var gait := only(["rig_idle"])
	var rest := settle(gait, moving(0.0, 0.0), 0.2)
	var peak := 0.0
	var fins := 0.0
	var s := rest.swim
	for i in 180:
		rest.react(DT, s)
		peak = maxf(peak, absf(rest.rig.pose.joint_yaw[2]))
		fins = maxf(fins, absf(rest.rig.pose.fin_flap.x))
	check(peak > 0.01 and peak < 0.2 and fins > 0.05, "at rest it hovers a little (tail joint %.3f rad, pectoral %.3f rad)" % [peak, fins])
	var fast := settle(gait, moving(10.0, 0.9), 0.5)
	var p := fast.rig.pose
	check(absf(p.joint_yaw[2]) < 1e-6 and absf(p.fin_flap.x) < 1e-6, "swimming (effort 0.9, 10 m/s) it's gone")
	var coasting := settle(gait, moving(1.5, 0.0), 0.5)
	var mid := 0.0
	for i in 180:
		coasting.react(DT, coasting.swim)
		mid = maxf(mid, absf(coasting.rig.pose.fin_flap.x))
	check(mid > 0.0 and mid < fins, "and fades out between (%.3f at 1.5 m/s, %.3f at rest)" % [mid, fins])


## The ray's wings (RigWingBeat, only for a class whose gait has it): a beat on the wave, a stride's downstroke and
## recovery, the far wing harder and the body rolling away from a sideways push, level on a surface; the skin takes it.
func _wing_beat() -> void:
	if GaitSettings.default_for(fish_class).rig_wing_beat <= 0.0:
		return
	print("Wing beat:")
	var gait := only(["rig_undulation", "rig_wing_beat"])
	var rest := settle(gait, moving(0.0, 0.0), 1.0)
	check(absf(rest.rig.pose.fin_flap.x) < 1e-5 and absf(rest.rig.pose.fin_flap.y) < 1e-5, "at rest, no stride: the wings hold still")
	var cruise := settle(gait, moving(12.0), 1.0)
	var high := -INF
	var low := INF
	var even := true
	for i in 180:
		cruise.react(DT, cruise.swim)
		var p := cruise.rig.pose
		high = maxf(high, p.fin_flap.x)
		low = minf(low, p.fin_flap.x)
		even = even and is_equal_approx(p.fin_flap.x, p.fin_flap.y)
	check(high > 0.05 and low < -0.05 and even, "cruising, both wings beat together on the wave (%.3f..%.3f rad)" % [low, high])
	var only_beat := only(["rig_wing_beat"])
	var model := shark(only_beat)
	var s := moving(12.0)
	s.gait = only_beat
	run(model, s, 0.5)
	s.stride_dir = Vector2(0.0, 0.0)
	var down := 0.0
	for i in 20:
		s.stride_power = minf(1.0, i / 10.0)
		model.react(DT, s)
		down = maxf(down, model.rig.pose.fin_flap.x)
	var up := 0.0
	for i in 40:
		s.stride_power = maxf(0.0, 1.0 - i / 12.0)
		model.react(DT, s)
		up = minf(up, model.rig.pose.fin_flap.x)
	check(down > 0.6 * only_beat.rig_wing_stride and up < -0.05, "a stride beats them down and they spring back up past level as it fades (%.3f / %.3f rad)" % [down, up])
	s.stride_dir = Vector2(1.0, 0.0)
	s.stride_power = 1.0
	run(model, s, 0.4)
	var p := model.rig.pose
	check(p.fin_flap.x > p.fin_flap.y + 0.1 and p.bank < -0.5 * only_beat.rig_wing_roll,
			"a sideways stride beats one wing harder and rolls the body (wings %.3f / %.3f, bank %.3f)" % [p.fin_flap.x, p.fin_flap.y, p.bank])
	s.grounded = true
	s.spin = Vector3(0.0, 1.5, 0.0)
	var grounded_gait := only(["rig_turn", "rig_wing_beat"])
	s.gait = grounded_gait
	var lying := shark(grounded_gait)
	run(lying, s, 1.5)
	check(absf(lying.rotation.z) < 0.02 and lying.rig.pose.fin_flap.x <= grounded_gait.rig_wing_ground + 1e-6,
			"on a surface it lies level, the tips out of the floor (bank %.3f, flap %.3f)" % [lying.rotation.z, lying.rig.pose.fin_flap.x])
	if model._skin != null:
		var flap := float(model._skin.get_shader_parameter("flap_left"))
		check(is_equal_approx(flap, -model.fin_left.rotation.z - model.rig.pose.fin_flap.x), "the skin's wings take the pose (flap_left %.3f)" % flap)


func _stride_cue() -> void:
	print("the stride cue:")
	var gait := only(layer_fields())
	var off := shark(zero_gait(false))
	var on := shark(gait)
	var s := moving(14.0)
	s.gait = gait
	s.stride_dir = Vector2(1.0, 0.0)
	s.stride_power = 0.8
	var s_off := moving(14.0)
	s_off.gait = off.swim.gait
	run(on, s, 0.5)
	run(off, s_off, 0.5)
	on.set_stride_cue(0.55, 0.9, 0.3)
	off.set_stride_cue(0.55, 0.9, 0.3)
	var ok := not on._tail_cue.is_empty() and on._tail_cue.size() == off._tail_cue.size()
	for part in on._tail_cue:
		ok = ok and is_equal_approx(float(part.get_instance_shader_parameter("stride_fill")), 0.55)
	check(ok, "the cue still reaches every tail mesh with the rig on (%d parts, fill 0.55)" % on._tail_cue.size())
	var same := true
	for i in on._tail_cue.size():
		var a := on._tail_cue[i].material_overlay as ShaderMaterial
		var b := off._tail_cue[i].material_overlay as ShaderMaterial
		if a != null and b != null:
			same = same and is_equal_approx(float(a.get_shader_parameter("root")), float(b.get_shader_parameter("root"))) \
					and is_equal_approx(float(a.get_shader_parameter("tip")), float(b.get_shader_parameter("tip")))
	check(same, "it still fills from the tail's root to its tip (the overlay's span is the rig-off one)")
	# The stride rides the wave amplitude as well: a stride deepens the wave.
	var calm := _excursion(0.0)
	var deep := _excursion(1.0)
	check(deep > calm * 1.2, "a stride deepens the wave over the whole body (spine swing %.3f rad with a full stride, %.3f without)" % [deep, calm])


## The spine's biggest total yaw over 2 s of the Undulation layer alone at 14 m/s with the given stride power.
func _excursion(power: float) -> float:
	var gait := only(["rig_undulation"])
	var s := moving(14.0)
	s.gait = gait
	s.stride_power = power
	var model := shark(gait)
	run(model, s, 1.5)
	var best := 0.0
	for i in 120:
		model.react(DT, s)
		best = maxf(best, maxf(absf(model.rig.pose.spine_yaw()), absf(model.rig.pose.spine_pitch())))
	return best


## 60 s of random states: a random walk through speed, effort, spin, slip, acceleration and strides, with now and then a
## teleport-sized jump, nothing NaN and the bend bounded.
func _soak() -> void:
	print("the soak:")
	var gait := only(layer_fields())
	var model := shark(gait)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var s := SwimState.new()
	s.gait = gait
	var bad := 0
	var worst := 0.0
	var speed := 5.0
	for i in 3600:
		speed = clampf(speed + rng.randf_range(-1.5, 1.5), 0.0, 23.0)
		if rng.randf() < 0.01:
			speed = rng.randf_range(0.0, 40.0)
		s.speed = speed
		s.speed_frac = minf(speed / 23.0, 1.0)
		s.effort = rng.randf()
		s.forward_speed = speed * rng.randf_range(0.7, 1.0)
		s.spin = Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(-6.0, 6.0), rng.randf_range(-3.0, 3.0))
		s.accel = Vector3(rng.randf_range(-60.0, 60.0), rng.randf_range(-60.0, 60.0), rng.randf_range(-80.0, 80.0))
		s.slip = Vector3(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0), 0.0)
		s.velocity = Vector3(s.slip.x, s.slip.y, -speed)
		s.stride_dir = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		s.stride_power = rng.randf()
		model.react(DT if rng.randf() > 0.02 else rng.randf_range(0.0, 0.3), s)
		var p := model.rig.pose
		var finite := p.is_finite_pose() and model.tail.position.is_finite() and model.tail.rotation.is_finite() \
				and model.bend_point(Vector3(0.1, 0.1, 1.0)).is_finite() and model.bend_point(Vector3(0.0, 0.0, -0.4)).is_finite()
		if not finite:
			bad += 1
		worst = maxf(worst, maxf(absf(p.spine_yaw()), absf(p.spine_pitch())))
	check(bad == 0, "no NaN or infinity in 3600 frames of random states and frame times (bad frames: %d)" % bad)
	check(worst < 4.0, "and the spine's bend stays bounded (worst total turn %.2f rad)" % worst)
	# Zero and negative frame times don't blow up either.
	model.react(0.0, s)
	model.react(-0.1, s)
	check(model.rig.pose.is_finite_pose(), "a zero or negative frame time is harmless")


## 50 sharks with every layer on, against the rig off and against the budget (planning_core_roadmap.md 2.2: 0.05 ms per
## fish per frame for the layers). The editor binary is slower than an export, so this is an upper bound.
func _bench() -> void:
	print("the cost (50 fish, 600 frames):")
	var on_gait := only(layer_fields())
	var off_gait := zero_gait(false)
	var fish_on: Array[FishModel] = []
	var fish_off: Array[FishModel] = []
	var states: Array[SwimState] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 50:
		fish_on.append(shark(on_gait))
		fish_off.append(shark(off_gait))
		var s := moving(rng.randf_range(2.0, 22.0))
		s.spin = Vector3(0.0, rng.randf_range(-2.0, 2.0), 0.0)
		s.accel = Vector3(rng.randf_range(-10.0, 10.0), 0.0, rng.randf_range(-10.0, 10.0))
		s.slip = Vector3(rng.randf_range(-4.0, 4.0), 0.0, 0.0)
		s.stride_dir = Vector2(rng.randf_range(-1.0, 1.0), 0.0)
		s.stride_power = rng.randf()
		states.append(s)
	var time := func(models: Array[FishModel], gait: Gait) -> float:
		for i in 50:
			states[i].gait = gait
		var start := Time.get_ticks_usec()
		for frame in 600:
			for i in 50:
				models[i].react(DT, states[i])
		return float(Time.get_ticks_usec() - start) / (600.0 * 50.0)
	time.call(fish_on, on_gait)
	time.call(fish_off, off_gait)
	var with_rig: float = time.call(fish_on, on_gait)
	var without: float = time.call(fish_off, off_gait)
	var layers_only := with_rig - without
	print("  react per fish: %.1f us with the rig, %.1f us without; the rig adds %.1f us" % [with_rig, without, layers_only])
	check(layers_only < 50.0, "the rig's layers cost under 0.05 ms per fish per frame (%.1f us)" % layers_only)
