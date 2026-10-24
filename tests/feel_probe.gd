extends Node
## Unnatural's feel and readability (the Playability pass, P3) in the real game:
## - damage numbers: one per hit, hits on the same zombie within the merge
##   window add up, a crit's flagged, damage_numbers_min hides small ones,
##   damage_numbers_max caps them, teammates' hidden by default;
## - kill pops: one burst per kill, at most kill_pop_max showing;
## - the target marker: the bite's aim_target() is what it bites, and the HUD
##   lists it; depth assist makes auto-aim pick a zombie at your depth over a
##   nearer one far above, and draws the horde toward its target's depth;
## - threat arrows: an elite behind you and a lunger winding up at you are
##   threats; edge_point() pins what's behind to the view's edge;
## - telegraphs: a winding-up lunger lays a lane, the Leviathan winds up its
##   dives (a lane, then the dive), the shark's charge has one;
## - hurt: a hit flushes the vignette, low hp beats a heartbeat;
## - the camera pulls back in a crowd and with Size;
## - drops: four colours, none alike, each with its beam.
##   Godot_console.exe --headless --path . res://tests/feel_probe.tscn

var main: Node
var fish: FishController
var run: UnnaturalRun
var horde: Horde
var hud: UnnaturalHud
var settings := UnnaturalSettings.shared()
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
	settings.heart_chance = 0.0
	settings.magnet_chance = 0.0
	settings.hourglass_chance = 0.0
	settings.lightning_chance = 0.0
	settings.chest_drop_chance = 0.0
	settings.pearl_drop_chance = 0.0
	settings.god_mode = true
	settings.depth_assist = 0.0
	settings.enemy_hp_scale = 1000.0  # hits don't kill (unless meant to)
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde
	hud = main._unnatural_hud
	await _park(run.centre + Vector3(0, 0, 40), Vector3.FORWARD)
	var ahead := -fish.global_basis.z

	print("damage numbers:")
	var numbers := hud.numbers
	var a := _place(fish.global_position + ahead * 6.0)
	var made := numbers.made
	run.hit(a, 40.0, fish, "bite")
	check(numbers.made == made + 1 and numbers.number_on(a) == [40.0, false], "a hit floats a number (%s)" % [numbers.number_on(a)])
	run.hit(a, 25.0, fish, "greek_fire")
	check(numbers.made == made + 1 and is_equal_approx(numbers.number_on(a)[0], 65.0), "a second hit straight after adds into it (%s)" % [numbers.number_on(a)])
	await _wait(settings.damage_number_merge + 0.1)
	run.hit(a, 10.0, fish, "bite")
	check(numbers.made == made + 2, "after the merge window, a new number")
	run.block_of(fish).add("crit_chance", 5.0)
	var b := _place(fish.global_position + ahead * 7.0 + Vector3.RIGHT * 2.0)
	run.hit(b, 10.0, fish, "bite")
	check(numbers.number_on(b).size() == 2 and numbers.number_on(b)[1] == true, "a crit's number says so")
	run.block_of(fish).add("crit_chance", -5.0)
	settings.damage_numbers_min = 1000.0
	check(numbers.showable() == 0, "damage_numbers_min 1000: none big enough to show (%d up)" % numbers.count())
	settings.damage_numbers_min = 0.0
	check(numbers.showable() == numbers.count() and numbers.count() >= 2, "damage_numbers_min 0: all show (%d)" % numbers.count())
	var before := numbers.made
	run.hit(b, 10.0, null, "contact")
	check(numbers.made == before, "a hit by nobody (or a teammate, by default) floats none")
	settings.damage_numbers_max = 5
	var row := []
	for n in 10:
		row.append(_place(fish.global_position + ahead * 9.0 + Vector3.RIGHT * (n - 5) * 1.5))
	for i: int in row:
		run.hit(i, 5.0, fish, "bite")
	check(numbers.count() == 5, "damage_numbers_max 5: ten hits keep five (%d)" % numbers.count())
	settings.damage_numbers_max = 48
	settings.damage_numbers = false
	before = numbers.made
	run.hit(row[0], 5.0, fish, "bite")
	check(numbers.made == before, "damage_numbers off: none")
	settings.damage_numbers = true
	_clear()

	print("kill pops:")
	var pops := run.kill_pops
	var popped := pops.popped
	var c := _place(fish.global_position + ahead * 6.0)
	run.hit(c, 1.0e7, fish, "bite")
	await _frames(2)
	check(pops.popped == popped + 1 and pops.showing >= 1, "a kill pops a burst (%d showing)" % pops.showing)
	await _wait(KillPops.LIFE + 0.1)
	check(pops.showing == 0, "and it's gone after its life")
	settings.kill_pop_max = 4
	for n in 10:
		var d := _place(fish.global_position + ahead * 8.0 + Vector3.RIGHT * (n - 5) * 1.5)
		run.hit(d, 1.0e7, fish, "bite")
	await _frames(2)
	check(pops.showing == 4, "kill_pop_max 4: ten kills show four (%d)" % pops.showing)
	settings.kill_pop_max = 96
	settings.kill_pop_size = 0.0
	popped = pops.popped
	run.hit(_place(fish.global_position + ahead * 6.0), 1.0e7, fish, "bite")
	check(pops.popped == popped, "kill_pop_size 0: none")
	settings.kill_pop_size = 1.0
	await _ticks(4)
	_clear()

	print("the target marker and depth assist:")
	var bite := run.attack_of(fish)
	var level := _place(fish.global_position + ahead * 5.0)
	var above := _place(fish.global_position + ahead * 3.0 + Vector3.UP * 3.0)
	await _ticks(2)
	check(bite.aim_target() == above, "no assist: the bite aims at the nearest (3.6 m, 3 m above)")
	hud.markers.scan()
	check(hud.markers.targets.size() == 1 and hud.markers.targets[0][0] == above, "and the HUD marks it")
	settings.depth_assist = 1.0
	check(bite.aim_target() == level, "depth assist 1: the one at your depth (5 m) instead")
	hud.markers.scan()
	check(hud.markers.targets.size() == 1 and hud.markers.targets[0][0] == level, "and the mark moves to it")
	settings.target_marker = false
	hud.markers.scan()
	check(hud.markers.targets.is_empty(), "target_marker off: no marks")
	settings.target_marker = true
	settings.depth_assist = 0.0
	_clear()
	var climbs := []
	for assist: float in [0.0, 1.0]:
		var test := Horde.new()
		add_child(test)
		var probe_settings := UnnaturalSettings.new()
		probe_settings.depth_assist = assist
		probe_settings.wander = 0.0
		test.setup(probe_settings, EnemyKind.defaults(), 4, 7)
		test.bounded = false
		test.targets = PackedVector3Array([Vector3.ZERO])
		test.chaseable = PackedByteArray([1])
		var z := test.spawn(1, Vector3(40.0, 12.0, 0.0), Vector3.LEFT)
		for n in 30:
			test.step_once(1.0 / 30.0)
		climbs.append(12.0 - test.enemy_position(z).y)
		test.queue_free()
	check(climbs[1] > climbs[0] * 1.5, "depth assist draws a chaser down to its target's depth sooner (%.1f m vs %.1f m in 1 s)" % [climbs[1], climbs[0]])

	print("threat arrows:")
	var behind := horde.spawn(1, fish.global_position - ahead * 20.0, ahead, true)
	_still(behind)
	_alive_now()  # the horde steps at sim_rate: don't wait on its next step
	hud.markers.scan()
	check(_threat(CombatMarkers.Threat.ELITE, behind), "an elite 20 m behind you is a threat (%s; alive %s, elite %s, %.1f m)" % [
			hud.markers.threats, horde.is_alive(behind), horde.is_elite(behind), horde.enemy_position(behind).distance_to(fish.global_position)])
	var camera := get_viewport().get_camera_3d()
	var place := CombatMarkers.edge_point(camera, Vector2(1280, 720), horde.enemy_position(behind), 40.0)
	check(not place[1] and Rect2(0, 0, 1280, 720).has_point(place[0]), "behind: pinned to the view's edge (%s)" % [place[0]])
	var lunger := _lunger(fish.global_position + ahead * 10.0 + Vector3.RIGHT * 3.0)
	horde.step_once(1.0 / 30.0)
	hud.markers.scan()
	check(horde.telegraphing.has(lunger), "a lunger winding up is listed")
	check(_threat(CombatMarkers.Threat.LUNGE, lunger), "and it's a threat to the player it's after")
	check(hud.markers.threats[0][0] <= CombatMarkers.Threat.LUNGE, "lunges and bosses come before elites")
	settings.threat_arrows = false
	hud.markers.scan()
	check(hud.markers.threats.is_empty(), "threat_arrows off: none")
	settings.threat_arrows = true

	print("telegraphs:")
	await _frames(2)
	check(run.telegraphs.shown == 0, "by default a lunger lays no lane (lunge_lanes off: only bosses get them)")
	settings.lunge_lanes = true
	await _frames(2)
	check(run.telegraphs.shown >= 1, "lunge_lanes on: the lunger lays its lane (%d)" % run.telegraphs.shown)
	settings.telegraph_lines = false
	await _frames(2)
	check(run.telegraphs.shown == 0 and not run.telegraphs.visible, "telegraph_lines off: none")
	settings.telegraph_lines = true
	settings.lunge_lanes = false
	_clear()
	await _ticks(2)
	var shark := DrownedShark.new()
	run._add_boss(shark, fish.global_position + ahead * 30.0, 1000.0)
	await _ticks(2)
	shark.mode = DrownedShark.Mode.TELEGRAPH
	shark._mode_left = settings.shark_telegraph
	var lane := shark.telegraph()
	var lane_length: float = lane.get("length", 0.0)
	check(absf(lane_length - (settings.shark_charge_speed * settings.shark_charge_time + shark._length * 0.5)) < 0.1,
			"the shark's charge has a lane as long as the charge (%.0f m)" % lane_length)
	shark.mode = DrownedShark.Mode.HUNT
	check(shark.telegraph().is_empty(), "and none while it hunts")
	run.bosses.erase(shark)
	shark.queue_free()
	await _ticks(2)
	settings.leviathan_dive_telegraph = 0.5
	var leviathan := BloodLeviathan.new()
	run._add_boss(leviathan, fish.global_position + ahead * 40.0, 1000.0)
	await _ticks(2)
	leviathan._dive_left = 0.0
	var dives := leviathan.dives
	await _ticks(3)
	check(leviathan.winding_up() and not leviathan.telegraph().is_empty() and leviathan.dives == dives, "the Leviathan winds up a dive first (a lane, no dive yet)")
	await _wait(0.6)
	check(leviathan.dives == dives + 1 and not leviathan.winding_up(), "then it dives")
	check((leviathan._net_mode() & 7) == leviathan.phase, "its net mode still carries its phase")
	run.bosses.erase(leviathan)
	leviathan.queue_free()
	await _frames(3)  # the HUD's marks drawn with the boss freed since their scan
	await _ticks(2)

	print("hurt:")
	settings.god_mode = false
	var health := run.health_of(fish)
	health.iframes_left = 0.0
	hud.hurt_level = 0.0
	run.hurt(fish, 10.0)
	check(hud.hurt_level >= UnnaturalHud.HURT_MIN, "a hit flushes the vignette (%.2f)" % hud.hurt_level)
	await _wait(1.0)
	check(hud.hurt_level < 0.1, "and it fades (%.2f)" % hud.hurt_level)
	health.hp = health.max_hp * 0.1
	var beat := 0.0
	var until := Time.get_ticks_msec() + 1300
	while Time.get_ticks_msec() < until:
		await _frames(1)
		beat = maxf(beat, hud.beat_level)
	check(hud.low_level > 0.4 and beat > 0.5, "at 10%% hp the heartbeat beats (low %.2f, beat %.2f)" % [hud.low_level, beat])
	health.hp = health.max_hp
	await _frames(2)
	check(hud.low_level == 0.0 and hud.beat_level == 0.0, "back at full: no heartbeat")
	settings.god_mode = true

	print("the camera's pull:")
	settings.camera_pull_rate = 20.0
	await _wait(0.4)
	var calm := run.camera_pull_of(fish)
	for n in settings.camera_crowd_full:
		var angle := TAU * n / settings.camera_crowd_full
		_place(fish.global_position + Vector3(cos(angle), 0.2, sin(angle)) * 8.0)
	await _wait(0.6)
	var crowded := run.camera_pull_of(fish)
	check(calm < 0.2 and absf(crowded - settings.camera_crowd_pull) < 0.3, "a full crowd pulls the camera back camera_crowd_pull (%.2f, was %.2f)" % [crowded, calm])
	_clear()
	run.block_of(fish).add("size", 1.0)
	await _wait(0.6)
	check(absf(run.camera_pull_of(fish) - settings.camera_size_pull) < 0.3, "+100%% Size pulls it back camera_size_pull (%.2f)" % run.camera_pull_of(fish))
	run.block_of(fish).add("size", -1.0)
	settings.camera_pull_rate = 1.0

	print("drops:")
	var tints: Array = Pickup.COLORS
	var apart := INF
	for x in tints.size():
		for y in range(x + 1, tints.size()):
			var p: Color = tints[x]
			var q: Color = tints[y]
			apart = minf(apart, Vector3(p.r - q.r, p.g - q.g, p.b - q.b).length())
	check(apart > 0.3, "the four drops' colours are far apart (closest %.2f)" % apart)
	var drop := run.drop_pickup(Pickup.Kind.MAGNET, fish.global_position + ahead * 20.0)
	await _ticks(1)
	check(is_instance_valid(drop) and drop.beam != null and drop.beam.mesh is CylinderMesh, "a drop sends up its beam")

	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


