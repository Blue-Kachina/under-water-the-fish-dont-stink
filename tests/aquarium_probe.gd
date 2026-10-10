## Checks the Aquarium Arena: the shell holds the fish in, a boosted hit sends
## the ball into the orange goal, the goal scores and the ball comes back, and
## ball water settings can follow the fish or be set on their own.
## Run headless: Godot_console.exe --headless --path . res://tests/aquarium_probe.tscn
extends Node

var main: Node
var fish: FishController
var aquarium: AquariumArena
var ball: Ball
var t := 0.0
var events := {}
var touch_time := -1.0
var peak_ball_speed := 0.0
var goal_time := -1.0
var max_outside := 0.0

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Aquarium Arena", false)
	fish = main.get_node("Fish")
	aquarium = main.get_node("AquariumArena")
	ball = aquarium.ball
	ball.touched.connect(func(_by: Node3D, hit_speed: float) -> void:
		if touch_time < 0.0:
			touch_time = t
			print("touch at %.2fs, hit speed %.1f m/s" % [t, hit_speed]))
	aquarium.goal_scored.connect(func(team: int) -> void:
		goal_time = t
		print("goal for %s at %.2fs, score %s" % [AquariumArena.TEAM_NAMES[team], t, aquarium.scores]))

func once(key: String, at: float) -> bool:
	if t >= at and not events.has(key):
		events[key] = true
		return true
	return false

## How far the fish is past the tank's rounded inner surface (0 when inside).
func outside(p: Vector3) -> float:
	var half := AquariumArena.SIZE / 2.0
	var limit := half - Vector3.ONE * AquariumArena.CORNER_RADIUS
	var local := p - aquarium.centre
	if absf(local.z) > half.z - 1.0 and absf(local.x) < AquariumArena.GOAL_SIZE.x / 2.0 and absf(local.y) < AquariumArena.GOAL_SIZE.y / 2.0:
		return 0.0  # in a goal mouth
	return maxf((local - local.clamp(-limit, limit)).length() - AquariumArena.CORNER_RADIUS, 0.0)

func boost(on: bool) -> void:
	if on:
		Input.action_press("thrust_forward"); Input.action_press("boost")
	else:
		Input.action_release("thrust_forward"); Input.action_release("boost")

func _physics_process(delta: float) -> void:
	t += delta
	if touch_time >= 0.0 and goal_time < 0.0:
		peak_ball_speed = maxf(peak_ball_speed, ball.speed)
	var out := outside(fish.global_position) if t > 0.1 else 0.0  # the spawn reset lands on the first tick
	if out > max_outside + 0.5:
		print("  outside %.2f m at t=%.2f, fish %s" % [out, t, fish.global_position])
	max_outside = maxf(max_outside, out)

	if once("start", 0.2):
		var shell: CollisionShape3D = aquarium.get_node("Shell").get_child(0)
		print("shell triangles %d, goals %d, ball at %s r=%.2f, fish at %s" % [
			(shell.shape as ConcavePolygonShape3D).get_faces().size() / 3, aquarium.goals.size(),
			ball.global_position, ball.settings.radius, fish.global_position])
		boost(true)
	if once("hit report", 2.5):
		print("ball after hit: peak %.1f m/s, now %.1f m/s at z=%.1f" % [peak_ball_speed, ball.speed, ball.global_position.z])
		boost(false)
	if once("goal check", 4.0):
		print("goal scored: %s (t=%.2f), ball popped: %s, score %s" % [goal_time >= 0.0, goal_time, ball.popped, aquarium.scores])
	if goal_time >= 0.0 and once("respawn check", goal_time + ball.settings.goal_reset_delay + 0.3):
		print("after reset delay: popped %s, ball at %s, speed %.2f" % [ball.popped, ball.global_position, ball.speed])

	# Water: inherited drag (fish linear_drag) vs custom zero drag.
	if once("drag inherit", 9.0):
		ball.linear_velocity = Vector3(10, 0, 0)
	if once("drag inherit read", 10.0):
		print("inherit_water on (fish drag %.2f): 10 m/s -> %.2f m/s after 1 s" % [fish.linear_drag, ball.speed])
		ball.settings.inherit_water = false
		ball.settings.linear_drag = 0.0
		ball.linear_velocity = Vector3(-10, 0, 0)
	if once("drag custom read", 11.0):
		print("inherit_water off, drag 0: 10 m/s -> %.2f m/s after 1 s" % ball.speed)
		ball.settings.inherit_water = true
		aquarium.reset_kickoff()

	# Walls: boost flat into a side wall, then diagonally into a rounded corner.
	if once("wall", 11.5):
		fish.set_spawn(Transform3D(Basis(Vector3.UP, -PI / 2.0), aquarium.centre))
		boost(true)
	if once("corner", 14.5):
		print("side wall: fish at %s, max outside so far %.2f m" % [fish.global_position, max_outside])
		fish.set_spawn(Transform3D(Basis.looking_at(Vector3(1, 1, -1).normalized()), aquarium.centre))
	if once("ball radius", 17.5):
		print("corner: fish at %s, max outside so far %.2f m" % [fish.global_position, max_outside])
		boost(false)
		ball.settings.radius = 3.0
	if once("ball radius read", 17.7):
		var shape: SphereShape3D = (ball.get_child(0) as CollisionShape3D).shape
		print("radius 3.0 -> shape radius %.2f" % shape.radius)
		ball.settings.radius = 1.5

	# Ball cam: the action toggles it, and the camera swings to look from the fish towards the ball.
	if once("cam press", 18.0):
		fish.set_spawn(Transform3D(Basis.IDENTITY, aquarium.centre + Vector3(10, 0, 20)))
		aquarium.reset_kickoff()
		Input.action_press("ball_cam")
	if once("cam release", 18.1):
		Input.action_release("ball_cam")
	if once("cam read", 19.5):
		var camera: Camera3D = main.get_node("FollowCamera")
		var to_ball := (ball.global_position - fish.global_position).normalized()
		print("ball cam on: %s, camera aim vs fish->ball %.1f deg (fish faces %.1f deg away)" % [
			camera.ball_cam, rad_to_deg((-camera.global_basis.z).angle_to(to_ball)),
			rad_to_deg((-fish.global_basis.z).angle_to(to_ball))])
		Input.action_press("ball_cam")
	if once("cam off", 19.6):
		Input.action_release("ball_cam")
		print("ball cam after second press: %s" % main.get_node("FollowCamera").ball_cam)

	# World-up squash: hit the ball from below, once with RL's 0.35 and once unsquashed.
	for run in 2:
		var at := 20.0 + run * 3.0
		if once("up hit %d" % run, at):
			ball.settings.hit_up_scale = [0.35, 1.0][run]
			aquarium.reset_kickoff()
			fish.set_spawn(Transform3D(Basis.looking_at(Vector3(0, 1, -1).normalized()), aquarium.centre + Vector3(0, -12, 12)))
			touch_time = -1.0
			boost(true)
		if once("up hit read %d" % run, at + 1.5):
			boost(false)
			print("hit from below at 45 deg, hit_up_scale %.2f: ball velocity %s (climb angle %.0f deg)" % [
				ball.settings.hit_up_scale, ball.linear_velocity.snapped(Vector3.ONE * 0.1),
				rad_to_deg(asin(ball.linear_velocity.normalized().y))])
	if once("quit", 26.0):
		get_tree().quit()
