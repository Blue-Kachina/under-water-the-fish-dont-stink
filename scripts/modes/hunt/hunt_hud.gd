class_name HuntHud
extends ModeHud
## Hunt's HUD: the scorebug (both fish's goals, the clock, each fish's points),
## the BATTERED! / FISH FRY! / result splashes, the style-points feed, the
## battery replay overlay and the held scoreboard, all through hud.gd's slots.

## Hunt's scoreboard columns (as many as StatsBoard.HEADINGS).
## BATTERED FISH: fish battered (Battery; a battery being a beating).
const HUNT_HEADINGS := ["POINTS", "BATTERED FISH", "CLOSE", "DODGES", "PERFECT", "BEST RUN", "TOP KM/H"]

var hunt: HuntMatch
var _hud: Node


func _init(match_node: HuntMatch) -> void:
	hunt = match_node
	restart_hint = "restart match"
	camera_word = "fish"
	has_board = true
	shows_scorebug = true


func attach(hud: Node) -> void:
	_hud = hud
	hunt.battered.connect(_on_battered)
	hunt.battery_replay_started.connect(_on_battery_replay_started)
	hunt.battery_replay_ended.connect(hud.replay_overlay.stop)
	hunt.match_over.connect(_on_over)
	hunt.stat_event.connect(_on_event)


func live() -> bool:
	return is_instance_valid(hunt)


func replay_live() -> bool:
	return is_instance_valid(hunt) and hunt.phase == HuntMatch.Phase.REPLAY


func countdown_text() -> String:
	if hunt.phase == HuntMatch.Phase.COUNTDOWN:
		return str(ceili(hunt.countdown_left))
	return "GO!" if hunt.go_time_left > 0.0 else ""


func _on_battered(attacker: FishController, _victim: FishController) -> void:
	if attacker == null:
		_hud.splash.play("FISH FRY!", "Both battered  ·  nobody scores", "", BroadcastUI.GOLD, _hud.SPLASH_TIME)
		return
	var team := hunt._team_of(attacker)
	_hud.splash.play("BATTERED!", _hud.name_of(attacker), _hud.speed_text(hunt.last_battery.speed),
			AquariumArena.TEAM_COLORS[team], _hud.SPLASH_TIME)
	_hud.scorebug.flash(team)


## A style point: a line in the feed, in the scorer's team colour.
func _on_event(event: Dictionary) -> void:
	var who: String = _hud.name_of(hunt._fish_of(event.player))
	var text := "%s  +%d" % [event.title, event.points]
	if event.type == StylePoints.PERFECT_RHYTHM:
		text = "%s x%d  +%d" % [event.title, event.streak, event.points]
	if event.player != 0:
		text = "%s:  %s" % [who.to_upper(), text]
	var color: Color = AquariumArena.TEAM_COLORS[event.team]
	if event.player == 0:
		color = BroadcastUI.GOLD  # the player's own stand out
	_hud.feed_add(text, color)


func _on_battery_replay_started(battery_replay: GoalReplay) -> void:
	var battery := hunt.last_battery
	_hud.splash.hide_now()
	_hud.feed_clear()
	var speed: String = _hud.speed_text(battery.get("speed", 0.0))
	if battery.get("fish_fry", false):
		_hud.replay_overlay.start(battery_replay, _hud.name_of(hunt.player), _hud.name_of(hunt.opponent), speed,
				BroadcastUI.GOLD, "FISH FRY", "WITH")
		return
	var attacker: FishController = battery.get("attacker")
	var victim: FishController = battery.get("victim")
	_hud.replay_overlay.start(battery_replay, _hud.name_of(attacker) if is_instance_valid(attacker) else "",
			_hud.name_of(victim) if is_instance_valid(victim) else "", speed,
			AquariumArena.TEAM_COLORS[maxi(battery.get("team", 0), 0)], "BATTERED BY", "VICTIM")


func _on_over(winner: int) -> void:
	var winner_fish := hunt._fish_of(winner)
	var detail := "Final  %d - %d" % [hunt.scores[0], hunt.scores[1]]
	if hunt.won_on_points():
		detail += "    ·    on points  %d - %d" % [hunt.style.points[0], hunt.style.points[1]]
	_hud.splash.play("VICTORY!" if winner == 0 else "DEFEATED", "%s wins" % _hud.name_of(winner_fish), detail,
			AquariumArena.TEAM_COLORS[winner], _hud.RESULT_TIME)


func update_slots(hud: Node) -> void:
	var bug: Node = hud.scorebug
	bug.team_names = [hud.name_of(hunt.player).to_upper(), hud.name_of(hunt.opponent).to_upper()]
	bug.scores = hunt.scores.duplicate()
	bug.players = ["%d PTS" % hunt.style.points[0], "%d PTS" % hunt.style.points[1]]
	bug.clock_color = Color.WHITE
	if hunt.overtime:
		bug.clock = BroadcastUI.clock_text(hunt.overtime_elapsed, true)
		bug.clock_color = BroadcastUI.GOLD
	else:
		bug.clock = BroadcastUI.clock_text(hunt.clock_left)
	match hunt.phase:
		HuntMatch.Phase.REPLAY:
			bug.caption = "REPLAY"
		HuntMatch.Phase.OVER:
			bug.caption = "FINAL"
		_:
			bug.caption = "OVERTIME" if hunt.overtime else "HUNT"
	hud.course_text = ""


## Hunt's scoreboard: each fish's points and what they're made of, held up
## like the 1v1's, and by itself once the result's splash has been.
func update_board(hud: Node) -> void:
	var board: Node = hud.board
	var over := hunt.phase == HuntMatch.Phase.OVER
	var result_up: bool = over and hunt.over_left < HuntMatch.OVER_TIME - hud.RESULT_TIME
	board.shown = not is_instance_valid(hud.replay) and (Input.is_action_pressed("show_scoreboard") or result_up)
	if not board.shown:
		return
	board.headings = HUNT_HEADINGS
	board.title = "FINAL STATS" if over else "MATCH STATS"
	board.footer = "NEXT MATCH IN %d    ·    START / R: PLAY AGAIN" % ceili(hunt.over_left) if over else ""
	board.bars = [hud.share_bar("POINTS", hunt.style.points.map(func(p: int) -> float: return float(p)), false)]
	var teams := []
	for team in 2:
		var who := hunt._fish_of(team)
		var counts: Dictionary = hunt.style.counts[team]
		teams.append({
			"name": hud.name_of(who),
			"score": hunt.scores[team],
			"color": AquariumArena.TEAM_COLORS[team],
			"rows": [{"name": hud.name_of(who), "focus": who == hud.fish, "values": [
				hunt.style.points[team], counts.battered_fish, counts.close_calls, counts.dodges,
				counts.perfect, counts.best_streak, roundi(counts.top_speed * 3.6)]}],
		})
	board.teams = teams
