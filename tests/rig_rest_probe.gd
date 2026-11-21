## The rest of the procedural rig (planning_core_roadmap.md 2.3 P5 / 2.4, track rig-rest), everything behind toggles that
## default off:
##  - rig-off identity against tests/fixtures/rig_rest_baseline.json, RECORDED FROM THE CODE BEFORE THIS TRACK: the
##    jelly's bell uniforms (strides, free beat, no gait), the ray's skin/whip uniforms and bank, the shark's fins and
##    bend under a random tail, the school bakes, and in a game the sea hare's flap pivots and hinge uniforms;
##  - Gait.rig_bell_flap on: the bell's uniforms are the very same (the layer steps the model's own BellPulse); the flap
##    layer reproduces the controller's flap and reverse flutter from the rig's own clocks (no Time);
##  - the ray's rig (wing beat layer), the mantis's, the school bakes at the rig's phases and the shark's dorsal rider.
## Needs a fixed frame time so the in-game part is repeatable:
##   Godot_console.exe --headless --fixed-fps 60 --path . res://tests/rig_rest_probe.tscn [-- --record]
extends Node

const BASELINE := "res://tests/fixtures/rig_rest_baseline.json"
const DT := 1.0 / 60.0
const BAKED := [FishCharacter.FishClass.HUNTER, FishCharacter.FishClass.GLIDER, FishCharacter.FishClass.DRIFTER,
		FishCharacter.FishClass.SKIRMISHER, FishCharacter.FishClass.BREACHER, FishCharacter.FishClass.BRAWLER]

var record := false
var checks := 0
var failures := 0


func _ready() -> void:
	GaitSettings.rig_defaults_off = true  # its off-path recordings predate the rig defaults going on
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		record = record or arg == "--record"
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])


