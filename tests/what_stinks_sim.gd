extends Node
## What Stinks? with bots only (what_stinks.md Phase 7, two-stage-attack.md Phase 6): every fish a
## bot (the player's too), a few rounds per form, variant and bite mode, and what happened. It
## REPORTS; it tunes nothing ([[playtest-before-tuning]]). Per run (form x variant x bite mode):
## - fish per bite (every landing, misses count as 0) and the share of bites that took something,
##   fish per minute of live round, how the fish were taken (bites, including a dash or an engulf; body rams);
## - Clean Sweep: Hunter win rate (every prey eaten before the clock) and round length; prey eaten per round;
## - Upset Stomach: Hunter win rate (the belly filled before the clock) and round length; spits and hurls per round;
## - the bots' echo and relocation work: Clicks, sniffs, prey relocations.
## Every run prints a ROW| line of JSON; --out=file also appends them for aggregation.
## Keep runs short ([[feedback-limit-analysis]]); a form x variant x mode cell is ~rounds x 1-3 minutes of game time:
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/what_stinks_sim.tscn
##       [-- --forms=all|drowned_shark,orca --variants=sweep,stomach --modes=hold,tap --rounds=3
##           --round_time=180 --players=5 --size=1.0 --out=path]

const TICKS := 120

var main: Node
var settings: WhatStinksSettings
var forms: Array[String] = []
var variants: Array[int] = [WhatStinksSettings.Variant.SWEEP, WhatStinksSettings.Variant.STOMACH]
var modes: Array[int] = [WhatStinksSettings.BiteMode.HOLD]
var rounds := 3
var round_time := 180.0
var players := 5
var size_mult := 1.0
var out_path := ""

var _row := {}
var _rammed_before := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=")
		if pair.size() != 2:
			continue
		match pair[0]:
			"forms":
				if pair[1] != "all":
					for key in pair[1].split(","):
						forms.append(key)
			"variants":
				variants.clear()
				for v in pair[1].split(","):
					variants.append(WhatStinksSettings.Variant.STOMACH if v.begins_with("stom") else WhatStinksSettings.Variant.SWEEP)
			"modes":
				modes.clear()
				for m in pair[1].split(","):
					modes.append(WhatStinksSettings.BiteMode.TAP if m == "tap" else WhatStinksSettings.BiteMode.HOLD)
			"rounds":
				rounds = int(pair[1])
			"round_time":
				round_time = float(pair[1])
			"players":
				players = int(pair[1])
			"size":
				size_mult = float(pair[1])
			"out":
				out_path = pair[1]
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	settings = WhatStinksSettings.shared()
	_run.call_deferred()


