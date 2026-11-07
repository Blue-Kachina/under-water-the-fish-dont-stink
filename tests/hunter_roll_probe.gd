## What Stinks?: every ready Hunter form's model rolls with its body under air roll.
## Per form: dressed as a match dresses it, placed mid-water, air roll held with the
## stick full right for 2 s, held in place and then swimming. Each frame the body's
## roll and the model's roll (the up of what's drawn: a spine rig's head frame, turned
## back from the spine's way onto the fish's, else the model node's) are summed; the
## model should follow the body, without jumps.
##   --only=KEY just that form; --trace prints every frame.
## Run headless: Godot_console.exe --headless --path . res://tests/hunter_roll_probe.tscn
extends Node

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var _sampling := false
var _body_roll := 0.0
var _model_roll := 0.0
var _worst_gap := 0.0
var _worst_jump := 0.0
var _last_body_up := Vector3.ZERO
var _last_model_up := Vector3.ZERO
var _pinned_at := Vector3.INF  # held here (sinking would trail a spine body straight up)
var _trace := false  # --trace: every frame's roll
var _only := ""  # --only=KEY: just that form


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	await _frames(5)
	main.set_environment("Ocean")
	await _frames(5)
	for arg in OS.get_cmdline_user_args():
		_trace = _trace or arg == "--trace"
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	for key: String in HunterForms.ready_keys():
		if _only != "" and key != _only:
			continue
		await _form(key, 0.0)
		await _form(key, 1.0)
	print("hunter_roll_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _place() -> void:
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 40.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


## The up of what's drawn, in world space.
func _model_up() -> Vector3:
	var visual: Node3D = fish._visual
	for child in visual.get_children():
		var spine = child.get("rig")
		if spine is SpineRig and (child as Node3D).visible:
			var rig := spine as SpineRig
			var head := rig.frame_at(0.0).basis
			# King and Lamprey bodies are top_level (their spine is in world space); Angel and Gulper ride the model.
			if not (rig.instances.size() > 0 and rig.instances[0].top_level):
				head = (child as Node3D).global_basis.orthonormalized() * head
			var back := head.z.normalized()
			var want := fish.global_basis.z.normalized()
			return (Quaternion(back, want) * head.y).normalized() if back.dot(want) > -0.999 else head.y
	return visual.global_basis.orthonormalized().y


func _physics_process(_delta: float) -> void:
	if _pinned_at != Vector3.INF:
		fish.global_position = _pinned_at
		fish.linear_velocity = Vector3.ZERO


func _process(_delta: float) -> void:
	if not _sampling:
		return
	var forward := -fish.global_basis.z.normalized()
	var body_up := fish.global_basis.orthonormalized().y
	var model_up := _model_up()
	if _last_body_up != Vector3.ZERO:
		_body_roll += _last_body_up.signed_angle_to(body_up, forward)
		var step := _last_model_up.signed_angle_to(model_up, forward)
		_model_roll += step
		_worst_jump = maxf(_worst_jump, absf(step))
		if OS.get_cmdline_user_args().has("--trace"):
			var kr: Node = fish._visual.get_node_or_null("KingRig")
			print("    body %.0f model %.0f step %.1f  up %s model_up %s head_up %s ups0 %s twist %.2f vis_rot %s pts %s %s" % [rad_to_deg(_body_roll), rad_to_deg(_model_roll), rad_to_deg(step), body_up, model_up, kr.rig.head_up, kr.rig.ups[0], kr.rig.twist, fish._visual.rotation, kr.rig.points[0], kr.rig.points[1]])
	_worst_gap = maxf(_worst_gap, body_up.angle_to(model_up))
	_last_body_up = body_up
	_last_model_up = model_up


func _form(key: String, thrust: float) -> void:
	var tag := "%s %s" % [key, "swimming" if thrust > 0.0 else "still"]
	var form := HunterForm.sheet(key)
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().size_mult = 1.0
	HunterSize.shared().apply(fish, form)
	HunterForms.dress(fish, key)
	_place()
	if thrust == 0.0:
		_pinned_at = fish.global_position
	await _frames(10)
	var input := FishInput.new()
	fish.controls = input
	input.air_roll = true
	input.forward = thrust
	input.stick = Vector2(1.0, 0.0)
	_body_roll = 0.0
	_model_roll = 0.0
	_worst_gap = 0.0
	_worst_jump = 0.0
	_last_body_up = Vector3.ZERO
	_sampling = true
	await get_tree().create_timer(2.0).timeout
	_sampling = false
	_pinned_at = Vector3.INF
	fish.controls = null
	print("  %s: body rolled %.0f deg, model %.0f deg, widest gap %.0f deg, biggest frame jump %.1f deg" % [tag, rad_to_deg(_body_roll), rad_to_deg(_model_roll), rad_to_deg(_worst_gap), rad_to_deg(_worst_jump)])
	_check(absf(_body_roll) > PI, "%s: the body rolls (%.0f deg)" % [tag, rad_to_deg(_body_roll)])
	_check(absf(_model_roll - _body_roll) < deg_to_rad(30.0), "%s: the model rolls with it (%.0f vs %.0f deg)" % [tag, rad_to_deg(_model_roll), rad_to_deg(_body_roll)])
	_check(_worst_jump < deg_to_rad(10.0), "%s: without a snap (biggest frame jump %.1f deg)" % [tag, rad_to_deg(_worst_jump)])
	_check(_worst_gap < deg_to_rad(35.0), "%s: and stays on it (widest gap %.0f deg)" % [tag, rad_to_deg(_worst_gap)])
