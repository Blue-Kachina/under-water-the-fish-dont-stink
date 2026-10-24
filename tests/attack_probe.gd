extends Node
## Every fish unique (planning_unnatural.md phase 6) in the real game: each
## fish gets its own auto-attack (and the panel's fish_attack overrides it,
## live); the Anemone Sting hits all round and out-reaches the bow wave; the
## Shock Lash whips any way round and arcs on (one more per Quantity); the
## Bill Thrust's spear pierces a line ahead; the Bubble Volley's bubbles home
## in and pop; the Spine Burst hits all round; projectile cards are offered only
## to fish that shoot. Then the twists: Nimble turns sharper, Glide keeps its
## speed, Frenzy speeds up per kill, Armoured takes less and swims slower, Dash
## bursts on the mobility button (untouchable), and Leap splashes down on the zombies.
##   Godot_console.exe --headless --path . res://tests/attack_probe.tscn

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
	settings.card_choices = 0
	settings.enemy_speed_scale = 0.0  # zombies hold still
	settings.enemy_hp_scale = 100.0  # and nothing dies: count the hits
	settings.difficulty_per_minute = 0.0  # every zombie at its kind's hp (_hurt compares with it)
	settings.enemy_damage_scale = 0.0
	settings.chest_count = 0
	settings.twists = false
	fish.character = FishCharacter.FishClass.GLIDER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde

	print("each fish its own:")
	check(run.attack_of(fish) is ShockLash, "the String Ray lashes")
	var expected := {FishCharacter.FishClass.SKIRMISHER: AnemoneSting, FishCharacter.FishClass.HUNTER: GhostBite,
			FishCharacter.FishClass.LANCER: BillThrust, FishCharacter.FishClass.CHARMER: BubbleVolley, FishCharacter.FishClass.BULWARK: SpineBurst,
			FishCharacter.FishClass.SCORCHER: GreekFire, FishCharacter.FishClass.DRIFTER: JellyfishHalo, FishCharacter.FishClass.BRAWLER: CavitationPunch,
			FishCharacter.FishClass.BREACHER: RemoraBuddy, FishCharacter.FishClass.ALCHEMIST: PurpleHaze}
	for fish_class: FishCharacter.FishClass in expected:
		var made := FishAttack.make(FishAttack.kind_for(fish_class))
		check(made.get_script() == expected[fish_class], "%s: %s" % [FishCharacter.display_name(fish_class), FishAttack.title(made.kind)])
		made.free()
	settings.fish_attack = FishAttack.Kind.SPINES
	await _ticks(2)
	check(run.attack_of(fish) is SpineBurst and run.bite_of(fish) == null, "the panel's fish_attack swaps it, live")
	settings.fish_attack = FishAttack.Kind.OWN
	await _ticks(2)
	check(run.attack_of(fish) is ShockLash, "and back to its own")

	print("anemone sting:")
	var sting: AnemoneSting = await _use(FishAttack.Kind.STING)
	check(sting.radius() >= GhostBite.bow_reach(fish) * settings.sting_over_bow - 0.01 and sting.radius() > GhostBite.bow_reach(fish),
			"it out-reaches the bow wave (%.1f m vs %.1f m)" % [sting.radius(), GhostBite.bow_reach(fish)])
	var round_it := [horde.spawn(1, Vector3(0, 0, -5)), horde.spawn(1, Vector3(0, 0, 5)), horde.spawn(1, Vector3(4, 3, 0))]
	var far := horde.spawn(1, Vector3(0, 0, -25))
	await _ticks(40)
	check(_all_hurt(round_it) and not _hurt(far), "it stings all round (ahead, behind, above), not 25 m off")
	check(sting.uses >= 1 and run.stats_of(fish).by_source.get("sting", 0.0) > 0.0, "counted as sting damage")

	print("shock lash:")
	var lash: ShockLash = await _use(FishAttack.Kind.LASH)
	var first := horde.spawn(1, Vector3(0, 0, 10))  # behind: a lash goes any way round
	var second := horde.spawn(1, Vector3(5, 0, 12))
	var third := horde.spawn(1, Vector3(10, 0, 14))
	await _ticks(20)
	check(_hurt(first) and _hurt(second) and not _hurt(third), "it whips the nearest (behind), arcs to one more, not two")
	run.block_of(fish).add("quantity", 1.0)
	run._apply_stats(fish)
	_heal_all()
	await _ticks(roundi(settings.lash_cooldown * Engine.physics_ticks_per_second) + 10)
	check(_hurt(third) and lash.arcs() == 2, "+1 Quantity: one more arc (%d made)" % lash.arcs_made)

	print("bill thrust:")
	var thrust: BillThrust = await _use(FishAttack.Kind.THRUST)
	var line := [horde.spawn(1, Vector3(0, 0, -8)), horde.spawn(1, Vector3(0, 0, -13)), horde.spawn(1, Vector3(0, 0, -18))]
	var behind := horde.spawn(1, Vector3(0, 0, 8))
	await _ticks(100)
	check(_all_hurt(line) and not _hurt(behind), "the spear pierces the line ahead, not the one behind")
	var slow := thrust.speed()
	run.block_of(fish).add("projectile_speed", 0.5)
	run._apply_stats(fish)
	check(thrust.speed() > slow * 1.4, "Projectile Speed makes it faster (%.0f -> %.0f m/s)" % [slow, thrust.speed()])
	var melee := AnemoneSting.new()
	check(StatBlock.pool(thrust).has("projectile_speed") and not StatBlock.pool(melee).has("quantity"),
			"projectile cards only for fish that shoot")
	melee.free()

	print("bubble volley:")
	var volley: BubbleVolley = await _use(FishAttack.Kind.BUBBLES)
	var targets := [horde.spawn(1, Vector3(0, 0, -10)), horde.spawn(1, Vector3(10, 0, 0))]
	await _ticks(260)
	check(_all_hurt(targets) and volley.bubbles.pops >= 2, "bubbles home in on zombies ahead and to the side, and pop (%d)" % volley.bubbles.pops)

	print("spine burst:")
	var burst: SpineBurst = await _use(FishAttack.Kind.SPINES)
	var ring := []
	for n in 8:
		var a := TAU * n / 8.0
		ring.append(horde.spawn(1, Vector3(cos(a), 0, sin(a)) * 6.0))
	await _ticks(roundi(settings.spine_cooldown * Engine.physics_ticks_per_second) + 60)  # two bursts
	var hurt_count := 0
	for i: int in ring:
		hurt_count += 1 if _hurt(i) else 0
	check(hurt_count >= 5, "spines out all round (%d of 8 hit)" % hurt_count)
	var before := burst.count()
	run.block_of(fish).add("quantity", 1.0)
	run._apply_stats(fish)
	check(burst.count() == before + 4, "+1 Quantity: 4 more spines")
	settings.fish_attack = FishAttack.Kind.OWN
	horde.clear()

	print("twists:")
	settings.twists = true
	settings.sting_damage = 0.0  # no attacks muddling the twists
	settings.bite_damage = 0.0
	settings.lash_damage = 0.0
	settings.thrust_damage = 0.0
	settings.bubble_damage = 0.0
	settings.spine_damage = 0.0
	await _be(FishCharacter.FishClass.SKIRMISHER)
	check(is_equal_approx(fish.turn_scale, settings.nimble_turn), "Clownfish, Nimble: turns x%.2f" % fish.turn_scale)
	await _be(FishCharacter.FishClass.GLIDER)
	check(is_equal_approx(fish.drag_scale, settings.glide_drag) and is_equal_approx(fish.turn_scale, 1.0), "String Ray, Glide: drag x%.2f" % fish.drag_scale)
	await _be(FishCharacter.FishClass.HUNTER)
	var twist := run.twist_of(fish)
	for n in 3:
		twist.on_kill()
	await _ticks(2)
	check(absf(fish.speed_scale - (1.0 + 3.0 * settings.frenzy_per_kill)) < 0.01 and is_equal_approx(fish.drag_scale, 1.0),
			"Shark, Frenzy: 3 kills, swim x%.2f" % fish.speed_scale)
	await _be(FishCharacter.FishClass.BULWARK)
	var taken: float = run.stats_of(fish).taken
	run.hurt(fish, 20.0)
	check(is_equal_approx(run.stats_of(fish).taken - taken, 20.0 * settings.armour_taken) and is_equal_approx(fish.speed_scale, settings.armour_speed),
			"Boxfish, Armoured: took %.0f of 20, swims x%.2f" % [run.stats_of(fish).taken - taken, fish.speed_scale])

	await _be(FishCharacter.FishClass.LANCER)
	fish.freeze = false
	run.health_of(fish).iframes_left = 0.0
	run.twist_of(fish).mobility()
	await _ticks(2)
	check(run.twist_of(fish).dashes == 1 and fish.linear_velocity.dot(Vector3.FORWARD) > settings.dash_speed * 0.5
			and run.health_of(fish).iframes_left > 0.0, "Swordfish, Dash: the mobility button bursts on (%.1f m/s), untouchable" % fish.linear_velocity.dot(Vector3.FORWARD))

	await _be(FishCharacter.FishClass.CHARMER)
	fish.freeze = false
	var splashed := horde.spawn(1, Vector3(3, 0, 0))
	var leap := run.twist_of(fish)
	run.twist_of(fish).mobility()
	for t in 200:
		await get_tree().physics_frame
		if leap.splashes > 0:
			break
	check(leap.leaps == 1 and leap.splashes == 1 and run.stats_of(fish).by_source.get("splash", 0.0) > 0.0,
			"Butterfly Koi, Leap: up, then a splash on the zombies (%s)" % _hurt(splashed))
	run.twist_of(fish).mobility()
	await _ticks(2)
	check(leap.leaps == 1, "then a cooldown before the next")

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## Every fish to the attack of `kind`, parked at the middle facing forward, the horde cleared.
func _use(kind: FishAttack.Kind) -> FishAttack:
	horde.clear()
	run.block_of(fish).reset()
	settings.fish_attack = kind
	await _park(Vector3.ZERO, Vector3.FORWARD)
	await _ticks(2)
	var attack := run.attack_of(fish)
	attack.cooldown_left = 0.0
	run._apply_stats(fish)
	return attack


## Plays as `fish_class` now, parked.
func _be(fish_class: FishCharacter.FishClass) -> void:
	horde.clear()
	fish.character = fish_class
	run.twist_of(fish).reset()
	await _park(Vector3.ZERO, Vector3.FORWARD)
	await _ticks(3)


func _hurt(index: int) -> bool:
	return horde.is_alive(index) and horde.enemy_hp(index) < horde.enemy_kind(index).hp * settings.enemy_hp_scale - 0.01


func _all_hurt(indices: Array) -> bool:
	for i: int in indices:
		if not _hurt(i):
			return false
	return true


## Every zombie back to full hp (by respawning it where it is).
func _heal_all() -> void:
	for i in horde.alive.duplicate():
		var at := horde.enemy_position(i)
		var kind := horde.enemy_kind_index(i)
		horde.remove(i)
		horde.spawn(kind, at)


func _park(at: Vector3, facing: Vector3) -> void:
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(facing), at))
	await _ticks(2)
	fish.freeze = true


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
