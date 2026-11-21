class_name OneVOneHud
extends ModeHud
## The 1v1's HUD: the scorebug (Blue and Orange, the clock, each fish's name),
## the 3-2-1 / GO! countdown, the BATTERED banner, the goal replay's overlay
## and player lists, the result splash and the held scoreboard, all through
## hud.gd's slots. (The GOAL! splash is the arena's, shared with Free Play, and
## stays in hud.gd.)

var game: Match1v1
var _hud: Node


func _init(match_node: Match1v1) -> void:
	game = match_node
	restart_hint = "restart kickoff"
	camera_word = "ball"
	has_board = true
	shows_scorebug = true


func attach(hud: Node) -> void:
	_hud = hud
	game.battered.connect(_on_battered)
	game.goal_replay_started.connect(_on_goal_replay_started)
	game.goal_replay_ended.connect(hud.replay_overlay.stop)
	game.match_over.connect(_on_match_over)


func live() -> bool:
	return is_instance_valid(game)


func replay_live() -> bool:
	return is_instance_valid(game) and game.phase == Match1v1.Phase.REPLAY


## The goal replay's ghosts, for the HUD's player lists.
func ghost_replay() -> GoalReplay:
	return game.goal_replay if is_instance_valid(game) else null


func countdown_text() -> String:
	if game.phase == Match1v1.Phase.COUNTDOWN:
		return str(ceili(game.countdown_left))
	return "GO!" if game.go_time_left > 0.0 else ""


func update_slots(hud: Node) -> void:
	var bug: Node = hud.scorebug
	bug.team_names = ["BLUE", "ORANGE"]
	bug.scores = game.arena.scores.duplicate()
	bug.clock_color = Color.WHITE
	bug.players = [game.player.display_name, game.bot_fish.display_name]
	if game.overtime:
		bug.clock = BroadcastUI.clock_text(game.overtime_elapsed, true)
		bug.clock_color = BroadcastUI.GOLD
	else:
		bug.clock = BroadcastUI.clock_text(game.clock_left)
	match game.phase:
		Match1v1.Phase.REPLAY:
			bug.caption = "REPLAY"
		Match1v1.Phase.OVER:
			bug.caption = "FINAL"
		_:
			bug.caption = "OVERTIME" if game.overtime else "1V1"
	hud.course_text = ""


## The 1v1's scoreboard, while the button's held (not over a Rocket League replay).
func update_board(hud: Node) -> void:
	var board: Node = hud.board
	board.headings = BroadcastUI.StatsBoard.HEADINGS
	var over := game.phase == Match1v1.Phase.OVER
	var result_up: bool = over and game.over_left < Match1v1.OVER_TIME - hud.RESULT_TIME
	board.shown = game.stats.size() == 2 and not is_instance_valid(hud.replay) \
			and (Input.is_action_pressed("show_scoreboard") or result_up)
	if not board.shown:
		return
	board.title = "FINAL STATS" if over else "MATCH STATS"
	board.footer = "NEXT MATCH IN %d    ·    START / R: PLAY AGAIN" % ceili(game.over_left) if over else ""
	var totals: Dictionary = game.team_stats
	board.bars = [
		hud.share_bar("BALL POSSESSION", totals.possession),
		hud.share_bar("BOOST USED", totals.boost, false),
		hud.share_bar("FIELD DOMINATION", totals.territory),
	]
	var teams := []
	for team in 2:
		var fish_of_team := game.player if team == 0 else game.bot_fish
		var line: Dictionary = game.stats[team]
		var values := MatchStats.COLUMNS.map(func(column: String) -> int: return line[column])
		teams.append({
			"name": AquariumArena.TEAM_NAMES[team],
			"score": game.arena.scores[team],
			"color": AquariumArena.TEAM_COLORS[team],
			"rows": [{"name": hud.name_of(fish_of_team), "values": values, "focus": fish_of_team == hud.fish}],
		})
	board.teams = teams


## A battery: the banner for the fish that was battered or that battered.
func _on_battered(attacker: FishController, victim: FishController) -> void:
	if victim == _hud.fish:
		_hud.show_banner("BATTERED!  Respawning...")
	elif attacker == _hud.fish:
		_hud.show_banner("BATTERED!")


func _on_goal_replay_started(goal_replay: GoalReplay) -> void:
	var arena := game.arena
	var credit: Dictionary = arena.last_goal if is_instance_valid(arena) else {}
	var team: int = credit.get("team", 0)
	var scorer: Node3D = credit.get("scorer")
	var assister: Node3D = credit.get("assister")
	_hud.splash.hide_now()
	_hud.replay_overlay.start(goal_replay, _hud.name_of(scorer) if is_instance_valid(scorer) else AquariumArena.TEAM_NAMES[team],
			_hud.name_of(assister) if is_instance_valid(assister) else "", _hud.speed_text(credit.get("speed", 0.0)),
			AquariumArena.TEAM_COLORS[team])


func _on_match_over(winner: int) -> void:
	var winner_fish := game.player if winner == 0 else game.bot_fish
	_hud.splash.play("%s WINS" % AquariumArena.TEAM_NAMES[winner].to_upper(), _hud.name_of(winner_fish),
			"Final  %d - %d" % [game.arena.scores[0], game.arena.scores[1]], AquariumArena.TEAM_COLORS[winner], _hud.RESULT_TIME)
