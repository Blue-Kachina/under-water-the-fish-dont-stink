extends Node3D
## Probe for the whale's water FX (titan_wake_fx.gd): a Titan stub swims over a
## floor under a roof; every stand-in power stroke sheds a ring, silt, a floor cloud
## and a roof boil; the effects are capped and freed again; wake_fx off shows none.
## `--shots --out=DIR` (needs a window): the strokes mid-life.

const FISH_SCENE := preload("res://scenes/fish.tscn")

var failures := 0
var out_dir := "user://wake_fx_shots"
var fx: Node
var stub: StubMatch


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


func _slab(at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = at
	var mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = box.size
	mesh.mesh = plane
	body.add_child(mesh)


func _run(shots: bool) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.12, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.7, 0.7)
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	_slab(Vector3(0.0, -0.5, 0.0))
	_slab(Vector3(0.0, 12.5, 0.0))
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(10.0, 5.0, 10.0), Vector3(0.0, 4.0, 0.0))
	camera.make_current()
	stub = StubMatch.new()
	add_child(stub)
	var titan: FishController = FISH_SCENE.instantiate()
	titan.character = FishCharacter.FishClass.TITAN
	add_child(titan)
	titan.global_position = Vector3(0.0, 4.0, 0.0)
	titan.freeze = true
	stub.players = [titan]
	fx = load("res://scripts/marco_polo/titan_wake_fx.gd").new()
	stub.add_child(fx)
	fx.call("bind", stub)
	await get_tree().process_frame
	check(int(titan.character) == int(FishCharacter.FishClass.TITAN), "the stub is a Titan")
	fx.call("_on_stroke", 0.9, titan.global_transform.translated_local(Vector3(0.0, 0.0, 3.0)), titan)
	var kinds := {}
	for entry: Dictionary in fx._live:
		kinds[entry.kind] = int(kinds.get(entry.kind, 0)) + 1
	check(kinds.get("ring", 0) == 1 and kinds.get("cloud", 0) >= 3 and kinds.get("bubbles", 0) == 2,
			"a hard stroke sheds a ring, silt, a floor cloud, a roof boil and bubbles (%s)" % [kinds])
	if shots:
		for n in 3:
			await get_tree().create_timer(0.45).timeout
			await _shot("wake_%d" % n)
	await get_tree().create_timer(3.0).timeout
	check(fx._live.is_empty(), "they all go again")
	for i in 60:
		fx.call("_on_stroke", 0.5, titan.global_transform, titan)
	check(fx._live.size() <= int(stub.settings.wake_fx_max), "capped at wake_fx_max (%d)" % fx._live.size())
	stub.settings.wake_fx = false
	await get_tree().process_frame
	await get_tree().process_frame
	check(fx._live.is_empty(), "wake_fx off clears them")
	fx.call("_on_stroke", 0.5, titan.global_transform, titan)
	check(fx._live.is_empty(), "and makes none")
	print("wake_fx_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))


class StubMatch extends Node:
	var settings := MarcoPoloSettings.new()
	var players: Array[FishController] = []
