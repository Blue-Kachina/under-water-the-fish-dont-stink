class_name SonarPinger
extends Powerup
## Sonar Pinger (planning_unnatural.md §7b, uncommon): a dish on the head.
## Every sonar_every s (sooner with attack speed) a pulse marks every zombie
## within sonar_radius m until the next; this player's hits on a marked zombie
## do sonar_bonus more (more sonar_bonus_per_stack a stack; UnnaturalRun.hit
## asks bonus_on()).

## Pings sent, for the probes.
var pings := 0
var _left := 0.0


func every() -> float:
	return settings.sonar_every / rate_scale()


func bonus() -> float:
	return settings.sonar_bonus + settings.sonar_bonus_per_stack * (stacks - 1)


func on_tick(delta: float) -> void:
	_left -= delta
	if _left > 0.0 or not is_instance_valid(fish):
		return
	_left = every()
	ping()


## A pulse round the fish, marking what it reaches.
func ping() -> void:
	pings += 1
	var at := fish.global_position
	var reach := settings.sonar_radius * area_scale()
	for i in run.horde.query_sphere(at, reach):
		run.horde.mark(i, every() + 0.25)
	PowerupFx.ring(run, at, reach, color(id), Vector3.UP, 0.6)


func bonus_on(index: int) -> float:
	return bonus() if stacks > 0 and run.horde.is_alive(index) and run.horde.is_marked(index) else 0.0


## A little dish on a stalk on the head.
func make_worn() -> Node3D:
	var dish := Node3D.new()
	dish.name = "Sonar"
	dish.position = Vector3(0.0, fish.hitbox_height * 0.5, -fish.hitbox_length * 0.2)
	var skin := worn_material(0.8)
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.012
	stalk.bottom_radius = 0.012
	stalk.height = 0.14
	stalk.radial_segments = 5
	dish.add_child(worn_mesh(stalk, skin, Vector3(0.0, 0.07, 0.0)))
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.09
	bowl.bottom_radius = 0.02
	bowl.height = 0.05
	bowl.radial_segments = 12
	dish.add_child(worn_mesh(bowl, skin, Vector3(0.0, 0.16, -0.02), Vector3(-0.6, 0.0, 0.0)))
	return dish
