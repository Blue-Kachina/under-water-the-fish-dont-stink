class_name LureAttack
extends HunterAttack
## The Lantern Angler's style (planning_new_hunters.md D3): bait, then snap.
##
##   PRESS    the esca flares to full (a bright spike that rings down to the hold level), the jaws go agape (gape_mult()
##            on the jaw wrapper), the eyes flash, the stalk is flicked, and the attraction field (LureField) starts.
##   HOLD     the attraction ramps up (lure_ramp_s): prey inside the light cone and radius are drifted toward the esca and,
##            nearer, the open mouth. A person can swim away (thrust against it cancels most of it) or dash (boost) out of
##            it; bots feel a steering bias too (LureField.blend_target, one line in the prey bot) and a smaller resist.
##            School fish are drawn by School.pull. The esca flickers faster the closer prey come. Holding costs speed
##            and turn as for every Hunter (HunterBite).
##   RELEASE  the field ends, the esca drops dark, the jaws snap shut on the frustum (the chomp's: reach and capacity
##            grow with the charge) with the chomp's feel and hit-stop (HunterBiteFx on `landed`); the esca relights
##            over the cooldown, which is lure_cooldown longer than a plain bite's.
##
## The pull is a pure function of where the open mouth is (LureField.Source), so every machine runs it for the Angler it
## sees and moves only the prey it owns (a puppet is pushed on its own machine, as the Gulper's suction).
## The model (AnglerModel) is found by walking the fish's visual; with none the attack still pulls and keeps esca_level /
## eye_level / flicker_hz for any rig that wants to read them. In tap mode this plays as the plain chomp.

enum Beat { IDLE, FLARE, HOLD, SNAP, COOL }

## What the esca and eyes should show now (the model gets these; a rig without the model can read them).
var esca_level := 1.0
var eye_level := 1.0
var flicker_hz := 0.0
var beat := Beat.IDLE
## The live field while the lure is held (null otherwise).
var source: LureField.Source
## Prey drawn (captivated above a fifth) as of the last hold tick, and 0..1 how near the nearest is to the mouth.
var captive_count := 0
var closeness := 0.0
## A probe's prey list (a Callable returning Array[FishController]); empty uses the match's live_prey().
var target_source := Callable()

var _model: Node3D
var _find_wait := 0.0
var _vel := 0.0
var _eye_vel := 0.0
var _phase := 0.0
var _beat_t := 0.0
var _cool_len := 1.0
var _was_holding := false
var _written_esca := -1.0
var _written_eye := -1.0
var _gape := 1.0
var _pulled: Array[School] = []


func _init() -> void:
	key = "lure"


## The jaw wrapper's extra opening while the lure is held (x the bite's open amount).
func gape_mult(bite: HunterBite) -> float:
	return LureField.cfg(bite.settings, "lure_gape") if beat == Beat.FLARE or beat == Beat.HOLD else 1.0


func reach_mult_at(bite: HunterBite, charge: float) -> float:
	return lerpf(1.0, bite.settings.hold_reach_mult, charge)


func capacity_mult_at(bite: HunterBite, charge: float) -> float:
	return lerpf(1.0, bite.settings.hold_capacity_mult, charge)


func on_open(bite: HunterBite) -> void:
	_stop_pulls()
	source = LureField.Source.new(bite.fish, bite.settings)
	source.place(_esca(bite), bite.mouth_point(), -bite.fish.global_basis.z, bite.reach())
	source.start()
	beat = Beat.FLARE
	_beat_t = 0.0
	captive_count = 0
	closeness = 0.0
	_was_holding = true
	_vel += 14.0  # the flare's spike, rung down by the spring in on_tick
	_eye_vel += 18.0
	var m := _angler(bite, true)
	if m != null:
		var k := bite.fish.hitbox_length / 6.0
		m.call("kick_stalk", (-bite.fish.global_basis.z * 1.5 + bite.fish.global_basis.y * 2.5) * 4.0 * k)


