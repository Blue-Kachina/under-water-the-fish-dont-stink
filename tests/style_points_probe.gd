extends Node
## Hunt's style points (StylePoints), with the two fish held still and moved
## by hand through scripted passes: a fast near miss is a close call for the
## fish passed, a dodge if it turned away (or dodged) as it came; a wide pass
## or a slow one scores nothing, nor does a pass that ends in a battery;
## a fish scores at most once per cooldown; every fourth perfect stride in a
## row scores, and a mistimed one starts the count again.
##   Godot_console.exe --headless --path . res://tests/style_points_probe.tscn

const STEP := 1.0 / 120.0

var main: Node
var fish: FishController
var failures := 0
var hunt: HuntMatch
var style: StylePoints
var opponent: FishController
var awards: Array = []


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
	main.set_mode(main.HUNT)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(5)
	hunt = main.hunt_match
	style = hunt.style
	opponent = hunt.opponent
	# The match and bot stand by: this probe moves the fish and runs the points itself.
	hunt.process_mode = Node.PROCESS_MODE_DISABLED
	for f: FishController in [fish, opponent]:
		f.freeze = true
		f.controls_locked = true
	await _ticks(2)
	style.reset()
	style.live = true
	style.batter_speed = 10.0
	style.awarded.connect(func(index: int, type: String, points: int, _extra: Dictionary) -> void: awards.append([index, type, points]))

	print("close call:")
	await _pass(1.5, 15.0)
	check(_only(0, StylePoints.CLOSE_CALL), "a fast miss at 1.5 m is a close call for the fish passed %s" % [awards])
	check(style.points[0] == StylePoints.POINTS[StylePoints.CLOSE_CALL] and style.points[1] == 0, "+%d to it, nothing to the other" % StylePoints.POINTS[StylePoints.CLOSE_CALL])

	print("cooldown:")
	await _pass(1.5, 15.0)
	check(awards.is_empty(), "another straight after scores nothing %s" % [awards])
	_cool_down()

	print("dodge (turn):")
	await _pass(1.5, 15.0, 50.0)
	check(_only(0, StylePoints.DODGE), "turning 50 degrees away as it comes is a dodge %s" % [awards])
	check(style.counts[0].dodges == 1 and style.counts[0].close_calls == 1, "counted as one (and the close call before)")
	_cool_down()

	print("dodge (button):")
	await _pass(1.5, 15.0, 0.0, true)
	check(_only(0, StylePoints.DODGE), "a dodge as it comes is a dodge too %s" % [awards])
	_cool_down()

	print("nothing:")
	await _pass(5.0, 15.0)
	check(awards.is_empty(), "a pass 5 m wide scores nothing %s" % [awards])
	await _pass(1.5, 6.0)
	check(awards.is_empty(), "a slow pass (6 m/s) scores nothing %s" % [awards])

	print("battery:")
	style.points = [0, 0]
	await _pass(0.05, 15.0, 0.0, false, true)
	check(awards.size() == 1 and awards[0] == [1, StylePoints.BATTERY, StylePoints.POINTS[StylePoints.BATTERY]],
			"a pass that ends in a battery: the battery's points, no close call %s" % [awards])
	_cool_down()

	print("perfect rhythm:")
	style.points = [0, 0]
	for i in 3:
		fish.strode.emit(0.95, 0.5)
	check(awards.is_empty() and style.streaks[0] == 3, "three perfect strides: not yet")
	fish.strode.emit(0.9, 0.5)
	check(_only(0, StylePoints.PERFECT_RHYTHM) and style.points[0] == StylePoints.POINTS[StylePoints.PERFECT_RHYTHM],
			"the fourth in a row scores +%d" % StylePoints.POINTS[StylePoints.PERFECT_RHYTHM])
	fish.strode.emit(0.4, 0.5)
	check(style.streaks[0] == 0 and style.counts[0].best_streak == 4, "a late one starts the count again (best run 4)")
	awards.clear()
	for i in 4:
		opponent.strode.emit(1.0, 0.5)
	check(_only(1, StylePoints.PERFECT_RHYTHM), "the opponent's count is its own")
	style.live = false
	awards.clear()
	for i in 4:
		fish.strode.emit(1.0, 0.5)
	check(awards.is_empty(), "nothing scores between plays")

	print("style_points_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## The opponent swims past the player at `speed` (m/s), its hitbox `miss` (m)
## to one side of the player's at the closest, from 10 m before to 10 m after.
## `turn`: the player turns this far (degrees) away over the pass. `press`: it
## dodges as the opponent closes in. `battery`: the opponent batters it when
## it as it touches instead of passing.
func _pass(miss: float, speed: float, turn := 0.0, press := false, batter := false) -> void:
	awards.clear()
	var at := hunt.center + Vector3(0.0, 20.0, 0.0)
	fish.global_transform = Transform3D(Basis.IDENTITY, at)  # nose to -Z
	var half_widths := ((fish.get_node("Collision").shape as BoxShape3D).size.x + (opponent.get_node("Collision").shape as BoxShape3D).size.x) / 2.0
	var lane := at + Vector3.RIGHT * (half_widths + miss)
	opponent.speed = speed
	style._lagged = [Vector3.FORWARD, Vector3.FORWARD]  # both have been heading this way a while
	var travelled := -10.0
	var turned := 0.0
	while travelled <= 10.0:
		# Coming up from behind (+Z) and on past, nose to -Z.
		opponent.global_transform = Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP), lane + Vector3.BACK * -travelled)
		if turn > 0.0 and travelled > -6.0 and turned < turn:
			turned = minf(turned + 400.0 * STEP, turn)
			fish.global_basis = Basis(Vector3.UP, deg_to_rad(turned))
		if batter and StylePoints.gap(opponent, fish) < 0.1:
			style.on_battery(1, 0)
			fish.battered = true
			style.update(STEP)
			fish.battered = false
			break
		style.update(STEP)
		travelled = snappedf(travelled + speed * STEP, 0.0001)
		if press and travelled > -4.0 and travelled - speed * STEP <= -4.0:
			fish.dodged.emit(Vector3.LEFT)
	await _ticks(1)


## Lets the award cooldown run out.
func _cool_down() -> void:
	style.live = false
	for i in roundi(StylePoints.AWARD_COOLDOWN / STEP) + 2:
		style.update(STEP)
	style.live = true
	awards.clear()


## Exactly one award: `type` to `index`.
func _only(index: int, type: String) -> bool:
	return awards.size() == 1 and awards[0][0] == index and awards[0][1] == type


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
