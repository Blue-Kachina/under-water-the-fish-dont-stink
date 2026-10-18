extends Node
## Sound effects, phase 2 (planning_audio.md §4): Battered, Nature and Hunt.
## A 1v1's and a Hunt's batteries (ram landed, ram taken, Fish Fry, the victim
## going out), Hunt's lock-on, catch and getaway, Hunt's match flow; Nature's
## batteries, pearls (drop, streak up the scale), multis and sprees, schools
## nearby and startled, the lone fish turning up, and the target wheel. Listens
## to Sfx.requested, so it works whatever profile is picked.
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/audio_hooks2_probe.tscn

const TICK := 1.0 / 120.0

var main: Node
var fish: FishController
var failures := 0
var heard: Array[String] = []


func _ready() -> void:
	Sfx.requested.connect(func(id: String) -> void: heard.append(id))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	await _nature()
	await _hunt()
	await _one_v_one()
	await _wheel()
	print("audio_hooks2_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


func _nature() -> void:
	print("nature:")
	var settings := NatureSettings.shared()
	main.set_mode(main.NATURE)
	await _seconds(0.05)
	settings.lone_target = true
	settings.school_count = 1
	settings.school_speed = 0.0
	settings.pearl_chance = 1.0
	settings.bait_rate = 0.0
	main._match_card.play_requested.emit()
	await _seconds(0.1)
	var run: NatureRun = main.nature_run
	check(run.get_node_or_null("Sounds") is NatureSounds, "the run has its NatureSounds")
	var school: School = run.schools[0]
	school.alarm = 0.0
	heard.clear()
	await _seconds(0.6)
	var far := school.middle().distance_to(fish.global_position)
	print("  (info) the first school is %.0f m away" % far)
	check(heard.has("nature/school_loop") == (far < NatureSounds.LOOP_RANGE), "a school in earshot has its loop, one far off doesn't")
	school.alarm = 1.0
	school.global_position = school.global_position  # (alarm is read next tick)
	heard.clear()
	await _seconds(0.5)
	check(heard.has("nature/school_scatter"), "a startled school scatters")

	heard.clear()
	var key := "s%d:0" % school.id
	run.confirm_battery(key, fish, 1)
	check(heard.has("nature/battery"), "a school fish battered")
	check(heard.has("nature/pearl_drop"), "and its pearl drops")
	heard.clear()
	run.battered.emit(fish, run.target)
	check(heard.has("nature/battery"), "the lone fish battered")
	heard.clear()
	run.fish_teleported.emit(run.target)
	run.fish_teleported.emit(fish)
	check(heard.count("nature/target_respawn") == 1, "the lone fish turning up (not the players' own moves)")

	heard.clear()
	var score := run.score_of(fish)
	score.on_battery()
	check(not heard.has("battered/fish_fry") and not heard.has("nature/style"), "a plain battery: just its battery sound")
	score.on_battery()
	check(heard.has("battered/fish_fry") and heard.has("voice/fish_fry") and heard.has("nature/style"), "a double: Fish Fry")
	heard.clear()
	score.on_battery()
	check(heard.has("battered/fish_fry_more") and not heard.has("battered/fish_fry"), "a triple: it climbs")

	heard.clear()
	for i in 4:
		run.pearl_collected.emit(fish)
		await _seconds(0.1)
	check(heard.count("nature/pearl") == 4, "pearls collected (%d)" % heard.count("nature/pearl"))
	await _seconds(NatureSounds.STREAK_WINDOW + 0.2)
	heard.clear()
	run.pearl_collected.emit(fish)
	check(heard.count("nature/pearl") == 1, "and one after a pause starts again")
	main.set_mode(main.FREE_PLAY)
	await _seconds(0.3)


func _hunt() -> void:
	print("hunt:")
	main.set_mode(main.HUNT)
	await _seconds(0.05)
	heard.clear()
	main._match_card.play_requested.emit()
	await _seconds(0.1)
	var hunt: HuntMatch = main.hunt_match
	check(hunt.get_node_or_null("Sounds") is MatchSounds and hunt.get_node_or_null("BatteredSounds") is BatteredSounds,
			"the Hunt has its MatchSounds and BatteredSounds")
	hunt.bot.process_mode = Node.PROCESS_MODE_DISABLED
	hunt.bot.input.clear()
	await _seconds(HuntMatch.COUNTDOWN_TIME + 0.3)
	check(heard.count("match/countdown") == 3 and heard.has("match/go"), "3, 2, 1, GO")
	heard.clear()
	hunt.last_battery = {"speed": 40.0}
	hunt.battered.emit(fish, hunt.opponent)
	check(heard.has("battered/battery") and not heard.has("battered/battered"), "you batter the hunter")
	check(not heard.has("hunt/caught"), "and aren't caught")
	await _seconds(BatteredSounds.OUT_DELAY + 0.1)
	check(heard.has("battered/out"), "it goes out a moment later")
	heard.clear()
	hunt.battered.emit(hunt.opponent, fish)
	check(heard.has("battered/battered") and heard.has("hunt/caught"), "the hunter batters you: battered, caught")
	await _seconds(BatteredSounds.OUT_DELAY + 0.1)
	heard.clear()
	hunt.battered.emit(null, null)
	await _seconds(BatteredSounds.OUT_DELAY + 0.1)
	check(heard.has("battered/fish_fry") and heard.has("voice/fish_fry") and heard.count("battered/out") == 2, "a Fish Fry: both go out")
	heard.clear()
	hunt.stat_event.emit({"type": StylePoints.DODGE, "player": 0, "title": "DODGE", "points": 50, "team": 0})
	hunt.stat_event.emit({"type": StylePoints.CLOSE_CALL, "player": 1, "title": "CLOSE CALL", "points": 25, "team": 1})
	check(heard.count("hunt/escaped") == 1, "your dodge is a getaway, the hunter's isn't")
	# The hunter coming at you.
	hunt.phase = HuntMatch.Phase.LIVE
	hunt.style.live = true
	var at := hunt.center + Vector3(0.0, 10.0, 0.0)
	fish.global_transform = Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP), at)
	fish.linear_velocity = Vector3.ZERO
	hunt.opponent.global_transform = Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), at + Vector3(0.4, 0.0, -5.0))
	hunt.opponent.linear_velocity = Vector3.BACK * 30.0
	hunt.opponent.speed = 30.0
	heard.clear()
	await _seconds(0.1)
	check(hunt.style.is_threatened(0) and heard.has("hunt/target_spotted"), "the hunter locking on (threatened %s)" % hunt.style.is_threatened(0))
	main.set_mode(main.FREE_PLAY)
	await _seconds(0.3)