## Whether the HUD's last scan has `what` as a threat of `kind`.
func _threat(kind: int, what: Variant) -> bool:
	for entry: Array in hud.markers.threats:
		if entry[0] == kind and entry[1] == what:
			return true
	return false


## A still clownfish zombie at `at` (drawn where it is).
func _place(at: Vector3) -> int:
	var i := horde.spawn(1, at, Vector3.FORWARD)
	_still(i)
	horde._position[i] = at
	horde._last_position[i] = at
	horde.grid.build(horde._position, _alive_now())
	return i


func _still(i: int) -> void:
	horde._velocity[i] = Vector3.ZERO


## A swordfish at `at` winding up a lunge at the player.
func _lunger(at: Vector3) -> int:
	var i := _place(at)
	horde._kind[i] = 3
	horde._mode[i] = Horde.Lunge.TELEGRAPH
	horde._mode_left[i] = settings.lunge_telegraph
	horde._lunge[i] = (fish.global_position - at).normalized()
	horde._target[i] = run.players.find(fish)
	return i


## Every live slot (the grid's built from it, so new ones are found at once).
func _alive_now() -> PackedInt32Array:
	var all := PackedInt32Array()
	for i in horde._high:
		if horde._state[i] == Horde.State.ALIVE:
			all.append(i)
	horde.alive = all
	return all


func _clear() -> void:
	horde.clear()
	hud.numbers.clear()


func _park(at: Vector3, facing: Vector3) -> void:
	fish.freeze = false
	fish.revive(Transform3D(Basis.looking_at(facing), at))
	await _ticks(2)
	fish.freeze = true


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
