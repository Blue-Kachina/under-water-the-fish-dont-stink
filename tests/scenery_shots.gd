extends Node
## Not a probe: screenshots of Unnatural's scenery and HUD for checking by eye
## (planning_environment.md). Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/scenery_shots.tscn -- --out=DIR [--what=hud,shrines,ruins,reef,fx] [--clear]
## --what picks the sets (default: all); --clear turns the murk off.
## - hud: the compass strip and ring, with a boss, chests, a teammate-less run;
## - shrines: each of the four temples up close, then from 40 m and 80 m in the murk;
## - ruins: the ruin clusters and rubble from swimming height;
## - reef: the reef, kelp forests and sea grass at a few spots, and a wide view;
## - rift: the boss rift up close, looking down into it, from 20 m and 40 m,
##   erupting and cold, and the HUD with its marker;
## - fx: the hazards (fire, shock, haze), the Tsunami Heart's wave, the whirlpool, the drops, the chests.

var out_dir := "user://scenery_shots"
var what := ["hud", "shrines", "ruins", "reef", "pieces", "fx", "worn", "rift"]
var clear := false
var main: Node
var fish: FishController
var run: UnnaturalRun
var camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--what="):
			what = Array(arg.trim_prefix("--what=").split(","))
		elif arg == "--clear":
			clear = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	settings.spawning = false
	settings.enemy_speed_scale = 0.0
	settings.god_mode = true
	settings.shrine_reveal_range = 0.0
	if clear:
		settings.murk_density = 0.0
	main.set_mode(main.UNNATURAL)
	await _frames(5)
	main._match_card.play_requested.emit()
	await _frames(10)
	run = main.unnatural_run
	run.start()
	await _frames(20)
	fish.freeze = true
	if "hud" in what:
		await _hud()
	if "shrines" in what:
		await _shrines()
	if "ruins" in what:
		await _ruins()
	if "reef" in what:
		await _reef()
	if "pieces" in what:
		await _pieces()
	if "fx" in what:
		await _fx()
	if "worn" in what:
		await _worn()
	if "rift" in what:
		await _rift()
	get_tree().quit()


func _hud() -> void:
	var ahead := -fish.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var side := Vector3.UP.cross(ahead)
	run.add_chest(fish.global_position + side * 12.0 + ahead * 6.0, 0.0)
	run.add_chest(fish.global_position - side * 20.0 - ahead * 4.0, 0.0, -INF, TreasureChest.Kind.CURSED)
	run._start_event("miniboss")
	await _seconds(1.5)
	await _shot("hud_compass")


func _shrines() -> void:
	_free_camera()
	for shrine in run.shrines:
		if not is_instance_valid(shrine):
			continue
		var at := shrine.global_position
		var name_now := (Shrine.NAMES[shrine.kind] as String).to_snake_case().replace("shrine_of_the_", "").replace("shrine_of_", "")
		_look(at + Vector3(9.0, 4.5, 9.0), at + Vector3(0.0, 2.2, 0.0))
		await _seconds(0.4)
		await _shot("shrine_%s_near" % name_now)
		_look(at + Vector3(0.0, 2.5, 4.5), at + Vector3(0.0, 2.6, 0.0))
		await _seconds(0.2)
		await _shot("shrine_%s_statue" % name_now)
		if shrine.kind == Shrine.Kind.TIDE:
			for far: float in [40.0, 80.0]:
				_look(at + Vector3(far, 4.0, 0.0), at + Vector3(0.0, 2.0, 0.0))
				await _seconds(0.3)
				await _shot("shrine_from_%dm" % roundi(far))
	_end_camera()


func _ruins() -> void:
	_free_camera()
	var spots: Array = run.seabed.cluster_spots if is_instance_valid(run.seabed) and "cluster_spots" in run.seabed else []
	var n := 0
	for spot: Vector3 in spots:
		var at := run.seabed.global_position + spot
		_look(at + Vector3(16.0, 6.0, 12.0), at + Vector3(0.0, 1.5, 0.0))
		await _seconds(0.3)
		await _shot("ruins_%d" % n)
		n += 1
	_look(run.centre + Vector3(30.0, 3.0, 30.0), run.centre + Vector3(0.0, 0.0, 0.0))
	await _seconds(0.3)
	await _shot("rubble")
	_end_camera()


func _reef() -> void:
	_free_camera()
	var floor_y := run.seabed.global_position.y if is_instance_valid(run.seabed) else run.centre.y
	for n in 4:
		var at := run.centre + Vector3.FORWARD.rotated(Vector3.UP, n * 1.7) * (25.0 + 22.0 * n)
		at.y = floor_y
		_look(at + Vector3(6.0, 3.0, 6.0), at + Vector3(-4.0, 1.0, -4.0))
		await _seconds(0.3)
		await _shot("reef_%d" % n)
	_look(run.centre + Vector3(0.0, 22.0, 60.0), run.centre + Vector3(0.0, 0.0, -20.0))
	await _seconds(0.3)
	await _shot("reef_wide")
	_end_camera()


