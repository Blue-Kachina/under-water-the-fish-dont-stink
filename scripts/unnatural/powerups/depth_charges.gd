class_name DepthCharges
extends Powerup
## Depth Charges (planning_unnatural.md §7b, D14, rare): a mine rack under the
## fish. A mine drops behind it every interval() s; it arms after charge_arm
## s, then blows when a zombie comes within charge_trigger m (or when
## charge_life s are up): damage() to every zombie within blast() m (proc
## coefficient charge_proc). At most charge_max mines out (the oldest goes).

## Mines dropped and blown so far, for the probes.
var dropped := 0
var blown := 0
var mines: Array[Mine] = []
var _next := 0.0


func interval() -> float:
	return settings.charge_interval * pow(1.0 - settings.charge_interval_per_stack, stacks - 1)


func damage() -> float:
	return settings.charge_damage + settings.charge_damage_per_stack * (stacks - 1)


func blast() -> float:
	return settings.charge_blast + settings.charge_blast_per_stack * (stacks - 1)


func on_tick(delta: float) -> void:
	_next -= delta
	if _next <= 0.0:
		_next = interval()
		drop()
	for k in range(mines.size() - 1, -1, -1):
		var mine := mines[k]
		if not is_instance_valid(mine):
			mines.remove_at(k)
			continue
		mine.age += delta
		var armed := mine.age >= settings.charge_arm
		if mine.age >= settings.charge_life or (armed and not run.horde.query_sphere(mine.global_position, settings.charge_trigger).is_empty()):
			mines.remove_at(k)
			explode(mine.global_position)
			mine.queue_free()


## A mine behind the fish, now.
func drop() -> void:
	while mines.size() >= settings.charge_max:
		var oldest: Mine = mines.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var mine := Mine.new()
	mine.tint = color(id)
	run.add_child(mine)
	mine.global_position = fish.global_position + fish.global_basis.z * (fish.hitbox_length * 0.6)
	mines.append(mine)
	dropped += 1


func explode(at: Vector3) -> void:
	blown += 1
	var reach := blast()
	Explosion.spawn(run.ocean, at, color(id), reach, 0.0, 0.3)
	for i in run.horde.query_sphere(at, reach):
		var push := run.horde.enemy_position(i) - at
		run.hit(i, damage(), fish, id, push.normalized() if push.length_squared() > 0.0001 else Vector3.UP, settings.charge_proc, [id])


func on_removed() -> void:
	for mine in mines:
		if is_instance_valid(mine):
			mine.queue_free()
	mines.clear()


## A little rack of mines under the belly.
func make_worn() -> Node3D:
	var rack := Node3D.new()
	rack.name = "MineRack"
	rack.position = Vector3(0.0, -fish.hitbox_height * 0.5 - 0.06, fish.hitbox_length * 0.15)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.3, 0.33, 0.3)
	steel.metallic = 0.7
	steel.roughness = 0.45
	var bar := BoxMesh.new()
	bar.size = Vector3(0.06, 0.04, fish.hitbox_length * 0.45)
	rack.add_child(worn_mesh(bar, steel, Vector3(0.0, 0.03, 0.0)))
	var ball := SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	ball.radial_segments = 8
	ball.rings = 4
	for n in 3:
		rack.add_child(worn_mesh(ball, steel, Vector3(0.0, -0.05, (n - 1) * fish.hitbox_length * 0.14)))
	return rack


## One mine: a spiked ball with a blinking light, bobbing where it was dropped.
class Mine extends Node3D:
	var age := 0.0
	var tint := Color.WHITE
	var _light_material := StandardMaterial3D.new()

	func _ready() -> void:
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color(0.28, 0.3, 0.28)
		steel.metallic = 0.7
		steel.roughness = 0.4
		var ball := SphereMesh.new()
		ball.radius = 0.3
		ball.height = 0.6
		ball.radial_segments = 10
		ball.rings = 5
		add_child(Powerup.worn_mesh(ball, steel, Vector3.ZERO))
		var spike := CylinderMesh.new()
		spike.top_radius = 0.02
		spike.bottom_radius = 0.05
		spike.height = 0.18
		spike.radial_segments = 5
		spike.rings = 1
		for out: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var part := Powerup.worn_mesh(spike, steel, out * 0.33)
			if absf(out.y) < 0.5:
				part.basis = Basis(Quaternion(Vector3.UP, out))
			elif out.y < 0.0:
				part.basis = Basis(Vector3.RIGHT, PI)
			add_child(part)
		_light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_light_material.albedo_color = Color(1.0, 0.2, 0.15)
		var light := SphereMesh.new()
		light.radius = 0.07
		light.height = 0.14
		light.radial_segments = 6
		light.rings = 3
		add_child(Powerup.worn_mesh(light, _light_material, Vector3(0.0, 0.32, 0.0)))

	func _process(delta: float) -> void:
		position.y += sin(age * 2.5) * 0.15 * delta
		var blink := fmod(age * 3.0, 1.0) < 0.5
		_light_material.albedo_color = Color(1.0, 0.2, 0.15) if blink else Color(0.25, 0.05, 0.05)
