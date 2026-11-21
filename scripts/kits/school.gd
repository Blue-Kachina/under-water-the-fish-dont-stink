class_name School
extends Node3D
## A school of harmless fish for Nature (NatureRun), swimming together, mostly
## in unison. An invisible leader roams between random spots around `home`, as
## a WanderBot does, at a calm cruise. Each fish has its own place (slot) in a
## loose ellipsoid around the leader, in the leader's frame, so the whole school
## turns together, and steers to it:
## - pulled to its slot (slot_pull), at up to catch_up times the school's speed;
## - pushed apart from fish closer than `separation` (its nearest few, a list
##   refreshed every NEIGHBOUR_REFRESH steps rather than every pair every step);
## - drifting a little around its slot (wander), so it looks alive;
## - following where the leader was a moment ago, longer the further back it
##   swims (ripple_delay), so a turn ripples from the front of the school to
##   the back.
##
## Built for lots of fish: the fish are data (arrays), not nodes. The school
## steps them at settings.sim_rate and draws each frame between the last two
## steps, through one MultiMesh per tail pose (SchoolLook: a flipbook wag).
## Only the few nearest the camera (detail_fish within detail_distance) get a
## full model (SchoolFish), with a smooth tail and rippling skin.
##
## Threats (the players' fish) scare it: one coming at it fast and near makes
## it tighten into a bait ball (bait_tighten) and swerve away (bait_swerve). A
## fish battered (batter()) makes the survivors near it burst away from it
## (burst_strength), and they regroup as their slots pull them back.
##
## Every value is read live from `settings` (NatureSettings). Changing the
## school size adds or takes away fish; a school that has lost fish otherwise
## stays as it is.
##
## `centre` follows the middle of the school's fish (hidden once none are
## left): what the camera's ball cam looks at. With a threat in or right by the
## school, it eases out to a point ahead of that fish instead (CENTRE_LEAD), so
## the camera doesn't whip round to look at the middle of the school as the
## fish swims through it. middle() is always the true middle.

const NAMES := ["the Sardine Steves", "the Gill Gang", "the Fin Crowd", "the Scale Mates",
		"the Herring Aids", "the Cod Squad", "the Krill Seekers", "the Reef Raffs",
		"the Shoal Patrol", "the Bubble Bunch", "the Salty Dogs", "the Fry-day Crew"]
## The leader picks its next spot within this (m) of the last, or the school's length if longer.
const HOME_ARRIVED := 4.0
## How quickly a fish turns to face the way it swims (1/s).
const FACE_RATE := 8.0
## How quickly `centre` catches up with the middle of the school (1/s).
const CENTRE_RATE := 10.0
## With a threat inside the school, `centre` sits this far (m) ahead of it,
## easing back to the middle over CENTRE_EASE (m) once it's out the other side.
const CENTRE_LEAD := 15.0
const CENTRE_EASE := 20.0
## Separation looks at this many of each fish's nearest, refreshed every
## NEIGHBOUR_REFRESH steps (a share of the fish each step).
const NEIGHBOURS := 6
const NEIGHBOUR_REFRESH := 8
## Seconds between choosing which fish get full models.
const DETAIL_INTERVAL := 0.2
## Never more than this many steps in one physics tick (after a hitch).
const MAX_STEPS := 4
## Seconds a pull() lasts without another call.
const PULL_TTL := 0.15

## Full models built this frame, across all schools: building one takes a few ms.
## A fish that had claimed a place here lost it (its fish was eaten or battered).
signal claim_lost(fish: FishController)

static var _built_frame := -1
## The players' cameras (split-screen has several): detail fish go to the
## fish nearest any of them. Empty: the viewport's camera.
static var view_cameras: Array[Camera3D] = []

## Its number in the run (NatureRun), the same on every machine in co-op.
var id := -1
## Everything random about it (its name, its fish's places, drift and tail
## beats, the leader's spots) comes from this, seeded at setup(): two machines
## given the same seed build the same school.
var rng := RandomNumberGenerator.new()
## Online co-op, on a machine that isn't the host: the leader and its alarm
## follow the host's (set_net_state()) instead of roaming and taking fright
## here. Its fish still swim to their places here, from that leader.
var follower := false
var settings: NatureSettings
var character := FishCharacter.FishClass.SKIRMISHER
var display_name := ""
## The middle of where it roams.
var home := Vector3.ZERO
## The middle of its live fish.
var centre := Node3D.new()
## Fish that scare it (the players').
var threats: Array[FishController] = []
## How scared it is, 0..1: it tightens and swerves away as this rises.
var alarm := 0.0

## The leader: where it is, which way it heads (unit), and its spot to swim to.
var leader_position := Vector3.ZERO
var leader_heading := Vector3.FORWARD
var _spot := Vector3.ZERO
## The leader's recent frames, oldest first, one per step, for the ripple.
var _history: Array[Transform3D] = []

## The fish, by index: where they are this step and the last (drawn between),
## how they swim and face, their places and their drift, tail beat and state.
var _position := PackedVector3Array()
var _last_position := PackedVector3Array()
var _velocity := PackedVector3Array()
var _facing: Array[Quaternion] = []
var _last_facing: Array[Quaternion] = []
var _slot := PackedVector3Array()
var _slot_back := PackedFloat32Array()
var _wander := PackedVector3Array()
var _tail := PackedFloat32Array()
var _alive := PackedByteArray()
var _neighbours: Array[PackedInt32Array] = []
## After eat() (What Stinks?): each scattering fish's heading (zero: it isn't),
## and the seconds the school has left to reform (scatter fades out over them).
var _scatter_dir := PackedVector3Array()
var _scatter_left := 0.0
var _scatter_total := 1.0

