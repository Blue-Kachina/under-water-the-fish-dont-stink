extends CanvasLayer
## The game's HUD, broadcast style (see BroadcastUI): in the Aquarium Arena a
## scoreboard at the top, a boost gauge in the bottom right, and a splash when
## someone scores; in a 1v1 (set_match) also the clock, the kickoff countdown,
## batteries, the goal replay's overlay and the result. While a Rocket League
## replay plays (set_replay), the same for the replay and its followed player.
## In both kinds of replay, each team's players are listed in the top corners
## with their boost, and a badge pops up beside a player for a goal, assist,
## shot, save or battery (a demo in a Rocket League replay; MatchStats). Live,
## the lists stay hidden (they'd give away the opponents' boost); the other
## fish get name plates instead, with boost shown for teammates only. Holding D-pad up (or B) in a 1v1 holds up
## its scoreboard (BroadcastUI.StatsBoard), each fish's points and stats and
## the teams' possession, boost and territory. It comes up by itself at the end
## of the match, once the winner's splash has been.
##
## With Extra Swishy swimming (Nature), the last stride's timing and the flow
## (StrideMeter) sit at the bottom centre and the boost gauge hides while boost is off; in Nature
## (set_nature) the battery count shows at the top. In Hunt (set_hunt) the
## scorebug shows both fish's goals (batteries), the clock and each fish's
## points; a battery gets a splash, each style point (StylePoints) a line in
## the points feed under the banner, the battery replay its overlay, and the
## scoreboard (held, or at the end) each fish's points and their make-up.
##
## Two tuning aids show only when switched on in the tuning panel's UI section
## (UISettings): the speed / drift / ... readout and the controller-input display.

## How long the goal splash shows.
const SPLASH_TIME := 3.0
## How long the winner's splash shows before the final scoreboard comes up.
const RESULT_TIME := 4.5
## How far above a fish's centre its name plate points (m).
const NAME_PLATE_HEIGHT := 0.9
## How long a line stays in the points feed (s), and the most lines it shows.
const FEED_TIME := 2.5
const FEED_LINES := 4
## Nature's multis get hotter each step: Battered, Double Dip, Triple Fry,
## Fish Supper, Feeding Frenzy, Monster Catch (and sprees, the hottest).
const NATURE_HEAT := [Color(0.95, 0.95, 0.9), Color(1.0, 0.82, 0.3), Color(1.0, 0.6, 0.2),
		Color(1.0, 0.38, 0.18), Color(0.95, 0.2, 0.35), Color(0.85, 0.25, 0.95)]
## Hunt's scoreboard columns (as many as StatsBoard.HEADINGS).
## BATTERIES: fish battered (Battery; a battery being a beating).
const HUNT_HEADINGS := ["POINTS", "BATTERIES", "CLOSE", "DODGES", "PERFECT", "BEST RUN", "TOP KM/H"]

@export var fish: FishController
@export var arena: Arena
@export var aquarium: AquariumArena

var _stats_panel: PanelContainer
var _stats: Label
var _speed_bar: ProgressBar
var _boost_bar: ProgressBar
var _course: Label
var _banner: Label
var _banner_time_left := 0.0
var _viz: InputViz
var _hint: Label
var _countdown: Label
var _scorebug: BroadcastUI.ScoreBug
var _boost: BroadcastUI.BoostGauge
var _splash: BroadcastUI.Splash
var _replay_overlay: BroadcastUI.ReplayOverlay
var _lists: Array[BroadcastUI.PlayerList] = []
var _plates: BroadcastUI.NamePlates
var _board: BroadcastUI.StatsBoard
## Player index -> [team, row] in the lists, for the events' "player".
var _row_of := {}
## The replay (ReplayData) whose events the lists are calling out, those
## events, and how far through them the lists have got.
var _events_source: ReplayData
var _events: Array[Dictionary] = []
var _events_time := 0.0
var replay: ReplayPlayer
var match_1v1: Match1v1
var nature_run: NatureRun
var hunt_match: HuntMatch
var _stride_meter: StrideMeter
## Hunt's points feed: each line [text, colour, seconds left], newest last.
var _feed: RichTextLabel
var _feed_lines: Array = []
## Nature: how long is left to extend a multi, under the counts.
var _chain_bar: ChainBar
## Replays mode before a replay's picked: the live fish sits out, so its
## boost, the scorebug and the ball countdown are hidden.
var fish_sitting_out := false:
	set(value):
		fish_sitting_out = value
		_update_hint()


