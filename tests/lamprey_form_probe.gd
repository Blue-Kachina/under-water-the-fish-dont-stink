## What Stinks? Phase 5, the Lamprey Queen form (forms/lamprey_queen.gd, lamprey_rig.gd, lamprey_jaw.gd):
## the form dressed on a plain controller at sizes 0.5, 1 and 3: the body (a LampreyRig on the visual, the shark
## hidden), its length against the hitbox, the spine following the head through a turn, the swim wave, the jaw
## gaping from the bite, the Corkscrew latch's cone (wide, reach, capacity, wind-up), dress safe to run twice and
## rebuilt on a size change, and the card (ready, listed, plays as itself).
## Run headless: Godot_console.exe --headless --path . res://tests/lamprey_form_probe.tscn
##   --shots=DIR (needs a window) saves a side, a front and a camera shot per size.
extends Node

const KEY := "lamprey_queen"

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
		await get_tree().process_frame  # the body is posed in _process


func _place() -> void:
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 25.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


func _run() -> void:
	await _frames(5)
	main.set_environment("Ocean")
	await _frames(5)
	_card()
	for s: float in [0.5, 1.0, 3.0]:
		await _at(s)
	print("lamprey_form_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _card() -> void:
	print("card:")
	var sheet := HunterForms.sheet(KEY)
	_check(HunterForms.is_ready(KEY) and HunterForms.ready_keys().has(KEY), "the Queen is ready and on the card")
	_check(HunterForms.playable(KEY) == KEY, "a Queen pick plays as the Queen")
	_check(sheet["name"] == "Lamprey Queen" and sheet["class"] == FishCharacter.FishClass.MONSTER, "its sheet: %s, class MONSTER" % sheet["name"])
	var shark := HunterForm.SHARK
	var cone_king := rad_to_deg(atan2(float(sheet["bite_radius_m"]), float(sheet["bite_reach_m"])))
	var cone_shark := rad_to_deg(atan2(float(shark["bite_radius_m"]), float(shark["bite_reach_m"])))
	print("      cone half angle %.1f deg (shark %.1f), reach %.1f m, capacity %d, wind %.2f s" % [cone_king, cone_shark, sheet["bite_reach_m"], sheet["capacity"], sheet["bite_wind"]])
	_check(cone_king < cone_shark and float(sheet["capacity"]) <= 1.0 and float(sheet["bite_reach_m"]) < float(shark["bite_reach_m"]), "the latch is a narrow, short cone for one target (narrower than the shark's)")
	_check(float(sheet["bite_wind"]) > float(shark["bite_wind"]) and float(sheet["bite_every"]) > float(shark["bite_every"]), "it is slower to wind up and to come back than the shark")
	for id: String in ["sound_chomp", "sound_arrive", "sound_miss"]:
		_check(SoundCatalog.info(str(sheet[id])).size() > 0, "%s: %s is a catalogue id" % [id, sheet[id]])


func _dress(s: float) -> Dictionary:
	var form := HunterForm.sheet(KEY)
	var size := HunterSize.shared()
	size.size_mult = s
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	size.apply(fish, form)
	HunterForms.dress(fish, KEY)
	return form


func _at(s: float) -> void:
	var tag := "lamprey x%.1f" % s
	print("%s:" % tag)
	var form := _dress(s)
	await _frames(3)
	_place()
	await _frames(3)
	var visual: Node3D = fish._visual
	var body := visual.get_node_or_null("LampreyRig") as Node3D
	_check(body != null, "%s: a LampreyRig on the visual" % tag)
	if body == null:
		return
	_check(absf(fish.hitbox_length - 14.0 * s) < 0.01, "%s: hitbox %.2f m" % [tag, fish.hitbox_length])
	_check(absf(float(body.get("length")) - fish.hitbox_length) < 0.01, "%s: the body is %.2f m, the hitbox's length" % [tag, body.get("length")])
	var shark_hidden := true
	for node in visual.get_children():
		if node != body and node is Node3D and (node as Node3D).visible:
			shark_hidden = false
	_check(shark_hidden, "%s: the shark's parts are hidden" % tag)
	_check(visual.has_meta("hunter_jaw") and visual.get_meta("hunter_jaw").get_script().resource_path.ends_with("lamprey_jaw.gd"), "%s: the bite gets the Queen's jaw" % tag)
	# The body mesh is in rest pose at the world origin (the shader bends it onto the spine), so its size is its own box, not placed on the fish.
	var extent := ((body.get("rig") as SpineRig).instances[0] as MeshInstance3D).mesh.get_aabb().size
	print("      model extent %s m for a hitbox length %.2f" % [extent, fish.hitbox_length])
	_check(extent.z > fish.hitbox_length * 0.7 and extent.z < fish.hitbox_length * 1.5, "%s: model length %.2f m is about the hitbox's" % [tag, extent.z])
	# Dress twice keeps the body; a size change builds another.
	HunterForms.dress(fish, KEY)
	_check(visual.get_node("LampreyRig") == body, "%s: dressing again keeps the body" % tag)
	# Swim and turn: the spine follows the head.
	var input := FishInput.new()
	fish.controls = input
	input.forward = 1.0
	input.boost = true
	fish.boost_amount = 100.0
	var peak := 0.0
	var tps := int(Engine.physics_ticks_per_second)
	for i in tps * 3:
		await get_tree().physics_frame
		peak = maxf(peak, fish.linear_velocity.length())
	var wave_fast := float(body.get("_wave"))
	_check(peak > 2.0, "%s: swims (%.1f m/s)" % [tag, peak])
	var rig: SpineRig = body.get("rig")
	var head := rig.points[0]
	var near := head.distance_to(fish.global_position + fish.global_basis * Vector3(0.0, 0.0, -fish.hitbox_length * 0.5))
	_check(near < 0.5 * fish.hitbox_length * 0.2 + 1.0 + peak / tps * 2.0, "%s: the spine's head is at the front of the box (%.2f m off)" % [tag, near])
	var back_len := head.distance_to(rig.points[rig.points.size() - 1])
	_check(back_len > fish.hitbox_length * 0.85, "%s: the body is laid out %.1f m behind the head going straight" % [tag, back_len])
	input.forward = 1.0
	input.stick = Vector2(1.0, 0.0)  # boost held: a circle at speed, so the body lies along a curve
	var spin := 0.0
	var tightest := INF
	for i in tps * 3:
		await get_tree().physics_frame
		spin = maxf(spin, absf(fish.angular_velocity.y))
		if i > tps:
			tightest = minf(tightest, rig.points[0].distance_to(rig.points[rig.points.size() - 1]))
	input.boost = false
	var bent := head.distance_to(rig.points[0])
	var chord := rig.points[0].distance_to(rig.points[rig.points.size() - 1])
	print("      turn: spin %.2f rad/s, chord %.1f of %.1f m" % [spin, chord, float(body.get("length"))])
	_check(spin > 0.05, "%s: turns (%.2f rad/s)" % [tag, spin])
	_check(tightest < float(body.get("length")) * 0.97, "%s: the body bends through the turn (tightest chord %.1f of %.1f)" % [tag, tightest, body.get("length")])
	_check(bent > 0.0, "%s: the head moved" % tag)
	_check(wave_fast > 0.0, "%s: the swim wave has amplitude (%.3f)" % [tag, wave_fast])
	input.stick = Vector2.ZERO
	input.forward = 0.0
	# Bite.
	_place()
	fish.angular_velocity = Vector3.ZERO
	await _frames(5)
	await _bite(form, s, tag)
	if shots_dir != "":
		await _shots(s)
	fish.controls = null
	# A size change builds it again at the new length.
	var again := s * 2.0
	HunterSize.shared().size_mult = again
	HunterSize.shared().apply(fish, form)
	HunterForms.dress(fish, KEY)
	var rebuilt := fish._visual.get_node_or_null("LampreyRig") as Node3D
	_check(rebuilt != null and absf(float(rebuilt.get("length")) - 14.0 * again) < 0.01, "%s: a size change rebuilds the body at %.1f m" % [tag, 14.0 * again])
	var count := fish._visual.find_children("LampreyRig", "", false, false).size()
	_check(count == 1, "%s: still one body (%d)" % [tag, count])


func _bite(form: Dictionary, s: float, tag: String) -> void:
	var bite := HunterBite.new()
	bite.name = "HunterBite"  # as the match names it (LampreyRig finds it by name)
	fish.add_child(bite)
	bite.setup(fish, form)
	var landed: Array = []
	bite.chomped.connect(func(mouth: Vector3, reach: float, radius: float, capacity: int) -> void:
		landed.append([mouth, reach, radius, capacity]))
	var input := FishInput.new()
	fish.controls = input
	await _frames(2)
	var mouth := bite.mouth_point()
	var head: Vector3 = (fish._visual.get_node("LampreyRig").get("rig") as SpineRig).points[0]
	_check(mouth.distance_to(head) < fish.hitbox_length * 0.1 + 0.5, "%s: the mouth is at the head (%.2f m)" % [tag, mouth.distance_to(head)])
	input.jump = true
	var skin: ShaderMaterial = fish._visual.get_node("LampreyRig").get("skin")
	var gape := 0.0
	var warned := false
	var tps := int(Engine.physics_ticks_per_second)
	for i in tps * 5:
		await get_tree().physics_frame
		if i == 6:
			input.jump = false
		gape = maxf(gape, float(skin.get_shader_parameter("disc")))
		warned = warned or float(skin.get_shader_parameter("warn")) > 0.0
		if not landed.is_empty() and not bite.busy():
			break
	_check(landed.size() == 1, "%s: one bite lands" % tag)
	_check(gape > 0.5, "%s: the disc flares wide (%.2f)" % [tag, gape])
	_check(warned, "%s: the skin warns through the wind-up" % tag)
	var rig_node := fish._visual.get_node("LampreyRig")
	_check(float(rig_node.get("latch_left")) > 0.0 or absf(float(rig_node.get("spin"))) > 0.1, "%s: a landed bite latches: she rolls (latch %.2f s left, spin %.2f rad)" % [tag, rig_node.get("latch_left"), rig_node.get("spin")])
	_check(float(skin.get_shader_parameter("disc")) < gape, "%s: the disc clamps down after the bite lands" % tag)
	if not landed.is_empty():
		var hit: Array = landed[0]
		_check(absf(float(hit[1]) - float(form["bite_reach_m"]) * s) < 0.01 and absf(float(hit[2]) - float(form["bite_radius_m"]) * s) < 0.01, "%s: reach %.2f m radius %.2f m" % [tag, hit[1], hit[2]])
		_check(int(hit[3]) == maxi(1, roundi(float(form["capacity"]) * pow(s, 1.5))), "%s: capacity %d" % [tag, hit[3]])
	var forward := -fish.global_basis.z
	var mouth_now := bite.mouth_point()
	var wide := bite.radius() * 0.9
	_check(bite.in_bite(mouth_now + forward * bite.reach() * 0.95 + fish.global_basis.x * wide), "%s: the far end takes a fish %.1f m to the side" % [tag, wide])
	_check(not bite.in_bite(mouth_now + forward * bite.reach() * 1.2), "%s: past the reach is out" % tag)
	bite.queue_free()
	await _frames(2)




func _shots(s: float) -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var tag := str(s).replace(".", "_")
	var free := Camera3D.new()
	free.far = 2000.0
	main.add_child(free)
	var length := fish.hitbox_length
	var centre := fish.global_position
	for view: Array in [["side", Vector3(-1.0, 0.15, 0.0), 1.1], ["front", Vector3(-0.5, 0.2, -1.0), 0.8], ["above", Vector3(0.0, 1.0, 0.2), 1.1]]:
		free.global_position = centre + fish.global_basis * (Vector3(view[1]).normalized() * length * float(view[2]))
		free.look_at(centre, Vector3.UP)
		free.make_current()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/lamprey_x%s_%s.png" % [shots_dir, tag, view[0]])
	camera.make_current()
	free.queue_free()
	var zoom := HunterSize.shared().frame(camera, fish, HunterForm.sheet(KEY))
	await _frames(1)
	if camera.has_method("snap"):
		camera.call("snap")
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/lamprey_x%s_cam.png" % [shots_dir, tag])
	var gap := camera.global_position.distance_to(fish.global_position)
	print("      camera zoom %.2f, %.1f m away (%.2f body lengths), height over the fish %.1f m" % [zoom, gap, gap / fish.hitbox_length, camera.global_position.y - fish.global_position.y])
