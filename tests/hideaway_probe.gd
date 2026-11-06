extends Node
## Marco Polo Hideaways (planning_marco_whales.md section 8, D7): the rules of
## hideaway.gd on a sphere set by the probe, with a whale seeker:
## - settling: not hidden before hideaway_settle, hidden after; hidden means
##   no view (whale_in_sight false), no tag by the whale's body;
## - capacity: only hideaway_capacity fish hide in one spot, the next stays out;
## - Stale Water: fills while hidden, forces the fish out of the sphere with a
##   noise burst and a cooldown (it can not hide again at once), and is not a catch;
## - leaving by swimming out ends it quietly and the gauge drains outside;
## - a new round clears everyone;
## - a hider bot that picks a hideaway gets hidden in it.
##   Godot_console.exe --headless --fixed-fps 60 --path . res://tests/hideaway_probe.tscn

var main: Node
var mp: MarcoPoloSettings
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	mp = MarcoPoloSettings.shared()
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _run() -> void:
	mp.hide_time = 0.5
	mp.round_time = 300.0
	mp.round_over_time = 0.5
	mp.min_players = 4
	mp.rounds = 0
	mp.bot_seeker_rounds = 1
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	mp.start_as = MarcoPoloSettings.StartAs.HIDER
	mp.whale_seeker = true
	mp.hideaway_time = 3.0
	mp.hideaway_settle = 0.6
	mp.hideaway_capacity = 1
	mp.hideaway_cooldown = 3.0
	mp.hideaway_recovery = 1.0
	mp.arena = "Sunken Temple"
	main.set_mode(main.MARCO_POLO)
	await _ticks(3)
	if main._match_card:
		main._match_card.play_requested.emit()
	await _ticks(5)
	var game: MarcoPoloMatch = main.marco_polo
	var me: FishController = main.get_node("Fish")
	if game == null or game.hideaway_system == null:
		check(false, "the match and its hideaway system exist")
		get_tree().quit(1)
		return
	var guard := 0
	while game.phase != MarcoPoloMatch.Phase.LIVE and guard < 1200:
		await _ticks(1)
		guard += 1
	check(game.phase == MarcoPoloMatch.Phase.LIVE and game.role_of(me) == MarcoPoloMatch.Role.HIDER, "live, the player is a hider")
	print("    eliminated %s battered %s puppet %s" % [game.eliminated.has(me), me.battered, me.puppet])
	var hides: Node = game.hideaway_system
	var whale: FishController = game.seekers()[0]
	var other: FishController
	for f in game.live_hiders():
		if f != me:
			other = f
			break
	# Quiet everything: the probe moves the fish itself.
	for bot: Node in game.bots.values():
		bot.set_physics_process(false)
	me.controls = FishInput.new()
	for f in [whale, other]:
		(f as FishController).controls = FishInput.new()
	var spot := {"name": "probe", "position": me.global_position, "radius": 3.0}
	hides.call("setup", game, [spot])
	var events: Array = []
	hides.connect("entered", func(_f: FishController, _i: int) -> void: events.append("in"))
	hides.connect("exited", func(_f: FishController, _i: int) -> void: events.append("out"))
	var flushes: Array = []
	hides.connect("flushed", func(f: FishController, _i: int, impulse: Vector3) -> void: flushes.append([f, impulse]))
	var middle: Vector3 = spot.position
	var caught: Array = []
	game.caught.connect(func(h: FishController, _how: String, _by: FishController) -> void: caught.append(h))

	print("settling:")
	_hold(me, middle)
	_hold(other, middle + Vector3(40.0, 0.0, 0.0))
	await _seconds(0.3)
	_hold(me, middle)
	check(not game.is_hidden(me) and not bool(hides.call("is_hidden", me)), "inside for 0.3 s: not hidden yet")
	await _seconds(0.6)
	_hold(me, middle)
	check(game.is_hidden(me) and int(hides.call("hideaway_of", me)) == 0, "inside for 0.9 s: hidden in hideaway 0")
	check(events == ["in"], "entered fired once (%s)" % [events])

	print("hidden:")
	_hold(whale, middle + Vector3(5.0, 0.0, 0.0))
	whale.look_at(middle)
	await _ticks(10)
	_hold(me, middle)
	check(not game.whale_in_sight(whale, me), "the whale does not see it, even close and facing it")
	check(game.whale_sees(whale, me) < mp.layer_skeleton, "and sees nothing of it (%.2f)" % game.whale_sees(whale, me))
	_hold(whale, middle)
	await _seconds(0.5)
	check(caught.is_empty(), "the whale's body on top of it does not tag it")
	_hold(whale, middle + Vector3(60.0, 0.0, 0.0))

	print("capacity:")
	_hold(other, middle + Vector3(0.5, 0.0, 0.0))
	await _seconds(1.0)
	_hold(me, middle)
	check(not game.is_hidden(other) and game.is_hidden(me), "hideaway full (capacity 1): the second fish stays out")
	_hold(other, middle + Vector3(40.0, 0.0, 0.0))

	print("Stale Water:")
	var g0 := float(hides.call("gauge", me))
	await _seconds(0.5)
	_hold(me, middle)
	check(float(hides.call("gauge", me)) > g0 and float(hides.call("gauge", me)) < 1.0, "the gauge rises while hidden (%.2f)" % float(hides.call("gauge", me)))
	var bursts: Array = []
	(game._meters[me] as NoiseMeter).burst.connect(func(amount: float) -> void: bursts.append(amount))
	var waited := 0.0
	while game.is_hidden(me) and waited < 6.0:
		_hold(me, middle)
		await _ticks(6)
		waited += 6.0 / Engine.physics_ticks_per_second
	check(not game.is_hidden(me) and flushes.size() == 1 and flushes[0][0] == me, "full gauge: flushed after %.1f s" % waited)
	await _ticks(10)
	check(me.global_position.distance_to(middle) > 3.0 and me.linear_velocity.length() > 1.0,
			"out of the sphere (%.1f m) and moving (%.1f m/s)" % [me.global_position.distance_to(middle), me.linear_velocity.length()])
	check(bursts.size() == 1 and bursts[0] >= mp.hideaway_exit_noise - 0.01, "with a noise burst (%s)" % [bursts])
	check(not caught.has(me) and game.live_hiders().has(me), "found, not caught")
	_hold(me, middle)
	await _seconds(1.5)
	_hold(me, middle)
	check(not game.is_hidden(me), "back inside straight away: can not hide again (cooldown)")
	await _seconds(2.0)
	_hold(me, middle)
	await _seconds(1.0)
	_hold(me, middle)
	check(game.is_hidden(me), "after the cooldown it can")

	print("leaving and recovering:")
	var high := float(hides.call("gauge", me))
	_hold(me, middle + Vector3(10.0, 0.0, 0.0))
	await _ticks(8)
	check(not game.is_hidden(me), "swimming out ends it")
	await _seconds(1.0)
	check(float(hides.call("gauge", me)) < high, "the gauge drains outside (%.2f -> %.2f)" % [high, float(hides.call("gauge", me))])

	print("a new round:")
	_hold(me, middle)
	await _seconds(1.5)
	_hold(me, middle)
	check(game.is_hidden(me), "hidden again")
	mp.rounds = 2
	game.start_round(1)
	await _ticks(5)
	check(not bool(hides.call("is_hidden", me)) and float(hides.call("gauge", me)) == 0.0, "a new round: nobody hidden, gauges empty")

	await _bot_check(game, hides, spot)
	print("hideaway_probe: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## A fish held still at `at` (its own controls empty): the probe places it.
func _hold(fish: FishController, at: Vector3) -> void:
	fish.global_position = at
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO


## A hider bot that picks the hideaway gets hidden in it.
func _bot_check(game: MarcoPoloMatch, hides: Node, spot: Dictionary) -> void:
	print("a bot hides in one:")
	mp.bot_hideaway_chance = 1.0
	mp.hideaway_time = 30.0
	var guard := 0
	while game.phase != MarcoPoloMatch.Phase.LIVE and guard < 1200:
		await _ticks(1)
		guard += 1
	var middle: Vector3 = spot.position
	var seeker: FishController = game.seekers()[0]
	var bots: Array[FishController] = []
	for f in game.live_hiders():
		if game.bots.has(f):
			bots.append(f)
	if game.bots.has(seeker):
		(game.bots[seeker] as Node).set_physics_process(false)
		seeker.controls = FishInput.new()
	for f in bots:
		var bot: Node = game.bots[f]
		bot.set_physics_process(true)
		bot.call("_reset_plan")
		f.controls = bot.input
		_hold(f, middle + Vector3(9.0, 0.0, 0.0))
	var hidden := false
	var t := 0.0
	while t < 40.0 and not hidden:
		await _ticks(6)
		t += 6.0 / Engine.physics_ticks_per_second
		for f in bots:
			if game.is_hidden(f):
				hidden = true
	check(hidden, "a bot hid in the hideaway within %.1f s" % t)
