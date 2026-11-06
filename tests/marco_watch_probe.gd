extends Node
## Marco Polo's watching and surfaces (play-test 3):
## - stick_to_surfaces (off by default): no fish in the match drives on
##   surfaces, bots too; the player's own setting comes back after the match;
## - a hider's camera button (Y): a tap parks them (their fish held still) and
##   watches another fish, a second tap is back on their own follow cam; held,
##   the watch wheel opens with a slice per fish (their own first), the left
##   stick picks, and letting go watches the pick (their own slice: back);
## - a seeker's Y still swaps follow and free cam (the camera keeps the button).
##   Godot_console.exe --headless --path . res://tests/marco_watch_probe.tscn

var main: Node
var fish: FishController
var camera: Node
var failures := 0
var mp := MarcoPoloSettings.shared()


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	camera = main._camera
	mp.hide_time = 0.3
	mp.round_time = 120.0
	mp.round_over_time = 0.3
	mp.min_players = 4
	mp.rounds = 2
	mp.bot_seeker_rounds = 1
	mp.arena = "Sunken Temple"
	var own_surfaces := fish.rl_surface_mechanics
	main.set_mode(main.MARCO_POLO)
	await _frames(3)
	if main._match_card:
		main._match_card.play_requested.emit()
	await _frames(5)
	var game: MarcoPoloMatch = main.marco_polo
	check(game != null, "a Marco Polo match")
	if game == null:
		_finish()
		return

	print("surfaces:")
	await _ticks(3)
	check(game.players.all(func(f: FishController) -> bool: return not f.rl_surface_mechanics), "stick_to_surfaces off: no fish sticks to surfaces, bots too")
	mp.stick_to_surfaces = true
	await _ticks(2)
	check(game.players.all(func(f: FishController) -> bool: return f.rl_surface_mechanics), "turned on in the panel: every fish, live")
	mp.stick_to_surfaces = false
	await _ticks(2)

	print("a hider watches:")
	var hiding := 0 if game.seeker_order()[0] != fish else 1
	game.start_round(hiding)
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, 3.0)
	for bot: Node in game.bots.values():
		bot.process_mode = Node.PROCESS_MODE_DISABLED
	check(game.is_live_hider(fish), "the player hides")
	await _frames(2)
	check(bool(camera.get("button_taken")) and not bool(camera.get("free_cam")), "the match has the camera button, on the follow cam")
	await _tap(&"ball_cam")
	var watched: FishController = game.spectate_target()
	check(game.is_parked() and watched != null and watched != fish, "a tap parks and watches %s" % MarcoPoloHud.name_of(watched))
	check(camera.get("target") == watched, "the camera follows them")
	await _ticks(2)
	check(fish.controls_locked, "the parked fish is held still")
	check(game.watchable().has(watched) and not game.watchable().has(fish), "watchable: everyone in the round but the player")
	await _tap(&"ball_cam")
	check(not game.is_parked() and camera.get("target") == null, "a second tap: back on their own cam")
	await _ticks(2)
	check(not fish.controls_locked, "their fish is theirs again")

	print("the watch wheel:")
	await _frames(1)
	Input.action_press(&"ball_cam")
	await _seconds(mp.watch_hold_time + 0.15)
	var wheel := game.watch_wheel()
	check(wheel.is_open, "holding Y opens the wheel")
	check(wheel.entries.size() == game.players.size() and wheel.entries[0] == fish, "a slice per fish, their own first (%d)" % wheel.entries.size())
	await _ticks(2)
	check(fish.controls_locked, "their fish holds still while they pick")
	# Point the left stick at the slice to the right of the top one.
	var want: FishController = wheel.entries[1]
	var at := wheel.slice_angle(1)
	_stick(Vector2.from_angle(at))
	await _frames(3)
	check(wheel.picked == want, "the left stick picks %s's slice" % MarcoPoloHud.name_of(want))
	Input.action_release(&"ball_cam")
	_stick(Vector2.ZERO)
	await _frames(3)
	check(not wheel.is_open and game.is_parked() and game.spectate_target() == want, "letting go watches them")
	await _frames(1)
	Input.action_press(&"ball_cam")
	await _seconds(mp.watch_hold_time + 0.15)
	_stick(Vector2.from_angle(wheel.slice_angle(0)))
	await _frames(3)
	check(wheel.picked == fish, "their own slice (top)")
	Input.action_release(&"ball_cam")
	_stick(Vector2.ZERO)
	await _frames(3)
	check(not game.is_parked() and camera.get("target") == null, "letting go on it: back on their own cam")
	await _ticks(2)
	check(not fish.controls_locked, "and their fish free")

	print("a seeker's Y:")
	game.start_round(1 - hiding)
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, 3.0)
	await _frames(2)
	check(game.role_of(fish) == MarcoPoloMatch.Role.SEEKER, "the player seeks")
	check(not bool(camera.get("button_taken")), "the camera has its button back")
	var free_before := bool(camera.get("free_cam"))
	await _tap(&"ball_cam")
	check(bool(camera.get("free_cam")) != free_before and not game.is_parked(), "Y swaps follow and free cam")

	print("after the match:")
	main.set_mode(main.FREE_SWIM)
	await _frames(3)
	check(fish.rl_surface_mechanics == own_surfaces, "the player's own surface setting is back")
	check(not bool(camera.get("button_taken")), "the camera's button is its own")
	_finish()


func _stick(direction: Vector2) -> void:
	for pair: Array in [[&"stick_right", direction.x], [&"stick_left", -direction.x], [&"stick_down", direction.y], [&"stick_up", -direction.y]]:
		if float(pair[1]) > 0.01:
			Input.action_press(pair[0], float(pair[1]))
		else:
			Input.action_release(pair[0])


func _finish() -> void:
	print("marco_watch_probe: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


func _tap(action: StringName) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _until(done: Callable, seconds: float) -> void:
	for i in roundi(seconds * 120):
		if done.call():
			return
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
