class_name LocalCoop
extends Node
## Split-screen co-op in Nature and Unnatural: up to MAX_PLAYERS players on one
## machine, a controller each (PlayerSlot). While a run is on, pressing Back/View
## (JOIN_BUTTON) on a controller nobody's using adds a player: their own fish
## (a different character, which D-pad left/right changes), camera, HUD,
## arcade looks and school wheel, in their own part of the window
## (SplitScreen). Holding Back/View for LEAVE_HOLD on a joined controller
## leaves. With one player left, the first player has the whole window back.
##
## The first player is main's own fish, camera and HUD (slot 0). While others
## play, the first player has the keyboard and the controller they used first
## (every controller drives them when they're alone, as before co-op).
## Everything tuned in the tuning panel is the first player's, and is copied
## to every other player's fish and camera as it changes.
##
## attach_run() wires each player (and anyone joining later) into a run. A
## NatureRun: their ball cam on their own focus, their school wheel, their
## HUD's counts. An UnnaturalRun: the survivor cam and their own UnnaturalHud
## (mode_hud; the first player's is main's). detach_run() undoes it. Leaving
## for a mode without co-op drops the extra players (drop_extras()).

signal players_changed(count: int)

const MAX_PLAYERS := 4
const JOIN_BUTTON := JOY_BUTTON_BACK
const LEAVE_HOLD := 1.0
const FISH_SCENE := preload("res://scenes/fish.tscn")
const CAMERA_SCRIPT := preload("res://scripts/follow_camera.gd")
const HUD_SCRIPT := preload("res://scripts/hud.gd")
## Camera exports never copied from the first player's (each camera's own).
const CAMERA_OWN := ["fish"]

var slots: Array[PlayerSlot] = []
## The run the players are in (a NatureRun or an UnnaturalRun; null: none, and no joining).
var run: Node
## The tuning panel (DebugPanel), whose tuning every player gets.
var panel: Node

var _split: SplitScreen
## Where the fish live (main), and where the first player's views go back to.
var _home: Node
## The controller the first player used first (-1: none yet).
var _primary_pad := -1
var _tuning_dirty := false
var _next_uid := 1


## The first player's slot (main's own fish, camera, HUD and arcade looks).
func setup(home: Node, first: PlayerSlot, tuning_panel: Node) -> void:
	_home = home
	first.index = 0
	slots = [first]
	panel = tuning_panel
	if panel and panel.has_signal("tuning_changed"):
		panel.tuning_changed.connect(func() -> void: _tuning_dirty = true)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


## Local players now.
func count() -> int:
	return slots.size()


func slot_of(fish: Node) -> PlayerSlot:
	for slot in slots:
		if slot.fish == fish:
			return slot
	return null


func _input(event: InputEvent) -> void:
	var pad := -1
	if event is InputEventJoypadButton and event.pressed:
		pad = event.device
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		pad = event.device
	if pad < 0:
		return
	if _primary_pad < 0 and not (event is InputEventJoypadButton and event.button_index == JOIN_BUTTON):
		_primary_pad = pad
	if not (event is InputEventJoypadButton):
		return
	var button: int = event.button_index
	var owner := _slot_for_pad(pad)
	# The first player's own controller never joins as someone else.
	# (With one controller plugged in, that's the only one.)
	if button == JOIN_BUTTON and owner == null and pad != _primary_pad and _joinable_pad(pad) and can_join():
		join(pad)
		get_viewport().set_input_as_handled()
	elif owner and owner.index > 0 and button in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT] and not get_tree().paused:
		_next_character(owner, 1 if button == JOY_BUTTON_DPAD_RIGHT else -1)


## `pad` can be a new player's: not the first player's only controller. (A
## made-up id, as the probes use, isn't plugged in at all: it can.)
func _joinable_pad(pad: int) -> bool:
	var pads := Input.get_connected_joypads()
	return not (pads.size() == 1 and pads[0] == pad and slots.size() == 1)


