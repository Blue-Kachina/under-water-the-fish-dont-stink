## B2 (planning_new_hunters.md): the Drowned Shark's exaggerated chomp (forms/shark_rig.gd on AttackExaggerate).
## Checks: the rig is dressed on, the tooth rows are split per tooth and rooted, everything sits exactly at rest before and after
## a bite, the press pulls the head back (anticipation) before it swells, the hold gapes the jaw wider than the plain bite and
## grows the teeth and eyes with the charge, the release thrusts the head forward past the hold and rings out (overshoot), the
## landing hit-stops the rig's own clock, the motion has no pops, hunter_exaggeration 0 is the plain bite, 2 is bigger than 1,
## and the peak stays inside the camera's margin.
##   Godot_console.exe --headless --path . res://tests/b2_shark_probe.tscn
extends Node

const KEY := "drowned_shark"

var main: Node
var fish: FishController
var rig: Node
var bite: HunterBite
var checks := 0
var failures := 0
var tps := 120


func _ready() -> void:
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


func _set_master(v: float) -> void:
	var settings := WhatStinksSettings.shared()
	if settings.get("hunter_exaggeration") != null:
		settings.set("hunter_exaggeration", v)
	rig.call("configure", HunterForms.sheet(KEY))
	rig.ex.set_strength(v, 1.0)


func _hot_glow() -> float:
	return float((rig._eyes[0]["mat"] as ShaderMaterial).get_shader_parameter("glow"))