## Places players have joined (What Stinks?, claim()): fish index -> a claim
## dictionary. The school writes the player's fish's transform from the place;
## the fish only reads (and leans, set_lean()).
var _claims := {}
## Fish a whale's mouth holds (What Stinks?, hold()): fish index -> {holder, local, from, age, ease}.
## An extra state Nature never sets: while a fish is held the school neither moves it nor counts it
## in its middle (so in its alarm), and the holder says where it is. Empty everywhere else.
var _held := {}
## Mouths sucking at the school (What Stinks?, pull()): source id -> {point, dir, cone, speed, reach, mouth, ttl}. Another state
## Nature never sets: while one is live the fish in its cone are drawn toward the point; each entry lapses when its source stops calling.
var _pulls := {}

var _time := 0.0
var _since_step := 0.0
var _steps := 0
## The school size last asked for (NatureSettings.fish_per_school).
var _planned := 0
var _looks: Array[MultiMeshInstance3D] = []
var _buffers: Array[PackedFloat32Array] = []
## Full models, and which fish each shows (fish index -> SchoolFish).
var _details: Array[SchoolFish] = []
var _detailed := {}
var _detail_left := 0.0
var _shadows := false
## A follower's latest from the host: the leader (moved on since, at the
## school's speed), its heading and the alarm.
var _net_position := Vector3.ZERO
var _net_heading := Vector3.FORWARD
var _net_alarm := 0.0
var _has_net := false


func _init() -> void:
	centre.name = "Centre"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # drawn every frame


func _ready() -> void:
	add_child(centre)


## Puts the school at `at` heading along `heading`, with its fish in their places.
## Call once it's in the tree. `rng_seed` makes it the same school wherever it's
## built (negative: a random one).
func setup(school_settings: NatureSettings, at: Vector3, heading: Vector3, kind: FishCharacter.FishClass, rng_seed := -1) -> void:
	settings = school_settings
	character = kind
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	display_name = NAMES[rng.randi_range(0, NAMES.size() - 1)]
	home = at
	leader_position = at
	leader_heading = _level_heading(heading)
	_history.clear()
	_history.append(_leader_frame())
	_build_looks()
	_planned = 0
	_resize(settings.fish_per_school)
	pick_spot()
	centre.global_position = _middle()
	_draw(0.0)


## How many fish it has, battered ones included.
func fish_count() -> int:
	return _position.size()


## How many of its fish are left (not battered).
func alive_count() -> int:
	return _alive.count(1)


func is_alive(index: int) -> bool:
	return _alive[index] == 1


## Where fish `index` is now (m), between steps.
func fish_position(index: int) -> Vector3:
	return _position[index] + _velocity[index] * _since_step


func fish_velocity(index: int) -> Vector3:
	return _velocity[index]


## Which way fish `index` faces (unit, nose).
func fish_heading(index: int) -> Vector3:
	return -(Basis(_facing[index]).z)


## How far back in the school fish `index` swims: 0 the front, 1 the back.
func fish_slot_back(index: int) -> float:
	return _slot_back[index]


## How many fish have full models now.
func detail_count() -> int:
	return _detailed.size()


## A new spot for the leader to head for, around home.
func pick_spot() -> void:
	var flat := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 1.0) * settings.roam_radius
	_spot = home + Vector3(flat.x, rng.randf_range(-1.0, 1.0) * settings.roam_height, flat.y)


## The school's size (along its heading): half its length, at the current spread.
func radius() -> float:
	return settings.spread * maxf(settings.spread_length, 1.0)


func _physics_process(delta: float) -> void:
	if settings == null:
		return
	if settings.fish_per_school != _planned:
		_resize(settings.fish_per_school)
	var step := 1.0 / maxf(settings.sim_rate, 1.0)
	_since_step += delta
	var steps := 0
	while _since_step >= step and steps < MAX_STEPS:
		_since_step -= step
		_step(step)
		steps += 1
	_since_step = minf(_since_step, step)
	if not _claims.is_empty():
		_write_claimed(step)


func _process(delta: float) -> void:
	if settings == null:
		return
	_draw(delta)


## One step of the school: the leader, then every fish.
func _step(delta: float) -> void:
	_time += delta
	_steps += 1
	_last_position = _position.duplicate()
	_last_facing = _facing.duplicate()
	_scatter_left = maxf(_scatter_left - delta, 0.0)
	_strip_claims()
	_update_alarm(delta)
	_move_leader(delta)
	_refresh_neighbours()
	_move_fish(delta)
	if not _pulls.is_empty():
		_age_pulls(delta)
	_apply_claims(delta)
	if not _held.is_empty():
		_apply_holds(delta)


## Which of its fish are left (1) or battered (0), by index.
func alive_mask() -> PackedByteArray:
	return _alive.duplicate()


## Its fish as `mask` has them (a guest joining late): those battered there go,
## quietly (no burst).
func apply_alive_mask(mask: PackedByteArray) -> void:
	for i in mini(mask.size(), _alive.size()):
		if mask[i] == 0 and _alive[i] == 1:
			_alive[i] = 0
			_drop_claim(i)
			if _detailed.has(i):
				_detailed[i].index = -1
				_detailed[i].visible = false
				_detailed.erase(i)


