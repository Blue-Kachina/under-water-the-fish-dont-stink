class_name ReplayData
extends RefCounted
## A Rocket League replay converted by tools/rl_replay (*.rlreplay.json, schema
## v1), loaded and converted into the arena's space once. Sample the ball or any
## car at any time; positions follow a cubic curve through the recorded
## velocities, rotations slerp, and nothing blends across a teleport. Each
## body is sampled on its own times: the converter works out when each of its
## samples really happened (they come from physics ticks a little before or
## after the frame's time, which played as recorded looks jittery).
##
## Car positions are RL's centre of mass, as recorded. The fish's origin is its
## hitbox centre, so ghosts add each player's hitbox offset (see ReplayCar).

const FORMAT := "uwfds.rlreplay"
const VERSION := 1
const FLAG_BOOST := 1
const FLAG_JUMP := 2
const FLAG_DOUBLE_JUMP := 4
const FLAG_DODGE := 8
const FLAG_POWERSLIDE := 16
const FLAG_SUPERSONIC := 32
const FLAG_DEMOLISHED := 64
## A recorded fish's looks (FishController.replay_fx, GoalRecorder clips
## only; RL replays have none): the stride tail's swing (rad) and growth, its
## timing cue, the stride's swing and power, the bow wave's size (0..1, then
## its shape in m), the stride bubbles poured (bubbles/s, then their colour),
## and the flow's share of its most.
const FX_TAIL_YAW := 0
const FX_TAIL_PITCH := 1
const FX_TAIL_SCALE := 2
const FX_CUE_FILL := 3
const FX_CUE_GLOW := 4
const FX_CUE_SWEET := 5
const FX_SWING_X := 6
const FX_SWING_Y := 7
const FX_POWER := 8
const FX_BOW := 9
const FX_BOW_X := 10
const FX_BOW_Y := 11
const FX_BOW_Z := 12
const FX_POUR := 13
const FX_POUR_R := 14
const FX_POUR_G := 15
const FX_POUR_B := 16
const FX_POUR_A := 17
const FX_FLOW := 18
const FX_SIZE := 19
const GAME_LIVE := 0
const GAME_COUNTDOWN := 1
const GAME_POST_GOAL := 2
## Samples further apart than this are held, not blended (s).
const MAX_BLEND_GAP := 0.25
## Safety net for teleports the converter missed: anything implying more than
## this speed between samples is held (m/s; RL's ball tops out at 60).
const MAX_BLEND_SPEED := 90.0
## The Aquarium has Blue defending +Z, RL's replays -Z (see RLSpace): turning
## the replay half round about the arena's centre lines them up, without
## mirroring anything.
const AQUARIUM_FROM_RL := Basis(Vector3.UP, PI)


## One body's recorded motion.
class Track:
	## When each sample really happened (the frame's time plus the body's offset).
	var times := PackedFloat64Array()
	var present := PackedByteArray()
	var teleport := PackedByteArray()
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var ang_vel := PackedVector3Array()
	var rot: Array[Quaternion] = []
	# Cars only.
	var boost := PackedFloat32Array()
	var throttle := PackedFloat32Array()
	var steer := PackedFloat32Array()
	var flags := PackedInt32Array()
	## Per sample, FX_SIZE looks (recorded fish only; empty otherwise).
	var fx: Array[PackedFloat32Array] = []


## A body's state at one moment (reused between calls to avoid allocations).
class Sample:
	var present := false
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var rotation := Quaternion.IDENTITY
	var angular_velocity := Vector3.ZERO
	## The frame at or before the sampled time, for step values like flags.
	var frame := 0
	var boost := 0.0
	var throttle := 0.0
	var steer := 0.0
	var flags := 0
	## The car's FX_* looks, blended between samples (empty when it has none).
	var fx := PackedFloat32Array()


var source := {}
var match_info := {}
## Per player: index, name, team, fish_class (its key; "" in RL's, which go by
## hitbox_family: FishCharacter.class_of), hitbox_family (the RL hitbox),
## species (its key; "" or missing: the class's first), hitbox_size (m; width,
## height, length as the fish's hitbox_* exports) and hitbox_offset (m, the
## hitbox centre from the centre of mass in the fish's frame).
var players: Array[Dictionary] = []
var times := PackedFloat64Array()
var game_state := PackedByteArray()
var seconds_remaining := PackedInt32Array()
var kickoff_countdown := PackedByteArray()
var ball := Track.new()
var cars: Array[Track] = []
## Each with "type", "time" and "frame", plus the type's own fields.
var events: Array[Dictionary] = []
var segments: Array[Dictionary] = []
var duration := 0.0
var path := ""

