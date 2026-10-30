class_name FallenAngelBoss
extends BloodLeviathan
## The Fallen Angel, an alternate final boss (big_changes.md §3, D5, D12): a
## giant zombie sea angel (Clione), drawn from the clip of one hunting a sea
## butterfly. Unlike the serpents it hangs upright, head up, its glass-clear
## body showing the orange head and gut glowing through, two small torn wings
## at its shoulders beating it up and down, a long tail with an orange tip.
##
## How it fights (the host's; a guest's puppet follows its state):
## - HOVER: it keeps angel_lash_reach x 1.6 m off its prey, leaning toward
##   where it's going, rising on each wingbeat (angel_beat s) and sinking
##   between, for angel_rest s;
## - LOCK: as the clip's angel shadows its butterfly, it picks a player and
##   holds itself angel_lock_gap x angel_lash_reach m off them, matching their
##   every move and circling them (angel_orbit), a pale halo round them closing
##   as it locks on; after angel_lock_time s locked on, its crown opens;
## - CROWN: it turns to face its prey and its head bursts open into six
##   tentacles over angel_crown s (angel_fury_crown in fury), pale and then
##   flushing orange, its lane showing (the wind-up players read);
## - FLURRY: angel_flurry s of tumbling in after its prey, its body curling into
##   a hook, lashing angel_lashes times (angel_fury_lashes in fury). A lash
##   catches a player within angel_lash_reach m of its head and angel_lash_cone
##   degrees of the lash, unless they strode within angel_dodge s before it
##   (D12: a timed stride dodges), and every zombie it catches is eaten (it
##   heals angel_eat_heal of its max hp each);
## - HELD: a caught player is held at its mouth in the wrapped crown (the
##   Gulper's rules: drained, three strides break free), its body curled round,
##   turning them this way and that as the clip's angel turns its butterfly's shell.
## Hits on its head and gut (proxies 0 and 1) do angel_weak times the damage,
## angel_crown_weak times more while the crown's open. From two thirds (SPIT)
## it sheds angel_butterflies Sea Butterflies every leviathan_bolt_every x 2 s,
## and when it's hurt it turns its flurries on any that are near to feed. In
## FURY it beats faster, its crown opens quicker, it lashes more and its
## lashes take turns between the two nearest players.

enum State { HOVER, CROWN, FLURRY, HELD, LOCK }

const BODY_SHADER := preload("res://shaders/boss_angel.gdshader")
const ORGAN_SHADER := preload("res://shaders/boss_angel_organ.gdshader")
const TENTACLE_SHADER := preload("res://shaders/angel_tentacle.gdshader")
const TENTACLES := 6

var state := State.HOVER
## This fight's lashes, the players and zombies they caught, and the players
## who dodged one with a stride (probes, the run log).
var lashes := 0
var caught := 0
var dodged := 0
var eaten := 0
var butterflies_shed := 0

## How far open the crown is (0 folded inside the head to 1 a starburst), how
## orange its tentacles are, and how far the body curls (rad, nose to tail).
var crown_open := 0.0
var flush := 0.0
var curl := 0.15
## The way it faces (front, its rest +y) and how far its body leans from
## upright toward where it's going (rad).
var facing := Vector3.FORWARD
var lean := 0.0
## Its tumble while it flurries (rad round its side axis).
var tumble := 0.0

var _state_left := 2.0
var _beat_clock := 0.0
var _lash_times: Array[float] = []
var _lash_dir := Vector3.FORWARD
var _lash_tentacle := 0
var _lash_glow := 0.0
var _flurry_prey: FlurryTarget
var _shed_left := 0.0
var _strode_at := {}
var _hooks := {}
var _wings: Array[MeshInstance3D] = []
var _tentacles: Array[MeshInstance3D] = []
var _tentacle_skins: Array[ShaderMaterial] = []
var _organs: ShaderMaterial
var _crown_light: OmniLight3D
## Its lock-on: who, how long it's been locked on (s), how long it has been
## trying, and the way round them it sits (rad); the halo round them.
var lock_prey: FishController
var locks := 0
var _locked_for := 0.0
## How far it is from where it means to sit off its prey (m; probes).
var lock_miss := 0.0
var _locking := 0.0
var _lock_angle := 0.0
var _halo: MeshInstance3D
var _halo_skin: StandardMaterial3D


## What a flurry is after: a player, or a point (the butterflies it's feeding on).
class FlurryTarget:
	var fish: FishController
	var point := Vector3.ZERO

	func at() -> Vector3:
		return fish.global_position if is_instance_valid(fish) else point


# --- What each final boss sets ------------------------------------------------

func boss_title() -> String:
	return "THE FALLEN ANGEL"


func boss_line() -> String:
	return "IT OPENS ITS CROWN TO FEED"


func net_kind() -> String:
	return "angel"


func height() -> float:
	return settings.angel_height


func body_length() -> float:
	return height()