func _ready() -> void:
	_plates = BroadcastUI.NamePlates.new()
	add_child(_plates)
	_replay_overlay = BroadcastUI.ReplayOverlay.new()
	add_child(_replay_overlay)

	_stats_panel = _make_panel()
	_stats_panel.anchor_left = 1.0
	_stats_panel.anchor_right = 1.0
	_stats_panel.offset_left = -290.0
	_stats_panel.offset_right = -16.0
	_stats_panel.offset_top = 140.0  # under the player lists
	add_child(_stats_panel)
	var column := VBoxContainer.new()
	_stats_panel.add_child(column)
	_stats = Label.new()
	column.add_child(_stats)
	column.add_child(_caption("Speed"))
	_speed_bar = _bar(Color(0.3, 0.8, 1.0))
	column.add_child(_speed_bar)
	column.add_child(_caption("Boost"))
	_boost_bar = _bar(BroadcastUI.BOOST_COLOR)
	column.add_child(_boost_bar)

	_scorebug = BroadcastUI.ScoreBug.new()
	add_child(_scorebug)
	_boost = BroadcastUI.BoostGauge.new()
	add_child(_boost)
	for team in 2:
		var list := BroadcastUI.PlayerList.new()
		list.team = team
		list.visible = false
		add_child(list)
		_lists.append(list)

	_course = _centred_label(16.0, 28)
	add_child(_course)
	_banner = _centred_label(124.0, 32)
	_banner.modulate = Color(1.0, 0.9, 0.3)
	add_child(_banner)
	_feed = RichTextLabel.new()
	_feed.bbcode_enabled = true
	_feed.scroll_active = false
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.anchor_left = 0.5
	_feed.anchor_right = 0.5
	_feed.offset_left = -400.0
	_feed.offset_right = 400.0
	_feed.offset_top = 170.0
	_feed.offset_bottom = 300.0
	_feed.add_theme_font_override("normal_font", BroadcastUI.font(700))
	_feed.add_theme_font_size_override("normal_font_size", 20)
	_feed.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_feed.add_theme_constant_override("outline_size", 6)
	add_child(_feed)
	_chain_bar = ChainBar.new()
	_chain_bar.anchor_left = 0.5
	_chain_bar.anchor_right = 0.5
	_chain_bar.offset_left = -110.0
	_chain_bar.offset_right = 110.0
	_chain_bar.offset_top = 58.0
	_chain_bar.offset_bottom = 84.0
	_chain_bar.visible = false
	add_child(_chain_bar)
	_countdown = _centred_label(0.0, 120)
	_countdown.anchor_top = 0.5
	_countdown.anchor_bottom = 0.5
	_countdown.offset_top = -210.0
	_countdown.offset_bottom = -50.0
	_countdown.add_theme_font_override("font", BroadcastUI.font(800))
	_countdown.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_countdown.add_theme_constant_override("outline_size", 12)
	add_child(_countdown)

	_splash = BroadcastUI.Splash.new()
	_splash.visible = false
	add_child(_splash)
	_board = BroadcastUI.StatsBoard.new()
	add_child(_board)

	_stride_meter = StrideMeter.new()
	_stride_meter.fish = fish
	_stride_meter.anchor_left = 0.5
	_stride_meter.anchor_right = 0.5
	_stride_meter.anchor_top = 1.0
	_stride_meter.anchor_bottom = 1.0
	_stride_meter.offset_left = -140.0
	_stride_meter.offset_right = 140.0
	_stride_meter.offset_top = -110.0
	_stride_meter.offset_bottom = -36.0
	add_child(_stride_meter)

	_viz = InputViz.new()
	_viz.fish = fish
	_viz.anchor_top = 1.0
	_viz.anchor_bottom = 1.0
	_viz.offset_left = 16.0
	_viz.offset_top = -160.0
	_viz.offset_right = 300.0
	_viz.offset_bottom = -46.0
	add_child(_viz)

	_hint = Label.new()
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 16.0
	_hint.offset_top = -36.0
	_hint.modulate = Color(1, 1, 1, 0.6)
	add_child(_hint)
	_update_hint()

	UISettings.changed.connect(func(_key: String) -> void: _apply_ui_settings())
	_apply_ui_settings()
	set_arena(arena)


func _apply_ui_settings() -> void:
	_stats_panel.visible = UISettings.show_stats
	_viz.visible = UISettings.show_input_overlay


## Point the course readout at a new arena, or null for environments without one.
func set_arena(new_arena: Arena) -> void:
	if is_instance_valid(arena) and arena.course_finished.is_connected(_on_course_finished):
		arena.course_finished.disconnect(_on_course_finished)
	arena = new_arena
	if arena:
		arena.course_finished.connect(_on_course_finished)
	if _course:
		_course.text = ""
	if _hint:
		_update_hint()


## Point the scoreboard at a new aquarium, or null for environments without one.
func set_aquarium(new_aquarium: AquariumArena) -> void:
	if is_instance_valid(aquarium) and aquarium.goal_scored.is_connected(_on_goal_scored):
		aquarium.goal_scored.disconnect(_on_goal_scored)
	aquarium = new_aquarium
	if aquarium:
		aquarium.goal_scored.connect(_on_goal_scored)


## Show a replay's readouts instead of the fish's, or null to go back.
func set_replay(new_replay: ReplayPlayer) -> void:
	replay = new_replay
	_banner.text = ""
	_banner_time_left = 0.0
	_splash.hide_now()
	_events_source = null
	if replay:
		replay.target_changed.connect(func(car: ReplayCar) -> void: _viz.fish = car)
		replay.goal_reached.connect(_on_replay_goal)
		_viz.fish = replay.target
	else:
		_viz.fish = fish
	_update_hint()


## Show a 1v1's clock, countdown, batteries and goal replays, or null when there's none.
func set_match(new_match: Match1v1) -> void:
	match_1v1 = new_match
	_replay_overlay.stop()
	_splash.hide_now()
	if match_1v1:
		match_1v1.battered.connect(_on_battered)
		match_1v1.goal_replay_started.connect(_on_goal_replay_started)
		match_1v1.goal_replay_ended.connect(_replay_overlay.stop)
		match_1v1.match_over.connect(_on_match_over)
	if _countdown:
		_countdown.text = ""
	if _hint:
		_update_hint()


