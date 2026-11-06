extends Node
## Marco Polo with bots only (planning_marco_polo.md phase 6): a few short
## rounds per arena, every fish a MarcoPoloBot (the player's too), and what
## happened:
## - tags per round and how long rounds last (and how they end);
## - points by layer (MatchStats.SEEN);
## - how often a settled hider is found (tagged after sitting still a while),
##   and how often a seeker tags "blind": with nothing of the hider in its view
##   and no blip near it in the last few seconds (should be about never);
## - how often a Fake Fish fools; porthole entries, knocks and fish out of water.
## Keep runs short ([[feedback-limit-analysis]]):
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/marco_polo_sim.tscn
##       [-- --arena=temple|tank|both --rounds=4 --round_time=60 --players=5 --variant=elimination|conversion]

const TICKS := 120
## Still this long (s) counts as settled.
const SETTLED := 1.5
## A tag is blind when the seeker saw nothing of the hider and had no blip
## within BLIND_PING_RANGE m of it for BLIND_WINDOW s before.
const BLIND_WINDOW := 3.0
const BLIND_PING_RANGE := 12.0

var main: Node
var mp: MarcoPoloSettings
var arenas: Array[String] = ["Sunken Temple", "Aquarium"]
var rounds := 4
var round_time := 60.0
var players := 5
var variant := MarcoPoloSettings.Variant.ELIMINATION

var _time := 0.0
var _still := {}  # hider -> seconds still
var _settles := 0
var _seen_at := {}  # [seeker, hider] key -> last time it saw a layer
var _ping_log: Array = []  # [time, seeker, pos]
var _fakes_seen := {}
var _row := {}
var _pilots := {}  # fish -> MarcoPoloBot
var _chase_closest := {}  # seeker -> closest (m) in the chase going on


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=")
		if pair.size() != 2:
			continue
		match pair[0]:
			"arena":
				if pair[1] == "temple":
					arenas = ["Sunken Temple"]
				elif pair[1] == "tank":
					arenas = ["Aquarium"]
			"rounds":
				rounds = int(pair[1])
			"round_time":
				round_time = float(pair[1])
			"players":
				players = int(pair[1])
			"variant":
				variant = MarcoPoloSettings.Variant.CONVERSION if pair[1].begins_with("conv") else MarcoPoloSettings.Variant.ELIMINATION
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	mp = MarcoPoloSettings.shared()
	_run.call_deferred()


