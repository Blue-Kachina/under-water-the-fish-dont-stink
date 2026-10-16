extends Node
## HunterBot (Hunt's opponent, Basic): it gets up to demolition speed from a
## standstill on its own strides alone (it only writes its FishInput), its
## stride timing is loose but far from mashing, it demolishes a player sitting
## still, and set to always evade it gets out of the way of straight rams that
## catch it when it never evades.
##   Godot_console.exe --headless --path . res://tests/hunter_bot_probe.tscn

var main: Node
var fish: FishController
var failures := 0
var timings: Array[float] = []
## How fast the test's rams turn to follow the bot (rad/s).
const HOMING_RATE := 1.2


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	print("only inputs:")
	var source := FileAccess.get_file_as_string("res://scripts/hunter_bot.gd")
	var writes := RegEx.create_from_string("(linear_velocity|angular_velocity|global_position|global_transform)\\s*[-+*]?=|apply_(push|impulse|central|force|torque)")
	check(writes.search(source) == null, "the bot's script never moves its fish itself")

	main.set_mode(main.HUNT)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	var hunt: HuntMatch = main.hunt_match
	hunt.demo_replays = false
	var opponent := hunt.opponent
	var bot := hunt.bot
	check(opponent.controls == bot.input, "it drives its fish through its FishInput")
	opponent.strode.connect(func(timing: float, _flow: float) -> void:
		if timing >= 0.0:
			timings.append(timing))

	print("speed from strides:")
	await _go_live(hunt)
	# Out of its way: it swims after the player from far off.
	fish.freeze = true
	fish.global_position = hunt.center + Vector3(0.0, 0.0, 85.0)  # the far side of the arena
	var reached := -1.0
	var top := 0.0
	for i in 600:
		await get_tree().physics_frame
		top = maxf(top, opponent.speed)
		if reached < 0.0 and opponent.speed >= hunt.demo_speed():
			reached = i / 120.0
	check(reached >= 0.0 and reached < 4.0, "it reaches demolition speed (%.1f m/s) in %.2f s" % [hunt.demo_speed(), reached])
	check(top > opponent.max_speed + 2.0, "faster than throttle alone (%.1f m/s top, throttle caps at %.1f)" % [top, opponent.max_speed])
	check(timings.size() >= 10, "on strides (%d of them in 5 s)" % timings.size())
	var mean := 0.0
	var perfect := 0
	for t in timings:
		mean += t
		perfect += 1 if t >= SwishySwim.SWEET_SPOT else 0
	mean /= maxf(timings.size(), 1.0)
	check(mean > 0.55 and mean < 0.97, "loosely timed: %.2f on average, %d of %d perfect" % [mean, perfect, timings.size()])
	check(perfect > 0, "but some land on the peak")
	fish.freeze = false

	print("hunting:")
	main.reset_play()
	await _go_live(hunt)
	var scored_at := -1.0
	for i in 120 * 40:
		await get_tree().physics_frame
		fish.linear_velocity = Vector3.ZERO  # the player sits still where it kicked off
		if hunt.scores[1] > 0:
			scored_at = i / 120.0
			break
	check(scored_at >= 0.0, "it demolishes a player sitting still (after %.1f s)" % scored_at)

	print("evading:")
	var sharp := BotDifficulty.basic()
	sharp.reaction_time = 0.1  # the reaction itself, not how late it notices
	sharp.evade_chance = 1.0
	sharp.dodge_chance = 0.0
	var escapes_always := await _rams(hunt, sharp, 6)
	var never := BotDifficulty.basic()
	never.reaction_time = 0.1
	never.evade_chance = 0.0
	var escapes_never := await _rams(hunt, never, 6)
	check(escapes_always >= 3, "always evading, it escapes %d of 6 straight rams" % escapes_always)
	check(escapes_never <= 1, "never evading, it escapes %d of 6" % escapes_never)
	var dodger := sharp.duplicate()
	dodger.dodge_chance = 1.0
	var dodges := [0]
	opponent.dodged.connect(func(_direction: Vector3) -> void: dodges[0] += 1)
	await _rams(hunt, dodger, 2)
	check(dodges[0] > 0, "set to dodge, it dodges out of the way (%d dodges)" % dodges[0])

	print("hunter_bot_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## `trials` straight rams by the player from 20 m at 18 m/s at a bot playing
## `difficulty` swimming across at 12 m/s, aimed where it'd be if it carried
## straight on and homing in from there at HOMING_RATE. How many it escaped.
func _rams(hunt: HuntMatch, difficulty: BotDifficulty, trials: int) -> int:
	hunt.bot.difficulty = difficulty
	var escapes := 0
	for trial in trials:
		main.reset_play()
		await _go_live(hunt)
		var opponent := hunt.opponent
		var start := hunt.center + Vector3(0.0, 5.0, 0.0)
		# It swims across; the ram goes for where it'll be if it carries on.
		opponent.global_transform = Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP), start)
		opponent.linear_velocity = Vector3.RIGHT * 12.0
		var line := Vector3(0.3, 0.0, -1.0).normalized()
		var meet := start + Vector3.RIGHT * 12.0 * (20.0 / 18.0)
		var from := meet - line * 20.0
		fish.global_transform = Transform3D(Basis.looking_at(line, Vector3.UP), from)
		var scores_before := hunt.scores.duplicate()
		var heading := line
		for i in 240:
			# Homing in, but turning no faster than a fish at speed can.
			var want := (opponent.global_position - fish.global_position).normalized()
			var angle := heading.angle_to(want)
			if angle > 0.0001:
				heading = heading.slerp(want, minf(1.0, HOMING_RATE / 120.0 / angle)).normalized()
			fish.global_basis = Basis.looking_at(heading, Vector3.UP)
			fish.linear_velocity = heading * 18.0
			fish.angular_velocity = Vector3.ZERO
			await get_tree().physics_frame
			if hunt.phase != HuntMatch.Phase.LIVE:
				break
		if hunt.scores[0] == scores_before[0]:
			escapes += 1
	return escapes


## Through a kickoff's countdown to live play.
func _go_live(hunt: HuntMatch) -> void:
	for i in 1200:
		if hunt.phase == HuntMatch.Phase.LIVE:
			return
		await get_tree().physics_frame


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
