## What Stinks? Phase 5, the Gulper Mother form (forms/gulper_mother.gd, gulper_model/rig/jaw.gd): the
## dress hook (the eel's body replaces the shark's, once, with its mouth wired to the bite), the model
## against the hitbox, the swim reading from the controller (the spine trails a turn and the wave grows
## with speed), the bite's cone (wide, deep, the mouth in front, the pouch gaping on the wind-up) and
## the camera framing, at sizes 0.5, 1 and 3, then through a real match.
## Run headless: Godot_console.exe --headless --path . res://tests/gulper_form_probe.tscn
##   --shots=DIR (needs a window) saves a side, front and mid-turn shot per size and the bite's open mouth.
extends Node

const KEY := "gulper_mother"
const SIZES := [0.5, 1.0, 3.0]

var main: Node
var fish: FishController
var camera: Camera3D
var checks := 0
var failures := 0
var shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
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
	await _in_match()
	print("gulper_form_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _place() -> void:
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 25.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


func _sheet() -> void:
	print("sheet:")
	var form := HunterForms.sheet(KEY)
	_check(HunterForms.is_ready(KEY) and bool(form["ready"]), "the Gulper Mother reports ready")
	_check(HunterForms.ready_keys().has(KEY), "and the card would list it")
	_check(str(form["name"]) == "Gulper Mother" and form["class"] == FishCharacter.FishClass.MONSTER, "its sheet: name and class")
	var shark := HunterForm.SHARK
	_check(float(form["bite_reach_m"]) > float(shark["bite_reach_m"]) and float(form["bite_radius_m"]) > float(shark["bite_radius_m"]), "the cone is deeper and wider than the shark's chomp")
	_check(float(form["bite_wind"]) > float(shark["bite_wind"]) and float(form["capacity"]) > float(shark["capacity"]), "it opens slower and takes more")
	_check(float(form["bite_radius_m"]) / float(form["bite_reach_m"]) > 0.5, "a half angle past 26 degrees at the far end (radius over reach %.2f)" % (float(form["bite_radius_m"]) / float(form["bite_reach_m"])))


func _model_extent(model: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	var inverse := fish.global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var part := (inverse * mesh.global_transform) * mesh.mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box.size


func _at(s: float) -> void:
	var form := HunterForm.sheet(KEY)
	var tag := "x%.1f" % s
	print("size %s:" % tag)
	var size := HunterSize.shared()
	size.size_mult = s
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	size.apply(fish, form)
	HunterForms.dress(fish, KEY)
	await _frames(3)
	_place()
	await _frames(3)
	var model: FishModel = fish._visual
	var rig: Node3D = model.get_meta("gulper_rig", null)
	_check(rig != null and rig.get_parent() == model, "%s: the Gulper's rig is on the model" % tag)
	if rig == null:
		return
	_check(model.get_meta("hunter_jaw") == rig.jaw, "%s: the bite's jaw is the Gulper's" % tag)
	# Dressing again (the next round on the same model) adds nothing.
	HunterForms.dress(fish, KEY)
	var rigs := model.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Gulper") and n != null)
	_check(rigs.size() == 1, "%s: dressing twice leaves one rig (%d)" % [tag, rigs.size()])
	var hidden := true
	for child in model.get_children():
		if child is Node3D and child != rig and (child as Node3D).visible:
			hidden = false
	_check(hidden, "%s: the shark's own parts are hidden" % tag)
	# Body and hitbox.
	var scale := HunterForm.body_scale(form) * s
	_check(is_equal_approx(fish.body_scale, scale) and absf(fish.hitbox_length - float(form["length_m"]) * s) < 0.01, "%s: body scale %.2f, hitbox %.2f m" % [tag, fish.body_scale, fish.hitbox_length])
	var extent := _model_extent(model)
	extent.z = (rig.get_node("GulperMesh") as MeshInstance3D).mesh.get_aabb().size.z * model.scale.z * rig.scale.z  # the rest mesh is drawn from the spine, so only its own length counts
	print("      model extent %s m for a hitbox of %.2f m long" % [extent, fish.hitbox_length])
	_check(extent.z > fish.hitbox_length * 0.7 and extent.z < fish.hitbox_length * 1.5, "%s: model length %.2f m is about the hitbox's" % [tag, extent.z])
	_check(extent.x < fish.hitbox_width * 1.6 and extent.y < fish.hitbox_height * 1.8, "%s: its girth sits near the box (%.2f x %.2f m for %.2f x %.2f)" % [tag, extent.x, extent.y, fish.hitbox_width, fish.hitbox_height])
	# Rest: a straight spine, the head at the front of the box.
	var spread := _tail_offset(rig)
	_check(spread.length() < 0.02, "%s: straight at rest (tail off the axis by %.3f of its length)" % [tag, spread.length()])
	_check(is_equal_approx(rig.rig.points[0].z, rig.head_z) and rig.head_z < 0.0, "%s: the head is the box's front" % tag)
	# Swim: thrust, then turn. The body trails the turn; the wave grows with speed.
	var input := FishInput.new()
	fish.controls = input
	input.forward = 1.0
	input.boost = true
	fish.boost_amount = 100.0
	var tps := int(Engine.physics_ticks_per_second)
	await _frames(tps)
	var idle_wave := _wave(rig)
	var peak := 0.0
	for i in tps * 3:
		await get_tree().physics_frame
		peak = maxf(peak, fish.linear_velocity.length())
	_check(rig.speed_frac > 0.3, "%s: the swim reads speed (%.2f of full at %.1f m/s)" % [tag, rig.speed_frac, peak])
	_check(_wave(rig) > rig.wave_idle * 0.9 * 2.0 and _wave(rig) >= idle_wave, "%s: the wave grows with speed (%.2f, was %.2f at rest, idle size %.2f)" % [tag, _wave(rig), idle_wave, rig.wave_idle * 0.9])
	input.boost = false
	input.forward = 0.5
	input.stick = Vector2(1.0, 0.0)
	var bent := 0.0
	var side := 0.0
	for i in tps * 2:
		await get_tree().physics_frame
		var off := _tail_offset(rig)
		if off.length() > bent:
			bent = off.length()
			side = off.x
	print("      tail trailed %.2f of its length (x %.2f) in the turn" % [bent, side])
	_check(bent > 0.04, "%s: the body trails a turn (tail %.2f of its length off the axis)" % [tag, bent])
	if shots_dir != "":
		await _shot("turn", s)
	input.stick = Vector2.ZERO
	input.forward = 0.0
	fish.controls = null
	await _frames(tps)
	await _bite(form, s, tag)
	# Camera framing.
	_place()
	fish.linear_velocity = Vector3.ZERO
	var zoom := size.frame(camera, fish, form)
	await _frames(1)
	if camera.has_method("snap"):
		camera.call("snap")
	await get_tree().create_timer(1.5).timeout
	var gap := camera.global_position.distance_to(fish.global_position)
	var share := _screen_share()
	print("      camera: %.2f m away (%.2f body lengths), zoom %.2f, the body's box spans %.0f%% of the screen width" % [gap, gap / fish.hitbox_length, zoom, share * 100.0])
	_check(share > 0.05 and share < 0.95, "%s: the body fills a fair share of the screen (%.0f%%)" % [tag, share * 100.0])
	if shots_dir != "":
		await _shot("cam", s)
		await _shot("side", s)
		await _shot("front", s)


## How far the tail sits off the straight axis, over the body's length.
func _tail_offset(rig: Node3D) -> Vector3:
	var tail: Vector3 = rig.rig.points[SpineRig.SPINE_N - 1]
	var head: Vector3 = rig.rig.points[0]
	var off := tail - head
	off.z = 0.0
	return off / rig.rig.length


func _wave(rig: Node3D) -> float:
	var amp: Vector4 = rig.skin.get_shader_parameter("spine_wave")
	return amp.x / rig.k


func _screen_share() -> float:
	var low := INF
	var high := -INF
	var half := Vector3(fish.hitbox_width, fish.hitbox_height, fish.hitbox_length) * 0.5
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				var corner := fish.global_transform * (half * Vector3(x, y, z))
				if camera.is_position_behind(corner):
					continue
				var px := camera.unproject_position(corner).x
				low = minf(low, px)
				high = maxf(high, px)
	var width := float(get_viewport().get_visible_rect().size.x)
	return (high - low) / width if high > low else 0.0


func _bite(form: Dictionary, s: float, tag: String) -> void:
	var bite := HunterBite.new()
	bite.name = "HunterBite"  # as the match names it (GulperRig finds it by name)
	fish.add_child(bite)
	bite.setup(fish, form)
	var landed: Array = []
	bite.chomped.connect(func(mouth: Vector3, reach: float, radius: float, capacity: int) -> void: landed.append([mouth, reach, radius, capacity]))
	_place()
	fish.controls = FishInput.new()
	await _frames(2)
	var rig: Node3D = (fish._visual as Node3D).get_meta("gulper_rig")
	var mouth := bite.mouth_point()
	var forward := -fish.global_basis.z
	var front := fish.global_position + forward * fish.hitbox_length * 0.5
	_check(mouth.distance_to(front) < fish.hitbox_length * 0.2, "%s: the bite's mouth is at the front of the body (%.2f m off the nose)" % [tag, mouth.distance_to(front)])
	var gape_rest: float = rig.gape
	var input: FishInput = fish.controls
	input.jump = true
	var peak_open := 0.0
	var peak_gape := 0.0
	var emitted := false
	var shot := false
	for i in int(Engine.physics_ticks_per_second) * 5:
		await get_tree().physics_frame
		if i == 6:
			input.jump = false
		peak_open = maxf(peak_open, bite.bite.open)
		peak_gape = maxf(peak_gape, rig.gape)
		emitted = emitted or (rig._suction as CPUParticles3D).emitting
		if shots_dir != "" and not shot and bite.bite.phase == ChompKit.Phase.HOLD and bite.bite.t > 0.05:
			shot = true
			await _shot("bite", s)
		if not landed.is_empty() and not bite.busy():
			break
	print("      bite: %d landed, jaw opened to %.2f, the pouch gaped to %.2f (rest %.2f)" % [landed.size(), peak_open, peak_gape, gape_rest])
	_check(landed.size() == 1, "%s: one bite lands from one press" % tag)
	_check(peak_gape > gape_rest + 0.8, "%s: the pouch gapes on the wind-up (%.2f from %.2f)" % [tag, peak_gape, gape_rest])
	_check(emitted, "%s: the suction streams in while it is open" % tag)
	if not landed.is_empty():
		var hit: Array = landed[0]
		_check(absf(float(hit[1]) - float(form["bite_reach_m"]) * s) < 0.01 and absf(float(hit[2]) - float(form["bite_radius_m"]) * s) < 0.01, "%s: reach %.2f m, radius %.2f m" % [tag, hit[1], hit[2]])
	# The cone: wide at the far end, nothing behind the mouth.
	mouth = bite.mouth_point()
	forward = -fish.global_basis.z
	var up := fish.global_basis.y
	var reach := bite.reach()
	var radius := bite.radius()
	_check(bite.in_bite(mouth + forward * reach * 0.9 + up * radius * 0.8), "%s: the far end takes fish most of the radius off the nose" % tag)
	_check(not bite.in_bite(mouth + forward * reach * 0.1 + up * radius * 0.8), "%s: and the near end is narrow" % tag)
	_check(not bite.in_bite(mouth - forward * reach * 0.5) and not bite.in_bite(mouth + forward * reach * 1.2), "%s: nothing behind the mouth or past the reach" % tag)
	bite.queue_free()
	fish.controls = null
	await _frames(3)
	await get_tree().create_timer(1.0).timeout


## A shot from a free camera: `view` "side", "front", "turn"/"bite" (three quarter), or the follow camera's own ("cam").
func _shot(view: String, s: float) -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var name := "%s/gulper_x%s_%s.png" % [shots_dir, str(s).replace(".", "_"), view]
	if view == "cam":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(name)
		return
	var free := Camera3D.new()
	free.far = 2000.0
	var lamp := OmniLight3D.new()  # the deep is dark: light the body for the shot
	lamp.omni_range = 400.0
	lamp.light_energy = 6.0
	free.add_child(lamp)
	main.add_child(free)
	var length := fish.hitbox_length
	var dirs := {"side": Vector3(-1.0, 0.15, 0.0), "front": Vector3(-0.35, 0.2, -1.0), "turn": Vector3(-0.5, 0.9, 0.7), "bite": Vector3(-1.0, 0.1, -0.9)}
	var middle := fish.global_position
	free.global_position = middle + fish.global_basis * (Vector3(dirs[view]).normalized() * length * (1.5 if view == "bite" else 1.0))
	free.look_at(middle, Vector3.UP)
	free.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(name)
	camera.make_current()
	free.queue_free()


## Through Main: the form picked in the settings is what the local Hunter wears, rig and all.
func _in_match() -> void:
	print("in a match:")
	var settings := WhatStinksSettings.shared()
	var size := HunterSize.shared()
	settings.hide_time = 1.0
	settings.round_time = 60.0
	settings.arena_radius = 90.0
	settings.school_count = 2
	settings.school_min = 8
	settings.school_max = 10
	settings.min_players = 3
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	for round_no in 2:  # the second round dresses the same model again
		main.set_mode(main.WHAT_STINKS)  # entering a mode restores its saved tuning, so the picks go in after
		await _frames(5)
		settings.form = KEY
		size.size_mult = 1.0
		main._close_match_card()
		main._apply_mode()
		await _frames(3)
		var card: MatchCard = main._match_card
		var titles: Array = card.choices.map(func(c: Dictionary) -> String: return str(c.title))
		var shown: Array = card.choices[titles.find("Hunter")].options
		_check(shown.has("Gulper Mother"), "round %d: the match card offers the Gulper Mother (%s)" % [round_no, str(shown)])
		main.play_match()
		await _frames(8)
		var game: WhatStinksMatch = main.what_stinks
		_check(game != null and game.hunters == [fish], "round %d: a match with the local fish as Hunter" % round_no)
		if game == null:
			continue
		var model: FishModel = fish._visual
		_check(model.has_meta("gulper_rig") and fish.character == FishCharacter.FishClass.MONSTER, "round %d: the Hunter wears the Gulper's rig" % round_no)
		var bite: HunterBite = game.bites[fish]
		_check(str(bite.form["key"]) == KEY and bite._jaw == model.get_meta("hunter_jaw"), "round %d: the bite is the Gulper's, with its mouth (reach %.1f m)" % [round_no, bite.reach()])
		_check(bite.mouth_point().distance_to(fish.global_position) > fish.hitbox_length * 0.2, "round %d: and bites from the front, not the middle" % round_no)
		main.set_mode(main.FREE_PLAY)
		await _frames(5)