var _arena := Basis.IDENTITY


## Reads and converts a file. Returns "" on success, otherwise what was wrong.
## `turn_for_aquarium`: line the replay's teams up with the Aquarium's goals.
func load_file(file_path: String, turn_for_aquarium := true) -> String:
	if not FileAccess.file_exists(file_path):
		return "no such file: %s" % file_path
	var text := FileAccess.get_file_as_string(file_path)
	if text.is_empty():
		return "couldn't read %s (%s)" % [file_path, error_string(FileAccess.get_open_error())]
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return "%s isn't valid JSON" % file_path.get_file()
	path = file_path
	return load_document(parsed, turn_for_aquarium)


func load_document(doc: Dictionary, turn_for_aquarium := true) -> String:
	if doc.get("format") != FORMAT:
		return "not a converted replay (format %s); convert .replay files with tools/rl_replay" % doc.get("format")
	if int(doc.get("version", 0)) != VERSION:
		return "replay format version %s; this game reads version %d" % [doc.get("version"), VERSION]
	_arena = AQUARIUM_FROM_RL if turn_for_aquarium else Basis.IDENTITY
	source = doc.source
	match_info = doc.match
	var frames: Dictionary = doc.frames
	times = PackedFloat64Array(frames.time)
	var n := times.size()
	if n < 2:
		return "the replay has fewer than 2 frames"
	game_state = PackedByteArray(frames.game_state)
	seconds_remaining = PackedInt32Array(frames.seconds_remaining)
	kickoff_countdown = PackedByteArray(frames.kickoff_countdown)
	duration = times[n - 1]

	var problem := _read_track(doc.ball, ball, n, "ball")
	if problem:
		return problem
	players.clear()
	cars.clear()
	for raw_player: Dictionary in doc.players:
		var hitbox: Dictionary = raw_player.hitbox
		var offset: Array = hitbox.offset
		players.append({
			"index": int(raw_player.index), "name": str(raw_player.name), "team": int(raw_player.team),
			"fish_class": str(raw_player.get("fish_class", "")),  # none in RL's
			"hitbox_family": str(raw_player.hitbox_family),
			"species": str(raw_player.get("species", raw_player.get("skin", ""))),  # none in RL's: the class's first
			"hitbox_size": Vector3(hitbox.width, hitbox.height, hitbox.length) * RLSpace.M_PER_UU,
			"hitbox_offset": RLSpace.car_offset(Vector3(offset[0], offset[1], offset[2])),
		})
	var raw_cars: Array = doc.cars
	if raw_cars.size() != players.size():
		return "%d car tracks for %d players" % [raw_cars.size(), players.size()]
	for i in raw_cars.size():
		var track := Track.new()
		problem = _read_track(raw_cars[i], track, n, "cars[%d]" % i)
		if problem:
			return problem
		track.boost = PackedFloat32Array(raw_cars[i].boost)
		track.throttle = PackedFloat32Array(raw_cars[i].throttle)
		track.steer = PackedFloat32Array(raw_cars[i].steer)
		track.flags = PackedInt32Array(raw_cars[i].flags)
		if track.boost.size() != n or track.throttle.size() != n or track.steer.size() != n or track.flags.size() != n:
			return "cars[%d] controls don't match the frame count" % i
		cars.append(track)

	events.clear()
	for event: Dictionary in doc.events:
		var e := event.duplicate()
		e.frame = clampi(int(e.frame), 0, n - 1)
		e.time = times[e.frame]
		for key in ["player", "team", "attacker", "victim"]:
			if e.get(key) != null:
				e[key] = int(e[key])
		events.append(e)
	segments.clear()
	for segment: Dictionary in doc.segments:
		segments.append(segment.duplicate())
	return ""


