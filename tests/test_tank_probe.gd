extends Node
## Unnatural's Test Tank (planning_unnatural.md §8, phase 4): its dummies
## turn up in their cluster and lines, hold still and never die; the bite
## hurts them and the DPS log adds up (per source to the total, the total to
## what the player dealt); hits that would have killed count as kills; the
## panel sets the level and stats; tank_horde keeps that many chasers out
## (no contact damage unless asked); slow walkers drift in; R resets the log.
##   Godot_console.exe --headless --path . res://tests/test_tank_probe.tscn

var failures := 0
var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _run() -> void:
	settings.card_choices = 0
	settings.fish_attack = FishAttack.Kind.BITE  # the bite's numbers below
	settings.twists = false  # and no fish's twist skews them
	check(main.TEST_TANK in main.MODES, "the Test Tank is in the mode list")
	main.set_mode(main.TEST_TANK)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: UnnaturalRun = main.unnatural_run
	check(run != null and run.test_tank and run.tank != null, "Play starts the tank")
	var horde := run.horde
	var tank := run.tank

	print("dummies:")
	check(horde.alive_count() == tank.dummy_count(), "%d dummies out (cluster and lines)" % horde.alive_count())
	var all_immortal := true
	for i in horde.alive:
		all_immortal = all_immortal and horde.is_immortal(i)
	check(all_immortal, "all immortal")
	var where := {}
	for i in horde.alive:
		where[i] = horde.enemy_position(i)
	fish.freeze = true
	await _ticks(240)
	var drift := 0.0
	for i: int in where:
		drift = maxf(drift, horde.enemy_position(i).distance_to(where[i]))
	check(drift < 0.2, "they hold still (moved %.2f m at most)" % drift)

	print("the DPS log:")
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), Vector3(0, 0, -12)))
	await _ticks(2)  # the move happens on the next physics step
	fish.freeze = true
	await _ticks(120 * 4)
	var rows := tank.sources()
	var total: Dictionary = rows[-1]
	var bite_row := {}
	var sum := 0.0
	for row: Dictionary in rows.slice(0, rows.size() - 1):
		sum += row.damage
		if row.source == "bite":
			bite_row = row
	check(not bite_row.is_empty() and bite_row.damage > 0.0 and bite_row.hits > 0, "the bite is logged (%.0f damage, %d hits)" % [bite_row.get("damage", 0.0), bite_row.get("hits", 0)])
	check(is_equal_approx(total.damage, sum) and is_equal_approx(total.damage, run.stats_of(fish).damage), "per source adds up to the total, and to what the fish dealt (%.0f)" % total.damage)
	check(total.dps > 0.0 and total.overall > 0.0, "DPS, recent and overall (%.1f, %.1f)" % [total.dps, total.overall])
	check(horde.alive_count() == tank.dummy_count(), "no dummy died")

	print("would-be kills:")
	settings.tank_dummy_hp = 20.0
	main.reset_play()
	await _ticks(3)
	check(tank.sources().size() == 1 and tank.elapsed < 0.1, "R resets the log")
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), Vector3(0, 0, -12)))
	await _ticks(2)
	fish.freeze = true
	await _ticks(120 * 3)
	var kills: int = tank.sources()[-1].kills
	check(kills > 0 and horde.alive_count() == tank.dummy_count(), "weak dummies count kills it would have scored (%d), and stay" % kills)
	settings.tank_dummy_hp = 100.0

	print("panel overrides:")
	settings.tank_level = 6
	settings.tank_damage = 1.0
	settings.tank_attack_speed = 0.5
	await _ticks(3)
	check(run.levels.level == 6 and is_equal_approx(run.health_of(fish).max_hp, run.max_hp()), "the level (6) and its max hp")
	check(is_equal_approx(run.block_of(fish).value("damage"), 1.0) and is_equal_approx(run.bite_of(fish).attack_speed, 1.5), "the stats (damage +100%, attack speed +50%)")
	settings.tank_level = 1
	settings.tank_damage = 0.0
	settings.tank_attack_speed = 0.0

	print("the horde:")
	settings.tank_horde = 300
	await _ticks(30)
	check(horde.alive_count() >= tank.dummy_count() + 290, "tank_horde 300 brings chasers (%d alive)" % horde.alive_count())
	await _ticks(120 * 3)
	var health := run.health_of(fish)
	check(is_equal_approx(health.hp, health.max_hp), "no contact damage by default (%.0f hp)" % health.hp)
	settings.tank_horde = 0
	await _ticks(5)
	check(horde.alive_count() == tank.dummy_count(), "back to 0: just the dummies")

	print("slow walkers:")
	settings.tank_slow_walkers = true
	var near_before := INF
	for i in horde.alive:
		near_before = minf(near_before, horde.enemy_position(i).distance_to(fish.global_position))
	var far_one := horde.alive[horde.alive.size() - 1]
	var gap_before := horde.enemy_position(far_one).distance_to(fish.global_position)
	await _ticks(120 * 3)
	check(horde.enemy_position(far_one).distance_to(fish.global_position) < gap_before - 2.0, "they drift towards the player")
	settings.tank_slow_walkers = false

	print("leaving:")
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	check(main.unnatural_run == null and main._match_card != null, "switching to Unnatural ends the tank (its card waits)")

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
