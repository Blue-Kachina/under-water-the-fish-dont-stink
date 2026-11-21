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
	return []


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
