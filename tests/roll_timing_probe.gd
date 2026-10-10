## Checks air roll, dodge flips and flip cancels against Rocket League (a
## reference simulation of RocketSim's update rules at 120 Hz), completed
## flips, and that the direction lock stops turning but not rolling.
## Run headless: Godot_console.exe --headless --path . res://tests/roll_timing_probe.tscn
extends Node

const TICK := 1.0 / 120.0
const TORQUE_TICKS := 78  # FLIP_TORQUE_TIME (0.65 s) at 120 Hz
const LOCK_END_TICKS := 114  # + FLIP_PITCHLOCK_EXTRA_TIME (0.3 s)

var main: Node
var fish: FishController
var step := 0
var tick := 0
var total := 0.0
var prev_axis := Vector3.ZERO
var marks := {}
var start_basis := Basis.IDENTITY
var steps: Array


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Ocean", false)
	fish = main.get_node("Fish")
	_print_roll_reference()
	print("RL front flip:       %s" % _flip_reference(FishController.RL_FLIP_TORQUE_FORWARD, FishController.RL_PITCH_DAMPING, -1))
	print("RL side flip:        %s" % _flip_reference(FishController.RL_FLIP_TORQUE_SIDE, FishController.RL_ROLL_DAMPING, -1))
	print("RL front flip, stick held: full turn in %d ticks (%.3f s)" % _held_flip_reference(true))
	print("RL side flip, air roll held: full turn in %d ticks (%.3f s)" % _held_flip_reference(false))
	steps = [
		_roll_test,
		func() -> bool: return _flip_test("Fish front flip:     ", "stick_up", false, -1.0, false),
		func() -> bool: return _flip_test("Fish side flip:      ", "stick_right", false, -1.0, false),
		func() -> bool: return _flip_test("Completed front flip:", "stick_up", true, -1.0, false),
		func() -> bool: return _flip_test("Completed side flip: ", "stick_right", true, -1.0, false),
		func() -> bool: return _flip_test("Half flip (fish):    ", "stick_down", true, 0.2, false),
		func() -> bool: return _flip_test("Cancel released:     ", "stick_down", true, 0.2, true),
		_lock_test,
		func() -> bool: return _z_damp_test(true),
		func() -> bool: return _z_damp_test(false),
		func() -> bool: return _boost_dodge_test(false),
		func() -> bool: return _boost_dodge_test(true),
		_cancel_control_test,
	]


func _print_roll_reference() -> void:
	var rate := 0.0
	var angle := 0.0
	var found := {}
	for n in range(1, 1000):
		rate = minf(rate + (FishController.RL_ROLL_TORQUE - FishController.RL_ROLL_DAMPING * rate) * TICK, FishController.RL_MAX_ANGULAR_SPEED)
		angle += rate * TICK
		for turns in [1, 2]:
			if angle >= TAU * turns and not found.has(turns):
				found[turns] = n
	print("RL roll reference:  360° in %d ticks (%.3f s), 720° in %d ticks (%.3f s)" % [found[1], found[1] * TICK, found[2], found[2] * TICK])


## RocketSim flip with no other input, optionally cancelled with full stick
## from flip tick `cancel_tick` on (cancel: no flip torque, air-control damping).
func _flip_reference(torque: float, damping: float, cancel_tick: int) -> String:
	var rate := 0.0
	var angle := 0.0
	var at_torque_end := 0.0
	for n in range(1, LOCK_END_TICKS + 1):
		var cancelled := cancel_tick > 0 and n >= cancel_tick
		if n <= TORQUE_TICKS and not cancelled:
			rate = minf(rate + torque * TICK, FishController.RL_MAX_ANGULAR_SPEED)
		else:
			rate -= damping * rate * TICK
		angle += rate * TICK
		if n == TORQUE_TICKS:
			at_torque_end = angle
	return "%5.1f° when the flip torque ends (0.65 s), %5.1f° when pitch lock ends (0.95 s)" % [rad_to_deg(at_torque_end), rad_to_deg(angle)]


## RocketSim flip with the flip direction held throughout: flip torque, then air
## control (pitch input locked until 0.95 s for front flips; held roll input
## for side flips). Returns [ticks, seconds] to one full turn.
func _held_flip_reference(front: bool) -> Array:
	var rate := 0.0
	var angle := 0.0
	for n in range(1, 1000):
		if n <= TORQUE_TICKS:
			rate += (FishController.RL_FLIP_TORQUE_FORWARD if front else FishController.RL_FLIP_TORQUE_SIDE) * TICK
		elif front:
			var pitch_scale := 0.0 if n <= LOCK_END_TICKS else 1.0
			rate += (FishController.RL_PITCH_TORQUE * pitch_scale - FishController.RL_PITCH_DAMPING * (1.0 - pitch_scale) * rate) * TICK
		else:
			rate += (FishController.RL_ROLL_TORQUE - FishController.RL_ROLL_DAMPING * rate) * TICK
		rate = minf(rate, FishController.RL_MAX_ANGULAR_SPEED)
		angle += rate * TICK
		if angle >= TAU - 0.0001:
			return [n, n * TICK]
	return [-1, -1.0]


