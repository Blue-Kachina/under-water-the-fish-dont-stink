extends Node
## Not a probe: screenshots of Unnatural's feel pass (the Playability pass, P3)
## for checking it by eye: damage numbers (crits gold) and kill pops over a
## pack ahead, the target bracket; a swordfish's lunge lane and the Drowned
## Shark's charge lane; threat arrows (an elite and the shark behind) and drop
## beams and pings; the hurt vignette at low hp. Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/feel_shots.tscn -- --out=DIR

var out_dir := "user://feel_shots"
var main: Node
var fish: FishController
var run: UnnaturalRun
var horde: Horde


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 900)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	settings.spawning = false
	settings.stage_events = false
	settings.chest_count = 0
	settings.chest_interval = 0.0
	settings.card_choices = 0
	settings.enemy_speed_scale = 0.0
	settings.enemy_damage_scale = 0.0
	settings.bite_damage = 0.0
	settings.fish_attack = FishAttack.Kind.BITE
	settings.god_mode = true
	settings.enemy_hp_scale = 50.0
	settings.pearl_drop_chance = 0.0
	settings.chest_drop_chance = 0.0
	settings.xp_base = 1.0e9  # no level-up splash over the shots
	main.set_mode(main.UNNATURAL)
	await _frames(5)
	main._match_card.play_requested.emit()
	await _frames(10)
	run = main.unnatural_run
	horde = run.horde
	run.start()
	await _frames(20)
	fish.freeze = true
	var ahead := -fish.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var side := Vector3.UP.cross(ahead)
	await _seconds(0.5)

	# 1. Numbers and pops: a pack ahead, hit over and over, some crits, a few killed.
	var pack := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for n in 24:
		var at := fish.global_position + ahead * rng.randf_range(6.0, 16.0) + side * rng.randf_range(-7.0, 7.0) + Vector3.UP * rng.randf_range(-1.5, 2.0)
		pack.append(horde.spawn(n % 3, at, -ahead, n == 5))
	await _seconds(0.3)
	for round_n in 6:
		run.block_of(fish).add("crit_chance", 0.35 if round_n == 0 else 0.0)
		for k in range(0, pack.size(), 2):
			if horde.is_alive(pack[k]):
				run.hit(pack[k], rng.randf_range(8.0, 140.0), fish, "bite")
		await _seconds(0.12)
	for k in [1, 3, 7, 9, 13]:
		run.hit(pack[k], 1.0e7, fish, "bite")
	await _seconds(0.08)
	await _shot("numbers_pops")
	await _seconds(0.6)
	horde.clear()
	run.block_of(fish).add("crit_chance", -0.35)

	# 1b. Just the pops, close: a pack 5 to 9 m ahead all killed at once.
	settings.damage_numbers = false
	pack.clear()
	for n in 10:
		var at := fish.global_position + ahead * rng.randf_range(5.0, 9.0) + side * rng.randf_range(-4.0, 4.0) + Vector3.UP * rng.randf_range(0.0, 2.0)
		pack.append(horde.spawn(n % 3, at, -ahead, n == 2))
	await _seconds(0.3)
	for i: int in pack:
		run.hit(i, 1.0e7, fish, "bite")
	await _seconds(0.14)
	await _shot("pops")
	settings.damage_numbers = true
	await _seconds(0.5)
	horde.clear()

	# 2. Lanes: a swordfish winding up from the right, the shark winding up its charge ahead.
	var lunger := horde.spawn(3, fish.global_position + ahead * 12.0 + side * 9.0, -side)
	horde._mode[lunger] = Horde.Lunge.TELEGRAPH
	horde._mode_left[lunger] = 100.0
	horde._lunge[lunger] = (fish.global_position - horde._position[lunger]).normalized()
	horde._target[lunger] = 0
	var shark := DrownedShark.new()
	run._add_boss(shark, fish.global_position + ahead * 70.0 - side * 25.0, 10000.0)
	await _seconds(0.3)
	shark.mode = DrownedShark.Mode.TELEGRAPH
	shark._mode_left = 0.5
	shark._charge_dir = (fish.global_position - shark.global_position).normalized()
	settings.shark_telegraph = 1.0
	await _seconds(0.25)
	await _shot("lanes")
	shark.mode = DrownedShark.Mode.HUNT
	shark._charge_left = 100.0

	# 3. Threats and drops: an elite behind, the shark off to the side; drops round about.
	horde.clear()
	horde.spawn(1, fish.global_position - ahead * 25.0 + side * 6.0, ahead, true)
	shark.global_position = fish.global_position - ahead * 50.0 - side * 40.0
	run.drop_pickup(Pickup.Kind.HEART, fish.global_position + ahead * 25.0 + side * 8.0)
	run.drop_pickup(Pickup.Kind.MAGNET, fish.global_position + ahead * 45.0 - side * 12.0)
	run.drop_pickup(Pickup.Kind.HOURGLASS, fish.global_position + side * 30.0 - ahead * 5.0)
	run.drop_pickup(Pickup.Kind.LIGHTNING, fish.global_position + ahead * 70.0 + side * 25.0)
	await _seconds(0.5)
	await _shot("threats_drops")

	# 4. Low hp: the heartbeat on its beat, just after a hit.
	settings.god_mode = false
	var health := run.health_of(fish)
	health.hp = health.max_hp * 0.12
	var hud := main._unnatural_hud as UnnaturalHud
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and hud.beat_level < 0.75:
		await _frames(1)
	await _shot("low_hp")
	settings.god_mode = true
	health.hp = health.max_hp
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % shot_name))
	print("shot ", shot_name)


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