## The leader and alarm as the host has them, for its followers (set_net_state()).
func net_state() -> Array:
	return [leader_position, leader_heading, alarm]


## A follower's leader and alarm, from the host's net_state(), `age` seconds old.
func set_net_state(host_position: Vector3, heading: Vector3, host_alarm: float, age := 0.0) -> void:
	_net_heading = heading.normalized() if heading.length_squared() > 0.000001 else leader_heading
	_net_position = host_position + _net_heading * settings.school_speed * maxf(age, 0.0)
	_net_alarm = host_alarm
	if not _has_net:
		leader_position = _net_position
		leader_heading = _net_heading
	_has_net = true


## A follower's leader: on the host's heading, eased onto where the host's is
## by now (snapping back if it's strayed far).
func _follow_leader(delta: float) -> void:
	if _has_net:
		_net_position += _net_heading * settings.school_speed * delta
		leader_heading = leader_heading.slerp(_net_heading, 1.0 - exp(-10.0 * delta)).normalized()
	leader_position += leader_heading * settings.school_speed * delta
	if _has_net:
		if leader_position.distance_to(_net_position) > maxf(radius() * 2.0, 8.0):
			leader_position = _net_position
		else:
			leader_position = leader_position.lerp(_net_position, 1.0 - exp(-8.0 * delta))
	_history.append(_leader_frame())
	var keep := ceili(settings.ripple_delay / delta) + 2
	if _history.size() > keep:
		_history = _history.slice(_history.size() - keep)


func _move_leader(delta: float) -> void:
	if follower:
		_follow_leader(delta)
		return
	if leader_position.distance_to(_spot) < maxf(HOME_ARRIVED, radius()):
		pick_spot()
	var to_spot := _spot - leader_position
	if to_spot.length_squared() > 0.01:
		var wanted := _level_heading(to_spot.normalized())
		var angle := leader_heading.angle_to(wanted)
		var turn := deg_to_rad(settings.school_turn_rate) * delta
		if angle > 0.0001:
			leader_heading = leader_heading.slerp(wanted, minf(turn / angle, 1.0)).normalized()
	var away := _away_from_threats()
	if alarm > 0.01 and away != Vector3.ZERO:
		var flee := _level_heading(away)
		var angle := leader_heading.angle_to(flee)
		var turn := deg_to_rad(settings.bait_swerve) * alarm * delta
		if angle > 0.0001:
			leader_heading = leader_heading.slerp(flee, minf(turn / angle, 1.0)).normalized()
	leader_position += leader_heading * settings.school_speed * delta
	_history.append(_leader_frame())
	var keep := ceili(settings.ripple_delay / delta) + 2
	if _history.size() > keep:
		_history = _history.slice(_history.size() - keep)


## A share of the fish (every NEIGHBOUR_REFRESH-th) find their nearest few again.
func _refresh_neighbours() -> void:
	var count := _position.size()
	var reach := settings.separation * 2.0
	var reach_squared := reach * reach
	for i in range(_steps % NEIGHBOUR_REFRESH, count, NEIGHBOUR_REFRESH):
		var near := PackedInt32Array()
		var gaps := PackedFloat32Array()
		if reach > 0.0 and _alive[i] == 1:
			var at := _position[i]
			for j in count:
				if j == i or _alive[j] == 0:
					continue
				var gap := at.distance_squared_to(_position[j])
				if gap >= reach_squared:
					continue
				if near.size() < NEIGHBOURS:
					near.append(j)
					gaps.append(gap)
				else:
					var worst := 0
					for k in range(1, NEIGHBOURS):
						if gaps[k] > gaps[worst]:
							worst = k
					if gap < gaps[worst]:
						near[worst] = j
						gaps[worst] = gap
		_neighbours[i] = near


## Scared (alarm rises) while a threat comes at the school fast and near.
func _update_alarm(delta: float) -> void:
	if follower:
		alarm = move_toward(alarm, _net_alarm, settings.bait_rate * delta)
		return
	var scared := false
	var middle := _middle()
	for threat in threats:
		if not is_instance_valid(threat) or threat.battered:
			continue
		var offset := middle - threat.global_position
		var gap := offset.length()
		if gap < settings.bait_range + radius() and gap > 0.001:
			scared = scared or threat.swim_velocity().dot(offset / gap) >= settings.bait_speed
	alarm = move_toward(alarm, 1.0 if scared else 0.0, settings.bait_rate * delta)


## Away from the nearest threat, or zero with none about.
func _away_from_threats() -> Vector3:
	var middle := _middle()
	var nearest := INF
	var away := Vector3.ZERO
	for threat in threats:
		if not is_instance_valid(threat) or threat.battered:
			continue
		var offset := middle - threat.global_position
		if offset.length() < nearest and offset.length() > 0.001:
			nearest = offset.length()
			away = offset.normalized()
	return away


## How tightly it's packed now: 1 as usual, down to bait_tighten when scared.
func tightness() -> float:
	return lerpf(1.0, settings.bait_tighten, alarm)


