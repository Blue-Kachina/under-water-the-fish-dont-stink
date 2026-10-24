extends Node
## The final bosses (the King of Herrings and its alternates) in the real game:
## the pick (the King, or an alternate by alternate_boss_chance; final_boss
## forces one); each builds its seamless body (one bent mesh) with its proxies,
## takes hits and changes phase; the Gulper gulps zombies and heals, and grabs
## a player who strides free; the Lamprey's gills take gill_bonus damage, its
## brood drops off as zombies, and it grabs too; the Whale Fall's hagfish hold
## their own hp (dying one by one, their proxies gone), the carcass is armoured
## while any live, and in fury they tear loose; the Fallen Angel hangs upright,
## its head and gut take angel_weak damage, it opens its crown (the wind-up,
## its lane showing) then lashes: a lash grabs a player who didn't stride, is
## dodged by one who did, eats the zombies it catches, and it sheds Sea
## Butterflies; and beaten, any of them opens the whirlpool and drops the boss
## chest.
##   Godot_console.exe --headless --path . res://tests/final_boss_probe.tscn

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
	settings.chest_count = 0
	settings.shrine_count = 0
	settings.stage_events = false
	settings.twists = false
	settings.base_hp = 100000.0
	settings.enemy_speed_scale = 0.0
	settings.fish_attack = FishAttack.Kind.BITE
	settings.bite_damage = 0.0
	settings.iframes = 0.0
	settings.run_length = 0
	fish.character = FishCharacter.FishClass.HUNTER
	main.set_mode(main.UNNATURAL)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	run = main.unnatural_run
	horde = run.horde

	print("the pick:")
	settings.final_boss = 0
	settings.alternate_boss_chance = 0.0
	check(run.pick_final_boss() == "boss", "chance 0: always the King")
	settings.alternate_boss_chance = 1.0
	var seen := {}
	for n in 60:
		seen[run.pick_final_boss()] = true
	check(seen.size() == 4 and not seen.has("boss"), "chance 1: each alternate, never the King (%s)" % [seen.keys()])
	settings.final_boss = 3
	check(run.pick_final_boss() == "whale", "final_boss forces one")
	settings.final_boss = 0
	settings.alternate_boss_chance = 0.4

	for kind: String in ["boss", "gulper", "whale", "lamprey", "angel"]:
		await _each(kind)
	_finish()


func _each(kind: String) -> void:
	print("%s:" % kind)
	horde.clear()
	await _ticks(2)
	var at := fish.global_position + Vector3(0.0, 0.0, -40.0)
	var boss := UnnaturalRun.make_final_boss(kind)
	run._add_boss(boss, at, 100000.0)
	await _ticks(3)
	check(boss is BloodLeviathan and boss.title != "", "%s comes" % boss.title)
	check(boss.parts.size() == boss.proxy_count(), "its %d proxies" % boss.parts.size())
	var meshes := boss.find_children("*", "MeshInstance3D", true, false)
	var bent := 0
	for node in meshes:
		var mesh := (node as MeshInstance3D).mesh
		if mesh is ArrayMesh and (mesh as ArrayMesh).get_surface_count() == 1 and (node as MeshInstance3D).top_level and mesh.get_faces().size() > 3000:
			bent += 1
	check(bent >= 1, "its body is one seamless bent mesh (%d)" % bent)
	var near := true
	for index in boss.parts:
		near = near and horde.enemy_position(index).distance_to(boss.global_position) < boss.body_length() * 1.5
	check(near, "its proxies lie along its body")
	var before := boss.hp
	run.hit(boss.parts[0], 1000.0, fish, "probe")
	check(boss.hp < before, "a hit on it hurts it (%.0f)" % (before - boss.hp))
	match kind:
		"gulper":
			await _gulper(boss as GulperBoss)
		"lamprey":
			await _lamprey(boss as LampreyBoss)
		"whale":
			await _whale(boss as WhaleFallBoss)
		"angel":
			await _angel(boss as FallenAngelBoss)
	boss.hp = boss.max_hp * 0.6
	boss.take(1.0, fish, "probe")
	check(boss.phase == BloodLeviathan.Phase.SPIT, "at 60% it spits")
	var chests_before := run.chests.size()
	boss.take(boss.hp + 10.0, fish, "probe")
	await _ticks(3)
	check(is_instance_valid(run.whirlpool), "beaten, the whirlpool opens")
	var coil := false
	for n in range(chests_before, run.chests.size()):
		coil = coil or (is_instance_valid(run.chests[n]) and run.chests[n].item == "attack_leviathans_coil")
	check(coil, "and its chest holds the Coil")
	await _ticks(int(Boss.DEATH_TIME * 120) + 10)
	if is_instance_valid(run.whirlpool):
		run.whirlpool.queue_free()
	run.whirlpool = null
	run.cleared_at = -1.0


