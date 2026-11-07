## What Stinks? Hunter size feel (what_stinks.md section 3): how the size dial moves speed, turning, coasting and
## the camera, in metres and in body lengths, so a size that "doesn't feel right" shows up as a number.
## Prints a table per form; checks nothing (a measuring probe, always exits 0).
##   Godot_console.exe --headless --path . res://tests/hunter_size_feel_probe.tscn [-- --forms=a,b --sizes=0.5,1,2,4]

extends Node

const DEFAULT_SIZES := [0.5, 1.0, 2.0, 4.0]

var main: Node
var fish: FishController
var camera: Camera3D
var sizes: Array = DEFAULT_SIZES.duplicate()
var only_forms: PackedStringArray = PackedStringArray()
var rows: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--forms="):
			only_forms = arg.trim_prefix("--forms=").split(",")
		elif arg.begins_with("--exps="):  # speed,accel,turn exponents
			var e := arg.trim_prefix("--exps=").split(",")
			var dial := HunterSize.shared()
			dial.speed_exp = float(e[0])
			dial.accel_exp = float(e[1])
			dial.turn_exp = float(e[2])
			print("exps: speed %s accel %s turn %s" % [e[0], e[1], e[2]])
		elif arg.begins_with("--sizes="):
			sizes = []
			for part in arg.trim_prefix("--sizes=").split(","):
				sizes.append(float(part))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	await _frames(5)
	main.set_environment("Ocean")
	await _frames(5)
	var keys: Array = HunterForms.ready_keys()
	print("forms ready: %s" % [keys])
	for key: String in keys:
		if only_forms.size() > 0 and not only_forms.has(key):
			continue
		for s: float in sizes:
			await _measure(key, s)
	_print_table()
	get_tree().quit(0)


func _place() -> void:
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 25.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


func _heading() -> float:
	var f := -fish.global_transform.basis.z
	return atan2(f.x, f.z)


func _measure(key: String, s: float) -> void:
	print("measuring %s x%.2f" % [key, s])
	var form := HunterForms.sheet(key)
	var size := HunterSize.shared()
	size.size_mult = s
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	size.apply(fish, form)
	HunterForms.dress(fish, key)
	await _frames(3)
	_place()
	await _frames(3)
	var tps := int(Engine.physics_ticks_per_second)
	var dt := 1.0 / float(tps)
	var length := fish.hitbox_length
	var input := FishInput.new()
	fish.controls = input

	# Straight swim, no boost: top speed, time to 90% of it.
	var start := fish.global_position
	input.forward = 1.0
	var speeds: Array[float] = []
	for i in tps * 14:
		await get_tree().physics_frame
		speeds.append(fish.linear_velocity.length())
	var top := 0.0
	for v in speeds:
		top = maxf(top, v)
	var t90 := -1.0
	for i in speeds.size():
		if speeds[i] >= 0.9 * top:
			t90 = float(i) * dt
			break
	var swum := fish.global_position.distance_to(start)

	# Camera while cruising at top speed (the lag), then the gap.
	var cruise_gap := camera.global_position.distance_to(fish.global_position)

	# Turn at cruise: yaw rate and radius over the last second of a 3 s turn.
	input.stick = Vector2(1.0, 0.0)
	var yaw_start := 0.0
	var turn_speed := 0.0
	var turn_ticks := tps * 3
	var last := _heading()
	var swept := 0.0
	var swept_ticks := 0
	for i in turn_ticks:
		await get_tree().physics_frame
		var h := _heading()
		var d := wrapf(h - last, -PI, PI)
		last = h
		if i >= turn_ticks - tps:
			swept += d
			swept_ticks += 1
			turn_speed += fish.linear_velocity.length()
	var yaw_rate := absf(swept) / (float(swept_ticks) * dt) if swept_ticks > 0 else 0.0
	turn_speed /= float(maxi(swept_ticks, 1))
	var radius := turn_speed / yaw_rate if yaw_rate > 0.01 else INF
	input.stick = Vector2.ZERO

	# Coast: release, time to half speed and distance covered.
	input.forward = 0.0
	var v0 := fish.linear_velocity.length()
	var from := fish.global_position
	var half_t := -1.0
	for i in tps * 20:
		await get_tree().physics_frame
		if fish.linear_velocity.length() <= 0.5 * v0:
			half_t = float(i) * dt
			break
	var coast := fish.global_position.distance_to(from)

	# Camera at rest: gap after a settle.
	_place()
	fish.controls = null
	await _frames(1)
	var zoom := size.frame(camera, fish, form)
	if camera.has_method("snap"):
		camera.call("snap")
	await _frames(tps * 2)
	var rest_gap := camera.global_position.distance_to(fish.global_position)

	rows.append({
		"form": key, "s": s, "len": length, "top": top, "top_bl": top / length, "t90": t90,
		"swum_bl": swum / length, "yaw": yaw_rate, "radius": radius, "radius_bl": radius / length,
		"half_t": half_t, "coast_bl": coast / length, "rest_gap": rest_gap, "rest_gap_bl": rest_gap / length,
		"cruise_gap_bl": cruise_gap / length, "zoom": zoom, "gap_per_len": rest_gap / length,
		"view_speed": top / maxf(rest_gap, 0.01),
	})


func _print_table() -> void:
	print("")
	print("form             size  len_m  top_m/s top_BL/s t90_s  yaw_r/s turn_R_BL half_s coast_BL  cam_m  cam_BL cruise_BL zoom  top/cam(1/s)")
	var last_key := ""
	for r: Dictionary in rows:
		if last_key != "" and last_key != str(r["form"]):
			print("")
		last_key = str(r["form"])
		print("%-16s %4.2f %6.2f %8.2f %8.2f %6.2f %7.2f %9.2f %6.2f %8.2f %6.2f %6.2f %8.2f %5.2f %8.2f" % [
			r["form"], r["s"], r["len"], r["top"], r["top_bl"], r["t90"], r["yaw"], r["radius_bl"],
			r["half_t"], r["coast_bl"], r["rest_gap"], r["rest_gap_bl"], r["cruise_gap_bl"], r["zoom"], r["view_speed"]])
