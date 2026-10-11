## Rocket League surface mechanics in the aquarium: resting on the floor,
## throttle and boost top speeds, ground turn rate, driving up the rounded side
## wall, jumping off, landing on the ball (a surface too) and carrying it.
## Run headless: Godot_console.exe --headless --path . res://tests/surface_probe.tscn
extends Node

var main: Node
var fish: FishController
var aquarium: AquariumArena
var t := 0.0
var events := {}
var phase_start := 0.0
var time_to_10 := -1.0
var surfaces_seen := {}
var on_ball := false

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	main.set_environment("Aquarium Arena", false)
	fish = main.get_node("Fish")
	aquarium = main._environment
	fish.boost_unlimited = true
	print("ground: max %.1f, accel %.1f, boost %.1f to %.1f m/s, stick %.1f, buoyancy %.1f" % [
		fish.ground_max_speed, fish.ground_accel, fish.ground_boost_accel, fish.ground_max_boost_speed, fish.surface_stick, fish.buoyancy])

func once(key: String, at: float) -> bool:
	if t >= at and not events.has(key):
		events[key] = true
		return true
	return false

func release_all() -> void:
	for a in ["thrust_forward", "boost", "stick_right", "jump"]:
		Input.action_release(a)

func _surface_label() -> String:
	if not fish.on_surface:
		return "none"
	return "floor" if fish.surface_normal.y > 0.7 else ("ceiling" if fish.surface_normal.y < -0.7 else "wall")

func _physics_process(delta: float) -> void:
	t += delta
	if fish.on_surface:
		surfaces_seen[_surface_label()] = true
		if fish.global_position.y > aquarium.ball.global_position.y and fish.surface_normal.y > 0.3 and aquarium.ball.global_position.distance_to(fish.global_position) < aquarium.ball.settings.radius + 1.5:
			on_ball = true

	if once("spawn", 0.1):
		fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(-20, 0.6, 45)))
	if once("rest", 1.0):
		print("resting: on_surface %s, normal %s, y %.3f, up . world up %.4f" % [fish.on_surface, fish.surface_normal.snapped(Vector3.ONE * 0.01), fish.global_position.y, fish.global_basis.y.dot(Vector3.UP)])
		Input.action_press("thrust_forward")
		phase_start = t
	if time_to_10 < 0.0 and phase_start > 0.0 and fish.speed >= 10.0:
		time_to_10 = t - phase_start
	if once("throttle read", 4.0):
		print("throttle 3 s: speed %.2f m/s (RL max 14.1), 0 -> 10 m/s in %.2f s, on %s at z %.0f" % [fish.speed, time_to_10, _surface_label(), fish.global_position.z])
		release_all()
		fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(-20, 0.6, 45)))
	if once("boost start", 4.3):
		fish.linear_velocity = Vector3(0, 0, -14.1)
		Input.action_press("boost")
	if once("boost read", 5.5):
		print("boost 1.2 s from 14.1: speed %.2f m/s (RL max 23), on %s at z %.0f" % [fish.speed, _surface_label(), fish.global_position.z])
		release_all()
		fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(-20, 0.6, 40)))
	if once("turn start", 5.8):
		fish.linear_velocity = Vector3(0, 0, -14.1)
		Input.action_press("thrust_forward")
		Input.action_press("stick_right")
	if once("turn read", 6.3):
		var local_spin := fish.global_basis.orthonormalized().transposed() * fish.angular_velocity
		print("full right at %.1f m/s: yaw %.2f rad/s (RL about 2.2 at 14.1 m/s), drift %.0f deg, on %s" % [fish.speed, -local_spin.y, fish.drift_angle, _surface_label()])
		release_all()

	# Drive at the side wall (x = -40.96) and up it.
	if once("wall", 7.0):
		fish.set_spawn(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-20, 0.6, 0)))  # facing -X
	if once("wall go", 7.5):
		Input.action_press("thrust_forward")
		Input.action_press("boost")
	for i in 5:
		if once("wall log %d" % i, 8.0 + i * 0.5):
			print("  wall drive t=%.1f: pos (%.1f, %.1f, %.1f) up %s surface %s speed %.1f" % [t - 7.5, fish.global_position.x, fish.global_position.y, fish.global_position.z, fish.global_basis.y.snapped(Vector3.ONE * 0.01), _surface_label(), fish.speed])
	if once("wall read", 10.1):
		print("surfaces driven on so far: %s" % [surfaces_seen.keys()])
		release_all()

	# Jump off the floor.
	if once("jump spawn", 10.5):
		fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(-20, 0.6, 40)))
	if once("jump", 11.5):
		print("before jump: on_surface %s" % fish.on_surface)
		Input.action_press("jump")
	if once("jump read", 11.75):
		print("0.25 s after jump: on_surface %s, vertical %.2f m/s, height %.2f" % [fish.on_surface, fish.linear_velocity.y, fish.global_position.y])
		release_all()

	# Drop onto the ball: its top is a surface too (RL flip resets).
	if once("ball", 13.0):
		aquarium.reset_kickoff()
	if once("ball drop", 13.3):
		fish.set_spawn(Transform3D(Basis.IDENTITY, aquarium.ball.global_position + Vector3(0, aquarium.ball.settings.radius + 1.5, 0)))
	if once("ball read", 15.0):
		print("landed on the ball as a surface: %s" % on_ball)
		fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(-20, 0.6, 45)))
	if once("carry drop", 15.5):
		aquarium.ball.respawn(fish.global_position + Vector3(0, 2, 0))
	if once("carry go", 20.0):
		print("ball resting on the fish: %.2f m above it" % (aquarium.ball.global_position.y - fish.global_position.y))
		Input.action_press("thrust_forward", 0.3)
	if once("carry read", 22.0):
		var offset := aquarium.ball.global_position - fish.global_position
		print("carrying at 30%% throttle for 2 s: fish speed %.1f m/s, ball %.2f m above, %.2f m behind the fish centre (still on top: %s)" % [fish.speed, offset.y, offset.dot(fish.global_basis.z), offset.y > fish.hitbox_height / 2.0 + aquarium.ball.settings.radius * 0.8])
		release_all()
		get_tree().quit()