## Show a Nature run's batteries, or null when there's none.
func set_nature(new_run: NatureRun) -> void:
	nature_run = new_run
	_feed_lines.clear()
	_chain_bar.visible = false
	_splash.hide_now()
	if nature_run:
		nature_run.battered.connect(_on_battered)
		nature_run.school_fish_battered.connect(func(attacker: FishController, _school: School, _at: Vector3) -> void:
			_on_battered(attacker, null))
		nature_run.awarded.connect(_on_nature_award)
		nature_run.pearl_collected.connect(func(_by: FishController) -> void:
			_feed_lines.append(["PEARL  +1", Pearl.GLOW, FEED_TIME])
			while _feed_lines.size() > FEED_LINES:
				_feed_lines.pop_front())
	if _course:
		_course.text = ""
	if _hint:
		_update_hint()


## Show a Hunt's scorebug, countdown, batteries, points and battery replays, or
## null when there's none.
func set_hunt(new_match: HuntMatch) -> void:
	hunt_match = new_match
	_replay_overlay.stop()
	_splash.hide_now()
	_feed_lines.clear()
	if hunt_match:
		hunt_match.battered.connect(_on_hunt_battered)
		hunt_match.battery_replay_started.connect(_on_battery_replay_started)
		hunt_match.battery_replay_ended.connect(_replay_overlay.stop)
		hunt_match.match_over.connect(_on_hunt_over)
		hunt_match.stat_event.connect(_on_hunt_event)
	if _countdown:
		_countdown.text = ""
	if _course:
		_course.text = ""
	if _hint:
		_update_hint()


func _on_hunt_battered(attacker: FishController, _victim: FishController) -> void:
	if attacker == null:
		_splash.play("FISH FRY!", "Both battered  ·  nobody scores", "", BroadcastUI.GOLD, SPLASH_TIME)
		return
	var team := hunt_match._team_of(attacker)
	_splash.play("BATTERED!", _name_of(attacker), _speed_text(hunt_match.last_battery.speed),
			AquariumArena.TEAM_COLORS[team], SPLASH_TIME)
	_scorebug.flash(team)


## A style point: a line in the feed, in the scorer's team colour.
func _on_hunt_event(event: Dictionary) -> void:
	var who := _name_of(hunt_match._fish_of(event.player))
	var text := "%s  +%d" % [event.title, event.points]
	if event.type == StylePoints.PERFECT_RHYTHM:
		text = "%s x%d  +%d" % [event.title, event.streak, event.points]
	if event.player != 0:
		text = "%s:  %s" % [who.to_upper(), text]
	var color: Color = AquariumArena.TEAM_COLORS[event.team]
	if event.player == 0:
		color = BroadcastUI.GOLD  # the player's own stand out
	_feed_lines.append([text, color, FEED_TIME])
	while _feed_lines.size() > FEED_LINES:
		_feed_lines.pop_front()


func _update_feed(delta: float) -> void:
	var lines := PackedStringArray()
	for line: Array in _feed_lines:
		line[2] -= delta
	_feed_lines = _feed_lines.filter(func(line: Array) -> bool: return line[2] > 0.0)
	for line: Array in _feed_lines:
		var color: Color = line[1]
		color.a = clampf(line[2] / 0.4, 0.0, 1.0)  # fades over its last moment
		lines.append("[color=#%s]%s[/color]" % [color.to_html(), line[0]])
	_feed.text = "[center]%s[/center]" % "\n".join(lines)


func _on_battery_replay_started(battery_replay: GoalReplay) -> void:
	var battery := hunt_match.last_battery
	_splash.hide_now()
	_feed_lines.clear()
	var speed := _speed_text(battery.get("speed", 0.0))
	if battery.get("fish_fry", false):
		_replay_overlay.start(battery_replay, _name_of(hunt_match.player), _name_of(hunt_match.opponent), speed,
				BroadcastUI.GOLD, "FISH FRY", "WITH")
		return
	var attacker: FishController = battery.get("attacker")
	var victim: FishController = battery.get("victim")
	_replay_overlay.start(battery_replay, _name_of(attacker) if is_instance_valid(attacker) else "",
			_name_of(victim) if is_instance_valid(victim) else "", speed,
			AquariumArena.TEAM_COLORS[maxi(battery.get("team", 0), 0)], "BATTERED BY", "VICTIM")


func _on_hunt_over(winner: int) -> void:
	var winner_fish := hunt_match._fish_of(winner)
	var detail := "Final  %d - %d" % [hunt_match.scores[0], hunt_match.scores[1]]
	if hunt_match.won_on_points():
		detail += "    ·    on points  %d - %d" % [hunt_match.style.points[0], hunt_match.style.points[1]]
	_splash.play("VICTORY!" if winner == 0 else "DEFEATED", "%s wins" % _name_of(winner_fish), detail,
			AquariumArena.TEAM_COLORS[winner], RESULT_TIME)


