class_name HunterFormModel
extends RefCounted
## The Hunter forms' looks (FishModel.build hands FishCharacter.MONSTER here):
## species m.species of FishCharacter.SPECIES[MONSTER]. So far only the Drowned
## Shark: the Hunters' shark model (great white) gone rotten with red eyes and
## the jaw rig, as the mini-boss wears it (DrownedShark). It is built on the
## Hunters' own box, not the Monsters' (a narrower one for collision), so its
## shape is the shark's; the controller then scales it uniformly by body_scale.
## The jaw is kept in meta "hunter_jaw" for HunterBite to open.

const ROT := Color(0.36, 0.42, 0.34)
const EYE_RED := Color(0.55, 0.04, 0.02)


static func build(m: FishModel) -> void:
	m._size = FishCharacter.hitbox_size(FishCharacter.FishClass.HUNTER)
	var species := m.species
	m.species = 0  # SharkModel's great white
	SharkModel.build(m)
	m.species = species
	m._tint(ROT)  # not set_body_color: the controller resets that when it has no team colour
	for node in m.find_children("Eye*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).material_override as ShaderMaterial
		if material and material.shader == FishModel.FISH_EYE:
			material.set_shader_parameter("iris", EYE_RED)
			material.set_shader_parameter("iris_inner", EYE_RED.darkened(0.5))
			material.set_shader_parameter("sheen", 0.1)
			material.set_shader_parameter("pupil", 0.5)
			material.set_shader_parameter("pupil_stretch", 0.3)
			material.set_shader_parameter("glow", 2.5)
	var jaw := HunterJaw.new()
	jaw.build(m, ROT)
	m.set_meta("hunter_jaw", jaw)