## Every reef and Greek piece in a row on a cleared patch, side-on and from above.
func _pieces() -> void:
	_free_camera()
	var base := Vector3(run.centre.x, run.seabed.global_position.y, run.centre.z) + Vector3(0.0, 0.0, 30.0)
	run.seabed.clear_around(base, 16.0)
	var row := Node3D.new()
	run.add_child(row)
	var names := ["boulder", "slab", "staghorn", "brain", "table", "fan", "tube_sponge", "barrel", "anemone", "starfish", "urchin", "clam", "seagrass"]
	var x := -14.0
	for piece: String in names:
		var shown := MeshInstance3D.new()
		shown.mesh = ReefKit.mesh(piece, 0)
		row.add_child(shown)
		shown.global_position = base + Vector3(x, 0.0, 0.0)
		x += 2.3
	var greek: Array[Mesh] = [GreekKit.cached("rubble/drum/1", Callable(), null), GreekKit.cached("rubble/capital", Callable(), null),
			GreekKit.cached("rubble/amphora", Callable(), null), GreekKit.cached("rubble/krater", Callable(), null)]
	x = -6.0
	for mesh in greek:
		var shown := MeshInstance3D.new()
		shown.mesh = mesh
		row.add_child(shown)
		shown.global_position = base + Vector3(x, 0.0, -5.0)
		x += 3.0
	_look(base + Vector3(-8.0, 2.0, 7.0), base + Vector3(-8.0, 0.6, 0.0))
	await _seconds(0.4)
	await _shot("pieces_left")
	_look(base + Vector3(9.0, 2.0, 7.0), base + Vector3(9.0, 0.6, 0.0))
	await _seconds(0.3)
	await _shot("pieces_right")
	_look(base + Vector3(0.0, 2.5, 2.0), base + Vector3(0.0, 0.6, -5.0))
	await _seconds(0.3)
	await _shot("pieces_greek")
	row.queue_free()
	_end_camera()


func _fx() -> void:
	_free_camera()
	var at := run.centre + Vector3(0.0, run.settings.arena_floor + 1.0, 0.0) - Vector3(0.0, run.centre.y, 0.0)
	at = Vector3(run.centre.x, run.seabed.global_position.y + 0.2, run.centre.z) if is_instance_valid(run.seabed) else run.centre
	var fire := run._hazard(at + Vector3(-7.0, 0.0, 0.0), 3.0, 30.0, 0.0, Color(1.0, 0.45, 0.08, 0.35), UnnaturalRun.BURN_CAUSE)
	var shock := run._hazard(at + Vector3(0.0, 1.0, 0.0), 3.0, 30.0, 0.0, Color(0.45, 0.8, 1.0, 0.4), "an electric elite's shock")
	shock.delay = 30.0
	var haze := run._hazard(at + Vector3(7.0, 1.0, 0.0), 3.0, 30.0, 0.0, Color(0.6, 0.3, 0.75, 0.3), UnnaturalRun.SOUR_CAUSE, true)
	_look(at + Vector3(0.0, 6.0, 14.0), at + Vector3(0.0, 1.0, 0.0))
	await _seconds(0.6)
	await _shot("fx_hazards")
	for cloud in [fire, shock, haze]:
		if is_instance_valid(cloud):
			cloud.queue_free()
	var kinds := [Pickup.Kind.HEART, Pickup.Kind.MAGNET, Pickup.Kind.HOURGLASS, Pickup.Kind.LIGHTNING]
	var drops := []
	for n in kinds.size():
		var drop := run.drop_pickup(kinds[n], at + Vector3((n - 1.5) * 2.5, 1.2, 0.0))
		if drop:
			drops.append(drop)
	_look(at + Vector3(0.0, 2.5, 7.0), at + Vector3(0.0, 1.2, 0.0))
	await _seconds(0.5)
	await _shot("fx_drops")
	for drop in drops:
		if is_instance_valid(drop):
			drop.queue_free()
	var kinds_chest := [TreasureChest.Kind.TREASURE, TreasureChest.Kind.CURSED, TreasureChest.Kind.BOSS]
	var chests := []
	for n in 3:
		chests.append(run.add_chest(at + Vector3((n - 1) * 3.0, -0.2, 0.0), 0.3))
		(chests[n] as TreasureChest).kind = kinds_chest[n]
	_look(at + Vector3(1.5, 2.2, 5.0), at + Vector3(0.0, 0.4, 0.0))
	await _seconds(0.3)
	await _shot("fx_chests")
	var pool := Whirlpool.new()
	run.add_child(pool)
	pool.global_position = at + Vector3(0.0, -0.2, -20.0)
	_look(at + Vector3(0.0, 8.0, 12.0), at + Vector3(0.0, 6.0, -20.0))
	await _seconds(0.8)
	await _shot("fx_whirlpool")
	pool.queue_free()
	# The wave's look alone (a live Wave needs its heart and frees itself without one).
	var wave := MeshInstance3D.new()
	wave.mesh = TsunamiHeart.Wave.curl_mesh(8.0)
	var water := ShaderMaterial.new()
	water.shader = preload("res://shaders/wave.gdshader")
	wave.material_override = water
	run.add_child(wave)
	wave.global_position = at + Vector3(0.0, 2.0, -4.0)
	wave.look_at(wave.global_position + Vector3.FORWARD, Vector3.UP)
	_look(at + Vector3(9.0, 4.0, 4.0), at + Vector3(0.0, 2.0, -4.0))
	await _seconds(0.4)
	await _shot("fx_tsunami")
	wave.queue_free()
	_end_camera()


