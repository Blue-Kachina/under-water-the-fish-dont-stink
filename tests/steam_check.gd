extends Node
## Not a probe: checks the Steam backend (NetSession, GodotSteam) against the
## Steam client running on this PC: hosting in a friends-only lobby. Needs a
## window (Steam isn't started headless) and Steam running and logged in.
##   Godot_console.exe --path . res://tests/steam_check.tscn


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var ok := NetSession.steam_ready()
	print("steam_check: Steam ready: %s" % ok)
	if not ok:
		get_tree().quit(1)
		return
	var steam := Engine.get_singleton("Steam")
	var result := {}
	NetSession.steam_lobby_ready.connect(func(lobby_id: int) -> void: result["lobby"] = lobby_id)
	NetSession.connection_failed.connect(func(reason: String) -> void: result["failed"] = reason)
	NetSession.host_steam()
	var waited := 0.0
	while result.is_empty() and waited < 15.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if result.has("lobby"):
		print("steam_check: logged on as %s (%d)" % [steam.call("getPersonaName"), steam.call("getSteamID")])
		print("steam_check: hosting in lobby %d: online %s, host %s, peer %s, members %d" % [result.lobby, NetSession.is_online(),
				NetSession.is_host(), multiplayer.multiplayer_peer.get_class(), steam.call("getNumLobbyMembers", result.lobby)])
	else:
		print("steam_check: FAILED: %s" % result.get("failed", "no answer from Steam in 15 s"))
	NetSession.leave()
	await get_tree().create_timer(0.5).timeout
	print("steam_check: left: online %s" % NetSession.is_online())
	get_tree().quit(0 if result.has("lobby") else 1)
