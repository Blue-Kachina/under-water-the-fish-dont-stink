extends Node
## The online session (autoloaded as "NetSession"): the only part of the game
## that knows how machines reach each other. Gameplay (CoopSession, its child
## "Coop") only uses Godot's multiplayer API (RPCs, peer ids), whichever
## backend carries it:
## - ENet: straight to an address and port (LAN, or a port-forwarded host);
##   what development and the headless probes use.
## - Steam (GodotSteam, if the addon is installed): a friends-only lobby,
##   invites and joining from the friends list or overlay, carried over Steam's
##   relays (no addresses, no port forwarding).
## Another platform (Epic Online Services) would be one more backend here.
##
## Bad networks can be simulated for testing (lag_ms, jitter_ms, loss): CoopSession
## delays and drops its own messages by these on the way out.
##
## Command line (after `--`): --host, --join=ADDRESS, --port=N, --lag=MS,
## --jitter=MS, --loss=FRACTION, --name=NAME.

signal session_started
## Our session ended (left, the host went, or the connection was lost): why.
signal session_ended(reason: String)
signal connection_failed(reason: String)
signal peer_joined(id: int)
signal peer_left(id: int)
## Steam: a lobby's ready (hosting) or someone asked to join a friend's.
signal steam_lobby_ready(lobby_id: int)

enum Backend { NONE, ENET, STEAM }

const DEFAULT_PORT := 24680
const MAX_PEERS := 4
## Steam's test app (Spacewar) until the game has its own App ID.
const STEAM_TEST_APP_ID := 480
## Steam is switched off for now (2026-10-16): under the test app, Steam
## applies Spacewar's Steam Input layout, which takes the controller over. On
## again once the game has its own App ID with Steam Input off by default.
## Off, the addon stays installed but Steam never starts, and the Co-op menu
## shows only Host / Join by address.
const STEAM_ENABLED := false

var backend := Backend.NONE
## Simulated network trouble (each way): delay (ms), its random spread (ms), and
## the share of unreliable messages lost.
var lag_ms := 0.0
var jitter_ms := 0.0
var loss := 0.0
## Where we joined (ENet), for the menu.
var address := ""
var port := DEFAULT_PORT

var coop: CoopSession
var _steam: Object
var _steam_lobby := 0
var _joining_lobby := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # online, pausing doesn't stop the world
	coop = CoopSession.new()
	coop.name = "Coop"
	add_child(coop)
	multiplayer.peer_connected.connect(func(id: int) -> void: peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: session_started.emit())
	multiplayer.connection_failed.connect(func() -> void:
		_reset()
		connection_failed.emit("Couldn't reach the host"))
	multiplayer.server_disconnected.connect(func() -> void:
		_reset()
		session_ended.emit("The host left"))
	_read_command_line()
	_init_steam()


func is_online() -> bool:
	return backend != Backend.NONE and multiplayer.multiplayer_peer != null \
			and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func peer_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


