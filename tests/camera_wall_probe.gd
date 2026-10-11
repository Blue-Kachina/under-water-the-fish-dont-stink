## The chase camera never ends up inside or skimming a wall: fish hugging the
## side wall with the camera swung toward it, and fish pressed up under the
## ceiling (where the camera's aim point would be inside it). Reports the
## camera's clearance from solid geometry each time. Then drives along the
## side wall, where the camera should roll with the fish (as RL's does), and
## jumps clear, where it should ease back to a level horizon.
## Run headless: Godot_console.exe --headless --path . res://tests/camera_wall_probe.tscn
extends Node

var main: Node
var fish: FishController
var camera: Camera3D
var t := 0.0
var events := {}
var worst := INF

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Aquarium Arena", false)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")

func once(key: String, at: float) -> bool:
	if t >= at and not events.has(key):
		events[key] = true
		return true
	return false

## Largest of a few test radii that fits around the camera without touching anything solid.
func clearance() -> float:
	var space := camera.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, camera.global_position)
	query.exclude = [fish.get_rid()]
	for r in [0.4, 0.3, 0.2, 0.1, 0.05]:
		sphere.radius = r
		if space.intersect_shape(query, 1).is_empty():
			return r
	return 0.0

func _process(_delta: float) -> void:
	if t > 0.6:
		worst = minf(worst, clearance())

func _physics_process(delta: float) -> void:
	t += delta
	var wall_x := AquariumArena.SIZE.x / 2.0
	if once("wall", 0.1):
		# Right side against the +X wall, facing -Z; swing the camera to look at the fish from the wall side.
		fish.buoyancy = 0.0
		fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(wall_x - 0.6, 3.0, 0)))
		Input.action_press("camera_left")
	if once("wall read", 2.0):
		print("against the side wall, camera swung toward it: camera at x %.2f (wall at %.2f), worst clearance %.2f m" % [camera.global_position.x, wall_x, worst])
		Input.action_release("camera_left")
		worst = INF
		fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0, AquariumArena.SIZE.y - 0.4, 0)))
	if once("ceiling read", 3.5):
		print("pressed under the ceiling: camera at y %.2f (ceiling at %.2f), worst clearance %.2f m" % [camera.global_position.y, AquariumArena.SIZE.y, worst])
		# On the +X wall, wheels to it (up = -X), facing -Z, driving along it.
		fish.set_spawn(Transform3D(Basis(Vector3.UP, Vector3.LEFT, Vector3.BACK), Vector3(wall_x - 0.4, 6.0, 20.0)))
		Input.action_press("thrust_forward")
	if once("on wall", 5.0):
		var camera_up := camera.global_basis.y
		print("driving along the side wall: on surface %s, camera up . fish up %.2f, camera up . world up %.2f" % [fish.on_surface, camera_up.dot(fish.global_basis.y), camera_up.dot(Vector3.UP)])
		Input.action_release("thrust_forward")
		# Clear of the wall in mid-air, upright: the camera starts rolled and should level out.
		fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 10.0, 0)))
	if once("leaving", 5.25):
		print("0.25 s after leaving it: camera up . world up %.2f" % camera.global_basis.y.dot(Vector3.UP))
	if once("left", 6.5):
		print("1.5 s after leaving it: camera up . world up %.2f" % camera.global_basis.y.dot(Vector3.UP))
		get_tree().quit()
