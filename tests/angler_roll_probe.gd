## What Stinks? Lantern Angler under air roll and pitch (D2): dressed as a match dresses it, placed mid-water, air roll held with the
## stick full right for 2 s (still, then swimming), then a pitch loop. Each frame the body's roll and the model's roll (the up of the
## spine's head frame, turned back onto the fish's way) are summed: the model should follow the body, without jumps. Also: the lure
## stalk stays attached (the esca within the stalk's reach of the head every frame, finite), its path is smooth (no frame jumps) and
## it really lags a roll's spin-up (the esca trails its rest spot by a measurable amount), and the tail and fin channels stay
## continuous through it.
##   --trace prints every frame.
## Run headless: Godot_console.exe --headless --path . res://tests/angler_roll_probe.tscn
extends Node

const FORM := preload("res://scripts/what_stinks/forms/lantern_angler.gd")

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
var _pinned_at := Vector3.INF
var _trace := false
var _rig: Node3D
var _max_reach := 0.0
var _max_esca_step := 0.0
var _last_esca := Vector3.INF
var _max_lag := 0.0
var _max_tail_step := 0.0
var _last_tail := 0.0
var _max_flap_step := 0.0
var _last_flap := 0.0
var _finite := true
var _spine_kink := 0.0
var _kink_at := 0
var _last_age := 0.0
var _kink_dump: Array = []


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
	for s: float in [1.0, 3.0]:
		await _dress(s)
		await _roll("x%.0f still" % s, 0.0, Vector2(1.0, 0.0), true)
		await _roll("x%.0f swimming" % s, 1.0, Vector2(1.0, 0.0), true)
		await _roll("x%.0f loop" % s, 0.6, Vector2(0.0, 1.0), false)
	print("angler_roll_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _dress(s: float) -> void:
	var form := HunterForms.DEFAULTS.duplicate()
	form.merge(FORM.sheet() as Dictionary, true)
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().size_mult = s
	HunterSize.shared().apply(fish, form)
	FORM.dress(fish, form)
	await _frames(5)
	_rig = (fish._visual as Node3D).get_node("LanternRig")
	_last_age = 0.0


func _place() -> void:
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 40.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


## The up of what's drawn, in world space (the spine's head frame turned back onto the fish's way).
func _model_up() -> Vector3:
	var rig: SpineRig = _rig.rig
	var head := rig.frame_at(0.0).basis
	var back := head.z.normalized()
	var want := fish.global_basis.z.normalized()
	return (Quaternion(back, want) * head.y).normalized() if back.dot(want) > -0.999 else head.y


func _physics_process(_delta: float) -> void:
	if _pinned_at != Vector3.INF:
		fish.global_position = _pinned_at
		fish.linear_velocity = Vector3.ZERO


func _process(delta: float) -> void:
	if not _sampling or _rig == null:
		return
	var dt := maxf(delta, 0.001)
	var age_now: float = _rig.shown["age"] if _rig.shown.has("age") else 0.0
	if age_now <= _last_age:
		return  # the rig has not updated since the last sample
	dt = age_now - _last_age if _last_age > 0.0 and age_now - _last_age < 0.5 else dt
	_last_age = age_now
	var forward := -fish.global_basis.z.normalized()
	var body_up := fish.global_basis.orthonormalized().y
	var model_up := _model_up()
	var model: AnglerModel = _rig.model
	var head: Vector3 = _rig.rig.points[0]
	var esca := model.esca_world()
	var rest_pos := model._place(model.esca_rest())  # where the bulb would be with no spring lag
	_max_reach = maxf(_max_reach, esca.distance_to(head) / model.k)
	_max_lag = maxf(_max_lag, esca.distance_to(rest_pos) / model.k)
	if _last_esca != Vector3.INF:
		_max_esca_step = maxf(_max_esca_step, esca.distance_to(_last_esca) / model.k)
	_last_esca = esca
	_finite = _finite and is_finite(esca.x) and is_finite(esca.y) and is_finite(esca.z)
	var sh: Dictionary = _rig.shown
	_max_tail_step = _rig.peak_rate["tail"]
	_last_tail = float(sh["tail"])
	_max_flap_step = maxf(_rig.peak_rate["flap"], _rig.peak_rate["sweep"] * 0.5)
	_last_flap = float(sh["flap_l"])
	for i in range(1, SpineRig.SPINE_N - 1):
		var a: Vector3 = _rig.rig.points[i] - _rig.rig.points[i - 1]
		var b: Vector3 = _rig.rig.points[i + 1] - _rig.rig.points[i]
		if a.angle_to(b) > _spine_kink:
			_spine_kink = a.angle_to(b)
			_kink_at = i
			_kink_dump = []
			for j in range(0, 9):
				_kink_dump.append(fish.global_basis.inverse() * (_rig.rig.points[j] - _rig.rig.points[0]))
	if _last_body_up != Vector3.ZERO:
		_body_roll += _last_body_up.signed_angle_to(body_up, forward)
		var step := _last_model_up.signed_angle_to(model_up, forward)
		_model_roll += step
		_worst_jump = maxf(_worst_jump, absf(step))
		if _trace:
			print("    body %.0f model %.0f step %.1f esca-lag %.2f" % [rad_to_deg(_body_roll), rad_to_deg(_model_roll), rad_to_deg(step), esca.distance_to(rest_pos) / model.k])
	_worst_gap = maxf(_worst_gap, body_up.angle_to(model_up))
	_last_body_up = body_up
	_last_model_up = model_up


func _roll(tag: String, thrust: float, stick: Vector2, air_roll: bool) -> void:
	_place()
	_pinned_at = fish.global_position if thrust == 0.0 else Vector3.INF
	await _frames(10)
	var input := FishInput.new()
	fish.controls = input
	input.air_roll = air_roll
	input.forward = thrust
	input.stick = stick
	_body_roll = 0.0
	_model_roll = 0.0
	_worst_gap = 0.0
	_worst_jump = 0.0
	_last_body_up = Vector3.ZERO
	_max_reach = 0.0
	_max_esca_step = 0.0
	_last_esca = Vector3.INF
	_max_lag = 0.0
	_max_tail_step = 0.0
	_max_flap_step = 0.0
	_spine_kink = 0.0
	_last_age = 0.0
	_rig.peak_rate = {"tail": 0.0, "flap": 0.0, "sweep": 0.0}
	_finite = true
	_sampling = true
	await get_tree().create_timer(2.0).timeout
	_sampling = false
	_pinned_at = Vector3.INF
	fish.controls = null
	print("  %s: body rolled %.0f deg, model %.0f, widest gap %.0f, biggest jump %.1f deg; esca reach %.2f, lag %.2f, step %.3f (x length unit k)" % [tag, rad_to_deg(_body_roll), rad_to_deg(_model_roll), rad_to_deg(_worst_gap), rad_to_deg(_worst_jump), _max_reach, _max_lag, _max_esca_step])
	if air_roll:
		_check(absf(_body_roll) > PI, "%s: the body rolls (%.0f deg)" % [tag, rad_to_deg(_body_roll)])
		_check(absf(_model_roll - _body_roll) < deg_to_rad(30.0), "%s: the model rolls with it (%.0f vs %.0f deg)" % [tag, rad_to_deg(_model_roll), rad_to_deg(_body_roll)])
		_check(_worst_gap < deg_to_rad(35.0), "%s: and stays on it (widest gap %.0f deg)" % [tag, rad_to_deg(_worst_gap)])
	_check(_worst_jump < deg_to_rad(10.0), "%s: without a snap (biggest frame jump %.1f deg)" % [tag, rad_to_deg(_worst_jump)])
	_check(_finite, "%s: the stalk stays finite" % tag)
	_check(_max_reach < 4.3, "%s: the lure stays on its stalk (reach %.2f of 3.3)" % [tag, _max_reach])
	_check(_max_esca_step < 0.9, "%s: the lure moves smoothly (frame step %.3f)" % [tag, _max_esca_step])
	_check(_max_tail_step < 9.0 and _max_flap_step < 8.0, "%s: tail and fins continuous (tail %.2f, fin %.2f rad/s)" % [tag, _max_tail_step, _max_flap_step])
	if _spine_kink > deg_to_rad(25.0):
		print("    kink dump: ", _kink_dump)
	_check(_spine_kink < deg_to_rad(25.0), "%s: no kink in the spine (worst joint %.1f deg at point %d)" % [tag, rad_to_deg(_spine_kink), _kink_at])
	if air_roll:
		_check(_max_lag > 0.02, "%s: the spin-up swings the lure off its rest spot (%.2f)" % [tag, _max_lag])
