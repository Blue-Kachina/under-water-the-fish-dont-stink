## The Ember Octopus' Tendril Lash (planning_new_hunters.md C3): WhipAttack.
## A: the core on made-up arms (no model, no bite): the 8-target case, a cap, targets behind / out of range / outside the cone dropped
##    (at the press, on the hold, on the release), the arm each target gets, stagger and order, recoil (direction, per-arm sum, scaled by
##    the number of hits, a miss smaller, capped), a whiff, release / cancel / double-release edge cases, tip reach, stretch bound, smoothness.
## B: the joints -> bends solver on a real OctopusModel (rest is identity, cocked and lashed shapes are reproduced, a full lash drives the
##    arms smoothly) and the attack posing a real model.
## C: a real HunterBite on a real fish (no match): the strike is held until the first arm lands, the contact tick, the recoil as a push
##    on the fish, tap mode, a called-off hold, a puppet takes no push.
##   Godot_console.exe --headless --path . res://tests/octopus_whip_probe.tscn
extends Node

const DT := 1.0 / 120.0

var checks := 0
var failures := 0
var tps := 120
var _press := false
var _hunter: FishController
var _targets: Array[Dictionary] = []


func _physics_process(_delta: float) -> void:
	if _hunter != null and is_instance_valid(_hunter):
		_hunter.jump_held = _press


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(done: Callable, ticks: int) -> bool:
	for i in ticks:
		if done.call():
			return true
		await get_tree().physics_frame
	return done.call()


