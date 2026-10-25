class_name CursedPowerup
extends Powerup
## The cursed powerups (planning_unnatural.md §7b, D13): strong, each with a
## catch. They come only from the blood-red cursed chest, and luck doesn't help.
## - Blood Moon Shard: +shard_damage damage, +shard_taken damage taken (a stack).
## - Glass Coral: +coral_damage damage; max hp times coral_hp (a stack).
## - Siren's Song: +siren_xp XP gain; siren_horde more zombies (a stack).
## - Abyssal Hunger: a kill heals hunger_heal of max hp; lose hunger_drain of
##   max hp a second (never below 1 hp unless hunger_can_kill).
## - Sunken Idol: one more pick from every chest (a stack, UnnaturalRun); each
##   stage event takes one stack of a random other powerup earned.

## Powerups the Sunken Idol has taken so far, for the probes.
var taken: Array[String] = []


func stat_bonus() -> Dictionary:
	match id:
		"blood_moon_shard":
			return {"damage": settings.shard_damage * stacks}
		"glass_coral":
			return {"damage": settings.coral_damage * stacks}
		"sirens_song":
			return {"xp_gain": settings.siren_xp * stacks}
	return {}


func taken_factor() -> float:
	return 1.0 + settings.shard_taken * stacks if id == "blood_moon_shard" else 1.0


func max_hp_factor() -> float:
	return pow(settings.coral_hp, stacks) if id == "glass_coral" else 1.0


func horde_factor() -> float:
	return 1.0 + settings.siren_horde * stacks if id == "sirens_song" else 1.0


func on_kill(_at: Vector3, _source: String) -> void:
	if id != "abyssal_hunger":
		return
	var health := run.health_of(fish)
	if health:
		health.heal(health.max_hp * settings.hunger_heal * stacks)


func on_tick(delta: float) -> void:
	if id != "abyssal_hunger":
		return
	var health := run.health_of(fish)
	if health == null or health.down:
		return
	var drain := health.max_hp * settings.hunger_drain * stacks * delta
	if settings.hunger_can_kill:
		health.hp -= drain
		if health.hp <= 0.0:
			health.hp = 0.01
			health.iframes_left = 0.0
			run.hurt(fish, 1.0, -1, "hunger (a curse)")  # the last of it: down, as a hit would put it
	else:
		health.hp = maxf(health.hp - drain, minf(health.hp, 1.0))


func on_stage_event(_event: String) -> void:
	if id != "sunken_idol":
		return
	var powerups := run.powerups_of(fish)
	var choices: Array[String] = []
	for other in powerups.earned():
		if other != id:
			choices.append(other)
	if choices.is_empty():
		return
	var lost := choices[run.rng.randi_range(0, choices.size() - 1)]
	taken.append(lost)
	powerups.remove_stack(lost)
	run.powerup_lost.emit(fish, lost)


func make_worn() -> Node3D:
	var look := Node3D.new()
	look.name = "Cursed_" + id
	var glow := worn_material(1.6)
	match id:
		"blood_moon_shard":
			# Red crystals standing on the back.
			glow.roughness = 0.1
			look.add_child(worn_mesh(WornKit.crystals(4, 0.35, 0.05, 7), glow, Vector3(0.0, fish.hitbox_height * 0.5, 0.05)))
		"glass_coral":
			# Pale branching coral over the back.
			glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glow.albedo_color = Color(color(id), 0.6)
			var coral := worn_mesh(ReefKit.mesh("staghorn", 1), glow, Vector3(0.0, fish.hitbox_height * 0.5, 0.05))
			coral.scale = Vector3.ONE * 0.25
			look.add_child(coral)
		"sirens_song":
			# A little conch held up like a horn.
			look.add_child(worn_mesh(WornKit.conch(0.24), glow, Vector3(fish.hitbox_width * 0.5, fish.hitbox_height * 0.3, -0.05), Vector3(0.0, 0.0, -0.9)))
		"abyssal_hunger":
			# A dark ring of teeth round the mouth.
			var dark := worn_material(0.6)
			dark.albedo_color = Color(0.12, 0.02, 0.05)
			var jaw := maxf(fish.hitbox_width, fish.hitbox_height) * 0.34
			look.add_child(worn_mesh(WornKit.toothed_ring(snappedf(jaw, 0.02)), dark, Vector3(0.0, 0.0, -fish.hitbox_length * 0.45)))
		"sunken_idol":
			# A small gold idol: a god on its plinth.
			var idol := worn_mesh(GreekKit.cached("worn/idol", func() -> MeshKit: return GreekKit.statue("hades", 5), null), glow,
					Vector3(0.0, fish.hitbox_height * 0.5, 0.15))
			idol.scale = Vector3.ONE * 0.11
			look.add_child(idol)
	return look
