class_name FishBot
extends Node
## A basic Rocket League style bot for the aquarium. It drives its fish through
## FishController.controls, the same inputs a player has: it gets behind the
## ball on the line to the goal it attacks and drives through it, falls back
## goal-side when it's out of position, boosts down straights, powerslides
## round tight turns, dodges into the ball when it's close, and lands wheels
## down after a jump or a bump. No aerials or wall play yet.

## Within this of the ball (m) and lined up, it dodges into it.
const DODGE_RANGE := 3.2
## The ball's this high (m) or more and it waits under it instead.
const HIGH_BALL := 3.0
## Ticks of the first jump, the pause before the dodge, and the dodge press.
const JUMP_TICKS := 6
const PAUSE_TICKS := 4
const DODGE_TICKS := 6
## Seconds of crawling along before it jumps to get unstuck.
const STUCK_TIME := 1.5

var fish: FishController
var ball: Node3D
var arena: AquariumArena
## The team it plays for: 0 (Blue) defends +Z, 1 (Orange) defends -Z.
var team := 1

var input := FishInput.new()
## Ticks into a jump-and-dodge; -1 while not doing one.
var _dodge_tick := -1
var _dodge_stick := Vector2.ZERO
var _stuck_time := 0.0


func _ready() -> void:
	process_physics_priority = -10  # before the fish samples its controls
	fish.controls = input


func _physics_process(delta: float) -> void:
	input.clear()
	if not is_instance_valid(fish) or not is_instance_valid(ball) or fish.demolished or fish.controls_locked:
		_dodge_tick = -1
		return
	if _dodge_tick >= 0:
		_continue_dodge()
		return
	if not fish.on_surface:
		_recover()
		return
	_drive(delta)


## Where to go and how, on a surface.
func _drive(delta: float) -> void:
	var me := fish.global_position
	var ball_position := ball.global_position
	var ball_velocity: Vector3 = ball.get("linear_velocity")
	var attack := -_own_side()  # +1: it attacks toward +Z
	# Lead the ball by roughly how long it'll take to get there.
	var lead := clampf(me.distance_to(ball_position) / maxf(fish.speed, 10.0), 0.0, 1.2)
	var aim := ball_position + Vector3(ball_velocity.x, 0.0, ball_velocity.z) * lead
	aim.x = clampf(aim.x, -AquariumArena.SIZE.x / 2.0 + 2.0, AquariumArena.SIZE.x / 2.0 - 2.0)
	aim.z = clampf(aim.z, -AquariumArena.SIZE.z / 2.0 + 2.0, AquariumArena.SIZE.z / 2.0 - 2.0)
	var goal := Vector3(0.0, 0.0, attack * AquariumArena.SIZE.z / 2.0)

	var target: Vector3
	var goal_side := (aim.z - me.z) * attack > -1.0  # between the ball and its own goal
	if not goal_side:
		# Out of position: back round the ball, on the side it's already on,
		# to a spot between the ball and its own goal.
		var side := signf(me.x - aim.x) if absf(me.x - aim.x) > 0.5 else 1.0
		target = Vector3(aim.x + side * 5.0, 0.0, aim.z - attack * 8.0)
	else:
		# Behind the ball on the line through it to the goal, closing in as it gets near.
		var shot := (goal - aim)
		shot.y = 0.0
		shot = shot.normalized()
		var behind := clampf(me.distance_to(aim) * 0.35, 0.0, 6.0)
		target = aim - shot * behind
	var high := ball_position.y > HIGH_BALL and Vector2(me.x - ball_position.x, me.z - ball_position.z).length() < 8.0
	if high:
		target = Vector3(ball_position.x, 0.0, ball_position.z)  # wait under it

	var local := fish.global_basis.inverse() * (target - me)
	var angle := atan2(local.x, -local.z)  # + = target to the right
	var distance := Vector2(local.x, local.z).length()
	input.stick.x = clampf(angle * 3.0, -1.0, 1.0)
	input.forward = 1.0
	input.powerslide = absf(angle) > 1.6 and fish.speed > 5.0
	input.boost = absf(angle) < 0.3 and distance > 8.0 and fish.speed < fish.max_boost_speed - 0.5 and not high

	# Dodge into a ball that's close, low and dead ahead.
	var to_ball := fish.global_basis.inverse() * (ball_position - me)
	var ball_angle := atan2(to_ball.x, -to_ball.z)
	if goal_side and not high and to_ball.length() < DODGE_RANGE and ball_position.y < 2.0 \
			and absf(ball_angle) < 0.4 and fish.speed > 6.0:
		_start_dodge(Vector2(clampf(ball_angle * 1.5, -1.0, 1.0), -1.0))
		return

	# Crawling along (pinned on a wall, nose in a corner): hop out.
	_stuck_time = _stuck_time + delta if fish.speed < 1.0 else 0.0
	if _stuck_time > STUCK_TIME:
		_stuck_time = 0.0
		_start_dodge(Vector2.ZERO)


## +1 if it defends the +Z end, -1 for -Z.
func _own_side() -> float:
	return 1.0 if team == 0 else -1.0


## Jump, then dodge with `stick` (zero: a plain double jump).
func _start_dodge(stick: Vector2) -> void:
	_dodge_tick = 0
	_dodge_stick = stick
	_continue_dodge()


func _continue_dodge() -> void:
	input.forward = 1.0
	if _dodge_tick < JUMP_TICKS:
		input.jump = true
	elif _dodge_tick < JUMP_TICKS + PAUSE_TICKS:
		input.jump = false
	elif _dodge_tick < JUMP_TICKS + PAUSE_TICKS + DODGE_TICKS:
		input.jump = true
		input.stick = _dodge_stick
	else:
		_dodge_tick = -1
		return
	_dodge_tick += 1


## In the air: turn wheels down and nose level, so it lands driving.
func _recover() -> void:
	if fish.is_flipping():
		return
	var basis := fish.global_basis.orthonormalized()
	var forward := -basis.z
	input.forward = 1.0
	input.stick.y = clampf(-forward.y * 3.0, -1.0, 1.0)  # stick back lifts the nose
	input.roll = clampf(basis.x.y * 3.0, -1.0, 1.0)  # right side high: roll right
	if basis.y.y < 0.0 and absf(basis.x.y) < 0.3:
		input.roll = 1.0  # upside down and level: roll either way
