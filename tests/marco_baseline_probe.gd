extends Node
## Marco Polo characterisation (mig-marco M0): a scripted run of the mode through
## the host (card with its pickers, Play, countdown, live, a bot's tag that sends
## the player to spectate, round over, leaving, then the online host / guest / solo
## entry points) with coarse state rows recorded to tests/fixtures/marco_baseline.json.
## The migration (GameMode, ModeHud, camera claim, ModeData) must keep every row.
##   Godot_console.exe --headless --path . res://tests/marco_baseline_probe.tscn [-- --record]

const TICKS := 120

var main: Node
var fish: FishController
var camera: Node
var failures := 0
var snaps: Array[Dictionary] = []
var record := false
var mp: MarcoPoloSettings
const BASELINE := "res://tests/fixtures/marco_baseline.json"


func _ready() -> void:
	seed(20261122)
	record = "--record" in OS.get_cmdline_args() or "--record" in OS.get_cmdline_user_args()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	mp = MarcoPoloSettings.shared()
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	mp.whale_seeker = false
	mp.arena = "Sunken Temple"
	mp.hide_time = 0.5
	mp.round_time = 60.0
	mp.round_over_time = 0.5
	mp.min_players = 4
	mp.rounds = 3
	mp.bot_seeker_rounds = 1
	mp.variant = MarcoPoloSettings.Variant.ELIMINATION
	mp.start_as = MarcoPoloSettings.StartAs.SEEKER
	var max_speed_before := fish.max_speed
	var boost_before := fish.boost_enabled
	var bow_before := fish.bow_scale

	print("card:")
	main.set_mode(main.NATURE)
	await _ticks(3)
	main._match_card.play_requested.emit()
	await _ticks(3)
	main._local.join(7)
	await _ticks(3)
	main.set_mode(main.MARCO_POLO)
	await _ticks(5)
	_snap("card")
	check(main.current_environment == "Sunken Temple", "plays in the arena picked")
	check(main._playing_mode() == "", "not playing on the card")

	print("play:")
	main._match_card.play_requested.emit()
	await _ticks(5)
	var game: MarcoPoloMatch = main.marco_polo
	check(game != null, "Play starts the match")
	if game == null:
		_finish()
		return
	_still_bots(game)
	_snap("play")
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, 5.0)
	_snap("live_seeker")

	print("a bot seeks, the player hides:")
	game.start_round(1)
	await _ticks(2)
	_still_bots(game)
	_snap("round2_countdown")
	await _until(func() -> bool: return game.phase == MarcoPoloMatch.Phase.LIVE, 5.0)
	_snap("round2_live")
	var seeker: FishController = game.seekers()[0]
	game.tag(seeker, fish)
	await _ticks(10)
	_snap("tagged_spectating")
	game.cycle_spectate(1)
	await _ticks(10)
	_snap("spectate_cycled")

	print("leaving:")
	main.set_mode(main.FREE_SWIM)
	await _ticks(5)
	check(main.marco_polo == null, "the match is over")
	_snap("left")
	check(is_equal_approx(fish.max_speed, max_speed_before) and fish.boost_enabled == boost_before and is_equal_approx(fish.bow_scale, bow_before),
			"the player's own tuning is back")

	print("online entry points:")
	main.host_marco_polo()
	await _ticks(10)
	_snap("host")
	main.host_marco_polo()
	await _ticks(2)
	_snap("host_again")
	main.guest_marco_polo("Sunken Temple")
	await _ticks(10)
	_snap("guest")
	main.solo_marco_polo()
	await _ticks(10)
	_snap("solo")
	main.set_mode(main.FREE_SWIM)
	await _ticks(5)
	_snap("left_again")

	_finish_baseline()
	_finish()