func on_hold(bite: HunterBite, delta: float) -> void:
	if source == null:
		return
	var world := bite.world
	if world != null and (not is_instance_valid(world) or world.get("phase") != WhatStinksMatch.Phase.LIVE):
		return
	var fwd := -bite.fish.global_basis.z.normalized()
	source.place(_esca(bite), bite.mouth_point(), fwd, bite.reach())
	source.advance(delta)
	var takes_players: bool = bite.settings.get("bite_takes_players") != false
	var count := 0
	var near := 0.0
	if takes_players:
		for prey: FishController in _prey(bite):
			if not is_instance_valid(prey) or prey == bite.fish or prey.puppet:
				continue  # a puppet is pulled on its own machine
			var id := prey.get_instance_id()
			var accel := source.accel_on(id, prey.global_position, LureField.intent_of(prey), LureField.is_human(prey), LureField.dashing(prey), delta)
			if accel != Vector3.ZERO:
				prey.apply_push(accel * delta)
			var level: float = float(source.captive.get(id, 0.0))
			if level > 0.2:
				count += 1
			if level > 0.05:
				near = maxf(near, 1.0 - clampf(prey.global_position.distance_to(source.mouth) / (source.radius * 0.6), 0.0, 1.0))
	captive_count = count
	closeness = near
	_pull_schools(bite, fwd)


func on_tick(bite: HunterBite, delta: float) -> void:
	LureField.tick(delta)
	var holding := bite.holding()
	if _was_holding and not holding:
		_released(bite)
	_was_holding = holding
	_beat_t += delta
	if beat == Beat.FLARE and _beat_t > 0.3:
		beat = Beat.HOLD
	var ramp: float = source.strength() if source != null else 0.0
	var flare := LureField.cfg(bite.settings, "lure_flare")
	var want := 1.0
	var want_eye := 1.0
	match beat:
		Beat.FLARE, Beat.HOLD:
			want = flare * (0.85 + 0.15 * ramp)
			want_eye = 1.0 + 0.35 * ramp + 0.3 * closeness
		Beat.SNAP:
			want = 0.1
			want_eye = 0.15
		Beat.COOL:
			var t := smoothstep(0.0, 1.0, _beat_t / _cool_len)
			want = lerpf(0.1, 1.0, t)
			want_eye = lerpf(0.15, 1.0, t)
			if _beat_t >= _cool_len:
				beat = Beat.IDLE
	# The level is a damped spring (rings after the press's kick); the eyes a stiffer one.
	_vel += (want - esca_level) * 220.0 * delta
	_vel *= exp(-14.0 * delta)
	esca_level = maxf(esca_level + _vel * delta, 0.0)
	_eye_vel += (want_eye - eye_level) * 300.0 * delta
	_eye_vel *= exp(-18.0 * delta)
	eye_level = clampf(eye_level + _eye_vel * delta, 0.0, 2.0)
	# The flicker quickens as prey close in; it only shows while the lure is held.
	var shown := esca_level
	if beat == Beat.FLARE or beat == Beat.HOLD:
		flicker_hz = lerpf(LureField.cfg(bite.settings, "lure_flicker_min"), LureField.cfg(bite.settings, "lure_flicker_max"), closeness)
		_phase = fmod(_phase + TAU * flicker_hz * delta, TAU * 64.0)
		shown *= 1.0 + (0.12 + 0.3 * closeness) * ramp * sin(_phase)
	else:
		flicker_hz = 0.0
	_write(bite, shown)
	_gape_jaw(bite, delta)


## Eases the jaw wrapper's gape multiplier toward gape_mult() (the Angler's jaw opens wider while the lure is held).
func _gape_jaw(bite: HunterBite, delta: float) -> void:
	var jaw: Object = bite.get("_jaw")
	if jaw == null or not ("gape_mult" in jaw):
		return
	_gape = lerpf(_gape, gape_mult(bite), 1.0 - exp(-10.0 * delta))
	if absf(_gape - float(jaw.get("gape_mult"))) > 0.002:
		jaw.set("gape_mult", _gape)
		jaw.call("refresh")


## The called-off bite (or the Hunter went): the field ends at once and the esca relights.
func on_cancel(bite: HunterBite) -> void:
	_stop_field()
	if beat != Beat.IDLE:
		beat = Beat.COOL
		_beat_t = 0.0
		_cool_len = 0.6
	_was_holding = false


func on_landed(bite: HunterBite) -> void:
	var extra := LureField.cfg(bite.settings, "lure_cooldown")
	bite.cooldown = maxf(bite.cooldown, extra)
	beat = Beat.COOL
	_beat_t = 0.0
	_cool_len = maxf(bite.cooldown, 0.6)


