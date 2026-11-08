extends Node
## What Stinks? Phase 7 bots (what_stinks.md section 9): every fish a bot, the player's too.
## - The prey bot (WhatStinksPreyBot): joins a school in the countdown; a Hunter reading it for
##   prey_bot_patience seconds makes it leave and join another school; patience 0 and Upset
##   Stomach's bait keep it put.
## - The Hunter bot (WhatStinksBot): in Clean Sweep it prefers a prey it can read and ignores a loner
##   it can't; it Clicks when the Click is ready and nothing is readable, sniffs over a school for
##   hunter_bot_sniff_s and no more (and not in Upset Stomach); the Angel's bot won't lock on a
##   stinker (Upset Stomach) and does on a prey it can't read.
##   Godot_console.exe --headless --path . res://tests/what_stinks_bots_probe.tscn

var main: Node
var game: WhatStinksMatch
var settings: WhatStinksSettings
var failures := 0
var checks := 0
var tps := 120


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checks += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _until(done: Callable, ticks: int) -> bool:
	for i in ticks:
		if done.call():
			return true
		await get_tree().physics_frame
	return done.call()


## A match of bots only in the Ocean, round 0 started.
func _begin(form: String, variant: int) -> void:
	if main.what_stinks:
		main.set_mode(main.FREE_SWIM)
		await _frames(3)
	main.set_mode(main.WHAT_STINKS)
	await _frames(3)
	settings = WhatStinksSettings.shared()
	settings.form = form
	settings.variant = variant
	settings.hide_time = 12.0
	settings.round_time = 600.0
	settings.round_over_time = 0.2
	settings.arena_radius = 90.0
	settings.school_count = 5
	settings.school_min = 14
	settings.school_max = 18
	settings.min_players = 5
	settings.rounds = 6
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	settings.lock_bite = false
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	settings.rejoin_cooldown = 1.0
	settings.prey_bot_patience = 1.0
	settings.prey_bot_exposure = 0.45
	settings.hunter_bot_sniff_s = 2.0
	settings.hunter_bot_click = true
	settings.hunter_bot_read_exposure = 0.25
	settings.click_auto = false
	settings.bite_takes_players = true
	settings.satiation_max = 1000.0
	settings.hitstop_ms = 0.0
	HunterSize.shared().size_mult = 1.0
	main.play_match()
	await _frames(5)
	game = main.what_stinks
	game.bots[main.get_node("Fish")] = null
	game.start_round(0)
	await _frames(3)


func _prey_bots() -> Array[WhatStinksPreyBot]:
	var out: Array[WhatStinksPreyBot] = []
	for bot: Variant in game.bots.values():
		if bot is WhatStinksPreyBot:
			out.append(bot)
	return out