## Joining is open: a run on, with room, and a controller to spare.
func can_join() -> bool:
	return is_instance_valid(run) and slots.size() < MAX_PLAYERS and not get_tree().paused


func _process(delta: float) -> void:
	if _tuning_dirty:
		_tuning_dirty = false
		for slot in slots:
			if slot.index > 0:
				_copy_tuning(slot)
	for slot in slots.duplicate():
		if slot.index == 0 or slot.input == null:
			continue
		if Input.is_joy_button_pressed(slot.input.device, JOIN_BUTTON) and not get_tree().paused:
			slot.leave_held += delta
			if slot.leave_held >= LEAVE_HOLD:
				leave(slot)
		else:
			slot.leave_held = 0.0


## The player on controller `pad`, or null.
func _slot_for_pad(pad: int) -> PlayerSlot:
	for slot in slots:
		if slot.index > 0 and slot.input and slot.input.device == pad:
			return slot
	return null


## A new player on controller `pad` (the joining press): their fish, camera,
## HUD and looks, in a new view. Returns their slot (null if there's no room).
func join(pad: int) -> PlayerSlot:
	if slots.size() >= MAX_PLAYERS:
		return null
	var first := slots[0]
	if slots.size() == 1:
		# From now on the first player has the keyboard and their own controller only.
		if _primary_pad == pad:
			_primary_pad = _other_pad(pad)
		first.input = PlayerInput.for_device(_primary_pad if _primary_pad >= 0 else -2, true)
		first.fish.input_source = first.input
		first.camera.input = first.input
	var slot := PlayerSlot.new()
	slot.index = slots.size()
	slot.uid = _next_uid
	_next_uid += 1
	slot.input = PlayerInput.for_device(pad)
	slot.fish = FISH_SCENE.instantiate()
	slot.fish.name = "Fish%d" % (slot.index + 1)
	slot.fish.character = _unused_character()
	slot.fish.display_name = "Player %d" % (slot.index + 1)
	slot.fish.input_source = slot.input
	slot.fish.set_meta("coop_index", slot.index)
	_home.add_child(slot.fish)
	_copy_tuning(slot)
	slot.camera = Camera3D.new()
	slot.camera.set_script(CAMERA_SCRIPT)
	slot.camera.name = "FollowCamera%d" % (slot.index + 1)
	slot.camera.fish = slot.fish
	slot.camera.input = slot.input
	_copy_camera(first.camera, slot.camera)
	slot.hud = CanvasLayer.new()
	slot.hud.set_script(HUD_SCRIPT)
	slot.hud.name = "HUD%d" % (slot.index + 1)
	slot.hud.fish = slot.fish
	slot.hud.joined_player = true
	slot.arcade = ArcadeFx.new()
	slot.arcade.name = "ArcadeFx%d" % (slot.index + 1)
	slot.arcade.fish = slot.fish
	slot.arcade.camera = slot.camera
	slots.append(slot)
	_ensure_split()
	var view := _split.view(slot.index)
	view.add_child(slot.camera)
	slot.camera.make_current()
	view.add_child(slot.hud)
	view.add_child(slot.arcade)
	if is_instance_valid(run):
		slot.fish.set_meta("coop_index", slot.index)
		run.add_player(slot.fish)
		_wire(slot)
		slot.camera.snap()
	_refresh_cameras()
	players_changed.emit(slots.size())
	return slot


## A player (not the first) leaves: their fish and views go.
func leave(slot: PlayerSlot) -> void:
	if slot.index == 0 or slot not in slots:
		return
	if is_instance_valid(run):
		_unwire(slot)
		run.remove_player(slot.fish)
	slots.erase(slot)
	for node: Node in slot.view_nodes() + [slot.fish]:
		if is_instance_valid(node):
			node.queue_free()
	# The rest move up a view each (their views are rebuilt in order).
	for i in slots.size():
		slots[i].index = i
	_rebuild_views()
	players_changed.emit(slots.size())