## Batters fish `index`: it's gone, and the survivors near it burst away.
## Returns where it was.
func batter(index: int) -> Vector3:
	var at := fish_position(index)
	_alive[index] = 0
	_drop_claim(index)
	if _detailed.has(index):
		var freed: SchoolFish = _detailed[index]
		freed.index = -1
		freed.visible = false
		_detailed.erase(index)
	var reach := settings.burst_radius
	if reach > 0.0 and settings.burst_strength > 0.0:
		for i in _position.size():
			if _alive[i] == 0:
				continue
			var offset := _position[i] - at
			var gap := offset.length()
			if gap < reach:
				var out := offset / gap if gap > 0.001 else Vector3.UP
				_velocity[i] += out * settings.burst_strength * (1.0 - gap / reach)
	return at


## Eats the fish in `indices` (What Stinks?'s Hunter; the live ones only): like
## batter(), they're gone, but the survivors panic harder: the school goes to full
## alarm, survivors within burst_radius x `radius_mult` of a fish eaten burst away
## `strength_mult` x harder, and each of those then scatters along one of `groups`
## headings for `reform_time` s (fading out), before its slot pulls it back: the
## school splits in a few groups and reforms. Returns where each eaten fish was
## (the same order as the live ones in `indices`).
func eat(indices: Array, strength_mult := 2.0, radius_mult := 2.0, groups := 3, reform_time := 6.0) -> PackedVector3Array:
	var spots := PackedVector3Array()
	var eaten: Array[int] = []
	for entry: Variant in indices:
		var index := int(entry)
		if index < 0 or index >= _alive.size() or _alive[index] == 0:
			continue
		spots.append(fish_position(index))
		eaten.append(index)
		_alive[index] = 0
		_drop_claim(index)
		if _detailed.has(index):
			var freed: SchoolFish = _detailed[index]
			freed.index = -1
			freed.visible = false
			_detailed.erase(index)
	if eaten.is_empty():
		return spots
	alarm = 1.0
	_net_alarm = 1.0
	var reach := settings.burst_radius * radius_mult
	var headings: Array[Vector3] = []
	for g in maxi(groups, 1):
		headings.append(Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU + g * TAU / maxi(groups, 1)))
	for i in _position.size():
		if _alive[i] == 0:
			continue
		var nearest := INF
		var from := Vector3.ZERO
		for spot in spots:
			var gap := _position[i].distance_to(spot)
			if gap < nearest:
				nearest = gap
				from = spot
		if nearest >= reach:
			continue
		var offset := _position[i] - from
		var out := offset / nearest if nearest > 0.001 else Vector3.UP
		_velocity[i] += out * settings.burst_strength * strength_mult * (1.0 - nearest / reach)
		var heading: Vector3 = headings[rng.randi() % headings.size()]
		_scatter_dir[i] = Vector3(heading.x, heading.y + out.y * 0.3, heading.z).normalized()
	_scatter_total = maxf(reform_time, 0.1)
	_scatter_left = _scatter_total
	return spots


# --- Held in a mouth (What Stinks?, two-stage-attack.md 4b) -------------------

## Holds live, unclaimed fish `index` in `holder`'s mouth: the school stops moving it (and leaves it
## out of its middle, so out of its alarm), and it rides at `local` (holder space), drawn in from where
## it was over `ease_time` s. Eaten when the mouth closes (eat()), or let go (release_hold()).
## False if it can't be held (dead, claimed, already held, no holder).
func hold(index: int, holder: Node3D, local: Vector3, ease_time := 0.35) -> bool:
	if index < 0 or index >= _alive.size() or _alive[index] == 0 or _claims.has(index) or _held.has(index) or not is_instance_valid(holder):
		return false
	_held[index] = {"holder": holder, "local": local, "from": fish_position(index), "age": 0.0, "ease": maxf(ease_time, 0.0)}
	_velocity[index] = Vector3.ZERO
	return true


## Lets go of a held fish: an ordinary school fish again, where it is (its slot pulls it back).
func release_hold(index: int) -> void:
	_held.erase(index)


## Knocks a free fish: adds `impulse` (m/s) to its velocity (a full mouth's lips bumping it away).
func nudge(index: int, impulse: Vector3) -> void:
	if index >= 0 and index < _alive.size() and _alive[index] == 1 and not _held.has(index):
		_velocity[index] += impulse


## A mouth sucks at the school (a Gulper's held bite; call it every tick while it lasts, it lapses a moment after the last call):
## the fish within `reach` of `point` and within `cone_deg` of `dir` (the way the mouth faces) are drawn toward it, aiming at
## `speed` m/s (the school's own acceleration limit still applies) and easing in once they are within `mouth` of the point.
## The pull is strongest at the lips and fades out to nothing at `reach`. `source` tells two mouths apart.
func pull(source: Object, point: Vector3, dir: Vector3, cone_deg: float, speed: float, reach: float, mouth := 0.0) -> void:
	if source == null or reach <= 0.0 or speed <= 0.0:
		return
	_pulls[source.get_instance_id()] = {"point": point, "dir": dir.normalized(), "cone": cos(deg_to_rad(clampf(cone_deg, 0.0, 180.0))),
			"speed": speed, "reach": reach, "mouth": maxf(mouth, 0.0), "ttl": PULL_TTL}


## Stops `source`'s pull at once.
func end_pull(source: Object) -> void:
	if source != null:
		_pulls.erase(source.get_instance_id())


func is_pulled() -> bool:
	return not _pulls.is_empty()


func _age_pulls(delta: float) -> void:
	for key: Variant in _pulls.keys():
		var entry: Dictionary = _pulls[key]
		entry["ttl"] = float(entry["ttl"]) - delta
		if float(entry["ttl"]) <= 0.0:
			_pulls.erase(key)