func proxy_count() -> int:
	return 5


## Head, gut (the weak spots), then down the tail.
func proxy_distance(n: int) -> float:
	return height() * [0.11, 0.4, 0.58, 0.74, 0.9][clampi(n, 0, 4)]


func proxy_radius(n: int) -> float:
	return height() * [0.14, 0.1, 0.075, 0.05, 0.035][clampi(n, 0, 4)]


## Where a held player sits: in the crown, just off the top of its head.
func mouth_point() -> Vector3:
	return rig.place(Vector3(0.0, height() * 0.03, -height() * 0.05))


func hold_reach() -> float:
	return settings.angel_lash_reach


func hold_verb() -> String:
	return "CROWNED"


## How locked on it is (0 to 1).
func lock_progress() -> float:
	if state == State.CROWN or state == State.FLURRY:
		return 1.0
	if state != State.LOCK:
		return 0.0
	return clampf(_locked_for / maxf(settings.angel_lock_time, 0.01), 0.0, 1.0) if not puppet else 0.6


## It grabs with its lashes, not by charging into you (BloodLeviathan._update_hold).
func grabs() -> bool:
	return false


func circle_radius() -> float:
	return settings.angel_lash_reach * 1.6


func _ready() -> void:
	super()
	name = "FallenAngel"
	facing = -global_basis.z
	_state_left = settings.angel_rest
	_shed_left = settings.leviathan_bolt_every * 2.0
	velocity = Vector3.ZERO
	for fish in run.local_players():
		var hook := func(_timing: float, _flow: float) -> void: _strode_at[fish] = age
		fish.strode.connect(hook)
		_hooks[fish] = hook
	_halo = MeshInstance3D.new()
	_halo.name = "LockHalo"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	_halo_skin = StandardMaterial3D.new()
	_halo_skin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_skin.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_skin.no_depth_test = true
	_halo_skin.albedo_color = Color(1.0, 0.85, 0.7, 0.0)
	torus.material = _halo_skin
	_halo.mesh = torus
	_halo.top_level = true
	_halo.visible = false
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_halo)
	_pose()


func _exit_tree() -> void:
	for fish: FishController in _hooks:
		if is_instance_valid(fish) and fish.strode.is_connected(_hooks[fish]):
			fish.strode.disconnect(_hooks[fish])
	_hooks.clear()
	super()


# --- The fight ----------------------------------------------------------------

func take_part(index: int, amount: float, by: FishController, source: String) -> void:
	var weak := parts.find(index) in [0, 1]
	var scale := 1.0
	if weak:
		scale = settings.angel_weak * (settings.angel_crown_weak if crown_open > 0.5 else 1.0)
	take(amount * scale, by, source)