## Everyone but the first player leaves.
func drop_extras() -> void:
	for slot in slots.duplicate():
		if slot.index > 0:
			leave(slot)


## Wires every player into `game_run` (see the class description).
func attach_run(game_run: Node) -> void:
	run = game_run
	run.fish_teleported.connect(func(fish: FishController) -> void:
		var slot := slot_of(fish)
		if slot:
			slot.camera.snap())
	if run is UnnaturalRun:
		for slot in slots:
			_wire(slot)
		_refresh_views()
		return
	run.focus_changed.connect(func(focus: Node3D, fish: FishController) -> void:
		var slot := slot_of(fish)
		if slot:
			slot.camera.ball = focus)
	run.awarded.connect(func(event: Dictionary) -> void:
		# Big multis and sprees punch the player's view in, harder each step.
		var slot := slot_of(event.get("by"))
		var chain: int = event.get("chain", 0)
		if slot and is_instance_valid(slot.arcade) and (event.type == NatureScore.SPREE or chain >= 3):
			slot.arcade.punch(1.0 if event.type == NatureScore.SPREE else minf(0.4 + 0.15 * chain, 1.2)))
	for slot in slots:
		_wire(slot)


## Undoes attach_run() (the run's ending).
func detach_run() -> void:
	for slot in slots:
		_unwire(slot)
	run = null


func _wire(slot: PlayerSlot) -> void:
	if run is UnnaturalRun:
		_wire_unnatural(slot)
		return
	var nature := run as NatureRun
	var camera := slot.camera
	camera.ball = nature.focus_of(slot.fish)
	camera.ball_cam = true
	# Ball cam: a tap looks at the nearest thing ahead, holding opens the school wheel.
	camera.hold_opens_wheel = true
	var fish := slot.fish
	var toggled := func(on: bool) -> void:
		if on and is_instance_valid(nature):
			nature.pick_focus(fish)
	camera.set_meta("coop_toggled", toggled)
	camera.ball_cam_toggled.connect(toggled)
	slot.wheel = TargetWheel.new()
	slot.wheel.name = "TargetWheel" if slot.index == 0 else "TargetWheel%d" % (slot.index + 1)
	slot.wheel.camera = camera
	slot.wheel.run = nature
	slot.wheel.fish = fish
	camera.get_parent().add_child(slot.wheel)
	camera.wheel_opened.connect(slot.wheel.open)
	camera.wheel_closed.connect(slot.wheel.close)
	slot.hud.set_nature(nature)


## Unnatural: the survivor cam, and (past the first player) their own HUD in their view.
func _wire_unnatural(slot: PlayerSlot) -> void:
	var unnatural := run as UnnaturalRun
	slot.camera.ball = null
	slot.camera.ball_cam = false
	slot.camera.cull_mask = TreasureChest.view_mask(slot.index)  # their chests, not the others'
	UnnaturalRun.steady_camera(slot.camera, true, unnatural.settings)
	if slot.index > 0 and not is_instance_valid(slot.mode_hud):
		var hud := UnnaturalHud.new()
		hud.name = "UnnaturalHud%d" % (slot.index + 1)
		hud.run = unnatural
		hud.fish = slot.fish
		slot.mode_hud = hud
		slot.camera.get_parent().add_child(hud)
	if slot.mode_hud is UnnaturalHud:
		(slot.mode_hud as UnnaturalHud).player_camera = slot.camera  # its follow / free cam note


