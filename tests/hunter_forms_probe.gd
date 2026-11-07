## What Stinks? Phase 5 (what_stinks.md): the Hunter form registry (HunterForms) and
## the size dial across every form that reports ready. Registry checks (all 11
## forms registered with a file of their own, defaults filled, only ready forms on
## the match card, an unready pick plays as the Drowned Shark); then per ready form
## at sizes 0.5, 1 and 3 on a plain controller: body and hitbox, model extent, swim,
## bite (reach, radius and capacity follow the size, the frustum, the cooldown) and
## camera framing; then through a real match: the form and size picked in the
## settings are what the Hunter wears, with the school alarm and camera following.
## Run headless: Godot_console.exe --headless --path . res://tests/hunter_forms_probe.tscn
##   --shots=DIR (needs a window) saves a framing and a jaw shot per form and size.
extends Node

const SIZES := [0.5, 1.0, 3.0]

var main: Node
var fish: FishController
var camera: Camera3D
var checks := 0
var failures := 0
var shots_dir := ""
var only_key := ""  # --only=KEY: just that form, then quit (for a quick shot)
var results := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
		if arg.begins_with("--only="):
			only_key = arg.trim_prefix("--only=")
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
	_registry()
	for key: String in HunterForms.ready_keys():
		if only_key != "" and key != only_key:
			continue
		results[key] = {}
		for s: float in SIZES:
			await _form_at(key, s)
		_compare(key)
	if only_key != "":
		get_tree().quit()
		return
	await _in_match()
	print("hunter_forms_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _place() -> void:
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 25.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


func _form_at(key: String, s: float) -> void:
	var form := HunterForm.sheet(key)
	var tag := "%s x%.1f" % [key, s]
	var size := HunterSize.shared()
	size.size_mult = s
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	size.apply(fish, form)
	await _frames(3)
	_place()
	await _frames(3)
	# Body and hitbox.
	var scale := HunterForm.body_scale(form) * s
	var box := FishCharacter.hitbox_size(form["class"]) * scale
	_check(is_equal_approx(fish.body_scale, scale), "%s: body_scale %.2f" % [tag, fish.body_scale])
	_check(absf(fish.hitbox_length - float(form["length_m"]) * s) < 0.01, "%s: hitbox length %.2f m (form %.1f x %.1f)" % [tag, fish.hitbox_length, form["length_m"], s])
	var shape := (fish._collision.shape as BoxShape3D).size
	_check(shape.is_equal_approx(box), "%s: collision box %s" % [tag, shape])
	var extent := _model_extent(fish._visual)
	var wanted := fish.hitbox_length
	print("      model extent %s m for a hitbox %s" % [extent, shape])
	_check(extent.z > wanted * 0.7 and extent.z < wanted * 1.5, "%s: model length %.2f m is about the hitbox's %.2f" % [tag, extent.z, wanted])
	if fish._visual.has_meta("titan_lod_rescale"):
		var far := (fish._visual.find_children("*", "GeometryInstance3D", true, false).filter(func(n: Node) -> bool: return n.has_meta("lod"))[0] as GeometryInstance3D).visibility_range_end
		print("      lod range end now %.1f" % far)
	# Swim: thrust for 4 s, then turn for 2 s.
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
	input.boost = false
	input.forward = 0.4
	input.stick = Vector2(1.0, 0.0)
	var heading := -fish.global_basis.z
	var turned := 0.0
	var spin := 0.0
	for i in tps * 2:
		await get_tree().physics_frame
		var now := -fish.global_basis.z
		turned += heading.angle_to(now)
		heading = now
		spin = maxf(spin, fish.angular_velocity.length())
	var rate := turned / 2.0  # over the 2 s
	print("      peak spin %.2f rad/s" % spin)
	input.stick = Vector2.ZERO
	input.forward = 0.0
	print("      swim: peak speed %.1f m/s, turn rate %.2f rad/s (top_speed_scale %.2f, turn_scale %.2f)" % [peak, rate, fish.top_speed_scale, fish.turn_scale])
	_check(peak > 2.0, "%s: swims (peak %.1f m/s)" % [tag, peak])
	_check(rate > 0.05, "%s: turns (%.2f rad/s)" % [tag, rate])
	results[key][s] = {"peak": peak, "turn": rate}
	# Camera framing: where it sits over the body's length, and the screen share.
	_place()
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	var zoom := size.frame(camera, fish, form)
	await _frames(1)
	if camera.has_method("snap"):
		camera.call("snap")
	await get_tree().create_timer(1.5).timeout
	fish.linear_velocity = Vector3.ZERO
	var gap := camera.global_position.distance_to(fish.global_position)
	var share := _screen_share(fish._visual)
	print("      camera: %.2f m away (%.2f body lengths), zoom %.2f, body spans %.0f%% of the screen width" % [gap, gap / fish.hitbox_length, zoom, share * 100.0])
	results[key][s]["cam_ratio"] = gap / fish.hitbox_length
	results[key][s]["share"] = share
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_x%s.png" % [shots_dir, key, str(s).replace(".", "_")])
	await _bite_at(form, s, tag)
	fish.controls = null


## The model's extent in the fish's own frame (m): width, height, length, from its meshes' boxes.
func _model_extent(model: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	var inverse := fish.global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var local := inverse * mesh.global_transform
		var part := local * mesh.mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box.size


## The share of the screen's width the body's box spans from the camera.
func _screen_share(model: Node3D) -> float:
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


func _bite_at(form: Dictionary, s: float, tag: String) -> void:
	var bite := HunterBite.new()
	fish.add_child(bite)
	bite.setup(fish, form)
	var landed: Array = []
	bite.chomped.connect(func(mouth: Vector3, reach: float, radius: float, capacity: int) -> void:
		landed.append([mouth, reach, radius, capacity, Time.get_ticks_msec()]))
	_place()
	fish.controls = FishInput.new()
	await _frames(2)
	var input: FishInput = fish.controls
	input.jump = true
	var peak_open := 0.0
	var ticks := 0
	var landed_tick := -1
	var shot_taken := false
	var tps := int(Engine.physics_ticks_per_second)
	for i in tps * 4:
		await get_tree().physics_frame
		ticks += 1
		if i == 6:
			input.jump = false
		peak_open = maxf(peak_open, bite.bite.open)
		if shots_dir != "" and not shot_taken and (bite.bite.phase == ChompKit.Phase.HOLD and bite.bite.t > 0.05 or bite.bite.phase == ChompKit.Phase.STRIKE and bite.bite.open < 0.7):
			shot_taken = true
			bite.set_physics_process(false)  # freeze the chomp mid-strike (a snap chomp is over in 4 ticks)
			await _jaw_shot(str(form["key"]), s)
			bite.set_physics_process(true)
		if not landed.is_empty() and landed_tick < 0:
			landed_tick = i
		if landed_tick >= 0 and not bite.busy():
			break
	print("      bite: %d landed (tick %d), jaw opened to %.2f, took %.2f s, phase %d" % [landed.size(), landed_tick, peak_open, float(ticks) / tps, bite.bite.phase])
	_check(landed.size() == 1, "%s: one bite lands from one press" % tag)
	_check(peak_open > 0.9, "%s: the jaw gapes (%.2f)" % [tag, peak_open])
	if not landed.is_empty():
		var hit: Array = landed[0]
		_check(absf(float(hit[1]) - float(form["bite_reach_m"]) * s) < 0.01, "%s: reach %.2f m" % [tag, hit[1]])
		_check(absf(float(hit[2]) - float(form["bite_radius_m"]) * s) < 0.01, "%s: radius %.2f m" % [tag, hit[2]])
		var cap := maxi(1, roundi(float(form["capacity"]) * pow(s, 1.5)))
		_check(int(hit[3]) == cap, "%s: capacity %d (wanted %d)" % [tag, hit[3], cap])
	# The frustum: a point halfway out on the nose is in; behind, far off to the side and past the reach are out.
	var mouth := bite.mouth_point()
	var forward := -fish.global_basis.z
	var up := fish.global_basis.y
	_check(bite.in_bite(mouth + forward * bite.reach() * 0.5), "%s: a point half the reach ahead is in the bite" % tag)
	_check(bite.in_bite(mouth + forward * bite.reach() * 0.9 + up * bite.radius() * 0.5), "%s: a point at the far end, half the radius off, is in" % tag)
	_check(not bite.in_bite(mouth - forward * bite.reach() * 0.5), "%s: a point behind the mouth is out" % tag)
	_check(not bite.in_bite(mouth + forward * bite.reach() * 1.3), "%s: a point past the reach is out" % tag)
	_check(not bite.in_bite(mouth + forward * bite.reach() * 0.5 + up * bite.radius() * 1.5), "%s: a point far off the nose is out" % tag)
	# The cooldown: another press at once starts nothing.
	input.jump = true
	await _frames(3)
	_check(not bite.busy(), "%s: cooldown (%.1f s) holds the next bite" % [tag, bite.cooldown])
	input.jump = false
	bite.queue_free()
	await _frames(2)


func _compare(key: String) -> void:
	var small: Dictionary = results[key][SIZES[0]]
	var one: Dictionary = results[key][SIZES[1]]
	var big: Dictionary = results[key][SIZES[2]]
	print("%s: peak speed %.1f / %.1f / %.1f m/s, turn %.2f / %.2f / %.2f rad/s at x0.5 / x1 / x3" % [key, small.peak, one.peak, big.peak, small.turn, one.turn, big.turn])
	print("%s: camera %.2f / %.2f / %.2f body lengths away, screen share %.0f%% / %.0f%% / %.0f%%" % [key, small.cam_ratio, one.cam_ratio, big.cam_ratio,
			small.share * 100.0, one.share * 100.0, big.share * 100.0])
	_check(big.peak > one.peak and one.peak > small.peak, "%s: bigger boosts to a higher speed (%.1f > %.1f > %.1f)" % [key, big.peak, one.peak, small.peak])
	_check(big.turn < small.turn, "%s: bigger turns slower (%.2f < %.2f)" % [key, big.turn, small.turn])
	var ratio: float = big.cam_ratio / maxf(small.cam_ratio, 0.001)
	_check(ratio > 0.6 and ratio < 1.6, "%s: camera framing holds across sizes (ratio %.2f)" % [key, ratio])


## The jaw held wide, from the front three-quarter and the side, on a free camera.
func _jaw_shot(key: String, s: float) -> void:
	var free := Camera3D.new()
	free.far = 2000.0
	main.add_child(free)
	var length := fish.hitbox_length
	var mouth := fish.global_position - fish.global_basis.z * length * 0.4
	for view: Array in [["front", Vector3(-0.7, 0.25, -1.0)], ["side", Vector3(-1.0, 0.1, -0.1)]]:
		free.global_position = mouth + fish.global_basis * (Vector3(view[1]).normalized() * length * 0.7)
		free.look_at(mouth, Vector3.UP)
		free.make_current()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_x%s_jaw_%s.png" % [shots_dir, key, str(s).replace(".", "_"), view[0]])
	camera.make_current()
	free.queue_free()


const EXPECTED := ["drowned_shark", "humpback", "orca", "beluga", "sperm", "blue", "king_of_herrings", "gulper_mother", "whale_fall", "lamprey_queen", "fallen_angel"]


## The registry itself: no scene needed.
func _registry() -> void:
	print("registry:")
	_check(HunterForms.KEYS == EXPECTED, "eleven forms, five whales and six bosses, in card order")
	for key: String in EXPECTED:
		_check(HunterForms.has(key) and FileAccess.file_exists("res://scripts/what_stinks/forms/%s.gd" % key), "%s: registered, with its own file" % key)
		var sheet := HunterForms.sheet(key)
		var whole := true
		for need: String in HunterForm.SHARK:
			whole = whole and sheet.has(need)
		_check(whole and str(sheet["key"]) == key and sheet.has("ready"), "%s: the sheet has every key (name '%s')" % [key, sheet["name"]])
		_check(int(sheet["species"]) < FishCharacter.species_count(sheet["class"]), "%s: its class has the species" % key)
		_check(float(sheet["length_m"]) > 0.0 and float(sheet["bite_reach_m"]) > 0.0 and int(sheet["capacity"]) > 0, "%s: sane lengths" % key)
	var ready := HunterForms.ready_keys()
	_check(ready.has("drowned_shark") and ready.has("humpback"), "the shark and the humpback are ready (%s)" % str(ready))
	for key in ready:
		_check(HunterForms.is_ready(key) and bool(HunterForms.sheet(key)["ready"]), "%s: ready both ways" % key)
	_check(not HunterForms.is_ready("nope") and HunterForms.playable("nope") == "drowned_shark", "an unknown form is not ready and plays as the shark")
	_check(str(HunterForms.sheet("nope")["key"]) == "drowned_shark", "an unknown form's sheet is the shark's")
	var settings := WhatStinksSettings.shared()
	var was := settings.form
	for key: String in EXPECTED:
		settings.form = key
		var played := str(settings.form_sheet()["key"])
		_check(played == (key if HunterForms.is_ready(key) else "drowned_shark"), "settings form %s plays as %s" % [key, played])
	settings.form = was
	_check(str(HunterForm.sheet("humpback")["name"]) == "Humpback" and HunterForm.sheet("humpback")["class"] == FishCharacter.FishClass.TITAN, "HunterForm.sheet reads the registry")


## Through Main: the match card lists the ready forms and a size; the settings' form and
## size are what the local Hunter wears; the schools' alarm and the camera follow.
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
	var nature_bait := NatureSettings.shared().bait_range
	for key: String in HunterForms.ready_keys():
		for s: float in [0.5, 3.0]:
			var tag := "%s x%.1f" % [key, s]
			main.set_mode(main.WHAT_STINKS)  # entering a mode restores its saved tuning, so the picks go in after
			await _frames(5)
			settings.form = key
			size.size_mult = s
			main._close_match_card()
			main._apply_mode()
			await _frames(3)
			var card: MatchCard = main._match_card
			var titles: Array = card.choices.map(func(c: Dictionary) -> String: return str(c.title))
			_check(titles.has("Hunter") and not titles.has("Size"), "%s: the card has Hunter and no Size (locked at %sx, a panel option) (%s)" % [tag, str(HunterSize.MATCH_SIZE), str(titles)])
			var hunter_choice: Dictionary = card.choices[titles.find("Hunter")]
			var shown: Array = hunter_choice.options
			var want: Array = HunterForms.ready_keys().map(func(k: String) -> String: return HunterForms.name_of(k))
			_check(shown == want, "%s: the card lists the ready forms only (%s)" % [tag, str(shown)])
			_check(shown[int(hunter_choice.index)] == HunterForms.name_of(key), "%s: and has this one picked" % tag)
			main.play_match()
			await _frames(8)
			var game: WhatStinksMatch = main.what_stinks
			_check(game != null and game.hunters == [fish], "%s: a match with the local fish as Hunter" % tag)
			if game == null:
				continue
			var form := HunterForms.sheet(key)
			_check(fish.character == form["class"] and fish.species == int(form["species"]), "%s: wears the form's class and species" % tag)
			_check(is_equal_approx(fish.body_scale, HunterForm.body_scale(form) * s), "%s: body scale %.2f follows the size" % [tag, fish.body_scale])
			_check(absf(fish.hitbox_length - float(form["length_m"]) * s) < 0.01, "%s: hitbox %.2f m" % [tag, fish.hitbox_length])
			var bite: HunterBite = game.bites[fish]
			_check(str(bite.form["key"]) == key and absf(bite.reach() - float(form["bite_reach_m"]) * s) < 0.01, "%s: the bite is the form's (reach %.2f m)" % [tag, bite.reach()])
			_check(bite.capacity() == maxi(1, roundi(float(form["capacity"]) * pow(s, size.bite_capacity_exp))), "%s: capacity %d" % [tag, bite.capacity()])
			_check(absf(game.field.alarm_scale - pow(s, size.alarm_exp)) < 0.001, "%s: the schools' alarm scale %.2f" % [tag, game.field.alarm_scale])
			var school: School = game.field.schools[0]
			_check(absf(school.settings.bait_range - nature_bait * pow(s, size.alarm_exp)) < 0.01, "%s: a school's alarm range %.1f m" % [tag, school.settings.bait_range])
			var cam := main.get_node("FollowCamera")
			var full := maxf(fish.hitbox_length / HunterSize.CAM_BASE, 1.0)
			var follow := 1.0 if full <= 1.0001 else (full - 1.0) / (pow(full, HunterSize.CAM_POWER) - 1.0)
			_check(absf(float(cam.get("body_follow")) - follow) < 0.001, "%s: the camera's body_follow %.2f" % [tag, float(cam.get("body_follow"))])
			main.set_mode(main.FREE_PLAY)
			await _frames(5)
	# A form's own camera offsets: the factors move the distance and height.
	var camera_node := main.get_node("FollowCamera")
	fish.set_look(FishCharacter.FishClass.MONSTER, 0, 0)
	size.size_mult = 1.0
	size.frame(camera_node, fish, {"cam": Vector2(1.5, 1.0)})
	_check(absf(float(camera_node.get("extra_distance")) - float(camera_node.get("distance")) * 0.5) < 0.001 and absf(float(camera_node.get("extra_height"))) < 0.001, "a form's camera factor pushes the camera back (extra %.2f m)" % float(camera_node.get("extra_distance")))
	size.frame(camera_node, fish, {"cam": Vector2(1.0, 1.0)})
	_check(absf(float(camera_node.get("extra_distance"))) < 0.001, "and factor 1 puts it back")
