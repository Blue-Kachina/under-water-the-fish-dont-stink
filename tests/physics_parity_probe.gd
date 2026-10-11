## RocketSim parity: runs the scenarios written by tools/rocketsim_compare/run.py
## through the game's physics with the same inputs, tick for tick, and writes
## the states for run.py to diff against RocketSim. Normally run by run.py:
##   uv run run.py   (in tools/rocketsim_compare)
## By hand: Godot_console.exe --headless --path . res://tests/physics_parity_probe.tscn -- SCENARIOS.json OUT.json
##
## States are reported in Rocket League units and axes (uu, +X left, +Y toward
## orange, +Z up) with the fish's centre standing in for RL's hitbox centre.
## "void" scenarios run in the Ocean (no colliders), "soccar" ones in the Aquarium.
extends Node

const UU_PER_M := 100.0
const TICK := 1.0 / 120.0
const ENVIRONMENTS := {"void": "Ocean", "soccar": "Aquarium Arena"}
const ACTIONS := ["thrust_forward", "thrust_reverse", "stick_left", "stick_right", "stick_up", "stick_down",
		"roll_left", "roll_right", "jump", "boost", "powerslide", "air_roll", "direction_lock"]

var main: Node
var fish: FishController
var ball: Ball
var own_ball: Ball  # for the Ocean, which has none
var scenarios: Array
var out_path: String
var results := {}
var index := -1
var tick := 0
var ticks: Array
## Ticks to wait before the current scenario starts (environment switch, resets).
var wait := 0
var started := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("physics_parity_probe: nothing to do. It needs scenarios from tools/rocketsim_compare/run.py (uv run run.py there).")
		get_tree().quit()
		return
	scenarios = JSON.parse_string(FileAccess.get_file_as_string(args[0]))["scenarios"]
	out_path = args[1]
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	fish = main.get_node("Fish")
	# Stand-ins and extras that RL doesn't have: no boost refill, no swim strokes.
	fish.boost_regen = 0.0
	fish.swim_strokes = false
	# RocketSim's controls are after any deadzone; the probe's inputs are too.
	fish.controller_deadzone = 0.0
	fish.physics_tick.connect(_on_physics_tick)
	_next_scenario()


## Runs at the start of the fish's physics tick, before it samples input: the
## same point RocketSim records a state and takes the next controls.
func _on_physics_tick(state: PhysicsDirectBodyState3D) -> void:
	if index >= scenarios.size():
		return
	var scenario: Dictionary = scenarios[index]
	if wait > 0:
		wait -= 1
		if wait == 2:
			_spawn(scenario)  # the resets land this tick or the next; _apply_start then sets the exact state
		return
	if not started:
		started = true
		tick = 0
		_apply_start(scenario, state)
	else:
		tick += 1
	ticks.append(_snapshot(scenario, state))
	if tick >= int(scenario.ticks):
		results[scenario.name] = ticks
		_next_scenario()
		return
	_apply_controls(_controls_at(scenario, tick))


func _next_scenario() -> void:
	_release_all()
	index += 1
	if index >= scenarios.size():
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"scenarios": results}))
		file.close()
		print("parity: wrote %d scenarios to %s" % [results.size(), out_path])
		get_tree().quit.call_deferred()
		return
	var scenario: Dictionary = scenarios[index]
	var env_name: String = ENVIRONMENTS[scenario.arena]
	wait = 3
	if main.current_environment != env_name:
		main.set_environment.call_deferred(env_name, false)
		wait = 10
	ticks = []
	started = false


func _spawn(scenario: Dictionary) -> void:
	if scenario.arena == "soccar":
		ball = main._environment.ball
		main._environment.scoring_enabled = false  # a ball rolled into a net mustn't be popped
	else:
		if own_ball == null:
			own_ball = Ball.new()
			own_ball.settings = main.ball_settings
			own_ball.fish = fish
			main.add_child(own_ball)
		ball = own_ball
	var start: Dictionary = scenario.start
	for setting: String in scenario.get("settings", {}):
		fish.set(setting, scenario.settings[setting])
	fish.set_spawn(Transform3D(_basis(start), _pos(start.centre)))
	if scenario.ball:
		ball.respawn(_pos(scenario.ball.pos), scenario.ball.get("kickoff_float", false))
	elif scenario.arena == "soccar":
		# Parked in a far corner. (Popping it would make the arena respawn it at
		# kickoff, right where the ground scenarios start.)
		ball.respawn(Vector3(-30.0, ball.settings.radius, 40.0))
	else:
		ball.respawn(Vector3(300, 300, 300))  # out of the way
		ball.pop()


