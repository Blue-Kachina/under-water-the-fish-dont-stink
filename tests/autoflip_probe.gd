## Rocket League auto-flip: lying upside down on the floor, a jump press hops
## off and rolls the fish back onto its belly. Without the jump, it stays over.
## Run headless: Godot_console.exe --headless --path . res://tests/autoflip_probe.tscn
extends Node

var main: Node
var fish: FishController
var t := 0.0
var events := {}

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Aquarium Arena", false)
	fish = main.get_node("Fish")

func once(key: String, at: float) -> bool:
	if t >= at and not events.has(key):
		events[key] = true
		return true
	return false

func upright() -> float:
	return fish.global_basis.y.dot(Vector3.UP)

func _physics_process(delta: float) -> void:
	t += delta
	for run in 2:  # 0: just roll input; 1: jump (auto-flip)
		var at := 0.1 + run * 4.0
		if once("spawn %d" % run, at):
			# Upside down (rolled 180 degrees about the nose), a little off the floor, beside the kickoff spot.
			fish.set_spawn(Transform3D(Basis(Vector3.FORWARD, PI), Vector3(-20, 1.0, 20)))
		if once("settle %d" % run, at + 1.5):
			print("run %d settled: up . world up %.2f, roof contact %s, on surface %s" % [run, upright(), fish._roof_normal != Vector3.ZERO, fish.on_surface])
			if run == 0:
				Input.action_press("roll_right")
			else:
				Input.action_press("jump")
		if once("release %d" % run, at + 1.6):
			Input.action_release("jump")
		if once("read %d" % run, at + 3.5):
			Input.action_release("roll_right")
			print("run %d (%s): after 2 s up . world up %.2f, on surface %s" % [run, "roll input only" if run == 0 else "jump = auto-flip", upright(), fish.on_surface])
	if once("quit", 8.2):
		get_tree().quit()
