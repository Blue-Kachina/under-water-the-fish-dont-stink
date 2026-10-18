class_name RemoraBuddy
extends Powerup
## Remora Buddy (planning_unnatural.md §7b, D14, common): remoras ride along
## under the fish (remora_count, + per stack). Each nips the nearest zombie
## within remora_range every remora_interval s for remora_damage (proc
## coefficient remora_proc); they take turns, so the nips come evenly.

## Nips so far, for the probes.
var nips := 0
var _next := 0.0


func count() -> int:
	return settings.remora_count + settings.remora_count_per_stack * (stacks - 1)


func on_stacks_changed() -> void:
	take_off()  # worn again with the new number of remoras


func on_tick(delta: float) -> void:
	var n := count()
	if n <= 0:
		return
	_next -= delta
	if _next > 0.0:
		return
	_next += settings.remora_interval / n
	_next = maxf(_next, 0.0)
	var at := fish.global_position
	var target := run.horde.nearest_in_cone(at, Vector3.FORWARD, settings.remora_range, -1.0)
	if target < 0:
		_next = 0.1  # nothing near: look again shortly
		return
	nips += 1
	var to := run.horde.enemy_position(target)
	PowerupFx.flash(run, to, 0.45, color(id), 0.18)
	run.hit(target, settings.remora_damage, fish, id, (to - at).normalized(), settings.remora_proc, [id])


## The remoras stuck under the belly, nose to tail.
func make_worn() -> Node3D:
	var school := Node3D.new()
	school.name = "Remoras"
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.5, 0.55, 0.62)
	skin.roughness = 0.6
	var n := mini(count(), 8)
	for k in n:
		var body := CapsuleMesh.new()
		body.radius = 0.05
		body.height = 0.3
		body.radial_segments = 8
		body.rings = 2
		var side := (k % 2) * 2.0 - 1.0 if n > 1 else 0.0
		var at := Vector3(side * fish.hitbox_width * 0.3, -fish.hitbox_height * 0.5, (k / 2) * 0.22 - 0.1)
		school.add_child(worn_mesh(body, skin, at, Vector3(PI / 2.0, 0.0, 0.0)))
	return school
