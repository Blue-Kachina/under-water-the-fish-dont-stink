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
	return minf(settings.tooth_execute + settings.tooth_execute_per_stack * extra(), settings.tooth_execute_max)


func extra_level_picks() -> int:
	return roundi(settings.pearl_picks * eff()) if id == "moon_pearl" else 0


func stat_bonus() -> Dictionary:
	if id == "abyssal_engine":
		return {"quantity": settings.engine_projectiles * eff(), "size": settings.engine_size * eff()}
	return {}


func make_worn() -> Node3D:
	var look := Node3D.new()
	look.name = "Worn" + id.to_pascal_case()
	match id:
		"megalodon_tooth":
			# A big serrated tooth on a cord under the chin.
			look.position = Vector3(0.0, -fish.hitbox_height * 0.45, -fish.hitbox_length * 0.3)
			var enamel := worn_material(0.4)
			enamel.albedo_color = Color(0.95, 0.92, 0.85)
			look.add_child(worn_mesh(WornKit.tooth(0.18), enamel, Vector3.ZERO))
			look.add_child(worn_mesh(WornKit.ring(0.04, 0.008), worn_material(0.1), Vector3(0.0, 0.1, 0.0), Vector3(PI / 2.0, 0.0, 0.0)))
		"moon_pearl":
			# A glowing pearl on the forehead.
			look.position = Vector3(0.0, fish.hitbox_height * 0.45, -fish.hitbox_length * 0.3)
			var nacre := worn_material(2.0)
			nacre.roughness = 0.1
			nacre.clearcoat_enabled = true
			look.add_child(worn_mesh(WornKit.ball(0.06), nacre, Vector3.ZERO))
		"abyssal_engine":
			# A churning engine on the back: a ribbed drum and its spinning ring.
			look.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.06, fish.hitbox_length * 0.1)
			look.add_child(worn_mesh(WornKit.barrel_tube(0.14, 0.07), worn_material(0.3), Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0)))
			var spin := worn_mesh(WornKit.ring(0.09, 0.02), worn_material(2.0), Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0))
			look.add_child(spin)
			look.ready.connect(func() -> void:
				var turn := spin.create_tween().set_loops()
				turn.tween_property(spin, "rotation:y", TAU, 1.2).from(0.0))
	return look
