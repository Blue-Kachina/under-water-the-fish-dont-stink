class_name CoopSession
extends Node
## Online co-op (NetSession's child "Coop", at the same path on every machine,
## so its RPCs meet): the game's side of a session, the same for every mode. A
## session is in the mode the host was in when it started hosting (a registered
## mode with a net adapter: descriptor "net"; Nature from anywhere else); a guest
## joins that mode. What's the mode's own goes through its adapter (a ModeNet,
## a child of this one: NatureNet, UnnaturalNet, MarcoPoloNet, WhatStinksNet);
## this keeps the session, roster, players' fish and tuning for all of them.
##
## Who runs what (going_coop.md §3):
## - Each machine runs its own players' fish, with no added input lag, and
##   sends their state and looks (FishController.replay_fx()) SEND_RATE times a
##   second (send_own_fish, from the adapter's tick). Everyone else shows them as
##   puppets (FishController.puppet), NetFish-interpolated a little behind.
## - The host runs the world (the mode's authority); its adapter says what goes
##   out and what a guest asks for.
## - Only the host tunes: its fish tuning and every net mode's sections go to
##   every guest on joining and whenever they change, and the guests' tuning
##   panels are locked to it (their own tuning comes back when they leave).
##
## Players are named by a player id, pid = peer id * 100 + the slot's uid on
## its machine (PlayerSlot.uid), so a split-screen machine can bring several.
## The host keeps the roster (pid -> name, character, peer, co-op place) and
## sends it whenever it changes; each machine makes puppets to match.

signal status_changed(text: String)

## Guests must run the same protocol.
const VERSION := 1
## Fish snapshots per second.
const SEND_RATE := 30.0
## Tuning changes are sent this long (s) after the last one, not every slider step.
const TUNING_DELAY := 0.25
## The tuning that's the host's in every mode (the camera stays each player's
## own); tuning_sections() adds every net mode's own sections.
const CORE_TUNING_SECTIONS := ["fish", "gaits"]
## The mode a session is in when the host's mode has no net adapter (its net key).
const DEFAULT_NET_KEY := "nature"
## How often (s) guests time the round trip to the host, and send any change of
## their players (joining, leaving, a new fish).
const PING_INTERVAL := 1.0
const FISH_SCENE := preload("res://scenes/fish.tscn")

## The game (main.gd), which registers itself.
var main: Node
## A registered mode with a net adapter (descriptor "net"), while it is hooked: its game, its
## adapter (ModeNet), and its id. _mode_nets: net_key -> adapter, one per such mode.
var mgame: GameMode
var mnet: ModeNet
var _mode_net_id := ""
var _mode_nets := {}
## pid -> {"pid", "peer", "name", "character", "species" (its key), "index"}.
var roster := {}
## The last status line (for the menu).
var status := "Offline"
## Round trip to the host (s), guests.
var rtt := 0.0

## Remote players: pid -> NetFish (its .fish the puppet).
var _remote := {}
## The host's clock, learnt from its messages (a guest's).
var _host_clock := NetFish.new()
var _send_left := 0.0
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
## Swapping our game for a guest's (its ending isn't us leaving the mode).
var _switching := false
## Outgoing messages held back by the simulated lag: [due (us), callable].
var _outbox: Array = []
var _last_due := 0
var _next_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for d: Dictionary in ModeRegistry.net_descriptors():
		var adapter: ModeNet = (d["net"] as GDScript).new()
		adapter.coop = self
		add_child(adapter)
		_mode_nets[d["net_key"]] = adapter
	var session := get_parent()
	session.session_started.connect(_on_session_started)
	session.session_ended.connect(_on_session_ended)
	session.connection_failed.connect(func(reason: String) -> void: _set_status(reason))
	session.peer_left.connect(_on_peer_left)


## The game registers itself (main.gd's _ready).
func attach_main(game: Node) -> void:
	main = game
	main.mode_started.connect(_on_mode_started)
	main.mode_ended.connect(_on_mode_ended)
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


## The descriptor of the registered mode with a net adapter that this machine is in (the
## default net mode's when it's in none).
func _net_mode() -> Dictionary:
	var d := ModeRegistry.describe(str(main.get("current_mode")))
	return d if d.has("net") else _net_mode_of_key(DEFAULT_NET_KEY)