## Tap mode and a plain press: close enough, press once. Hold: open when prey are in the light, let the lure work, shut once a
## fish is in the frustum and the charge is up (or it is getting away).
func bot_plan(bot: WhatStinksBot, bite: HunterBite) -> Dictionary:
	var settings := bite.settings
	var gap := bot.target_gap
	var radius := LureField.cfg(settings, "lure_radius")
	var ready := bite.cooldown <= 0.0 and not bite.busy() and bot.target_ahead > 0.4 and not bot.stinker_blocks
	if settings.bite_mode == WhatStinksSettings.BiteMode.TAP:
		return {"press": ready and gap <= bite.reach() * settings.hunter_bot_bite_share, "hold": false}
	if not bite.holding():
		return {"press": ready and gap <= radius * 0.6, "hold": false}
	var in_frustum := bite.in_bite(bot.target_at)
	var ramped: bool = source != null and source.strength() >= 0.5
	var getting_away := gap > bot.target_prev_gap + 0.001 and gap <= bite.reach() * 1.2
	var gave_up := gap > radius * 1.3 or bite.held_for > LureField.cfg(settings, "lure_ramp_s") * 3.0 + 3.0
	var release := (in_frustum and (bite.charge() >= settings.hunter_bot_charge or ramped)) or getting_away or gave_up
	if bot.stinker_blocks and not gave_up:
		release = false
	return {"press": false, "hold": not release}


func _released(bite: HunterBite) -> void:
	_stop_field()
	beat = Beat.SNAP
	_beat_t = 0.0
	_vel -= 6.0  # the light is knocked out
	var m := _angler(bite, false)
	if m != null:
		var k := bite.fish.hitbox_length / 6.0
		m.call("kick_stalk", bite.fish.global_basis.z * 6.0 * k)


func _stop_field() -> void:
	if source != null:
		source.stop()
		source = null
	_stop_pulls()
	captive_count = 0
	closeness = 0.0


func _stop_pulls() -> void:
	for school in _pulled:
		if is_instance_valid(school):
			school.end_pull(self)
	_pulled.clear()


func _prey(bite: HunterBite) -> Array:
	if target_source.is_valid():
		return target_source.call()
	if bite.world != null and is_instance_valid(bite.world):
		return bite.world.call("live_prey")
	return []


func _pull_schools(bite: HunterBite, fwd: Vector3) -> void:
	var world := bite.world
	if world == null or not is_instance_valid(world) or source == null:
		return
	var factor := LureField.cfg(bite.settings, "lure_school_pull")
	var field: WhatStinksField = world.get("field")
	_pulled.clear()
	if field == null or factor <= 0.0:
		return
	var speed := source.pull * factor * source.strength()
	var point := source.mouth + fwd * source.reach * 0.45
	for school in field.schools:
		if not is_instance_valid(school) or school.alive_count() == 0:
			continue
		if school.middle().distance_to(source.esca) > source.radius + school.radius() * 2.0:
			continue
		school.pull(self, point, fwd, source.cone_deg, speed, source.radius, source.reach * 0.4)
		_pulled.append(school)


## The esca now (world): the model's bulb, or a point over the snout when there is no model.
func _esca(bite: HunterBite) -> Vector3:
	var m := _angler(bite, false)
	if m != null:
		return m.call("esca_world")
	var fish := bite.fish
	return bite.mouth_point() - fish.global_basis.z * bite.reach() * 0.3 + fish.global_basis.y * fish.hitbox_length * 0.45


func _angler(bite: HunterBite, force: bool) -> Node3D:
	if _model != null and is_instance_valid(_model):
		return _model
	_model = null
	if not force and Time.get_ticks_msec() < _find_wait:
		return null
	_find_wait = Time.get_ticks_msec() + 500.0
	var visual: Node = bite.fish.get("_visual") if is_instance_valid(bite.fish) else null
	_model = _search(visual, 0)
	return _model


func _search(node: Node, depth: int) -> Node3D:
	if node == null or depth > 6:
		return null
	if node is AnglerModel:
		return node as Node3D
	for child in node.get_children():
		var hit := _search(child, depth + 1)
		if hit != null:
			return hit
	return null


func _write(bite: HunterBite, esca: float) -> void:
	var m := _angler(bite, false)
	if m == null:
		return
	if absf(esca - _written_esca) > 0.003:
		_written_esca = esca
		m.set("esca_intensity", esca)
	if absf(eye_level - _written_eye) > 0.003:
		_written_eye = eye_level
		m.set("eye_glint", eye_level)
