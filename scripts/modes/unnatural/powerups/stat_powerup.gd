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
			return {"armour": settings.barnacle_armour * eff()}
		"hermit_shell":
			return {"max_hp": settings.hermit_hp * eff()}
		"fizzy_soda":
			return {"attack_speed": settings.soda_attack_speed * eff()}
		"speedy_seahorse":
			return {"swim_speed": settings.seahorse_speed * eff()}
		"kelp_wrap":
			return {"regen": settings.kelp_regen * eff()}
		"sea_salt":
			return {"crit_chance": settings.salt_crit * eff()}
		"coral_knuckles":
			return {"battery_damage": settings.knuckles_battery * eff()}
		"divers_goggles":
			return {"pickup_range": settings.goggles_range * eff()}
		"lucky_sand_dollar":
			return {"luck": settings.dollar_luck * eff()}
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
		"kelp_wrap", "sea_salt", "coral_knuckles", "divers_goggles", "lucky_sand_dollar":
			return _trinket()
	return null


## A small glowing charm on the back in the item's colour: the other commons'
## look (kelp, salt, coral, goggles and the coin are all this, for now).
func _trinket() -> Node3D:
	var charm := Node3D.new()
	charm.name = "Trinket"
	charm.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.06, 0.0)
	var cut := worn_material(0.7)
	cut.roughness = 0.08
	cut.metallic = 0.3
	charm.add_child(worn_mesh(WornKit.gem(0.07), cut, Vector3(0.0, 0.0, fish.hitbox_length * (posmod(hash(id), 5) - 2) * 0.1)))
	return charm


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
		var cone := WornKit.barnacle(snappedf(dice.randf_range(0.05, 0.08), 0.01), snappedf(dice.randf_range(0.06, 0.11), 0.01))
		var at := Vector3(dice.randf_range(-0.12, 0.12), 0.0, dice.randf_range(-0.35, 0.35) * fish.hitbox_length)
		plating.add_child(worn_mesh(cone, shell, at, Vector3(dice.randf_range(-0.3, 0.3), 0.0, dice.randf_range(-0.3, 0.3))))
	return plating


## A spiral shell on the back: a cone of shrinking rings.
func _shell() -> Node3D:
	var home := Node3D.new()
	home.name = "HermitShell"
	home.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.02, fish.hitbox_length * 0.1)
	var material := worn_material(0.25)
	material.albedo_color = Color(0.92, 0.62, 0.48)
	home.add_child(worn_mesh(WornKit.cone_shell(0.32), material, Vector3.ZERO, Vector3(-1.1, 0.0, 0.0)))
	return home


## Bubbles rising off the gills, over and over.
func _bubbles() -> Node3D:
	var fizz := Node3D.new()
	fizz.name = "Fizz"
	var glass := FxKit.rim(Color(color(id).lerp(Color.WHITE, 0.3), 0.8), 0.04, 0.7)
	for side: float in [-1.0, 1.0]:
		for n in 3:
			var start := Vector3(side * fish.hitbox_width * 0.5, 0.0, -fish.hitbox_length * 0.2)
			var part := worn_mesh(WornKit.ball(0.035 + n * 0.012), glass, start)
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
	rider.add_child(worn_mesh(WornKit.seahorse(0.3), worn_material(0.4), Vector3.ZERO))
	return rider
