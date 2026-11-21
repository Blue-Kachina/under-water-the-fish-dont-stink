class_name WhatStinksCam
extends Node
## What Stinks?'s camera (what_stinks.md decision 8, "camera as in Nature"):
## the follow cam, and a lock-on on a school (Nature's ball cam).
##
## The view is Unnatural's follow cam (UnnaturalRun.steady_camera, from its
## panel: Settle style, lags turns, coast swing) for every role. Without it the
## FollowCamera keeps the chase camera of the arenas, which holds still in open
## water, so the view looked fixed. The Hunter's form framing (HunterSize.frame)
## goes on top of it.
##
## While a round is live, the ball cam button (FollowCamera.hold_opens_wheel)
## locks on: a tap toggles it and, as it goes on, looks at the school nearest
## and ahead; holding opens the school wheel (TargetWheel: a slice per live
## school, name, fish left, edge arrows) and the right stick picks one, letting
## go locks on it (the stick left alone: as it was). The view aims at the
## school's centre (School._aim_point), so it frames the school, not one fish.
## A school wiped out (or the one a joined prey is in) moves it on to the next.
## Out of a live round (countdown, round over, eaten and spectating) it is the
## follow cam alone, and the wheel is gone.
##
## It answers TargetWheel the way NatureRun does: targets(), focus_of(fish),
## set_focus(node, fish). For the local player only.

var game: WhatStinksMatch
var settings := WhatStinksSettings.shared()
## The wheel and edge arrows, while lock-on is on offer.
var wheel: TargetWheel
## Lock-on is on offer (a live round, the local fish out and about).
var active := false

var _focus: Node3D
var _set_frame := -1
var _swing_before := -1.0
var _snapped := false


func bind(match_node: WhatStinksMatch) -> void:
	game = match_node


func _camera() -> Node:
	return game.camera if game != null and is_instance_valid(game.camera) else null


func _fish() -> FishController:
	return game.local_fish() if game != null else null


## Whether the lock-on is on offer now.
func wanted() -> bool:
	var fish := _fish()
	if not settings.lock_on or not is_instance_valid(fish) or _camera() == null:
		return false
	if game.phase != WhatStinksMatch.Phase.LIVE or game.eaten.has(fish) or game.is_spectating():
		return false
	return game.is_hunter(fish) or settings.lock_on_prey


func _process(_delta: float) -> void:
	var camera := _camera()
	if camera == null:
		return
	UnnaturalRun.steady_camera(camera, true, UnnaturalSettings.shared())  # live from the panel
	var fish := _fish()
	if is_instance_valid(fish) and game.is_hunter(fish) and not game.is_spectating():
		var form := game.settings.form_sheet()
		game.size.frame(camera, fish, form)  # the form's distance over the follow cam's
		var settle: float = float(form.get("cam_settle", 1.0))  # a lively form's view follows its nose slower, so its stride sweeps don't wobble it
		camera.set("settle_rate", float(camera.get("settle_rate")) * settle)
	if not _snapped:
		_snapped = true
		if camera.has_method("snap"):
			camera.call("snap")
	var on := wanted()
	if on and not active:
		_activate()
	elif not on and active:
		_deactivate(false)
	if active:
		camera.set("transition_speed", settings.lock_swing)
		if not _focus_ok(_focus):
			pick_focus(fish)


func _activate() -> void:
	var camera := _camera()
	active = true
	camera.set("hold_opens_wheel", true)
	camera.set("free_cam", false)  # lock-on is a follow cam thing: the free cam had Y, which is now the wheel
	_swing_before = float(camera.get("transition_speed"))
	_focus = null
	wheel = TargetWheel.new()
	wheel.name = "TargetWheel"
	wheel.camera = camera
	wheel.run = self
	wheel.fish = _fish()
	wheel.settings = settings
	camera.get_parent().add_child(wheel)
	camera.connect("wheel_opened", _on_wheel_opened)
	camera.connect("wheel_opened", wheel.open)
	camera.connect("wheel_closed", wheel.close)
	camera.connect("ball_cam_toggled", _on_toggled)
	pick_focus(_fish())  # ready for a tap's first look, though the cam stays a follow cam


