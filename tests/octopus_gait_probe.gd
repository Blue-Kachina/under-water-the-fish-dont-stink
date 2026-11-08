## OctopusRig (C2) gait on a bare rig (no fish): the direction -> bends converter is exact, the jet cycle (mantle squeeze and refill, arms
## bundle then flare, thrust only in the power stroke along the siphon), cruise scull, idle life, crawl (feet plant on a floor, world fixed
## while planted, they step, arms reach them, blend in and out), gait transitions without pops (per-frame tip steps and jerk), inertia in a
## spin, finite everywhere, and the per-frame cost of 8 arms x 14 segments.
##   --trace prints gait frame summaries.
## Run headless: Godot_console.exe --headless --path . res://tests/octopus_gait_probe.tscn
extends Node

const L := 6.0
var checks := 0
var failures := 0
var rig: OctopusRig
var floor_y := -1.0e9
var _trace := false


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


func _plane(from: Vector3, to: Vector3) -> Dictionary:
	if from.y >= floor_y and to.y <= floor_y:
		var t := (from.y - floor_y) / maxf(from.y - to.y, 0.0001)
		return {"pos": from.lerp(to, t), "normal": Vector3.UP}
	return {}


func _ready() -> void:
	_trace = OS.get_cmdline_user_args().has("--trace")
	_run.call_deferred()


func _fresh() -> void:
	if rig != null:
		rig.queue_free()
		await get_tree().process_frame
	rig = OctopusRig.new()
	add_child(rig)
	rig.build_model(L)
	rig.floor_query = _plane
	floor_y = -1.0e9


## Every arm's tip, model space.
func _tips() -> PackedVector3Array:
	var out := PackedVector3Array()
	for a in 8:
		out.append(rig.model.arm_tip_local(a))
	return out


class Run:
	var max_step := 0.0
	var max_jerk := 0.0
	var mean_move := 0.0
	var finite := true
	var mantle_min := 1.0
	var mantle_max := -1.0
	var spread_min := 1.0
	var spread_max := -1.0
	var env_sum := 0.0
	var dv_sum := Vector3.ZERO
	var frames := 0
	var crawl_max := 0.0


## Steps `seconds` with a per-frame context callable(t) -> Dictionary, integrating the thrust into the velocity the rig is given.
func _go(seconds: float, ctxf: Callable, r: Run, vel0 := Vector3.ZERO, dt := 1.0 / 60.0) -> Vector3:
	var vel := vel0
	var prev := _tips()
	var prev2 := prev
	var n := int(seconds / dt)
	var last_step := 0.0
	for i in n:
		var c: Dictionary = ctxf.call(float(i) * dt)
		if not c.has("vel"):
			c["vel"] = vel
		else:
			vel = c["vel"]
		rig.step(dt, c)
		var gb := rig.model.global_basis.orthonormalized()
		var dv := rig.thrust_dv(dt, gb)
		vel += dv
		r.dv_sum += dv
		var tips := _tips()
		for a in 8:
			var p := tips[a]
			if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
				r.finite = false
				continue
			var st := p.distance_to(prev[a]) / L
			last_step = maxf(last_step, st)
			r.max_step = maxf(r.max_step, st)
			r.mean_move += st
			var j2 := (p - 2.0 * prev[a] + prev2[a]).length() / L
			if i > 3:
				r.max_jerk = maxf(r.max_jerk, j2)
		prev2 = prev
		prev = tips
		r.mantle_min = minf(r.mantle_min, rig.shown["mantle"])
		r.mantle_max = maxf(r.mantle_max, rig.shown["mantle"])
		r.spread_min = minf(r.spread_min, rig.shown["spread"])
		r.spread_max = maxf(r.spread_max, rig.shown["spread"])
		r.env_sum += rig.shown["jet_env"] * dt
		r.crawl_max = maxf(r.crawl_max, rig.shown["crawl"])
		r.frames += 1
		if _trace and i % 6 == 0:
			print("    t %.2f jet_t %.2f mantle %.2f spread %.2f env %.2f crawl %.2f tipstep %.4f" % [float(i) * dt, rig.shown["jet_t"], rig.shown["mantle"], rig.shown["spread"], rig.shown["jet_env"], rig.shown["crawl"], last_step])
			last_step = 0.0
	r.mean_move /= maxf(float(r.frames * 8), 1.0)
	return vel


