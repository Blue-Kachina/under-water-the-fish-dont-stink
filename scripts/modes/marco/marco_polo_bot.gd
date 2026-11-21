class_name MarcoPoloBot
extends Node
## Marco Polo's bots (planning_marco_polo.md §8): one per bot fish, made by
## MarcoPoloMatch (fish set, added, then bind). It plays whichever role its
## fish has this moment, so a hider caught in Join the Seekers just carries on
## as a seeker. Like HunterBot it drives its fish only through
## FishController.controls (a FishInput) and swims Extra Swishy: throttle held,
## the stick flicked across at each stride's peak, give or take a timing error
## from bot_stride_skill. Quiet swimming lets go of the throttle above a speed
## so it coasts rather than piling up noise.
##
## Hider:
## - picks a spot far from the seekers: behind furniture, low, in a working
##   bubble curtain, or a free porthole (lined up carefully: slow, nose first,
##   inside the angle, so it can miss and knock like anyone);
## - swims there quietly, and lets go to settle on the floor (hiders sink) when
##   a seeker comes close; still is invisible;
## - dares (bot_boldness): edges into a seeker's view at the edge of the murk to
##   score, and backs off when the seeker turns toward it or comes in;
## - throws its Fake Fish when a seeker closing in has it in sight, flips away
##   from a bow about to tag it, and leaves a porthole before the gauge runs out.
## Seeker: sees only what the scope (recent_pings) and its own view (in_sight
## with exposure) show, never where the hiders really are. It chases what it
## sees, then the newest loud blip, sweeps when there's nothing, calls Marco
## when it's been quiet a while and now and then waits outside a porthole.
## Seekers spread out: each heads for a blip no other bot seeker has claimed.
## A whale seeker (settings.whale_seeker) sees through game.whale_sees and its own
## cone and range, never calls Marco! (it's automatic), and hunts the streaks the
## calls leave (MarcoScan.streak_heads): a head and a heading, not an exact spot,
## so it swims ahead along the heading at bot_streak_lead and gives up on a head it
## has reached. Hiders hold still around a whale's calls (bot_freeze_*) and swim
## between them.
## Decoy (FakeFish's pilot): straight on along its heading at fake_speed, away
## from walls and furniture, striding badly on purpose with a flip or two.

enum Plan { IDLE, HIDE, SETTLE, DARE, PORTHOLE, SEEK }

## The longest a stride reversal waits past its peak (s), as HunterBot's.
const MAX_LATE := 0.25
const SWEEP := 0.95
const FLICK_TICKS := 3
const STEER_GAIN := 1.6
const STEER_DAMPING := 0.35
const COMMIT_STICK := 0.9
const JUMP_TICKS := 6
const PAUSE_TICKS := 4
const DODGE_TICKS := 6
## How far ahead it looks for walls (m, plus its speed's worth of `LOOK_AHEAD_TIME`).
const LOOK_AHEAD := 4.0
const LOOK_AHEAD_TIME := 0.6
# What the bots do is tuned in MarcoPoloSettings' Bots group (bot_*).

## Every bot seeker's claimed point, so they spread out (bot -> Vector3).
static var _claims := {}

var fish: FishController
var game: MarcoPoloMatch
var settings := MarcoPoloSettings.shared()
var input := FishInput.new()
var rng := RandomNumberGenerator.new()
## FakeFish's pilot: swim the decoy instead of playing a role.
var decoy := false
var plan := Plan.IDLE

var _time := 0.0
var _role := -1
var _goal := Vector3.ZERO
var _spot := Vector3.ZERO
var _porthole: Porthole
var _plan_left := 0.0
var _heading := Vector3.FORWARD
var _stride_seen := -1
var _flip_at := 0.0
var _sweep_sign := 1.0
var _flick_left := 0
var _dodge_tick := -1
var _dodge_stick := Vector2.ZERO
var _stuck := 0.0
var _jump_ticks := 0
## Swimming up to a porthole to jump in: the closest it's got (m) and how long
## (s) it has left to get closer before it hops free of whatever holds it.
var _approach_best := INF
var _approach_left := 0.0
# Seeker memory: what it's chasing, where it last saw it, and when it last had anything.
var _target: FishController
var _last_seen := Vector3.ZERO
var _last_seen_velocity := Vector3.ZERO
var _last_news := 0.0
var _look_left := 0.0
var _waiting := 0.0
## Whale seeker: streak heads it has been to ({pos, until}); hider: the last
## auto-Marco countdown seen, and how long ago the whale called (s).
var _visited: Array[Dictionary] = []
var _visit_time := 0.0
var _prev_auto_left := -1.0
## Hider: the hideaway it's heading for (an index, -1 none), the one it just left and for how long (s).
var _hideaway := -1
var _ban := -1
var _ban_left := 0.0
var _since_call := INF
# Decoy: when it next flips.
var _next_flip := 0.0


