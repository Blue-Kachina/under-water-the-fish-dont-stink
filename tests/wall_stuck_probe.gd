## Drives into the side wall at a spread of speeds and angles, lets go, and
## watches what the fish itself does: how deep its hull sinks into the arena,
## whether it shakes (spin reversing tick to tick), and how it comes down the
## wall. Looks for the fish getting caught on a wall.
## Run headless: Godot_console.exe --headless --path . res://tests/wall_stuck_probe.tscn
extends Node

const RUNS := [
	{"name": "slow, square on", "x": 37.0, "angle": 0.0, "boost": false, "hold": 1.6},
	{"name": "medium, square on", "x": 32.0, "angle": 0.0, "boost": false, "hold": 2.0},
	{"name": "fast, square on", "x": 22.0, "angle": 0.0, "boost": false, "hold": 2.4},
	{"name": "boost, square on", "x": 22.0, "angle": 0.0, "boost": true, "hold": 1.8},
	{"name": "slow, 45 deg", "x": 36.0, "angle": 45.0, "boost": false, "hold": 1.8},
	{"name": "medium, 45 deg", "x": 30.0, "angle": 45.0, "boost": false, "hold": 2.2},
	{"name": "fast, 70 deg", "x": 30.0, "angle": 70.0, "boost": false, "hold": 2.6},
	{"name": "medium, held on", "x": 32.0, "angle": 0.0, "boost": false, "hold": 6.0},
]
const RUN_TIME := 6.5

var main: Node
var fish: FishController
var hull: CollisionShape3D
var run := -1
var t := 0.0
var r := {}
var last_spin := Vector3.ZERO

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Aquarium Arena", false)
	fish = main.get_node("Fish")
	hull = fish.get_node("WorldHull")
	next_run()

func next_run() -> void:
	if run >= 0:
		if r.outside > 0:
			print("FAIL %s: fish centre outside the arena for %d ticks" % [RUNS[run].name, r.outside])
		print("%-20s deepest into arena %.3f m (%s) | shaking: %3d spin reversals, max pitch/roll spin %.1f rad/s | after letting go: %.2f s on the wall, slid down %s m/s avg, wheels %s | end height %.2f, up.y %.2f" % [
			RUNS[run].name, r.depth, r.depth_at, r.flips, r.max_spin, r.wall_time,
			"%.2f" % (r.slide / r.slide_n) if r.slide_n > 0 else "-", r.wheels, fish.global_position.y, fish.global_basis.y.y])
	run += 1
	if run >= RUNS.size():
		get_tree().quit()
		return
	var spec: Dictionary = RUNS[run]
	t = 0.0
	r = {"outside": 0, "depth_at": "", "depth": 0.0, "flips": 0, "max_spin": 0.0, "wall_time": 0.0, "slide": 0.0, "slide_n": 0, "wheels": {}}
	last_spin = Vector3.ZERO
	fish.set_spawn(Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0 + spec.angle)), Vector3(spec.x, 0.4, 10.0)))
	Input.action_press("thrust_forward")
	if spec.boost:
		Input.action_press("boost")

func depth() -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull.shape
	query.transform = hull.global_transform
	query.exclude = [fish.get_rid()]
	var pairs := fish.get_world_3d().direct_space_state.collide_shape(query, 16)
	var deepest := 0.0
	for i in range(0, pairs.size(), 2):
		deepest = maxf(deepest, (pairs[i] - pairs[i + 1]).length())
	return deepest

func _physics_process(delta: float) -> void:
	if run < 0 or run >= RUNS.size():
		return
	t += delta
	var spec: Dictionary = RUNS[run]
	if t >= spec.hold:
		Input.action_release("thrust_forward")
		Input.action_release("boost")
	# Outside the arena's box at all (centre past a wall, under the floor or over the ceiling)?
	var p := fish.global_position
	var half := AquariumArena.SIZE / 2.0
	if p.y < 0.0 or p.y > AquariumArena.SIZE.y or absf(p.x) > half.x:
		r.outside += 1
	if t > 0.3:
		var d := depth()
		if d > r.depth:
			r.depth = d
			r.depth_at = "t %.2f at %s up.y %.2f v %.1f wheels %d" % [t, fish.global_position.snapped(Vector3.ONE * 0.01), fish.global_basis.y.y, fish.linear_velocity.length(), fish.wheels_touching]
	var spin := fish.global_basis.transposed() * fish.angular_velocity
	for i in 3:
		if absf(spin[i]) > 0.3 and absf(last_spin[i]) > 0.3 and signf(spin[i]) != signf(last_spin[i]):
			r.flips += 1
	last_spin = spin
	r.max_spin = maxf(r.max_spin, Vector2(spin.x, spin.z).length())
	if t >= spec.hold and fish.global_position.y > 1.0:
		r.wheels[fish.wheels_touching] = r.wheels.get(fish.wheels_touching, 0) + 1
		if fish.on_surface and fish.surface_normal.x < -0.7:
			r.wall_time += delta
			r.slide += -fish.linear_velocity.y
			r.slide_n += 1
	if t >= RUN_TIME:
		next_run()
