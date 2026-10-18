class_name BallSounds
extends Node
## The ball's sounds (planning_audio.md §3.3): hits, bounces off the arena, and
## respawns. SfxHooks adds one to every Ball.

## Hit speed (m/s) for the softest and the hardest hit layer.
const HIT_SOFT := 2.0
const HIT_HARD := 30.0
## How fast the ball has to be going for a bounce to be heard, and for the
## hardest one.
const BOUNCE_SOFT := 2.5
const BOUNCE_HARD := 25.0

var ball: Ball


func _ready() -> void:
	ball = get_parent() as Ball
	ball.touched.connect(_on_touched)
	ball.body_entered.connect(_on_body_entered)
	ball.respawned.connect(func() -> void: Sfx.play_at("ball/reset", ball.global_position))


func _on_touched(_by: Node3D, hit_speed: float) -> void:
	Sfx.play_at("ball/hit", ball.global_position, inverse_lerp(HIT_SOFT, HIT_HARD, hit_speed))


## The engine only reports the arena (fish contacts are the ball's own maths).
func _on_body_entered(_body: Node) -> void:
	var speed := maxf(ball.linear_velocity.length(), ball.velocity_for_last_step().length())
	if ball.popped or ball.waiting_for_touch or speed < BOUNCE_SOFT:
		return
	Sfx.play_at("ball/bounce", ball.global_position, clampf(inverse_lerp(BOUNCE_SOFT, BOUNCE_HARD, speed), 0.0, 1.0))