func _ready() -> void:
	process_physics_priority = -10  # before the fish samples its controls
	rng.randomize()
	if is_instance_valid(fish):
		fish.controls = input
		_heading = -fish.global_basis.z.normalized()
	_next_flip = rng.randf_range(0.8, 2.0)


func bind(match_node: MarcoPoloMatch) -> void:
	game = match_node
	settings = match_node.settings


## Hider: head for porthole `p` now (probes; the bot's own picks go the same way).
func go_to_porthole(p: Porthole) -> void:
	if game:
		_role = game.role_of(fish)  # so its first tick doesn't take this for a role change
	_porthole = p
	plan = Plan.PORTHOLE
	_plan_left = 0.0
	_approach_best = INF


func _exit_tree() -> void:
	_claims.erase(self)


func _physics_process(delta: float) -> void:
	input.clear()
	_time += delta
	if not is_instance_valid(fish):
		return
	_heading = -fish.global_basis.z.normalized()
	if decoy:
		_pilot_decoy(delta)
		return
	if game == null or not game.players.has(fish):
		return
	var now_role := game.role_of(fish)
	if now_role != _role:
		_role = now_role
		_reset_plan()
	if game.eliminated.has(fish) or fish.battered or fish.controls_locked or game.phase in [MarcoPoloMatch.Phase.ROUND_OVER, MarcoPoloMatch.Phase.OVER]:
		_stride_seen = -1
		_claims.erase(self)
		return
	if _dodge_tick >= 0:
		_continue_dodge()
		return
	if _role == MarcoPoloMatch.Role.SEEKER:
		if game.phase == MarcoPoloMatch.Phase.LIVE:
			_seek(delta)
	else:
		_hide(delta)


func _reset_plan() -> void:
	plan = Plan.IDLE
	_plan_left = 0.0
	_porthole = null
	_target = null
	_last_news = _time
	_waiting = 0.0
	_stuck = 0.0
	_stride_seen = -1
	_dodge_tick = -1
	_claims.erase(self)


# --- Hider ------------------------------------------------------------------

