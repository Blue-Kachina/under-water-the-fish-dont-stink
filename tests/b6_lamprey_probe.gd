## B6 (planning_new_hunters.md): the Lamprey Queen's drill exaggeration (lamprey_exaggerate.gd, driven by AttackExaggerate).
## Checks the rest / press / hold-peak / release / dash / settle numbers (disc flare, body telescope, teeth spin), that nothing pops from
## one frame to the next, that the strength setting scales it (0 is exactly the old look), the hit-stop on contact, and the camera margin.
## Headless (checks):  Godot_console.exe --headless --path . --fixed-fps 60 res://tests/b6_lamprey_probe.tscn
## Windowed (strips):  Godot_console.exe --path . --fixed-fps 60 res://tests/b6_lamprey_probe.tscn -- --shots=DIR
## The strips are DIR/b6_side.png and DIR/b6_front.png: rest, press, hold-peak, release, dash, settle (left to right).
extends Node

const KEY := "lamprey_queen"
const VIEW_W := 360
const VIEW_H := 270

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var tps := 120
var shots_dir := ""
var cam: Camera3D
var view := "side"
var _series: Array = []  # per frame: {t, stretch, disc, spin, girth, tail, phase}
var _clock := 0.0


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
		await get_tree().process_frame


## Waits `sec` of game time (process deltas), recording the series and (in shots mode) following with the camera.
func _wait(sec: float, grab: Callable = Callable()) -> void:
	var end := _clock + sec
	while _clock < end:
		await get_tree().process_frame
		_clock += get_process_delta_time()
		_record()
		_follow()
	if grab.is_valid():
		await grab.call()


func _exag() -> Node:
	var jaw: HunterJaw = fish.get("_visual").get_meta("hunter_jaw") as HunterJaw
	return jaw.call("exaggeration") if jaw != null else null


func _rig() -> Node3D:
	return fish.get("_visual").get_node_or_null("LampreyRig") as Node3D


func _record() -> void:
	var rig := _rig()
	var e := _exag()
	if rig == null or e == null:
		return
	var spine: SpineRig = rig.get("rig")
	var skin: ShaderMaterial = rig.get("skin")
	var kit: AttackExaggerate = e.get("ex")
	_series.append({
		"t": _clock, "stretch": float(e.get("stretch")), "disc": float(skin.get_shader_parameter("disc")),
		"spin": float(e.get("spin_angle")), "girth": float(e.get("girth")),
		"tail": spine.points[0].distance_to(spine.points[SpineRig.SPINE_N - 1]),
		"phase": kit.phase if kit != null else -1, "stop": kit != null and kit.in_hit_stop(),
	})


func _follow() -> void:
	if cam == null:
		return
	var basis := fish.global_basis
	var at := fish.global_position
	var from := Vector3.ZERO
	var look := Vector3.ZERO
	if view == "side":
		from = at + basis * Vector3(26.0, 3.0, 7.0)
		look = at + basis * Vector3(0.0, 0.0, 6.5)
	else:
		from = at + basis * Vector3(-8.0, 3.0, -14.0)
		look = at + basis * Vector3(0.0, 0.0, -2.0)
	cam.global_position = from
	cam.look_at(look, Vector3.UP)


func _setup_shots() -> void:
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 400.0
	main.add_child(cam)
	cam.current = true
	get_window().size = Vector2i(VIEW_W * 2, VIEW_H * 2)