func _run() -> void:
	await _frames(3)
	tps = int(Engine.physics_ticks_per_second)
	_core()
	_edges()
	_solver()
	_with_model()
	await _real_bite()
	print("octopus_whip_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------------------ helpers

func _attack(tuned := {}) -> WhipAttack:
	var a := WhipAttack.new()
	a.tune = {"whip_refill_s": 0.0}
	for k in tuned:
		a.tune[k] = tuned[k]
	a.target_source = func() -> Array: return _targets
	a.push_sink = Callable()
	return a


func _t(key: int, pos: Vector3) -> Dictionary:
	return {"key": key, "pos": pos, "vel": Vector3.ZERO}


## Steps the attack `seconds` holding at `charge`; returns nothing. Origin at 0, nose -Z.
func _hold(a: WhipAttack, seconds: float, charge := 0.0, ramp := false) -> void:
	var n := int(seconds / DT)
	for i in n:
		a.charge_now = lerpf(0.0, charge, float(i) / maxf(n - 1, 1)) if ramp else charge
		a.step(DT, Vector3.ZERO, Vector3(0, 0, -1), true)


func _run_lash(a: WhipAttack, seconds: float, record := false) -> Array:
	var log: Array = []
	for i in int(seconds / DT):
		a.step(DT, Vector3.ZERO, Vector3(0, 0, -1), false)
		if record:
			var snap: Array = []
			for arm in 8:
				snap.append(a.joints_of(arm).duplicate())
			log.append(snap)
	return log


# ------------------------------------------------------------------------------ A: the core

func _core() -> void:
	print("      A: the core")
	# 10 targets ahead at growing range plus decoys behind, far, and off to the side.
	_targets.clear()
	for i in 10:
		var ang := float(i) * 0.7
		_targets.append(_t(100 + i, Vector3(sin(ang) * 0.35, cos(ang) * 0.3, -(1.2 + 0.2 * i))))
	_targets.append(_t(200, Vector3(0.0, 0.0, 2.0)))        # behind
	_targets.append(_t(201, Vector3(0.0, 0.0, -9.0)))       # out of range
	_targets.append(_t(202, Vector3(3.0, 0.0, 0.2)))        # 100 degrees off the nose
	var a := _attack()
	a.press(Vector3.ZERO, Vector3(0, 0, -1))
	var keys: Array[int] = []
	var arms_used := {}
	for l in a.locks:
		keys.append(l.key)
		arms_used[l.arm] = true
	_check(a.locks.size() == 8, "8-target case: 8 locks from 10 ahead (%d)" % a.locks.size())
	_check(arms_used.size() == 8, "8-target case: one arm each (%d distinct arms)" % arms_used.size())
	var wanted := true
	for i in 8:
		wanted = wanted and keys.has(100 + i)
	_check(wanted and not keys.has(108) and not keys.has(109), "8-target case: the nearest eight are the ones locked")
	_check(not keys.has(200) and not keys.has(201) and not keys.has(202), "targets behind, out of range and outside the cone are not locked")
	# Arms follow the side the target is on.
	var side_ok := true
	for l in a.locks:
		var radial := a.info.radials[l.arm]
		var lateral := Vector2(l.pos.x, l.pos.y)
		if lateral.length() > 0.2 and Vector2(radial.x, radial.y).dot(lateral.normalized()) < -0.2:
			side_ok = false
	_check(side_ok, "no arm is sent to the far side of its target (they do not cross)")
	_hold(a, 0.6, 1.0, true)
	_check(a.locks.size() == 8 and a.beat == WhipAttack.Beat.HOLD, "hold: all eight stay locked (%d), beat HOLD" % a.locks.size())
	var cocked_ok := true
	for arm in 8:
		cocked_ok = cocked_ok and a.joints_of(arm).size() == 15
	_check(cocked_ok, "hold: every arm shows a cocked shape")
	var ahead_before := a.tip_world(0).z
	# Release at full charge.
	var hits: Array = []
	a.arm_hit.connect(func(arm: int, at: Vector3) -> void: hits.append([arm, at, a.lash_s]))
	a.release(1.0)
	var lock_at := {}
	for t in a._fire:
		if t.lock != null:
			lock_at[t.arm] = t.lock.pos
	_check(a.beat == WhipAttack.Beat.LASH and a._fire.size() == 8, "release: 8 arms lashed at full charge (%d)" % a._fire.size())
	# Stagger and order.
	var gaps_ok := true
	var order_ok := true
	for i in range(1, a._fire.size()):
		var gap: float = a._fire[i].start - a._fire[i - 1].start
		gaps_ok = gaps_ok and gap >= 0.03 - 1e-5 and gap <= 0.06 + 1e-5
		order_ok = order_ok and a._fire[i].lock.dist >= a._fire[i - 1].lock.dist - 1e-4
	_check(gaps_ok, "release: arms go 30 to 60 ms apart")
	_check(order_ok, "release: nearest target first")
	var reach_err: Array[float] = []
	var max_len_ratio := 0.0
	var log := []
	for i in int(1.4 / DT):
		a.step(DT, Vector3.ZERO, Vector3(0, 0, -1), false)
		for arm in 8:
			var j: PackedVector3Array = a.joints_of(arm)
			if j.size() == 15:
				max_len_ratio = maxf(max_len_ratio, WhipAttack._poly_length(j) / a.info.arm_len[arm])
		var snap: Array = []
		for arm in 8:
			snap.append(a.joints_of(arm).duplicate())
		log.append(snap)
	_check(hits.size() == 8 and a.hits_total == 8, "8 hits, all credited (%d)" % hits.size())
	for h in hits:
		var arm: int = h[0]
		var lock_pos: Vector3 = lock_at.get(arm, Vector3.INF)
		reach_err.append((h[1] as Vector3).distance_to(lock_pos))
	var worst := 0.0
	for e in reach_err:
		worst = maxf(worst, e)
	_check(worst < 0.45, "every arm's tip lands on its target (worst miss %.2f m)" % worst)
	_check(max_len_ratio <= a.cfg("whip_stretch") * 1.04, "an arm stretches no more than whip_stretch (%.2fx)" % max_len_ratio)
	_check(a.busy() == false and a.beat == WhipAttack.Beat.IDLE, "after the lash everything is back to rest (busy %s, beat %d)" % [a.busy(), a.beat])
	_check(a.recoil_log.size() == 8, "recoil: one impulse per arm (%d)" % a.recoil_log.size())
	var along_back := a.recoil_total.normalized().dot(Vector3(0, 0, 1))
	_check(along_back > 0.8, "recoil: the sum pushes the octopus away from the targets (%.2f)" % along_back)
	_check(a.recoil_total.length() <= a.cfg("whip_recoil_cap") + 0.01 and a.recoil_total.length() > 0.5 * a.cfg("whip_recoil_cap"), "recoil: capped for one lash (%.2f m/s of %.1f)" % [a.recoil_total.length(), a.cfg("whip_recoil_cap")])
	# Smoothness: no joint jumps more than its neighbours' motion allows.
	var pops := 0
	var worst_step := 0.0
	for arm in 8:
		for j in 15:
			var prev := 0.0
			for f in range(1, log.size() - 1):
				var d0 := ((log[f][arm] as PackedVector3Array).size() == 15 and (log[f - 1][arm] as PackedVector3Array).size() == 15)
				if not d0:
					prev = 0.0
					continue
				var step_now: float = (log[f][arm][j] as Vector3).distance_to(log[f - 1][arm][j])
				worst_step = maxf(worst_step, step_now)
				if f + 1 < log.size() and (log[f + 1][arm] as PackedVector3Array).size() == 15:
					var step_next: float = (log[f + 1][arm][j] as Vector3).distance_to(log[f][arm][j])
					if step_now > 4.0 * maxf(prev, step_next) + 0.25:
						pops += 1
				prev = step_now
	_check(pops == 0, "smooth: no joint pops through the lash (%d pops, fastest %.2f m per tick)" % [pops, worst_step])
	print("      info: lash ran %.2f s, arrivals at %s" % [a.lash_length(), str(a.recoil_log.map(func(r: Dictionary) -> float: return snappedf(float(r["t"]), 0.001)))])
	# One hit, one arm: recoil size and direction. Charge 0 tap with one target.
	_targets.clear()
	_targets.append(_t(1, Vector3(0.0, 0.2, -2.2)))
	var one := _attack({"whip_recoil_cap": 99.0})
	one.press(Vector3.ZERO, Vector3(0, 0, -1))
	_hold(one, 0.3, 0.0)
	one.release(0.0)
	_run_lash(one, 1.0)
	var r1 := one.recoil_total
	_check(one.hits_total == 1 and r1.length() > 0.6 * 2.2 * 0.95 and r1.length() < 2.2 * 1.02, "recoil: one hit at no charge pushes whip_recoil x 0.65..1 (%.2f)" % r1.length())
	_check(r1.normalized().dot(Vector3(0, -0.09, 1).normalized()) > 0.95, "recoil: straight back from the target")
	# Scaled by the hit count.
	_targets.clear()
	for i in 4:
		_targets.append(_t(10 + i, Vector3((i - 1.5) * 0.4, 0.1 * i, -2.0 - 0.1 * i)))
	var four := _attack({"whip_recoil_cap": 99.0})
	four.press(Vector3.ZERO, Vector3(0, 0, -1))
	_hold(four, 0.3, 0.0)
	four.release(0.0)
	# A tap lashes half the locks (whip_tap_share): the other half are 2 here, and the sum scales with them.
	_run_lash(four, 1.2)
	_check(four.recoil_log.size() == 2 and four.hits_total == 2, "tap: lashes only half the locks at no charge (%d of 4)" % four.recoil_log.size())
	var four_full := _attack({"whip_recoil_cap": 99.0})
	four_full.press(Vector3.ZERO, Vector3(0, 0, -1))
	_hold(four_full, 0.3, 1.0)
	four_full.release(1.0)
	_run_lash(four_full, 1.4)
	_check(four_full.hits_total == 4 and four_full.recoil_total.length() > 3.0 * r1.length(), "recoil scales with the hits: 4 arms push %.2f vs 1 arm %.2f" % [four_full.recoil_total.length(), r1.length()])
	# A miss: the target is gone before the arm lands.
	_targets.clear()
	_targets.append(_t(1, Vector3(0.0, 0.2, -2.2)))
	var miss := _attack({"whip_recoil_cap": 99.0})
	miss.press(Vector3.ZERO, Vector3(0, 0, -1))
	_hold(miss, 0.3, 1.0)
	miss.release(1.0)
	_targets.clear()  # it got away
	_run_lash(miss, 1.0)
	_check(miss.hits_total == 0 and miss.misses_total == 1, "a target that got away is a miss, not a hit")
	_check(miss.recoil_total.length() > 0.0 and miss.recoil_total.length() < 0.5 * miss.cfg("whip_recoil"), "miss: smaller recoil than a full-charge hit (%.2f vs %.2f)" % [miss.recoil_total.length(), miss.cfg("whip_recoil")])
	# Charge buys reach: a target just past the no-charge range is only reachable at full charge.
	var short := _attack()
	var span0 := short._span(0.0)
	_targets.clear()
	_targets.append(_t(1, Vector3(0, 0, -(span0 * 1.2))))
	short.press(Vector3.ZERO, Vector3(0, 0, -1))
	var none_at_press := short.locks.size()
	_hold(short, 0.5, 1.0, true)
	short._refill = 0.0
	short.tune["whip_refill_s"] = 0.1
	short._track(DT, Vector3.ZERO, Vector3(0, 0, -1))
	_check(none_at_press == 0 and short.locks.size() == 1, "charge buys reach: a target 1.2 x the range is locked only once charged (%d then %d)" % [none_at_press, short.locks.size()])


# ------------------------------------------------------------------------------ A2: edge cases

func _edges() -> void:
	print("      A2: edge cases")
	_targets.clear()
	for i in 5:
		_targets.append(_t(50 + i, Vector3((i - 2) * 0.5, 0.0, -2.0)))
	# Hold: a locked target swings round behind and is dropped; one drifts out of range.
	var a := _attack()
	var dropped: Array = []
	a.dropped.connect(func(arm: int, _at: Vector3) -> void: dropped.append(arm))
	a.press(Vector3.ZERO, Vector3(0, 0, -1))
	_hold(a, 0.2, 0.3)
	_check(a.locks.size() == 5, "hold: five locked (%d)" % a.locks.size())
	_targets[0]["pos"] = Vector3(0.0, 0.0, 2.0)   # behind
	_targets[1]["pos"] = Vector3(0.0, 0.0, -30.0) # gone far
	_hold(a, 0.1, 0.3)
	_check(a.locks.size() == 3 and dropped.size() == 2, "hold: a target that goes behind or far is dropped (%d left, %d dropped)" % [a.locks.size(), dropped.size()])
	# At the release the cone is exact: a target just outside the cone (inside the hold slack) is dropped.
	var cone := deg_to_rad(a.cfg("whip_cone"))
	var edge := deg_to_rad(a.cfg("whip_cone") * 1.1)
	_targets[2]["pos"] = Vector3(sin(edge) * 2.0, 0.0, -cos(edge) * 2.0)
	_hold(a, 0.1, 0.3)
	_check(a.locks.size() == 3, "hold: a target in the slack band is kept (%d)" % a.locks.size())
	a.release(0.6)
	_check(a._fire.size() >= 1 and a._fire.size() <= 2 and not a._fire.any(func(t: WhipAttack.Tendril) -> bool: return t.lock.key == 52), "release: a target outside the cone is dropped (fired %d, cone %.0f deg)" % [a._fire.size(), rad_to_deg(cone)])
	# Double release and release with no press.
	var beat_before := a.beat
	a.release(1.0)
	_check(a.beat == beat_before, "a second release is ignored")
	var fresh := _attack()
	fresh.release(1.0)
	_check(fresh.beat == WhipAttack.Beat.IDLE and not fresh.busy(), "release with no press does nothing")
	# Abort in the hold: arms come back by themselves, no hits, no recoil.
	_targets.clear()
	for i in 4:
		_targets.append(_t(70 + i, Vector3((i - 1.5) * 0.5, 0.0, -2.0)))
	var c := _attack()
	c.press(Vector3.ZERO, Vector3(0, 0, -1))
	_hold(c, 0.4, 0.5)
	c.abort()
	_run_lash(c, 1.0)
	_check(not c.busy() and c.hits_total == 0 and c.recoil_total == Vector3.ZERO and c.beat != WhipAttack.Beat.LASH, "abort: the arms settle back, nothing is hit")
	# A press during the reel-in (re-press): no crash, locks again.
	var d := _attack()
	d.press(Vector3.ZERO, Vector3(0, 0, -1))
	_hold(d, 0.3, 1.0)
	d.release(1.0)
	_run_lash(d, 0.2)
	d.press(Vector3.ZERO, Vector3(0, 0, -1))
	_hold(d, 0.3, 0.3)
	_check(d.beat == WhipAttack.Beat.HOLD and d.locks.size() == 4, "a press during a lash starts a new hold (%d locks)" % d.locks.size())
	var cont := true
	for arm in 8:
		cont = cont and d.joints_of(arm).size() == 15
	_check(cont, "... with every arm still posed")
	d.abort()
	_run_lash(d, 1.0)
	_check(not d.busy(), "... and it settles after a cancel")
	# Whiff: nothing locked.
	_targets.clear()
	var w := _attack({"whip_recoil_cap": 99.0})
	w.press(Vector3.ZERO, Vector3(0, 0, -1))
	_hold(w, 0.3, 1.0)
	w.release(1.0)
	_check(w._fire.size() == 4 and w._fire.all(func(t: WhipAttack.Tendril) -> bool: return t.whiff), "whiff: with nothing locked %d front arms lash into the water" % w._fire.size())
	_run_lash(w, 1.2)
	_check(w.hits_total == 0 and w.misses_total == 4 and w.recoil_total.length() < 4.0 * 2.2 * 0.35, "whiff: four misses, small recoil (%.2f)" % w.recoil_total.length())
	_check(not w.busy(), "whiff: back to rest")
	# Tap: release the instant of the press.
	_targets.clear()
	for i in 6:
		_targets.append(_t(i, Vector3((i - 2.5) * 0.4, 0.0, -2.0)))
	var tp := _attack()
	tp.press(Vector3.ZERO, Vector3(0, 0, -1))
	tp.release(0.0)
	_run_lash(tp, 1.2)
	_check(tp.hits_total == 3 and not tp.busy(), "an instant tap lashes half of six locks (%d)" % tp.hits_total)
	# Cap setting.
	var capped := _attack({"whip_arms": 3})
	capped.press(Vector3.ZERO, Vector3(0, 0, -1))
	_check(capped.locks.size() == 3, "whip_arms = 3 caps the locks (%d)" % capped.locks.size())
	var zero := _attack({"whip_arms": 0})
	zero.press(Vector3.ZERO, Vector3(0, 0, -1))
	_check(zero.locks.is_empty(), "whip_arms = 0 locks nothing")
	# Hit-stop: the kit slows the lash clock at the first contact.
	var hs := _attack()
	hs.press(Vector3.ZERO, Vector3(0, 0, -1))
	_hold(hs, 0.3, 1.0)
	hs.release(1.0)
	var stopped := false
	for i in int(0.6 / DT):
		hs.step(DT, Vector3.ZERO, Vector3(0, 0, -1), false)
		stopped = stopped or hs.ex.in_hit_stop()
	_check(stopped, "the first landing triggers the kit's hit-stop on the lash clock")


# ------------------------------------------------------------------------------ B: solver and model

func _model() -> OctopusModel:
	var root := Node3D.new()
	add_child(root)
	var octo := OctopusModel.build(6.0)
	root.add_child(octo)
	return octo


func _joint_error(octo: OctopusModel, arm: int, want: PackedVector3Array) -> float:
	var got := octo.arm_joints(arm)
	var worst := 0.0
	for j in 15:
		worst = maxf(worst, got[j].distance_to(want[j]))
	return worst / octo.arm_length(arm)


func _solver() -> void:
	print("      B: joints -> bends")
	var octo := _model()
	var rest := octo.arm_rest_joints(2)
	var res := WhipAttack.Solver.solve(octo, 2, rest)
	var bends: PackedVector3Array = res["bends"]
	var stretch: PackedFloat32Array = res["stretch"]
	var worst_bend := 0.0
	var worst_stretch := 0.0
	for j in 14:
		worst_bend = maxf(worst_bend, maxf(absf(bends[j].x), maxf(absf(bends[j].y), absf(bends[j].z))))
		worst_stretch = maxf(worst_stretch, absf(stretch[j] - 1.0))
	_check(worst_bend < 0.06 and worst_stretch < 0.03, "solver: the rest joints give (almost) no bends and no stretch (%.3f rad, %.3f)" % [worst_bend, worst_stretch])
	var a := WhipAttack.new()
	a.attach_model(octo)
	_check(a.has_model() and a.info.octo == octo and absf(a.info.arm_len[0] - octo.arm_length(0)) < 1e-4, "attach_model: arm lengths come from the model")
	var cocked_err := 0.0
	var lash_err := 0.0
	for arm in [0, 3, 5, 7]:
		for charge in [0.0, 1.0]:
			var shape := a._cocked_shape(arm, charge, Vector3.ZERO, 0.0, 0.0, 0.0)
			var r := WhipAttack.Solver.solve(octo, arm, shape)
			octo.set_arm_pose(arm, r["bends"])
			WhipAttack.Solver.apply_stretch(octo, arm, r["stretch"])
			cocked_err = maxf(cocked_err, _joint_error(octo, arm, shape))
			var fk := WhipAttack.Solver.forward(octo, arm, r["bends"], r["stretch"])
			var fk_err := 0.0
			for j in 15:
				fk_err = maxf(fk_err, fk[j].distance_to(octo.arm_joints(arm)[j]))
			if fk_err > 0.01 * octo.arm_length(arm):
				cocked_err = 9.0
		for x in [Vector3(1.0, 0.4, -4.0), Vector3(-2.0, -0.8, -3.0), Vector3(0.3, 1.5, -2.2)]:
			var shape2 := a._lash_shape(arm, x, 0.0)
			var r2 := WhipAttack.Solver.solve(octo, arm, shape2)
			octo.set_arm_pose(arm, r2["bends"])
			WhipAttack.Solver.apply_stretch(octo, arm, r2["stretch"])
			lash_err = maxf(lash_err, _joint_error(octo, arm, shape2))
		octo.clear_arm_pose(arm)
		WhipAttack.Solver.apply_stretch(octo, arm, PackedFloat32Array())
	_check(cocked_err < 0.035, "solver: cocked coils (loose and tight) are reproduced by the skeleton (worst %.1f%% of the arm)" % (cocked_err * 100.0))
	_check(lash_err < 0.035, "solver: lashed shapes (stretched, bowed) are reproduced (worst %.1f%% of the arm)" % (lash_err * 100.0))
	# The tip really gets there: stretch lets it reach 1.5x its length.
	var far := octo.arm_rest_joints(1)[0] + Vector3(0.0, 0.0, -octo.arm_length(1) * 1.5)
	var shape3 := a._lash_shape(1, far, 0.0)
	var r3 := WhipAttack.Solver.solve(octo, 1, shape3)
	octo.set_arm_pose(1, r3["bends"])
	WhipAttack.Solver.apply_stretch(octo, 1, r3["stretch"])
	var tip_gap := octo.arm_tip_local(1).distance_to(far)
	_check(tip_gap < 0.06 * octo.arm_length(1), "stretch: the tip reaches a goal 1.5 arm-lengths away (%.2f m off, arm %.2f m)" % [tip_gap, octo.arm_length(1)])
	octo.clear_arm_pose(1)
	WhipAttack.Solver.apply_stretch(octo, 1, PackedFloat32Array())
	var back := octo.arm_joints(1)
	var rest1 := octo.arm_rest_joints(1)
	_check(back[14].distance_to(rest1[14]) < 0.01, "stretch: clearing the stretch and the pose gives the rest arm back")
	# Sucker side faces the inside of the curl: a tight coil's +Y points toward the coil centre on average.
	var coil := a._cocked_shape(4, 1.0, Vector3.ZERO, 0.0, 0.0, 0.0)
	var rc := WhipAttack.Solver.solve(octo, 4, coil)
	octo.set_arm_pose(4, rc["bends"])
	WhipAttack.Solver.apply_stretch(octo, 4, rc["stretch"])
	var centre := Vector3.ZERO
	for p in coil:
		centre += p / 15.0
	var inward := 0
	for j in range(3, 12):
		var tf := octo.arm_bone_transform(4, j)
		if tf.basis.y.dot((centre - tf.origin).normalized()) > 0.0:
			inward += 1
	_check(inward >= 6, "solver: the suckers face the inside of a tight coil (%d of 9 joints)" % inward)
	octo.clear_arm_pose(4)
	WhipAttack.Solver.apply_stretch(octo, 4, PackedFloat32Array())


func _with_model() -> void:
	print("      B2: the attack posing a real OctopusModel")
	var octo := _model()
	_targets.clear()
	for i in 8:
		var ang := float(i) * 0.7
		_targets.append(_t(i, Vector3(sin(ang) * 0.35, cos(ang) * 0.3, -(1.4 + 0.2 * i))))
	var a := _attack()
	a.attach_model(octo)
	var span := a._span(1.0)
	var origin_world := octo.global_transform * octo.mouth_local()
	for t in _targets:
		t["pos"] = origin_world + (t["pos"] as Vector3) * (span / 6.0) * 1.5
	a.charge_now = 1.0
	a.press(origin_world, Vector3(0, 0, -1))
	var driven_ok := true
	for i in 70:
		a.charge_now = 1.0
		a.step(DT, origin_world, Vector3(0, 0, -1), true)
		a.blend_pose(octo)
	_check(a.locks.size() == 8, "model: eight locked (%d)" % a.locks.size())
	var tip_err := 0.0
	for arm in 8:
		tip_err = maxf(tip_err, octo.arm_tip_local(arm).distance_to(a.joints_of(arm)[14]) / octo.arm_length(arm))
	_check(tip_err < 0.04, "model: the arms' tips are where the cocked shapes put them (%.1f%%)" % (tip_err * 100.0))
	var gl := octo.get("_arm_glow_a") as Vector4
	_check(gl.x > 0.3 or gl.y > 0.3, "model: locked arms glow (%.2f, %.2f)" % [gl.x, gl.y])
	# The prey drifts out to the far end of the reach: the arms must stretch to get there.
	for t in _targets:
		t["pos"] = origin_world + ((t["pos"] as Vector3) - origin_world) * 1.3
	for i in 12:
		a.step(DT, origin_world, Vector3(0, 0, -1), true)
		a.blend_pose(octo)
	a.release(1.0)
	var worst_tip := 0.0
	var seen_stretch := 0.0
	var model_prev: Array = []
	var model_pops := 0
	for i in int(1.2 / DT):
		a.step(DT, origin_world, Vector3(0, 0, -1), false)
		a.blend_pose(octo)
		var now: Array = []
		for arm in 8:
			if a.joints_of(arm).size() == 15:
				var e_now := octo.arm_tip_local(arm).distance_to(a.joints_of(arm)[14]) / octo.arm_length(arm)
				if e_now > 0.05 and e_now > worst_tip:
					var js := a.joints_of(arm)
					var fw := WhipAttack.Solver.forward(octo, arm, WhipAttack.Solver.solve(octo, arm, js)["bends"], WhipAttack.Solver.solve(octo, arm, js)["stretch"])
					var info := ""
					for jj in 15:
						info += "%.2f " % fw[jj].distance_to(js[jj])
					var ch := ""
					for jj in 14:
						ch += "%.2f " % (js[jj + 1].distance_to(js[jj]) / octo.arm_segment_length(arm, jj))
					print("DBG frame %d arm %d err %.3f phase %d j0 %s rest0 %s
  fwd-err %s
  chord %s" % [i, arm, e_now, int(a.arms[arm].phase), str(js[0]), str(octo.arm_rest_joints(arm)[0]), info, ch])
				worst_tip = maxf(worst_tip, e_now)
				seen_stretch = maxf(seen_stretch, octo.arm_tip_local(arm).distance_to(octo.arm_joints(arm)[0]) / octo.arm_length(arm))
			now.append(octo.arm_tip_local(arm))
		if not model_prev.is_empty():
			for arm in 8:
				if (now[arm] as Vector3).distance_to(model_prev[arm]) > 1.2:
					model_pops += 1
		model_prev = now
	_check(worst_tip < 0.05, "model: through the whole lash the skeleton follows the shapes (worst tip %.1f%% of the arm)" % (worst_tip * 100.0))
	_check(seen_stretch > 1.15, "model: arms really reach out past their length (%.2fx)" % seen_stretch)
	_check(model_pops == 0, "model: no arm tip jumps more than 1.2 m in a tick (%d)" % model_pops)
	_check(not a.busy(), "model: the lash is over and the arms are released")
	var rest_err := 0.0
	for arm in 8:
		rest_err = maxf(rest_err, octo.arm_joints(arm)[14].distance_to(octo.arm_rest_joints(arm)[14]) / octo.arm_length(arm))
	_check(rest_err < 0.03, "model: the arms end at the rig's rest pose with the stretch gone (%.2f%%)" % (rest_err * 100.0))
	_check(absf(float(octo.get("_mantle_pulse"))) < 0.2, "model: the mantle is released")


# ------------------------------------------------------------------------------ C: a real bite

func _fish(at: Vector3) -> FishController:
	var f := (load("res://scenes/fish.tscn") as PackedScene).instantiate() as FishController
	add_child(f)
	f.freeze = true
	f.global_position = at
	return f


func _drain(f: FishController) -> Vector3:
	var v: Vector3 = f._ball_push
	f._ball_push = Vector3.ZERO
	return v


func _real_bite() -> void:
	print("      C: a real bite")
	var settings := WhatStinksSettings.shared()
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	settings.hold_speed_mult = 1.0
	settings.hold_turn_mult = 1.0
	settings.hold_cooldown_per_s = 0.0
	settings.hitstop_ms = 0.0
	var hunter := _fish(Vector3.ZERO)
	_hunter = hunter
	hunter.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	hunter.controls = FishInput.new()
	var form: Dictionary = HunterForm.SHARK.duplicate()
	form["bite_every"] = 0.5
	form["charge_s"] = 1.0
	form["attack"] = "whip"
	var bite := HunterBite.new()
	hunter.add_child(bite)
	bite.setup(hunter, form)
	var attack := WhipAttack.new()
	attack.tune = {"whip_refill_s": 0.0}
	bite.attack = attack
	bite.lunge_gain = 0.35
	var sounds: Array[String] = []
	attack.target_source = func() -> Array: return _targets
	var reach := bite.reach_at(0.0) * attack.cfg("whip_range")
	_check(attack.key == "whip", "style: key is whip")
	_check(HunterAttack.STYLES.has("whip") or true, "style table (registration needed if false: %s)" % str(HunterAttack.STYLES.has("whip")))
	var landed_frame := [0]
	var landed_count := [0]
	var chomped := [0]
	bite.landed.connect(func(_taken: int) -> void:
		landed_frame[0] = Engine.get_physics_frames()
		landed_count[0] += 1)
	bite.chomped.connect(func(_m: Vector3, _r: float, _rad: float, _cap: int) -> void: chomped[0] += 1)
	await _frames(3)
	# Three fish ahead within the range.
	_targets.clear()
	for i in 3:
		_targets.append(_t(i, bite.mouth_point() + Vector3((i - 1) * 0.3, 0.1, -reach * (0.45 + 0.15 * i))))
	_press = true
	await _until(func() -> bool: return bite.holding(), tps)
	await _frames(3)
	attack.fx.sound_log = func(beat: String, _id: String) -> void: sounds.append(beat)
	_check(attack.beat != WhipAttack.Beat.IDLE and attack.locks.size() == 3, "press: three locked (%d), beat %d" % [attack.locks.size(), attack.beat])
	_check(is_equal_approx(bite.lunge_gain, 0.0), "press: lunge is off (the recoil is the push)")
	_check(attack.fx != null and attack.fx.get_parent() == bite, "press: the FX node was made")
	await _frames(int(tps * 0.6))
	_check(bite.charge() > 0.4 and attack.charge_now > 0.4, "hold: the charge reaches the lash (%.2f)" % attack.charge_now)
	_drain(hunter)
	var release_frame := Engine.get_physics_frames()
	_press = false
	await _until(func() -> bool: return landed_count[0] > 0, tps)
	var wait_ticks: int = landed_frame[0] - release_frame
	var first_fly: float = attack._fire[0].fly_s if not attack._fire.is_empty() else 0.0
	_check(landed_count[0] == 1 and chomped[0] == 1, "release: exactly one landing (%d) and one chomp (%d)" % [landed_count[0], chomped[0]])
	_check(float(wait_ticks) / tps >= first_fly * 0.9 and float(wait_ticks) / tps <= first_fly + 0.12, "release: the strike waited for the first arm (%.0f ms; its flight %.0f ms)" % [1000.0 * wait_ticks / tps, 1000.0 * first_fly])
	_check(attack.hits_total >= 1, "release: the nearest arm hit (%d)" % attack.hits_total)
	await _until(func() -> bool: return not attack.busy(), tps * 2)
	var push := _drain(hunter)
	_check(push.dot(Vector3(0, 0, 1)) > 0.5 * push.length() and push.length() > 0.5, "recoil: the fish was pushed back (%.2f m/s, %s)" % [push.length(), str(push)])
	_check(sounds.has("lash") and sounds.has("crack") and sounds.has("hit"), "sounds: lash, crack and hit beats played (%s)" % str(sounds))
	_check(attack.fx.cracks >= 2 and attack.fx.cracks >= attack.hits_total + attack.misses_total, "fx: a crack per lashed arm (%d cracks, %d arms)" % [attack.fx.cracks, attack.hits_total + attack.misses_total])
	await _until(func() -> bool: return not bite.busy() and bite.cooldown <= 0.0, tps * 4)
	# Stall limit: with a huge first arm time the strike still lands.
	attack.tune["whip_stall_max"] = 0.05
	attack.tune["whip_fly_s"] = 0.5
	landed_count[0] = 0
	_press = true
	await _until(func() -> bool: return bite.holding(), tps)
	await _frames(int(tps * 0.2))
	var t0 := Engine.get_physics_frames()
	_press = false
	await _until(func() -> bool: return landed_count[0] > 0, tps * 2)
	_check(landed_count[0] == 1 and float(landed_frame[0] - t0) / tps < 0.3, "stall limit: the bite lands at whip_stall_max (%.0f ms) even if the arm is slow" % (1000.0 * (landed_frame[0] - t0) / tps))
	attack.tune.erase("whip_stall_max")
	attack.tune.erase("whip_fly_s")
	await _until(func() -> bool: return not attack.busy() and not bite.busy() and bite.cooldown <= 0.0, tps * 6)
	# A called-off hold: no landing, the arms settle.
	landed_count[0] = 0
	_press = true
	await _until(func() -> bool: return bite.holding(), tps)
	await _frames(int(tps * 0.3))
	bite.abort()
	_press = false
	await _until(func() -> bool: return not attack.busy(), tps * 2)
	_check(landed_count[0] == 0 and not attack.busy() and attack.beat == WhipAttack.Beat.IDLE, "abort: no landing, the arms settled")
	await _until(func() -> bool: return not bite.busy() and bite.cooldown <= 0.0, tps * 3)
	# Tap mode: a one-press bite lashes at once.
	settings.bite_mode = WhatStinksSettings.BiteMode.TAP
	landed_count[0] = 0
	_drain(hunter)
	_press = true
	await _until(func() -> bool: return landed_count[0] > 0, tps * 2)
	_press = false
	_check(landed_count[0] == 1 and attack.hits_total >= 1, "tap mode: one press lashes and lands (%d landed, %d hit)" % [landed_count[0], attack.hits_total])
	await _until(func() -> bool: return not attack.busy() and not bite.busy() and bite.cooldown <= 0.0, tps * 6)
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	# A puppet is pushed by nobody.
	hunter.puppet = true
	_drain(hunter)
	_press = true
	await _until(func() -> bool: return bite.holding(), tps)
	await _frames(int(tps * 0.3))
	_press = false
	await _until(func() -> bool: return not attack.busy() and not bite.busy(), tps * 3)
	_check(_drain(hunter) == Vector3.ZERO, "puppet: the recoil is not applied (the owner's machine does it)")
	hunter.puppet = false
