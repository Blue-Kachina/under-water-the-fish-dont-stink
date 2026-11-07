extends Node
## The bosses' signature moves (the memorable-bosses pass) in the real game:
## the Drowned Shark's jaw drops open and snaps shut on a player ahead of it,
## biting them; the King of Herrings chomps the same way in any phase, and in
## fury coils round a player it reaches (its body wound round them, tightening,
## three strides and they're out); the Gulper sucks a player in front of its
## mouth toward it, swallows them (hidden, a lump in its belly) and coughs them
## out the front; the Lamprey lunges with her disc flared and corkscrews on a
## player she latches onto; a Whale Fall hagfish bites a player and ties
## itself in a knot; the Fallen Angel locks on (shadowing a moving player,
## its halo round them) then opens its crown. Every grab draws the player in
## (not a snap), pulls their camera back, and shows the break-free panel.
##   Godot_console.exe --headless --path . res://tests/boss_moves_probe.tscn

var main: Node
var fish: FishController
var settings := UnnaturalSettings.shared()
var run: UnnaturalRun
var horde: Horde
var hud: UnnaturalHud
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
	hud = main._unnatural_hud
	await _shark()
	await _king()
	await _gulper()
	await _lamprey()
	await _whale()
	await _angel()
	await _pressure()
	print("FAILURES: %d" % failures if failures else "ALL PASS")
	get_tree().quit(1 if failures else 0)


func _place(at: Vector3) -> void:
	fish.freeze = false
	fish.global_position = at
	fish.linear_velocity = Vector3.ZERO
	fish._ball_push = Vector3.ZERO  # a chomp's knockback, saved up while frozen
	fish.freeze = true


func _boss(boss: Boss, at: Vector3) -> Boss:
	horde.clear()
	await _ticks(2)
	run._add_boss(boss, at, 100000.0)
	await _ticks(3)
	return boss


func _gone(boss: Boss) -> void:
	if boss is BloodLeviathan:
		(boss as BloodLeviathan).release()
	run.bosses.erase(boss)
	boss.queue_free()
	fish.set_model_visible(true)
	await _ticks(3)


## A grab's shared checks: drawn in, not snapped; the camera pulls back; the
## panel shows; strides free them.
func _held_checks(boss: BloodLeviathan, verb: String) -> void:
	check(boss.held == fish and boss.hold_verb() == verb, "%s: it grabs them (%s)" % [boss.title, boss.hold_verb()])
	await _ticks(60)
	check(run.camera_pull_of(fish) > settings.grab_camera_pull * 0.6, "held, their camera pulls back (%.0f m)" % run.camera_pull_of(fish))
	check(hud._break.visible and hud._break.verb == verb and hud._break.who == boss.title, "the break-free panel shows: %s  ·  %s" % [hud._break.verb, hud._break.who])
	fish.strode.emit(1.0, 1.0)
	await _ticks(10)
	check(hud._break.strides == 1, "a stride lights one of its %d diamonds" % hud._break.needed)
	for n in settings.final_hold_strides - 1:
		fish.strode.emit(1.0, 1.0)
	await _ticks(3)
	check(boss.held == null, "strides break free")
	await _ticks(40)
	check(not hud._break.visible, "and the panel goes")


