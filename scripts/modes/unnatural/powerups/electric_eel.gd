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
	return (settings.eel_radius + settings.eel_radius_per_stack * extra()) * size_scale()


func damage() -> float:
	return settings.eel_damage + settings.eel_damage_per_stack * extra()


func on_tick(delta: float) -> void:
	_cool = maxf(_cool - delta * rate_scale(), 0.0)


func on_battery(_index: int) -> void:
	if _cool > 0.0:
		return
	_cool = settings.eel_cooldown
	rings += 1
	var at := fish.global_position
	var reach := radius()
	PowerupFx.shock(run, at, reach, color(id), fish.global_basis.y)
	Sfx.play_at("pw/eel_shock_ring", at)
	run.hit_area(run.horde.query_sphere(at, reach), damage(), fish, id, at, 1.0, settings.eel_proc, [id])


## An eel wound round the middle, glowing.
func make_worn() -> Node3D:
	var coil := Node3D.new()
	coil.name = "Eel"
	var skin := worn_material(1.2)
	var around := maxf(fish.hitbox_width, fish.hitbox_height) * 0.5 + 0.04
	coil.add_child(worn_mesh(WornKit.eel(snappedf(around, 0.05), snappedf(fish.hitbox_length * 0.7, 0.1)), skin, Vector3.ZERO))
	coil.ready.connect(func() -> void:
		var hum := coil.create_tween().set_loops()
		hum.tween_property(skin, "emission_energy_multiplier", 2.6, 0.08)
		hum.tween_property(skin, "emission_energy_multiplier", 0.9, 0.4))
	return coil