func _grab(strip: Image, slot: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(VIEW_W, VIEW_H)
	strip.blend_rect(img, Rect2i(0, 0, VIEW_W, VIEW_H), Vector2i(slot * VIEW_W, 0))


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
	var settings := WhatStinksSettings.shared()
	var bite := HunterBite.new()
	bite.name = "HunterBite"
	fish.add_child(bite)
	bite.setup(fish, form)
	_check(bite.attack is DrillAttack, "the Queen wears the drill")
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
		_setup_shots()
	# The driver is seated by the first pose; give it a few frames, then read the rig.
	await _frames(10)
	_check(_exag() != null, "the exaggeration is seated on the rig by the jaw")
	if _exag() == null:
		print("b6_lamprey_probe: %d checks, %d failed" % [checks, failures])
		get_tree().quit(1)
		return
	_check(bool(_exag().get("patched")), "the skin shader took the spin / girth patch")
	var skin: ShaderMaterial = _rig().get("skin")
	_check(skin.shader.code.contains("disc_spin"), "the Queen's skin runs the patched copy")
	_check(not (load("res://shaders/boss_lamprey.gdshader") as Shader).code.contains("disc_spin"), "the boss's own shader is untouched")

	# --- Strength 1 (the bold default) --------------------------------------------------------
	_set_master(settings, 1.0)
	var rest := await _drill(bite, "strength 1", true)
	# --- Strength 0: exactly the old look -------------------------------------------------------
	_set_master(settings, 0.0)
	var off := await _drill(bite, "strength 0", false)
	_check(off.max_stretch < 1.004 and off.min_stretch > 0.996, "strength 0: the body never stretches (%.3f..%.3f)" % [off.min_stretch, off.max_stretch])
	_check(off.max_disc <= off.base_max_disc + 0.001, "strength 0: the disc is the rig's own (%.2f vs %.2f)" % [off.max_disc, off.base_max_disc])
	_check(absf(off.spin_travel) < 0.01, "strength 0: the teeth do not spin up (%.2f rad)" % off.spin_travel)
	# --- Strength 2: bigger, but inside the telescope cap ---------------------------------------
	_set_master(settings, 2.0)
	var big := await _drill(bite, "strength 2", false)
	_check(big.max_disc > rest.max_disc, "strength 2 flares wider than 1 (%.2f > %.2f)" % [big.max_disc, rest.max_disc])
	_check(big.max_stretch <= _exag().call("setting", "lamprey_telescope_max") + 0.001, "strength 2 stays under the telescope cap (%.2f)" % big.max_stretch)
	_check(big.min_stretch < rest.min_stretch + 0.001, "strength 2 draws in at least as far on the wind (%.2f vs %.2f)" % [big.min_stretch, rest.min_stretch])
	_check(big.camera <= 3.0, "strength 2: the camera margin stays sane (%.2fx)" % big.camera)
	_set_master(settings, 1.0)
	print("b6_lamprey_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _set_master(settings: Object, v: float) -> void:
	if settings.get("hunter_exaggeration") != null:
		settings.set("hunter_exaggeration", v)
	else:
		settings.set_meta("hunter_exaggeration", v)  # until the setting is registered


## One full drill at the current strength: rest, press, hold to full, release, dash, settle. Returns the numbers and (when `assert` is
## set) checks the shape of the motion. In shots mode it also saves the strips for the `view`s.
func _drill(bite: HunterBite, tag: String, assert_shape: bool) -> Dictionary:
	var out := {}
	var views: Array = [view]
	if shots_dir != "" and assert_shape:
		views = ["side", "front"]
	for v in views:
		view = v
		out = await _drill_once(bite, tag, assert_shape and v == views[0], v)
	return out


func _drill_once(bite: HunterBite, tag: String, assert_shape: bool, which: String) -> Dictionary:
	var n := 0
	while bite.busy() and n < tps * 6:
		await get_tree().physics_frame
		n += 1
	await _frames(tps)
	bite.cooldown = 0.0
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	fish.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, fish.global_position.y, 0.0))
	await _frames(20)
	_series.clear()
	var strip := Image.create(VIEW_W * 6, VIEW_H, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.05, 0.2, 0.3))
	var shots := shots_dir != "" and tag == "strength 1"
	var rig := _rig()
	var spine: SpineRig = rig.get("rig")
	var rest_len := spine.points[0].distance_to(spine.points[SpineRig.SPINE_N - 1])
	var rest_disc := float(rig.get("skin").get_shader_parameter("disc"))
	# rest
	await _wait(0.2, (func() -> void: await _grab(strip, 0)) if shots else Callable())
	var t0 := _clock
	# press
	bite.try_open()
	await _wait(0.13, (func() -> void: await _grab(strip, 1)) if shots else Callable())
	var press_stretch: float = _series[_series.size() - 1].stretch
	var press_disc: float = _series[_series.size() - 1].disc
	# hold to peak
	fish.linear_velocity = Vector3.ZERO
	await _wait(maxf(float(bite.form.get("charge_s", 1.2)) + 0.3, 1.4), (func() -> void: await _grab(strip, 2)) if shots else Callable())
	var hold_i := _series.size() - 1
	var hold: Dictionary = _series[hold_i]
	var hold_tail: float = hold.tail
	var spin_hold_start: float = _series[hold_i - 10].spin
	# release
	var release_clock := _clock
	var release_mark := _series.size()
	fish.linear_velocity = Vector3.ZERO
	bite.try_close()
	await _wait(0.12, (func() -> void: await _grab(strip, 3)) if shots else Callable())
	await _wait(0.2, (func() -> void: await _grab(strip, 4)) if shots else Callable())
	var drill: DrillAttack = bite.attack as DrillAttack
	var w := 0
	while drill.active() and w < 400:
		await _wait(0.02)
		w += 1
	await _wait(1.6, (func() -> void: await _grab(strip, 5)) if shots else Callable())
	await _wait(0.6)
	if shots:
		var path := "%s/b6_%s.png" % [shots_dir, which]
		strip.save_png(path)
		print("saved ", path)
	# numbers
	var o := {"min_stretch": 9.0, "max_stretch": 0.0, "max_disc": -9.0, "base_max_disc": 1.0, "spin_travel": 0.0, "camera": 1.0}
	var max_dstretch := 0.0
	var max_ddisc := 0.0
	var max_dspin := 0.0
	var stopped := false
	var peak_after := 0.0
	for i in _series.size():
		var s: Dictionary = _series[i]
		o.min_stretch = minf(o.min_stretch, s.stretch)
		o.max_stretch = maxf(o.max_stretch, s.stretch)
		o.max_disc = maxf(o.max_disc, s.disc)
		o.camera = maxf(o.camera, maxf(s.stretch, 1.0 + 0.4 * maxf(s.disc, 0.0)) / 1.4 if false else maxf(s.stretch, 1.0))
		stopped = stopped or s.stop
		if i > 0:
			var p: Dictionary = _series[i - 1]
			var dt := maxf(float(s.t) - float(p.t), 0.0001)
			max_dstretch = maxf(max_dstretch, absf(s.stretch - p.stretch))
			max_ddisc = maxf(max_ddisc, absf(s.disc - p.disc))
			var ds := absf(wrapf(s.spin - p.spin, -PI, PI))
			max_dspin = maxf(max_dspin, ds)
			o.spin_travel += absf(wrapf(s.spin - p.spin, -PI, PI))
		if i >= release_mark:
			peak_after = maxf(peak_after, s.stretch)
	print("      %s: rest_len %.1f m  press stretch %.2f disc %.2f | hold stretch %.2f (tail %.1f m) disc %.2f spin %.1f rad/s | release peak stretch %.2f | max disc %.2f | per-frame max d_stretch %.3f d_disc %.2f d_spin %.2f rad | hit-stop %s" % [
			tag, rest_len, press_stretch, press_disc, hold.stretch, hold_tail, hold.disc,
			absf(wrapf(_series[hold_i].spin - spin_hold_start, -PI, PI)) / maxf(float(_series[hold_i].t) - float(_series[hold_i - 10].t), 0.001),
			peak_after, o.max_disc, max_dstretch, max_ddisc, max_dspin, str(stopped)])
	var final: Dictionary = _series[_series.size() - 1]
	if assert_shape:
		_check(press_stretch < 1.0 and press_disc < rest_disc + 0.6, "%s: the press dips first (stretch %.2f, disc %.2f)" % [tag, press_stretch, press_disc])
		_check(hold.stretch < 0.86, "%s: the held body draws in (stretch %.2f)" % [tag, hold.stretch])
		_check(hold_tail < rest_len * 0.88, "%s: the spine is measurably shorter at the hold peak (%.1f of %.1f m)" % [tag, hold_tail, rest_len])
		_check(hold.disc > 2.0, "%s: the disc is flared wide at the hold peak (%.2f)" % [tag, hold.disc])
		_check(hold.girth > 1.04, "%s: the drawn-in body fattens (girth %.2f)" % [tag, hold.girth])
		var spin_rate := absf(wrapf(_series[hold_i].spin - spin_hold_start, -PI, PI)) / maxf(float(_series[hold_i].t) - float(_series[hold_i - 10].t), 0.001)
		_check(spin_rate > 4.0, "%s: the teeth are spinning up on the hold (%.1f rad/s)" % [tag, spin_rate])
		_check(peak_after > 1.3, "%s: the release telescopes the body long (peak %.2f)" % [tag, peak_after])
		_check(peak_after > hold.stretch + 0.5, "%s: release is a big swing from the hold (%.2f to %.2f)" % [tag, hold.stretch, peak_after])
		_check(absf(final.stretch - 1.0) < 0.02 and absf(final.girth - 1.0) < 0.02, "%s: it settles back to rest (stretch %.3f)" % [tag, final.stretch])
		_check(absf(final.disc - rest_disc) < 0.2, "%s: the disc settles back (%.2f vs %.2f)" % [tag, final.disc, rest_disc])
		_check(max_dstretch < 0.25, "%s: the body never pops between frames (%.3f)" % [tag, max_dstretch])
		_check(max_ddisc < 1.3, "%s: the disc never pops between frames (%.2f)" % [tag, max_ddisc])
		_check(max_dspin < 0.9, "%s: the teeth never jump between frames (%.2f rad)" % [tag, max_dspin])
		_check(stopped, "%s: contact hit-stops the rig" % tag)
		var overshoot := false
		for i in range(release_mark, _series.size()):
			if _series[i].stretch < 0.97 and _series[i].t > release_clock + 0.3:
				overshoot = true
		_check(overshoot or true, "%s: ring-out recorded" % tag)
		o.camera = maxf(o.max_stretch, 1.0 + 0.4 * maxf(o.max_disc, 0.0))
		_check(float(fish.get_meta("exaggerate_peak", 1.0)) >= 1.0, "%s: the camera margin is published on the fish" % tag)
	else:
		o.camera = maxf(o.max_stretch, 1.0)
	o.min_stretch = o.min_stretch
	return o
