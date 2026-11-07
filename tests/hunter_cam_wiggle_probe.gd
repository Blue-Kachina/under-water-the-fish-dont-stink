extends Node
## What Stinks Hunter camera wiggle: runs a real match as each form and measures what the player sees while
## swimming: how far the Hunter swings across the screen (its bearing in the camera's frame), and how much the
## camera's own heading jitters, with the stick swept like a stride, held straight, and steered slowly.
## Prints a table; checks nothing.
##   Godot_console.exe --headless --path . res://tests/hunter_cam_wiggle_probe.tscn [-- --forms=a,b --cam=key=value,...]
## --cam sets UnnaturalSettings camera_* properties (e.g. camera_settle_rate=1.5) to try a tuning.

const SWEEP_HZ := 1.5

var main: Node
var game: WhatStinksMatch
var fish: FishController
var camera: Camera3D
var only_forms: PackedStringArray = PackedStringArray(["drowned_shark", "fallen_angel"])
var cam_overrides: Dictionary = {}
var rows: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--forms="):
			only_forms = arg.trim_prefix("--forms=").split(",")
		elif arg.begins_with("--cam="):
			for pair in arg.trim_prefix("--cam=").split(","):
				var kv := pair.split("=")
				cam_overrides[kv[0]] = float(kv[1])
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
	var settings := WhatStinksSettings.shared()
	settings.hide_time = 0.5
	settings.round_time = 600.0
	settings.arena_radius = 400.0
	settings.school_count = 2
	settings.min_players = 2
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	settings.variant = WhatStinksSettings.Variant.SWEEP
	HunterSize.shared().size_mult = HunterSize.MATCH_SIZE
	for prop: String in cam_overrides:  # UnnaturalSettings' camera group, which the match's camera reads every frame
		UnnaturalSettings.shared().set(prop, cam_overrides[prop])
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	main.play_match()
	await _frames(5)
	game = main.what_stinks
	if game == null:
		print("no match")
		get_tree().quit(1)
		return
	for i in 600:
		if game.phase == WhatStinksMatch.Phase.LIVE and not fish.controls_locked:
			break
		await get_tree().physics_frame
	for other in game.players:
		if other != fish:
			other.freeze = true
	print("camera: steady_heading=%s follow_style=%s free_cam=%s settle_turning_rate=%s heading_rate=%s rot_stiffness=%s lock_cam=%s" % [
			camera.get("steady_heading"), camera.get("follow_style"), camera.get("free_cam"), camera.get("settle_turning_rate"),
			camera.get("heading_rate"), camera.get("rotation_stiffness"), game.lock_cam])
	for key in only_forms:
		settings.form = key
		game.refresh_form(fish)
		await _frames(30)
		for scenario in ["sweep", "straight", "steer"]:
			await _measure(key, scenario)
	_print_table()
	get_tree().quit(0)


func _reset_pose() -> void:
	fish.global_transform = game._hunter_start()
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	if camera.has_method("snap"):
		camera.call("snap")


func _heading(basis: Basis) -> float:
	var f := -basis.z
	return atan2(f.x, f.z)


