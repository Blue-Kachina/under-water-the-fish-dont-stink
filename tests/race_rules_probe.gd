extends Node
## Race rules (planning_race.md probes): swimming the wrong way shows WRONG WAY and then rescues; out of bounds
## rescues; standing still (stuck) rescues; a rescued racer is back at its last gate facing along the track; the finish
## clock starts when the first human finishes; whoever hasn't finished is placed by progress.
##   Godot_console.exe --headless --path . res://tests/race_rules_probe.tscn

const KIT := preload("res://tests/race_probe_kit.gd")

var main: Node
var failures := 0
var race: RaceMatch
var rescues: Array[String] = []


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	race = await KIT.start(self, main, 1, 3)
	if race == null:
		check(false, "the race mode starts")
		get_tree().quit(1)
		return
	var rs := race.settings
	rs.race_wrong_way_time = 2.0
	rs.wrong_way_banner = 0.5
	rs.race_oob_time = 0.5
	rs.stuck_time = 1.5
	rs.rescue_fade = 0.1
	rs.rescue_cooldown = 0.0
	race.rescued.connect(func(fish: FishController, reason: String) -> void:
		rescues.append("%s:%s" % [fish.name, reason]))
	await _until_racing()
	await _wrong_way()
	await _out_of_bounds()
	await _stuck()
	await _finish_clock()
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _until_racing() -> void:
	var guard := 0
	while race.phase != RaceMatch.Phase.RACING and guard < 600:
		await get_tree().physics_frame
		guard += 1
	await KIT.frames(self, 30)


## Every racer but `except` carries on driving the line (the ones under test are driven by hand).
func _drive_others(except: Array, throttle := 1.0) -> void:
	for r in race.racers:
		if r not in except:
			KIT.drive(race, r, throttle)


func _wrong_way() -> void:
	print("wrong way:")
	var r: RaceMatch.Racer = race.racers[1]
	KIT.place(race, r, 60.0, true)
	var before := rescues.size()
	var banner_seen := false
	var ticks := 0
	while rescues.size() == before and ticks < 600:
		_drive_others([r])
		(r.fish.controls as FishInput).forward = 1.0
		(r.fish.controls as FishInput).stick = Vector2.ZERO
		await get_tree().physics_frame
		ticks += 1
		if r.banner == "WRONG WAY" and r.banner_left > 0.0:
			banner_seen = true
	check(banner_seen, "WRONG WAY shows after wrong_way_banner s")
	check(rescues.size() > before and rescues[-1].ends_with(":wrong way"), "rescued for the wrong way (%s) after %.1f s" % [rescues[-1] if not rescues.is_empty() else "none", ticks / 60.0])
	await _after_rescue(r)


func _out_of_bounds() -> void:
	print("out of bounds:")
	race.arena.soft_walls = false  # nothing leans it back in
	var r: RaceMatch.Racer = race.racers[2]
	KIT.place(race, r, 150.0, false, 70.0)
	var before := rescues.size()
	var ticks := 0
	while rescues.size() == before and ticks < 600:
		_drive_others([r])
		var input := r.fish.controls as FishInput
		input.clear()
		await get_tree().physics_frame
		ticks += 1
	check(rescues.size() > before and rescues[-1].ends_with(":out of bounds"), "rescued for leaving the channel (%s) after %.1f s" % [rescues[-1] if not rescues.is_empty() else "none", ticks / 60.0])
	race.arena.soft_walls = true
	await _after_rescue(r)


func _stuck() -> void:
	print("stuck:")
	var r: RaceMatch.Racer = race.racers[2]
	var before := rescues.size()
	var ticks := 0
	while rescues.size() == before and ticks < 1500:
		_drive_others([r])
		(r.fish.controls as FishInput).clear()
		await get_tree().physics_frame
		ticks += 1
	check(rescues.size() > before and rescues[-1].ends_with(":stuck"), "rescued for being stuck (%s) after %.1f s" % [rescues[-1] if not rescues.is_empty() else "none", ticks / 60.0])
	await _after_rescue(r)


## A rescued racer ends up on its last gate, facing along the track, swimming again.
func _after_rescue(r: RaceMatch.Racer) -> void:
	var guard := 0
	while r.rescue_stage != 0 and guard < 120:
		_drive_others([r])
		await get_tree().physics_frame
		guard += 1
	await KIT.frames(self, 6)
	var fix := race.track.nearest(r.fish.global_position, r.d)
	var gate := (r.next_cp - 1 + race.track.checkpoints.size()) % race.track.checkpoints.size() if r.started else 0
	var gate_d := float(race.track.checkpoints[gate]["d"])
	check(absf(race.track.delta(gate_d, fix.d)) < 8.0, "back at gate %d (%.1f m from it)" % [gate, race.track.delta(gate_d, fix.d)])
	check((-r.fish.global_basis.z).dot(fix.forward) > 0.8, "facing along the track")
	check(r.rescue_stage == 0, "the rescue is over")


func _finish_clock() -> void:
	print("finish clock and places:")
	race.settings.finish_clock = 3.0
	race.restart()
	await _until_racing()
	var human: RaceMatch.Racer = race.racers[0]
	var slow: RaceMatch.Racer = race.racers[1]
	slow.human = true  # a second human who is still swimming: the 3 s clock (not "everyone is home") ends the race
	var still: RaceMatch.Racer = race.racers[2]
	var ticks := 0
	var finished_at := -1.0
	while race.phase != RaceMatch.Phase.OVER and ticks < 20000:
		KIT.drive(race, human, 1.0)
		KIT.drive(race, slow, 0.35)
		(still.fish.controls as FishInput).clear()
		await get_tree().physics_frame
		ticks += 1
		if finished_at < 0.0 and human.finished:
			finished_at = race.race_time
	check(human.finished, "the human finished (%.1f s)" % human.finish_time)
	check(race.phase == RaceMatch.Phase.OVER, "the race is over")
	check(finished_at > 0.0 and absf(race.race_time - finished_at - 3.0) < 0.4, "it ended %.1f s after the first human finished (clock 3 s)" % (race.race_time - finished_at))
	check(race.results.size() == 3 and int(race.results[0]["place"]) == 1 and bool(race.results[0]["human"]), "the human won")
	check(not slow.finished and not still.finished, "the others did not finish")
	var by_progress := slow.progress >= still.progress
	check(by_progress == (slow.place < still.place), "the others are placed by progress (slow %.0f m: place %d, still %.0f m: place %d)" % [slow.progress, slow.place, still.progress, still.place])
