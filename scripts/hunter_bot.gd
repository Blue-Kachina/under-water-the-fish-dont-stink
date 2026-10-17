class_name HunterBot
extends Node
## Hunt's opponent: a hostile fish that swims Extra Swishy like the player and
## tries to batter it. It drives its fish only through
## FishController.controls (a FishInput), like FishBot and WanderBot, and never
## touches its velocity: its speed comes from its own strides, timed off its own
## stride envelope with the error its BotDifficulty allows.
##
## Strides: throttle held, the stick flicked from side to side, each flick
## aimed at the current stride's peak (give or take timing_error). Between
## flicks the stick rests where it steers (a little toward the turn, and the
## pitch on the other axis). Turns too sharp for that let go of the throttle
## and steer with the whole stick.
##
## What it does:
## - hunt: swim at where it saw the player (reaction_time ago), led by
##   lead_skill and off by up to aim_error; too slow to commit when close, it
##   swings wide to build speed first;
## - commit: fast enough and close, it lets go of the throttle (so nothing
##   strides) and lines up the ram with the whole stick, coasting in on the
##   speed it built;
## - evade: when the player comes at it fast and nose on, it may (evade_chance)
##   turn hard across the player's line, sometimes with a dodge (dodge_chance);
## - recover: after a pass, swing away and build speed before turning back in.
## Near the edge of the arena it heads back in.

enum Mode { HUNT, COMMIT, EVADE, RECOVER }

## The longest it waits before reversing a stride, past its peak (s): a missed
## reversal shouldn't let the stride fade away completely.
const MAX_LATE := 0.25
## How much of the stick a stride sweep uses, and for how many physics ticks
## a flick lasts (the first through the middle) before it springs back.
const SWEEP := 0.95
const FLICK_TICKS := 3
## Turning further than this (degrees) off the way it's going: let go and steer.
## Close in (CLOSE_SHARP_RANGE), the first: at speed a gentle turn would only
## circle the target.
const SHARP_TURN := 70.0
const CLOSE_SHARP_TURN := 30.0
const CLOSE_SHARP_RANGE := 25.0
## Steering: stick per radian off target, less this much per rad/s it's
## already turning that way (so it doesn't swing past).
const STEER_GAIN := 1.6
const STEER_DAMPING := 0.35
## A fast fish within this (m), nose on, is a threat to react to.
const THREAT_RANGE := 20.0
## Seconds it keeps evading / recovering once it starts.
const EVADE_TIME := 0.9
const RECOVER_TIME := 1.4
## The aim error is re-rolled this often (s).
const AIM_REROLL := 1.5
## Too slow to commit and closer than this (m): swing wide first.
const COMMIT_RANGE := 14.0
## How much of its sideways drift it allows for when aiming (1 = all).
const DRIFT_ALLOWANCE := 1.0
## It commits this long (s) before it would reach the target at its speed.
const COMMIT_TIME := 0.35
## Steering where it could start a stride, the stick stays this short of it
## (this much of SwishySwim's stride_threshold).
const COMMIT_STICK := 0.9
## Its heading for steering while striding is smoothed over this long (s), so
## it steers by where it's going, not by the weave.
const HEADING_SMOOTHING := 0.3
## Physics ticks of each dodge step: hold jump, let go, then jump with the stick.
const JUMP_TICKS := 6
const PAUSE_TICKS := 4
const DODGE_TICKS := 6

var fish: FishController
## The fish it's after (the player's).
var target: FishController
var difficulty := BotDifficulty.basic()
## The slowest ram that batters (m/s).
var batter_speed := 10.0
## The arena it should stay in.
var arena_center := Vector3.ZERO
var arena_radius := INF
var mode := Mode.HUNT

var input := FishInput.new()
var rng := RandomNumberGenerator.new()

var _time := 0.0
## What it has seen of the target: [time, position, velocity, forward], oldest first.
var _seen: Array = []
## Which way the stride sweep goes now (+1 right).
var _sweep_sign := 1.0
## The stride the reversal below is for (SwishySwim.strides when it started).
var _stride_seen := -1
var _flip_at := 0.0
var _mode_left := 0.0
var _evade_dir := Vector3.ZERO
## Whether it has already made up its mind about the threat in progress.
var _threat_judged := false
var _aim_tilt := Vector2.ZERO
var _aim_left := 0.0
## The dodge in progress: ticks into it, -1 when there's none.
var _dodge_tick := -1
var _dodge_stick := Vector2.ZERO
var _heading := Vector3.FORWARD
## Ticks left in the current stride flick.
var _flick_left := 0


func _ready() -> void:
	process_physics_priority = -10  # before the fish samples its controls
	fish.controls = input
	rng.randomize()


## A kickoff: fresh stride, fresh mind.
func reset() -> void:
	mode = Mode.HUNT
	_heading = -fish.global_basis.z.normalized() if is_instance_valid(fish) else Vector3.FORWARD
	_mode_left = 0.0
	_seen.clear()
	_stride_seen = -1
	_threat_judged = false
	_dodge_tick = -1
	_aim_left = 0.0
	_flick_left = 0
	input.clear()


