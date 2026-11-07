class_name WhatStinksNet
extends Node
## Online What Stinks? (what_stinks.md Phase 6): CoopSession's child "WhatStinks"
## (the same path everywhere, so its RPCs meet), carrying what's the mode's own.
## CoopSession still does the session, the roster, the players' fish (each
## machine runs its own and sends it) and the tuning.
##
## The host (WhatStinksMatch.authority) judges everything, and sends:
## - reliable: each round (to each guest its own place; the Hunters, the ocean's
##   seed and its schools), the clocks' phase changes, the round's results and the
##   match's end, each bite (what it took: the same school fish by index, and the
##   prey players), spits (the fling and daze), hurls, feeding, Clicks and Sniffs,
##   schools that appear and go, the fish alive in every school (twice a second),
##   and the bots (there are no bots on a guest: puppets of the host's, named by
##   negative ids);
## - to prey only, never the Hunter (it can't know who is a player): who joined
##   which school's place, who left, who spooked. A Hunter guest sees a school it
##   can't tell from any other;
## - unreliable: the schools' leaders and alarm, the bots' states, the clocks and
##   the Hunters' bars, and VIEW_RATE times a second to each guest only what its own
##   player sees: as a Hunter, the exposure of every live prey; as prey, only its
##   own exposure, echo and noise rings. Never anyone else's points (they go out at
##   ROUND_OVER).
## A guest runs no judging: its Join, Leave and Spook buttons are requests, its
## Hunter's bite begins here (the jaws) and its landing (mouth and heading) is
## reported, its buttons (Click, Sniff) and its noise bursts go to the host. The
## host takes the bite's reach, radius and capacity from its own form and size.
## Claimed places are assigned by the host only; a guest applies them with the
## host's index.

const VIEW_RATE := 10.0
const SEND_RATE := 30.0
const SCHOOL_RATE := 10.0
const MASK_RATE := 2.0
const STATUS_RATE := 4.0

var coop: CoopSession
var game: WhatStinksMatch

## Host: bot fish -> its id (negative). Guest: id -> NetFish of the host's bot.
var _bot_ids := {}
var _bot_nets := {}
## Host: bot fish -> times it was placed (so its puppets snap rather than glide).
var _bot_teleports := {}
var _links: Array = []
var _view_left := 0.0
var _send_left := 0.0
var _school_left := 0.0
var _mask_left := 0.0
var _status_left := 0.0
## What the last view packets carried, per peer (for the probe): peer -> the args.
var sent_views := {}
## What the last join, bite and spit messages carried (for the probe): counts per RPC name.
var sent_counts := {}


func _ready() -> void:
	name = "WhatStinks"
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_host() -> bool:
	return game != null and game.authority


## Wires `match_node` up: what it does goes out (the host), what we do goes to the host (a guest).
func hook(match_node: WhatStinksMatch) -> void:
	unhook()
	game = match_node
	sent_views.clear()
	sent_counts.clear()
	if game.authority:
		_number_bots()
		_link(game.round_started, _on_round_started)
		_link(game.phase_changed, _on_phase_changed)
		_link(game.round_over, _on_round_over)
		_link(game.match_over, _on_match_over)
		_link(game.bite_started, _on_bite_started)
		_link(game.bite_result, _on_bite_result)
		_link(game.bite_penalty, _on_bite_penalty)
		_link(game.spit_applied, _on_spit)
		_link(game.hurled, _on_hurled)
		_link(game.fed, _on_fed)
		_link(game.join.joined, _on_joined)
		_link(game.join.left, _on_left)
		_link(game.join.spooked, _on_spooked)
		_link(game.echo.clicked, _on_clicked)
		_link(game.echo.sniff_changed, _on_sniff)
		_link(game.field.school_added, _on_school_added)
		_link(game.field.school_removed, _on_school_removed)
	else:
		_link(game.local_bite, _on_local_bite)
		_link(game.bite_started, _on_local_bite_started)
		_link(game.echo.local_buttons, _on_local_buttons)
		_link(game.echo.local_burst, _on_local_burst)
		_link(game.join.requested, _on_join_requested)


