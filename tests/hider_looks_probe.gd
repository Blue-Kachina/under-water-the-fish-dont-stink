extends Node3D
## Probe for HiderLooks (planning_marco_polo.md §3 "Seeing per machine",
## phase 2), against a stub match:
## - as seeker, a still hider (exposure 0) draws nothing: its real model, its
##   FX and its reveal all hidden;
## - its reveal builds up: bones at the skeleton band, the real model back
##   under the dithered copy at the skin band;
## - after a role change to hider (or spectator) it's drawn normally again,
##   with every reveal part gone and the real layers back as they were;
## - the seeker itself is never concealed; a class change rebuilds the reveal;
## - self view: a local hider sees their own fish as the seekers do (max
##   exposure), with the dashed sketch outline while less than fully visible,
##   gone once fully seen; self_view off shows their real fish.
## `--bench` (needs a window): fps with 12 fish swimming all in reveal at the
## muscular band, against the same 12 shown normally.
##   Godot_console.exe --headless --path . res://tests/hider_looks_probe.tscn
##   Godot_console.exe --path . res://tests/hider_looks_probe.tscn -- --bench

const FISH_SCENE := preload("res://scenes/fish.tscn")

var failures := 0
var stub: StubMatch
var looks: HiderLooks


func _ready() -> void:
	_run.call_deferred(OS.get_cmdline_user_args().has("--bench"))


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _run(bench: bool) -> void:
	stub = StubMatch.new()
	add_child(stub)
	looks = HiderLooks.new()
	stub.add_child(looks)
	looks.bind(stub)
	if bench:
		await _bench()
	else:
		await _probe()
		print("hider_looks_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _spawn(fish_class: FishCharacter.FishClass, at: Vector3) -> FishController:
	var fish: FishController = FISH_SCENE.instantiate()
	fish.character = fish_class
	add_child(fish)
	fish.global_position = at
	fish.freeze = true
	return fish


func _drawn(fish: FishController) -> Array[GeometryInstance3D]:
	var drawn: Array[GeometryInstance3D] = []
	for node: Node in fish.find_children("*", "GeometryInstance3D", true, false):
		var part := node as GeometryInstance3D
		if part.is_visible_in_tree() and part.layers != 0:
			drawn.append(part)
	return drawn


func _reveal_parts(fish: FishController, shown_only: bool) -> int:
	var count := 0
	for node: Node in fish.find_children("*", "GeometryInstance3D", true, false):
		if node.has_meta("marco_reveal") and not node.is_queued_for_deletion():
			if not shown_only or (node as GeometryInstance3D).is_visible_in_tree():
				count += 1
	return count


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _probe() -> void:
	var seeker := _spawn(FishCharacter.FishClass.HUNTER, Vector3.ZERO)
	var hider := _spawn(FishCharacter.FishClass.SKIRMISHER, Vector3(4.0, 0.0, -6.0))
	var real_layers := {}
	for node: Node in hider.find_children("*", "GeometryInstance3D", true, false):
		real_layers[node] = (node as GeometryInstance3D).layers
	var drawn_before := _drawn(hider).size()
	stub.players = [seeker, hider]
	stub.me = seeker
	stub.hiders = [hider]
	stub.view_role = HiderLooks.SEEKER
	stub.exposures[hider] = 0.0
	await _frames(2)
	print("seeker's view, hider still (exposure 0):")
	check(looks.concealed(hider), "the hider is concealed")
	check(not looks.concealed(seeker), "the seeker isn't")
	var drawn := _drawn(hider)
	check(drawn.is_empty(), "nothing of the hider is drawn (%d parts drawn, %d before)" % [drawn.size(), drawn_before])
	check(_drawn(seeker).size() > 0, "the seeker is drawn")
	print("exposure 0.16 (skeleton):")
	stub.exposures[hider] = 0.16
	await _frames(2)
	var reveal := looks.reveal_of(hider)
	check(reveal != null and reveal.layers.x > 0.0 and reveal.layers.y == 0.0, "bones growing, no vessels yet (%s)" % [reveal.layers if reveal else null])
	check(_reveal_parts(hider, true) > 0, "reveal parts drawn (%d)" % _reveal_parts(hider, true))
	check(not _drawn(hider).any(func(p: GeometryInstance3D) -> bool: return not p.has_meta("marco_reveal")), "the real model stays hidden")
	print("exposure 0.75 (skin):")
	stub.exposures[hider] = 0.75
	await _frames(2)
	check(_drawn(hider).any(func(p: GeometryInstance3D) -> bool: return String(p.name) == "Body"), "the real body is back under the copy")
	check(reveal.layers.w > 0.0 and reveal.layers.w < 1.0, "skin washing in (%.2f)" % reveal.layers.w)
	print("exposure 0.92 (aura):")
	stub.exposures[hider] = 0.92
	await _frames(2)
	check(reveal.aura > 0.0 and _reveal_parts(hider, true) >= 1, "the aura shows (%.2f)" % reveal.aura)
	print("the hider changes class mid-round:")
	hider.set_look(FishCharacter.FishClass.DRIFTER, 0)
	await _frames(2)
	var rebuilt := looks.reveal_of(hider)
	check(rebuilt != null and rebuilt.model == hider._visual, "the reveal rebuilt on the new model")
	print("role change: the local player becomes a hider (or spectator):")
	stub.view_role = 0
	stub.local_role_changed.emit(0)
	await _frames(2)
	check(not looks.concealed(hider), "the hider isn't concealed any more")
	check(_reveal_parts(hider, false) == 0, "no reveal parts left (%d)" % _reveal_parts(hider, false))
	var restored := true
	for node: Node in hider.find_children("*", "GeometryInstance3D", true, false):
		var part := node as GeometryInstance3D
		if real_layers.has(part) and part.layers != real_layers[part]:
			restored = false
	check(restored, "every real part's layers back as they were")
	check(_drawn(hider).any(func(p: GeometryInstance3D) -> bool: return String(p.name) == "Body"), "drawn normally")
	print("back to seeker: an eliminated hider shows normally:")
	stub.view_role = HiderLooks.SEEKER
	stub.hiders = []
	await _frames(2)
	check(not looks.concealed(hider), "not concealed once out of the round")
	print("self view: the local player hides:")
	stub.view_role = 0
	stub.me = hider
	stub.hiders = [hider]
	stub.seeker_list = [seeker]
	stub.exposures[hider] = 0.0
	await get_tree().create_timer(0.35).timeout
	var own := looks.reveal_of(hider)
	check(own != null and own.self_look, "their own fish is a self look")
	check(not _drawn(hider).any(func(p: GeometryInstance3D) -> bool: return not p.has_meta("marco_reveal")), "drawn as the seekers see it (nothing real at exposure 0)")
	var sketch := _part(hider, HiderLooks.SKETCH_SHADER)
	check(sketch != null and sketch.visible and own.sketch > 0.9, "the dashed outline keeps them in sight (%.2f)" % (own.sketch if own else -1.0))
	stub.exposures[hider] = 0.95
	await get_tree().create_timer(0.35).timeout
	check(own.sketch == 0.0 and (sketch == null or not sketch.visible), "fully seen: no outline (%.2f)" % own.sketch)
	check(_drawn(hider).any(func(p: GeometryInstance3D) -> bool: return String(p.name) == "Body"), "fully seen: the real body shows")
	stub.exposures[hider] = 0.6
	await get_tree().create_timer(0.35).timeout
	check(own.sketch > 0.9, "the moment some of them is lost, the outline's back (%.2f)" % own.sketch)
	stub.settings.self_view = false
	await _frames(2)
	check(not looks.concealed(hider) and _reveal_parts(hider, false) == 0, "self_view off: their real fish")
	stub.settings.self_view = true


## `fish`'s reveal part drawn with `shader`, or null (copies of one part can share a name, so Godot renames them).
func _part(fish: FishController, shader: Shader) -> MeshInstance3D:
	for node: Node in fish.find_children("*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).material_override as ShaderMaterial
		if material and material.shader == shader and not node.is_queued_for_deletion():
			return node
	return null


func _bench() -> void:
	get_window().size = Vector2i(1280, 720)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.1, 0.2, 0.22)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.7, 0.75)
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.6, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.0, 9.0, 16.0)
	camera.look_at(Vector3(0.0, 0.0, -2.0))
	camera.make_current()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var seeker := _spawn(FishCharacter.FishClass.HUNTER, Vector3(0.0, 0.0, 30.0))
	var fish: Array[FishController] = []
	var classes: Array = FishCharacter.CLASSES.keys()
	for i in 12:
		fish.append(_spawn(classes[i % classes.size()], Vector3((i % 4 - 1.5) * 4.0, 0.0, -float(i / 4) * 4.0)))
	stub.players = [seeker]
	stub.players.append_array(fish)
	stub.me = seeker
	stub.view_role = 0
	var normal := await _measure(fish, false)
	stub.view_role = HiderLooks.SEEKER
	stub.hiders = fish.duplicate()
	for f in fish:
		stub.exposures[f] = 0.55
	var revealed := await _measure(fish, true)
	print("hider_looks bench: 12 fish shown normally %.0f fps, all in reveal (muscular) %.0f fps" % [normal, revealed])


