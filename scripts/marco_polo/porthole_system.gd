class_name PortholeSystem
extends Node
## The rules of an arena's portholes (planning_marco_polo.md §11), run on the
## host: MarcoPoloMatch calls step() every physics tick while a round is LIVE.
## - Getting in (porthole_jump_entry, the default): a live hider presses Jump
##   within porthole_jump_range of a free porthole's mouth, in front of its
##   wall, and slides in from wherever it is. That jump makes no noise
##   (JUMP_IN_META tells the NoiseMeter). With porthole_jump_entry off: only
##   nose first, lined up (within porthole_entry_angle of the axis), slowly
##   (under porthole_entry_speed), not mid-flip, with its nose through the
##   opening (each fish's own: its hitbox's half width times
##   porthole_radius_scale), into a free porthole. Anything else knocks off the
##   rim: bump_noise and an mp/bump thud. No magnet.
## - Inside: the fish slides in and turns to face out over porthole_turn_time,
##   its head just inside the opening; it's hidden (is_hidden: no view, no
##   scope, no score, no answering Marco, and the bow can't reach it).
##   Steering and strides do nothing: the fish is frozen in place.
## - Getting out: only jump. It shoots out along the axis at
##   porthole_exit_speed with a porthole_exit_noise burst.
## - Out of Water: a gauge per fish that fills over porthole_time inside and
##   drains at porthole_recovery of that rate outside (it carries over from one
##   porthole to the next). Full: the fish flops out and dried_out fires (the
##   match counts it as caught).
##
## Online, a guest drives its own fish, so its machine runs the entry check,
## the turn and the exit for that one fish (_guest_step) and asks the host
## (enter_requested / exit_requested, sent by MarcoPoloNet). The host owns who's
## in which porthole, the gauge and dried_out: net_enter() takes the porthole
## or refuses (the guest then knocks back out), request_exit() lets it go, and
## the host's entered/exited go back to every guest (apply_net_hidden), which
## is also how a guest hears its own fish dried out. A guest's knocks and its
## exit burst go to the host as its own noise bursts (local_burst).

signal entered(fish: FishController, porthole: Porthole)
signal exited(fish: FishController, porthole: Porthole)
signal knocked(fish: FishController, porthole: Porthole, speed: float)
signal dried_out(fish: FishController)
## A guest's own fish got in here (`hole`, index_of): ask the host.
signal enter_requested(fish: FishController, hole: int)
## A guest's own fish jumped out: tell the host.
signal exit_requested(fish: FishController)

## How far in front of the opening (m) a nose is judged (in or knock), and how
## far off the axis the rim reaches (m, at least; or twice the opening).
const MOUTH_REACH := 0.9
const RIM_REACH := 1.6
## The slowest approach that counts (m/s toward the wall): drifting past isn't a try.
const APPROACH_SPEED := 0.2
## One knock per fish per this long (s).
const KNOCK_COOLDOWN := 0.6
## A knock sends the fish back off the rim at least this fast (m/s).
const KNOCK_BOUNCE := 1.5
## Flopping out when the gauge is full (m/s).
const FLOP_SPEED := 2.0
## The gasping starts at this much of the gauge.
const GASP_FROM := 0.6
## Set on a live hider while Jump would take it into a porthole (porthole_jump_entry):
## its NoiseMeter lets that jump go quietly.
const JUMP_IN_META := &"mp_jump_in"
## After getting out, this long (s) before Jump takes the fish back in.
const JUMP_IN_COOLDOWN := 1.0

var match_node: MarcoPoloMatch
var settings: MarcoPoloSettings

