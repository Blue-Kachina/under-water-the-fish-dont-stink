class_name StylePoints
extends RefCounted
## Hunt's points, a tally beside the goals (batteries): close calls, dodges,
## perfect rhythm and batteries, for both fish alike.
##
## A fish is threatened while the other comes at it fast enough to batter it
## (at least batter_speed), close (THREAT_RANGE) and with it in front of its nose
## (Battery.FRONT). When that ends without a battery, the threatened fish
## gets points if it came within CLOSE_CALL_DISTANCE:
## - a dodge if it did something about it: a dodge, or turned DODGE_TURN or more
##   from the way it was heading just before (its heading a moment ago,
##   smoothed, so a turn started as the threat closed in counts);
## - otherwise a close call: it just got missed.
## Each fish gets at most one of those per AWARD_COOLDOWN, so circling another
## fish doesn't farm them.
##
## Perfect rhythm is a streak: every STREAK_STEP perfect strides in a row
## (timing at or above SwishySwim.SWEET_SPOT, the gold bubbles) score; any other
## stride starts the count again. A point per stride would swamp everything else.
##
## The match calls update() every physics tick while play is live (live on),
## on_battery() for a battery, and detach() when it's done.

signal awarded(index: int, type: String, points: int, extra: Dictionary)

const CLOSE_CALL := "close_call"
const DODGE := "dodge"
const PERFECT_RHYTHM := "perfect_rhythm"
const BATTERY := "battery"
const POINTS := {CLOSE_CALL: 25, DODGE: 50, PERFECT_RHYTHM: 10, BATTERY: 100}
## What the callouts say.
const TITLES := {CLOSE_CALL: "CLOSE CALL", DODGE: "DODGE", PERFECT_RHYTHM: "PERFECT RHYTHM", BATTERY: "BATTERED"}
## How close (m, centre to centre) a fast fish must come for it to be a threat.
const THREAT_RANGE := 6.0
## How near (m, between hitboxes) a miss must be to score.
const CLOSE_CALL_DISTANCE := 2.5
## How far (degrees) a threatened fish must turn for its escape to count as a dodge.
const DODGE_TURN := 35.0
## The heading a turn is measured from trails the fish's by about this long (s).
const HEADING_LAG := 0.4
## A dodge this long (s) before a threat starts still counts for it.
const DODGE_LEAD := 0.6
const AWARD_COOLDOWN := 2.0
const STREAK_STEP := 4

## The two fish: index 0 the player's, 1 the opponent's.
var fish: Array[FishController] = []
## The slowest ram that batters (m/s).
var batter_speed := 10.0
## Off between plays (countdowns, after a battery): nothing scores.
var live := false
## Each fish's points.
var points := [0, 0]
## Each fish's counts: "close_calls", "dodges", "perfect" (strides),
## "best_streak", "batteries" and "top_speed" (m/s, live play).
var counts: Array[Dictionary] = []
## Each fish's current run of perfect strides.
var streaks := [0, 0]

## Per threatened fish: its open threat window, or empty.
var _windows: Array[Dictionary] = [{}, {}]
var _cooldown := [0.0, 0.0]
## Per fish: its heading, trailing by HEADING_LAG.
var _lagged := [Vector3.FORWARD, Vector3.FORWARD]
## Per fish: seconds since its last dodge.
var _since_dodge := [INF, INF]


func setup(the_fish: Array[FishController]) -> void:
	fish = the_fish
	for i in fish.size():
		fish[i].strode.connect(_on_strode.bind(i))
		fish[i].dodged.connect(_on_dodged.bind(i))
	reset()


## Lets go of the fish's signals.
func detach() -> void:
	for i in fish.size():
		if not is_instance_valid(fish[i]):
			continue
		if fish[i].strode.is_connected(_on_strode):
			fish[i].strode.disconnect(_on_strode)
		if fish[i].dodged.is_connected(_on_dodged):
			fish[i].dodged.disconnect(_on_dodged)


## A new match: everything back to nothing.
func reset() -> void:
	points = [0, 0]
	counts.clear()
	for i in 2:
		counts.append({"close_calls": 0, "dodges": 0, "perfect": 0, "best_streak": 0, "batteries": 0, "top_speed": 0.0})
	streaks = [0, 0]
	clear_windows()


