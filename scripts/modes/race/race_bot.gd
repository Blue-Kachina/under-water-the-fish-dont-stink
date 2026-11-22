class_name RaceBot
extends Node
## A racer for Fin-ish Line (planning_race.md section 9). Drives its FishController through `controls`, like WanderBot
## and HunterBot, and never touches its velocity: its speed comes from a stride chain (the stick flicked from side to
## side, each flick aimed at the current stride's peak, give or take the tier's timing error), exactly as a player's.
## What it does on the track:
##   - steers at a lookahead point on the racing line, further ahead the faster it goes (RaceSettings.bot_lookahead);
##   - brakes (lets go of the throttle, so the whole stick steers) for a bend, by curvature x its turn_scale;
##   - leans toward a bubble stream's core while one is ahead, and into a rival's wake (slipstream), then swings out
##     of the wake to pass; moves its line sideways inside the channel when a rival is in the way;
##   - keeps off the walls with Terrain.sdf (only where there is a terrain);
##   - uses a forward mobility skill on straights and any skill to get out of trouble;
##   - rubber band (bots only): a bot far behind the leader gains a little top speed, one far ahead loses a little.
## RaceMatch wires it: set `fish`, `track`, `tier`, `handling` (RaceHandling row), optionally `skill` (Traversal),
## `rivals` (every other racer) and `progress_of` (Callable(FishController) -> total progress in m; else it works
## each rival's out itself), then add_child. `go` stays false while the grid is held (the start reaction runs from
## when it turns true). Tier numbers are first guesses (play-test before tuning).

## Modifier set the rubber band pushes (a top_speed factor).
const MODS_RUBBER := "race.rubber"
## Per tier: stride timing error (s, std dev), chance of a lapse (a stride reversed as late as it goes), chance of a perfectly timed stride, reaction time at the start (s), how
## much of the racing line's offset it holds (1 = all), the share of the safe bend speed it brakes to (1 = at the limit),
## the chance it uses a skill when it could, and the chance it rides a stream it sees.
const TIERS := [
	{"timing_error": 0.16, "lapse": 0.30, "perfect_chance": 0.10, "reaction": 0.40, "tightness": 0.60, "margin": 0.75, "skill_use": 0.35, "stream_use": 0.50},
	{"timing_error": 0.09, "lapse": 0.12, "perfect_chance": 0.30, "reaction": 0.20, "tightness": 0.85, "margin": 0.90, "skill_use": 0.75, "stream_use": 0.85},
	{"timing_error": 0.035, "lapse": 0.02, "perfect_chance": 0.60, "reaction": 0.08, "tightness": 1.00, "margin": 0.92, "skill_use": 1.00, "stream_use": 1.00},
]
## Turn radius at speed v at full stick with turn_scale 1 is about RADIUS_K x v^2 (m), measured in Phase 0
## (3.6 m at 12.5 m/s, 6.8 at 18, 9 at 21).
const RADIUS_K := 0.022
## The longest it waits before reversing a stride, past its peak (s).
const MAX_LATE := 0.25
## A stride flick: the stick's reach, and the physics ticks it lasts.
const SWEEP := 0.95
const FLICK_TICKS := 3
## Steering: stick per radian off target, less this much per rad/s already turning that way.
const STEER_GAIN := 1.6
const STEER_DAMPING := 0.35
## More than this (degrees) off the heading to the aim point: let go of the throttle and steer with the whole stick.
const SHARP_TURN := 55.0
## The aim point moves sideways at most this much per metre of lookahead (a lane change is a slope, not a jump).
const MAX_SLOPE := 0.45
## Steering where it could start a stride, the stick stays this short of the stride threshold.
const COMMIT_STICK := 0.9
## How far a pass shifts the line sideways (m), and for how long (s).
const PASS_SHIFT := 3.5
const PASS_TIME := 2.5
## A rival counts as ahead inside this (m) along the track, and as in the way inside this sideways (m).
const SEE_AHEAD := 28.0
const IN_WAY := 3.0
## In a wake this long (s) it pulls out to pass.
const DRAFT_BEFORE_PASS := 1.4
## Keeps this far (m) of the channel's wall when it picks a sideways offset.
const WALL_MARGIN := 3.5
## Terrain wall avoidance: starts at this clearance (m) on a probe this far ahead (s of travel).
const WALL_CLEAR := 3.0
const WALL_PROBE := 0.8
## A stream further than this (m) from its racing line sideways is left alone.
const STREAM_REACH := 7.0
## Aim points with less rock clearance than this (m) are moved to a nearby open one (_open_point): the sideways and
## upward steps it tries (m).
## The body radius (m) and the sideways steps (m) _reachable tries to get round rock in the way.
const REACH_RADIUS := 1.4
const REACH_STEPS := [2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0]
const OPEN_CLEAR := 5.0
const OPEN_SIDE := [0.0, -1.5, 1.5, -3.0, 3.0, -4.5, 4.5, -6.0, 6.0]
const OPEN_RISE := [0.0, -2.0, 2.0, -4.0, 4.0]
## Mobility skills that are a burst forward (Traversal's classes): used on straights.
const BURST_SKILLS := [FishCharacter.FishClass.HUNTER, FishCharacter.FishClass.SCORCHER, FishCharacter.FishClass.LANCER,
		FishCharacter.FishClass.GLIDER]