func _hide(delta: float) -> void:
	var system := game.porthole_system as PortholeSystem
	if system and system.is_hidden(fish):
		_in_porthole(system)
		return
	_ban_left -= delta
	var hides := game.hideaway_system
	if hides and bool(hides.call("is_hidden", fish)):
		if float(hides.call("gauge", fish)) < settings.bot_hideaway_leave:
			plan = Plan.SETTLE  # hands off: still inside, quiet
			_plan_left = maxf(_plan_left, 1.0)
			return
		if _ban_left <= 0.0:
			_ban = int(hides.call("hideaway_of", fish))  # Stale Water's high: out before it flushes it noisily
			_ban_left = 6.0
			plan = Plan.HIDE
			_spot = _pick_spot(_nearest_seeker())
	var threat := _nearest_seeker()
	var threat_distance := INF if threat == null else threat.global_position.distance_to(fish.global_position)
	var live := game.phase == MarcoPoloMatch.Phase.LIVE
	if live and threat and threat_distance < settings.bot_flip_range and _coming_at(threat, 0.8):
		var away := (fish.global_position - threat.global_position).normalized()
		_start_dodge(_stick_toward(fish.global_position + away.cross(Vector3.UP) * (1.0 if rng.randf() < 0.5 else -1.0)))
		plan = Plan.HIDE
		_spot = _pick_spot(threat)
		return
	if live and threat and threat_distance < settings.bot_throw_range and game.fake_charges(fish) > 0 and game.in_sight(threat, fish) \
			and game.exposure(threat, fish) >= settings.layer_skeleton and _coming_at(threat, 0.6):
		if game.throw_fake(fish):
			plan = Plan.HIDE
			_spot = _pick_spot(threat)
			return
	if live and _hold_for_call(threat, delta):
		return
	_plan_left -= delta
	match plan:
		Plan.IDLE:
			plan = Plan.HIDE
			_spot = _pick_spot(threat)
		Plan.HIDE:
			if live and threat and threat_distance < settings.bot_settle_range and _coming_at(threat, 0.3):
				plan = Plan.SETTLE
				_plan_left = rng.randf_range(2.0, 4.0)
				return
			if _porthole:
				plan = Plan.PORTHOLE
				return
			if fish.global_position.distance_to(_spot) < 2.5:
				plan = Plan.SETTLE
				_plan_left = rng.randf_range(4.0, 9.0) * (1.5 - settings.bot_boldness)
				return
			_swim_quietly(_spot, delta)
		Plan.SETTLE:
			# Hands off: it sinks to the floor and goes still.
			if threat and threat_distance < settings.bot_settle_range:
				_plan_left = maxf(_plan_left, 1.0)
			if _plan_left <= 0.0:
				if live and threat and rng.randf() < settings.bot_boldness:
					plan = Plan.DARE
					_spot = _dare_point(threat)
					_plan_left = rng.randf_range(3.0, 6.0)
				else:
					plan = Plan.HIDE
					_spot = _pick_spot(threat)
		Plan.DARE:
			if threat == null or _plan_left <= 0.0 or threat_distance < settings.bot_settle_range * 0.8 or _coming_at(threat, 0.5) \
					or game.exposure(threat, fish) >= settings.layer_muscle:
				plan = Plan.HIDE
				_spot = _pick_spot(threat)
				return
			_swim_quietly(_spot, delta)
		Plan.PORTHOLE:
			_line_up(system, delta)


## A whale's automatic Marco!: hold still just before and after each call (hands
## off, so it sinks and goes quiet), carry on in between. True while holding.
func _hold_for_call(whale: FishController, delta: float) -> bool:
	_since_call += delta
	if whale == null or not game.uses_auto_marco(whale):
		_prev_auto_left = -1.0
		return false
	var left := game.auto_marco_left(whale)
	if _prev_auto_left >= 0.0 and left > _prev_auto_left + 0.3:
		_since_call = 0.0
	_prev_auto_left = left
	var tell := settings.marco_tell_time
	if left >= 0.0 and left < settings.bot_freeze_before + tell or _since_call < settings.bot_freeze_after:
		input.forward = 0.0
		input.roll = clampf(fish.global_basis.x.y * 3.0, -1.0, 1.0)
		_stride_seen = -1
		return true
	return false


