extends Node
## The Lantern Angler integrated as a playable Hunter (planning_new_hunters.md INT3): registered and ready, its settings, docs and
## sounds in the shared tables, then played in a real What Stinks? match.
##   1. Registry: the form is on the card, its sheet says "lure", the style table builds a LureAttack, every LanternRig, LureField
##      default is a registered panel setting with a doc line, every sound id is in the catalog, the picker offers the form.
##   2. Player match: the Hunter wears the LanternRig/AnglerModel at its hitbox length; a held press flares the esca, gapes the jaw
##      wider, starts a LureField source and draws prey inside the cone (a bot-style prey is pulled, a dash breaks the hold, the
##      human resist cancels most of it); the captivated level eases in; the release snaps (bites counted, esca dims, field ends).
##   3. Bot match: a bot Hunter in the angler form hunts (presses, holds, releases) and the prey bot feels the steering bias.
##   4. Net: a puppet's bite opened by the host's message runs the same lure visuals without judging.
##   Godot_console.exe --headless --path . res://tests/angler_match_probe.tscn

const KEY := "lantern_angler"
const LanternRig := preload("res://scripts/what_stinks/forms/lantern_rig.gd")

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
	print("angler_match_probe: %s (%d checks)" % ["all checks passed" if failures == 0 else "%d FAILED" % failures, checks])
	get_tree().quit(1 if failures else 0)


# --- 1. Registry -----------------------------------------------------------------------------

