class_name NatureNet
extends ModeNet
## Online co-op in Nature (going_coop.md §3): CoopSession's child "Nature" (the
## same path everywhere, so its RPCs meet), carrying what's Nature's own.
## CoopSession still does the session, the roster, the players' fish (each
## machine runs its own and sends it) and the tuning.
##
## The host runs the world (NatureRun.authority): the schools' leaders and
## alarms (sent SCHOOL_RATE times a second; every machine swims the fish around
## them itself, School.follower), spawns and removals (with their seeds), the
## lone fish (its state SEND_RATE times a second), pearl drops, the shared counts,
## restarts.
## - A battery shows first where the attacker is, and is claimed to the host,
##   which confirms it to everyone (two claims on one fish within
##   NatureRun.SHARE_WINDOW share it). Pearls the same.
## - Each player's points, multis and sprees are their own machine's; their
##   awards are sent to the others' feeds.

## School leaders per second.
const SCHOOL_RATE := 10.0

var run: NatureRun
## The run last hooked (puppets leave it after unhook()).
var _last_run: NatureRun
## The host's lone fish, on a guest.
var _target_net := NetFish.new()
var _school_left := 0.0


func _ready() -> void:
	name = "Nature"
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_host() -> bool:
	return run != null and run.authority


func puppet_added(fish: FishController) -> void:
	if is_instance_valid(_last_run):
		_last_run.add_player(fish)


func puppet_removed(fish: FishController) -> void:
	if is_instance_valid(_last_run):
		_last_run.remove_player(fish)


func puppet_parent() -> Node:
	return _last_run


## Wires `mode_game` up: what it does goes out.
func hook(mode_game: GameMode) -> void:
	unhook()
	run = mode_game as NatureRun
	_last_run = run
	_target_net.clear()
	run.school_spawned.connect(_on_school_spawned)
	run.school_removed.connect(_on_school_removed)
	run.battery_claimed.connect(_on_battery_claimed)
	run.battery_confirmed.connect(_on_battery_confirmed)
	run.battery_shared.connect(_on_battery_shared)
	run.pearl_claimed.connect(_on_pearl_claimed)
	run.pearl_confirmed.connect(_on_pearl_confirmed)
	run.target_state.connect(_on_target_state)
	run.restarted.connect(_on_restarted)
	run.awarded.connect(_on_awarded)
	run.fish_teleported.connect(coop.note_teleport)


func unhook() -> void:
	if run == null or not is_instance_valid(run):
		run = null
		return
	for sig: StringName in [&"school_spawned", &"school_removed", &"battery_claimed", &"battery_confirmed",
			&"battery_shared", &"pearl_claimed", &"pearl_confirmed", &"target_state", &"restarted", &"awarded"]:
		for connection in run.get_signal_connection_list(sig):
			if (connection.callable as Callable).get_object() == self:
				run.disconnect(sig, connection.callable)
	if run.fish_teleported.is_connected(coop.note_teleport):
		run.fish_teleported.disconnect(coop.note_teleport)
	run = null


func _send_all(method: StringName, args: Array, reliable: bool) -> void:
	coop.send_from(self, 0, method, args, reliable)


func _send_host(method: StringName, args: Array, reliable: bool) -> void:
	coop.send_from(self, 1, method, args, reliable)


# --- Each tick -------------------------------------------------------------

## The puppets follow their players (hidden while battered), the lone fish follows the
## host's (a guest's), ours and the host's lone fish go out, and the host's schools.
func tick(delta: float) -> void:
	if run == null or not is_instance_valid(run):
		return
	coop.follow_puppets(func(fish: FishController) -> bool: return not fish.battered)
	if not run.authority and _target_net.has_state() and not run.target.battered:
		_target_net.fish = run.target
		_target_net.apply()
	if coop.send_own_fish(delta, run.local_players()) and run.authority and not run.target.battered:
		var target := run.target
		_send_all("_target_snap", [CoopSession._now(), target.global_position, target.global_basis.get_rotation_quaternion(),
				target.linear_velocity, target.replay_fx(), coop._teleports.get(target, 0)], false)
	if run.authority:
		_school_left -= delta
		if _school_left <= 0.0:
			_school_left += 1.0 / SCHOOL_RATE
			var states := []
			for school in run.schools:
				var state := school.net_state()
				states.append([school.id, state[0], state[1], state[2]])
			_send_all("_schools_snap", [CoopSession._now(), states], false)


# --- Run -> session --------------------------------------------------------

func _on_school_spawned(school: School, at: Vector3, heading: Vector3) -> void:
	if run.authority:
		_send_all("_school_spawned", [school.id, school.rng.seed, int(school.character), at, heading], true)


func _on_school_removed(id: int) -> void:
	if run.authority:
		_send_all("_school_removed", [id], true)


func _on_battery_claimed(key: String, attacker: FishController, chain: int) -> void:
	_send_host("_claim_battery", [key, coop.pid_of(attacker), chain], true)


func _on_battery_confirmed(key: String, attackers: Array, at: Vector3, pearl_id: int) -> void:
	if run.authority:
		_send_all("_battery_confirmed", [key, attackers.map(coop.pid_of), at, pearl_id], true)


func _on_battery_shared(key: String, attacker: FishController) -> void:
	if run.authority:
		_send_all("_battery_shared", [key, coop.pid_of(attacker)], true)


func _on_pearl_claimed(id: int, by: FishController) -> void:
	_send_host("_claim_pearl", [id, coop.pid_of(by)], true)


func _on_pearl_confirmed(id: int, by: FishController) -> void:
	if run.authority:
		_send_all("_pearl_confirmed", [id, coop.pid_of(by)], true)


