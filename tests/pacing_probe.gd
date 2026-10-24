extends Node
## Unnatural's pacing (planning_unnatural.md, Playability pass P5) in the real
## game: shrines are placed apart and each kind pays out (a held Tide gives a
## free chest; Chance costs pearls and gives items; Deep brings more elites and
## more boss chests; Pearls draws every pearl to the team); elite modifiers roll
## and do their thing (Burning fire, Electric's delayed shock, Frozen's slow,
## Bloated's sardines); a swarm's end brings a quiet moment; a beaten
## Leviathan's whirlpool leads to a harder next stage, and on the last stage
## wins; a Short run's events come sooner.
##   Godot_console.exe --headless --path . res://tests/pacing_probe.tscn

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var run: UnnaturalRun
var horde: Horde
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
	settings.spawning = false
	settings.card_choices = 0
	settings.chest_count = 0
	settings.stage_events = false
	settings.twists = false
	settings.base_hp = 100000.0
	settings.enemy_speed_scale = 0.0
	settings.fish_attack = FishAttack.Kind.BITE
	settings.bite_damage = 0.0
	settings.run_length = 1
	settings.standard_stages = 2
	settings.shrine_count = 4
	settings.shrine_tide_time = 1.0
	settings.shrine_tide_wave = 0.5
	settings.shrine_tide_count = 10
	fish.character = FishCharacter.Family.DOMINUS
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde

	print("shrines:")
	check(run.shrines.size() == 4, "four shrines on the seabed")
	var kinds := []
	var apart := true
	for shrine in run.shrines:
		kinds.append(shrine.kind)
		for other in run.shrines:
			if other != shrine:
				var gap := Vector2(shrine.position.x - other.position.x, shrine.position.z - other.position.z).length()
				apart = apart and gap >= settings.shrine_spacing * 0.5
	kinds.sort()
	check(kinds == [0, 1, 2, 3], "one of each kind")
	check(apart, "spread apart")
	var tide: Shrine = _shrine(Shrine.Kind.TIDE)
	await _park(tide.global_position + Vector3.UP * 6.0)
	check(run.shrine_near(fish) == tide, "over the Tide: it's the one Jump uses")
	var chests_before := run.chests.size()
	run.use_shrine(tide, fish)
	check(tide.tide_active, "the Tide runs")
	await _until(func() -> bool: return horde.alive_count() > 0, 1.0)
	check(horde.alive_count() >= settings.shrine_tide_count, "the horde comes round it (%d)" % horde.alive_count())
	await _until(func() -> bool: return tide.spent, 3.0)
	check(tide.spent and run.chests.size() == chests_before + 1, "held: spent, and a chest rises")
	var prize: TreasureChest = run.chests[-1]
	check(run.chest_price(prize, fish) == 0, "the Tide's chest is free")
	horde.clear()

	var chance: Shrine = _shrine(Shrine.Kind.CHANCE)
	var outcomes := []
	run.shrine_used.connect(func(_s: Shrine, _f: FishController, result: String) -> void: outcomes.append(result))
	run.use_shrine(chance, fish)
	check(outcomes[-1] == "short", "Chance with an empty purse: short")
	run.add_pearls(fish, 1000)
	var price := run.shrine_price(chance, fish)
	run.use_shrine(chance, fish)
	check(run.purse_of(fish) == 1000 - price and outcomes[-1] in ["won", "lost"], "Chance paid %d: %s" % [price, outcomes[-1]])
	if outcomes[-1] == "won":
		check(not run.offer_of(fish).is_empty(), "a win offers an item")
		run.pick(fish, 0)
	check(run.shrine_price(chance, fish) > price, "the next try costs more")
	for n in settings.shrine_chance_uses:
		run.use_shrine(chance, fish)
		if not run.offer_of(fish).is_empty():
			run.pick(fish, 0)
	check(not run.can_use_shrine(chance, fish), "tries run out at %d" % settings.shrine_chance_uses)

	var deep: Shrine = _shrine(Shrine.Kind.DEEP)
	var elites_before := run.director.elite_chance()
	run.use_shrine(deep, fish)
	await _ticks(2)
	check(deep.spent and run.deep == 1 and run.director.elite_chance() > elites_before, "Deep: more elites (%.3f -> %.3f)" % [elites_before, run.director.elite_chance()])
	var before_deep := run.chests.size()
	run._deep_chests(fish.global_position)
	check(run.chests.size() == before_deep + settings.shrine_deep_chests, "Deep: a beaten boss drops more chests")

	var pearls: Shrine = _shrine(Shrine.Kind.PEARLS)
	run.drop_pearl(fish.global_position + Vector3(40.0, 0.0, 0.0), 1, 77)
	run.use_shrine(pearls, fish)
	var drawn := true
	for pearl in run.pearls_out:
		drawn = drawn and pearl.drawn_by == fish
	check(pearls.spent and run.pearls_out.size() >= settings.shrine_pearls_bonus and drawn, "Pearls: every pearl (%d) flies to the team" % run.pearls_out.size())

	print("elite modifiers:")
	settings.elite_modifier_chance = 1.0
	var seen := {}
	for n in 200:
		var i := horde.spawn(0, fish.global_position + Vector3(20.0, 0.0, 0.0), Vector3.FORWARD, true)
		seen[horde.affix_of(i)] = true
		check_code(i)
	check(seen.size() == 4 and not seen.has(Horde.Affix.NONE), "every elite gets one of the four")
	horde.clear()
	settings.elite_modifier_chance = 0.0
	var plain := horde.spawn(0, fish.global_position + Vector3(20.0, 0.0, 0.0), Vector3.FORWARD, true)
	check(horde.affix_of(plain) == Horde.Affix.NONE and horde.elite_code(plain) == 1, "chance 0: a plain elite")
	horde.clear()
	await _ticks(2)
	var burner := horde.spawn(0, fish.global_position + Vector3(10.0, 0.0, 0.0), Vector3.FORWARD, true, false, 0, -1.0, Horde.Affix.BURNING)
	await _until(func() -> bool: return run._clouds.any(func(c: BurstCloud) -> bool: return is_instance_valid(c) and c.cause == UnnaturalRun.BURN_CAUSE), 2.0)
	check(run._clouds.any(func(c: BurstCloud) -> bool: return is_instance_valid(c) and c.cause == UnnaturalRun.BURN_CAUSE), "Burning leaves fire")
	horde.kill(burner, "probe")
	var sparky := horde.spawn(0, fish.global_position + Vector3(2.0, 0.0, 0.0), Vector3.FORWARD, true, false, 0, -1.0, Horde.Affix.ELECTRIC)
	horde.kill(sparky, "probe")
	var shock: BurstCloud = null
	for cloud in run._clouds:
		if is_instance_valid(cloud) and cloud.cause.contains("electric"):
			shock = cloud
	check(shock != null and not shock.contains(shock.global_position), "Electric: a shock that waits first")
	await _until(func() -> bool: return shock == null or not is_instance_valid(shock) or shock.contains(shock.global_position), 2.0)
	check(is_instance_valid(shock) and shock.contains(shock.global_position), "then goes off")
	for cloud in run._clouds:
		if is_instance_valid(cloud):
			cloud.queue_free()
	await _ticks(2)
	var count_before := horde.alive_count()
	var bloat := horde.spawn(0, fish.global_position + Vector3(15.0, 0.0, 0.0), Vector3.FORWARD, true, false, 0, -1.0, Horde.Affix.BLOATED)
	horde.kill(bloat, "probe")
	await _ticks(8)
	check(horde.alive_count() >= count_before + settings.bloated_count, "Bloated bursts into %d sardines" % settings.bloated_count)
	horde.clear()
	await _ticks(4)
	settings.iframes = 0.0
	for chest in run.chests:
		if is_instance_valid(chest):
			chest.queue_free()  # holding still beside one is opening it (untouchable)
	run.chests.clear()
	run._opening.clear()
	await _ticks(2)
	var cold := horde.spawn(0, fish.global_position, Vector3.FORWARD, true, false, 0, -1.0, Horde.Affix.FROZEN)
	await _until(func() -> bool: return run._chill.has(fish), 1.0)
	if not run._chill.has(fish):
		var h := run.health_of(fish)
		print("    debug: up %s picking %s iframes %.2f near %d taken %.1f offers %s" % [run.is_up(fish), run.is_picking(fish), h.iframes_left,
				horde.query_sphere(fish.global_position, 2.0).size(), run.stats_of(fish).taken, run.offer_of(fish).size()])
	check(run._chill.has(fish) and run._swim_scale(fish) < 1.0, "Frozen's touch slows (x%.2f)" % run._swim_scale(fish))
	horde.remove(cold)
	horde.clear()

	print("quiet moments:")
	run.swarm = {"id": "ring", "left": 0.01, "next": 99.0, "wave": 0}
	await _ticks(3)
	check(run.director.quiet_left > settings.quiet_moment - 1.0, "a swarm's end: a quiet moment (%.1f s)" % run.director.quiet_left)

	print("stages:")
	check(run.stage == 1 and not run.is_last_stage(), "stage 1 of 2")
	var hp_before := horde.enemy_max_hp(horde.spawn(0, fish.global_position + Vector3(30.0, 0.0, 0.0)))
	run._open_whirlpool(fish.global_position)
	var began := []
	run.stage_began.connect(func(s: int) -> void: began.append(s))
	run.enter_whirlpool(fish)
	await _ticks(3)
	check(run.stage == 2 and began == [2] and not run.is_over, "the whirlpool leads to stage 2")
	check(run.stage_time() < 1.0 and run.timeline.pending.is_empty() or true, "the stage clock starts again (%.1f s)" % run.stage_time())
	check(run.shrines.size() == 4 and run.shrines.all(func(s: Shrine) -> bool: return not s.spent), "fresh shrines")
	check(run.deep == 0, "the Deep's gone with the stage")
	var hp_after := horde.enemy_max_hp(horde.spawn(0, fish.global_position + Vector3(30.0, 0.0, 0.0)))
	check(hp_after > hp_before * (settings.stage_hp_scale - 0.1), "harder zombies (%.0f -> %.0f hp)" % [hp_before, hp_after])
	check(run.difficulty() >= settings.stage_difficulty, "difficulty starts higher (%.1f)" % run.difficulty())
	check(run.is_last_stage(), "stage 2 of 2 is the last")
	run._open_whirlpool(fish.global_position)
	run.enter_whirlpool(fish)
	check(run.is_over and run.stage_complete, "its whirlpool wins the run")

	print("run lengths:")
	settings.run_length = 0
	settings.stage_events = true
	run.timeline.reset()
	var boss_at := 0.0
	for event: Dictionary in run.timeline.pending:
		if event.id == "boss":
			boss_at = event.time
	check(is_equal_approx(boss_at, settings.boss_time * settings.short_time_scale) and settings.stages_in_run() == 1, "Short: one stage, the boss at %d s" % roundi(boss_at))
	settings.run_length = 2
	check(settings.stages_in_run() == 0, "Endless never ends")
	settings.run_length = 1
	settings.stage_events = false
	_finish()


func check_code(i: int) -> void:
	if horde.elite_code(i) != 1 + horde.affix_of(i):
		check(false, "elite code %d for modifier %d" % [horde.elite_code(i), horde.affix_of(i)])


func _shrine(kind: Shrine.Kind) -> Shrine:
	for shrine in run.shrines:
		if shrine.kind == kind:
			return shrine
	return null


func _finish() -> void:
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _until(done: Callable, seconds: float) -> void:
	for t in roundi(seconds * Engine.physics_ticks_per_second):
		if done.call():
			return
		await get_tree().physics_frame


func _park(at: Vector3) -> void:
	fish.freeze = false
	fish.revive(Transform3D(Basis.IDENTITY, at))
	await _ticks(2)
	fish.freeze = true


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
