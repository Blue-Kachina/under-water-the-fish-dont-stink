extends CanvasLayer
## The game's HUD, broadcast style (see BroadcastUI): in the Aquarium Arena a
## scoreboard at the top, a boost gauge in the bottom right, and a splash when
## someone scores; in a 1v1 (OneVOneHud, a ModeHud) also the clock, the kickoff countdown,
## battered fish, the goal replay's overlay and the result. While a Rocket League
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
## With Extra Swishy swimming, the stroke rhythm meter
## (StrideMeter) sits at the bottom centre and the boost gauge hides while boost is off; in Nature
## (NatureHud, a ModeHud) the battery count shows at the top, and the scoreboard (held)
## each player's points, battered fish, pearls, best multi and spree, perfect
## strides and top speed, with the run's time. In Hunt (HuntHud, a ModeHud given to set_mode_hud) the
## scorebug shows both fish's goals (battered fish), the clock and each fish's
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
@export var fish: FishController
## A split-screen player who joined (LocalCoop): the hint shows their own controls.
var joined_player := false
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
## The playing mode's HUD (ModeHud), if any.
var mode_hud: ModeHud
var _stride_meter: StrideMeter
## The points feed: each line [text, colour, seconds left], newest last.
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
## Unnatural's survivor cam is on: Y swaps follow and free cam (the hint says so).
var survivor_cam := false:
	set(value):
		survivor_cam = value
		_update_hint()
## Set by the mode (Marco Polo): called with another fish, false hides its name
## plate (the seeker sees hiders' only once they show enough). Unset: all show.
var plate_filter := Callable()


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
	_stride_meter.offset_left = -240.0
	_stride_meter.offset_right = 240.0
	_stride_meter.offset_top = -88.0
	_stride_meter.offset_bottom = -24.0
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


## Slots a ModeHud fills (the HudHost surface).
var scorebug: Node:
	get:
		return _scorebug
var splash: Node:
	get:
		return _splash
var board: Node:
	get:
		return _board
var chain_bar: ChainBar:
	get:
		return _chain_bar
var replay_overlay: Node:
	get:
		return _replay_overlay
var course_text: String:
	get:
		return _course.text
	set(value):
		_course.text = value


## Puts `new_hud` (a ModeHud) on the HUD, or takes the playing mode's off (null).
func set_mode_hud(new_hud: ModeHud) -> void:
	if mode_hud:
		mode_hud.detach()
	mode_hud = new_hud
	_chain_bar.visible = false
	_replay_overlay.stop()
	_splash.hide_now()
	_feed_lines.clear()
	if mode_hud:
		mode_hud.attach(self)
	if _countdown:
		_countdown.text = ""
	if _course:
		_course.text = ""
	if _hint:
		_update_hint()


## A line in the points feed (a new one pushes the oldest off at FEED_LINES).
func feed_add(text: String, color: Color) -> void:
	_feed_lines.append([text, color, FEED_TIME])
	while _feed_lines.size() > FEED_LINES:
		_feed_lines.pop_front()


func feed_clear() -> void:
	_feed_lines.clear()


## The banner under the top row, for `seconds`.
func show_banner(text: String, seconds := 2.5) -> void:
	_banner.text = text
	_banner_time_left = seconds


## The name a fish goes by on the HUD.
func name_of(node: Node3D) -> String:
	return _name_of(node)


func speed_text(speed: float) -> String:
	return _speed_text(speed)


func share_bar(label: String, values: Array, percent := true) -> Dictionary:
	return _share_bar(label, values, percent)


## Some players' name plates are held back (a plate filter or the mode HUD's).
func plates_filtered() -> bool:
	return plate_filter.is_valid() or (_mode_hud_live() and mode_hud.filters_plates)


## A mode's HUD is up and its node still alive.
func _mode_hud_live() -> bool:
	return mode_hud != null and mode_hud.live()


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


