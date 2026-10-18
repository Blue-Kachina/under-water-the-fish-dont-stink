class_name BubbleWrap
extends Powerup
## Bubble Wrap (planning_unnatural.md §7b, D14, common): a bubble round the
## fish. Once it's gone ready_time() s untouched (bubble_ready, less
## bubble_ready_per_stack a stack), the bubble shows, takes the next hit
## instead of the fish (UnnaturalRun.hurt) and pops.

## Hits it has taken, for the probes.
var blocked := 0
var _untouched := 0.0


func ready_time() -> float:
	return maxf(settings.bubble_ready - settings.bubble_ready_per_stack * (stacks - 1), settings.bubble_ready_min)


func is_ready() -> bool:
	return _untouched >= ready_time()


func on_tick(delta: float) -> void:
	_untouched += delta
	if _worn and is_instance_valid(_worn):
		_worn.visible = is_ready()
		_worn.scale = Vector3.ONE  # it fits the fish, whatever the stacks


func blocks_hit(_amount: float) -> bool:
	if not is_ready():
		return false
	_untouched = 0.0
	blocked += 1
	if _worn and is_instance_valid(_worn):
		_worn.visible = false
	PowerupFx.pop(run, fish.global_position, fish.hitbox_length * 0.75, color(id), 0.3)
	return true


func on_hurt(_amount: float, _from: int) -> void:
	_untouched = 0.0


## A clear bubble round the whole fish.
func make_worn() -> Node3D:
	var bubble := MeshInstance3D.new()
	bubble.name = "Bubble"
	var sphere := SphereMesh.new()
	sphere.radius = fish.hitbox_length * 0.6
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	# A soap-film skin: clear face on, bright round the rim, a glint up top.
	sphere.material = FxKit.rim(Color(color(id).lerp(Color.WHITE, 0.3), 0.7), 0.03, 0.7)
	bubble.mesh = sphere
	bubble.scale = Vector3(0.75, 0.6, 1.0)
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble.visible = false
	return bubble