func _update_hunt_scorebug() -> void:
	_scorebug.team_names = [_name_of(hunt_match.player).to_upper(), _name_of(hunt_match.opponent).to_upper()]
	_scorebug.scores = hunt_match.scores.duplicate()
	_scorebug.players = ["%d PTS" % hunt_match.style.points[0], "%d PTS" % hunt_match.style.points[1]]
	_scorebug.clock_color = Color.WHITE
	if hunt_match.overtime:
		_scorebug.clock = BroadcastUI.clock_text(hunt_match.overtime_elapsed, true)
		_scorebug.clock_color = BroadcastUI.GOLD
	else:
		_scorebug.clock = BroadcastUI.clock_text(hunt_match.clock_left)
	match hunt_match.phase:
		HuntMatch.Phase.REPLAY:
			_scorebug.caption = "REPLAY"
		HuntMatch.Phase.OVER:
			_scorebug.caption = "FINAL"
		_:
			_scorebug.caption = "OVERTIME" if hunt_match.overtime else "HUNT"


func _on_battered(attacker: FishController, victim: FishController) -> void:
	if victim == fish:
		_banner.text = "BATTERED!  Respawning..."
	elif attacker == fish:
		_banner.text = "BATTERED!"
		if is_instance_valid(nature_run):
			_banner.text = "BATTERED!  %s" % _speed_text(nature_run.last_battery_speed)
	else:
		return
	_banner_time_left = 2.5


## Nature's points: a feed line for each, and the splash for a multi (from a
## Double Dip up, hotter each step) or a spree milestone.
func _on_nature_award(event: Dictionary) -> void:
	var color: Color = NATURE_HEAT[clampi(event.get("chain", 1) - 1, 0, NATURE_HEAT.size() - 1)]
	match event.type:
		NatureScore.MULTI:
			_splash.play("%s!" % event.title, "x%d" % event.chain, "+%d" % event.points, color, 1.2 + 0.15 * event.chain)
		NatureScore.SPREE:
			color = NATURE_HEAT[-1]
			_splash.play("%s!" % event.title, "%d batteries without slowing" % event.spree, "+%d" % event.points, color, 2.2)
	_feed_lines.append(["%s  +%d" % [event.title, event.points], color, FEED_TIME])
	while _feed_lines.size() > FEED_LINES:
		_feed_lines.pop_front()


func _update_hint() -> void:
	if _hint == null:
		return
	if replay:
		_hint.text = "P/jump: play    , . / D-pad: 5 s    [ ]: goals    V/boost: camera    T G / D-pad: target    - =: speed    H: hitboxes    Y: ball cam"
	elif fish_sitting_out:
		_hint.text = "Start/Esc: pause, settings    F11: fullscreen"
	else:
		_hint.text = "Start/Esc: pause, settings    R: %s    Right stick/IJKL: look around    Y: %s cam    %sF11: fullscreen" % [
				"restart kickoff" if match_1v1 else ("restart match" if hunt_match else "reset"),
				"ring" if arena else ("fish" if nature_run or hunt_match else "ball"),
				"Hold D-pad up/B: scoreboard    " if match_1v1 or hunt_match else ""]


func _process(delta: float) -> void:
	_update_player_lists()
	_update_name_plates()
	_update_board()
	if is_instance_valid(replay):
		_replay_readouts(delta)
		return
	if fish == null:
		return
	_stride_meter.visible = not fish_sitting_out and not _in_live_replay() and fish.swim_strokes \
			and fish.swim_style == FishController.SwimStyle.EXTRA_SWISHY
	if fish_sitting_out:
		_boost.visible = false
		_scorebug.visible = false
		_course.text = ""
		return
	var in_goal_replay := _in_live_replay()
	_hint.visible = not in_goal_replay
	_update_feed(delta)
	_feed.visible = not in_goal_replay

	if _stats_panel.visible:
		var jump_names := ["READY", "DOUBLE JUMP / DODGE", "cooldown"]
		var pad := Input.get_connected_joypads()
		var lines := [
			"Speed     %5.1f m/s" % fish.speed,
			"Forward   %5.1f m/s" % fish.forward_speed,
			"Drift     %5.0f°" % fish.drift_angle,
			"Spin      %5.2f rad/s" % fish.angular_speed,
			"Jump      %s" % jump_names[fish.jump_state],
			"Surface   %s" % _surface_name(),
			"Strokes   %s" % ("x%d  timing %3.0f%%" % [fish.stroke_chain, fish.stroke_quality * 100.0] if fish.stroke_chain > 0 else "-"),
			"Pad       %s" % (Input.get_joy_name(pad[0]) if not pad.is_empty() else "none (keyboard)"),
			"Controls  %s" % Controls.current_profile,
		]
		if is_instance_valid(aquarium):
			lines.append("Ball      %5.1f m/s" % aquarium.ball.speed)
		_stats.text = "\n".join(lines)
		_speed_bar.max_value = fish.max_boost_speed
		_speed_bar.value = fish.speed
		_boost_bar.value = 100.0 if fish.boost_unlimited else fish.boost_amount

	_boost.visible = not in_goal_replay and fish.boost_enabled
	_boost.amount = 100.0 if fish.boost_unlimited else fish.boost_amount
	_boost.boosting = fish.is_boosting
	_boost.color = fish.body_color()  # its team's colour in a match, else the character's own

	_scorebug.visible = is_instance_valid(aquarium) or is_instance_valid(hunt_match)
	_course.offset_top = 16.0
	if is_instance_valid(arena):
		var best :="--" if is_inf(arena.best_time) else "%.2f" % arena.best_time
		if arena.running:
			_course.text = "Hoop %d / %d    %.2f s    best %s" % [arena.next_hoop + 1, arena.hoops.size(), arena.course_time, best]
		else:
			_course.text = "Swim through the yellow hoop to start    best %s" % best
	elif is_instance_valid(nature_run):
		_course.text = "Batteries  %d    Points  %d    Pearls  %d" % [nature_run.batteries, nature_run.score.points, nature_run.pearls]
		var score := nature_run.score
		_chain_bar.show_chain(score.chain_left / maxf(score.settings.multi_window, 0.01), score.chain,
				NATURE_HEAT[clampi(score.chain - 1, 0, NATURE_HEAT.size() - 1)])
	elif is_instance_valid(hunt_match):
		_update_hunt_scorebug()
		_course.text = ""
	elif is_instance_valid(aquarium):
		_update_scorebug()
		_course.offset_top = 104.0
		_course.text = ""
		if aquarium.ball.popped and aquarium.auto_respawn:
			_course.text = "Next ball in %.1f s" % maxf(aquarium.respawn_time_left, 0.0)

	if is_instance_valid(match_1v1):
		if match_1v1.phase == Match1v1.Phase.COUNTDOWN:
			_countdown.text = str(ceili(match_1v1.countdown_left))
		else:
			_countdown.text = "GO!" if match_1v1.go_time_left > 0.0 else ""
	elif is_instance_valid(hunt_match):
		if hunt_match.phase == HuntMatch.Phase.COUNTDOWN:
			_countdown.text = str(ceili(hunt_match.countdown_left))
		else:
			_countdown.text = "GO!" if hunt_match.go_time_left > 0.0 else ""

	_banner_time_left -= delta
	if _banner_time_left <= 0.0:
		if fish.is_boosting and fish.speed > fish.max_speed:
			_banner.text = "TORPEDO!"
		elif fish.swim_style == FishController.SwimStyle.EXTRA_SWISHY:
			_banner.text = "IN THE FLOW  x%.1f" % (1.0 + fish.swishy.flow) if fish.swishy.flow >= 0.5 else ""
		elif fish.stroke_chain >= 3:
			_banner.text = "IN THE RHYTHM  x%d" % fish.stroke_chain
		else:
			_banner.text = ""
	_banner.visible = not in_goal_replay


