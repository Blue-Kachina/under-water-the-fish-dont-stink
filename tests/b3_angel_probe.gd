## B3-angel: the Fallen Angel's exaggerated lock (press / hold / release / contact) through AttackExaggerate. Checks that the
## exaggeration is there and obvious (wings, crown, ring, body lunge), that it is smooth (no pops between frames), that it
## is exactly rest when switched off, that the tail stays planted through the lunge, that hit-stop and the lash fire on
## contact, and that the camera margin follows the peak.
##   Godot_console.exe --headless --path . res://tests/b3_angel_probe.tscn
##   --shots=DIR (needs a window) saves rest / press / hold / release / settle shots and one strip (b3_angel_strip.png).
extends Node

const KEY := "fallen_angel"

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var shots_dir := ""
var rig: Node3D
var bite: HunterBite
var hit_stops: Array[int] = []
var punches: Array[float] = []
var _saved: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	WhatStinksSettings.shared().bite_mode = WhatStinksSettings.BiteMode.HOLD
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
	var form := HunterForms.sheet(KEY)
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().apply(fish, form)
	HunterForms.dress(fish, KEY)
	await _frames(3)
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 25.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	await _frames(3)
	rig = (fish._visual as Node3D).get_meta("angel_rig")
	bite = HunterBite.new()
	fish.add_child(bite)
	bite.setup(fish, form)
	fish.controls = FishInput.new()
	await _frames(4)
	_check(rig.ex != null and rig.ex_lash != null, "the rig owns the exaggeration kits")
	rig.ex.hit_stopped.connect(func(n: int) -> void: hit_stops.append(n))
	rig.ex.camera_punch.connect(func(a: float, _d: Vector3) -> void: punches.append(a))
	await _cycle()
	await _off()
	print("b3_angel_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## What the rig is showing now: wing span, crown reach (shader length), the ring, the body's stretch.
func _read() -> Dictionary:
	var wing: Node3D = rig._wings[1]
	var tent: ShaderMaterial = rig._tentacle_skins[0]
	return {
		"wing": wing.transform.basis.x.length(),
		"crown": float(tent.get_shader_parameter("length")) / (rig.MODEL.H * 0.36),
		"ring": rig.halo.scale.x if rig.halo.visible else 0.0,
		"body": rig.scale.z / rig.unit, "girth": rig.scale.x / rig.unit,
		"light": rig._light.light_energy, "open": rig.crown_open,
	}


func _cycle() -> void:
	print("cycle:")
	await _frames(3)
	var rest := _read()
	_check(absf(rest["body"] - 1.0) < 0.001, "rest: the body is at rest scale (%.3f)" % rest["body"])
	if shots_dir != "":
		await _shot("rest")
	var tail_rest: float = rig.position.z + rig.scale.z * rig.MODEL.H * 0.5
	var trace: Array[Dictionary] = []
	var tps := int(Engine.physics_ticks_per_second)
	var cam_peak := 1.0
	_check(bite.try_open(), "press: the bite opens")
	var dip_wing := 9.0
	var dip_body := 9.0
	for i in int(tps * 0.2):
		await get_tree().physics_frame
		var r := _read()
		trace.append(r)
		dip_wing = minf(dip_wing, r["wing"] / maxf(rest["wing"], 0.001))
		dip_body = minf(dip_body, r["body"])
		if i == int(tps * 0.1) and shots_dir != "":
			await _shot("press")
	print("      press dip: wing %.2f, body %.2f" % [dip_wing, dip_body])
	_check(dip_wing < 0.851, "press: the wings fold in before the swell (anticipation, %.2f of rest)" % dip_wing)
	_check(dip_body < 0.951, "press: the body coils back (%.2f of its length)" % dip_body)
	var peak_wing := 0.0
	var peak_crown := 0.0
	var peak_body := 0.0
	var tail_drift := 0.0
	for i in int(tps * 1.8):
		await get_tree().physics_frame
		var r := _read()
		trace.append(r)
		peak_wing = maxf(peak_wing, r["wing"])
		peak_crown = maxf(peak_crown, r["crown"])
		peak_body = maxf(peak_body, r["body"])
		cam_peak = maxf(cam_peak, rig.camera_margin(1.0))
		tail_drift = maxf(tail_drift, absf(rig.position.z + rig.scale.z * rig.MODEL.H * 0.5 - tail_rest))
	print("      hold: charge %.2f, wing %.2f, crown %.2f, body %.2f" % [bite.charge(), peak_wing, peak_crown, peak_body])
	if shots_dir != "":
		await _shot("hold")
	_check(peak_wing > 1.35, "hold: the wings flare wide (%.2f x)" % peak_wing)
	_check(peak_crown > 1.3, "hold: the crown reaches out past its rest length (%.2f x)" % peak_crown)
	_check(tail_drift < 0.001, "the tail stays planted through the lunge (drift %.5f)" % tail_drift)
	var landed := [0]
	bite.landed.connect(func(_n: int) -> void: landed[0] += 1)
	_check(bite.try_close(), "release: the bite shuts")
	var snap_wing := 0.0
	var snap_ring := 0.0
	var snap_body := 0.0
	var lash_crown := 0.0
	var shot_rel := false
	for i in int(tps * 1.2):
		await get_tree().physics_frame
		var r := _read()
		trace.append(r)
		snap_wing = maxf(snap_wing, r["wing"])
		snap_ring = maxf(snap_ring, r["ring"])
		snap_body = maxf(snap_body, r["body"])
		lash_crown = maxf(lash_crown, r["crown"])
		cam_peak = maxf(cam_peak, rig.camera_margin(1.0))
		if shots_dir != "" and not shot_rel and r["body"] > 1.1:
			shot_rel = true
			await _shot("release")
	print("      release: wing %.2f, ring %.2f, body %.2f, lash crown %.2f, landed %d, hit-stop %s, punches %s" % [snap_wing, snap_ring, snap_body, lash_crown, landed[0], str(hit_stops), str(punches)])
	_check(snap_wing > 1.7, "release: the wings snap out (%.2f x)" % snap_wing)
	_check(snap_body > 1.15, "release: the body lunges (%.2f x its length)" % snap_body)
	_check(lash_crown > 1.5, "contact: the tentacles lash out well past rest (%.2f x)" % lash_crown)
	_check(landed[0] == 1, "the bite lands once")
	_check(hit_stops.size() >= 1 and hit_stops[0] >= 2 and hit_stops[0] <= 4, "contact: a 2-4 tick hit-stop (%s)" % str(hit_stops))
	_check(punches.size() >= 1 and punches[0] > 0.0, "contact: a camera punch is asked for (%s)" % str(punches))
	_check(cam_peak > 1.3, "camera: the margin grows with the lunge (x%.2f)" % cam_peak)
	await _frames(int(tps * 0.8))
	var after := _read()
	if shots_dir != "":
		await _shot("settle")
		_strip()
	_check(absf(after["body"] - 1.0) < 0.02, "settle: back to rest (body %.3f)" % after["body"])
	var worst := 0.0
	var worst_key := ""
	var worst_i := 0
	for i in range(1, trace.size()):
		for key in ["wing", "crown", "body"]:
			var d := absf(float(trace[i][key]) - float(trace[i - 1][key]))
			if d > worst:
				worst = d
				worst_key = key
				worst_i = i
	print("      worst step between physics frames: %.3f (%s) at %d of %d" % [worst, worst_key, worst_i, trace.size()])
	for k in range(maxi(worst_i - 3, 0), mini(worst_i + 3, trace.size())):
		print("        %d: %s" % [k, str(trace[k])])
	_check(worst < 1.2, "smooth: no pop between frames (worst step %.3f in %s)" % [worst, worst_key])


## The same cycle with the multiplier at 0: every part stays exactly at rest.
func _off() -> void:
	print("exaggeration off:")
	var tps := int(Engine.physics_ticks_per_second)
	await _frames(tps * 2)  # past the cooldown
	rig.ex.params["form_mult"] = 0.0
	rig.ex.set_strength(1.0, 0.0)
	rig.ex_lash.set_strength(1.0, 0.0)
	hit_stops.clear()
	bite.cooldown = 0.0
	_check(bite.try_open(), "press with the multiplier at 0")
	var body := 0.0
	var wing_lo := 9.0
	var wing_hi := 0.0
	for i in int(tps * 1.0):
		await get_tree().physics_frame
		var r := _read()
		body = maxf(body, absf(r["body"] - 1.0))
		wing_lo = minf(wing_lo, r["wing"])
		wing_hi = maxf(wing_hi, r["wing"])
	bite.try_close()
	for i in int(tps * 0.8):
		await get_tree().physics_frame
		body = maxf(body, absf(float(_read()["body"]) - 1.0))
		wing_hi = maxf(wing_hi, float(_read()["wing"]))
	print("      off: body deviation %.4f, wing %.3f..%.3f, hit stops %s" % [body, wing_lo, wing_hi, str(hit_stops)])
	_check(body < 0.0005, "off: the body never stretches (%.5f)" % body)
	_check(wing_hi - wing_lo < 0.05, "off: the wings keep their rest span (%.3f..%.3f)" % [wing_lo, wing_hi])
	_check(hit_stops.is_empty(), "off: no hit-stop")
	_check(rig.ex.peak_scale() == 1.0, "off: peak scale is 1")


func _shot(view: String) -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var free := Camera3D.new()
	free.far = 2000.0
	var lamp := OmniLight3D.new()
	lamp.omni_range = 400.0
	lamp.light_energy = 6.0
	free.add_child(lamp)
	main.add_child(free)
	var length := fish.hitbox_length
	var middle := fish.global_position + fish.global_basis * Vector3(0.0, 0.0, -length * 0.1)
	free.global_position = middle + fish.global_basis * (Vector3(-1.0, 0.25, -0.9).normalized() * length * 1.6)
	free.look_at(middle, Vector3.UP)
	free.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/b3_angel_%s.png" % [shots_dir, view])
	_saved[view] = image
	main.get_node("FollowCamera").make_current()
	free.queue_free()


## Rest + the four beats side by side in one image.
func _strip() -> void:
	var order := ["rest", "press", "hold", "release", "settle"]
	var cell := Vector2i(480, 320)
	var strip := Image.create(cell.x * order.size(), cell.y, false, Image.FORMAT_RGBA8)
	for i in order.size():
		var image: Image = _saved.get(order[i])
		if image == null:
			continue
		image = image.duplicate()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		strip.blit_rect(image, Rect2i(Vector2i.ZERO, cell), Vector2i(cell.x * i, 0))
	strip.save_png("%s/b3_angel_strip.png" % shots_dir)
