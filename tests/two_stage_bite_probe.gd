## Two-stage attacks, phase 0 (two-stage-attack.md section 7, core and net): the held bite.
## Per ready form at 0.5x, 1x and 3x on a plain controller: a press opens the jaws within
## `open_s` (+ a few ticks), a hold keeps them open (30 s for the shark at 1x), the charge reaches
## 1 at `charge_s`, the chomp's reach and capacity grow with it, a release lands within the
## strike's length, a tap strikes from a partial open, the cooldown grows with the hold up to
## its cap, the hold costs swim speed and turn and give them back, and the Hunter's jump press
## neither jumps nor dodges. `bite_mode = tap` behaves as the snap did. Then the bot's press,
## hold and release for the chomp style, a puppet's net_open / net_clamp / net_close (the host's
## cap on a guest's reported charge), the ChompKit.Bite hold (opt-in: the timed bite unchanged),
## and a real match: a held bite through a school takes more than a tap.
##   Godot_console.exe --headless --path . res://tests/two_stage_bite_probe.tscn   (about 4 min; -- --match-only skips the per-form sweep)
extends Node

const SIZES := [0.5, 1.0, 3.0]

var main: Node
var fish: FishController
var checks := 0
var failures := 0
var tps := 120


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Waits until `done` is true, at most `ticks` physics ticks. Returns whether it was.
func _until(done: Callable, ticks: int) -> bool:
	for i in ticks:
		if done.call():
			return true
		await get_tree().physics_frame
	return done.call()