func _shark() -> void:
	print("the Drowned Shark:")
	var shark := DrownedShark.new()
	await _boss(shark, fish.global_position + Vector3(0.0, 0.0, -60.0))
	shark._charge_left = 100.0
	shark._chomp_cool = 0.0
	_place(shark.mouth_point() - shark.global_basis.z * settings.shark_chomp_reach * 0.5)
	var health := run.health_of(fish)
	var hp := health.hp
	var widest := 0.0
	var open_at_bite := -1.0
	var lifted := 0.0
	var start_at := shark.global_position
	var camera := ChompKit._camera_of(fish)
	var punched := 0.0
	var froze := 0.0
	var flushed := 0.0
	for n in int((settings.shark_chomp_wind + settings.chomp_strike) * 120) + 40:
		await get_tree().physics_frame
		widest = maxf(widest, shark.jaw)
		lifted = maxf(lifted, shark._model.rotation.x)
		if open_at_bite < 0.0 and shark.chomp_hits > 0:
			open_at_bite = shark.jaw
			punched = camera.get("_punch") if camera else 0.0
			froze = shark.hit_stop
			flushed = hud.hurt_level
	check(widest > 0.9 and lifted > settings.chomp_lift * 0.5, "a player ahead: its snout lifts (%.2f rad) and its jaw drops open (%.2f)" % [lifted, widest])
	check(shark.chomps >= 1 and shark.chomp_hits >= 1 and health.hp < hp, "it snaps shut, biting them (%.0f)" % (hp - health.hp))
	check(open_at_bite >= 0.0 and open_at_bite <= 1.0 - settings.chomp_contact + 0.001,
			"the bite lands only once its jaws are %.0f%% shut (open %.2f then)" % [settings.chomp_contact * 100.0, open_at_bite])
	var lunged := (shark.global_position - start_at).dot(-shark.global_basis.z)
	check(lunged > settings.shark_chomp_reach * settings.chomp_lunge * 0.5, "its head lunges in as it strikes (%.1f m)" % lunged)
	check(camera != null and punched > settings.chomp_cam_shake * 0.5, "the bitten player's camera punches (%.2f m)" % punched)
	check(froze > 0.0 and flushed >= settings.chomp_vignette * 0.9, "hit-stop on the shark (%.2f s) and a strong red flush (%.2f)" % [froze, flushed])
	var fx := run.get_node_or_null("ChompFx") as ChompKit.Fx
	check(fx != null and fx.blood.emitting and fx.teeth.emitting, "blood and tooth sparks burst at its jaws")
	var big := 0
	for code in hud.numbers._crit:
		big += 1 if code == DamageNumbers.BITTEN else 0
	check(big >= 1, "the bite's damage shows big, in red")
	check(shark._jaw._lower and shark._jaw._lower.rotation.x < -0.3 or shark.jaw < 0.5, "its jaw turns on its hinge")
	await _ticks(60)
	check(shark.jaw < 0.2, "then shuts")
	# A player who leaves its reach during the hold takes no bite: a clack on nothing.
	shark._chomp_cool = 0.0
	_place(shark.mouth_point() - shark.global_basis.z * settings.shark_chomp_reach * 0.5)
	var held_wide := false
	for n in 240:
		await get_tree().physics_frame
		if shark._bite.phase == ChompKit.Phase.HOLD:
			held_wide = true
			break
	var hits := shark.chomp_hits
	var chomped := shark.chomps
	_place(shark.mouth_point() + shark.global_basis.x * settings.shark_chomp_reach * 3.0)
	for n in 60:
		await get_tree().physics_frame
	check(held_wide and shark.chomps == chomped + 1 and shark.chomp_hits == hits,
			"a player who leaves its reach during the hold isn't bitten (chomps %d, bites %d)" % [shark.chomps - chomped, shark.chomp_hits - hits])
	await _gone(shark)


func _king() -> void:
	print("the King of Herrings:")
	var king := UnnaturalRun.make_final_boss("boss") as BloodLeviathan
	await _boss(king, fish.global_position + Vector3(0.0, 0.0, -60.0))
	check(king.chomps() and king.coils(), "it chomps and coils")
	king._chomp_cool = 0.0
	king._dive_left = 100.0
	_place(king.mouth_point() - king.rig.frame_at(0.0).basis.z * settings.king_chomp_reach * 0.5)
	var health := run.health_of(fish)
	var hp := health.hp
	var widest := 0.0
	var open_at_bite := -9.0
	var sawed := 0.0
	for n in int((settings.king_chomp_wind + settings.chomp_strike + settings.chomp_shake) * 120) + 30:
		await get_tree().physics_frame
		widest = maxf(widest, king.jaw)
		sawed = maxf(sawed, absf(king.rig.twist))
		if open_at_bite < -5.0 and king.chomp_hits > 0:
			open_at_bite = king.jaw
	check(widest > 0.9 and king.chomp_count >= 1 and health.hp < hp, "in its first phase, it chomps: jaw gaping (%.2f), a bite (%.0f)" % [widest, hp - health.hp])
	check(open_at_bite > -5.0 and open_at_bite <= 1.0 - settings.chomp_contact + 0.001,
			"its bite lands only once its jaws are %.0f%% shut (jaw %.2f then)" % [settings.chomp_contact * 100.0, open_at_bite])
	check(sawed > settings.chomp_saw * 0.5, "jaws shut, it saws round its length (%.2f rad)" % sawed)
	var hinge: Vector3 = king._jaw_skin.get_shader_parameter("hinge")
	check(king._jaw_skin != null and absf(hinge.x) > 0.1, "its jaw is hinged in the shader (%.2f rad)" % hinge.z)
	# Fury: a player at its mouth is coiled round. (Its hp says fury too: any
	# hit, even the probe fish's harmless bites, sets its phase from its hp.)
	king.hp = king.max_hp * 0.2
	king.phase = BloodLeviathan.Phase.FURY
	king._regrab_left = 0.0
	_place(king.mouth_point())
	await _ticks(3)
	var caught := king.held == fish
	await _ticks(120)
	var round := 0
	for p in king.rig.points:
		var flat := Vector3(p.x - fish.global_position.x, 0.0, p.z - fish.global_position.z)
		if flat.length() < settings.coil_radius * 1.6:
			round += 1
	check(caught and round > SpineRig.SPINE_N * 0.4, "coiled: %d of its %d spine points wound round them" % [round, SpineRig.SPINE_N])
	check(king._coil_tight > 0.3 and king.hold_drain_scale() > 1.2, "the coil tightens, squeezing harder (x%.2f)" % king.hold_drain_scale())
	var tight := king._coil_tight
	king.take(king.max_hp * 0.03, null, "probe")
	check(king._coil_tight < tight, "a friend's hits pry it loose")
	king.release()
	await _ticks(3)
	king._regrab_left = 0.0
	_place(king.mouth_point())
	await _ticks(3)
	await _held_checks(king, "COILED")
	await _gone(king)