## Its own moves replace the serpents' circling and diving.
func _move(delta: float) -> void:
	if not enraged and settings.leviathan_enrage > 0.0 and age >= settings.leviathan_enrage:
		_enrage_now()
	var prey := target()
	var fury := phase == Phase.FURY
	var beat := settings.angel_beat * (0.7 if fury else 1.0) / (settings.enrage_scale if enraged else 1.0)
	_beat_clock += delta / maxf(beat, 0.05)
	_state_left -= delta
	var wanted := Vector3.ZERO
	var goal := prey.global_position if prey else run.centre
	match state:
		State.HOVER:
			var off := goal - global_position
			var flat := Vector3(off.x, 0.0, off.z)
			var gap := flat.length()
			var stand := circle_radius()
			if gap > 0.01:
				wanted = flat / gap * clampf((gap - stand) / 8.0, -1.0, 1.0) * speed() * 0.7
				wanted += Vector3.UP.cross(flat / gap) * speed() * 0.25  # drifting round its prey
				_face_toward(flat, delta, 2.0)
			wanted.y = clampf((goal.y - global_position.y) / 6.0, -1.0, 1.0) * speed() * 0.4
			crown_open = move_toward(crown_open, 0.0, delta * 2.0)
			flush = move_toward(flush, 0.0, delta)
			curl = lerpf(curl, 0.15, 1.0 - exp(-3.0 * delta))
			tumble = lerpf(tumble, 0.0, 1.0 - exp(-4.0 * delta))
			if _state_left <= 0.0 and prey:
				var pick := _pick_prey()
				if pick.fish:
					_start_lock(pick.fish)
				else:
					_start_crown(pick)
		State.LOCK:
			# Shadowing its prey: matching their every move from just off them,
			# circling slowly, as the clip's angel shadows its butterfly.
			if not is_instance_valid(lock_prey) or not run.is_up(lock_prey):
				_rest()
			else:
				var gap := settings.angel_lash_reach * settings.angel_lock_gap
				_lock_angle += settings.angel_orbit * delta * _orbit
				var slot := lock_prey.global_position + Vector3(cos(_lock_angle), 0.0, sin(_lock_angle)) * gap + Vector3.UP * height() * 0.04
				# Kept in the arena (by the wall, it sits on the inside of them).
				var flat := Vector2(slot.x - run.centre.x, slot.z - run.centre.z)
				var reach := settings.arena_radius - 6.0
				if flat.length() > reach:
					flat = flat.normalized() * reach
					slot = Vector3(run.centre.x + flat.x, slot.y, run.centre.z + flat.y)
				slot.y = maxf(slot.y, run.centre.y + settings.arena_floor + 3.0)
				var miss := slot - global_position
				lock_miss = miss.length()
				wanted = lock_prey.swim_velocity() + miss * 2.4
				wanted = wanted.limit_length(speed() * 3.0)
				var to := lock_prey.global_position - global_position
				_face_toward(Vector3(to.x, 0.0, to.z), delta, 5.0)
				crown_open = move_toward(crown_open, 0.12, delta)  # its crown stirring
				flush = move_toward(flush, 0.15, delta)
				curl = lerpf(curl, 0.35, 1.0 - exp(-3.0 * delta))
				tumble = lerpf(tumble, 0.0, 1.0 - exp(-4.0 * delta))
				_locking += delta
				if miss.length() < gap * 0.6:
					_locked_for += delta
				else:
					_locked_for = maxf(_locked_for - delta * 0.5, 0.0)
				if _locked_for >= settings.angel_lock_time or _locking >= settings.angel_lock_time * 3.0 + 2.0:
					var pick := FlurryTarget.new()
					pick.fish = lock_prey
					_start_crown(pick)
		State.CROWN:
			var to := _flurry_prey.at() - global_position
			_face_toward(Vector3(to.x, 0.0, to.z), delta, 6.0)
			wanted = Vector3(0.0, clampf(to.y / 6.0, -1.0, 1.0) * speed() * 0.3, 0.0)
			var wind := _crown_time()
			crown_open = clampf(1.0 - _state_left / maxf(wind, 0.01), 0.0, 1.0)
			flush = crown_open * 0.6
			curl = lerpf(curl, 0.5, 1.0 - exp(-3.0 * delta))
			if _state_left <= 0.0:
				_start_flurry()
		State.FLURRY:
			var to := _flurry_prey.at() - global_position
			var gap := to.length()
			# Tumbling in: it rolls round its side, curling into a hook, the
			# tentacles lashing out each way (and missing, as often as not).
			wanted = to / maxf(gap, 0.01) * speed() * (1.9 if gap > settings.angel_lash_reach * 0.5 else 0.4)
			_face_toward(Vector3(to.x, 0.0, to.z), delta, 4.0)
			tumble += delta * TAU * 0.55 / maxf(settings.angel_flurry, 0.1)
			curl = lerpf(curl, 1.9, 1.0 - exp(-4.0 * delta))
			crown_open = 1.0
			flush = minf(flush + delta, 1.0)
			var elapsed := settings.angel_flurry - _state_left
			while not _lash_times.is_empty() and elapsed >= _lash_times[0]:
				_lash_times.remove_at(0)
				_lash(to)
				if held:
					break
			if held:
				state = State.HELD
			elif _state_left <= 0.0:
				_rest()
		State.HELD:
			if held == null:
				_rest()
			else:
				wanted = velocity * 0.0
				curl = lerpf(curl, 2.3, 1.0 - exp(-4.0 * delta))
				crown_open = 1.0
				flush = 1.0
				# Turning its prey this way and that in its crown.
				tumble = lerpf(tumble, sin(age * 2.2) * 0.45, 1.0 - exp(-3.0 * delta))
	# A wingbeat lifts it; between beats it sinks.
	var stroke := fposmod(_beat_clock, 1.0)
	var lift := (pow(maxf(sin(stroke * TAU), 0.0), 2.0) - 0.32) * speed() * (0.2 if state == State.LOCK else 0.45)
	wanted.y += lift
	var turn := 2.5
	var accel := 9.0
	if state == State.FLURRY:
		turn = 5.0
		accel = 22.0
	elif state == State.LOCK:
		turn = 8.0
		accel = 60.0
	steer(wanted, turn, accel, delta)
	global_position += velocity * delta
	var going := Vector3(velocity.x, 0.0, velocity.z).length()
	lean = lerpf(lean, clampf(going / maxf(speed(), 0.1), 0.0, 1.0) * deg_to_rad(40.0), 1.0 - exp(-3.0 * delta))
	if phase != Phase.CIRCLE and settings.angel_butterflies > 0 and settings.leviathan_bolt_every > 0.0:
		_shed_left -= delta
		if _shed_left <= 0.0:
			_shed_left = settings.leviathan_bolt_every * 2.0
			_shed()
	_lash_glow = maxf(_lash_glow - delta * 4.0, 0.0)
	_update_hold(delta)
	_pose()
	_glow_now()


func _crown_time() -> float:
	return settings.angel_fury_crown if phase == Phase.FURY else settings.angel_crown