func _update_scorebug() -> void:
	_scorebug.team_names = ["BLUE", "ORANGE"]
	_scorebug.scores = aquarium.scores.duplicate()
	_scorebug.clock_color = Color.WHITE
	if is_instance_valid(match_1v1):
		_scorebug.players = [match_1v1.player.display_name, match_1v1.bot_fish.display_name]
		if match_1v1.overtime:
			_scorebug.clock = BroadcastUI.clock_text(match_1v1.overtime_elapsed, true)
			_scorebug.clock_color = BroadcastUI.GOLD
		else:
			_scorebug.clock = BroadcastUI.clock_text(match_1v1.clock_left)
		match match_1v1.phase:
			Match1v1.Phase.REPLAY:
				_scorebug.caption = "REPLAY"
			Match1v1.Phase.OVER:
				_scorebug.caption = "FINAL"
			_:
				_scorebug.caption = "OVERTIME" if match_1v1.overtime else "1V1"
	else:
		_scorebug.players = [fish.display_name, ""]
		_scorebug.clock = "--:--"
		_scorebug.caption = "FREE PLAY"


## The player lists: a Rocket League replay's players or a goal replay's
## ghosts; hidden otherwise. Badges pop as playback passes each event.
func _update_player_lists() -> void:
	var rows: Array = [[], []]
	_row_of.clear()
	var goal_replay: GoalReplay = match_1v1.goal_replay if is_instance_valid(match_1v1) else null
	if is_instance_valid(replay):
		for car in replay.cars:
			_add_row(rows, car.player.index, car.team, car.player.name, car.boost_amount, car.visible, car == replay.target)
		_follow_events(replay.data, replay.time, func(data: ReplayData) -> Array[Dictionary]: return MatchStats.replay_events(data))
	elif is_instance_valid(goal_replay):
		for i in goal_replay.cars.size():
			var car := goal_replay.cars[i]
			_add_row(rows, i, car.team, car.player.name, car.boost_amount, car.visible, i == goal_replay.scorer)
		_follow_events(goal_replay.data, goal_replay.time, func(data: ReplayData) -> Array[Dictionary]: return data.events)
	elif _events_source != null:  # back from a replay: its badges are done with
		_events_source = null
		for list in _lists:
			list.clear_badges()
	for team in 2:
		_lists[team].visible = not rows[team].is_empty()
		_lists[team].rows.assign(rows[team])


## A 1v1's goal replay or a Hunt's battery replay is playing.
func _in_live_replay() -> bool:
	return (is_instance_valid(match_1v1) and match_1v1.phase == Match1v1.Phase.REPLAY) \
			or (is_instance_valid(hunt_match) and hunt_match.phase == HuntMatch.Phase.REPLAY)


