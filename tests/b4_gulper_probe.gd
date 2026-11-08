## B4: the Gulper Mother's Battletoads-style exaggeration across press / hold / release (AttackExaggerate in gulper_rig.gd):
## the pouch pinches on the press, balloons to a sail on the hold, clamps shut on the release; the body puffs a touch then
## deflates under the hold and rebounds fat on the gulp; the gulp bulge is bigger; hit-stop on contact slows the
## rig's own clock; hunter_exaggeration 0 is exactly the old look; the traces are smooth (no pops); camera margin grows.
##   Godot_console.exe --headless --path . res://tests/b4_gulper_probe.tscn
##   --shots=DIR (needs a window) saves a strip (rest / press / hold-peak / release / settle) from a side camera.
extends Node

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var tps := 120
var shots_dir := ""
var side: Camera3D


func _ready() -> void:
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


func _until(done: Callable, ticks: int) -> bool:
	for i in ticks:
		if done.call():
			return true
		await get_tree().physics_frame
	return done.call()


func _run() -> void:
	await _frames(5)
	tps = int(Engine.physics_ticks_per_second)
	await _in_match()
	print("b4_gulper_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## One sample of what the rig shows now.
func _sample(rig: Node3D) -> Dictionary:
	var skin: ShaderMaterial = rig.get("skin")
	var mesh: Node3D = (rig.get("rig") as SpineRig).instances[0]
	return {
		"gape": float(skin.get_shader_parameter("gape")),
		"girth": mesh.scale.x, "len": mesh.scale.z,
		"lump": float((skin.get_shader_parameter("lump") as Vector3).z), "t": Engine.get_physics_frames(),
	}


## A press-hold-release cycle of a kit at a fixed 60 fps: the biggest one-frame step of the gape and of the girth.
func _kit_steps(kit: AttackExaggerate) -> Vector2:
	var m := Vector2.ZERO
	var last := Vector2(kit.scale_of(&"jaw"), kit.scale_of(&"body"))
	kit.press()
	for i in 150:
		kit.hold(clampf(float(i) / 70.0, 0.0, 1.0))
		if i == 100:
			kit.release(1.0)
		if i == 108:
			kit.contact(1.0)
		kit.tick(1.0 / 60.0)
		var now := Vector2(kit.scale_of(&"jaw"), kit.scale_of(&"body"))
		m = Vector2(maxf(m.x, absf(now.x - last.x) * 1.1), maxf(m.y, absf(now.y - last.y)))
		last = now
	return m


func _in_match() -> void:
	fish.puppet = false
	fish.freeze = false
	var settings := WhatStinksSettings.shared()
	settings.form = "gulper_mother"
	settings.hide_time = 1.0
	settings.round_time = 300.0
	settings.arena_radius = 90.0
	settings.school_count = 4
	settings.school_min = 30
	settings.school_max = 30
	settings.min_players = 5
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	settings.variant = WhatStinksSettings.Variant.SWEEP
	settings.lock_bite = false
	settings.hold_cooldown_per_s = 0.0
	settings.hold_speed_mult = 1.0
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	settings.satiation_max = 1000.0
	HunterSize.shared().size_mult = 1.0
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	main.play_match()
	await _frames(5)
	var game: WhatStinksMatch = main.what_stinks
	if game == null:
		_check(false, "match started")
		return
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 4)
	var bite: HunterBite = game.bites[fish]
	var rig: Node3D = bite._model.get_meta("gulper_rig")
	var ex: AttackExaggerate = rig.ex
	_check(ex != null and bite.attack is SuctionAttack, "wiring: the rig owns the kit and the attack is the suction")
	fish.controls = FishInput.new()
	fish.global_position = Vector3(0.0, 60.0, 0.0)  # away from the schools: a clean bite on nothing
	fish.linear_velocity = Vector3.ZERO
	await _frames(tps / 2)
	var punches: Array = []
	var stops: Array = []
	ex.camera_punch.connect(func(a: float, _d: Vector3) -> void: punches.append(a))
	ex.hit_stopped.connect(func(n: int) -> void: stops.append(n))
	if shots_dir != "":
		_make_side_camera()

	print("      A: rest")
	var rest := _sample(rig)
	_check(absf(rest.girth - 1.0) < 0.001 and absf(rest.len - 1.0) < 0.001, "rest: body at rest scale (%.3f)" % rest.girth)
	_check(rest.gape < 0.3 and rest.lump == 0.0, "rest: pouch near shut (gape %.2f)" % rest.gape)

	print("      B: press / hold / release")
	bite.cooldown = 0.0
	var trace: Array = []
	var shots: Array = []
	if shots_dir != "":
		shots.append(await _grab())
	bite.try_open()
	var min_gape := 99.0
	var max_puff := 0.0
	for i in int(tps * 0.18):
		await get_tree().physics_frame
		var s := _sample(rig)
		trace.append(s)
		min_gape = minf(min_gape, s.gape)
		max_puff = maxf(max_puff, s.girth)
		if shots_dir != "" and i == int(tps * 0.1):
			shots.append(await _grab())
	_check(min_gape < rest.gape - 0.1, "press: the pouch pinches before it swells (gape %.2f from %.2f)" % [min_gape, rest.gape])
	_check(max_puff > 1.04, "press: the body puffs up a touch (girth %.2f)" % max_puff)
	var peak_gape := 0.0
	var min_girth := 9.0
	for i in int(tps * 1.6):
		await get_tree().physics_frame
		var s := _sample(rig)
		trace.append(s)
		peak_gape = maxf(peak_gape, s.gape)
		min_girth = minf(min_girth, s.girth)
		if shots_dir != "" and i == int(tps * 1.45):
			shots.append(await _grab())
	_check(bite.holding() and bite.charge() > 0.8, "hold: the charge built (%.2f)" % bite.charge())
	_check(peak_gape > 2.0, "hold: the pouch balloons to a sail (gape %.2f, 1.25 was the most before)" % peak_gape)
	_check(min_girth < 0.82, "hold: the body deflates (girth %.2f)" % min_girth)
	_check(ex.camera_margin(1.0) > 1.5, "hold: the camera margin grows (%.2f)" % ex.camera_margin(1.0))
	var held_len: float = _sample(rig).len
	_check(held_len > 1.02, "hold: a deflated body lengthens a little (%.3f)" % held_len)
	bite.try_close()
	var release_gape := 99.0
	var rebound := 0.0
	var slow_seen := false
	for i in int(tps * 1.4):
		await get_tree().physics_frame
		var s := _sample(rig)
		trace.append(s)
		release_gape = minf(release_gape, s.gape)
		rebound = maxf(rebound, s.girth)
		slow_seen = slow_seen or ex.in_hit_stop()
		if shots_dir != "" and i == int(tps * 0.15):
			shots.append(await _grab())
	_check(release_gape < peak_gape - 1.5, "release: the pouch clamps shut (gape %.2f from %.2f)" % [release_gape, peak_gape])
	_check(rebound > 1.12, "release: the body rebounds fat on the gulp (girth %.2f)" % rebound)
	_check(punches.size() >= 1 and stops.size() >= 1 and stops[0] >= 1, "contact: camera punch (%d) and hit-stop (%s ticks)" % [punches.size(), str(stops)])
	_check(slow_seen, "contact: the rig's own clock slowed during the hit-stop")
	await _frames(tps * 2)
	if shots_dir != "":
		shots.append(await _grab())
	var end := _sample(rig)
	_check(absf(end.girth - 1.0) < 0.02 and end.gape < 0.4, "settle: back to rest (girth %.3f, gape %.2f)" % [end.girth, end.gape])
	_check(ex.idle(), "settle: the kit is idle")
	var kit := AttackExaggerate.new(AttackExaggerate.params_from(null, {"exaggerate": rig.get("EXAGGERATE")}))
	var steps := _kit_steps(kit)
	_check(steps.x < 0.6 and steps.y < 0.16, "smooth: at 60 fps the biggest frame step is gape %.2f, girth %.3f (the snap spans several frames)" % [steps.x, steps.y])
	if shots_dir != "":
		_save_strip(shots)

	print("      C: the gulp bulge")
	bite.cooldown = 0.0
	await _lump_peak(game, bite, rig)

	print("      D: master 0 is the old look")
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	ex.set_strength(0.0, 1.0)
	rig.set("_pin_master", 0.0)
	bite.cooldown = 0.0
	bite.try_open()
	var flat := true
	for i in tps:
		await get_tree().physics_frame
		var s := _sample(rig)
		flat = flat and absf(s.girth - 1.0) < 0.0001 and absf(s.len - 1.0) < 0.0001
	_check(flat, "master 0: the body never moves off 1.0 through a hold")
	_check(float(rig.get("gape_extra")) == 0.0, "master 0: no extra gape")
	bite.try_close()
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	rig.set("_pin_master", -1.0)

	print("      E: abort and puppets")
	await _until(func() -> bool: return bite.cooldown <= 0.0, tps * 5)
	bite.cooldown = 0.0
	bite.try_open()
	await _frames(tps / 2)
	bite.abort()
	await _frames(tps * 2)
	_check(ex.idle(), "abort: the kit eases back to rest")