## The aim error is re-rolled this often (s).
const NOISE_REROLL := 0.45
## Still this long (s) at low speed starts the recovery (and a skill to get out).
const STUCK_SPEED := 3.0
const STUCK_TIME := 1.0
## Backing off rock lasts this long (s), then it aims for the middle of the channel for RECOVER_TIME.
const BACK_TIME := 0.9
const RECOVER_TIME := 2.5
## Its heading for steering while striding is smoothed over this long (s).
const HEADING_SMOOTHING := 0.3

var fish: FishController
var track: RaceTrack
var tier := RaceSettings.Bots.NORMAL
## RaceMatch sets these by name (a bot node given fish, race, track, difficulty, handling, traversal): `difficulty` is
## the tier as an int and `traversal` the mobility skill.
var difficulty: int:
	get:
		return tier
	set(value):
		tier = clampi(value, 0, TIERS.size() - 1) as RaceSettings.Bots
var traversal: Traversal:
	get:
		return skill
	set(value):
		skill = value
## The RaceMatch it races in (untyped: duck calls racer_fish(), progress_of(fish), racing, fish_teleported). With one the
## rivals, progress, go and rescues come from it, and the rubber band is the match's (it pushes its own).
var race: Node
## Its RaceHandling row (turn_scale is read for the bend speed).
var handling := RaceHandling.NEUTRAL
## Its mobility skill (a Traversal), when the race has them on.
var skill: Traversal
## The other racers (the match keeps this up to date), and Callable(FishController) -> total progress (m) for them and
## for this bot; without it each racer's progress is worked out here.
var rivals: Array[FishController] = []
var progress_of := Callable()
## False while the grid is held: it doesn't stride.
var go := true
## An ideal driver: no noise, perfect timing, the racing line exactly (race_roster_bench measures handling with it).
var ideal := false
## Off: no rubber band for this bot (the match turns it off for humans anyway: they have no bot).
var rubber_enabled := true
var settings := RaceSettings.shared()

var input := FishInput.new()
var rng := RandomNumberGenerator.new()

## Stats for the sims: seconds, total and in a stream core / a rival's wake, and skills used.
var stream_time := 0.0
var slip_time := 0.0
var skills_used := 0
## Where along the lap (m) it got wedged against rock and had to back off (for the sims: trouble spots).
var wedges: Array[float] = []
## Where it is on the track (its own tracking, for the sim and the fallback progress).
var d_now := 0.0
var lap_progress := 0.0