## The 1v1's scoreboard, while the button's held (not over a Rocket League replay).
func _update_board() -> void:
	if is_instance_valid(hunt_match):
		_update_hunt_board()
		return
	_board.headings = BroadcastUI.StatsBoard.HEADINGS
	var over := is_instance_valid(match_1v1) and match_1v1.phase == Match1v1.Phase.OVER
	var result_up := over and match_1v1.over_left < Match1v1.OVER_TIME - RESULT_TIME
	_board.shown = is_instance_valid(match_1v1) and match_1v1.stats.size() == 2 and not is_instance_valid(replay) \
			and (Input.is_action_pressed("show_scoreboard") or result_up)
	if not _board.shown:
		return
	_board.title = "FINAL STATS" if over else "MATCH STATS"
	_board.footer = "NEXT MATCH IN %d    ·    START / R: PLAY AGAIN" % ceili(match_1v1.over_left) if over else ""
	var totals: Dictionary = match_1v1.team_stats
	_board.bars = [
		_share_bar("BALL POSSESSION", totals.possession),
		_share_bar("BOOST USED", totals.boost, false),
		_share_bar("FIELD DOMINATION", totals.territory),
	]
	var teams := []
	for team in 2:
		var fish_of_team := match_1v1.player if team == 0 else match_1v1.bot_fish
		var line: Dictionary = match_1v1.stats[team]
		var values := MatchStats.COLUMNS.map(func(column: String) -> int: return line[column])
		teams.append({
			"name": AquariumArena.TEAM_NAMES[team],
			"score": aquarium.scores[team] if is_instance_valid(aquarium) else 0,
			"color": AquariumArena.TEAM_COLORS[team],
			"rows": [{"name": _name_of(fish_of_team), "values": values, "focus": fish_of_team == fish}],
		})
	_board.teams = teams


## Hunt's scoreboard: each fish's points and what they're made of, held up
## like the 1v1's, and by itself once the result's splash has been.
func _update_hunt_board() -> void:
	var over := hunt_match.phase == HuntMatch.Phase.OVER
	var result_up := over and hunt_match.over_left < HuntMatch.OVER_TIME - RESULT_TIME
	_board.shown = not is_instance_valid(replay) and (Input.is_action_pressed("show_scoreboard") or result_up)
	if not _board.shown:
		return
	_board.headings = HUNT_HEADINGS
	_board.title = "FINAL STATS" if over else "MATCH STATS"
	_board.footer = "NEXT MATCH IN %d    ·    START / R: PLAY AGAIN" % ceili(hunt_match.over_left) if over else ""
	_board.bars = [_share_bar("POINTS", hunt_match.style.points.map(func(p: int) -> float: return float(p)), false)]
	var teams := []
	for team in 2:
		var who := hunt_match._fish_of(team)
		var counts: Dictionary = hunt_match.style.counts[team]
		teams.append({
			"name": _name_of(who),
			"score": hunt_match.scores[team],
			"color": AquariumArena.TEAM_COLORS[team],
			"rows": [{"name": _name_of(who), "focus": who == fish, "values": [
				hunt_match.style.points[team], counts.batteries, counts.close_calls, counts.dodges,
				counts.perfect, counts.best_streak, roundi(counts.top_speed * 3.6)]}],
		})
	_board.teams = teams


## A StatsBoard bar: Blue's and Orange's shares of `values`, written at the
## ends as percentages or as the amounts themselves.
static func _share_bar(label: String, values: Array, percent := true) -> Dictionary:
	var total: float = values[0] + values[1]
	var share: float = 0.5 if total <= 0.0 else values[0] / total
	var text := ["%d" % roundi(values[0]), "%d" % roundi(values[1])]
	if percent:
		text = ["%d%%" % roundi(share * 100.0), "%d%%" % (100 - roundi(share * 100.0))] if total > 0.0 else ["-", "-"]
	return {"label": label, "share": share, "text": text}


## A name plate over each other fish in view, live only (replays have the lists).
## Teammates' plates carry their boost; opponents' don't.
func _update_name_plates() -> void:
	var plates: Array[Dictionary] = []
	var camera := get_viewport().get_camera_3d()
	var live := not is_instance_valid(replay) and not _in_live_replay()
	if live and camera and fish:
		for other: FishController in get_tree().get_nodes_in_group(FishController.GROUP):
			if other == fish or not other.is_visible_in_tree() or other.battered:
				continue
			var above := other.global_position + Vector3.UP * NAME_PLATE_HEIGHT
			if camera.is_position_behind(above):
				continue
			var on_screen := camera.unproject_position(above)
			if not get_viewport().get_visible_rect().grow(200.0).has_point(on_screen):
				continue  # far off screen (or right on the camera, where the projection blows up)
			var distance := camera.global_position.distance_to(above)
			var teammate := other.team >= 0 and other.team == fish.team
			var color: Color = AquariumArena.TEAM_COLORS[other.team] if other.team >= 0 else BroadcastUI.GOLD
			plates.append({
				"at": on_screen,
				"name": _name_of(other),
				"color": color,
				"boost": (100.0 if other.boost_unlimited else other.boost_amount) if teammate else -1.0,
				"scale": clampf(18.0 / maxf(distance, 0.1), 0.75, 1.0),
			})
	_plates.plates = plates


func _add_row(rows: Array, index: int, team: int, player_name: String, boost: float, present: bool, focus: bool) -> void:
	_row_of[index] = [team, rows[team].size()]
	rows[team].append({"name": player_name, "boost": boost, "present": present, "focus": focus})


## Pops badges for `data`'s events between the last call and `time`. A new
## replay (or a jump back, or a long jump ahead) starts afresh without them.
func _follow_events(data: ReplayData, time: float, events_of: Callable) -> void:
	if data != _events_source:
		_events_source = data
		_events = events_of.call(data)
		_events_time = time
		for list in _lists:
			list.clear_badges()
		return
	var back := time < _events_time - 0.001
	if back or time > _events_time + 1.0:
		if back:
			for list in _lists:
				list.clear_badges()
		_events_time = time
		return
	for event in _events:
		if event.time > _events_time and event.time <= time:
			_pop(event)
	_events_time = time


