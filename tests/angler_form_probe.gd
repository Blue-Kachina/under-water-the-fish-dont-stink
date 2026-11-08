## Lantern Angler form (D2: forms/lantern_angler.gd, lantern_rig.gd): the dress hook (one rig, shark hidden, jaw wired to the bite),
## the model against the hitbox, a straight stiff body at rest, the gait reading from the controller (cruise sway small and slow,
## a lunge fires the tail spring which rings and settles, pectoral scull big when still and small when fast, the turning side's
## fin held out), continuity of every animated channel frame to frame (no popping), the jaw and the mouth point, and a real bite
## release firing a snap. Sizes 0.5, 1 and 3.
## Run headless: Godot_console.exe --headless --path . res://tests/angler_form_probe.tscn
extends Node

const FORM := preload("res://scripts/what_stinks/forms/lantern_angler.gd")
const SIZES := [0.5, 1.0, 3.0]

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	WhatStinksSettings.shared().bite_mode = WhatStinksSettings.BiteMode.TAP
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
		await get_tree().process_frame


func _run() -> void:
	await _frames(5)
	main.set_environment("Ocean")
	await _frames(5)
	_sheet()
	for s: float in SIZES:
		await _at(s)
	_spring_unit()
	print("angler_form_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _form() -> Dictionary:
	var d := HunterForms.DEFAULTS.duplicate()
	d.merge(FORM.sheet() as Dictionary, true)
	return d


func _sheet() -> void:
	print("sheet:")
	var form := _form()
	_check(str(form["name"]) == "Lantern Angler" and form["class"] == FishCharacter.FishClass.MONSTER, "name and class")
	_check(float(form["length_m"]) > 4.0 and float(form["bite_reach_m"]) > 0.0 and float(form["bite_wind"]) > 0.0, "length, reach, wind-up set")
	_check(form["cam"] is Vector2 and (form["cam"] as Vector2).y > 1.0, "camera sits above for the stalk")
	_check(bool(FORM.ready()), "reports ready")


func _dress(s: float) -> Dictionary:
	var form := _form()
	var size := HunterSize.shared()
	size.size_mult = s
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	size.apply(fish, form)
	FORM.dress(fish, form)
	return form


func _place() -> void:
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 30.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


func _rig() -> Node3D:
	return (fish._visual as Node3D).get_node_or_null("LanternRig")


func _at(s: float) -> void:
	var tag := "x%.1f" % s
	print("size %s:" % tag)
	var form := _dress(s)
	await _frames(3)
	_place()
	for i in 110:  # held still while the body settles straight (it forgets its trail after 0.8 s)
		await get_tree().physics_frame
		fish.linear_velocity = Vector3.ZERO
		fish.angular_velocity = Vector3.ZERO
	var visual: Node3D = fish._visual
	var rig := _rig()
	_check(rig != null, "%s: the angler's rig is on the model" % tag)
	if rig == null:
		return
	_check(visual.get_meta("hunter_jaw") == rig.jaw and rig.jaw is HunterJaw, "%s: the bite's jaw is the angler's" % tag)
	FORM.dress(fish, form)
	var rigs := visual.get_children().filter(func(n: Node) -> bool: return n.name == "LanternRig")
	_check(rigs.size() == 1, "%s: dressing twice leaves one rig (%d)" % [tag, rigs.size()])
	var hidden := true
	for child in visual.get_children():
		if child is Node3D and child != rig and (child as Node3D).visible:
			hidden = false
	_check(hidden, "%s: the shark's own parts are hidden" % tag)
	_check(absf(fish.hitbox_length - float(form["length_m"]) * s) < 0.05 * s + 0.01, "%s: hitbox %.2f m (body scale %.2f)" % [tag, fish.hitbox_length, fish.body_scale])
	var model: AnglerModel = rig.model
	var box := model.rest_aabb()
	_check(absf(box.end.z - fish.hitbox_length) < fish.hitbox_length * 0.06, "%s: model length %.2f m = hitbox %.2f m" % [tag, box.end.z, fish.hitbox_length])
	_check(absf(rig.rig.points[0].z - (fish.global_position.z - fish.hitbox_length * 0.5)) < 0.1 * s + 0.05, "%s: head at the front of the box" % tag)
	var off := _tail_offset(rig)
	_check(off.length() < 0.1, "%s: nearly straight at rest (a sinking head bends it a little) (tail off axis by %s of length)" % [tag, off])
	var jaw: HunterJaw = rig.jaw
	var mouth_w: Vector3 = visual.to_global(jaw.mouth_local())
	var front := fish.global_position - fish.global_basis.z * fish.hitbox_length * 0.5
	_check(mouth_w.distance_to(front) < fish.hitbox_length * 0.3, "%s: the mouth is near the front (%.2f m off the nose)" % [tag, mouth_w.distance_to(front)])
	jaw.pose(0.0)
	var shut: float = model.jaw_open
	jaw.pose(1.0)
	_check(model.jaw_open > shut + 0.5 and is_equal_approx(model.jaw_open, 1.0), "%s: pose(open) turns the jaw (%.2f -> %.2f)" % [tag, shut, model.jaw_open])
	jaw.pose(0.0)
	if shots_dir != "" and is_equal_approx(s, 1.0):
		await _shots(rig)
	await _gait(rig, tag)
	await _bite(form, rig, tag)


func _tail_offset(rig: Node3D) -> Vector3:
	var tail: Vector3 = rig.rig.points[SpineRig.SPINE_N - 1]
	var head: Vector3 = rig.rig.points[0]
	var off: Vector3 = fish.global_basis.inverse() * (tail - head)
	off.z = 0.0
	return off / rig.rig.length


## Records `frames` frames of the rig's gait values.
func _record(rig: Node3D, frames: int) -> Dictionary:
	var rec := {"tail": [], "snap": [], "flap_l": [], "flap_r": [], "sweep": [], "flutter": [], "esca_z": [], "bursts": 0, "speed_t": 0.0, "thrust": 0.0}
	var start_bursts: int = rig.shown["bursts"]
	for i in frames:
		await get_tree().process_frame
		var sh: Dictionary = rig.shown
		for key in ["tail", "snap", "flap_l", "flap_r", "sweep", "flutter"]:
			(rec[key] as Array).append(float(sh[key]))
		(rec["esca_z"] as Array).append(rig.model.esca_world().z)
		rec["bursts"] = int(sh["bursts"]) - start_bursts
		rec["speed_t"] = maxf(rec["speed_t"], float(sh["speed_t"]))
		rec["thrust"] = maxf(rec["thrust"], float(sh["thrust"]))
	return rec


func _max_step(a: Array) -> float:
	var worst := 0.0
	for i in range(1, a.size()):
		worst = maxf(worst, absf(float(a[i]) - float(a[i - 1])))
	return worst


func _span(a: Array) -> float:
	var lo := INF
	var hi := -INF
	for v in a:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	return hi - lo


func _mean(a: Array) -> float:
	var total := 0.0
	for v in a:
		total += float(v)
	return total / maxf(a.size(), 1)


func _gait(rig: Node3D, tag: String) -> void:
	_place()
	fish.controls = FishInput.new()
	await _frames(20)
	var still := await _record(rig, 150)
	var snap_rad := deg_to_rad(rig.opt("angler_tail_snap_deg"))
	print("      still: tail span %.3f rad, flap span %.3f rad, bursts %d" % [_span(still["tail"]), _span(still["flap_l"]), still["bursts"]])
	_check(_span(still["tail"]) < snap_rad * 0.9 and _span(still["tail"]) > 0.01, "%s: a still angler sways its tail a little (%.3f rad)" % [tag, _span(still["tail"])])
	_check(_span(still["flap_l"]) > 0.15, "%s: and sculls its pectorals (%.3f rad)" % [tag, _span(still["flap_l"])])
	_check(int(still["bursts"]) == 0, "%s: no burst while still" % tag)
	_check(_max_step(still["tail"]) < 0.05 and _max_step(still["flap_l"]) < 0.1, "%s: still channels move smoothly (tail step %.4f, fin step %.4f)" % [tag, _max_step(still["tail"]), _max_step(still["flap_l"])])
	var input: FishInput = fish.controls
	input.forward = 1.0
	input.boost = true
	fish.boost_amount = 100.0
	var lunge := await _record(rig, 120)
	var peak_snap := 0.0
	for v in lunge["snap"]:
		peak_snap = maxf(peak_snap, absf(float(v)))
	print("      lunge: peak thrust %.1f m/s2, bursts %d, peak snap %.3f rad (cap %.3f), tail step max %.4f" % [lunge["thrust"], lunge["bursts"], peak_snap, snap_rad, _max_step(lunge["tail"])])
	_check(int(lunge["bursts"]) >= 1, "%s: a lunge fires a tail burst (%d)" % [tag, lunge["bursts"]])
	_check(peak_snap > snap_rad * 0.3 and peak_snap <= snap_rad * 1.31, "%s: the snap is a real flick, bounded (%.3f of %.3f)" % [tag, peak_snap, snap_rad])
	_check(_max_step(lunge["tail"]) < 0.12, "%s: the snap is continuous, no pop (largest frame step %.4f)" % [tag, _max_step(lunge["tail"])])
	_check(float(rig.peak_rate["flap"]) < 4.0 and _max_step(lunge["sweep"]) < 0.08 and _max_step(lunge["flutter"]) < 0.08, "%s: fins blend smoothly in the burst (flap rate %.2f rad/s, sweep %.3f flutter %.3f)" % [tag, float(rig.peak_rate["flap"]), _max_step(lunge["sweep"]), _max_step(lunge["flutter"])])
	input.boost = false
	input.forward = 1.0
	await _frames(120)
	var fast := await _record(rig, 150)
	print("      cruising: speed share %.2f, flap span %.3f, sweep mean %.3f" % [fast["speed_t"], _span(fast["flap_l"]), _mean(fast["sweep"])])
	_check(_span(fast["flap_l"]) < _span(still["flap_l"]) + 0.001, "%s: the scull is smaller at speed (%.3f < %.3f)" % [tag, _span(fast["flap_l"]), _span(still["flap_l"])])
	_check(_mean(fast["sweep"]) > _mean(still["sweep"]), "%s: fins sweep back at speed" % tag)
	input.stick = Vector2(1.0, 0.0)
	await _frames(40)
	var turning := await _record(rig, 90)
	var ml := _mean(turning["flap_l"])
	var mr := _mean(turning["flap_r"])
	print("      turning: mean flap left %.3f right %.3f" % [ml, mr])
	_check(absf(ml - mr) > 0.03, "%s: a turn favours one fin (%.3f vs %.3f)" % [tag, ml, mr])
	_check(_max_step(turning["tail"]) < 0.08, "%s: and the tail stays smooth in the turn (step %.4f)" % [tag, _max_step(turning["tail"])])
	input.stick = Vector2.ZERO
	input.forward = 0.0
	fish.controls = null
	var ok := true
	for p in rig.rig.points:
		ok = ok and is_finite(p.x) and is_finite(p.y) and is_finite(p.z)
	ok = ok and is_finite(rig.model.esca_world().x) and is_finite(rig.model.tail_bend)
	_check(ok, "%s: no NaN in the spine, tail or esca" % tag)


func _bite(form: Dictionary, rig: Node3D, tag: String) -> void:
	_place()
	await _frames(5)
	var bite := HunterBite.new()
	bite.name = "HunterBite"
	fish.add_child(bite)
	bite.setup(fish, form)
	bite.refresh_model()
	var input := FishInput.new()
	fish.controls = input
	await _frames(40)
	var bursts_before: int = rig.shown["bursts"]
	var peak_open := 0.0
	var landed: Array = []
	bite.chomped.connect(func(_m: Vector3, _r: float, _d: float, _c: int) -> void: landed.append(1))
	input.jump = true
	for i in 120:
		await get_tree().physics_frame
		if i == 6:
			input.jump = false
		peak_open = maxf(peak_open, float(rig.model.jaw_open))
		if not landed.is_empty() and i > 30:
			break
	print("      bite: landed %d, jaw peak %.2f, bursts %d -> %d" % [landed.size(), peak_open, bursts_before, rig.shown["bursts"]])
	_check(landed.size() >= 1, "%s: one press lands a bite" % tag)
	_check(peak_open > 0.6, "%s: the bite opens the angler's jaw (%.2f)" % [tag, peak_open])
	_check(int(rig.shown["bursts"]) > bursts_before, "%s: the bite's release snaps the tail" % tag)
	fish.controls = null
	bite.queue_free()
	await _frames(2)


## The tail spring's maths: an impulse rings and settles inside its cap.
func _spring_unit() -> void:
	print("spring:")
	var rig = load("res://scripts/what_stinks/forms/lantern_rig.gd").new()
	var w := TAU * float(rig.opt("angler_tail_hz"))
	var zeta := float(rig.opt("angler_tail_zeta"))
	var cap := deg_to_rad(float(rig.opt("angler_tail_snap_deg")))
	var x := 0.0
	var v := cap * w * 1.1
	var crossings := 0
	var prev := x
	var peak := 0.0
	var h := 1.0 / 120.0
	var settled_at := -1.0
	for i in 360:
		v += (-w * w * x - 2.0 * zeta * w * v) * h
		x += v * h
		peak = maxf(peak, absf(x))
		if prev * x < 0.0:
			crossings += 1
		prev = x
		if settled_at < 0.0 and i > 20 and absf(x) < peak * 0.1 and absf(v) < peak * w * 0.1:
			settled_at = i * h
	print("      peak %.3f rad, %d zero crossings, settled at %.2f s" % [peak, crossings, settled_at])
	_check(crossings >= 2, "the tail rings through the middle at least twice (%d)" % crossings)
	_check(peak < cap * 1.3, "and a full lunge stays inside the cap (%.3f)" % peak)
	_check(settled_at > 0.0 and settled_at < 2.5, "and settles in under 2.5 s (%.2f)" % settled_at)
	rig.free()


# ---------------------------------------------------------------------------------------------------------
# --shots=DIR (needs a window): contact sheets of the gait, for looking at by eye.

var _free: Camera3D


func _free_cam() -> Camera3D:
	if _free == null:
		_free = Camera3D.new()
		_free.far = 2000.0
		var lamp := OmniLight3D.new()
		lamp.omni_range = 300.0
		lamp.light_energy = 5.0
		_free.add_child(lamp)
		main.add_child(_free)
	return _free


## Puts the free camera `dist` body lengths from the fish along `dir` (fish-local) and looks at the body's middle.
func _aim(dir: Vector3, dist: float, up := Vector3.UP) -> void:
	var cam := _free_cam()
	var middle := fish.global_position
	cam.global_position = middle + fish.global_basis * (dir.normalized() * fish.hitbox_length * dist)
	cam.look_at(middle, up if absf(dir.normalized().dot(up)) < 0.95 else Vector3.FORWARD)
	cam.make_current()


## `count` frames `gap` seconds apart into one sheet (3 columns).
func _sheet_of(name: String, count: int, gap: float, dir: Vector3, dist: float, each: Callable = Callable()) -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var cols := 3
	var cell := Vector2i(420, 280)
	var sheet := Image.create(cell.x * cols, cell.y * int(ceil(float(count) / cols)), false, Image.FORMAT_RGB8)
	for i in count:
		if each.is_valid():
			each.call(i)
		_aim(dir, dist)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), Vector2i((i % cols) * cell.x, (i / cols) * cell.y))
		await get_tree().create_timer(gap).timeout
	sheet.save_png("%s/%s.png" % [shots_dir, name])


