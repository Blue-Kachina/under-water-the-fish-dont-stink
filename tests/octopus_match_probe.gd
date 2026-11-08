extends Node
## The Ember Octopus integrated as a playable Hunter (planning_new_hunters.md INT2): registered and ready, its settings and docs and
## sounds in the shared tables, then played in a real What Stinks? match.
##   1. Registry: the form is on the card, its sheet says "whip", the style table builds a WhipAttack, every OctopusRig and WhipAttack
##      default is a registered panel setting with a doc line, every sound id the form and attack use is in the catalog.
##   2. Player match: the Hunter wears the OctopusRig and OctopusModel at its hitbox length, the lash is wired to the rig (the rig
##      poses the lash's arms), it jets under throttle (real thrust: speed rises, jets counted), a held press locks arms on a school,
##      the release lashes (arms hit, fish eaten, recoil push), the arms settle back onto the gait, and the HUD's ring count shows
##      the locks while held.
##   3. Bot match: a bot Hunter in the octopus form hunts (presses, locks, lashes, eats) with no script error.
##   4. Net: a puppet's bite opened by the host's message runs the same lash visuals without judging.
##   Godot_console.exe --headless --path . res://tests/octopus_match_probe.tscn

const KEY := "ember_octopus"

var main: Node
var game: WhatStinksMatch
var fish: FishController
var checks := 0
var failures := 0
var tps := 120


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
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
	await _frames(5)
	tps = int(Engine.physics_ticks_per_second)
	_registry()
	await _player_match()
	await _bot_match()
	await _net()
	print("octopus_match_probe: %s (%d checks)" % ["all checks passed" if failures == 0 else "%d FAILED" % failures, checks])
	get_tree().quit(1 if failures else 0)


# --- 1. Registry -----------------------------------------------------------------------------

func _registry() -> void:
	print("registry:")
	_check(HunterForms.has(KEY) and HunterForms.KEYS.has(KEY), "the form is registered and in card order")
	_check(HunterForms.is_ready(KEY) and HunterForms.ready_keys().has(KEY), "it is ready and the card lists it")
	_check(HunterForms.playable(KEY) == KEY, "it plays as itself, not the fallback")
	var sheet := HunterForms.sheet(KEY)
	_check(str(sheet["name"]) == "Ember Octopus" and str(sheet["attack"]) == "whip", "its sheet names the Ember Octopus and the whip style")
	var attack := HunterAttack.make("whip")
	_check(attack != null and attack.key == "whip" and attack is WhipAttack, "the style table builds a WhipAttack")
	_check(HunterBiteFx.SOUNDS.has("whip"), "the bite fx has a sound row for the whip style")
	var settings := WhatStinksSettings.shared()
	var missing: Array[String] = []
	var undocumented: Array[String] = []
	var ids: Array = []
	ids.append_array(OctopusRig.DEFAULTS.keys())
	ids.append_array(WhipAttack.DEFAULTS.keys())
	for id: String in ids:
		if settings.get(id) == null:
			missing.append(id)
		if not SettingDocs.DOCS.has("what_stinks/" + id):
			undocumented.append(id)
	_check(missing.is_empty(), "every rig and attack tuning value is a panel setting (missing: %s)" % [missing])
	_check(undocumented.is_empty(), "and each has a doc line (missing: %s)" % [undocumented])
	var bad_sounds: Array[String] = []
	for id: String in ["octopus/flare", "octopus/charge", "octopus/lock", "octopus/lock_lost", "octopus/lash", "octopus/crack", "octopus/hit", "octopus/miss", "octopus/jet", "octopus/foot"]:
		if not SoundCatalog.events().has(id):
			bad_sounds.append(id)
	_check(bad_sounds.is_empty(), "every octopus sound id is in the catalog (missing: %s)" % [bad_sounds])
	var forms_enum := false
	for prop in settings.get_property_list():
		if prop["name"] == "form":
			forms_enum = str(prop["hint_string"]).contains(KEY)
	_check(forms_enum, "the settings' form picker offers it")


# --- 2. A player match -----------------------------------------------------------------------

func _begin(as_bots: bool) -> void:
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


