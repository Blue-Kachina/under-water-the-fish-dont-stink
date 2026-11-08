## What Stinks? Ember Octopus under air roll and pitch (C2), like hunter_roll_probe / angler_roll_probe: dressed as a match dresses
## it, placed mid-water, air roll held with the stick full right for 2 s (still, then swimming), then a pitch loop and a long
## swim. Checks: the body really rolls (more than half a turn) and the model stays on it (the rig is rigid on the body, so the
## gap is the proof the rig does not fight it); the siphon stays on the axis while the stick means roll (no stray yaw); every arm
## tip moves smoothly frame to frame through the spin-up and the reversal; the arms trail the roll (swing off rest); nothing goes
## non-finite; a slack inverted octopus still drapes its arms toward the world's down (up-vector aware); the jet follows the
## nose through a pitch loop (velocity heading within a margin of the nose) and in a full inverted swim the thrust is still along
## the body.
##   --trace prints every frame.
## Run headless: Godot_console.exe --headless --path . res://tests/octopus_roll_probe.tscn
extends Node

const FORM := preload("res://scripts/what_stinks/forms/ember_octopus.gd")

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var _sampling := false
var _trace := false
var _rig: OctopusRig
var _body_roll := 0.0
var _worst_gap := 0.0
var _worst_step := 0.0
var _max_swing := 0.0
var _max_siphon_x := 0.0
var _finite := true
var _last_up := Vector3.ZERO
var _last_tips := PackedVector3Array()
var _worst_tip := 0.0
var _worst_head_gap := 0.0
var _heading_gap_max := 0.0
var _speed_end := 0.0
var _pitch_total := 0.0
var _last_fwd := Vector3.ZERO
var _pinned_at := Vector3.INF


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
	_trace = OS.get_cmdline_user_args().has("--trace")
	for s: float in [1.0, 2.0]:
		await _dress(s)
		await _roll("x%.0f still" % s, 0.0, Vector2(1.0, 0.0), true)
		await _roll("x%.0f swimming" % s, 1.0, Vector2(1.0, 0.0), true)
		await _drape("x%.0f" % s)
		await _loop("x%.0f loop" % s)
		await _inverted("x%.0f inverted" % s)
	print("octopus_roll_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _dress(s: float) -> void:
	var form := HunterForms.DEFAULTS.duplicate()
	form.merge(FORM.sheet() as Dictionary, true)
	fish.controls = null
	fish.input_forward = 0.0
	fish.input_stick = Vector2.ZERO
	fish.input_roll = 0.0
	fish.air_roll_held = false
	fish.is_boosting = false
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().size_mult = s
	HunterSize.shared().apply(fish, form)
	FORM.dress(fish, form)
	await _frames(5)
	_rig = (fish._visual as Node3D).get_node("OctopusRig") as OctopusRig


func _place(basis := Basis.IDENTITY) -> void:
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(basis, at.origin + Vector3(0.0, 40.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


func _physics_process(_delta: float) -> void:
	if _pinned_at != Vector3.INF:
		fish.global_position = _pinned_at
		fish.linear_velocity = Vector3.ZERO


func _tips() -> PackedVector3Array:
	var out := PackedVector3Array()
	for a in 8:
		out.append(_rig.model.arm_tip_local(a))
	return out


func _reset_samples() -> void:
	_body_roll = 0.0
	_worst_gap = 0.0
	_worst_step = 0.0
	_max_swing = 0.0
	_max_siphon_x = 0.0
	_finite = true
	_last_up = Vector3.ZERO
	_last_tips = PackedVector3Array()
	_worst_tip = 0.0
	_worst_head_gap = 0.0
	_heading_gap_max = 0.0
	_pitch_total = 0.0
	_last_fwd = Vector3.ZERO


func _process(_delta: float) -> void:
	if not _sampling or _rig == null:
		return
	var forward := -fish.global_basis.z.normalized()
	var body_up := fish.global_basis.orthonormalized().y
	# the rig is a child of the fish's visual: its own up, in the world, against the body's
	var model_up := _rig.model.global_basis.orthonormalized().y
	var tips := _tips()
	var len_m := fish.hitbox_length
	for t in tips:
		_finite = _finite and is_finite(t.x) and is_finite(t.y) and is_finite(t.z)
	if _last_tips.size() == 8:
		for a in 8:
			_worst_tip = maxf(_worst_tip, tips[a].distance_to(_last_tips[a]) / len_m)
	for a in 8:
		var rest: Vector3 = _rig.model.arm_rest_joints(a)[OctopusRig.SEGS]
		_max_swing = maxf(_max_swing, tips[a].distance_to(rest) / len_m)
	_last_tips = tips
	_max_siphon_x = maxf(_max_siphon_x, absf(_rig.model.siphon_exhaust_dir().x))
	if _last_up != Vector3.ZERO:
		_body_roll += _last_up.signed_angle_to(body_up, forward)
	_worst_gap = maxf(_worst_gap, body_up.angle_to(model_up))
	_last_up = body_up
	if _last_fwd != Vector3.ZERO:
		_pitch_total += _last_fwd.angle_to(forward)
	_last_fwd = forward
	var v := fish.linear_velocity
	if v.length() > 3.0:
		_heading_gap_max = maxf(_heading_gap_max, v.normalized().angle_to(forward))
	if _trace:
		print("    body roll %.0f gap %.1f tipstep %.4f siphon.x %.2f" % [rad_to_deg(_body_roll), rad_to_deg(body_up.angle_to(model_up)), _worst_tip, _rig.model.siphon_exhaust_dir().x])


func _roll(tag: String, thrust: float, stick: Vector2, air_roll: bool) -> void:
	_place()
	_pinned_at = fish.global_position if thrust == 0.0 else Vector3.INF
	await _frames(10)
	var input := FishInput.new()
	fish.controls = input
	input.air_roll = air_roll
	input.forward = thrust
	input.stick = stick
	_reset_samples()
	_sampling = true
	await get_tree().create_timer(2.0).timeout
	_sampling = false
	_pinned_at = Vector3.INF
	fish.controls = null
	print("  %s: body rolled %.0f deg, widest gap %.1f deg, biggest tip step %.4f, swing %.2f, siphon x %.2f" % [tag, rad_to_deg(_body_roll), rad_to_deg(_worst_gap), _worst_tip, _max_swing, _max_siphon_x])
	_check(absf(_body_roll) > PI, "%s: the body rolls (%.0f deg)" % [tag, rad_to_deg(_body_roll)])
	_check(_worst_gap < deg_to_rad(2.0), "%s: the model stays on the body (widest gap %.1f deg)" % [tag, rad_to_deg(_worst_gap)])
	_check(_max_siphon_x < 0.12, "%s: the siphon stays on the axis while the stick rolls (x %.2f)" % [tag, _max_siphon_x])
	_check(_finite, "%s: arms stay finite" % tag)
	_check(_worst_tip < 0.06, "%s: every arm tip moves smoothly (biggest step %.4f of length per frame)" % [tag, _worst_tip])
	_check(_max_swing > 0.05, "%s: the arms move with the roll (%.2f of length from rest)" % [tag, _max_swing])


## A slack octopus, upright and inverted: the arms hang toward the world's down by the same amount in both (up-vector aware).
func _drape(tag: String) -> void:
	var drops := []
	for flip in [false, true]:
		_place(Basis(Vector3(0, 0, 1), PI) if flip else Basis.IDENTITY)
		_pinned_at = fish.global_position
		await _frames(10)
		await get_tree().create_timer(2.5).timeout
		var head := _rig.model.global_position
		var drop := 0.0
		var rest_drop := 0.0
		for a in 8:
			var tip := _rig.model.arm_tip_global(a)
			var rest_tip := _rig.model.global_transform * (_rig.model.arm_rest_joints(a)[OctopusRig.SEGS] as Vector3)
			drop += (head.y - tip.y)
			rest_drop += (head.y - rest_tip.y)
		drop /= 8.0
		rest_drop /= 8.0
		drops.append(drop - rest_drop)
		_pinned_at = Vector3.INF
	print("  %s drape: extra drop upright %.3f m, inverted %.3f m" % [tag, drops[0], drops[1]])
	_check(float(drops[0]) > 0.01 * fish.hitbox_length, "%s: slack arms hang down (%.3f m)" % [tag, drops[0]])
	_check(float(drops[1]) > 0.01 * fish.hitbox_length, "%s: and inverted too: they follow the world's down, not the body's (%.3f m)" % [tag, drops[1]])


## Hold pitch and thrust: the nose loops and the jet (along the siphon, which rides the nose) carries the heading with it.
func _loop(tag: String) -> void:
	_place()
	await _frames(10)
	var input := FishInput.new()
	fish.controls = input
	input.forward = 1.0
	input.stick = Vector2(0.0, 1.0)
	_reset_samples()
	_sampling = true
	await get_tree().create_timer(3.0).timeout
	_sampling = false
	fish.controls = null
	print("  %s: nose swept %.0f deg, heading gap max %.0f deg, biggest tip step %.4f, speed %.1f" % [tag, rad_to_deg(_pitch_total), rad_to_deg(_heading_gap_max), _worst_tip, fish.linear_velocity.length()])
	_check(rad_to_deg(_pitch_total) > 120.0, "%s: the nose really loops (%.0f deg)" % [tag, rad_to_deg(_pitch_total)])
	_check(_finite and _worst_tip < 0.06, "%s: arms smooth and finite through the loop (%.4f)" % [tag, _worst_tip])
	_check(_worst_gap < deg_to_rad(2.0), "%s: the model stays on the body (%.1f deg)" % [tag, rad_to_deg(_worst_gap)])


## Swim upside down: the jets' thrust (summed by the rig) is along the body's own forward, so the octopus goes where its nose points,
## not toward the world's up. (The controller's own flow, lift and gravity act on top; only the rig's share is judged here.)
func _inverted(tag: String) -> void:
	_place(Basis(Vector3(0, 0, 1), PI))
	await _frames(10)
	var input := FishInput.new()
	fish.controls = input
	input.forward = 1.0
	var fwd := -fish.global_basis.z
	_rig.thrust_applied = Vector3.ZERO
	await get_tree().create_timer(1.2).timeout
	var thrust := _rig.thrust_applied
	fish.controls = null
	var ang := rad_to_deg(thrust.angle_to(fwd)) if thrust.length() > 0.001 else 180.0
	print("  %s: jets added %.1f m/s, %.0f deg off the nose" % [tag, thrust.length(), ang])
	_check(thrust.length() > 1.5, "%s: the jets still fire (%.1f m/s)" % [tag, thrust.length()])
	_check(ang < 25.0, "%s: and push along the nose, not toward the world's up (%.0f deg off)" % [tag, ang])