## Where a fish at `at` wants to go once the mouths sucking at the school have had their say (`wanted` if none reaches it).
func _pulled(at: Vector3, wanted: Vector3) -> Vector3:
	var best := 0.0
	var aim := Vector3.ZERO
	for entry: Dictionary in _pulls.values():
		var point: Vector3 = entry["point"]
		var off := point - at
		var gap := off.length()
		var reach: float = entry["reach"]
		if gap >= reach or gap < 0.0001:
			continue
		if (-off / gap).dot(entry["dir"]) < float(entry["cone"]):
			continue  # behind or beside the lips: not in the cone
		var share := 1.0 - gap / reach
		if share <= best:
			continue
		best = share
		var mouth: float = entry["mouth"]
		var speed: float = entry["speed"]
		aim = off / gap * (speed if gap > mouth else minf(speed, gap * 4.0))  # settle at the lips instead of overshooting
	return wanted if best <= 0.0 else wanted.lerp(aim, minf(best * 2.0, 1.0))


func is_held(index: int) -> bool:
	return _held.has(index)


func held_count() -> int:
	return _held.size()


## The held fish, by index.
func held_indices() -> Array:
	return _held.keys()


## Where held fish `index` rides in its holder's space (INF with none).
func held_local(index: int) -> Vector3:
	return _held[index]["local"] if _held.has(index) else Vector3.INF


## Places each held fish: eased from where it was to its spot in the holder's mouth, facing the way the holder does.
func _apply_holds(delta: float) -> void:
	for index: int in _held.keys():
		if index >= _alive.size() or _alive[index] == 0:
			_held.erase(index)
			continue
		var held: Dictionary = _held[index]
		if not is_instance_valid(held["holder"]):
			_held.erase(index)  # (a freed holder can't be cast: check it as a Variant first)
			continue
		var holder := held["holder"] as Node3D
		if not holder.is_inside_tree():
			_held.erase(index)
			continue
		held["age"] = float(held["age"]) + delta
		var ease_time: float = held["ease"]
		var share := 1.0 if ease_time <= 0.0 else smoothstep(0.0, 1.0, clampf(float(held["age"]) / ease_time, 0.0, 1.0))
		_position[index] = (held["from"] as Vector3).lerp(holder.to_global(held["local"]), share)
		_velocity[index] = Vector3.ZERO
		_facing[index] = holder.global_basis.orthonormalized().get_rotation_quaternion()


# --- Joined players (What Stinks?, what_stinks.md section 5) ------------------

## Gives fish `index` (alive, unclaimed) to the player's `fish`: it stays a real
## school fish, drawn and moved by the school, and the player's fish takes its
## transform each frame (a claimed fish's motion is the controller's to read,
## never to write). The player eases in from `from` over `ease_time` s. False if
## the place isn't free. The host picks the index (claim_nearest()); a guest is
## told it.
func claim(index: int, fish: FishController, ease_time := 0.6, from := Vector3.INF) -> bool:
	if index < 0 or index >= _alive.size() or _alive[index] == 0 or _claims.has(index) or claim_of(fish) >= 0:
		return false
	var start: Vector3 = from if from.is_finite() else fish.global_position
	var rel := start - fish_position(index)
	_claims[index] = {"fish": fish, "rel": rel, "age": 0.0, "ease": maxf(ease_time, 0.0),
			"lean": Vector2.ZERO, "lean_now": Vector2.ZERO, "range": 0.0, "ofs": rel}
	# Starts where the player is, so the first frame doesn't jump (the next step strips and re-applies it).
	_position[index] += rel
	_last_position[index] += rel
	return true


## The live, unclaimed fish nearest `near` (-1 with none).
func nearest_free(near: Vector3) -> int:
	var best := -1
	var best_gap := INF
	for i in _position.size():
		if _alive[i] == 0 or _claims.has(i):
			continue
		var gap := fish_position(i).distance_squared_to(near)
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


## Claims the free fish nearest `near` (the player's position) for `fish`; its
## index, or -1.
func claim_nearest(fish: FishController, near: Vector3, ease_time := 0.6) -> int:
	var index := nearest_free(near)
	if index >= 0 and claim(index, fish, ease_time, near):
		return index
	return -1


## The index `fish` has claimed here, or -1.
func claim_of(fish: FishController) -> int:
	for index: int in _claims:
		if _claims[index]["fish"] == fish:
			return index
	return -1


func is_claimed(index: int) -> bool:
	return _claims.has(index)


## The player's fish at place `index`, or null.
func claimed_by(index: int) -> FishController:
	return _claims[index]["fish"] if _claims.has(index) else null


func claimed_count() -> int:
	return _claims.size()


## The claimed places, by index.
func claimed_indices() -> Array:
	return _claims.keys()


## How far `fish` has eased in: 0 where it joined, 1 in its place.
func claim_progress(fish: FishController) -> float:
	var index := claim_of(fish)
	if index < 0:
		return 0.0
	return _ease_share(_claims[index])


## Leans `fish`'s place: `stick` (x right, y up, -1..1) of `range_m` metres,
## in the place's own frame. The player's input, nothing else.
func set_lean(fish: FishController, stick: Vector2, range_m: float) -> void:
	var index := claim_of(fish)
	if index >= 0:
		_claims[index]["lean"] = stick.limit_length(1.0)
		_claims[index]["range"] = maxf(range_m, 0.0)