func _measure(fish: Array[FishController], _reveal: bool) -> float:
	await _frames(30)
	var frames := 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 3000000:
		var t := Time.get_ticks_msec() / 1000.0
		for i in fish.size():
			var f := fish[i]
			f._visual.tail.rotation.y = sin(t * 6.0 + i) * 0.5
			f._visual.react(1.0 / 60.0, Vector3(0.0, 0.0, -10.0))
		await get_tree().process_frame
		frames += 1
	return frames / ((Time.get_ticks_usec() - start) / 1000000.0)


## The bits of MarcoPoloMatch HiderLooks reads.
class StubMatch extends Node:
	signal local_role_changed(role: int)
	var settings := MarcoPoloSettings.new()
	var players: Array[FishController] = []
	var hiders: Array[FishController] = []
	var exposures := {}
	var me: FishController
	var view_role := 0
	var seeker_list: Array[FishController] = []

	func max_exposure(fish: FishController) -> float:
		return float(exposures.get(fish, 0.0))

	func seekers() -> Array[FishController]:
		return seeker_list

	func local_view_role() -> int:
		return view_role

	func is_live_hider(fish: FishController) -> bool:
		return hiders.has(fish)

	func local_exposure(fish: FishController) -> float:
		return float(exposures.get(fish, 0.0)) if view_role == HiderLooks.SEEKER else 0.0

	func local_fish() -> FishController:
		return me

	func decoys() -> Array[FishController]:
		return []
