class_name CoopSession
extends Node
## Online co-op in Nature and Unnatural (NetSession's child "Coop", at the same
## path on every machine, so its RPCs meet): the game's side of a session. A
## session is in the mode the host was in when it started hosting (Unnatural if
## it was in Unnatural, else Nature); a guest joins that mode. What's
## Unnatural's own goes through the child UnnaturalNet; this keeps the session,
## roster, players' fish, tuning and restarts for both.
##
## Who runs what (going_coop.md §3):
## - Each machine runs its own players' fish, with no added input lag, and
##   sends their state and looks (FishController.replay_fx()) SEND_RATE times a
##   second. Everyone else shows them as puppets (FishController.puppet),
##   NetFish-interpolated a little behind.
## - The host runs the world (NatureRun.authority): the schools' leaders and
##   alarms (sent SCHOOL_RATE times a second; every machine swims the fish
##   around them itself, School.follower), spawns and removals (with their
##   seeds), the lone fish, pearl drops, the shared counts, restarts.
## - A battery shows first where the attacker is, and is claimed to the host,
##   which confirms it to everyone (two claims on one fish within
##   NatureRun.SHARE_WINDOW share it). Pearls the same.
## - Each player's points, multis and sprees are their own machine's; their
##   awards are sent to the others' feeds.
## - Only the host tunes: its fish and Nature tuning go to every guest on
##   joining and whenever it changes, and the guests' tuning panels are locked
##   to it (their own tuning comes back when they leave).
##
## Players are named by a player id, pid = peer id * 100 + the slot's uid on
## its machine (PlayerSlot.uid), so a split-screen machine can bring several.
## The host keeps the roster (pid -> name, character, peer, co-op place) and
## sends it whenever it changes; each machine makes puppets to match.

signal status_changed(text: String)

## Guests must run the same protocol.
const VERSION := 1
## Fish snapshots per second, and school leaders.
const SEND_RATE := 30.0
const SCHOOL_RATE := 10.0
## Tuning changes are sent this long (s) after the last one, not every slider step.
const TUNING_DELAY := 0.25
## The tuning that's the host's (the camera stays each player's own).
const TUNING_SECTIONS := ["fish", "nature", "unnatural", "powerups"]
## How often (s) guests time the round trip to the host, and send any change of
## their players (joining, leaving, a new fish).
const PING_INTERVAL := 1.0
const FISH_SCENE := preload("res://scenes/fish.tscn")

## The game (main.gd), which registers itself.
var main: Node
var run: NatureRun
## The Unnatural run in the session (instead of `run`), and its messages.
var urun: UnnaturalRun
var unnatural_net := UnnaturalNet.new()
## pid -> {"pid", "peer", "name", "character", "skin" (its key), "index"}.
var roster := {}
## The last status line (for the menu).
var status := "Offline"
## Round trip to the host (s), guests.
var rtt := 0.0

## Remote players: pid -> NetFish (its .fish the puppet).
var _remote := {}
## The host's lone fish, on a guest.
var _target_net := NetFish.new()
## The host's clock, learnt from its messages (a guest's).
var _host_clock := NetFish.new()
var _send_left := 0.0
var _school_left := 0.0
var _ping_left := 0.0
## Our fish's teleports so far (fish -> count): sent, so puppets snap.
var _teleports := {}
var _tuning_dirty := false
var _tuning_left := 0.0
## A guest's own tuning from before the host's (put back on leaving).
var _own_tuning := {}
## Our players as last sent (a guest's), to notice changes.
var _sent_players := []
var _welcomed := false
## Swapping our run for a guest's run (its ending isn't us leaving Nature).
var _switching := false
## Outgoing messages held back by the simulated lag: [due (us), callable].
var _outbox: Array = []
var _last_due := 0
var _next_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	unnatural_net.coop = self
	add_child(unnatural_net)
	var session := get_parent()
	session.session_started.connect(_on_session_started)
	session.session_ended.connect(_on_session_ended)
	session.connection_failed.connect(func(reason: String) -> void: _set_status(reason))
	session.peer_left.connect(_on_peer_left)