func _update_hint() -> void:
	if _hint == null:
		return
	if replay:
		_hint.text = "P/jump: play    , . / D-pad: 5 s    [ ]: goals    V/boost: camera    T G / D-pad: target    - =: speed    H: hitboxes    Y: ball cam"
	elif fish_sitting_out:
		_hint.text = "Start/Esc: pause, settings    F11: fullscreen"
	elif mode_hud and mode_hud.joined_hint != "" and joined_player:
		# A split-screen player who joined: their own few controls.
		_hint.text = mode_hud.joined_hint
	else:
		_hint.text = "Start/Esc: pause, settings    R: %s    Right stick/IJKL: look around    Y: %s cam    %s%sF11: fullscreen" % [
				mode_hud.restart_hint if mode_hud else "reset",
				"follow/free" if survivor_cam else ("ring" if arena else (mode_hud.camera_word if mode_hud else "ball")),
				"Hold D-pad up/B: scoreboard    " if mode_hud and mode_hud.has_board else "",
				mode_hud.join_hint if mode_hud else ""]


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
	_hint.visible = not in_goal_replay and not survivor_cam  # Unnatural: no controls line (the HUD redesign)
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

	_scorebug.visible = is_instance_valid(aquarium) or (_mode_hud_live() and mode_hud.shows_scorebug)
	_course.offset_top = 16.0
	if is_instance_valid(arena):
		var best :="--" if is_inf(arena.best_time) else "%.2f" % arena.best_time
		if arena.running:
			_course.text = "Hoop %d / %d    %.2f s    best %s" % [arena.next_hoop + 1, arena.hoops.size(), arena.course_time, best]
		else:
			_course.text = "Swim through the yellow hoop to start    best %s" % best
	elif _mode_hud_live():
		mode_hud.update_slots(self)
	elif is_instance_valid(aquarium):
		_update_scorebug()
		_course.offset_top = 104.0
		_course.text = ""
		if aquarium.ball.popped and aquarium.auto_respawn:
			_course.text = "Next ball in %.1f s" % maxf(aquarium.respawn_time_left, 0.0)

	if _mode_hud_live():
		_countdown.text = mode_hud.countdown_text()

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
	_scorebug.players = [fish.display_name, ""]
	_scorebug.clock = "--:--"
	_scorebug.caption = "FREE PLAY"


## The player lists: a Rocket League replay's players or a goal replay's
## ghosts; hidden otherwise. Badges pop as playback passes each event.
func _update_player_lists() -> void:
	var rows: Array = [[], []]
	_row_of.clear()
	var goal_replay: GoalReplay = mode_hud.ghost_replay() if _mode_hud_live() else null
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


## A mode's own replay (the 1v1's goal, Hunt's battery) is playing.
func _in_live_replay() -> bool:
	return _mode_hud_live() and mode_hud.replay_live()


## The playing mode's scoreboard, while the button's held (not over a Rocket League replay).
func _update_board() -> void:
	if _mode_hud_live() and mode_hud.has_board:
		mode_hud.update_board(self)
		return
	_board.headings = BroadcastUI.StatsBoard.HEADINGS
	_board.shown = false


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
			if plate_filter.is_valid() and not bool(plate_filter.call(other)):
				continue
			if _mode_hud_live() and mode_hud.filters_plates and not mode_hud.shows_plate(other):
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


