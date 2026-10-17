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


func _ready() -> void:
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

	print("boost button:")
	Input.action_press("boost")
	await _ticks(3)
	check(fish.direction_lock_held and not fish.is_boosting, "boost holds the direction lock instead")
	Input.action_release("boost")
	await _ticks(3)
	check(not fish.direction_lock_held, "letting go lets go of the lock")

	print("slow bump:")
	await _ram(run, 5.0)
	check(run.battered_fish == 0 and not run.target.battered, "a slow bump doesn't batter it")

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
	fish.linear_velocity = Vector3.ZERO  # stop coasting off, so "nearby" means where it appeared
	await _ticks(roundi((NatureRun.RESPAWN_TIME + 0.3) * 120.0))
	gap = fish.global_position.distance_to(run.target.global_position)
	check(not run.target.battered and run.target.visible, "a new one turns up")
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

	print("leaving:")
	main.set_mode(main.FREE_SWIM)
	await _ticks(3)
	check(main.nature_run == null and camera.ball == null, "the run's over")
	check(fish.swim_style == FishController.SwimStyle.ORIGINAL and fish.boost_enabled and not fish.bow_wave and not fish.boost_button_locks,
			"Original strokes, boost (as boost) and no bow wave back")
	check(is_equal_approx(fish.max_speed, max_speed_before), "the tuning from before is back (max_speed %.1f)" % fish.max_speed)

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
