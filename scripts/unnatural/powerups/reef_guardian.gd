class_name ReefGuardian
extends Powerup
## Reef Guardian (planning_unnatural.md §7b, rare): a coral crown. A hit that
## leaves the fish under guardian_threshold of its max hp makes it untouchable
## for guardian_time s; then the crown rests guardian_cooldown s (each more
## stack takes guardian_cooldown_per_stack of that off).

## Times it saved the fish, for the probes.
var saves := 0
var _resting := 0.0


func cooldown() -> float:
	return settings.guardian_cooldown * pow(1.0 - settings.guardian_cooldown_per_stack, extra())


func is_ready() -> bool:
	return _resting <= 0.0


func on_tick(delta: float) -> void:
	_resting = maxf(_resting - delta, 0.0)
	if _worn and is_instance_valid(_worn):
		_worn.visible = is_ready() or fmod(_resting, 1.0) < 0.15  # glints while it rests


func on_hurt(_amount: float, _from: int) -> void:
	var health := run.health_of(fish)
	if not is_ready() or health == null or health.down or health.hp >= health.max_hp * settings.guardian_threshold:
		return
	_resting = cooldown()
	saves += 1
	health.shield(settings.guardian_time * duration_scale())
	PowerupFx.shock(run, fish.global_position, fish.hitbox_length * 1.5, color(id), Vector3.UP, 0.6)
	PowerupFx.flash(run, fish.global_position, fish.hitbox_length, color(id), 0.5)
	Sfx.play("pw/bubble_wrap_pop")


## A ring of coral branches on the head.
func make_worn() -> Node3D:
	var crown := Node3D.new()
	crown.name = "Crown"
	crown.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.02, -fish.hitbox_length * 0.15)
	# A little branching coral crown.
	var coral := worn_mesh(ReefKit.mesh("staghorn", 2), worn_material(0.7), Vector3.ZERO)
	coral.scale = Vector3.ONE * 0.2
	crown.add_child(coral)
	return crown