func _unwire(slot: PlayerSlot) -> void:
	var camera := slot.camera
	if not is_instance_valid(camera):
		return
	if run is UnnaturalRun:
		UnnaturalRun.steady_camera(camera, false, (run as UnnaturalRun).settings)
		camera.cull_mask = 0xFFFFF
		if slot.index > 0 and is_instance_valid(slot.mode_hud):
			slot.mode_hud.queue_free()
		slot.mode_hud = null
		return
	camera.ball = null
	camera.hold_opens_wheel = false
	if camera.has_meta("coop_toggled"):
		var toggled: Callable = camera.get_meta("coop_toggled")
		if camera.ball_cam_toggled.is_connected(toggled):
			camera.ball_cam_toggled.disconnect(toggled)
		camera.remove_meta("coop_toggled")
	if is_instance_valid(slot.wheel):
		if camera.wheel_opened.is_connected(slot.wheel.open):
			camera.wheel_opened.disconnect(slot.wheel.open)
			camera.wheel_closed.disconnect(slot.wheel.close)
		slot.wheel.queue_free()
	slot.wheel = null
	if is_instance_valid(slot.hud):
		slot.hud.set_nature(null)


## The window splits once there's a second player: the first player's camera,
## HUD, looks and wheel move into the first view.
func _ensure_split() -> void:
	if _split:
		return
	_split = SplitScreen.new()
	_split.name = "SplitScreen"
	_home.add_child(_split)
	var view := _split.view(0)
	for node in slots[0].view_nodes():
		node.reparent(view, false)
	slots[0].camera.make_current()


## Every player's views where they belong now (a node added since the split).
func _refresh_views() -> void:
	if _split:
		_rebuild_views()


## Views in slot order again (after someone leaves); one player: the whole window.
func _rebuild_views() -> void:
	if slots.size() <= 1:
		_unsplit()
		return
	# Park every player's views in their slot's view, in order.
	for slot in slots:
		var view := _split.view(slot.index)
		for node in slot.view_nodes():
			if node.get_parent() != view:
				node.reparent(view, false)
		slot.camera.make_current()
	_split.shrink_to(slots.size())
	_refresh_cameras()


## Back to one player: the first player's views back in the window.
func _unsplit() -> void:
	var first := slots[0]
	for node in first.view_nodes():
		node.reparent(_home, false)
	first.camera.make_current()
	first.input = null
	first.fish.input_source = null  # every controller and the keyboard again
	first.camera.input = null
	if _split:
		_split.queue_free()
		_split = null
	_refresh_cameras()


## The cameras that pick school fish for full models.
func _refresh_cameras() -> void:
	var cameras: Array[Camera3D] = []
	if slots.size() > 1:
		for slot in slots:
			cameras.append(slot.camera)
	School.view_cameras = cameras


## A character none of the players are.
func _unused_character() -> FishCharacter.Family:
	var taken := slots.map(func(slot: PlayerSlot) -> FishCharacter.Family: return slot.fish.character)
	for family: FishCharacter.Family in FishCharacter.CARS:
		if family not in taken:
			return family
	return FishCharacter.CARS.keys()[0]


func _next_character(slot: PlayerSlot, step: int) -> void:
	var families: Array = FishCharacter.CARS.keys()
	var at := families.find(slot.fish.character)
	slot.fish.character = families[posmod(at + step, families.size())]


## A connected controller other than `pad`, or -1.
func _other_pad(pad: int) -> int:
	for other in Input.get_connected_joypads():
		if other != pad and _slot_for_pad(other) == null:
			return other
	return -1


func _on_joy_connection_changed(pad: int, connected: bool) -> void:
	if connected:
		return
	var slot := _slot_for_pad(pad)
	if slot:
		leave(slot)


## The first player's tuning on `slot`'s fish and camera.
func _copy_tuning(slot: PlayerSlot) -> void:
	var first := slots[0]
	if is_instance_valid(slot.fish):
		var character := slot.fish.character
		Match1v1.copy_tuning(first.fish, slot.fish)
		slot.fish.character = character
	if is_instance_valid(slot.camera):
		_copy_camera(first.camera, slot.camera)


static func _copy_camera(from: Camera3D, to: Camera3D) -> void:
	for property in from.get_property_list():
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (property.usage & PROPERTY_USAGE_EDITOR):
			continue
		if property.name in CAMERA_OWN:
			continue
		to.set(property.name, from.get(property.name))