func _place() -> void:
	var at: Transform3D = main._environment.spawn_transform()
	fish.global_transform = Transform3D(Basis.IDENTITY, at.origin + Vector3(0.0, 25.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


func _run() -> void:
	await _frames(5)
	main.set_environment("Ocean")
	await _frames(5)
	tps = int(Engine.physics_ticks_per_second)
	var settings := WhatStinksSettings.shared()
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	_check(settings.bite_mode == WhatStinksSettings.BiteMode.HOLD, "the default bite mode is hold")
	_kit_hold()
	var match_only := OS.get_cmdline_user_args().has("--match-only")  # skip the per-form sweep (it takes minutes)
	var first := true
	for key: String in ([] as Array[String] if match_only else HunterForms.ready_keys()):
		for s: float in SIZES:
			await _form_at(key, s, first and s == 1.0)
			first = first and s != 1.0
	await _tap_mode()
	await _feel()
	await _jump_ignored()
	_bot_plans()
	await _puppet()
	await _in_match()
	print("two_stage_bite_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# --- ChompKit.Bite -----------------------------------------------------------

func _kit_hold() -> void:
	var settings := UnnaturalSettings.shared()
	var held := ChompKit.Bite.new(settings)
	var cues: Array[StringName] = []
	held.cue.connect(func(name: StringName) -> void: cues.append(name))
	var full := [false]
	held.charged.connect(func() -> void: full[0] = true)
	held.open_now(0.1, 3.0, 0.5)
	var dt := 1.0 / tps
	var landed := false
	for i in tps * 20:
		landed = held.update(dt) or landed
	_check(held.phase == ChompKit.Phase.HOLD and held.open == 1.0 and not landed, "kit: a held-open bite stays in HOLD for 20 s")
	_check(held.charge == 1.0 and full[0], "kit: the charge hit 1 (and charged fired once)")
	_check(cues.has(&"gape") and cues.has(&"hold") and not cues.has(&"strike"), "kit: gape then hold cues, no strike")
	held.release()
	var contact := false
	for i in tps:
		contact = held.update(dt) or contact
	_check(contact and held.phase != ChompKit.Phase.HOLD and cues.has(&"strike"), "kit: release strikes and lands")
	# The bosses' timed chomp is as it was: HOLD times out into STRIKE on its own.
	var timed := ChompKit.Bite.new(settings)
	timed.start(0.5, 3.0)
	var struck := false
	var timed_cues: Array[StringName] = []
	timed.cue.connect(func(name: StringName) -> void: timed_cues.append(name))
	for i in tps * 2:
		struck = timed.update(dt) or struck
	_check(struck and timed_cues.has(&"strike") and not timed.held_open, "kit: the timed bite still strikes by itself (bosses unchanged)")
	# A tap: released in the gape strikes from the partial open.
	var tap := ChompKit.Bite.new(settings)
	tap.open_now(0.2, 3.0)
	for i in 5:
		tap.update(dt)
	var partial := tap.open
	tap.release()
	_check(partial > 0.0 and partial < 1.0 and tap.phase == ChompKit.Phase.STRIKE, "kit: released in the gape it strikes from a partial open (%.2f)" % partial)


# --- Per form ------------------------------------------------------------------

func _form_at(key: String, s: float, long_hold: bool) -> void:
	var settings := WhatStinksSettings.shared()
	var form := HunterForm.sheet(key)
	var tag := "%s x%.1f" % [key, s]
	var size := HunterSize.shared()
	size.size_mult = s
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	size.apply(fish, form)
	await _frames(3)
	_place()
	await _frames(3)
	var bite := HunterBite.new()
	bite.settings = settings
	fish.add_child(bite)
	bite.setup(fish, form)
	var landed: Array = []
	bite.chomped.connect(func(_m: Vector3, reach: float, _r: float, capacity: int) -> void:
		landed.append({"reach": reach, "capacity": capacity, "charge": bite.strike_charge(), "frame": Engine.get_physics_frames()}))
	var released: Array = []
	bite.released.connect(func(charge: float) -> void: released.append({"charge": charge, "open": bite.bite.open, "frame": Engine.get_physics_frames()}))
	var input := FishInput.new()
	fish.controls = input
	await _frames(2)
	var base_reach := size.bite_reach(fish, form)
	var base_capacity := size.bite_capacity(fish, form)
	var base_speed := fish.speed_scale
	var base_turn := fish.turn_scale
	var open_s := float(form["open_s"])
	var charge_s := float(form["charge_s"])
	var strike_ticks := ceili(UnnaturalSettings.shared().chomp_strike * tps)

	# The press opens.
	input.jump = true
	var pressed := Engine.get_physics_frames()
	var opened := await _until(func() -> bool: return bite.bite.open > 0.9, tps)
	var open_ticks := Engine.get_physics_frames() - pressed
	_check(opened and open_ticks <= ceili(open_s * tps) + 3, "%s: the press opens the jaws in %d ticks (open_s %.2f s)" % [tag, open_ticks, open_s])
	_check(bite.holding() and landed.is_empty(), "%s: held open, nothing has landed" % tag)
	_check(is_equal_approx(fish.speed_scale, base_speed * settings.hold_speed_mult) and is_equal_approx(fish.turn_scale, base_turn * settings.hold_turn_mult), "%s: holding costs speed x%.2f and turn x%.2f" % [tag, settings.hold_speed_mult, settings.hold_turn_mult])
	_check(is_equal_approx(bite.reach_at(0.0), base_reach) and bite.capacity_at(0.0) == base_capacity, "%s: an uncharged bite is the plain one (reach %.2f, capacity %d)" % [tag, base_reach, base_capacity])

	# The charge.
	var full := await _until(func() -> bool: return bite.charge() >= 1.0, int((open_s + charge_s) * tps) + 30)
	var full_ticks := Engine.get_physics_frames() - pressed
	var wanted := int((open_s + charge_s) * tps)
	_check(full and absi(full_ticks - wanted) <= 4, "%s: full charge after %d ticks (wanted %d)" % [tag, full_ticks, wanted])
	# Reach x hold_reach_mult and capacity x hold_capacity_mult are the chomp style's; the other styles
	# spend the charge their own way (their own probes cover it), so only check they stay sane.
	var chomp_style := String(form["attack"]) == "chomp"
	if chomp_style:
		_check(absf(bite.reach() - base_reach * settings.hold_reach_mult) < 0.01, "%s: reach grew with the charge (%.2f of %.2f)" % [tag, bite.reach(), base_reach])
		_check(bite.capacity() == maxi(1, roundi(base_capacity * settings.hold_capacity_mult)), "%s: capacity grew with it (%d from %d)" % [tag, bite.capacity(), base_capacity])
	else:
		_check(bite.reach() >= base_reach - 0.01 and bite.capacity() >= base_capacity, "%s: a charged %s bite is at least the plain one (reach %.2f, capacity %d)" % [tag, form["attack"], bite.reach(), bite.capacity()])

	# Held on: no max hold.
	var hold_s := 30.0 if long_hold else 2.5
	await _frames(int(hold_s * tps))
	_check(bite.holding() and bite.bite.phase == ChompKit.Phase.HOLD and bite.bite.open > 0.99 and landed.is_empty(), "%s: still held open after %.0f s more" % [tag, hold_s])
	var held := bite.held_for

	# The release lands within the strike's length.
	input.jump = false
	var let_go := Engine.get_physics_frames()
	var did_land := await _until(func() -> bool: return not landed.is_empty(), tps)
	var land_ticks := Engine.get_physics_frames() - let_go
	_check(did_land and land_ticks <= strike_ticks + 4, "%s: the release lands in %d ticks (strike %d)" % [tag, land_ticks, strike_ticks])
	if did_land:
		var hit: Dictionary = landed[0]
		if chomp_style:
			_check(float(hit["charge"]) > 0.99 and absf(float(hit["reach"]) - base_reach * settings.hold_reach_mult) < 0.01, "%s: it landed at full charge (reach %.2f)" % [tag, hit["reach"]])
			_check(int(hit["capacity"]) == maxi(1, roundi(base_capacity * settings.hold_capacity_mult)), "%s: and took the held capacity (%d)" % [tag, hit["capacity"]])
		else:
			_check(float(hit["charge"]) > 0.99, "%s: it landed at full charge (%.2f)" % [tag, hit["charge"]])
	var bite_every := float(form["bite_every"])
	var cd_wanted := minf(bite_every + settings.hold_cooldown_per_s * held, maxf(settings.hold_cooldown_max, bite_every))
	_check(absf(bite.cooldown - cd_wanted) < 0.15, "%s: the cooldown grew with the hold (%.2f s after %.1f s held; wanted %.2f)" % [tag, bite.cooldown, held, cd_wanted])
	if long_hold:
		_check(absf(bite.cooldown - maxf(settings.hold_cooldown_max, bite_every)) < 0.15, "%s: and stopped at its cap (%.1f s)" % [tag, settings.hold_cooldown_max])
	_check(is_equal_approx(fish.speed_scale, base_speed) and is_equal_approx(fish.turn_scale, base_turn), "%s: the hold costs were given back" % tag)
	_check(released.size() == 1 and float(released[0]["charge"]) > 0.99, "%s: released(charge) said so once" % tag)

	# A tap: strikes at once from a partial open.
	await _until(func() -> bool: return not bite.busy(), tps * 2)
	bite.cooldown = 0.0
	landed.clear()
	released.clear()
	input.jump = true
	await _frames(3)
	input.jump = false
	let_go = Engine.get_physics_frames()
	did_land = await _until(func() -> bool: return not landed.is_empty(), tps)
	land_ticks = Engine.get_physics_frames() - let_go
	_check(did_land and land_ticks <= strike_ticks + 4, "%s: a tap lands %d ticks after the release" % [tag, land_ticks])
	_check(not released.is_empty() and float(released[0]["open"]) >= settings.tap_open_min - 0.001 and float(released[0]["charge"]) == 0.0, "%s: a tap strikes from at least tap_open_min open, uncharged (%.2f)" % [tag, float(released[0]["open"]) if not released.is_empty() else -1.0])
	if did_land:
		_check(float(landed[0]["charge"]) == 0.0 and is_equal_approx(float(landed[0]["reach"]), base_reach) and int(landed[0]["capacity"]) == base_capacity, "%s: with the plain reach %.2f and capacity %d" % [tag, landed[0]["reach"], landed[0]["capacity"]])
	_check(absf(bite.cooldown - bite_every) < 0.15, "%s: a tap's cooldown is the form's own (%.2f s)" % [tag, bite.cooldown])

	# The cooldown refuses a press.
	input.jump = true
	await _frames(3)
	_check(not bite.holding(), "%s: a press on the cooldown opens nothing" % tag)
	input.jump = false
	await _frames(2)
	bite.release_fish()
	bite.queue_free()
	await _frames(2)


# --- bite_mode = tap -------------------------------------------------------------

func _tap_mode() -> void:
	var settings := WhatStinksSettings.shared()
	var form := HunterForm.sheet("drowned_shark")
	HunterSize.shared().size_mult = 1.0
	fish.controls = null
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().apply(fish, form)
	await _frames(3)
	_place()
	await _frames(3)
	settings.bite_mode = WhatStinksSettings.BiteMode.TAP
	var bite := HunterBite.new()
	bite.settings = settings
	fish.add_child(bite)
	bite.setup(fish, form)
	var landed: Array = []
	bite.chomped.connect(func(_m: Vector3, _r: float, _d: float, _c: int) -> void: landed.append(Engine.get_physics_frames()))
	var input := FishInput.new()
	fish.controls = input
	await _frames(2)
	var pressed := Engine.get_physics_frames()
	input.jump = true
	var did_land := await _until(func() -> bool: return not landed.is_empty(), tps)
	var delay := Engine.get_physics_frames() - pressed
	_check(did_land and delay <= ceili(UnnaturalSettings.shared().chomp_strike * tps) + 5, "tap mode: it chomps on the press (%d ticks), as the snap did" % delay)
	_check(not bite.holding() and not bite.busy() or bite.bite.phase != ChompKit.Phase.HOLD, "tap mode: it never held open")
	_check(is_equal_approx(bite.strike_charge(), 0.0), "tap mode: no charge")
	input.jump = false
	await _frames(5)
	_check(landed.size() == 1, "tap mode: the release did nothing")
	_check(absf(bite.cooldown - float(form["bite_every"])) < 0.2, "tap mode: the plain cooldown (%.2f s)" % bite.cooldown)
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	bite.release_fish()
	bite.queue_free()
	await _frames(2)


# --- Jump and dodge ------------------------------------------------------------------

func _jump_ignored() -> void:
	var settings := WhatStinksSettings.shared()
	var form := HunterForm.sheet("drowned_shark")
	fish.controls = null
	_place()
	await _frames(3)
	var jumps := [0, 0, 0]
	fish.jumped.connect(func() -> void: jumps[0] += 1)
	fish.double_jumped.connect(func() -> void: jumps[1] += 1)
	fish.dodged.connect(func(_d: Vector3) -> void: jumps[2] += 1)
	var input := FishInput.new()
	fish.controls = input
	# Without a bite the press jumps (the control).
	fish.ignore_jump = false
	input.jump = true
	await _frames(4)
	input.jump = false
	await _frames(4)
	_check(jumps[0] >= 1, "control: a plain fish jumps on the press")
	await _frames(tps * 2)
	jumps = [0, 0, 0]
	_place()
	var bite := HunterBite.new()
	bite.settings = settings
	fish.add_child(bite)
	bite.setup(fish, form)
	_check(fish.ignore_jump, "the Hunter's fish ignores jump and dodge")
	await _frames(3)
	for i in 3:
		input.jump = true
		input.stick = Vector2(1.0, 0.0)  # a dodge if it were a second jump
		await _frames(6)
		input.jump = false
		await _frames(6)
		bite.cooldown = 0.0
		await _until(func() -> bool: return not bite.busy(), tps * 2)
	_check(jumps[0] == 0 and jumps[1] == 0 and jumps[2] == 0, "presses and releases never jump, double-jump or dodge (%s)" % [jumps])
	_check(bite.bites >= 1, "...they only bite (%d)" % bite.bites)
	input.stick = Vector2.ZERO
	bite.release_fish()
	_check(not fish.ignore_jump, "the fish gets its jump back when the bite goes")
	bite.queue_free()
	await _frames(2)


# --- The bot ---------------------------------------------------------------------------

func _bot_plans() -> void:
	var settings := WhatStinksSettings.shared()
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	var form := HunterForm.sheet("drowned_shark")
	HunterSize.shared().size_mult = 1.0
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().apply(fish, form)
	var bite := HunterBite.new()
	bite.settings = settings
	fish.add_child(bite)
	bite.setup(fish, form)
	var bot := WhatStinksBot.new()
	var forward := -fish.global_basis.z.normalized()
	var reach := bite.reach()
	var plan := {}
	bot.target_ahead = 0.9
	bot.target_gap = reach * (settings.hunter_bot_open_gap + 1.0)
	bot.target_at = bite.mouth_point() + forward * bot.target_gap
	bot.target_prev_gap = bot.target_gap
	plan = bite.attack.bot_plan(bot, bite)
	_check(not bool(plan["press"]), "bot: a fish far off is not worth opening for")
	bot.target_gap = reach * settings.hunter_bot_open_gap * 0.9
	bot.target_prev_gap = bot.target_gap
	plan = bite.attack.bot_plan(bot, bite)
	_check(bool(plan["press"]), "bot: a fish in open range gets a press")
	bot.target_ahead = 0.1
	_check(not bool(bite.attack.bot_plan(bot, bite)["press"]), "bot: not one behind it")
	bot.target_ahead = 0.9
	bot.stinker_blocks = true
	_check(not bool(bite.attack.bot_plan(bot, bite)["press"]), "bot: not with a stinker in the bite (Upset Stomach)")
	bot.stinker_blocks = false
	# Held: keep it down until a fish is in the frustum and the charge is up.
	bite.cooldown = 0.0
	bite.try_open()
	_check(bite.holding(), "bot: (the probe opened the jaws)")
	bot.target_at = bite.mouth_point() + forward * bite.reach() * 0.5
	bot.target_gap = bite.reach() * 0.5
	bot.target_prev_gap = bot.target_gap
	_check(bool(bite.attack.bot_plan(bot, bite)["hold"]), "bot: a fish in the frustum but no charge yet: keep holding")
	bite.bite.charge = 1.0
	_check(not bool(bite.attack.bot_plan(bot, bite)["hold"]), "bot: charged with a fish in the frustum: let go")
	bot.stinker_blocks = true
	_check(bool(bite.attack.bot_plan(bot, bite)["hold"]), "bot: ...unless a stinker is in it")
	bot.stinker_blocks = false
	bite.bite.charge = 0.0
	bot.target_prev_gap = bot.target_gap - 0.5
	_check(not bool(bite.attack.bot_plan(bot, bite)["hold"]), "bot: a fish getting away: let go at once")
	bot.target_prev_gap = bot.target_gap
	bot.target_gap = bite.reach() * settings.hunter_bot_open_gap * 3.0
	bot.target_at = bite.mouth_point() + forward * bot.target_gap
	_check(not bool(bite.attack.bot_plan(bot, bite)["hold"]), "bot: nothing near any more: give up and let go")
	settings.bite_mode = WhatStinksSettings.BiteMode.TAP
	bite.abort()
	bot.target_gap = reach * settings.hunter_bot_bite_share * 0.8
	bot.target_prev_gap = bot.target_gap
	_check(bool(bite.attack.bot_plan(bot, bite)["press"]), "bot: in tap mode it presses when close, as before")
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	bot.free()
	bite.release_fish()
	bite.queue_free()


# --- Net: a puppet ---------------------------------------------------------------------

func _puppet() -> void:
	var settings := WhatStinksSettings.shared()
	var form := HunterForm.sheet("drowned_shark")
	fish.controls = null
	_place()
	await _frames(3)
	fish.make_puppet()
	var bite := HunterBite.new()
	bite.settings = settings
	fish.add_child(bite)
	bite.setup(fish, form)
	var events: Array = []
	bite.opened.connect(func() -> void: events.append("open"))
	bite.released.connect(func(charge: float) -> void: events.append("close %.2f" % charge))
	bite.aborted.connect(func() -> void: events.append("abort"))
	var landed: Array = []
	bite.chomped.connect(func(_m: Vector3, _r: float, _d: float, _c: int) -> void: landed.append(bite.strike_charge()))
	await _frames(2)
	bite.net_open()
	var opened := await _until(func() -> bool: return bite.bite.open > 0.9, tps)
	_check(opened and bite.holding() and events == ["open"], "net: _ws_bite_open opens the puppet's jaws (pose only)")
	var wanted := 0.3
	await _frames(int(wanted * tps))
	var seen := bite.bite.charge
	_check(seen > 0.05 and seen < 0.5, "net: the puppet's own clock charged it (%.2f)" % seen)
	var cap := bite.net_clamp(1.0)
	_check(cap <= seen + HunterBite.NET_SLACK / float(form["charge_s"]) + 0.02 and cap < 1.0, "net: a reported charge of 1.0 is clamped to what the host saw (%.2f)" % cap)
	_check(is_equal_approx(bite.net_clamp(seen * 0.5), seen * 0.5), "net: a smaller report stands")
	_check(bite.net_clamp(-1.0) < 0.0, "net: a call-off passes through")
	bite.net_close(cap)
	var did_land := await _until(func() -> bool: return not landed.is_empty(), tps)
	_check(did_land and absf(float(landed[0]) - cap) < 0.001 and is_equal_approx(bite.net_cap, cap) and events.size() == 2, "net: _ws_bite_close shuts them at the clamped charge (%.2f)" % cap)
	await _until(func() -> bool: return not bite.busy(), tps * 2)
	# Called off: back to rest with no strike.
	landed.clear()
	events.clear()
	bite.net_open()
	await _frames(20)
	bite.net_close(-1.0)
	await _frames(tps)
	_check(landed.is_empty() and not bite.holding() and events == ["open", "abort"] and not bite.busy(), "net: a negative charge calls the bite off with no strike")
	# A puppet's button does nothing (its owner's machine bites).
	var input := FishInput.new()
	fish.controls = input
	input.jump = true
	await _frames(10)
	input.jump = false
	_check(not bite.holding() and landed.is_empty(), "net: a puppet's own press opens nothing here")
	bite.release_fish()
	bite.queue_free()
	await _frames(2)


# --- A match ----------------------------------------------------------------------------

func _in_match() -> void:
	fish.puppet = false
	fish.freeze = false
	var settings := WhatStinksSettings.shared()
	settings.hide_time = 1.0
	settings.round_time = 120.0
	settings.arena_radius = 90.0
	settings.school_count = 4
	settings.school_min = 30
	settings.school_max = 30
	settings.min_players = 4
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	settings.variant = WhatStinksSettings.Variant.SWEEP
	settings.lock_bite = false
	settings.hold_cooldown_per_s = 0.0
	HunterSize.shared().size_mult = 1.0
	main.set_mode(main.WHAT_STINKS)
	await _frames(5)
	main.play_match()
	await _frames(5)
	var game: WhatStinksMatch = main.what_stinks
	_check(game != null and game.is_hunter(fish) and game.bites.has(fish), "match: the local fish is the Hunter with a bite")
	if game == null:
		return
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 4)
	for other in game.players:
		if other != fish and not game.is_hunter(other):
			other.freeze = true
	var bite: HunterBite = game.bites[fish]
	_check(fish.ignore_jump and bite.attack.key == "chomp", "match: the Hunter ignores jump and its style is the chomp")
	var closes: Array = []
	game.bite_closed.connect(func(_h: FishController, charge: float) -> void: closes.append(charge))
	var input := FishInput.new()
	fish.controls = input
	var ate := {}
	var judged := {}  # what each bite offered: how many fish it could take, and how far it reached
	var mode_now := [""]
	bite.chomped.connect(func(_m: Vector3, bite_reach: float, _r: float, cap: int) -> void: judged[mode_now[0]] = [cap, bite_reach])
	for mode in ["tap", "hold"]:
		var school: School = game.field.schools[0 if mode == "tap" else 1]
		mode_now[0] = mode
		school.set_physics_process(false)
		var target := school.middle()  # the thick of it: the frustum has fish to choose from
		fish.global_transform = Transform3D(Basis.IDENTITY, target + Vector3(0.0, 0.0, fish.hitbox_length * 0.45 + 1.0))
		fish.global_position += (target + Vector3(0.0, 0.0, 1.0)) - bite.mouth_point()
		fish.linear_velocity = Vector3.ZERO
		fish.angular_velocity = Vector3.ZERO
		fish.controls_locked = false
		bite.cooldown = 0.0
		await _frames(3)
		var before := school.alive_count()
		var bites_before := bite.bites
		input.jump = true
		if mode == "hold":
			await _until(func() -> bool: return bite.charge() >= 1.0, tps * 3)
		else:
			await _frames(3)
		input.jump = false
		await _until(func() -> bool: return not bite.busy() and bite.bites > bites_before, tps * 3)
		await _frames(5)
		ate[mode] = before - school.alive_count()
		print("      %s: ate %d" % [mode, ate[mode]])
		await _until(func() -> bool: return not bite.busy(), tps * 3)
	_check(int(ate["tap"]) >= 1 and int(ate["tap"]) <= bite.capacity_at(0.0), "match: a tap ate %d (capacity %d)" % [ate["tap"], bite.capacity_at(0.0)])
	_check(int(ate["hold"]) <= bite.capacity_at(1.0) and int(judged["hold"][0]) > int(judged["tap"][0]) and float(judged["hold"][1]) > float(judged["tap"][1]), "match: a held bite is judged with more capacity and reach (%s vs %s; it ate %d vs %d, which depends on the school)" % [judged["hold"], judged["tap"], ate["hold"], ate["tap"]])
	_check(closes.size() == 2 and float(closes[0]) == 0.0 and float(closes[1]) > 0.99, "match: bite_closed carried each charge (%s)" % [closes])
	# The schools' alarm follows the open jaws.
	bite.cooldown = 0.0
	var calm := _alarm_of(game)
	input.jump = true
	await _until(func() -> bool: return bite.holding(), tps)
	var alarmed := _alarm_of(game)
	input.jump = false
	await _until(func() -> bool: return not bite.busy(), tps * 2)
	var after := _alarm_of(game)
	_check(absf(alarmed - calm * settings.hold_alarm_mult) < 0.01 and absf(after - calm) < 0.01, "match: the schools' alarm x%.1f while the jaws are open (%.2f, %.2f, %.2f)" % [settings.hold_alarm_mult, calm, alarmed, after])
	# A prey player near the open mouth feels the heartbeat; one far away does not.
	var watcher: FishController = null
	for other in game.players:
		if other != fish and game.is_live_prey(other):
			watcher = other
			break
	if watcher != null:
		var kept := watcher.controls
		watcher.controls = null  # a person's fish, as far as the rumble goes
		bite.cooldown = 0.0
		WhatStinksRumble.reset()
		WhatStinksRumble.record = true
		watcher.global_position = bite.mouth_point() - fish.global_basis.z * 2.0
		watcher.linear_velocity = Vector3.ZERO
		input.jump = true
		await _until(func() -> bool: return bite.charge() > 0.3, tps * 2)
		var near_pulses := WhatStinksRumble.calls.filter(func(call: Dictionary) -> bool: return call["fish"] == watcher and bool(call["felt"])).size()
		watcher.global_position = bite.mouth_point() - fish.global_basis.z * bite.reach() * 20.0
		WhatStinksRumble.calls.clear()
		await _frames(tps)
		var far_pulses := WhatStinksRumble.calls.filter(func(call: Dictionary) -> bool: return call["fish"] == watcher).size()
		input.jump = false
		await _until(func() -> bool: return not bite.busy(), tps * 2)
		watcher.controls = kept
		WhatStinksRumble.reset()
		_check(near_pulses > 0 and far_pulses == 0, "match: a prey player near the open mouth feels a heartbeat (%d pulses), one far off does not (%d)" % [near_pulses, far_pulses])


func _alarm_of(game: WhatStinksMatch) -> float:
	return game.field.alarm_scale


# --- Feel (phase 1): seen, felt and heard on the same tick -----------------------------------

## One held bite on a plain fish, with the sound and the rumble stubbed to record their calls. For each
## beat the tick of the pose change, the ChompKit cue, the HunterBiteFx sound and the pad rumble must all
## lie within one tick of each other. Then a miss, the hit-stop, bots/puppets feeling nothing, the sound
## ids, and the prey-side impact.
func _feel() -> void:
	var settings := WhatStinksSettings.shared()
	var form := HunterForm.sheet("drowned_shark")
	await get_tree().create_timer(settings.hitstop_ms * 0.001 + 0.2).timeout  # the last stage's hit-stop (a tap chomp landing) is over
	fish.controls_locked = false
	HunterSize.shared().size_mult = 1.0
	fish.controls = null
	fish.puppet = false
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().apply(fish, form)
	await _frames(3)
	_place()
	await _frames(3)
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	WhatStinksRumble.reset()
	WhatStinksRumble.record = true
	for bite_taken in [3, 0]:
		var tag := "feel (caught 3)" if bite_taken > 0 else "feel (a miss)"
		var bite := HunterBite.new()
		bite.settings = settings
		fish.add_child(bite)
		bite.setup(fish, form)
		var fx := bite.fx()
		_check(fx != null and fx.get_parent() == bite, "%s: HunterBiteFx is a child of the bite" % tag)
		var events: Array = []  # {k, n, t}
		fx.sound_log = func(beat: String, id: String) -> void: events.append({"k": "sound", "n": beat, "id": id, "t": Engine.get_physics_frames()})
		bite.bite.cue.connect(func(cue_name: StringName) -> void: events.append({"k": "cue", "n": str(cue_name), "t": Engine.get_physics_frames()}))
		bite.bite.charged.connect(func() -> void: events.append({"k": "cue", "n": "charged", "t": Engine.get_physics_frames()}))
		bite.landed.connect(func(taken: int) -> void: events.append({"k": "landed", "n": str(taken), "t": Engine.get_physics_frames()}))
		bite.chomped.connect(func(_m: Vector3, _r: float, _d: float, _c: int) -> void: bite.report_landing(bite_taken))  # the match's judging
		var input := FishInput.new()
		fish.controls = input
		await _frames(2)
		WhatStinksRumble.calls.clear()
		var poses: Dictionary = {}  # beat -> first tick the pose shows it
		var last_phase: ChompKit.Phase = ChompKit.Phase.IDLE
		input.jump = true
		var total := int((float(form["open_s"]) + float(form["charge_s"]) + 0.5) * tps)
		for i in total + tps:
			await get_tree().physics_frame
			var t := Engine.get_physics_frames()
			var phase: ChompKit.Phase = bite.bite.phase
			if phase != last_phase:
				if phase == ChompKit.Phase.GAPE and not poses.has("press"):
					poses["press"] = t
				elif phase == ChompKit.Phase.HOLD and not poses.has("hold"):
					poses["hold"] = t
				elif phase == ChompKit.Phase.STRIKE and not poses.has("strike"):
					poses["strike"] = t
				last_phase = phase
			if bite.bite.charge >= 1.0 and not poses.has("charged"):
				poses["charged"] = t
			if bite.bite.landed and not poses.has("contact") and poses.has("strike"):
				poses["contact"] = t
			if i == total:
				input.jump = false
			if poses.has("contact") and i > total + 10:
				break
		var first := func(kind: String, event_name: String) -> int:
			for e: Dictionary in events:
				if e["k"] == kind and e["n"] == event_name:
					return int(e["t"])
			return -1
		# The first pulse of that length within a tick of `near` (seconds < 0: a catch's, over 0.125 s).
		var rumble_in := func(near: int, seconds: float) -> int:
			for call: Dictionary in WhatStinksRumble.calls:
				var length := float(call["seconds"])
				var match_length: bool = length > 0.125 if seconds < 0.0 else absf(length - seconds) < 0.001
				if match_length and int(call["tick"]) >= near - 1 and int(call["tick"]) <= near + 3:
					return int(call["tick"])
			return -1
		var sound_in := func(beat_name: String, near: int) -> int:
			for e: Dictionary in events:
				if e["k"] == "sound" and e["n"] == beat_name and absi(int(e["t"]) - near) <= 3:
					return int(e["t"])
			return -1
		# beat: [cue, sound beat, rumble seconds (0: none, -1: a catch's)]
		var contact_rumble := -1.0 if bite_taken > 0 else 0.06
		var beats := {"press": ["gape", "open", 0.08], "hold": ["hold", "hold", 0.12], "strike": ["strike", "strike", 0.0],
				"charged": ["charged", "charged", 0.06], "contact": ["contact", "chomp" if bite_taken > 0 else "miss", contact_rumble]}
		for beat: String in beats:
			var spec: Array = beats[beat]
			var pose: int = poses.get(beat, -1)
			var cue: int = first.call("cue", str(spec[0]))
			var sound: int = sound_in.call(str(spec[1]), cue)
			var rumble := -2  # none expected
			if float(spec[2]) != 0.0:
				rumble = rumble_in.call(cue, float(spec[2]))
			var ticks: Array[int] = [pose, cue, sound]
			if rumble != -2:
				ticks.append(rumble)
			var ok := not ticks.has(-1)
			var spread: int = (ticks.max() - ticks.min()) if ok else -1
			_check(ok and spread <= 1, "%s: %s: pose %d, cue %d, sound %d, rumble %s (spread %d tick)" % [tag, beat, pose, cue, sound, "-" if rumble == -2 else str(rumble), spread])
		var landed_at: int = first.call("landed", str(bite_taken))
		_check(landed_at >= 0 and landed_at == first.call("cue", "contact"), "%s: landed(%d) fired on the contact tick" % [tag, bite_taken])
		if bite_taken > 0:
			var crunch: int = sound_in.call("crunch", landed_at)
			_check(crunch == landed_at, "%s: a crunch on the contact tick" % tag)
			_check(fish.controls_locked, "%s: the Hunter is in hit-stop on a catch" % tag)
			await get_tree().create_timer(settings.hitstop_ms * 0.001 + 0.2).timeout
			_check(not fish.controls_locked and is_equal_approx(Engine.time_scale, 1.0), "%s: hit-stop ended; the global time scale never moved" % tag)
			# A round that ended (or a hurl) during the hit-stop keeps the Hunter locked when it ends.
			bite.fx().may_unlock = func() -> bool: return false
			bite.fx()._on_landed(2)
			_check(fish.controls_locked, "%s: a second hit-stop locks" % tag)
			await get_tree().create_timer(settings.hitstop_ms * 0.001 + 0.2).timeout
			_check(fish.controls_locked, "%s: the hit-stop does not unlock a Hunter the match locked meanwhile" % tag)
			bite.fx().may_unlock = Callable()
			fish.controls_locked = false
		else:
			_check(not fish.controls_locked, "%s: no hit-stop on a miss" % tag)
		_check(WhatStinksRumble.calls.all(func(call: Dictionary) -> bool: return not bool(call["felt"])), "%s: a bot-driven Hunter feels no rumble" % tag)
		input.jump = false
		await _until(func() -> bool: return not bite.busy(), tps * 2)
		bite.release_fish()
		bite.queue_free()
		await _frames(2)
		fish.controls = null
		fish.controls_locked = false

	# Sound ids: every beat of every style resolves to a catalogued id with a stand-in.
	var missing: Array = []
	for style: String in HunterBiteFx.SOUNDS:
		var ids: Array = (HunterBiteFx.SOUNDS[style] as Dictionary).values() + HunterBiteFx.COMMON.values()
		for id: String in ids:
			if not SoundCatalog.has(id) or not SoundCatalog.has(str(SoundCatalog.FALLBACKS.get(id, ""))):
				missing.append(id)
	_check(missing.is_empty(), "sounds: every Hunter sound id is a catalog row with a stand-in (%s)" % [missing])

	# Who feels a rumble: a local player yes, a bot or a puppet no.
	WhatStinksRumble.calls.clear()
	fish.controls = null
	fish.puppet = false
	WhatStinksRumble.pulse(fish, 0.5, 0.1)
	fish.puppet = true
	WhatStinksRumble.pulse(fish, 0.5, 0.1)
	fish.puppet = false
	fish.controls = FishInput.new()
	WhatStinksRumble.pulse(fish, 0.5, 0.1)
	fish.controls = null
	var felt: Array = WhatStinksRumble.calls.map(func(call: Dictionary) -> bool: return bool(call["felt"]))
	_check(felt == [true, false, false], "rumble: a local player's fish feels it, a puppet and a bot do not (%s)" % [felt])

	# Prey get the impact: a camera punch, a pulse, a flush (here the pulse; there is no view in the probe).
	WhatStinksRumble.calls.clear()
	var prey_bite := HunterBite.new()
	prey_bite.settings = settings
	fish.add_child(prey_bite)
	prey_bite.setup(fish, form)
	prey_bite.fx().prey_caught([fish], Vector3.ZERO)
	_check(WhatStinksRumble.calls.size() == 1 and float(WhatStinksRumble.calls[0]["strength"]) > 0.0, "prey: a caught player's pad takes a hard pulse")
	var power := settings.prey_impact
	settings.prey_impact = 0.0
	WhatStinksRumble.calls.clear()
	prey_bite.fx().prey_caught([fish], Vector3.ZERO)
	settings.prey_impact = power
	_check(WhatStinksRumble.calls.is_empty(), "prey: prey_impact 0 switches it off")
	prey_bite.release_fish()
	prey_bite.queue_free()
	WhatStinksRumble.reset()
	await _frames(2)