func _player_match() -> void:
	print("player match:")
	await _begin(false)
	_check(game != null and game.is_hunter(fish) and game.bites.has(fish), "the local fish is the Hunter with a bite")
	if game == null or not game.is_hunter(fish):
		return
	var settings := WhatStinksSettings.shared()
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 6)
	for other in game.players:
		if other != fish and not game.is_hunter(other):
			other.freeze = true
	var visual := fish.get("_visual") as Node3D
	var rig: OctopusRig = visual.get_meta("octopus_rig", null) as OctopusRig
	_check(rig != null and rig.model != null, "the Hunter wears the OctopusRig and its model")
	if rig == null:
		return
	_check(rig.model.has_meta("hunter_octopus"), "the model carries the hunter_octopus meta (the lash finds it)")
	_check(absf(rig.length - fish.hitbox_length) < 0.05, "the model is built at the hitbox length (%.2f of %.2f)" % [rig.length, fish.hitbox_length])
	var bite: HunterBite = game.bites[fish]
	var attack := bite.attack as WhipAttack
	_check(attack != null and attack.key == "whip", "the bite's style is the whip")
	# the lash is wired to the rig once the bite has started (find_model); a press wires it
	var input := FishInput.new()
	fish.controls = input
	fish.controls_locked = false
	# --- the jet swims it
	var school: School = game.field.schools[0]
	school.set_physics_process(false)
	fish.global_transform = Transform3D(Basis.IDENTITY, school.middle() + Vector3(0.0, 0.0, 60.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	await _frames(3)
	var jets_before := int(rig.shown.get("jets", 0))
	var start := fish.global_position
	input.forward = 1.0
	var top := 0.0
	for i in tps * 5:
		await get_tree().physics_frame
		top = maxf(top, fish.linear_velocity.length())
	input.forward = 0.0
	var jets := int(rig.shown.get("jets", 0)) - jets_before
	_check(jets >= 3, "under throttle it fires jet pulses (%d in 5 s)" % jets)
	_check(top > 2.0 and fish.global_position.distance_to(start) > fish.hitbox_length * 0.8, "and the jets move it (top %.1f m/s, %.1f m)" % [top, fish.global_position.distance_to(start)])
	_check(rig.thrust_applied.length() > 0.0, "the thrust is real (velocity added in the physics tick)")
	# --- a lash on a school
	await _frames(tps)
	school.set_physics_process(false)
	var target := school.middle()
	var mouth_off := (target + Vector3(0.0, 0.0, 1.0)) - bite.mouth_point()
	fish.global_transform = Transform3D(Basis.IDENTITY, target + Vector3(0.0, 0.0, fish.hitbox_length * 0.45 + 4.0))
	fish.global_position += (target + Vector3(0.0, 0.0, 4.0)) - bite.mouth_point()
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	bite.cooldown = 0.0
	await _frames(3)
	var alive_before := school.alive_count()
	var bites_before := bite.bites
	var arm_hits: Array = []
	attack.arm_hit.connect(func(arm: int, _at: Vector3) -> void: arm_hits.append(arm))
	input.jump = true
	await _until(func() -> bool: return bite.holding(), tps)
	await _frames(tps / 2)
	_check(attack.has_model(), "the lash found the octopus model")
	_check(not attack.auto_pose and rig.lash == attack, "the lash is wired to the rig (the rig runs blend_pose after its gait)")
	_check(attack.locks.size() >= 1, "a held press locks arms onto the school (%d locks)" % attack.locks.size())
	_check(bite.attack.ring_count(bite) == attack.locks.size(), "the HUD's ring shows the lock count while held (%d)" % bite.attack.ring_count(bite))
	await _until(func() -> bool: return bite.charge() >= 1.0, tps * 3)
	var driven_while_held := attack.driven_arms().size()
	_check(driven_while_held >= 1, "arms are posed by the lash while held (%d)" % driven_while_held)
	var push_before := fish.linear_velocity
	input.jump = false
	await _until(func() -> bool: return not bite.busy() and bite.bites > bites_before, tps * 4)
	await _frames(tps / 2)
	_check(bite.bites > bites_before, "the release lashed (bites %d)" % (bite.bites - bites_before))
	_check(arm_hits.size() >= 1, "arms hit (%d arm hits)" % arm_hits.size())
	_check(school.alive_count() < alive_before, "and ate fish (%d of %d)" % [alive_before - school.alive_count(), alive_before])
	_check(attack.recoil_total.length() > 0.1, "the lash's recoil pushed the octopus (%.2f m/s)" % attack.recoil_total.length())
	# --- the arms settle back on the gait
	await _until(func() -> bool: return attack.driven_arms().is_empty(), tps * 3)
	_check(attack.driven_arms().is_empty(), "the arms were let go back to the gait")
	var stretched := false
	for a in 8:
		for j in 14:
			var bone: int = rig.model.arm_bones[a][j]
			if not rig.model.skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE) and rig.model.skeleton.get_bone_pose_scale(bone).distance_to(Vector3.ONE) > 0.02:
				stretched = true
	_check(not stretched, "no bone is left stretched after the lash")
	var worst := 0.0
	for a in 8:
		var want := rig.gait_joints(a)
		var have := rig.model.arm_joints(a)
		if want.size() == have.size():
			for p in want.size():
				worst = maxf(worst, want[p].distance_to(have[p]))
	_check(worst < rig.length * 0.2, "the settled arms sit on the gait pose (worst joint %.2f m of %.2f m body)" % [worst, rig.length])
	# --- a tap
	settings.bite_mode = WhatStinksSettings.BiteMode.TAP
	bite.cooldown = 0.0
	await _frames(3)
	bites_before = bite.bites
	input.jump = true
	await _frames(3)
	input.jump = false
	await _until(func() -> bool: return not bite.busy() and bite.bites > bites_before, tps * 4)
	_check(bite.bites > bites_before, "a tap lashes too")
	settings.bite_mode = WhatStinksSettings.BiteMode.HOLD
	await _until(func() -> bool: return not bite.busy(), tps * 3)
	# --- air roll is the rig's, with the stick's x as roll
	input.air_roll = true
	input.stick = Vector2(1.0, 0.0)
	input.forward = 0.6
	await _frames(tps * 2)
	input.air_roll = false
	input.stick = Vector2.ZERO
	input.forward = 0.0
	_check(is_finite(fish.global_basis.get_euler().x) and is_finite(rig.shown.get("spread", 0.0)), "air roll with the octopus stays finite")
	# --- a puppet / net: another octopus body, bite opened as the host would message it
	fish.controls = null


# --- 3. A bot Hunter -------------------------------------------------------------------------

func _bot_match() -> void:
	print("bot match:")
	await _begin(true)
	if game == null or game.hunters.is_empty():
		_check(false, "a bot match started")
		return
	var hunter: FishController = game.hunters[0]
	var hbot: WhatStinksBot = game.bots.get(hunter)
	_check(hbot != null, "the Hunter is a WhatStinksBot")
	var bite: HunterBite = game.bites[hunter]
	var visual := hunter.get("_visual") as Node3D
	_check(visual != null and visual.has_meta("octopus_rig"), "the bot's Hunter wears the octopus")
	_check(bite.attack.key == "whip", "its style is the whip")
	var presses := [0]
	var lashes := [0]
	var max_locks := [0]
	bite.opened.connect(func() -> void: presses[0] += 1)
	bite.released.connect(func(_c: float) -> void: lashes[0] += 1)
	var eaten_before := 0
	for s: School in game.field.schools:
		eaten_before += s.alive_count()
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 12)
	for i in tps * 90:
		await get_tree().physics_frame
		var att := bite.attack as WhipAttack
		if att != null:
			max_locks[0] = maxi(max_locks[0], att.locks.size())
		if lashes[0] >= 4 and i > tps * 20:
			break
	var alive_after := 0
	for s: School in game.field.schools:
		alive_after += s.alive_count()
	_check(presses[0] >= 2, "the bot presses the bite (%d presses)" % presses[0])
	_check(lashes[0] >= 2, "and releases it (%d lashes)" % lashes[0])
	_check(max_locks[0] >= 1, "its arms lock on prey (most %d at once)" % max_locks[0])
	_check(alive_after < eaten_before, "and it eats (%d fish gone)" % (eaten_before - alive_after))


# --- 4. Net ----------------------------------------------------------------------------------

func _net() -> void:
	print("net:")
	if game == null or game.hunters.is_empty():
		return
	var hunter: FishController = game.hunters[0]
	var bite: HunterBite = game.bites[hunter]
	var attack := bite.attack as WhipAttack
	hunter.puppet = true  # as another machine's Hunter: it follows messages, it does not decide
	bite.cooldown = 0.0
	await _frames(5)
	var landed := [0]
	bite.chomped.connect(func(_m: Vector3, _r: float, _rad: float, _c: int) -> void: landed[0] += 1)
	bite.net_open()
	await _frames(tps / 2)
	_check(bite.holding() or bite.busy(), "a puppet's bite opens from the host's message (the lash visuals run)")
	_check(attack.beat != WhipAttack.Beat.IDLE, "the puppet's arms flare (beat %d)" % attack.beat)
	bite.net_close(1.0)
	await _until(func() -> bool: return not bite.busy(), tps * 4)
	_check(not bite.busy(), "and its release runs out to the end")
	_check(attack.driven_arms().is_empty() or await _until(func() -> bool: return attack.driven_arms().is_empty(), tps * 3), "the arms settle")
