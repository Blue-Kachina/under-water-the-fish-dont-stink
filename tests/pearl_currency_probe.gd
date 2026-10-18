extends Node
## Unnatural's XP on kill and pearls as currency (planning_unnatural.md,
## Playability pass P1e, D22, D23): a kill's XP lands at once, with no pickup,
## times the killer's XP Gain; pearls drop by chance (pearl_drop_chance x 1 +
## Pearl Chance, an elite's always, worth pearl_elite_value), and a taken
## pearl goes in the taker's purse; a beaten mini-boss drops boss_pearls; a
## chest's price follows the formula, a chest won't open short of pearls, and
## opening one pays for it; chest_cost off makes them free.
##   Godot_console.exe --headless --path . res://tests/pearl_currency_probe.tscn

var failures := 0
var main: Node
var fish: FishController


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var settings := UnnaturalSettings.shared()
	settings.spawning = false
	settings.fish_attack = FishAttack.Kind.BITE
	settings.twists = false
	settings.enemy_speed_scale = 0.0
	settings.card_choices = 0  # no cards in the way
	settings.chest_count = 0
	settings.chest_interval = 0.0
	settings.chest_drop_chance = 0.0
	settings.heart_chance = 0.0
	settings.magnet_chance = 0.0
	settings.hourglass_chance = 0.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	fish.character = FishCharacter.Family.DOMINUS
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	var far := run.centre + Vector3(0, 0, -120)

	print("xp on kill:")
	settings.pearl_drop_chance = 0.0
	var kind := run.horde.kinds[1]
	var before := run.levels.total_xp
	var target := run.horde.spawn(1, far)
	run.hit(target, 1e6, fish, "test")
	await _ticks(1)
	check(is_equal_approx(run.levels.total_xp - before, kind.xp * settings.xp_gain), "a kill's XP lands at once (+%.1f)" % (run.levels.total_xp - before))
	check(run.pearls_out.is_empty(), "with pearl_drop_chance 0, no pearl")
	run.block_of(fish).add("xp_gain", 0.5)
	before = run.levels.total_xp
	target = run.horde.spawn(1, far)
	run.hit(target, 1e6, fish, "test")
	await _ticks(1)
	check(is_equal_approx(run.levels.total_xp - before, kind.xp * 1.5 * settings.xp_gain), "the killer's XP Gain counts (+50%%: +%.1f)" % (run.levels.total_xp - before))
	run.block_of(fish).add("xp_gain", -0.5)

	print("pearl drops:")
	var dropped := [0]
	run.pearl_dropped.connect(func(_id: int, _at: Vector3, _value: int) -> void: dropped[0] += 1)
	settings.pearl_drop_chance = 0.2
	for n in 4000:
		run._roll_pearl(far, fish, false, 100000 + n)
	var share: float = dropped[0] / 4000.0
	check(absf(share - 0.2) < 0.025, "4,000 kills drop pearls at pearl_drop_chance (%.3f)" % share)
	dropped[0] = 0
	run.block_of(fish).add("pearl_chance", 1.0)
	for n in 4000:
		run._roll_pearl(far, fish, false, 200000 + n)
	share = dropped[0] / 4000.0
	check(absf(share - 0.4) < 0.03, "Pearl Chance +100%% doubles it (%.3f)" % share)
	run.block_of(fish).add("pearl_chance", -1.0)
	for pearl in run.pearls_out:
		pearl.queue_free()
	await _ticks(1)
	settings.pearl_drop_chance = 0.0
	target = run.horde.spawn(1, far, Vector3.ZERO, true)
	run.hit(target, 1e9, fish, "test")
	await _ticks(1)
	check(run.pearls_out.size() == 1 and roundi(run.pearls_out[0].value) == settings.pearl_elite_value,
			"an elite always drops one, worth %d" % settings.pearl_elite_value)

	print("taking pearls:")
	var purse := run.purse_of(fish)
	var pearl: Pearl = run.pearls_out[0]
	pearl.global_position = fish.global_position
	for n in 120:
		await get_tree().physics_frame
		if not is_instance_valid(pearl) or pearl.is_queued_for_deletion():
			break
	check(run.purse_of(fish) == purse + settings.pearl_elite_value, "a taken pearl goes in the purse (%d -> %d)" % [purse, run.purse_of(fish)])
	check(run.stats_of(fish).pearls >= settings.pearl_elite_value, "and on the board")

	print("chest prices:")
	settings.chest_cost = true
	settings.chest_price_base = 10.0
	settings.chest_price_growth = 0.5
	run.elapsed = 120.0
	var chest := run.add_chest(fish.global_position + Vector3(0, -1, -3), 0.0)
	check(run.chest_price(chest) == 20, "the price: base x (1 + growth x minutes) (%d at 2:00)" % run.chest_price(chest))
	var cursed := run.add_chest(far + Vector3(10, 0, 0), 0.0, -INF, TreasureChest.Kind.CURSED)
	check(run.chest_price(cursed) == 30, "a cursed one's x chest_cursed_price (%d)" % run.chest_price(cursed))
	var boss := run.add_chest(far + Vector3(20, 0, 0), 0.0, -INF, TreasureChest.Kind.BOSS, "drowned_fin")
	check(run.chest_price(boss) == 0, "a boss's is free")
	run._purses[fish] = 5
	fish.global_position = chest.global_position + Vector3(0, 1, 2)
	fish.linear_velocity = Vector3.ZERO
	for n in roundi(settings.chest_open_time * 120.0) + 60:
		await get_tree().physics_frame
	check(not chest.is_open_for(fish) and run.purse_of(fish) == 5, "short of pearls, holding still doesn't open it")
	run._purses[fish] = 25
	for n in roundi(settings.chest_open_time * 120.0) + 60:
		await get_tree().physics_frame
		if chest.is_open_for(fish):
			break
	check(chest.is_open_for(fish) and run.purse_of(fish) == 5, "with the pearls it opens, and costs 20 (%d left)" % run.purse_of(fish))
	settings.chest_cost = false
	check(run.chest_price(cursed) == 0, "chest_cost off: free")
	settings.chest_cost = true

	print("the mini-boss:")
	for p in run.pearls_out:
		p.queue_free()
	await _ticks(1)
	var shark := DrownedShark.new()
	run._add_boss(shark, far, 10.0)
	await _ticks(2)
	before = run.levels.total_xp
	shark.defeat(fish)
	await _ticks(3)
	check(run.pearls_out.size() == settings.boss_pearls, "a beaten mini-boss spills %d pearls (%d out)" % [settings.boss_pearls, run.pearls_out.size()])
	check(run.levels.total_xp - before >= settings.shark_xp * settings.xp_gain - 0.01, "and its XP lands at once")

	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
