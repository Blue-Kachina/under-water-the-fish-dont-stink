## Two-stage attacks, phase 2 (two-stage-attack.md 4b, section 7 engulf and net): the whales' mouth.
## The Titan jaw on a Hunter's model (every species: it opens past 70 degrees, the belly patch swaps in, the sperm
## whale's rod swings, the throat swells with `fullness`) while Marco Polo's whales get none and stay shut. Then
## a real match with the Humpback: a press opens the mouth and fish that swim into it are held (School.hold) and
## eaten on the release in one bite; a full mouth stays open and takes no more (and strains); a prey player in the
## mouth is locked and eaten on the release (Clean Sweep), spat out and unlocked (Upset Stomach); the host runs
## a guest Hunter's engulf on its puppet and judges the guest's release from the held list (and lets go of it if
## the guest never reports). The bot's plan for the style. `-- --species-only` skips the match.
##   Godot_console.exe --headless --path . res://tests/whale_engulf_probe.tscn
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
	_models()
	if not OS.get_cmdline_user_args().has("--species-only"):
		await _bot_plan()
		await _in_match()
	print("whale_engulf_probe: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# --- The jaw on each species ---------------------------------------------------------------

func _models() -> void:
	var settings := WhatStinksSettings.shared()
	var titan := FishCharacter.FishClass.TITAN
	for species in 5:
		var key: String = load(FishModel.TITAN_MODEL).SPECIES_KEYS[species]
		# Marco Polo's whale: no jaw, nothing cut, the mouth is the painted line.
		var plain := FishModel.build(titan, species, 0)
		add_child(plain)
		var plain_skin: ShaderMaterial = plain._skins[0]
		_check(not plain.has_meta("hunter_jaw") and plain.find_child("WhaleJawSkin0", true, false) == null and _f(plain_skin, "jaw_cut") == 0.0 and _f(plain_skin, "throat_swell") == 0.0,
				"%s: a Marco Polo whale has no jaw and an untouched skin" % key)
		plain.queue_free()
		# A Hunter's.
		var model := FishModel.build(titan, species, 0)
		add_child(model)
		var jaw := WhaleJaw.new()
		jaw.build(model, Color.WHITE)
		model.set_meta("hunter_jaw", jaw)
		var skin: ShaderMaterial = jaw.info.skin if not bool(jaw.info.sperm) else null
		_check(is_equal_approx(jaw.angle(), 0.0), "%s: the jaw is shut to begin with" % key)
		if skin != null:
			_check(_f(skin, "jaw_cut") == 0.0, "%s: shut, the body's skin is whole" % key)
			for patch: MeshInstance3D in jaw.info.patches:
				_check(not patch.visible, "%s: shut, the jaw's skin copy is hidden" % patch.name)
		_check(not (jaw.info.jaw as Node3D).visible and not (jaw.info.head as Node3D).visible, "%s: shut, the inside is hidden" % key)
		jaw.pose(1.0)
		_check(jaw.angle() < -deg_to_rad(settings.whale_gape_deg) * 0.99, "%s: wide open it drops to the gape (%.0f deg)" % [key, rad_to_deg(-jaw.angle())])
		_check((jaw.info.jaw as Node3D).visible and (jaw.info.head as Node3D).visible and is_equal_approx((jaw.info.jaw as Node3D).rotation.x, jaw.angle()), "%s: open, the inside shows and the jaw's inside swings with it" % key)
		_check(is_equal_approx((jaw.info.jaw as Node3D).scale.z, settings.whale_smear), "%s: and stretches %.2fx" % [key, settings.whale_smear])
		var jaw_skin: ShaderMaterial = jaw.info.jaw_skin
		_check(jaw_skin != null and is_equal_approx(_f(jaw_skin, "jaw_angle"), jaw.angle()), "%s: the skin's shader hinge follows (%.2f rad)" % [key, jaw.angle()])
		if skin != null:
			_check(_f(skin, "jaw_cut") == 1.0, "%s: open, the belly is cut out of the body" % key)
			for patch: MeshInstance3D in jaw.info.patches:
				_check(patch.visible, "%s: open, the jaw's skin copy shows" % patch.name)
		jaw.fullness = 1.0
		jaw.pose(1.0)
		if skin != null:
			_check(_f(skin, "throat_swell") > 0.0, "%s: a full mouth swells the throat (%.2f m)" % [key, _f(skin, "throat_swell")])
		jaw.set_overshoot(0.28)
		jaw.pose(1.0)
		_check(jaw.angle() < -deg_to_rad(settings.whale_gape_deg) * 1.2, "%s: the fling swings it past wide (%.0f deg)" % [key, rad_to_deg(-jaw.angle())])
		jaw.set_overshoot(0.0)
		jaw.fullness = 0.0
		jaw.pose(0.0)
		_check(is_equal_approx(jaw.angle(), 0.0) and not (jaw.info.jaw as Node3D).visible, "%s: shut again" % key)
		_check(jaw.mouth_local().z < -model._size.z * 0.3, "%s: the mouth is at the nose (z %.2f)" % [key, jaw.mouth_local().z])
		model.queue_free()
	await _frames(2)


# --- The bot -----------------------------------------------------------------------------

func _bot_plan() -> void:
	var settings := WhatStinksSettings.shared()
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	var form := HunterForms.sheet("humpback")
	HunterSize.shared().size_mult = 1.0
	fish.set_look(form["class"], int(form["species"]), 0)
	HunterSize.shared().apply(fish, form)
	HunterForms.dress(fish, "humpback")
	var bite := HunterBite.new()
	bite.settings = settings
	fish.add_child(bite)
	bite.setup(fish, form)
	_check(bite.attack.key == "engulf" and bite.attack is EngulfAttack, "bot: the Humpback's style is the engulf")
	var attack := bite.attack as EngulfAttack
	var bot := WhatStinksBot.new()
	var reach := bite.reach()
	bot.target_ahead = 0.9
	bot.target_gap = reach * (settings.hunter_bot_open_gap + 1.0)
	_check(not bool(attack.bot_plan(bot, bite)["press"]), "bot: a fish far off is not worth opening for")
	bot.target_gap = reach * settings.hunter_bot_open_gap * 0.9
	_check(bool(attack.bot_plan(bot, bite)["press"]), "bot: a school in range gets a press")
	bot.stinker_blocks = true
	_check(not bool(attack.bot_plan(bot, bite)["press"]), "bot: not with a stinker about (Upset Stomach)")
	bot.stinker_blocks = false
	bite.cooldown = 0.0
	bite.try_open()
	_check(bite.holding(), "bot: (the probe opened the mouth)")
	bot.target_gap = reach * 0.5
	_check(bool(attack.bot_plan(bot, bite)["hold"]), "bot: an empty mouth with a school near: keep it open")
	for i in attack.max_held(bite):
		attack.held.append({"index": i})
	_check(not bool(attack.bot_plan(bot, bite)["hold"]), "bot: a full mouth: shut it")
	attack.held.clear()
	attack.held.append({"index": 0})
	attack._idle = 0.2
	_check(bool(attack.bot_plan(bot, bite)["hold"]), "bot: a fish just went in: keep it open for more")
	attack._idle = 1.5
	_check(not bool(attack.bot_plan(bot, bite)["hold"]), "bot: nothing has gone in for a while: shut it")
	attack.held.clear()
	attack._idle = 0.0
	bot.target_ahead = -0.5
	_check(not bool(attack.bot_plan(bot, bite)["hold"]), "bot: the school is behind it and the mouth is empty: shut it")
	bite.abort()
	bot.free()
	bite.release_fish()
	bite.queue_free()
	await _frames(2)


# --- A match ----------------------------------------------------------------------------

func _in_match() -> void:
	fish.puppet = false
	fish.freeze = false
	var settings := WhatStinksSettings.shared()
	settings.form = "humpback"
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
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	settings.engulf_max_mult = 2.0
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
	var attack := bite.attack as EngulfAttack
	var jaw := bite._jaw as WhaleJaw
	_check(attack != null and jaw != null and str(bite.form["key"]) == "humpback" and bite.world == game, "match: the Hunter wears the Humpback: the engulf style, a WhaleJaw, and the bite knows the match")
	if attack == null or jaw == null:
		return
	var input := FishInput.new()
	fish.controls = input
	var closes: Array = []
	var bitten: Array = []
	game.bitten.connect(func(_h: FishController, school_fish: int, prey: Array) -> void: bitten.append([school_fish, prey.size()]))
	game.bite_closed.connect(func(_h: FishController, charge: float) -> void: closes.append(charge))
	var school: School = game.field.schools[0]

	print("      A: school fish")
	await _aim_at(game, bite, school.middle())
	var cap := attack.max_held(bite)
	_check(cap == 12, "engulf: the Humpback's mouth holds up to %d (capacity 6 x engulf_max_mult 2)" % cap)
	input.jump = true
	await _until(func() -> bool: return bite.holding() and bite.bite.open > 0.95, tps)
	_check(bite.holding() and jaw.angle() < -deg_to_rad(settings.whale_gape_deg) * 0.9, "engulf: the press opens the jaw (%.0f deg)" % rad_to_deg(-jaw.angle()))
	await _until(func() -> bool: return attack.held.size() >= 4, tps * 4)
	var held_n := attack.held.size()
	_check(held_n >= 4 and held_n <= cap, "engulf: fish that swim into the mouth are held (%d)" % held_n)
	_check(school.held_count() > 0 and school.held_count() == held_n, "engulf: the school holds the same fish (%d)" % school.held_count())
	var mouth := bite.mouth_point()
	var near := 0
	for index: int in school.held_indices():
		if school.fish_position(index).distance_to(mouth) <= float(attack._box["len"]) + 1.0:
			near += 1
	_check(near == held_n, "engulf: they ride in the mouth (%d of %d within the box)" % [near, held_n])
	await _frames(tps / 2)
	_check(float((jaw.info.skin as ShaderMaterial).get_shader_parameter("throat_swell")) > 0.0 and attack.fullness > 0.0, "engulf: the throat swells with them (%.2f)" % attack.fullness)
	_check(bite.fx() != null and attack.ring_count(bite) == attack.held.size(), "engulf: the HUD's ring counts what is held (%d)" % attack.ring_count(bite))
	held_n = attack.held.size()
	var alive_before := school.alive_count()
	_check(alive_before == 30, "engulf: held fish are still alive until it shuts (%d of 30)" % alive_before)
	var strays := bitten.size()
	input.jump = false
	await _until(func() -> bool: return bitten.size() > strays, tps * 2)
	_check(bitten.size() == strays + 1 and int(bitten[-1][0]) >= held_n and int(bitten[-1][0]) <= cap and int(bitten[-1][1]) == 0, "engulf: the release eats everything held in one bite (held %d, ate %s)" % [held_n, bitten[-1] if not bitten.is_empty() else "nothing"])
	_check(school.alive_count() == alive_before - int(bitten[-1][0]), "engulf: those fish are gone from the school (%d left)" % school.alive_count())
	_check(school.held_count() == 0 and attack.held.is_empty(), "engulf: nothing is held after it shut")
	await _frames(tps)
	_check(attack.fullness < 0.05, "engulf: the pleats squeeze back down (%.2f)" % attack.fullness)
	await _until(func() -> bool: return not bite.busy(), tps * 3)

	print("      B: a full mouth")
	settings.engulf_max_mult = 0.5
	var small := attack.max_held(bite)
	school = game.field.schools[1]
	await _aim_at(game, bite, school.middle())
	bite.cooldown = 0.0
	input.jump = true
	var filled := await _until(func() -> bool: return attack.held.size() >= small, tps * 5)
	_check(filled and small == 3, "full: the mouth fills to its limit (%d)" % attack.held.size())
	var strained := false
	for i in tps * 2:
		await get_tree().physics_frame
		strained = strained or bite.fx().straining()
	_check(bite.holding() and attack.held.size() == small, "full: it stays open but takes no more (%d held)" % attack.held.size())
	_check(strained, "full: the strain cue plays while it is full")
	strays = bitten.size()
	input.jump = false
	await _until(func() -> bool: return bitten.size() > strays, tps * 2)
	_check(bitten.size() == strays + 1 and int(bitten[-1][0]) == small, "full: the release ate exactly what it held (%s)" % [bitten[-1] if not bitten.is_empty() else "nothing"])
	settings.engulf_max_mult = 2.0
	await _until(func() -> bool: return not bite.busy(), tps * 3)

	print("      C: prey players")
	var prey: Array[FishController] = []
	for other in game.players:
		if other != fish and game.is_live_prey(other):
			prey.append(other)
	_check(prey.size() >= 2, "prey: the match has prey to test with (%d)" % prey.size())
	if prey.size() >= 2:
		for p in prey:
			for s: School in game.field.schools:
				s.release_claim(p)
			p.controls = null
		school = game.field.schools[2]
		await _aim_at(game, bite, school.middle() + Vector3(0.0, 60.0, 0.0))  # away from any school: only the players are near
		bite.cooldown = 0.0
		var victim := prey[0]
		input.jump = true
		await _until(func() -> bool: return bite.holding() and bite.bite.open > 0.95, tps)
		victim.global_position = bite.mouth_point() + (-fish.global_basis.z) * float(attack._box["len"]) * 0.4
		victim.linear_velocity = Vector3.ZERO
		await _until(func() -> bool: return attack._holds_prey(victim), tps)
		_check(attack._holds_prey(victim) and victim.controls_locked and victim.freeze, "prey: a player that swims into the mouth is held and locked")
		await _frames(tps)
		_check(victim.global_position.distance_to(bite.mouth_point()) <= float(attack._box["len"]) + 1.0, "prey: and carried with it (%.1f m from the mouth)" % victim.global_position.distance_to(bite.mouth_point()))
		var kills := game.eaten.size()
		input.jump = false
		await _until(func() -> bool: return game.eaten.has(victim), tps * 2)
		_check(game.eaten.has(victim) and game.eaten.size() == kills + 1, "prey: eaten on the release (Clean Sweep)")
		await _until(func() -> bool: return not bite.busy(), tps * 3)
		# Upset Stomach: spat out, unlocked.
		var spat := []
		game.spat.connect(func(p: FishController, _h: FishController) -> void: spat.append(p))
		var second := prey[1]
		bite.cooldown = 0.0
		input.jump = true
		await _until(func() -> bool: return bite.holding() and bite.bite.open > 0.95, tps)
		second.global_position = bite.mouth_point() + (-fish.global_basis.z) * float(attack._box["len"]) * 0.4
		second.linear_velocity = Vector3.ZERO
		await _until(func() -> bool: return attack._holds_prey(second), tps)
		_check(attack._holds_prey(second) and second.controls_locked, "stomach: a second player is held")
		settings.variant = WhatStinksSettings.Variant.STOMACH
		input.jump = false
		await _until(func() -> bool: return spat.has(second), tps * 2)
		_check(spat.has(second) and not game.eaten.has(second), "stomach: it is spat out, not eaten")
		await _frames(5)
		_check(not second.controls_locked and not second.freeze, "stomach: and free again")
		settings.variant = WhatStinksSettings.Variant.SWEEP
		await _until(func() -> bool: return not bite.busy(), tps * 3)

	print("      E: other sizes")
	for mult: float in [0.5, 2.0]:
		fish.set_meta("size_mult", mult)
		HunterSize.shared().apply(fish, bite.form)
		await _frames(3)
		school = _fullest(game)
		await _aim_at(game, bite, school.middle())
		bite.cooldown = 0.0
		var cap_s := attack.max_held(bite)
		input.jump = true
		await _until(func() -> bool: return bite.holding() and bite.bite.open > 0.95, tps)
		await _until(func() -> bool: return attack.held.size() >= mini(3, cap_s), tps * 4)
		var held_s := attack.held.size()
		var near_s := 0
		for index: int in school.held_indices():
			if school.fish_position(index).distance_to(bite.mouth_point()) <= float(attack._box["len"]) + 1.0:
				near_s += 1
		_check(held_s >= 1 and held_s <= cap_s and near_s == held_s, "size %.1f: fish are held and ride in the mouth (%d of cap %d, %d near)" % [mult, held_s, cap_s, near_s])
		strays = bitten.size()
		input.jump = false
		await _until(func() -> bool: return bitten.size() > strays, tps * 2)
		_check(bitten.size() == strays + 1 and int(bitten[-1][0]) >= held_s and int(bitten[-1][0]) <= cap_s, "size %.1f: the release eats them (held %d, ate %s)" % [mult, held_s, bitten[-1] if not bitten.is_empty() else "nothing"])
		_check(school.held_count() == 0 and attack.held.is_empty(), "size %.1f: nothing held after" % mult)
		await _until(func() -> bool: return not bite.busy(), tps * 3)
	fish.set_meta("size_mult", 1.0)
	HunterSize.shared().apply(fish, bite.form)

	print("      D: a guest's Hunter (the host runs its engulf)")
	school = _fullest(game)
	await _aim_at(game, bite, school.middle())
	bite.cooldown = 0.0
	fish.controls = null
	fish.make_puppet()
	_check(fish.puppet, "net: the Hunter is a puppet here, as a guest's is on the host")
	bite.net_open()
	await _until(func() -> bool: return attack.held.size() >= 3, tps * 4)
	var puppet_held := attack.held.size()
	_check(puppet_held >= 3 and school.held_count() == puppet_held, "net: the host holds fish for the guest's open mouth (%d)" % puppet_held)
	await _frames(tps / 4)
	bite.net_close(0.5)
	await _until(func() -> bool: return not bite.busy(), tps * 2)
	_check(attack.held.size() >= puppet_held, "net: the puppet's shutting does not let go (the guest's report is on its way)")
	strays = bitten.size()
	game.judge_net_bite(fish, bite.mouth_point(), -fish.global_basis.z, 0.5, {})
	_check(bitten.size() == strays + 1 and int(bitten[-1][0]) >= puppet_held, "net: judge_net_bite eats what the host held (held %d, ate %s)" % [puppet_held, bitten[-1] if not bitten.is_empty() else "nothing"])
	_check(school.held_count() == 0 and attack.held.is_empty(), "net: nothing held after the judgment")
	# A guest that never reports: let go after a while.
	await _aim_at(game, bite, school.middle())
	bite.cooldown = 0.0
	bite.net_open()
	await _until(func() -> bool: return attack.held.size() >= 2, tps * 4)
	var unreported := attack.held.size()
	bite.net_close(0.3)
	await _frames(tps * 2)
	_check(unreported >= 2 and attack.held.is_empty() and school.held_count() == 0, "net: an unreported bite lets go of its fish after %.1f s (held %d)" % [EngulfAttack.PUPPET_EXPIRE, unreported])
	fish.puppet = false
	fish.freeze = false
	bite.release_fish()


func _f(m: ShaderMaterial, name: String) -> float:
	var v: Variant = m.get_shader_parameter(name)
	return 0.0 if v == null else float(v)


## Puts the Hunter facing -Z with its mouth at `point` (the world's origin of what it is aimed at).
func _aim_at(game: WhatStinksMatch, bite: HunterBite, point: Vector3) -> void:
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	fish.controls_locked = false
	fish.global_transform = Transform3D(Basis.IDENTITY, point)
	fish.global_position += point - bite.mouth_point() + Vector3(0.0, 0.0, float(bite.size.bite_reach(fish, bite.form)) * 0.3)
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	await _frames(3)


## The school with the most fish left (the earlier sections thin the others out and scare them).
func _fullest(game: WhatStinksMatch) -> School:
	var best: School = game.field.schools[0]
	for other: School in game.field.schools:
		if other.alive_count() > best.alive_count():
			best = other
	return best