func _one_v_one() -> void:
	print("1v1:")
	main.set_environment("Aquarium Arena")
	main.set_mode(main.ONE_V_ONE)
	main.play_match()
	var game: Match1v1 = main.match_1v1
	game.goal_replays = false
	await _seconds(0.1)
	check(game.get_node_or_null("BatteredSounds") is BatteredSounds, "the match has its BatteredSounds")
	heard.clear()
	game.battered.emit(fish, game.bot_fish)
	check(heard.has("battered/battery"), "you batter the bot")
	heard.clear()
	game.battered.emit(game.bot_fish, fish)
	check(heard.has("battered/battered"), "the bot batters you")
	main.set_mode(main.FREE_PLAY)
	await _seconds(0.3)


func _wheel() -> void:
	print("target wheel:")
	var wheel := TargetWheel.new()
	add_child(wheel)
	await _seconds(0.1)
	check(wheel.get_node_or_null("Sounds") is WheelSounds, "the wheel has its WheelSounds")
	var a := Node3D.new()
	var b := Node3D.new()
	add_child(a)
	add_child(b)
	wheel.is_open = true
	wheel.picked = [a, "a", 1]
	await _seconds(0.05)
	heard.clear()
	wheel.picked = [b, "b", 1]
	await _seconds(0.05)
	check(heard == ["nature/target_cycle"], "stick onto another slice: a tick %s" % [heard])
	heard.clear()
	wheel.is_open = false
	await _seconds(0.05)
	check(heard == ["nature/target_lock"], "letting go: it locks %s" % [heard])
	wheel.queue_free()
	a.queue_free()
	b.queue_free()


func _seconds(time: float) -> void:
	for i in roundi(time / TICK):
		await get_tree().physics_frame
