## B1 whales (planning_new_hunters.md phase B): the Battletoads-style exaggeration on the whales' engulf. For every
## species a real ChompKit.Bite is driven through press / hold / release / landing beside a WhaleJaw wearing the
## species' form sheet, and the pose is read back each tick: the gape reaches well past whale_gape_deg but never past
## whale_gape_max_deg, the body squashes on the press and swells on the charge, the throat balloons empty, the baleen /
## teeth pop, the jaw rebounds off the landing and everything settles back (no popping: per-tick angle steps are bounded),
## hit-stop freezes the pose a few ticks, hunter_exaggeration 0 is exactly the old pose. Then a real match with the
## Humpback to check the engulf attack wires the beats (press, hold, release, contact).
##   Godot_console.exe --headless --path . res://tests/b1_whales_probe.tscn            (add `-- --species-only` to skip the match)
## With a window, `-- --shots --out=DIR [--species=0,1,2,3,4]` writes a strip of poses per species instead (rest, press,
## hold early, hold peak, release, contact, rebound, settle) from the side and the front, plus a contact sheet.
extends Node

const KEYS := ["humpback", "orca", "beluga", "sperm", "blue"]
const DT := 1.0 / 120.0

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var tps := 120
var shots := false
var out_dir := "user://b1_whale_strips"
var species_list := [0, 1, 2, 3, 4]
var _camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--shots":
			shots = true
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--species="):
			species_list = []
			for part in arg.trim_prefix("--species=").split(","):
				species_list.append(int(part))
	if shots:
		_shots_setup()
		_shots_run.call_deferred()
		return
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
	for species in 5:
		_species(species)
	_off_switch()
	if not OS.get_cmdline_user_args().has("--species-only"):
		await _in_match()
	print("b1_whales_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# --- A scripted bite on one species ---------------------------------------------------------

class Rig extends RefCounted:
	var model: FishModel
	var jaw: WhaleJaw
	var bite: ChompKit.Bite
	var sheet: Dictionary
	var frozen_ticks := 0
	var landed_tick := -1
	var tick := 0
	var held := true
	var landed_now := false

	func _init(species: int, parent: Node, with_sheet: Dictionary) -> void:
		sheet = with_sheet
		model = FishModel.build(FishCharacter.FishClass.TITAN, species, 0)
		parent.add_child(model)
		jaw = WhaleJaw.new()
		jaw.form = sheet
		jaw.build(model, Color.WHITE)
		model.set_meta("hunter_jaw", jaw)
		bite = ChompKit.Bite.new(UnnaturalSettings.shared())

	## The press: what HunterBite.try_open + EngulfAttack's wiring do.
	func press() -> void:
		bite.open_now(0.12, 2.0, 1.2)
		jaw.ex_press()

	func release() -> void:
		var charge := bite.charge
		bite.release()
		jaw.ex_release(charge)

	## One physics tick of HunterBite._physics_process: attack.on_hold / on_tick, the Bite, the jaw's pose, the landing.
	func step(holding: bool) -> void:
		tick += 1
		if holding:
			jaw.ex_hold(bite.charge)
		jaw.step(DT)
		var landed := bite.update(DT)
		jaw.set_overshoot(bite.over)
		jaw.pose(bite.open)
		landed_now = landed
		if landed:
			landed_tick = tick
			jaw.ex_contact(1.0)
		if jaw.ex.in_hit_stop():
			frozen_ticks += 1

	func dispose() -> void:
		model.queue_free()


func _species(species: int) -> void:
	var settings := WhatStinksSettings.shared()
	settings.whale_gape_deg = 80.0
	var key: String = KEYS[species]
	var sheet: Dictionary = (load("res://scripts/what_stinks/forms/%s.gd" % key) as GDScript).call("sheet")
	var rig := Rig.new(species, self, sheet)
	var jaw := rig.jaw
	var base_scale := rig.model.scale
	var gape_max := deg_to_rad(maxf(float(settings.get("whale_gape_max_deg") if settings.get("whale_gape_max_deg") != null else 135.0), 10.0))
	_check(jaw.ex != null and is_equal_approx(jaw.angle(), 0.0), "%s: rests shut with an exaggeration kit" % key)
	rig.press()
	var angles: Array[float] = []
	var body_min := 9.0
	var body_max := 0.0
	var teeth_max := 1.0
	var swell_empty := 0.0
	var swell_skin: ShaderMaterial = jaw.info.skin if not bool(jaw.info.sperm) else null
	# Press and hold a second (the full charge).
	for i in tps:
		rig.step(true)
		angles.append(jaw.angle())
		body_min = minf(body_min, rig.model.scale.x / base_scale.x)
		body_max = maxf(body_max, rig.model.scale.x / base_scale.x)
		teeth_max = maxf(teeth_max, jaw.ex.scale_of(&"teeth"))
		if swell_skin != null:
			swell_empty = maxf(swell_empty, float(swell_skin.get_shader_parameter("throat_swell")))
	var hold_deg := rad_to_deg(-jaw.angle())
	_check(hold_deg > settings.whale_gape_deg * 1.2, "%s: the held gape (%.0f deg) is well past the old %.0f" % [key, hold_deg, settings.whale_gape_deg])
	_check(hold_deg <= rad_to_deg(gape_max) + 0.5, "%s: and never past the limit (%.0f of %.0f)" % [key, hold_deg, rad_to_deg(gape_max)])
	var anticipation: float = rig.model.scale.x / base_scale.x
	_check(body_min < 0.995 or sheet.get("exaggerate", {}).get("channels", {}).has("head"), "%s: the press squashes the body first (min %.3f)" % [key, body_min])
	_check(body_max > 1.04, "%s: the charge swells the body (max %.3f, now %.3f)" % [key, body_max, anticipation])
	_check(body_max < 1.4, "%s: but the camera margin stays small (peak %.2f)" % [key, jaw.peak_scale()])
	_check(teeth_max > 1.35, "%s: the baleen / teeth grow (x%.2f)" % [key, teeth_max])
	if swell_skin != null:
		_check(swell_empty > 0.0, "%s: the empty throat balloons while held (swell %.3f m)" % [key, swell_empty])
	_check(rig.bite.open > 0.95, "%s: bite is fully open" % key)
	# Release: the jaw slams shut, lands, bounces and settles.
	rig.release()
	var max_step := 0.0
	var prev := jaw.angle()
	var rebound_deg := 0.0
	var frozen_pose := true
	var last_angle := jaw.angle()
	var stopped := 0
	var stop_angles: Array[float] = []
	for i in tps * 2:
		rig.step(false)
		var a := jaw.angle()
		if OS.get_cmdline_user_args().has("--trace") and i < 40:
			print("   t%d angle %.1f open %.2f over %.2f mult %.2f rebound %.1f" % [i, rad_to_deg(-a), rig.bite.open, rig.bite.over, jaw.ex.scale_of(&"jaw"), rad_to_deg(jaw._rebound)])
		max_step = maxf(max_step, absf(a - prev))
		prev = a
		if rig.landed_tick >= 0:
			rebound_deg = maxf(rebound_deg, rad_to_deg(-a))
			if jaw.ex.in_hit_stop():
				stopped += 1
				stop_angles.append(a)
		if rig.landed_tick >= 0 and i > rig.landed_tick + tps:
			break
	_check(rig.landed_tick >= 0, "%s: the release lands" % key)
	_check(rig.frozen_ticks >= 2 and rig.frozen_ticks <= 4, "%s: hit-stop holds %d ticks" % [key, rig.frozen_ticks])
	for a in stop_angles:
		if absf(a - stop_angles[0]) > 0.0001:
			frozen_pose = false
	_check(frozen_pose, "%s: the pose does not move during hit-stop" % key)
	_check(rebound_deg > 4.0, "%s: the jaw rebounds open off the landing (%.1f deg)" % [key, rebound_deg])
	_check(rad_to_deg(max_step) < 32.0, "%s: no popping: largest per-tick jaw step %.1f deg" % [key, rad_to_deg(max_step)])
	for i in tps * 2:
		rig.step(false)
	_check(absf(jaw.angle()) < 0.01 and rig.model.scale.is_equal_approx(base_scale) and jaw.ex.idle(), "%s: everything settles back (angle %.3f, scale %s, phase %d)" % [key, jaw.angle(), rig.model.scale, jaw.ex.phase])
	var parts_ok := true
	for part in jaw._parts:
		if not (part.node as Node3D).scale.is_equal_approx(Vector3.ONE):
			parts_ok = false
	_check(parts_ok, "%s: baleen / teeth / tongue are back to rest size" % key)
	# An aborted bite eases back with no snap.
	rig.press()
	for i in tps / 2:
		rig.step(true)
	rig.bite.cancel()
	jaw.ex_abort()
	for i in tps * 2:
		rig.step(false)
	_check(absf(jaw.angle()) < 0.01 and rig.model.scale.is_equal_approx(base_scale), "%s: an aborted bite settles with no rebound" % key)
	rig.dispose()


func _off_switch() -> void:
	var settings := WhatStinksSettings.shared()
	settings.whale_gape_deg = 80.0
	var saved: Variant = settings.get("hunter_exaggeration")
	var rig := Rig.new(0, self, (load("res://scripts/what_stinks/forms/humpback.gd") as GDScript).call("sheet"))
	rig.sheet = {}
	rig.jaw.set_exaggeration({"exaggeration": 0.0})
	var base := rig.model.scale
	rig.press()
	var worst := 0.0
	for i in tps:
		rig.step(true)
		worst = maxf(worst, rig.model.scale.distance_to(base))
	_check(worst < 0.0001, "off (form multiplier 0): the body is never scaled (%.5f)" % worst)
	_check(absf(rad_to_deg(-rig.jaw.angle()) - 80.0) < 12.0, "off: the held gape is the old whale_gape_deg (%.1f)" % rad_to_deg(-rig.jaw.angle()))
	rig.release()
	for i in tps:
		rig.step(false)
	_check(rig.frozen_ticks == 0, "off: no hit-stop")
	rig.dispose()
	if saved != null:
		settings.set("hunter_exaggeration", saved)


# --- The attack drives the beats in a real match ----------------------------------------------

func _in_match() -> void:
	fish.puppet = false
	fish.freeze = false
	var settings := WhatStinksSettings.shared()
	settings.form = "humpback"
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
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	settings.satiation_max = 1000.0
	HunterSize.shared().size_mult = 1.0
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	main.play_match()
	await _frames(5)
	var game: WhatStinksMatch = main.what_stinks
	if game == null:
		_check(false, "match: started")
		return
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 4)
	var bite: HunterBite = game.bites[fish]
	var jaw := bite._jaw as WhaleJaw
	_check(jaw != null and jaw.ex != null and str(bite.form["key"]) == "humpback", "match: the Humpback's jaw carries the kit")
	if jaw == null:
		return
	var input := FishInput.new()
	fish.controls = input
	var snaps := [0]
	var stops := [0]
	jaw.ex.snapped.connect(func() -> void: snaps[0] += 1)
	jaw.ex.hit_stopped.connect(func(_n: int) -> void: stops[0] += 1)
	var peak := 0.0
	var phases := {}
	input.jump = true
	for i in tps * 2:
		await get_tree().physics_frame
		phases[jaw.ex.phase] = true
		peak = maxf(peak, rad_to_deg(-jaw.angle()))
	_check(phases.has(AttackExaggerate.Phase.ANTICIPATE) and phases.has(AttackExaggerate.Phase.HOLD), "match: the press runs the anticipation then the hold (%s)" % [phases.keys()])
	_check(peak > settings.whale_gape_deg * 1.2, "match: the held gape is exaggerated (%.0f deg)" % peak)
	_check(jaw.ex.charge > 0.5, "match: the charge feeds the kit (%.2f)" % jaw.ex.charge)
	input.jump = false
	await _until(func() -> bool: return snaps[0] > 0, tps)
	_check(snaps[0] == 1, "match: the release fires the snap once (%d)" % snaps[0])
	await _until(func() -> bool: return stops[0] > 0, tps * 2)
	_check(stops[0] == 1, "match: the landing's contact starts one hit-stop (%d)" % stops[0])
	await _frames(tps * 3)
	_check(jaw.ex.idle() and absf(jaw.angle()) < 0.02, "match: it settles after the bite (phase %d, angle %.3f)" % [jaw.ex.phase, jaw.angle()])
	input.jump = true
	await _frames(tps / 3)
	fish.battered = true
	await _frames(tps)
	fish.battered = false
	input.jump = false
	await _frames(tps * 2)
	_check(absf(jaw.angle()) < 0.05 and jaw.ex.phase != AttackExaggerate.Phase.HOLD, "match: a bite called off (battered) lets the kit settle (phase %d)" % jaw.ex.phase)