## Locks on to `fish`: it shadows them until it's locked on, then its crown opens.
func _start_lock(fish: FishController) -> void:
	state = State.LOCK
	lock_prey = fish
	locks += 1
	_locked_for = 0.0
	_locking = 0.0
	var off := global_position - fish.global_position
	_lock_angle = atan2(off.z, off.x)


func _start_crown(pick: FlurryTarget = null) -> void:
	state = State.CROWN
	_state_left = _crown_time()
	_flurry_prey = pick if pick else _pick_prey()


func _start_flurry() -> void:
	state = State.FLURRY
	_state_left = settings.angel_flurry
	var count := settings.angel_fury_lashes if phase == Phase.FURY else settings.angel_lashes
	_lash_times.clear()
	for n in count:
		_lash_times.append(settings.angel_flurry * (n + 0.6) / (count + 0.2))


func _rest() -> void:
	state = State.HOVER
	lock_prey = null
	_orbit = -_orbit
	_state_left = settings.angel_rest / (settings.enrage_scale if enraged else 1.0)
	_lash_times.clear()


## Who (or what) the next flurry's for: a player, or, hurt and with Sea
## Butterflies near, the butterflies.
func _pick_prey() -> FlurryTarget:
	var pick := FlurryTarget.new()
	pick.fish = target()
	if phase != Phase.CIRCLE and hp < max_hp and run.rng.randf() < 0.5:
		var swarm := _butterflies_near(global_position, settings.angel_lash_reach * 3.0)
		if swarm.size() >= 3:
			var middle := Vector3.ZERO
			for i in swarm:
				middle += run.horde.enemy_position(i)
			pick.fish = null
			pick.point = middle / swarm.size()
	return pick


## One lash, its `n`th tentacle sweeping out toward `toward` (wobbling off it,
## so some miss). Catches a player in reach and in its cone unless they strode
## just before (a dodge); eats the zombies it catches.
func _lash(toward: Vector3) -> void:
	lashes += 1
	_lash_glow = 1.0
	var head := global_position
	var aim := toward.normalized() if toward.length_squared() > 0.01 else facing
	var wobble := Vector3(run.rng.randf_range(-1.0, 1.0), run.rng.randf_range(-0.6, 0.6), run.rng.randf_range(-1.0, 1.0)) * 0.35
	_lash_dir = (aim + wobble).normalized()
	_lash_tentacle = (_lash_tentacle + 1 + run.rng.randi_range(0, 2)) % TENTACLES
	var reach := settings.angel_lash_reach
	var cone := cos(deg_to_rad(settings.angel_lash_cone))
	# Fury: the lashes take turns between the two nearest players.
	var prey_list: Array[FishController] = run.local_players()
	if phase == Phase.FURY:
		prey_list.sort_custom(func(a: FishController, b: FishController) -> bool:
			return a.global_position.distance_squared_to(head) < b.global_position.distance_squared_to(head))
	for fish in prey_list:
		if held or not run.is_up(fish) or run.is_picking(fish):
			continue
		var off := fish.global_position - head
		var gap := off.length()
		if gap > reach + UnnaturalRun.PLAYER_RADIUS or (gap > 1.0 and off.dot(_lash_dir) < gap * cone):
			continue
		if age - float(_strode_at.get(fish, -100.0)) <= settings.angel_dodge:
			dodged += 1  # slipped it with a stride, as the butterfly does
			continue
		caught += 1
		hold(fish)
		break
	var eat := 0
	for i in run.horde.query_sphere(head, reach):
		if eat >= 12:
			break
		if run.horde.is_proxy(i) or run.horde.is_immortal(i) or not run.horde.is_alive(i):
			continue
		var off := run.horde.enemy_position(i) - head
		var gap := off.length()
		if gap > 1.0 and off.dot(_lash_dir) < gap * cone:
			continue
		var butterfly := run.horde.enemy_kind(i).id == "butterfly"
		run.horde.remove(i)
		eat += 1
		eaten += 1
		hp = minf(hp + max_hp * (settings.angel_butterfly_heal if butterfly else settings.angel_eat_heal), max_hp)


## Sheds a swarm of Sea Butterflies round itself (its prey, in the clip).
func _shed() -> void:
	var kind := _butterfly_kind()
	if kind < 0:
		return
	var away := Vector3(facing.x, 0.0, facing.z).normalized() * height() * 0.3
	butterflies_shed += run.horde.spawn_pack(kind, settings.angel_butterflies, global_position + away, 6.0, facing, 0.0)


func _butterfly_kind() -> int:
	for k in run.horde.kinds.size():
		if run.horde.kinds[k].id == "butterfly":
			return k
	return -1


