## Ball indicator rings: one on the floor under a resting ball (touching, so
## it pulsed), one on a nearby wall, rings oriented out of their surface and
## hidden while the ball is popped.
## Run headless: Godot_console.exe --headless --path . res://tests/indicator_probe.tscn
extends Node

var main: Node
var aquarium: AquariumArena
var t := 0.0
var events := {}
var max_pulse := 0.0

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	main.set_environment("Aquarium Arena", false)
	aquarium = main._environment

func once(key: String, at: float) -> bool:
	if t >= at and not events.has(key):
		events[key] = true
		return true
	return false

func report(label: String) -> void:
	var rings: BallIndicators = aquarium.ball._indicators
	var lines := []
	for i in rings._decals.size():
		var d: Decal = rings._decals[i]
		if d.is_visible_in_tree():
			lines.append("%s at (%.1f, %.1f, %.1f) facing %s mix %.2f touching %s right-handed %s" % [
				BallIndicators.DIRECTIONS[i], d.global_position.x, d.global_position.y, d.global_position.z,
				d.global_basis.y.snapped(Vector3.ONE * 0.01), d.albedo_mix, rings._touching[i], d.global_basis.determinant() > 0.0])
	print("%s: %d ring(s), ball at %s" % [label, lines.size(), aquarium.ball.global_position.snapped(Vector3.ONE * 0.1)])
	for line in lines:
		print("   " + line)

func _physics_process(delta: float) -> void:
	t += delta
	var rings: BallIndicators = aquarium.ball._indicators
	for p in rings._pulse:
		max_pulse = maxf(max_pulse, p)
	if once("start", 0.05):
		aquarium.ball.respawn(Vector3(0, 6, 0))  # drop so it lands and pulses
	if once("rest", 1.5):
		report("resting on the floor")
		print("   a ring pulsed on landing: %s" % (max_pulse > 0.5))
		aquarium.ball.respawn(Vector3(AquariumArena.SIZE.x / 2.0 - 2.0, 8, 0))  # near the +X wall, falling
	if once("wall", 1.7):
		report("near the +X wall, mid-air")
		aquarium.respawn_time_left = 5.0  # as after a goal
		aquarium.ball.pop()
	if once("popped", 1.9):
		report("popped")
		get_tree().quit()