func _physics_process(_delta: float) -> void:
	if step >= steps.size():
		get_tree().quit()
		return
	tick += 1
	if steps[step].call():
		_release_all()
		step += 1
		tick = 0
		total = 0.0
		marks.clear()


func _release_all() -> void:
	for action in ["roll_right", "jump", "stick_up", "stick_down", "stick_right", "direction_lock", "thrust_forward", "boost"]:
		Input.action_release(action)


func _roll_test() -> bool:
	if tick == 1:
		fish.request_reset()
	if tick == 10:
		prev_axis = fish.global_basis.y
		Input.action_press("roll_right")
	if tick > 10:
		total += prev_axis.angle_to(fish.global_basis.y)
		prev_axis = fish.global_basis.y
		var t := tick - 11
		for turns in [1, 2]:
			if total >= TAU * turns - 0.0001 and not marks.has(turns):
				marks[turns] = t
		if marks.size() == 2:
			print("Fish roll:          360° in %d ticks (%.3f s), 720° in %d ticks (%.3f s)" % [marks[1], marks[1] * TICK, marks[2], marks[2] * TICK])
			return true
	return false


## Jump, then dodge with `stick`. Optionally cancel `cancel_at` seconds into the
## flip by pushing the stick the other way (and let go again after 0.1 s if
## `release_cancel`). Prints rotation at RL's checkpoints, or for completed
## flips how long they took and how square the fish ended up.
func _flip_test(label: String, stick: String, complete: bool, cancel_at: float, release_cancel: bool) -> bool:
	var axis_of := func() -> Vector3:
		return fish.global_basis.y if stick == "stick_right" else -fish.global_basis.z
	if tick == 1:
		fish.request_reset()
		fish.complete_flips = complete
	if tick == 10:
		Input.action_press("jump")
	if tick == 12:
		Input.action_release("jump")
	if tick == 40:
		prev_axis = axis_of.call()
		start_basis = fish.global_basis
		Input.action_press(stick)
		Input.action_press("jump")
	if tick == 42:
		Input.action_release(stick)
		Input.action_release("jump")
	if tick <= 40:
		return false

	# Godot runs the fish's _integrate_forces before this, so the rotation seen
	# now happened in the step after the previous tick's _integrate_forces.
	var step_rotation: float = prev_axis.angle_to(axis_of.call())
	prev_axis = axis_of.call()
	var flip_time: float = fish.get("_flip_time")
	var was_running: bool = marks.get("running", false)
	marks["running"] = flip_time >= 0.0
	if not was_running and not marks.has("steps"):
		return false
	marks["steps"] = marks.get("steps", 0) + 1
	total += step_rotation
	var n: int = marks["steps"]

	if cancel_at >= 0.0:
		var counter := "stick_up" if stick == "stick_down" else "stick_down"
		if flip_time >= cancel_at - TICK * 0.5 and not marks.has("cancel_pressed"):
			Input.action_press(counter)
			marks["cancel_pressed"] = n
		if fish.get("_flip_cancelled") and not marks.has("cancel_tick"):
			marks["cancel_tick"] = n + 1  # flip step that first saw the cancel (see note above)
		if release_cancel and marks.has("cancel_tick") and n == marks["cancel_tick"] + 12:
			Input.action_release(counter)
	if n == TORQUE_TICKS:
		marks["torque"] = total

	if complete and cancel_at < 0.0:
		if flip_time < 0.0:
			var tilt := rad_to_deg((start_basis.inverse() * fish.global_basis).get_rotation_quaternion().get_angle())
			print("%s full turn %.1f° in %d ticks (%.3f s), ends %.2f° from its starting orientation" % [label, rad_to_deg(total), n, n * TICK, tilt])
			fish.complete_flips = true
			return true
	elif n == LOCK_END_TICKS:
		var line := "%s %5.1f° when the flip torque ends (0.65 s), %5.1f° when pitch lock ends (0.95 s)" % [label, rad_to_deg(marks["torque"]), rad_to_deg(total)]
		if cancel_at >= 0.0 and not release_cancel:
			line += "\nHalf flip (RL):       %s   (cancelled from flip tick %d)" % [_flip_reference(FishController.RL_FLIP_TORQUE_FORWARD, FishController.RL_PITCH_DAMPING, marks["cancel_tick"]), marks["cancel_tick"]]
		print(line)
		fish.complete_flips = true
		return true
	return false


