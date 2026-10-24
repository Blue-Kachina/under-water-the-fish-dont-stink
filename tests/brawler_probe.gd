extends Node
## The Brawlers (big_changes.md §4, Phase 2) in the real game: the Mantis
## Shrimp's own attack is the Cavitation Punch; a punch lands twice (the glove,
## then the bubble collapsing a moment later, on the zombies round it too); the
## glove is solid for the first part of its flight, fades over the last
## punch_fade, and is gone at its range; each Quantity throws one more glove
## from the other claw; the milestones (wider ring, stun, pierce, Haymaker).
## Then the twist and skill: the Recoil Dash throws the fish backwards and
## punches ahead with the stick neutral, and goes the way the stick leans (the
## punch the other way); Heavy Hitter turns a punched zombie into a missile.
##   Godot_console.exe --headless --path . res://tests/brawler_probe.tscn

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
	settings.difficulty_per_minute = 0.0
	settings.enemy_damage_scale = 0.0
	settings.chest_count = 0
	settings.twists = false
	fish.character = FishCharacter.FishClass.BRAWLER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde

	print("the brawlers' own:")
	check(run.attack_of(fish) is CavitationPunch, "the Mantis Shrimp punches")
	check(FishAttack.kind_for(FishCharacter.FishClass.BRAWLER) == FishAttack.Kind.PUNCH and Traversal.title(FishCharacter.FishClass.BRAWLER) == "Heavy Hitter"
			and Traversal.skill_title(FishCharacter.FishClass.BRAWLER) == "Recoil Dash", "Cavitation Punch, Heavy Hitter, Recoil Dash")
	check("attack_punch" in Weapons.card_pool(FishAttack.Kind.BITE) and "attack_punch" not in Weapons.card_pool(FishAttack.Kind.PUNCH)
			and "attack_purple_haze" in Weapons.card_pool(FishAttack.Kind.PUNCH), "others can take it as a second weapon; Purple Haze is in the pool")
	check(Weapons.facets(Weapons.ATTACK, FishAttack.Kind.PUNCH).size() == 4 and Weapons.milestones(Weapons.ATTACK, FishAttack.Kind.PUNCH).size() == 4,
			"four facets, four milestones")

	print("two impacts per punch:")
	var punch := await _use()
	var struck := horde.spawn(1, Vector3(0, 0, -4))
	var beside := horde.spawn(1, Vector3(1.6, 0, -4))  # off the glove's line, inside the collapse
	var far := horde.spawn(1, Vector3(6, 0, -4))
	var full := horde.enemy_hp(struck)
	var struck_at := horde.enemy_position(struck)
	await _until(func() -> bool: return punch.glove_hits > 0, 60)
	var after_glove := full - horde.enemy_hp(struck)
	check(punch.gloves_thrown == 1 and punch.glove_hits == 1 and is_equal_approx(after_glove, settings.punch_damage) and punch.collapses == 0,
			"the glove strikes first (%.0f dmg), nothing else yet" % after_glove)
	await _until(func() -> bool: return punch.collapses > 0, 30)
	var total := full - horde.enemy_hp(struck)
	check(is_equal_approx(total, settings.punch_damage * (1.0 + settings.punch_collapse_share)),
			"then the bubble collapses: %.0f in all (%.0f + %.0f)" % [total, after_glove, total - after_glove])
	check(_hurt(beside) and not _hurt(far), "the collapse hits the zombie beside it too, not one 6 m off")
	await _ticks(10)
	check(horde.enemy_position(struck).z < struck_at.z - 0.3, "the strike knocks it back (%.1f m)" % (struck_at.z - horde.enemy_position(struck).z))

	print("the glove fades and is gone at its range:")
	punch = await _use()
	punch.punch(Vector3.FORWARD)
	var glove: Dictionary = punch.gloves[0]
	var life: float = glove.total
	var flight := roundi(life * Engine.physics_ticks_per_second)
	await _ticks(roundi(flight * 0.4))
	var early := (glove.node as MeshInstance3D).material_override.albedo_color.a as float
	await _ticks(roundi(flight * 0.4))
	var late := (glove.node as MeshInstance3D).material_override.albedo_color.a as float
	check(is_equal_approx(early, 1.0) and late < 0.8 and late > 0.0, "solid at 40%% of its flight (%.2f), fading at 80%% (%.2f)" % [early, late])
	await _ticks(roundi(flight * 0.3) + 2)
	check(punch.gloves.is_empty(), "gone past its range (%.1f m in %.2f s)" % [punch.reach(), life])

	print("quantity: a one-two:")
	punch = await _use()
	run.block_of(fish).add("quantity", 1.0)
	run._apply_stats(fish)
	punch.punch(Vector3.FORWARD)
	var first_at: Vector3 = punch.gloves[0].at
	check(punch.gloves_thrown == 1, "one glove now")
	await _ticks(roundi(settings.punch_follow_gap * Engine.physics_ticks_per_second) + 2)
	check(punch.gloves_thrown == 2, "the follow-up %.2f s later" % settings.punch_follow_gap)
	var second_at: Vector3 = punch.gloves[-1].at
	check(absf(second_at.x - first_at.x) > CavitationPunch.CLAW_APART * 0.5, "from the other claw")

	print("milestones:")
	punch = await _use()
	var normal_ring := punch.collapse_radius()
	_set_level(punch, settings.milestone_level(1))
	check(is_equal_approx(punch.collapse_radius(), normal_ring * CavitationPunch.RING_GROW), "Lv %d: a wider collapse ring" % settings.milestone_level(1))
	_set_level(punch, settings.milestone_level(2))
	var stunned := horde.spawn(1, Vector3(0, 0, -4))
	await _until(func() -> bool: return punch.collapses > 0, 90)
	check(horde.slow_share(stunned) >= 1.0, "Lv %d: collapses stun" % settings.milestone_level(2))
	punch = await _use()
	_set_level(punch, settings.milestone_level(3))
	punch.cooldown_left = 60.0  # only this punch
	var front := horde.spawn(1, Vector3(0, 0, -3.5))
	var back := horde.spawn(1, Vector3(0, 0, -6.5))
	punch.punch(Vector3.FORWARD)
	await _ticks(40)
	check(_hurt(front) and _hurt(back) and punch.glove_hits == 2 and punch.collapses == 2,
			"Lv %d: the glove punches through one, collapsing at each (%d hits, %d collapses)" % [settings.milestone_level(3), punch.glove_hits, punch.collapses])
	punch = await _use()
	_set_level(punch, settings.milestone_level(4))
	for n in CavitationPunch.HAYMAKER_EVERY:
		punch.punch(Vector3.FORWARD)
	var biggest := 0.0
	for g: Dictionary in punch.gloves:
		biggest = maxf(biggest, float(g.radius))
	check(punch.haymakers == 1 and is_equal_approx(biggest, punch.glove_radius() * CavitationPunch.HAYMAKER_SIZE),
			"Lv %d: every third punch is a Haymaker, twice the glove" % settings.milestone_level(4))

	print("recoil dash:")
	settings.twists = true
	settings.punch_cooldown = 60.0  # only the skill's punches
	await _be()
	var twist := run.twist_of(fish)
	run.attack_of(fish).cooldown_left = 60.0
	var ahead := horde.spawn(1, Vector3(0, 0, -4))
	fish.freeze = false
	check(twist.recoil_heading().is_equal_approx(fish.global_basis.z), "stick neutral: it goes backwards")
	check(twist.mobility() and twist.recoils == 1, "it goes off")
	await _ticks(3)
	var own := run.attack_of(fish) as CavitationPunch
	check(absf(fish.linear_velocity.dot(Vector3.BACK) - settings.recoil_speed) < settings.recoil_speed * 0.2 and run.health_of(fish).iframes_left > 0.0,
			"thrown back at %.1f m/s, untouchable" % fish.linear_velocity.dot(Vector3.BACK))
	check(own.gloves_thrown == 1 and not own.gloves.is_empty() and (own.gloves[0].velocity as Vector3).normalized().dot(Vector3.FORWARD) > 0.99,
			"the punch goes the other way: ahead")
	await _ticks(30)
	check(_hurt(ahead) and run.stats_of(fish).by_source.get("punch", 0.0) > 0.0, "and lands on the zombie in front")
	check(not twist.mobility(), "then a cooldown")
	await _be()
	twist = run.twist_of(fish)
	Input.action_press("stick_right", 1.0)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var leaning := twist.recoil_heading()
	check(leaning.is_equal_approx(fish.global_basis.x), "stick held right: it goes right (%s)" % leaning)
	fish.freeze = false
	twist.mobility()
	await _ticks(3)
	Input.action_release("stick_right")
	own = run.attack_of(fish) as CavitationPunch
	check(absf(fish.linear_velocity.dot(Vector3.RIGHT) - settings.recoil_speed) < settings.recoil_speed * 0.2, "thrown right (%.1f m/s)" % fish.linear_velocity.dot(Vector3.RIGHT))
	check(not own.gloves.is_empty() and (own.gloves[0].velocity as Vector3).normalized().dot(Vector3.LEFT) > 0.99, "and punches left")
	settings.fish_attack = FishAttack.Kind.LASH
	await _be()
	twist = run.twist_of(fish)
	var spare := twist.punch_for_recoil()
	check(spare != null and run.attack_of(fish) is ShockLash, "another attack from the panel: the skill still punches (a spare)")
	settings.fish_attack = FishAttack.Kind.OWN

	print("heavy hitter:")
	settings.punch_cooldown = 0.7
	settings.heavy_time = 1.0
	await _be()
	twist = run.twist_of(fish)
	punch = run.attack_of(fish) as CavitationPunch
	punch.cooldown_left = 60.0
	var missile := horde.spawn(1, Vector3(0, 0, -4))
	var hit_by_it := horde.spawn(1, Vector3(0, 0, -9))  # past the collapse ring, in the line it's knocked along
	punch.punch(Vector3.FORWARD)
	await _ticks(90)
	check(twist.flings >= 1 and twist.fling_hits >= 1 and _hurt(hit_by_it) and run.stats_of(fish).by_source.get("heavy_hitter", 0.0) > 0.0,
			"the punched zombie flies into the one behind it (%d flung, %d hit)" % [twist.flings, twist.fling_hits])
	settings.twists = false
	await _be()
	twist = run.twist_of(fish)
	punch = run.attack_of(fish) as CavitationPunch
	punch.cooldown_left = 60.0
	missile = horde.spawn(1, Vector3(0, 0, -4))
	hit_by_it = horde.spawn(1, Vector3(0, 0, -9))
	punch.punch(Vector3.FORWARD)
	await _ticks(90)
	check(twist.flings == 0 and not _hurt(hit_by_it), "twists off: no missiles")
	settings.heavy_time = 0.35

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## The fish's own punch, parked at the middle facing forward, the horde cleared.
func _use() -> CavitationPunch:
	await _be()
	var attack := run.attack_of(fish) as CavitationPunch
	attack.cooldown_left = 0.0
	return attack


## The Mantis Shrimp, parked, a fresh attack and twist, the horde cleared.
func _be() -> void:
	horde.clear()
	fish.character = FishCharacter.FishClass.BRAWLER
	run.block_of(fish).reset()
	var attack := run.attack_of(fish)
	if attack:
		attack.on_removed()
	var twist := run.twist_of(fish)
	if twist:
		twist.reset()
		twist.recoils = 0
		twist.flings = 0
		twist.fling_hits = 0
	await _park(Vector3.ZERO, Vector3.FORWARD)
	await _ticks(2)
	run._apply_stats(fish)
	var punch := run.attack_of(fish) as CavitationPunch
	if punch:
		_set_level(punch, 1)
		punch.gloves_thrown = 0
		punch.glove_hits = 0
		punch.collapses = 0
		punch.haymakers = 0
		punch._punches = 0


func _set_level(attack: FishAttack, level: int) -> void:
	attack.level = level
	attack.milestones = settings.milestones_at(level)


func _hurt(index: int) -> bool:
	return horde.is_alive(index) and horde.enemy_hp(index) < horde.enemy_kind(index).hp * settings.enemy_hp_scale - 0.01


func _until(done: Callable, most: int) -> void:
	for n in most:
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
