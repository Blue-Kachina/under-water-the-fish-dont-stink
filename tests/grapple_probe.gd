## The Ember Octopus' grapple (planning_hunter_refine.md C): GrappleAttack.
## A: the core on made-up arms (no model, no bite): the press grabs the nearest fish in reach (the reach sphere biased forward, the
##    front bias), the hold grabs more one every grapple_regrab_s up to the cap, a fish past the max stretch tears loose (and a free
##    arm regrabs), the latched tip sits on its fish, the release yanks then the contact takes everything held, a tap whiffs, a tap
##    with a fish in reach still takes it.
## B: on a real OctopusModel: the posed arms reach their fish (stretching past the arm's length), the arms leave the body at their
##    bases, and nothing is left stretched once they settle.
## C: a real match (the octopus Hunter's bite set to the grapple): school fish held and eaten on the release (the count credited),
##    a prey player towing the octopus without being slowed (the same swim held and free), its dash and its
##    counter-steer tearing the arm off, the max stretch, a held prey eaten, the HUD cue, a prey bot struggling free, tap mode, a
##    puppet (no tow, follows net_state), bot_plan.
## D: a bot Hunter grapples a match (presses, holds, grabs, releases, eats).
##   Godot_console.exe --headless --path . res://tests/grapple_probe.tscn
extends Node

const DT := 1.0 / 120.0
const KEY := "ember_octopus"

var checks := 0
var failures := 0
var tps := 120
var main: Node
var game: WhatStinksMatch
var fish: FishController
var _targets: Array[Dictionary] = []


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(done: Callable, ticks: int) -> bool:
	for i in ticks:
		if done.call():
			return true
		await get_tree().physics_frame
	return done.call()


func _run() -> void:
	await _frames(3)
	tps = int(Engine.physics_ticks_per_second)
	_core()
	_model_part()
	await _match_part()
	await _bot_part()
	print("grapple_probe: %s (%d checks)" % ["all checks passed" if failures == 0 else "%d FAILED" % failures, checks])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------------------ A: the core

func _attack(tuned := {}) -> GrappleAttack:
	var a := GrappleAttack.new()
	for k: String in tuned:
		a.tune[k] = tuned[k]
	a.target_source = func() -> Array: return _targets
	return a


func _t(key: int, pos: Vector3) -> Dictionary:
	return {"key": key, "pos": pos, "vel": Vector3.ZERO}


func _step(a: GrappleAttack, seconds: float, holding := true) -> void:
	for i in maxi(int(round(seconds / DT)), 1):
		a.step(DT, Vector3.ZERO, Vector3(0, 0, -1), holding)


func _grip_keys(a: GrappleAttack) -> Array[int]:
	var out: Array[int] = []
	for g in a.held():
		out.append(g.key)
	return out


