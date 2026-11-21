class_name InkSac
extends Powerup
## Ink Sac (planning_unnatural.md §7b, common): a dark sac. When the fish is
## hurt, an ink cloud ink_radius m round it blinds the zombies in it for
## ink_time s (more ink_time_per_stack a stack): they lose the fish (all but
## ink_blind of their speed gone) and are pushed off it. At most once every
## ink_cooldown s.

## Clouds let out, for the probes.
var clouds := 0
var _cooldown := 0.0


func on_tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func on_hurt(_amount: float, _from: int) -> void:
	if _cooldown > 0.0 or not is_instance_valid(fish):
		return
	_cooldown = settings.ink_cooldown
	clouds += 1
	var at := fish.global_position
	var reach := settings.ink_radius * size_scale()
	var seconds := (settings.ink_time + settings.ink_time_per_stack * extra()) * duration_scale()
	for i in run.horde.query_sphere(at, reach):
		if run.horde.is_proxy(i):
			continue
		run.horde.slow(i, settings.ink_blind, seconds)
		var away := run.horde.enemy_position(i) - at
		run.horde.shove(i, away.normalized() * 6.0 if away.length_squared() > 0.0001 else Vector3.UP * 6.0)
	PowerupFx.pop(run, at, reach, Color(0.12, 0.08, 0.2, 0.9), 0.8)
	PowerupFx.flash(run, at, reach * 0.8, Color(0.25, 0.15, 0.4), 1.0)
	Sfx.play("pw/lure_burst")


## A dark ink sac slung under the belly.
func make_worn() -> Node3D:
	var sac := MeshInstance3D.new()
	sac.name = "InkSac"
	sac.mesh = WornKit.ball(0.12)
	sac.material_override = worn_material(0.25)
	sac.scale = Vector3(0.85, 1.0, 1.25)  # a pouch, longer than deep
	sac.position = Vector3(0.0, -fish.hitbox_height * 0.45, fish.hitbox_length * 0.05)
	sac.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sac
