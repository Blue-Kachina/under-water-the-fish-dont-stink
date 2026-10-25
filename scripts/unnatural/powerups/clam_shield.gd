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
	return maxf(settings.clam_ready - settings.clam_ready_per_stack * extra(), settings.clam_ready_min)


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
	var clam := Node3D.new()
	clam.name = "Clam"
	clam.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.02, 0.0)
	var shell := worn_material(0.3)
	shell.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Two ridged halves, the top one a little open.
	var half := ReefKit.mesh("clam", 0)
	clam.add_child(worn_mesh(half, shell, Vector3.ZERO, Vector3.ZERO))
	var lid := worn_mesh(half, shell, Vector3(0.0, 0.01, 0.0), Vector3(-0.35, 0.0, PI))
	lid.scale = Vector3(1.0, 0.8, 1.0)
	clam.add_child(lid)
	clam.scale = Vector3.ONE * 1.3
	return clam