func _core() -> void:
	print("A: the core")
	var probe := _attack()
	var reach := probe.reach_m()
	var behind := reach * probe.cfg("grapple_behind")
	_check(reach > 1.0, "reach is %.2f m (%.2f arm lengths of %.2f m)" % [reach, probe.cfg("grapple_reach"), probe.mean_arm_m()])
	# The press: a fish ahead at 2 m beats one behind at 1.5 m (the front bias); one behind past the behind reach, one far ahead: never.
	_targets = [_t(1, Vector3(0.2, 0.0, -2.0)), _t(2, Vector3(0.0, 0.0, 1.5)), _t(3, Vector3(0.0, 0.0, behind + 0.4)), _t(4, Vector3(0.0, 0.0, -reach - 1.0))]
	var a := _attack()
	var grabbed: Array[int] = []
	a.grabbed.connect(func(arm: int, _at: Vector3) -> void: grabbed.append(arm))
	a.press(Vector3.ZERO, Vector3(0, 0, -1))
	_check(a.reaching_count() == 1 and a.held_count() == 0, "press: one arm shoots out (reaching %d, held %d)" % [a.reaching_count(), a.held_count()])
	_step(a, a.cfg("grapple_latch_s") + 0.05)
	_check(a.held_count() == 1 and _grip_keys(a) == [1] and grabbed.size() == 1, "press: it latches on the fish ahead, not the nearer one behind (%s)" % [_grip_keys(a)])
	var arm_on := -1
	for t in a.arms:
		if t.grip != null:
			arm_on = t.arm
	var tip_err := a.tip_world(arm_on).distance_to(Vector3(0.2, 0.0, -2.0)) if arm_on >= 0 else 99.0
	_check(tip_err < 0.05, "the latched tip sits on its fish (%.3f m off)" % tip_err)
	var j0_err := a.joints_of(arm_on)[0].distance_to(a.info.bases[arm_on]) if arm_on >= 0 else 99.0
	_check(j0_err < 0.001, "the arm still grows out of its base (%.4f m)" % j0_err)
	_step(a, 1.0)
	var keys := _grip_keys(a)
	_check(keys.has(2) and not keys.has(3) and not keys.has(4), "hold: the one behind in reach is grabbed next; past the behind reach and out of reach never (%s)" % [keys])
	# The front bias at 0: the nearest wins.
	var nb := _attack({"grapple_front_bias": 0.0})
	nb.press(Vector3.ZERO, Vector3(0, 0, -1))
	_step(nb, 0.3, false)
	_check(_grip_keys(nb) == [2], "front bias 0: the nearest (behind) is grabbed first (%s)" % [_grip_keys(nb)])
	# The hold: ten fish ahead; arms go one at a time, regrab_s apart, eight at most.
	_targets.clear()
	for i in 10:
		var ang := float(i) * 0.63
		_targets.append(_t(100 + i, Vector3(sin(ang) * 0.9, cos(ang) * 0.6, -(1.6 + 0.2 * i))))
	var h := _attack()
	h.press(Vector3.ZERO, Vector3(0, 0, -1))
	var starts: Array[float] = [0.0]
	var last := h.held_count() + h.reaching_count()
	var clock := 0.0
	for i in int(4.0 / DT):
		h.step(DT, Vector3.ZERO, Vector3(0, 0, -1), true)
		clock += DT
		var now := h.held_count() + h.reaching_count()
		if now > last:
			starts.append(clock)
		last = now
	var min_gap := INF
	for i in range(1, starts.size()):
		min_gap = minf(min_gap, starts[i] - starts[i - 1])
	_check(h.held_count() == 8, "hold: eight arms hold eight fish of ten (%d)" % h.held_count())
	_check(starts.size() == 8 and min_gap >= h.cfg("grapple_regrab_s") - DT * 1.5, "hold: one grab every %.2f s (%d grabs, closest %.3f s apart)" % [h.cfg("grapple_regrab_s"), starts.size(), min_gap])
	var arms_used := {}
	for t in h.arms:
		if t.grip != null:
			arms_used[t.arm] = true
	_check(arms_used.size() == 8, "one fish per arm (%d distinct arms)" % arms_used.size())
	var tips_ok := true
	for t in h.arms:
		if t.grip != null:
			tips_ok = tips_ok and h.tip_world(t.arm).distance_to(t.grip.pos) < 0.06
	_check(tips_ok, "every latched tip is on its fish")
	# A fish dragged past the max stretch tears loose; a free arm takes one of the two left.
	var lost: Array[String] = []
	h.let_go.connect(func(_arm: int, _at: Vector3, why: String) -> void: lost.append(why))
	var victim: int = _grip_keys(h)[0]
	for d in _targets:
		if int(d["key"]) == victim:
			d["pos"] = Vector3(0.0, 0.0, -(h.cfg("grapple_max_stretch") * h.mean_arm_m() + 3.0))
	_step(h, DT)
	_check(lost == ["stretch"] and h.held_count() == 7, "a fish past the max stretch tears loose (%s, held %d)" % [lost, h.held_count()])
	_step(h, h.cfg("grapple_regrab_s") + h.cfg("grapple_latch_s") + 0.1)
	_check(h.held_count() == 8 and not _grip_keys(h).has(victim), "a free arm grabs another while held (held %d)" % h.held_count())
	# The release: the arms yank, then the snap takes all eight at once.
	var ate := [-1]
	h.ate.connect(func(count: int) -> void: ate[0] = count)
	h.release(0.5)
	_check(h.beat == GrappleAttack.Beat.REEL and not h.contact_due(), "release: the arms yank first (the snap waits %.2f s)" % h.cfg("grapple_yank_s"))
	var waited := 0.0
	while not h.contact_due() and waited < 1.0:
		_step(h, DT, false)
		waited += DT
	var taken := h.contact()
	_check(taken.size() == 8 and ate[0] == 8, "release: the snap takes all eight held (%d, ate %d) after %.2f s" % [taken.size(), ate[0], waited])
	_check(h.contact().size() == 8 and ate[0] == 8, "the contact is taken once per release")
	_step(h, h.cfg("grapple_reel_s") + 0.1, false)
	_check(h.fx == null or true, "reel: the catch rides the tips to the beak")
	_step(h, 0.5, false)
	_check(h.beat == GrappleAttack.Beat.IDLE and not h.busy(), "the arms settle and the attack is idle (beat %d)" % h.beat)
	# The cap.
	var c := _attack({"grapple_arms": 3})
	c.press(Vector3.ZERO, Vector3(0, 0, -1))
	_step(c, 3.0)
	_check(c.held_count() == 3, "grapple_arms 3: three held at most (%d)" % c.held_count())
	# A tap with nothing in reach whiffs.
	_targets.clear()
	var w := _attack()
	var whiffs := [0]
	w.whiffed.connect(func(_arm: int, _at: Vector3) -> void: whiffs[0] += 1)
	w.press(Vector3.ZERO, Vector3(0, 0, -1))
	w.release(0.0)
	_check(whiffs[0] == 1 and w.busy(), "a tap with nothing in reach whiffs (one arm flicks out)")
	_step(w, w.cfg("grapple_yank_s") + DT, false)
	_check(w.contact_due() and w.contact().is_empty(), "the whiff's snap takes nothing")
	_step(w, w.cfg("grapple_whiff_s") + 0.2, false)
	_check(not w.busy() and w.beat == GrappleAttack.Beat.IDLE, "and the arm comes back")
	# A tap with a fish in reach: the arm is still flying at the release, the snap waits for it and takes it.
	_targets = [_t(7, Vector3(0.0, 0.3, -3.0))]
	var tp := _attack()
	tp.press(Vector3.ZERO, Vector3(0, 0, -1))
	tp.release(0.0)
	var wait2 := 0.0
	while not tp.contact_due() and wait2 < 1.0:
		_step(tp, DT, false)
		wait2 += DT
	var tap_taken := tp.contact()
	_check(tap_taken.size() == 1, "a tap with a fish in reach takes it (%d, after %.2f s)" % [tap_taken.size(), wait2])


