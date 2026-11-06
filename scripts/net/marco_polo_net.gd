class_name MarcoPoloNet
extends Node
## Online Marco Polo (planning_marco_polo.md §8): CoopSession's child
## "MarcoPolo" (the same path everywhere, so its RPCs meet), carrying what's
## Marco Polo's own. CoopSession still does the session, the roster, the
## players' fish (each machine runs its own and sends it) and the tuning.
##
## The host (MarcoPoloMatch.authority) judges everything, and sends:
## - reliable: rounds (each guest only its own fish's start), the phase and
##   clocks, catches (tags, fish out of water; conversions follow from the
##   variant), "Marco!", FOOLED, porthole in/out, the round's results and the
##   match's end, and the bots (there are no bots on a guest: puppets of the
##   host's, named by negative ids);
## - unreliable, VIEW_RATE times a second, to each guest only what its own
##   player sees: as a seeker, the exposure of every hider in its view; as a
##   hider, its own exposure (the layer pip), its own round tally and whether
##   it's in sight (the eye pip) — never anyone else's points (§6: other
##   players' round points go out only at ROUND_OVER); and each seeker
##   guest's own pings, already blurred;
## - the bots' states, SEND_RATE times a second.
## A guest runs no noise of its own but its hider's bursts (flips, strides,
## jumps), which it sends; its "Marco!" and Fake Fish buttons; and where its
## camera looks (the sight cone is round the seeker's camera).

const VIEW_RATE := 10.0
const SEND_RATE := 30.0

var coop: CoopSession
var game: MarcoPoloMatch

## Host: bot fish -> its id (negative). Guest: id -> NetFish of the host's bot.
var _bot_ids := {}
var _bot_nets := {}
var _view_left := 0.0
var _send_left := 0.0
## What the last view packets carried, per peer (for the probe): peer -> the args.
var sent_views := {}


func _ready() -> void:
	name = "MarcoPolo"
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_host() -> bool:
	return game != null and game.authority


## Wires `match_node` up: what it does goes out.
func hook(match_node: MarcoPoloMatch) -> void:
	unhook()
	game = match_node
	sent_views.clear()
	if game.authority:
		_number_bots()
		game.round_started.connect(_on_round_started)
		game.phase_changed.connect(_on_phase_changed)
		game.caught.connect(_on_caught)
		game.round_over.connect(_on_round_over)
		game.match_over.connect(_on_match_over)
		game.marco_called.connect(_on_marco)
		game.pinged.connect(_on_pinged)
		game.fooled.connect(_on_fooled)
		game.bots_changed.connect(_on_bots_changed)
		game.whale_picked.connect(_on_whale_picked)
		game.wake_pushed.connect(_on_wake_pushed)
		game.marco_tell_started.connect(func(seeker: FishController, time: float) -> void: coop.send_from(self, 0, "_mp_tell", [id_of(seeker), time], true))
		var holes := game.porthole_system
		if holes and holes.has_signal("entered"):
			holes.connect("entered", func(fish: FishController, hole: Node) -> void: _send_hidden(fish, true, hole))
			holes.connect("exited", func(fish: FishController, hole: Node) -> void: _send_hidden(fish, false, hole))
		var hideaways := game.hideaway_system
		if hideaways:
			hideaways.connect("entered", func(fish: FishController, index: int) -> void: _send_hideaway(fish, true, index))
			hideaways.connect("exited", func(fish: FishController, index: int) -> void: _send_hideaway(fish, false, index))
	else:
		game.local_burst.connect(_on_local_burst)
		game.local_button.connect(_on_local_button)
		game.local_whale_pick.connect(_on_local_whale_pick)
		var holes := game.porthole_system
		if holes and holes.has_signal("enter_requested"):
			holes.connect("enter_requested", _on_porthole_enter)
			holes.connect("exit_requested", _on_porthole_exit)


func unhook() -> void:
	if game and is_instance_valid(game):
		for connection in get_incoming_connections():
			var sig: Signal = connection.signal
			if sig.get_object() == game or sig.get_object() == game.porthole_system or sig.get_object() == game.hideaway_system:
				sig.disconnect(connection.callable)
	for net: NetFish in _bot_nets.values():
		if is_instance_valid(net.fish):
			net.fish.queue_free()
	_bot_nets.clear()
	_bot_ids.clear()
	game = null