func _run() -> void:
	await _frames(5)
	tps = int(Engine.physics_ticks_per_second)
	main.set_environment("Ocean")
	await _frames(5)
	var form := HunterForms.sheet(KEY)
	_check(form.has("exaggerate"), "the shark's sheet carries its exaggeration preset")
	HunterSize.shared().size_mult = 1.0
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().apply(fish, form)
	HunterForms.dress(fish, KEY)
	await _frames(3)
	bite = HunterBite.new()
	bite.name = "HunterBite"
	fish.add_child(bite)
	bite.setup(fish, form)
	var model := fish.get("_visual") as Node3D
	rig = model.get_node_or_null("SharkRig")
	_check(rig != null, "dress puts a SharkRig on the model")
	if rig == null:
		print("b2_shark_probe: aborted")
		get_tree().quit(1)
		return
	HunterForms.dress(fish, KEY)
	var rigs := 0
	for c in model.get_children():
		if c.name == "SharkRig":
			rigs += 1
	_check(rigs == 1, "dressing twice keeps one rig")
	await _frames(3)
	_check(rig._teeth.size() >= 20, "the tooth rows are split per tooth (%d teeth)" % rig._teeth.size())
	var jaw: HunterJaw = rig.jaw
	var rooted := true
	for entry: Dictionary in rig._teeth:
		var node := entry["node"] as Node3D
		if node.get_parent() == jaw._upper:
			var near := false
			for lip: Vector3 in jaw._lip:
				if lip.distance_to(node.position) < float(jaw.mouth.length) * 0.05:
					near = true
			rooted = rooted and near
	_check(rooted, "every upper tooth is rooted on the lip line")
	_check(rig._eyes.size() >= 2, "both eyes found (%d)" % rig._eyes.size())

	# rest
	var base_pos := model.position
	var base_scale := model.scale
	var base_glow := _hot_glow()
	var length: float = float(model.get("_size").z) * base_scale.z
	print("      rest: model length %.2f m, eye glow %.2f" % [length, base_glow])
	await _frames(10)
	_check(model.position == base_pos and model.scale == base_scale, "at rest the model is untouched")

	# a plain bite for reference (master 0)
	_set_master(0.0)
	var plain := await _bite_trace(model, jaw, length, base_pos, 0.8)
	_check(absf(plain["min_z"]) < 0.0001 and absf(plain["max_z"]) < 0.0001, "master 0: the model never moves")
	_check(absf(plain["teeth_max"] - 1.0) < 0.0001 and absf(plain["glow_max"] - base_glow) < 0.0001, "master 0: teeth and eyes never change")
	var plain_angle: float = plain["angle_max"]
	print("      plain steps: jaw %.3f rad" % plain["max_angle_step"])
	_check(plain_angle > 0.8 and plain_angle < 1.7, "master 0: the plain gape is the bite's own (%.2f rad)" % plain_angle)

	# the exaggerated bite
	_set_master(1.0)
	var bold := await _bite_trace(model, jaw, length, base_pos, 0.8)
	print("      bold: angle %.2f rad (plain %.2f), thrust fwd %.3f L back %.3f L, teeth %.2f..%.2f, glow %.2f, peak %.2f, hit-stop ticks %d" % [
		bold["angle_max"], plain_angle, bold["thrust_max"] / length, -bold["back_max"] / length, bold["teeth_min"], bold["teeth_max"], bold["glow_max"], bold["peak"], bold["stop_ticks"]])
	_check(bold["angle_max"] > plain_angle + 0.35, "the hold gapes wider than the plain bite (%.2f vs %.2f rad)" % [bold["angle_max"], plain_angle])
	_check(bold["back_max"] < -length * 0.005, "the press pulls the head back first (%.3f L)" % (-bold["back_max"] / length))
	_check(bold["thrust_max"] > length * 0.08, "the release thrusts the head forward (%.3f L)" % (bold["thrust_max"] / length))
	_check(bold["thrust_max"] > bold["hold_thrust"] * 1.15, "the release thrust is past the hold's lean (%.3f vs %.3f L)" % [bold["thrust_max"] / length, bold["hold_thrust"] / length])
	_check(bold["teeth_min"] < 0.95, "the teeth shrink in the anticipation (%.2f)" % bold["teeth_min"])
	_check(bold["teeth_max"] > 1.7, "the teeth grow to at least 1.7x (%.2f)" % bold["teeth_max"])
	_check(bold["glow_max"] > base_glow + 1.0, "the eyes flare (%.2f from %.2f)" % [bold["glow_max"], base_glow])
	_check(bold["hold_teeth"] > 1.3, "the teeth are already big on the hold (%.2f)" % bold["hold_teeth"])
	_check(bold["ring_overshoot"], "the thrust rings out past rest (overshoot) before settling")
	_check(bold["stop_ticks"] >= 2, "the landing hit-stops the rig (%d ticks)" % bold["stop_ticks"])
	_check(bold["max_step"] < length * 0.05 and bold["max_teeth_step"] < 0.16 and bold["max_angle_step"] < plain["max_angle_step"] * 1.6, "no pops: largest steps %.4f L, teeth %.3f, jaw %.3f rad per tick" % [bold["max_step"] / length, bold["max_teeth_step"], bold["max_angle_step"]])
	_check(bold["peak"] <= 3.5 and bold["peak"] >= 1.5, "peak scale %.2f inside 1.5-3.5, margin %.2f m for a 1 m camera" % [bold["peak"], rig.camera_margin(1.0)])
	_check(bold["rest_exact"], "after the settle the model, teeth, eyes and jaw sit exactly at rest")
	_check(bold["punches"] >= 1, "the landing asks the camera for a punch")

	# bigger master
	_set_master(2.0)
	var extreme := await _bite_trace(model, jaw, length, base_pos, 0.8)
	_check(extreme["thrust_max"] > bold["thrust_max"] * 1.3 and extreme["angle_max"] > bold["angle_max"], "hunter_exaggeration 2 is bigger than 1 (thrust %.3f L, jaw %.2f rad)" % [extreme["thrust_max"] / length, extreme["angle_max"]])
	_check(extreme["peak"] <= 3.5, "extreme is clamped at max_scale (%.2f)" % extreme["peak"])
	_check(extreme["rest_exact"], "extreme settles back to exact rest")

	# a cancel ends at rest
	_set_master(1.0)
	bite.cooldown = 0.0
	bite.try_open()
	await _frames(int(tps * 0.4))
	bite.abort()
	await _frames(tps * 2)
	_check(model.position.is_equal_approx(base_pos) and model.scale.is_equal_approx(base_scale) and rig.ex.idle(), "an aborted bite eases back to rest")
	_check(is_equal_approx(_hot_glow(), base_glow), "and the eyes cool back to their base")

	print("b2_shark_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## One full bite: press, hold `hold_s` seconds to the charge, release, land, settle. Returns the traces' extremes.
func _bite_trace(model: Node3D, jaw: HunterJaw, length: float, base_pos: Vector3, hold_s: float) -> Dictionary:
	var n := 0
	while bite.busy() and n < tps * 6:
		await get_tree().physics_frame
		n += 1
	await _frames(tps)
	bite.cooldown = 0.0
	var out := {
		"angle_max": 0.0, "thrust_max": 0.0, "back_max": 0.0, "hold_thrust": 0.0, "teeth_min": 9.0, "teeth_max": 0.0, "glow_max": 0.0,
		"hold_teeth": 0.0, "stop_ticks": 0, "max_step": 0.0, "max_teeth_step": 0.0, "max_angle_step": 0.0, "peak": 1.0,
		"min_z": 0.0, "max_z": 0.0, "ring_overshoot": false, "rest_exact": false, "punches": 0,
	}
	var punches := [0]
	var counter := func(_a: float, _d: Vector3) -> void: punches[0] += 1
	rig.ex.camera_punch.connect(counter)
	var prev_z := 0.0
	var prev_t := 1.0
	var prev_a := 0.0
	var released := false
	var held_ticks := int(tps * hold_s)
	var tick := 0
	bite.try_open()
	var after_release_z: Array[float] = []
	var total := held_ticks + tps * 4
	while tick < total:
		await get_tree().physics_frame
		tick += 1
		if tick == held_ticks:
			bite.try_close()
			released = true
			out["hold_thrust"] = out["thrust_max"]
			out["hold_teeth"] = out["teeth_max"]
		var z := -(model.position.z - base_pos.z)  # forward positive
		var t0 := (rig._teeth[0]["node"] as Node3D).scale.y
		var ang := absf(jaw._lower.rotation.x) if jaw._lower.visible else 0.0
		out["thrust_max"] = maxf(out["thrust_max"], z)
		out["back_max"] = minf(out["back_max"], z)
		out["min_z"] = minf(out["min_z"], z)
		out["max_z"] = maxf(out["max_z"], z)
		out["teeth_min"] = minf(out["teeth_min"], t0)
		out["teeth_max"] = maxf(out["teeth_max"], t0)
		out["angle_max"] = maxf(out["angle_max"], ang)
		out["glow_max"] = maxf(out["glow_max"], _hot_glow())
		out["peak"] = maxf(out["peak"], rig.ex.peak_scale())
		if rig.ex.in_hit_stop():
			out["stop_ticks"] += 1
		if tick > 1:
			out["max_step"] = maxf(out["max_step"], absf(z - prev_z))
			out["max_teeth_step"] = maxf(out["max_teeth_step"], absf(t0 - prev_t))
			out["max_angle_step"] = maxf(out["max_angle_step"], absf(ang - prev_a))
		prev_z = z
		prev_t = t0
		prev_a = ang
		if released:
			after_release_z.append(z)
	# overshoot: after the thrust peak the head passes back through rest (z < 0) and then returns
	var peaked := false
	for z: float in after_release_z:
		if z > out["thrust_max"] * 0.8:
			peaked = true
		elif peaked and z < -length * 0.0015:
			out["ring_overshoot"] = true
	rig.ex.camera_punch.disconnect(counter)
	out["punches"] = punches[0]
	var teeth_rest := true
	for entry: Dictionary in rig._teeth:
		teeth_rest = teeth_rest and (entry["node"] as Node3D).scale == Vector3.ONE
	out["rest_exact"] = rig.ex.idle() and model.position.is_equal_approx(base_pos) and teeth_rest and is_equal_approx(_hot_glow(), float(rig._eyes[0]["glow"])) and not jaw._lower.visible
	return out
