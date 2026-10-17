class_name BowGrowBow
extends Powerup
## Bow Grow Bow (planning_unnatural.md §7): the fish wears a bow (a ribbon on
## its head), and its bow wave grows (length and girth times 1 + bow_growth
## per stack, FishController.bow_scale). The bow wave already counts for
## batteries, so it batters far wider; the Shark's bite grows with it (it
## always out-reaches the bow wave). From bow_low_speed_stacks stacks the bow
## wave batters below the battering speed too (Powerups.batter_speed_share()).

var _ribbon: Node3D


func on_stacks_changed() -> void:
	fish.bow_scale = 1.0 + settings.bow_growth * stacks
	if _ribbon == null or not is_instance_valid(_ribbon):
		_ribbon = _make_ribbon()
		fish.add_child(_ribbon)
	_ribbon.scale = Vector3.ONE * (1.0 + 0.15 * (stacks - 1))


func on_removed() -> void:
	if is_instance_valid(fish):
		fish.bow_scale = 1.0
	if _ribbon and is_instance_valid(_ribbon):
		_ribbon.queue_free()
	_ribbon = null


## Two loops and a knot, on top of the fish's head.
func _make_ribbon() -> Node3D:
	var ribbon := Node3D.new()
	ribbon.name = "Bow"
	ribbon.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.05, -fish.hitbox_length * 0.2)
	var satin := StandardMaterial3D.new()
	satin.albedo_color = Powerup.color(id)
	satin.roughness = 0.35
	satin.emission_enabled = true
	satin.emission = Powerup.color(id)
	satin.emission_energy_multiplier = 0.35
	for side: float in [-1.0, 1.0]:
		var loop := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		sphere.material = satin
		loop.mesh = sphere
		loop.scale = Vector3(1.4, 0.8, 0.5)
		loop.position = Vector3(side * 0.15, 0.04, 0.0)
		loop.rotation.z = side * 0.4
		ribbon.add_child(loop)
	var knot := MeshInstance3D.new()
	var bead := SphereMesh.new()
	bead.radius = 0.06
	bead.height = 0.12
	bead.material = satin
	knot.mesh = bead
	ribbon.add_child(knot)
	return ribbon