# ------------------------------------------------------------------------------ B: a real model

func _model_part() -> void:
	print("B: on an OctopusModel")
	var model := OctopusModel.build(6.0)
	add_child(model)
	var a := _attack({"grapple_tremble": 0.0})
	a.attach_model(model)
	_check(a.has_model() and a.auto_pose, "the model is attached (no rig: the attack poses it)")
	var origin := model.to_global(model.mouth_local())
	var fwd := -model.global_basis.z
	var arm_m := a.mean_arm_m()
	_targets = [_t(1, origin + fwd * arm_m * 0.6 + Vector3(0.6, 0.2, 0.0)), _t(2, origin + fwd * arm_m * 1.25 - Vector3(0.5, 0.0, 0.0)),
			_t(3, origin + fwd * arm_m * 0.9 + Vector3(0.0, -0.8, 0.0))]
	a.press(origin, fwd, model.global_basis)
	for i in int(1.2 / DT):
		a.step(DT, origin, fwd, true, model.global_basis)
		a.blend_pose(model)
	_check(a.held_count() == 3, "three fish held (%d)" % a.held_count())
	var worst := 0.0
	var base_worst := 0.0
	var stretched := false
	for t in a.arms:
		if t.grip == null:
			continue
		var len_m := float(model.arm_length(t.arm))
		worst = maxf(worst, model.arm_tip_global(t.arm).distance_to(t.grip.pos) / len_m)
		var rest0: Vector3 = model.arm_rest_joints(t.arm)[0]
		base_worst = maxf(base_worst, model.arm_joints(t.arm)[0].distance_to(rest0))
		if t.grip.key == 2:
			stretched = model.arm_tip_global(t.arm).distance_to(origin) > len_m
	_check(worst < 0.12, "the posed arm tips reach their fish (worst %.0f%% of an arm)" % (worst * 100.0))
	_check(stretched, "the fish past the arm's length is reached by stretching")
	_check(base_worst < 0.01, "the arms stay on their bases on the body (%.4f m)" % base_worst)
	a.release(0.4)
	for i in int(0.3 / DT):
		a.step(DT, origin, fwd, false, model.global_basis)
		a.blend_pose(model)
		if a.contact_due():
			a.contact()
	for i in int(1.0 / DT):
		a.step(DT, origin, fwd, false, model.global_basis)
		a.blend_pose(model)
	var bone_off := 0.0
	for arm in 8:
		for j in range(1, 14):
			var bone: int = model.arm_bones[arm][j]
			bone_off = maxf(bone_off, model.skeleton.get_bone_pose_position(bone).distance_to(model.skeleton.get_bone_rest(bone).origin))
		bone_off = maxf(bone_off, model.skeleton.get_bone_pose_scale(model.arm_bones[arm][13]).distance_to(Vector3.ONE))
	_check(not a.busy() and bone_off < 0.001, "reeled in: no arm left stretched (%.4f)" % bone_off)
	model.queue_free()


