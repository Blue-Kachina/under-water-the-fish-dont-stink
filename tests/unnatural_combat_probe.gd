extends Node
## Unnatural's bones (planning_unnatural.md phase 1) in the real game: the mode
## builds its arena (edge, seabed, blood moon); the Shark's ghost bite always
## out-reaches the bow wave, bites what's ahead and not what's behind, and
## kills drop XP pearls; touching a zombie hurts, then i-frames; ramming one
## at speed batters it, harder the faster, without hurting the fish; XP levels
## the team up (more max hp, healed by as much); the arena's edge pushes the
## fish back; the director sends packs out of view, strays are moved back
## near; and at 0 hp a solo run is over, until R starts it again.
##   Godot_console.exe --headless --path . res://tests/unnatural_combat_probe.tscn

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
	settings.spawning = false
	settings.difficulty_per_minute = 0.0  # exact damage checks
	settings.enemy_damage_scale = 1.0  # at the kinds' own contact damage
	settings.fish_attack = FishAttack.Kind.BITE  # these checks are the bite's (attack_probe has the rest)
	settings.twists = false  # and no fish's twist skews them
	settings.card_choices = 0  # level-ups without cards here (levels_probe has them)
	settings.enemy_speed_scale = 0.0  # zombies hold still unless a test wants them moving
	settings.bite_damage = 30.0  # one bite kills a clownfish (22 hp) in the checks below
	fish.character = FishCharacter.FishClass.HUNTER  # the Shark, whatever was picked last (an Alchemist's Regen skews the hp checks)
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	check(main._match_card != null, "Unnatural waits on its card")
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde
	var ocean: Ocean = main.get_node("Ocean")

	print("arena:")
	check(run != null and main._unnatural_hud != null, "Play starts a run, with its HUD")
	check(ocean.boundary_radius == settings.arena_radius, "the ocean's edge is the arena's (%.0f m)" % ocean.boundary_radius)
	check(run.seabed.get_child_count() >= 3 and is_equal_approx(run.seabed.position.y, settings.arena_floor), "a seabed: sand, rocks, kelp at the floor")
	var fog: Color = ocean.environment().fog_light_color
	check(fog.r > fog.g and fog.r > fog.b, "the blood moon reddens the fog (%s)" % fog)
	check(fish.boost_enabled == false, "on Nature's tuning (no boost)")

	print("ghost bite reach:")
	var bite := run.bite_of(fish)
	check(bite.reach() > GhostBite.bow_reach(fish) and bite.half_width() > GhostBite.bow_half_width(fish),
			"the jaws out-reach the bow wave (%.1f m vs %.1f m ahead, %.1f vs %.1f wide)" % [bite.reach(), GhostBite.bow_reach(fish), bite.half_width(), GhostBite.bow_half_width(fish)])
	var bow_before := fish.bow_length
	fish.bow_length = 12.0  # a huge bow wave (Bow Grow Bow, later)
	check(bite.reach() >= GhostBite.bow_reach(fish) * settings.bite_over_bow - 0.01, "a bigger bow wave grows the bite with it (%.1f m)" % bite.reach())
	fish.bow_length = bow_before

	print("ghost bite:")
	await _park(Vector3.ZERO, Vector3.FORWARD)
	await _ticks(2)
	var ahead := horde.spawn(1, Vector3(1.5, 0.0, -6.5))
	var behind := horde.spawn(1, Vector3(0.0, 0.0, 6.0))
	var side := horde.spawn(1, Vector3(14.0, 0.0, 0.0))
	await _ticks(90)
	check(not horde.is_alive(ahead), "a clownfish 6.5 m ahead (past the bow wave) is bitten dead")
	check(horde.is_alive(behind) and horde.is_alive(side), "one behind and one far off to the side aren't")
	var stats := run.stats_of(fish)
	var bitten: float = stats.by_source.get("bite", 0.0)
	check(stats.kills == 1 and run.kills == 1 and bitten >= 22.0, "the kill and bite damage are counted (%d, %.0f)" % [stats.kills, bitten])
	check(bite.bites >= 1 and bite.cooldown_left > 0.0, "the bite went on cooldown")
	check(is_equal_approx(run.levels.total_xp, horde.kinds[1].xp * settings.xp_gain), "its XP went to the team at once (%.1f)" % run.levels.total_xp)
	horde.clear()

	print("contact damage:")
	settings.bite_damage = 0.0
	var health := run.health_of(fish)
	health.reset(run.max_hp())
	await _park(Vector3(0, 0, 20), Vector3.FORWARD)
	await _ticks(2)
	var biter := horde.spawn(1, fish.global_position + Vector3(0.3, 0.0, 0.0))
	await _ticks(12)
	var one_hit := run.max_hp() - horde.kinds[1].contact_damage
	check(is_equal_approx(health.hp, one_hit), "touching a zombie hurts (%.0f hp)" % health.hp)
	check(health.iframes_left > 0.0, "then i-frames")
	horde.relocate(biter, fish.global_position + Vector3(0.2, 0.0, 0.0))
	await _ticks(12)
	check(is_equal_approx(health.hp, one_hit), "no more hurt during them")
	await _ticks(int(settings.iframes * 120.0))
	horde.relocate(biter, fish.global_position + Vector3(0.2, 0.0, 0.0))
	await _ticks(12)
	check(health.hp < one_hit - 1.0, "after them it hurts again (%.0f hp)" % health.hp)
	horde.clear()

	print("batteries:")
	health.reset(run.max_hp())
	var slow_speed := fish.nature_batter_speed + 2.0
	var fast_speed := fish.nature_batter_speed * 2.5
	var slow_hit: float = await _ram(slow_speed)
	health.reset(run.max_hp())
	var fast_hit: float = await _ram(fast_speed)
	check(slow_hit > 0.0 and fast_hit > slow_hit * 1.5, "ramming a boxfish batters it, harder faster (%.0f at %.0f m/s, %.0f at %.0f m/s)" % [
			slow_hit, slow_speed, fast_hit, fast_speed])
	check(is_equal_approx(health.hp, run.max_hp()), "a battery doesn't hurt the fish (%.0f hp)" % health.hp)
	var none: float = await _ram(fish.nature_batter_speed * 0.6)
	check(none == 0.0 and health.hp < run.max_hp(), "under the battering speed it's no battery, and the touch hurts (%.0f hp)" % health.hp)

	print("burst clouds:")
	horde.clear()
	await _park(Vector3(0, 0, 80), Vector3.FORWARD)
	await _ticks(2)
	health.reset(run.max_hp())
	var box := horde.spawn(2, fish.global_position + Vector3(0, 0, -2.5))
	await _ticks(6)
	run.hit(box, 9999.0, fish, "test")
	await _ticks(4)
	check(run._clouds.size() == 1, "a boxfish bursts into a cloud when it dies")
	await _ticks(40)
	# Less any armour from the level-up's signature stat (the Boxfish's is armour).
	var burst := maxf(settings.burst_damage - run.block_of(fish).value("armour"), 1.0)
	check(is_equal_approx(health.hp, run.max_hp() - burst), "the cloud hurts a fish inside it (%.0f hp)" % health.hp)
	await _ticks(int(settings.burst_time * 120.0))
	check(run._clouds.is_empty(), "then it fades away")
	settings.bite_damage = 30.0

	print("levels:")
	var levels := run.levels
	for pearl in run.pearls_out:
		pearl.queue_free()
	levels.reset()
	health.reset(run.max_hp())
	health.hp = 50.0
	var hp_before := health.hp
	var to_next := levels.xp_to_next()
	await _park(Vector3(0, 0, 40), Vector3.FORWARD)
	await _ticks(2)
	var purse_before := run.purse_of(fish)
	run.drop_pearl(fish.global_position + Vector3(0, 0, -3), 2)
	await _ticks(120)
	check(run.pearls_out.is_empty() and run.purse_of(fish) == purse_before + 2, "a pearl nearby is drawn in, into the purse (+%d)" % (run.purse_of(fish) - purse_before))
	run.credit_xp(to_next / settings.xp_gain, fish)
	check(levels.level == 2, "enough XP: level 2")
	check(is_equal_approx(health.max_hp, run.max_hp_of(fish)) and is_equal_approx(run.max_hp(), settings.base_hp + settings.hp_per_level) and is_equal_approx(health.hp, hp_before + settings.hp_per_level),
			"max hp up by hp_per_level, healed by as much (%.0f / %.0f)" % [health.hp, health.max_hp])
	check(levels.xp_to_next() > to_next, "the next level takes more (%.0f > %.0f)" % [levels.xp_to_next(), to_next])
	levels.add(levels.xp_to_next() + levels.xp_to_next(3) + 0.5)
	check(levels.level == 4, "a lot of XP at once: several levels (%d)" % levels.level)

	print("arena edge:")
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(Vector3.RIGHT), Vector3(settings.arena_radius + 8.0, 0.0, 0.0)))
	await _ticks(2)
	fish.linear_velocity = Vector3.RIGHT * 10.0
	var furthest := 0.0
	for t in 120 * 4:
		await get_tree().physics_frame
		furthest = maxf(furthest, Vector2(fish.global_position.x, fish.global_position.z).length())
	var now := Vector2(fish.global_position.x, fish.global_position.z).length()
	check(now < furthest - 3.0 and now < settings.arena_radius + 8.0, "past the edge it's pushed back in (furthest %.0f m, now %.0f m)" % [furthest, now])
	fish.revive(Transform3D(Basis(), Vector3(0, settings.arena_floor - 2.0, 0)))
	await _ticks(240)
	check(fish.global_position.y > settings.arena_floor, "under the seabed it's pushed back up (%.1f m)" % fish.global_position.y)

	print("director:")
	await _park(Vector3.ZERO, Vector3.FORWARD)
	settings.enemy_speed_scale = 1.0
	settings.spawning = true
	settings.base_alive = 12
	settings.bite_damage = 0.0  # nothing thins them out here
	run.director.intensity = 0.0
	run.director.relief_left = 0.0
	var spawned_far := true
	var in_arena := true
	var seen := {}
	for t in 120 * 4:
		await get_tree().physics_frame
		for i in horde.alive:
			if not seen.has(i):
				seen[i] = true
				var gap := horde.enemy_position(i).distance_to(fish.global_position)
				spawned_far = spawned_far and gap > settings.spawn_distance_min - 8.0
				in_arena = in_arena and Vector2(horde.enemy_position(i).x, horde.enemy_position(i).z).length() <= settings.arena_radius
	check(horde.alive_count() >= 12 and horde.alive_count() <= run.director.target_alive() + run.director.swarm_size(),
			"the director fills the horde to its target (%d alive, target %d)" % [horde.alive_count(), run.director.target_alive()])
	check(spawned_far and in_arena, "packs turn up out at spawn distance, inside the arena (%d seen)" % seen.size())
	run.director.elapsed = 300.0
	var later := run.director.target_alive()
	run.director.players = 2
	var coop := run.director.target_alive()
	run.director.elapsed = run.elapsed
	run.director.players = 1
	check(later > 100 and coop > later, "the target grows with time (5:00: %d) and players (two: %d)" % [later, coop])
	settings.spawning = false
	settings.difficulty_per_minute = 0.0  # exact damage checks
	settings.base_alive = 4
	settings.bite_damage = 30.0
	var stray := horde.alive[0]
	horde.relocate(stray, Vector3(0, 0, 120))
	await _ticks(150)
	var stray_gap := horde.enemy_position(stray).distance_to(fish.global_position)
	check(stray_gap < settings.spawn_distance_max + 10.0, "a stray past the leash is moved back near (%.0f m)" % stray_gap)

	print("death:")
	horde.clear()
	settings.enemy_speed_scale = 0.0
	var overs := [0]
	run.run_over.connect(func() -> void: overs[0] += 1)
	health.hp = 3.0
	health.iframes_left = 0.0
	horde.spawn(1, fish.global_position + Vector3(0.3, 0, 0))
	await _ticks(20)
	check(health.down and run.is_over and overs[0] == 1, "at 0 hp, solo: the run is over")
	check(fish.controls_locked, "the fish is out of it")
	var time_then := run.elapsed
	await _ticks(60)
	check(run.elapsed == time_then, "the clock stops")
	main.reset_play()
	await _ticks(5)
	check(not run.is_over and not health.down and is_equal_approx(health.hp, settings.base_hp) and run.levels.level == 1, "R starts it again: up, full hp, level 1")
	check(horde.alive_count() == 0 and run.kills == 0 and not fish.controls_locked, "the horde gone, nothing counted")

	print("leaving:")
	main.set_mode(main.FREE_SWIM)
	await _ticks(5)
	check(main.unnatural_run == null and ocean.boundary_radius == 0.0, "leaving the mode ends the run and the arena's edge")
	check(not ocean.environment().fog_light_color.is_equal_approx(fog), "the blood moon's gone from the fog")

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## The fish held still at `at`, facing `facing`.
func _park(at: Vector3, facing: Vector3) -> void:
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(facing), at))
	await _ticks(2)  # the move happens on the next physics step
	fish.freeze = true


## Rams a fresh boxfish at `speed`; returns the battery damage it took.
func _ram(speed: float) -> float:
	horde.clear()
	fish.freeze = false
	var start := Vector3(0, 0, 60)
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), start))
	await _ticks(2)
	var target := horde.spawn(2, start + Vector3(0, 0, -12))
	var stats := run.stats_of(fish)
	var before: float = stats.by_source.get("battery", 0.0)
	for t in 120 * 3:
		fish.linear_velocity = Vector3.FORWARD * speed
		await get_tree().physics_frame
		if stats.by_source.get("battery", 0.0) > before or fish.global_position.z < start.z - 16.0:
			break
	fish.linear_velocity = Vector3.ZERO
	await _ticks(3)
	horde.remove(target)
	var after: float = stats.by_source.get("battery", 0.0)
	return after - before


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