func _run() -> void:
	await _fresh()
	_converter()
	await _idle()
	await _jet()
	await _cruise()
	await _transitions()
	await _crawl()
	await _spin()
	await _perf()
	print("octopus_gait_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------------------------------------

func _converter() -> void:
	var m := rig.model
	# at rest the converter gives no bend
	var worst_rest := 0.0
	rig._apply_dirs(rig._rest_dirs, 0.0)
	for a in 8:
		var pts := m.arm_joints(a)
		var rest := m.arm_rest_joints(a)
		for j in pts.size():
			worst_rest = maxf(worst_rest, pts[j].distance_to(rest[j]) / L)
	_check(worst_rest < 0.002, "rest directions reproduce the rest pose (worst joint error %.4f of length)" % worst_rest)
	# arbitrary smooth direction fields come out as the bones' real directions
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var worst := 0.0
	for trial in 20:
		var fields: Array[PackedVector3Array] = []
		for a in 8:
			var d := PackedVector3Array()
			var swirl := Quaternion(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 1.1))
			for j in 14:
				var base: Vector3 = rig._rest_dirs[a][j]
				var tw := Quaternion(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0.2).normalized(), rng.randf_range(0.0, 0.1))
				d.append((tw * (Quaternion().slerp(swirl, float(j) / 13.0) * base)).normalized())
			fields.append(d)
		rig._apply_dirs(fields, 0.0)
		for a in 8:
			for j in 13:
				var xf := m.arm_bone_transform(a, j)
				var got := (-xf.basis.z).normalized()
				worst = maxf(worst, got.angle_to(fields[a][j]))
	_check(worst < 0.01, "arbitrary direction fields come out as the bones' directions (worst error %.4f rad)" % worst)
	rig._apply_dirs(rig._dirs, 0.0)


func _idle() -> void:
	await _fresh()
	var r := Run.new()
	_go(4.0, func(_t: float) -> Dictionary: return {"throttle": 0.0, "vel": Vector3.ZERO, "stick": Vector2.ZERO, "boost": false, "roll": 0.0}, r)
	_check(r.finite, "idle: everything finite")
	_check(r.mean_move > 0.00005, "idle: the arms are alive (mean tip step %.5f of length per frame)" % r.mean_move)
	_check(r.max_step < 0.006, "idle: lazy (biggest tip step %.4f of length per frame)" % r.max_step)
	_check(rig.shown["jets"] == 0, "idle: no jets fire")
	_check(r.dv_sum == Vector3.ZERO, "idle: no thrust")