var _portholes: Array[Porthole] = []
## Fish -> {porthole, time, from: Transform3D, freeze_mode, layers: Vector2i, jump_was_held}.
var _inside := {}
## Fish -> 0..1.
var _gauge := {}
## Fish -> seconds until it can knock again (or, with porthole_jump_entry, jump back in).
var _knock_left := {}
## Fish -> its jump button last tick (porthole_jump_entry's press).
var _jump_was_held := {}
## Fish asked to leave by something other than its jump button (the network, a probe).
var _exit_requests := {}
## A guest: its own fish's porthole index while the host hasn't said yes yet (-1: none).
var _pending := -1
## A guest: what the host says each porthole holds (index -> fish).
var _net_occupants := {}


func setup(with_match: MarcoPoloMatch, portholes: Array) -> void:
	match_node = with_match
	settings = with_match.settings if with_match else MarcoPoloSettings.shared()
	_portholes.clear()
	for p: Porthole in portholes:
		_portholes.append(p)


func portholes() -> Array[Porthole]:
	return _portholes.duplicate()


## `p`'s number in this arena (the same on every machine), or -1.
func index_of(p: Porthole) -> int:
	return _portholes.find(p)


func porthole_at(index: int) -> Porthole:
	return _portholes[index] if index >= 0 and index < _portholes.size() else null


func is_hidden(fish: FishController) -> bool:
	return _inside.has(fish)


## The Out of Water gauge, 0..1.
func gauge(fish: FishController) -> float:
	return float(_gauge.get(fish, 0.0))


func porthole_of(fish: FishController) -> Porthole:
	if not _inside.has(fish):
		return null
	return _inside[fish].porthole as Porthole


## Where the camera goes for `fish` inside a porthole: behind its head,
## looking out (FollowCamera); its own transform if it isn't in one.
func camera_transform(fish: FishController) -> Transform3D:
	var p := porthole_of(fish)
	return p.camera_transform(fish.hitbox_length) if p else fish.global_transform


## Leaves at once, as if jump was pressed (online guests' requests, probes).
func request_exit(fish: FishController) -> void:
	if _inside.has(fish):
		_exit_requests[fish] = true


## Everyone out quietly and every gauge empty (a new round, the match ending).
func reset() -> void:
	for fish: FishController in _inside.keys():
		if is_instance_valid(fish):
			_release(fish, 0.0)
	_inside.clear()
	_gauge.clear()
	_knock_left.clear()
	_exit_requests.clear()
	_net_occupants.clear()
	for fish: FishController in _jump_was_held.keys():
		if is_instance_valid(fish):
			fish.remove_meta(JUMP_IN_META)
	_jump_was_held.clear()
	_pending = -1
	for p in _portholes:
		p.occupant = null


func _physics_process(delta: float) -> void:
	if match_node != null and not match_node.authority:
		_guest_step(delta)


func step(delta: float) -> void:
	if match_node == null:
		return
	for fish: FishController in _inside.keys():
		if not is_instance_valid(fish):
			var gone: Porthole = _inside[fish].porthole
			gone.occupant = null
			_inside.erase(fish)
	for fish in match_node.players:
		if not is_instance_valid(fish):
			continue
		if _inside.has(fish):
			_step_inside(fish, delta)
			continue
		if _gauge.has(fish):
			var left := gauge(fish) - delta / maxf(settings.porthole_time, 0.01) * settings.porthole_recovery
			if left <= 0.0:
				_gauge.erase(fish)
			else:
				_gauge[fish] = left
		_knock_left[fish] = float(_knock_left.get(fish, 0.0)) - delta
		_try_enter(fish)


# --- Getting in ------------------------------------------------------------------------

## The way in porthole_jump_entry says: Jump near a mouth, or nose first.
## On the host a guest's fish (a puppet) gets in when its guest asks (net_enter).
func _try_enter(fish: FishController) -> void:
	var able := match_node.is_live_hider(fish) and not fish.battered and not fish.freeze
	if not settings.porthole_jump_entry:
		fish.remove_meta(JUMP_IN_META)
		if able:
			_try_portholes(fish)
		return
	if fish.puppet:
		return
	var held := _jump_held(fish)
	var pressed := held and not bool(_jump_was_held.get(fish, false))
	_jump_was_held[fish] = held
	var p := jump_porthole(fish) if able else null
	if p == null:
		fish.remove_meta(JUMP_IN_META)
		return
	fish.set_meta(JUMP_IN_META, true)
	if pressed:
		_enter(fish, p)
		if not match_node.authority:
			_pending = index_of(p)
			enter_requested.emit(fish, _pending)


