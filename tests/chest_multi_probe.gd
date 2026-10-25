extends Node
## Several chests in reach (planning_environment.md, Phase 1, E7): holding
## still fills every chest in reach together; Jump opens the closest; taking
## its pick opens the next unlocked one still in reach (chest_chain_open);
## putting a chest back (B) doesn't chain; with chest_chain_open off, the next
## waits for Jump.
##   Godot_console.exe --headless --path . res://tests/chest_multi_probe.tscn

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
	settings.card_choices = 0
	settings.chest_count = 0
	settings.chest_interval = 0.0
	settings.chest_drop_chance = 0.0
	settings.chest_cost = false
	settings.chest_chain_open = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	await _ticks(3)
	fish.character = FishCharacter.FishClass.HUNTER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	var base := fish.global_position + Vector3(0.0, -1.0, 0.0)
	var chests: Array[TreasureChest] = [
		run.add_chest(base + Vector3(0.0, 0.0, -2.0), 0.0),
		run.add_chest(base + Vector3(3.0, 0.0, -2.0), 0.0),
		run.add_chest(base + Vector3(-4.5, 0.0, -2.5), 0.0),
	]
	var spot := fish.global_position

	print("counting down together:")
	var half := roundi(settings.chest_open_time * 0.5 * 120.0)
	for n in half:
		_hold(spot)
		await get_tree().physics_frame
	var all_filling := true
	for chest in chests:
		all_filling = all_filling and chest.progress_of(fish) > 0.2 and not chest.is_unlocked_for(fish)
	check(all_filling, "halfway, all three are filling (%.2f, %.2f, %.2f)" % [chests[0].progress_of(fish), chests[1].progress_of(fish),
			chests[2].progress_of(fish)])
	check(run.is_picking(fish), "while they fill, the fish is opening (untouchable)")
	for n in half + 30:
		_hold(spot)
		await get_tree().physics_frame
	check(chests.all(func(c: TreasureChest) -> bool: return c.is_unlocked_for(fish)), "then all three are unlocked")
	check(not run.is_picking(fish), "and the fish is free to swim")

	print("jump opens the closest, the pick chains on:")
	check(run.open_unlocked(fish), "Jump opens one")
	check(chests[0].is_open_for(fish) and not chests[1].is_open_for(fish), "the closest")
	await _ticks(2)
	run.pick(fish, 0)
	for n in 10:
		_hold(spot)
		await get_tree().physics_frame
	check(chests[1].is_open_for(fish), "taking its pick opens the next closest")
	check(not run.offer_of(fish).is_empty(), "and its cards are up")

	print("putting one back doesn't chain:")
	check(run.can_cancel(fish), "the second can be put back")
	run.cancel_offer(fish)
	for n in 20:
		_hold(spot)
		await get_tree().physics_frame
	check(not chests[2].is_open_for(fish), "the third stays shut")
	check(run.offer_of(fish).is_empty(), "no cards up")

	print("chest_chain_open off:")
	settings.chest_chain_open = false
	check(run.open_unlocked(fish), "Jump opens one")
	var first_open := chests[1].is_open_for(fish)
	await _ticks(2)
	run.pick(fish, 0)
	for n in 20:
		_hold(spot)
		await get_tree().physics_frame
	var opened := 0
	for chest in chests:
		if chest.is_open_for(fish):
			opened += 1
	check(first_open and opened == 2, "after its pick the last one waits for Jump (%d of 3 open)" % opened)
	settings.chest_chain_open = true

	print("swimming off resets a chest that hadn't unlocked:")
	var lone := run.add_chest(base + Vector3(60.0, 0.0, 0.0), 0.0)
	var there := lone.global_position + Vector3(0.0, 1.0, 2.0)
	for n in half:
		_hold(there)
		await get_tree().physics_frame
	var partway := lone.progress_of(fish)
	_hold(there + Vector3(40.0, 0.0, 0.0))
	await _ticks(3)
	check(partway > 0.2 and lone.progress_of(fish) == 0.0, "its countdown starts again (%.2f -> %.2f)" % [partway, lone.progress_of(fish)])

	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _hold(at: Vector3) -> void:
	fish.global_position = at
	fish.linear_velocity = Vector3.ZERO


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
