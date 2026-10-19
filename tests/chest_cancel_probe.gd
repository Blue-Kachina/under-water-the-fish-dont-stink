extends Node
## Backing out of a chest (refining_weaponry.md §2.2): B on a chest's cards puts
## it back: the pearls return, the chest is shut for you again, and opening it
## again offers the very same cards (no free rerolls). Once a card's taken it's
## final, and the chest goes.
##   Godot_console.exe --headless --path . res://tests/chest_cancel_probe.tscn

var failures := 0
var main: Node
var fish: FishController
var run: UnnaturalRun
var settings := UnnaturalSettings.shared()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	settings.spawning = false
	settings.twists = false
	settings.card_choices = 0
	settings.enemy_speed_scale = 0.0
	settings.enemy_damage_scale = 0.0
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	var offers := []
	run.cards_offered.connect(func(_f: FishController, cards: Array, heading: String, _line: String) -> void: offers.append([cards, heading]))

	var chest: TreasureChest = run.chests[0]
	run.add_pearls(fish, 500)
	var price := run.chest_price(chest, fish)
	var purse := run.purse_of(fish)
	check(price > 0, "the chest costs pearls (%d)" % price)
	run.open_chest(chest, fish)
	await _ticks(2)
	check(offers.size() == 1 and chest.is_open_for(fish) and run.purse_of(fish) == purse - price, "opened: cards up, %d pearls paid" % price)
	check(run.can_cancel(fish), "and it can be put back")
	var first_ids: Array = (offers[0][0] as Array).map(func(c: Dictionary) -> String: return c.powerup)
	run.cancel_offer(fish)
	await _ticks(2)
	check(run.purse_of(fish) == purse and not chest.is_open_for(fish) and not run.is_picking(fish), "cancelled: pearls back, shut for me again, no pick")
	check(not get_tree().paused and run.stats_of(fish).get("chests", 0) == 0 and run.stats_of(fish).get("paid_chests", 0) == 0, "the game runs on, the chest uncounted")
	check(not chest.is_queued_for_deletion() and chest in run.shut_chests_for(fish), "the chest is still there to open")
	offers.clear()
	run.open_chest(chest, fish)
	await _ticks(2)
	var again_ids: Array = (offers[0][0] as Array).map(func(c: Dictionary) -> String: return c.powerup) if offers.size() else []
	check(again_ids == first_ids and run.purse_of(fish) == purse - price, "opened again: the same cards %s, paid again" % [again_ids])
	run.pick(fish, 0)
	await _ticks(2)
	check(not run.can_cancel(fish) and run.stats_of(fish).get("chests", 0) == 1, "after a pick: final")
	var after := run.purse_of(fish)
	run.cancel_offer(fish)
	check(run.purse_of(fish) == after, "cancel does nothing now")
	await _ticks(2)
	check(chest._vanished or chest.is_queued_for_deletion(), "the chest goes once its card's taken")

	print("failures: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)