func _run() -> void:
	var results := {}
	results["jelly"] = _jelly(false)
	results["ray"] = _ray(false)
	results["shark"] = _shark()
	results["bakes"] = _bakes()
	results["sea_hare"] = await _sea_hare(false)
	if record:
		var out := FileAccess.open(ProjectSettings.globalize_path(BASELINE), FileAccess.WRITE)
		out.store_string(JSON.stringify(results, "\t", true, true))
		out.close()
		print("rig_rest_probe: baseline recorded")
		get_tree().quit(0)
		return
	print("rig off reads as recorded:")
	var want: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE)) if FileAccess.file_exists(BASELINE) else {}
	check(not want.is_empty(), "the baseline exists (%s)" % BASELINE)
	for key: String in results:
		var tolerance := 1e-4 if key == "bakes" else 1e-6
		var gap := _gap(results[key], want.get(key, []))
		check(gap[0] <= tolerance, "%s: identical to the code before this track (%d values, worst gap %.7f)" % [key, gap[1], gap[0]])
	if Gait.new().get("rig_bell_flap") != null:
		await _rig_on(results)
	print("rig_rest_probe: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


## [worst difference, values compared] between two nested arrays of numbers (INF when the shapes differ).
func _gap(a: Variant, b: Variant) -> Array:
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return [INF, 0]
		var worst := 0.0
		var count := 0
		for i in (a as Array).size():
			var inner := _gap(a[i], b[i])
			worst = maxf(worst, inner[0])
			count += inner[1]
		return [worst, count]
	if (a is float or a is int) and (b is float or b is int):
		return [absf(float(a) - float(b)), 1]
	return [INF, 0]


## A gait for `fish_class` with `field` set to `on` (when the field exists: recording runs on the code before it).
func _gait(fish_class: FishCharacter.FishClass, field: String, on: bool) -> Gait:
	var gait := GaitSettings.default_for(fish_class)
	if gait.get(field) != null:
		gait.set(field, on)
	return gait


# --- The jelly's bell -------------------------------------------------------------------------------------------------

## 12 s of a jelly model under a scripted state: strides with the bell leaning, a free beat (bell_lean -1), no gait at
## all, strides again. Every 4th frame, the bell's six uniforms as its first pulsing shader has them.
func _jelly(on: bool) -> Array:
	var model := FishModel.build(FishCharacter.FishClass.DRIFTER, 0)
	add_child(model)
	var gait := _gait(FishCharacter.FishClass.DRIFTER, "rig_bell_flap", on)
	var s := SwimState.new()
	var rows: Array = []
	for f in 720:
		var t := f * DT
		s.gait = null if f >= 480 and f < 600 else gait
		s.bell_lean = -1.0 if f >= 240 and f < 480 else 0.6
		s.speed = 3.0 + 5.0 * sin(t)
		s.velocity = Vector3(0.0, 0.0, -s.speed)
		var beat := int(t / 0.5)
		s.stride_phase = fmod(t, 0.5) if beat % 3 != 2 else -1.0
		s.stride_peak = 0.28
		s.stride_fade = 0.48
		model.react(DT, s)
		if f % 4 == 0:
			var m: ShaderMaterial = model._bell_pulses[0]
			var row: Array = []
			for p: String in ["bell_crown", "bell_margin", "bell_ripple", "bell_ripple_phase", "bell_squeeze", "bell_flatten"]:
				row.append(float(m.get_shader_parameter(p)))
			rows.append(row)
	model.queue_free()
	return rows


# --- The ray ----------------------------------------------------------------------------------------------------------

## 10 s of a ray model turning, striding and touching down, its fin pivots swept as a controller would. Every 4th
## frame: its bank, the skin's flap/sweep/ripple uniforms, the whip's bends and its basis.
func _ray(on: bool, gait_in: Gait = null) -> Array:
	var model := FishModel.build(FishCharacter.FishClass.GLIDER, 0)
	add_child(model)
	var gait := gait_in if gait_in != null else _gait(FishCharacter.FishClass.GLIDER, "procedural_rig", on)
	var s := SwimState.new()
	s.gait = gait
	var rows: Array = []
	for f in 600:
		var t := f * DT
		var yaw_rate := 1.2 * sin(t * 0.7)
		model.rotation.y += yaw_rate * DT
		s.speed = 8.0 + 4.0 * sin(t * 0.5)
		s.velocity = model.global_basis * Vector3(0.6 * sin(t), 0.0, -s.speed)
		s.spin = Vector3(0.0, yaw_rate, 0.0)
		s.grounded = f >= 420 and f < 480
		var beat := fmod(t, 0.7)
		s.stride_power = clampf(sin(beat / 0.7 * PI), 0.0, 1.0) if int(t / 0.7) % 2 == 0 else 0.0
		s.stride_dir = Vector2(sin(t * 1.3), 0.3 * cos(t))
		model.fin_left.rotation = Vector3(0.0, 0.3 * sin(t), 0.2 * sin(2.0 * t))
		model.fin_right.rotation = Vector3(0.0, -0.3 * sin(t), -0.2 * sin(2.0 * t))
		model.tail.rotation = Vector3(0.1 * sin(t * 2.0), 0.3 * sin(t * 3.0), 0.0)
		model.react(DT, s)
		if f % 4 == 0:
			var row: Array = [model.rotation.z]
			for p: String in ["flap_left", "flap_right", "sweep_left", "sweep_right", "ripple", "ripple_bias", "phase"]:
				row.append(float(model._skin.get_shader_parameter(p)))
			var yaw: Vector4 = model._tail_skin.get_shader_parameter("bend_yaw")
			var pitch: Vector4 = model._tail_skin.get_shader_parameter("bend_pitch")
			row.append_array([yaw.x, yaw.y, yaw.z, yaw.w, pitch.x, pitch.y, pitch.z, pitch.w])
			var e := model._whip.basis.get_euler()
			row.append_array([e.x, e.y, e.z])
			rows.append(row)
	model.queue_free()
	return rows


# --- The shark's fins -------------------------------------------------------------------------------------------------

## 4 s of a shark (rig off) under a random tail swing: every 8th frame, every mesh part's bounds centre in the model's
## space (sorted, so moving a part to another parent doesn't reorder them) and the tail pivot's place.
func _shark() -> Array:
	var model := FishModel.build(FishCharacter.FishClass.HUNTER, 0)
	add_child(model)
	var s := SwimState.new()
	s.gait = GaitSettings.default_for(FishCharacter.FishClass.HUNTER)
	s.speed = 10.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rows: Array = []
	for f in 240:
		model.tail.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.6, 0.6), 0.0)
		model.react(DT, s)
		if f % 8 == 0:
			var centres: Array = []
			for node in model.find_children("*", "MeshInstance3D", true, false):
				var part := node as MeshInstance3D
				var c := (_in_model(part, model) * part.get_aabb()).get_center()
				centres.append([c.x, c.y, c.z])
			centres.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2] if a[2] != b[2] else a[1] < b[1])
			var row: Array = []
			for c: Array in centres:
				row.append_array(c)
			row.append_array([model.tail.position.x, model.tail.position.y, model.tail.position.z])
			rows.append(row)
	model.queue_free()
	return rows


