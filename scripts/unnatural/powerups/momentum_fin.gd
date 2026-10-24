class_name MomentumFin
extends Powerup
## Momentum Fin (planning_unnatural.md §7b, uncommon): streamers off the fins.
## The faster the fish swims, the harder its hits land: momentum_damage more
## per momentum_speed m/s, a stack (UnnaturalRun.hit asks damage_factor()).


func damage_factor() -> float:
	if not is_instance_valid(fish) or stacks <= 0:
		return 1.0
	return 1.0 + settings.momentum_damage * eff() * fish.speed / maxf(settings.momentum_speed, 0.1)


## Two bright streamers trailing from the back fins.
func make_worn() -> Node3D:
	var streamers := Node3D.new()
	streamers.name = "Streamers"
	var skin := worn_material(0.8)
	for side: float in [-1.0, 1.0]:
		var ribbon := BoxMesh.new()
		ribbon.size = Vector3(0.04, 0.02, 0.8)
		streamers.add_child(worn_mesh(ribbon, skin, Vector3(side * fish.hitbox_width * 0.5, 0.0, fish.hitbox_length * 0.5 + 0.3), Vector3(0.0, side * 0.15, 0.0)))
	return streamers
