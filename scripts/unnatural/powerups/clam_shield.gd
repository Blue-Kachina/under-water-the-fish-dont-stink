class_name ClamShield
extends Powerup
## Clam Shield (planning_unnatural.md §7b, uncommon): a clam on the fish. Once
## it's been ready_time() s since it last shut (clam_ready, less
## clam_ready_per_stack a stack, down to clam_ready_min), it takes the next hit
## instead of the fish and shuts. Unlike Bubble Wrap it recharges on its own
## clock, hurt or not.

## Hits it has taken, for the probes.
var blocked := 0
var _charge := 0.0


func ready_time() -> float:
	return maxf(settings.clam_ready - settings.clam_ready_per_stack * (stacks - 1), settings.clam_ready_min)


func is_ready() -> bool:
	return _charge >= ready_time()


func on_tick(delta: float) -> void:
	var was_ready := is_ready()
	_charge += delta
	if is_ready() and not was_ready and stacks > 0:
		Sfx.play("pw/bubble_wrap_ready")
	if _worn and is_instance_valid(_worn):
		_worn.scale = Vector3.ONE * (1.0 if is_ready() else 0.7)  # open when ready


func blocks_hit(_amount: float) -> bool:
	if not is_ready():
		return false
	_charge = 0.0
	blocked += 1
	PowerupFx.pop(run, fish.global_position, fish.hitbox_length * 0.75, color(id), 0.3)
	Sfx.play("pw/bubble_wrap_pop")
	return true


## A flattened pink shell sitting on the back.
func make_worn() -> Node3D:
	var clam := MeshInstance3D.new()
	clam.name = "Clam"
	var shell := SphereMesh.new()
	shell.radius = 0.2
	shell.height = 0.2
	shell.radial_segments = 12
	shell.rings = 4
	clam.mesh = shell
	clam.material_override = worn_material(0.3)
	clam.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.08, 0.0)
	clam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return clam