func unhook() -> void:
	for pair: Array in _links:
		var sig: Signal = pair[0]
		var target: Object = sig.get_object()
		if is_instance_valid(target) and sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	_links.clear()
	for net: NetFish in _bot_nets.values():
		if is_instance_valid(net.fish):
			net.fish.queue_free()
	_bot_nets.clear()
	_bot_ids.clear()
	_bot_teleports.clear()
	game = null


func _link(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_links.append([sig, callable])


## The match as it is now, for a guest joining (CoopSession's _welcome).
func world() -> Dictionary:
	var hunter_ids := []
	for fish in game.hunters:
		hunter_ids.append(id_of(fish))
	var eaten_ids := []
	for fish: FishController in game.eaten:
		if is_instance_valid(fish):
			eaten_ids.append(id_of(fish))
	var hurled_ids := []
	for fish: FishController in game.hurled_out:
		if is_instance_valid(fish):
			hurled_ids.append(id_of(fish))
	var schools := []
	for school in game.field.schools:
		schools.append([school.id, school.rng.seed, int(school.character), school.fish_count(), school.leader_position, school.leader_heading,
				school.alarm, school.alive_mask(), school.home])
	var claims := []
	for entry: Array in game.join.claims():
		claims.append([id_of(entry[0]), entry[1], entry[2]])
	return {"mode": "what_stinks", "variant": int(game.settings.variant), "form": game.settings.form, "size": game.size.size_mult,
			"bots": _bot_list(), "round": game.round_index, "rounds": game.rounds_in_match(), "phase": game.phase,
			"phase_left": game.phase_left, "time_left": game.time_left, "hunters": hunter_ids, "eaten": eaten_ids, "hurled": hurled_ids,
			"totals": _by_id(game.totals()), "seed": game.last_seed, "schools": schools, "claims": claims,
			"satiation": _by_id(game.satiation), "queasy": _by_id(game.queasy)}


## A guest: the host's match as it was when we joined.
func apply_world(state: Dictionary) -> void:
	game.settings.variant = int(state.get("variant", 0)) as WhatStinksSettings.Variant
	game.settings.form = str(state.get("form", game.settings.form))
	game.size.size_mult = float(state.get("size", game.size.size_mult))
	_apply_bots(state.get("bots", []))
	var entries := []
	for entry: Array in state.get("schools", []):
		entries.append([entry[0], entry[1], entry[2], entry[3], entry[4], entry[5]])
	game.apply_net_world(int(state.round), _fish_list(state.get("hunters", [])), _fish_list(state.get("eaten", [])), int(state.phase),
			float(state.phase_left), float(state.time_left), _from_id(state.get("totals", {})), int(state.get("rounds", 1)), int(state.get("seed", 0)), entries)
	var age := coop.rtt / 2.0
	for entry: Array in state.get("schools", []):
		var school := game.field.school_by_id(int(entry[0]))
		if school:
			school.home = entry[8]
			school.apply_alive_mask(entry[7])
			school.set_net_state(entry[4], entry[5], entry[6], age)
	game.apply_net_stomach(_from_id(state.get("satiation", {})), _from_id(state.get("queasy", {})))
	for fish: FishController in _fish_list(state.get("hurled", [])):
		game.hurled_out[fish] = true
	for claim: Array in state.get("claims", []):
		var fish := fish_by_id(int(claim[0]))
		var school := game.field.school_by_id(int(claim[1]))
		if fish and school:
			game.join.join(fish, school, int(claim[2]), true)


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


func _ids(fish_list: Array) -> Array:
	var out := []
	for fish: Variant in fish_list:
		if is_instance_valid(fish):
			out.append(id_of(fish as FishController))
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


## Every guest's peer with a fish in the match.
func _peers() -> Array:
	var out := []
	for fish in game.players:
		var peer := _peer_of(fish)
		if peer != 0 and not out.has(peer):
			out.append(peer)
	return out


## The peers whose player is prey now (the Hunter's never told who joined a school).
func _prey_peers() -> Array:
	var out := []
	for fish in game.players:
		var peer := _peer_of(fish)
		if peer != 0 and game.role_of(fish) == WhatStinksMatch.Role.PREY and not out.has(peer):
			out.append(peer)
	return out


func _send_to_prey(method: StringName, args: Array) -> void:
	sent_counts[method] = int(sent_counts.get(method, 0)) + 1
	for peer: int in _prey_peers():
		coop.send_from(self, peer, method, args, true)


func _send_all(method: StringName, args: Array, reliable := true) -> void:
	sent_counts[method] = int(sent_counts.get(method, 0)) + 1
	coop.send_from(self, 0, method, args, reliable)


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
		net.fish.name = "StinkBot%d" % -id
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
			net.fish.visible = not game.eaten.has(net.fish)
			if not game.join.is_joined(net.fish):
				net.apply()
	if is_host():
		_host_tick(delta)


func _host_tick(delta: float) -> void:
	_send_left -= delta
	if _send_left <= 0.0:
		_send_left += 1.0 / SEND_RATE
		var states := []
		for fish: FishController in _bot_ids:
			if is_instance_valid(fish):
				states.append([int(_bot_ids[fish]), fish.global_position, fish.global_basis.get_rotation_quaternion(), fish.linear_velocity,
						fish.replay_fx(), int(_bot_teleports.get(fish, 0))])
		if not states.is_empty():
			coop.send_from(self, 0, "_ws_bot_states", [CoopSession._now(), states], false)
	_school_left -= delta
	if _school_left <= 0.0:
		_school_left += 1.0 / SCHOOL_RATE
		var states := []
		for school in game.field.schools:
			var state := school.net_state()
			states.append([school.id, state[0], state[1], state[2]])
		coop.send_from(self, 0, "_ws_schools_snap", [states], false)
	_mask_left -= delta
	if _mask_left <= 0.0:
		_mask_left += 1.0 / MASK_RATE
		var masks := []
		for school in game.field.schools:
			masks.append([school.id, school.alive_mask()])
		coop.send_from(self, 0, "_ws_masks", [masks], true)
	_status_left -= delta
	if _status_left <= 0.0:
		_status_left += 1.0 / STATUS_RATE
		coop.send_from(self, 0, "_ws_status", [game.phase, game.phase_left, game.time_left, _by_id(game.satiation), _by_id(game.queasy)], false)
	_view_left -= delta
	if _view_left <= 0.0:
		_view_left += 1.0 / VIEW_RATE
		_send_views()


## Each guest's own view: a Hunter's exposures of the live prey and its Click's cooldown, or a prey's
## own exposure, echo and noise. Nobody else's.
func _send_views() -> void:
	for fish in game.players:
		var peer := _peer_of(fish)
		if peer == 0:
			continue
		var view := {}
		var own_echo := 0.0
		var own_noise := 0.0
		var click_in := 0.0
		if game.role_of(fish) == WhatStinksMatch.Role.HUNTER:
			for prey in game.live_prey():
				var exposure := game.echo.exposure(fish, prey)
				if exposure > 0.001:
					view[id_of(prey)] = exposure
			click_in = game.echo.click_ready_in(fish)
		else:
			view[id_of(fish)] = game.max_exposure(fish)
			own_echo = game.echo.echo_max(fish)
			own_noise = game.echo.noise_of(fish)
		var args := [view, own_echo, own_noise, click_in]
		sent_views[peer] = args
		coop.send_from(self, peer, "_ws_view", args, false)


# --- Host: match -> session --------------------------------------------------

func _on_round_started(index: int, hunters: Array) -> void:
	_number_bots()
	for fish: FishController in game.players:
		if not fish.puppet:
			coop._teleports[fish] = int(coop._teleports.get(fish, 0)) + 1
			_bot_teleports[fish] = int(_bot_teleports.get(fish, 0)) + 1
	_send_all("_ws_bots", [_bot_list()])
	var schools := []
	for school in game.field.schools:
		schools.append([school.id, school.rng.seed, int(school.character), school.fish_count(),
				school.get_meta("ws_at", school.leader_position), school.get_meta("ws_heading", school.leader_heading)])
	var totals := _by_id(game.totals())
	var starting := _ids(hunters)
	for fish in game.players:
		var peer := _peer_of(fish)
		if peer == 0:
			continue
		var place: Transform3D = game.round_places.get(fish, Transform3D.IDENTITY)
		coop.send_from(self, peer, "_ws_round", [index, starting, coop.pid_of(fish), place, totals, game.rounds_in_match(),
				int(game.settings.variant), game.settings.form, game.size.size_mult, game.last_seed, schools], true)


## The clocks go out on a phase change to LIVE (the round message carries the countdown, the
## results the end of a round, the match's end its own).
func _on_phase_changed(new_phase: int) -> void:
	if new_phase == WhatStinksMatch.Phase.LIVE:
		_send_all("_ws_phase", [new_phase, game.phase_left, game.settings.round_time])


func _on_round_over(results: Dictionary) -> void:
	var out := {"hunters_won": bool(results.hunters_won), "points": _by_id(results.points), "eaten": int(results.eaten),
			"survivors": _ids(results.survivors), "hunters": _ids(results.hunters), "reason": str(results.reason), "spat": int(results.spat),
			"satiation": _by_id(results.satiation), "queasy": _by_id(results.queasy)}
	_send_all("_ws_round_over", [out, _by_id(game.match_totals)])


func _on_match_over(best: FishController) -> void:
	_send_all("_ws_match_over", [id_of(best)])


## A bite of the host's own (or a bot's) began; a guest's is relayed in _ws_bite_start.
func _on_bite_started(hunter: FishController) -> void:
	if not hunter.puppet:
		_send_all("_ws_bite_started", [id_of(hunter)])


func _on_bite_result(hunter: FishController, taken: Dictionary, prey: Array) -> void:
	_send_all("_ws_bite", [id_of(hunter), taken, _ids(prey)])


func _on_bite_penalty(hunter: FishController, extra: float) -> void:
	var peer := _peer_of(hunter)
	if peer != 0:
		coop.send_from(self, peer, "_ws_bite_penalty", [extra], true)


func _on_spit(prey: FishController, hunter: FishController, velocity: Vector3, daze: float) -> void:
	_send_all("_ws_spit", [id_of(prey), id_of(hunter), velocity, daze])


func _on_hurled(hunter: FishController) -> void:
	_send_all("_ws_hurl", [id_of(hunter)])


func _on_fed(hunter: FishController, gain: float) -> void:
	_send_all("_ws_fed", [id_of(hunter), gain])


func _on_joined(fish: FishController, school: School, index: int) -> void:
	_send_to_prey("_ws_joined", [id_of(fish), school.id, index])


func _on_left(fish: FishController, loud: bool) -> void:
	_send_to_prey("_ws_left", [id_of(fish), loud])


func _on_spooked(fish: FishController, school: School) -> void:
	var state := int(school.get_meta("ws_spook_state", 0))
	_send_to_prey("_ws_spooked", [id_of(fish), state, true])
	# The Hunter sees the school bolt (not who made it): the same scatter, no name.
	var prey_peers := _prey_peers()
	for peer: int in _peers():
		if not prey_peers.has(peer):
			coop.send_from(self, peer, "_ws_startled", [school.id, state], true)


func _on_clicked(hunter: FishController, origin: Vector3, reached: int) -> void:
	_send_all("_ws_click", [id_of(hunter), origin, reached])


func _on_sniff(hunter: FishController, on: bool) -> void:
	_send_all("_ws_sniff", [id_of(hunter), on])


func _on_school_added(school: School) -> void:
	_send_all("_ws_school_added", [school.id, school.rng.seed, int(school.character), school.fish_count(), school.leader_position, school.leader_heading])


func _on_school_removed(id: int) -> void:
	_send_all("_ws_school_removed", [id])


# --- Guest: our player -> the host --------------------------------------------

func _own_pid() -> int:
	return coop.pid_of(game.local_fish())


func _on_join_requested(action: String, school_id: int, index: int) -> void:
	match action:
		"join":
			coop.send_from(self, 1, "_ws_join_request", [_own_pid(), school_id, index], true)
		"leave":
			coop.send_from(self, 1, "_ws_leave_request", [_own_pid()], true)
		"spook":
			coop.send_from(self, 1, "_ws_spook_request", [_own_pid()], true)


## Our Hunter's jaws open: the host and so everyone else's copy of us open theirs.
func _on_local_bite_started(hunter: FishController) -> void:
	if hunter == game.local_fish():
		coop.send_from(self, 1, "_ws_bite_start", [_own_pid()], true)


## Our Hunter's jaws shut: where, and which way: the host judges what it ate.
func _on_local_bite(mouth: Vector3, forward: Vector3) -> void:
	coop.send_from(self, 1, "_ws_bite_land", [_own_pid(), mouth, forward], true)


func _on_local_buttons(mask: int) -> void:
	coop.send_from(self, 1, "_ws_buttons", [_own_pid(), mask], true)


func _on_local_burst(amount: float) -> void:
	coop.send_from(self, 1, "_ws_burst", [_own_pid(), amount], true)


# --- RPCs: host side -------------------------------------------------------

## The guest's fish `pid`, if the message came from that guest (else null).
func _sender_fish(pid: int) -> FishController:
	var fish := fish_by_id(pid)
	if not is_host() or fish == null or pid / 100 != multiplayer.get_remote_sender_id():
		return null
	return fish


@rpc("any_peer", "call_remote", "reliable")
func _ws_join_request(pid: int, school_id: int, index: int) -> void:
	var fish := _sender_fish(pid)
	var school := game.field.school_by_id(school_id) if fish else null
	if fish and school:
		if not game.join.join(fish, school, index):
			game.join.join(fish, school)


@rpc("any_peer", "call_remote", "reliable")
func _ws_leave_request(pid: int) -> void:
	var fish := _sender_fish(pid)
	if fish:
		game.join.leave(fish)


@rpc("any_peer", "call_remote", "reliable")
func _ws_spook_request(pid: int) -> void:
	var fish := _sender_fish(pid)
	if fish:
		game.join.spook(fish)


@rpc("any_peer", "call_remote", "reliable")
func _ws_bite_start(pid: int) -> void:
	var fish := _sender_fish(pid)
	var bite: HunterBite = game.bites.get(fish) if fish else null
	if bite == null or not game.is_hunter(fish):
		return
	bite.net_start()
	var sender := multiplayer.get_remote_sender_id()
	for peer: int in _peers():
		if peer != sender:
			coop.send_from(self, peer, "_ws_bite_started", [pid], true)


@rpc("any_peer", "call_remote", "reliable")
func _ws_bite_land(pid: int, mouth: Vector3, forward: Vector3) -> void:
	var fish := _sender_fish(pid)
	if fish:
		game.judge_net_bite(fish, mouth, forward)


@rpc("any_peer", "call_remote", "reliable")
func _ws_buttons(pid: int, mask: int) -> void:
	var fish := _sender_fish(pid)
	if fish:
		fish.set_meta("ws_buttons", mask)


@rpc("any_peer", "call_remote", "reliable")
func _ws_burst(pid: int, amount: float) -> void:
	var fish := _sender_fish(pid)
	if fish and game.is_live_prey(fish):
		game.echo.add_noise(fish, amount)


# --- RPCs: guest side ------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _ws_bots(list: Array) -> void:
	if game and not is_host():
		_apply_bots(list)


@rpc("authority", "call_remote", "unreliable")
func _ws_bot_states(time: float, states: Array) -> void:
	if game == null or is_host():
		return
	for state: Array in states:
		var net: NetFish = _bot_nets.get(int(state[0]))
		if net:
			net.push(time, state[1], state[2], state[3], state[4], int(state[5]))


@rpc("authority", "call_remote", "reliable")
func _ws_round(index: int, starting_ids: Array, own_pid: int, place: Transform3D, totals: Dictionary, rounds: int, variant: int, form: String,
		size_mult: float, ocean_seed: int, schools: Array) -> void:
	if game == null or is_host() or own_pid != coop.pid_of(game.local_fish()):
		return
	game.settings.variant = variant as WhatStinksSettings.Variant
	game.settings.form = form
	game.size.size_mult = size_mult
	game.apply_net_round(index, _fish_list(starting_ids), place, _from_id(totals), rounds, ocean_seed, schools)
	coop._teleports[game.local_fish()] = int(coop._teleports.get(game.local_fish(), 0)) + 1


@rpc("authority", "call_remote", "reliable")
func _ws_phase(new_phase: int, phase_left: float, time_left: float) -> void:
	if game and not is_host():
		game.apply_net_phase(new_phase, phase_left, time_left)


@rpc("authority", "call_remote", "unreliable")
func _ws_status(phase: int, phase_left: float, time_left: float, satiation: Dictionary, queasy: Dictionary) -> void:
	if game == null or is_host():
		return
	game.apply_net_clock(phase, phase_left, time_left)
	game.apply_net_stomach(_from_id(satiation), _from_id(queasy))


@rpc("authority", "call_remote", "reliable")
func _ws_round_over(results: Dictionary, totals: Dictionary) -> void:
	if game == null or is_host():
		return
	var mine := {"hunters_won": bool(results.hunters_won), "points": _from_id(results.points), "eaten": int(results.eaten),
			"survivors": _fish_list(results.survivors), "hunters": _fish_list(results.hunters), "reason": str(results.reason),
			"spat": int(results.spat), "satiation": _from_id(results.satiation), "queasy": _from_id(results.queasy)}
	game.apply_net_round_over(mine, _from_id(totals))


@rpc("authority", "call_remote", "reliable")
func _ws_match_over(winner_id: int) -> void:
	if game and not is_host():
		game.apply_net_match_over(fish_by_id(winner_id))


@rpc("authority", "call_remote", "reliable")
func _ws_bite_started(hunter_id: int) -> void:
	var fish := fish_by_id(hunter_id)
	var bite: HunterBite = game.bites.get(fish) if game and fish else null
	if bite and not is_host():
		bite.net_start()


@rpc("authority", "call_remote", "reliable")
func _ws_bite(hunter_id: int, taken: Dictionary, prey_ids: Array) -> void:
	var fish := fish_by_id(hunter_id)
	if game and not is_host() and fish:
		game.apply_net_bite(fish, taken, _fish_list(prey_ids))


## Our own bite waits longer (it chewed, or spat something out).
@rpc("authority", "call_remote", "reliable")
func _ws_bite_penalty(extra: float) -> void:
	if game and not is_host():
		var bite: HunterBite = game.bites.get(game.local_fish())
		if bite:
			bite.cooldown += extra


@rpc("authority", "call_remote", "reliable")
func _ws_spit(prey_id: int, hunter_id: int, velocity: Vector3, daze: float) -> void:
	var prey := fish_by_id(prey_id)
	var hunter := fish_by_id(hunter_id)
	if game and not is_host() and prey and hunter:
		game.apply_net_spit(prey, hunter, velocity, daze)


@rpc("authority", "call_remote", "reliable")
func _ws_hurl(hunter_id: int) -> void:
	var hunter := fish_by_id(hunter_id)
	if game and not is_host() and hunter:
		game.apply_net_hurl(hunter)


@rpc("authority", "call_remote", "reliable")
func _ws_fed(hunter_id: int, gain: float) -> void:
	var hunter := fish_by_id(hunter_id)
	if game and not is_host() and hunter:
		game.apply_net_fed(hunter, gain)


@rpc("authority", "call_remote", "reliable")
func _ws_joined(fish_id: int, school_id: int, index: int) -> void:
	var fish := fish_by_id(fish_id)
	var school := game.field.school_by_id(school_id) if game else null
	if game and not is_host() and fish and school:
		game.join.join(fish, school, index, true)


@rpc("authority", "call_remote", "reliable")
func _ws_left(fish_id: int, loud: bool) -> void:
	var fish := fish_by_id(fish_id)
	if game and not is_host() and fish:
		game.join.leave(fish, loud)


@rpc("authority", "call_remote", "reliable")
func _ws_spooked(fish_id: int, rng_state: int, has_state: bool) -> void:
	var fish := fish_by_id(fish_id)
	if game and not is_host() and fish:
		game.join.spook(fish, true, rng_state if has_state else null)


@rpc("authority", "call_remote", "reliable")
func _ws_startled(school_id: int, rng_state: int) -> void:
	var school := game.field.school_by_id(school_id) if game else null
	if school and not is_host():
		school.rng.state = rng_state
		school.startle(game.settings.spook_strength, game.settings.spook_groups, game.settings.spook_reform)


@rpc("authority", "call_remote", "reliable")
func _ws_click(hunter_id: int, origin: Vector3, reached: int) -> void:
	var fish := fish_by_id(hunter_id)
	if game and not is_host() and fish:
		game.echo.apply_net_click(fish, origin, reached)


@rpc("authority", "call_remote", "reliable")
func _ws_sniff(hunter_id: int, on: bool) -> void:
	var fish := fish_by_id(hunter_id)
	if game and not is_host() and fish:
		game.echo.apply_net_sniff(fish, on)


@rpc("authority", "call_remote", "reliable")
func _ws_school_added(id: int, school_seed: int, kind: int, count: int, at: Vector3, heading: Vector3) -> void:
	if game and not is_host() and game.field.school_by_id(id) == null:
		game.field.add_school(at, heading, kind as FishCharacter.FishClass, count, school_seed, id)


@rpc("authority", "call_remote", "reliable")
func _ws_school_removed(id: int) -> void:
	if game and not is_host():
		game.field.remove_school(id)


@rpc("authority", "call_remote", "unreliable")
func _ws_schools_snap(states: Array) -> void:
	if game == null or is_host():
		return
	var age := coop.rtt / 2.0
	for state: Array in states:
		var school := game.field.school_by_id(int(state[0]))
		if school:
			school.set_net_state(state[1], state[2], state[3], age)


## The fish alive in each school; one grown by the steady respawn grows here too.
@rpc("authority", "call_remote", "reliable")
func _ws_masks(masks: Array) -> void:
	if game == null or is_host():
		return
	for entry: Array in masks:
		var school := game.field.school_by_id(int(entry[0]))
		if school == null:
			continue
		var mask: PackedByteArray = entry[1]
		if school.settings.fish_per_school != mask.size():
			school.settings.fish_per_school = mask.size()
		school.apply_alive_mask(mask)


@rpc("authority", "call_remote", "unreliable")
func _ws_view(view: Dictionary, own_echo: float, own_noise: float, click_in: float) -> void:
	if game == null or is_host():
		return
	game.echo.apply_net_view(_from_id(view), own_echo, own_noise, click_in)
