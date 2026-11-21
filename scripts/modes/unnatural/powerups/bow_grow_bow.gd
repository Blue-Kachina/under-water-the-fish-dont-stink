class_name BowGrowBow
extends Powerup
## Bow Grow Bow (planning_unnatural.md §7): the fish wears a bow (a ribbon on
## its head), and its bow wave grows (length and girth times 1 + bow_growth
## per stack, FishController.bow_scale). The bow wave already counts for
## batteries, so it batters far wider; the Shark's bite grows with it (it
## always out-reaches the bow wave). From bow_low_speed_stacks stacks the bow
## wave batters below the battering speed too (Powerups.batter_speed_share()).

func on_stacks_changed() -> void:
	fish.bow_scale = 1.0 + settings.bow_growth * eff()


func on_removed() -> void:
	if is_instance_valid(fish):
		fish.bow_scale = 1.0


## Two loops and a knot, on top of the fish's head.
func make_worn() -> Node3D:
	var ribbon := Node3D.new()
	ribbon.name = "Bow"
	ribbon.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.08, -fish.hitbox_length * 0.2)
	var satin := StandardMaterial3D.new()
	satin.albedo_color = Powerup.color(id)
	satin.roughness = 0.35
	satin.cull_mode = BaseMaterial3D.CULL_DISABLED
	satin.emission_enabled = true
	satin.emission = Powerup.color(id)
	satin.emission_energy_multiplier = 0.35
	ribbon.add_child(worn_mesh(WornKit.bow(), satin, Vector3.ZERO))
	return ribbon