func _physics_process(delta: float) -> void:
	input.clear()
	_time += delta
	if not is_instance_valid(fish) or not is_instance_valid(target):
		return
	_remember_target()
	if fish.battered or fish.controls_locked:
		_stride_seen = -1
		return
	if _dodge_tick >= 0:
		_continue_dodge()
		return
	_aim_left -= delta
	if _aim_left <= 0.0:
		_aim_left = AIM_REROLL
		var spread := deg_to_rad(difficulty.aim_error)
		_aim_tilt = Vector2(rng.randfn(0.0, spread), rng.randfn(0.0, spread * 0.5))
	_heading = _heading.slerp(-fish.global_basis.z.normalized(), 1.0 - exp(-delta / HEADING_SMOOTHING)).normalized()
	_think(delta)
	_swim_to(_destination())


## Picks what to do from what it has seen.
func _think(delta: float) -> void:
	var seen := _seen_now()
	var me := fish.global_position
	var to_target: Vector3 = seen[1] - me
	var distance := to_target.length()
	_mode_left -= delta

	if _threatened(seen, distance):
		if not _threat_judged:
			_threat_judged = true
			if rng.randf() < difficulty.evade_chance:
				_start_evade(seen)
				return
	else:
		_threat_judged = false

	if _mode_left > 0.0 and (mode == Mode.EVADE or mode == Mode.RECOVER):
		return
	var fast := fish.speed >= batter_speed + difficulty.commit_speed_margin * 0.5
	var ahead := to_target.normalized().dot(_heading) > 0.5
	if mode == Mode.COMMIT:
		if fish.speed >= batter_speed and ahead and distance < COMMIT_RANGE:
			return
	elif fast and ahead and distance < maxf(fish.speed * COMMIT_TIME, 6.0):
		mode = Mode.COMMIT
		return
	mode = Mode.HUNT
	var behind := to_target.dot(-fish.global_basis.z) < 0.0
	var slow := fish.speed < batter_speed + difficulty.commit_speed_margin
	if (behind and distance < COMMIT_RANGE * 0.6) or (slow and distance < COMMIT_RANGE and not behind and fish.speed < batter_speed):
		mode = Mode.RECOVER
		_mode_left = RECOVER_TIME
		var away := (me - (seen[1] as Vector3))
		var side := away.cross(Vector3.UP)
		if side.length() < 0.1:
			side = Vector3.RIGHT
		_evade_dir = (away.normalized() + side.normalized() * (1.0 if rng.randf() < 0.5 else -1.0)).normalized()


## The player coming at it fast and nose on (as it saw it).
func _threatened(seen: Array, distance: float) -> bool:
	var velocity: Vector3 = seen[2]
	if distance > THREAT_RANGE or velocity.length() < batter_speed or target.battered:
		return false
	var from_target := (fish.global_position - (seen[1] as Vector3)).normalized()
	return (seen[3] as Vector3).dot(from_target) > 0.8 and velocity.dot(from_target) > 3.0


func _start_evade(seen: Array) -> void:
	mode = Mode.EVADE
	_mode_left = EVADE_TIME
	var line := (seen[2] as Vector3).normalized()
	var across := (fish.global_position - (seen[1] as Vector3))
	across -= line * across.dot(line)  # its offset from the player's line
	if across.length() < 0.3:
		across = line.cross(Vector3.UP if absf(line.y) < 0.9 else Vector3.RIGHT)
	_evade_dir = (across.normalized() * 2.0 + line * 0.5).normalized()
	if rng.randf() < difficulty.dodge_chance:
		var local := fish.global_basis.orthonormalized().inverse() * _evade_dir
		_dodge_stick = Vector2(signf(local.x) if absf(local.x) > 0.2 else 1.0, 0.0)  # a side dodge, toward the escape
		_dodge_tick = 0


## Where it's swimming now.
func _destination() -> Vector3:
	var me := fish.global_position
	var goal: Vector3
	match mode:
		Mode.EVADE, Mode.RECOVER:
			goal = me + _evade_dir * 20.0
		_:
			var seen := _seen_now()
			var at: Vector3 = seen[1]
			var lead := clampf(me.distance_to(at) / maxf(fish.speed, 5.0), 0.0, 2.0) * difficulty.lead_skill
			goal = at + (seen[2] as Vector3) * lead
			var offset := goal - me
			offset = offset.rotated(Vector3.UP, _aim_tilt.x)
			var side := offset.cross(Vector3.UP)
			if side.length() > 0.01:
				offset = offset.rotated(side.normalized(), _aim_tilt.y)
			goal = me + offset
			# Allow for its own drift: sliding sideways at this rate, it'd pass that
			# far to the side by the time it got there, so aim that far the other way.
			var line := (goal - me).normalized()
			var slip := fish.linear_velocity - line * fish.linear_velocity.dot(line)
			goal -= slip * clampf(me.distance_to(goal) / maxf(fish.speed, 5.0), 0.0, 1.5) * DRIFT_ALLOWANCE
	# Back toward the middle near the edge.
	var out := (goal - arena_center).length() - arena_radius * 0.8
	if out > 0.0:
		var back := (arena_center - me).normalized() * 30.0
		goal = goal.lerp(me + back, clampf(out / (arena_radius * 0.3), 0.0, 1.0))
	return goal


