class_name BillThrust
extends FishAttack
## The Swordfish's auto-attack (planning_unnatural.md §5): a spear of light
## shot off its bill, at the nearest zombie within thrust_aim_cone of the nose
## (or straight on if one is anywhere within range ahead), piercing up to
## thrust_pierce zombies. Each Projectiles stat adds a spear, fanned
## thrust_spread degrees apart; Projectile Speed (the Swordfish's signature)
## makes them faster and fly further in the same time.

const COLOR := Color(0.55, 0.85, 1.0, 0.9)

var spears := ProjectileSwarm.new()


func _init() -> void:
	name = "BillThrust"
	var spear := CylinderMesh.new()
	spear.top_radius = 0.0
	spear.bottom_radius = 0.5
	spear.height = 2.0
	spear.radial_segments = 6
	spear.rings = 1
	# Along -z, point first.
	var mesh := ArrayMesh.new()
	var arrays := spear.get_mesh_arrays()
	var turn := Basis(Vector3.RIGHT, -PI / 2.0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in points.size():
		points[i] = turn * points[i]
		normals[i] = turn * normals[i]
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	spears.set_look(mesh, FishAttack.ghost_material(COLOR))
	spears.stretch = 2.5
	add_child(spears)


func _ready() -> void:
	spears.horde = horde
	spears.on_hit = func(index: int, amount: float, push: Vector3) -> void: strike(index, amount, push)


func cooldown() -> float:
	return settings.thrust_cooldown


func damage() -> float:
	return settings.thrust_damage


func uses_stat(id: String) -> bool:
	return id == "projectile_count" or id == "projectile_speed"


func speed() -> float:
	return settings.thrust_speed * projectile_speed


func fire() -> bool:
	var at := origin()
	var ahead := nose()
	var target := horde.nearest_in_cone(at, ahead, settings.thrust_range, cos(deg_to_rad(settings.thrust_aim_cone)))
	if target < 0:
		return false
	var aim := toward(at, target, ahead)
	var count := 1 + extra_projectiles
	var side := aim.cross(Vector3.UP if absf(aim.y) < 0.98 else Vector3.BACK).normalized()
	var up := side.cross(aim)
	var tip := at + ahead * fish.hitbox_length * 0.5
	for n in count:
		var offset := (n - (count - 1) * 0.5) * deg_to_rad(settings.thrust_spread)
		var direction := aim.rotated(up, offset)
		spears.fire(tip, direction * speed(), settings.thrust_damage, settings.thrust_size * area_scale,
				settings.thrust_range / settings.thrust_speed, settings.thrust_pierce)
	return true
