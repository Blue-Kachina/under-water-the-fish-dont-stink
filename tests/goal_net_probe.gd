## Checks the curved goal nets in the Aquarium Arena: raycasts find the floor
## ramping up into the back wall and the back wall curving over onto the roof and
## round into the side walls, and a plain sphere rolled into the net climbs the
## back curve and comes back out instead of stopping dead against a flat wall.
## Run headless: Godot_console.exe --headless --path . res://tests/goal_net_probe.tscn
extends Node

var main: Node
var aquarium: AquariumArena
var goal: Goal
var sphere: RigidBody3D
var t := 0.0
var events := {}
var peak_y := 0.0
var deepest := 0.0
var failures := 0

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_environment("Aquarium Arena")
	aquarium = main._environment
	goal = aquarium.goals[1]  # Orange, at -Z
	main.get_node("Fish").set_spawn(Transform3D(Basis.IDENTITY, aquarium.centre + Vector3(20, 0, 20)))  # out of the way
	aquarium.ball.respawn(Vector3(-20, 1, 20))

func once(key: String, at: float) -> bool:
	if t >= at and not events.has(key):
		events[key] = true
		return true
	return false

func check(ok: bool, message: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		failures += 1

## Casts in the goal's local frame; returns the local hit point and normal, or {}.
func cast(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(goal.to_global(from), goal.to_global(to))
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	return {"point": goal.to_local(hit.position), "normal": goal.global_basis.inverse() * hit.normal}

func _physics_process(delta: float) -> void:
	t += delta
	if once("rays", 0.2):
		var h := goal.height / 2.0
		var d := goal.depth
		var rf := goal.floor_radius
		var rc := goal.roof_radius
		var top := -h + goal.back_height  # the net's height at the back (the roof slopes up to the crossbar)
		# Straight back at mid-height of the straight back wall: the back is at full depth.
		var mid_y := (-h + rf + top - rc) / 2.0
		var hit := cast(Vector3(0, mid_y, 1), Vector3(0, mid_y, d + 5))
		check(not hit.is_empty() and absf(hit.point.z - d) < 0.05, "back wall at depth %.2f (expected %.2f)" % [hit.get("point", Vector3.ZERO).z, d])
		# Low down, the floor curve meets the ray before the back wall.
		var low_y := -h + rf * 0.25
		hit = cast(Vector3(0, low_y, 1), Vector3(0, low_y, d + 5))
		var expect_z := d - rf + sqrt(rf * rf - pow(rf - rf * 0.25, 2))
		check(not hit.is_empty() and absf(hit.point.z - expect_z) < 0.1 and hit.normal.y > 0.3,
				"floor curve at z %.2f (expected %.2f), normal %s" % [hit.get("point", Vector3.ZERO).z, expect_z, hit.get("normal", Vector3.ZERO)])
		# High up, the roof curve meets the ray before the back wall.
		var high_y := top - rc * 0.25
		hit = cast(Vector3(0, high_y, 1), Vector3(0, high_y, d + 5))
		expect_z = d - rc + sqrt(rc * rc - pow(rc - rc * 0.25, 2))
		check(not hit.is_empty() and absf(hit.point.z - expect_z) < 0.1 and hit.normal.y < -0.3,
				"roof curve at z %.2f (expected %.2f), normal %s" % [hit.get("point", Vector3.ZERO).z, expect_z, hit.get("normal", Vector3.ZERO)])
		# Straight up near the mouth: the roof, sloping from the crossbar down to the back.
		hit = cast(Vector3(0, 0, 1), Vector3(0, h + 5, 1))
		var roof_y := h - (h - top) * 1.0 / (d - rc)
		check(not hit.is_empty() and absf(hit.point.y - roof_y) < 0.05, "roof at %.2f (expected %.2f)" % [hit.get("point", Vector3.ZERO).y, roof_y])
		# Sideways from the middle of the net: a flat side wall at the mouth's edge.
		hit = cast(Vector3(0, 0, d / 2.0), Vector3(goal.width, 0, d / 2.0))
		check(not hit.is_empty() and absf(hit.point.x - goal.width / 2.0) < 0.05 and hit.normal.x < -0.99,
				"side wall at x %.2f (expected %.2f)" % [hit.get("point", Vector3.ZERO).x, goal.width / 2.0])
		# Diagonally into a side-to-back corner from its curve's centre: the curve is corner_radius away.
		var rs := goal.corner_radius
		var centre := Vector3(goal.width / 2.0 - rs, mid_y, d - rs)
		hit = cast(centre, centre + Vector3(1, 0, 1).normalized() * rs * 2.0)
		var reach: float = hit.get("point", centre).distance_to(centre)
		var facing: float = hit.get("normal", Vector3.ZERO).dot(-Vector3(1, 0, 1).normalized())
		check(not hit.is_empty() and absf(reach - rs) < 0.05 and facing > 0.98,  # the curve is faceted
				"rounded corner %.2f m from its centre (expected %.2f), normal facing back %.3f" % [reach, rs, facing])
		# Along the side wall just short of the back: the corner curve, not a square corner.
		var near_back := d - rs / 2.0
		hit = cast(Vector3(0, mid_y, near_back), Vector3(goal.width, mid_y, near_back))
		var expect_x := goal.width / 2.0 - rs + sqrt(rs * rs - rs * rs / 4.0)
		check(not hit.is_empty() and absf(hit.point.x - expect_x) < 0.05,
				"corner curve at x %.2f (expected %.2f, side wall %.2f)" % [hit.get("point", Vector3.ZERO).x, expect_x, goal.width / 2.0])
		# Low in a corner, where it meets the floor curve: still closed.
		hit = cast(Vector3(0, 0, d / 2.0), Vector3(goal.width, -goal.height, d * 2.0))
		check(not hit.is_empty(), "closed towards the back bottom corner")
		# Out the back corner: still closed.
		hit = cast(Vector3(0, 0, d / 2.0), Vector3(goal.width, goal.height, d * 2.0))
		check(not hit.is_empty(), "closed towards the back top corner")

	if once("roll", 0.5):
		# A plain sphere the size of RL's ball, rolling along the net floor at the back wall.
		sphere = RigidBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = SphereShape3D.new()
		shape.shape.radius = 0.9275
		sphere.add_child(shape)
		sphere.continuous_cd = true
		aquarium.add_child(sphere)
		sphere.global_position = goal.to_global(Vector3(0, -goal.height / 2.0 + 0.93, 1.5))
		sphere.linear_velocity = goal.global_basis * Vector3(0, 0, 10)
	if sphere and t > 0.5 and t < 4.0:
		var local := goal.to_local(sphere.global_position)
		peak_y = maxf(peak_y, local.y + goal.height / 2.0)
		deepest = maxf(deepest, local.z)
	if once("roll read", 4.0):
		var local := goal.to_local(sphere.global_position)
		var vz := (goal.global_basis.inverse() * sphere.linear_velocity).z
		print("sphere: deepest %.2f of %.2f, climbed %.2f m above the net floor, now at z %.2f moving %.2f m/s along the net" % [deepest, goal.depth, peak_y - 0.9275, local.z, vz])
		check(peak_y - 0.9275 > 1.0, "rolled up the back curve")
		check(local.z < deepest - 1.0, "came back towards the mouth")
	if once("quit", 4.2):
		print("goal_net_probe: %s" % ("all passed" if failures == 0 else "%d failed" % failures))
		get_tree().quit(1 if failures else 0)
