class_name Riptide
extends Powerup
## Riptide (planning_unnatural.md §7b, rare): swirling water. A stride timed
## at its peak (SwishySwim's timing riptide_timing or better) leaves a current
## riptide_length m back along the way the fish came, for riptide_time s:
## zombies in it (riptide_width m either side) are dragged back riptide_drag
## m/s and take riptide_dps a second (more riptide_dps_per_stack a stack).

## Currents left, for the probes.
var currents := 0
var _out: Array[Current] = []


func on_stride(timing: float) -> void:
	if timing < settings.riptide_timing or not is_instance_valid(fish):
		return
	var velocity := fish.swim_velocity()
	var heading := velocity.normalized() if velocity.length_squared() > 0.25 else -fish.global_basis.z
	leave(fish.global_position, fish.global_position - heading * settings.riptide_length)


## A current from `from` back to `to`.
func leave(from: Vector3, to: Vector3) -> Current:
	_out = _out.filter(func(current: Current) -> bool: return is_instance_valid(current))
	var current := Current.new()
	current.owner_tide = self
	current.from = from
	current.to = to
	current.width = settings.riptide_width * size_scale()
	current.life = settings.riptide_time * duration_scale()
	current.dps = settings.riptide_dps + settings.riptide_dps_per_stack * (stacks - 1)
	current.drag = settings.riptide_drag
	run.add_child(current)
	_out.append(current)
	currents += 1
	GhostSwordfish.streak(run, from, to, color(id), current.width * 1.6, current.life)
	return current


func on_removed() -> void:
	for current in _out:
		if is_instance_valid(current):
			current.queue_free()
	_out.clear()


## Swirls of water round the tail.
func make_worn() -> Node3D:
	var swirl := Node3D.new()
	swirl.name = "Riptide"
	swirl.position = Vector3(0.0, 0.0, fish.hitbox_length * 0.45)
	var skin := worn_material(0.5)
	for n in 2:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.12 + n * 0.06
		ring.outer_radius = 0.14 + n * 0.06
		ring.rings = 16
		ring.ring_segments = 4
		swirl.add_child(worn_mesh(ring, skin, Vector3(0.0, 0.0, n * 0.08), Vector3(PI * 0.5, 0.0, 0.0)))
	return swirl


## One current: every TICK s it drags the zombies along it back and hurts them.
class Current extends Node:
	const TICK := 0.2
	var owner_tide: Riptide
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var width := 2.5
	var life := 3.0
	var dps := 25.0
	var drag := 8.0
	var _age := 0.0
	var _tick := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= life or not is_instance_valid(owner_tide) or owner_tide.run == null:
			queue_free()
			return
		_tick -= delta
		if _tick > 0.0:
			return
		_tick += TICK
		var run := owner_tide.run
		var length := from.distance_to(to)
		var back := (to - from) / maxf(length, 0.01)
		var caught := PackedInt32Array()
		for i in run.horde.query_sphere((from + to) * 0.5, length * 0.5 + width):
			var at := run.horde.enemy_position(i)
			var along := clampf((at - from).dot(back), 0.0, length)
			if at.distance_to(from + back * along) > width + run.horde.enemy_radius(i):
				continue
			if not run.horde.is_proxy(i):
				run.horde.shove(i, back * drag)
			caught.append(i)
		if is_instance_valid(owner_tide.fish):
			run.hit_area(caught, dps * TICK, owner_tide.fish, owner_tide.id, Vector3.INF, 0.0, run.powerup_settings.fire_proc, [owner_tide.id])