func _run() -> void:
	await _ticks(5)
	if forms.is_empty():
		forms.append_array(HunterForms.ready_keys())
	var started := Time.get_ticks_msec()
	print("what_stinks_sim: forms %s, variants %s, modes %s, %d rounds of up to %.0f s, %d fish, size %.2fx" % [
			str(forms), str(variants.map(func(v: int) -> String: return WhatStinksSettings.VARIANT_NAMES[v])),
			str(modes.map(func(m: int) -> String: return WhatStinksSettings.BiteMode.keys()[m])), rounds, round_time, players, size_mult])
	for form_key in forms:
		for variant in variants:
			for mode in modes:
				await _cell(form_key, variant, mode)
	print("what_stinks_sim: done in %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	get_tree().quit(0)


func _cell(form_key: String, variant: int, mode: int) -> void:
	var cell_started := Time.get_ticks_msec()
	if main.what_stinks:
		main.set_mode(main.FREE_SWIM)
		await _ticks(3)
	main.set_mode(main.WHAT_STINKS)  # entering a mode restores its saved tuning: the picks go in after
	await _ticks(3)
	settings.form = form_key
	settings.variant = variant
	settings.bite_mode = mode
	settings.round_time = round_time
	settings.round_over_time = 0.2
	settings.match_over_time = 600.0
	settings.min_players = players
	settings.rounds = rounds
	settings.start_as = WhatStinksSettings.StartAs.HUNTER
	HunterSize.shared().size_mult = size_mult
	if main._match_card:
		main.play_match()
	await _ticks(5)
	var game: WhatStinksMatch = main.what_stinks
	if game == null:
		print("%s: no match" % form_key)
		return
	var player: FishController = main.get_node("Fish")
	game.bots[player] = null  # the player's fish is a bot too: every turn is a bot's
	var tag := "%s / %s / %s" % [form_key, WhatStinksSettings.VARIANT_NAMES[variant], "tap" if mode == WhatStinksSettings.BiteMode.TAP else "hold"]
	_row = {"form": form_key, "variant": "sweep" if variant == WhatStinksSettings.Variant.SWEEP else "stomach",
			"mode": "tap" if mode == WhatStinksSettings.BiteMode.TAP else "hold", "size": size_mult,
			"rounds": 0, "wins": 0, "time": 0.0, "fish": 0, "bites": 0, "hits": 0, "rams": 0, "prey_eaten": 0, "spat": 0, "hurls": 0,
			"clicks": 0, "sniff_s": 0.0, "relocations": 0, "ends": {}, "lengths": [], "fish_list": []}
	var acc := [0]  # a lambda captures by value: the count lives in an array
	var on_bitten := func(_hunter: FishController, school_fish: int, prey: Array) -> void:
		acc[0] += school_fish + (0 if game.stomach() else prey.size())
	game.bitten.connect(on_bitten)
	game.eaten_fish.connect(func(_f: FishController, _by: FishController) -> void: _row.prey_eaten += 1)
	game.hurled.connect(func(_h: FishController) -> void: _row.hurls += 1)
	for index in rounds:
		_rammed_before = game.rammed_total
		acc[0] = 0
		game.start_round(index)
		for hunter in game.hunters:
			var bite: HunterBite = game.bites.get(hunter)
			if bite:
				bite.landed.connect(func(taken: int) -> void:
					_row.bites += 1
					if taken > 0:
						_row.hits += 1)
		await _until(func() -> bool: return game.phase == WhatStinksMatch.Phase.LIVE, settings.hide_time + 3.0)
		await _until(func() -> bool: return game.phase != WhatStinksMatch.Phase.LIVE, round_time + 5.0)
		var results := game.last_results
		var length := round_time - game.time_left
		var reason := str(results.get("reason", "?"))
		_row.rounds += 1
		_row.time += length
		_row.wins += 1 if bool(results.get("hunters_won", false)) else 0
		_row.spat += int(results.get("spat", 0))
		_row.rams += game.rammed_total - _rammed_before
		_row.fish += int(acc[0])
		(_row.lengths as Array).append(snappedf(length, 0.1))
		(_row.fish_list as Array).append(int(acc[0]))
		_row.ends[reason] = int(_row.ends.get(reason, 0)) + 1
		for bot: Variant in game.bots.values():
			if bot is WhatStinksBot:
				_row.clicks += (bot as WhatStinksBot).clicks
				_row.sniff_s += _sum(bot.scanned)
			elif bot is WhatStinksPreyBot:
				_row.relocations += (bot as WhatStinksPreyBot).relocations
		print("  %s round %d: %s in %.1f s, %d fish by bites, %d rams, %d spat (%s)" % [tag, index + 1,
				"Hunter won" if results.get("hunters_won", false) else "prey won", length, int(acc[0]), game.rammed_total - _rammed_before, int(results.get("spat", 0)), reason])
		game.phase = WhatStinksMatch.Phase.OVER  # hold it between rounds: the next start_round is ours
		game.phase_left = 1000.0
	game.bitten.disconnect(on_bitten)
	_report(tag, (Time.get_ticks_msec() - cell_started) / 1000.0)


func _sum(d: Dictionary) -> float:
	var total := 0.0
	for v: Variant in d.values():
		total += float(v)
	return total


func _report(tag: String, seconds: float) -> void:
	var n := maxi(int(_row.rounds), 1)
	var minutes := maxf(float(_row.time) / 60.0, 0.001)
	var bite_fish := maxi(int(_row.fish) - int(_row.rams), 0)
	print("%s (%.0f s wall): win %d of %d (%.0f%%), round %.1f s %s" % [tag, seconds, _row.wins, _row.rounds, 100.0 * _row.wins / n, float(_row.time) / n, str(_row.ends)])
	print("  %d bites (%d took something, %.0f%%): %.2f fish per bite; %.1f fish per minute (%d by bites, %d by rams of %d total)" % [
			_row.bites, _row.hits, 100.0 * _row.hits / maxi(int(_row.bites), 1), float(bite_fish) / maxi(int(_row.bites), 1), float(_row.fish) / minutes, bite_fish, _row.rams, _row.fish])
	print("  prey eaten %.2f/round, spat %.2f/round, hurls %d; clicks %d, sniffed %.0f s, prey relocations %d" % [
			float(_row.prey_eaten) / n, float(_row.spat) / n, _row.hurls, _row.clicks, _row.sniff_s, _row.relocations])
	print("ROW|%s" % JSON.stringify(_row))
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.READ_WRITE) if FileAccess.file_exists(out_path) else FileAccess.open(out_path, FileAccess.WRITE)
		if file:
			file.seek_end()
			file.store_line(JSON.stringify(_row))
			file.close()


func _until(done: Callable, seconds: float) -> void:
	for i in roundi(seconds * TICKS):
		if done.call():
			return
		await get_tree().physics_frame


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
