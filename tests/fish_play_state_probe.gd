extends Node
## FishController.play_state / modifiers / capabilities (planning_core_roadmap.md H5):
## HELD and LIVE follow controls_locked, OUT is batter() (layers saved and put
## back by revive(), the lock remembered through it), modifiers multiply and
## pop back to 1.0, capabilities restore exactly what they saved, and
## nature_batter_speed reads BatterySettings.
##   Godot_console.exe --headless --path . res://tests/fish_play_state_probe.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _ready() -> void:
	var fish: FishController = load("res://scenes/fish.tscn").instantiate()
	add_child(fish)
	await get_tree().physics_frame
	check(fish.play_state == FishController.PlayState.LIVE, "starts LIVE")
	fish.play_state = FishController.PlayState.HELD
	check(fish.controls_locked and fish.play_state == FishController.PlayState.HELD, "HELD is controls_locked")
	fish.controls_locked = false
	check(fish.play_state == FishController.PlayState.LIVE, "controls_locked = false is LIVE")
	var layer := fish.collision_layer
	var mask := fish.collision_mask
	fish.play_state = FishController.PlayState.HELD
	fish.play_state = FishController.PlayState.OUT
	check(fish.battered and not fish.visible and fish.collision_layer == 0 and fish.collision_mask == 0, "OUT is battered: hidden, no collisions")
	check(fish.play_state == FishController.PlayState.OUT, "reads OUT")
	fish.revive(fish.global_transform)
	check(fish.collision_layer == layer and fish.collision_mask == mask and fish.visible and not fish.battered, "revive restores the layers")
	check(fish.play_state == FishController.PlayState.HELD, "the lock survived OUT")
	fish.play_state = FishController.PlayState.LIVE
	fish.join_team(1, Color.RED)
	check(fish.team == 1 and fish.team_color == Color.RED, "join_team")
	fish.leave_team()
	check(fish.team == -1 and fish.team_color == Color.TRANSPARENT, "leave_team")

	var speed := fish.speed_scale
	fish.modifiers.push("a", {"speed": 1.5, "stride": 2.0})
	fish.modifiers.push("b", {"speed": 2.0})
	check(is_equal_approx(fish.speed_scale, speed * 3.0) and is_equal_approx(fish.stride_scale, 2.0), "modifiers multiply")
	fish.modifiers.pop("a")
	check(is_equal_approx(fish.speed_scale, 2.0) and is_equal_approx(fish.stride_scale, 1.0), "pop leaves the other set")
	fish.modifiers.pop("b")
	check(is_equal_approx(fish.speed_scale, 1.0), "all popped is 1.0")

	var boost := fish.boost_enabled
	var jump := fish.ignore_jump
	fish.capabilities.push("x", {"boost": false, "jump": false})
	check(not fish.boost_enabled and fish.ignore_jump, "capabilities applied")
	fish.capabilities.pop("x")
	check(fish.boost_enabled == boost and fish.ignore_jump == jump, "capabilities restored")

	fish.nature_batter_speed = 17.0
	check(is_equal_approx(BatterySettings.shared().batter_speed, 17.0), "nature_batter_speed writes BatterySettings")
	print("fish_play_state_probe: ", "all checks passed" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures else 0)
