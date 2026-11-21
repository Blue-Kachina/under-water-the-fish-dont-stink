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
	return ["rig_undulation"]


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