## Forgets any threat in progress (a kickoff). Streaks carry on.
func clear_windows() -> void:
	_windows = [{}, {}]
	_cooldown = [0.0, 0.0]
	for i in fish.size():
		_lagged[i] = _heading(fish[i])


func update(delta: float) -> void:
	for i in fish.size():
		_cooldown[i] = maxf(_cooldown[i] - delta, 0.0)
		_since_dodge[i] += delta
		var heading := _heading(fish[i])
		_lagged[i] = _lagged[i].slerp(heading, 1.0 - exp(-delta / HEADING_LAG)).normalized()
	if not live:
		_windows = [{}, {}]
		return
	for i in fish.size():
		counts[i].top_speed = maxf(counts[i].top_speed, fish[i].speed)
	for victim in fish.size():
		var attacker := 1 - victim
		var window := _windows[victim]
		if threatens(fish[attacker], fish[victim]):
			if window.is_empty():
				window = {"closest": INF, "from": _lagged[victim], "turn": 0.0, "dodged": _since_dodge[victim] <= DODGE_LEAD}
				_windows[victim] = window
			window.closest = minf(window.closest, gap(fish[attacker], fish[victim]))
			window.turn = maxf(window.turn, rad_to_deg(window.from.angle_to(_heading(fish[victim]))))
		elif not window.is_empty():
			_windows[victim] = {}
			_judge_escape(victim, window)


## `attacker` battered `victim`: points for it, and no escape for `victim`.
func on_battery(attacker: int, victim: int) -> void:
	_windows[victim] = {}
	counts[attacker].batteries += 1
	_award(attacker, BATTERY, {"victim": victim})


## Whether `attacker` is coming at `victim` fast enough, close enough and nose on.
func threatens(attacker: FishController, victim: FishController) -> bool:
	if attacker.battered or victim.battered or attacker.speed < batter_speed:
		return false
	var offset := victim.global_position - attacker.global_position
	if offset.length() > THREAT_RANGE:
		return false
	return offset.normalized().dot(-attacker.global_basis.z) >= Battery.FRONT


## About how far apart (m) two fish's hitboxes are: 0 when they touch.
static func gap(a: FishController, b: FishController) -> float:
	var box_a := a.get_node("Collision") as CollisionShape3D
	var box_b := b.get_node("Collision") as CollisionShape3D
	# The point of each box nearest the other, refined once.
	var on_a := _nearest_on_box(box_a, box_b.global_position)
	var on_b := _nearest_on_box(box_b, on_a)
	on_a = _nearest_on_box(box_a, on_b)
	return on_a.distance_to(on_b)


static func _nearest_on_box(box: CollisionShape3D, point: Vector3) -> Vector3:
	var half := (box.shape as BoxShape3D).size / 2.0
	var xform := box.global_transform.orthonormalized()
	var local := xform.affine_inverse() * point
	return xform * local.clamp(-half, half)


static func _heading(f: FishController) -> Vector3:
	return -f.global_basis.z.normalized() if is_instance_valid(f) else Vector3.FORWARD


func _judge_escape(victim: int, window: Dictionary) -> void:
	if fish[victim].battered or window.closest > CLOSE_CALL_DISTANCE or _cooldown[victim] > 0.0:
		return
	_cooldown[victim] = AWARD_COOLDOWN
	if window.dodged or window.turn >= DODGE_TURN:
		counts[victim].dodges += 1
		_award(victim, DODGE, {"distance": window.closest})
	else:
		counts[victim].close_calls += 1
		_award(victim, CLOSE_CALL, {"distance": window.closest})


func _on_strode(timing: float, _flow: float, index: int) -> void:
	if not live:
		return
	if timing < SwishySwim.SWEET_SPOT:
		streaks[index] = 0  # a mistimed stride, or a fresh one after the last chain faded
		return
	streaks[index] += 1
	counts[index].perfect += 1
	counts[index].best_streak = maxi(counts[index].best_streak, streaks[index])
	if streaks[index] % STREAK_STEP == 0:
		_award(index, PERFECT_RHYTHM, {"streak": streaks[index]})


func _on_dodged(_direction: Vector3, index: int) -> void:
	_since_dodge[index] = 0.0
	if not _windows[index].is_empty():
		_windows[index].dodged = true


func _award(index: int, type: String, extra := {}) -> void:
	var value: int = POINTS[type]
	points[index] += value
	awarded.emit(index, type, value, extra)