func _pop(event: Dictionary) -> void:
	var at = _row_of.get(event.get("player"))
	if at != null:
		_lists[at[0]].pop(at[1], event.type)


func _on_course_finished(time: float, is_best: bool) -> void:
	_banner.text = "Course complete: %.2f s%s" % [time, "  NEW BEST!" if is_best else ""]
	_banner_time_left = 3.0


func _replay_readouts(delta: float) -> void:
	var data := replay.data
	var t := replay.time
	var score := data.score_at(t)
	var frame := data.frame_at(t)
	var seconds := data.seconds_remaining[frame]
	var state := data.game_state[frame]
	_hint.visible = true
	_banner.visible = true
	_scorebug.visible = true
	_scorebug.team_names = ["BLUE", "ORANGE"]
	_scorebug.scores = score
	_scorebug.clock = "%d:%02d" % [seconds / 60, seconds % 60]
	_scorebug.clock_color = Color.WHITE
	if seconds == 0 and state == ReplayData.GAME_LIVE and t > 0.0:
		_scorebug.clock = "OT"
		_scorebug.clock_color = BroadcastUI.GOLD
	var names := [PackedStringArray(), PackedStringArray()]
	for player in data.players:
		names[player.team].append(player.name)
	_scorebug.players = [", ".join(names[0]), ", ".join(names[1])]
	_scorebug.caption = "REPLAY"
	_course.offset_top = 104.0
	_course.text = ""
	if state == ReplayData.GAME_COUNTDOWN and data.kickoff_countdown[frame] > 0:
		_course.text = "Kickoff in %d" % data.kickoff_countdown[frame]

	var car := replay.target
	_boost.visible = car != null and car.visible
	if car:
		_boost.amount = car.boost_amount
		_boost.boosting = car.is_boosting
		_boost.color = AquariumArena.TEAM_COLORS[car.team]
		var actions := PackedStringArray()
		for pair: Array in [[ReplayData.FLAG_BOOST, "boost"], [ReplayData.FLAG_JUMP, "jump"],
				[ReplayData.FLAG_DOUBLE_JUMP, "double jump"], [ReplayData.FLAG_DODGE, "dodge"],
				[ReplayData.FLAG_POWERSLIDE, "powerslide"], [ReplayData.FLAG_SUPERSONIC, "supersonic"]]:
			if car.flags & pair[0]:
				actions.append(pair[1])
		_stats.text = "\n".join([
			"%s  (%s)" % [car.player.name, AquariumArena.TEAM_NAMES[car.team]],
			"Car       %s hitbox" % car.player.hitbox_family.capitalize(),
			"Speed     %4.0f uu/s  %4.1f m/s" % [car.speed / RLSpace.M_PER_UU, car.speed],
			"Boost     %3.0f" % car.boost_amount,
			"Surface   %s" % ("yes" if car.on_surface else "-"),
			"Doing     %s" % (", ".join(actions) if not actions.is_empty() else "-"),
			"Replay    %s" % data.path.get_file().get_basename().get_basename(),
		])
		_speed_bar.max_value = 23.0  # RL's top speed, 2300 uu/s
		_speed_bar.value = car.speed if car.visible else 0.0
		_boost_bar.value = car.boost_amount

	_banner_time_left -= delta
	if _banner_time_left <= 0.0:
		_banner.text = ""


func _on_replay_goal(event: Dictionary) -> void:
	var team: int = event.team
	var scorer = event.get("player")
	var scorer_name := ""
	if scorer != null and scorer < replay.data.players.size():
		scorer_name = replay.data.players[scorer].name
	_splash.play("GOAL!", scorer_name if scorer_name else "%s scores" % AquariumArena.TEAM_NAMES[team],
			"", AquariumArena.TEAM_COLORS[team], SPLASH_TIME)
	_scorebug.flash(team)


func _on_goal_scored(team: int) -> void:
	var credit := aquarium.last_goal
	var scorer: Node3D = credit.get("scorer")
	var headline := _name_of(scorer) if is_instance_valid(scorer) else "%s scores" % AquariumArena.TEAM_NAMES[team]
	var details := PackedStringArray()
	if is_instance_valid(credit.get("assister")):
		details.append("Assist  %s" % _name_of(credit.assister))
	details.append(_speed_text(credit.get("speed", 0.0)))
	_splash.play("GOAL!", headline, "    ·    ".join(details), AquariumArena.TEAM_COLORS[team], SPLASH_TIME)
	_scorebug.flash(team)


func _on_goal_replay_started(goal_replay: GoalReplay) -> void:
	var credit := aquarium.last_goal if is_instance_valid(aquarium) else {}
	var team: int = credit.get("team", 0)
	var scorer: Node3D = credit.get("scorer")
	var assister: Node3D = credit.get("assister")
	_splash.hide_now()
	_replay_overlay.start(goal_replay, _name_of(scorer) if is_instance_valid(scorer) else AquariumArena.TEAM_NAMES[team],
			_name_of(assister) if is_instance_valid(assister) else "", _speed_text(credit.get("speed", 0.0)),
			AquariumArena.TEAM_COLORS[team])


