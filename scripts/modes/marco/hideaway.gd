extends Node
## The rules of an arena's Hideaways (planning_marco_whales.md §8, D7): spaces a
## hider reaches and a whale can't, placed on purpose by the arena
## (MarcoArena.add_hideaway_spot: a name, a position, a radius). Porthole rules
## for a bigger space, run on the host like PortholeSystem: MarcoPoloMatch calls
## step() every physics tick while a round is LIVE, and mirrors its API
## (is_hidden, gauge, entered / exited).
## - Getting in: swim in. A live hider whose middle stays inside a spot's sphere
##   for hideaway_settle seconds is hidden (is_hidden: no view, no scope, no
##   score, no answering Marco, quiet, and the bow can't reach it), if the spot
##   has room (hideaway_capacity). No button, no knock.
## - Inside it swims as it likes; leaving the sphere ends it, quietly.
## - Stale Water: a gauge per fish that fills over hideaway_time while hidden
##   and drains at hideaway_recovery of that rate outside (it carries over from
##   one hideaway to the next). Full: the fish is flushed out, away from the
##   middle at hideaway_exit_speed with a hideaway_exit_noise burst, and can't
##   hide again for hideaway_cooldown seconds. It isn't caught: it's only found.
##
## Online the host owns who's hidden and the gauge; a guest's machine learns
## (apply_net_hidden) and keeps its own fish's gauge for its HUD. A flushed
## person's fish is pushed on their own machine (MarcoPoloMatch.wake_pushed).
## Hiding in a hideaway is not a porthole: a fish in one is left to the porthole system.

signal entered(fish: FishController, index: int)
signal exited(fish: FishController, index: int)
## Stale Water ran out: `fish` was flushed from hideaway `index` (the host).
signal flushed(fish: FishController, index: int, impulse: Vector3)

## A spot's place in the tree: the node group "mp_hideaway", `radius` (m), for whale_reach_probe.
class Marker extends Node3D:
	var radius := 0.0
	var spot_name := ""
	var index := -1


var match_node: MarcoPoloMatch
var settings: MarcoPoloSettings

## [{name, position (world), radius}] as MarcoArena.hideaway_spots().
var _spots: Array[Dictionary] = []
var _markers: Array[Marker] = []
## Fish -> {index, time} while hidden.
var _inside := {}
## Fish -> {index, time} while settling in (not yet hidden).
var _settling := {}
## Fish -> 0..1, the Stale Water.
var _gauge := {}
## Fish -> seconds until it can hide again.
var _cooldown := {}


func setup(with_match: MarcoPoloMatch, spots: Array) -> void:
	match_node = with_match
	settings = with_match.settings if with_match else MarcoPoloSettings.shared()
	_spots.clear()
	for marker in _markers:
		marker.queue_free()
	_markers.clear()
	for spot: Dictionary in spots:
		_spots.append(spot)
		var marker := Marker.new()
		marker.name = "Hideaway%d" % _markers.size()
		marker.index = _markers.size()
		marker.spot_name = str(spot.get("name", ""))
		marker.radius = float(spot.radius) * settings.hideaway_radius_scale
		marker.add_to_group("mp_hideaway")
		add_child(marker)
		marker.global_position = spot.position
		_markers.append(marker)


func spots() -> Array[Dictionary]:
	return _spots.duplicate()


func count() -> int:
	return _spots.size()


## Spot `index`'s sphere radius now (m): the arena's x hideaway_radius_scale.
func radius_of(index: int) -> float:
	return float(_spots[index].radius) * settings.hideaway_radius_scale if index >= 0 and index < _spots.size() else 0.0


func position_of(index: int) -> Vector3:
	return _spots[index].position as Vector3 if index >= 0 and index < _spots.size() else Vector3.ZERO


func is_hidden(fish: FishController) -> bool:
	return _inside.has(fish)


## The Stale Water gauge, 0..1.
func gauge(fish: FishController) -> float:
	return float(_gauge.get(fish, 0.0))


## The spot `fish` is hidden in (an index), or -1.
func hideaway_of(fish: FishController) -> int:
	return int((_inside[fish] as Dictionary).index) if _inside.has(fish) else -1


## The spot whose sphere holds `point` (the nearest middle if more than one), or -1.
func spot_at(point: Vector3) -> int:
	var best := -1
	var best_distance := INF
	for i in _spots.size():
		var d := point.distance_to(position_of(i))
		if d <= radius_of(i) and d < best_distance:
			best_distance = d
			best = i
	return best


## Fish hidden in spot `index` now.
func occupants(index: int) -> int:
	var n := 0
	for fish: FishController in _inside.keys():
		if int((_inside[fish] as Dictionary).index) == index:
			n += 1
	return n


## Whether spot `index` has room.
func has_room(index: int) -> bool:
	return occupants(index) < settings.hideaway_capacity


## Whether `fish` could hide in spot `index` right now (the entry check, nothing else).
func can_hide(fish: FishController, index: int) -> bool:
	return is_instance_valid(fish) and not _inside.has(fish) and float(_cooldown.get(fish, 0.0)) <= 0.0 \
			and has_room(index) and match_node.is_live_hider(fish) and not fish.battered


## Leaves at once, quietly (online requests, probes).
func request_exit(fish: FishController) -> void:
	if _inside.has(fish):
		_leave(fish, false)