func _jet() -> void:
	await _fresh()
	var r := Run.new()
	_go(5.0, func(_t: float) -> Dictionary: return {"throttle": 1.0, "boost": false, "stick": Vector2.ZERO, "roll": 0.0}, r, Vector3(0, 0, -2.0))
	_check(r.finite, "jet: everything finite")
	_check(rig.shown["jets"] >= 3 and rig.shown["jets"] <= 6, "jet: a pulse about every period (%d jets in 5 s)" % rig.shown["jets"])
	_check(r.mantle_max > 0.8, "jet: the mantle squeezes (peak %.2f)" % r.mantle_max)
	_check(r.mantle_min < -0.15, "jet: and refills past rest (low %.2f)" % r.mantle_min)
	_check(r.spread_min < -0.8, "jet: the arms bundle into a spear (spread low %.2f)" % r.spread_min)
	_check(r.spread_max > 0.25, "jet: and flare on recovery (spread high %.2f)" % r.spread_max)
	var gb := rig.model.global_basis.orthonormalized()
	_check(r.dv_sum.dot(-gb.z) > 1.0, "jet: thrust drives it forward along the siphon (dv along travel %.1f m/s over 5 s)" % r.dv_sum.dot(-gb.z))
	_check(absf(r.dv_sum.y) < 0.5 * absf(r.dv_sum.z) + 0.01, "jet: and level (rest siphon points back and a little down: dv up %.2f, forward %.2f)" % [r.dv_sum.y, r.dv_sum.z])
	_check(r.max_step < 0.04, "jet: smooth (biggest tip step %.4f of length per frame)" % r.max_step)
	_check(r.max_jerk < 0.02, "jet: no jerks (biggest second difference %.4f)" % r.max_jerk)
	# thrust is only in the power stroke
	await _fresh()
	rig.jet_now(1.0, false)
	var power_dv := 0.0
	var late_dv := 0.0
	for i in 66:
		rig.tick(1.0 / 60.0, Vector3(0, 0, -3), rig.model.global_basis)
		var dv := rig.thrust_dv(1.0 / 60.0, rig.model.global_basis).length()
		if i < 14:
			power_dv += dv
		elif i > 30:
			late_dv += dv
	_check(power_dv > 0.0 and late_dv < 0.0001, "jet: thrust lives in the power stroke only (power %.3f, recovery %.4f)" % [power_dv, late_dv])
	# siphon vectoring: stick right sends the jet left, the force right at the head
	await _fresh()
	for i in 41:
		rig.step(1.0 / 60.0, {"throttle": 1.0, "stick": Vector2(1.0, 0.0), "vel": Vector3(0, 0, -3)})
	var ex := rig.model.siphon_exhaust_dir()
	_check(ex.x < -0.1, "vector: stick right aims the exhaust left (x %.2f)" % ex.x)
	rig.jet_now(1.0)
	for i in 6:
		rig.tick(1.0 / 60.0, Vector3(0, 0, -3), rig.model.global_basis)
	var dvv := rig.thrust_dv(1.0 / 60.0, rig.model.global_basis)
	_check(dvv.x > 0.0, "vector: so the thrust has a rightward part (%.3f)" % dvv.x)
	# dash: bundled arms, faster pulses, stronger thrust
	await _fresh()
	var rd := Run.new()
	_go(3.0, func(_t: float) -> Dictionary: return {"throttle": 1.0, "boost": true, "stick": Vector2.ZERO}, rd, Vector3(0, 0, -2.0))
	await _fresh()
	var rn := Run.new()
	_go(3.0, func(_t: float) -> Dictionary: return {"throttle": 1.0, "boost": false, "stick": Vector2.ZERO}, rn, Vector3(0, 0, -2.0))
	_check(rd.dv_sum.length() > rn.dv_sum.length() * 1.5, "dash: much more thrust than a normal pulse (%.1f vs %.1f m/s)" % [rd.dv_sum.length(), rn.dv_sum.length()])
	_check(rd.spread_max < 0.0, "dash: the arms stay bundled (highest spread %.2f)" % rd.spread_max)


func _cruise() -> void:
	await _fresh()
	var r := Run.new()
	_go(3.0, func(_t: float) -> Dictionary: return {"throttle": 0.0, "vel": Vector3.ZERO}, r)
	var idle_move := r.mean_move
	# in the gap between jets (throttle low) the arms scull
	var r2 := Run.new()
	_go(3.0, func(_t: float) -> Dictionary: return {"throttle": 0.1, "vel": Vector3(0, 0, -3), "stick": Vector2(0.4, 0.0)}, r2)
	_check(rig.shown["jets"] == 0, "cruise: a light throttle does not jet")
	_check(rig.shown["scull"] > 0.3, "cruise: the scull is in (%.2f)" % rig.shown["scull"])
	_check(r2.mean_move > idle_move, "cruise: the arms undulate more than at idle (%.5f vs %.5f)" % [r2.mean_move, idle_move])
	_check(r2.max_step < 0.02, "cruise: smooth (biggest tip step %.4f)" % r2.max_step)


