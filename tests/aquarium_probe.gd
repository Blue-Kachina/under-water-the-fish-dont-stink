## Checks the Aquarium Arena: the shell holds the fish in, a boosted hit sends
## a Surface ball along the floor into the orange goal, the goal scores and the
## ball comes back, Water ball settings follow the fish or stand alone, the
## panel shows only the options for the current ball type, ball cam aims at the
## ball, and hits are squashed along world up.
## Run headless: Godot_console.exe --headless --path . res://tests/aquarium_probe.tscn
extends Node

const SURFACE := BallSettings.BallType.SURFACE
const WATER := BallSettings.BallType.WATER

var main: Node
var fish: FishController
var aquarium: AquariumArena
var ball: Ball
var settings: BallSettings
var t := 0.0
var events := {}
var touch_time := -1.0
var peak_ball_speed := 0.0
var goal_time := -1.0
var max_outside := 0.0
var saved_buoyancy := 0.0

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	settings = main.ball_settings
	settings.ball_type = SURFACE
	main.set_environment("Aquarium Arena", false)
	fish = main.get_node("Fish")
	aquarium = main._environment  # by reference: the one main started with may still be in the tree
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

## How far a point is past the tank's rounded inner surface (0 when inside).
func outside(p: Vector3) -> float:
	var half := AquariumArena.SIZE / 2.0
	if absf(p.x) < AquariumArena.GOAL_SIZE.x / 2.0 and p.y < AquariumArena.GOAL_SIZE.y and absf(p.z) > half.z - AquariumArena.CORNER_RADIUS:
		return 0.0  # in a goal mouth or the notch in front of it
	var limit := half - Vector3.ONE * AquariumArena.CORNER_RADIUS
	var local := p - aquarium.centre
	return maxf((local - local.clamp(-limit, limit)).length() - AquariumArena.CORNER_RADIUS, 0.0)

func boost(on: bool) -> void:
	if on:
		Input.action_press("thrust_forward"); Input.action_press("boost")
	else:
		Input.action_release("thrust_forward"); Input.action_release("boost")

func panel_shows(prop: String) -> bool:
	return main.get_node("DebugPanel")._rows["ball/" + prop].visible