## A bite on a school: the shader's bulge against the plain lump the attack asks for.
func _lump_peak(game: WhatStinksMatch, bite: HunterBite, rig: Node3D) -> void:
	var peak := 0.0
	var plain := 0.0
	for attempt in 4:  # a school may swim off the mouth: try again at the next one
		var got: Vector2 = await _gulp_at(game.field.schools[attempt], game, bite, rig)
		peak = got.x
		plain = got.y
		if plain > 0.0:
			break
	_check(plain > 0.0, "gulp: the school gave a lump (%.2f)" % plain)
	_check(plain == 0.0 or peak > plain * 1.4, "gulp: the bulge is bigger than the plain lump (%.2f vs %.2f)" % [peak, plain])


func _gulp_at(school: School, game: WhatStinksMatch, bite: HunterBite, rig: Node3D) -> Vector2:
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	fish.global_transform = Transform3D(Basis.IDENTITY, school.middle())
	fish.global_position += school.middle() - bite.mouth_point() + Vector3(0.0, 0.0, float(bite.size.bite_reach(fish, bite.form)) * 0.8)
	fish.linear_velocity = Vector3.ZERO
	await _frames(3)
	bite.cooldown = 0.0
	bite.try_open()
	await _frames(tps * 2)
	bite.try_close()
	var peak := 0.0
	var plain := 0.0
	for i in tps * 2:
		await get_tree().physics_frame
		peak = maxf(peak, float((rig.skin.get_shader_parameter("lump") as Vector3).z))
		plain = maxf(plain, (bite.attack as SuctionAttack).lump_vec(bite, rig.skin.get_shader_parameter("belly_span")).z)
	return Vector2(peak, plain)


func _make_side_camera() -> void:
	side = Camera3D.new()
	side.far = 2000.0
	var lamp := OmniLight3D.new()  # the deep is dark: light the body for the shot
	lamp.omni_range = 400.0
	lamp.light_energy = 6.0
	side.add_child(lamp)
	main.add_child(side)
	side.make_current()


func _grab() -> Image:
	var length := fish.hitbox_length
	side.global_position = fish.global_position + fish.global_basis * (Vector3(-0.9, 0.35, -0.75).normalized() * length * 0.85)
	side.fov = 85.0
	side.look_at(fish.global_position, Vector3.UP)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _save_strip(frames: Array) -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	if frames.is_empty():
		return
	var w: int = (frames[0] as Image).get_width() / 2
	var h: int = (frames[0] as Image).get_height() / 2
	var sheet := Image.create(w * 3, h * 2, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var im: Image = frames[i]
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h)
		sheet.blend_rect(im, Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
	sheet.save_png("%s/gulper_strip.png" % shots_dir)