func _run() -> void:
	await _frames(5)
	tps = int(Engine.physics_ticks_per_second)
	await _begin("drowned_shark", WhatStinksSettings.Variant.SWEEP)
	check_match()
	var hunter: FishController = game.hunters[0]
	var hbot: WhatStinksBot = game.bots[hunter]
	_check(hbot != null, "the Hunter is a WhatStinksBot")
	_check(_prey_bots().size() == 4, "four prey bots, all WhatStinksPreyBots (%d)" % _prey_bots().size())

	print("prey bots join a school:")
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 16)
	hunter.controls_locked = true  # the Hunter stands still: this part is about the prey
	var joined: Array = []
	var waited := 0
	for i in 40:
		await _frames(tps)
		waited += 1
		joined = _prey_bots().filter(func(b: WhatStinksPreyBot) -> bool: return game.join.is_joined(b.fish))
		if joined.size() >= 3:
			break
	_check(joined.size() >= 3, "at least three of four joined a school (%d, within %d s of the countdown start)" % [joined.size(), 12 + waited])

	print("relocation:")
	var prey_bot: WhatStinksPreyBot = joined[0]
	for candidate: WhatStinksPreyBot in joined:  # one with a choice of schools: the class of the school it may join is its own
		var choices := game.field.schools.filter(func(s: School) -> bool: return game.join.eligible(candidate.fish, s)).size()
		if choices >= 2:
			prey_bot = candidate
			break
	var prey := prey_bot.fish
	var first := game.join.school_of(prey)
	game.echo.forced[prey] = 1.0
	_check(await _until(func() -> bool: return not game.join.is_joined(prey), tps * 6), "a prey a Hunter reads at 1.0 leaves its school after the patience")
	_check(prey_bot.relocations == 1, "it counted one relocation (%d)" % prey_bot.relocations)
	game.echo.forced.erase(prey)
	_check(await _until(func() -> bool: return game.join.is_joined(prey), tps * 40), "and joins a school again")
	var options := 0
	for school: School in game.field.schools:
		options += 1 if game.join.eligible(prey, school) else 0
	_check(game.join.school_of(prey) != first or options < 2, "a different one (%d schools of its class)" % options)

	game.echo.forced[prey] = 1.0
	settings.prey_bot_patience = 0.0
	var stayed := not await _until(func() -> bool: return not game.join.is_joined(prey), tps * 4)
	_check(stayed, "patience 0: it never relocates")
	settings.prey_bot_patience = 1.0
	settings.variant = WhatStinksSettings.Variant.STOMACH
	settings.prey_bot_baits = true
	stayed = not await _until(func() -> bool: return not game.join.is_joined(prey), tps * 4)
	_check(stayed, "Upset Stomach with bait: it stays")
	settings.prey_bot_baits = false
	_check(await _until(func() -> bool: return not game.join.is_joined(prey), tps * 6), "Upset Stomach without bait: it leaves again")
	game.echo.forced.erase(prey)
	settings.variant = WhatStinksSettings.Variant.SWEEP

	print("the Hunter reads loners (Clean Sweep):")
	var bite: HunterBite = game.bites[hunter]
	for school: School in game.field.schools:
		school.set_physics_process(false)
	var far := (game.field.schools[0] as School).middle() + Vector3(0.0, 70.0, 0.0)
	var loner: FishController
	for bot in _prey_bots():
		game.join.leave(bot.fish, false)
		bot.fish.controls = null
		bot.fish.freeze = true
		bot.fish.global_position = far + Vector3(0.0, 0.0, 600.0) * (1 + _prey_bots().find(bot))
		if bot.fish != prey:
			loner = loner if loner else bot.fish
	hunter.freeze = true
	hunter.global_position = far
	hunter.global_basis = Basis.IDENTITY
	await _frames(3)
	var ahead := -hunter.global_basis.z
	loner.global_position = far + ahead * 12.0
	game.echo.forced.clear()
	var seen: Dictionary = hbot._nearest_target(bite.mouth_point())
	_check(not bool(seen["readable"]) and (seen["at"] as Vector3).distance_to(loner.global_position) > 1.0, "a loner it can't read is not a target")
	game.echo.forced[loner] = 0.9
	seen = hbot._nearest_target(bite.mouth_point())
	_check(bool(seen["readable"]) and (seen["at"] as Vector3).distance_to(loner.global_position) < 1.0, "a loner it reads (0.9) is the target, marked readable")
	game.echo.forced[loner] = 0.1
	seen = hbot._nearest_target(bite.mouth_point())
	_check(not bool(seen["readable"]) and (seen["at"] as Vector3).distance_to(loner.global_position) > 1.0, "below hunter_bot_read_exposure it is nothing")
	game.echo.forced[loner] = 0.0
	settings.hunter_bot_read_exposure = 0.0
	seen = hbot._nearest_target(bite.mouth_point())
	_check((seen["at"] as Vector3).distance_to(loner.global_position) < 1.0 and not bool(seen["readable"]), "read exposure 0: every prey is just the nearest fish (the old rule)")
	settings.hunter_bot_read_exposure = 0.25
	game.echo.forced.clear()

	print("click and sniff:")
	for school: School in game.field.schools:
		school.set_physics_process(true)
	for bot in _prey_bots():
		bot.fish.freeze = false
	game.start_round(1)
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 12)
	hunter = game.hunters[0]
	hbot = game.bots[hunter]
	var charges: Array[float] = []
	(game.bites[hunter] as HunterBite).released.connect(func(c: float) -> void: charges.append(c))
	var clicks_before: int = game.echo.clicks.get(hunter, 0)
	_check(await _until(func() -> bool: return int(game.echo.clicks.get(hunter, 0)) > clicks_before, tps * 8), "it Clicks when the Click is ready and nothing is readable")
	var at_click := int(game.echo.clicks.get(hunter, 0))
	await _frames(tps * 7)
	_check(int(game.echo.clicks.get(hunter, 0)) >= at_click + 1, "and again after the cooldown (%d clicks in all)" % int(game.echo.clicks.get(hunter, 0)))
	settings.hunter_bot_click = false
	var frozen := int(game.echo.clicks.get(hunter, 0))
	await _frames(tps * 5)
	_check(int(game.echo.clicks.get(hunter, 0)) <= frozen + 1, "hunter_bot_click off: no more clicks")
	settings.hunter_bot_click = true
	settings.hunter_bot_read_exposure = 1.0  # nothing is readable: the sniff is what it does
	var sniffed := await _until(func() -> bool: return hbot.sniffing and game.echo.is_sniffing(hunter), tps * 120)
	_check(sniffed, "it sniffs over a school (the echo hears the button)")
	await _frames(tps * 40)
	var longest := 0.0
	for school: Variant in hbot.scanned:
		longest = maxf(longest, float(hbot.scanned[school]))
	_check(longest > 0.5 and longest <= settings.hunter_bot_sniff_s + 0.1, "no school is sniffed past hunter_bot_sniff_s (longest %.2f s of %.1f)" % [longest, settings.hunter_bot_sniff_s])
	settings.hunter_bot_sniff_s = 0.0
	await _frames(5)
	_check(not hbot.sniffing, "sniff time 0: it never sniffs")
	_check(charges.size() >= 2 and charges.max() >= settings.hunter_bot_charge, "the bot holds its bite: it let go at a charge of %.2f or more (%d releases: %s)" % [settings.hunter_bot_charge, charges.size(), str(charges.map(func(c: float) -> String: return "%.2f" % c))])

	print("Upset Stomach: no sniffing:")
	await _begin("drowned_shark", WhatStinksSettings.Variant.STOMACH)
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 12)
	hbot = game.bots[game.hunters[0]]
	var sniff_seen := false
	for i in tps * 25:
		await get_tree().physics_frame
		sniff_seen = sniff_seen or hbot.sniffing
	_check(not sniff_seen, "it never sniffs in Upset Stomach")

	print("Angel lock gate (Upset Stomach):")
	await _begin("fallen_angel", WhatStinksSettings.Variant.STOMACH)
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 12)
	hunter = game.hunters[0]
	hbot = game.bots[hunter]
	hunter.controls_locked = true
	bite = game.bites[hunter]
	var lock := bite.attack as LockAttack
	_check(lock != null, "the Angel's style is the lock")
	for school: School in game.field.schools:
		school.set_physics_process(false)
		school.global_position += Vector3(0.0, 400.0, 0.0)
	var victims := game.live_prey()
	for v in victims:
		game.join.leave(v, false)
		v.controls = null
		v.freeze = true
		v.global_position = Vector3(0.0, -500.0, 0.0) + Vector3(50.0 * victims.find(v), 0.0, 0.0)
	var angel_at := (game.field.schools[0] as School).middle() + Vector3(0.0, -800.0, 0.0)
	hunter.freeze = true
	hunter.global_position = angel_at
	hunter.global_basis = Basis.IDENTITY
	await _frames(3)
	var reach := bite.size.bite_reach(hunter, bite.form)
	var target: FishController = victims[0]
	target.global_position = bite.mouth_point() + (-hunter.global_basis.z) * reach * 1.8  # in the gate, out of the frustum
	await _frames(2)
	bite.cooldown = 0.0
	game.echo.forced.clear()
	hbot.stinker_blocks = hbot._stinker_in_bite(bite)
	hbot.target_ahead = 1.0
	var plan := lock.bot_plan(hbot, bite)
	_check(bool(plan["press"]), "a prey it can't read in the gate: it opens (%s)" % str(plan))
	game.echo.forced[target] = 1.0
	hbot.stinker_blocks = hbot._stinker_in_bite(bite)
	_check(not hbot.stinker_blocks, "(the prey is outside the frustum, so the old gate would not have stopped it)")
	plan = lock.bot_plan(hbot, bite)
	_check(not bool(plan["press"]), "a stinker it can read: it won't lock on it")
	game.echo.forced.erase(target)

	print("what_stinks_bots_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check_match() -> void:
	_check(game != null and game.players.size() == 5, "a match of five fish")
