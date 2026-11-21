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
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		record = record or arg == "--record"
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	_run.call_deferred()


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
	await _frames(5)
	main.set_environment("Ocean")
	await _frames(5)
	var results := {}
	for key: String in FORMS:
		if only != "" and key != only:
			continue
		var node := _dress(key)
		_check(node != null, "%s: dressed (%s)" % [key, FORMS[key]])
		if node == null:
			continue
		fish.global_position = main._environment.spawn_transform().origin + Vector3(0.0, 40.0, 0.0)
		await _frames(10)
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


## Hook for the rig-on checks (below).
func _extra(_key: String, _node: Node, _results: Dictionary) -> void:
	pass


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