## Exact starting state, set on the physics state itself so this tick already uses it.
func _apply_start(scenario: Dictionary, state: PhysicsDirectBodyState3D) -> void:
	var start: Dictionary = scenario.start
	state.transform = Transform3D(_basis(start), _pos(start.centre))
	state.linear_velocity = _pos(start.com_vel)  # a body's velocity is its centre of mass's
	state.angular_velocity = _ang_vel(start.ang_vel)
	fish.boost_amount = start.boost
	fish.reset_tyres()  # RocketSim's car starts each scenario with no throttle, brake or steering
	fish.jump_state = FishController.JumpState.READY
	if start.can_flip:
		fish.jump_state = FishController.JumpState.SECOND_JUMP
		fish._jump_timer = fish.double_jump_window
		fish._jump_hold_elapsed = -1.0
	if scenario.ball:
		var rid := ball.get_rid()
		var velocity := _pos(scenario.ball.vel)
		# Seed the ball's own record (velocity_for_last_step) with the start velocity.
		if ball._step_frame == Engine.get_physics_frames():
			ball._prev_step_velocity = velocity
			if not ball.waiting_for_touch:
				# The ball's own tick already ran this frame (before the fish's), so
				# hand the step what that tick would have made of the start velocity.
				var settings: BallSettings = ball.settings
				velocity.y -= settings.gravity * TICK
				velocity *= pow(1.0 - settings.air_drag, TICK)
		ball._step_velocity = velocity
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, _pos(scenario.ball.pos)))
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, velocity)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, _ang_vel(scenario.ball.ang_vel))


func _controls_at(scenario: Dictionary, at: int) -> Dictionary:
	var current := {}
	for segment: Array in scenario.controls:
		if int(segment[0]) <= at:
			current = segment[1]
	return current


## RL controls onto the game's input actions. Pitch +1 is nose up (stick back,
## which the game reads as stick down); steer and yaw share the stick's x.
func _apply_controls(c: Dictionary) -> void:
	_release_all()
	var throttle: float = c.get("throttle", 0.0)
	var steer: float = c.get("steer", 0.0) if c.get("steer", 0.0) != 0.0 else c.get("yaw", 0.0)
	var pitch: float = c.get("pitch", 0.0)
	var roll: float = c.get("roll", 0.0)
	_press_axis("thrust_reverse", "thrust_forward", throttle)
	_press_axis("stick_left", "stick_right", steer)
	_press_axis("stick_up", "stick_down", pitch)
	_press_axis("roll_left", "roll_right", roll)
	for pair in [["jump", "jump"], ["boost", "boost"], ["handbrake", "powerslide"]]:
		if c.get(pair[0], false):
			Input.action_press(pair[1])


func _press_axis(negative: String, positive: String, value: float) -> void:
	if value > 0.0:
		Input.action_press(positive, value)
	elif value < 0.0:
		Input.action_press(negative, -value)


func _release_all() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)


func _snapshot(scenario: Dictionary, state: PhysicsDirectBodyState3D) -> Dictionary:
	var b := state.transform.basis.orthonormalized()
	var snap := {
		"centre": _rl(state.transform.origin), "com": _rl(state.transform.origin + state.center_of_mass),
		"vel": _rl(state.linear_velocity),
		"ang_vel": _rl_ang_vel(state.angular_velocity),
		"fwd": _rl_dir(-b.z), "right": _rl_dir(b.x), "up": _rl_dir(b.y),
		"boost": fish.boost_amount, "flipping": fish.is_flipping(), "on_ground": fish.on_surface, "wheels": fish.wheels_touching,
	}
	if scenario.ball:
		# The physics server's state, not the node's, so it's the same step as the fish's.
		var rid := ball.get_rid()
		var ball_xform: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
		snap.ball_pos = _rl(ball_xform.origin)
		snap.ball_vel = _rl(ball.velocity_for_last_step())  # not the server's: the ball's tick may have run already
		snap.ball_ang_vel = _rl_ang_vel(PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY))
	return snap


# RL (uu, +X left, +Y to orange, +Z up, left-handed) <-> Godot (m, Y up): swap Y and Z.
func _pos(v: Array) -> Vector3:
	return Vector3(v[0], v[2], v[1]) / UU_PER_M


func _dir(v: Array) -> Vector3:
	return Vector3(v[0], v[2], v[1])


func _ang_vel(w: Array) -> Vector3:
	return -Vector3(w[0], w[2], w[1])  # a pseudovector flips sign under the reflection


func _basis(start: Dictionary) -> Basis:
	# The fish's +X is its right, +Y its up and -Z its nose.
	return Basis(_dir(start.right), _dir(start.up), -_dir(start.fwd))


func _rl(v: Vector3) -> Array:
	return [v.x * UU_PER_M, v.z * UU_PER_M, v.y * UU_PER_M]


func _rl_dir(v: Vector3) -> Array:
	return [v.x, v.z, v.y]


func _rl_ang_vel(w: Vector3) -> Array:
	return [-w.x, -w.z, -w.y]