var _time := 0.0
var _go_time := -1.0
var _sweep_sign := 1.0
var _stride_seen := -1
var _flip_at := 0.0
var _flick_left := 0
var _heading := Vector3.FORWARD
var _noise := Vector2.ZERO
var _noise_left := 0.0
var _hint := -1.0
var _last_d := 0.0
var _laps := 0
var _lap_init := false
var _pass_left := 0.0
var _pass_side := 1.0
var _draft := 0.0
var _still := 0.0
var _back_left := 0.0
var _recover_left := 0.0
var _stream_choice := {}  # stream index -> whether this bot rides it (one roll per stream per lap)
var _rival_hint := {}  # FishController -> last d (fallback progress)
var _rival_laps := {}
var _last_rubber := 1.0
var _skill_roll := 0.0


func _ready() -> void:
	process_physics_priority = -10  # before the fish samples its controls
	fish.controls = input
	rng.randomize()
	_heading = -fish.global_basis.z.normalized()
	if race != null:
		rubber_enabled = false  # the match runs the rubber band
		if race.has_signal("fish_teleported"):
			race.connect("fish_teleported", _on_teleported)


func _exit_tree() -> void:
	if is_instance_valid(fish) and _last_rubber != 1.0:
		fish.modifiers.pop(MODS_RUBBER)


## The match put a racer back on the track: a fresh mind from there.
func _on_teleported(who: FishController) -> void:
	if who == fish and track != null:
		reset(track.nearest(fish.global_position).d)


## The tier row with ideal driving applied.
func row() -> Dictionary:
	var r: Dictionary = (TIERS[tier] as Dictionary).duplicate()
	if ideal:
		r["timing_error"] = 0.0
		r["lapse"] = 0.0
		r["perfect_chance"] = 1.0
		r["reaction"] = 0.0
		r["tightness"] = 1.0
		r["margin"] = 1.0
		r["skill_use"] = 1.0
		r["stream_use"] = 1.0
	return r


## Back on the grid (a restart or a rescue): fresh stride, fresh mind.
func reset(at_d := -1.0) -> void:
	_heading = -fish.global_basis.z.normalized()
	_stride_seen = -1
	_flick_left = 0
	_pass_left = 0.0
	_draft = 0.0
	_still = 0.0
	_hint = at_d
	_stream_choice.clear()
	input.clear()


func _physics_process(delta: float) -> void:
	input.clear()
	if not is_instance_valid(fish) or track == null or fish.battered or fish.controls_locked:
		return
	_time += delta
	if race != null:
		go = bool(race.get("racing"))
		rivals = race.call("racer_fish")
	var cfg := row()
	var me := fish.global_position
	var fix := track.nearest(me, _hint)
	_hint = fix.d
	_track_laps(fix.d)
	d_now = fix.d
	if not go:
		_go_time = -1.0
		_apply_rubber(0.0)
		return
	if _go_time < 0.0:
		_go_time = _time
	if _time - _go_time < float(cfg["reaction"]):
		return
	var speed := fish.swim_velocity().length()
	var ahead := _rivals_ahead(fix, speed, delta)
	var aim := _aim_point(fix, speed, cfg, ahead, delta)
	aim = _avoid_walls(aim, me, fish.linear_velocity)
	_heading = _heading.slerp(-fish.global_basis.z, clampf(delta / HEADING_SMOOTHING, 0.0, 1.0)).normalized()
	_drive(aim, fix, speed, cfg, delta)
	_use_skill(fix, speed, cfg, ahead, delta)
	_apply_rubber(delta)
	_stats(fix, delta)


# --- Where to aim ----------------------------------------------------------------------------------------------