func _finish() -> void:
	print("marco_baseline_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


func _still_bots(game: MarcoPoloMatch) -> void:
	for bot: Node in game.bots.values():
		bot.process_mode = Node.PROCESS_MODE_DISABLED
		var input: Variant = bot.get("input")
		if input is FishInput:
			(input as FishInput).clear()


func _until(done: Callable, seconds: float) -> void:
	for i in roundi(seconds * TICKS):
		if done.call():
			return
		await get_tree().physics_frame


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## One row of the baseline: coarse state at a named moment (flags, counts and
## rounded tuning, nothing that depends on a frame landing one tick either side).
func _snap(label: String) -> void:
	var game: MarcoPoloMatch = main.marco_polo
	var pose: Variant = camera.get("pose_override")
	var hud: CanvasLayer = main._hud
	var row := {
		"at": label,
		"mode": main.current_mode,
		"playing_mode": main._playing_mode(),
		"environment": main.current_environment,
		"mode_environment": main.mode_environment(main.MARCO_POLO),
		"match": game != null,
		"card": main._match_card != null,
		"card_choices": _card_choices(),
		"card_note": main._match_card != null and main._match_card.note != "",
		"no_split": main._local.no_split_screen,
		"can_join": main._local.can_join(),
		"players_local": main._local.count(),
		"fish_visible": fish.visible,
		"reset_label": main._reset_label(),
		"boost": fish.boost_enabled,
		"bow": snappedf(fish.bow_scale, 0.01),
		"buoyancy": snappedf(fish.buoyancy, 0.01),
		"locked": fish.controls_locked,
		"team": fish.team,
		"cam_pose_override": pose is Callable and (pose as Callable).is_valid(),
		"cam_button_taken": bool(camera.get("button_taken")),
		"cam_ball_cam": camera.ball_cam,
		"cam_hold_wheel": camera.hold_opens_wheel,
		"cam_target": camera.get("target") != null,
		"cam_ball": camera.ball != null,
		"hud_survivor_cam": hud.survivor_cam,
		"hud_plate_filter": hud.plate_filter.is_valid(),
		"console": Console.has_command("mp_role"),
	}
	if game != null:
		row["authority"] = game.authority
		row["phase"] = MarcoPoloMatch.Phase.keys()[game.phase]
		row["round"] = game.round_index
		row["players"] = game.players.size()
		row["bots"] = game.bots.size()
		row["seekers"] = game.seekers().size()
		row["live_hiders"] = game.live_hiders().size()
		row["local_role"] = MarcoPoloMatch.Role.keys()[game.local_view_role()]
		row["eliminated"] = game.eliminated.size()
		row["spectating"] = game.is_spectating()
		row["has_hud_node"] = game.get_node_or_null("MarcoPoloHud") != null
		row["has_looks_node"] = game.get_node_or_null("HiderLooks") != null
		row["parent_is_env"] = game.get_parent() == main._environment
	snaps.append(row)


func _card_choices() -> Array:
	var out := []
	if main._match_card != null:
		for choice: Dictionary in main._match_card.choices:
			out.append("%s:%s" % [choice.title, ",".join(PackedStringArray(choice.options))])
	return out


func _finish_baseline() -> void:
	var path := ProjectSettings.globalize_path(BASELINE)
	if record:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var out := FileAccess.open(path, FileAccess.WRITE)
		out.store_string(JSON.stringify({"snaps": snaps}, "	", true))
		out.close()
		print("  baseline recorded: %s (%d snapshots)" % [path, snaps.size()])
		return
	if not FileAccess.file_exists(BASELINE):
		check(false, "no baseline at %s (run with --record)" % BASELINE)
		return
	var want: Array = JSON.parse_string(FileAccess.get_file_as_string(BASELINE)).snaps
	var got: Array = JSON.parse_string(JSON.stringify({"snaps": snaps})).snaps
	var bad := 0
	for i in maxi(want.size(), got.size()):
		var a: Variant = want[i] if i < want.size() else null
		var b: Variant = got[i] if i < got.size() else null
		if a != b:
			bad += 1
			print("    baseline differs: want %s got %s" % [a, b])
	check(bad == 0, "matches marco_baseline.json (%d snapshots)" % snaps.size())
