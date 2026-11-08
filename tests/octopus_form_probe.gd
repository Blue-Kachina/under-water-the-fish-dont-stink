## Ember Octopus form (C2: forms/ember_octopus.gd, octopus_rig.gd) on a real FishController, dressed as a match dresses a Hunter:
## the sheet, the dress hook (one rig, shark hidden, twice safe), the model against the hitbox, the gait reading from the controller
## (idle life, jets under the throttle that really speed the fish up through the physics tick, siphon vectoring that turns it, the dash),
## a crawl on a floor (the arms plant on a static floor under it), continuity of the arm tips frame to frame, frame cost. Sizes 0.5, 1, 2.
## Run headless: Godot_console.exe --headless --path . res://tests/octopus_form_probe.tscn
extends Node

const FORM := preload("res://scripts/what_stinks/forms/ember_octopus.gd")
const SIZES := [0.5, 1.0, 2.0]

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var _floor: StaticBody3D


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
	_sheet()
	for s: float in SIZES:
		await _at(s)
	print("octopus_form_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _form() -> Dictionary:
	var d := HunterForms.DEFAULTS.duplicate()
	d.merge(FORM.sheet() as Dictionary, true)
	return d


func _sheet() -> void:
	print("sheet:")
	var form := _form()
	_check(str(form["name"]) == "Ember Octopus" and form["class"] == FishCharacter.FishClass.MONSTER, "name and class")
	_check(float(form["length_m"]) > 4.0 and float(form["bite_reach_m"]) > 0.0 and float(form["bite_wind"]) > 0.0, "length, reach, wind-up set")
	_check(bool(FORM.ready()), "reports ready")


func _dress(s: float) -> Dictionary:
	fish.input_forward = 0.0
	fish.input_reverse = 0.0
	fish.input_stick = Vector2.ZERO
	fish.is_boosting = false
	var form := _form()
	var size := HunterSize.shared()
	size.size_mult = s
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	size.apply(fish, form)
	FORM.dress(fish, form)
	return form


func _place(at_y := 30.0) -> void:
	fish.input_forward = 0.0
	fish.input_reverse = 0.0
	fish.input_stick = Vector2.ZERO
	fish.input_roll = 0.0
	fish.is_boosting = false
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, at_y, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


func _rig() -> OctopusRig:
	return (fish._visual as Node3D).get_node_or_null("OctopusRig") as OctopusRig


func _tips(rig: OctopusRig) -> PackedVector3Array:
	var out := PackedVector3Array()
	for a in 8:
		out.append(rig.model.arm_tip_local(a))
	return out


func _at(s: float) -> void:
	var tag := "x%.1f" % s
	print("size %s:" % tag)
	var form := _dress(s)
	await _frames(3)
	_place()
	await _frames(10)
	var visual: Node3D = fish._visual
	var rig := _rig()
	_check(rig != null, "%s: the octopus rig is on the model" % tag)
	if rig == null:
		return
	FORM.dress(fish, form)
	var rigs := visual.get_children().filter(func(n: Node) -> bool: return n.name == "OctopusRig")
	_check(rigs.size() == 1, "%s: dressing twice leaves one rig (%d)" % [tag, rigs.size()])
	var hidden := true
	for child in visual.get_children():
		if child is Node3D and child != rig and (child as Node3D).visible:
			hidden = false
	_check(hidden, "%s: the shark's own parts are hidden" % tag)
	_check(absf(fish.hitbox_length - float(form["length_m"]) * s) < 0.05 * s + 0.01, "%s: hitbox %.2f m" % [tag, fish.hitbox_length])
	# the model against the hitbox: the mantle tip leads at the box's front, the arms trail toward its back (soft: at rest they
	# droop and curl, so the tips fall a little short of the box's end; swimming straightens them)
	var front := rig.model.global_position.z
	var mantle := rig.model.to_global(rig.model.mantle_tip_local()).z
	var arm_back := -1.0e9
	for a in 8:
		arm_back = maxf(arm_back, rig.model.arm_tip_global(a).z)
	var span := arm_back - mantle
	_check(span > fish.hitbox_length * 0.78 and span < fish.hitbox_length * 1.1, "%s: model span %.2f m ~ hitbox %.2f m" % [tag, span, fish.hitbox_length])
	var box_front := fish.global_position.z - fish.hitbox_length * 0.5
	_check(absf(mantle - box_front) < fish.hitbox_length * 0.06, "%s: the mantle leads at the front of the box (mantle %.2f vs box %.2f, arms back to %.2f)" % [tag, mantle, box_front, arm_back])
	_check(front < fish.global_position.z + 0.01, "%s: the head is ahead of the centre" % tag)
	await _gait(rig, tag)
	if is_equal_approx(s, 1.0):
		await _crawl(rig, tag)
	_cost(rig, tag)


func _gait(rig: OctopusRig, tag: String) -> void:
	rig.jet_fired.connect(func(a: float) -> void: print("      [jet %.2f] throttle %.2f boost %s fwd_in %.2f t=%d" % [a, rig._throttle, rig._boost, fish.input_forward, Engine.get_physics_frames()]))
	_place()
	var input := FishInput.new()
	fish.controls = input
	await _frames(30)
	# still: alive, no jets, no drift from thrust
	var prev := _tips(rig)
	var max_step := 0.0
	var move := 0.0
	for i in 120:
		await get_tree().physics_frame
		fish.linear_velocity = Vector3.ZERO
		var t := _tips(rig)
		for a in 8:
			var st := t[a].distance_to(prev[a]) / fish.hitbox_length
			max_step = maxf(max_step, st)
			move += st
		prev = t
	_check(int(rig.shown["jets"]) == 0, "%s: no jets while still (throttle %.2f boost %s jets %d)" % [tag, rig._throttle, rig._boost, int(rig.shown["jets"])])
	_check(move > 0.001 and max_step < 0.01, "%s: still, the arms drift lazily (total %.4f, biggest step %.4f)" % [tag, move, max_step])
	# swimming with jets vs without: the jets really speed it up
	var results := {}
	for scale: float in [0.0, 1.0]:
		_place()
		fish.controls = input
		rig.thrust_scale = scale
		await _frames(10)
		input.forward = 1.0
		input.stick = Vector2.ZERO
		var jets0: int = rig.shown["jets"]
		var worst := 0.0
		prev = _tips(rig)
		var max_mantle := -1.0
		for i in 300:
			await get_tree().physics_frame
			var t := _tips(rig)
			for a in 8:
				worst = maxf(worst, t[a].distance_to(prev[a]) / fish.hitbox_length)
			prev = t
			max_mantle = maxf(max_mantle, rig.shown["mantle"])
		results[scale] = {"speed": fish.linear_velocity.length(), "added": rig.thrust_applied.length(), "jets": int(rig.shown["jets"]) - jets0, "step": worst, "mantle": max_mantle}
		input.forward = 0.0
	var no_jet: Dictionary = results[0.0]
	var with_jet: Dictionary = results[1.0]
	print("      swim 5 s: speed %.1f m/s with jets, %.1f without; jets %d; jets added %.1f m/s in total; biggest tip step %.4f" % [with_jet["speed"], no_jet["speed"], with_jet["jets"], with_jet["added"], with_jet["step"]])
	_check(int(with_jet["jets"]) >= 3, "%s: the throttle fires jet pulses (%d in 5 s)" % [tag, with_jet["jets"]])
	_check(float(with_jet["mantle"]) > 0.7, "%s: the mantle squeezes with them (%.2f)" % [tag, with_jet["mantle"]])
	_check(float(with_jet["speed"]) > float(no_jet["speed"]) + 0.5, "%s: the jets add speed through the physics (%.1f vs %.1f m/s)" % [tag, with_jet["speed"], no_jet["speed"]])
	_check(float(with_jet["step"]) < 0.05, "%s: swimming is smooth (biggest tip step %.4f of length per frame)" % [tag, with_jet["step"]])
	rig.thrust_scale = 1.0
	# steering: the stick right turns the nose right, with the siphon aimed left
	_place()
	fish.controls = input
	await _frames(10)
	var yaw0 := fish.global_rotation.y
	input.forward = 1.0
	input.stick = Vector2(1.0, 0.0)
	await _frames(90)
	var ex := rig.model.siphon_exhaust_dir()
	_check(ex.x < -0.05, "%s: stick right aims the exhaust left (x %.2f)" % [tag, ex.x])
	_check(absf(angle_difference(yaw0, fish.global_rotation.y)) > 0.1, "%s: and the fish turns (%.0f deg)" % [tag, rad_to_deg(absf(angle_difference(yaw0, fish.global_rotation.y)))])
	# dash
	_place()
	fish.controls = input
	input.stick = Vector2.ZERO
	await _frames(10)
	input.forward = 1.0
	input.boost = true
	fish.boost_amount = 100.0
	await _frames(70)
	_check(bool(rig.shown["dash"]) or int(rig.shown["jets"]) > 0, "%s: the boost makes a dash jet" % tag)
	input.boost = false
	fish.boost_amount = 0.0
	await _frames(40)
	input.forward = 0.0
	fish.controls = null


func _crawl(rig: OctopusRig, tag: String) -> void:
	# a static floor under the octopus
	if _floor == null:
		_floor = StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(400.0, 2.0, 400.0)
		shape.shape = box
		_floor.add_child(shape)
		add_child(_floor)
	_place(30.0)
	_floor.global_position = Vector3(fish.global_position.x, fish.global_position.y - fish.hitbox_length * 0.45 - 1.0, fish.global_position.z)
	var input := FishInput.new()
	fish.controls = input
	await _frames(40)
	var crawl_max := 0.0
	var steps0: int = rig.shown["steps"]
	var prev := _tips(rig)
	var worst := 0.0
	for i in 360:
		await get_tree().physics_frame
		fish.linear_velocity = Vector3(0.0, fish.linear_velocity.y, -0.8)
		crawl_max = maxf(crawl_max, rig.shown["crawl"])
		var t := _tips(rig)
		for a in 8:
			worst = maxf(worst, t[a].distance_to(prev[a]) / fish.hitbox_length)
		prev = t
	print("      crawl: weight %.2f, steps %d, height %.2f, biggest tip step %.4f" % [crawl_max, int(rig.shown["steps"]) - steps0, rig.shown["height"], worst])
	_check(crawl_max > 0.6, "%s: near a floor the crawl comes in (%.2f)" % [tag, crawl_max])
	_check(int(rig.shown["steps"]) - steps0 >= 2, "%s: the arms step (%d)" % [tag, int(rig.shown["steps"]) - steps0])
	var want_h := OctopusRig.opt("octopus_crawl_height") * fish.hitbox_length
	_check(absf(float(rig.shown["height"]) - want_h) < fish.hitbox_length * 0.12, "%s: it settles to the crawl height (%.2f m vs %.2f)" % [tag, float(rig.shown["height"]), want_h])
	_check(worst < 0.05, "%s: crawling is smooth (biggest tip step %.4f)" % [tag, worst])
	_floor.global_position.y -= 500.0
	fish.controls = null


func _cost(rig: OctopusRig, tag: String) -> void:
	var t0 := Time.get_ticks_usec()
	for i in 300:
		rig.step(1.0 / 60.0, {"throttle": 1.0, "vel": Vector3(0, 0, -6)})
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 300.0
	print("      step cost %.3f ms" % ms)
	_check(ms < 1.5, "%s: the rig's frame cost is small (%.3f ms)" % [tag, ms])