func _gulper() -> void:
	print("the Gulper Mother:")
	var gulper := UnnaturalRun.make_final_boss("gulper") as GulperBoss
	await _boss(gulper, fish.global_position + Vector3(0.0, 0.0, -60.0))
	gulper.hp = gulper.max_hp * 0.2
	gulper.phase = BloodLeviathan.Phase.FURY
	gulper._regrab_left = 0.0
	var forward := -gulper.rig.frame_at(0.0).basis.z
	fish.freeze = false
	fish.global_position = gulper.mouth_point() + forward * settings.gulper_suck_range * 0.6
	fish.linear_velocity = Vector3.ZERO
	var start := fish.global_position.distance_to(gulper.mouth_point())
	var sucked := false
	for n in 40:
		await get_tree().physics_frame
		sucked = sucked or gulper.sucking
		if gulper.held:
			break
	check(sucked and (gulper.held == fish or fish.global_position.distance_to(gulper.mouth_point()) < start - 0.5),
			"in fury, a player in front of its mouth is sucked in (%.1f m closer)" % (start - fish.global_position.distance_to(gulper.mouth_point())))
	fish.freeze = true
	_place(gulper.mouth_point())
	await _ticks(3)
	check(gulper.held == fish and not fish._visual.visible, "reached, they're swallowed: out of sight")
	await _ticks(100)
	check(gulper._lump_z > gulper.mouth_length() and gulper._gape < 0.0, "a lump slides down into its belly, its jaws shut (z %.0f m)" % gulper._lump_z)
	var lump: Vector3 = gulper.skins[0].get_shader_parameter("lump")
	check(lump.z > 0.2, "its belly bulges round them")
	for n in settings.final_hold_strides:
		fish.strode.emit(1.0, 1.0)
	await _ticks(3)
	var ahead := (fish.global_position - gulper.mouth_point()).dot(-gulper.rig.frame_at(0.0).basis.z)
	check(gulper.held == null and ahead > 0.0, "strides cough them out the front (%.0f m ahead)" % ahead)
	_place(gulper.global_position + Vector3(0.0, 0.0, 80.0))  # clear of its body
	await _ticks(150)
	check(fish._visual.visible, "seen again")
	gulper._regrab_left = 0.0
	_place(gulper.mouth_point())
	await _ticks(3)
	await _held_checks(gulper, "SWALLOWED")
	await _gone(gulper)


