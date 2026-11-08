## AttackExaggerate (B0): the hunter exaggeration kit. Checks: master 0 is exactly rest, anticipation squash before the swell,
## 1.5-2.5x peaks at the default, overshoot then settle on release, smoothness (no pops), multipliers and the max clamp,
## hit-stop frames (and none when off), the camera punch signal, smear basis, peak/camera margin, stability at big steps.
##   Godot_console.exe --headless --path . res://tests/exaggerate_probe.tscn
extends Node

var checks := 0
var failures := 0


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


## Runs press -> hold(ramp) -> release and records the jaw/tail trace at 120 Hz.
func _cycle(ex: AttackExaggerate, hold_s := 0.6, settle_s := 2.0) -> Dictionary:
	var dt := 1.0 / 120.0
	var jaw: Array[float] = []
	var tail: Array[float] = []
	var peak := 0.0
	ex.press()
	for i in int(hold_s / dt):
		ex.hold(clampf(float(i) * dt / hold_s, 0.0, 1.0))
		ex.tick(dt)
		jaw.append(ex.scale_of(&"jaw"))
		tail.append(ex.scale_of(&"tail"))
		peak = maxf(peak, ex.scale_of(&"jaw"))
	var hold_end := jaw.size()
	ex.hold(1.0)
	ex.release(1.0)
	for i in int(settle_s / dt):
		ex.tick(dt)
		jaw.append(ex.scale_of(&"jaw"))
		tail.append(ex.scale_of(&"tail"))
	return {"jaw": jaw, "tail": tail, "peak": peak, "hold_end": hold_end}


func _max_step(a: Array[float]) -> float:
	var m := 0.0
	for i in range(1, a.size()):
		m = maxf(m, absf(a[i] - a[i - 1]))
	return m


