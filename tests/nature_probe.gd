extends Node
## Nature mode: its card with the fish sitting out and Nature's tuning on;
## Play starts a run with a target fish that ball cam locks onto; a fast ram
## batters it and a new one turns up nearby, a slow bump doesn't; leaving
## Nature puts the tuning from before back.
##   Godot_console.exe --headless --path . res://tests/nature_probe.tscn

var main: Node
var fish: FishController
var camera: Node
var failures := 0
var snaps: Array[Dictionary] = []
var record := false
const BASELINE := "res://tests/fixtures/nature_baseline.json"


func _ready() -> void:
	# Fixed seed; --record rewrites tests/fixtures/nature_baseline.json (the migration's fixture).
	seed(20261121)
	record = "--record" in OS.get_cmdline_args() or "--record" in OS.get_cmdline_user_args()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	print("card:")
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	var max_speed_before := fish.max_speed
	main.set_mode(main.NATURE)
	await _ticks(3)
	check(main.current_environment == "Ocean", "Nature plays in the Ocean")
	check(main._match_card != null and main.nature_run == null and not fish.visible, "waits on its card, fish sitting out")
	check(fish.swim_style == FishController.SwimStyle.EXTRA_SWISHY and not fish.boost_enabled, "Nature's tuning: Extra Swishy, no boost")
	_snap("card")

	print("run:")
	main._match_card.play_requested.emit()
	await _ticks(5)
	var run: NatureRun = main.nature_run
	check(run != null and main._match_card == null and fish.visible, "Play starts the run, fish back")
	check(is_instance_valid(run.target) and run.target.visible and not run.target.battered, "a target fish is out")
	check(camera.ball == run.target and camera.ball_cam, "ball cam locked on the target")
	var gap := fish.global_position.distance_to(run.target.global_position)
	check(gap > 20.0 and gap < 40.0, "the target waits ahead (%.1f m)" % gap)
	check(main._reset_label() == "Restart", "reset restarts the run")
	_snap("run_start")

	print("boost button:")
	Input.action_press("boost")
	await _ticks(3)
	check(fish.direction_lock_held and not fish.is_boosting, "boost holds the direction lock instead")
	Input.action_release("boost")
	await _ticks(3)
	check(not fish.direction_lock_held, "letting go lets go of the lock")
	_snap("boost_released")

	print("slow bump:")
	await _ram(run, 5.0)
	check(run.battered_fish == 0 and not run.target.battered, "a slow bump doesn't batter it")
	_snap("slow_bump")

	print("bow wave:")
	check(fish.bow_wave and not run.target.bow_wave, "Nature's fish has a bow wave, the target doesn't")
	var target := run.target
	var heading := -target.global_basis.z
	var half := (fish.get_node("Collision").shape as BoxShape3D).size.z / 2.0
	# Centres apart by the hitboxes' length plus 0.8 m: beyond them, within a full bow.
	fish.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), target.global_position - heading * (half * 2.0 + 0.8))
	fish.bow_amount = 0.0
	check(not Battery.touching(fish, target), "0.8 m short: the hitboxes don't touch")
	fish.bow_amount = 1.0
	check(Battery.touching(fish, target), "...but a full bow wave does")
	fish.bow_amount = 0.0
	await _ticks(3)
	fish.linear_velocity = Vector3.ZERO

	print("battery:")
	await _ram(run, fish.nature_batter_speed + 6.0)
	check(run.battered_fish == 1 and run.target.battered, "a fast ram batters it (%.1f m/s)" % run.last_battery_speed)
	_snap("battery")
	fish.linear_velocity = Vector3.ZERO  # stop coasting off, so "nearby" means where it appeared
	await _ticks(roundi((NatureRun.RESPAWN_TIME + 0.3) * 120.0))
	gap = fish.global_position.distance_to(run.target.global_position)
	check(not run.target.battered and run.target.visible, "a new one turns up")
	_snap("respawn")
	check(gap >= NatureRun.RESPAWN_DISTANCE.x - 2.0 and gap <= NatureRun.RESPAWN_DISTANCE.y + 2.0, "nearby (%.1f m)" % gap)

	print("wandering:")
	var from := run.target.global_position
	await _ticks(360)  # from rest: it eases up to its pace
	var wandered := run.target.global_position.distance_to(from)
	check(wandered > 3.0 and run.target.speed < 15.0, "the target cruises calmly (%.1f m in 3 s, %.1f m/s)" % [wandered, run.target.speed])

	print("bow growth:")
	fish.global_position = run.target.global_position + Vector3(0, 40, 0)  # well clear of it
	fish.linear_velocity = -fish.global_basis.z * fish.bow_full_speed
	await _ticks(30)
	var grown := fish.bow_amount
	fish.linear_velocity = Vector3.ZERO
	await _ticks(90)
	check(grown > 0.5 and fish.bow_amount < 0.05, "it grows with speed (%.2f at %.0f m/s) and goes when slow (%.2f)" % [grown, fish.bow_full_speed, fish.bow_amount])
	_snap("bow_growth")

	print("leaving:")
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	check(main.nature_run == null and camera.ball == null, "the run's over")
	check(fish.swim_style == FishController.SwimStyle.ORIGINAL and fish.boost_enabled and not fish.bow_wave and not fish.boost_button_locks,
			"Original strokes, boost (as boost) and no bow wave back")
	check(is_equal_approx(fish.max_speed, max_speed_before), "the tuning from before is back (max_speed %.1f)" % fish.max_speed)
	_snap("leaving")

	_finish_baseline()
	print("nature_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## The player 2.5 m behind the target, nose on, at `speed` (m/s), for a moment.
func _ram(run: NatureRun, speed: float) -> void:
	var target := run.target
	var heading := -target.global_basis.z
	var at := target.global_position - heading * 2.5
	fish.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), at)
	fish.linear_velocity = heading * speed
	fish.angular_velocity = Vector3.ZERO
	await _ticks(30)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## One row of the baseline: coarse run state at a named moment of the script
## (counts, flags and tuning, nothing that depends on a frame landing one tick either side).
func _snap(label: String) -> void:
	var run: NatureRun = main.nature_run
	var row := {
		"at": label,
		"mode": main.current_mode,
		"playing_mode": main._playing_mode(),
		"run": run != null,
		"card": main._match_card != null,
		"fish_visible": fish.visible,
		"swim_style": FishController.SwimStyle.keys()[fish.swim_style],
		"boost_enabled": fish.boost_enabled,
		"bow_wave": fish.bow_wave,
		"locked": fish.direction_lock_held,
		"camera_ball": camera.ball != null,
		"camera_ball_cam": camera.ball_cam,
		"hold_wheel": camera.hold_opens_wheel,
		"reset_label": main._reset_label(),
	}
	if run != null:
		row["battered_fish"] = run.battered_fish
		row["pearls"] = run.pearls
		row["points"] = run.score_of(fish).points
		row["target_out"] = is_instance_valid(run.target) and run.target.battered
		row["ball_on_target"] = camera.ball == run.target
		row["players"] = run.players.size()
		row["schools"] = run.schools.size() > 0
		row["hud_run"] = main._hud.mode_hud is NatureHud and (main._hud.mode_hud as NatureHud).run == run
	snaps.append(row)


func _same_row(a: Variant, b: Variant) -> bool:
	return a == b


## --record writes the baseline; otherwise the run is diffed against it.
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
		if not _same_row(a, b):
			bad += 1
			print("    baseline differs: want %s got %s" % [a, b])
	check(bad == 0, "matches nature_baseline.json (%d snapshots)" % snaps.size())
