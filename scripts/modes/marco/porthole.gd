class_name Porthole
extends Node3D
## A small round opening in an arena's wall (planning_marco_polo.md §11) that a
## hider can duck into to vanish for a while. This node is just the place and
## its look: its origin is the middle of the opening on the wall's face, +Z
## points out into the water (axis()) and the tunnel runs back along -Z. Who's
## in it and the rules for getting in and out are PortholeSystem's.
##
## Its collision is the wall's: the system lets a fish through.

enum Look {
	## Sunken Temple: an arched window / wall niche in marble.
	NICHE,
	## Aquarium: a round hole in the filter box's back panel, a rubber grommet round it.
	ROUND,
	## Aquarium: an arrow slit in the castle's wall.
	SLIT,
}

## How far the tunnel goes back into the wall (m): long enough for a long fish.
const DEPTH := 4.5

var look := Look.NICHE
## The opening as drawn (m). The entry check uses each fish's own size.
var radius := 0.8
## The hider inside now (PortholeSystem), or null.
var occupant: FishController
## The frame's material (the arena's marble, plastic, stone).
var frame_material: Material

var _inside_material := StandardMaterial3D.new()


func _ready() -> void:
	_inside_material.albedo_color = Color(0.015, 0.02, 0.02)
	_inside_material.roughness = 1.0
	_inside_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_tunnel()
	match look:
		Look.NICHE:
			_build_niche()
		Look.ROUND:
			_build_grommet()
		Look.SLIT:
			_build_slit()


## Out of the porthole into the water (world).
func axis() -> Vector3:
	return global_basis.z.normalized()


## The middle of the opening (world).
func mouth() -> Vector3:
	return global_position


## How far `point` is in front of the opening along the axis (negative: inside).
func along(point: Vector3) -> float:
	return (point - global_position).dot(axis())


## How far `point` is off the axis line (m).
func off_axis(point: Vector3) -> float:
	var d := point - global_position
	return (d - axis() * d.dot(axis())).length()


func is_free() -> bool:
	return not is_instance_valid(occupant)


## Where a fish `length` m long sits inside, facing out, its head just inside
## the opening.
func seat(length: float) -> Transform3D:
	return Transform3D(Basis.looking_at(axis(), _up()), global_position - axis() * (length * 0.5 + 0.15))


## The camera for the hider inside: behind its head in the tunnel, looking out
## through the opening.
func camera_transform(length: float) -> Transform3D:
	var at := global_position - axis() * minf(length * 0.5 + 0.6, DEPTH - 0.3) + _up() * radius * 0.35
	return Transform3D(Basis.looking_at(axis(), _up()), at)


func _up() -> Vector3:
	return global_basis.y.normalized()


func _build_tunnel() -> void:
	var tunnel := CylinderMesh.new()
	tunnel.top_radius = radius
	tunnel.bottom_radius = radius * 0.9
	tunnel.height = DEPTH
	tunnel.cap_top = false
	tunnel.radial_segments = 20
	tunnel.rings = 1
	var view := MeshInstance3D.new()
	view.name = "Tunnel"
	view.mesh = tunnel
	view.material_override = _inside_material
	view.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.0, 0.0, -DEPTH * 0.5 + 0.02))  # open end (+Y) out at the mouth
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


func _ring(ring_radius: float, thick: float, at_z: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = ring_radius
	torus.outer_radius = ring_radius + thick
	torus.rings = 24
	torus.ring_segments = 8
	_part(torus, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.0, 0.0, at_z)))


func _box(box: Vector3, at: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box
	_part(mesh, Transform3D(Basis(), at))


func _part(mesh: Mesh, xform: Transform3D) -> void:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.transform = xform
	if frame_material:
		view.material_override = frame_material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


## An arched window: a moulded ring, a keystone over it, a sill under it and
## two pilasters either side.
func _build_niche() -> void:
	_ring(radius, radius * 0.22, 0.05)
	_box(Vector3(radius * 0.45, radius * 0.5, radius * 0.5), Vector3(0.0, radius * 1.25, 0.12))
	_box(Vector3(radius * 3.0, radius * 0.28, radius * 0.7), Vector3(0.0, -radius * 1.2, 0.2))
	for side: float in [-1.0, 1.0]:
		_box(Vector3(radius * 0.36, radius * 2.6, radius * 0.4), Vector3(side * radius * 1.45, 0.0, 0.1))


## A round hole with a fat rubber grommet, lighter than the black panel so the
## holes read from across the tank.
func _build_grommet() -> void:
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.42, 0.5, 0.56)
	rubber.roughness = 0.55
	rubber.emission_enabled = true
	rubber.emission = Color(0.1, 0.16, 0.2)
	frame_material = rubber
	_ring(radius, radius * 0.18, 0.02)
	_ring(radius * 1.05, radius * 0.1, 0.12)


## An arrow slit: a tall narrow frame of stones round the opening.
func _build_slit() -> void:
	for side: float in [-1.0, 1.0]:
		_box(Vector3(radius * 0.5, radius * 3.4, radius * 0.6), Vector3(side * radius * 1.2, 0.0, 0.05))
	_box(Vector3(radius * 2.9, radius * 0.5, radius * 0.6), Vector3(0.0, radius * 1.7, 0.05))
	_box(Vector3(radius * 2.9, radius * 0.5, radius * 0.6), Vector3(0.0, -radius * 1.7, 0.05))
	# The slit's dark inside, facing out only: a curved tower's surface would hide
	# the tunnel, and from inside (looking out) it isn't drawn.
	var dark := PlaneMesh.new()
	dark.size = Vector2(radius * 1.95, radius * 2.95)
	var face := StandardMaterial3D.new()
	face.albedo_color = Color(0.015, 0.02, 0.02)
	face.roughness = 1.0
	var view := MeshInstance3D.new()
	view.mesh = dark
	view.material_override = face
	view.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.0, 0.0, 0.03))
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