## Everyone out quietly, every gauge empty (a new round, the match ending).
func reset() -> void:
	for fish: FishController in _inside.keys():
		if is_instance_valid(fish):
			exited.emit(fish, hideaway_of(fish))
	_inside.clear()
	_settling.clear()
	_gauge.clear()
	_cooldown.clear()


func _physics_process(delta: float) -> void:
	if match_node != null and not match_node.authority:
		_guest_step(delta)


func step(delta: float) -> void:
	if match_node == null or not settings.hideaways_on:
		return
	for fish: FishController in _inside.keys():
		if not is_instance_valid(fish):
			_inside.erase(fish)
	for fish: FishController in _settling.keys():
		if not is_instance_valid(fish):
			_settling.erase(fish)
	for fish in match_node.players:
		if not is_instance_valid(fish):
			continue
		_cooldown[fish] = maxf(float(_cooldown.get(fish, 0.0)) - delta, 0.0)
		if _inside.has(fish):
			_step_inside(fish, delta)
			continue
		_drain(fish, delta)
		_step_outside(fish, delta)


func _drain(fish: FishController, delta: float) -> void:
	if not _gauge.has(fish):
		return
	var left := gauge(fish) - delta / maxf(settings.hideaway_time, 0.01) * settings.hideaway_recovery
	if left <= 0.0:
		_gauge.erase(fish)
	else:
		_gauge[fish] = left


## Out in the water: swimming into a spot with room, and staying a moment, hides it.
func _step_outside(fish: FishController, delta: float) -> void:
	var porthole := match_node.porthole_system
	var holed := porthole != null and porthole.has_method("is_hidden") and bool(porthole.call("is_hidden", fish))
	var index := -1 if holed or not match_node.is_live_hider(fish) else spot_at(fish.global_position)
	if index < 0 or not can_hide(fish, index):
		_settling.erase(fish)
		return
	var state: Dictionary = _settling.get(fish, {"index": index, "time": 0.0})
	if int(state.index) != index:
		state = {"index": index, "time": 0.0}
	state.time = float(state.time) + delta
	_settling[fish] = state
	if float(state.time) >= settings.hideaway_settle:
		_settling.erase(fish)
		_enter(fish, index)


func _enter(fish: FishController, index: int) -> void:
	_inside[fish] = {"index": index, "time": 0.0}
	Sfx.play_at("mp/porthole_in", position_of(index), 0.5)
	entered.emit(fish, index)


## Hidden: Stale Water rises; out of the sphere (swam off, knocked, battered, caught) it ends.
func _step_inside(fish: FishController, delta: float) -> void:
	var state: Dictionary = _inside[fish]
	var index: int = state.index
	state.time = float(state.time) + delta
	var full := gauge(fish) + delta / maxf(settings.hideaway_time, 0.01)
	_gauge[fish] = minf(full, 1.0)
	if full >= GASP_FROM and fish == match_node.local_fish():
		Sfx.play("mp/gasp")
	if full >= 1.0:
		_flush(fish, index)
		return
	if not match_node.is_live_hider(fish) or fish.battered \
			or fish.global_position.distance_to(position_of(index)) > radius_of(index) + 0.5:
		_leave(fish, false)


const GASP_FROM := 0.6


## Stale Water full: out of the sphere away from its middle, noisily, and no hiding again for a while.
func _flush(fish: FishController, index: int) -> void:
	var from := position_of(index)
	var away := fish.global_position - from
	if away.length() < 0.1:
		away = -fish.global_basis.z
	away = (away.normalized() + Vector3.UP * 0.15).normalized()
	_gauge.erase(fish)
	_cooldown[fish] = settings.hideaway_cooldown
	_inside.erase(fish)
	var impulse := away * settings.hideaway_exit_speed
	if not fish.puppet:
		fish.global_position = from + away * (radius_of(index) + fish.hitbox_length * 0.5 + 0.3)
		fish.linear_velocity = impulse
	match_node.add_noise(fish, settings.hideaway_exit_noise, true)
	Sfx.play_at("mp/porthole_out", fish.global_position)
	flushed.emit(fish, index, impulse)
	exited.emit(fish, index)


func _leave(fish: FishController, noisy: bool) -> void:
	var index := hideaway_of(fish)
	_inside.erase(fish)
	if noisy:
		match_node.add_noise(fish, settings.hideaway_exit_noise)
	exited.emit(fish, index)


# --- Online ---------------------------------------------------------------------------

## A guest: the host's word on `fish` and spot `index` (hidden or out). The match
## has already set it hidden for everyone's view; this keeps our own fish's
## Stale Water for its HUD.
func apply_net_hidden(fish: FishController, hidden: bool, index: int) -> void:
	if not is_instance_valid(fish):
		return
	if hidden:
		_inside[fish] = {"index": index, "time": 0.0}
		entered.emit(fish, index)
	elif _inside.has(fish):
		_inside.erase(fish)
		exited.emit(fish, index)


## A guest, every physics tick: our own fish's gauge only (the host's is the one that counts).
func _guest_step(delta: float) -> void:
	var fish := match_node.local_fish()
	if not is_instance_valid(fish):
		return
	if match_node.phase != MarcoPoloMatch.Phase.LIVE:
		_inside.erase(fish)
		_gauge.erase(fish)
		return
	if _inside.has(fish):
		_gauge[fish] = minf(gauge(fish) + delta / maxf(settings.hideaway_time, 0.01), 1.0)
		if gauge(fish) >= GASP_FROM:
			Sfx.play("mp/gasp")
	else:
		_drain(fish, delta)
