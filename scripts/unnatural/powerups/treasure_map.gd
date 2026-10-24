class_name TreasureMap
extends Powerup
## Treasure Map (planning_unnatural.md §7b, uncommon): a rolled map. Their kills
## drop chests 1 + treasure_chests (a stack) times as often, and the HUD pings
## chests treasure_ping m further out (a stack).


func chest_drop_factor() -> float:
	return 1.0 + settings.treasure_chests * eff()


func chest_ping_bonus() -> float:
	return settings.treasure_ping * eff()


## A rolled map tucked on the back.
func make_worn() -> Node3D:
	var map := MeshInstance3D.new()
	map.name = "Map"
	var scroll := CylinderMesh.new()
	scroll.top_radius = 0.05
	scroll.bottom_radius = 0.05
	scroll.height = 0.3
	scroll.radial_segments = 8
	map.mesh = scroll
	map.material_override = worn_material(0.3)
	map.position = Vector3(0.0, fish.hitbox_height * 0.5 + 0.06, 0.0)
	map.rotation = Vector3(0.0, 0.0, PI / 2.0)
	map.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return map
