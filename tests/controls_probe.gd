## Prints each controller profile's button bindings, then checks the Personal
## profile's powerslide works in open water.
## Run headless: Godot_console.exe --headless --path . res://tests/controls_probe.tscn
extends Node

var fish: FishController
var t := 0.0
var events := {}
var saved_profile := ""

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
	main.set_environment("Obstacle Course", false)
	fish = main.get_node("Fish")

func _button_name(index: int) -> String:
	return {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_RIGHT_STICK: "R3"}.get(index, str(index))

func once(key: String, at: float) -> bool:
	if t >= at and not events.has(key):
		events[key] = true
		return true
	return false

func _physics_process(delta: float) -> void:
	t += delta
	if once("start", 0.2):
		fish.global_position = Vector3(0, 32, 70)
		Input.action_press("powerslide")
	if once("check", 0.4):
		print("Personal: powerslide held in open water -> powersliding=%s" % fish.is_powersliding)
	if once("quit", 0.5):
		Input.action_release("powerslide")
		Controls.apply_profile(saved_profile, false)
		get_tree().quit()
