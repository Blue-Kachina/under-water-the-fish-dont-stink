## Hunter rig convergence (planning_core_roadmap.md 2.4): the spine forms' private speed estimates and wave clocks
## (King, Lamprey, Angel, Gulper, Lantern) can be driven by the shared SwimState through a TrailAdapter, behind
## Gait.trail_rig (default off).
##  - rig-off identity: each converted form, dressed as a match dresses it and driven through a scripted run (still,
##    cruise, a turn at speed, coast), reads the same as tests/fixtures/trail_rig_baseline.json (recorded from the code
##    before the adapter existed): wave clock, wave size, speed estimates, spine points. No adapter is built.
##  - rig on: the adapter exists, takes its speed and turn from the SwimState, the wave clock runs faster with speed,
##    nothing is NaN, and switching it off again hands the body back.
## Needs a fixed frame time so the process delta is repeatable:
##   Godot_console.exe --headless --fixed-fps 60 --path . res://tests/trail_rig_probe.tscn [-- --record] [-- --only=KEY]
extends Node

const BASELINE := "res://tests/fixtures/trail_rig_baseline.json"
const FORMS := {"king_of_herrings": "KingRig", "lamprey_queen": "LampreyRig", "fallen_angel": "Angel",
		"gulper_mother": "Gulper", "lantern_angler": "LanternRig"}
## Fields read off a form's node when it has them.
const FIELDS := ["_speed", "_wave_clock", "_wave", "speed_frac", "_speed_t", "_tail_phase", "beat_clock"]
const PHASES := [[30, 0.0, 0.0], [90, 8.0, 0.0], [90, 20.0, 1.0], [30, 0.0, 0.0]]  # frames, speed, turn rad/s
const SAMPLE_EVERY := 15

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var record := false
var only := ""
var _drive := false
var _start := Transform3D.IDENTITY
var _frame := 0
var _speed := 0.0
var _turn := 0.0
var _heading := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		record = record or arg == "--record"
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	_run.call_deferred()


## A fresh game for each form: what one form's run leaves in the fish (its smoothing, its old body) must not reach the next.
func _fresh_main() -> void:
	if main != null:
		main.queue_free()
		await get_tree().process_frame
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _frames(5)
	main.set_environment("Ocean")
	await _frames(5)


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _physics_process(delta: float) -> void:
	if not _drive:
		return
	_heading += _turn * delta
	var basis := Basis(Vector3.UP, -_heading)
	var forward := -basis.z
	fish.global_transform = Transform3D(basis, _start.origin + _pos)
	fish.linear_velocity = forward * _speed
	fish.angular_velocity = Vector3(0.0, -_turn, 0.0)


var _pos := Vector3.ZERO


func _dress(key: String) -> Node:
	var form := HunterForm.sheet(key)
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().size_mult = 1.0
	HunterSize.shared().apply(fish, form)
	HunterForms.dress(fish, key)
	return fish._visual.get_node_or_null(FORMS[key])


## Every course starts from the same place, at rest.
## A fresh game with the form dressed and the fish settled: the node of its body.
func _start_form(key: String) -> Node:
	await _fresh_main()
	await _settle()
	var node := _dress(key)
	await _settle()
	return node


