class_name SfxHooks
extends Node
## Hooks the game up to Sfx (planning_audio.md §2.1), so gameplay code stays
## mostly unaware of sound. Every node entering the tree is looked at once: a
## fish, the ball, the aquarium and a 1v1 get their sound node (FishSounds,
## BallSounds, ArenaSounds, MatchSounds); menus get their UI sounds here.
##
## UI sounds are settled once a frame: one press can move focus, press a button
## and open a menu all at once, and only the most specific sound plays (a
## mode picked beats the button press that picked it, which beats the focus
## landing in the next menu). Focus moving just after another UI sound (a menu
## opening and grabbing focus) stays quiet.

## UI sounds, least specific first. Anything else (a menu's own sound) beats them;
## between equals the first one asked for wins.
const RANKS := {"ui/move": 0, "ui/back": 1, "ui/select": 2}
## These, this soon (ms) after another UI sound, are part of it: focus landing
## in a menu that just opened, a back press that closed one, the mode picker
## closing because a mode was picked.
const QUIET := ["ui/move", "ui/back", "ui/mode_picker_close"]
const QUIET_MS := 150

## Every fish in the game (FishController), for the sounds that watch them all.
var fish: Array[FishController] = []

var _coop: LocalCoop
var _pending := ""
var _pending_step := -1
var _last_ui_ms := -100000
var _had_focus := false
var _coop_players := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var space := SpaceSounds.new()
	space.name = "Space"
	add_child(space)
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(func(_focus: Control) -> void: request("ui/move"))
	NetSession.peer_joined.connect(func(_id: int) -> void: request("ui/player_join"))
	NetSession.peer_left.connect(func(_id: int) -> void: request("ui/player_leave"))
	NetSession.connection_failed.connect(func(_reason: String) -> void: request("ui/connect_fail"))
	# The startup scene can be in the tree before this is (Godot readies it with
	# the autoloads), so its nodes never pass through node_added.
	_hook_existing.call_deferred(get_tree().root)


