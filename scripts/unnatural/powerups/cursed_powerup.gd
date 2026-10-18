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
			# A red crystal standing on the back.
			var shard := CylinderMesh.new()
			shard.top_radius = 0.0
			shard.bottom_radius = 0.09
			shard.height = 0.35
			shard.radial_segments = 3
			shard.rings = 1
			look.add_child(worn_mesh(shard, glow, Vector3(0.0, fish.hitbox_height * 0.5 + 0.15, 0.05), Vector3(0.0, 0.0, 0.2)))
		"glass_coral":
			# Pale branching twigs over the back.
			glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glow.albedo_color = Color(color(id), 0.6)
			for n in 4:
				var twig := CylinderMesh.new()
				twig.top_radius = 0.01
				twig.bottom_radius = 0.025
				twig.height = 0.22
				twig.radial_segments = 5
				twig.rings = 1
				var lean := (n - 1.5) * 0.35
				look.add_child(worn_mesh(twig, glow, Vector3(lean * 0.12, fish.hitbox_height * 0.5 + 0.1, (n % 2) * 0.1), Vector3(0.0, 0.0, lean)))
		"sirens_song":
			# A little conch held up like a horn.
			var conch := CylinderMesh.new()
			conch.top_radius = 0.07
			conch.bottom_radius = 0.0
			conch.height = 0.22
			conch.radial_segments = 8
			conch.rings = 1
			look.add_child(worn_mesh(conch, glow, Vector3(fish.hitbox_width * 0.5, fish.hitbox_height * 0.3, -0.05), Vector3(0.0, 0.0, -0.9)))
		"abyssal_hunger":
			# A dark ring of teeth round the mouth.
			var dark := worn_material(0.6)
			dark.albedo_color = Color(0.12, 0.02, 0.05)
			var jaw := TorusMesh.new()
			jaw.inner_radius = maxf(fish.hitbox_width, fish.hitbox_height) * 0.32
			jaw.outer_radius = jaw.inner_radius + 0.05
			jaw.rings = 16
			jaw.ring_segments = 5
			look.add_child(worn_mesh(jaw, dark, Vector3(0.0, 0.0, -fish.hitbox_length * 0.45), Vector3(PI / 2.0, 0.0, 0.0)))
		"sunken_idol":
			# A small gold idol: a body and a round head.
			var body := BoxMesh.new()
			body.size = Vector3(0.1, 0.14, 0.08)
			look.add_child(worn_mesh(body, glow, Vector3(0.0, fish.hitbox_height * 0.5 + 0.07, 0.15)))
			var head := SphereMesh.new()
			head.radius = 0.055
			head.height = 0.11
			head.radial_segments = 8
			head.rings = 4
			look.add_child(worn_mesh(head, glow, Vector3(0.0, fish.hitbox_height * 0.5 + 0.19, 0.15)))
	return look
