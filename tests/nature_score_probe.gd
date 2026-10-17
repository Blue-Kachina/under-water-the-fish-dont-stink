extends Node
## NatureScore on its own, with batteries fed in at chosen times: they chain
## into multis within the window and start again after it; each step scores as
## the settings say; a spree survives a gap while fast and ends after the grace
## time under the battering speed; milestones score and are named.
##   Godot_console.exe --headless --path . res://tests/nature_score_probe.tscn

var failures := 0
var events: Array = []


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	var settings := NatureSettings.new()
	var score := NatureScore.new(settings)
	score.awarded.connect(func(event: Dictionary) -> void: events.append(event))
	const FAST := 20.0
	const BATTER := 10.0

	print("multis:")
	score.on_battery()
	check(events[-1].type == NatureScore.BATTERY and events[-1].title == "BATTERED" and events[-1].points == 100, "one is a plain battery, +100")
	_wait(score, 2.0, FAST, BATTER)
	score.on_battery()
	check(events[-1].type == NatureScore.MULTI and events[-1].title == "DOUBLE DIP" and events[-1].points == 100 + 150, "another 2 s later: DOUBLE DIP, +100 +150")
	_wait(score, 1.0, FAST, BATTER)
	score.on_battery()
	check(events[-1].title == "TRIPLE FRY" and events[-1].points == 100 + 200, "then TRIPLE FRY, +100 +200")
	score.on_battery()
	score.on_battery()
	score.on_battery()
	check(events.filter(func(e: Dictionary) -> bool: return e.type != NatureScore.SPREE)[-1].title == "MONSTER CATCH" and score.chain == 6, "six in a row: MONSTER CATCH")
	score.on_battery()
	check(score.chain == 7 and events[-1].title == "MONSTER CATCH", "and it stays MONSTER CATCH past that")
	_wait(score, settings.multi_window + 0.1, FAST, BATTER)
	check(score.chain == 0, "past the window the chain is over")
	score.on_battery()
	check(events[-1].title == "BATTERED" and score.chain == 1, "the next starts again")
	check(score.best_chain == 7, "best chain kept (%d)" % score.best_chain)

	print("sprees:")
	var sprees := events.filter(func(e: Dictionary) -> bool: return e.type == NatureScore.SPREE)
	check(sprees.size() == 1 and sprees[0].title == "SPRING ROLL" and sprees[0].points == 250, "five batteries at speed: SPRING ROLL +250")
	check(score.spree == 8, "a gap while fast keeps the spree going (%d)" % score.spree)
	_wait(score, settings.spree_grace * 0.5, 3.0, BATTER)
	check(score.spree == 8, "slow for a moment: still going")
	_wait(score, settings.spree_grace, 3.0, BATTER)
	check(score.spree == 0, "slow past the grace time: over")
	events.clear()
	for i in 10:
		score.on_battery()
	sprees = events.filter(func(e: Dictionary) -> bool: return e.type == NatureScore.SPREE)
	check(sprees.size() == 2 and sprees[1].title == "RIPTIDE" and sprees[1].points == 500, "ten: SPRING ROLL then RIPTIDE +500")

	print("settings:")
	settings.points_scale = 2.0
	settings.multi_bonus = 0.0
	score.reset()
	events.clear()
	score.on_battery()
	score.on_battery()
	check(events[-1].points == 200 and score.points == 400, "points_scale doubles, multi_bonus 0 drops the bonus (%d)" % score.points)
	settings.multi_window = 0.5
	score.reset()
	score.on_battery()
	_wait(score, 0.6, FAST, BATTER)
	score.on_battery()
	check(score.chain == 1, "a shorter window breaks sooner")

	print("nature_score_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _wait(score: NatureScore, seconds: float, speed: float, batter_speed: float) -> void:
	var step := 1.0 / 120.0
	for i in roundi(seconds / step):
		score.update(step, speed, batter_speed)
