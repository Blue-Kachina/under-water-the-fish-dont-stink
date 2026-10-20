class_name AttackWeapon
extends Powerup
## A fish's attack held as an extra weapon (Weapons.ATTACK_WEAPONS): the
## Clownfish's Anemone Sting on a Shark, say. It owns its own FishAttack,
## fired on the run's tick like the fish's own, with the player's stats and
## its own facets and milestones (its level is its stacks) on top, just as
## UnnaturalRun._apply_stats does for the fish's own attack.

## Its attack (made on the first tick).
var attack: FishAttack


func kind() -> FishAttack.Kind:
	return Weapons.ATTACK_WEAPONS.get(id, FishAttack.Kind.BITE)


func on_tick(delta: float) -> void:
	if not is_instance_valid(fish) or stacks <= 0:
		return
	if not is_instance_valid(attack):
		attack = FishAttack.make(kind())
		attack.name = "Extra" + FishAttack.source_of(kind()).capitalize()
		attack.fish = fish
		attack.horde = run.horde
		attack.settings = run.settings
		attack.on_hit = run.hit
		run.add_child(attack)
	_apply()
	attack.update(delta, run.is_up(fish) and not run.is_over)


## The player's stats and this weapon's facets on its attack.
func _apply() -> void:
	var block := run.block_of(fish)
	attack.attack_speed = (1.0 + block.value("attack_speed")) * (1.0 + facet("rate"))
	attack.area_scale = (1.0 + block.value("area")) * (1.0 + facet("size"))
	attack.damage_scale = 1.0 + facet("damage")
	attack.knock_scale = 1.0 + facet("knock")
	attack.extra_projectiles = roundi(block.value("projectile_count") + facet("count"))
	attack.projectile_speed = (1.0 + block.value("projectile_speed")) * (1.0 + facet("speed"))
	attack.milestones = run.settings.milestones_at(stacks)


func on_removed() -> void:
	if is_instance_valid(attack):
		attack.queue_free()
	attack = null