## The tuning sections that are the host's: the core ones and every net mode's settings
## (its descriptor's "settings_key", or its lower-cased id, and its "extra_settings").
static func tuning_sections() -> Array:
	var out := CORE_TUNING_SECTIONS.duplicate()
	for d: Dictionary in ModeRegistry.net_descriptors():
		if d.has("settings"):
			out.append(d.get("settings_key", String(d["id"]).to_lower()))
		for extra: Array in d.get("extra_settings", []):
			out.append(extra[0])
	return out


## The adapter of net key `key` (what a guest's welcome names), null when none.
func net_of(key: String) -> ModeNet:
	return _mode_nets.get(key)


## The descriptor of the registered mode whose wire key is `key` ({} when none).
func _net_mode_of_key(key: String) -> Dictionary:
	for d: Dictionary in ModeRegistry.net_descriptors():
		if d["net_key"] == key:
			return d
	return {}


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
		var net_mode := _net_mode()
		main.host_mode(net_mode["id"])  # (one already running stays: its guests join it)
		for entry in _local_players():
			_add_to_roster(entry, 1)
		_hook_mode(main.active_mode(), net_mode)
	else:
		_welcomed = false
		_set_status("Connected: joining...")
		_sent_players = _local_players()
		_send_to(1, "_hello", [VERSION, _sent_players], true)


func _on_session_ended(reason: String) -> void:
	if main == null:
		_set_status(reason)
		return
	var was_mode_guest: bool = _welcomed and mgame and is_instance_valid(mgame) and not mgame.get("authority")
	var guest_of := _mode_net_id
	_unhook_mode()
	for pid: int in _remote.keys():
		_drop_remote(pid)
	roster.clear()
	_outbox.clear()
	_welcomed = false
	main._panel.set_sections_locked(tuning_sections(), false)
	if not _own_tuning.is_empty():
		main._panel.restore_tuning(_own_tuning)
		_own_tuning = {}
	_set_status(reason)
	if was_mode_guest:
		_switching = true
		main.solo_mode(guest_of)  # back to the mode on our own, the world ours again
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


func _on_mode_started(mode: GameMode) -> void:
	if not is_active() or not (_welcomed or _is_host()):
		return
	# (its node is named by its id; a mode without "net", e.g. the Test Tank, is never in a session)
	var d := ModeRegistry.describe(String(mode.name))
	if d.has("net"):
		_hook_mode(mode, d)


func _on_mode_ended(id: String) -> void:
	var d := ModeRegistry.describe(id)
	if not d.has("net"):
		return
	_unhook_mode()
	if is_active() and not _switching:
		NetSession.leave(("Left %s, so the session ended" % d["title"]) if _is_host() else "Left the session")


## `fish` jumped (a mode's fish_teleported): ours go out with a new count, so puppets snap.
func note_teleport(fish: FishController) -> void:
	if not fish.puppet:
		_teleports[fish] = _teleports.get(fish, 0) + 1


# --- Players ---------------------------------------------------------------

## Our machine's players, as sent: [{"pid", "name", "character", "species"}]
## ("species": the species' key, FishCharacter.SPECIES).
func _local_players() -> Array:
	if main == null:
		return []
	var players := []
	for slot: PlayerSlot in main._local.slots:
		players.append(player_entry(_pid(NetSession.peer_id(), slot.uid), slot.fish))
	return players


## How `fish` (player `pid`) is sent in the roster.
static func player_entry(pid: int, fish: FishController) -> Dictionary:
	var character := fish.character
	var species := fish.species
	# A Marco Polo whale is sent as the player's own fish: the role swap is local.
	var base := ModeData.swapped_look(fish)
	if not base.is_empty():
		character = base[0] as FishCharacter.FishClass
		species = int(base[1])
	return {"pid": pid, "name": fish.display_name, "character": int(character),
			"species": FishCharacter.species_key(character, species)}