## The match as it is now, for a guest joining (CoopSession's _welcome).
func world() -> Dictionary:
	var roles := {}
	for fish in game.players:
		roles[id_of(fish)] = game.role_of(fish)
	var out := []
	for fish: FishController in game.eliminated:
		out.append(id_of(fish))
	var picks := {}
	for fish in game.seekers():
		var pick := game.whale_pick_of(fish)
		if bool(pick.locked):
			picks[id_of(fish)] = [int(pick.species), int(pick.skin)]
	return {"mode": "marco_polo", "arena": game.settings.arena, "variant": int(game.settings.variant), "bots": _bot_list(),
			"round": game.round_index, "rounds": game.rounds_in_match(), "phase": game.phase, "phase_left": game.phase_left,
			"time_left": game.time_left, "roles": roles, "eliminated": out, "totals": _by_id(game.totals()), "whale_picks": picks}


## A guest: the host's match as it was when we joined.
func apply_world(state: Dictionary) -> void:
	game.settings.variant = int(state.get("variant", 0)) as MarcoPoloSettings.Variant
	_apply_bots(state.get("bots", []))
	var roles := {}
	var given: Dictionary = state.get("roles", {})
	for id: Variant in given:
		var fish := fish_by_id(int(id))
		if fish:
			roles[fish] = int(given[id])
	var picks: Dictionary = state.get("whale_picks", {})
	for id: Variant in picks:
		var fish := fish_by_id(int(id))
		if fish:
			game.apply_net_whale_pick(fish, int((picks[id] as Array)[0]), int((picks[id] as Array)[1]))
	game.apply_net_state(int(state.round), roles, _fish_list(state.get("eliminated", [])), int(state.phase), float(state.phase_left),
			float(state.time_left), _from_id(state.get("totals", {})), int(state.get("rounds", 1)))


# --- Ids -------------------------------------------------------------------

## A fish's id on the network: its player id (CoopSession), or a bot's negative id.
func id_of(fish: FishController) -> int:
	if fish == null:
		return 0
	if is_host():
		if _bot_ids.has(fish):
			return int(_bot_ids[fish])
	else:
		for id: int in _bot_nets:
			if (_bot_nets[id] as NetFish).fish == fish:
				return id
	return coop.pid_of(fish)


func fish_by_id(id: int) -> FishController:
	if id == 0:
		return null
	if id < 0:
		if is_host():
			for fish: FishController in _bot_ids:
				if int(_bot_ids[fish]) == id:
					return fish
			return null
		var net: NetFish = _bot_nets.get(id)
		return net.fish if net and is_instance_valid(net.fish) else null
	return coop.fish_of(id)


func _fish_list(ids: Array) -> Array[FishController]:
	var out: Array[FishController] = []
	for id: Variant in ids:
		var fish := fish_by_id(int(id))
		if fish:
			out.append(fish)
	return out


func _by_id(values: Dictionary) -> Dictionary:
	var out := {}
	for fish: Variant in values:
		if is_instance_valid(fish):
			out[id_of(fish as FishController)] = values[fish]
	return out


func _from_id(values: Dictionary) -> Dictionary:
	var out := {}
	for id: Variant in values:
		var fish := fish_by_id(int(id))
		if fish:
			out[fish] = values[id]
	return out


## The peer whose player `fish` is (0: none, a bot or ours).
func _peer_of(fish: FishController) -> int:
	var pid := coop.pid_of(fish)
	return pid / 100 if pid >= 0 and fish.puppet else 0


func _number_bots() -> void:
	_bot_ids.clear()
	var next := -1
	for fish: FishController in game.bots:
		_bot_ids[fish] = next
		next -= 1


func _bot_list() -> Array:
	var out := []
	for fish: FishController in _bot_ids:
		if is_instance_valid(fish):
			out.append([int(_bot_ids[fish]), int(fish.character), FishCharacter.species_key(fish.character, fish.species), fish.display_name])
	return out


## A guest: puppets of the host's bots to match `list` ([id, character, species key, name]).
func _apply_bots(list: Array) -> void:
	var wanted := {}
	for entry: Array in list:
		wanted[int(entry[0])] = entry
	for id: int in _bot_nets.keys():
		if not wanted.has(id):
			var gone: NetFish = _bot_nets[id]
			_bot_nets.erase(id)
			if is_instance_valid(gone.fish):
				game.remove_player(gone.fish)
				gone.fish.queue_free()
	for id: int in wanted:
		if _bot_nets.has(id):
			continue
		var entry: Array = wanted[id]
		var net := NetFish.new()
		net.fish = CoopSession.FISH_SCENE.instantiate()
		net.fish.name = "MarcoBot%d" % -id
		var fish_class: FishCharacter.FishClass = int(entry[1]) as FishCharacter.FishClass
		net.fish.set_look(fish_class, FishCharacter.species_from_key(fish_class, str(entry[2])))
		net.fish.display_name = str(entry[3])
		game.add_child(net.fish)
		net.fish.make_puppet()
		net.fish.visible = false  # until its first snapshot
		_bot_nets[id] = net
		game.add_player(net.fish)