func _run() -> void:
	mp.round_time = round_time
	mp.round_over_time = 0.2
	mp.min_players = players
	mp.rounds = rounds
	mp.bot_seeker_rounds = 11  # every bot a turn (it was a bool)
	mp.variant = variant
	var started := Time.get_ticks_msec()
	for arena_name in arenas:
		if not main.ENVIRONMENTS.has(arena_name):
			print("%s: not registered in main.gd ENVIRONMENTS, skipped" % arena_name)
			continue
		await _arena(arena_name)
	print("marco_polo_sim: done in %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	get_tree().quit(0)


func _arena(arena_name: String) -> void:
	mp.arena = arena_name
	if main.marco_polo:
		main.set_mode(main.FREE_SWIM)
		await _ticks(3)
	main.set_mode(main.MARCO_POLO)
	await _ticks(3)
	if main._match_card:
		main._match_card.play_requested.emit()
	await _ticks(5)
	var game: MarcoPoloMatch = main.marco_polo
	if game == null:
		print("%s: no match" % arena_name)
		return
	var player: FishController = main.get_node("Fish")
	if not game.bots.has(player):
		var pilot := MarcoPoloBot.new()
		pilot.name = "PlayerBot"
		pilot.fish = player
		game.add_child(pilot)
		pilot.bind(game)
	_row = {"split": {}, "rounds": 0, "tags": 0, "time": 0.0, "ends": {}, "settled_found": 0, "blind": 0, "fakes": 0, "fooled": 0,
			"entries": 0, "knocks": 0, "out_of_water": 0, "pings": 0, "in_view": 0.0, "chases": 0, "closest": [], "exposed": 0.0, "in_sight": 0.0, "both": 0.0}
	_pilots.clear()
	_chase_closest.clear()
	for f: FishController in game.bots:
		if game.bots[f] is MarcoPoloBot:
			_pilots[f] = game.bots[f]
	for child in game.get_children():
		if child is MarcoPoloBot and is_instance_valid((child as MarcoPoloBot).fish):
			_pilots[(child as MarcoPoloBot).fish] = child
	_still.clear()
	_settles = 0
	_seen_at.clear()
	_ping_log.clear()
	_fakes_seen.clear()
	game.caught.connect(_on_caught.bind(game))
	game.fooled.connect(func(_s: FishController, _f: FishController) -> void: _row.fooled += 1)
	game.pinged.connect(func(seeker: FishController, pos: Vector3, _l: float, _p: bool) -> void:
		_row.pings += 1
		_ping_log.append([_time, seeker, pos]))
	var system := game.porthole_system as PortholeSystem
	if system:
		system.entered.connect(func(_f: FishController, _p: Porthole) -> void: _row.entries += 1)
		system.knocked.connect(func(_f: FishController, _p: Porthole, _s: float) -> void: _row.knocks += 1)
	print("%s (%s, %d fish, %d rounds of %.0f s):" % [arena_name, MarcoPoloSettings.Variant.keys()[variant], game.players.size(), rounds, round_time])
	for index in rounds:
		game.start_round(index)
		await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, mp.hide_time + 2.0, game)
		var live_from := _time
		var tags_before: int = _row.tags
		await _until(func() -> bool: return game.phase != MarcoPoloMatch.Phase.LIVE, round_time + 2.0, game)
		var length := _time - live_from
		var why := "time" if length >= round_time - 0.1 else "all caught"
		_row.rounds += 1
		_row.time += length
		_row.ends[why] = int(_row.ends.get(why, 0)) + 1
		print("  round %d: %d tags, %.1f s (%s)" % [index + 1, _row.tags - tags_before, length, why])
		# Hold it between rounds: the next start_round is ours.
		game.phase = MarcoPoloMatch.Phase.OVER
		game.phase_left = 1000.0
	_report(game)
	game.caught.disconnect(_on_caught)


func _report(game: MarcoPoloMatch) -> void:
	var by_layer := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for fish: FishController in game.stats:
		var line: Dictionary = game.stats[fish]
		var seen: Array = line.get(MatchStats.SEEN, [])
		for i in mini(seen.size(), by_layer.size()):
			by_layer[i] += float(seen[i])
	var n := maxi(int(_row.rounds), 1)
	print("  tags/round %.2f, round length %.1f s, ends %s" % [float(_row.tags) / n, float(_row.time) / n, str(_row.ends)])
	print("  points by layer (none, skeleton, cardio, muscle, skin, aura): %s" % str(by_layer.map(func(v: float) -> String: return "%.0f" % v)))
	print("  settled hiders found %d of %d settles (%.0f%%)" % [_row.settled_found, _settles, 100.0 * _row.settled_found / maxi(_settles, 1)])
	print("  blind tags %d of %d" % [_row.blind, _row.tags])
	print("  whale tags by what led them (hider seen through the whale's eyes / a streak head within 12 m): %s" % str(_row.split))
	print("  Fake Fish thrown %d, fooled %d (%.0f%%)" % [_row.fakes, _row.fooled, 100.0 * _row.fooled / maxi(int(_row.fakes), 1)])
	print("  porthole entries %d, knocks %d, out of water %d (%.0f%% of entries)" % [_row.entries, _row.knocks, _row.out_of_water,
			100.0 * _row.out_of_water / maxi(int(_row.entries), 1)])
	print("  pings %d (%.1f/round)" % [_row.pings, float(_row.pings) / n])
	print("  per round: some hider showing a layer %.1f s, some hider in line of sight %.1f s, both at once %.1f s" % [
			float(_row.exposed) / n, float(_row.in_sight) / n, float(_row.both) / n])
	var closest: Array = _row.closest
	closest.sort()
	var near := closest.filter(func(d: float) -> bool: return d < 2.0).size()
	print("  seekers: a hider in view %.1f s/round, %d chases, closest per chase median %.1f m, %d got within 2 m" % [float(_row.in_view) / n, _row.chases,
			float(closest[closest.size() / 2]) if not closest.is_empty() else -1.0, near])