## The free porthole Jump takes `fish` into now (porthole_jump_entry): the
## nearest whose mouth is within porthole_jump_range, with the fish in front of
## its wall; null if none, for anyone but a live hider, or straight after getting out.
func jump_porthole(fish: FishController) -> Porthole:
	if not settings.porthole_jump_entry or _inside.has(fish) or float(_knock_left.get(fish, 0.0)) > 0.0 \
			or not match_node.is_live_hider(fish):
		return null
	var best: Porthole = null
	var best_distance := settings.porthole_jump_range
	for p in _portholes:
		if not p.is_free() or p.along(fish.global_position) < -fish.hitbox_length * 0.25:
			continue
		var distance := fish.global_position.distance_to(p.mouth())
		if distance <= best_distance:
			best_distance = distance
			best = p
	return best

func _try_portholes(fish: FishController) -> void:
	var forward := -fish.global_basis.z.normalized()
	var nose := fish.global_position + forward * fish.hitbox_length * 0.5
	for p in _portholes:
		var in_front := p.along(nose)
		if in_front > MOUTH_REACH or in_front < -fish.hitbox_length * 0.5:
			continue
		var off := p.off_axis(nose)
		if off > maxf(RIM_REACH, p.radius * 2.0):
			continue
		var closing := -fish.linear_velocity.dot(p.axis())
		if closing < APPROACH_SPEED:
			continue
		if float(_knock_left.get(fish, 0.0)) > 0.0:
			return
		if can_enter(fish, p):
			_enter(fish, p)
			if not match_node.authority:
				_pending = index_of(p)
				enter_requested.emit(fish, _pending)
		else:
			_knock(fish, p, closing)
		return


## Whether `fish` would get into `p` now (the entry check, nothing else).
func can_enter(fish: FishController, p: Porthole) -> bool:
	return entry_problem(fish, p) == ""


## Why `fish` can't get into `p` now ("" if it can): taken, size, angle, speed or flip.
func entry_problem(fish: FishController, p: Porthole) -> String:
	if not p.is_free():
		return "taken"
	var forward := -fish.global_basis.z.normalized()
	var nose := fish.global_position + forward * fish.hitbox_length * 0.5
	if rad_to_deg(forward.angle_to(-p.axis())) > settings.porthole_entry_angle:
		return "angle"
	if p.off_axis(nose) > opening(fish):
		return "size"
	if fish.linear_velocity.length() > settings.porthole_entry_speed:
		return "speed"
	if fish.is_flipping():
		return "flip"
	return ""


## The opening `fish` has to get its nose through (m off the axis).
func opening(fish: FishController) -> float:
	return fish.hitbox_width * 0.5 * settings.porthole_radius_scale


func _enter(fish: FishController, p: Porthole) -> void:
	p.occupant = fish
	_inside[fish] = {"porthole": p, "time": 0.0, "from": fish.global_transform, "freeze_mode": fish.freeze_mode,
			"layers": Vector2i(fish.collision_layer, fish.collision_mask), "jump_was_held": _jump_held(fish)}
	fish.linear_velocity = Vector3.ZERO
	fish.angular_velocity = Vector3.ZERO
	fish.collision_layer = 0
	fish.collision_mask = 0
	fish.remove_meta(JUMP_IN_META)
	if not fish.puppet:
		fish.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		fish.freeze = true
	Sfx.play_at("mp/porthole_in", p.mouth())
	entered.emit(fish, p)


