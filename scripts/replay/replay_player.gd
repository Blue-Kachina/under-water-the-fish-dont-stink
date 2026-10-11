class_name ReplayPlayer
extends Node3D
## Plays a ReplayData back: a timeline (play, pause, speed, seek) driving one
## ghost per player and the ball. Times are the replay's playback seconds, from
## 0 (the converter closes up cut-out goal replays). Runs before the camera
## each frame, so the camera always sees this frame's ghosts.

signal time_changed(time: float)
signal target_changed(car: ReplayCar)
## Played (not jumped) past a goal.
signal goal_reached(event: Dictionary)
## The view jumped (a seek, a new target, or the followed car teleporting):
## anything easing after the target should snap to it.
signal cut
## The viewer's Target (`watch`) or Camera (`view`) changed.
signal view_changed

## `watch` values besides a player's index: the director picks who to watch,
## or the camera stays where it is.
const AUTO := -1
const FREE := -2
## How the camera shows them: the car cam behind the player (the game's follow
## camera), or the director's broadcast framing, with the ball in view.
enum View { PLAYER, DIRECTOR }

const SPEEDS := [0.1, 0.25, 0.5, 1.0, 1.5, 2.0, 4.0]

var data: ReplayData
var time := 0.0
var playing := true
var speed := 1.0
var loop := false
## Jump over the pause after each goal and the kickoff countdown.
var skip_pauses := false
var cars: Array[ReplayCar] = []
var ball: ReplayBall
## The soundtrack, if one's loaded (load_audio).
var audio: ReplayAudio
## The player being watched now: the Target if one's picked, else the
## director's pick.
var follow := 0
var show_hitboxes := false:
	set(value):
		show_hitboxes = value
		for car in cars:
			car.show_hitbox = value
var show_names := true:
	set(value):
		show_names = value
		for car in cars:
			car.show_name = value

var target: ReplayCar:
	get:
		return cars[follow] if follow >= 0 and follow < cars.size() else null
## The camera that follows a player (the game's follow camera), set before
## adding to the tree. The director's own camera does the director's framing
## and the free camera.
var follow_camera: Camera3D
var director_camera: DirectorCamera
## Target: a player's index (stay on them), AUTO (the director picks who) or
## FREE (the camera stays where it is). See set_watch.
var watch := AUTO
## Camera: View.PLAYER or View.DIRECTOR.
var view := View.DIRECTOR:
	set(value):
		if value == view:
			return
		view = value
		_apply_camera()
		view_changed.emit()

var _sample := ReplayData.Sample.new()
var _last_frame := -1


## Sets up the ghosts for `replay_data`. Call before adding to the tree.
func setup(replay_data: ReplayData) -> void:
	data = replay_data
	name = "ReplayPlayer"


func _ready() -> void:
	process_priority = -10  # before the follow camera
	ball = ReplayBall.new()
	ball.name = "ReplayBall"
	add_child(ball)
	for player in data.players:
		var car := ReplayCar.new()
		car.setup(player)
		car.show_hitbox = show_hitboxes
		car.show_name = show_names
		add_child(car)
		cars.append(car)
	follow = _first_present(0, 0.0)
	_update(false)
	target_changed.emit(target)
	director_camera = DirectorCamera.new()
	director_camera.setup(self)
	add_child(director_camera)
	_apply_camera()
	audio = ReplayAudio.new()
	audio.player = self
	add_child(audio)


## Plays `path` (.ogg, .mp3 or .wav, starting with the replay) along with the
## replay. Returns a problem, or "".
func load_audio(path: String) -> String:
	return audio.open(path)


func _exit_tree() -> void:
	if is_instance_valid(follow_camera):
		follow_camera.make_current()


func _apply_camera() -> void:
	if not is_inside_tree() or director_camera == null:
		return
	if watch == FREE:
		# Stays where the view is now; only the director's camera can be left standing.
		if not director_camera.current:
			director_camera.hold(get_viewport().get_camera_3d())
			director_camera.make_current()
	elif view == View.DIRECTOR:
		director_camera.cut()
		director_camera.make_current()
	elif is_instance_valid(follow_camera):
		follow_camera.make_current()
		cut.emit()


