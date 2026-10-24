extends Node
## The stage (planning_unnatural.md phase 7) in the real game, its timeline
## squeezed into seconds: each event is warned, the director holds its packs
## before one, the ring closes round the player, the Drowned Shark comes as a
## boss whose body attacks hit (its hp, not a zombie's), it hurts on touch,
## and beaten it drops a chest and XP; the stampede and tide come; the
## Leviathan clears the stragglers, changes phase as it's hurt, spits bolts
## that hurt, enrages when it's left too long (the director escalating), and
## beaten it completes the stage.
##   Godot_console.exe --headless --path . res://tests/stage_probe.tscn

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var run: UnnaturalRun
var horde: Horde
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
	settings.spawning = true
	settings.base_alive = 0
	settings.alive_per_minute = 0.0  # the director wants none: only events spawn
	settings.card_choices = 0
	settings.chest_count = 0
	settings.enemy_speed_scale = 0.0
	settings.fish_attack = FishAttack.Kind.BITE
	settings.bite_damage = 0.0  # attacks off until a test wants them
	settings.twists = false
	settings.base_hp = 100000.0
	settings.stage_events = true
	settings.run_length = 1
	settings.standard_stages = 1  # one stage: the Leviathan's whirlpool wins (pacing_probe has the next stage)
	settings.swarm_event_time = 0.0  # one wave each, as counted below (arsenal_batch_probe has the lasting swarms)
	settings.event_warning = 0.5
	settings.event_hush = 1.0
	settings.ring_time = 1.0
	settings.miniboss_time = 2.5
	settings.stampede_time = 8.0
	settings.tide_time = 10.0
	settings.boss_time = 12.0
	settings.leviathan_enrage = 6.0
	settings.leviathan_bolt_every = 0.5
	fish.character = FishCharacter.FishClass.HUNTER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde
	await _park(Vector3.ZERO, Vector3.FORWARD)
	var warned: Array[String] = []
	var started: Array[String] = []
	run.stage_warned.connect(func(e: String) -> void: warned.append(e))
	run.stage_event.connect(func(e: String) -> void: started.append(e))

	print("timeline:")
	check(run.timeline.pending.size() == 5 and run.timeline.next_event().id == "ring", "five events, the ring first")
	await _until(func() -> bool: return warned.has("ring"), 2.0)
	check(started.is_empty() and run.director.hushed, "the ring is warned before it comes, the director hushed")
	await _until(func() -> bool: return started.has("ring"), 2.0)
	await _ticks(8)  # the horde's live list updates on its next step
	var ring_count := horde.alive_count()
	var round_it := 0
	for i in horde.alive:
		var gap := horde.enemy_position(i).distance_to(fish.global_position)
		round_it += 1 if absf(gap - settings.ring_radius) < 3.0 else 0
	check(ring_count == settings.ring_count and round_it == ring_count, "the ring: %d zombies, all %.0f m round the player" % [ring_count, settings.ring_radius])
	horde.clear()

	print("the drowned shark:")
	await _until(func() -> bool: return run.current_boss() != null, 3.0)
	var shark := run.current_boss() as DrownedShark
	check(shark != null and warned.has("miniboss"), "the Drowned Shark comes, warned")
	if shark == null:
		_finish()
		return
	check(shark.parts.size() >= DrownedShark.MIN_PARTS and horde.alive_count() == 0, "its body is %d proxies, not counted as zombies" % shark.parts.size())
	# Put it right ahead and let the bite at it.
	shark.global_position = fish.global_position + Vector3(0, 0, -7)
	shark._place_parts()
	await _ticks(2)
	settings.bite_damage = 30.0
	var hp_before := shark.hp
	await _ticks(120)
	settings.bite_damage = 0.0
	check(shark.hp < hp_before and run.stats_of(fish).by_source.get("bite", 0.0) > 0.0, "the bite hurts it (%.0f -> %.0f)" % [hp_before, shark.hp])
	check(horde.is_alive(shark.parts[0]), "its proxies never die as zombies")
	var health := run.health_of(fish)
	health.iframes_left = 0.0
	var taken: float = run.stats_of(fish).taken
	shark.global_position = fish.global_position
	shark._place_parts()
	await _ticks(3)
	check(run.stats_of(fish).taken - taken >= settings.shark_contact * 0.99, "touching it hurts (%.0f)" % (run.stats_of(fish).taken - taken))
	shark.global_position = fish.global_position + Vector3(0, 0, -15)  # its chest out of reach (it'd open, and pause for the pick)
	shark._place_parts()
	var at := shark.global_position
	var chests_before := run.chests.size()
	var pearls_before := run.pearls_out.size()
	run.hit(shark.parts[1], shark.hp + 1.0, fish, "battery")
	await _ticks(2)
	check(shark.dying and run.current_boss() == null and run.chests.size() == chests_before + 1 and run.chests[-1].global_position.distance_to(at) < 1.0,
			"beaten: it drops a chest where it was")
	check(run.pearls_out.size() == pearls_before + settings.boss_pearls, "and %d pearls spill out (D23)" % settings.boss_pearls)
	await _ticks(10)
	check(shark.parts.is_empty(), "its proxies are gone")

	print("swarms:  (%.1f s in, fired %s)" % [run.elapsed, started])
	await _until(func() -> bool: return started.has("stampede"), 6.0)
	await _ticks(2)
	check(horde.alive_count() == settings.stampede_count, "the stampede: %d sardines" % horde.alive_count())
	horde.clear()
	await _until(func() -> bool: return started.has("tide"), 4.0)
	await _ticks(2)
	check(horde.alive_count() == settings.tide_count, "the tide: %d zombies" % horde.alive_count())

	print("the blood leviathan:")
	var straggler := horde.spawn(1, fish.global_position + Vector3(60, 0, 0))  # past boss_cleanup, inside the leash
	var near := horde.spawn(1, fish.global_position + Vector3(10, 0, 0))
	await _until(func() -> bool: return run.current_boss() is BloodLeviathan, 4.0)
	print("  (%.1f s in, fired %s)" % [run.elapsed, started])
	var leviathan := run.current_boss() as BloodLeviathan
	check(leviathan != null, "the Leviathan comes")
	if leviathan == null:
		_finish()
		return
	check((not horde.is_alive(straggler) or horde.is_proxy(straggler)) and horde.is_alive(near) and not horde.is_proxy(near), "it clears away the stragglers (the slot may be its own now), not the zombies near you")
	check(leviathan.parts.size() == settings.leviathan_segments, "%d segments, each a proxy" % leviathan.parts.size())
	run.hit(leviathan.parts[3], leviathan.max_hp * 0.4, fish, "battery")
	check(leviathan.phase == BloodLeviathan.Phase.SPIT, "at 60% hp it spits")
	leviathan.global_position = fish.global_position + Vector3(0, 0, -20)
	health.iframes_left = 0.0
	taken = run.stats_of(fish).taken
	await _until(func() -> bool: return run.stats_of(fish).taken > taken, 3.0)
	check(leviathan.bolts_fired > 0 and run.stats_of(fish).taken > taken, "its blood bolts hurt (%d fired)" % leviathan.bolts_fired)
	run.hit(leviathan.parts[5], leviathan.max_hp * 0.3, fish, "battery")
	check(leviathan.phase == BloodLeviathan.Phase.FURY, "under a third: fury")
	await _until(func() -> bool: return leviathan.enraged, 8.0)
	await _ticks(2)
	check(leviathan.enraged and run.enraged and is_equal_approx(run.director.escalation, settings.enrage_scale),
			"left too long, it enrages and the director escalates (x%.2f)" % run.director.escalation)
	var completed := [false]
	run.stage_completed.connect(func() -> void: completed[0] = true)
	run.hit(leviathan.parts[0], leviathan.hp + 1.0, fish, "battery")
	await _ticks(3)
	check(not completed[0] and not run.is_over and is_instance_valid(run.whirlpool), "beaten: the run goes on and a whirlpool opens")
	var coil_chest := run.chests.filter(func(c: TreasureChest) -> bool: return is_instance_valid(c) and c.item == "attack_leviathans_coil")
	check(coil_chest.size() == 1 and (coil_chest[0] as TreasureChest).kind == TreasureChest.Kind.BOSS, "and it leaves a boss chest with the Leviathan's Coil")
	fish.global_position = run.whirlpool.global_position + Vector3(settings.whirlpool_range + 20.0, 0, 0)
	check(not run.near_whirlpool(fish), "far from the whirlpool: no prompt")
	fish.global_position = run.whirlpool.global_position + Vector3(settings.whirlpool_range - 2.0, 0, 0)
	check(run.near_whirlpool(fish), "within %d m: you can enter" % roundi(settings.whirlpool_range))
	fish.global_position = run.whirlpool.global_position + Vector3(2.0, settings.arena_ceiling - settings.arena_floor - 1.0, 0)
	check(run.near_whirlpool(fish) and run.whirlpool.height >= settings.arena_ceiling - settings.arena_floor, "the whirlpool is a column: seabed to surface")
	run.enter_whirlpool(fish)
	check(completed[0] and run.stage_complete and run.is_over, "entering it: STAGE COMPLETE, the run's over (won)")
	run.start()
	await _ticks(3)
	check(run.bosses.is_empty() and not run.stage_complete and run.timeline.pending.size() == 5 and horde.alive_count() == 0, "R: a fresh stage")
	_finish()


func _finish() -> void:
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## Waits until `done` is true, or `seconds` pass.
func _until(done: Callable, seconds: float) -> void:
	for t in roundi(seconds * Engine.physics_ticks_per_second):
		if done.call():
			return
		await get_tree().physics_frame


func _park(at: Vector3, facing: Vector3) -> void:
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(facing), at))
	await _ticks(2)
	fish.freeze = true


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