## The hider's spot: furthest from the seekers among the arena's hider spawns,
## curtains, furniture-sheltered floor and (sometimes) a free porthole.
func _pick_spot(threat: FishController) -> Vector3:
	_porthole = null
	var arena := game.arena as MarcoArena
	var candidates: Array[Vector3] = []
	if arena:
		for spawn in arena.hider_spawns():
			candidates.append(spawn.origin + Vector3(rng.randf_range(-4.0, 4.0), -spawn.origin.y + 1.0, rng.randf_range(-4.0, 4.0)))
		for curtain in arena.curtains():
			if curtain.on_time >= 0.0:
				candidates.append(curtain.global_position + Vector3(0.0, 1.5, 0.0))
		for n in 4:
			var half := arena.size * 0.5 - Vector3(5.0, 0.0, 5.0)
			candidates.append(arena.global_position + Vector3(rng.randf_range(-half.x, half.x), 1.0, rng.randf_range(-half.z, half.z)))
	else:
		for n in 6:
			candidates.append(game.center + Vector3(rng.randf_range(-20.0, 20.0), 0.0, rng.randf_range(-20.0, 20.0)))
	var from := threat.global_position if threat else (arena.seeker_start().origin if arena else game.center)
	var best := candidates[0] if not candidates.is_empty() else fish.global_position
	var best_score := -INF
	for at in candidates:
		var score := at.distance_to(from) - at.distance_to(fish.global_position) * 0.35 + rng.randf_range(0.0, 8.0)
		if score > best_score:
			best_score = score
			best = at
	_hideaway = -1
	var hides := game.hideaway_system
	if hides and settings.hideaways_on and float(hides.call("gauge", fish)) < 0.4 \
			and rng.randf() < settings.bot_hideaway_chance + (0.3 if threat and game.is_whale(threat) else 0.0):
		var pick := -1
		var pick_score := -INF
		for i in int(hides.call("count")):
			if i == _ban and _ban_left > 0.0 or not bool(hides.call("has_room", i)):
				continue
			var at: Vector3 = hides.call("position_of", i)
			var score := at.distance_to(from) - at.distance_to(fish.global_position) * 0.5
			if score > pick_score:
				pick_score = score
				pick = i
		if pick >= 0 and pick_score > best_score - 40.0:
			_hideaway = pick
			return hides.call("position_of", pick)
	var system := game.porthole_system as PortholeSystem
	if system and rng.randf() < settings.bot_porthole_chance + settings.bot_boldness * 0.3:
		var choice: Porthole
		var choice_score := -INF
		for p in system.portholes():
			if not p.is_free() or system.gauge(fish) > 0.3 or system.opening(fish) < fish.hitbox_width * 0.5:
				continue
			var score := p.mouth().distance_to(from) - p.mouth().distance_to(fish.global_position) * 0.5
			if score > choice_score:
				choice_score = score
				choice = p
		if choice and choice_score > best_score - 10.0:
			_porthole = choice
			_approach_best = INF
			return choice.mouth() + choice.axis() * settings.bot_line_up
	return best


## Where to dare: at the edge of `threat`'s view, about two thirds of the way
## out to the murk, where the layers are faint but the points count.
func _dare_point(threat: FishController) -> Vector3:
	var forward := -threat.global_basis.z.normalized()
	var side := forward.cross(Vector3.UP).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
	var reach := game.sight_range() * rng.randf_range(0.5, 0.75)
	var at := threat.global_position + (forward + side * 0.35).normalized() * reach
	var arena := game.arena as MarcoArena
	if arena:
		var half := arena.size * 0.5 - Vector3(4.0, 0.0, 4.0)
		var local := at - arena.global_position
		at = arena.global_position + Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, 2.0, arena.size.y * 0.5), clampf(local.z, -half.z, half.z))
	return at


## Into the chosen porthole: with porthole_jump_entry, up to its mouth and
## Jump; else out at settings.bot_line_up on its axis, then slowly nose first.
func _line_up(system: PortholeSystem, delta: float) -> void:
	if system == null or not is_instance_valid(_porthole) or not _porthole.is_free():
		plan = Plan.HIDE
		_spot = _pick_spot(_nearest_seeker())
		return
	var p := _porthole
	if settings.porthole_jump_entry:
		if system.jump_porthole(fish) != null:
			# A tap: pressed a couple of ticks, let go, and again if it's still out.
			_jump_ticks += 1
			input.jump = _jump_ticks <= 2
			if _jump_ticks > 8:
				_jump_ticks = 0
			return
		_jump_ticks = 0
		var close := p.mouth() + p.axis() * minf(1.2, settings.porthole_jump_range * 0.5)
		var distance := fish.global_position.distance_to(close)
		if distance < _approach_best - 0.5:
			_approach_best = distance
			_approach_left = settings.bot_stuck_time
		else:
			_approach_left -= delta
			if _approach_left <= 0.0:
				input.jump = true  # caught on something: hop free (a jump's noise)
				_approach_best = distance
				_approach_left = settings.bot_stuck_time
				return
		_swim_quietly(close, delta, clampf(distance * 0.6, 1.5, settings.porthole_entry_speed * 1.5))
		return
	var front := p.mouth() + p.axis() * settings.bot_line_up
	var along := p.along(fish.global_position)
	var off := p.off_axis(fish.global_position)
	var speed := fish.linear_velocity.length()
	if along > settings.bot_line_up + 2.5 or off > 1.2 or (along > 1.5 and speed > settings.porthole_entry_speed):
		# Out to the line-up point, slowing as it gets there so it doesn't overshoot.
		var to_front := fish.global_position.distance_to(front)
		_swim_quietly(front, delta, clampf(to_front * 0.6, 2.0, settings.porthole_entry_speed * 1.5))
		return
	# Lined up: in nose first along the axis (aiming at a point on it a little
	# ahead, so sinking off it steers back up), striding gently only while
	# slow and facing in, coasting otherwise.
	var goal := p.mouth() + p.axis() * maxf(along - 1.5, -2.0)
	if along < 1.5:
		goal = p.mouth() - p.axis() * 2.0
	var facing := _heading.dot(-p.axis())
	input.roll = clampf(fish.global_basis.x.y * 3.0, -1.0, 1.0)
	if facing > 0.9 and speed < settings.porthole_entry_speed * 0.45:
		_stride_toward(goal, _timing_error(), settings.bot_stride_skill * 0.6)
	else:
		input.forward = 0.0
		input.stick = (_steer(goal) * 1.5).limit_length(1.0)
		_stride_seen = -1
	_stuck_check(delta, 0.15)