func _lamprey() -> void:
	print("the Lamprey Queen:")
	var lamprey := UnnaturalRun.make_final_boss("lamprey") as LampreyBoss
	await _boss(lamprey, fish.global_position + Vector3(0.0, 0.0, -60.0))
	lamprey.hp = lamprey.max_hp * 0.2
	lamprey.phase = BloodLeviathan.Phase.FURY
	var forward := -lamprey.rig.frame_at(0.0).basis.z
	_place(lamprey.mouth_point() + forward * settings.lamprey_lunge_range * 0.6)
	var flared := 0.0
	var lane := false
	for n in int(settings.lamprey_lunge_wind * 120) + 10:
		await get_tree().physics_frame
		flared = maxf(flared, lamprey._disc)
		lane = lane or not lamprey.telegraph().is_empty()
	check(lamprey.lunges >= 1 and flared > 0.5 and lane, "in fury she lunges at a player ahead, disc flaring (%.2f), lane showing" % flared)
	lamprey._regrab_left = 0.0
	_place(lamprey.mouth_point())
	await _ticks(3)
	check(lamprey.held == fish, "her disc latches on")
	await _ticks(60)
	check(absf(lamprey.rig.twist) > 1.0 and lamprey._disc < 0.0, "she corkscrews, disc clamped (%.1f rad)" % lamprey.rig.twist)
	lamprey.release()
	lamprey._regrab_left = 0.0
	await _ticks(3)
	_place(lamprey.mouth_point())
	await _ticks(3)
	await _held_checks(lamprey, "LATCHED ON")
	await _gone(lamprey)


func _whale() -> void:
	print("the Whale Fall:")
	var whale := UnnaturalRun.make_final_boss("whale") as WhaleFallBoss
	await _boss(whale, fish.global_position + Vector3(0.0, 0.0, -60.0))
	var h: WhaleFallBoss.Hagfish = whale.hagfish[0]
	_place(h.head + _exit(whale, h) * 6.0)
	h.state = 2
	h.state_left = WhaleFallBoss.STRIKE
	h.aim = fish.global_position
	var bit := false
	for n in 120:
		await get_tree().physics_frame
		if whale.held:
			bit = true
			break
	check(bit and whale.held == fish and whale._grabber == h and h.state == 4, "a striking hagfish bites a player and holds on")
	var anchor := whale._exit_point(h.index)
	var far := fish.global_position.distance_to(anchor)
	await _ticks(int(settings.hagfish_knot_time * 120) + 30)
	check(fish.global_position.distance_to(anchor) < far - 1.0, "it reels them in toward its hole (%.0f to %.0f m)" % [far, fish.global_position.distance_to(anchor)])
	check(h.knot_size > 0.5 and h.knot > 0.9, "it ties itself in a knot that slides to its head (%.2f tied)" % h.knot_size)
	var clouds := run._clouds.size() if "_clouds" in run else -1
	for n in settings.final_hold_strides:
		fish.strode.emit(1.0, 1.0)
	await _ticks(3)
	check(whale.held == null and h.state == 3, "strides break free, it draws back")
	if clouds >= 0:
		check(run._clouds.size() > clouds, "and it slimes them as it lets go")
	await _ticks(150)
	check(h.knot_size < 0.05, "its knot slips loose")
	await _gone(whale)


func _exit(whale: WhaleFallBoss, h: WhaleFallBoss.Hagfish) -> Vector3:
	return whale._exit_out(h.index)


func _angel() -> void:
	print("the Fallen Angel:")
	settings.enemy_speed_scale = 1.0
	_place(run.centre + Vector3(-30.0, 0.0, 0.0))
	var angel := UnnaturalRun.make_final_boss("angel") as FallenAngelBoss
	await _boss(angel, fish.global_position + Vector3(0.0, 0.0, -40.0))
	angel._start_lock(fish)
	check(angel.state == FallenAngelBoss.State.LOCK and angel.lock_prey == fish, "it locks on to a player")
	# The player swims off; it shadows them.
	var gap := settings.angel_lash_reach * settings.angel_lock_gap
	var worst := 0.0
	var halo := false
	var tether := false
	var most := 0.0
	for n in int(settings.angel_lock_time * 120) + 480:
		fish.freeze = false
		fish.linear_velocity = Vector3(6.0, 0.0, 0.0)  # swimming off
		await get_tree().physics_frame
		if angel._locked_for > 0.0 and angel.state == FallenAngelBoss.State.LOCK:
			worst = maxf(worst, angel.global_position.distance_to(fish.global_position))
		halo = halo or angel._halo.visible
		tether = tether or (angel.state == FallenAngelBoss.State.LOCK and not angel.telegraph().is_empty())
		most = maxf(most, angel.lock_progress())
		if angel.state == FallenAngelBoss.State.CROWN:
			break
	fish.freeze = true
	check(worst < gap * 2.0, "it shadows them as they swim off (never more than %.0f m away, gap %.0f)" % [worst, gap])
	check(halo and tether, "a halo round them and a tether to them while it locks on")
	check(angel.state == FallenAngelBoss.State.CROWN and most >= 1.0, "locked on, its crown opens (state %d, locked %.2f s of %.2f)" % [angel.state, angel._locked_for, angel._locking])
	settings.enemy_speed_scale = 0.0
	await _gone(angel)