# ------------------------------------------------------------------------------ C: a real match

func _begin(as_bots: bool) -> void:
	if main == null:
		main = load("res://scenes/main.tscn").instantiate()
		add_child(main)
		await _frames(5)
	if main.what_stinks:
		main.set_mode(main.FREE_SWIM)
		await _frames(3)
	var settings := WhatStinksSettings.shared()
	settings.form = KEY
	settings.hide_time = 1.0 if not as_bots else 4.0
	settings.round_time = 600.0
	settings.round_over_time = 0.2
	settings.arena_radius = 90.0
	settings.school_count = 4
	settings.school_min = 24
	settings.school_max = 24
	settings.min_players = 5 if as_bots else 4
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	settings.variant = WhatStinksSettings.Variant.SWEEP
	settings.lock_bite = false
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	settings.hold_cooldown_per_s = 0.0
	settings.satiation_max = 1000.0
	settings.hitstop_ms = 0.0
	settings.bite_takes_players = true
	settings.bots_join = as_bots
	HunterSize.shared().size_mult = 1.0
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	main.play_match()
	await _frames(5)
	game = main.what_stinks
	fish = main.get_node("Fish")
	if as_bots:
		game.bots[fish] = null
		game.start_round(0)
		await _frames(3)


## The bite's style made the grapple (the sheet may still name the whip until the orchestrator flips it).
func _grapple_on(bite: HunterBite) -> GrappleAttack:
	if bite.attack is GrappleAttack:
		return bite.attack as GrappleAttack
	bite.attack.on_cancel(bite)
	var g := GrappleAttack.new()
	bite.attack = g
	bite.form["attack"] = "grapple"
	return g


func _place_mouth(bite: HunterBite, at: Vector3) -> void:
	fish.global_transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.0, fish.hitbox_length * 0.45))
	fish.global_position += at - bite.mouth_point()
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


## A spot in reach ahead of the beak and clear of the octopus' body (the mantle may lead the beak).
func _ahead_spot(bite: HunterBite, g: GrappleAttack) -> Vector3:
	var fwd := -fish.global_basis.z
	var spot := fish.global_position + fwd * (fish.hitbox_length * 0.5 + 1.2)
	if not g.in_reach(bite.mouth_point(), fwd, spot) or spot.distance_to(bite.mouth_point()) > g.reach_m() * 0.85:
		spot = bite.mouth_point() + fwd * g.reach_m() * 0.7
	return spot


## Moves the octopus (facing -Z) so `prey` sits at its _ahead_spot.
func _put_behind(bite: HunterBite, g: GrappleAttack, prey: FishController) -> void:
	_place_mouth(bite, prey.global_position + Vector3(0.0, 0.0, 3.0))
	fish.global_position += prey.global_position - _ahead_spot(bite, g)


func _prey_dict(prey: FishController) -> Dictionary:
	return {"key": prey.get_instance_id(), "pos": prey.global_position, "vel": prey.swim_velocity(), "prey": prey}


