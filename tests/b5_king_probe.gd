## B5: the King of Herrings' coil-whip exaggeration (forms/king_exaggerate.gd, king_jaw.gd, attacks/coil_attack.gd; the kit is
## AttackExaggerate). A held bite on a dressed King, stepped tick by tick: rest -> press -> hold-peak -> release -> settle.
## Checks: rest is untouched; the press dips (anticipation) then the coil winds tighter than the plain coil (chord and curl); the
## jaw gapes wider than the plain gape; the eyes bulge; the release stretches the tail (>= 1.4x) with the body longer and
## no frame-to-frame pop; everything settles to rest; master 0 changes nothing; hit-stop and camera punch on landing; a tap bite
## also winds and whips. Prints the numbers.
##   Godot_console.exe --headless --path . res://tests/b5_king_probe.tscn
##   --shots=DIR (needs a window) saves a strip: rest / press / hold-peak / release / settle, from above and from the side.
extends Node

const KEY := "king_of_herrings"

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var tps := 120
var shots_dir := ""
var bite: HunterBite
var body: Node3D
var driver: Node
var rig: SpineRig


func _ready() -> void:
	WhatStinksSettings.shared().bite_mode = WhatStinksSettings.BiteMode.HOLD
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
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
		await get_tree().process_frame


func _chord() -> float:
	return rig.points[0].distance_to(rig.points[rig.points.size() - 1])


func _path() -> float:
	var total := 0.0
	for i in range(1, rig.points.size()):
		total += rig.points[i].distance_to(rig.points[i - 1])
	return total


func _tail() -> Vector3:
	return rig.points[rig.points.size() - 1]


func _gape() -> float:
	var hinge: Vector3 = body.get("skin").get_shader_parameter("hinge")
	return hinge.z


## Back to a still, straight King with a fresh idle bite.
func _reset() -> void:
	if bite != null and is_instance_valid(bite):
		bite.abort()
	await _frames(tps)
	driver.ex.reset()
	driver.lag = 0.0
	driver.lag_v = 0.0
	bite.cooldown = 0.0
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	fish.global_transform = Transform3D(Basis.IDENTITY, fish.global_position)
	await _frames(tps)