## Lock-on goes (round over, eaten, role change) or `all` of it (the match ends): the view is the plain follow cam again.
func _deactivate(all: bool) -> void:
	var camera := _camera()
	active = false
	_focus = null
	if camera != null:
		for pair: Array in [["wheel_opened", _on_wheel_opened], ["ball_cam_toggled", _on_toggled]]:
			if camera.is_connected(pair[0], pair[1]):
				camera.disconnect(pair[0], pair[1])
		if is_instance_valid(wheel):
			for pair: Array in [["wheel_opened", wheel.open], ["wheel_closed", wheel.close]]:
				if camera.is_connected(pair[0], pair[1]):
					camera.disconnect(pair[0], pair[1])
		camera.set("hold_opens_wheel", false)
		camera.set("wheel_open", false)
		camera.set("ball", null)
		if all:
			camera.set("ball_cam", false)
		elif camera.get("ball_cam") == true and camera.has_method("set_ball_cam"):
			camera.call("set_ball_cam", false)  # swings back behind the fish
		if _swing_before > 0.0:
			camera.set("transition_speed", _swing_before)
	_swing_before = -1.0
	if is_instance_valid(wheel):
		wheel.is_open = false
		wheel.queue_free()
	wheel = null


## The match is over (or the mode left): hands the camera back as it was.
func clear() -> void:
	if active:
		_deactivate(true)
	var camera := _camera()
	if camera != null:
		UnnaturalRun.steady_camera(camera, false, UnnaturalSettings.shared())
		camera.set("ball", null)
		camera.set("ball_cam", false)
	_snapped = false
	set_process(false)  # the match is going: nothing puts the follow cam back


func _on_wheel_opened() -> void:
	if focus_of(_fish()) == null:
		pick_focus(_fish())  # holding with nothing picked yet: start on the nearest


## Lock-on went on: look at the nearest school ahead (a wheel's pick this frame stands).
func _on_toggled(on: bool) -> void:
	if on and Engine.get_process_frames() != _set_frame:
		pick_focus(_fish())


# --- What TargetWheel asks (as NatureRun's) ------------------------------------

## What `fish`'s lock-on looks at (a school's centre; null: nothing).
func focus_of(_fish_asked: FishController = null) -> Node3D:
	return _focus if is_instance_valid(_focus) else null


## The school nearest `fish` and ahead of it to look at (ones behind count as further off).
func pick_focus(fish: FishController = null) -> void:
	if fish == null:
		fish = _fish()
	var best: Node3D = null
	var best_cost := INF
	if is_instance_valid(fish):
		var ahead := -fish.global_basis.z
		for entry: Array in targets():
			var offset: Vector3 = (entry[0] as Node3D).global_position - fish.global_position
			var far := offset.length()
			if settings.lock_range > 0.0 and far > settings.lock_range:
				continue
			var cost := far * (settings.lock_behind_cost - ahead.dot(offset.normalized()))
			if cost < best_cost:
				best = entry[0]
				best_cost = cost
	_set_focus(best)


## Looks at `candidate` (a school's centre) if it is still there.
func set_focus(candidate: Node3D, _fish_asked: FishController = null) -> void:
	if _focus_ok(candidate):
		_set_frame = Engine.get_process_frames()
		_set_focus(candidate)


func _set_focus(candidate: Node3D) -> void:
	_focus = candidate
	var camera := _camera()
	if camera != null:
		camera.set("ball", candidate)


## For the school wheel: [node, name, fish left] for each school with fish left.
func targets() -> Array:
	var found := []
	if game == null or game.field == null:
		return found
	for school in game.field.schools:
		if _focus_ok(school.centre):
			found.append([school.centre, school.display_name, school.alive_count()])
	return found


func _focus_ok(candidate: Node3D) -> bool:
	if not is_instance_valid(candidate) or not candidate.is_inside_tree() or not candidate.visible:
		return false
	var school := candidate.get_parent() as School
	if school == null or not game.field.schools.has(school) or school.alive_count() == 0:
		return false
	var fish := _fish()
	if is_instance_valid(fish) and game.join != null and game.join.school_of(fish) == school:
		return false  # the school a joined prey swims in: looking at its own middle shows nothing
	return true
