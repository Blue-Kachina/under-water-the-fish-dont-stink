class_name LookTank
extends Node
## The Look Tank (planning_abyssal_look.md, phase 0): the Test Tank's Ocean and
## Unnatural seabed (reef, ruins, kelp, murk, blood moon) with the fish frozen
## and a free camera that jumps to six fixed viewpoints, so every phase of the
## water look is compared from the same places (tests/look_shots.gd saves them):
##   1 looking up through kelp      4 the open blue
##   2 a ruin in shafts             5 floor level into murk
##   3 a reef close-up              6 split-screen (WaterLook.tank_split_players players)
## 0 gives the game's own camera back. Keys 1 to 6 (0) or the console's
## `look_view <n>` jump; `look_tank` in the console (or scenes/look_tank.tscn)
## starts it. WaterLook's Look Tank options set the field of view, the players
## joined for view 6, whether the HUD stays, and the settle frames.

const MAIN_SCENE := "res://scenes/main.tscn"
const COUNT := 6
## The viewpoints' file-name stems, in order (view n is NAMES[n - 1]).
const NAMES: Array[String] = ["kelp_up", "ruin_shafts", "reef_close", "open_blue", "floor_murk", "split"]
const TITLES: Array[String] = ["Looking up through kelp", "A ruin in shafts", "A reef close-up", "The open blue", "Floor level into murk",
		"Split-screen"]
## The first view's pad id for the extra split-screen players (made-up controllers).
const FIRST_PAD := 20

## The game's Main, and whether this node made it (look_tank.tscn) or was added to a running one.
var main: Node
var standalone := true
## The viewpoint now (0: the game's own camera).
var view := 0
var camera: Camera3D
var run: UnnaturalRun
## The places the views look at, found on the seabed (global): "kelp", "ruin", "reef", "centre", "floor_y".
var spots := {}
var _hud_was := {}
var _ready_done := false
var _fog_volume: FogVolume

signal ready_to_shoot


## Adds a Look Tank to a running Main (the console's look_tank).
static func attach(host: Node) -> LookTank:
	var tank := LookTank.new()
	tank.name = "LookTank"
	tank.standalone = false
	tank.main = host
	host.add_child(tank)
	return tank


func _ready() -> void:
	Console.register_command("look_view", "look_view <0-6>: the Look Tank's viewpoint (0: the game's camera)", _cmd_view)
	if standalone:
		main = load(MAIN_SCENE).instantiate()
		add_child(main)
	_start.call_deferred()


func _exit_tree() -> void:
	if run != null and is_instance_valid(run) and run.ocean != null and is_instance_valid(run.ocean) and run.ocean.environment() != null:
		run.ocean.environment().volumetric_fog_enabled = false
	Console.unregister_command("look_view")


func _start() -> void:
	if standalone:
		var settings := UnnaturalSettings.shared()
		settings.god_mode = true
		settings.card_choices = 0
		settings.shrine_reveal_range = 0.0
		main.get_node("DebugPanel")._panel.visible = false
		main.set_mode(main.TEST_TANK, false)
		for i in 5:
			await get_tree().process_frame
		if main._match_card:
			main.play_match()
	for i in 20:
		if main.unnatural_run != null and is_instance_valid(main.unnatural_run.seabed):
			break
		await get_tree().process_frame
	run = main.unnatural_run
	if run == null:
		push_warning("LookTank: no Unnatural run to look at")
		return
	main.mode_ended.connect(func(_id: String) -> void: queue_free(), CONNECT_ONE_SHOT)
	camera = Camera3D.new()
	camera.name = "LookCamera"
	camera.far = 1000.0
	WaterGradeEffect.attach(camera)
	add_child(camera)
	_find_spots()
	for i in 10:
		await get_tree().process_frame
	_ready_done = true
	ready_to_shoot.emit()
	go(1)


func is_ready() -> bool:
	return _ready_done


func _input(event: InputEvent) -> void:
	if not _ready_done or Console.is_open():
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode >= KEY_0 and key.keycode <= KEY_6:
		go(key.keycode - KEY_0)


func _cmd_view(args: PackedStringArray) -> String:
	if args.is_empty() or not args[0].is_valid_int() or args[0].to_int() < 0 or args[0].to_int() > COUNT:
		return "look_view <0-%d> (now %d)" % [COUNT, view]
	if not _ready_done:
		return "the Look Tank isn't ready yet"
	go(args[0].to_int())
	return "view %d: %s" % [view, TITLES[view - 1] if view > 0 else "the game's camera"]


## Jumps to viewpoint `n` (1..COUNT), or back to the game's camera (0).
func go(n: int) -> void:
	view = clampi(n, 0, COUNT)
	var look := WaterLook.shared()
	var fish: FishController = main.get_node("Fish")
	if is_instance_valid(run.blood_moon):
		run.blood_moon.strength = look.tank_blood_moon if view > 0 else run.settings.blood_moon
	_set_huds(look.tank_hud or view == 0)
	_apply_volfog.call_deferred(look)
	if view == 0:
		camera.current = false
		fish.freeze = false
		return
	fish.freeze = true
	camera.fov = look.tank_fov
	if view == COUNT:
		_split(look)
		return
	_leave_split()
	var pose := pose_of(view)
	camera.global_position = pose[0]
	camera.look_at(pose[1], Vector3.UP)
	camera.current = true