func _transitions() -> void:
	await _fresh()
	var r := Run.new()
	var sched := func(t: float) -> Dictionary:
		var c := {"throttle": 0.0, "boost": false, "stick": Vector2(0.5 * sin(t * 1.5), 0.3 * sin(t * 0.8)), "roll": 0.0}
		if t > 1.0 and t < 3.0:
			c["throttle"] = 0.3
		elif t >= 3.0 and t < 6.0:
			c["throttle"] = 1.0
		elif t >= 6.0 and t < 8.0:
			c["throttle"] = 1.0
			c["boost"] = true
		elif t >= 8.0 and t < 9.0:
			c["throttle"] = -0.8
		return c
	_go(11.0, sched, r, Vector3(0, 0, -1.0))
	_check(r.finite, "transitions: finite through idle, cruise, jet, dash, reverse, idle")
	_check(r.max_step < 0.06, "transitions: no pops (biggest tip step %.4f of length per frame)" % r.max_step)
	_check(r.max_jerk < 0.03, "transitions: no jerks (biggest second difference %.4f)" % r.max_jerk)
	var worst := 0.0
	for a in 8:
		var pts := rig.model.arm_joints(a)
		for j in range(1, pts.size()):
			worst = maxf(worst, pts[j].distance_to(pts[j - 1]) / maxf(rig.model.arm_segment_length(a, mini(j - 1, 13)), 0.0001))
	_check(absf(worst - 1.0) < 0.01, "transitions: arm segments keep their length (worst ratio %.3f)" % worst)


func _crawl() -> void:
	await _fresh()
	floor_y = -L * 0.38
	var crawl_max := 0.0
	var sat_floor := 0.0
	var reach_err := 0.0
	var reach_n := 0
	for i in 480:
		var t := float(i) / 60.0
		var fwd := 0.9 if t > 1.5 else 0.0
		var vel := Vector3(0, 0, -fwd)
		rig.position += vel / 60.0   # glide over the floor (the rig is the body here)
		rig.step(1.0 / 60.0, {"throttle": 0.0, "vel": vel, "stick": Vector2.ZERO, "boost": false})
		crawl_max = maxf(crawl_max, rig.shown["crawl"])
		if rig.shown["crawl"] > 0.9:
			for a in 8:
				if rig._feet_ok[a] > 0.7 and not rig.foot_swinging(a):
					var f := rig.foot_world(a)
					sat_floor = maxf(sat_floor, absf(f.y - floor_y))
					if t > 3.0:
						reach_err += rig.model.arm_tip_global(a).distance_to(f) / L
						reach_n += 1
	_check(crawl_max > 0.9, "crawl: blends in near the floor (weight %.2f)" % crawl_max)
	_check(rig.shown["steps"] >= 4, "crawl: the arms take steps as the body glides (%d)" % rig.shown["steps"])
	_check(sat_floor < 0.02, "crawl: feet stand on the floor (worst height error %.3f m)" % sat_floor)
	var mean_err := reach_err / maxf(float(reach_n), 1.0)
	_check(reach_n > 0 and mean_err < 0.12, "crawl: the arm tips reach their feet (mean error %.3f of length, %d samples)" % [mean_err, reach_n])
	# foot slip: a planted foot does not move
	var f0: Array[Vector3] = []
	var is_pl: Array[bool] = []
	for a in 8:
		f0.append(rig.foot_world(a))
		is_pl.append(not rig.foot_swinging(a))
	rig.step(1.0 / 60.0, {"throttle": 0.0, "vel": Vector3(0, 0, -0.9), "stick": Vector2.ZERO})
	var moved := 0.0
	for a in 8:
		if is_pl[a] and not rig.foot_swinging(a):
			moved = maxf(moved, rig.foot_world(a).distance_to(f0[a]))
	_check(moved < 0.0001, "crawl: a planted foot does not slip (moved %.5f m)" % moved)
	var worst_swing := 0
	var neighbour_clash := false
	for i in 240:
		rig.position += Vector3(0, 0, -0.9 / 60.0)
		rig.step(1.0 / 60.0, {"throttle": 0.0, "vel": Vector3(0, 0, -0.9), "stick": Vector2.ZERO})
		var n := 0
		for a in 8:
			if rig.foot_swinging(a):
				n += 1
				if rig.foot_swinging((a + 1) % 8):
					neighbour_clash = true
		worst_swing = maxi(worst_swing, n)
	_check(worst_swing <= 3, "crawl: at most 3 arms swing at once (%d)" % worst_swing)
	_check(not neighbour_clash, "crawl: neighbouring arms never swing together")
	# leaving the floor: swim away with a jet
	var r2 := Run.new()
	var t_leave := func(t: float) -> Dictionary:
		if t > 1.0:
			floor_y = -1.0e9
		return {"throttle": 1.0, "boost": false, "stick": Vector2.ZERO}
	_go(4.0, t_leave, r2, Vector3(0, 0, -1.0))
	_check(r2.finite and r2.max_step < 0.05, "crawl to swim: no pop (biggest tip step %.4f)" % r2.max_step)
	_check(rig.shown["crawl"] < 0.05, "crawl to swim: the crawl fades out (%.2f)" % rig.shown["crawl"])