func _on_match_over(winner: int) -> void:
	var winner_fish := match_1v1.player if winner == 0 else match_1v1.bot_fish
	_splash.play("%s WINS" % AquariumArena.TEAM_NAMES[winner].to_upper(), _name_of(winner_fish),
			"Final  %d - %d" % [aquarium.scores[0], aquarium.scores[1]], AquariumArena.TEAM_COLORS[winner], RESULT_TIME)


func _name_of(node: Node3D) -> String:
	if "display_name" in node and not str(node.display_name).is_empty():
		return node.display_name
	return UISettings.display_name()


## A ball speed (m/s) as broadcasts show it.
static func _speed_text(speed: float) -> String:
	return "%d km/h" % roundi(speed * 3.6)


func _surface_name() -> String:
	if not fish.on_surface:
		return "- (swimming)"
	if fish.surface_normal.y > 0.7:
		return "floor"
	return "ceiling" if fish.surface_normal.y < -0.7 else "wall"


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.1, 0.75)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.6)
	return label


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _centred_label(top: float, font_size: int) -> Label:
	var label := Label.new()
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -400.0
	label.offset_right = 400.0
	label.offset_top = top
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


## Draws the left stick, triggers and held buttons so you can see exactly what
## the fish is receiving while tuning.
class InputViz extends Control:
	## The live fish, or anything with its input fields (a replay's ReplayCar).
	var fish  # untyped: read by field name

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if fish == null:
			return
		var font := ThemeDB.fallback_font
		var dim := Color(1, 1, 1, 0.35)
		var radius := 45.0
		var centre := Vector2(radius + 4.0, size.y / 2.0)
		draw_arc(centre, radius, 0.0, TAU, 48, dim, 2.0)
		draw_circle(centre + fish.input_stick * radius, 8.0, Color.WHITE)

		_trigger(Vector2(120, 8), "LT", fish.input_reverse, Color(1.0, 0.4, 0.4))
		_trigger(Vector2(150, 8), "RT", fish.input_forward, Color(0.4, 1.0, 0.5))

		var buttons := [
			["BOOST", fish.boost_held],
			["AIR ROLL", fish.air_roll_held],
			["POWERSLIDE", fish.is_powersliding],
			["LOCK", fish.direction_lock_held],
			["ROLL %+.0f" % fish.input_roll, fish.input_roll != 0.0],
		]
		var y := 12.0
		for entry: Array in buttons:
			draw_string(font, Vector2(190, y), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE if entry[1] else dim)
			y += 18.0

	func _trigger(pos: Vector2, label: String, amount: float, color: Color) -> void:
		var bar := Rect2(pos, Vector2(18, size.y - 32.0))
		draw_rect(bar, Color(1, 1, 1, 0.35), false, 1.5)
		var fill_height := bar.size.y * amount
		draw_rect(Rect2(pos.x, bar.end.y - fill_height, bar.size.x, fill_height), color)
		draw_string(ThemeDB.fallback_font, Vector2(pos.x, bar.end.y + 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


## Extra Swishy's readout (the timing cue itself is the fish's tail, which
## lights up root to tip as a stride builds): how the last stride was timed,
## and the flow built up.
class StrideMeter extends Control:
	const DIM := Color(1, 1, 1, 0.35)
	const FLOW := Color(0.45, 0.85, 1.0)
	## How long the last stride's timing shows (s).
	const TIMING_TIME := 0.6
	var fish: FishController

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if fish == null:
			return
		var swim := fish.swishy
		var font := BroadcastUI.font(700)
		var width := size.x
		if swim.last_timing >= 0.0 and swim.phase >= 0.0 and swim.phase < TIMING_TIME:
			var perfect := swim.last_timing >= SwishySwim.SWEET_SPOT
			var text := "PERFECT" if perfect else ("EARLY" if swim.last_early else "LATE")
			var color := BroadcastUI.GOLD if perfect else Color(1.0, 0.55, 0.45)
			color.a = 1.0 - swim.phase / TIMING_TIME
			draw_string(font, Vector2(0, 22), text, HORIZONTAL_ALIGNMENT_CENTER, width, 22, color)
		var bar := Rect2(width * 0.2, 36.0, width * 0.6, 8.0)
		draw_rect(bar, DIM, false, 1.5)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * swim.flow / maxf(fish.stride_flow_max, 0.01), bar.size.y)), FLOW)
		draw_string(font, Vector2(0, 64), "FLOW  x%.1f" % (1.0 + swim.flow), HORIZONTAL_ALIGNMENT_CENTER, width, 14, Color.WHITE)


## Nature's multi timer: a bar under the counts that drains over the time left
## to extend the chain, with the chain so far ("x3").
class ChainBar extends Control:
	var share := 0.0
	var chain := 0
	var color := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_chain(new_share: float, new_chain: int, new_color: Color) -> void:
		share = new_share
		chain = new_chain
		color = new_color
		visible = chain > 0 and share > 0.0
		queue_redraw()

	func _draw() -> void:
		var bar := Rect2(0.0, size.y - 8.0, size.x, 6.0)
		draw_rect(bar, Color(0, 0, 0, 0.45))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), color)
		BroadcastUI.text(self, Rect2(0.0, 0.0, size.x, size.y - 10.0), "x%d" % chain, 16, color, HORIZONTAL_ALIGNMENT_CENTER, 800)
