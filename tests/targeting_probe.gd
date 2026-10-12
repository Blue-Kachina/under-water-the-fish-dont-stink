extends Node
## Ring cam and target outlines. Ring cam (ball cam on the obstacle course) aims
## from the fish at the next hoop, and moves on to the following hoop once the
## fish passes through. Windowed (not --headless), it also saves screenshots of
## the next hoop and the ball each hidden behind a wall, to check by eye that
## their outlines show through it:
##   Godot_console.exe --fixed-fps 120 --path . res://tests/targeting_probe.tscn -- --shots=<dir>
## Headless runs the aiming checks only.

const AIM_TOLERANCE := 6.0  # degrees

var main: Node
var fish: FishController
var camera: Camera3D
var arena: Arena
var failures := 0
var shots_dir := ""
var _wall: MeshInstance3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	if DisplayServer.get_name() == "headless":
		shots_dir = ""
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	fish = main.get_node("Fish")
	camera = main.get_node("FollowCamera")
	fish.swim_strokes = false
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	main.set_environment("Obstacle Course", false)
	arena = main._environment
	await _frames(2)
	check(camera.course == arena and camera.ball == null, "on the course the camera has the course and no ball")

	# Ring cam aims at the next hoop, from a spot looking away from it.
	camera.ball_cam = true
	await _place(Vector3(10, 12, 70), Vector3(0, 0, 1))
	await _seconds(2.0)
	check(_aim_error(arena.hoops[0]) < AIM_TOLERANCE, "ring cam aims at hoop 1 (%.1f deg off)" % _aim_error(arena.hoops[0]))

	# Through hoop 1: on to hoop 2.
	arena._on_hoop_fish_entered(arena.hoops[0], fish)
	check(arena.next_hoop == 1, "passing hoop 1 makes hoop 2 next")
	await _seconds(2.5)
	check(_aim_error(arena.hoops[1]) < AIM_TOLERANCE, "ring cam aims at hoop 2 (%.1f deg off)" % _aim_error(arena.hoops[1]))

	# Off: back to the fish's facing.
	camera.ball_cam = false
	await _seconds(2.0)
	var facing := rad_to_deg((-camera.global_basis.z).angle_to(-fish.global_basis.z))
	check(facing < 15.0, "ring cam off: back behind the fish (%.1f deg off its facing)" % facing)

	# Outlines: only the next hoop has one.
	check(arena.hoops[1].get_child(0).mesh.material.next_pass != null, "the next hoop has an outline pass")
	check(arena.hoops[0].get_child(0).mesh.material.next_pass == null, "a passed hoop has none")

	if shots_dir:
		await _hoop_shot()
	arena.reset_course()

	# The ball.
	main.ball_settings.ball_type = BallSettings.BallType.SURFACE
	main.set_environment("Aquarium Arena", false)
	await _frames(2)
	var aquarium: AquariumArena = main._environment
	check(camera.course == null and camera.ball == aquarium.ball, "in the aquarium ball cam has the ball again")
	check(aquarium.ball._material.next_pass != null, "the ball has an outline pass")
	if shots_dir:
		await _ball_shot(aquarium)

	print("targeting_probe: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## Hoop 2 in view through ring cam, then a wall between: the outline should show on it.
func _hoop_shot() -> void:
	var hoop := arena.hoops[1]
	var from := hoop.global_position + Vector3(-14, 0, 0) + Vector3(0, 0, 20)
	await _place(from, (hoop.global_position - from).normalized())
	camera.ball_cam = true
	await _seconds(2.5)
	_save("hoop_in_view")
	_wall = _add_wall(fish.global_position.lerp(hoop.global_position, 0.55), hoop.global_position - fish.global_position, Vector2(5, 12))
	await _frames(3)
	_save("hoop_hidden")
	_wall.queue_free()


func _ball_shot(aquarium: AquariumArena) -> void:
	var ball := aquarium.ball
	aquarium.set_physics_process(false)
	var from := ball.global_position + Vector3(0, 0, 18)
	await _place(from, Vector3(0, 0, -1))
	camera.ball_cam = true
	await _seconds(2.0)
	_save("ball_in_view")
	_wall = _add_wall(fish.global_position.lerp(ball.global_position, 0.5), ball.global_position - fish.global_position, Vector2(3.5, 1.2))
	await _frames(3)
	_save("ball_half_hidden")
	_wall.scale = Vector3(3, 6, 1)
	await _frames(3)
	_save("ball_hidden")
	_wall.queue_free()


func _place(at: Vector3, facing: Vector3) -> void:
	fish.set_spawn(Transform3D(Basis.looking_at(facing, Vector3.UP), at))
	await get_tree().physics_frame
	camera.snap()


func _aim_error(node: Node3D) -> float:
	var to := (node.global_position - fish.global_position).normalized()
	return rad_to_deg((-camera.global_basis.z).angle_to(to))


## An opaque wall, `size` across, at `at`, facing along `normal`.
func _add_wall(at: Vector3, normal: Vector3, size: Vector2) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(size.x, size.y, 0.3)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.3, 0.28)
	box.material = material
	var wall := MeshInstance3D.new()
	wall.mesh = box
	add_child(wall)
	wall.global_transform = Transform3D(Basis.looking_at(normal.normalized(), Vector3.UP), at)
	return wall


func _save(shot: String) -> void:
	var path := shots_dir.path_join("%s.png" % shot)
	get_viewport().get_texture().get_image().save_png(path)
	print("  shot  %s" % path)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(time: float) -> void:
	await get_tree().create_timer(time).timeout
