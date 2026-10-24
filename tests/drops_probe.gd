extends Node
## Unnatural's second play-test round (planning_unnatural.md "Round 2") in the
## real game:
## - XP pearls never fade; past max_pearls a drop merges into the nearest, which grows;
## - a kill can drop a chest that sinks to the seabed; chests offer powerups of
##   a rolled rarity (filling from below);
## - every chest is every player's: in split-screen one player opening it hides
##   it from their view alone (render layers), and the other can still open it;
## - drops: a heart heals, a magnet draws every pearl to the taker, an
##   hourglass stops every zombie (they don't bite meanwhile), a lightning bolt
##   kills every zombie in the arena (not a boss's body) and its kills drop nothing;
## - zombies spawned later are tougher and bigger (the difficulty level);
## - every powerup is worn on the fish;
## - the scoreboard shows your own stats beside it.
##   Godot_console.exe --headless --path . res://tests/drops_probe.tscn

const PADS := [11]

var main: Node
var fish: FishController
var run: UnnaturalRun
var settings := UnnaturalSettings.shared()
var powers := PowerupSettings.shared()
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	settings.spawning = false
	settings.stage_events = false
	settings.chest_count = 0
	settings.chest_interval = 0.0
	settings.enemy_speed_scale = 0.0
	settings.bite_damage = 0.0
	settings.battery_damage = 0.0
	settings.fish_attack = 2
	settings.twists = false
	settings.chest_drop_chance = 0.0
	settings.heart_chance = 0.0
	settings.magnet_chance = 0.0
	settings.hourglass_chance = 0.0
	settings.lightning_chance = 0.0
	settings.difficulty_per_minute = 0.0
	settings.card_choices = 0
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	var horde := run.horde
	fish.freeze = true

	print("pearls:")
	var away := fish.global_position + Vector3(40, 0, 0)
	run.drop_pearl(away, 3, 9001)
	await _ticks(2)
	var pearl := run.pearl_by_id(9001)
	pearl.age = 100000.0
	await _ticks(10)
	check(is_instance_valid(pearl) and run.pearl_by_id(9001) == pearl, "a pearl never fades")
	var cap := settings.max_pearls
	settings.max_pearls = run.pearls_out.size() + 1
	run.drop_pearl(away + Vector3(0, 0, 30), 3, 9002)
	await _ticks(1)
	run.drop_pearl(away + Vector3(0.5, 0, 0), 3, 9003)
	await _ticks(1)
	check(run.pearl_by_id(9003) == null and is_equal_approx(pearl.value, 6.0) and pearl.bulk > 1.0,
			"past the cap a drop merges into the nearest pearl, which grows (%.0f pearls, x%.2f)" % [pearl.value, pearl.bulk])
	settings.max_pearls = cap
	for p in run.pearls_out.duplicate():
		p.queue_free()
	await _ticks(2)

	print("chests from kills:")
	settings.chest_drop_chance = 1.0
	var chests_before := run.chests.size()
	var zombie := horde.spawn(1, fish.global_position + Vector3(0, 6, -12))
	run.hit(zombie, 1e6, fish, "probe")
	await _ticks(2)
	check(run.chests.size() == chests_before + 1, "a kill dropped a chest")
	var dropped: TreasureChest = run.chests[-1]
	await _seconds((dropped.position.y - dropped.sink_to) / TreasureChest.SINK_SPEED + 0.5)
	check(absf(dropped.position.y - dropped.sink_to) < 0.01, "it sank to the seabed (%.1f m)" % dropped.position.y)
	settings.chest_drop_chance = 0.0
	var legendary := Powerup.pick_for_chest(run.rng, Rarity.Tier.LEGENDARY, 3)
	var common := Powerup.pick_for_chest(run.rng, Rarity.Tier.COMMON, 3)
	var all_legendary := legendary.all(func(id: String) -> bool: return Powerup.tier(id) == Rarity.Tier.LEGENDARY)
	var rare_fill := Powerup.pick_for_chest(run.rng, Rarity.Tier.LEGENDARY, 6)
	check(legendary.size() == 3 and all_legendary and Powerup.tier(rare_fill[-1]) == Rarity.Tier.RARE,
			"a legendary chest offers legendaries first, then fills from below (%s)" % [rare_fill])
	check(common.size() == 3 and common.all(func(id: String) -> bool: return Powerup.tier(id) == Rarity.Tier.COMMON),
			"a common chest: all common (%s)" % [common])

	print("everyone's own chests:")
	var local: LocalCoop = main._local
	_press(PADS[0], LocalCoop.JOIN_BUTTON)
	await _ticks(5)
	var second: PlayerSlot = local.slots[1]
	check(local.count() == 2 and run.players.size() == 2, "a second player joins")
	check(local.slots[0].camera.cull_mask == TreasureChest.view_mask(0) and second.camera.cull_mask == TreasureChest.view_mask(1),
			"each player's camera sees its own layer")
	run.open_chest(dropped, fish)
	await _ticks(2)
	check(dropped.is_open_for(fish) and not dropped.is_open_for(second.fish), "the first opens it: theirs, not the second's")
	check(dropped not in run.shut_chests_for(fish) and dropped in run.shut_chests_for(second.fish), "it's still shut for the second")
	check(dropped._shown & TreasureChest.player_layer(0) == 0 and dropped._shown & TreasureChest.player_layer(1) != 0 and dropped._shut.visible,
			"gone from the first's view only")
	run.pick(fish, 0)
	run.open_chest(dropped, second.fish)
	await _ticks(2)
	check(is_instance_valid(dropped) and not dropped.is_queued_for_deletion(), "both opened it: it stays while the second's choosing (they could put it back)")
	run.pick(second.fish, 0)
	await _ticks(2)
	check(not is_instance_valid(dropped) or not dropped._shut.visible, "and once they've picked: it goes")
	var mine := run.health_of(fish)
	var theirs := run.health_of(second.fish)
	mine.hp = mine.max_hp * 0.2
	theirs.hp = theirs.max_hp * 0.2
	run.apply_pickup(Pickup.Kind.HEART, fish)
	check(is_equal_approx(mine.hp, mine.max_hp * 0.7) and is_equal_approx(theirs.hp, theirs.max_hp * 0.7),
			"one player takes a heart: it heals the whole team (D12)")
	mine.hp = mine.max_hp
	local.leave(second)
	await _ticks(5)

	print("drops:")
	var health := run.health_of(fish)
	health.hp = health.max_hp * 0.2
	settings.heart_chance = 1.0
	var target := horde.spawn(1, fish.global_position + Vector3(0, 0, -10))
	run.hit(target, 1e6, fish, "probe")
	await _ticks(2)
	settings.heart_chance = 0.0
	check(run.pickups.size() == 1 and run.pickups[0].kind == Pickup.Kind.HEART, "a kill dropped a heart")
	var heart_at := run.pickups[0].global_position if not run.pickups.is_empty() else fish.global_position
	await _hold(heart_at, 0.5)
	check(is_equal_approx(health.hp, health.max_hp * 0.7) and run.pickups.is_empty(),
			"taking it heals half the max hp (%.0f of %.0f)" % [health.hp, health.max_hp])
	for n in 5:
		run.drop_pearl(fish.global_position + Vector3(60 + n * 10, 0, 20), 1, 9100 + n)
	run.drop_pickup(Pickup.Kind.MAGNET, fish.global_position + Vector3(0, 0, -6))
	await _hold(fish.global_position + Vector3(0, 0, -6), 0.3)
	check(run.pearls_out.all(func(p: Pearl) -> bool: return p.drawn_by == fish), "a magnet: every pearl flies to the taker")
	var purse_before := run.purse_of(fish)
	await _seconds(6.0)
	check(run.pearls_out.is_empty() and run.purse_of(fish) >= purse_before + 5, "...and they all come in (+%d pearls)" % (run.purse_of(fish) - purse_before))
	settings.enemy_speed_scale = 1.0
	var biter := horde.spawn(1, fish.global_position + Vector3(0, 0, 8))
	run.drop_pickup(Pickup.Kind.HOURGLASS, fish.global_position + Vector3(0, 0, -6))
	await _hold(fish.global_position + Vector3(0, 0, -6), 0.3)
	check(horde.is_frozen(), "an hourglass: the horde stops")
	var held_at := horde.enemy_position(biter)
	await _seconds(1.0)
	check(horde.enemy_position(biter).distance_to(held_at) < 0.01, "a zombie stands still")
	health.hp = health.max_hp
	health.iframes_left = 0.0
	horde.relocate(biter, fish.global_position + Vector3(0.3, 0, 0))
	await _ticks(12)
	check(is_equal_approx(health.hp, health.max_hp), "and doesn't bite")
	horde.frozen_left = 0.0
	settings.enemy_speed_scale = 0.0
	horde.clear()
	var far_off: Array[int] = []
	for n in 6:
		far_off.append(horde.spawn(0, fish.global_position + Vector3(-40 + n * 16, 0, 45)))
	var part := horde.spawn_proxy(fish.global_position + Vector3(30, 0, -30), 2.0)
	settings.heart_chance = 1.0  # a bolt's kills must not roll drops anyway
	var kills_before := run.kills
	var drops_before := run.pickups.size()
	run.drop_pickup(Pickup.Kind.LIGHTNING, fish.global_position + Vector3(0, 0, -6))
	await _hold(fish.global_position + Vector3(0, 0, -6), 0.3)
	settings.heart_chance = 0.0
	check(far_off.all(func(i: int) -> bool: return not horde.is_alive(i)), "a lightning bolt: every zombie across the arena dies")
	check(run.kills - kills_before == far_off.size(), "...credited as %d kills" % (run.kills - kills_before))
	check(horde.is_alive(part), "...but a boss's body is spared")
	check(run.pickups.size() <= drops_before, "...and its kills drop nothing")
	horde.clear()

	print("difficulty:")
	settings.difficulty_per_minute = 1.0
	var early := horde.spawn(1, fish.global_position + Vector3(0, 0, -20))
	run.elapsed = 300.0
	await _ticks(2)
	var late := horde.spawn(1, fish.global_position + Vector3(0, 0, -25))
	check(run.difficulty() > 4.9 and horde.enemy_level(late) > horde.enemy_level(early), "the difficulty level grows with the clock (%.1f)" % run.difficulty())
	check(horde.enemy_hp(late) > horde.enemy_hp(early) and horde.enemy_size(late) > horde.enemy_size(early) and horde.damage_scale(late) > horde.damage_scale(early),
			"a later zombie is tougher and bigger (%.0f hp vs %.0f, x%.2f size)" % [horde.enemy_hp(late), horde.enemy_hp(early),
			horde.enemy_size(late) / horde.enemy_size(early)])
	settings.difficulty_per_minute = 0.0
	horde.clear()

	print("worn powerups:")
	run.powerups_of(fish).clear()  # what the chests above gave
	powers.fire_stacks = 1
	powers.lightning_stacks = 1
	powers.torpedo_stacks = 2
	powers.bow_stacks = 1
	await _ticks(2)
	var worn := ["Lantern", "Coil", "Tubes", "Bow"].filter(func(n: String) -> bool: return fish.find_child(n, false, false) != null)
	check(worn.size() == 4, "every powerup is worn (%s)" % [worn])
	powers.fire_stacks = 0
	powers.lightning_stacks = 0
	powers.torpedo_stacks = 0
	powers.bow_stacks = 0
	await _ticks(2)
	var left := ["Lantern", "Coil", "Tubes", "Bow"].filter(func(n: String) -> bool: return fish.find_child(n, false, false) != null)
	check(left.is_empty(), "and taken off with it (left: %s)" % [left])

	print("your stats:")
	Input.action_press("show_scoreboard")
	await _frames(3)
	var hud: UnnaturalHud = main._unnatural_hud
	check(hud._board.shown and hud._stats.visible, "the board shows your stats beside it")
	var row: Dictionary = hud._board.teams[0].rows[0]
	check(row.badges.size() == run.powerups_of(fish).list().size(),
			"your powerups are badges under your name (%d)" % row.badges.size())
	Input.action_release("show_scoreboard")
	await _frames(3)
	check(not hud._stats.visible, "and goes with it")
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## Our fish at `at` for `seconds`.
func _hold(at: Vector3, seconds: float) -> void:
	for t in roundi(seconds * 120.0):
		fish.global_position = at
		fish.linear_velocity = Vector3.ZERO
		await get_tree().physics_frame


func _press(pad: int, button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = pad
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _seconds(s: float) -> void:
	await _ticks(roundi(s * 120.0))


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