func _shots(rig: Node3D) -> void:
	print("      shots to ", shots_dir)
	_place()
	fish.controls = FishInput.new()
	await _frames(30)
	# Still, side and top: the scull and the idle sway over 2.4 s.
	await _sheet_of("still_side", 6, 0.4, Vector3(-1.0, 0.1, 0.1), 1.3)
	await _sheet_of("still_top", 6, 0.4, Vector3(0.0, 1.0, 0.25), 1.4)
	# A snap from rest, from above (pinned): the tail flick and its ringing.
	var pin := fish.global_position
	var pinner := func(_i: int) -> void:
		fish.global_position = pin
		fish.linear_velocity = Vector3.ZERO
	rig.snap_tail(1.0)
	await _sheet_of("snap_top", 9, 0.07, Vector3(0.0, 1.0, 0.25), 1.4, pinner)
	await _frames(40)
	rig.snap_tail(1.0)
	await _sheet_of("snap_side", 9, 0.07, Vector3(-1.0, 0.1, 0.1), 1.3, pinner)
	# A real lunge, the camera on the fish as it goes.
	await _frames(60)
	var input: FishInput = fish.controls
	input.forward = 1.0
	input.boost = true
	fish.boost_amount = 100.0
	await _sheet_of("lunge_side", 9, 0.12, Vector3(-1.0, 0.15, 0.3), 1.6)
	input.boost = false
	input.stick = Vector2(1.0, 0.0)
	await _sheet_of("turn_top", 6, 0.3, Vector3(0.0, 1.0, 0.3), 1.8)
	input.stick = Vector2.ZERO
	input.forward = 0.0
	input.air_roll = true
	input.stick = Vector2(1.0, 0.0)
	await _sheet_of("roll_front", 9, 0.2, Vector3(-0.3, 0.25, -1.0), 1.5)
	input.air_roll = false
	input.stick = Vector2.ZERO
	fish.controls = null
	_place()
	var cam := main.get_node("FollowCamera") as Camera3D
	cam.make_current()
