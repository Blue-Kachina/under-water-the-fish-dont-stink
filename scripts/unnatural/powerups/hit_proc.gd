class_name HitProc
extends Powerup
## The on-hit control items (planning_unnatural.md §7b), each hit rolling its
## chance (more a stack), times the hit's proc coefficient:
## - Sticky Anemone (common): takes anemone_slow of the zombie's speed for anemone_time s;
## - Cold Seep (uncommon): freezes it solid for seep_time s (bosses shrug it off);
## - Kraken's Grasp (rare): a tentacle slams down on it, kraken_damage to every
##   zombie within kraken_radius m, each held still kraken_hold s; at most
##   kraken_max_rate slams a second.

## Times it went off, for the probes.
var procs := 0
var _slams_left := 0.0
var _refilled := -1.0


func chance() -> float:
	match id:
		"sticky_anemone":
			return settings.anemone_chance + settings.anemone_chance_per_stack * (stacks - 1)
		"cold_seep":
			return settings.seep_chance + settings.seep_chance_per_stack * (stacks - 1)
		"krakens_grasp":
			return settings.kraken_chance + settings.kraken_chance_per_stack * (stacks - 1)
	return 0.0


func on_hit(index: int, _damage: float, _source: String, proc: float, chain: Array) -> void:
	var horde := run.horde
	if not horde.is_alive(index):
		return
	if id == "cold_seep" and horde.is_proxy(index):
		return  # a boss's body
	if id == "krakens_grasp" and not _may_slam():
		return
	if not roll(chance() * proc):
		return
	procs += 1
	var at := horde.enemy_position(index)
	var radius := horde.enemy_radius(index)
	match id:
		"sticky_anemone":
			horde.slow(index, settings.anemone_slow, settings.anemone_time * duration_scale())
			PowerupFx.pop(run, at, radius * 1.4, color(id), 0.3)
		"cold_seep":
			horde.slow(index, 1.0, settings.seep_time * duration_scale())
			PowerupFx.flash(run, at, radius * 1.8, color(id), 0.45)
		"krakens_grasp":
			_slams_left -= 1.0
			slam(at, chain)


## A tentacle slamming down at `at`.
func slam(at: Vector3, chain: Array) -> void:
	var reach := settings.kraken_radius * size_scale()
	var damage := settings.kraken_damage + settings.kraken_damage_per_stack * (stacks - 1)
	for i in run.horde.query_sphere(at, reach):
		run.horde.slow(i, 1.0, settings.kraken_hold * duration_scale())
		run.hit(i, damage, fish, id, (run.horde.enemy_position(i) - at).normalized(), run.powerup_settings.chain_proc, chain + [id])
	PowerupFx.shock(run, at, reach, color(id), Vector3.UP, 0.45)
	PowerupFx.spikes(run, at, reach * 0.8, color(id).lightened(0.3), 0.3)
	Sfx.play("pw/depth_charge_arm")


## Whether a slam's allowed now (kraken_max_rate a second, refilled as time passes).
func _may_slam() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var cap := maxf(settings.kraken_max_rate * 0.5, 1.0)
	_slams_left = cap if _refilled < 0.0 else minf(_slams_left + (now - _refilled) * settings.kraken_max_rate, cap)
	_refilled = now
	return _slams_left >= 1.0


func make_worn() -> Node3D:
	var look := Node3D.new()
	look.name = "Worn" + id.to_pascal_case()
	var skin := worn_material(0.6)
	match id:
		"sticky_anemone":
			# A tuft of short tentacles on the head.
			look.position = Vector3(0.0, fish.hitbox_height * 0.5, -fish.hitbox_length * 0.15)
			for n in 7:
				var strand := CylinderMesh.new()
				strand.top_radius = 0.012
				strand.bottom_radius = 0.025
				strand.height = 0.16
				strand.radial_segments = 5
				var turn := n * TAU / 7.0
				look.add_child(worn_mesh(strand, skin, Vector3(cos(turn), 1.0, sin(turn)) * 0.05, Vector3(sin(turn) * 0.5, 0.0, -cos(turn) * 0.5)))
		"cold_seep":
			# Frost crystals along the back.
			look.position = Vector3(0.0, fish.hitbox_height * 0.45, 0.0)
			for n in 3:
				var crystal := PrismMesh.new()
				crystal.size = Vector3(0.08, 0.16, 0.08)
				look.add_child(worn_mesh(crystal, skin, Vector3(0.0, 0.05, (n - 1) * fish.hitbox_length * 0.18)))
		"krakens_grasp":
			# A tentacle curling up off the side.
			look.position = Vector3(fish.hitbox_width * 0.5, 0.0, fish.hitbox_length * 0.1)
			for n in 6:
				var bead := SphereMesh.new()
				bead.radius = 0.06 - n * 0.007
				bead.height = bead.radius * 2.0
				bead.radial_segments = 8
				bead.rings = 4
				var t := n / 5.0
				look.add_child(worn_mesh(bead, skin, Vector3(0.05 + sin(t * 2.5) * 0.12, t * 0.3, -cos(t * 2.5) * 0.08)))
	return look