## The game registers itself (main.gd's _ready).
func attach_main(game: Node) -> void:
	main = game
	main.nature_started.connect(_on_nature_started)
	main.nature_ended.connect(_on_nature_ended)
	main.unnatural_started.connect(_on_unnatural_started)
	main.unnatural_ended.connect(_on_unnatural_ended)
	main._local.players_changed.connect(func(_count: int) -> void: _players_changed())
	main._panel.tuning_changed.connect(func() -> void:
		if _is_host():
			_tuning_dirty = true
			_tuning_left = TUNING_DELAY)
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			NetSession.host_enet.call_deferred(NetSession.port)
		elif arg.begins_with("--join="):
			NetSession.join_enet.call_deferred(arg.get_slice("=", 1), NetSession.port)


func is_active() -> bool:
	return NetSession.is_online()


func _is_host() -> bool:
	return NetSession.is_host()


## The session's run here: Nature's or Unnatural's (null: none).
func _game_run() -> Node:
	if urun and is_instance_valid(urun):
		return urun
	if run and is_instance_valid(run):
		return run
	return null


## Whether this machine is in Unnatural (the mode a session it hosts is in).
func _in_unnatural() -> bool:
	return main != null and main.get("current_mode") == "Unnatural"


func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)


# --- Session ---------------------------------------------------------------

func _on_session_started() -> void:
	if main == null:
		return  # no game here (a tool or test without one)
	_remote.clear()
	_teleports.clear()
	roster.clear()
	_next_index = 0
	if _is_host():
		_welcomed = true
		_set_status("Hosting: waiting for friends" if NetSession.backend == NetSession.Backend.STEAM
				else "Hosting on port %d: waiting for friends" % NetSession.port)
		var unnatural := _in_unnatural()
		if unnatural:
			main.host_unnatural_run()
		else:
			main.host_nature_run()
		for entry in _local_players():
			_add_to_roster(entry, 1)
		if unnatural:
			_hook_unnatural(main.unnatural_run)
		else:
			_hook(main.nature_run)
	else:
		_welcomed = false
		_set_status("Connected: joining...")
		_sent_players = _local_players()
		_send_to(1, "_hello", [VERSION, _sent_players], true)


func _on_session_ended(reason: String) -> void:
	if main == null:
		_set_status(reason)
		return
	var was_guest := _welcomed and run and not run.authority
	var was_unnatural_guest := _welcomed and urun and is_instance_valid(urun) and not urun.authority
	_unhook()
	_unhook_unnatural()
	for pid: int in _remote.keys():
		_drop_remote(pid)
	roster.clear()
	_outbox.clear()
	_welcomed = false
	main._panel.set_sections_locked(TUNING_SECTIONS, false)
	if not _own_tuning.is_empty():
		main._panel.restore_tuning(_own_tuning)
		_own_tuning = {}
	_set_status(reason)
	if was_guest:
		_switching = true
		main.solo_nature_run()  # back to Nature on our own, the world ours again
		_switching = false
	elif was_unnatural_guest:
		_switching = true
		main.solo_unnatural_run()
		_switching = false


func _on_peer_left(peer: int) -> void:
	if not _is_host():
		return
	for pid: int in roster.keys():
		if roster[pid].peer == peer:
			roster.erase(pid)
	_sync_puppets()
	_send_all("_roster", [roster], true)
	_set_status("A friend left: %d playing" % roster.size())


func _on_nature_started(nature_run: NatureRun) -> void:
	if is_active() and (_welcomed or _is_host()):
		_hook(nature_run)


func _on_nature_ended() -> void:
	_unhook()
	if is_active() and not _switching:
		NetSession.leave("Left Nature, so the session ended" if _is_host() else "Left the session")


func _on_unnatural_started(unnatural_run: UnnaturalRun) -> void:
	if is_active() and (_welcomed or _is_host()) and not unnatural_run.test_tank:
		_hook_unnatural(unnatural_run)


func _on_unnatural_ended() -> void:
	_unhook_unnatural()
	if is_active() and not _switching:
		NetSession.leave("Left Unnatural, so the session ended" if _is_host() else "Left the session")


## Wires an Unnatural run up to the session (UnnaturalNet), puppets joining it.
func _hook_unnatural(unnatural_run: UnnaturalRun) -> void:
	if urun == unnatural_run or unnatural_run == null:
		return
	_unhook_unnatural()
	urun = unnatural_run
	unnatural_net.hook(urun)
	urun.restarted.connect(_on_restarted)
	urun.fish_teleported.connect(_on_teleported)
	for net: NetFish in _remote.values():
		if is_instance_valid(net.fish) and net.fish.get_parent() != urun:
			net.fish.reparent(urun)
		urun.add_player(net.fish)
	_sync_puppets()


