extends Node
## Probe for the whale pick card and the Titan's murk view (planning_marco_whales.md
## §1a, §3), against a stub match:
## - the card is up for a person's whale-to-be inside its window, and not for a
##   hider, a spectator, a bot's puppet, or once the window's over;
## - it opens on the remembered pick; species and skin cycle, the pick is sent;
##   locking is final;
## - the Titan view thickens the fog only for the local whale seeker (eased), and
##   puts it back; whale_desaturate greys it.
## `--shots --out=DIR` (needs a window): the card with every species.
##   Godot_console.exe --headless --path . res://tests/pick_card_probe.tscn
##   Godot_console.exe --path . res://tests/pick_card_probe.tscn -- --shots --out=DIR

const FISH_SCENE := preload("res://scenes/fish.tscn")

var failures := 0
var out_dir := "user://pick_card_shots"
var stub: StubMatch
var card: Node
var view: Node


func _ready() -> void:
	var shots := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--shots":
			shots = true
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	_run.call_deferred(shots)


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _run(shots: bool) -> void:
	if shots:
		get_window().size = Vector2i(1280, 720)
		DirAccess.make_dir_recursive_absolute(out_dir)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.12, 0.13)
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	stub = StubMatch.new()
	add_child(stub)
	var me: FishController = FISH_SCENE.instantiate()
	add_child(me)
	me.freeze = true
	stub.me = me
	stub.arena = ArenaStub.new()
	stub.arena.env = env
	env.fog_enabled = true
	env.fog_density = 0.04
	env.fog_light_color = Color(0.05, 0.18, 0.17)
	stub.add_child(stub.arena)
	stub.settings.whale_seeker = true
	stub.settings.whale_last_pick = 2
	stub.settings.whale_last_skin = 1
	card = load("res://scripts/marco_polo/whale_pick_card.gd").new()
	stub.add_child(card)
	card.call("bind", stub)
	view = load("res://scripts/marco_polo/titan_view.gd").new()
	stub.add_child(view)
	view.call("bind", stub)

	print("the card:")
	stub.role = 0
	await _frames(3)
	check(not card.shown, "not for a hider")
	stub.role = 1
	stub.phase_left = 8.0
	stub.settings.whale_seeker = false
	await _frames(3)
	check(not card.shown, "not when whales are off")
	stub.settings.whale_seeker = true
	await _frames(3)
	check(card.shown, "up for a whale seeker while it waits")
	check(card.species == 2 and card.skin == 1, "it opens on the remembered pick (%d, %d)" % [card.species, card.skin])
	card.species = 2
	Input.action_press(&"ui_right")
	await _frames(2)
	Input.action_release(&"ui_right")
	await _frames(2)
	check(card.species == 3 and card.skin == 0, "right cycles the species (%d) and resets the skin" % card.species)
	Input.action_press(&"ui_down")
	await _frames(2)
	Input.action_release(&"ui_down")
	await _frames(2)
	check(card.skin == 1, "down cycles the skin (%d)" % card.skin)
	check(stub.last_request == [3, 1, false], "the pick is sent (%s)" % [stub.last_request])
	Input.action_press(&"ui_accept")
	await _frames(2)
	Input.action_release(&"ui_accept")
	await _frames(2)
	check(card.locked and stub.last_request[2] == true, "A locks it in")
	var kept: int = card.species
	Input.action_press(&"ui_right")
	await _frames(2)
	Input.action_release(&"ui_right")
	await _frames(2)
	check(card.species == kept, "locked is final")
	if shots:
		for i in 5:
			card.locked = false
			card.species = i
			card.skin = 0
			await _frames(30)
			await _shot("card_%d" % i)
	stub.phase_left = 0.0
	await _frames(3)
	check(not card.shown, "gone once the window's over")
	stub.phase_left = 5.0
	stub.spectating = true
	await _frames(3)
	check(not card.shown, "not for a spectator")
	stub.spectating = false

	print("the Titan view:")
	stub.phase = 1
	stub.role = 0
	await get_tree().create_timer(1.5).timeout
	check(is_equal_approx(env.fog_density, 0.04), "a hider sees the arena's own murk")
	stub.role = 1
	await get_tree().create_timer(1.5).timeout
	check(is_equal_approx(env.fog_density, 0.04 * stub.settings.whale_murk), "a whale seeker's murk is whale_murk times thicker (%.3f)" % env.fog_density)
	check(not is_equal_approx(env.fog_light_color.r, 0.05), "and darker")
	stub.settings.whale_desaturate = 0.5
	await _frames(5)
	check(env.adjustment_enabled and env.adjustment_saturation < 1.0, "whale_desaturate greys it (%.2f)" % env.adjustment_saturation)
	stub.settings.whale_desaturate = 0.0
	stub.role = 0
	await get_tree().create_timer(1.5).timeout
	check(is_equal_approx(env.fog_density, 0.04) and not env.adjustment_enabled, "back to the arena's own when it's no longer the seeker")
	stub.role = 1
	stub.spectating = true
	await get_tree().create_timer(1.5).timeout
	check(is_equal_approx(env.fog_density, 0.04), "a spectator isn't in the whale's eyes")
	if shots:
		await _view_shots(camera, env, world)
	print("pick_card_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## The Titan view with blur and grey-out at 0 and above: view_*.png.
func _view_shots(camera: Camera3D, env: Environment, world: WorldEnvironment) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(light)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.75, 0.75)
	for n in 6:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.0, 3.0, 2.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.from_hsv(n / 6.0, 0.8, 0.9)
		mesh.material = material
		box.mesh = mesh
		box.position = Vector3((n % 3 - 1) * 5.0, 0.0, -6.0 - n * 7.0)
		add_child(box)
	camera.position = Vector3(0.0, 1.0, 4.0)
	camera.rotation = Vector3.ZERO
	stub.spectating = false
	stub.phase = 1
	stub.role = 1
	stub.phase_left = 0.0
	stub.settings.whale_murk = 1.5
	for case: Array in [["arena", 0, 0.0, 0.0], ["murk", 1, 0.0, 0.0], ["blur", 1, 0.7, 0.0], ["desaturate", 1, 0.0, 0.7], ["all", 1, 0.7, 0.7]]:
		stub.role = case[1]
		stub.settings.whale_blur = case[2]
		stub.settings.whale_desaturate = case[3]
		await get_tree().create_timer(1.2).timeout
		await _shot("view_%s" % case[0])


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))


class StubMatch extends Node:
	var settings := MarcoPoloSettings.new()
	var me: FishController
	var role := 1
	var phase := 0
	var phase_left := 0.0
	var spectating := false
	var arena: Node3D
	var last_request := []
	const WHALE_SKINS := 3

	func local_fish() -> FishController:
		return me

	func role_of(_fish: Node) -> int:
		return role

	func local_view_role() -> int:
		return role

	func is_spectating() -> bool:
		return spectating

	func sight_range() -> float:
		return 40.0

	func request_whale_pick(species: int, skin: int, locked: bool) -> void:
		last_request = [species, skin, locked]


class ArenaStub extends Node3D:
	var env: Environment

	func environment() -> Environment:
		return env
