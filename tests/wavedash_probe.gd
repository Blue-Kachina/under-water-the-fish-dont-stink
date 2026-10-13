extends Node
## Wave dashes on the Aquarium Arena floor: drive, hop with the nose tipped up a
## little, then dodge forward just before the wheels touch down. As in Rocket
## League, landing ends the flip on the spot, so the fish drives off upright
## with the dodge's push. Sweeps the dodge's timing and compares the best one
## with the same hop landed without a dodge. Also a sideways wave dash.
##   Godot_console.exe --headless --fixed-fps 120 --path . res://tests/wavedash_probe.tscn

const TICK := 1.0 / 120.0
const DRIVE_TIME := 1.2
## Ticks the stick is held back after the jump, tipping the nose up for the landing.
const TILT_TICKS := 10
## How long after landing the speed is measured.
const AFTER_LANDING := 0.3
## A dodge counts as a wave dash when it touches down this many ticks after the press or sooner.
const LAND_WITHIN := 12

var main: Node
var fish: FishController
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	main.set_environment("Aquarium Arena")
	var ball: Ball = main._environment.ball
	ball.respawn(Vector3(30.0, ball.settings.radius + 0.05, 30.0))
	await _seconds(0.5)

	var hop := await _trial(-1, Vector2.ZERO)
	print("hop alone: lands at tick %d, %.2f m/s after" % [hop.landed_tick, hop.speed])
	check(hop.landed_tick > 0, "the hop lands")

	var best := {}
	var best_dodge := -1
	var stuck := 0
	# Only dodges that touch down within LAND_WITHIN ticks count: a dodge higher
	# up is a whole front flip, not a wave dash.
	for dodge_tick in range(hop.landed_tick - 30, hop.landed_tick + 1):
		var result := await _trial(dodge_tick, Vector2(0.0, -1.0))
		if result.landed_tick > dodge_tick and result.landed_tick - dodge_tick < LAND_WITHIN:
			print("  dodge at %3d: landed %3d (%d ticks later), %5.2f m/s, upright %.2f, flipping %s" % [
					dodge_tick, result.landed_tick, result.landed_tick - dodge_tick, result.speed, result.upright, result.flipping])
			if result.flipping:
				stuck += 1
			if result.upright > 0.9 and (best.is_empty() or result.speed > best.speed):
				best = result
				best_dodge = dodge_tick
	check(not best.is_empty(), "a forward wave dash lands upright")
	if not best.is_empty():
		var gain: float = best.speed - hop.speed
		check(gain > 3.0, "and is %.2f m/s faster than the hop alone (best dodge at tick %d, %d ticks before landing)" % [
				gain, best_dodge, best.landed_tick - best_dodge])
		check(not best.flipping and best.on_surface, "driving, not flipping, after it")
	check(stuck == 0, "every dodge that lands ends its flip (%d didn't)" % stuck)

	# Sideways: the same hop, dodging right a tick or a few before landing.
	var side := {}
	for dodge_tick in range(hop.landed_tick - 8, hop.landed_tick + 1):
		var result := await _trial(dodge_tick, Vector2(1.0, 0.0))
		if result.landed_tick > dodge_tick and result.landed_tick - dodge_tick < LAND_WITHIN:
			print("  side dodge at %3d: landed %3d, %5.2f m/s across on landing, %5.2f after, upright %.2f" % [
					dodge_tick, result.landed_tick, result.sideways_landing, result.sideways, result.upright])
			if result.upright > 0.9 and (side.is_empty() or result.sideways_landing > side.sideways_landing):
				side = result
	check(not side.is_empty() and side.sideways_landing > 3.0,
			"a sideways wave dash lands upright, sliding right (%.2f m/s across)" % side.get("sideways_landing", 0.0))

	print("wavedash_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## Drive straight, jump (a tap) with the stick back for TILT_TICKS, and press
## jump again with `dodge` on the stick at `dodge_tick` ticks after the jump
## (-1: no dodge). Waits for the landing, then AFTER_LANDING more.
func _trial(dodge_tick: int, dodge: Vector2) -> Dictionary:
	fish.set_spawn(Transform3D(Basis.IDENTITY, Vector3(-20.0, 0.6, 30.0)))
	var input := FishInput.new()
	fish.controls = input
	await _seconds(0.4)
	input.forward = 1.0
	await _seconds(DRIVE_TIME)
	var start_forward := -fish.global_basis.z
	var result := {"landed_tick": -1, "speed": 0.0, "upright": 0.0, "flipping": false, "on_surface": false, "sideways": 0.0, "sideways_landing": 0.0}
	var tick := 0
	while tick < 240:
		input.jump = tick == 0 or tick == dodge_tick
		input.stick = Vector2(0.0, 0.6) if tick > 0 and tick <= TILT_TICKS else Vector2.ZERO
		if tick == dodge_tick:
			input.stick = dodge
		await get_tree().physics_frame
		tick += 1
		if tick > 8 and fish.on_surface:
			result.landed_tick = tick
			break
	input.stick = Vector2.ZERO
	input.jump = false
	if result.landed_tick > 0:
		result.sideways_landing = fish.linear_velocity.dot(start_forward.cross(Vector3.UP))
		await _seconds(AFTER_LANDING)
		var v := fish.linear_velocity
		result.speed = Vector2(v.x, v.z).length()
		result.sideways = v.dot(start_forward.cross(Vector3.UP))
		result.upright = fish.global_basis.y.y
		result.flipping = fish.is_flipping()
		result.on_surface = fish.on_surface
	fish.controls = null
	return result


func _seconds(time: float) -> void:
	for i in roundi(time / TICK):
		await get_tree().physics_frame