## Boss aggression (planning_bosses_and_survival.md §3): every final boss stalks
## a target out of range, and its signature move comes before fury.
func _pressure() -> void:
	print("aggression:")
	settings.enemy_speed_scale = 1.0
	_place(run.centre + Vector3(-40.0, 0.0, 0.0))
	var king := UnnaturalRun.make_final_boss("boss") as BloodLeviathan
	await _boss(king, run.centre + Vector3(60.0, 0.0, 30.0))
	king._dive_left = 100.0
	king._chomp_cool = 100.0
	var far := king.global_position.distance_to(fish.global_position)
	var stalked := false
	for n in 360:
		await get_tree().physics_frame
		stalked = stalked or king.stalking
	var near := king.global_position.distance_to(fish.global_position)
	check(stalked and near < far - 20.0, "the King, its target %.0f m off, stalks it (now %.0f m)" % [far, near])
	settings.enemy_speed_scale = 0.0
	check(not king.grabs(), "in its first phase the King doesn't coil")
	king.hp = king.max_hp * 0.5
	king.phase = BloodLeviathan.Phase.SPIT
	check(king.grabs() and not king.grabbing_now(), "from two thirds it coils (coil_from_phase), as it dives")
	settings.boss_aggression = 2.0
	check(is_equal_approx(king.aggression(), 2.0 * settings.king_aggression), "boss_aggression scales it (x%.2f)" % king.aggression())
	settings.boss_aggression = 1.0
	await _gone(king)
	# The Gulper sucks in its first phase (weaker), its lane showing.
	var gulper := UnnaturalRun.make_final_boss("gulper") as GulperBoss
	await _boss(gulper, fish.global_position + Vector3(0.0, 0.0, -60.0))
	gulper._suck_every = 0.0
	gulper._dive_left = 100.0
	var forward := -gulper.rig.frame_at(0.0).basis.z
	_place(gulper.mouth_point() + forward * settings.gulper_suck_range * 0.6)
	var sucked := false
	var lane := false
	for n in 60:
		await get_tree().physics_frame
		sucked = sucked or gulper.sucking
		lane = lane or not gulper.telegraph().is_empty()
	check(gulper.phase == BloodLeviathan.Phase.CIRCLE and sucked and lane, "the Gulper sucks in its first phase, its lane showing")
	await _gone(gulper)
	# The Lamprey lunges in her first phase.
	var lamprey := UnnaturalRun.make_final_boss("lamprey") as LampreyBoss
	await _boss(lamprey, fish.global_position + Vector3(0.0, 0.0, -60.0))
	lamprey._lunge_cool = 0.0
	lamprey._dive_left = 100.0
	_place(lamprey.mouth_point() - lamprey.rig.frame_at(0.0).basis.z * settings.lamprey_lunge_range * 0.6)
	for n in int(settings.lamprey_lunge_wind * 120) + 10:
		await get_tree().physics_frame
	check(lamprey.phase == BloodLeviathan.Phase.CIRCLE and lamprey.lunges >= 1, "the Lamprey lunges in her first phase")
	await _gone(lamprey)
	# The Whale Fall: from two thirds, hagfish_free_spit tear free and hunt.
	var whale := UnnaturalRun.make_final_boss("whale") as WhaleFallBoss
	await _boss(whale, fish.global_position + Vector3(0.0, 0.0, -30.0))
	await _ticks(10)
	var loose_before := whale.hagfish.filter(func(h: WhaleFallBoss.Hagfish) -> bool: return h.loose).size()
	whale.hp = whale.max_hp * 0.5
	whale.phase = BloodLeviathan.Phase.SPIT
	await _ticks(10)
	var loose := whale.hagfish.filter(func(h: WhaleFallBoss.Hagfish) -> bool: return h.loose).size()
	check(loose_before == 0 and loose == settings.hagfish_free_spit, "at two thirds %d hagfish tear free (%d before)" % [loose, loose_before])
	await _gone(whale)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