func _knock(fish: FishController, p: Porthole, closing: float) -> void:
	_knock_left[fish] = KNOCK_COOLDOWN
	match_node.add_noise(fish, settings.bump_noise)
	var nose := fish.global_position - fish.global_basis.z.normalized() * fish.hitbox_length * 0.5
	Sfx.play_at("mp/bump", nose, clampf(closing / 10.0, 0.15, 1.0))
	fish.apply_push(p.axis() * (closing + KNOCK_BOUNCE))
	knocked.emit(fish, p, closing)


# --- Inside ---------------------------------------------------------------------------

func _step_inside(fish: FishController, delta: float) -> void:
	var state: Dictionary = _inside[fish]
	var p: Porthole = state.porthole
	state.time = float(state.time) + delta
	var seat := p.seat(fish.hitbox_length)
	var k := smoothstep(0.0, 1.0, clampf(float(state.time) / maxf(settings.porthole_turn_time, 0.001), 0.0, 1.0))
	var from: Transform3D = state.from
	if not fish.puppet:
		fish.global_transform = from.interpolate_with(seat, k)
	var full := gauge(fish) + delta / maxf(settings.porthole_time, 0.01)
	_gauge[fish] = minf(full, 1.0)
	if fish == match_node.local_fish() and full >= GASP_FROM:
		Sfx.play("mp/gasp")
	if full >= 1.0:
		_release(fish, FLOP_SPEED)
		Sfx.play_at("mp/fish_out_of_water", p.mouth())
		_gauge.erase(fish)
		exited.emit(fish, p)
		dried_out.emit(fish)
		return
	# A guest's fish (a puppet here) leaves when its guest says (request_exit),
	# never on this machine's jump button; its exit burst comes from the guest.
	var held := _jump_held(fish) if not fish.puppet else false
	var pressed := held and not bool(state.jump_was_held)
	state.jump_was_held = held
	if (pressed or _exit_requests.has(fish)) and (fish.puppet or float(state.time) >= minf(settings.porthole_turn_time, 0.2)):
		_exit_requests.erase(fish)
		_release(fish, settings.porthole_exit_speed)
		if not fish.puppet:
			match_node.add_noise(fish, settings.porthole_exit_noise)
		Sfx.play_at("mp/porthole_out", p.mouth())
		exited.emit(fish, p)


## Out of its porthole along the axis at `speed`, simulated again.
func _release(fish: FishController, speed: float) -> void:
	var state: Dictionary = _inside[fish]
	var p: Porthole = state.porthole
	_inside.erase(fish)
	_exit_requests.erase(fish)
	p.occupant = null
	var layers: Vector2i = state.layers
	fish.collision_layer = layers.x
	fish.collision_mask = layers.y
	var out := p.axis()
	if not fish.puppet:
		fish.global_transform = Transform3D(Basis.looking_at(out, Vector3.UP if absf(out.y) < 0.9 else Vector3.BACK),
				p.mouth() + out * (fish.hitbox_length * 0.5 + 0.4))
		fish.freeze = false
		fish.freeze_mode = state.freeze_mode
		fish.linear_velocity = out * speed
		fish.angular_velocity = Vector3.ZERO
	_knock_left[fish] = maxf(KNOCK_COOLDOWN * 2.0, JUMP_IN_COOLDOWN)  # no knocking (or jumping) straight back in on the way out
	_jump_was_held[fish] = true  # the jump that got it out doesn't take it back in


## Whether `fish`'s jump is held: its bot's input, or its player's controls.
func _jump_held(fish: FishController) -> bool:
	if fish.controls:
		return fish.controls.jump
	var source: PlayerInput = fish.input_source if fish.input_source else PlayerInput.everyone()
	return source.pressed("jump")


# --- Online ---------------------------------------------------------------------------

## The host: a guest's fish got into porthole `hole` on its own machine. Takes
## it if it's still free and the fish is a live hider; false means no (the
## guest knocks back out: MarcoPoloNet sends apply_net_denied).
func net_enter(fish: FishController, hole: int) -> bool:
	var p := porthole_at(hole)
	if p == null or not is_instance_valid(fish) or not match_node.is_live_hider(fish) or _inside.has(fish) or not p.is_free():
		return false
	_enter(fish, p)
	return true


