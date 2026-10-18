class_name DrownedFin
extends Powerup
## Drowned Fin (planning_unnatural.md §7b, D13, boss: the Drowned Shark's):
## pressing boost with the fin ready charges. The fish dashes ahead at
## fin_dash_speed, untouchable for fin_dash_time s, battering everything in
## the way (at that speed every battery lands, and each zombie it passes
## within fin_radius takes fin_damage once). Then the fin needs cooldown() s.

## Dashes so far, and zombies they've struck, for the probes.
var dashes := 0
var struck := 0
var _cool := 0.0
var _dash_left := 0.0
var _heading := Vector3.FORWARD
var _hit := {}
var _loop := 0


func cooldown() -> float:
	return settings.fin_cooldown * pow(1.0 - settings.fin_cooldown_per_stack, stacks - 1)


func damage() -> float:
	return settings.fin_damage + settings.fin_damage_per_stack * (stacks - 1)


func is_ready() -> bool:
	return _cool <= 0.0 and _dash_left <= 0.0


func is_dashing() -> bool:
	return _dash_left > 0.0


func on_tick(delta: float) -> void:
	if _dash_left > 0.0:
		_dash_left -= delta
		_dash_step()
		if _dash_left <= 0.0:
			Sfx.stop_loop(_loop)
			_loop = 0
	else:
		_cool = maxf(_cool - delta, 0.0)
		if is_ready() and not fish.puppet and fish._player_input().just_pressed("boost"):
			dash()


## Charges now (if ready).
func dash() -> void:
	if not is_ready():
		return
	dashes += 1
	_dash_left = settings.fin_dash_time
	_cool = cooldown()
	_hit.clear()
	_heading = -fish.global_basis.z
	var along := fish.linear_velocity.dot(_heading)
	fish.apply_push(_heading * maxf(settings.fin_dash_speed - along, 0.0))
	var health := run.health_of(fish)
	if health:
		health.shield(settings.fin_dash_time + 0.1)
	PowerupFx.ring(run, fish.global_position, 1.5, color(id), _heading, 0.3)
	Sfx.play_at("pw/drowned_fin_dash", fish.global_position)
	Sfx.stop_loop(_loop)
	_loop = Sfx.start_loop("pw/drowned_fin_charge_loop")


func _dash_step() -> void:
	var at := fish.global_position
	for i in run.horde.query_sphere(at, settings.fin_radius):
		if _hit.has(i):
			continue
		_hit[i] = true
		struck += 1
		run.hit(i, damage(), fish, id, _heading, settings.fin_proc, [id])


## A ragged dorsal fin, pale and drowned.
func make_worn() -> Node3D:
	var fin := Node3D.new()
	fin.name = "DrownedFin"
	var material := worn_material(0.5)
	material.albedo_color = Color(0.6, 0.72, 0.78)
	var blade := PrismMesh.new()
	blade.size = Vector3(0.36, 0.34, 0.04)
	blade.left_to_right = 0.85
	fin.add_child(worn_mesh(blade, material, Vector3(0.0, fish.hitbox_height * 0.5 + 0.15, 0.05), Vector3(0.0, PI / 2.0, 0.0)))
	return fin