## Hosts over ENet on `on_port`.
func host_enet(on_port := DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(on_port, MAX_PEERS - 1)
	if error != OK:
		connection_failed.emit("Couldn't host on port %d (%s)" % [on_port, error_string(error)])
		return error
	port = on_port
	address = ""
	_use(peer, Backend.ENET)
	session_started.emit()
	return OK


## Joins a host over ENet.
func join_enet(host_address: String, on_port := DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host_address, on_port)
	if error != OK:
		connection_failed.emit("Couldn't connect to %s:%d (%s)" % [host_address, on_port, error_string(error)])
		return error
	address = host_address
	port = on_port
	_use(peer, Backend.ENET)
	return OK  # session_started once connected


## Leaves the session (as host: ends it for everyone).
func leave(reason := "") -> void:
	if backend == Backend.NONE:
		return
	if _steam and _steam_lobby != 0:
		_steam.call("leaveLobby", _steam_lobby)
		_steam.call("clearRichPresence")
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	_reset()
	session_ended.emit(reason if reason else "Left the session")


func _use(peer: MultiplayerPeer, kind: Backend) -> void:
	multiplayer.multiplayer_peer = peer
	backend = kind


func _reset() -> void:
	backend = Backend.NONE
	_steam_lobby = 0
	_joining_lobby = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


# --- Steam (GodotSteam) ----------------------------------------------------
# Called by name, so the game runs (and parses) without the addon.

## Steam can be used: the GodotSteam addon is installed, this is a windowed run
## (not headless, as the probes are) and not `--no-steam`. Steam itself only
## starts when it's first used (_start_steam()).
func steam_ready() -> bool:
	if not STEAM_ENABLED:
		return false
	return _steam != null or (Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")
			and DisplayServer.get_name() != "headless" and "--no-steam" not in OS.get_cmdline_user_args())


## At startup Steam only starts if the game was launched from a friend's
## invite (Steam passes the lobby on the command line). Otherwise it waits until
## it's used: while the game's in Steam, Steam applies that app's Steam Input
## controller layout, and the test app's (Spacewar's) takes the controller over.
func _init_steam() -> void:
	if not STEAM_ENABLED:
		return
	var args := OS.get_cmdline_args()
	var at := args.find("+connect_lobby")
	if at >= 0 and at + 1 < args.size():
		join_steam.call_deferred(args[at + 1].to_int())


## Starts Steam if it isn't yet (see _init_steam()). Its App ID is the project
## setting steam/initialization/app_data/app_id (GodotSteam's), or Steam's test
## app until the game has one. False if it can't.
func _start_steam() -> bool:
	if _steam:
		return true
	if not steam_ready():
		return false
	var steam := Engine.get_singleton("Steam")
	var app_id: int = ProjectSettings.get_setting("steam/initialization/app_data/app_id", 0)
	if app_id <= 0:
		app_id = STEAM_TEST_APP_ID
	var result: Variant = steam.call("steamInitEx", app_id, false)  # callbacks run in _process
	if result is Dictionary and int(result.get("status", 1)) != 0:
		push_warning("Steam isn't available: %s" % result.get("verbal", "?"))
		return false
	_steam = steam
	_steam.connect("lobby_created", _on_steam_lobby_created)
	_steam.connect("lobby_joined", _on_steam_lobby_joined)
	_steam.connect("join_requested", func(lobby_id: int, _friend: int) -> void: join_steam(lobby_id))
	return true


func _process(_delta: float) -> void:
	if _steam:
		_steam.call("run_callbacks")


## Hosts in a new friends-only Steam lobby (invite friends to it from the
## overlay: invite_friends()).
func host_steam() -> void:
	if not _start_steam():
		connection_failed.emit("Steam isn't available (is it running and logged in?)")
		return
	leave()
	_steam.call("createLobby", 1, MAX_PEERS)  # Steam.LOBBY_TYPE_FRIENDS_ONLY


## Joins a friend's lobby (from an invite or the friends list).
func join_steam(lobby_id: int) -> void:
	if not _start_steam():
		connection_failed.emit("Steam isn't available (is it running and logged in?)")
		return
	leave()
	_joining_lobby = true
	_steam.call("joinLobby", lobby_id)


## The Steam lobby we're in (0: none), to share by hand when the overlay's not there
## (it only is when Steam launched the game).
func steam_lobby() -> int:
	return _steam_lobby


## Steam's overlay invite dialog for the lobby we're in.
func invite_friends() -> void:
	if _steam and _steam_lobby != 0:
		_steam.call("activateGameOverlayInviteDialog", _steam_lobby)


func _on_steam_lobby_created(result: int, lobby_id: int) -> void:
	if result != 1:  # Steam.RESULT_OK
		connection_failed.emit("Couldn't make a Steam lobby (%d)" % result)
		return
	_steam_lobby = lobby_id
	_steam.call("setLobbyJoinable", lobby_id, true)
	_steam.call("setRichPresence", "status", "Hunting schools in the Ocean")
	_steam.call("setRichPresence", "connect", "+connect_lobby %d" % lobby_id)  # "Join Game" in the friends list
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var error: int = peer.call("host_with_lobby", lobby_id)
	if error != OK:
		connection_failed.emit("Couldn't host the Steam lobby (%s)" % error_string(error))
		return
	_use(peer, Backend.STEAM)
	steam_lobby_ready.emit(lobby_id)
	session_started.emit()


func _on_steam_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if not _joining_lobby:
		return  # our own lobby, as its host
	_joining_lobby = false
	if response != 1:  # Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS
		connection_failed.emit("Couldn't join the Steam lobby (%d)" % response)
		return
	_steam_lobby = lobby_id
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var error: int = peer.call("connect_to_lobby", lobby_id)
	if error != OK:
		connection_failed.emit("Couldn't connect through the Steam lobby (%s)" % error_string(error))
		return
	_use(peer, Backend.STEAM)  # session_started once connected


func _read_command_line() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--port="):
			port = value.to_int()
		elif arg.begins_with("--lag="):
			lag_ms = value.to_float()
		elif arg.begins_with("--jitter="):
			jitter_ms = value.to_float()
		elif arg.begins_with("--loss="):
			loss = value.to_float()