func _process(delta: float) -> void:
	if not playing:
		return
	var before := time
	time += delta * speed
	if time >= data.duration:
		if loop:
			seek(0.0)
			return
		time = data.duration
		playing = false
	if skip_pauses and data.state_at(time) != ReplayData.GAME_LIVE:
		var resume := data.next_event_time("kickoff", time)
		if resume > time:
			time = resume
			_update(false)
			cut.emit()
			time_changed.emit(time)
			return
	for event in data.events:
		if event.time > before and event.time <= time:
			if event.type == "goal":
				goal_reached.emit(event)
			elif event.type == "demo" and event.get("victim") != null:
				cars[event.victim].explode()
	_update(true)
	time_changed.emit(time)


func toggle_play() -> void:
	if not playing and time >= data.duration:
		seek(0.0)
	playing = not playing


func seek(to: float) -> void:
	time = clampf(to, 0.0, data.duration)
	_update(false)
	cut.emit()
	time_changed.emit(time)


## Moves the paused timeline a frame at a time (the replay's frames, about 30 a second).
func step(frames: int) -> void:
	playing = false
	var i := clampi(data.frame_at(time + 0.0001) + frames, 0, data.times.size() - 1)
	seek(data.times[i])


func set_speed_step(direction: int) -> void:
	var i := SPEEDS.find(speed)
	if i < 0:
		i = SPEEDS.find(1.0)
	speed = SPEEDS[clampi(i + direction, 0, SPEEDS.size() - 1)]


## A little before the next or previous goal, to see it built up.
func jump_to_goal(direction: int) -> void:
	var lead := 4.0
	var at := data.next_event_time("goal", time + lead) if direction > 0 else data.previous_event_time("goal", time + lead)
	if at >= 0.0:
		seek(maxf(at - lead, 0.0))


func jump_to_kickoff(direction: int) -> void:
	var at := data.next_event_time("kickoff", time) if direction > 0 else data.previous_event_time("kickoff", time)
	if at >= 0.0:
		seek(at)


## The next Target in the list Auto, the players in the game right now (by
## index), Free, round again.
func cycle_watch(direction := 1) -> void:
	var options: Array[int] = [AUTO]
	for i in cars.size():
		if i == watch or data.sample_car(i, time, _sample).present:
			options.append(i)
	options.append(FREE)
	var at := maxi(options.find(watch), 0)
	set_watch(options[posmod(at + direction, options.size())])


## The Target: player `value` (the camera stays on them), AUTO (the director
## picks who to watch) or FREE (the camera stays where it is).
func set_watch(value: int) -> void:
	if value >= cars.size() or value < FREE or value == watch:
		return
	var was_free := watch == FREE
	watch = value
	if watch >= 0 and watch != follow:
		follow = watch
		target_changed.emit(target)
		if not was_free:
			cut.emit()
	if watch == FREE or was_free:
		_apply_camera()
	view_changed.emit()


## Watch player `index`: the director's pick, while the Target is AUTO.
func set_target(index: int) -> void:
	if index == follow:
		return
	follow = clampi(index, 0, cars.size() - 1)
	target_changed.emit(target)
	if view == View.PLAYER:
		cut.emit()  # the car cam jumps to them, rather than swooping across


func _first_present(start: int, at: float, direction := 1) -> int:
	for k in cars.size():
		var i := posmod(start + k * direction, cars.size())
		if data.sample_car(i, at, _sample).present:
			return i
	return start


func _update(continuous: bool) -> void:
	ball.apply(data.sample_ball(time, _sample))
	for i in cars.size():
		cars[i].apply(data.sample_car(i, time, _sample))
	# The followed car jumping (a kickoff or respawn) is a cut for the camera.
	var frame := data.frame_at(time)
	if continuous and follow < cars.size() and frame != _last_frame:
		var track := data.cars[follow]
		for i in range(_last_frame + 1, frame + 1):
			if i >= 0 and track.teleport[i] == 1:
				cut.emit()
				break
	_last_frame = frame