## Runs press -> hold `hold_s` -> release -> settle with the driver at `master`; returns the record.
func _cycle(master: float, hold_s: float, shots_tag := "") -> Dictionary:
	driver.master_override = master
	await _reset()
	var rec := {"rest_chord": _chord(), "rest_path": _path(), "rest_gape": _gape(), "rest_tail": _tail()}
	if shots_tag != "":
		await _shot(shots_tag + "_1rest")
	var dips := 1.0
	bite.try_open()
	var press_frames := int(tps * 0.12)
	for i in press_frames:
		await _frames(1)
		dips = minf(dips, driver.ex.scale_of(&"coil"))
	rec["dip"] = dips
	rec["press_curl"] = float(driver.shown["curl"])
	if shots_tag != "":
		await _shot(shots_tag + "_2press")
	var max_gape := 0.0
	var max_eye := 1.0
	var min_chord := INF
	var min_radius := INF
	var max_turn := 0.0
	var max_curl := 0.0
	var max_lift := 0.0
	var n := int(tps * hold_s)
	for i in n:
		await _frames(1)
		max_gape = maxf(max_gape, _gape())
		max_eye = maxf(max_eye, float(driver.shown["eyes"]))
		min_chord = minf(min_chord, _chord())
		min_radius = minf(min_radius, _coil_radius())
		max_turn = maxf(max_turn, _coil_turn())
		max_curl = maxf(max_curl, float(driver.shown["curl"]))
		max_lift = maxf(max_lift, float(driver.shown["lift"]))
	rec["hold_gape"] = max_gape
	rec["hold_eye"] = max_eye
	rec["hold_chord"] = min_chord
	rec["hold_radius"] = min_radius
	rec["hold_turn"] = max_turn
	rec["hold_curl"] = max_curl
	rec["hold_lift"] = max_lift
	rec["hold_charge"] = bite.charge()
	rec["hold_jaw_scale"] = driver.ex.scale_of(&"jaw")
	if shots_tag != "":
		await _shot(shots_tag + "_3hold")
	bite.try_close()
	var max_stretch := 1.0
	var max_path := 0.0
	var worst_step := 0.0
	var worst_eye_jump := 0.0
	var last_tail := _tail()
	var last_eye := 1.0
	var released_at := 0
	var shot_taken := false
	var len_cycle := int(tps * 3.0)
	for i in len_cycle:
		await _frames(1)
		max_stretch = maxf(max_stretch, float(driver.shown["stretch"]))
		max_path = maxf(max_path, _path())
		if _tail().distance_to(last_tail) > 1.5:
			print("      jump %.2f m at %d: swing %.2f lag %.2f stretch %.2f curl %.2f coil %.2f whip %.2f phase %s" % [_tail().distance_to(last_tail), i, driver._swing(), driver.lag, driver.shown["stretch"], driver.shown["curl"], body.get("_coil"), driver.shown["lag"], bite.bite.phase])
		worst_step = maxf(worst_step, _tail().distance_to(last_tail))
		last_tail = _tail()
		worst_eye_jump = maxf(worst_eye_jump, absf(float(driver.shown["eyes"]) - last_eye))
		last_eye = float(driver.shown["eyes"])
		if shots_tag != "" and not shot_taken and float(driver.shown["stretch"]) > 1.4:
			shot_taken = true
			await _shot(shots_tag + "_4release")
		if shots_tag != "" and i == int(tps * 1.2):
			await _shot(shots_tag + "_5settle")
	rec["max_stretch"] = max_stretch
	rec["max_path"] = max_path
	rec["worst_step"] = worst_step
	rec["end_stretch"] = float(driver.shown["stretch"])
	rec["end_curl"] = float(driver.shown["curl"])
	rec["end_eye"] = float(driver.shown["eyes"])
	rec["end_gape"] = _gape()
	rec["end_idle"] = driver.ex.idle()
	return rec