func _on_caught(hider: FishController, how: String, by: FishController, _game: MarcoPoloMatch) -> void:
	if how == "out_of_water":
		_row.out_of_water += 1
		return
	if how != "tag":
		return
	_row.tags += 1
	if float(_still.get(hider, 0.0)) >= SETTLED:
		_row.settled_found += 1
	if is_instance_valid(by) and _game.is_whale(by):
		var sight := _game.whale_sees(by, hider) > 0.0
		var streak := false
		for head in _game.streak_heads_of(by):
			if (head.pos as Vector3).distance_to(hider.global_position) <= 12.0:
				streak = true
		var key := "sight+streak" if sight and streak else ("sight only" if sight else ("streak only" if streak else "neither"))
		_row.split[key] = int(_row.split.get(key, 0)) + 1
	if is_instance_valid(by):
		var saw := _time - float(_seen_at.get([by, hider], -INF)) <= BLIND_WINDOW
		var heard := false
		for entry: Array in _ping_log:
			if entry[1] == by and _time - float(entry[0]) <= BLIND_WINDOW and (entry[2] as Vector3).distance_to(hider.global_position) <= BLIND_PING_RANGE:
				heard = true
				break
		if not saw and not heard:
			_row.blind += 1


## Per tick: who's still, what each seeker sees, new Fake Fish.
func _watch(game: MarcoPoloMatch, delta: float) -> void:
	_time += delta
	if game.phase != MarcoPoloMatch.Phase.LIVE:
		return
	for hider in game.live_hiders():
		var v := hider.linear_velocity
		var was := float(_still.get(hider, 0.0))
		var now := was + delta if Vector2(v.x, v.z).length() < mp.still_speed else 0.0
		if was < SETTLED and now >= SETTLED and not game.is_hidden(hider):
			_settles += 1
		_still[hider] = now
		for seeker in game.seekers():
			if game.exposure(seeker, hider) >= mp.layer_skeleton:
				_seen_at[[seeker, hider]] = _time
	for seeker in game.seekers():
		var exposed := false
		var sighted := false
		var both := false
		for hider in game.live_hiders():
			var e := game.exposure(seeker, hider) >= mp.layer_skeleton
			var s := game.in_sight(seeker, hider)
			exposed = exposed or e
			sighted = sighted or s
			both = both or (e and s)
		_row.exposed += delta if exposed else 0.0
		_row.in_sight += delta if sighted else 0.0
		_row.both += delta if both else 0.0
		var bot: MarcoPoloBot = _pilots.get(seeker)
		if bot == null:
			continue
		var chasing := is_instance_valid(bot._target)
		if chasing:
			_row.in_view += delta
			var d := seeker.global_position.distance_to(bot._target.global_position)
			_chase_closest[seeker] = minf(float(_chase_closest.get(seeker, INF)), d)
		elif _chase_closest.has(seeker):
			(_row.closest as Array).append(float(_chase_closest[seeker]))
			_row.chases += 1
			_chase_closest.erase(seeker)
	for fake in game.decoys():
		if not _fakes_seen.has(fake):
			_fakes_seen[fake] = true
			_row.fakes += 1
	while not _ping_log.is_empty() and _time - float(_ping_log[0][0]) > BLIND_WINDOW:
		_ping_log.pop_front()


func _until(done: Callable, seconds: float, game: MarcoPoloMatch) -> void:
	for i in roundi(seconds * TICKS):
		if done.call():
			return
		await get_tree().physics_frame
		_watch(game, 1.0 / TICKS)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