func _butterflies_near(at: Vector3, reach: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	for i in run.horde.query_sphere(at, reach):
		if not run.horde.is_proxy(i) and run.horde.is_alive(i) and run.horde.enemy_kind(i).id == "butterfly":
			found.append(i)
	return found


## Turns to face `flat` (a horizontal direction) at `rate` (1/s): it turns on the spot.
func _face_toward(flat: Vector3, delta: float, rate: float) -> void:
	if flat.length_squared() < 0.0001:
		return
	facing = facing.slerp(flat.normalized(), 1.0 - exp(-rate * delta)).normalized()
	facing.y = 0.0
	facing = facing.normalized() if facing.length_squared() > 0.0001 else Vector3.FORWARD


func winding_up() -> bool:
	return state == State.CROWN


## The crown's lane toward its prey while it opens; locking on, a thin tether
## to them filling as it locks.
func telegraph() -> Dictionary:
	if state == State.LOCK:
		var prey := lock_prey if is_instance_valid(lock_prey) else target()
		if prey == null:
			return {}
		var off := prey.global_position - global_position
		return {"from": global_position, "dir": off.normalized() if off.length_squared() > 0.01 else facing,
				"length": off.length(), "width": 0.7, "progress": lock_progress()}
	if state != State.CROWN or _flurry_prey == null:
		return {}
	var to := _flurry_prey.at() - global_position
	return {"from": global_position, "dir": to.normalized() if to.length_squared() > 0.01 else facing,
			"length": to.length() + settings.angel_lash_reach * 0.5, "width": settings.angel_lash_reach * 0.6,
			"progress": crown_open}


func _glow_now() -> void:
	var warn := (0.5 + 0.5 * sin(age * 26.0)) * settings.telegraph_glow if state == State.CROWN else 0.0
	for material in skins:
		material.set_shader_parameter("flash", flash)
		material.set_shader_parameter("warn", warn)
		material.set_shader_parameter("rage", 1.0 if enraged else 0.0)
	if _organs:
		var fed := clampf(eaten / 40.0, 0.0, 1.0)
		_organs.set_shader_parameter("glow", 0.6 + crown_open * 0.9 + _lash_glow * 0.6 + (0.4 if enraged else 0.0))
		_organs.set_shader_parameter("fed", fed)
	for skin in _tentacle_skins:
		skin.set_shader_parameter("flush", flush)
		skin.set_shader_parameter("flash", flash)
	if is_instance_valid(_crown_light):
		_crown_light.light_energy = 1.2 + crown_open * 3.0 + _lash_glow * 2.0
	_pose_halo()


## The halo round the player it's locking on to: wide and faint at first,
## closing in and brightening as it locks, flaring orange as its crown opens.
func _pose_halo() -> void:
	if not is_instance_valid(_halo):
		return
	var prey: FishController = null
	if state == State.LOCK:
		prey = lock_prey if is_instance_valid(lock_prey) else (target() if puppet else null)
	elif state == State.CROWN and _flurry_prey and is_instance_valid(_flurry_prey.fish):
		prey = _flurry_prey.fish
	elif state == State.CROWN and puppet:
		prey = target()
	_halo.visible = prey != null and not dying
	if not _halo.visible:
		return
	var lock := lock_progress()
	var size := lerpf(7.0, 2.6, smoothstep(0.0, 1.0, lock)) * (1.0 + 0.06 * sin(age * 8.0))
	_halo.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * size), prey.global_position)
	var color := Color(1.0, 0.88, 0.75).lerp(Color(1.0, 0.45, 0.1), crown_open if state == State.CROWN else 0.0)
	color.a = lerpf(0.25, 0.85, lock) * (0.75 + 0.25 * sin(age * (10.0 if state == State.CROWN else 5.0)))
	_halo_skin.albedo_color = color


## Its state online: the phase, plus its state above 15 (a puppet opens its
## crown and curls as the host's does).
func _net_mode() -> int:
	return phase + 16 * state


func _set_net_mode(net_mode: int) -> void:
	super(net_mode & 15)
	state = (net_mode >> 4) as State


func _puppet_update(delta: float) -> void:
	var target_open := 0.0
	var target_curl := 0.15
	match state:
		State.CROWN:
			target_open = 1.0
			target_curl = 0.5
		State.FLURRY:
			target_open = 1.0
			target_curl = 1.9
			tumble += delta * TAU * 0.55 / maxf(settings.angel_flurry, 0.1)
		State.HELD:
			target_open = 1.0
			target_curl = 2.3
		State.LOCK:
			target_open = 0.12
			target_curl = 0.35
	if state != State.FLURRY:
		tumble = lerpf(tumble, 0.0, 1.0 - exp(-3.0 * delta))
	crown_open = move_toward(crown_open, target_open, delta * 1.5)
	flush = move_toward(flush, target_open, delta)
	curl = lerpf(curl, target_curl, 1.0 - exp(-4.0 * delta))
	var going := Vector3(velocity.x, 0.0, velocity.z)
	if going.length_squared() > 0.25:
		facing = facing.slerp(going.normalized(), 1.0 - exp(-3.0 * delta)).normalized()
	lean = lerpf(lean, clampf(going.length() / maxf(speed(), 0.1), 0.0, 1.0) * deg_to_rad(40.0), 1.0 - exp(-3.0 * delta))
	_beat_clock += delta / maxf(settings.angel_beat, 0.05)
	_glow_now()