## Lets go of `fish`'s place (the school fish stays, an ordinary one again).
## Returns where and how the player's fish was: {"position", "velocity", "basis"}
## (empty if it hadn't one).
func release_claim(fish: FishController) -> Dictionary:
	var index := claim_of(fish)
	if index < 0:
		return {}
	var out := {"position": fish_position(index), "velocity": _velocity[index], "basis": Basis(_facing[index])}
	_claims.erase(index)
	return out


## A fish that's gone (eaten, battered) is no longer held by a mouth, and a player's place on it is forgotten, and the fish told.
func _drop_claim(index: int) -> void:
	_held.erase(index)
	if not _claims.has(index):
		return
	var fish: FishController = _claims[index]["fish"]
	_claims.erase(index)
	claim_lost.emit(fish)


func _ease_share(claim: Dictionary) -> float:
	var ease_time: float = claim["ease"]
	return 1.0 if ease_time <= 0.0 else smoothstep(0.0, 1.0, clampf(float(claim["age"]) / ease_time, 0.0, 1.0))


## Takes last step's offsets off the claimed fish, so the school's own sim
## (neighbours, slots) never sees them.
func _strip_claims() -> void:
	for index: int in _claims:
		_position[index] -= _claims[index]["ofs"]
		_claims[index]["ofs"] = Vector3.ZERO


## Puts each claimed fish where its player is: the school's own place, plus
## what's left of the way in from where it joined, plus its lean.
func _apply_claims(delta: float) -> void:
	for index: int in _claims.keys():
		if index >= _alive.size() or _alive[index] == 0:
			_drop_claim(index)
			continue
		var claim: Dictionary = _claims[index]
		claim["age"] = float(claim["age"]) + delta
		var rate := 1.0 - exp(-8.0 * delta)
		claim["lean_now"] = (claim["lean_now"] as Vector2).lerp(claim["lean"], rate)
		var lean: Vector2 = claim["lean_now"]
		var basis := Basis(_facing[index])
		var offset: Vector3 = (claim["rel"] as Vector3) * (1.0 - _ease_share(claim)) + (basis.x * lean.x + basis.y * lean.y) * float(claim["range"])
		claim["ofs"] = offset
		_position[index] += offset


## Writes each player's fish onto its place, drawn between the last step and this one.
func _write_claimed(step: float) -> void:
	var blend := clampf(_since_step / step, 0.0, 1.0)
	for index: int in _claims:
		var fish := _claims[index]["fish"] as FishController
		if not is_instance_valid(fish):
			continue
		var facing := _last_facing[index].slerp(_facing[index], blend)
		fish.global_transform = Transform3D(Basis(facing), _last_position[index].lerp(_position[index], blend))
		fish.linear_velocity = _velocity[index]


## Startles the whole school (a player's Spook): every fish bolts off along one
## of `groups` headings, `strength_mult` x the usual burst, for `reform_time` s
## (fading out), then its place pulls it back: the school splits and re-forms.
func startle(strength_mult := 2.5, groups := 3, reform_time := 4.0) -> void:
	alarm = 1.0
	_net_alarm = 1.0
	var headings: Array[Vector3] = []
	for g in maxi(groups, 1):
		headings.append(Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU + g * TAU / maxi(groups, 1)))
	var middle := _middle()
	for i in _position.size():
		if _alive[i] == 0:
			continue
		var heading: Vector3 = headings[rng.randi() % headings.size()]
		var out := _position[i] - middle
		out = out.normalized() if out.length_squared() > 0.0001 else Vector3.UP
		var dir := Vector3(heading.x, heading.y + out.y * 0.3, heading.z).normalized()
		_velocity[i] += dir * settings.burst_strength * strength_mult
		_scatter_dir[i] = dir
	_scatter_total = maxf(reform_time, 0.1)
	_scatter_left = _scatter_total


func _move_fish(delta: float) -> void:
	var scatter := smoothstep(0.0, 1.0, _scatter_left / _scatter_total) if _scatter_left > 0.0 else 0.0
	var extent := Vector3(settings.spread, settings.spread, settings.spread * settings.spread_length) * tightness()
	var top_speed := settings.school_speed * settings.catch_up + 1.0
	var reach := settings.separation
	var spin := settings.wander_rate * TAU * _time
	var steps_back := settings.ripple_delay / delta
	var last := _history.size() - 1
	var holding := not _held.is_empty()
	var pulling := not _pulls.is_empty()
	for i in _position.size():
		if _alive[i] == 0 or (holding and _held.has(i)):
			continue
		var at := _position[i]
		# Where the leader was this fish's ripple delay ago, and its place around that.
		var back := clampi(roundi(steps_back * _slot_back[i]), 0, last)
		var frame: Transform3D = _history[last - back]
		var phase := _wander[i]
		var drift := Vector3(sin(spin + phase.x), 0.6 * sin(spin * 0.8 + phase.y), sin(spin * 0.9 + phase.z)) * settings.wander
		var place := frame * (_slot[i] * extent + drift)
		var wanted := -frame.basis.z * settings.school_speed + (place - at) * settings.slot_pull
		if scatter > 0.0 and _scatter_dir[i] != Vector3.ZERO:
			wanted = wanted.lerp(_scatter_dir[i] * top_speed, scatter)
		if wanted.length() > top_speed:
			wanted = wanted.normalized() * top_speed
		var push := Vector3.ZERO
		if reach > 0.0:
			for j in _neighbours[i]:
				if j >= _position.size() or _alive[j] == 0:
					continue
				var apart := at - _position[j]
				var gap := apart.length()
				if gap < reach and gap > 0.0001:
					push += apart / gap * settings.separation_strength * (1.0 - gap / reach)
		if pulling:
			wanted = _pulled(at, wanted)
		var before := _velocity[i]
		var velocity := before.move_toward(wanted, settings.fish_accel * delta) + push * delta
		_velocity[i] = velocity
		_position[i] = at + velocity * delta
		_facing[i] = _face(_facing[i], velocity, (velocity - before) / delta, delta)


