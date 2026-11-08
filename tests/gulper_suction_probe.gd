## Two-stage attacks, phase 4 (two-stage-attack.md 4d): the Gulper Mother's suction. School.pull (a force on the boids
## that lapses when its mouth stops calling, Nature never sets it), then a real match with the Gulper: the press
## balloons the pouch and school fish in the cone are drawn toward the mouth (the strength and reach grow with the
## charge), prey players are shoved toward it (a player behind is not), the release snaps shut on what is within
## gulper_mouth_r of the mouth, the belly fills and a lump slides down it, the pull stops, tap mode stays the
## frustum snap, a guest's release is judged from the mouth it reports, and the bot's plan for the style.
##   Godot_console.exe --headless --path . res://tests/gulper_suction_probe.tscn
extends Node

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


func _until(done: Callable, ticks: int) -> bool:
	for i in ticks:
		if done.call():
			return true
		await get_tree().physics_frame
	return done.call()


func _run() -> void:
	await _frames(5)
	tps = int(Engine.physics_ticks_per_second)
	await _in_match()
	print("gulper_suction_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## How many of a school's live fish are within `r` of `point`.
func _near(school: School, point: Vector3, r: float) -> int:
	var n := 0
	for i in school.fish_count():
		if school.is_alive(i) and school.fish_position(i).distance_to(point) <= r:
			n += 1
	return n


func _in_match() -> void:
	fish.puppet = false
	fish.freeze = false
	var settings := WhatStinksSettings.shared()
	settings.form = "gulper_mother"
	settings.hide_time = 1.0
	settings.round_time = 300.0
	settings.arena_radius = 90.0
	settings.school_count = 4
	settings.school_min = 30
	settings.school_max = 30
	settings.min_players = 5
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	settings.variant = WhatStinksSettings.Variant.SWEEP
	settings.lock_bite = false
	settings.hold_cooldown_per_s = 0.0
	settings.hold_speed_mult = 1.0
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	settings.satiation_max = 1000.0
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
	var bite: HunterBite = game.bites[fish]
	var attack := bite.attack as SuctionAttack
	_check(attack != null and attack.key == "suction" and str(bite.form["key"]) == "gulper_mother", "style: the Gulper's attack is the suction")
	if attack == null:
		return
	var rig: Node3D = bite._model.get_meta("gulper_rig") if bite._model.has_meta("gulper_rig") else null
	_check(rig != null and rig.get("skin") != null, "style: the Gulper's rig wears the boss skin")
	if rig == null:
		return
	var skin: ShaderMaterial = rig.get("skin")
	var input := FishInput.new()
	fish.controls = input
	var bitten: Array = []
	game.bitten.connect(func(_h: FishController, school_fish: int, prey: Array) -> void: bitten.append([school_fish, prey.size()]))

	print("      A: the numbers")
	_check(attack.pull_reach(bite, 1.0) > attack.pull_reach(bite, 0.0) and attack.pull_reach(bite, 1.0) > bite.reach() * 1.5, "numbers: the suction reaches %.1f m at full charge (bite %.1f), %.1f m at none" % [attack.pull_reach(bite, 1.0), bite.reach(), attack.pull_reach(bite, 0.0)])
	_check(attack.pull_speed(bite, 1.0) > attack.pull_speed(bite, 0.0) and is_equal_approx(attack.pull_speed(bite, 1.0), settings.suck_strength), "numbers: and pulls harder with the charge (%.1f to %.1f m/s)" % [attack.pull_speed(bite, 0.0), attack.pull_speed(bite, 1.0)])
	_check(attack.mouth_radius(bite) < bite.radius() and attack.mouth_radius(bite) > 0.0, "numbers: the snap's sphere is smaller than the bite's radius (%.1f m)" % attack.mouth_radius(bite))
	var rule := attack.catch_rule(bite)
	_check(not bool(rule["frustum"]) and (rule["inside"] as Callable).call(bite.mouth_point()) and not (rule["inside"] as Callable).call(bite.mouth_point() + Vector3(0.0, 0.0, attack.mouth_radius(bite) * 1.5)), "numbers: held, the catch is a sphere round the mouth")
	var net_mouth := Vector3(10.0, 20.0, 30.0)
	var net_rule := attack.net_catch_rule(bite, net_mouth, Vector3.FORWARD, 0.5, {})
	_check((net_rule["inside"] as Callable).call(net_mouth + Vector3(0.0, attack.mouth_radius(bite) * 0.5, 0.0)) and not (net_rule["inside"] as Callable).call(net_mouth + Vector3(0.0, attack.mouth_radius(bite) * 2.0, 0.0)), "net: a guest's release is judged round the mouth it reports")
	settings.bite_mode = WhatStinksSettings.BiteMode.TAP
	_check(bool(attack.catch_rule(bite)["frustum"]) and bool(attack.net_catch_rule(bite, net_mouth, Vector3.FORWARD, 0.0, {})["frustum"]), "tap: the snap is the plain frustum")
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD

	print("      B: school fish")
	var school: School = game.field.schools[0]
	var control: School = game.field.schools[3]
	var swim: float = school.settings.school_speed
	school.settings.school_speed = 0.0  # a school that stays put, so the pull is the only thing moving it
	await _aim_at(game, bite, school.middle())
	var mouth := bite.mouth_point()
	var before := _near(school, mouth, attack.mouth_radius(bite))
	_check(not school.is_pulled(), "pull: nothing is pulling before the press")
	input.jump = true
	await _until(func() -> bool: return bite.holding() and bite.bite.open > 0.95, tps)
	await _frames(3)
	_check(bite.holding() and school.is_pulled(), "pull: the press opens the pouch and the school feels the suction")
	_check(not control.is_pulled(), "pull: a school out of reach does not")
	await _frames(tps * 2)
	mouth = bite.mouth_point()
	var after := _near(school, mouth, attack.mouth_radius(bite))
	_check(after > before + 3, "pull: the school is drawn to the mouth (%d fish within the snap's reach, from %d)" % [after, before])
	_check(attack.in_mouth > 0 and attack.fullness > 0.0, "pull: fish crowd the mouth (%d) and the belly fills (%.2f)" % [attack.in_mouth, attack.fullness])
	_check(bite.charge() > 0.3, "pull: the charge is building (%.2f)" % bite.charge())
	await _until(func() -> bool: return attack.in_mouth >= 3, tps * 3)
	var crowd := attack.in_mouth
	_check(attack.ring_count(bite) == mini(crowd, bite.capacity()), "pull: the HUD's ring counts the crowd (%d)" % attack.ring_count(bite))
	_check(float(skin.get_shader_parameter("fullness")) > 0.31, "pull: the shader's belly is fuller than at rest (%.2f)" % float(skin.get_shader_parameter("fullness")))
	var alive_before := school.alive_count()
	var strays := bitten.size()
	input.jump = false
	await _until(func() -> bool: return bitten.size() > strays, tps * 2)
	var ate: int = int(bitten[-1][0]) if bitten.size() > strays else -1
	_check(ate >= 1 and ate <= bite.capacity(), "snap: the release ate what was at the mouth (%d of capacity %d, crowd was %d)" % [ate, bite.capacity(), crowd])
	await _frames(3)  # the school hears of the eaten fish a tick after the bite lands
	_check(school.alive_count() <= alive_before - ate, "snap: they are gone from the school (%d left)" % school.alive_count())
	await _frames(tps / 2)
	_check(not school.is_pulled(), "snap: the suction stops")
	_check(attack.lump_left() > 0.0, "snap: the belly shows a lump (%.1f s left)" % attack.lump_left())
	var lump: Vector3 = skin.get_shader_parameter("lump")
	var span: Vector2 = skin.get_shader_parameter("belly_span")
	_check(lump.z > 0.0 and lump.x >= span.x and lump.x <= span.y, "snap: the shader's lump is on the belly (at %.1f m, press %.2f)" % [lump.x, lump.z])
	await _frames(tps * 2)
	var later: Vector3 = skin.get_shader_parameter("lump")
	_check(later.x > lump.x, "snap: and slides down it (%.1f to %.1f)" % [lump.x, later.x])
	await _frames(int(tps * settings.suck_lump_s))
	_check(attack.lump_left() == 0.0 and (skin.get_shader_parameter("lump") as Vector3).z == 0.0 and attack.fullness < 0.05, "snap: it passes and the belly empties (full %.2f)" % attack.fullness)
	await _until(func() -> bool: return not bite.busy(), tps * 3)

	school.settings.school_speed = swim
	print("      C: a called-off bite")
	await _aim_at(game, bite, school.middle())
	bite.cooldown = 0.0
	input.jump = true
	await _until(func() -> bool: return bite.holding() and bite.bite.open > 0.95, tps)
	await _frames(10)
	_check(school.is_pulled(), "lapse: pulling while held")
	bite.abort()
	input.jump = false
	await _frames(tps / 4)
	_check(not school.is_pulled(), "lapse: a called-off bite stops pulling")
	await _until(func() -> bool: return not bite.busy(), tps * 3)

	print("      D: prey players")
	var prey: Array[FishController] = []
	for other in game.players:
		if other != fish and game.is_live_prey(other):
			prey.append(other)
	_check(prey.size() >= 2, "prey: the match has prey to test with (%d)" % prey.size())
	if prey.size() >= 2:
		game.settings.bots_join = false  # the prey bots (WhatStinksPreyBot) would otherwise rejoin a school and be frozen in it
		for p in prey:
			var prey_bot: Variant = game.bots.get(p)
			if prey_bot != null and is_instance_valid(prey_bot):
				(prey_bot as Node).set_physics_process(false)
			game.join.leave(p, false)  # a prey bot may have joined a school by now: this unfreezes it
			for s: School in game.field.schools:
				s.release_claim(p)
			p.controls = null
		var away: School = game.field.schools[2]
		await _aim_at(game, bite, away.middle() + Vector3(0.0, 80.0, 0.0))  # away from any school
		bite.cooldown = 0.0
		var ahead := prey[0]
		var behind := prey[1]
		var forward := -fish.global_basis.z
		input.jump = true
		await _until(func() -> bool: return bite.holding() and bite.bite.open > 0.95 and bite.charge() > 0.99, tps * 6)  # the reach grows with the charge: wait for all of it
		mouth = bite.mouth_point()
		var reach := attack.pull_reach(bite, 1.0)
		ahead.global_position = mouth + forward * reach * 0.6
		behind.global_position = mouth + fish.global_basis.x * reach * 0.5  # beside, out of the cone (behind is inside the Gulper's own body)
		ahead.linear_velocity = Vector3.ZERO
		behind.linear_velocity = Vector3.ZERO
		await _frames(tps / 4)
		mouth = bite.mouth_point()
		# Judged by the prey own velocity toward the mouth (the Gulper drifts, so the gap alone proves nothing).
		var ahead_in := ahead.linear_velocity.dot((mouth - ahead.global_position).normalized())
		var behind_in := behind.linear_velocity.dot((mouth - behind.global_position).normalized())
		_check(ahead_in > 0.5, "prey: a player in the cone is shoved toward the mouth (%.2f m/s in)" % ahead_in)
		_check(behind_in < 1.5, "prey: a player beside the mouth is not (%.2f m/s; the Gulper drifts and can bump it)" % behind_in)
		_check(not ahead.controls_locked and not ahead.freeze, "prey: the player's controls stay free (they can swim against it)")
		# A player at the lips when it shuts is eaten.
		ahead.global_position = bite.mouth_point()
		ahead.linear_velocity = Vector3.ZERO
		var kills := game.eaten.size()
		input.jump = false
		await _until(func() -> bool: return game.eaten.has(ahead), tps * 2)
		_check(game.eaten.has(ahead) and game.eaten.size() >= kills + 1, "prey: a player at the mouth is eaten on the release")
		_check(not game.eaten.has(behind), "prey: the one behind is not")
		await _until(func() -> bool: return not bite.busy(), tps * 3)

	print("      E: the bot")
	var bot := WhatStinksBot.new()
	bite.cooldown = 0.0
	bot.target_ahead = 0.9
	bot.target_gap = attack.pull_reach(bite, 1.0) * (settings.hunter_bot_open_gap + 1.0)
	_check(not bool(attack.bot_plan(bot, bite)["press"]), "bot: a school far off is not worth opening for")
	bot.target_gap = attack.pull_reach(bite, 1.0) * settings.hunter_bot_open_gap * 0.9
	_check(bool(attack.bot_plan(bot, bite)["press"]), "bot: a school in the suction's range gets a press")
	bot.stinker_blocks = true
	_check(not bool(attack.bot_plan(bot, bite)["press"]), "bot: not with a stinker about")
	bot.stinker_blocks = false
	bite.try_open()
	_check(bite.holding(), "bot: (the probe opened the mouth)")
	attack.in_mouth = 0
	bot.target_gap = bite.reach()
	_check(bool(attack.bot_plan(bot, bite)["hold"]), "bot: an empty mouth with a school near: keep sucking")
	attack.in_mouth = bite.capacity()
	_check(not bool(attack.bot_plan(bot, bite)["hold"]), "bot: a crowded mouth: snap shut")
	attack.in_mouth = 2
	attack.idle = 1.0
	_check(not bool(attack.bot_plan(bot, bite)["hold"]), "bot: the crowd stopped growing: snap shut")
	attack.idle = 0.0
	bot.stinker_blocks = true
	attack.in_mouth = bite.capacity()
	_check(bool(attack.bot_plan(bot, bite)["hold"]), "bot: a stinker in the mouth holds the release back")
	bot.stinker_blocks = false
	bite.abort()
	await _frames(5)
	bot.free()


func _aim_at(game: WhatStinksMatch, bite: HunterBite, point: Vector3) -> void:
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	fish.controls_locked = false
	fish.global_transform = Transform3D(Basis.IDENTITY, point)
	fish.global_position += point - bite.mouth_point() + Vector3(0.0, 0.0, float(bite.size.bite_reach(fish, bite.form)) * 0.8)
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	await _frames(3)