## Strides toward `goal`, steering by where the sweeps are centred.
func _swim_to(goal: Vector3) -> void:
	var basis := fish.global_basis.orthonormalized()
	var local := basis.inverse() * (goal - fish.global_position)
	var yaw := atan2(local.x, -local.z)  # + = to the right
	var pitch := atan2(local.y, Vector2(local.x, local.z).length())  # + = above
	input.roll = clampf(basis.x.y * 3.0, -1.0, 1.0)  # right side high: roll right, back upright
	# Toward the goal, damped by how fast it's already turning (+x = turning
	# right, +y = nose rising, as the stick has them).
	var turning := Vector2(-fish.angular_velocity.dot(basis.y), fish.angular_velocity.dot(basis.x))
	var steer := Vector2(yaw, pitch) * STEER_GAIN - turning * STEER_DAMPING  # stick down (+y) lifts the nose
	if mode == Mode.COMMIT:
		# Off the throttle nothing strides, so the whole stick can line it up; it
		# coasts in on the speed it built.
		input.forward = 0.0
		input.stick = (steer * 1.5).limit_length(1.0)
		_stride_seen = -1
		return
	var distance := fish.global_position.distance_to(goal) if mode == Mode.HUNT else INF
	var sharp := lerpf(CLOSE_SHARP_TURN, SHARP_TURN, clampf((distance - 10.0) / (CLOSE_SHARP_RANGE - 10.0), 0.0, 1.0))
	# Evading or recovering, it keeps striding as it turns: letting go would only
	# spin it on the spot and lose the speed it wants.
	if mode == Mode.HUNT and rad_to_deg(Vector2(yaw, pitch).length()) > sharp:
		input.forward = 0.0  # no strides: the stick just steers
		input.stick = steer.limit_length(1.0)
		_stride_seen = -1
		return
	input.forward = 1.0
	# Flicks across for the strides; in between, the stick steers.
	_time_stride()
	# Evading, any stride the steering starts is welcome.
	input.stick = steer.limit_length(1.0) if mode == Mode.EVADE else _resting_stick(steer.limit_length(1.0))
	if _flick_left > 0:
		# Through the middle first (so the flick counts as a sweep back), then
		# straight across, so each flick reverses the last.
		input.stick = Vector2.ZERO if _flick_left == FLICK_TICKS else Vector2(_sweep_sign * SWEEP, 0.0)
		_flick_left -= 1


## The stick between flicks, steering: as far as `wanted` goes, unless that
## would start a stride of its own (reaching the threshold toward where the
## next flick goes, or with no stride going), where it stays short of it.
func _resting_stick(wanted: Vector2) -> Vector2:
	var threshold := fish.stride_threshold
	if wanted.length() < threshold * COMMIT_STICK:
		return wanted
	var toward_next := wanted.normalized().x * _sweep_sign < -fish.stride_reversal + 0.1
	if fish.swishy.phase < 0.0 or toward_next:
		return wanted.limit_length(threshold * COMMIT_STICK)
	return wanted


## Reverses the sweep around each stride's peak, give or take its timing.
func _time_stride() -> void:
	var swim := fish.swishy
	if swim.phase < 0.0:
		# Nothing going: a flick starts a fresh stride.
		_stride_seen = -1
		if _flick_left <= 0:
			_flick()
		return
	if swim.strides != _stride_seen:
		_stride_seen = swim.strides
		var error := 0.0 if rng.randf() < difficulty.perfect_chance else rng.randfn(0.0, difficulty.timing_error)
		_flip_at = clampf(fish.stride_peak_time + error, 0.08, fish.stride_peak_time + MAX_LATE)
	if swim.phase >= _flip_at:
		_flick()
		_flip_at = INF  # once per stride


## A sweep the other way: the stick flicks out past the stride threshold for a
## moment and springs back, as a thumb does, so the sweep pushes without
## steering the fish round with it for the whole stride.
func _flick() -> void:
	_sweep_sign = -_sweep_sign
	_flick_left = FLICK_TICKS


## The dodge sequence, a few ticks per step (as FishBot's).
func _continue_dodge() -> void:
	input.roll = 0.0
	if _dodge_tick < JUMP_TICKS:
		input.jump = true
	elif _dodge_tick < JUMP_TICKS + PAUSE_TICKS:
		input.jump = false
	elif _dodge_tick < JUMP_TICKS + PAUSE_TICKS + DODGE_TICKS:
		input.jump = true
		input.stick = _dodge_stick
	else:
		_dodge_tick = -1
		return
	_dodge_tick += 1


func _remember_target() -> void:
	_seen.append([_time, target.global_position, target.linear_velocity, -target.global_basis.z.normalized()])
	while _seen.size() > 2 and _seen[1][0] <= _time - difficulty.reaction_time:
		_seen.pop_front()


## The target as it saw it reaction_time ago (or as early as it has).
func _seen_now() -> Array:
	return _seen[0] if not _seen.is_empty() else [_time, target.global_position, target.linear_velocity, -target.global_basis.z]