## A puppet keeps its own facing (it's upright: turning to its velocity would
## tip it over).
func _follow_net(delta: float) -> void:
	if _net_age_now() < 0.0:
		_place_body()
		return
	super(delta)
	global_basis = Basis.IDENTITY


func _net_age_now() -> float:
	return _net_age


func face(_forward: Vector3) -> void:
	pass  # it stays upright; its body is posed from facing, lean and tumble


# --- The body -----------------------------------------------------------------

## Its body, upright: the head up top (the boss's position is its head), the
## body hanging below it, leaning toward where it's going, curling toward its
## front by `curl`, and rolling with its tumble while it flurries.
func _pose() -> void:
	var side := Vector3.UP.cross(facing).normalized()
	if side.length_squared() < 0.5:
		side = Vector3.RIGHT
	var up := Vector3.UP.rotated(side, -lean)  # leaning its head toward where it goes
	var front := facing
	if absf(tumble) > 0.001:
		var roll := Basis(side, tumble)
		up = roll * up
		front = roll * front
	front = (front - up * front.dot(up)).normalized()
	var chain := PackedVector3Array()
	var count := 14
	var step := height() / (count - 1)
	var head_top := global_position + up * height() * 0.06
	var at := head_top
	chain.append(at)
	for n in range(1, count):
		var t := float(n) / (count - 1)
		# The tail curls toward its front, more toward the tip: a hook.
		var dir := (-up).rotated(side.rotated(up, 0.0), -curl * pow(t, 1.4))
		at += dir * step
		chain.append(at)
	rig.follow_chain(chain)
	_frames_facing(front)
	_pose_parts()
	_pose_riders()
	_pose_wings(side, up, front)
	_pose_crown(up, front)
	rig.apply()


## The rig's frames from the head down with the head's front (its rest +y)
## facing `front`, carried down the body without twisting (as SpineRig._frames).
func _frames_facing(front: Vector3) -> void:
	var last_up := front
	for s in SpineRig.SPINE_N:
		var ahead := rig.points[maxi(s - 1, 0)]
		var behind := rig.points[mini(s + 1, SpineRig.SPINE_N - 1)]
		var back := behind - ahead
		back = back.normalized() if back.length_squared() > 0.000001 else Vector3.DOWN
		var guess := last_up - back * last_up.dot(back)
		if guess.length_squared() < 0.0001:
			guess = Vector3.FORWARD - back * back.z
		var right := guess.normalized().cross(back).normalized()
		var up := back.cross(right).normalized()
		rig.rights[s] = right
		rig.ups[s] = up
		last_up = up


## Beats the wings: they row forward and back at the shoulders, down hard on
## the power stroke.
func _pose_wings(_side: Vector3, _up: Vector3, _front: Vector3) -> void:
	var stroke := fposmod(_beat_clock, 1.0)
	var flap := sin(stroke * TAU) * 0.75 - 0.1
	var frame := rig.frame_at(height() * 0.24)
	for w in _wings.size():
		var wing := _wings[w]
		var sign_x := -1.0 if w == 0 else 1.0
		var root := frame.origin + frame.basis.x * sign_x * height() * 0.095 + frame.basis.y * height() * 0.01
		var turn := Basis(frame.basis.z, sign_x * flap * 0.6) * Basis(frame.basis.y, -flap * 0.5 * sign_x)
		wing.global_transform = Transform3D(turn * frame.basis * Basis.from_scale(Vector3(sign_x, 1.0, 1.0)), root)


## The crown: six tentacles out of the top of the head, folded inside it when
## closed, splayed into a starburst as it opens, one lashing out along the lash,
## all wrapped round a held player.
func _pose_crown(up: Vector3, front: Vector3) -> void:
	var base := rig.place(Vector3(0.0, height() * 0.012, height() * 0.03))  # out of the top of the hood
	var right := up.cross(front).normalized()
	var length := height() * 0.36
	for t in _tentacles.size():
		var tentacle := _tentacles[t]
		var skin := _tentacle_skins[t]
		var around := TAU * t / TENTACLES + 0.3
		var radial := (front * cos(around) + right * sin(around)).normalized()
		var root := base + radial * height() * 0.05 * crown_open  # round the opened crown's rim
		var splay := lerpf(0.05, 1.25, crown_open)
		var dir := (up * cos(splay) + radial * sin(splay)).normalized()
		var reach := lerpf(0.04, 1.0, smoothstep(0.0, 0.6, crown_open))
		var bend := lerpf(0.0, -1.1, crown_open)  # curling back at the tips
		if held and is_instance_valid(held):
			var to := held.global_position - root
			dir = (to.normalized() * 0.7 + radial * 0.3).normalized()
			reach = clampf(to.length() / length + 0.3, 0.2, 1.0)
			bend = 2.6  # wrapped round them
		elif state == State.FLURRY and t == _lash_tentacle and _lash_glow > 0.0:
			dir = dir.slerp(_lash_dir, _lash_glow).normalized()
			reach = 1.0
			bend = lerpf(bend, 0.4, _lash_glow)
		tentacle.visible = crown_open > 0.02 or held != null
		var curl_axis := dir.cross(up).normalized() if absf(dir.dot(up)) < 0.98 else right
		var y := curl_axis.cross(dir).normalized()
		tentacle.global_transform = Transform3D(Basis(curl_axis, y, dir), root)
		skin.set_shader_parameter("length", length * reach)
		skin.set_shader_parameter("curl", bend + sin(age * 3.0 + t) * 0.15 * crown_open)