## The worn looks (Powerup.make_worn) on the fish, a few items at a time.
func _worn() -> void:
	_free_camera()
	var groups := [["ammonite_spiral", "anglerfish_lure", "bioluminescence", "bow_grow_bow", "chain_lightning", "momentum_fin"],
			["clam_shield", "electric_eel", "ghost_swordfish", "sticky_anemone", "ink_sac", "megalodon_tooth"],
			["cold_seep", "krakens_grasp", "lamprey", "moon_pearl", "poseidons_trident", "treasure_map"],
			["pufferfish_spines", "reef_guardian", "riptide", "sonar_pinger", "torpedo", "abyssal_engine"],
			["barnacle_plating", "hermit_shell", "speedy_seahorse", "tsunami_heart", "whirlpool_charm", "sea_salt"],
			["blood_moon_shard", "sirens_song", "abyssal_hunger", "sunken_idol", "fizzy_soda"],
			["glass_coral", "remora_buddy", "attack_greek_fire", "attack_jellyfish_halo", "attack_purple_haze"]]
	var powers := run.powerups_of(fish)
	for n in groups.size():
		powers.clear()
		for id: String in groups[n]:
			if Powerup.INFO.has(id):
				powers.add(id)
		powers.refresh()
		await _seconds(0.3)
		var at := fish.global_position
		var side := fish.global_basis.x
		_look(at + side * 2.6 + Vector3.UP * 1.0 - fish.global_basis.z * 0.6, at)
		await _seconds(0.2)
		await _shot("worn_%d" % n)
	powers.clear()
	_end_camera()


func _rift() -> void:
	var rift := run.rift
	if not is_instance_valid(rift):
		print("no rift")
		return
	fish.freeze = false
	fish.global_position = rift.to_global(Vector3(0.0, 4.0, 14.0))
	fish.freeze = true
	await _seconds(0.6)
	await _shot("rift_hud")
	_free_camera()
	var mid := rift.global_position
	_look(rift.to_global(Vector3(5.0, 3.5, 6.0)), mid + Vector3(0.0, 0.3, 0.0))
	await _seconds(0.5)
	await _shot("rift_near")
	_look(rift.to_global(Vector3(-0.4, 3.2, 1.6)), rift.to_global(Vector3(-0.4, -1.0, 0.0)))
	await _seconds(0.3)
	await _shot("rift_into")
	_look(rift.to_global(Vector3(-0.3, 1.4, 0.9)), rift.to_global(Vector3(-0.4, -3.0, -0.2)))
	await _seconds(0.3)
	await _shot("rift_into_close")
	for far: float in [20.0, 40.0]:
		_look(rift.to_global(Vector3(far * 0.6, 4.0, far * 0.8)), mid + Vector3(0.0, 0.5, 0.0))
		await _seconds(0.3)
		await _shot("rift_from_%dm" % roundi(far))
	_look(rift.to_global(Vector3(8.0, 5.0, 10.0)), mid + Vector3(0.0, 2.0, 0.0))
	rift.erupt()
	await _seconds(0.5)
	await _shot("rift_erupt")
	rift.spent = true
	await _seconds(4.5)
	_look(rift.to_global(Vector3(5.0, 3.5, 6.0)), mid + Vector3(0.0, 0.3, 0.0))
	await _seconds(0.2)
	await _shot("rift_cold")
	_end_camera()


func _free_camera() -> void:
	if camera == null:
		camera = Camera3D.new()
		camera.fov = 70.0
		add_child(camera)
	camera.current = true


func _end_camera() -> void:
	if camera:
		camera.current = false


func _look(from: Vector3, to: Vector3) -> void:
	camera.global_position = from
	camera.look_at(to, Vector3.UP)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % shot_name))
	print("shot ", shot_name)


func _seconds(s: float) -> void:
	var left := s
	while left > 0.0:
		await RenderingServer.frame_post_draw
		left -= get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