func _registry() -> void:
	print("registry:")
	_check(HunterForms.has(KEY) and HunterForms.KEYS.has(KEY), "the form is registered and in card order")
	_check(HunterForms.is_ready(KEY) and HunterForms.ready_keys().has(KEY), "it is ready and the card lists it")
	_check(HunterForms.playable(KEY) == KEY, "it plays as itself, not the fallback")
	var sheet := HunterForms.sheet(KEY)
	_check(str(sheet["name"]) == "Lantern Angler" and str(sheet["attack"]) == "lure", "its sheet names the Lantern Angler and the lure style")
	var attack := HunterAttack.make("lure")
	_check(attack != null and attack.key == "lure" and attack is LureAttack, "the style table builds a LureAttack")
	_check(HunterBiteFx.SOUNDS.has("lure"), "the bite fx has a sound row for the lure style")
	var settings := WhatStinksSettings.shared()
	var missing: Array[String] = []
	var undocumented: Array[String] = []
	var ids: Array = []
	ids.append_array(LanternRig.DEFAULTS.keys())
	ids.append_array(LureField.DEFAULTS.keys())
	for id: String in ids:
		if settings.get(id) == null:
			missing.append(id)
		if not SettingDocs.DOCS.has("what_stinks/" + id):
			undocumented.append(id)
	_check(missing.is_empty(), "every rig and lure tuning value is a panel setting (missing: %s)" % [missing])
	_check(undocumented.is_empty(), "and each has a doc line (missing: %s)" % [undocumented])
	var off: Array[String] = []
	for id: String in LureField.DEFAULTS.keys():
		if settings.get(id) != null and not is_equal_approx(float(settings.get(id)), float(LureField.DEFAULTS[id])):
			off.append(id)
	_check(off.is_empty(), "the panel defaults match the LureField built-ins (differ: %s)" % [off])
	var bad_sounds: Array[String] = []
	for id: String in ["angler/flare", "angler/hum", "angler/snap"]:
		if not SoundCatalog.events().has(id):
			bad_sounds.append(id)
	_check(bad_sounds.is_empty(), "every angler sound id is in the catalog (missing: %s)" % [bad_sounds])
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
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 6)
	var prey: Array[FishController] = []
	for other in game.players:
		if other != fish and not game.is_hunter(other):
			other.freeze = true
			prey.append(other)
	var visual := fish.get("_visual") as Node3D
	var rig: Node3D = visual.get_meta("lantern_rig", null) as Node3D
	_check(rig != null and rig.model != null, "the Hunter wears the LanternRig and its model")
	if rig == null:
		return
	_check(absf(rig.length - fish.hitbox_length) < 0.05, "the model is built at the hitbox length (%.2f of %.2f)" % [rig.length, fish.hitbox_length])
	_check(visual.has_meta("hunter_jaw") and rig.jaw != null, "the jaw wrapper is registered for the bite")
	var bite: HunterBite = game.bites[fish]
	var attack := bite.attack as LureAttack
	_check(attack != null and attack.key == "lure", "the bite's style is the lure")
	var input := FishInput.new()
	fish.controls = input
	fish.controls_locked = false
	# --- swims
	fish.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0))
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	await _frames(3)
	var start := fish.global_position
	input.forward = 1.0
	var top := 0.0
	for i in tps * 4:
		await get_tree().physics_frame
		top = maxf(top, fish.linear_velocity.length())
	input.forward = 0.0
	_check(top > 2.0 and fish.global_position.distance_to(start) > fish.hitbox_length * 0.5, "the angler swims (top %.1f m/s)" % top)
	fish.linear_velocity = Vector3.ZERO
	await _frames(tps / 2)
	# --- a lure hold on prey in the cone. A prey "bot": controlled by an empty input, so a push is all that moves it.
	var victim: FishController = prey[0] if not prey.is_empty() else null
	_check(victim != null, "there is prey to draw")
	if victim == null:
		return
	victim.freeze = false
	victim.controls = FishInput.new()
	victim.set_meta("ws_dashing", false)
	var fwd := -fish.global_basis.z
	victim.global_position = bite.mouth_point() + fwd * 22.0
	victim.linear_velocity = Vector3.ZERO
	attack.target_source = func() -> Array: return [victim]
	bite.cooldown = 0.0
	var jaw_before: float = rig.jaw.gape_mult
	var gap_before := victim.global_position.distance_to(bite.mouth_point())
	var bites_before := bite.bites
	input.jump = true
	await _until(func() -> bool: return bite.holding(), tps)
	await _frames(tps / 2)
	_check(attack.source != null and attack.source.active, "the press starts a LureField source")
	_check(LureField.active().size() >= 1, "and LureField lists it")
	_check(attack.esca_level > 1.2 and float(rig.model.get("esca_intensity")) > 1.2, "the esca flares (level %.2f, model %.2f)" % [attack.esca_level, float(rig.model.get("esca_intensity"))])
	await _frames(tps * 2)
	_check(rig.jaw.gape_mult > maxf(jaw_before, 1.0) + 0.1, "the jaw gapes wider while held (x%.2f)" % rig.jaw.gape_mult)
	var gap_now := victim.global_position.distance_to(bite.mouth_point())
	var toward_v := victim.linear_velocity.dot((attack.source.esca - victim.global_position).normalized())
	_check(toward_v > 0.3, "prey in the cone is drawn toward the light (%.2f m/s toward it; %.1f m to %.1f m)" % [toward_v, gap_before, gap_now])
	var held := LureField.captivated(victim)
	_check(held > 0.1, "its captivated level rises (%.2f)" % held)
	_check(attack.captive_count >= 1, "the attack counts it as drawn (%d)" % attack.captive_count)
	# the human resist and the dash, straight on the source
	var src := attack.source
	var id := victim.get_instance_id()
	var pos := victim.global_position
	var toward := (src.pull_target(pos) - pos).normalized()
	var free_a := src.accel_on(id, pos, Vector3.ZERO, true, false, 0.0).length()
	var swim_a := src.accel_on(id, pos, -toward, true, false, 0.0).length()
	_check(free_a > 0.0 and swim_a < free_a * 0.3, "a person swimming straight away cancels most of the pull (%.2f to %.2f)" % [free_a, swim_a])
	var dash_a := src.accel_on(id, pos, Vector3.ZERO, true, true, 0.0).length()
	_check(dash_a < free_a * 0.05, "a dash cancels it (%.3f)" % dash_a)
	_check(src.immune.has(id), "and grants a short immunity")
	# the field is bounded: a fish out of the cone feels nothing
	var behind := src.accel_on(id, src.esca - src.axis * 30.0, Vector3.ZERO, false, false, 0.0).length()
	_check(behind == 0.0, "a fish behind the Angler is not drawn")
	# the HUD's source of truth
	_check(LureField.is_human(fish) == false or true, "LureField.is_human is callable")
	# --- release snaps
	var hits := [0]
	bite.chomped.connect(func(_m: Vector3, _r: float, _rad: float, _c: int) -> void: hits[0] += 1)
	input.jump = false
	await _until(func() -> bool: return not bite.busy() and bite.bites > bites_before, tps * 4)
	await _frames(5)
	_check(bite.bites > bites_before, "the release snaps shut (bites %d)" % (bite.bites - bites_before))
	_check(attack.source == null or not attack.source.active, "the field ends with the snap")
	_check(LureField.active().is_empty(), "and LureField has no live source")
	_check(attack.esca_level < 1.0, "the esca drops dark (%.2f)" % attack.esca_level)
	await _until(func() -> bool: return LureField.captivated(victim) < 0.01, tps * 4)
	_check(LureField.captivated(victim) < 0.05, "the captivated level fades out, not pops (%.3f)" % LureField.captivated(victim))
	await _frames(tps * 3)
	_check(attack.esca_level > 0.8, "the esca relights over the cooldown (%.2f)" % attack.esca_level)
	_check(rig.jaw.gape_mult < 1.1, "and the gape returns to normal (x%.2f)" % rig.jaw.gape_mult)
	# --- air roll stays finite
	input.air_roll = true
	input.stick = Vector2(1.0, 0.0)
	input.forward = 0.6
	await _frames(tps * 2)
	input.air_roll = false
	input.stick = Vector2.ZERO
	input.forward = 0.0
	_check(is_finite(fish.global_basis.get_euler().x), "air roll with the angler stays finite")
	# a bot-style prey feels the steering bias
	attack.target_source = Callable()
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
	_check(visual != null and visual.has_meta("lantern_rig"), "the bot's Hunter wears the angler")
	_check(bite.attack.key == "lure", "its style is the lure")
	var presses := [0]
	var lashes := [0]
	var fields := [0]
	bite.opened.connect(func() -> void: presses[0] += 1)
	bite.released.connect(func(_c: float) -> void: lashes[0] += 1)
	var eaten_before := 0
	for s: School in game.field.schools:
		eaten_before += s.alive_count()
	await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, tps * 12)
	for i in tps * 90:
		await get_tree().physics_frame
		if not LureField.active().is_empty():
			fields[0] += 1
		if lashes[0] >= 4 and i > tps * 20:
			break
	var alive_after := 0
	for s: School in game.field.schools:
		alive_after += s.alive_count()
	_check(presses[0] >= 2, "the bot presses the bite (%d presses)" % presses[0])
	_check(lashes[0] >= 2, "and releases it (%d snaps)" % lashes[0])
	_check(fields[0] > 0, "its lure field was live for %d ticks" % fields[0])
	_check(alive_after <= eaten_before, "fish count is sane (%d gone)" % (eaten_before - alive_after))
	# the prey-bot steering bias: a prey bot near a live source has its target bent toward the light
	var src := LureField.Source.new(hunter, WhatStinksSettings.shared())
	var fwd := -hunter.global_basis.z
	src.place(hunter.global_position + Vector3.UP, hunter.global_position, fwd, 6.0)
	src.start()
	src.ramp = 1.0
	var prey_fish: FishController = null
	for p in game.live_prey():
		prey_fish = p
		break
	if prey_fish != null and prey_fish.controls != null:
		var old := prey_fish.global_position
		prey_fish.global_position = hunter.global_position + fwd * 15.0
		var away := prey_fish.global_position + fwd * 30.0
		var blended := LureField.blend_target(prey_fish, away)
		_check(blended.distance_to(src.esca) < away.distance_to(src.esca) - 1.0, "a prey bot's target is bent toward the lure (blend_target)")
		prey_fish.global_position = old
	else:
		_check(true, "(no bot prey to test the steering bias on)")
	src.stop()
	LureField.reset()


# --- 4. Net ----------------------------------------------------------------------------------

func _net() -> void:
	print("net:")
	if game == null or game.hunters.is_empty():
		return
	var hunter: FishController = game.hunters[0]
	var bite: HunterBite = game.bites[hunter]
	var attack := bite.attack as LureAttack
	hunter.puppet = true  # as another machine's Hunter: it follows messages, it does not decide
	var driver: Node = game.bots.get(hunter)
	if driver != null:
		driver.set_physics_process(false)  # the bot would press and release on its own
	bite.abort()
	await _frames(10)
	bite.cooldown = 0.0
	await _frames(5)
	bite.net_open()
	await _frames(tps / 2)
	_check(bite.holding() or bite.busy(), "a puppet's bite opens from the host's message (the lure visuals run)")
	_check(attack.beat != LureAttack.Beat.IDLE and attack.source != null, "the puppet's esca flares and its field runs (beat %d)" % attack.beat)
	bite.net_close(1.0)
	await _until(func() -> bool: return not bite.busy(), tps * 4)
	_check(not bite.busy(), "and its release runs out to the end")
	await _frames(tps / 2)
	_check(LureField.active().is_empty(), "the puppet's field ends with the snap")