func _grab(boss: BloodLeviathan) -> void:
	boss.phase = BloodLeviathan.Phase.FURY
	boss._regrab_left = 0.0
	fish.freeze = false
	fish.global_position = boss.mouth_point()
	await _ticks(3)
	check(boss.held == fish, "in fury, a player at its mouth is grabbed")
	var health := run.health_of(fish)
	var hp := health.hp
	await _ticks(130)
	check(health.hp < hp, "held, it drains them (%.0f)" % (hp - health.hp))
	for n in settings.final_hold_strides:
		fish.strode.emit(1.0, 1.0)
	await _ticks(3)
	check(boss.held == null, "%d strides break free" % settings.final_hold_strides)
	fish.global_position = run.centre + Vector3(0.0, 0.0, 60.0)
	boss.phase = BloodLeviathan.Phase.CIRCLE
	await _ticks(2)


func _gulper(boss: GulperBoss) -> void:
	boss.hp = boss.max_hp * 0.5
	var mouth := boss.mouth_point()
	for n in 12:
		horde.spawn(0, mouth + Vector3(sin(n) * 4.0, cos(n * 1.3) * 2.0, cos(n) * 4.0))
	boss._gulp_left = 0.0
	await _ticks(int(GulperBoss.GULP_TIME * 120))
	check(boss.swallowed > 0 and boss.hp > boss.max_hp * 0.5, "a gulp swallows %d zombies and heals it" % boss.swallowed)
	await _grab(boss)


func _lamprey(boss: LampreyBoss) -> void:
	var gill := boss._gill_parts[0]
	var body := boss.parts[3]
	var a := boss.hp
	run.hit(gill, 100.0, null, "probe")
	var gill_took := a - boss.hp
	a = boss.hp
	run.hit(body, 100.0, null, "probe")
	var body_took := a - boss.hp
	check(absf(gill_took - body_took * settings.gill_bonus) < 1.0, "its gills take %.1fx (%.0f vs %.0f)" % [settings.gill_bonus, gill_took, body_took])
	var alive := horde.alive_count()
	boss._brood_left = 0.0
	await _ticks(10)
	check(horde.alive_count() >= alive + settings.brood_count, "one of its brood drops off as %d zombies" % settings.brood_count)
	horde.clear()
	await _ticks(2)
	await _grab(boss)


func _whale(boss: WhaleFallBoss) -> void:
	check(boss.hagfish.size() == settings.hagfish_count, "%d hagfish" % boss.hagfish.size())
	var h: WhaleFallBoss.Hagfish = boss.hagfish[0]
	var pool := h.hp
	var a := boss.hp
	run.hit(boss.parts[1], 100.0, null, "probe")
	check(absf((a - boss.hp) - 100.0 * settings.carcass_armour) < 1.0, "the carcass is armoured while they live (%.0f of 100)" % (a - boss.hp))
	run.hit(h.parts[0], 100.0, null, "probe")
	check(h.hp < pool, "a hit on a hagfish goes to its own hp")
	var its := h.parts.duplicate()
	run.hit(h.parts[0], pool + 10.0, null, "probe")
	await _ticks(2)
	var gone := true
	for index in its:
		gone = gone and not horde.is_alive(index)
	check(not h.alive and gone and not boss.parts.has(its[0]), "at no hp it dies, its proxies gone")
	for other in boss.hagfish:
		if other.alive:
			run.hit(other.parts[0], other.hp + 10.0, null, "probe")
	await _ticks(2)
	a = boss.hp
	run.hit(boss.parts[1], 100.0, null, "probe")
	check(not boss.any_alive() and absf((a - boss.hp) - 100.0) < 1.0, "all dead: the carcass takes full damage")
	var fresh := UnnaturalRun.make_final_boss("whale") as WhaleFallBoss
	run._add_boss(fresh, fish.global_position + Vector3(30.0, 0.0, 0.0), 100000.0)
	await _ticks(3)
	fresh.hp = fresh.max_hp * 0.3
	fresh.take(1.0, fish, "probe")
	await _ticks(3)
	check(fresh.hagfish.all(func(x: WhaleFallBoss.Hagfish) -> bool: return x.loose), "in fury the hagfish tear loose")
	fresh.queue_free()
	run.bosses.erase(fresh)