## The species a roster entry's fish wears (its first if the entry has none: an
## older build's).
static func entry_species(entry: Dictionary) -> int:
	var fish_class: FishCharacter.FishClass = int(entry.get("character", 0)) as FishCharacter.FishClass
	return FishCharacter.species_from_key(fish_class, str(entry.get("species", "")))


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
			"species": str(entry.get("species", "")), "index": index}


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
			net.fish.set_look(entry.character, entry_species(entry))
			net.fish.display_name = entry.name
			var parent := mnet.puppet_parent() if _hooked() else null
			(parent if parent else main).add_child(net.fish)
			net.fish.make_puppet()
			net.fish.visible = false  # until its first snapshot
			if _hooked():
				mnet.puppet_added(net.fish)
		var species := entry_species(entry)
		# A puppet a match has grown into a whale keeps that body (ModeData: swapped).
		var swapped: bool = ModeData.swapped_owner(net.fish) != ""
		if not swapped and (net.fish.character != entry.character or net.fish.species != species):
			net.fish.set_look(entry.character, species)
		net.fish.display_name = entry.name
		net.fish.set_meta("coop_index", entry.index)


func _drop_remote(pid: int) -> void:
	var net: NetFish = _remote.get(pid)
	_remote.erase(pid)
	if net and is_instance_valid(net.fish):
		if _hooked():
			mnet.puppet_removed(net.fish)
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
	if is_active() and _hooked():
		mnet.tick(delta)


## Puppets follow their players (a little behind), each shown as `shown` (Callable(fish) -> bool) says.
func follow_puppets(shown: Callable) -> void:
	for net: NetFish in _remote.values():
		if net.has_state() and is_instance_valid(net.fish):
			net.fish.visible = shown.call(net.fish)
			net.apply()


## Our players' fish among `fish_list` go out, SEND_RATE times a second (call it every physics
## frame). True on the frames they went.
func send_own_fish(delta: float, fish_list: Array) -> bool:
	_send_left -= delta
	if _send_left > 0.0:
		return false
	_send_left += 1.0 / SEND_RATE
	var now := _now()
	for fish: FishController in fish_list:
		var pid := pid_of(fish)
		if pid >= 0:
			_send_all("_fish_state", [pid, now, fish.global_position, fish.global_basis.get_rotation_quaternion(),
					fish.linear_velocity, fish.replay_fx(), _teleports.get(fish, 0)], false)
	return true


## Whether a mode's game is wired up to the session now.
func _hooked() -> bool:
	return mnet != null and mgame != null and is_instance_valid(mgame)


## Wires a registered mode's game (descriptor `d`) up to the session through its adapter, puppets joining it.
func _hook_mode(game: GameMode, d: Dictionary) -> void:
	if mgame == game or game == null:
		return
	_unhook_mode()
	mgame = game
	_mode_net_id = str(d["id"])
	mnet = _mode_nets.get(d["net_key"])
	mnet.hook(game)
	var parent := mnet.puppet_parent()
	for net: NetFish in _remote.values():
		if is_instance_valid(net.fish):
			if parent != null and net.fish.get_parent() != parent:
				net.fish.reparent(parent)
			mnet.puppet_added(net.fish)
	_sync_puppets()


func _unhook_mode() -> void:
	if mnet != null:
		mnet.unhook()
		if mgame != null and is_instance_valid(mgame):
			for net: NetFish in _remote.values():
				if is_instance_valid(net.fish):
					mnet.puppet_removed(net.fish)
	mgame = null
	mnet = null
	_mode_net_id = ""


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


# --- Host side -------------------------------------------------------------

func _host_tuning() -> Dictionary:
	var snapshot: Dictionary = main._panel.tuning_snapshot()
	var sections := {}
	for section: String in tuning_sections():
		if snapshot.has(section):
			sections[section] = snapshot[section]
	return sections


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
	var world: Dictionary = mnet.world() if _hooked() else {}
	_send_to(peer, "_welcome", [roster, _host_tuning(), world], true)
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
	var joined_mode := _net_mode_of_key(str(world.get("mode", DEFAULT_NET_KEY)))
	if joined_mode.is_empty():
		NetSession.leave("The host is in a mode this game doesn't have")
		return
	_apply_tuning(tuning)  # before the game: it reads the host's settings as it starts
	_switching = true
	main.join_mode(joined_mode["id"], world)  # our own players in the host's game
	_switching = false
	_apply_tuning(tuning)  # and again, over the mode's preset if joining put it on
	_hook_mode(main.active_mode(), joined_mode)
	mnet.apply_world(world)
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
	main._panel.set_sections_locked(tuning_sections(), true, "Tuned by the host")


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