## The point it steers at: a lookahead on the racing line, moved sideways for a pass or a wake, toward a stream's core
## and away from the walls.
func _aim_point(fix: RaceTrack.Fix, speed: float, cfg: Dictionary, ahead: Dictionary, delta: float) -> Vector3:
	var look := maxf(settings.bot_lookahead_min, speed * settings.bot_lookahead)
	var d_aim := fix.d + look
	var f := track.sample(d_aim)
	var offset := track.line_offset(d_aim) * float(cfg["tightness"])
	if _recover_left > 0.0:
		_recover_left -= delta
		offset = 0.0
	# A rival in the way: sit in its wake for a moment, then pull out to pass.
	if _pass_left > 0.0:
		_pass_left -= delta
		offset = _pass_offset(f, offset)
	elif not ahead.is_empty():
		var rival_lat: float = ahead["lateral"]
		var gap: float = ahead["gap"]
		if settings.slipstream and gap > 2.0 and absf(rival_lat - fix.lateral) < IN_WAY * 2.0:
			_draft += delta
			offset = lerpf(offset, rival_lat, 0.8)  # into the wake
			if _draft >= DRAFT_BEFORE_PASS and gap < 12.0:
				_pass_left = PASS_TIME
				_pass_side = _side_with_room(f, rival_lat)
				_draft = 0.0
		elif absf(rival_lat - offset) < IN_WAY and gap < 14.0:
			_pass_side = _side_with_room(f, rival_lat)
			offset = rival_lat + _pass_side * PASS_SHIFT
	else:
		_draft = maxf(_draft - delta, 0.0)
	var up_off := 0.0
	var stream := _stream_target(f, d_aim, cfg)
	if stream.size() == 2:
		offset = lerpf(offset, stream[0], 0.7)
		up_off = stream[1]
	var room := maxf(f.width * 0.5 - WALL_MARGIN, 0.5)
	offset = clampf(offset, -room, room)
	up_off = clampf(up_off, -f.height * 0.3, f.height * 0.3)
	offset = clampf(offset, fix.lateral - look * MAX_SLOPE, fix.lateral + look * MAX_SLOPE)
	var point := _open_point(f, offset, up_off)
	return _reachable(f, point, offset, up_off)


## `point` if the way to it from the fish is clear of rock (Terrain.line_clear), else the nearest sideways shift of it that
## is: a pillar or a wall corner between the fish and its aim point sends it round, to the side the racing line prefers.
func _reachable(f: RaceTrack.Fix, point: Vector3, offset: float, up_off: float) -> Vector3:
	var me := fish.global_position
	if Terrain.sdf(me) > 500.0 or Terrain.line_clear(me, point, REACH_RADIUS):
		return point
	var prefer := signf(track.line_offset(f.d) - offset)
	if prefer == 0.0:
		prefer = 1.0 if f.width * 0.5 - offset >= f.width * 0.5 + offset else -1.0
	for step: float in REACH_STEPS:
		for sign_side: float in [prefer, -prefer]:
			var p := f.pos + f.right * (offset + step * sign_side) + f.up * up_off
			if Terrain.sdf(p) >= OPEN_CLEAR * 0.6 and Terrain.line_clear(me, p, REACH_RADIUS):
				return p
	return point


## The point at (offset, up_off) from the centreline, or, where the terrain leaves it too close to rock (the nominal
## channel is not the real one: blends, pillars, roofs), the nearest point round it with clearance, found by sampling
## Terrain.sdf over a small grid (sideways x up). Without a terrain it is the point itself.
func _open_point(f: RaceTrack.Fix, offset: float, up_off: float) -> Vector3:
	var wanted := f.pos + f.right * offset + f.up * up_off
	var here := Terrain.sdf(wanted)
	if here > 500.0 or here >= OPEN_CLEAR:
		return wanted
	var best := wanted
	var best_score := -INF
	for side: float in OPEN_SIDE:
		for rise: float in OPEN_RISE:
			var p := f.pos + f.right * (offset + side) + f.up * (up_off + rise)
			var score := minf(Terrain.sdf(p), OPEN_CLEAR) - 0.12 * absf(side) - 0.1 * absf(rise)
			if score > best_score:
				best_score = score
				best = p
	return best


