class_name SchoolFish
extends Node3D
## A school fish up close: the full model (FishModel) of one of a School's
## fish, which the school puts on whichever of its fish are nearest the camera
## (NatureSettings.detail_fish, within detail_distance). It wags its tail and
## ripples its skin as it swims; everything further off is drawn by the
## school's MultiMesh instead (SchoolLook).
##
## The school places it every frame (place()), from the fish it's showing.

## The physics layer school fish's hitboxes are on (nothing collides with it).
const LAYER := 1 << 5

## The school fish it shows (an index into its School), or -1 for none.
var index := -1
var model: FishModel
var _size := 1.0


func _init(character: FishCharacter.FishClass) -> void:
	model = FishModel.build(character)
	add_child(model)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # placed every frame


## Shows the fish at `transform` (unscaled), `size` times a playable fish,
## swimming at `velocity`, its tail at `tail_phase` in its beat.
func place(transform: Transform3D, size: float, velocity: Vector3, tail_phase: float, delta: float) -> void:
	global_transform = transform
	if not is_equal_approx(size, _size):
		_size = size
		model.scale = Vector3.ONE * size
	if model.tail:
		var effort := clampf(velocity.length() / (12.0 * size + 1.0), 0.0, 1.0)
		var wag := sin(tail_phase) * lerpf(0.2, 0.5, effort)
		if model.fluke:
			model.tail.rotation.x = wag  # a whale's flukes beat up and down
		else:
			model.tail.rotation.y = wag
	model.react(delta, velocity)


## Shadows on or off for its model.
func set_shadows(on: bool) -> void:
	var setting := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = setting