func _unhook_unnatural() -> void:
	unnatural_net.unhook()
	if urun == null or not is_instance_valid(urun):
		urun = null
		return
	if urun.restarted.is_connected(_on_restarted):
		urun.restarted.disconnect(_on_restarted)
	if urun.fish_teleported.is_connected(_on_teleported):
		urun.fish_teleported.disconnect(_on_teleported)
	for net: NetFish in _remote.values():
		if is_instance_valid(net.fish):
			urun.remove_player(net.fish)
	urun = null


func _on_teleported(fish: FishController) -> void:
	if not fish.puppet:
		_teleports[fish] = _teleports.get(fish, 0) + 1


## Wires a run up to the session: what it does goes out, puppets join it.
func _hook(nature_run: NatureRun) -> void:
	if run == nature_run or nature_run == null:
		return
	_unhook()
	run = nature_run
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
	run.fish_teleported.connect(func(fish: FishController) -> void:
		if not fish.puppet:
			_teleports[fish] = _teleports.get(fish, 0) + 1)
	for net: NetFish in _remote.values():
		if is_instance_valid(net.fish) and net.fish.get_parent() != run:
			net.fish.reparent(run)
		run.add_player(net.fish)
	_sync_puppets()


func _unhook() -> void:
	if run == null or not is_instance_valid(run):
		run = null
		return
	for sig: StringName in [&"school_spawned", &"school_removed", &"battery_claimed", &"battery_confirmed",
			&"battery_shared", &"pearl_claimed", &"pearl_confirmed", &"target_state", &"restarted", &"awarded", &"fish_teleported"]:
		for connection in run.get_signal_connection_list(sig):
			if (connection.callable as Callable).get_object() == self:
				run.disconnect(sig, connection.callable)
	for net: NetFish in _remote.values():
		if is_instance_valid(net.fish):
			run.remove_player(net.fish)
	run = null


# --- Players ---------------------------------------------------------------

## Our machine's players, as sent: [{"pid", "name", "character", "skin"}]
## ("skin": the skin's key, FishCharacter.SKINS).
func _local_players() -> Array:
	if main == null:
		return []
	var players := []
	for slot: PlayerSlot in main._local.slots:
		players.append(player_entry(_pid(NetSession.peer_id(), slot.uid), slot.fish))
	return players


## How `fish` (player `pid`) is sent in the roster.
static func player_entry(pid: int, fish: FishController) -> Dictionary:
	return {"pid": pid, "name": fish.display_name, "character": int(fish.character),
			"skin": FishCharacter.skin_key(fish.character, fish.skin)}


## The skin a roster entry's fish wears (its first if the entry has none: an
## older build's).
static func entry_skin(entry: Dictionary) -> int:
	var family: FishCharacter.Family = int(entry.get("character", 0)) as FishCharacter.Family
	return FishCharacter.skin_from_key(family, str(entry.get("skin", "")))


static func _pid(peer: int, uid: int) -> int:
	return peer * 100 + uid % 100


## The fish of player `pid` here (ours, or a puppet), or null.
func fish_of(pid: int) -> FishController:
	if pid / 100 == NetSession.peer_id():
		for slot: PlayerSlot in main._local.slots:
			if _pid(NetSession.peer_id(), slot.uid) == pid:
				return slot.fish
		return null
	var net: NetFish = _remote.get(pid)
	return net.fish if net and is_instance_valid(net.fish) else null


## The pid of a fish here (ours or a puppet), or -1.
func pid_of(fish: Node) -> int:
	for slot: PlayerSlot in main._local.slots:
		if slot.fish == fish:
			return _pid(NetSession.peer_id(), slot.uid)
	for pid: int in _remote:
		if _remote[pid].fish == fish:
			return pid
	return -1


func _add_to_roster(entry: Dictionary, peer: int) -> void:
	var pid: int = entry.pid
	var index: int = roster[pid].index if roster.has(pid) else _next_index
	if not roster.has(pid):
		_next_index += 1
	roster[pid] = {"pid": pid, "peer": peer, "name": entry.name, "character": entry.character,
			"skin": str(entry.get("skin", "")), "index": index}