# --- Strips (needs a window) --------------------------------------------------------------------

func _shots_setup() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(960, 640)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.2, 0.36, 0.5)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.6, 0.0)
	sun.light_energy = 1.3
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.far = 500.0
	add_child(_camera)
	_camera.make_current()


func _shots_run() -> void:
	var views := {"side": Vector3(1.0, 0.1, 0.0), "front": Vector3(0.55, 0.25, -1.0)}
	var marks := ["rest", "press", "hold_early", "hold_peak", "release", "contact", "rebound", "settle"]
	for species: int in species_list:
		var key: String = KEYS[species]
		var sheet: Dictionary = (load("res://scripts/what_stinks/forms/%s.gd" % key) as GDScript).call("sheet")
		var rig := Rig.new(species, self, sheet)
		var length := rig.model._size.z
		var head := Vector3(0.0, 0.0, -length * 0.38)
		for view_name: String in views:
			rig.jaw.ex_reset()
			rig.jaw.pose(0.0)
			rig.bite = ChompKit.Bite.new(UnnaturalSettings.shared())
			var frames: Array[Image] = []
			var shoot := func(mark: String) -> void:
				rig.model.apply_bend()
				var view_dir: Vector3 = views[view_name]
				_camera.position = head + view_dir.normalized() * length * 0.9
				_camera.look_at(head + Vector3(0.0, -length * 0.1, length * 0.06), Vector3.UP)
				for n in 3:
					await RenderingServer.frame_post_draw
				var image := get_viewport().get_texture().get_image()
				image.save_png(out_dir.path_join("%s_%s_%s.png" % [key, view_name, mark]))
				frames.append(image)
			await shoot.call("rest")
			rig.press()
			for i in 8:  # ~0.07 s in: the squash
				rig.step(true)
			await shoot.call("press")
			for i in 60:
				rig.step(true)
			await shoot.call("hold_early")
			for i in 120:
				rig.step(true)
			await shoot.call("hold_peak")
			rig.release()
			for i in 5:
				rig.step(false)
			await shoot.call("release")
			var guard := 0
			while rig.landed_tick < 0 and guard < 200:
				rig.step(false)
				guard += 1
			await shoot.call("contact")
			for i in 14:
				rig.step(false)
			await shoot.call("rebound")
			for i in 120:
				rig.step(false)
			await shoot.call("settle")
			var w := frames[0].get_width() / 2
			var h := frames[0].get_height() / 2
			var sheet_image := Image.create(w * 4, h * 2, false, Image.FORMAT_RGB8)
			for n in frames.size():
				var f := frames[n].duplicate() as Image
				f.convert(Image.FORMAT_RGB8)
				f.resize(w, h, Image.INTERPOLATE_LANCZOS)
				sheet_image.blit_rect(f, Rect2i(0, 0, w, h), Vector2i((n % 4) * w, (n / 4) * h))
			sheet_image.save_png(out_dir.path_join("%s_%s_strip.png" % [key, view_name]))
		rig.dispose()
		await get_tree().process_frame
	print("b1_whales_probe: strips written to ", ProjectSettings.globalize_path(out_dir), " marks: ", marks)
	get_tree().quit()