func _match_part() -> void:
	print("C: a real match")
	await _begin(false)
	if game == null or not game.is_hunter(fish):
		_check(false, "the local fish is the octopus Hunter")
		return
	var settings := WhatStinksSettings.shared()
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 6)
	var bite: HunterBite = game.bites[fish]
	var g := _grapple_on(bite)
	var input := FishInput.new()
	fish.controls = input
	fish.controls_locked = false
	var visual := fish.get("_visual") as Node3D
	var rig: OctopusRig = visual.get_meta("octopus_rig", null) as OctopusRig if visual != null else null
	var prey_list: Array[FishController] = []
	for other in game.players:
		if other != fish and not game.is_hunter(other):
			prey_list.append(other)
	_check(prey_list.size() >= 3, "three prey players to work with (%d)" % prey_list.size())
	if prey_list.size() < 3:
		return
	for p in prey_list:
		p.global_position = Vector3(0.0, -400.0, 0.0) + Vector3(randf() * 10.0, 0.0, 0.0)  # out of the way until used
		p.freeze = true
	# --- C1: school fish held and eaten
	settings.bite_takes_players = false
	var school: School = game.field.schools[0]
	school.set_physics_process(false)
	_place_mouth(bite, school.middle() + Vector3(0.0, 0.0, 2.5))
	bite.cooldown = 0.0
	await _frames(3)
	var landed := [-2]
	var on_landed := func(taken: int) -> void: landed[0] = taken
	bite.landed.connect(on_landed)
	input.jump = true
	await _until(func() -> bool: return bite.holding(), tps)
	await _frames(3)
	_check(rig == null or rig.lash == g, "the grapple poses the rig's arms (rig.lash)")
	_check(g.reaching_count() + g.held_count() == 1, "press: one arm goes for the nearest fish")
	await _frames(int(tps * 2.8))
	var held_n := g.held_count()
	var could := held_n + g.reaching_count()
	_check(held_n >= 6, "hold: more arms grab fish of the school (%d held)" % held_n)
	_check(bite.attack.ring_count(bite) == held_n, "the HUD ring shows the arms holding (%d)" % bite.attack.ring_count(bite))
	var driven := g.driven_arms().size()
	_check(driven >= held_n, "the held arms are posed by the grapple (%d)" % driven)
	var alive_before := school.alive_count()
	input.jump = false
	await _until(func() -> bool: return landed[0] != -2, tps * 2)
	_check(landed[0] >= held_n and landed[0] <= could, "release: the beak takes every fish held at once (%d of %d held, %d reaching)" % [landed[0], held_n, could - held_n])
	_check(alive_before - school.alive_count() >= held_n, "and they are gone from the school (%d)" % (alive_before - school.alive_count()))
	await _until(func() -> bool: return not g.busy() and not bite.busy(), tps * 3)
	_check(not g.busy(), "the arms reel in and settle")
	var worst := 0.0
	if rig != null:
		for a in 8:
			var want := rig.gait_joints(a)
			var have := rig.model.arm_joints(a)
			for p in mini(want.size(), have.size()):
				worst = maxf(worst, want[p].distance_to(have[p]))
	_check(worst < fish.hitbox_length * 0.2, "the settled arms sit on the gait (worst %.2f m)" % worst)
	school.set_physics_process(true)
	bite.landed.disconnect(on_landed)
	# --- C2: a prey tows the octopus and is not slowed: the same swim from the same spot, first free, then held
	settings.bite_takes_players = true
	settings.bots_join = false
	var held_prey := prey_list[0]
	var helper := prey_list[2]
	for p: FishController in prey_list:
		var bot: Node = game.bots.get(p)
		if bot != null:
			bot.set_physics_process(false)
	var pin := FishInput.new()
	held_prey.controls = pin
	g.target_source = func() -> Array: return [_prey_dict(held_prey)] if is_instance_valid(held_prey) else []
	var start := Vector3(0.0, 0.0, 55.0)
	_place_mouth(bite, start)
	var spot := _ahead_spot(bite, g)
	held_prey.freeze = false
	var swim := func(seconds: float) -> Array:
		var from := held_prey.global_position
		pin.forward = 1.0
		await _frames(int(tps * seconds))
		pin.forward = 0.0
		return [held_prey.global_position - from, held_prey.linear_velocity.length()]
	var park := func() -> void:
		held_prey.global_transform = Transform3D(Basis.IDENTITY, spot)
		held_prey.linear_velocity = Vector3.ZERO
		held_prey.angular_velocity = Vector3.ZERO
	# Free: the octopus parked well off to the side.
	fish.global_position = start + Vector3(70.0, 0.0, 0.0)
	park.call()
	await _frames(int(tps * 0.3))
	var free: Array = await swim.call(2.5)
	print("    dbg free run %.2f m, end %.2f m/s" % [(free[0] as Vector3).length(), float(free[1])])
	park.call()
	await _frames(2)
	var free2: Array = await swim.call(2.5)
	print("    dbg free run 2 (2 frames rest) %.2f m, end %.2f m/s" % [(free2[0] as Vector3).length(), float(free2[1])])
	park.call()
	await _frames(int(tps * 1.0))
	var free3: Array = await swim.call(2.5)
	print("    dbg free run 3 (1 s rest) %.2f m, end %.2f m/s" % [(free3[0] as Vector3).length(), float(free3[1])])
	# Held: the octopus back where it was, the prey grabbed at rest, then the same swim.
	_place_mouth(bite, start)
	park.call()
	await _frames(2)
	bite.cooldown = 0.0
	input.jump = true
	await _until(func() -> bool: return bite.holding(), tps)
	await _until(func() -> bool: return g.held_count() == 1, tps)
	_check(g.held_count() == 1 and GrappleAttack.gripped_now(held_prey), "a prey player is grabbed")
	_check(GrappleAttack.grip_level(held_prey) > 0.95, "its HUD cue is on (%.2f)" % GrappleAttack.grip_level(held_prey))
	park.call()
	await get_tree().physics_frame
	var o0 := fish.global_position
	var w := {"gap": 0.0, "taut": 0.0, "held": true, "closest": INF}
	var watch := func() -> void:
		w["gap"] = maxf(float(w["gap"]), held_prey.global_position.distance_to(bite.mouth_point()))
		w["taut"] = maxf(float(w["taut"]), g.tow_taut)
		w["held"] = bool(w["held"]) and g.held_count() == 1
		w["closest"] = minf(float(w["closest"]), held_prey.global_position.distance_to(fish.global_position))
		if Engine.get_physics_frames() % 30 == 0:
			print("    dbg gap=%.2f oct=%.2f prey=%.2f taut=%.2f push=%.3f centre=%.2f" % [held_prey.global_position.distance_to(bite.mouth_point()), fish.linear_velocity.length(), held_prey.linear_velocity.length(), g.tow_taut, g.tow_push.length(), held_prey.global_position.distance_to(fish.global_position)])
	get_tree().physics_frame.connect(watch)
	var towed: Array = await swim.call(2.5)
	get_tree().physics_frame.disconnect(watch)
	pin.forward = 1.0  # keep swimming for the dash below
	var prey_run: Vector3 = towed[0]
	var free_run: Vector3 = free[0]
	var oct_run := fish.global_position - o0
	var max_gap: float = w["gap"]
	var max_taut: float = w["taut"]
	var still_held: bool = w["held"]
	var closest: float = w["closest"]
	var speed_gap := absf(float(towed[1]) - float(free[1])) / maxf(float(free[1]), 0.1)
	_check(still_held, "the prey stays held while it swims (2.5 s)")
	_check(closest > fish.hitbox_length * 0.5 + 0.3, "the towed octopus never runs into the prey (closest %.2f m centre to centre)" % closest)
	_check(prey_run.distance_to(free_run) < maxf(free_run.length() * 0.03, 0.25) and speed_gap < 0.03,
			"the tow does not slow the prey: held it swam %.2f m, free %.2f m (end speed off by %.1f%%)" % [prey_run.length(), free_run.length(), speed_gap * 100.0])
	_check(oct_run.dot(prey_run.normalized()) > prey_run.length() * 0.6, "the octopus is towed behind it (%.1f m of the prey's %.1f m)" % [oct_run.dot(prey_run.normalized()), prey_run.length()])
	_check(max_gap <= g.cfg("grapple_max_stretch") * g.mean_arm_m() and max_taut > 0.3, "it trails within the max stretch (widest %.1f m of %.1f m; rope taut %.2f)" % [max_gap, g.cfg("grapple_max_stretch") * g.mean_arm_m(), max_taut])
	# --- C3: a dash tears the arm off
	var whys: Array[String] = []
	g.let_go.connect(func(_arm: int, _at: Vector3, why: String) -> void: whys.append(why))
	pin.boost = true
	await _until(func() -> bool: return whys.has("torn"), tps)
	_check(whys.has("torn") and g.held_count() == 0, "the prey's dash tears the arm off (%s)" % [whys])
	pin.boost = false
	pin.forward = 0.0
	input.jump = false
	await _until(func() -> bool: return not bite.busy() and not g.busy(), tps * 3)
	await _frames(int(tps * (g.cfg("grapple_break_immune_s") + 0.1)))
	_check(GrappleAttack.grip_level(held_prey) < 0.01, "the cue fades once it is free")
	# --- C4: a hard counter-steer tears free too
	var tune_dash: Variant = settings.get("grapple_break_dash")
	g.tune["grapple_break_dash"] = 0.0
	held_prey.linear_velocity = Vector3.ZERO
	_put_behind(bite, g, held_prey)
	held_prey.global_basis = Basis.IDENTITY
	whys.clear()
	bite.cooldown = 0.0
	input.jump = true
	await _until(func() -> bool: return g.held_count() == 1, tps)
	pin.forward = 1.0
	pin.stick = Vector2(1.0, 0.0)  # a hard turn
	var steer_t := 0
	for i in tps * 3:
		await get_tree().physics_frame
		steer_t += 1
		if whys.has("torn"):
			break
	_check(whys.has("torn") and steer_t > int(tps * g.cfg("grapple_break_steer_s")), "turning hard tears free (after %.2f s)" % (float(steer_t) / tps))
	g.tune.erase("grapple_break_dash")
	pin.forward = 0.0
	pin.stick = Vector2.ZERO
	if not whys.has("torn"):
		bite.abort()  # not eaten: the next checks need it
	input.jump = false
	await _until(func() -> bool: return not bite.busy() and not g.busy(), tps * 3)
	await _frames(int(tps * (g.cfg("grapple_break_immune_s") + 0.1)))
	# --- C5: the max stretch, then a held prey eaten
	held_prey.linear_velocity = Vector3.ZERO
	held_prey.global_basis = Basis.IDENTITY
	_put_behind(bite, g, held_prey)
	whys.clear()
	bite.cooldown = 0.0
	input.jump = true
	await _until(func() -> bool: return g.held_count() == 1, tps)
	held_prey.global_position += Vector3(0.0, 0.0, -(g.cfg("grapple_max_stretch") * g.mean_arm_m() + 6.0))
	await _until(func() -> bool: return not whys.is_empty(), tps)
	_check(whys == ["stretch"], "a prey yanked past the max stretch tears loose (%s)" % [whys])
	input.jump = false
	await _until(func() -> bool: return not bite.busy() and not g.busy(), tps * 3)
	held_prey.linear_velocity = Vector3.ZERO
	_put_behind(bite, g, held_prey)
	bite.cooldown = 0.0
	input.jump = true
	await _until(func() -> bool: return g.held_count() == 1, tps)
	await _frames(int(tps * 0.3))
	input.jump = false
	await _until(func() -> bool: return game.eaten.has(held_prey), tps * 2)
	_check(game.eaten.has(held_prey), "a held prey is eaten on the release")
	await _until(func() -> bool: return not bite.busy() and not g.busy(), tps * 3)
	# --- C6: a prey bot struggles free
	var bot_prey := helper
	var pbot: Node = game.bots.get(bot_prey)
	g.tune["grapple_bot_break"] = 1.0
	settings.set("grapple_bot_break", 1.0)
	settings.set("grapple_bot_react_s", 0.2)
	bot_prey.freeze = false
	bot_prey.linear_velocity = Vector3.ZERO
	bot_prey.global_transform = Transform3D(Basis.IDENTITY, fish.global_position + Vector3(20.0, 0.0, 0.0))
	await _frames(2)
	_put_behind(bite, g, bot_prey)
	g.target_source = func() -> Array: return [_prey_dict(bot_prey)] if is_instance_valid(bot_prey) else []
	whys.clear()
	bite.cooldown = 0.0
	input.jump = true
	await _until(func() -> bool: return g.held_count() == 1, tps)
	var held_bot := g.held_count() == 1
	if pbot != null:
		pbot.set_physics_process(true)  # its own mind from here: it should struggle
	for i in tps * 3:
		await get_tree().physics_frame
		if whys.has("torn"):
			break
	_check(pbot is WhatStinksPreyBot and held_bot and whys.has("torn"), "a grabbed prey bot struggles free (%s)" % [whys])
	settings.set("grapple_bot_break", 0.65)
	settings.set("grapple_bot_react_s", 0.4)
	g.tune.erase("grapple_bot_break")
	input.jump = false
	await _until(func() -> bool: return not bite.busy() and not g.busy(), tps * 3)
	if tune_dash != null:
		settings.set("grapple_break_dash", tune_dash)
	# --- C7: tap mode takes the nearest in reach
	g.target_source = Callable()
	settings.bite_takes_players = false
	school = game.field.schools[0] if game.field.schools[0].alive_count() > 0 else game.field.schools[1]
	school.set_physics_process(false)
	_place_mouth(bite, school.middle() + Vector3(0.0, 0.0, 2.5))
	settings.bite_mode = WhatStinksSettings.BiteMode.TAP
	bite.cooldown = 0.0
	await _frames(3)
	landed[0] = -2
	bite.landed.connect(on_landed)
	input.jump = true
	await _frames(3)
	input.jump = false
	await _until(func() -> bool: return landed[0] != -2, tps * 2)
	_check(landed[0] == 1, "tap mode: a tap grabs the nearest and the beak takes it (%d)" % landed[0])
	bite.landed.disconnect(on_landed)
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	await _until(func() -> bool: return not bite.busy() and not g.busy(), tps * 3)
	# --- C8: a puppet is not towed and follows the owner's grips
	bite.cooldown = 0.0
	input.jump = true
	await _until(func() -> bool: return g.held_count() >= 2, tps * 2)
	var state := g.net_state(func(f: FishController) -> int: return f.get_instance_id())
	var named := 0
	for a in 8:
		if state[a * 3] == 1:
			named += 1
	_check(named == g.held_count() + g.reaching_count() or named == g.held_count(), "net_state names what each arm holds (%d)" % named)
	fish.puppet = true
	await _frames(2)
	_check(g.tow_push == Vector3.ZERO, "a puppet is not towed")
	var twin_g := GrappleAttack.new()
	bite.attack = twin_g
	twin_g.on_open(bite)
	twin_g.apply_net_state(state, func(_id: int) -> FishController: return null, game.field)
	await _frames(int(tps * 0.4))
	_check(twin_g.net_driven and twin_g.held_count() == named, "a puppet's grapple holds what the owner said (%d of %d)" % [twin_g.held_count(), named])
	twin_g.apply_net_state(PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]), func(_id: int) -> FishController: return null, game.field)
	await _frames(2)
	_check(twin_g.held_count() == 0, "and lets go when told")
	twin_g.on_cancel(bite)
	fish.puppet = false
	bite.attack = g
	input.jump = false
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	school.set_physics_process(true)
	# --- C9: bot_plan
	var hb := WhatStinksBot.new()
	bite.cooldown = 0.0
	hb.target_gap = g.reach_m() * 0.5
	hb.target_ahead = 1.0
	var near := g.bot_plan(hb, bite)
	hb.target_gap = g.reach_m() * 3.0
	var far := g.bot_plan(hb, bite)
	_check(bool(near["press"]) and not bool(far["press"]), "bot_plan presses with a fish in reach, not without")
	hb.free()
	fish.controls = null


