extends Node
## The Look Tank (LookTank, planning_abyssal_look.md phase 0): it starts the
## Test Tank, finds its places on the seabed, jumps to every viewpoint (the
## camera moves, the fish are held, the split view has its players) and back,
## the console's look_view and look_tank are there, and WaterLook's Sunlit
## preset copies abyssal-garden's constants (and Ours puts ours back).
##   Godot_console.exe --headless --path . res://tests/look_tank_probe.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var look := WaterLook.shared()
	print("WaterLook:")
	look.preset = WaterLook.Preset.SUNLIT
	check(look.sig() == WaterLook.SUNLIT_SIG and look.wcol() == WaterLook.SUNLIT_WCOL, "Sunlit copies their constants")
	check(is_equal_approx(look.fade_end, 230.0), "Sunlit fades out at 230 m")
	look.preset = WaterLook.Preset.OURS
	check(look.sig() == WaterLook.OURS_SIG and look.kd() == WaterLook.OURS_KD, "Ours puts ours back")

	print("the tank:")
	var tank: LookTank = load("res://scenes/look_tank.tscn").instantiate()
	add_child(tank)
	for i in 600:
		if tank.is_ready():
			break
		await get_tree().process_frame
	check(tank.is_ready(), "it starts")
	if not tank.is_ready():
		get_tree().quit(1)
		return
	check(tank.run != null and tank.run.test_tank, "on the Test Tank")
	check(Console.has_command("look_view"), "the console has look_view")
	check(tank.main.has_method("_cmd_look_tank") and Console.has_command("look_tank"), "and look_tank")
	for key: String in ["kelp", "ruin", "reef"]:
		var at: Vector3 = tank.spots[key]
		check(at.distance_to(tank.spots.centre) > 20.0, "%s found %.0f m from the middle" % [key, at.distance_to(tank.spots.centre)])
	var fish: FishController = tank.main.get_node("Fish")
	for n in range(1, LookTank.COUNT):
		tank.go(n)
		var pose := tank.pose_of(n)
		check(tank.camera.current and tank.camera.global_position.is_equal_approx(pose[0]), "view %d (%s): the camera is there" % [n, LookTank.NAMES[n - 1]])
		check(fish.freeze, "view %d: the fish is held" % n)
	tank.go(LookTank.COUNT)
	for i in 30:
		await get_tree().physics_frame
	check(tank.main._local.count() == WaterLook.shared().tank_split_players, "view 6 has %d players" % tank.main._local.count())
	check(not tank.camera.current, "view 6 uses the players' cameras")
	var a: FishController = tank.main._local.slots[0].fish
	var b: FishController = tank.main._local.slots[1].fish
	check(a.global_position.distance_to(b.global_position) > 5.0, "and they stand apart (%.0f m)" % a.global_position.distance_to(b.global_position))
	check(Console.run_command("look_view 1") != "" and tank.view == 1 and tank.main._local.count() == 1, "look_view 1 leaves the split")
	tank.go(0)
	check(not tank.camera.current and not fish.freeze, "view 0 gives the game's camera back")
	print("\n%s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)