func _ready() -> void:
	# master 0: exact rest through a full cycle, no hit-stop, no punch
	var off := AttackExaggerate.new({"master": 0.0})
	var punched := [0]
	off.camera_punch.connect(func(_a: float, _d: Vector3) -> void: punched[0] += 1)
	var r0 := _cycle(off)
	var all_one := true
	for v: float in r0["jaw"]:
		if v != 1.0:
			all_one = false
	_check(all_one, "master 0: every channel stays exactly 1.0")
	off.contact(1.0)
	_check(not off.in_hit_stop() and punched[0] == 0, "master 0: no hit-stop, no camera punch")
	_check(off.peak_scale() == 1.0 and off.camera_margin(0.5) == 0.5, "master 0: peak 1, camera margin unchanged")

	# default
	var ex := AttackExaggerate.new()
	var r := _cycle(ex)
	var jaw: Array[float] = r["jaw"]
	var tail: Array[float] = r["tail"]
	var peak: float = r["peak"]
	var hold_end: int = r["hold_end"]
	var early_min := 9.0
	for i in 30:
		early_min = minf(early_min, jaw[i])
	_check(early_min < 0.92, "press: anticipation squash dips the jaw below 0.92 first (min %.3f)" % early_min)
	_check(peak > 1.5 and peak <= 2.5, "hold: jaw peak in 1.5-2.5x (%.3f)" % peak)
	var tail_max := 0.0
	for v in tail:
		tail_max = maxf(tail_max, v)
	_check(tail_max > 1.5 and tail_max <= 2.5, "release: tail whip peak in 1.5-2.5x (%.3f)" % tail_max)
	var cross := 0
	for i in range(hold_end + 1, jaw.size()):
		if (jaw[i] - 1.0) * (jaw[i - 1] - 1.0) < 0.0:
			cross += 1
	_check(cross >= 2, "release: rings through rest at least twice (overshoot), crossings %d" % cross)
	_check(ex.idle() and absf(jaw[jaw.size() - 1] - 1.0) < 0.01, "settles back to 1.0 and goes idle (%.4f, phase %d)" % [jaw[jaw.size() - 1], ex.phase])
	var step := maxf(_max_step(jaw), _max_step(tail))
	_check(step < 0.3, "smooth: largest per-tick change at 120 Hz (the snap) %.4f < 0.3" % step)
	var tail_after: Array[float] = jaw.slice(hold_end + 14)
	_check(_max_step(tail_after) < 0.03, "smooth: after the snap the ring-out moves < 0.03 per tick (%.4f)" % _max_step(tail_after))
	var ring_max := 0.0
	for i in range(hold_end + 14, jaw.size()):
		ring_max = maxf(ring_max, jaw[i])
	_check(ring_max > 1.02 and ring_max < 1.4, "overshoot past rest is visible but modest (%.3f)" % ring_max)

	# multipliers
	var r2 := _cycle(AttackExaggerate.new({"master": 2.0}))
	var peak2: float = r2["peak"]
	_check(peak2 > peak and peak2 <= 3.5 + 0.001, "master 2 is bolder than 1 and clamped to max_scale (%.3f)" % peak2)
	var peak3: float = _cycle(AttackExaggerate.new({"master": 1.0, "form_mult": 0.5}))["peak"]
	_check(peak3 < peak and peak3 > 1.0, "form multiplier 0.5 is milder (%.3f)" % peak3)
	var peak4: float = _cycle(AttackExaggerate.new({"master": 9.0, "max_scale": 2.0}))["peak"]
	_check(peak4 <= 2.0 + 0.001, "max_scale clamps extreme settings (%.3f)" % peak4)
	var lo := 9.0
	var wild: Array[float] = _cycle(AttackExaggerate.new({"master": 9.0}))["jaw"]
	for v in wild:
		lo = minf(lo, v)
	_check(lo >= 0.35 - 0.001, "min_scale floors the squash (%.3f)" % lo)

	# hit-stop and punch
	var hs := AttackExaggerate.new()
	var amounts: Array[float] = []
	hs.camera_punch.connect(func(a: float, _d: Vector3) -> void: amounts.append(a))
	var stops := [0]
	hs.hit_stopped.connect(func(n: int) -> void: stops[0] = n)
	hs.press()
	hs.hold(1.0)
	hs.contact(1.0)
	_check(hs.in_hit_stop() and stops[0] >= 2 and stops[0] <= 3, "contact: hit-stop of 2-3 frames (%d)" % stops[0])
	var frozen := 0
	var first_dt := -1.0
	while hs.in_hit_stop() and frozen < 20:
		var d := hs.tick(1.0 / 60.0)
		if first_dt < 0.0:
			first_dt = d
		frozen += 1
	_check(frozen == stops[0] and first_dt < 0.1 / 60.0, "hit-stop lasts exactly its frames and time is ~frozen (%d frames, dt %.5f)" % [frozen, first_dt])
	_check(is_equal_approx(hs.tick(1.0 / 60.0), 1.0 / 60.0), "time returns to normal after the hit-stop")
	_check(amounts.size() == 1 and amounts[0] > 0.0, "contact emits one camera punch (%s)" % str(amounts))
	var hs2 := AttackExaggerate.new({"master": 2.0})
	var amounts2: Array[float] = []
	hs2.camera_punch.connect(func(a: float, _d: Vector3) -> void: amounts2.append(a))
	hs2.press()
	hs2.hold(1.0)
	hs2.contact(1.0)
	_check(amounts2[0] > amounts[0], "camera punch scales with exaggeration (%.2f vs %.2f)" % [amounts2[0], amounts[0]])

	# smear basis
	var sm := AttackExaggerate.new()
	sm.press()
	for i in 200:
		sm.hold(1.0)
		sm.tick(1.0 / 120.0)
	var held := sm.scale_basis(&"tail", Vector3.BACK)
	_check(held.z.z > 1.2 and held.x.x < 1.0 and held.y.y < 1.0, "stretch along the axis, thinner across it (z %.2f x %.2f)" % [held.z.z, held.x.x])
	var diag := sm.scale_basis(&"tail", Vector3(1, 1, 0))
	_check(absf(diag.x.y - diag.y.x) < 0.0001 and diag.x.y != 0.0, "diagonal axis gives a symmetric basis")
	sm.release(1.0)
	var smeared := 0.0
	for i in 6:
		sm.tick(1.0 / 120.0)
		smeared = maxf(smeared, sm.scale_basis(&"tail", Vector3.BACK).z.z / maxf(sm.scale_of(&"tail"), 0.001))
	_check(smeared > 1.02, "smear adds stretch while the part is moving (x%.3f)" % smeared)
	var node := Node3D.new()
	sm.apply(node, &"jaw")
	_check(node.scale.is_equal_approx(Vector3.ONE * sm.scale_of(&"jaw")), "apply() sets a uniform node scale")
	node.free()

	# camera safety
	var cam := AttackExaggerate.new()
	cam.press()
	for i in 120:
		cam.hold(1.0)
		cam.tick(1.0 / 120.0)
	_check(cam.peak_scale() > 1.5 and cam.camera_margin(0.4) > 0.4 * 1.5, "camera margin grows with the current peak (%.2f -> %.2f)" % [cam.peak_scale(), cam.camera_margin(0.4)])
	_check(cam.potential_peak() >= cam.peak_scale() - 0.01 and cam.potential_peak() <= 3.5, "potential_peak bounds the worst case (%.2f)" % cam.potential_peak())

	# stability
	var big := AttackExaggerate.new({"master": 2.0})
	big.press()
	var finite := true
	for i in 40:
		big.hold(1.0)
		big.tick(0.25)
		finite = finite and is_finite(big.scale_of(&"jaw"))
	big.release(1.0)
	for i in 40:
		big.tick(0.5)
		finite = finite and is_finite(big.scale_of(&"jaw"))
	_check(finite and absf(big.scale_of(&"jaw") - 1.0) < 0.01, "stable at 0.25-0.5 s steps (substepped)")

	# params_from without settings, custom channel, abort, reset
	var p := AttackExaggerate.params_from(null, {"exaggeration": 0.5, "exaggerate": {"antic_time": 0.2}})
	_check(is_equal_approx(p["form_mult"], 0.5) and is_equal_approx(p["antic_time"], 0.2) and is_equal_approx(p["master"], 1.0), "params_from reads form multiplier + preset, falls back without settings")
	var cu := AttackExaggerate.new({"channels": {"eyes": {"hold_peak": 1.8}}})
	cu.press()
	for i in 100:
		cu.hold(1.0)
		cu.tick(1.0 / 120.0)
	_check(cu.scale_of(&"eyes") > 1.3 and cu.scale_of(&"nope") == 1.0, "custom channels via the preset; unknown channel reads 1.0")
	cu.abort()
	for i in 360:
		cu.tick(1.0 / 120.0)
	_check(cu.idle() and absf(cu.scale_of(&"eyes") - 1.0) < 0.01, "abort eases back to rest without a snap")
	cu.press()
	cu.tick(0.05)
	cu.reset()
	_check(cu.idle() and cu.scale_of(&"jaw") == 1.0, "reset snaps to rest")

	print("exaggerate_probe: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