func _in_porthole(system: PortholeSystem) -> void:
	plan = Plan.PORTHOLE
	var threat := _nearest_seeker()
	var close := threat and threat.global_position.distance_to(fish.global_position) < settings.bot_settle_range * 0.6
	var leave := system.gauge(fish) >= settings.bot_porthole_leave * (0.8 + settings.bot_boldness * 0.4) and not close
	leave = leave or system.gauge(fish) >= 0.92
	if leave:
		_jump_ticks += 1
		input.jump = _jump_ticks <= 3
		if _jump_ticks > 3:
			plan = Plan.HIDE
			_porthole = null
			_spot = _pick_spot(threat)
			_jump_ticks = 0
	else:
		_jump_ticks = 0


## Its nearest seeker (hiders can see them).
func _nearest_seeker() -> FishController:
	var best: FishController
	var best_distance := INF
	for seeker in game.seekers():
		var d := seeker.global_position.distance_to(fish.global_position)
		if d < best_distance:
			best_distance = d
			best = seeker
	return best


## Whether `other` is heading at this fish (its facing within acos(`cosine`)).
func _coming_at(other: FishController, cosine: float) -> bool:
	var to_me := fish.global_position - other.global_position
	return (-other.global_basis.z).normalized().dot(to_me.normalized()) > cosine


# --- Seeker -----------------------------------------------------------------

func _seek(delta: float) -> void:
	if game.is_whale(fish):
		_seek_whale(delta)
		return
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = settings.bot_look_every
		_look()
	if is_instance_valid(_target):
		_claims[self] = _last_seen
		var guess := _last_seen + _last_seen_velocity * 0.3
		_swim_at(guess, delta, true)
		if fish.global_position.distance_to(guess) < 2.0 and _time - _last_news > 0.6:
			_target = null  # lost it
		return
	_target = null
	var ping := _best_ping()
	if not ping.is_empty():
		var at: Vector3 = ping.pos
		_claims[self] = at
		_waiting = 0.0
		_swim_at(at, delta, float(ping.loudness) > 0.5)
		return
	_claims.erase(self)
	if _time - _last_news > settings.bot_marco_quiet and game.marco_ready(fish) >= 1.0:
		if game.marco(fish):
			_last_news = _time
			return
	_sweep(delta)


## A whale: what it sees, else the best streak head, else a sweep (its calls are automatic).
func _seek_whale(delta: float) -> void:
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = settings.bot_look_every
		_look()
	var boost_range := settings.bot_whale_boost_range
	if is_instance_valid(_target):
		_claims[self] = _last_seen
		var guess := _last_seen + _last_seen_velocity * 0.3
		_swim_whale(guess, delta, fish.global_position.distance_to(guess) < boost_range)
		if fish.global_position.distance_to(guess) < 2.0 and _time - _last_news > 0.6:
			_target = null
		return
	_target = null
	_visit_time = _visit_time if _visit_time > 0.0 else 0.0
	var head := _best_streak()
	if not head.is_empty():
		var at: Vector3 = head.at
		_claims[self] = at
		_waiting = 0.0
		var d := fish.global_position.distance_to(at)
		if d < 6.0:
			_visit_time += delta
			if _visit_time >= settings.bot_streak_visit * 0.25:
				_visited.append({"pos": at, "until": _time + settings.bot_streak_visit})
				_visit_time = 0.0
		else:
			_visit_time = 0.0
		_swim_whale(at, delta, d < boost_range and float(head.strength) > 0.5)
		return
	_claims.erase(self)
	_sweep(delta)