## Our players changed (one joined or left the split screen, or picked another fish).
func _players_changed() -> void:
	if main == null:
		return
	if not is_active():
		return
	var players := _local_players()
	if players == _sent_players and not _is_host():
		return
	_sent_players = players
	if _is_host():
		for pid: int in roster.keys():
			if roster[pid].peer == 1 and not players.any(func(p: Dictionary) -> bool: return p.pid == pid):
				roster.erase(pid)
		for entry in players:
			_add_to_roster(entry, 1)
		_sync_puppets()
		_send_all("_roster", [roster], true)
	elif _welcomed:
		_send_to(1, "_players", [players], true)


## Puppets to match the roster: one for each player on another machine.
func _sync_puppets() -> void:
	var me := NetSession.peer_id()
	for pid: int in _remote.keys():
		if not roster.has(pid):
			_drop_remote(pid)
	for pid: int in roster:
		var entry: Dictionary = roster[pid]
		if entry.peer == me:
			var own := fish_of(pid)
			if own:
				own.set_meta("coop_index", entry.index)
			continue
		var net: NetFish = _remote.get(pid)
		if net == null:
			net = NetFish.new()
			net.fish = FISH_SCENE.instantiate()
			net.fish.name = "Remote%d" % pid
			_remote[pid] = net
			net.fish.set_look(entry.character, entry_skin(entry))
			net.fish.display_name = entry.name
			var game := _game_run()
			(game if game else main).add_child(net.fish)
			net.fish.make_puppet()
			net.fish.visible = false  # until its first snapshot
			if game:
				game.add_player(net.fish)
		var skin := entry_skin(entry)
		if net.fish.character != entry.character or net.fish.skin != skin:
			net.fish.set_look(entry.character, skin)
		net.fish.display_name = entry.name
		net.fish.set_meta("coop_index", entry.index)


func _drop_remote(pid: int) -> void:
	var net: NetFish = _remote.get(pid)
	_remote.erase(pid)
	if net and is_instance_valid(net.fish):
		var game := _game_run()
		if game:
			game.remove_player(net.fish)
		net.fish.queue_free()


# --- Each tick -------------------------------------------------------------

func _process(delta: float) -> void:
	_flush_outbox()
	if not is_active():
		return
	if _tuning_dirty and _is_host():
		_tuning_left -= delta
		if _tuning_left <= 0.0:
			_tuning_dirty = false
			_send_all("_tuning", [_host_tuning()], true)
	if not _is_host() and _welcomed:
		_ping_left -= delta
		if _ping_left <= 0.0:
			_ping_left = PING_INTERVAL
			_send_to(1, "_ping", [_now()], false)
			_players_changed()


func _physics_process(delta: float) -> void:
	if is_active() and urun and is_instance_valid(urun):
		_unnatural_tick(delta)
		return
	if not is_active() or run == null or not is_instance_valid(run):
		return
	for net: NetFish in _remote.values():
		if net.has_state() and is_instance_valid(net.fish):
			net.fish.visible = not net.fish.battered
			net.apply()
	if not run.authority and _target_net.has_state() and not run.target.battered:
		_target_net.fish = run.target
		_target_net.apply()
	_send_left -= delta
	if _send_left <= 0.0:
		_send_left += 1.0 / SEND_RATE
		var now := _now()
		for fish in run.local_players():
			var pid := pid_of(fish)
			if pid >= 0:
				_send_all("_fish_state", [pid, now, fish.global_position, fish.global_basis.get_rotation_quaternion(),
						fish.linear_velocity, fish.replay_fx(), _teleports.get(fish, 0)], false)
		if run.authority and not run.target.battered:
			var target := run.target
			_send_all("_target_snap", [now, target.global_position, target.global_basis.get_rotation_quaternion(),
					target.linear_velocity, target.replay_fx(), _teleports.get(target, 0)], false)
	if run.authority:
		_school_left -= delta
		if _school_left <= 0.0:
			_school_left += 1.0 / SCHOOL_RATE
			var states := []
			for school in run.schools:
				var state := school.net_state()
				states.append([school.id, state[0], state[1], state[2]])
			_send_all("_schools_snap", [_now(), states], false)


