extends Node
## The home screen's fish showcase: the right stick orbits the camera round the
## fish (round and up / down, clamped over the top and under the belly), the
## turning waits while it's steered and picks up again a moment after, and the
## unsteered view is the one it always had.
##   Godot_console.exe --headless --path . res://tests/showcase_orbit_probe.tscn

const Showcase := preload("res://scripts/ui/home_screen.gd").FishShowcase

var failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	var showcase = Showcase.new()
	showcase.size = Vector2(400, 400)
	add_child(showcase)
	showcase.show_fish(FishCharacter.FishClass.values()[0], 0)
	var camera: Camera3D = showcase._camera
	var pivot: Node3D = showcase._pivot
	var reach: float = showcase._reach

	print("the resting view:")
	var old_view := Vector3(-0.55, 0.32, -1.0).normalized() * reach
	check(camera.position.distance_to(old_view) < 0.001, "unsteered, the camera sits where it always did")

	print("steering:")
	var before := camera.position
	var spin_before: float = pivot.rotation.y
	for i in 30:
		showcase.steer(Vector2(1.0, 0.0), 1.0 / 60.0)
	check(camera.position.distance_to(before) > 0.1, "right on the stick moves the camera round")
	check(absf(camera.position.length() - reach) < 0.001, "it keeps its distance from the fish")
	check(absf(camera.position.y - before.y) < 0.001, "sideways only goes round, not up or down")
	check(is_equal_approx(pivot.rotation.y, spin_before), "the fish stops turning while it's steered")
	var forward := -camera.global_basis.z
	check(forward.dot(-camera.position.normalized()) > 0.999, "the camera still looks at the fish")

	for i in 600:
		showcase.steer(Vector2(0.0, -1.0), 1.0 / 60.0)
	check(is_equal_approx(showcase._pitch, Showcase.ORBIT_PITCH_LIMIT), "up on the stick rises over the top, clamped")
	check(camera.position.y > 0.9 * reach, "and the camera is above the fish")
	for i in 1200:
		showcase.steer(Vector2(0.0, 1.0), 1.0 / 60.0)
	check(is_equal_approx(showcase._pitch, -Showcase.ORBIT_PITCH_LIMIT), "down goes under the belly, clamped")

	print("letting go:")
	var spin_held: float = pivot.rotation.y
	for i in 60:
		showcase.steer(Vector2.ZERO, 1.0 / 60.0)
	check(is_equal_approx(pivot.rotation.y, spin_held), "a second after letting go, still waiting")
	for i in 120:
		showcase.steer(Vector2.ZERO, 1.0 / 60.0)
	check(pivot.rotation.y > spin_held + 0.05, "a moment later the fish turns again")
	var resting := camera.position
	for i in 60:
		showcase.steer(Vector2.ZERO, 1.0 / 60.0)
	check(camera.position.distance_to(resting) < 0.001, "the camera stays where it was left")

	print("the stick read:")
	check(Showcase._right_stick() == Vector2.ZERO, "no pads, no steering")

	print("%s (%d failures)" % ["ALL PASS" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures else 0)
