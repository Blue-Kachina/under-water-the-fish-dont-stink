class_name PufferfishSpines
extends Powerup
## Pufferfish Spines (planning_unnatural.md §7b, D14, uncommon): spines out.
## A zombie that touches the fish gets reflect() of what it did back, and a
## burst of spines hits everything within spine_burst_radius for burst()
## (proc coefficient spine_proc).

## Bursts so far, for the probes.
var bursts := 0


func reflect() -> float:
	return settings.spine_reflect + settings.spine_reflect_per_stack * extra()


func burst() -> float:
	return settings.spine_burst_damage + settings.spine_burst_damage_per_stack * extra()


func on_hurt(amount: float, from: int) -> void:
	var at := fish.global_position
	if from >= 0 and run.horde.is_alive(from):
		var away := run.horde.enemy_position(from) - at
		run.hit(from, amount * reflect(), fish, id, away.normalized() if away.length_squared() > 0.0001 else Vector3.UP,
				settings.spine_proc, [id])
	bursts += 1
	PowerupFx.spikes(run, at, settings.spine_burst_radius, color(id), 0.22)
	Sfx.play_at("pw/puffer_spines", at)
	run.hit_area(run.horde.query_sphere(at, settings.spine_burst_radius), burst(), fish, id, at, 1.0, settings.spine_proc, [id])


## Spines standing out all round the body.
func make_worn() -> Node3D:
	var spines := Node3D.new()
	spines.name = "Spines"
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.95, 0.88, 0.6)
	bone.roughness = 0.5
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.025
	spike.height = 0.18
	spike.radial_segments = 5
	spike.rings = 1
	var half := Vector3(fish.hitbox_width, fish.hitbox_height, fish.hitbox_length) * 0.5
	for ring in 3:
		var z := (ring - 1) * half.z * 0.5
		for k in 8:
			var a := k * TAU / 8.0 + ring * 0.4 + 0.2  # never straight down (no arc from up to down)
			var out := Vector3(cos(a), sin(a), 0.0)
			var at := Vector3(out.x * half.x, out.y * half.y, z)
			var part := worn_mesh(spike, bone, at + out * 0.08)
			part.basis = Basis(Quaternion(Vector3.UP, out))
			spines.add_child(part)
	return spines