## Laid out for a screenshot (boss_shots): upright, its crown open, its body curling.
func pose_for_shot(_trail: PackedVector3Array) -> void:
	crown_open = 1.0
	flush = 0.5
	curl = 0.9
	lean = 0.2
	_beat_clock = 0.25
	_pose()
	_glow_now()


func _process(delta: float) -> void:
	super(delta)
	if dying:
		for node in _wings + _tentacles:
			node.visible = false


# --- The look -----------------------------------------------------------------

## Built head up at z 0, its tail tip at z height(), its front +y.
func _build_look() -> void:
	var h := height()
	rig.reach = h * 0.25
	var body := BossMesh.new(h)
	var profile := func(along: float) -> Vector4:
		var slice := _body_slice(along)
		return Vector4(slice.x * h, slice.y * h, slice.z * h, slice.w)
	body.loft(0.0, h, profile, 220, 48, BossMesh.BODY, Callable(), 0.0,
		func(a: float, angle: float) -> float:
			# Soft lengthwise muscle ridges down the body, fading out on the head.
			return 1.0 + 0.012 * sin(angle * 14.0) * smoothstep(0.2, 0.35, a) * (1.0 - smoothstep(0.85, 1.0, a)))
	# Two horns at the top corners of the hood, pricked up and out like ears.
	for side_x: float in [-1.0, 1.0]:
		var base := Vector3(side_x * h * 0.062, h * 0.004, h * 0.05)
		var path := PackedVector3Array()
		for i in 12:
			var t := i / 11.0
			path.append(base + Vector3(side_x * (0.03 * t + 0.012 * t * t), 0.004 * t, -0.085 * t + 0.01 * t * t) * h)
		body.tube(path, func(t: float) -> float: return h * 0.024 * pow(1.0 - t, 0.85) + h * 0.001, 12, BossMesh.EXTRA)
	var skin := _spine_material(BODY_SHADER)
	skin.set_shader_parameter("height", h)
	skin.set_shader_parameter("spine_wave", Vector4(h * 0.01, 0.4, 2.2, 0.55))
	skin.set_shader_parameter("flutter", Vector3(h * 0.004, 0.8, 3.0))
	var organs := BossMesh.new(h)
	# Inside the hood: the folded crown and brain, an orange lumpy mass toward
	# its front; below the neck, the gut, a long brownish-orange sac. Both
	# glow through the glass.
	organs.loft(h * 0.018, h * 0.14, func(along: float) -> Vector4:
		var r := h * 0.08 * pow(maxf(sin(along * PI), 0.0), 0.5) * lerpf(1.0, 0.8, along)
		return Vector4(r, r * 0.72, h * 0.03, 2.0), 36, 28, BossMesh.INSIDE, Callable(), 0.0,
		func(a: float, angle: float) -> float: return 1.0 + 0.13 * sin(angle * 3.0 + a * 6.0) + 0.07 * sin(angle * 7.0 - a * 11.0))
	organs.loft(h * 0.2, h * 0.46, func(along: float) -> Vector4:
		var r := h * 0.068 * pow(maxf(sin(along * PI), 0.0), 0.45) * lerpf(1.0, 0.75, along)
		return Vector4(r * 1.15, r * 0.8, h * 0.03 * (1.0 - along * 0.5), 2.0), 48, 24, BossMesh.INSIDE, Callable(), 1.0,
		func(a: float, angle: float) -> float: return 1.0 + 0.1 * sin(angle * 2.0 + a * 13.0) + 0.06 * sin(angle * 5.0 + a * 29.0))
	_organs = _spine_material(ORGAN_SHADER)
	_organs.set_shader_parameter("height", h)
	rig.add_mesh(self, organs.commit(), _organs)
	var glass := rig.add_mesh(self, body.commit(), skin)
	glass.sorting_offset = 1.0  # drawn over the organs inside it
	# The wings: small rounded paddles at the shoulders, torn at their edges.
	var wing_skin := ShaderMaterial.new()
	wing_skin.shader = BODY_SHADER
	wing_skin.set_shader_parameter("height", h)
	wing_skin.set_shader_parameter("is_wing", true)
	skins.append(wing_skin)
	var wing_mesh := _wing_mesh(h)
	for w in 2:
		var wing := MeshInstance3D.new()
		wing.name = "Wing"
		wing.mesh = wing_mesh
		wing.material_override = wing_skin
		wing.top_level = true
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wing.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		wing.extra_cull_margin = h * 0.3
		add_child(wing)
		_wings.append(wing)
	# The crown's six tentacles (buccal cones), and the glow they open with.
	var tube := _tentacle_mesh(h * 0.36, h * 0.026)
	for t in TENTACLES:
		var material := ShaderMaterial.new()
		material.shader = TENTACLE_SHADER
		material.set_shader_parameter("rest_length", h * 0.36)
		_tentacle_skins.append(material)
		var node := MeshInstance3D.new()
		node.name = "Tentacle"
		node.mesh = tube
		node.material_override = material
		node.top_level = true
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		node.extra_cull_margin = h * 0.5
		node.visible = false
		add_child(node)
		_tentacles.append(node)
	_crown_light = OmniLight3D.new()
	_crown_light.light_color = Color(1.0, 0.5, 0.15)
	_crown_light.omni_range = h * 0.6
	_crown_light.light_energy = 1.2
	_crown_light.light_volumetric_fog_energy = 0.0
	_crown_light.light_specular = 0.0  # its highlight drew a bright streak over its head
	_add_rider(_crown_light, Vector3(0.0, 0.0, h * 0.1), Basis.IDENTITY)