# --- Each tick -------------------------------------------------------------

func tick(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	for net: NetFish in _bot_nets.values():
		if net.has_state() and is_instance_valid(net.fish):
			net.apply()
	if is_host():
		_send_left -= delta
		if _send_left <= 0.0:
			_send_left += 1.0 / SEND_RATE
			var states := []
			for fish: FishController in _bot_ids:
				if is_instance_valid(fish):
					states.append([int(_bot_ids[fish]), fish.global_position, fish.global_basis.get_rotation_quaternion(), fish.linear_velocity,
							fish.replay_fx()])
			if not states.is_empty():
				coop.send_from(self, 0, "_mp_bot_states", [CoopSession._now(), states], false)
	_view_left -= delta
	if _view_left > 0.0:
		return
	_view_left += 1.0 / VIEW_RATE
	if is_host():
		_send_views()
	else:
		var me := game.local_fish()
		var camera := game.camera as Node3D
		if is_instance_valid(me) and camera and camera.is_inside_tree():
			coop.send_from(self, 1, "_mp_look", [coop.pid_of(me), camera.global_basis], false)


## Each guest's own view: a seeker's exposures of the hiders, or a hider's
## own exposure, own round tally and eye pip. Nobody else's points.
func _send_views() -> void:
	for fish in game.players:
		var peer := _peer_of(fish)
		if peer == 0:
			continue
		var exposures := {}
		var tally := 0.0
		var seen := false
		if game.role_of(fish) == MarcoPoloMatch.Role.SEEKER:
			for hider in game.live_hiders():
				exposures[id_of(hider)] = game.whale_sees(fish, hider)  # a whale's eyes, else the layers as ever
		else:
			exposures[id_of(fish)] = game.max_exposure(fish)
			tally = game.round_tally(fish)
			seen = game._seen_now.has(fish)
		var args := [exposures, tally, seen]
		sent_views[peer] = args
		coop.send_from(self, peer, "_mp_view", args, false)


# --- Host: match -> session --------------------------------------------------

func _on_round_started(index: int, _seeker: FishController) -> void:
	var starting := []
	for fish in game.starting_seekers:
		starting.append(id_of(fish))
	var totals := _by_id(game.totals())
	_on_bots_changed()
	for fish in game.players:
		var peer := _peer_of(fish)
		if peer == 0:
			continue
		var place: Transform3D = game.round_places.get(fish, Transform3D.IDENTITY)
		coop.send_from(self, peer, "_mp_round", [index, starting, coop.pid_of(fish), place, totals, game.rounds_in_match(),
				int(game.settings.variant)], true)


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == MarcoPoloMatch.Phase.ROUND_OVER or new_phase == MarcoPoloMatch.Phase.OVER:
		return  # their own messages carry them
	coop.send_from(self, 0, "_mp_phase", [new_phase, game.phase_left, game.time_left], true)


func _on_caught(hider: FishController, how: String, by: FishController) -> void:
	coop.send_from(self, 0, "_mp_caught", [id_of(hider), how, id_of(by)], true)


func _on_round_over(results: Dictionary) -> void:
	var survivors := []
	for fish: FishController in results.survivors:
		survivors.append(id_of(fish))
	coop.send_from(self, 0, "_mp_round_over", [_by_id(results.points), _by_id(results.totals), survivors, bool(results.cleared)], true)


func _on_match_over(best: FishController) -> void:
	coop.send_from(self, 0, "_mp_match_over", [id_of(best)], true)


func _on_marco(seeker: FishController) -> void:
	coop.send_from(self, 0, "_mp_marco", [id_of(seeker)], true)


func _on_pinged(seeker: FishController, at: Vector3, loudness: float, polo: bool) -> void:
	var peer := _peer_of(seeker)
	if peer != 0:
		coop.send_from(self, peer, "_mp_ping", [at, loudness, polo], false)


## The host: a whale's pick is final: everyone wears it.
func _on_whale_picked(fish: FishController, species: int, skin: int) -> void:
	coop.send_from(self, 0, "_mp_whale_pick", [id_of(fish), species, skin], true)


## The host: a whale's wake pushes a person's fish: their own machine applies it.
func _on_wake_pushed(hider: FishController, impulse: Vector3) -> void:
	var peer := _peer_of(hider)
	if peer != 0:
		coop.send_from(self, peer, "_mp_wake", [impulse], false)


func _on_fooled(seeker: FishController, _fake: FishController) -> void:
	coop.send_from(self, 0, "_mp_fooled", [id_of(seeker)], true)


func _on_bots_changed() -> void:
	_number_bots()
	coop.send_from(self, 0, "_mp_bots", [_bot_list()], true)


func _send_hideaway(fish: FishController, hidden: bool, index: int) -> void:
	coop.send_from(self, 0, "_mp_hideaway", [id_of(fish), hidden, index], true)


func _send_hidden(fish: FishController, hidden: bool, hole: Node) -> void:
	coop.send_from(self, 0, "_mp_hidden", [id_of(fish), hidden, int(game.porthole_system.call("index_of", hole))], true)


# --- Guest: our player -> the host --------------------------------------------

func _on_local_burst(amount: float) -> void:
	coop.send_from(self, 1, "_mp_burst", [coop.pid_of(game.local_fish()), amount], true)


func _on_local_button(action: String) -> void:
	coop.send_from(self, 1, "_mp_button", [coop.pid_of(game.local_fish()), action], true)


## Our whale pick on the card (shown or locked): the host decides it.
func _on_local_whale_pick(species: int, skin: int, locked: bool) -> void:
	coop.send_from(self, 1, "_mp_whale_request", [coop.pid_of(game.local_fish()), species, skin, locked], true)


## Our fish got into porthole `hole` here: the host says yes (_mp_hidden) or no (_mp_porthole_denied).
func _on_porthole_enter(fish: FishController, hole: int) -> void:
	coop.send_from(self, 1, "_mp_porthole_enter", [coop.pid_of(fish), hole], true)


func _on_porthole_exit(fish: FishController) -> void:
	coop.send_from(self, 1, "_mp_porthole_exit", [coop.pid_of(fish)], true)


# --- RPCs: host side -------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _mp_burst(pid: int, amount: float) -> void:
	var fish := fish_by_id(pid)
	if is_host() and fish and pid / 100 == multiplayer.get_remote_sender_id():
		game.add_noise(fish, amount)


@rpc("any_peer", "call_remote", "reliable")
func _mp_button(pid: int, action: String) -> void:
	var fish := fish_by_id(pid)
	if not is_host() or fish == null or pid / 100 != multiplayer.get_remote_sender_id():
		return
	if action == "marco":
		game.marco(fish)
	elif action == "fake":
		game.throw_fake(fish)


@rpc("any_peer", "call_remote", "reliable")
func _mp_whale_request(pid: int, species: int, skin: int, locked: bool) -> void:
	var fish := fish_by_id(pid)
	if is_host() and fish and pid / 100 == multiplayer.get_remote_sender_id():
		game.apply_whale_request(fish, species, skin, locked)


@rpc("any_peer", "call_remote", "reliable")
func _mp_porthole_enter(pid: int, hole: int) -> void:
	var fish := fish_by_id(pid)
	if not is_host() or fish == null or pid / 100 != multiplayer.get_remote_sender_id() or game.porthole_system == null:
		return
	if not bool(game.porthole_system.call("net_enter", fish, hole)):
		coop.send_from(self, pid / 100, "_mp_porthole_denied", [pid, hole], true)


@rpc("any_peer", "call_remote", "reliable")
func _mp_porthole_exit(pid: int) -> void:
	var fish := fish_by_id(pid)
	if is_host() and fish and pid / 100 == multiplayer.get_remote_sender_id() and game.porthole_system:
		game.porthole_system.call("request_exit", fish)


@rpc("any_peer", "call_remote", "unreliable")
func _mp_look(pid: int, view: Basis) -> void:
	var fish := fish_by_id(pid)
	if is_host() and fish and pid / 100 == multiplayer.get_remote_sender_id():
		fish.set_meta("mp_view", view)


# --- RPCs: guest side ------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _mp_bots(list: Array) -> void:
	if game and not is_host():
		_apply_bots(list)


@rpc("authority", "call_remote", "unreliable")
func _mp_bot_states(time: float, states: Array) -> void:
	if game == null or is_host():
		return
	for state: Array in states:
		var net: NetFish = _bot_nets.get(int(state[0]))
		if net:
			net.push(time, state[1], state[2], state[3], state[4], 0)


@rpc("authority", "call_remote", "reliable")
func _mp_round(index: int, starting_ids: Array, own_pid: int, place: Transform3D, totals: Dictionary, rounds: int, variant: int) -> void:
	if game == null or is_host() or own_pid != coop.pid_of(game.local_fish()):
		return
	game.settings.variant = variant as MarcoPoloSettings.Variant
	game.apply_net_round(index, _fish_list(starting_ids), place, _from_id(totals), rounds)


@rpc("authority", "call_remote", "reliable")
func _mp_phase(new_phase: int, phase_left: float, time_left: float) -> void:
	if game and not is_host():
		game.apply_net_phase(new_phase, phase_left, time_left)


@rpc("authority", "call_remote", "reliable")
func _mp_caught(hider_id: int, how: String, by_id: int) -> void:
	var hider := fish_by_id(hider_id)
	if game and not is_host() and hider:
		game.apply_net_caught(hider, how, fish_by_id(by_id))


@rpc("authority", "call_remote", "reliable")
func _mp_round_over(points: Dictionary, totals: Dictionary, survivor_ids: Array, cleared: bool) -> void:
	if game and not is_host():
		game.apply_net_round_over(_from_id(points), _from_id(totals), _fish_list(survivor_ids), cleared)


@rpc("authority", "call_remote", "reliable")
func _mp_match_over(winner_id: int) -> void:
	if game and not is_host():
		game.apply_net_match_over(fish_by_id(winner_id))


@rpc("authority", "call_remote", "reliable")
func _mp_marco(seeker_id: int) -> void:
	var seeker := fish_by_id(seeker_id)
	if game and not is_host() and seeker:
		game.apply_net_marco(seeker)


@rpc("authority", "call_remote", "reliable")
func _mp_whale_pick(id: int, species: int, skin: int) -> void:
	var fish := fish_by_id(id)
	if game and not is_host() and fish:
		game.apply_net_whale_pick(fish, species, skin)


@rpc("authority", "call_remote", "unreliable")
func _mp_wake(impulse: Vector3) -> void:
	if game and not is_host():
		game.apply_net_wake(impulse)


@rpc("authority", "call_remote", "unreliable")
func _mp_ping(at: Vector3, loudness: float, polo: bool) -> void:
	if game and not is_host():
		game.apply_net_ping(at, loudness, polo)


@rpc("authority", "call_remote", "reliable")
func _mp_fooled(seeker_id: int) -> void:
	var seeker := fish_by_id(seeker_id)
	if game and not is_host() and seeker:
		game.apply_net_fooled(seeker, null)


## A whale's call is about to come (marco_tell_time): the blowhole tell on every machine.
@rpc("authority", "call_remote", "reliable")
func _mp_tell(seeker_id: int, time: float) -> void:
	var seeker := fish_by_id(seeker_id)
	if game and not is_host() and seeker:
		game.apply_net_tell(seeker, time)


@rpc("authority", "call_remote", "reliable")
func _mp_hidden(id: int, hidden: bool, hole: int) -> void:
	var fish := fish_by_id(id)
	if game and not is_host() and fish:
		game.apply_net_hidden(fish, hidden)
		if game.porthole_system and game.porthole_system.has_method("apply_net_hidden"):
			game.porthole_system.call("apply_net_hidden", fish, hidden, hole)


## A hider went into (or out of) hideaway `index` on the host (Stale Water runs there).
@rpc("authority", "call_remote", "reliable")
func _mp_hideaway(id: int, hidden: bool, index: int) -> void:
	var fish := fish_by_id(id)
	if game and not is_host() and fish:
		game.apply_net_hidden(fish, hidden)
		if game.hideaway_system:
			game.hideaway_system.call("apply_net_hidden", fish, hidden, index)


@rpc("authority", "call_remote", "reliable")
func _mp_porthole_denied(pid: int, hole: int) -> void:
	var fish := fish_by_id(pid)
	if game and not is_host() and fish and game.porthole_system:
		game.porthole_system.call("apply_net_denied", fish, hole)


@rpc("authority", "call_remote", "unreliable")
func _mp_view(exposures: Dictionary, tally: float, seen: bool) -> void:
	if game == null or is_host():
		return
	game.apply_net_exposure(_from_id(exposures))
	game.apply_net_own_tally(tally, seen)