func _pass_offset(f: RaceTrack.Fix, offset: float) -> float:
	var room := maxf(f.width * 0.5 - WALL_MARGIN, 0.5)
	return clampf(offset + _pass_side * PASS_SHIFT, -room, room)


## Which side of the channel has more room away from a rival at sideways offset `rival_lat` (+1 right, -1 left).
func _side_with_room(f: RaceTrack.Fix, rival_lat: float) -> float:
	var half := f.width * 0.5
	return 1.0 if (half - rival_lat) >= (half + rival_lat) else -1.0


## The first stream it rides ahead (or inside) as [offset right, offset up], or [].
func _stream_target(f: RaceTrack.Fix, d_aim: float, cfg: Dictionary) -> Array:
	for i in track.streams_at(d_aim):
		if not _stream_choice.has(i):
			_stream_choice[i] = rng.randf() < float(cfg["stream_use"])
		if _stream_choice[i]:
			var s: Dictionary = track.streams[i]
			var off: Vector2 = s.get("offset", Vector2.ZERO)
			if absf(off.x - track.line_offset(d_aim)) > STREAM_REACH:
				continue  # across the channel from its line: not worth the swing
			return [off.x, off.y]
	return []


## Steers away from a wall the terrain puts close ahead (only where a terrain is live).
func _avoid_walls(aim: Vector3, me: Vector3, velocity: Vector3) -> Vector3:
	var push := Vector3.ZERO
	var need := WALL_CLEAR + velocity.length() * 0.06  # more room the faster it goes
	for reach: float in [0.0, WALL_PROBE * 0.5, WALL_PROBE]:  # here, soon and further: the worst counts
		var probe := me + velocity * reach
		var clearance := Terrain.sdf(probe)
		if clearance > 500.0:
			return aim
		if clearance < need:
			var away := Terrain.normal(probe) * (need - clearance) * 3.0
			if away.length() > push.length():
				push = away
	return aim + push


## The nearest rival ahead inside SEE_AHEAD along the track: {"gap": m, "lateral": m, "fish": FishController}, or {}.
func _rivals_ahead(fix: RaceTrack.Fix, speed: float, _delta: float) -> Dictionary:
	var best := {}
	var best_gap := SEE_AHEAD + speed * 0.5
	for other in rivals:
		if not is_instance_valid(other) or other == fish:
			continue
		var gap := track.delta(fix.d, _d_of(other))
		if gap <= 1.0 or gap >= best_gap:
			continue
		var o := track.nearest(other.global_position, fix.d + gap, 12.0)
		best_gap = gap
		best = {"gap": gap, "lateral": o.lateral, "fish": other}
	return best


func _d_of(other: FishController) -> float:
	var hint: float = _rival_hint.get(other, -1.0)
	var fix := track.nearest(other.global_position, hint, 60.0 if hint >= 0.0 else track.lap_length)
	_rival_hint[other] = fix.d
	return fix.d


# --- Driving -----------------------------------------------------------------------------------------------------

