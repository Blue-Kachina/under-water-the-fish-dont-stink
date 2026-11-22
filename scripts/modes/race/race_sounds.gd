class_name RaceSounds
extends Node
## Fin-ish Line's sounds (planning_race.md section 9): the countdown beeps and GO, a lap chime, FINAL LAP, the finish, the
## buzzer, a rescue, the wrong-way beep, and loops for a stream's whoosh and a wake's wind. Attached through RaceMatch's
## descriptor ("sfx"), one per match. Only the local players hear their own events (the loops follow the first one).

var game: RaceMatch

var _count := 0
var _stream_loop := -1
var _slip_loop := -1
var _wrong_cd := 0.0


func _ready() -> void:
	game = get_parent() as RaceMatch
	process_physics_priority = 100  # after the match has ticked
	game.phase_changed.connect(_on_phase)
	game.lap_completed.connect(_on_lap)
	game.racer_finished.connect(_on_finished)
	game.rescued.connect(_on_rescued)


func _exit_tree() -> void:
	Sfx.stop_loop(_stream_loop)
	Sfx.stop_loop(_slip_loop)


func _mine(fish: FishController) -> bool:
	var r := game.racer_of(fish)
	return r != null and r.human and not r.puppet


func _physics_process(delta: float) -> void:
	if game.phase == RaceMatch.Phase.COUNTDOWN:
		var count := ceili(game.count_left)
		if count != _count and count > 0:
			Sfx.play_pitched("race/countdown", maxi(ceili(game.settings.countdown) - count, 0))
		_count = count
	else:
		_count = 0
	_wrong_cd = maxf(_wrong_cd - delta, 0.0)
	var local: RaceMatch.Racer = null
	for r in game.racers:
		if r.human and not r.puppet and is_instance_valid(r.fish):
			local = r
			break
	var stream := 0.0
	var wake := 0.0
	if local != null and game.phase == RaceMatch.Phase.RACING and local.rescue_stage == 0:
		if local.fix != null:
			for index in game.track.streams_at(local.fix.d):
				var s: Dictionary = game.track.streams[index]
				var offset: Vector2 = s["offset"]
				var dist := Vector2(local.fix.lateral - offset.x, local.fix.vertical - offset.y).length()
				stream = maxf(stream, clampf(1.0 - dist / float(s["radius"]), 0.0, 1.0))
		wake = clampf(local.slip_gain / maxf(game.settings.slip_gain, 0.01), 0.0, 1.0)
		if local.banner == "WRONG WAY" and local.banner_left > 0.0 and _wrong_cd <= 0.0:
			_wrong_cd = 1.5
			Sfx.play("race/wrong_way")
	_loop(&"_stream_loop", "race/stream_loop", stream, local)
	_loop(&"_slip_loop", "race/slipstream_loop", wake, local)


## A loop that fades with `amount` (0 stops it) and follows the local racer's fish.
func _loop(slot: StringName, id: String, amount: float, local: RaceMatch.Racer) -> void:
	var handle: int = get(slot)
	if amount <= 0.01 or local == null:
		if handle >= 0:
			Sfx.stop_loop(handle)
			set(slot, -1)
		return
	if handle < 0 or not Sfx.is_looping(handle):
		handle = Sfx.start_loop(id, local.fish)
		set(slot, handle)
	Sfx.set_loop(handle, amount, 0.9 + 0.3 * amount)


func _on_phase(phase: int) -> void:
	if phase == RaceMatch.Phase.RACING:
		Sfx.play("race/go")
	elif phase == RaceMatch.Phase.OVER:
		Sfx.play("race/race_over")


func _on_lap(fish: FishController, laps_done: int, _lap_time: float) -> void:
	if not _mine(fish):
		return
	Sfx.play("race/final_lap" if laps_done == game.settings.laps - 1 else "race/lap")


func _on_finished(fish: FishController, _place: int, _time: float) -> void:
	if _mine(fish):
		Sfx.play("race/finish")


func _on_rescued(fish: FishController, _reason: String) -> void:
	if _mine(fish):
		Sfx.play("race/rescue")
