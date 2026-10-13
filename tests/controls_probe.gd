## Prints each controller profile's button bindings, then checks the Personal
## profile's shared LB (pressed as a real controller button): off a surface it
## powerslides and turns stick left/right into roll (free air roll); on the
## floor it powerslides and the stick still steers.
## Run headless: Godot_console.exe --headless --path . res://tests/controls_probe.tscn
extends Node

var fish: FishController
var t := 0.0
var events := {}
var saved_profile := ""
var failures := 0

func _ready() -> void:
	saved_profile = Controls.current_profile
	for profile in Controls.profile_names():
		Controls.apply_profile(profile, false)
		var lines := []
		for action: String in Controls.BUTTON_KEYS:
			var pads := InputMap.action_get_events(action).filter(func(e: InputEvent) -> bool: return e is InputEventJoypadButton)
			lines.append("%s=%s" % [action, "-" if pads.is_empty() else _button_name(pads[0].button_index)])
		print("%-9s %s" % [profile, "  ".join(lines)])
	Controls.apply_profile("Personal", false)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Aquarium Arena")
	fish = main.get_node("Fish")

func _button_name(index: int) -> String:
	return {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"}.get(index, str(index))

func once(key: String, at: float) -> bool:
	if t >= at and not events.has(key):
		events[key] = true
		return true
	return false

func press_lb(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_LEFT_SHOULDER
	event.pressed = pressed
	Input.parse_input_event(event)

## Spin in the fish's frame: x = pitch, y = yaw, z = roll (magnitudes, rad/s).
func local_spin() -> Vector3:
	return (fish.global_basis.inverse() * fish.angular_velocity).abs()

func check(ok: bool, text: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		failures += 1

func _physics_process(delta: float) -> void:
	t += delta
	if once("air", 0.2):
		# Mid-air, upright, not spinning.
		fish.buoyancy = 0.0
		fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 12, 0)))
		press_lb(true)
		Input.action_press("stick_right")
	if once("air check", 0.45):
		var spin := local_spin()
		print("Personal LB + stick right in the air: powerslide=%s air roll=%s, roll %.2f rad/s, yaw %.2f rad/s" % [
			fish.powerslide_held, fish.air_roll_held, spin.z, spin.y])
		check(fish.air_roll_held and spin.z > 2.0 and spin.y < 0.2, "LB air-rolls in the air")
		press_lb(false)
		Input.action_release("stick_right")
	if once("air release", 0.5):
		check(not fish.air_roll_held and not fish.powerslide_held, "LB release clears both actions")
		# On the floor, upright, driving forward.
		fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)))
		Input.action_press("thrust_forward")
	if once("ground", 1.5):
		press_lb(true)
		Input.action_press("stick_right")
	if once("ground check", 1.8):
		var spin := local_spin()
		print("Personal LB + stick right on the floor: on surface %s, powersliding=%s, yaw %.2f rad/s, roll %.2f rad/s, up . world up %.2f" % [
			fish.on_surface, fish.is_powersliding, spin.y, spin.z, fish.global_basis.y.dot(Vector3.UP)])
		check(fish.on_surface and fish.is_powersliding and spin.y > 1.0 and spin.z < 0.5, "LB powerslides on the floor and the stick still steers")
	if once("quit", 1.9):
		press_lb(false)
		Input.action_release("stick_right")
		Input.action_release("thrust_forward")
		Controls.apply_profile(saved_profile, false)
		print("controls probe: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		get_tree().quit()