## Swim as a whale: wide turns take the whole stick, the strokes are the strides.
func _swim_whale(goal: Vector3, delta: float, hurry: bool) -> void:
	_swim_at(goal, delta, hurry)


## The streak head worth going to: the guessed spot ahead of it, young, strong,
## near, not one it has been to and not another seeker's. {at, strength} or {}.
func _best_streak() -> Dictionary:
	var best := {}
	var best_score := -INF
	_visited = _visited.filter(func(v: Dictionary) -> bool: return float(v.until) > _time)
	for head in game.streak_heads_of(fish):
		var age := float(head.age)
		if age > settings.bot_streak_age:
			continue
		var heading: Vector3 = head.heading
		var at: Vector3 = head.pos + heading * settings.bot_streak_lead * minf(age, 3.0)
		var skip := false
		for v in _visited:
			if (v.pos as Vector3).distance_to(at) < settings.bot_claim_radius:
				skip = true
		for other: Object in _claims:
			if other != self and is_instance_valid(other) and game.seekers().size() > 1 and (_claims[other] as Vector3).distance_to(at) < settings.bot_claim_radius:
				skip = true
		if skip:
			continue
		var score := float(head.strength) * 2.0 - at.distance_to(fish.global_position) * 0.03 - age * 0.15
		if score > best_score:
			best_score = score
			best = {"at": at, "strength": float(head.strength)}
	if not best.is_empty():
		_last_news = _time
	return best


## What its own eyes show: a hider (or a Fake Fish) in sight at a layer it notices.
func _look() -> void:
	var best: FishController
	var best_exposure := 0.0
	var watched: Array[FishController] = game.live_hiders()
	watched.append_array(game.decoys())
	for hider in watched:
		var seen := game.whale_sees(fish, hider)
		if seen < settings.layer_skeleton or not game.whale_in_sight(fish, hider):
			continue
		# A faint skeleton is easy to miss; the pulse from cardio on isn't.
		if seen < settings.layer_cardio and hider != _target and rng.randf() > settings.bot_notice_chance:
			continue
		if seen > best_exposure:
			best_exposure = seen
			best = hider
	if best:
		_target = best
		_last_seen = best.global_position
		_last_seen_velocity = best.linear_velocity
		_last_news = _time


## The blip worth going to: loud and new, near, and not another seeker's.
func _best_ping() -> Dictionary:
	var best := {}
	var best_score := -INF
	var pings := game.recent_pings(fish)
	for i in pings.size():
		var ping: Dictionary = pings[i]
		var at: Vector3 = ping.pos
		var claimed := false
		for other: Object in _claims:
			if other != self and is_instance_valid(other) and (_claims[other] as Vector3).distance_to(at) < settings.bot_claim_radius:
				claimed = true
		if claimed and game.seekers().size() > 1:
			continue
		var newness := float(i + 1) / pings.size()  # newest last
		var score := float(ping.loudness) * 2.0 - at.distance_to(fish.global_position) * 0.03 + newness + (1.0 if ping.get("polo", false) else 0.0)
		if score > best_score:
			best_score = score
			best = ping
	if not best.is_empty():
		_last_news = _time
		if fish.global_position.distance_to(best.pos) < 3.0:
			return {}  # got there: nothing to see, carry on sweeping
	return best


