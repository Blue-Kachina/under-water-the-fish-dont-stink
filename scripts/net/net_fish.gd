class_name NetFish
extends RefCounted
## A remote fish's recent snapshots (another player's, or on a guest the
## host's lone fish), and where to show it: INTERP_DELAY behind the newest, so
## it moves smoothly between snapshots through jitter and the odd lost one.
## Past the newest (a gap) it carries on a little at its last velocity, then
## holds.
##
## Times are the sender's clock (seconds). Their offset from ours is learnt
## from arrivals (the smallest gap seen recently: the quickest a message has
## come), so no clock sync is needed: render_time() is "now", in the sender's
## clock, less the delay.

## How far behind the newest snapshot it's shown (s).
const INTERP_DELAY := 0.1
## The most it carries on past the newest (s).
const MAX_EXTRAPOLATE := 0.25
## Snapshots kept (s).
const KEEP := 1.0
## How long the offset's smallest gap is remembered (s).
const OFFSET_WINDOW := 3.0

var fish: FishController
## Snapshots, oldest first: [time, position, rotation, velocity, fx].
var _shots: Array = []
## The sender's teleports so far (a new count: snap, don't glide).
var _teleports := -1
## Arrival gaps (our time - theirs) with when they came, for the offset.
var _gaps: Array = []
var _offset := 0.0


## A snapshot arrived (its time is the sender's).
func push(time: float, position: Vector3, rotation: Quaternion, velocity: Vector3, fx: PackedFloat32Array, teleports: int) -> void:
	var now := Time.get_ticks_usec() / 1e6
	_learn_offset(now - time, now)
	if teleports != _teleports:
		_teleports = teleports
		_shots.clear()  # a jump: start over from here
	if not _shots.is_empty() and time <= _shots[-1][0]:
		return  # old or repeated
	_shots.append([time, position, rotation, velocity, fx])
	while _shots.size() > 2 and _shots[0][0] < time - KEEP:
		_shots.pop_front()


## Forgets the snapshots (it's been moved: wait for new ones).
func clear() -> void:
	_shots.clear()


## A message from the sender stamped `time` (their clock) arrived: learn from it.
func note_time(time: float) -> void:
	var now := Time.get_ticks_usec() / 1e6
	_learn_offset(now - time, now)


## Now in the sender's clock, less the delay: the moment shown.
func render_time() -> float:
	return Time.get_ticks_usec() / 1e6 - _offset - INTERP_DELAY


## The sender's time now (no delay), e.g. to tell how old a message is.
func sender_now() -> float:
	return Time.get_ticks_usec() / 1e6 - _offset


func has_state() -> bool:
	return not _shots.is_empty()


## The state at `time` (sender's clock): [position, rotation, velocity, fx].
func sample(time: float) -> Array:
	if _shots.is_empty():
		return []
	if _shots.size() == 1 or time <= _shots[0][0]:
		var only: Array = _shots[0] if time <= _shots[0][0] else _shots[-1]
		return [only[1], only[2], only[3], only[4]]
	var last: Array = _shots[-1]
	if time >= last[0]:
		var ahead: float = minf(time - last[0], MAX_EXTRAPOLATE)
		return [last[1] + last[3] * ahead, last[2], last[3], last[4]]
	for i in range(_shots.size() - 1, 0, -1):
		var a: Array = _shots[i - 1]
		var b: Array = _shots[i]
		if time >= a[0]:
			var t: float = (time - a[0]) / maxf(b[0] - a[0], 0.0001)
			# Hermite between the two, with their velocities: smooth through turns.
			var span: float = b[0] - a[0]
			var p := _hermite(a[1], a[3] * span, b[1], b[3] * span, t)
			return [p, (a[2] as Quaternion).slerp(b[2], t), (a[3] as Vector3).lerp(b[3], t), b[4] if t > 0.5 else a[4]]
	return []


## Shows the fish where it was at render_time().
func apply() -> void:
	var state := sample(render_time())
	if state.is_empty() or not is_instance_valid(fish):
		return
	fish.set_net_state(Transform3D(Basis(state[1]), state[0]), state[2], state[3])


func _learn_offset(gap: float, now: float) -> void:
	_gaps.append([gap, now])
	while _gaps.size() > 1 and _gaps[0][1] < now - OFFSET_WINDOW:
		_gaps.pop_front()
	var best := INF
	for entry: Array in _gaps:
		best = minf(best, entry[0])
	_offset = best


static func _hermite(p0: Vector3, m0: Vector3, p1: Vector3, m1: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return p0 * (2.0 * t3 - 3.0 * t2 + 1.0) + m0 * (t3 - 2.0 * t2 + t) + p1 * (-2.0 * t3 + 3.0 * t2) + m1 * (t3 - t2)