func _physics_process(delta: float) -> void:
	t += delta
	if touch_time >= 0.0 and goal_time < 0.0:
		peak_ball_speed = maxf(peak_ball_speed, ball.speed)
	var out := outside(fish.global_position) if t > 0.1 else 0.0  # the spawn reset lands on the first tick
	if out > max_outside + 0.5:
		print("  outside %.2f m at t=%.2f, fish %s" % [out, t, fish.global_position])
	max_outside = maxf(max_outside, out)

	# Surface ball kickoff: on the floor, fish level with it, boost straight through.
	if once("start", 0.2):
		var shell: CollisionShape3D = aquarium.get_node("Shell").get_child(0)
		print("shell triangles %d; surface ball at %s r=%.2f; fish at %s" % [
			(shell.shape as ConcavePolygonShape3D).get_faces().size() / 3,
			ball.global_position, settings.radius, fish.global_position])
		main.get_node("DebugPanel")._refresh_visibility()
		print("panel, Surface: gravity %s, air_drag %s, inherit_water %s, buoyancy %s, max_speed %s" % [
			panel_shows("gravity"), panel_shows("air_drag"), panel_shows("inherit_water"), panel_shows("buoyancy"), panel_shows("max_speed")])
		saved_buoyancy = fish.buoyancy
		fish.buoyancy = 0.0  # stay level with the ball whatever the tuning, so the hit is dead centre
		boost(true)
	if touch_time >= 0.0 and once("fish after touch", touch_time + 0.1):
		print("fish speed 0.1 s after the touch: %.1f m/s (ball mass %.2f, fish mass %.2f)" % [fish.speed, settings.mass, fish.mass])
	if once("hit report", 2.5):
		fish.buoyancy = saved_buoyancy
		print("ball after hit: peak %.1f m/s, now %.1f m/s at (%.1f, %.1f, %.1f)" % [
			peak_ball_speed, ball.speed, ball.global_position.x, ball.global_position.y, ball.global_position.z])
		boost(false)
	if once("goal check", 5.0):
		print("goal scored: %s (t=%.2f), ball popped: %s, score %s" % [goal_time >= 0.0, goal_time, ball.popped, aquarium.scores])
	if goal_time >= 0.0 and once("respawn check", goal_time + settings.goal_reset_delay + 1.0):
		print("after reset delay: popped %s, surface ball at %s (resting on floor = %s)" % [
			ball.popped, ball.global_position.snapped(Vector3.ONE * 0.01), absf(ball.global_position.y - settings.radius) < 0.05])

	# Dropped Surface ball falls under gravity.
	if once("drop", 10.0):
		ball.respawn(Vector3(0, 20, 0))
	if once("drop read", 11.0):
		print("surface ball dropped from 20 m: after 1 s at y=%.2f, vy=%.2f (no-drag estimate %.2f and %.2f)" % [ball.global_position.y, ball.linear_velocity.y, 20.0 - settings.gravity / 2.0, -settings.gravity])

	# Water ball: inherited drag (fish linear_drag) vs custom zero drag.
	if once("water", 12.0):
		settings.ball_type = WATER
		main.get_node("DebugPanel")._refresh_visibility()
		print("panel, Water + inherit: gravity %s, inherit_water %s, buoyancy %s" % [panel_shows("gravity"), panel_shows("inherit_water"), panel_shows("buoyancy")])
		aquarium.reset_kickoff()
	if once("drag inherit", 12.5):
		print("water ball kickoff at %s" % ball.global_position)
		ball.linear_velocity = Vector3(10, 0, 0)
	if once("drag inherit read", 13.5):
		print("inherit_water on (fish drag %.2f): 10 m/s -> %.2f m/s after 1 s" % [fish.linear_drag, ball.speed])
		settings.inherit_water = false
		settings.linear_drag = 0.0
		main.get_node("DebugPanel")._refresh_visibility()
		print("panel, Water custom: buoyancy %s, linear_drag %s" % [panel_shows("buoyancy"), panel_shows("linear_drag")])
		ball.linear_velocity = Vector3(-10, 0, 0)
	if once("drag custom read", 14.5):
		print("inherit_water off, drag 0: 10 m/s -> %.2f m/s after 1 s" % ball.speed)
		settings.inherit_water = true
		aquarium.reset_kickoff()

	# Walls: boost flat into a side wall, then diagonally into a rounded corner, then into a notch.
	if once("wall", 15.0):
		fish.set_spawn(Transform3D(Basis(Vector3.UP, -PI / 2.0), aquarium.centre))
		boost(true)
	if once("corner", 18.0):
		print("side wall: fish at %s, max outside so far %.2f m" % [fish.global_position, max_outside])
		fish.set_spawn(Transform3D(Basis.looking_at(Vector3(1, -1, -1).normalized()), aquarium.centre))
	if once("notch", 21.0):
		print("corner: fish at %s, max outside so far %.2f m" % [fish.global_position, max_outside])
		# Diagonally down into the notch's side cheek in front of the blue goal.
		fish.set_spawn(Transform3D(Basis.looking_at(Vector3(1, -0.3, 1).normalized()), Vector3(0, 6, 45)))
	if once("notch read", 24.0):
		print("notch cheek: fish at %s, max outside so far %.2f m" % [fish.global_position, max_outside])
		boost(false)

	# Ball cam: the action toggles it, and the camera swings to look from the fish towards the ball.
	if once("cam press", 24.5):
		fish.set_spawn(Transform3D(Basis.IDENTITY, aquarium.centre + Vector3(10, 0, 20)))
		aquarium.reset_kickoff()
		Input.action_press("ball_cam")
	if once("cam release", 24.6):
		Input.action_release("ball_cam")
	if once("cam read", 26.0):
		var camera: Camera3D = main.get_node("FollowCamera")
		var to_ball := (ball.global_position - fish.global_position).normalized()
		print("ball cam on: %s, camera aim vs fish->ball %.1f deg (fish faces %.1f deg away)" % [
			camera.ball_cam, rad_to_deg((-camera.global_basis.z).angle_to(to_ball)),
			rad_to_deg((-fish.global_basis.z).angle_to(to_ball))])
		Input.action_press("ball_cam")
	if once("cam off", 26.1):
		Input.action_release("ball_cam")

	# World-up squash: hit the Water ball from below, once with RL's 0.35 and once unsquashed.
	for run in 2:
		var at := 27.0 + run * 3.0
		if once("up hit %d" % run, at):
			settings.hit_up_scale = [0.35, 1.0][run]
			aquarium.reset_kickoff()
			fish.set_spawn(Transform3D(Basis.looking_at(Vector3(0, 1, -1).normalized()), aquarium.centre + Vector3(0, -12, 12)))
			boost(true)
		if once("up hit read %d" % run, at + 1.5):
			boost(false)
			print("hit from below at 45 deg, hit_up_scale %.2f: climb angle %.0f deg" % [
				settings.hit_up_scale, rad_to_deg(asin(ball.linear_velocity.normalized().y))])
	if once("quit", 33.0):
		get_tree().quit()