func _on_target_state(present: bool, at: Transform3D, target_name: String, generation: int) -> void:
	if run.authority:
		coop._teleports[run.target] = coop._teleports.get(run.target, 0) + 1
		_send_all("_target_state", [present, at, target_name, generation], true)


func _on_restarted() -> void:
	if run.authority:
		_send_all("_restart", [], true)


func _on_awarded(event: Dictionary) -> void:
	var by: Variant = event.get("by")
	if not is_instance_valid(by) or (by as FishController).puppet:
		return
	var sent := event.duplicate()
	sent.erase("by")
	sent.merge(run.score_of(by).stats())  # the scoreboard's numbers ride along
	_send_all("_award", [coop.pid_of(by), sent], true)


# --- Joining ---------------------------------------------------------------

## The world as it is now, for a guest joining (CoopSession's _welcome).
func world() -> Dictionary:
	var schools := []
	for school in run.schools:
		schools.append([school.id, school.rng.seed, int(school.character), school.leader_position, school.leader_heading,
				school.alarm, school.alive_mask(), school.home])
	var pearls := []
	for pearl in run.pearls_out:
		if is_instance_valid(pearl) and pearl.id >= 0 and pearl.absorbing == null:
			pearls.append([pearl.id, pearl.global_position])
	var target := run.target
	return {
		"mode": "nature",
		"schools": schools,
		"pearls": pearls,
		"target": [not target.battered, target.global_transform, target.display_name, run._target_generation],
		"counts": run.rules.save(coop.pid_of),
		"scores": _scores(),
	}


## Every player's scoreboard numbers (NatureScore.save()), by player id.
func _scores() -> Dictionary:
	var scores := {}
	for fish in run.players:
		if is_instance_valid(fish):
			scores[coop.pid_of(fish)] = run.score_of(fish).save()
	return scores


## A guest: the host's world as it was when we joined.
func apply_world(state: Dictionary) -> void:
	for entry: Array in state.schools:
		var school := run.spawn_school(entry[0], entry[1], entry[2], entry[3], entry[4])
		school.home = entry[7]
		school.apply_alive_mask(entry[6])
		school.set_net_state(entry[3], entry[4], entry[5], coop.rtt / 2.0)
	for entry: Array in state.pearls:
		run.drop_pearl(entry[0], entry[1])
	var target: Array = state.target
	run.apply_target_state(target[0], target[1], target[2], target[3])
	run.rules.restore(state.counts, coop.fish_of)
	var scores: Dictionary = state.get("scores", {})
	for pid: Variant in scores:
		var fish := coop.fish_of(pid)
		if fish and fish.puppet:
			run.score_of(fish).restore(scores[pid])


# --- Host side -------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _claim_battery(key: String, pid: int, chain: int) -> void:
	var fish := coop.fish_of(pid)
	if NetSession.is_host() and run and fish:
		run.confirm_battery(key, fish, chain)


@rpc("any_peer", "call_remote", "reliable")
func _claim_pearl(id: int, pid: int) -> void:
	var fish := coop.fish_of(pid)
	if NetSession.is_host() and run and fish:
		run.confirm_pearl(id, fish)


# --- Guest side ------------------------------------------------------------

func _guest_run() -> NatureRun:
	return run if run and is_instance_valid(run) and not run.authority else null


@rpc("authority", "call_remote", "reliable")
func _restart() -> void:
	if _guest_run():
		run.restart()


@rpc("authority", "call_remote", "reliable")
func _school_spawned(id: int, school_seed: int, kind: int, at: Vector3, heading: Vector3) -> void:
	if _guest_run():
		run.spawn_school(id, school_seed, kind, at, heading)


@rpc("authority", "call_remote", "reliable")
func _school_removed(id: int) -> void:
	if _guest_run():
		run.remove_school_by_id(id)


@rpc("authority", "call_remote", "unreliable")
func _schools_snap(time: float, states: Array) -> void:
	coop._host_clock.note_time(time)
	if not _guest_run():
		return
	var age := maxf(coop._host_clock.sender_now() - time, 0.0) + coop.rtt / 2.0
	for state: Array in states:
		var school := run.school_by_id(state[0])
		if school:
			school.set_net_state(state[1], state[2], state[3], age)


@rpc("authority", "call_remote", "unreliable")
func _target_snap(time: float, position: Vector3, rotation: Quaternion, velocity: Vector3, fx: PackedFloat32Array, teleports: int) -> void:
	coop._host_clock.note_time(time)
	_target_net.push(time, position, rotation, velocity, fx, teleports)


@rpc("authority", "call_remote", "reliable")
func _target_state(present: bool, at: Transform3D, target_name: String, generation: int) -> void:
	if _guest_run():
		_target_net.clear()  # it's somewhere new: no gliding from where it was
		run.apply_target_state(present, at, target_name, generation)


@rpc("authority", "call_remote", "reliable")
func _battery_confirmed(key: String, pids: Array, at: Vector3, pearl_id: int) -> void:
	if _guest_run():
		var attackers := pids.map(coop.fish_of).filter(func(fish: Variant) -> bool: return fish != null)
		run.apply_battery_confirmed(key, attackers, at, pearl_id)


@rpc("authority", "call_remote", "reliable")
func _battery_shared(key: String, pid: int) -> void:
	var fish := coop.fish_of(pid)
	if _guest_run() and fish:
		run.apply_battery_shared(key, fish)


@rpc("authority", "call_remote", "reliable")
func _pearl_confirmed(id: int, pid: int) -> void:
	var fish := coop.fish_of(pid)
	if _guest_run() and fish:
		run.apply_pearl_confirmed(id, fish)


# --- Everyone --------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _award(pid: int, event: Dictionary) -> void:
	var fish := coop.fish_of(pid)
	if run and fish:
		event["by"] = fish
		run.relay_award(event)