## Nothing to go on: swim between places worth a look, sometimes waiting
## outside a porthole for whoever's inside to give up.
func _sweep(delta: float) -> void:
	if _waiting > 0.0:
		_waiting -= delta
		input.forward = 0.0
		input.stick = (_steer(_goal) * 1.5).limit_length(1.0)
		return
	if plan != Plan.SEEK or fish.global_position.distance_to(_spot) < 4.0 or _stuck_check(delta, 0.6):
		plan = Plan.SEEK
		var system := game.porthole_system as PortholeSystem
		var arena := game.arena as MarcoArena
		if system and not system.portholes().is_empty() and rng.randf() < settings.bot_porthole_wait_chance:
			var p: Porthole = system.portholes().pick_random()
			_spot = p.mouth() + p.axis() * 6.0
			_goal = p.mouth()
			_waiting = 0.0
			plan = Plan.PORTHOLE
		elif arena:
			var half := arena.size * 0.5 - Vector3(6.0, 0.0, 6.0)
			_spot = arena.global_position + Vector3(rng.randf_range(-half.x, half.x), rng.randf_range(2.0, arena.size.y * 0.4), rng.randf_range(-half.z, half.z))
		else:
			_spot = game.center + Vector3(rng.randf_range(-25.0, 25.0), 0.0, rng.randf_range(-25.0, 25.0))
	if plan == Plan.PORTHOLE and fish.global_position.distance_to(_spot) < 4.0:
		_waiting = settings.bot_porthole_wait
		plan = Plan.SEEK
		_spot = fish.global_position
		return
	_swim_at(_spot, delta, false)


# --- Decoy ------------------------------------------------------------------

## FakeFish's pilot: on along its heading, away from walls, loud and sloppy.
func _pilot_decoy(delta: float) -> void:
	if fish.battered or _dodge_tick >= 0:
		if _dodge_tick >= 0:
			_continue_dodge()
		return
	_next_flip -= delta
	if _next_flip <= 0.0:
		_next_flip = rng.randf_range(1.5, 3.0)
		_start_dodge(Vector2(rng.randf_range(-0.4, 0.4), -1.0).normalized())
		return
	var goal := fish.global_position + _heading * 10.0
	goal = _avoid(goal)
	var speed := Vector2(fish.linear_velocity.x, fish.linear_velocity.z).length()
	if speed > settings.fake_speed * 1.15:
		input.forward = 0.0
		input.stick = _steer(goal).limit_length(1.0)
		_stride_seen = -1
	else:
		_stride_toward(goal, 0.25, 0.0)
	if speed < settings.fake_speed * 0.7:
		fish.apply_push(_heading * settings.fake_speed * delta * 1.5)  # keeps the pace its bad strides can't


# --- Swimming -----------------------------------------------------------------

## Toward `goal` without piling up noise: strides only while slower than
## `cap` (quiet_speed by default), coasting above it.
func _swim_quietly(goal: Vector3, delta: float, cap := -1.0) -> void:
	var limit := settings.quiet_speed * 1.1 if cap < 0.0 else cap
	goal = _avoid(goal)
	if fish.linear_velocity.length() > limit:
		input.forward = 0.0
		input.stick = _steer(goal).limit_length(1.0)
		input.roll = clampf(fish.global_basis.x.y * 3.0, -1.0, 1.0)
		_stride_seen = -1
	else:
		_stride_toward(goal, _timing_error(), settings.bot_stride_skill * 0.6)
	_stuck_check(delta, 0.4)


## Toward `goal` as a seeker: full strides, boosting when `hurry`, and the whole
## stick for turns too sharp to stride through.
func _swim_at(goal: Vector3, delta: float, hurry: bool) -> void:
	goal = _avoid(goal)
	var turn := _steer(goal)
	if turn.length() > 1.3:
		input.forward = 0.0
		input.stick = turn.limit_length(1.0)
		input.roll = clampf(fish.global_basis.x.y * 3.0, -1.0, 1.0)
		_stride_seen = -1
	else:
		_stride_toward(goal, _timing_error(), settings.bot_stride_skill * 0.6)
		input.boost = hurry and fish.boost_enabled and fish.global_position.distance_to(goal) < 12.0
	_stuck_check(delta, 0.5)


func _timing_error() -> float:
	return lerpf(0.2, 0.025, settings.bot_stride_skill)


## The stick toward `goal` (yaw, pitch; HunterBot's damped steering).
func _steer(goal: Vector3) -> Vector2:
	var basis := fish.global_basis.orthonormalized()
	var local := basis.inverse() * (goal - fish.global_position)
	var yaw := atan2(local.x, -local.z)
	var pitch := atan2(local.y, Vector2(local.x, local.z).length())
	var turning := Vector2(-fish.angular_velocity.dot(basis.y), fish.angular_velocity.dot(basis.x))
	return Vector2(yaw, pitch) * STEER_GAIN - turning * STEER_DAMPING