static func _in_model(part: Node3D, model: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var node: Node = part
	while node != model and node != null:
		if node is Node3D:
			xform = (node as Node3D).transform * xform
		node = node.get_parent()
	return xform


# --- School bakes -----------------------------------------------------------------------------------------------------

## Per baked class and pose: vertex count, the vertices' sum and the bounds (order-free, so a part moved to another
## parent reads the same).
func _bakes() -> Array:
	var rows: Array = []
	for fish_class: FishCharacter.FishClass in BAKED:
		for mesh: Mesh in SchoolLook.meshes(fish_class):
			rows.append(_mesh_print(mesh))
	return rows


static func _mesh_print(mesh: Mesh) -> Array:
	var count := 0
	var total := Vector3.ZERO
	for surface in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		count += vertices.size()
		for v in vertices:
			total += v
	var box := mesh.get_aabb()
	return [count, total.x, total.y, total.z, box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z]


# --- The sea hare in a game -------------------------------------------------------------------------------------------

var _main: Node
var _fish: FishController


## A game with the player a sea hare, striding side to side with the throttle held for 4 s: every 2nd frame its fin
## pivots' roll, its first flap's hinge uniform and the body wave's stride.
func _sea_hare(on: bool) -> Array:
	if _main != null:
		_main.queue_free()
		await get_tree().process_frame
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_main.set_environment("Ocean")
	var panel: Node = _main.get_node("DebugPanel")
	panel.load_mode_preset(_main.NATURE_PRESET)
	_fish = _main.get_node("Fish")
	var input := FishInput.new()
	_fish.controls = input
	var gait := GaitSettings.shared().for_class(FishCharacter.FishClass.ALCHEMIST)
	if gait.get("rig_bell_flap") != null:
		gait.set("rig_bell_flap", on)
	await get_tree().physics_frame
	_fish.set_look(FishCharacter.FishClass.ALCHEMIST, 0)
	_fish.request_reset()
	for i in 20:
		await get_tree().physics_frame
	var peak_frames := maxi(roundi(_fish.swishy.peak_time() * 60.0), 1)
	var rows: Array = []
	var flap: Node3D = _fish._visual._flaps[0]
	var hinge := (flap.get_child(0) as GeometryInstance3D).material_override as ShaderMaterial
	for f in 240:
		input.forward = 1.0
		input.stick = Vector2.RIGHT * (1.0 if floori(float(f) / peak_frames) % 2 == 0 else -1.0)
		await get_tree().process_frame
		if f % 2 == 0:
			var waves: ShaderMaterial = _fish._visual._body_waves[0]
			rows.append([_fish._visual.fin_left.rotation.z, _fish._visual.fin_right.rotation.z,
					float(hinge.get_shader_parameter("hinge_roll")), float(waves.get_shader_parameter("stride"))])
	input.clear()
	if gait.get("rig_bell_flap") != null:
		gait.set("rig_bell_flap", false)
	return rows


# --- Rig on -----------------------------------------------------------------------------------------------------------

func _rig_on(off: Dictionary) -> void:
	print("the bell layer (rig_bell_flap on):")
	var defaults := true
	for fc: FishCharacter.FishClass in FishCharacter.FishClass.values():
		var g := GaitSettings.default_for(fc)
		defaults = defaults and not g.rig_bell_flap and not g.rig_school_bake and not g.procedural_rig
	check(defaults, "rig_bell_flap, rig_school_bake and procedural_rig are off for every class by default")
	var gap := _gap(_jelly(true), off["jelly"])
	check(gap[0] <= 1e-6, "the bell's uniforms are the very same as the model's own step (worst gap %.7f; switching to no gait and back included)" % gap[0])
	_flap_layer()
	print("the flap layer in a game:")
	var rows: Array = await _sea_hare(true)
	var most := 0.0
	var mirrored := true
	var hinged := true
	for row: Array in rows:
		most = maxf(most, row[0])
		mirrored = mirrored and is_equal_approx(row[1], -row[0])
		hinged = hinged and absf(row[2] - clampf(row[0], -0.12, 1.2)) < 1e-5
	check(most > 0.5 and mirrored and hinged, "the sea hare's flaps beat with its strides from the layer (most %.3f rad), mirrored, the hinges following" % most)
	var near := _gap(rows, off["sea_hare"])
	check(near[0] < 0.3, "and look like the controller's beat (worst gap %.3f rad: the idle wave's own clock)" % near[0])
	_ray_rig()
	_mantis_rig()
	_dorsal_rider()
	_school_bakes()


## The shark's first dorsal on its rider: with the rig on, the head's counter-bend carries it whole, its root on the body.
func _dorsal_rider() -> void:
	print("the shark's dorsal rider:")
	var model := FishModel.build(FishCharacter.FishClass.HUNTER, 0)
	add_child(model)
	var rider: Node3D = model._riders[0] if not model._riders.is_empty() else null
	check(rider != null and rider.get_child_count() == 1 and not model.is_bent(rider.get_child(0) as GeometryInstance3D),
			"the first dorsal rides a rider and is not itself bent (stiff)")
	if rider == null:
		return
	var gait := GaitSettings.default_for(FishCharacter.FishClass.HUNTER)
	gait.procedural_rig = true
	var s := SwimState.new()
	s.gait = gait
	s.speed = 15.0
	s.speed_frac = 15.0 / 23.0
	s.effort = 1.0
	s.spin = Vector3(0.0, 1.5, 0.0)
	var turned := 0.0
	var on_body := 0.0
	for f in 120:
		model.react(DT, s)
		turned = maxf(turned, rider.transform.basis.get_euler().length())
		on_body = maxf(on_body, rider.position.distance_to(model.bend_point(model._rider_rest[0].origin)))
	check(turned > 0.01 and on_body < 1e-5, "the head's counter-bend turns it whole (%.3f rad), its root staying on the body" % turned)
	model.queue_free()


## School bakes from the rig's wave: rig_school_poses meshes for a rigged class, still three for others and the Horde.
func _school_bakes() -> void:
	print("school bakes at the rig's phases:")
	var gait := GaitSettings.shared().for_class(FishCharacter.FishClass.HUNTER)
	var classic := SchoolLook.meshes(FishCharacter.FishClass.HUNTER)
	check(classic.size() == SchoolLook.POSES.size() and not SchoolLook.is_wave_bake(FishCharacter.FishClass.HUNTER), "off: the three tail poses")
	gait.rig_school_bake = true
	var waved := SchoolLook.meshes(FishCharacter.FishClass.HUNTER)
	var tips: Array[float] = []
	for mesh: Mesh in waved:
		var mean: Array = _mesh_print(mesh)
		tips.append(float(mean[1]) / maxf(float(mean[0]), 1.0))
	var spread: float = tips.max() - tips.min()
	check(waved.size() == gait.rig_school_poses and SchoolLook.is_wave_bake(FishCharacter.FishClass.HUNTER),
			"on: one mesh per phase of the wave (%d)" % waved.size())
	check(spread > 0.005, "the phases differ: the body swings across the beat (vertices' mean x moves %.4f m)" % spread)
	check(SchoolLook.detail_meshes(FishCharacter.FishClass.HUNTER, 0.0) == classic, "the Horde's detail meshes keep the three tail poses")
	check(SchoolLook.wave_pose(0.0, 5) == 0 and SchoolLook.wave_pose(TAU * 0.41, 5) == 2 and SchoolLook.wave_pose(TAU * 0.95, 5) == 0,
			"a tail phase picks the nearest baked phase")
	var jelly := GaitSettings.shared().for_class(FishCharacter.FishClass.DRIFTER)
	jelly.rig_school_bake = true
	check(SchoolLook.meshes(FishCharacter.FishClass.DRIFTER).size() == SchoolLook.POSES.size() and not SchoolLook.is_wave_bake(FishCharacter.FishClass.DRIFTER),
			"a class with no rig keeps the three poses")
	jelly.rig_school_bake = false
	gait.rig_school_bake = false
	check(SchoolLook.meshes(FishCharacter.FishClass.HUNTER) == classic, "switching it off gives the old bakes back")


## The flap layer on a bare sea hare against the controller's formulas with the clock in place of Time: the stride
## beat, the idle wave, the reverse flutter; the pivots take it and the flaps' hinges follow; no wall clock.
func _flap_layer() -> void:
	print("the flap layer on a model:")
	var a := _flap_run(false)
	var b := _flap_run(true)
	check(_gap(a[0], a[1])[0] < 2e-3, "it is the controller's beat and flutter on the rig's clocks (worst gap %.5f rad)" % _gap(a[0], a[1])[0])
	check(_gap(a[0], b[0])[0] == 0.0, "the same with the wall clock held up between frames: no Time in it")
	var span := 0.0
	for v: float in a[0]:
		span = maxf(span, absf(v))
	check(span > 0.6, "it beats and flutters (%.3f rad at most)" % span)


## [the left pivot's roll each frame, the controller formula's] over 6 s: strides, then idle, then swimming backwards.
func _flap_run(stall: bool) -> Array:
	var model := FishModel.build(FishCharacter.FishClass.ALCHEMIST, 0)
	add_child(model)
	var gait := GaitSettings.default_for(FishCharacter.FishClass.ALCHEMIST)
	gait.rig_bell_flap = true
	var s := SwimState.new()
	s.gait = gait
	var got: Array = []
	var want: Array = []
	var phase := 0.0
	var flap := 0.0
	var hinge_ok := true
	for f in 360:
		var t := (f + 1) * DT
		s.effort = 0.5 + 0.5 * sin(t)
		s.stride_power = clampf(sin(fmod(t, 0.8) / 0.8 * PI), 0.0, 1.0) if f < 160 else 0.0
		s.reverse = 1.0 if f >= 260 else 0.0
		model.react(DT, s)
		if stall:
			OS.delay_msec(1)
		# FishController._process's formulas, with t for Time.get_ticks_msec() / 1000.
		phase += DT * lerpf(4.0, 18.0, s.effort)
		var flutter := sin(t * 50.0) * 0.7 * s.reverse
		flap = lerpf(flap, 0.9 * s.stride_power + sin(phase * 0.35) * 0.12, 1.0 - exp(-12.0 * DT))
		got.append(model.fin_left.rotation.z)
		want.append(flutter + flap)
		var hinge: Node3D = model._flaps[0]
		var side := signf(hinge.position.x)
		hinge_ok = hinge_ok and is_equal_approx(hinge.rotation.z, clampf(-side * (model.fin_left if side < 0.0 else model.fin_right).rotation.z, -FishModel.FLAP_CLOSE, 1.2) * -side)
	model.queue_free()
	check(hinge_ok and is_equal_approx(model.fin_right.rotation.z, -model.fin_left.rotation.z), "the pivots mirror and the flaps' hinges follow them")
	return [got, want]


## The Gliders' rig: the body banks into a turn and lies level when grounded, the wings take the pose, nothing NaN.
func _ray_rig() -> void:
	print("the ray's rig:")
	var gait := GaitSettings.default_for(FishCharacter.FishClass.GLIDER)
	gait.procedural_rig = true
	var rows := _ray(true, gait)
	var finite := true
	var bank := 0.0
	var flaps := 0.0
	for row: Array in rows:
		for v: float in row:
			finite = finite and is_finite(v)
		bank = maxf(bank, absf(row[0]))
		flaps = maxf(flaps, absf(row[1]))
	check(finite, "rig on, 10 s of turns, strides and a touchdown: nothing NaN")
	check(bank > 0.2 and flaps > 0.2, "it banks (%.2f rad) and beats its wings (%.2f) from the rig" % [bank, flaps])
	var grounded: Array = rows[115]  # frame 460, on the surface since 420
	check(absf(grounded[0]) < 0.05, "on the surface it lies level (%.3f rad)" % grounded[0])


## The Brawlers' rig: the abdomen flexes up and down, the claws barely move.
func _mantis_rig() -> void:
	print("the mantis's rig:")
	var model := FishModel.build(FishCharacter.FishClass.BRAWLER, 0)
	add_child(model)
	var gait := GaitSettings.default_for(FishCharacter.FishClass.BRAWLER)
	gait.procedural_rig = true
	var s := SwimState.new()
	s.gait = gait
	s.speed = 10.0
	s.speed_frac = 10.0 / 23.0
	s.effort = 0.8
	var pitch := 0.0
	var yaw := 0.0
	var claws := 0.0
	for f in 240:
		model.react(DT, s)
		pitch = maxf(pitch, absf(model.rig.pose.spine_pitch()))
		yaw = maxf(yaw, absf(model.rig.pose.spine_yaw()))
		claws = maxf(claws, absf(model.rig.pose.fin_flap.x) + absf(model.rig.pose.fin_sweep.x))
	check(model.rig.engaged and pitch > 0.1 and yaw < 1e-4, "the abdomen flexes up and down, not sideways (pitch %.3f, yaw %.5f rad)" % [pitch, yaw])
	check(claws < 0.05, "swimming straight the claws hold still (%.4f rad)" % claws)
	model.queue_free()