## Jump, then side dodge; report vertical speed around RL's Z-damp window
## (flip steps 18-25) and how much height the flip gained.
func _z_damp_test(z_damp: bool) -> bool:
	if tick == 1:
		fish.request_reset()
		fish.rl_flip_z_damp = z_damp
	if tick == 10:
		Input.action_press("jump")
	if tick == 12:
		Input.action_release("jump")
	if tick == 40:
		Input.action_press("stick_right")
		Input.action_press("jump")
	if tick == 42:
		Input.action_release("stick_right")
		Input.action_release("jump")
	if tick <= 40:
		return false
	# Velocity read now was set by this tick's _integrate_forces (flip step n).
	var flip_time: float = fish.get("_flip_time")
	if flip_time < 0.0 and not marks.has("start_y"):
		return false
	if not marks.has("start_y"):
		marks["start_y"] = fish.global_position.y
	var n := int(round(flip_time * 120.0))
	if n == 17:
		marks["vy17"] = fish.linear_velocity.y
	if n == 26:
		marks["vy26"] = fish.linear_velocity.y
	if n == TORQUE_TICKS:
		var label := "Flip Z-damp on: " if z_damp else "Flip Z-damp off:"
		var line := "%s vertical speed %.2f m/s at flip step 17, %.2f m/s at step 26; rose %.2f m during the flip" % [label, marks["vy17"], marks["vy26"], fish.global_position.y - marks["start_y"]]
		if z_damp:
			line += "  (RL rule: x0.65^8 = %.3f of step 17)" % pow(0.65, 8)
		print(line)
		fish.rl_flip_z_damp = true
		return true
	return false


## Side dodge from a standstill, with or without boost held from the dodge on:
## boost must work mid-flip, pushing along the fish's (spinning) nose.
func _boost_dodge_test(boost: bool) -> bool:
	if tick == 1:
		fish.request_reset()
	if tick == 10:
		Input.action_press("jump")
	if tick == 12:
		Input.action_release("jump")
	if tick == 40:
		Input.action_press("stick_right")
		Input.action_press("jump")
		if boost:
			Input.action_press("boost")
	if tick == 42:
		Input.action_release("stick_right")
		Input.action_release("jump")
	if tick == 40 + TORQUE_TICKS:
		print("Side dodge, boost %s: speed %.1f m/s at the end of the flip torque, boosting=%s mid-flip" % ["held" if boost else "off ", fish.speed, marks.get("boosting", false)])
		Input.action_release("boost")
		return true
	if tick == 70:
		marks["boosting"] = fish.is_boosting and fish.is_dodging
	return false


## Back flip with throttle held, cancelled 0.15 s in: control (throttle, camera)
## must come back at the cancel, not at the end of the pitch lock (0.95 s).
func _cancel_control_test() -> bool:
	if tick == 1:
		fish.request_reset()
	if tick == 10:
		Input.action_press("jump")
	if tick == 12:
		Input.action_release("jump")
	if tick == 40:
		Input.action_press("stick_down")
		Input.action_press("jump")
		Input.action_press("thrust_forward")
	if tick == 42:
		Input.action_release("stick_down")
		Input.action_release("jump")
	if tick == 58:
		Input.action_press("stick_up")  # cancel
	if tick == 60:
		marks["dodging_after_cancel"] = fish.is_dodging
		marks["speed_at_cancel"] = fish.speed
	if tick == 100:
		print("Half flip with throttle: dodging right after the cancel=%s; speed %.1f -> %.1f m/s in the next 0.33 s (pitch lock still running=%s)" % [marks["dodging_after_cancel"], marks["speed_at_cancel"], fish.speed, fish.get("_flip_time") >= 0.0])
		return true
	return false


func _lock_test() -> bool:
	if tick == 1:
		fish.request_reset()
	if tick == 5:
		Input.action_press("thrust_forward")
	if tick == 120:
		Input.action_press("direction_lock")
	if tick == 122:
		marks["heading"] = -fish.global_basis.z
		prev_axis = fish.global_basis.y
		Input.action_press("stick_right")
		Input.action_press("stick_up")
		Input.action_press("roll_right")
	if tick > 122:
		total += prev_axis.angle_to(fish.global_basis.y)
		prev_axis = fish.global_basis.y
	if tick == 242:
		print("Direction lock, stick right+up and roll right for 1 s at %.1f m/s: nose moved %.2f°, fish rolled %.0f°" % [fish.speed, rad_to_deg(marks["heading"].angle_to(-fish.global_basis.z)), rad_to_deg(total)])
		return true
	return false
