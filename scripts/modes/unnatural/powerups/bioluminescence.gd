class_name Bioluminescence
extends Powerup
## Bioluminescence (planning_unnatural.md §7b, rare): glowing spots. Every
## team level-up and every chest the fish opens sends out a flash
## biolum_radius m round it (more biolum_radius_per_stack a stack), doing
## biolum_damage (more biolum_damage_per_stack a stack) per team level to
## every zombie it reaches.

## Flashes sent, for the probes.
var flashes := 0
var _level := -1
var _chests := -1


func on_tick(_delta: float) -> void:
	if not is_instance_valid(fish):
		return
	var level: int = run.levels.level
	var chests: int = run.stats_of(fish).get("chests", 0)
	if _level >= 0 and (level > _level or chests > _chests):
		flash()
	_level = level
	_chests = chests


func flash() -> void:
	flashes += 1
	var at := fish.global_position
	var reach := (settings.biolum_radius + settings.biolum_radius_per_stack * extra()) * size_scale()
	var damage := (settings.biolum_damage + settings.biolum_damage_per_stack * extra()) * run.levels.level
	run.hit_area(run.horde.query_sphere(at, reach), damage, fish, id, at, 1.0, 1.0, [id])
	PowerupFx.flash(run, at, reach * 0.6, color(id), 0.5)
	PowerupFx.ring(run, at, reach, color(id), Vector3.UP, 0.5)
	Sfx.play("pw/eel_shock_ring")


## Glowing spots along the flanks.
func make_worn() -> Node3D:
	var spots := Node3D.new()
	spots.name = "Glowspots"
	var skin := worn_material(2.5)
	for side: float in [-1.0, 1.0]:
		for n in 3:
			var spot := worn_mesh(WornKit.ball(0.025), skin, Vector3(side * fish.hitbox_width * 0.5, 0.0, (n - 1) * fish.hitbox_length * 0.2))
			spot.scale = Vector3(0.6, 1.0, 1.0)  # flat on the skin
			spots.add_child(spot)
	return spots