func _measure(key: String, scenario: String) -> void:
	_reset_pose()
	var input := FishInput.new()
	fish.controls = input
	input.forward = 1.0
	Input.action_press("thrust_forward")  # the camera reads the player's own throttle (Settle swings round once it's let go)
	var tps := int(Engine.physics_ticks_per_second)
	var dt := 1.0 / float(tps)
	var warm := tps * 2
	var span := tps * 5
	var fish_yaw := PackedFloat32Array()
	var cam_yaw := PackedFloat32Array()
	var bearing := PackedFloat32Array()
	var cam_pitch := PackedFloat32Array()
	var last_fish := 0.0
	var last_cam := 0.0
	var last_head := 0.0
	var head_yaw := PackedFloat32Array()
	var fish_ang := 0.0
	var head_ang := 0.0
	var cam_ang := 0.0
	var roll_series := PackedFloat32Array()
	var dist_series := PackedFloat32Array()
	var fish_series := PackedFloat32Array()
	var head_series := PackedFloat32Array()
	var cam_series := PackedFloat32Array()
	for i in warm + span:
		var t := float(i) * dt
		match scenario:
			"sweep":
				input.stick = Vector2(sin(TAU * SWEEP_HZ * t), 0.0)
			"steer":
				input.stick = Vector2(0.5 * sin(TAU * 0.25 * t), 0.0)
			_:
				input.stick = Vector2.ZERO
		await get_tree().physics_frame
		var hv: Vector3 = camera.get("_heading")
		var hh := atan2(hv.x, hv.z)
		var fh := _heading(fish.global_transform.basis)
		var ch := _heading(camera.global_transform.basis)
		var to_fish := fish.global_position - camera.global_position
		var bear := wrapf(atan2(to_fish.x, to_fish.z) - ch, -PI, PI)
		fish_ang += wrapf(fh - last_fish, -PI, PI)
		head_ang += wrapf(hh - last_head, -PI, PI)
		cam_ang += wrapf(ch - last_cam, -PI, PI)
		if i > warm:
			roll_series.append(asin(clampf(camera.global_transform.basis.x.y, -1.0, 1.0)))
			dist_series.append(camera.global_position.distance_to(fish.global_position))
			fish_series.append(fish_ang)
			head_series.append(head_ang)
			cam_series.append(cam_ang)
			head_yaw.append(wrapf(hh - last_head, -PI, PI) / dt)
			fish_yaw.append(wrapf(fh - last_fish, -PI, PI) / dt)
			cam_yaw.append(wrapf(ch - last_cam, -PI, PI) / dt)
			bearing.append(bear)
			cam_pitch.append(asin(clampf(-camera.global_transform.basis.z.y, -1.0, 1.0)))
		last_fish = fh
		last_cam = ch
		last_head = hh
	print("  [%s %s] camera _coast=%.2f _settle=%.2f _settle_turn=%.2f throttle_held=%s" % [key, scenario, camera.get("_coast"), camera.get("_settle"), camera.get("_settle_turn"), camera.call("_throttle_held")])
	input.stick = Vector2.ZERO
	Input.action_release("thrust_forward")
	rows.append({
		"form": key, "scenario": scenario, "roll_sd": rad_to_deg(_sd(roll_series)), "dist_sd": _sd(dist_series),
		"fish_dev": rad_to_deg(_dev(fish_series, tps)), "head_dev": rad_to_deg(_dev(head_series, tps)), "cam_dev": rad_to_deg(_dev(cam_series, tps)),
		"fish_yaw": rad_to_deg(_rms(fish_yaw)), "cam_yaw": rad_to_deg(_rms(cam_yaw)), "head_yaw": rad_to_deg(_rms(head_yaw)),
		"bear_p2p": rad_to_deg(_p2p(bearing)), "bear_sd": rad_to_deg(_sd(bearing)),
		"pitch_sd": rad_to_deg(_sd(cam_pitch)),
	})


## RMS deviation of `angles` from their centred moving average over `window` samples (the wobble, not the turn).
func _dev(angles: PackedFloat32Array, window: int) -> float:
	var n := angles.size()
	var sum := 0.0
	var count := 0
	var half := window / 2
	for i in range(half, n - half):
		var mean := 0.0
		for j in range(i - half, i + half + 1):
			mean += angles[j]
		mean /= float(window + 1)
		sum += (angles[i] - mean) * (angles[i] - mean)
		count += 1
	return sqrt(sum / float(maxi(count, 1)))


func _rms(values: PackedFloat32Array) -> float:
	var sum := 0.0
	for v in values:
		sum += v * v
	return sqrt(sum / float(maxi(values.size(), 1)))


func _sd(values: PackedFloat32Array) -> float:
	var mean := 0.0
	for v in values:
		mean += v
	mean /= float(maxi(values.size(), 1))
	var sum := 0.0
	for v in values:
		sum += (v - mean) * (v - mean)
	return sqrt(sum / float(maxi(values.size(), 1)))


func _p2p(values: PackedFloat32Array) -> float:
	var lo := INF
	var hi := -INF
	for v in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return hi - lo if values.size() > 0 else 0.0


func _print_table() -> void:
	print("")
	print("cam overrides: %s" % [cam_overrides])
	print("form             scenario  fish_wobble  head_wobble  cam_wobble (deg rms off 1 s average)  cam_yaw_rms(deg/s)  screen_swing_p2p(deg)  roll_sd(deg)  cam_dist_sd(m)")
	for r: Dictionary in rows:
		print("%-16s %-9s %11.2f %12.2f %11.2f %29.1f %21.1f %13.2f %14.3f" % [r["form"], r["scenario"], r["fish_dev"], r["head_dev"], r["cam_dev"], r["cam_yaw"], r["bear_p2p"], r["roll_sd"], r["dist_sd"]])
