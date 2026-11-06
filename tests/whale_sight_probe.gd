extends Node
## Marco Polo whales (planning_marco_whales.md) Phase 2: how the whale sees and
## how a bot whale hunts. Checks:
## - the whale's falloff (whale_falloff) is 1 up to its near sight, falls to
##   half at its half sight, and is 0 past titan_sight_range();
## - whale_in_sight uses the whale's own cone and range (behind it, past its
##   range: out; ahead, inside it: in) while a hider seeker still uses in_sight;
## - whale_sees equals exposure for a fish seeker and is the whale's own track
##   for a whale (bots and people read the same call);
## - a bot whale never calls Marco! by hand, gets streak heads from the auto
##   calls, and finds a hider that stays still (the streaks are all it has).
##   Godot_console.exe --headless --fixed-fps 60 --path . res://tests/whale_sight_probe.tscn

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


func _run() -> void:
	mp.hide_time = 1.0
	mp.round_time = 90.0
	mp.round_over_time = 0.5
	mp.min_players = 3
	mp.rounds = 0
	mp.bot_seeker_rounds = 0
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	mp.start_as = MarcoPoloSettings.StartAs.SEEKER
	mp.whale_seeker = true
	mp.marco_auto = true
	mp.arena = "Sunken Temple"
	main.set_mode(main.MARCO_POLO)
	await _ticks(3)
	if main._match_card:
		main._match_card.play_requested.emit()
	await _ticks(5)
	var game: MarcoPoloMatch = main.marco_polo
	var fish: FishController = main.get_node("Fish")
	if game == null:
		check(false, "the match started")
		get_tree().quit(1)
		return
	var guard := 0
	while game.phase != MarcoPoloMatch.Phase.LIVE and guard < 1200:
		await _ticks(1)
		guard += 1
	check(game.phase == MarcoPoloMatch.Phase.LIVE and game.is_whale(fish), "live, the player is the whale")
	_falloff_table(game)
	_cone_checks(game, fish)
	await _hunt(game, fish)
	print("whale_sight_probe: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _falloff_table(game: MarcoPoloMatch) -> void:
	print("the whale's falloff:")
	var near := game.whale_near_sight()
	var half := game.whale_half_sight()
	var far := game.titan_sight_range()
	var row := []
	var last := 2.0
	var monotonic := true
	for k in 11:
		var d := far * 1.1 * k / 10.0
		var f := game.whale_falloff(d)
		row.append("%.0fm:%.2f" % [d, f])
		monotonic = monotonic and f <= last + 0.0001
		last = f
	print("    near %.1f half %.1f range %.1f  %s" % [near, half, far, " ".join(row)])
	check(is_equal_approx(game.whale_falloff(near * 0.5), 1.0), "full inside the near sight")
	check(absf(game.whale_falloff(half) - 0.5) < 0.02, "half at the half sight (%.2f)" % game.whale_falloff(half))
	check(game.whale_falloff(far * 1.05) == 0.0, "none past the range")
	check(monotonic, "never rises with distance")
	check(far < game.sight_range(), "the whale sees less far than a fish (%.1f < %.1f m)" % [far, game.sight_range()])


func _cone_checks(game: MarcoPoloMatch, whale: FishController) -> void:
	print("the whale's cone:")
	var hider: FishController = game.live_hiders()[0]
	var eye := game.eye_of(whale)
	var ahead := -game.view_of(whale).orthonormalized().z
	hider.freeze = true
	var far := game.titan_sight_range()
	hider.global_position = eye + ahead * far * 0.4
	check(game.whale_in_sight(whale, hider) or _blocked(game, whale, hider), "ahead and in range: in sight (or a wall's in the way)")
	hider.global_position = eye + ahead * far * 1.3
	check(not game.whale_in_sight(whale, hider), "past the range: out")
	hider.global_position = eye - ahead * far * 0.3
	check(not game.whale_in_sight(whale, hider), "behind it: out")
	hider.freeze = false
	var other: FishController = null
	for f in game.players:
		if f != whale and not game.is_whale(f):
			other = f
			break
	check(other != null and game.whale_in_sight(other, whale) == game.in_sight(other, whale), "a hider seeker would still use in_sight (same answer)")


func _blocked(game: MarcoPoloMatch, whale: FishController, hider: FishController) -> bool:
	return not SightCone.clear_line(whale.get_world_3d().direct_space_state, game.eye_of(whale), SightCone.body_points(hider), game._fish_rids(), game._blockers_mask())


## A bot whale (no manual Marco!) against hiders that sit still: streaks appear and it finds one.
func _hunt(game: MarcoPoloMatch, whale: FishController) -> void:
	print("a bot whale hunts:")
	var pilot := MarcoPoloBot.new()
	pilot.fish = whale
	game.add_child(pilot)
	pilot.bind(game)
	var calls := [0]
	game.marco_called.connect(func(_w: FishController) -> void: calls[0] += 1)
	for bot: Node in game.bots.values():
		bot.set_physics_process(false)  # the hiders hold still
	var tags := [0]
	game.caught.connect(func(_h: FishController, _how: String, _by: FishController) -> void: tags[0] += 1)
	var heads_seen := 0
	var by_hand := 0
	var t := 0.0
	while t < 75.0 and tags[0] == 0 and game.phase == MarcoPoloMatch.Phase.LIVE:
		await _ticks(6)
		t += 0.1
		heads_seen = maxi(heads_seen, game.streak_heads_of(whale).size())
		if game.marco(whale):
			by_hand += 1
	print("    %.1f s, %d auto calls, up to %d streak heads, %d tags" % [t, calls[0], heads_seen, tags[0]])
	check(calls[0] >= 1, "the whale called by itself (%d)" % calls[0])
	check(by_hand == 0, "the manual Marco! does nothing for a whale")
	check(tags[0] > 0, "it found a still hider in %.1f s" % t)
	pilot.queue_free()