## Strides toward `aim` (flicks across, the stick steering in between), braking for a bend.
func _drive(aim: Vector3, fix: RaceTrack.Fix, speed: float, cfg: Dictionary, delta: float) -> void:
	var basis := fish.global_basis.orthonormalized()
	var local := basis.inverse() * (aim - fish.global_position)
	var noise := _aim_noise(delta)
	var yaw := atan2(local.x, -local.z) + noise.x
	var pitch := atan2(local.y, Vector2(local.x, local.z).length()) + noise.y
	input.roll = clampf(basis.x.y * 3.0, -1.0, 1.0)
	var turning := Vector2(-fish.angular_velocity.dot(basis.y), fish.angular_velocity.dot(basis.x))
	var steer := Vector2(yaw, pitch) * STEER_GAIN - turning * STEER_DAMPING  # stick down (+y) lifts the nose
	var sharp := rad_to_deg(Vector2(yaw, pitch).length()) > SHARP_TURN
	var brake := _must_brake(fix, speed, cfg)
	if _back_left > 0.0:
		# Wedged against rock: back off it, then take the middle of the channel for a while.
		_back_left -= delta
		input.reverse = 1.0
		input.stick = Vector2.ZERO
		_stride_seen = -1
		if _back_left <= 0.0:
			_recover_left = RECOVER_TIME
			_still = -STUCK_TIME  # a pause before it can count as stuck again
		return
	if _still > STUCK_TIME:
		_back_left = BACK_TIME
		wedges.append(d_now)
		return
	if sharp or brake:
		input.forward = 0.0  # no strides: the stick just steers
		input.stick = (steer * (1.5 if sharp else 1.0)).limit_length(1.0)
		_stride_seen = -1
		return
	input.forward = 1.0
	_time_stride(cfg)
	input.stick = _resting_stick(steer.limit_length(1.0))
	if _flick_left > 0:
		input.stick = Vector2.ZERO if _flick_left == FLICK_TICKS else Vector2(_sweep_sign * SWEEP, 0.0)
		_flick_left -= 1


## True when the bend ahead is too tight for its speed: radius needed at v is RADIUS_K v^2 / turn_scale.
func _must_brake(fix: RaceTrack.Fix, speed: float, cfg: Dictionary) -> bool:
	if speed < 6.0:
		return false
	var span := clampf(speed * 0.9, 8.0, 40.0)
	var a := track.sample(fix.d + 2.0).forward
	var b := track.sample(fix.d + 2.0 + span).forward
	var curvature := a.angle_to(b) / span  # rad per m: 1 / radius
	if curvature < 0.002:
		return false
	var radius := 1.0 / curvature
	var safe := sqrt(radius * float(handling["turn_scale"]) / RADIUS_K) * float(cfg["margin"])
	return speed > safe


## The stick between flicks, steering: as far as `wanted` goes, unless that would start a stride of its own.
func _resting_stick(wanted: Vector2) -> Vector2:
	var threshold := fish.stride_threshold
	if wanted.length() < threshold * COMMIT_STICK:
		return wanted
	var toward_next := wanted.normalized().x * _sweep_sign < -fish.stride_reversal + 0.1
	if fish.swishy.phase < 0.0 or toward_next:
		return wanted.limit_length(threshold * COMMIT_STICK)
	return wanted


## Reverses the sweep around each stride's peak, give or take the tier's timing error.
func _time_stride(cfg: Dictionary) -> void:
	var swim := fish.swishy
	if swim.phase < 0.0:
		_stride_seen = -1
		if _flick_left <= 0:
			_flick()
		return
	if swim.strides != _stride_seen:
		_stride_seen = swim.strides
		var error := 0.0 if rng.randf() < float(cfg["perfect_chance"]) else rng.randfn(0.0, float(cfg["timing_error"]))
		if rng.randf() < float(cfg["lapse"]):
			error = MAX_LATE
		_flip_at = clampf(swim.peak_time() + error, 0.08, swim.peak_time() + MAX_LATE)
	if swim.phase >= _flip_at:
		_flick()
		_flip_at = INF  # once per stride


func _flick() -> void:
	_sweep_sign = -_sweep_sign
	_flick_left = FLICK_TICKS


## Steering noise (radians yaw, pitch), re-rolled now and then.
func _aim_noise(delta: float) -> Vector2:
	if ideal:
		return Vector2.ZERO
	_noise_left -= delta
	if _noise_left <= 0.0:
		_noise_left = NOISE_REROLL
		var sd := deg_to_rad(settings.noise_for(tier))
		_noise = Vector2(rng.randfn(0.0, sd), rng.randfn(0.0, sd * 0.5))
	return _noise


# --- Skills, rubber band, stats ---------------------------------------------------------------------------------