## A fish's facing turned toward the way it swims, rolling into its turns.
func _face(facing: Quaternion, velocity: Vector3, acceleration: Vector3, delta: float) -> Quaternion:
	if velocity.length_squared() < 0.04:
		return facing
	var forward := velocity.normalized()
	var up := Vector3.UP if absf(forward.y) < 0.98 else Vector3.BACK
	var level := Basis.looking_at(forward, up)
	var sideways := acceleration.dot(level.x)  # + = turning right
	var roll := clampf(-sideways * 0.08 * settings.bank, -1.2, 1.2)
	var target := level.rotated(forward, roll).get_rotation_quaternion()
	return facing.slerp(target, 1.0 - exp(-FACE_RATE * delta))


## Draws every live fish where it is now, between the last two steps: full
## models for the nearest, the rest through the pose MultiMeshes.
func _draw(delta: float) -> void:
	var step := 1.0 / maxf(settings.sim_rate, 1.0)
	var blend := clampf(_since_step / step, 0.0, 1.0)
	var size := settings.fish_scale
	if settings.fish_shadows != _shadows:
		_set_shadows(settings.fish_shadows)
	_detail_left -= delta
	if _detail_left <= 0.0:
		_detail_left = DETAIL_INTERVAL
		_choose_details(blend)
	var used := [0, 0, 0]
	var sum := Vector3.ZERO
	var alive := 0
	var low := Vector3.INF
	var high := -Vector3.INF
	for i in _position.size():
		if _alive[i] == 0:
			continue
		var at := _last_position[i].lerp(_position[i], blend)
		var facing := _last_facing[i].slerp(_facing[i], blend)
		var speed := _velocity[i].length()
		var effort := clampf(speed / (12.0 * size + 1.0), 0.0, 1.0)
		_tail[i] = fmod(_tail[i] + delta * lerpf(4.0, 14.0, effort), TAU)
		sum += at
		alive += 1
		low = low.min(at)
		high = high.max(at)
		var detail: SchoolFish = _detailed.get(i)
		if detail:
			detail.place(Transform3D(Basis(facing), at), size, _velocity[i], _tail[i], delta)
			continue
		var pose := SchoolLook.pose_for(_tail[i])
		var buffer := _buffers[pose]
		var basis := Basis(facing).scaled(Vector3.ONE * size)
		var k: int = used[pose] * 12
		buffer[k] = basis.x.x
		buffer[k + 1] = basis.y.x
		buffer[k + 2] = basis.z.x
		buffer[k + 3] = at.x
		buffer[k + 4] = basis.x.y
		buffer[k + 5] = basis.y.y
		buffer[k + 6] = basis.z.y
		buffer[k + 7] = at.y
		buffer[k + 8] = basis.x.z
		buffer[k + 9] = basis.y.z
		buffer[k + 10] = basis.z.z
		buffer[k + 11] = at.z
		used[pose] += 1
	var bounds := AABB(low, high - low).grow(2.0 * maxf(size, 0.1)) if alive > 0 else AABB()
	for pose in _looks.size():
		var multimesh := _looks[pose].multimesh
		multimesh.buffer = _buffers[pose]
		multimesh.visible_instance_count = used[pose]
		_looks[pose].custom_aabb = bounds
	centre.visible = alive > 0
	if alive > 0:
		var aim := _aim_point(sum / alive)
		centre.global_position = centre.global_position.lerp(aim, 1.0 - exp(-CENTRE_RATE * delta)) if delta > 0.0 else aim


## Full models for the live fish nearest the camera (up to detail_fish, within
## detail_distance), built at most one a frame across all schools.
func _choose_details(blend: float) -> void:
	var eyes := PackedVector3Array()
	for camera in view_cameras:
		if is_instance_valid(camera) and camera.is_inside_tree():
			eyes.append(camera.global_position)
	if eyes.is_empty() and is_inside_tree() and get_viewport().get_camera_3d():
		eyes.append(get_viewport().get_camera_3d().global_position)
	var wanted := {}
	if not eyes.is_empty() and settings.detail_fish > 0 and settings.detail_distance > 0.0:
		var reach := settings.detail_distance * settings.detail_distance
		var near: Array = []
		for i in _position.size():
			if _alive[i] == 0:
				continue
			var at := _last_position[i].lerp(_position[i], blend)
			var gap := INF
			for eye in eyes:
				gap = minf(gap, eye.distance_squared_to(at))
			if gap < reach:
				near.append([gap, i])
		near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for entry in near.slice(0, settings.detail_fish):
			wanted[entry[1]] = true
	# Let go of fish no longer wanted, then hand free models to new ones.
	for i: int in _detailed.keys():
		if not wanted.has(i):
			var freed: SchoolFish = _detailed[i]
			freed.index = -1
			freed.visible = false
			_detailed.erase(i)
	for i: int in wanted:
		if _detailed.has(i):
			continue
		var model := _free_detail()
		if model == null:
			break
		model.index = i
		model.visible = true
		_detailed[i] = model


