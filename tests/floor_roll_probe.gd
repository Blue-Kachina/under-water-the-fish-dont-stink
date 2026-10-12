## Rolls the match ball (Surface type) along lanes across the Aquarium Arena's
## flat floor, slow and fast, crossing the floor mesh's internal edges at many
## angles. On RL's floor (and RocketSim's) a rolling ball keeps a straight line:
## it never picks up sideways speed or bounces. Also checks the ball rests at
## RL's height: centre 93.15 uu up, 1.9 uu more than its radius (world_gap).
## Run headless: Godot_console.exe --headless --path . res://tests/floor_roll_probe.tscn
## FLOOR_TRACE=<lane> prints that lane tick by tick, with the floor under the ball.
extends Node

## [start x, start z, direction x, direction z, speed m/s, seconds]
const LANES := [
	[-25.0, -40.0, 0.0, 1.0, 4.5, 4.0],  # tools/rocketsim_compare ball_roll_slow
	[-10.0, -30.0, 0.0, 1.0, 4.5, 4.0],
	[-30.0, -20.0, 1.0, 0.0, 4.5, 4.0],
	[25.0, 10.0, -1.0, 0.0, 4.5, 4.0],
	[-25.0, 20.0, 1.0, -0.3, 4.5, 4.0],
	[-35.0, -15.0, 1.0, 0.0, 18.0, 3.0],
	[15.0, -45.0, 0.0, 1.0, 18.0, 3.5],
	[-30.0, 30.0, 1.0, -0.6, 18.0, 3.0],
]
const MAX_SIDEWAYS := 0.05  # m/s
## How far the ball's height may wander while rolling (m). Height, not vertical
## speed: the speed read between ticks still holds the tick's gravity (6.5/120).
const MAX_BOUNCE := 0.005
const RL_REST_GAP := 0.019  # RocketSim's rest z 93.15 uu minus the 91.25 uu radius

var main: Node
var ball: Ball
var lane := -1
var phase := ""
var phase_ticks := 0
var lane_time := 0.0
var direction := Vector3.ZERO
var worst_sideways := 0.0
var worst_at := Vector3.ZERO
var low := 0.0
var high := 0.0
var rest_gaps: Array[float] = []
var trace_lane := int(OS.get_environment("FLOOR_TRACE")) if OS.has_environment("FLOOR_TRACE") else -1
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	main.ball_settings.kickoff_float = false
	add_child(main)
	main.set_environment("Aquarium Arena", false)
	var aquarium: AquariumArena = main._environment
	aquarium.scoring_enabled = false
	ball = aquarium.ball
	main.get_node("Fish").set_spawn(Transform3D(Basis.IDENTITY, Vector3(0.0, 15.0, 0.0)))  # parked at the centre spot
	_next_lane()


func check(ok: bool, message: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		failures += 1


func _next_lane() -> void:
	lane += 1
	if lane >= LANES.size():
		_finish()
		return
	var l: Array = LANES[lane]
	direction = Vector3(l[2], 0.0, l[3]).normalized()
	ball.respawn(Vector3(l[0], ball.settings.radius + 0.05, l[1]))  # dropped, so it finds its own rest height
	phase = "settle"
	phase_ticks = 0
	worst_sideways = 0.0


func _physics_process(delta: float) -> void:
	if lane >= LANES.size():
		return
	var l: Array = LANES[lane]
	phase_ticks += 1
	match phase:
		"settle":
			if phase_ticks >= 60:
				var gap := ball.global_position.y - ball.settings.radius
				rest_gaps.append(gap)
				low = gap
				high = gap
				var velocity: Vector3 = direction * l[4]
				var rid := ball.get_rid()
				PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, velocity)
				PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.UP.cross(velocity) / ball.settings.radius)
				phase = "roll"
				lane_time = 0.0
		"roll":
			lane_time += delta
			var v := ball.linear_velocity
			var p := ball.global_position
			if lane == trace_lane:
				var query := PhysicsRayQueryParameters3D.create(p, p - Vector3.UP * 2.0)
				query.exclude = [ball.get_rid()]
				var hit := get_viewport().world_3d.direct_space_state.intersect_ray(query)
				print("  t %.3f pos %s v %s w %s floor y %s n %s" % [lane_time, p, v, ball.angular_velocity, hit.get("position", Vector3.ZERO).y, hit.get("normal", Vector3.ZERO)])
			if lane_time > 0.1:
				var sideways := absf(v.dot(direction.cross(Vector3.UP)))
				if sideways > worst_sideways:
					worst_sideways = sideways
					worst_at = p
				var gap := p.y - ball.settings.radius
				low = minf(low, gap)
				high = maxf(high, gap)
			if lane_time >= l[5]:
				check(worst_sideways < MAX_SIDEWAYS and high - low < MAX_BOUNCE,
						"lane %d (%.1f m/s from (%.0f, %.0f)): sideways %.3f m/s (worst at x %.2f z %.2f), height range %.4f m"
						% [lane, l[4], l[0], l[1], worst_sideways, worst_at.x, worst_at.z, high - low])
				_next_lane()


func _finish() -> void:
	var mean := 0.0
	for gap in rest_gaps:
		mean += gap
	mean /= rest_gaps.size()
	check(absf(mean - RL_REST_GAP) < 0.002, "ball rests %.4f m above its radius (RL: %.3f)" % [mean, RL_REST_GAP])
	print("floor_roll_probe: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	get_tree().quit(1 if failures else 0)
