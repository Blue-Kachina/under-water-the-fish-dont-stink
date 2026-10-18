class_name MatchSounds
extends Node
## A 1v1's or a Hunt's sounds (planning_audio.md §3.4): the 3-2-1 and GO, the
## last ten seconds, the buzzer, overtime, replays and the result. SfxHooks
## adds one to every Match1v1 and HuntMatch. The goal horn is the arena's
## (ArenaSounds), so Free Play's goals get it too. Read off the match's state
## each tick (the two share their phases' order, and their clock).

var game: Node

var _phase := -1
var _count := 0
var _second := 0
var _overtime := false
var _clock := 0.0


func _ready() -> void:
	game = get_parent()
	process_physics_priority = 100  # after the match has ticked
	var started := &"battery_replay_started" if game is HuntMatch else &"goal_replay_started"
	var ended := &"battery_replay_ended" if game is HuntMatch else &"goal_replay_ended"
	game.connect(started, func(_replay: GoalReplay) -> void: Sfx.play("match/goal_replay_in"))
	game.connect(ended, func() -> void: Sfx.play("match/goal_replay_out"))
	game.match_over.connect(_on_match_over)
	_clock = game.clock_left


func _physics_process(_delta: float) -> void:
	var phase: int = game.phase
	if phase == Match1v1.Phase.COUNTDOWN:
		var count := ceili(game.countdown_left)
		if count != _count and count > 0:
			Sfx.play_pitched("match/countdown", ceili(Match1v1.COUNTDOWN_TIME) - count)
		_count = count
	else:
		_count = 0
	if phase == Match1v1.Phase.LIVE and _phase == Match1v1.Phase.COUNTDOWN:
		Sfx.play("match/go")
	if phase == Match1v1.Phase.LIVE and not game.overtime:
		var second := ceili(game.clock_left)
		if second != _second and second > 0 and second <= 10:
			Sfx.play_pitched("match/clock_tick", 10 - second)
		_second = second
	if _clock > 0.0 and game.clock_left <= 0.0 and not _overtime:
		Sfx.play("match/time_up")
	if game.overtime and not _overtime:
		Sfx.play("match/overtime")
	_overtime = game.overtime
	_clock = game.clock_left
	_phase = phase


func _on_match_over(winner: int) -> void:
	var player: FishController = game.player
	var team := maxi(player.team, 0) if is_instance_valid(player) else 0
	if winner < 0:
		Sfx.play("match/draw")
	else:
		Sfx.play("match/win" if winner == team else "match/lose")