## A guest: the host's word on `fish` and porthole `hole` (in or out). For our
## own fish it confirms what we did, or (out while we're still in that
## porthole, confirmed) means it dried out: flop out.
func apply_net_hidden(fish: FishController, hidden: bool, hole: int) -> void:
	var p := porthole_at(hole)
	if p == null or not is_instance_valid(fish):
		return
	var own := fish == match_node.local_fish()
	if hidden:
		_net_occupants[hole] = fish
		p.occupant = fish
		if own and _pending == hole:
			_pending = -1  # confirmed
		return
	if _net_occupants.get(hole) == fish:
		_net_occupants.erase(hole)
	if not own:
		if p.occupant == fish:
			p.occupant = null
		return
	if _inside.has(fish) and porthole_of(fish) == p and _pending != hole:
		_release(fish, FLOP_SPEED)
		Sfx.play_at("mp/fish_out_of_water", p.mouth())
		_gauge.erase(fish)
		exited.emit(fish, p)


## A guest: the host said no to our fish in porthole `hole` (someone beat us
## to it, or we're not a live hider any more): knock back out.
func apply_net_denied(fish: FishController, hole: int) -> void:
	if fish != match_node.local_fish() or _pending != hole:
		return
	_pending = -1
	var p := porthole_of(fish)
	if p == null:
		return
	_release(fish, KNOCK_BOUNCE)
	if _net_occupants.has(hole):
		p.occupant = _net_occupants[hole] as FishController
	match_node.add_noise(fish, settings.bump_noise)
	Sfx.play_at("mp/bump", p.mouth(), 0.4)
	knocked.emit(fish, p, KNOCK_BOUNCE)


## A guest, every physics tick: our own fish only. The gauge here is only for
## its HUD; the host's is the one that counts.
func _guest_step(delta: float) -> void:
	var fish := match_node.local_fish()
	if not is_instance_valid(fish):
		return
	if match_node.phase != MarcoPoloMatch.Phase.LIVE:
		if _inside.has(fish):
			_release(fish, 0.0)
		_pending = -1
		return
	if _inside.has(fish):
		var state: Dictionary = _inside[fish]
		var p: Porthole = state.porthole
		state.time = float(state.time) + delta
		var k := smoothstep(0.0, 1.0, clampf(float(state.time) / maxf(settings.porthole_turn_time, 0.001), 0.0, 1.0))
		fish.global_transform = (state.from as Transform3D).interpolate_with(p.seat(fish.hitbox_length), k)
		var full := minf(gauge(fish) + delta / maxf(settings.porthole_time, 0.01), 1.0)
		_gauge[fish] = full
		if full >= GASP_FROM:
			Sfx.play("mp/gasp")
		var held := _jump_held(fish)
		var pressed := held and not bool(state.jump_was_held)
		state.jump_was_held = held
		if (pressed or _exit_requests.has(fish)) and float(state.time) >= minf(settings.porthole_turn_time, 0.2):
			_pending = -1
			_release(fish, settings.porthole_exit_speed)
			if _net_occupants.get(index_of(p)) != fish:
				p.occupant = _net_occupants.get(index_of(p)) as FishController
			match_node.add_noise(fish, settings.porthole_exit_noise)
			Sfx.play_at("mp/porthole_out", p.mouth())
			exited.emit(fish, p)
			exit_requested.emit(fish)
		return
	if _gauge.has(fish):
		var left := gauge(fish) - delta / maxf(settings.porthole_time, 0.01) * settings.porthole_recovery
		if left <= 0.0:
			_gauge.erase(fish)
		else:
			_gauge[fish] = left
	_knock_left[fish] = float(_knock_left.get(fish, 0.0)) - delta
	_try_enter(fish)