## Extra Swishy's stroke rhythm meter (the HUD redesign, 2026-10-25; the tail
## still lights up root to tip as a stride builds): a fin at each end, a track
## from each to the emblem in the middle, and a marker riding in along each
## track as the current stride builds, reaching the emblem right at its peak.
## Both sides are just "a stride": any direction counts, so no L / R. The
## pips light behind the markers; the sweet zone by the emblem brightens as
## the peak nears; a well-timed stride pops the emblem with a ripple, a poor
## one flushes it coral, with PERFECT / EARLY / LATE above it.
class StrideMeter extends Control:
	const LEFT := Color(70 / 255.0, 214 / 255.0, 1.0)
	const RIGHT := Color(1.0, 201 / 255.0, 74 / 255.0)
	const MISS := Color(1.0, 122 / 255.0, 89 / 255.0)
	const EMBLEM := Color(6 / 255.0, 42 / 255.0, 61 / 255.0)
	## Along each track (0 at the fin, 1 at the emblem): the pips, and where the sweet zone starts.
	const PIPS := [0.16, 0.35, 0.54, 0.73]
	const ZONE := 0.82
	## The fin (54x48 box) and its size on the meter (px).
	const FIN := "M2 24C14 6 34 2 52 6 42 14 38 20 40 24c-2 4 2 10 12 18C34 46 14 42 2 24Z"
	const FIN_SIZE := Vector2(42.0, 37.0)
	## How long the last stride's word, pop and flush show (s).
	const TIMING_TIME := 0.6
	const POP_TIME := 0.35
	var fish: FishController
	## The last stride's pop (perfect) and flush (poor), 1 fading to 0.
	var pop := 0.0
	var miss := 0.0
	var _strides := 0
	static var _fin := PackedVector2Array()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not visible or fish == null:
			return
		var swim := fish.swishy
		if swim.strides != _strides:
			_strides = swim.strides
			if swim.strides > 1 and swim.last_timing >= 0.0:
				if swim.last_timing >= SwishySwim.SWEET_SPOT:
					pop = 1.0
				else:
					miss = 1.0
		pop = move_toward(pop, 0.0, delta / POP_TIME)
		miss = move_toward(miss, 0.0, delta / POP_TIME)
		queue_redraw()

	## How far the markers have ridden in (0..1, 1 at the peak), or -1 between strides.
	func approach() -> float:
		var swim := fish.swishy
		if swim.phase < 0.0:
			return -1.0
		return clampf(swim.phase / maxf(swim.peak_time(), 0.01), 0.0, 1.0)

	func _draw() -> void:
		if fish == null:
			return
		var swim := fish.swishy
		var radius := minf(size.y * 0.36, 26.0)
		var mid := Vector2(size.x * 0.5, size.y * 0.5 + 4.0)
		var start := FIN_SIZE.x + 2.0
		var end := mid.x - radius - 1.0
		var p := approach()
		# How bright the sweet zone is: building over the last of the approach, full in the sweet spot.
		var zone := 0.3
		if p >= 0.0:
			zone = lerpf(0.3, 1.0, maxf(swim.sweetness(), smoothstep(0.6, 1.0, p) * (1.0 if swim.phase <= swim.peak_time() else 0.0)))
		zone = maxf(zone, pop)
		for side: float in [-1.0, 1.0]:
			var tint: Color = LEFT if side < 0.0 else RIGHT
			_draw_fin(mid, side, tint)
			var a := _x(start, mid.x, side)
			var b := _x(end, mid.x, side)
			draw_line(Vector2(a, mid.y), Vector2(b, mid.y), Color(tint, 0.35), 2.0)
			var zone_a := _x(lerpf(start, end, ZONE), mid.x, side)
			var zone_rect := Rect2(minf(zone_a, b), mid.y - 7.0, absf(b - zone_a), 14.0)
			UITheme.draw_box(self, zone_rect, Color(tint, 0.28 * zone), 7.0)
			for t: float in PIPS:
				var at := Vector2(_x(lerpf(start, end, t), mid.x, side), mid.y)
				var lit := p >= t and miss <= 0.0
				draw_circle(at, 4.0, tint if lit else Color(UITheme.DEEP, 0.9), true, -1.0, true)
				draw_arc(at, 4.0, 0.0, TAU, 16, tint, 1.5, true)
			if p >= 0.0:
				var fade := 1.0 if swim.phase <= swim.peak_time() else swim.power
				var at := Vector2(_x(lerpf(start, end, p), mid.x, side), mid.y)
				var glow := Color(tint, 0.35 * fade)
				draw_circle(at, 9.0, glow, true, -1.0, true)
				var core := tint.lightened(0.6)
				core.a = fade
				draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6.5), at + Vector2(6.5, 0), at + Vector2(0, 6.5), at + Vector2(-6.5, 0)]), core)
		# The emblem: a spiral in a ring, popping on a good stride, coral on a poor one.
		var ring := LEFT.lerp(MISS, miss)
		var r := radius * (1.0 + 0.14 * pop)
		if pop > 0.0:
			draw_circle(mid, r + 6.0, Color(LEFT, 0.35 * pop), true, -1.0, true)
			draw_arc(mid, r + 4.0 + (1.0 - pop) * 14.0, 0.0, TAU, 48, Color(LEFT, 0.5 * pop), 2.0, true)
		draw_circle(mid, r, EMBLEM, true, -1.0, true)
		draw_arc(mid, r, 0.0, TAU, 48, ring, 2.0, true)
		var spiral := PackedVector2Array()
		for n in 40:
			var t := n / 39.0
			spiral.append(mid + Vector2.from_angle(-PI * 0.5 + t * TAU * 2.1) * r * 0.66 * t)
		draw_polyline(spiral, Color(0.61, 0.91, 1.0).lerp(MISS, miss * 0.7), 2.0, true)
		# The last stride's timing, above the emblem.
		if swim.last_timing >= 0.0 and swim.phase >= 0.0 and swim.phase < TIMING_TIME and swim.strides > 1:
			var perfect := swim.last_timing >= SwishySwim.SWEET_SPOT
			var word := "PERFECT" if perfect else ("EARLY" if swim.last_early else "LATE")
			var color := RIGHT if perfect else MISS
			color.a = 1.0 - swim.phase / TIMING_TIME
			UITheme.draw_text(self, Rect2(mid.x - 80.0, mid.y - r - 30.0, 160.0, 22.0), word, UITheme.condensed(700), 18, color)

	## `x` (measured from the left end) on `side`'s half (-1 left, 1 mirrored right).
	func _x(x: float, middle: float, side: float) -> float:
		return x if side < 0.0 else middle * 2.0 - x

	func _draw_fin(mid: Vector2, side: float, tint: Color) -> void:
		if _fin.is_empty():
			for line: PackedVector2Array in HexBadge.parse_path(FIN).lines:
				for point in line:
					if _fin.is_empty() or _fin[_fin.size() - 1].distance_to(point) > 0.001:
						_fin.append(point)
			if _fin.size() > 2 and _fin[0].distance_to(_fin[_fin.size() - 1]) < 0.001:
				_fin.remove_at(_fin.size() - 1)
		var unit := FIN_SIZE / Vector2(54.0, 48.0)
		var points := PackedVector2Array()
		for point in _fin:
			var x := point.x * unit.x
			points.append(Vector2(_x(x, mid.x, side), mid.y + (point.y - 24.0) * unit.y))
		draw_colored_polygon(points, Color(tint, 0.18))
		points.append(points[0])
		draw_polyline(points, tint, 1.5, true)


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