func _angel(boss: FallenAngelBoss) -> void:
	var head := boss.rig.points[0]
	var tail := boss.rig.points[SpineRig.SPINE_N - 1]
	check(head.y - tail.y > boss.height() * 0.6, "it hangs upright, head up (%.0f m over its tail)" % (head.y - tail.y))
	boss.hp = boss.max_hp
	var before := boss.hp
	run.hit(boss.parts[4], 1000.0, fish, "probe")
	var tail_hit := before - boss.hp
	before = boss.hp
	run.hit(boss.parts[0], 1000.0, fish, "probe")
	var head_hit := before - boss.hp
	check(head_hit > tail_hit * (settings.angel_weak - 0.05), "its glowing head takes %.1fx a tail hit" % (head_hit / maxf(tail_hit, 0.01)))
	# The crown, then the flurry: a player in front of it, not striding, is caught.
	fish.freeze = false
	fish.global_position = boss.global_position + boss.facing * settings.angel_lash_reach * 0.5
	fish.freeze = true
	await _ticks(2)
	boss._start_crown()
	var lane := false
	var opened := 0.0
	for n in int(settings.angel_crown * 120) + 4:
		await get_tree().physics_frame
		lane = lane or not boss.telegraph().is_empty()
		opened = maxf(opened, boss.crown_open)
		if boss.state != FallenAngelBoss.State.CROWN:
			break
	check(lane and opened > 0.9, "its crown bursts open over angel_crown s, its lane showing (%.2f open)" % opened)
	check(boss.state == FallenAngelBoss.State.FLURRY, "then it tumbles in")
	await _until(func() -> bool: return boss.held != null or boss.state == FallenAngelBoss.State.HOVER, int(settings.angel_flurry * 120) + 20)
	check(boss.held == fish and boss.lashes >= 1, "a lash catches a player who didn't stride (%d lashes)" % boss.lashes)
	for n in settings.final_hold_strides:
		fish.strode.emit(1.0, 1.0)
	await _ticks(3)
	check(boss.held == null, "strides break free of its crown")
	# A timed stride dodges a lash.
	await _ticks(int(2.6 * 120))
	fish.freeze = false
	fish.global_position = boss.global_position + boss.facing * settings.angel_lash_reach * 0.5
	fish.freeze = true
	boss._regrab_left = 0.0
	var dodged := boss.dodged
	boss._start_crown()
	for n in int((settings.angel_crown + settings.angel_flurry) * 120) + 10:
		fish.strode.emit(1.0, 1.0)  # striding all the while: each lash is dodged
		await get_tree().physics_frame
		if boss.state == FallenAngelBoss.State.HOVER:
			break
	check(boss.dodged > dodged and boss.held == null, "a stride just before a lash dodges it (%d dodged)" % (boss.dodged - dodged))
	# Zombies in a lash's way are eaten, and heal it.
	fish.global_position = run.centre + Vector3(0.0, 0.0, 80.0)
	await _ticks(2)
	boss.hp = boss.max_hp * 0.5
	var eaten := boss.eaten
	for n in 8:
		horde.spawn(1, boss.global_position + boss.facing * 4.0 + Vector3(n * 0.4 - 1.6, 0.0, 0.0))
	await _ticks(14)
	boss._lash(boss.facing * 4.0)
	check(boss.eaten > eaten and boss.hp > boss.max_hp * 0.5, "its lashes eat the zombies they catch, healing it (%d)" % (boss.eaten - eaten))
	boss.state = FallenAngelBoss.State.HOVER
	# Sea Butterflies.
	var shed := boss.butterflies_shed
	boss._shed()
	await _ticks(14)
	var flutter := 0
	for i in horde.alive:
		if horde.enemy_kind(i).id == "butterfly":
			flutter += 1
	check(boss.butterflies_shed - shed == settings.angel_butterflies and flutter >= settings.angel_butterflies,
			"it sheds %d Sea Butterflies" % (boss.butterflies_shed - shed))
	horde.clear()
	await _ticks(2)


func _until(done: Callable, most: int) -> void:
	for n in most:
		if done.call():
			return
		await get_tree().physics_frame


func _finish() -> void:
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
