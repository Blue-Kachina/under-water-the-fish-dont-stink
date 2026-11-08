## The Lantern Angler's lure (planning_new_hunters.md D3): the LureField rules and LureAttack on a real HunterBite.
## A: the field's numbers (radius, cone, falloff, ramp, cap, resist, dash and its immunity, the HUD level).
## B: simulated prey (no physics): a bot is pulled in, a person swimming away holds their own, a dash escapes.
## C: a real bite: the press starts the field and flares the esca, the hold pulls a bot and an idle person (not one swimming
##    away, dashing, behind, out of range, or a puppet), the flicker quickens, the release ends it, dims the esca and adds
##    the cooldown, a called-off bite lets go.
##   Godot_console.exe --headless --path . res://tests/lure_pull_probe.tscn
extends Node

var checks := 0
var failures := 0
var tps := 60
var _press := false
var _hunter: FishController


## The Angler's button (a frozen body never samples its input, so the probe presses it).
func _physics_process(_delta: float) -> void:
	if _hunter != null and is_instance_valid(_hunter):
		_hunter.jump_held = _press


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


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
	LureField.reset()
	_field_numbers()
	_simulated()
	await _real_bite()
	LureField.reset()
	print("lure_pull_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## A source at the origin facing -Z, mouth 2 m ahead, ramped as asked.
func _source(ramp := 1.0) -> LureField.Source:
	var src := LureField.Source.new(null, null)
	src.place(Vector3(0.0, 2.0, 0.0), Vector3(0.0, 0.0, -2.0), Vector3(0.0, 0.0, -1.0), 4.0)
	src.start()
	src.ramp = ramp
	return src


func _field_numbers() -> void:
	print("      A: the field")
	var src := _source()
	var ahead := Vector3(0.0, 2.0, -15.0)
	_check(src.reach_weight(ahead) > 0.3, "range: prey 15 m ahead is in the light (%.2f)" % src.reach_weight(ahead))
	_check(src.reach_weight(Vector3(0.0, 2.0, -src.radius - 1.0)) == 0.0, "range: beyond the radius is not")
	_check(src.reach_weight(Vector3(0.0, 2.0, -30.0)) < src.reach_weight(Vector3(0.0, 2.0, -10.0)), "falloff: the pull weakens with distance")
	_check(src.reach_weight(Vector3(0.0, 2.0, 25.0)) == 0.0, "cone: prey behind the Angler is out of the cone")
	_check(src.reach_weight(Vector3(0.0, 2.0, 3.0)) > 0.0, "cone: but right beside the esca counts whatever the angle")
	var edge := src.esca + Vector3(sin(deg_to_rad(src.cone_deg)), 0.0, -cos(deg_to_rad(src.cone_deg))) * 15.0
	_check(src.reach_weight(edge) < 0.01 and src.reach_weight(src.esca + Vector3(sin(deg_to_rad(src.cone_deg * 0.5)), 0.0, -cos(deg_to_rad(src.cone_deg * 0.5))) * 15.0) > 0.2, "cone: fades out at its edge, full inside")

	var cold := _source(0.0)
	_check(cold.accel_on(1, ahead, Vector3.ZERO, false, false, 0.016) == Vector3.ZERO, "ramp: nothing at the instant of the press")
	var ramping := _source(0.0)
	var last := 0.0
	var rising := true
	var a_t := 0.0
	for i in 60:
		ramping.advance(ramping.ramp_s / 60.0)
		var m := ramping.accel_on(2, ahead, Vector3.ZERO, false, false, 0.016).length()
		rising = rising and m >= last - 0.0001
		last = m
		a_t = m
	_check(rising and a_t > 0.5, "ramp: the pull builds with the hold (%.2f m/s^2 at full)" % a_t)

	var idle := src.accel_on(3, ahead, Vector3.ZERO, true, false, 0.016)
	_check(idle.length() > 0.5 and idle.normalized().dot((src.pull_target(ahead) - ahead).normalized()) > 0.99, "pull: toward the lure (%.2f m/s^2)" % idle.length())
	var strong := LureField.Source.new(null, null)
	strong.pull = 500.0
	strong.cap = 9.0
	strong.place(src.esca, src.mouth, Vector3.FORWARD, 4.0)
	strong.ramp = 1.0
	_check(strong.accel_on(4, ahead, Vector3.ZERO, false, false, 0.016).length() <= 9.0001, "cap: no pull is harder than lure_cap")

	var away := Vector3(0.0, 0.0, -1.0)  # swimming straight away from the lure
	var human := src.accel_on(5, ahead, away, true, false, 0.016)
	var bot := src.accel_on(6, ahead, away, false, false, 0.016)
	_check(human.length() < idle.length() * 0.15, "resist: a person swimming straight away cancels most of it (%.2f of %.2f)" % [human.length(), idle.length()])
	_check(bot.length() > human.length() and bot.length() < idle.length(), "resist: a bot resists less (%.2f)" % bot.length())
	var side := src.accel_on(7, ahead, Vector3(1.0, 0.0, 0.0), true, false, 0.016)
	_check(side.length() < idle.length() and side.length() > human.length(), "resist: swimming sideways only helps a little (%.2f)" % side.length())
	var toward := src.accel_on(8, ahead, Vector3(0.0, 0.0, 1.0), true, false, 0.016)
	_check(toward.length() >= idle.length() * 0.99, "resist: swimming toward it does not resist")

	var broke := int(LureField.stats["breaks"])
	var held: Vector3 = Vector3.ZERO
	for i in 40:
		src.accel_on(9, ahead, Vector3.ZERO, true, false, 0.016)
	_check(float(src.captive.get(9, 0.0)) > 0.3 and LureField.captivated(null) == 0.0, "HUD: a held fish's level rises (%.2f)" % float(src.captive.get(9, 0.0)))
	held = src.accel_on(9, ahead, Vector3.ZERO, true, true, 0.016)
	_check(held == Vector3.ZERO, "dash: boosting cancels the pull outright")
	_check(int(LureField.stats["breaks"]) == broke + 1, "dash: counted as a break in the stats")
	var after := src.accel_on(9, ahead, Vector3.ZERO, true, false, 0.016)
	_check(after.length() < 0.01, "dash: and it cannot snap straight back (immunity %.1f s)" % src.break_s)
	for i in int(ceil((src.break_s + 0.1) / 0.016)):
		src.advance(0.016)
		src.accel_on(9, ahead, Vector3.ZERO, true, false, 0.016)
	_check(src.accel_on(9, ahead, Vector3.ZERO, true, false, 0.016).length() > 0.5, "dash: after the immunity the light draws again")

	var inner := src.accel_on(10, src.mouth + src.axis * src.reach * 0.4 + Vector3(0.0, 0.0, 0.3), Vector3.ZERO, true, false, 0.016)
	_check(inner.length() < src.pull * 0.2, "edge: the pull eases off where it is aiming (no jitter at the mouth)")
	var far_pt := src.pull_target(Vector3(0.0, 2.0, -40.0))
	var near_pt := src.pull_target(src.mouth + Vector3(0.0, 0.0, -2.0))
	_check(far_pt.distance_to(src.esca) < 0.01 and near_pt.distance_to(src.mouth + src.axis * src.reach * 0.4) < 1.5, "aim: the esca from afar, the open mouth when near")
	src.stop()
	cold.stop()
	ramping.stop()
	strong.stop()
	_check(LureField.active().is_empty(), "registry: a stopped source is gone")


## Kinematic prey: velocity += accel x dt, a drag, a thrust of their own.
func _sim(src: LureField.Source, start: Vector3, human: bool, thrust_dir: Vector3, dash_from: float, dash_to: float, seconds: float) -> Vector3:
	var pos := start
	var vel := Vector3.ZERO
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < seconds:
		var dashing := t >= dash_from and t < dash_to
		var intent := thrust_dir
		src.advance(dt)
		var a := src.accel_on(77, pos, intent, human, dashing, dt)
		var own := intent * 10.0 + (intent.normalized() * 25.0 if dashing and intent != Vector3.ZERO else Vector3.ZERO)
		vel += (a + own) * dt
		vel *= exp(-0.6 * dt)
		pos += vel * dt
		t += dt
	return pos


func _simulated() -> void:
	print("      B: simulated prey")
	var start := Vector3(0.0, 2.0, -28.0)
	var mouth_dist := func(p: Vector3, s: LureField.Source) -> float: return p.distance_to(s.mouth)
	var s1 := _source(0.0)
	var bot_end := _sim(s1, start, false, Vector3.ZERO, 99.0, 99.0, 10.0)
	_check(mouth_dist.call(bot_end, s1) < 6.0, "bot: drawn from 28 m to the mouth in 10 s (%.1f m left)" % mouth_dist.call(bot_end, s1))
	var s2 := _source(0.0)
	var human_idle := _sim(s2, start, true, Vector3.ZERO, 99.0, 99.0, 10.0)
	_check(mouth_dist.call(human_idle, s2) < 8.0, "person: drifting idle is drawn in too (%.1f m left)" % mouth_dist.call(human_idle, s2))
	var s3 := _source(0.0)
	var swum := _sim(s3, start, true, Vector3(0.0, 0.0, -1.0), 99.0, 99.0, 10.0)
	_check(mouth_dist.call(swum, s3) > mouth_dist.call(start, s3) + 20.0, "person: swimming straight away gets clear (%.1f m from the mouth)" % mouth_dist.call(swum, s3))
	var s4 := _source(0.0)
	var counter := _sim(s4, start, true, Vector3(1.0, 0.0, 0.0), 99.0, 99.0, 10.0)
	_check(mouth_dist.call(counter, s4) > mouth_dist.call(human_idle, s4), "person: a partial counter-steer is drawn in slower")
	# Dash escape: caught (idle) for 5 s, then a half second dash away.
	var s5 := _source(0.0)
	var caught := _sim(s5, start, true, Vector3.ZERO, 99.0, 99.0, 5.0)
	var s6 := _source(0.0)
	var dashed := _sim(s6, start, true, Vector3(0.0, 0.0, -1.0), 1.0, 2.0, 6.0)
	_check(mouth_dist.call(dashed, s6) > mouth_dist.call(start, s6), "dash: a burst away breaks free and stays free (%.1f m, caught-idle would be %.1f)" % [mouth_dist.call(dashed, s6), mouth_dist.call(caught, s5)])


func _prey_at(pos: Vector3, bot: bool) -> FishController:
	var f := (load("res://scenes/fish.tscn") as PackedScene).instantiate() as FishController
	add_child(f)
	f.freeze = true  # nothing but the lure's pushes (apply_push) are looked at, drained by the probe
	f.global_position = pos
	if bot:
		f.controls = FishInput.new()
	return f


func _drain(f: FishController) -> Vector3:
	var v: Vector3 = f._ball_push
	f._ball_push = Vector3.ZERO
	return v


func _sum_push(f: FishController, ticks: int) -> Vector3:
	var total := Vector3.ZERO
	for i in ticks:
		await get_tree().physics_frame
		total += _drain(f)
	return total


func _real_bite() -> void:
	print("      C: a real bite")
	LureField.reset()
	var settings := WhatStinksSettings.shared()
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	settings.hold_speed_mult = 1.0
	settings.hold_turn_mult = 1.0
	settings.hold_cooldown_per_s = 0.0
	var hunter := (load("res://scenes/fish.tscn") as PackedScene).instantiate() as FishController
	add_child(hunter)
	hunter.freeze = true
	_hunter = hunter
	hunter.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var input := FishInput.new()
	hunter.controls = input
	var form: Dictionary = HunterForm.SHARK.duplicate()
	form["bite_every"] = 0.5
	form["charge_s"] = 1.2
	var bite := HunterBite.new()
	hunter.add_child(bite)
	bite.setup(hunter, form)
	var attack := LureAttack.new()
	bite.attack = attack
	_check(attack.key == "lure", "style: the attack's key is lure")
	# A real model on the fish: the attack finds it and writes the glow.
	var model := AnglerModel.new()
	var visual: Node = hunter.get("_visual")
	(visual if visual != null else hunter).add_child(model)
	model.build(6.0)
	model.pose_straight()
	var bot := _prey_at(Vector3(0.0, 0.0, -22.0), true)
	var human := _prey_at(Vector3(5.0, 0.0, -22.0), false)
	var behind := _prey_at(Vector3(0.0, 0.0, 22.0), true)
	var far := _prey_at(Vector3(0.0, 0.0, -120.0), true)
	var puppet := _prey_at(Vector3(-5.0, 0.0, -22.0), true)
	puppet.puppet = true
	var herd: Array = [bot, human, behind, far, puppet]
	var human_thrust := [0.0]
	attack.target_source = func() -> Array:
		human.input_forward = human_thrust[0]  # the person's stick, set where the pull reads it
		human.input_reverse = 0.0
		return herd
	var landed_at := [0]
	bite.landed.connect(func(_taken: int) -> void: landed_at[0] = Engine.get_physics_frames())
	var chomped_count := [0]
	bite.chomped.connect(func(_m: Vector3, _r: float, _rad: float, _cap: int) -> void: chomped_count[0] += 1)
	await _frames(3)
	_drain(bot)
	_drain(human)
	_check(await _sum_push(bot, 10) == Vector3.ZERO and attack.esca_level < 1.1 and attack.beat == LureAttack.Beat.IDLE, "idle: no pull, the esca at its normal glow before the press")

	_press = true
	await _until(func() -> bool: return bite.holding(), tps)
	_check(bite.holding() and attack.source != null and LureField.active().size() == 1, "press: the field starts (one source registered)")
	await _frames(int(tps * 0.15))
	_check(attack.esca_level > 1.8, "press: the esca flares up (%.2f)" % attack.esca_level)
	_check(attack.eye_level > 1.15, "press: the eyes flash (%.2f)" % attack.eye_level)
	_check(model.esca_intensity > 1.5 and model.eye_glint > 1.1, "model: the AnglerModel is lit up (esca %.2f, eyes %.2f)" % [model.esca_intensity, model.eye_glint])
	_check(attack.source.esca.distance_to(model.esca_world()) < 0.01, "model: the field's light is the model's esca")
	_check(attack.gape_mult(bite) > 1.0, "press: the jaws are to go agape (x%.2f)" % attack.gape_mult(bite))
	_drain(bot)
	var early := (await _sum_push(bot, int(tps * 0.3))).length() / 0.3
	await _frames(int(tps * 2.0))
	_drain(bot)
	_drain(human)
	var late_bot := (await _sum_push(bot, int(tps * 0.5)))
	var late_idle := _drain(human)  # drained over the same half second below, re-measured with a clean window
	late_idle = Vector3.ZERO
	human_thrust[0] = 0.0
	_drain(human)
	await _frames(int(tps * 0.5))
	late_idle = _drain(human)
	var late_rate := late_bot.length() / 0.5
	_check(late_rate > early * 1.5 and late_rate > 1.0, "hold: the pull ramps up (%.1f m/s^2 early, %.1f late)" % [early, late_rate])
	_check(late_bot.normalized().dot(Vector3(0.0, 0.0, 1.0)) > 0.9, "hold: the bot is drawn toward the Angler")
	var bot_level := LureField.captivated(bot)
	_check(bot_level > 0.3, "HUD: the bot reads captivated (%.2f)" % bot_level)
	_check(late_idle.length() / 0.5 > 1.0 and late_idle.normalized().dot(Vector3(-0.2, 0.0, 1.0).normalized()) > 0.9, "hold: an idle person is drawn too (%.1f m/s^2)" % (late_idle.length() / 0.5))
	_check(attack.captive_count >= 2, "hold: the attack counts who it holds (%d)" % attack.captive_count)

	human_thrust[0] = 1.0  # the person swims straight away (their nose is -Z, away from the Angler)
	await _frames(int(tps * 0.5))
	_drain(human)
	var resisted := (await _sum_push(human, int(tps * 0.5))).length() / 0.5
	_check(resisted < late_idle.length() / 0.5 * 0.2, "resist: swimming away cancels most of it (%.2f vs %.2f)" % [resisted, late_idle.length() / 0.5])
	var held_level := LureField.captivated(human)
	_check(held_level < LureField.captivated(bot), "HUD: the person resisting reads less captivated (%.2f vs %.2f)" % [held_level, LureField.captivated(bot)])
	human_thrust[0] = 0.0
	await _frames(int(tps * 0.5))
	_drain(human)
	human.boost_held = true
	_check((await _sum_push(human, int(tps * 0.3))) == Vector3.ZERO, "dash: boosting out of it gets no pull")
	human.boost_held = false
	_drain(human)
	_check((await _sum_push(human, int(tps * 0.2))).length() < 0.2, "dash: and none just after, either (immunity)")
	await _frames(int(tps * 2.0))
	_drain(human)
	_check((await _sum_push(human, int(tps * 0.3))).length() > 0.3, "dash: then it draws again")

	_check(_drain(behind) == Vector3.ZERO, "range: a fish behind the Angler is left alone")
	_check(_drain(far) == Vector3.ZERO, "range: so is one 120 m off")
	_check(_drain(puppet) == Vector3.ZERO, "net: a puppet is pushed on its own machine, not here")
	# Bot steering bias.
	var target := Vector3(30.0, 0.0, -40.0)
	var bent := LureField.blend_target(bot, target)
	_check(bent.distance_to(Vector3.ZERO) < target.distance_to(Vector3.ZERO) and LureField.bias_weight(bot) > 0.3, "bot: its swim target is bent toward the light (weight %.2f)" % LureField.bias_weight(bot))
	_check(LureField.blend_target(human, target) == target, "bot: a person's steering is never touched")
	_check(LureField.blend_target(far, target) == target, "bot: nothing out of range bends")

	# Flicker quickens as prey close in: compare the far fish with the bot dragged next to the mouth.
	var slow_hz := attack.flicker_hz
	bot.global_position = bite.mouth_point() + Vector3(0.0, 0.0, -3.0)
	human.global_position = Vector3(300.0, 0.0, 300.0)
	await _frames(int(tps * 0.6))
	var fast_hz := attack.flicker_hz
	_check(fast_hz > slow_hz + 1.0 and slow_hz >= LureField.cfg(settings, "lure_flicker_min") - 0.01, "flicker: quicker with prey at the mouth (%.1f Hz, was %.1f)" % [fast_hz, slow_hz])

	# Release.
	_press = false
	await _until(func() -> bool: return not bite.holding(), tps)
	await _frames(2)
	_check(LureField.active().is_empty() and attack.source == null, "release: the field ends")
	_check(attack.beat == LureAttack.Beat.SNAP or attack.beat == LureAttack.Beat.COOL, "release: the Angler snaps (beat %d)" % attack.beat)
	_drain(bot)
	_check((await _sum_push(bot, 20)) == Vector3.ZERO, "release: no more pull")
	await _frames(int(tps * 0.3))
	_check(attack.esca_level < 0.7 and model.esca_intensity < 0.7, "release: the esca dims (%.2f, model %.2f)" % [attack.esca_level, model.esca_intensity])
	await _until(func() -> bool: return chomped_count[0] >= 1, tps * 3)
	_check(chomped_count[0] == 1, "release: the jaws shut once (chomped)")
	await _frames(3)
	var spent := float(Engine.get_physics_frames() - landed_at[0]) / tps
	_check(bite.cooldown + spent >= LureField.cfg(settings, "lure_cooldown") - 0.05, "cooldown: lure_cooldown holds the next bite off (%.2f s left, %.2f s after the landing)" % [bite.cooldown, spent])
	_press = true
	await _frames(int(tps * 0.5))
	_check(not bite.holding(), "cooldown: a press during it is refused")
	_press = false
	await _frames(2)
	await _until(func() -> bool: return bite.cooldown <= 0.0, tps * 4)
	await _frames(int(tps * 1.0))
	_check(attack.esca_level > 0.85 and attack.beat == LureAttack.Beat.IDLE, "cooldown: the esca has relit (%.2f)" % attack.esca_level)
	_press = true
	await _until(func() -> bool: return bite.holding(), tps)
	_check(bite.holding() and LureField.active().size() == 1, "cooldown: and the lure can be cast again")

	# Called off.
	await _frames(int(tps * 0.4))
	bite.abort()
	_press = false
	await _frames(3)
	_check(LureField.active().is_empty() and attack.source == null, "abort: a called-off bite ends the field with no strike")
	_check(chomped_count[0] == 1, "abort: and nothing was bitten")
	await _frames(int(tps * 0.3))
	_check(LureField.captivated(bot) < bot_level, "HUD: the captivated level fades out, not pops")

	# The plan for a bot Angler.
	attack.source = null
	var stub := WhatStinksBot.new()
	stub.target_gap = 20.0
	stub.target_ahead = 0.9
	stub.target_at = Vector3(0.0, 0.0, -10.0)
	bite.cooldown = 0.0
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	var plan := attack.bot_plan(stub, bite)
	_check(bool(plan["press"]), "bot angler: opens the lure on prey inside the light")
	stub.target_gap = 400.0
	_check(not bool(attack.bot_plan(stub, bite)["press"]), "bot angler: not on prey far outside it")
	stub.free()
	for f in herd:
		f.queue_free()
	hunter.queue_free()