## The body's slice `along` it (0 the top of the head, 1 the tail tip), in
## heights: (half width, half depth, its middle toward the front, squareness).
## As in the clip: a broad rounded hood, a slight neck under it, shoulders
## where the wings are, a long full body, then a tail tapering to a point.
const BODY_RADII := [0.13, 0.131, 0.124, 0.103, 0.104, 0.116, 0.122, 0.124, 0.123, 0.12, 0.115, 0.107, 0.097,
		0.086, 0.074, 0.061, 0.048, 0.035, 0.022, 0.011]

static func _body_slice(along: float) -> Vector4:
	var r: float
	if along < 0.08:
		r = 0.13 * sqrt(maxf(1.0 - pow(1.0 - along / 0.08, 2.0), 0.0))  # the dome of the hood
	else:
		r = FishModel._sample(BODY_RADII, (along - 0.08) / 0.92)
		r *= 1.0 - smoothstep(0.97, 1.0, along) * 0.6
	r *= sqrt(maxf(1.0 - pow(maxf(along - 0.99, 0.0) / 0.01, 2.0), 0.0))
	# Deeper front to back on the head (the hood), flatter down the tail.
	var depth := lerpf(0.92, 0.72, smoothstep(0.2, 0.9, along))
	var front := 0.012 * sin(clampf(along / 0.35, 0.0, 1.0) * PI)
	return Vector4(r, r * depth, front, 2.1)


## A wing: a small rounded paddle out to +x (rest: its root along z at x 0),
## a little cupped, both faces built so the glass can cull its back faces.
static func _wing_mesh(h: float) -> ArrayMesh:
	var mesh := BossMesh.new(h)
	var span := h * 0.2
	var root := h * 0.095
	var thick := h * 0.003
	for face in 2:
		var flip := face == 1
		mesh.membrane(func(u: float) -> Vector3:
				var v := 1.0 - u if flip else u
				return Vector3(0.0, thick * (1.0 if flip else -1.0), (v - 0.5) * root),
			func(u: float) -> Vector3:
				var v := 1.0 - u if flip else u
				var reach := span * pow(maxf(sin(v * PI), 0.0), 0.45)
				return Vector3(reach, h * 0.018 * sin(v * PI), (v - 0.5) * root * 1.5 + h * 0.012),
			40, 12, Vector2(0.0, 1.0), BossMesh.FIN, 1.0 if flip else 0.0)
	return mesh.commit()


## A crown tentacle: a tube along +z, thick at the root, thinning to a blunt
## swollen tip (angel_tentacle.gdshader bends it).
static func _tentacle_mesh(length: float, radius: float) -> ArrayMesh:
	var mesh := BossMesh.new(length)
	var path := PackedVector3Array()
	for i in 41:
		path.append(Vector3(0.0, 0.0, length * i / 40.0))
	mesh.tube(path, func(t: float) -> float:
		var r := radius * lerpf(1.0, 0.45, pow(t, 0.8))
		r *= 1.0 + 0.35 * smoothstep(0.82, 0.95, t)  # a blunt knob at the end
		return r * sqrt(maxf(1.0 - pow(maxf(t - 0.93, 0.0) / 0.07, 2.0), 0.0)) + radius * 0.002, 14, BossMesh.FILAMENT)  # closed in a round end
	return mesh.commit()


func _bolt_mesh_look() -> Mesh:
	return SphereMesh.new()  # it never spits bolts