## Phase 6 option D4b bench: Godot's volumetric fog with a caustic FogVolume, on while WaterLook.tank_volfog is 1 (a Look Tank only option).
func _apply_volfog(look: WaterLook) -> void:
	var env: Environment = run.ocean.environment() if run != null and run.ocean != null else null
	if env == null:
		return
	var on := look.tank_volfog > 0 and view > 0
	env.volumetric_fog_enabled = on
	if on:
		env.volumetric_fog_density = 0.0  # all the density comes from the volume
		env.volumetric_fog_albedo = Color(0.7, 0.9, 1.0)
		env.volumetric_fog_length = 80.0
		env.volumetric_fog_detail_spread = 2.0
		env.volumetric_fog_gi_inject = 0.0
		if _fog_volume == null:
			_fog_volume = FogVolume.new()
			_fog_volume.name = "VolFogShafts"
			_fog_volume.size = Vector3(400.0, 120.0, 400.0)
			var shader_material := ShaderMaterial.new()
			shader_material.shader = load("res://shaders/volfog_shafts.gdshader")
			_fog_volume.material = shader_material
			add_child(_fog_volume)
		(_fog_volume.material as ShaderMaterial).set_shader_parameter("density", look.tank_volfog_density)
		_fog_volume.global_position = camera.global_position
	if _fog_volume != null:
		_fog_volume.visible = on

## Where viewpoint `n` (1..COUNT - 1) stands and looks: [from, to] (global).
func pose_of(n: int) -> Array:
	var floor_y: float = spots.floor_y
	var centre: Vector3 = spots.centre
	match n:
		1:
			var at: Vector3 = spots.kelp
			return [at + Vector3(1.5, 1.0, 1.5), at + Vector3(0.5, 14.0, 0.0)]
		2:
			var at: Vector3 = spots.ruin
			return [at + Vector3(16.0, 6.0, 12.0), at + Vector3(0.0, 1.5, 0.0)]
		3:
			var at: Vector3 = spots.reef
			return [at + Vector3(3.5, 1.8, 3.5), at + Vector3(0.0, 0.7, 0.0)]
		4:
			var from := Vector3(centre.x, centre.y, centre.z)
			return [from, from + Vector3(100.0, 3.0, 0.0)]
		_:
			var from := Vector3(centre.x - 30.0, floor_y + 0.8, centre.z)
			return [from, from + Vector3(80.0, 0.3, 0.0)]


func _find_spots() -> void:
	var seabed: Seabed = run.seabed
	var base := seabed.global_position
	spots.floor_y = base.y
	spots.centre = run.centre
	var reach := seabed.radius * 0.8
	var best_kelp := -1.0
	var best_reef := -1
	var kelp := Vector2.ZERO
	var reef := Vector2.ZERO
	var x := -reach
	while x <= reach:
		var z := -reach
		while z <= reach:
			var p := Vector2(x, z)
			if p.length() < reach and p.length() > 30.0:
				var k: float = 0.0  # the patch's average, so the camera stands in a forest, not at its edge
				for d in [Vector2.ZERO, Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
					k += seabed._kelp_noise.get_noise_2dv(p + d) * 0.2
				if k > best_kelp and seabed._clear_of_ruins(p, 10.0):
					best_kelp = k
					kelp = p
				if seabed.is_reef(p) and seabed._clear_of_ruins(p, 10.0):
					var around := 0
					for d in [Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4), Vector2(4, 4), Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 4)]:
						if seabed.is_reef(p + d):
							around += 1
					if around > best_reef:
						best_reef = around
						reef = p
			z += 5.0
		x += 5.0
	var crowd := 0  # blade kelp: the column with the most columns within 8 m, so the camera stands in a forest
	for c in seabed.kelp_spots:
		if c.length() < 30.0 or c.length() > reach or not seabed._clear_of_ruins(c, 10.0):
			continue
		var near := 0
		for o in seabed.kelp_spots:
			if c.distance_squared_to(o) < 64.0:
				near += 1
		if near > crowd:
			crowd = near
			kelp = c
	spots.kelp = base + Vector3(kelp.x, 0.0, kelp.y)
	spots.reef = base + Vector3(reef.x, 0.0, reef.y)
	var ruin := Vector3(40.0, 0.0, 40.0)
	if not seabed.cluster_spots.is_empty():
		ruin = seabed.cluster_spots[0]
	spots.ruin = base + Vector3(ruin.x, 0.0, ruin.z)


func _split(look: WaterLook) -> void:
	var local: LocalCoop = main._local
	while local.count() < look.tank_split_players:
		local.join(FIRST_PAD + local.count())
	camera.current = false
	var places: Array = [spots.ruin + Vector3(14.0, 4.0, 10.0), spots.reef + Vector3(4.0, 2.0, 4.0), spots.kelp + Vector3(1.5, 1.0, 1.5),
			spots.centre + Vector3(-30.0, spots.floor_y - spots.centre.y + 1.5, 0.0)]
	var looks: Array = [spots.ruin + Vector3(0.0, 1.5, 0.0), spots.reef, spots.kelp + Vector3(0.0, 6.0, 0.0), spots.centre + Vector3(40.0, 0.0, 0.0)]
	for slot in local.slots:
		if slot.index >= places.size():
			continue
		var at: Vector3 = places[slot.index]
		var basis := Basis.looking_at((looks[slot.index] as Vector3) - at, Vector3.UP)
		slot.fish.freeze = false  # a frozen fish ignores its reset
		slot.fish.set_spawn(Transform3D(basis, at))
	_set_huds(look.tank_hud)
	for i in 4:
		await get_tree().physics_frame
	for slot in local.slots:
		slot.fish.freeze = true
		slot.fish.set_spawn(slot.fish.global_transform)


func _leave_split() -> void:
	var local: LocalCoop = main._local
	if local.count() > 1:
		local.drop_extras()


func _set_huds(shown: bool) -> void:
	var huds: Array = [main._hud, main._unnatural_hud]
	for slot in main._local.slots:
		huds.append(slot.hud)
		huds.append(slot.mode_hud)
	for node: Node in huds:
		if node != null and "visible" in node:
			node.visible = shown