## Unnatural: the puppets follow their players, ours go out, then UnnaturalNet's.
func _unnatural_tick(delta: float) -> void:
	for net: NetFish in _remote.values():
		if net.has_state() and is_instance_valid(net.fish):
			net.fish.visible = true
			net.apply()
	_send_left -= delta
	if _send_left <= 0.0:
		_send_left += 1.0 / SEND_RATE
		var now := _now()
		for fish in urun.local_players():
			var pid := pid_of(fish)
			if pid >= 0:
				_send_all("_fish_state", [pid, now, fish.global_position, fish.global_basis.get_rotation_quaternion(),
						fish.linear_velocity, fish.replay_fx(), _teleports.get(fish, 0)], false)
	unnatural_net.tick(delta)


static func _now() -> float:
	return Time.get_ticks_usec() / 1e6


# --- Sending (with the simulated lag) --------------------------------------

func _send_all(method: StringName, args: Array, reliable: bool) -> void:
	_send(0, method, args, reliable)


func _send_to(peer: int, method: StringName, args: Array, reliable: bool) -> void:
	_send(peer, method, args, reliable)


func _send(peer: int, method: StringName, args: Array, reliable: bool) -> void:
	send_from(self, peer, method, args, reliable)


## Sends `node`'s RPC `method` (to everyone with `peer` 0), in the one queue
## (so the simulated lag keeps every reliable message in order, whichever node).
func send_from(node: Node, peer: int, method: StringName, args: Array, reliable: bool) -> void:
	if not is_active():
		return
	var call := (func() -> void:
		if not is_active() or not is_instance_valid(node):
			return
		if peer == 0:
			node.callv("rpc", [method] + args)
		else:
			node.callv("rpc_id", [peer, method] + args))
	var lag := NetSession.lag_ms
	var jitter := NetSession.jitter_ms
	if lag <= 0.0 and jitter <= 0.0 and NetSession.loss <= 0.0:
		call.call()
		return
	if not reliable and randf() < NetSession.loss:
		return  # lost
	var due := Time.get_ticks_usec() + int((lag + randf() * jitter) * 1000.0)
	if reliable:
		due = maxi(due, _last_due)  # reliable messages keep their order
		_last_due = due
	_outbox.append([due, call])


func _flush_outbox() -> void:
	if _outbox.is_empty():
		return
	var now := Time.get_ticks_usec()
	var keep: Array = []
	for item: Array in _outbox:
		if item[0] <= now:
			(item[1] as Callable).call()
		else:
			keep.append(item)
	_outbox = keep


# --- Run -> session --------------------------------------------------------

func _on_school_spawned(school: School, at: Vector3, heading: Vector3) -> void:
	if run.authority:
		_send_all("_school_spawned", [school.id, school.rng.seed, int(school.character), at, heading], true)


func _on_school_removed(id: int) -> void:
	if run.authority:
		_send_all("_school_removed", [id], true)


func _on_battery_claimed(key: String, attacker: FishController, chain: int) -> void:
	_send_to(1, "_claim_battery", [key, pid_of(attacker), chain], true)


func _on_battery_confirmed(key: String, attackers: Array, at: Vector3, pearl_id: int) -> void:
	if run.authority:
		_send_all("_battery_confirmed", [key, attackers.map(pid_of), at, pearl_id], true)


func _on_battery_shared(key: String, attacker: FishController) -> void:
	if run.authority:
		_send_all("_battery_shared", [key, pid_of(attacker)], true)


func _on_pearl_claimed(id: int, by: FishController) -> void:
	_send_to(1, "_claim_pearl", [id, pid_of(by)], true)


func _on_pearl_confirmed(id: int, by: FishController) -> void:
	if run.authority:
		_send_all("_pearl_confirmed", [id, pid_of(by)], true)


func _on_target_state(present: bool, at: Transform3D, target_name: String, generation: int) -> void:
	if run.authority:
		_teleports[run.target] = _teleports.get(run.target, 0) + 1
		_send_all("_target_state", [present, at, target_name, generation], true)


func _on_restarted() -> void:
	var game := _game_run()
	if game and game.get("authority"):
		_send_all("_restart", [], true)