func _read_track(raw: Dictionary, track: Track, n: int, label: String) -> String:
	var pos: Array = raw.pos
	var vel: Array = raw.vel
	var rot: Array = raw.rot
	var ang_vel: Array = raw.ang_vel
	if pos.size() != 3 * n or vel.size() != 3 * n or rot.size() != 4 * n or ang_vel.size() != 3 * n:
		return "%s's columns don't match the frame count" % label
	track.present = PackedByteArray(raw.present)
	track.teleport = PackedByteArray(raw.teleport)
	if track.present.size() != n or track.teleport.size() != n:
		return "%s's presence or teleport flags don't match the frame count" % label
	track.times = times.duplicate()
	var offsets: Array = raw.get("time_offset", [])  # older files have none
	if offsets.size() == n:
		for i in n:
			track.times[i] += offsets[i]
	track.pos.resize(n)
	track.vel.resize(n)
	track.ang_vel.resize(n)
	track.rot.resize(n)
	var turn := Quaternion(_arena)
	for i in n:
		var j := 3 * i
		track.pos[i] = _arena * RLSpace.pos(Vector3(pos[j], pos[j + 1], pos[j + 2]))
		track.vel[i] = _arena * RLSpace.pos(Vector3(vel[j], vel[j + 1], vel[j + 2]))
		track.ang_vel[i] = _arena * RLSpace.ang_vel(Vector3(ang_vel[j], ang_vel[j + 1], ang_vel[j + 2]))
		var k := 4 * i
		var basis := RLSpace.fish_basis(Quaternion(rot[k], rot[k + 1], rot[k + 2], rot[k + 3]))
		track.rot[i] = turn * basis.get_rotation_quaternion()
	return ""


## The last frame at or before `t`.
func frame_at(t: float) -> int:
	return clampi(times.bsearch(t, false) - 1, 0, times.size() - 1)


func sample_ball(t: float, out: Sample) -> Sample:
	return _sample(ball, t, out)


func sample_car(index: int, t: float, out: Sample) -> Sample:
	var track := cars[index]
	_sample(track, t, out)
	var i := out.frame
	out.boost = track.boost[i]
	out.throttle = track.throttle[i]
	out.steer = track.steer[i]
	out.flags = track.flags[i]
	if track.fx.is_empty():
		out.fx = PackedFloat32Array()
		return out
	var i1 := mini(i + 1, track.fx.size() - 1)
	var dt := track.times[i1] - track.times[i]
	var s := clampf((t - track.times[i]) / dt, 0.0, 1.0) if dt > 0.0 else 0.0
	var a := track.fx[i]
	var b := track.fx[i1]
	out.fx = a.duplicate()
	if s > 0.0 and out.present:
		for k in out.fx.size():
			out.fx[k] = lerpf(a[k], b[k], s)
	return out


func _sample(track: Track, t: float, out: Sample) -> Sample:
	# The frame whose sample (on this body's own times) is at or before t.
	var last := times.size() - 1
	var i0 := frame_at(t)
	while i0 < last and track.times[i0 + 1] <= t:
		i0 += 1
	while i0 > 0 and track.times[i0] > t:
		i0 -= 1
	var i1 := mini(i0 + 1, last)
	out.frame = i0
	out.present = track.present[i0] == 1
	out.position = track.pos[i0]
	out.velocity = track.vel[i0]
	out.rotation = track.rot[i0]
	out.angular_velocity = track.ang_vel[i0]
	if not out.present or i1 == i0 or track.present[i1] == 0 or track.teleport[i1] == 1:
		return out
	var dt := track.times[i1] - track.times[i0]
	if dt <= 0.0 or dt > MAX_BLEND_GAP:
		return out
	var p0 := track.pos[i0]
	var p1 := track.pos[i1]
	if p0.distance_to(p1) / dt > MAX_BLEND_SPEED:
		return out
	var s := clampf((t - track.times[i0]) / dt, 0.0, 1.0)
	var v0 := track.vel[i0]
	var v1 := track.vel[i1]
	# Cubic Hermite through both samples with their recorded velocities.
	out.position = p0.bezier_interpolate(p0 + v0 * dt / 3.0, p1 - v1 * dt / 3.0, p1, s)
	out.velocity = v0.lerp(v1, s)
	out.rotation = track.rot[i0].slerp(track.rot[i1], s)
	out.angular_velocity = track.ang_vel[i0].lerp(track.ang_vel[i1], s)
	return out


func state_at(t: float) -> int:
	return game_state[frame_at(t)]


## Goals so far as [blue, orange], counting a goal from the moment it's scored.
func score_at(t: float) -> Array:
	var score := [0, 0]
	for event in events:
		if event.time > t:
			break
		if event.type == "goal":
			score[event.team] += 1
	return score


func events_of(type: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event in events:
		if event.type == type:
			found.append(event)
	return found


## The time of the first event of `type` after `t` (or -1).
func next_event_time(type: String, t: float) -> float:
	for event in events:
		if event.type == type and event.time > t + 0.001:
			return event.time
	return -1.0


## The time of the last event of `type` before `t` (or -1), skipping one just
## behind it so stepping back twice gets past it.
func previous_event_time(type: String, t: float, skip_within := 1.0) -> float:
	var found := -1.0
	for event in events:
		if event.time >= t - skip_within:
			break
		if event.type == type:
			found = event.time
	return found