func _free_detail() -> SchoolFish:
	for model in _details:
		if model.index < 0:
			return model
	if _details.size() >= settings.detail_fish or _built_frame == Engine.get_process_frames():
		return null
	_built_frame = Engine.get_process_frames()
	var model := SchoolFish.new(character)
	model.name = "Detail%d" % _details.size()
	model.set_shadows(_shadows)
	add_child(model)
	_details.append(model)
	return model


## One MultiMesh per tail pose, drawing this kind of fish's baked look.
func _build_looks() -> void:
	for look in _looks:
		look.queue_free()
	_looks.clear()
	_buffers.clear()
	var meshes := SchoolLook.meshes(character)
	for pose in meshes.size():
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = meshes[pose]
		var look := MultiMeshInstance3D.new()
		look.name = "Look%d" % pose
		look.multimesh = multimesh
		look.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(look)
		_looks.append(look)
		_buffers.append(PackedFloat32Array())


func _set_shadows(on: bool) -> void:
	_shadows = on
	for look in _looks:
		look.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for model in _details:
		model.set_shadows(on)


## Where ball cam should look for a school whose middle is `middle`: there,
## unless a threat is in or right by it, when it eases to a point ahead of it.
func _aim_point(middle: Vector3) -> Vector3:
	var size := radius()
	for threat in threats:
		if not is_instance_valid(threat) or threat.battered:
			continue
		var offset := middle - threat.global_position
		var gap := offset.length()
		var forward := -threat.global_basis.z
		# In or right by the school; or just past it, with it behind, easing back
		# over CENTRE_EASE m so the view swings round gently rather than at once.
		var near := 1.0 - smoothstep(size, size * 2.5, gap)
		if offset.dot(forward) < 0.0:
			near = maxf(near, 1.0 - smoothstep(size * 2.5, size * 2.5 + CENTRE_EASE, gap))
		if near > 0.0 and gap > 0.001:
			# Turn the direction, not slide the point: a point slid from ahead of
			# the fish to behind it would pass through it, flipping the view.
			var direction := forward.slerp(offset / gap, 1.0 - near).normalized()
			return threat.global_position + direction * lerpf(CENTRE_LEAD, gap, 1.0 - near)
	return middle


## The middle of its live fish now (the leader's position when none are left).
func middle() -> Vector3:
	return _middle()


## The middle of its live fish (the leader's position when none are left).
func _middle() -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for i in _position.size():
		if _alive[i] == 1 and (_held.is_empty() or not _held.has(i)):
			sum += _position[i]
			count += 1
	return sum / count if count > 0 else leader_position


## Adds fish (in new places, already swimming with the school) or takes the
## last ones away, to make `count` of them as asked.
func _resize(count: int) -> void:
	_planned = count
	var frame: Transform3D = _history[-1] if not _history.is_empty() else _leader_frame()
	var extent := Vector3(settings.spread, settings.spread, settings.spread * settings.spread_length)
	while _position.size() > count:
		var gone := _position.size() - 1
		if _detailed.has(gone):
			_detailed[gone].index = -1
			_detailed[gone].visible = false
			_detailed.erase(gone)
		for list: Variant in [_position, _last_position, _velocity, _slot, _slot_back, _wander, _tail, _alive, _scatter_dir]:
			list.resize(gone)
		_facing.resize(gone)
		_last_facing.resize(gone)
		_neighbours.resize(gone)
	while _position.size() < count:
		var slot := _free_slot()
		var at := frame * (slot * extent)
		_slot.append(slot)
		_slot_back.append(clampf((slot.z + 1.0) / 2.0, 0.0, 1.0))
		_position.append(at)
		_last_position.append(at)
		_velocity.append(-frame.basis.z * settings.school_speed)
		_facing.append(frame.basis.get_rotation_quaternion())
		_last_facing.append(frame.basis.get_rotation_quaternion())
		_wander.append(Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU)
		_tail.append(rng.randf() * TAU)
		_alive.append(1)
		_scatter_dir.append(Vector3.ZERO)
		_neighbours.append(PackedInt32Array())
	for i in _buffers.size():
		_buffers[i].resize(count * 12)
		_looks[i].multimesh.instance_count = count


## A place in the unit ball, away from the other fish's places where it can be.
func _free_slot() -> Vector3:
	var best := Vector3.ZERO
	var best_gap := -1.0
	for attempt in 24:
		var point := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if point.length_squared() > 1.0:
			continue
		var gap := INF
		for other in _slot:
			gap = minf(gap, point.distance_to(other))
		if gap > best_gap:
			best = point
			best_gap = gap
	return best


func _leader_frame() -> Transform3D:
	return Transform3D(Basis.looking_at(leader_heading, Vector3.UP), leader_position)


## `heading` with its climb or dive kept within max_climb.
func _level_heading(heading: Vector3) -> Vector3:
	var flat := Vector2(heading.x, heading.z)
	if flat.length_squared() < 0.000001:
		flat = Vector2(0.0, -1.0)
	var climb := clampf(atan2(heading.y, flat.length()), -deg_to_rad(settings.max_climb), deg_to_rad(settings.max_climb))
	flat = flat.normalized() * cos(climb)
	return Vector3(flat.x, sin(climb), flat.y)