## A burst skill on a straight with the way clear; any skill when stuck.
func _use_skill(fix: RaceTrack.Fix, speed: float, cfg: Dictionary, ahead: Dictionary, delta: float) -> void:
	if speed < STUCK_SPEED:
		_still += delta
	else:
		_still = 0.0
	if skill == null or not settings.skills or skill.skill_wait() > 0.0 or skill.skill_active():
		return
	_skill_roll -= delta
	if _skill_roll > 0.0:
		return
	_skill_roll = 0.5  # decides twice a second at most
	var on_straight := track.sample(fix.d).forward.angle_to(track.sample(fix.d + 30.0).forward) < deg_to_rad(8.0)
	var burst := BURST_SKILLS.has(skill.fish_class())
	var wanted := false
	if _still > STUCK_TIME:
		wanted = true
	elif burst and on_straight and speed > 8.0 and rng.randf() < float(cfg["skill_use"]) \
			and (ahead.is_empty() or absf(float(ahead["lateral"]) - fix.lateral) > IN_WAY):
		wanted = true
	if wanted and skill.mobility():
		skills_used += 1


## Bots only: a bot behind the leader gains a little top speed, a bot well ahead loses a little (RaceSettings).
func _apply_rubber(delta: float) -> void:
	var strength := settings.rubber_for(tier)
	if ideal or not rubber_enabled or strength <= 0.0 or not progress_of.is_valid():
		if _last_rubber != 1.0:
			fish.modifiers.pop(MODS_RUBBER)
			_last_rubber = 1.0
		return
	var mine: float = progress_of.call(fish)
	var lead := mine
	var second := -INF
	for other in rivals:
		if not is_instance_valid(other) or other == fish:
			continue
		var p: float = progress_of.call(other)
		lead = maxf(lead, p)
		second = maxf(second, p)
	var factor := 1.0
	var behind := lead - mine
	if behind > 1.0:
		factor = 1.0 + strength * clampf(behind / settings.rubber_gap, 0.0, 1.0)
	elif second > -INF and mine - second > 1.0:
		factor = 1.0 - strength * 0.5 * clampf((mine - second) / settings.rubber_gap, 0.0, 1.0)
	if delta > 0.0 and absf(factor - _last_rubber) > 0.002:
		fish.modifiers.push(MODS_RUBBER, {"top_speed": factor})
		_last_rubber = factor


## Seconds in a stream's core and in a wake, for the sims.
func _stats(fix: RaceTrack.Fix, delta: float) -> void:
	for i in track.streams_at(fix.d):
		var s: Dictionary = track.streams[i]
		var off: Vector2 = s.get("offset", Vector2.ZERO)
		var across := Vector2(fix.lateral - off.x, fix.vertical - off.y).length()
		if across <= float(s.get("radius", 4.0)):
			stream_time += delta
			break
	for other in rivals:
		if not is_instance_valid(other) or other == fish:
			continue
		var rel := fish.global_position - other.global_position
		var back := -(-other.global_basis.z).dot(rel)  # how far behind the other it is
		var reach := settings.slip_length * maxf(other.body_scale * 1.2, 1.0)
		if back > 0.0 and back < reach and rel.length() > 0.001 \
				and rad_to_deg(acos(clampf(back / rel.length(), -1.0, 1.0))) < settings.slip_angle:
			slip_time += delta
			break


## Laps counted from d wrapping (for the fallback progress and the sim).
func _track_laps(d: float) -> void:
	if not _lap_init:
		_lap_init = true
		_laps = -1 if d > track.lap_length * 0.75 else 0  # the grid is behind the line
		_last_d = d
	if _last_d > track.lap_length * 0.75 and d < track.lap_length * 0.25:
		_laps += 1
	elif _last_d < track.lap_length * 0.25 and d > track.lap_length * 0.75 and _laps > 0:
		_laps -= 1
	_last_d = d
	lap_progress = track.progress(_laps, d)


## Total progress (m) of this bot, for a match that has no progress of its own.
func progress() -> float:
	return lap_progress
