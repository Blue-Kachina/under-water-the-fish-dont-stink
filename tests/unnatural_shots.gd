extends Node
## Not a probe: screenshots of Unnatural for checking it by eye: the arena
## under the blood moon, a horde closing in, the ghost bite mid-snap, the
## level-up cards, a chest's powerup pick, the powerups at work (fire trail,
## lightning, torpedoes, the bow), the results board, and the Test Tank's
## readout. Needs a window (not --headless).
##   Godot_console.exe --path . res://tests/unnatural_shots.tscn -- --out=DIR

var out_dir := "user://unnatural_shots"
var main: Node
var fish: FishController


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # through the cards' pause
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
	var powers := PowerupSettings.shared()
	settings.spawning = false
	settings.fish_attack = FishAttack.Kind.BITE  # these checks are the bite's (attack_probe has the rest)
	settings.twists = false  # and no fish's twist skews them
	main.set_mode(main.UNNATURAL)
	await _frames(5)
	main._match_card.play_requested.emit()
	await _frames(10)
	var run: UnnaturalRun = main.unnatural_run
	var horde := run.horde
	fish.character = FishCharacter.FishClass.HUNTER
	run.start()
	await _frames(20)
	await _shot("arena")

	# A horde closing in from ahead, the fish held still.
	fish.freeze = true
	settings.bite_damage = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for n in 260:
		var spot := Vector3(rng.randf_range(-12, 12), rng.randf_range(-4, 4), rng.randf_range(-40, -14))
		horde.spawn(0 if n % 3 else 1 + n % 4, fish.global_position + spot, Vector3.BACK, n % 37 == 0)
	await _seconds(1.6)
	await _shot("horde")

	# The ghost bite, caught mid-snap.
	settings.bite_damage = 30.0
	settings.enemy_speed_scale = 0.0
	var bite := run.bite_of(fish)
	bite.cooldown_left = 0.0
	for i in 200:
		await get_tree().physics_frame
		if bite._age >= GhostBite.OPEN_TIME * 0.9:
			break
	await _shot("bite")

	# Level-up cards.
	run.levels.add(run.levels.xp_to_next())
	await _seconds(0.5)
	await _shot("cards")
	run.pick(fish, 0)
	await _frames(3)

	# A chest's powerup pick.
	run.open_chest(run.shut_chests()[0], fish)
	await _seconds(0.5)
	await _shot("chest_pick")
	run.pick(fish, 0)
	await _frames(3)

	# The powerups at work: fire behind, lightning and torpedoes in the crowd, the bow on.
	powers.fire_stacks = 2
	powers.lightning_stacks = 2
	powers.torpedo_stacks = 3
	powers.bow_stacks = 2
	powers.lightning_chance = 1.0
	powers.torpedo_chance = 0.6
	settings.enemy_speed_scale = 0.4
	fish.freeze = false
	for t in 120 * 2:
		fish.linear_velocity = -fish.global_basis.z * 8.0
		await get_tree().physics_frame
	await _seconds(0.25)
	await _shot("powerups")
	powers.lightning_chance = 0.15
	powers.torpedo_chance = 0.08

	# A chest on the seabed, close up.
	var chest: TreasureChest = run.shut_chests()[0]
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), chest.global_position + Vector3(0, 2.5, 7.0)))
	await _frames(3)
	fish.freeze = true
	main.get_node("FollowCamera").snap()
	await _seconds(0.6)
	await _shot("chest")

	# Hurt, then overrun: the results board.
	powers.fire_stacks = 0
	powers.lightning_stacks = 0
	powers.torpedo_stacks = 0
	powers.bow_stacks = 0
	settings.enemy_speed_scale = 1.0
	for n in 60:
		horde.spawn(1, fish.global_position + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)))
	var health := run.health_of(fish)
	health.hp = 1.0
	health.iframes_left = 0.0
	for i in 600:
		await get_tree().physics_frame
		if run.is_over:
			break
	await _seconds(UnnaturalHud.OVER_SPLASH + 0.6)
	await _shot("results")

	# The Test Tank's readout.
	main.set_mode(main.TEST_TANK)
	await _frames(5)
	main._match_card.play_requested.emit()
	await _frames(10)
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), Vector3(0, 0, -12)))
	await _frames(3)
	fish.freeze = true
	powers.lightning_stacks = 1
	await _seconds(4.0)
	await _shot("test_tank")
	powers.lightning_stacks = 0
	get_tree().quit()


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