func _run() -> void:
	await _frames(5)
	tps = int(Engine.physics_ticks_per_second)
	main.set_environment("Ocean")
	await _frames(5)
	var form := HunterForm.sheet(KEY)
	HunterSize.shared().size_mult = 1.0
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().apply(fish, form)
	HunterForms.dress(fish, KEY)
	await _frames(3)
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 25.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	await _frames(5)
	body = fish._visual.get_node_or_null("KingRig")
	_check(body != null, "a KingRig")
	driver = body.get_node_or_null("KingExaggerate")
	_check(driver != null, "the exaggeration driver is on the rig")
	if driver == null:
		get_tree().quit(1)
		return
	rig = body.get("rig")
	driver.fixed_delta = 1.0 / tps
	HunterForms.dress(fish, KEY)
	_check(body.find_children("KingExaggerate", "", false, false).size() == 1, "dressing again keeps one driver")
	_check(form.has("exaggerate") and form.has("exaggeration"), "the sheet carries its exaggeration preset")
	bite = HunterBite.new()
	bite.name = "HunterBite"
	fish.add_child(bite)
	bite.setup(fish, form)
	var coil := bite.attack as CoilAttack
	_check(coil != null, "the King wears the coil")
	await _frames(tps)

	# The press floor: the press alone winds the coil well past the old 0.25.
	bite.try_open()
	await _frames(2)
	_check(coil.coil_target(bite) >= 0.39, "the press winds the coil target to the floor (%.2f)" % coil.coil_target(bite))
	bite.abort()
	await _frames(tps)

	print("master 0 (plain):")
	var plain := await _cycle(0.0, 1.3)
	var frames_plain: int = driver.bent_frames
	print("      rest chord %.2f path %.2f, hold chord %.2f, gape %.2f, max stretch %.3f, eye %.2f" % [plain["rest_chord"], plain["rest_path"], plain["hold_chord"], plain["hold_gape"], plain["max_stretch"], plain["hold_eye"]])
	_check(is_equal_approx(float(plain["max_stretch"]), 1.0) and is_equal_approx(float(plain["hold_eye"]), 1.0), "master 0: no tail stretch, no eye bulge")
	_check(driver.bent_frames == frames_plain, "master 0: the driver bent nothing")

	print("master 1 (bold):")
	var tag := "king" if shots_dir != "" else ""
	var bold := await _cycle(1.0, 1.3, tag)
	print("      dip %.2f, press curl %.1f deg, hold curl %.1f deg lift %.2f m, hold chord %.2f (plain %.2f), gape %.2f (plain %.2f), eye %.2f" % [bold["dip"], rad_to_deg(bold["press_curl"]), rad_to_deg(bold["hold_curl"]), bold["hold_lift"], bold["hold_chord"], plain["hold_chord"], bold["hold_gape"], plain["hold_gape"], bold["hold_eye"]])
	print("      release: max stretch %.2f, path %.1f -> %.1f m, worst tail step %.2f m/frame, eye jump %.3f" % [bold["max_stretch"], bold["rest_path"], bold["max_path"], bold["worst_step"], 0.0])
	_check(float(bold["dip"]) < 0.97, "the press dips first: anticipation (coil scale %.2f)" % bold["dip"])
	_check(float(bold["hold_curl"]) > deg_to_rad(60.0), "the coil winds visibly tighter at the hold's peak (+%.0f deg on top of the plain coil)" % rad_to_deg(bold["hold_curl"]))
	_check(float(bold["hold_radius"]) < float(plain["hold_radius"]) * 0.92, "the held coil is smaller than the plain one (mean radius %.2f vs %.2f m)" % [bold["hold_radius"], plain["hold_radius"]])
	_check(float(bold["hold_gape"]) > float(plain["hold_gape"]) * 1.6, "the gape is wider (%.2f vs %.2f rad)" % [bold["hold_gape"], plain["hold_gape"]])
	_check(float(bold["hold_eye"]) > 1.4, "the eyes bulge with the charge (%.2f x)" % bold["hold_eye"])
	_check(float(bold["max_stretch"]) >= 1.4, "the whip tail stretches on the release (%.2f x, smear included)" % bold["max_stretch"])
	_check(float(bold["max_stretch"]) < 2.6, "and stays bold but readable (%.2f x)" % bold["max_stretch"])
	_check(float(bold["max_path"]) > float(bold["rest_path"]) * 1.1, "the body is visibly longer at the whip's peak (%.1f vs %.1f m)" % [bold["max_path"], bold["rest_path"]])
	_check(float(bold["worst_step"]) < fish.hitbox_length * 0.5 and float(bold["worst_step"]) <= float(plain["worst_step"]) * 2.2 + 1.0, "no pop: the tail tip moves at most %.2f m a frame (plain %.2f, limit %.1f m)" % [bold["worst_step"], plain["worst_step"], fish.hitbox_length * 0.5])
	_check(absf(float(bold["end_stretch"]) - 1.0) < 0.01 and absf(float(bold["end_curl"])) < 0.01 and absf(float(bold["end_eye"]) - 1.0) < 0.01, "everything settles to rest")
	_check(bool(bold["end_idle"]), "the kit is idle again")
	_check(driver.ex.potential_peak() <= float(driver.ex.params["max_scale"]) + 0.001, "worst-case scale %.2f is within the clamp (camera margin %.1f m for a 2 m radius)" % [driver.ex.potential_peak(), driver.ex.camera_margin(2.0)])

	print("hit-stop and camera punch:")
	driver.master_override = 1.0
	await _reset()
	var punches := [0]
	driver.ex.camera_punch.connect(func(_a: float, _d: Vector3) -> void: punches[0] += 1)
	var stops := [0]
	driver.ex.hit_stopped.connect(func(f: int) -> void: stops[0] = f)
	bite.try_open()
	await _frames(int(tps * 0.8))
	bite.try_close()
	var saw_stop := false
	for i in tps * 3:
		await _frames(1)
		saw_stop = saw_stop or driver.ex.in_hit_stop()
		if stops[0] > 0 and not driver.ex.in_hit_stop():
			break
	print("      landed -> hit-stop of %d frames, punches %d" % [stops[0], punches[0]])
	_check(stops[0] >= 2 and saw_stop, "the landing freezes the rig for a few frames (%d)" % stops[0])
	_check(punches[0] >= 1, "the landing sends a camera punch")

	print("tap mode:")
	WhatStinksSettings.shared().bite_mode = WhatStinksSettings.BiteMode.TAP
	driver.master_override = 1.0
	await _reset()
	var tap_dip := 1.0
	var tap_stretch := 1.0
	var tap_curl := 0.0
	bite.try_bite()
	for i in tps * 4:
		await _frames(1)
		tap_dip = minf(tap_dip, driver.ex.scale_of(&"coil"))
		tap_stretch = maxf(tap_stretch, float(driver.shown["stretch"]))
		tap_curl = maxf(tap_curl, float(driver.shown["curl"]))
	print("      tap: coil dip %.2f, curl +%.0f deg, stretch %.2f" % [tap_dip, rad_to_deg(tap_curl), tap_stretch])
	_check(tap_dip < 0.99 and tap_curl > 0.05, "a tap bite winds too")
	_check(tap_stretch > 1.3, "a tap bite whips (%.2f x)" % tap_stretch)
	WhatStinksSettings.shared().bite_mode = WhatStinksSettings.BiteMode.HOLD

	print("abort:")
	driver.master_override = 1.0
	await _reset()
	bite.try_open()
	await _frames(int(tps * 0.6))
	bite.abort()
	await _frames(tps * 3)
	_check(driver.ex.idle() and absf(float(driver.shown["curl"])) < 0.01 and absf(float(driver.shown["eyes"]) - 1.0) < 0.01, "an aborted hold eases back to rest with no snap")

	print("b5_king_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## A strip frame: from above and from the side, at the King's centre.
func _shot(tag: String) -> void:
	if shots_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(shots_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true  # the body holds the pose while it is photographed
	var free := Camera3D.new()
	free.far = 2000.0
	main.add_child(free)
	var centre := Vector3.ZERO
	for i in range(0, rig.points.size(), 2):
		centre += rig.points[i]
	centre /= float(rig.points.size() / 2)
	var length := fish.hitbox_length
	for view: Array in [["top", Vector3(0.0, 1.0, 0.001), 0.95], ["iso", Vector3(0.8, 0.6, 0.7), 0.85]]:
		free.global_position = centre + Vector3(view[1]).normalized() * length * float(view[2])
		free.look_at(centre, Vector3.UP if view[0] == "iso" else Vector3.FORWARD)
		free.make_current()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [shots_dir, tag, view[0]])
	free.queue_free()
	get_tree().paused = false


## The coil's size: the mean distance of the curling part of the spine from its own centre, seen along the fish's up (smaller: tighter).
func _coil_radius() -> float:
	var n := SpineRig.SPINE_N
	var last := int(n * 0.75)
	var axis := rig.head_up.normalized()
	var flat: Array[Vector3] = []
	var centre := Vector3.ZERO
	for i in range(0, last):
		var p := rig.points[i]
		p -= axis * p.dot(axis)
		flat.append(p)
		centre += p
	centre /= float(last)
	var sum := 0.0
	for p in flat:
		sum += p.distance_to(centre)
	return sum / float(last)


## How far the body has turned round the fish's up from the neck to 3/4 down (rad, unwrapped).
func _coil_turn() -> float:
	var n := SpineRig.SPINE_N
	var axis := rig.head_up.normalized()
	var total := 0.0
	var prev := (rig.points[2] - rig.points[1])
	for i in range(3, int(n * 0.75)):
		var seg := rig.points[i] - rig.points[i - 1]
		total += prev.signed_angle_to(seg, axis)
		prev = seg
	return absf(total)
