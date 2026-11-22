extends Node
## Bots stay in the water: in What Stinks?, Hunt and Nature (their floors on) with bots playing, no bot fish (and no
## school fish) ends up under the seabed's floor or inside its rock, sampled through a stretch of play.
##   Godot_console.exe --headless --path . res://tests/bot_floor_probe.tscn

var main: Node
var failures := 0
## How far under the floor (m) or into the rock still counts as touching it (a fish's own radius sits low).
const SLACK := 1.0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _run() -> void:
	await _what_stinks()
	await _hunt()
	await _nature()
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


## Worst depth under the floor and into the rock over `ticks`, for `fishes()` and the schools' fish.
func _watch(label: String, fishes: Callable, schools: Callable, flat_y: float, ticks: int) -> void:
	var worst_under := -INF
	var worst_rock := INF
	var worst_school_under := -INF
	var who := ""
	var bad_samples := 0
	var samples := 0
	for t in ticks:
		await get_tree().physics_frame
		if t % 30 != 0:
			continue
		for fish: FishController in fishes.call():
			if not is_instance_valid(fish) or not fish.visible:
				continue
			var p := fish.global_position
			var under := Terrain.floor_y(p.x, p.z, flat_y) - p.y
			var rock := Terrain.sdf(p)
			samples += 1
			if under > SLACK or rock < -SLACK:
				bad_samples += 1
			if under > worst_under:
				worst_under = under
				who = "%s at %s (frozen %s, layers %d/%d)" % [fish.name, p.snapped(Vector3.ONE * 0.1), fish.freeze, fish.collision_layer, fish.collision_mask]
			worst_rock = minf(worst_rock, rock)
		for school: School in schools.call():
			if not is_instance_valid(school):
				continue
			for i in school.fish_count():
				if not school.is_alive(i):
					continue
				var q := school.fish_position(i)
				worst_school_under = maxf(worst_school_under, Terrain.floor_y(q.x, q.z, flat_y) - q.y)
	print("  %s: worst under floor %.1f m (%s), deepest in rock %.1f m, bad samples %d of %d, school fish worst under %.1f m" %
			[label, worst_under, who, -worst_rock, bad_samples, samples, worst_school_under])
	check(worst_under <= SLACK, "%s: bots stay above the floor" % label)
	check(worst_rock >= -SLACK, "%s: bots stay out of the rock" % label)
	check(worst_school_under <= SLACK, "%s: school fish stay above the floor" % label)


func _what_stinks() -> void:
	print("what stinks:")
	main.set_mode(main.WHAT_STINKS)
	await _frames(3)
	var settings := WhatStinksSettings.shared()
	settings.min_players = 6
	settings.hide_time = 8.0
	settings.round_time = 600.0
	main.play_match()
	await _frames(5)
	var game: WhatStinksMatch = main.what_stinks
	game.bots[main.get_node("Fish")] = null
	game.start_round(0)
	await _frames(3)
	check(game.seabed != null, "the match has a seabed")
	var flat_y := game.center.y - settings.floor_depth
	await _watch("what stinks", func() -> Array: return game.players, func() -> Array: return game.field.schools, flat_y, 120 * 90)
	main.set_mode(main.FREE_SWIM)
	await _frames(3)


## Hunt's floor is off by default: on here, so its bot has one to stay over.
func _hunt() -> void:
	print("hunt:")
	var hunt_settings := HuntSettings.shared()
	var was_on := hunt_settings.floor_enabled
	main.set_mode(main.HUNT)
	await _frames(3)
	hunt_settings.floor_enabled = true
	main._match_card.play_requested.emit()
	await _frames(5)
	var hunt: HuntMatch = main.hunt_match
	check(hunt.seabed != null, "the match has a seabed")
	var flat_y := hunt.center.y - hunt_settings.floor_depth
	await _watch("hunt", func() -> Array: return [hunt.opponent], func() -> Array: return [], flat_y, 120 * 60)
	main.set_mode(main.FREE_SWIM)
	await _frames(3)
	hunt_settings.floor_enabled = was_on


## Nature's floor is off by default: on and shallow here, so its schools and lone fish reach it.
func _nature() -> void:
	print("nature:")
	var settings := NatureSettings.shared()
	var was_on := settings.nature_floor
	var was_depth := settings.nature_floor_depth
	main.set_mode(main.NATURE)
	await _frames(3)
	settings.nature_floor = true
	settings.nature_floor_depth = 12.0
	main._match_card.play_requested.emit()
	await _frames(5)
	var run: NatureRun = main.nature_run
	check(run.floor_y > -INF, "the run has a floor")
	await _watch("nature", func() -> Array: return [run.target], func() -> Array: return run.schools, run.floor_y, 120 * 45)
	main.set_mode(main.FREE_SWIM)
	await _frames(3)
	settings.nature_floor = was_on
	settings.nature_floor_depth = was_depth