func _settle() -> void:
	fish.global_transform = Transform3D(Basis.IDENTITY, main._environment.spawn_transform().origin + Vector3(0.0, 40.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	await _frames(20)


func _sample(node: Node) -> Dictionary:
	var row := {}
	for f in FIELDS:
		var v: Variant = node.get(f)
		if v is float:
			row[f] = v
	var skin: Variant = node.get("skin")
	if skin is ShaderMaterial:
		row["wave_clock"] = float((skin as ShaderMaterial).get_shader_parameter("wave_clock"))
		var sw: Variant = (skin as ShaderMaterial).get_shader_parameter("spine_wave")
		if sw is Vector4:
			row["spine_wave_x"] = sw.x
	var rig: Variant = node.get("rig")
	if rig is SpineRig:
		for i in [8, 24, 47]:
			var p: Vector3 = (rig as SpineRig).points[i]
			row["p%d" % i] = [p.x, p.y, p.z]
	var tr: Variant = node.get("_adapter")
	if tr is TrailAdapter:
		row["tclock"] = (tr as TrailAdapter).clock
		row["tspeed"] = (tr as TrailAdapter).speed
	var model: Variant = node.get("model")
	if model != null and model.get("tail_bend") is float:
		row["tail_bend"] = model.get("tail_bend")
	return row


## Runs the scripted course for `node` and returns the samples.
func _course(node: Node) -> Array:
	var rows: Array = []
	_start = fish.global_transform
	_heading = 0.0
	_pos = Vector3.ZERO
	_frame = 0
	_drive = true
	for phase: Array in PHASES:
		_speed = phase[1]
		_turn = phase[2]
		for i in int(phase[0]):
			var basis := Basis(Vector3.UP, -_heading)
			_pos += -basis.z * _speed * (1.0 / 60.0)
			await get_tree().physics_frame
			_frame += 1
			if _frame % SAMPLE_EVERY == 0:
				rows.append(_sample(node))
	_drive = false
	return rows


func _run() -> void:
	var results := {}
	for key: String in FORMS:
		if only != "" and key != only:
			continue
		var node := await _start_form(key)  # dressed from the same place every time: a form's first frames read the jump from where it was
		_check(node != null, "%s: dressed (%s)" % [key, FORMS[key]])
		if node == null:
			continue
		results[key] = await _course(node)
		await _extra(key, node, results)
	if record:
		var out := FileAccess.open(ProjectSettings.globalize_path(BASELINE), FileAccess.WRITE)
		out.store_string(JSON.stringify(results, "\t", true))
		out.close()
		print("  baseline recorded (%d forms)" % results.size())
	else:
		_compare(results)
	print("trail_rig_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## The rig-on checks for one form: off-run rows are in `results[key]`.
func _extra(key: String, node: Node, results: Dictionary) -> void:
	if record:
		return
	var gait := fish.gait
	_check(not gait.trail_rig and gait.trail_pose == 0.0, "%s: Gait.trail_rig defaults off, trail_pose 0" % key)
	_check(node.get("_adapter") == null, "%s: rig off builds no adapter" % key)
	var off: Array = results[key]
	gait.trail_rig = true
	node = await _start_form(key)
	var on: Array = await _course(node)
	_check(node.get("_adapter") is TrailAdapter, "%s: rig on builds the adapter" % key)
	var finite := true
	for row: Dictionary in on:
		var flat := {}
		_flatten(row, "", flat)
		for k: String in flat:
			finite = finite and is_finite(flat[k])
	_check(finite, "%s: rig on, every value finite" % key)
	# The adapter's speed follows the SwimState: still at the start, near the run's speed at the end of the cruise.
	var still: float = on[1]["tspeed"]
	var cruise: float = on[5]["tspeed"]
	_check(still < 1.0 and cruise > 4.0 and cruise < 12.0, "%s: adapter speed follows the state (%.2f still, %.2f cruising at 8)" % [key, still, cruise])
	# The wave clock runs faster at speed than still.
	var slow := fposmod(float(on[1]["tclock"]) - float(on[0]["tclock"]), TAU)
	var fast := fposmod(float(on[9]["tclock"]) - float(on[8]["tclock"]), TAU)
	_check(fast > slow * 1.2, "%s: the shared wave clock runs faster at speed (%.2f vs %.2f rad per sample)" % [key, fast, slow])
	# With trail_pose 0 the adapter's bend leaves the spine's points exactly as the form laid them.
	if node.get("rig") is SpineRig:
		var spine := node.get("rig") as SpineRig
		var before := spine.points.duplicate()
		(node.get("_adapter") as TrailAdapter).bend(spine, 1.0 / 60.0, 10.0)
		_check(before == spine.points, "%s: rig on with trail_pose 0 leaves the spine points as the form laid them" % key)
	if node.get("rig") is SpineRig and key != "lantern_angler":
		gait.trail_pose = 1.0
		node = await _start_form(key)
		var posed: Array = await _course(node)
		var moved := 0.0
		var pose_finite := true
		for i in posed.size():
			var a: Array = posed[i]["p47"]
			var b: Array = on[i]["p47"]
			moved = maxf(moved, (Vector3(a[0], a[1], a[2]) - Vector3(b[0], b[1], b[2])).length())
			pose_finite = pose_finite and is_finite(a[0]) and is_finite(a[1]) and is_finite(a[2])
		_check(pose_finite and moved > 0.01, "%s: trail_pose 1 bends the spine (tail point moved up to %.2f m), finite" % [key, moved])
		var spacing := _spacing_ok(node.get("rig") as SpineRig)
		_check(spacing, "%s: the bent spine keeps its segment lengths" % key)
	gait.trail_pose = 0.0
	gait.trail_rig = false
	await _frames(3)
	_check(node.get("_adapter") == null, "%s: switching off drops the adapter" % key)


func _spacing_ok(spine: SpineRig) -> bool:
	var first := spine.points[1].distance_to(spine.points[0])
	for i in range(2, SpineRig.SPINE_N):
		var d := spine.points[i].distance_to(spine.points[i - 1])
		if absf(d - first) > maxf(first * 0.35, 0.02):
			return false
	return true


func _flatten(v: Variant, prefix: String, out: Dictionary) -> void:
	if v is Array:
		for i in v.size():
			_flatten(v[i], "%s[%d]" % [prefix, i], out)
	elif v is Dictionary:
		for k in v:
			_flatten(v[k], "%s.%s" % [prefix, k], out)
	else:
		out[prefix] = float(v)


func _compare(results: Dictionary) -> void:
	if not FileAccess.file_exists(BASELINE):
		_check(false, "no baseline at %s (run with --record)" % BASELINE)
		return
	var want: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	for key: String in results:
		var a := {}
		var b := {}
		_flatten(want.get(key, []), "", a)
		_flatten(results[key], "", b)
		var worst := 0.0
		var where := ""
		for k: String in b:
			if not a.has(k):
				worst = INF
				where = k
				break
			var d := absf(a[k] - b[k])
			if d > worst:
				worst = d
				where = k
		_check(a.size() == b.size() and worst <= 2e-3, "%s: rig off reads as recorded (%d values, worst gap %.5f at %s)" % [key, b.size(), worst, where])