func _on_awarded(event: Dictionary) -> void:
	var by: Variant = event.get("by")
	if not is_instance_valid(by) or (by as FishController).puppet:
		return
	var sent := event.duplicate()
	sent.erase("by")
	sent.merge(run.score_of(by).stats())  # the scoreboard's numbers ride along
	_send_all("_award", [pid_of(by), sent], true)


# --- Host side -------------------------------------------------------------

func _host_tuning() -> Dictionary:
	var snapshot: Dictionary = main._panel.tuning_snapshot()
	var sections := {}
	for section: String in TUNING_SECTIONS:
		if snapshot.has(section):
			sections[section] = snapshot[section]
	return sections


## The world as it is now, for a guest joining.
func _world() -> Dictionary:
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
		"schools": schools,
		"pearls": pearls,
		"target": [not target.battered, target.global_transform, target.display_name, run._target_generation],
		"counts": run.rules.save(pid_of),
		"scores": _scores(),
	}


## Every player's scoreboard numbers (NatureScore.save()), by player id.
func _scores() -> Dictionary:
	var scores := {}
	for fish in run.players:
		if is_instance_valid(fish):
			scores[pid_of(fish)] = run.score_of(fish).save()
	return scores


@rpc("any_peer", "call_remote", "reliable")
func _hello(version: int, players: Array) -> void:
	if not _is_host():
		return
	var peer := multiplayer.get_remote_sender_id()
	if version != VERSION:
		_send_to(peer, "_refused", ["The host's game is a different version"], true)
		return
	if roster.size() + players.size() > LocalCoop.MAX_PLAYERS:
		_send_to(peer, "_refused", ["The session's full (%d players)" % LocalCoop.MAX_PLAYERS], true)
		return
	for entry: Dictionary in players:
		_add_to_roster(entry, peer)
	_sync_puppets()
	_send_to(peer, "_welcome", [roster, _host_tuning(), unnatural_net.world() if urun and is_instance_valid(urun) else _world()], true)
	_send_all("_roster", [roster], true)
	_set_status("Hosting: %d playing" % roster.size())


@rpc("any_peer", "call_remote", "reliable")
func _players(players: Array) -> void:
	if not _is_host():
		return
	var peer := multiplayer.get_remote_sender_id()
	for pid: int in roster.keys():
		if roster[pid].peer == peer and not players.any(func(p: Dictionary) -> bool: return p.pid == pid):
			roster.erase(pid)
	for entry: Dictionary in players:
		if entry.pid / 100 == peer:
			_add_to_roster(entry, peer)
	_sync_puppets()
	_send_all("_roster", [roster], true)


@rpc("any_peer", "call_remote", "reliable")
func _claim_battery(key: String, pid: int, chain: int) -> void:
	var fish := fish_of(pid)
	if _is_host() and run and fish:
		run.confirm_battery(key, fish, chain)


@rpc("any_peer", "call_remote", "reliable")
func _claim_pearl(id: int, pid: int) -> void:
	var fish := fish_of(pid)
	if _is_host() and run and fish:
		run.confirm_pearl(id, fish)


@rpc("any_peer", "call_remote", "unreliable")
func _ping(time: float) -> void:
	_send_to(multiplayer.get_remote_sender_id(), "_pong", [time], false)


# --- Guest side ------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _refused(reason: String) -> void:
	NetSession.leave(reason)


@rpc("authority", "call_remote", "reliable")
func _welcome(host_roster: Dictionary, tuning: Dictionary, world: Dictionary) -> void:
	_welcomed = true
	roster = host_roster
	_own_tuning = main._panel.tuning_snapshot()
	if world.get("mode", "nature") == "unnatural":
		_apply_tuning(tuning)  # before the run: it reads the host's settings as it starts
		_switching = true
		main.guest_unnatural_run()  # a run of our own players, the world the host's
		_switching = false
		_hook_unnatural(main.unnatural_run)
		unnatural_net.apply_world(world)
		_set_status("Playing with %d others" % (roster.size() - _local_players().size()))
		return
	_switching = true
	main.guest_nature_run()  # a run of our own players, the world the host's
	_switching = false
	_apply_tuning(tuning)
	_hook(main.nature_run)
	for entry: Array in world.schools:
		var school := run.spawn_school(entry[0], entry[1], entry[2], entry[3], entry[4])
		school.home = entry[7]
		school.apply_alive_mask(entry[6])
		school.set_net_state(entry[3], entry[4], entry[5], rtt / 2.0)
	for entry: Array in world.pearls:
		run.drop_pearl(entry[0], entry[1])
	var target: Array = world.target
	run.apply_target_state(target[0], target[1], target[2], target[3])
	run.rules.restore(world.counts, fish_of)
	var scores: Dictionary = world.get("scores", {})
	for pid: Variant in scores:
		var fish := fish_of(pid)
		if fish and fish.puppet:
			run.score_of(fish).restore(scores[pid])
	_set_status("Playing with %d others" % (roster.size() - _local_players().size()))