func _hook_existing(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_existing(child)


func _process(_delta: float) -> void:
	_refresh_ears()
	# Menus take ui_cancel in their _input and set it handled, so it's read here.
	if _had_focus and Input.is_action_just_pressed("ui_cancel"):
		request("ui/back")
	var focus := get_viewport().gui_get_focus_owner()
	_had_focus = focus != null and focus.is_visible_in_tree()


## Asks for UI sound `id` (`step` for a pitched one) this frame; the most
## specific one asked for plays at the end of the frame.
func request(id: String, step := -1) -> void:
	if _pending == "":
		_flush.call_deferred()
	elif _rank(id) <= _rank(_pending):
		return
	_pending = id
	_pending_step = step


func _flush() -> void:
	var id := _pending
	_pending = ""
	if id == "":
		return
	var now := Time.get_ticks_msec()
	if id in QUIET and now - _last_ui_ms < QUIET_MS:
		return
	_last_ui_ms = now
	if _pending_step >= 0:
		Sfx.play_pitched(id, _pending_step)
	else:
		Sfx.play(id)


func _rank(id: String) -> int:
	return int(RANKS.get(id, 10))


func _on_node_added(node: Node) -> void:
	if node is Arena or node is AquariumArena or node is Ocean:
		_attach.call_deferred(node, BedSounds.new(), &"sfx_bed")
	elif node is BubbleColumn:
		_loop_for_deferred.call_deferred(node, "arena/bubble_column_loop")
	if node is FishController:
		_track(node)
		_attach.call_deferred(node, FishSounds.new())
	elif node is Ball:
		_attach.call_deferred(node, BallSounds.new())
	elif node is AquariumArena:
		_attach.call_deferred(node, ArenaSounds.new())
	elif node is Match1v1 or node is HuntMatch:
		_attach.call_deferred(node, MatchSounds.new(), &"sfx_hook")
		_attach.call_deferred(node, BatteredSounds.new(), &"sfx_battered")
	elif node is NatureRun:
		_attach.call_deferred(node, NatureSounds.new())
	elif node is UnnaturalRun:
		_attach.call_deferred(node, UnnaturalSounds.new())
	elif node is Boss:
		_attach.call_deferred(node, BossSounds.new())
	elif node is FishAttack:
		_watch(node, (node as FishAttack).fired, _on_attack_fired.bind(node))
	elif node is TargetWheel:
		_attach.call_deferred(node, WheelSounds.new())
	elif node is BaseButton:
		_watch(node, (node as BaseButton).pressed, _on_button_pressed.bind(node))
	elif node is Slider:
		_watch(node, (node as Slider).value_changed, _on_slider_changed.bind(node))
	elif node is ModePicker:
		_watch(node, (node as ModePicker).visibility_changed, _on_picker_shown.bind(node))
	elif node is PauseMenu:
		_watch(node, (node as PauseMenu).opened, request.bind("ui/pause"))
		_watch(node, (node as PauseMenu).closed, request.bind("ui/unpause"))
	elif node is HomeScreen:
		_watch(node, (node as HomeScreen).character_changed, func(_character: int) -> void: request("ui/character_change"))
		_watch(node, (node as HomeScreen).species_changed, func(_species: int) -> void: request("ui/character_change"))
		_watch(node, (node as HomeScreen).mode_chosen, func(_mode: String) -> void: request("ui/mode_chosen"))
	elif node is MatchCard:
		request("ui/match_card")
	elif node is LocalCoop:
		_coop = node
		_watch(node, (node as LocalCoop).players_changed, _on_players_changed)


## Adds sound node `hook` to `node`, once (a node can leave the tree and come back).
func _attach(node: Node, hook: Node, key := &"sfx_hook") -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or node.has_meta(key):
		hook.free()
		return
	node.set_meta(key, hook)
	hook.name = "Sounds" if key == &"sfx_hook" else String(hook.get_script().get_global_name())
	node.add_child(hook)


## A loop for as long as `node` is in the tree (a bubble column).
func _loop_for_deferred(node: Node3D, id: String) -> void:
	if is_instance_valid(node) and node.is_inside_tree() and not node.has_meta(&"sfx_loop"):
		node.set_meta(&"sfx_loop", Sfx.loop_for(id, node))


func _track(tracked: FishController) -> void:
	if tracked not in fish:
		fish.append(tracked)
		tracked.tree_exiting.connect(func() -> void: fish.erase(tracked))


## Every local player's fish when there's more than one (split-screen): a world
## sound is as loud as it is for the nearest (Sfx.ears).
func _refresh_ears() -> void:
	var list: Array[Node3D] = []
	if is_instance_valid(_coop) and _coop.slots.size() > 1:
		for slot in _coop.slots:
			if is_instance_valid(slot.fish):
				list.append(slot.fish)
	Sfx.ears = list


func _watch(node: Node, which: Signal, callback: Callable) -> void:
	var key := StringName("sfx_" + which.get_name())
	if node.has_meta(key):
		return
	node.set_meta(key, true)
	which.connect(callback)


## A button's sound: its "sfx" meta if it has one ("" for none, e.g. the
## Sound Board's rows, which play their own), else ui/select.
func _on_button_pressed(button: BaseButton) -> void:
	var id: String = button.get_meta(&"sfx", "ui/select")
	if id != "":
		request(id)


## An Unnatural attack goes off: its own sound, from the fish's place.
func _on_attack_fired(attack: FishAttack) -> void:
	if is_instance_valid(attack.fish) and not attack.fish.puppet:
		Sfx.play_at("unnatural/%s_fire" % attack.source(), attack.fish.global_position)


func _on_slider_changed(value: float, slider: Slider) -> void:
	var span := maxf(slider.max_value - slider.min_value, 0.0001)
	request("ui/slider", roundi(7.0 * clampf((value - slider.min_value) / span, 0.0, 1.0)))


func _on_picker_shown(picker: ModePicker) -> void:
	if picker.get_meta(&"sfx_open", false) == picker.visible:
		return
	picker.set_meta(&"sfx_open", picker.visible)
	request("ui/mode_picker_open" if picker.visible else "ui/mode_picker_close")


func _on_players_changed(count: int) -> void:
	if count != _coop_players:
		request("ui/player_join" if count > _coop_players else "ui/player_leave")
	_coop_players = count
