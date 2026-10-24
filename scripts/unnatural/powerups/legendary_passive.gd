class_name LegendaryPassive
extends Powerup
## The legendaries that change a rule rather than fire (planning_unnatural.md §7b):
## - Megalodon Tooth: a crit finishes off a zombie left under execute_share()
##   of its hp (not bosses; UnnaturalRun.hit asks);
## - Moon Pearl: pearl_picks more cards from each level-up's offer, a stack
##   (UnnaturalRun.pick);
## - Abyssal Engine: engine_projectiles more projectiles and engine_size more
##   Size, a stack.


func execute_share() -> float:
	if id != "megalodon_tooth" or stacks <= 0:
		return 0.0
	return minf(settings.tooth_execute + settings.tooth_execute_per_stack * (stacks - 1), settings.tooth_execute_max)


func extra_level_picks() -> int:
	return settings.pearl_picks * stacks if id == "moon_pearl" else 0


func stat_bonus() -> Dictionary:
	if id == "abyssal_engine":
		return {"projectile_count": settings.engine_projectiles * stacks, "size": settings.engine_size * stacks}
	return {}


func make_worn() -> Node3D:
	var look := Node3D.new()
	look.name = "Worn" + id.to_pascal_case()
	match id:
		"megalodon_tooth":
			# A big white tooth on a cord under the chin.
			look.position = Vector3(0.0, -fish.hitbox_height * 0.45, -fish.hitbox_length * 0.3)
			var tooth := PrismMesh.new()
			tooth.size = Vector3(0.1, 0.16, 0.03)
			look.add_child(worn_mesh(tooth, worn_material(0.4), Vector3.ZERO, Vector3(PI, 0.0, 0.0)))
		"moon_pearl":
			# A glowing pearl on the forehead.
			look.position = Vector3(0.0, fish.hitbox_height * 0.45, -fish.hitbox_length * 0.3)
			var pearl := SphereMesh.new()
			pearl.radius = 0.06
			pearl.height = 0.12
			pearl.radial_segments = 12
			pearl.rings = 6
			look.add_child(worn_mesh(pearl, worn_material(2.0), Vector3.ZERO))
		"abyssal_engine":
			# A churning engine on the back: a drum and its spinning ring.
			look.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.06, fish.hitbox_length * 0.1)
			var drum := CylinderMesh.new()
			drum.top_radius = 0.07
			drum.bottom_radius = 0.07
			drum.height = 0.14
			drum.radial_segments = 10
			look.add_child(worn_mesh(drum, worn_material(0.3), Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0)))
			var ring := TorusMesh.new()
			ring.inner_radius = 0.08
			ring.outer_radius = 0.1
			ring.rings = 16
			ring.ring_segments = 4
			var spin := worn_mesh(ring, worn_material(2.0), Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0))
			look.add_child(spin)
			look.ready.connect(func() -> void:
				var turn := spin.create_tween().set_loops()
				turn.tween_property(spin, "rotation:y", TAU, 1.2).from(0.0))
	return look
