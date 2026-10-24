extends Node
## The hit path's perf pass (2026-10-23) in the real game:
## - only powerups that hear hits are called on a hit: the rest are found deaf
##   the first time and dropped from the list;
## - damage_scale() is worked out once a physics tick;
## - an area hit (hit_area()) hurts each zombie as a hit apiece would (the same
##   damage, stats and signals), but its powerups hear at most AREA_PROC_ROLLS
##   of them, each standing for its share: torpedoes from 30 zombies are 3
##   launches carrying 30 launches' power;
## - torpedoes with no room fold their power into those flying;
## - lightning over its rate banks into the next strike.
##   Godot_console.exe --headless --path . res://tests/perf_pass_probe.tscn

var main: Node
var fish: FishController
var run: UnnaturalRun
var horde: Horde
var settings := UnnaturalSettings.shared()
var powers := PowerupSettings.shared()
var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	UnnaturalSettings.shared().limits = false  # the items' own numbers, in a line (limits_probe has P4's curves)
	settings.spawning = false
	settings.stage_events = false
	settings.chest_count = 0
	settings.chest_interval = 0.0
	settings.fish_attack = FishAttack.Kind.BITE
	settings.twists = false
	settings.card_choices = 0
	settings.enemy_speed_scale = 0.0
	settings.bite_damage = 0.0
	settings.battery_damage = 0.0
	settings.enemy_damage_scale = 0.0
	settings.difficulty_per_minute = 0.0
	settings.god_mode = true
	settings.enemy_hp_scale = 1000.0
	settings.depth_assist = 0.0
	settings.pearl_drop_chance = 0.0
	settings.chest_drop_chance = 0.0
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde
	fish.freeze = true
	var powerups := run.powerups_of(fish)

	print("only the powerups that hear hits:")
	powers.torpedo_stacks = 1
	powers.lightning_stacks = 1
	powers.bow_stacks = 1  # an item that never hears hits
	await _ticks(2)
	var a := _place(fish.global_position + Vector3(0, 0, -6))
	run.hit(a, 1.0, fish, "probe")
	run.hit(a, 1.0, fish, "probe")
	var hearing := powerups._hearing.map(func(p: Powerup) -> String: return p.id)
	check("torpedo" in hearing and "chain_lightning" in hearing, "torpedoes and lightning hear hits (%s)" % [hearing])
	var deaf := powerups.held.keys().filter(func(id: String) -> bool: return (powerups.held[id] as Powerup).deaf)
	check(not deaf.is_empty() and hearing.size() + deaf.size() == powerups.held.size(), "the rest were found deaf and dropped (%s)" % [deaf])
	check(not (powerups.held["torpedo"] as Powerup).deaf, "an item that overrides on_hit is never marked deaf")

	print("damage_scale() once a tick:")
	powerups._scale = 7.0
	powerups._scale_tick = Engine.get_physics_frames()
	check(is_equal_approx(powerups.damage_scale(), 7.0), "asked again in the same tick: the cached value")
	await _ticks(1)
	check(is_equal_approx(powerups.damage_scale(), 1.0), "the next tick: worked out again")

	print("area hits:")
	powers.torpedo_stacks = 0
	powers.lightning_stacks = 0
	powers.bow_stacks = 0
	await _ticks(2)
	horde.clear()
	var ring := PackedInt32Array()
	for n in 30:
		var angle := TAU * n / 30.0
		ring.append(_place(fish.global_position + Vector3(cos(angle) * 8.0, 0.0, sin(angle) * 8.0 - 20.0)))
	var stats := run.stats_of(fish)
	var dealt_before: float = stats.damage
	var hp_before := horde.enemy_hp(ring[0])
	var hits_seen := []
	var on_hit := func(index: int, amount: float, _by: FishController, _source: String, _chain: Array) -> void: hits_seen.append([index, amount])
	run.zombie_hit.connect(on_hit)
	run.hit_area(ring, 10.0, fish, "probe", fish.global_position + Vector3(0, 0, -20))
	run.zombie_hit.disconnect(on_hit)
	check(hits_seen.size() == 30, "every zombie in it is hurt, each with its own signal (%d)" % hits_seen.size())
	check(is_equal_approx(horde.enemy_hp(ring[0]), hp_before - 10.0), "each takes the hit's damage (%.0f -> %.0f)" % [hp_before, horde.enemy_hp(ring[0])])
	check(is_equal_approx(stats.damage - dealt_before, 300.0), "the stats count it all once (+%.0f)" % (stats.damage - dealt_before))
	var moved := horde.enemy_velocity(ring[5]).length()
	check(moved > 0.1, "each is knocked away from the centre (%.1f m/s)" % moved)

	print("its procs, a few rolls standing for all:")
	powers.torpedo_stacks = 1
	powers.torpedo_chance = 1.0
	powers.torpedo_max = 1000
	await _ticks(2)
	var launcher: TorpedoLauncher = powerups.held["torpedo"]
	var fired := launcher.fired
	run.hit_area(ring, 1.0, fish, "probe", Vector3.INF, 0.0, 1.0)
	check(launcher.fired - fired == UnnaturalRun.AREA_PROC_ROLLS * launcher.count(), "30 zombies: %d launches, not 30 (%d)" % [UnnaturalRun.AREA_PROC_ROLLS, launcher.fired - fired])
	var flying := launcher._swarm.power_total() if is_instance_valid(launcher._swarm) else 0.0
	check(is_equal_approx(flying, 30.0 * launcher.count()), "carrying 30 launches' power (%.1f)" % flying)
	launcher._swarm._power.fill(1.0)

	print("no room: folded in, not lost:")
	powers.torpedo_max = launcher.in_flight()
	var folded := launcher.folded
	var before := launcher._swarm.power_total()
	launcher.launch([], 4.0)
	check(launcher.folded == folded + 1 and is_equal_approx(launcher._swarm.power_total() - before, 4.0 * launcher.count()),
			"a launch with no room adds its power to those flying (+%.1f)" % (launcher._swarm.power_total() - before))
	powers.torpedo_max = 48
	powers.torpedo_chance = 0.08
	powers.torpedo_stacks = 0
	await _ticks(2)

	print("lightning over its rate banks:")
	powers.lightning_stacks = 1
	powers.lightning_chance = 1.0
	powers.lightning_max_rate = 1.0
	await _ticks(2)
	var lightning: ChainLightning = powerups.held["chain_lightning"]
	lightning.banked = 0.0
	for n in 6:
		lightning.on_hit(ring[n], 1.0, "probe", 1.0, [])
	check(lightning.banked >= 4.0, "strikes past the rate bank (%.0f banked)" % lightning.banked)
	lightning._strikes_left = 1.0
	lightning._refilled = Time.get_ticks_msec() / 1000.0
	var banked := lightning.banked
	lightning.on_hit(ring[9], 1.0, "probe", 1.0, [])
	check(lightning.banked == 0.0, "the next strike spends the bank")
	var biggest := 0.0
	for i in ring:
		biggest = maxf(biggest, hp_before - horde.enemy_hp(i))
	check(biggest > powers.lightning_damage * banked * 0.9, "and hits that much harder (%.0f of a %.0f strike)" % [biggest, powers.lightning_damage])
	powers.lightning_chance = 0.15
	powers.lightning_max_rate = 30.0
	powers.lightning_stacks = 0
	await _ticks(2)

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _place(at: Vector3) -> int:
	var i := horde.spawn(1, at, Vector3.FORWARD)
	horde._velocity[i] = Vector3.ZERO
	horde._position[i] = at
	horde._last_position[i] = at
	var all := PackedInt32Array()
	for j in horde._high:
		if horde._state[j] == Horde.State.ALIVE:
			all.append(j)
	horde.alive = all
	horde.grid.build(horde._position, all)
	return i


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