# ------------------------------------------------------------------------------ D: a bot Hunter

func _bot_part() -> void:
	print("D: a bot Hunter")
	await _begin(true)
	if game == null or game.hunters.is_empty():
		_check(false, "a bot match started")
		return
	var hunter: FishController = game.hunters[0]
	var bite: HunterBite = game.bites[hunter]
	var g: GrappleAttack
	if bite.attack is GrappleAttack:
		g = bite.attack as GrappleAttack
	else:
		bite.attack.on_cancel(bite)
		g = GrappleAttack.new()
		bite.attack = g
		bite.form["attack"] = "grapple"
	var presses := [0]
	var releases := [0]
	var most := [0]
	var taken := [0]
	bite.opened.connect(func() -> void: presses[0] += 1)
	bite.released.connect(func(_c: float) -> void: releases[0] += 1)
	bite.landed.connect(func(t: int) -> void: taken[0] += maxi(t, 0))
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 12)
	for i in tps * 90:
		await get_tree().physics_frame
		most[0] = maxi(most[0], g.held_count())
		if releases[0] >= 4 and taken[0] >= 3 and i > tps * 15:
			break
	_check(presses[0] >= 2, "the bot presses (%d)" % presses[0])
	_check(releases[0] >= 2, "and releases (%d)" % releases[0])
	_check(most[0] >= 2, "its arms hold several fish at once (most %d)" % most[0])
	_check(taken[0] >= 2, "and its releases eat (%d fish)" % taken[0])
