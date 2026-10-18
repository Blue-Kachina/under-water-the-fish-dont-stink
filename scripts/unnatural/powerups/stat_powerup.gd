class_name StatPowerup
extends Powerup
## The commons that only add to a stat (planning_unnatural.md §7b, D14), each a
## stack: Barnacle Plating (armour), Hermit Shell (max hp), Fizzy Soda (attack
## speed), Speedy Seahorse (swim speed). Powerups puts what they give on the
## player's StatBlock (its bonus), so they work through the same paths as the
## level-up cards.

func stat_bonus() -> Dictionary:
	match id:
		"barnacle_plating":
			return {"armour": settings.barnacle_armour * stacks}
		"hermit_shell":
			return {"max_hp": settings.hermit_hp * stacks}
		"fizzy_soda":
			return {"attack_speed": settings.soda_attack_speed * stacks}
		"speedy_seahorse":
			return {"swim_speed": settings.seahorse_speed * stacks}
	return {}


func make_worn() -> Node3D:
	match id:
		"barnacle_plating":
			return _barnacles()
		"hermit_shell":
			return _shell()
		"fizzy_soda":
			return _bubbles()
		"speedy_seahorse":
			return _seahorse()
	return null


## Little cones clustered along the back.
func _barnacles() -> Node3D:
	var plating := Node3D.new()
	plating.name = "Barnacles"
	plating.position = Vector3(0.0, fish.hitbox_height * 0.45, 0.0)
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.78, 0.74, 0.64)
	shell.roughness = 0.9
	var dice := RandomNumberGenerator.new()
	dice.seed = 1717
	for n in 7:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.025
		cone.bottom_radius = dice.randf_range(0.05, 0.08)
		cone.height = dice.randf_range(0.06, 0.11)
		cone.radial_segments = 6
		cone.rings = 1
		var at := Vector3(dice.randf_range(-0.12, 0.12), 0.0, dice.randf_range(-0.35, 0.35) * fish.hitbox_length)
		plating.add_child(worn_mesh(cone, shell, at, Vector3(dice.randf_range(-0.3, 0.3), 0.0, dice.randf_range(-0.3, 0.3))))
	return plating


## A spiral shell on the back: a cone of shrinking rings.
func _shell() -> Node3D:
	var home := Node3D.new()
	home.name = "HermitShell"
	home.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.08, fish.hitbox_length * 0.1)
	var material := worn_material(0.25)
	material.albedo_color = Color(0.92, 0.62, 0.48)
	for n in 4:
		var whorl := SphereMesh.new()
		whorl.radius = 0.16 - n * 0.035
		whorl.height = whorl.radius * 1.6
		whorl.radial_segments = 10
		whorl.rings = 5
		home.add_child(worn_mesh(whorl, material, Vector3(0.0, n * 0.07, n * 0.05)))
	return home


## Bubbles rising off the gills, over and over.
func _bubbles() -> Node3D:
	var fizz := Node3D.new()
	fizz.name = "Fizz"
	var glass := worn_material(0.8)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(color(id), 0.55)
	for side: float in [-1.0, 1.0]:
		for n in 3:
			var bubble := SphereMesh.new()
			bubble.radius = 0.035 + n * 0.012
			bubble.height = bubble.radius * 2.0
			bubble.radial_segments = 8
			bubble.rings = 4
			var start := Vector3(side * fish.hitbox_width * 0.5, 0.0, -fish.hitbox_length * 0.2)
			var part := worn_mesh(bubble, glass, start)
			fizz.add_child(part)
			part.ready.connect(func() -> void:
				var rise := part.create_tween().set_loops()
				rise.tween_property(part, "position", start + Vector3(side * 0.08, 0.35, 0.1), 0.6 + n * 0.15).from(start)
				rise.tween_interval(n * 0.1))
	return fizz


## A little seahorse riding on the back: a curled body and a snout.
func _seahorse() -> Node3D:
	var rider := Node3D.new()
	rider.name = "Seahorse"
	rider.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.12, -fish.hitbox_length * 0.05)
	var gold := worn_material(0.4)
	var body := CapsuleMesh.new()
	body.radius = 0.05
	body.height = 0.24
	body.radial_segments = 8
	body.rings = 2
	rider.add_child(worn_mesh(body, gold, Vector3.ZERO, Vector3(-0.3, 0.0, 0.0)))
	var head := SphereMesh.new()
	head.radius = 0.055
	head.height = 0.11
	head.radial_segments = 8
	head.rings = 4
	rider.add_child(worn_mesh(head, gold, Vector3(0.0, 0.13, -0.04)))
	var snout := CylinderMesh.new()
	snout.top_radius = 0.015
	snout.bottom_radius = 0.02
	snout.height = 0.09
	snout.radial_segments = 6
	rider.add_child(worn_mesh(snout, gold, Vector3(0.0, 0.13, -0.1), Vector3(PI / 2.0, 0.0, 0.0)))
	var tail := TorusMesh.new()
	tail.inner_radius = 0.02
	tail.outer_radius = 0.05
	tail.rings = 10
	tail.ring_segments = 5
	rider.add_child(worn_mesh(tail, gold, Vector3(0.0, -0.14, 0.03), Vector3(0.0, 0.0, PI / 2.0)))
	return rider
