## Getting the ball onto the fish's roof the ways Rocket League players do:
## scooping a ball rolling away (catch up slightly faster so the nose slides
## under it and it rolls up the hood), meeting a ball rolling toward you,
## driving gently into a still ball, and catching a dropped ball. Each run
## reports how long the ball rode on the roof and where it ended up.
## Run headless: Godot_console.exe --headless --path . res://tests/carry_probe.tscn
extends Node

const RUN_TIME := 4.0
const START_Z := 40.0

var main: Node
var fish: FishController
var aquarium: AquariumArena
var ball: Ball
var runs: Array[Dictionary] = []
var run := -1
var t := 0.0
var on_roof_time := 0.0
var longest := 0.0
var touched_at := -1.0
## Run index to trace tick by tick around the touch (user arg: -- trace N).
var trace_run := -1
var next_trace := 0.0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	main.set_environment("Aquarium Arena")
	fish = main.get_node("Fish")
	aquarium = main._environment
	ball = aquarium.ball
	ball.touched.connect(func(_by: Node3D, _speed: float) -> void:
		if touched_at < 0.0:
			touched_at = t)
	# name, throttle, ball offset ahead of the fish (m), ball velocity along the fish's facing (m/s), drop height
	for throttle in [0.3, 0.5, 0.7]:
		runs.append({"name": "scoop: ball rolling away at 3 m/s, throttle %.1f" % throttle, "throttle": throttle, "ahead": 6.0, "ball_speed": 3.0, "drop": 0.0})
	for throttle in [0.2, 0.4]:
		runs.append({"name": "meet: ball rolling toward at 2 m/s, throttle %.1f" % throttle, "throttle": throttle, "ahead": 8.0, "ball_speed": -2.0, "drop": 0.0})
	for throttle in [0.15, 0.3, 0.6]:
		runs.append({"name": "push: still ball, throttle %.2f" % throttle, "throttle": throttle, "ahead": 4.0, "ball_speed": 0.0, "drop": 0.0})
	# Feathered: the fish held just faster than the ball, so the touch is soft.
	for closing in [0.3, 0.6, 1.0, 1.5]:
		runs.append({"name": "feathered scoop: ball at 5 m/s, fish +%.1f m/s" % closing, "throttle": 0.0, "ahead": 3.0, "ball_speed": 5.0, "drop": 0.0, "fish_speed": 5.0 + closing})
	for speed in [0.5, 1.0, 2.0]:
		runs.append({"name": "feathered push: still ball, fish held at %.1f m/s" % speed, "throttle": 0.0, "ahead": 2.0, "ball_speed": 0.0, "drop": 0.0, "fish_speed": speed})
	runs.append({"name": "catch: ball dropped onto a still fish", "throttle": 0.0, "ahead": 0.0, "ball_speed": 0.0, "drop": 3.0})
	for speed in [4.0, 8.0]:
		runs.append({"name": "catch: ball dropped onto a fish moving %.0f m/s" % speed, "throttle": 0.0, "ahead": 0.0, "ball_speed": speed, "drop": 3.0, "fish_speed": speed})
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "trace":
		trace_run = int(args[1])
	_next_run()


func _next_run() -> void:
	Input.action_release("thrust_forward")
	if run >= 0:
		_report()
	run += 1
	if run >= runs.size():
		get_tree().quit()
		return
	t = 0.0
	on_roof_time = 0.0
	longest = 0.0
	touched_at = -1.0
	var r: Dictionary = runs[run]
	fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.6, START_Z)))  # facing -Z
	var ball_at := Vector3(0.0, ball.settings.radius, START_Z - r.ahead)
	if r.drop > 0.0:
		ball_at.y = 0.6 + r.drop
	ball.respawn(ball_at)


func _physics_process(delta: float) -> void:
	if run >= runs.size():
		return
	var r: Dictionary = runs[run]
	t += delta
	if is_equal_approx(t, 0.5) or (t > 0.5 - delta / 2.0 and t <= 0.5 + delta / 2.0):
		ball.linear_velocity = Vector3(0.0, 0.0, -r.ball_speed)
		fish.linear_velocity = Vector3(0.0, 0.0, -r.get("fish_speed", 0.0))
		if r.throttle > 0.0:
			Input.action_press("thrust_forward", r.throttle)
	if r.get("fish_speed", 0.0) > 0.0 and t > 0.5:
		# Hold the fish's speed (as a player would feather the throttle).
		var forward := -fish.global_basis.z
		fish.linear_velocity += forward * (r.fish_speed - fish.linear_velocity.dot(forward))
	if run == trace_run and touched_at >= 0.0 and t >= next_trace and t < touched_at + 1.5:
		next_trace = t + 0.05
		var local := fish.global_transform.affine_inverse() * ball.global_position
		var rel := fish.global_basis.inverse() * (ball.linear_velocity - fish.linear_velocity)
		print("  t=%.2f ball local (up %.2f, ahead %.2f)  ball vs fish velocity (up %.2f, fwd %.2f)  ball spin %s  fish %.1f m/s pitch rate %.2f" % [
			t, local.y, -local.z, rel.y, -rel.z, (fish.global_basis.inverse() * ball.angular_velocity).snapped(Vector3.ONE * 0.1),
			fish.speed, (fish.global_basis.inverse() * fish.angular_velocity).x])
	if t > 0.5:
		if _on_roof():
			on_roof_time += delta
			longest = maxf(longest, on_roof_time)
		else:
			on_roof_time = 0.0
	if t >= RUN_TIME:
		_next_run()


## Resting on the fish's top: above its roof and within its outline.
func _on_roof() -> bool:
	var local := fish.global_transform.affine_inverse() * ball.global_position
	var top := fish.hitbox_height / 2.0 + ball.settings.radius
	return local.y > top - 0.1 and local.y < top + 0.15 and absf(local.x) < fish.hitbox_width / 2.0 + 0.1 \
			and absf(local.z) < fish.hitbox_length / 2.0 + 0.2


func _report() -> void:
	var r: Dictionary = runs[run]
	var local := fish.global_transform.affine_inverse() * ball.global_position
	print("%-52s touch %5s  longest on roof %.2f s  end: ball %.2f m above fish centre, %.2f m %s of it, fish %.1f m/s" % [
		r.name, "%.2fs" % touched_at if touched_at >= 0.0 else "none", longest, local.y,
		absf(local.z), "ahead" if local.z < 0.0 else "behind", fish.speed])