@rpc("authority", "call_remote", "reliable")
func _roster(host_roster: Dictionary) -> void:
	roster = host_roster
	_sync_puppets()
	_set_status("Playing with %d others" % (roster.size() - _local_players().size()))


@rpc("authority", "call_remote", "reliable")
func _tuning(sections: Dictionary) -> void:
	_apply_tuning(sections)


func _apply_tuning(sections: Dictionary) -> void:
	main._panel.restore_tuning(sections)
	main._panel.set_sections_locked(TUNING_SECTIONS, true, "Tuned by the host")


@rpc("authority", "call_remote", "reliable")
func _restart() -> void:
	if run and not run.authority:
		run.start()
	elif urun and is_instance_valid(urun) and not urun.authority:
		urun.start()


@rpc("authority", "call_remote", "reliable")
func _school_spawned(id: int, school_seed: int, kind: int, at: Vector3, heading: Vector3) -> void:
	if run and not run.authority:
		run.spawn_school(id, school_seed, kind, at, heading)


@rpc("authority", "call_remote", "reliable")
func _school_removed(id: int) -> void:
	if run and not run.authority:
		run.remove_school_by_id(id)


@rpc("authority", "call_remote", "unreliable")
func _schools_snap(time: float, states: Array) -> void:
	_host_clock.note_time(time)
	if run == null or run.authority:
		return
	var age := maxf(_host_clock.sender_now() - time, 0.0) + rtt / 2.0
	for state: Array in states:
		var school := run.school_by_id(state[0])
		if school:
			school.set_net_state(state[1], state[2], state[3], age)


@rpc("authority", "call_remote", "unreliable")
func _target_snap(time: float, position: Vector3, rotation: Quaternion, velocity: Vector3, fx: PackedFloat32Array, teleports: int) -> void:
	_host_clock.note_time(time)
	_target_net.push(time, position, rotation, velocity, fx, teleports)


@rpc("authority", "call_remote", "reliable")
func _target_state(present: bool, at: Transform3D, target_name: String, generation: int) -> void:
	if run and not run.authority:
		_target_net.clear()  # it's somewhere new: no gliding from where it was
		run.apply_target_state(present, at, target_name, generation)


@rpc("authority", "call_remote", "reliable")
func _battery_confirmed(key: String, pids: Array, at: Vector3, pearl_id: int) -> void:
	if run and not run.authority:
		var attackers := pids.map(fish_of).filter(func(fish: Variant) -> bool: return fish != null)
		run.apply_battery_confirmed(key, attackers, at, pearl_id)


@rpc("authority", "call_remote", "reliable")
func _battery_shared(key: String, pid: int) -> void:
	var fish := fish_of(pid)
	if run and not run.authority and fish:
		run.apply_battery_shared(key, fish)


@rpc("authority", "call_remote", "reliable")
func _pearl_confirmed(id: int, pid: int) -> void:
	var fish := fish_of(pid)
	if run and not run.authority and fish:
		run.apply_pearl_confirmed(id, fish)


@rpc("authority", "call_remote", "unreliable")
func _pong(time: float) -> void:
	var sample := _now() - time
	rtt = sample if rtt <= 0.0 else lerpf(rtt, sample, 0.2)


# --- Everyone --------------------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable")
func _fish_state(pid: int, time: float, position: Vector3, rotation: Quaternion, velocity: Vector3, fx: PackedFloat32Array, teleports: int) -> void:
	var net: NetFish = _remote.get(pid)
	if net:
		net.push(time, position, rotation, velocity, fx, teleports)


@rpc("any_peer", "call_remote", "reliable")
func _award(pid: int, event: Dictionary) -> void:
	var fish := fish_of(pid)
	if run and fish:
		event["by"] = fish
		run.relay_award(event)
