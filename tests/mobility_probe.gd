extends Node
## Every fish's mobility skill on the boost button (the rest are in
## attack_probe and new_fish_probe): the Clownfish's Wriggle, the Shark's Fin
## Dash, the String Ray's Surge, the Boxfish's Brace; boosting is off in
## Unnatural, cooldowns hold, and the HUD has a readout.
##   Godot_console.exe --headless --path . res://tests/mobility_probe.tscn

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
	settings.enemy_speed_scale = 0.0
	settings.enemy_hp_scale = 100.0
	settings.difficulty_per_minute = 0.0
	settings.enemy_damage_scale = 0.0
	settings.chest_count = 0
	settings.twists = true
	fish.boost_enabled = true
	fish.character = FishCharacter.Family.DOMINUS
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde

	check(not fish.boost_enabled, "boosting is off in Unnatural: the button is the skill")
	await _be(FishCharacter.Family.DOMINUS)
	var twist := run.twist_of(fish)
	var victim := horde.spawn(1, Vector3(0, 0, -6))
	await _ticks(4)
	check(twist.mobility() and twist.fin_dashes == 1, "Shark, Fin Dash goes off")
	var top := 0.0
	for t in 60:
		await get_tree().physics_frame
		top = maxf(top, fish.speed)
	check(top > settings.fin_dash_speed * 0.6, "a charge at %.0f m/s" % top)
	check(run.stats_of(fish).by_source.get("fin_dash", 0.0) > 0.0, "it hurts what it passes")
	check(not twist.mobility() and twist.skill_wait() > 0.0, "then a cooldown (%.1f s)" % twist.skill_wait())
	await _ticks(roundi(settings.fin_cooldown * 120.0) + 30)
	check(twist.skill_wait() == 0.0 and twist.mobility(), "ready again after it")

	await _be(FishCharacter.Family.OCTANE)
	twist = run.twist_of(fish)
	var x_before := fish.global_position.x
	check(twist.mobility() and twist.wriggles == 1, "Clownfish, Wriggle goes off")
	await _ticks(20)
	check(absf(fish.linear_velocity.dot(fish.global_basis.z)) > 3.0 or absf(fish.linear_velocity.x) > 3.0 or fish.global_position.distance_to(Vector3.ZERO) > 0.5,
			"it bursts away (%.1f m/s)" % fish.speed)

	await _be(FishCharacter.Family.PLANK)
	twist = run.twist_of(fish)
	check(twist.mobility() and twist.surges == 1, "String Ray, Surge goes off")
	await _ticks(10)
	check(is_equal_approx(fish.drag_scale, 0.0) and fish.speed > settings.surge_speed * 0.5, "no drag, %.0f m/s" % fish.speed)
	await _ticks(roundi(settings.surge_time * 120.0) + 20)
	check(is_equal_approx(fish.drag_scale, settings.glide_drag), "then Glide's drag again")

	await _be(FishCharacter.Family.MERC)
	twist = run.twist_of(fish)
	var taken: float = run.stats_of(fish).taken
	run.hurt(fish, 40.0)
	var plain: float = run.stats_of(fish).taken - taken
	run.health_of(fish).iframes_left = 0.0
	check(twist.mobility() and twist.braces == 1, "Boxfish, Brace goes off")
	taken = run.stats_of(fish).taken
	run.hurt(fish, 40.0)
	var braced: float = run.stats_of(fish).taken - taken
	check(braced < plain * 0.5, "it takes much less (%.1f against %.1f)" % [braced, plain])
	check(twist.speed_factor() < settings.armour_speed, "and swims slower (x%.2f)" % twist.speed_factor())

	await _be(FishCharacter.Family.PLANK)
	run.pick(fish, 0) if run.is_picking(fish) else null
	twist = run.twist_of(fish)
	settings.twists = false
	check(not twist.mobility(), "with twists off: no skill")
	settings.twists = true

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _be(family: FishCharacter.Family) -> void:
	horde.clear()
	fish.character = family
	run.twist_of(fish).reset()
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(Vector3.FORWARD), Vector3.ZERO))
	await _ticks(5)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
