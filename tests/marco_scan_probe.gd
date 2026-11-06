extends Node3D
## Probe for MarcoScan (the "Marco!" scan pulse and its ghosts), against a stub
## match:
## - every machine gets the pulse, and it reaches the arena's far corner;
## - in a seeker's view, a hider moving as the scan passes leaves ghost cells,
##   a still one leaves none, nor does one in a porthole; a fast one's streak
##   is longer than a slow one's;
## - a streak's start fades before its end, and the cells all fade out;
## - in a hider's view there are no ghosts.
## `--shots --out=<dir>` (needs a window): the pulse mid-scan, then a slow
## fish and a fast fish mid-fade, in murk with a wall across part of a streak.
##   Godot_console.exe --headless --fixed-fps 60 --path . res://tests/marco_scan_probe.tscn
##   Godot_console.exe --fixed-fps 60 --path . res://tests/marco_scan_probe.tscn -- --shots --out=<dir>

const FISH_SCENE := preload("res://scenes/fish.tscn")

var failures := 0
var stub: StubMatch
var scan: MarcoScan
var out_dir := "user://marco_scan_shots"
## Fish moved by hand each frame: fish -> velocity (m/s).
var moving := {}


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


func _run(shots: bool) -> void:
	stub = StubMatch.new()
	add_child(stub)
	var arena := ArenaStub.new()
	add_child(arena)
	stub.arena = arena
	scan = MarcoScan.new()
	stub.add_child(scan)
	scan.bind(stub)
	if shots:
		await _shots()
	else:
		await _probe()
		print("marco_scan_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _process(delta: float) -> void:
	for fish: Variant in moving:
		if is_instance_valid(fish):
			(fish as Node3D).global_position += (moving[fish] as Vector3) * delta


func _spawn(fish_class: FishCharacter.FishClass, at: Vector3) -> FishController:
	var fish: FishController = FISH_SCENE.instantiate()
	fish.character = fish_class
	add_child(fish)
	fish.global_position = at
	fish.freeze = true
	return fish


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## The x-extent of the cells near `lane` (a z lane, fish swimming along x).
func _extent(lane: float) -> Vector2:
	var found := scan.cells_in(AABB(Vector3(-200.0, -20.0, lane - 3.0), Vector3(400.0, 40.0, 6.0)))
	if found.is_empty():
		return Vector2.ZERO
	var lo := INF
	var hi := -INF
	for at in found:
		lo = minf(lo, at.x)
		hi = maxf(hi, at.x)
	return Vector2(lo, hi)


func _count(lane: float) -> int:
	return scan.cells_in(AABB(Vector3(-200.0, -20.0, lane - 3.0), Vector3(400.0, 40.0, 6.0))).size()


func _probe() -> void:
	stub.settings.set("marco_scan_time", 2.0)
	var seeker := _spawn(FishCharacter.FishClass.HUNTER, Vector3(0.0, 0.0, -20.0))
	var still := _spawn(FishCharacter.FishClass.SKIRMISHER, Vector3(0.0, 0.0, 0.0))
	var slow := _spawn(FishCharacter.FishClass.SKIRMISHER, Vector3(0.0, 0.0, 10.0))
	var fast := _spawn(FishCharacter.FishClass.SKIRMISHER, Vector3(0.0, 0.0, 20.0))
	var hidden := _spawn(FishCharacter.FishClass.SKIRMISHER, Vector3(0.0, 0.0, 30.0))
	stub.hiders = [still, slow, fast, hidden]
	stub.hidden = [hidden]
	moving[slow] = Vector3(0.8, 0.0, 0.0)
	moving[fast] = Vector3(9.0, 0.0, 0.0)
	moving[hidden] = Vector3(5.0, 0.0, 0.0)
	await _frames(3)

	print("as seeker:")
	stub.view_role = MarcoScan.SEEKER
	stub.marco_scan_started.emit(seeker.global_position, seeker)
	await _frames(2)
	check(scan.pulses.size() == 1, "Marco! starts a pulse")
	var pulse := scan.pulses[0]
	check(float(pulse.reach) > 60.0, "it has to reach the arena's far corner (%.0f m)" % float(pulse.reach))
	check(is_equal_approx(scan.radius_at(pulse, 2.0), float(pulse.reach)), "and gets there in marco_scan_time")
	await _frames(150)
	var slow_x := _extent(10.0)
	var fast_x := _extent(20.0)
	check(_count(0.0) == 0, "a still hider leaves no ghost")
	check(_count(10.0) > 20, "a slow hider leaves its shape (%d cells, %.2f m long)" % [_count(10.0), slow_x.y - slow_x.x])
	check(fast_x.y - fast_x.x > slow_x.y - slow_x.x + 1.5,
			"a fast hider's streak is longer (%.2f m against %.2f m)" % [fast_x.y - fast_x.x, slow_x.y - slow_x.x])
	check(_count(30.0) == 0, "a hider in a porthole leaves none")
	check(scan._ghosts.visible and scan._ghosts.multimesh.visible_instance_count > 0, "the ghosts are drawn in the seeker's view")
	moving.clear()

	print("fading:")
	var mid := (fast_x.x + fast_x.y) * 0.5
	var start_cells := 0
	var end_cells := 0
	for i in 600:
		await get_tree().process_frame
		var found := scan.cells_in(AABB(Vector3(-200.0, -20.0, 17.0), Vector3(400.0, 40.0, 6.0)))
		start_cells = 0
		end_cells = 0
		for at in found:
			if at.x < mid:
				start_cells += 1
			else:
				end_cells += 1
		if start_cells < end_cells * 0.5:
			break
	check(start_cells < end_cells * 0.5, "a streak's start fades first (%d cells left behind the middle, %d ahead)" % [start_cells, end_cells])
	await _frames(int(60.0 * (float(scan._setting("ghost_fade_max", 5.0)) + 0.5)))
	check(scan.cells.is_empty(), "and they all fade out")

	print("as hider:")
	scan.clear()
	stub.view_role = 0
	moving[slow] = Vector3(0.8, 0.0, 0.0)
	moving[fast] = Vector3(9.0, 0.0, 0.0)
	stub.marco_scan_started.emit(seeker.global_position, seeker)
	await _frames(30)
	check(scan.pulses.size() == 1 and (scan.pulses[0].shell as Node3D).visible, "a hider sees the pulse too")
	await _frames(120)
	check(scan.cells.is_empty() and not scan._ghosts.visible, "but no ghosts")
	moving.clear()


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.12, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.7, 0.7)
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.2, 0.2)
	env.fog_density = 0.06
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	add_child(sun)
	var floor_box := CSGBox3D.new()
	floor_box.size = Vector3(80.0, 1.0, 80.0)
	floor_box.position = Vector3(0.0, -2.0, 0.0)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.25, 0.3, 0.3)
	floor_box.material = stone
	add_child(floor_box)
	var wall := CSGBox3D.new()
	wall.size = Vector3(0.4, 4.0, 1.0)
	wall.position = Vector3(1.6, 0.0, 2.6)
	add_child(wall)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(1.0, 3.0, -4.5), Vector3(1.0, -0.5, 3.0))
	camera.current = true
	var seeker := _spawn(FishCharacter.FishClass.HUNTER, Vector3(-4.0, 1.0, 9.0))
	var slow := _spawn(FishCharacter.FishClass.BULWARK, Vector3(-1.0, 0.0, 0.0))
	var fast := _spawn(FishCharacter.FishClass.SKIRMISHER, Vector3(-4.0, 0.0, 4.0))
	slow.rotation.y = -PI * 0.5
	fast.rotation.y = -PI * 0.5
	stub.hiders = [slow, fast]
	moving[slow] = Vector3(0.6, 0.0, 0.0)
	moving[fast] = Vector3(10.0, 0.0, 0.0)
	stub.view_role = MarcoScan.SEEKER
	await _frames(5)
	stub.marco_scan_started.emit(seeker.global_position, seeker)
	await _frames(8)
	await _shot("pulse_early")
	await _frames(14)
	await _shot("pulse_mid")
	await _frames(60)
	moving.clear()
	await _frames(10)
	await _shot("ghosts_fresh")
	slow.visible = false
	fast.visible = false
	await _frames(90)
	await _shot("ghosts_mid_fade")
	await _frames(90)
	await _shot("ghosts_late_fade")
	print("marco_scan_probe: shots in %s" % ProjectSettings.globalize_path(out_dir))


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))


class StubMatch extends Node:
	signal marco_scan_started(origin: Vector3, seeker: FishController)
	signal round_started(index: int, seeker: FishController)
	var settings := MarcoPoloSettings.new()
	var hiders: Array[FishController] = []
	var hidden: Array[FishController] = []
	var view_role := 0
	var arena: Node3D

	func local_view_role() -> int:
		return view_role

	func live_hiders() -> Array[FishController]:
		return hiders

	func is_hidden(fish: FishController) -> bool:
		return hidden.has(fish)

	func decoys() -> Array[FishController]:
		return []


class ArenaStub extends Node3D:
	var size := Vector3(80.0, 20.0, 80.0)
