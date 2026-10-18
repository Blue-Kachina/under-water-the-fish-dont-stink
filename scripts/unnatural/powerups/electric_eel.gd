class_name ElectricEel
extends Powerup
## Electric Eel (planning_unnatural.md §7b, D14, uncommon): an eel coiled
## round the fish. A battery sends out a shock ring, radius() m round, doing
## damage() to every zombie in it (proc coefficient eel_proc); at most one
## ring every eel_cooldown s, so battering through a crowd isn't a ring a zombie.

## Rings so far, for the probes.
var rings := 0
var _cool := 0.0


func radius() -> float:
	return settings.eel_radius + settings.eel_radius_per_stack * (stacks - 1)


func damage() -> float:
	return settings.eel_damage + settings.eel_damage_per_stack * (stacks - 1)


func on_tick(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)


func on_battery(_index: int) -> void:
	if _cool > 0.0:
		return
	_cool = settings.eel_cooldown
	rings += 1
	var at := fish.global_position
	var reach := radius()
	PowerupFx.ring(run, at, reach, color(id), fish.global_basis.y)
	for i in run.horde.query_sphere(at, reach):
		var push := run.horde.enemy_position(i) - at
		run.hit(i, damage(), fish, id, push.normalized() if push.length_squared() > 0.0001 else Vector3.UP, settings.eel_proc, [id])


## An eel wound round the middle, glowing.
func make_worn() -> Node3D:
	var coil := Node3D.new()
	coil.name = "Eel"
	var skin := worn_material(1.2)
	for n in 2:
		var turn := TorusMesh.new()
		turn.inner_radius = maxf(fish.hitbox_width, fish.hitbox_height) * 0.5
		turn.outer_radius = turn.inner_radius + 0.07
		turn.rings = 20
		turn.ring_segments = 6
		coil.add_child(worn_mesh(turn, skin, Vector3(0.0, 0.0, (n - 0.5) * fish.hitbox_length * 0.3), Vector3(PI / 2.0, 0.0, 0.25 * (n * 2 - 1))))
	coil.ready.connect(func() -> void:
		var hum := coil.create_tween().set_loops()
		hum.tween_property(skin, "emission_energy_multiplier", 2.6, 0.08)
		hum.tween_property(skin, "emission_energy_multiplier", 0.9, 0.4))
	return coil
