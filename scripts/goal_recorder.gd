class_name GoalRecorder
extends RefCounted
## Keeps the last few seconds of a match (the ball and every fish, each physics
## tick) and turns a stretch of it into a ReplayData clip for the goal replay
## (GoalReplay), so it plays back on the replay ghosts like a Rocket League
## replay does, along with the match's events (MatchStats: goals, shots, ...).
## Clear it at each kickoff: a clip never reaches back past one.

## Seconds kept.
const KEEP := 9.0
## Moving further than this (m) in one tick is a teleport, not motion.
const TELEPORT_DISTANCE := 3.0

var ball: Ball
var fish: Array[FishController] = []
## Seconds recorded since setup (the clock record() keeps).
var time := 0.0

var _times := PackedFloat64Array()
## Per tick: [present, position, velocity, rotation, angular velocity].
var _ball: Array = []
## Per fish, per tick: the same, then [boost, throttle, steer, flags, looks
## (FishController.replay_fx)].
var _fish: Array = []
## Events logged (log_event), with recorder times.
var _events: Array[Dictionary] = []


func setup(the_ball: Ball, the_fish: Array[FishController]) -> void:
	ball = the_ball
	fish = the_fish
	clear()


func clear() -> void:
	_times.clear()
	_ball.clear()
	_fish.clear()
	_events.clear()
	for i in fish.size():
		_fish.append([])


## Keeps `event` (its "player" an index into `fish`) for clips, stamped with the time now.
func log_event(event: Dictionary) -> void:
	var stamped := event.duplicate()
	stamped.time = time
	_events.append(stamped)


## Call once per physics tick.
func record(delta: float) -> void:
	time += delta
	_times.append(time)
	_ball.append(_body_state(ball, is_instance_valid(ball) and not ball.popped))
	for i in fish.size():
		var f := fish[i]
		var state := _body_state(f, is_instance_valid(f) and not f.battered)
		if is_instance_valid(f):
			var flags := 0
			if f.is_boosting:
				flags |= ReplayData.FLAG_BOOST
			if f.speed >= FishController.SUPERSONIC_SPEED:
				flags |= ReplayData.FLAG_SUPERSONIC
			if f.is_powersliding:
				flags |= ReplayData.FLAG_POWERSLIDE
			if f.is_flipping():
				flags |= ReplayData.FLAG_DODGE
			elif not f.on_surface:
				flags |= ReplayData.FLAG_JUMP
			state.append_array([f.boost_amount, f.input_forward - f.input_reverse, f.input_stick.x, flags, f.replay_fx()])
		else:
			state.append_array([0.0, 0.0, 0.0, 0, PackedFloat32Array()])
		_fish[i].append(state)
	# Drop what's too old, a second's worth at a time.
	if _times[0] < time - KEEP - 1.0:
		var keep_from := _times.bsearch(time - KEEP)
		_times = _times.slice(keep_from)
		_ball = _ball.slice(keep_from)
		for i in _fish.size():
			_fish[i] = _fish[i].slice(keep_from)
		_events.assign(_events.filter(func(e: Dictionary) -> bool: return e.time >= time - KEEP))


## The earliest time still kept.
func start_time() -> float:
	return _times[0] if not _times.is_empty() else time


## The recording from `from` to `to` (recorder times) as a replay whose time 0
## is `from`, with one player per fish (index, name, team, character).
func clip(from: float, to: float) -> ReplayData:
	var data := ReplayData.new()
	var i0 := clampi(_times.bsearch(from), 0, maxi(_times.size() - 2, 0))
	var i1 := clampi(_times.bsearch(to, false), i0 + 1, _times.size())
	data.times = _times.slice(i0, i1)
	for i in data.times.size():
		data.times[i] -= from
	var n := data.times.size()
	data.duration = data.times[n - 1] if n > 0 else 0.0
	data.game_state.resize(n)
	data.seconds_remaining.resize(n)
	data.kickoff_countdown.resize(n)
	data.ball = _track(_ball.slice(i0, i1), data.times, false)
	for i in fish.size():
		var f := fish[i]
		data.players.append({
			"index": i,
			"name": f.display_name if is_instance_valid(f) else "",
			"team": maxi(f.team, 0) if is_instance_valid(f) else i,
			"fish_class": FishCharacter.CLASSES[f.character].key if is_instance_valid(f) else "skirmisher",
			"hitbox_family": FishCharacter.rl_hitbox(f.character) if is_instance_valid(f) else "octane",
			"species": FishCharacter.species_key(f.character, f.species) if is_instance_valid(f) else "",
			"hitbox_size": FishCharacter.hitbox_size(f.character) if is_instance_valid(f) else Vector3.ONE,
			"hitbox_offset": Vector3.ZERO,  # the fish's origin is its hitbox centre already
		})
		data.cars.append(_track(_fish[i].slice(i0, i1), data.times, true))
	for event in _events:
		if event.time >= from and event.time <= to:
			var shifted := event.duplicate()
			shifted.time -= from
			shifted.frame = data.frame_at(shifted.time)
			data.events.append(shifted)
	return data


static func _body_state(body: Node3D, present: bool) -> Array:
	if not is_instance_valid(body):
		return [false, Vector3.ZERO, Vector3.ZERO, Quaternion.IDENTITY, Vector3.ZERO]
	var rigid := body as RigidBody3D
	return [present, body.global_position, rigid.linear_velocity, body.global_basis.orthonormalized().get_rotation_quaternion(),
			rigid.angular_velocity]


static func _track(states: Array, times: PackedFloat64Array, car: bool) -> ReplayData.Track:
	var track := ReplayData.Track.new()
	track.times = times
	var previous_present := false
	for i in states.size():
		var s: Array = states[i]
		var present: bool = s[0]
		track.present.append(1 if present else 0)
		var jumped := i > 0 and (s[1] as Vector3).distance_to(states[i - 1][1]) > TELEPORT_DISTANCE
		track.teleport.append(1 if i > 0 and present and (not previous_present or jumped) else 0)
		previous_present = present
		track.pos.append(s[1])
		track.vel.append(s[2])
		track.rot.append(s[3])
		track.ang_vel.append(s[4])
		if car:
			track.boost.append(s[5])
			track.throttle.append(s[6])
			track.steer.append(s[7])
			track.flags.append(s[8])
			var fx: PackedFloat32Array = s[9]
			if fx.size() == ReplayData.FX_SIZE:
				track.fx.append(fx)
	if car and track.fx.size() != track.flags.size():
		track.fx.clear()  # all or nothing
	return track
