class_name CoopMenu
extends CanvasLayer
## Online co-op, from the pause menu's "Co-op online": host a Nature session
## or join one (NetSession, CoopSession), and leave it.
## - Host: others join this machine's Nature run, by its address and port
##   (on a LAN, or with the port forwarded). With Steam (the GodotSteam addon),
##   Host on Steam makes a friends-only lobby instead; friends join it from an
##   invite or the friends list, with no addresses or ports.
## - Join: an address (and port) to join.
## - The simulated lag, jitter and loss are for testing what a bad connection
##   looks like.
## Mouse and controller both work. Runs while the game's paused.

var _panel := PanelContainer.new()
var _status := Label.new()
var _name := LineEdit.new()
var _port := SpinBox.new()
var _address := LineEdit.new()
var _host := Button.new()
var _join := Button.new()
var _steam_host := Button.new()
var _invite := Button.new()
var _leave := Button.new()
var _lobby := LineEdit.new()
var _steam_lobby_row: HBoxContainer
var _copy_lobby := Button.new()
var _join_lobby := Button.new()
var _steam_tip := Label.new()
var _close := Button.new()
var _lag := SpinBox.new()
var _jitter := SpinBox.new()
var _loss := SpinBox.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8  # over the pause menu and the tuning panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.08, 0.95)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(440, 0)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)

	var title := Label.new()
	var game: Node = NetSession.coop.main
	title.text = "CO-OP ONLINE  ·  %s" % ("UNNATURAL" if game and game.get("current_mode") == "Unnatural" else "NATURE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.modulate = Color(1, 1, 1, 0.75)
	column.add_child(_status)

	_name.text = UISettings.player_name
	_name.placeholder_text = "Your name"
	_name.text_submitted.connect(func(text: String) -> void: UISettings.set_value("player_name", text))
	_name.focus_exited.connect(func() -> void: UISettings.set_value("player_name", _name.text))
	column.add_child(_row("Name", _name))

	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = NetSession.DEFAULT_PORT
	column.add_child(_row("Port", _port))
	_setup_button(_host, "Host", func() -> void: NetSession.host_enet(int(_port.value)))
	column.add_child(_host)
	_address.text = "127.0.0.1"
	_address.placeholder_text = "Host's address"
	column.add_child(_row("Address", _address))
	_setup_button(_join, "Join", func() -> void:
		NetSession.coop._set_status("Connecting to %s..." % _address.text.strip_edges())
		NetSession.join_enet(_address.text.strip_edges(), int(_port.value)))
	column.add_child(_join)

	_setup_button(_steam_host, "Host on Steam (friends)", NetSession.host_steam)
	column.add_child(_steam_host)
	_setup_button(_invite, "Invite friends (Steam overlay)", NetSession.invite_friends)
	column.add_child(_invite)
	# Steam's overlay is only there when Steam started the game, so the lobby's
	# number can also be passed on by hand: the host copies it, a friend pastes it.
	_lobby.placeholder_text = "Friend's Steam lobby number"
	_steam_lobby_row = _row("Lobby", _lobby)
	_setup_button(_copy_lobby, "Copy", func() -> void:
		DisplayServer.clipboard_set(str(NetSession.steam_lobby()))
		NetSession.coop._set_status("Lobby number copied: send it to your friends"))
	_steam_lobby_row.add_child(_copy_lobby)
	_setup_button(_join_lobby, "Join", func() -> void:
		var lobby := _lobby.text.strip_edges()
		if lobby.is_valid_int():
			NetSession.coop._set_status("Joining Steam lobby %s..." % lobby)
			NetSession.join_steam(lobby.to_int()))
	_steam_lobby_row.add_child(_join_lobby)
	column.add_child(_steam_lobby_row)
	# Until the game has its own App ID, Steam treats it as its test app (Spacewar)
	# and applies that app's Steam Input layout, which takes the controller over.
	_steam_tip.text = "Controller stops working once Steam's on? In Steam: Settings > Controller > turn off \"Enable Steam Input for Xbox controllers\", then restart the game."
	_steam_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_steam_tip.modulate = Color(1.0, 0.85, 0.5, 0.85)
	_steam_tip.add_theme_font_size_override("font_size", 13)
	column.add_child(_steam_tip)
	_setup_button(_leave, "Leave session", func() -> void: NetSession.leave())
	column.add_child(_leave)

	var testing := Label.new()
	testing.text = "Simulated network (testing)"
	testing.modulate = Color(1, 1, 1, 0.5)
	column.add_child(testing)
	var trouble := HBoxContainer.new()
	for pair: Array in [[_lag, "Lag ms", 0.0, 1000.0, 1.0, NetSession.lag_ms], [_jitter, "Jitter ms", 0.0, 500.0, 1.0, NetSession.jitter_ms],
			[_loss, "Loss %", 0.0, 50.0, 1.0, NetSession.loss * 100.0]]:
		var box: SpinBox = pair[0]
		box.min_value = pair[2]
		box.max_value = pair[3]
		box.step = pair[4]
		box.value = pair[5]
		box.tooltip_text = pair[1]
		trouble.add_child(_row(pair[1], box))
	_lag.value_changed.connect(func(value: float) -> void: NetSession.lag_ms = value)
	_jitter.value_changed.connect(func(value: float) -> void: NetSession.jitter_ms = value)
	_loss.value_changed.connect(func(value: float) -> void: NetSession.loss = value / 100.0)
	column.add_child(trouble)

	_setup_button(_close, "Close", queue_free)
	column.add_child(_close)
	NetSession.coop.status_changed.connect(func(_text: String) -> void: _refresh())
	_refresh()
	_host.grab_focus.call_deferred()


func _process(_delta: float) -> void:
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _name.has_focus() and not _address.has_focus() and not _lobby.has_focus():
		queue_free()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var online := NetSession.is_online()
	var text: String = NetSession.coop.status
	if online and not NetSession.is_host() and NetSession.coop.rtt > 0.0:
		text += "    ·    ping %d ms" % roundi(NetSession.coop.rtt * 1000.0)
	_status.text = text
	_host.disabled = online
	_join.disabled = online
	_port.editable = not online
	_address.editable = not online
	_steam_host.visible = NetSession.steam_ready()
	_steam_host.disabled = online
	_invite.visible = NetSession.steam_ready() and online and NetSession.is_host()
	var hosting_lobby := NetSession.steam_lobby() != 0 and NetSession.is_host()
	_steam_lobby_row.visible = NetSession.steam_ready() and (hosting_lobby or not online)
	_steam_tip.visible = NetSession.steam_ready()
	_copy_lobby.visible = hosting_lobby
	_join_lobby.visible = not online
	_lobby.editable = not online
	if hosting_lobby and not _lobby.has_focus():
		_lobby.text = str(NetSession.steam_lobby())
	_leave.visible = online


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80.0
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _setup_button(button: Button, text: String, on_pressed: Callable) -> void:
	button.text = text
	button.custom_minimum_size.y = 34.0
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.pressed.connect(on_pressed)
