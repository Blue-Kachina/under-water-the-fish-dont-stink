class_name AttackWeapon
extends Powerup
## Another fish's weapon held as a second one (Weapons.ATTACK_WEAPONS): the
## Clownfish's Anemone Sting on a Shark, the Lionfish's Greek Fire on a Koi.
## It owns its own FishAttack, fired on the run's tick like the fish's own,
## with the player's stats and its own facets and level (its stacks) put on it
## (FishAttack.configure), just as UnnaturalRun._apply_stats does for the
## fish's own. The attack wears its own look on the fish.

## Its attack (made when it's first held).
var attack: FishAttack


func kind() -> FishAttack.Kind:
	return Weapons.ATTACK_WEAPONS.get(id, FishAttack.Kind.BITE)


func on_stacks_changed() -> void:
	_ensure()


func on_tick(delta: float) -> void:
	if not is_instance_valid(fish) or stacks <= 0:
		return
	_ensure()
	attack.update(delta, run.is_up(fish) and not run.is_over)


func on_kill(at: Vector3, source: String) -> void:
	if is_instance_valid(attack):
		attack.on_kill(at, source)


## Makes its attack if it hasn't one, and puts the player's stats and its
## facets and level on it.
func _ensure() -> void:
	if not is_instance_valid(fish) or stacks <= 0:
		return
	if not is_instance_valid(attack):
		attack = FishAttack.make(kind())
		attack.name = "Extra" + FishAttack.source_of(kind()).to_pascal_case()
		attack.fish = fish
		attack.horde = run.horde
		attack.settings = run.settings
		attack.run = run
		attack.powers = settings
		attack.on_hit = run.hit
		run.add_child(attack)
	attack.configure(run.block_of(fish), run.loadout_of(fish).facets_of(id), stacks)


## The attack wears its own look (FishAttack.wear).
func wear() -> void:
	pass


func on_removed() -> void:
	if is_instance_valid(attack):
		attack.take_off()  # off now, not at the frame's end
		attack.queue_free()
	attack = null