func _spin() -> void:
	await _fresh()
	var finite := true
	var worst_gap := 0.0
	var max_tip_step := 0.0
	var prev := _tips()
	for i in 240:
		rig.rotate_object_local(Vector3.BACK, deg_to_rad(240.0) / 60.0)   # about the nose axis, 240 deg/s
		rig.step(1.0 / 60.0, {"throttle": 0.0, "vel": rig.global_basis * Vector3(0, 0, -3.0), "stick": Vector2.ZERO, "roll": 1.0})
		var tips := _tips()
		for a in 8:
			max_tip_step = maxf(max_tip_step, tips[a].distance_to(prev[a]) / L)
			if not (is_finite(tips[a].x) and is_finite(tips[a].y)):
				finite = false
		prev = tips
		if i > 90:
			for a in 8:
				worst_gap = maxf(worst_gap, (rig._dirs[a] as PackedVector3Array)[13].angle_to((rig._rest_dirs[a] as PackedVector3Array)[13]))
	_check(finite, "spin: finite through two and a half turns of roll")
	_check(max_tip_step < 0.04, "spin: smooth (biggest tip step %.4f of length per frame)" % max_tip_step)
	_check(worst_gap > 0.15, "spin: the arm tips swing out against the roll (%.2f rad from rest)" % worst_gap)
	# a hard turn: yaw 90 deg in half a second, the mantle trails to the outside
	await _fresh()
	for i in 30:
		rig.rotate_y(deg_to_rad(90.0) / 30.0)
		rig.step(1.0 / 60.0, {"throttle": 0.0, "vel": Vector3.ZERO})
	var tip := rig.model.mantle_tip_local()
	_check(tip.x > 0.0, "turn: turning left (yaw +) the mantle trails out to the right (tip x %.2f)" % tip.x)


func _perf() -> void:
	await _fresh()
	var t0 := Time.get_ticks_usec()
	var n := 600
	for i in n:
		rig.step(1.0 / 60.0, {"throttle": 1.0 if (i / 120) % 2 == 0 else 0.0, "vel": Vector3(0, 0, -4), "stick": Vector2(sin(float(i) * 0.05), 0.0)})
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)
	print("  step cost: %.3f ms per frame (8 arms x 14 segments, jet + scull)" % ms)
	_check(ms < 1.5, "perf: step under 1.5 ms (%.3f ms)" % ms)
