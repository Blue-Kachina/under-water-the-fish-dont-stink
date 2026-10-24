class_name PoseidonsTrident
extends Powerup
## Poseidon's Trident (planning_unnatural.md §7b, legendary): every
## trident_every-th attack the fish makes (its fired weapons, own and held;
## a fish with only steady ones, like the fire trail or the halo: every
## trident_every s, sooner with attack speed) calls lightning down on the
## biggest zombie within trident_range m: trident_damage (more
## trident_damage_per_stack a stack) to everything within trident_radius m.

## Bolts called, for the probes.
var bolts := 0
var _counted := -1
var _attacks := 0
var _clock := 0.0


func on_tick(delta: float) -> void:
	if not is_instance_valid(fish):
		return
	var made := _attacks_made()
	if made < 0:
		_clock += delta * rate_scale()
		if _clock >= settings.trident_every:
			_clock = 0.0
			strike()
		return
	if _counted < 0:
		_counted = made
	_attacks += maxi(made - _counted, 0)
	_counted = made
	if _attacks >= settings.trident_every:
		_attacks = 0
		strike()


## Attacks made so far by the fish's fired weapons (-1: it has none, only
## steady ones like the fire trail: FishAttack.counts_uses).
func _attacks_made() -> int:
	var made := 0
	var any := false
	var own := run.attack_of(fish)
	if own and own.counts_uses():
		made += own.uses
		any = true
	for id_held: String in run.powerups_of(fish).held:
		var held: Powerup = run.powerups_of(fish).held[id_held]
		if held is AttackWeapon and is_instance_valid((held as AttackWeapon).attack) and (held as AttackWeapon).attack.counts_uses():
			made += (held as AttackWeapon).attack.uses
			any = true
	return made if any else -1


## Lightning down on the biggest zombie near (nothing near: it waits).
func strike() -> void:
	var horde := run.horde
	var best := -1
	var biggest := -1.0
	for i in horde.query_sphere(fish.global_position, settings.trident_range):
		if horde.enemy_size(i) > biggest:
			biggest = horde.enemy_size(i)
			best = i
	if best < 0:
		return
	bolts += 1
	var at := horde.enemy_position(best)
	var damage := settings.trident_damage + settings.trident_damage_per_stack * (stacks - 1)
	var reach := settings.trident_radius * size_scale()
	for i in horde.query_sphere(at, reach):
		run.hit(i, damage, fish, id, (horde.enemy_position(i) - at).normalized(), 1.0, [id])
	var bolt := ChainLightning.Bolt.new()
	bolt.path = PackedVector3Array([at + Vector3.UP * 25.0, at + Vector3.UP * 12.0, at])
	run.add_child(bolt)
	PowerupFx.shock(run, at, reach, color(id), Vector3.UP, 0.4)
	Sfx.play("pw/chain_zap")


## A little golden trident on the back.
func make_worn() -> Node3D:
	var trident := Node3D.new()
	trident.name = "Trident"
	trident.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.05, fish.hitbox_length * 0.1)
	trident.rotation = Vector3(-1.2, 0.0, 0.0)
	var skin := worn_material(1.0)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.012
	shaft.bottom_radius = 0.012
	shaft.height = 0.45
	shaft.radial_segments = 5
	trident.add_child(worn_mesh(shaft, skin, Vector3.ZERO))
	for side: float in [-1.0, 0.0, 1.0]:
		var prong := CylinderMesh.new()
		prong.top_radius = 0.0
		prong.bottom_radius = 0.012
		prong.height = 0.12
		prong.radial_segments = 5
		trident.add_child(worn_mesh(prong, skin, Vector3(side * 0.05, 0.28, 0.0)))
	var bar := BoxMesh.new()
	bar.size = Vector3(0.12, 0.015, 0.015)
	trident.add_child(worn_mesh(bar, skin, Vector3(0.0, 0.22, 0.0)))
	return trident
