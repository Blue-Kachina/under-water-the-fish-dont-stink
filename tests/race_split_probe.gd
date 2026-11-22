extends Node
## Split-screen Fin-ish Line (planning_race.md §11): 2, 3 and 4 local players in one race, in a 1080p window. Each gets
## their own view, camera and RaceHud; every person is a racer on the grid (taking a bot's seat once the field is full),
## places are distinct, a player leaving goes with their view and racer, and the race still runs.
##   Godot_console.exe --headless --path . res://tests/race_split_probe.tscn

var failures := 0


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred(main)


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run(main: Node) -> void:
	var settings := RaceSettings.shared()
	settings.field_size = 6
	settings.laps = 1
	settings.countdown = 0.5
	main.set_mode(RaceMatch.ID)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(10)
	var game := main.active_mode() as RaceMatch
	check(game != null and game.authority, "a Race match is on")
	if game == null:
		_finish()
		return
	var local: LocalCoop = main._local
	var pads := [11, 12, 13]
	for players in [2, 3, 4]:
		local.join(pads[players - 2])
		await _ticks(10)
		print("split_probe: %d players" % players)
		check(local.count() == players and game.racers.size() == maxi(settings.field_size, players), "%d local players, %d racers" % [local.count(), game.racers.size()])
		var humans := game.racers.filter(func(r: RaceMatch.Racer) -> bool: return r.human)
		check(humans.size() == players, "every person is a racer (%d)" % humans.size())
		var split: SplitScreen = main.get_node_or_null("SplitScreen")
		check(split != null and split.count() == players, "%d views" % players)
		for slot: PlayerSlot in local.slots:
			var hud := slot.hud as Node
			var mode_hud: Variant = hud.get("mode_hud")
			check(mode_hud is RaceHud and (mode_hud as RaceHud).fish == slot.fish, "slot %d: its own RaceHud" % slot.index)
			check(slot.camera.fish == slot.fish and is_instance_valid(slot.camera) and slot.camera.get_viewport() != main.get_viewport(),
					"slot %d: its own camera in its own view" % slot.index)
		var origins := {}
		for slot: PlayerSlot in local.slots:
			origins[slot.fish.global_position.snappedf(0.5)] = true
		check(origins.size() == players, "everyone on their own grid slot")
	print("split_probe: the race runs")
	await _seconds(2.0)
	check(game.phase == RaceMatch.Phase.RACING, "GO: racing")
	var seen := {}
	for slot: PlayerSlot in local.slots:
		var place := game.position_of(slot.fish)
		check(place >= 1 and not seen.has(place), "slot %d: place %d, distinct" % [slot.index, place])
		seen[place] = true
	for slot: PlayerSlot in local.slots:
		check(slot.fish.global_position.distance_to(slot.camera.global_position) < 60.0, "slot %d's camera is near its fish (%.1f m)" % [
				slot.index, slot.fish.global_position.distance_to(slot.camera.global_position)])
	print("split_probe: leaving")
	local.leave(local.slots[3])
	await _ticks(10)
	check(local.count() == 3 and game.racers.filter(func(r: RaceMatch.Racer) -> bool: return r.human).size() == 3, "a player left: three people racing")
	var split: SplitScreen = main.get_node_or_null("SplitScreen")
	check(split != null and split.count() == 3, "three views")
	await _seconds(1.0)
	_finish()


func _finish() -> void:
	print("race_split_probe: %s" % ("ok" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _ticks(roundi(s * 120.0))