func _stick_toward(at: Vector3) -> Vector2:
	var local := fish.global_basis.orthonormalized().inverse() * (at - fish.global_position)
	return Vector2(local.x, local.z).normalized() if Vector2(local.x, local.z).length() > 0.01 else Vector2(0.0, -1.0)


## Strides toward `goal`, each reversal timed off the peak give or take `error`
## (`perfect` the chance it's spot on).
func _stride_toward(goal: Vector3, error: float, perfect: float) -> void:
	var steer := _steer(goal)
	input.roll = clampf(fish.global_basis.x.y * 3.0, -1.0, 1.0)
	input.forward = 1.0
	_time_stride(error, perfect)
	input.stick = _resting_stick(steer.limit_length(1.0))
	if _flick_left > 0:
		input.stick = Vector2.ZERO if _flick_left == FLICK_TICKS else Vector2(_sweep_sign * SWEEP, 0.0)
		_flick_left -= 1


func _resting_stick(wanted: Vector2) -> Vector2:
	var threshold := fish.stride_threshold
	if wanted.length() < threshold * COMMIT_STICK:
		return wanted
	var toward_next := wanted.normalized().x * _sweep_sign < -fish.stride_reversal + 0.1
	if fish.swishy.phase < 0.0 or toward_next:
		return wanted.limit_length(threshold * COMMIT_STICK)
	return wanted


func _time_stride(error: float, perfect: float) -> void:
	var swim := fish.swishy
	if swim.phase < 0.0:
		_stride_seen = -1
		if _flick_left <= 0:
			_flick()
		return
	if swim.strides != _stride_seen:
		_stride_seen = swim.strides
		var off := 0.0 if rng.randf() < perfect else rng.randfn(0.0, error)
		_flip_at = clampf(swim.peak_time() + off, 0.08, swim.peak_time() + MAX_LATE)
	if swim.phase >= _flip_at:
		_flick()
		_flip_at = INF


func _flick() -> void:
	_sweep_sign = -_sweep_sign
	_flick_left = FLICK_TICKS


## `goal`, or somewhere along a wall or furniture in its way (and inside the arena).
func _avoid(goal: Vector3) -> Vector3:
	var arena := game.arena as MarcoArena if game else null
	var mask := arena.sight_blockers_mask() if arena else 1
	var from := fish.global_position
	var ahead := fish.linear_velocity if fish.linear_velocity.length() > 1.0 else _heading
	var reach := LOOK_AHEAD + fish.linear_velocity.length() * LOOK_AHEAD_TIME
	var query := PhysicsRayQueryParameters3D.create(from, from + ahead.normalized() * reach, mask, [fish.get_rid()])
	var hit := fish.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and from.distance_to(goal) > from.distance_to(hit.position):
		var normal: Vector3 = hit.normal
		var along := ahead.normalized().slide(normal)
		if along.length() < 0.2:
			along = normal.cross(Vector3.UP)
		goal = from + (along.normalized() + normal * 0.7).normalized() * 8.0
	if arena:
		var half := arena.size * 0.5 - Vector3(2.5, 0.0, 2.5)
		var local := goal - arena.global_position
		goal = arena.global_position + Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, 1.0, arena.size.y - 3.0), clampf(local.z, -half.z, half.z))
	return goal


## True (and resets) when it's been nearly still for settings.bot_stuck_time while trying to move.
func _stuck_check(delta: float, slow: float) -> bool:
	if fish.linear_velocity.length() < slow:
		_stuck += delta
	else:
		_stuck = 0.0
	if _stuck < settings.bot_stuck_time:
		return false
	_stuck = 0.0
	if plan == Plan.PORTHOLE and not decoy and _role == MarcoPoloMatch.Role.HIDER:
		_porthole = null
	plan = Plan.IDLE if _role == MarcoPoloMatch.Role.HIDER else Plan.SEEK
	if _role == MarcoPoloMatch.Role.SEEKER:
		_spot = fish.global_position - _heading * 10.0
	return true


func _start_dodge(stick: Vector2) -> void:
	_dodge_stick = stick
	_dodge_tick = 0


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
