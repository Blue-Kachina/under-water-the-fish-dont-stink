## Checks the Ocean environment: nothing solid to hit, endless swimming, and
## switching back to the obstacle course.
## Run headless: Godot_console.exe --headless --path . res://tests/ocean_probe.tscn
extends Node

var main: Node
var fish: FishController
var t := 0.0
var events := {}

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean", false)
	fish = main.get_node("Fish")

func once(key: String, at: float) -> bool:
	if t >= at and not events.has(key):
		events[key] = true
		return true
	return false

func count_solids(node: Node) -> int:
	var total := 1 if node is StaticBody3D else 0
	for child in node.get_children():
		total += count_solids(child)
	return total

func _physics_process(delta: float) -> void:
	t += delta
	if once("check", 0.2):
		print("ocean: solid bodies in world = %d, fish at %s" % [count_solids(main), fish.global_position])
		Input.action_press("thrust_forward"); Input.action_press("boost")
	if once("far", 8.2):
		print("ocean: after 8s of boost, fish at (%.0f, %.0f, %.0f), %.0f m from spawn, speed %.1f m/s" % [fish.global_position.x, fish.global_position.y, fish.global_position.z, fish.global_position.length(), fish.speed])
		Input.action_release("thrust_forward"); Input.action_release("boost")
		main.set_environment("Obstacle Course", false)
	if once("back", 8.4):
		print("switched back: environment=%s, solid bodies=%d, fish at %s" % [main.current_environment, count_solids(main), fish.global_position])
	if once("quit", 8.5): get_tree().quit()
