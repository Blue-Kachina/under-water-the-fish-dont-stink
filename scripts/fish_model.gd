class_name FishModel
extends Node3D
## A playable fish's look (one per FishCharacter), built from simple shapes to
## fill its character's hitbox at scale 1: width x height x length, centred on
## the hitbox centre, nose toward -Z. The body fills the box, so what you see is
## what the ball meets; fins and tails may poke out of it a little.
##
## Every model has the nodes the swim animation moves (TailPivot, FinLeftPivot,
## FinRightPivot) and a Body whose colour set_body_color() changes (replays
## tint each fish in its team's colour). Parts sharing the body's material
## (a manta's wings) change with it.

const BLACK := Color(0.04, 0.04, 0.06)
const WHITE := Color(0.97, 0.97, 0.95)
const BLUSH := Color(1.0, 0.55, 0.65)

var family := FishCharacter.Family.OCTANE
var tail: Node3D
var fin_left: Node3D
var fin_right: Node3D

var _size := Vector3.ONE  # the hitbox (m): width, height, length
var _body_material: StandardMaterial3D


static func build(character: FishCharacter.Family) -> FishModel:
	var model := FishModel.new()
	model.name = "Visual"
	model.family = character
	model._size = FishCharacter.hitbox_size(character)
	match character:
		FishCharacter.Family.OCTANE:
			model._build_clownfish()
		FishCharacter.Family.DOMINUS:
			model._build_shark()
		FishCharacter.Family.PLANK:
			model._build_manta()
		FishCharacter.Family.BREAKOUT:
			model._build_swordfish()
		FishCharacter.Family.HYBRID:
			model._build_goldfish()
		FishCharacter.Family.MERC:
			model._build_boxfish()
	return model


func set_body_color(color: Color) -> void:
	_body_material.albedo_color = color


# --- The fish -------------------------------------------------------------------

## Octane: an orange clownfish with three white bands, big eyes and rosy cheeks.
func _build_clownfish() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var semi := Vector3(w * 0.46, h * 0.5, l * 0.46)
	_body(Color(1.0, 0.5, 0.1), Vector3.ZERO, semi * 2.0)
	for z: float in [-l * 0.2, l * 0.06, l * 0.3]:
		_band(semi, z, l * 0.11, BLACK, 1.01)  # thin black rims either side of the white
		_band(semi, z, l * 0.08, WHITE, 1.02)
	var fin_color := Color(1.0, 0.62, 0.2)
	_part(self, _sphere(), _material(fin_color), Vector3(0.0, semi.y * 0.9, l * 0.02), Vector3(0.04, h * 0.55, l * 0.4))
	_tail_pivot(Vector3(0.0, 0.0, semi.z * 0.9))
	_part(tail, _sphere(), _material(fin_color), Vector3(0.0, 0.0, l * 0.1), Vector3(0.04, h * 0.95, l * 0.24))
	_part(tail, _sphere(), _material(BLACK), Vector3(0.0, 0.0, l * 0.11), Vector3(0.03, h * 1.0, l * 0.24))
	_fin_pivots(Vector3(semi.x * 0.85, -h * 0.15, -l * 0.1))
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		_part(pivot, _sphere(), _material(fin_color), Vector3(side * w * 0.07, 0.0, 0.0), Vector3(w * 0.22, 0.03, l * 0.15))
	_face(semi, -l * 0.34, h * 0.12, h * 0.17)
	_cheeks(semi, -l * 0.26, -h * 0.08, h * 0.09)
	_mouth(Vector3(0.0, -h * 0.06, -semi.z * 0.985), Vector3(w * 0.12, h * 0.07, 0.03))


## Dominus: a chubby little shark with a tall fin, a toothy grin and gills.
func _build_shark() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var semi := Vector3(w * 0.45, h * 0.5, l * 0.47)
	_body(Color(0.45, 0.56, 0.7), Vector3.ZERO, semi * 2.0)
	# White chin and chest.
	_part(self, _sphere(), _material(WHITE), Vector3(0.0, -h * 0.17, -l * 0.25), Vector3(w * 0.62, h * 0.6, l * 0.42))
	var fin_color := Color(0.4, 0.5, 0.64)
	_fin(self, fin_color, Vector3(0.0, semi.y * 0.75, l * 0.04), l * 0.3, h * 0.85, 0.25)
	_tail_pivot(Vector3(0.0, 0.0, semi.z * 0.88))
	_part(tail, _sphere(), _material(fin_color), Vector3(0.0, h * 0.38, l * 0.09), Vector3(0.04, h * 1.0, l * 0.11), Vector3(0.6, 0.0, 0.0))
	_part(tail, _sphere(), _material(fin_color), Vector3(0.0, -h * 0.22, l * 0.06), Vector3(0.04, h * 0.6, l * 0.09), Vector3(-0.6, 0.0, 0.0))
	_fin_pivots(Vector3(semi.x * 0.8, -h * 0.2, -l * 0.05))
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		_part(pivot, _sphere(), _material(fin_color), Vector3(side * w * 0.08, -h * 0.05, l * 0.03), Vector3(w * 0.26, 0.03, l * 0.15),
				Vector3(0.0, 0.0, side * -0.35))
		# Gills: three dark slits behind the eye.
		for k in 3:
			var z := -l * 0.14 + k * l * 0.045
			var x := _ellipsoid_x(semi, 0.0, z) * side
			_part(self, _box(), _material(fin_color.darkened(0.45)), Vector3(x, 0.0, z), Vector3(0.012, h * 0.32, 0.012))
	_face(semi, -l * 0.3, h * 0.1, h * 0.13, 0.75)
	# A wide grin with a row of little teeth along its top.
	var mouth_z := -semi.z * 0.9
	_mouth(Vector3(0.0, -h * 0.17, mouth_z), Vector3(w * 0.42, h * 0.1, 0.06))
	for k in 6:
		var x := (k - 2.5) * w * 0.06
		var tooth := _part(self, PrismMesh.new(), _material(WHITE), Vector3(x, -h * 0.15, mouth_z - 0.012),
				Vector3(w * 0.045, h * 0.1, 0.02), Vector3(0.0, 0.0, PI))
		tooth.name = "Tooth%d" % k


## Plank: a flat manta ray with wide flapping wings, little horns and a big smile.
func _build_manta() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var body_centre := Vector3(0.0, 0.0, -l * 0.1)
	var semi := Vector3(w * 0.23, h * 0.45, l * 0.32)
	_body(Color(0.2, 0.25, 0.4), body_centre, semi * 2.0)
	# Wings swept back from the shoulders (they share the body's colour).
	_fin_pivots(Vector3(semi.x * 0.6, 0.0, -l * 0.1))
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		var wing := _part(pivot, _sphere(), _body_material, Vector3(side * w * 0.14, 0.0, l * 0.05), Vector3(w * 0.44, h * 0.28, l * 0.42),
				Vector3(0.0, side * -0.4, 0.0))
		wing.name = "Wing"
		# White shoulder patches, as a real manta has.
		_part(self, _sphere(), _material(WHITE), Vector3(side * w * 0.12, semi.y * 0.82, -l * 0.02), Vector3(w * 0.1, 0.03, l * 0.12))
		# Cephalic horns, curling forward either side of the mouth.
		_part(self, _capsule(), _body_material, Vector3(side * w * 0.11, -h * 0.05, -l * 0.42), Vector3(0.055, l * 0.13, 0.055),
				Vector3(-1.3, 0.0, 0.0))
	_tail_pivot(Vector3(0.0, 0.0, l * 0.2))
	_part(tail, _cylinder(), _material(Color(0.15, 0.18, 0.3)), Vector3(0.0, 0.0, l * 0.15), Vector3(0.03, l * 0.3, 0.03),
			Vector3(PI / 2.0, 0.0, 0.0))
	_part(self, _prism(), _body_material, Vector3(0.0, semi.y * 0.8, l * 0.12), Vector3(l * 0.08, h * 0.3, 0.03), Vector3(0.0, PI / 2.0, 0.0))
	var head_z := body_centre.z - semi.z * 0.72
	_face(semi, head_z - body_centre.z, h * 0.12, h * 0.15, 0.6, body_centre)
	_mouth(Vector3(0.0, -h * 0.08, body_centre.z - semi.z * 0.97), Vector3(w * 0.24, h * 0.13, 0.05))


## Breakout: a sleek blue swordfish with a sail on its back and a pointy nose.
func _build_swordfish() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var body_centre := Vector3(0.0, 0.0, l * 0.1)
	var semi := Vector3(w * 0.43, h * 0.5, l * 0.36)
	_body(Color(0.2, 0.42, 0.85), body_centre, semi * 2.0)
	# Silver underside.
	_part(self, _sphere(), _material(Color(0.82, 0.86, 0.92)), body_centre + Vector3(0.0, -h * 0.14, 0.0), Vector3(w * 0.8, h * 0.72, l * 0.68))
	# The sword: a cone from the nose to the front of the hitbox.
	var nose := body_centre.z - semi.z
	var sword_length := l * 0.5 + nose + l * 0.02
	_part(self, _cone(), _material(Color(0.3, 0.33, 0.42)), Vector3(0.0, -h * 0.02, nose + l * 0.02 - sword_length / 2.0),
			Vector3(0.07, sword_length, 0.05), Vector3(-PI / 2.0, 0.0, 0.0))
	var fin_color := Color(0.16, 0.3, 0.68)
	_fin(self, fin_color, Vector3(0.0, semi.y * 0.7, body_centre.z - l * 0.08), l * 0.36, h * 1.0, 0.12)
	_tail_pivot(Vector3(0.0, 0.0, body_centre.z + semi.z * 0.9))
	_part(tail, _sphere(), _material(fin_color), Vector3(0.0, h * 0.4, l * 0.07), Vector3(0.035, h * 1.05, l * 0.08), Vector3(0.75, 0.0, 0.0))
	_part(tail, _sphere(), _material(fin_color), Vector3(0.0, -h * 0.4, l * 0.07), Vector3(0.035, h * 1.05, l * 0.08), Vector3(-0.75, 0.0, 0.0))
	_fin_pivots(Vector3(semi.x * 0.8, -h * 0.18, body_centre.z - l * 0.16))
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		_part(pivot, _sphere(), _material(fin_color), Vector3(side * w * 0.07, 0.0, l * 0.04), Vector3(w * 0.22, 0.03, l * 0.12),
				Vector3(0.0, side * -0.3, 0.0))
	_face(semi, -l * 0.18 - body_centre.z, h * 0.1, h * 0.17, 0.5, body_centre)
	_mouth(Vector3(0.0, -h * 0.14, nose + l * 0.035), Vector3(w * 0.14, h * 0.05, 0.03))


## Hybrid: a bubble-eye goldfish, gazing upward over two wobbly bubble sacs,
## with a flowing double tail.
func _build_goldfish() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var body_centre := Vector3(0.0, 0.0, l * 0.04)
	var semi := Vector3(w * 0.4, h * 0.5, l * 0.4)
	_body(Color(1.0, 0.62, 0.15), body_centre, semi * 2.0)
	var bubble := _material(Color(0.75, 0.9, 1.0), 0.1, 0.55)
	var fin_color := Color(1.0, 0.72, 0.3)
	var fin_material := _material(fin_color, 0.5, 0.85)
	for side: float in [-1.0, 1.0]:
		_part(self, _sphere(), bubble, Vector3(side * w * 0.3, -h * 0.12, -l * 0.27), Vector3(w * 0.32, h * 0.6, l * 0.2))
		# Eyes on top, looking up.
		_eye(Vector3(side * w * 0.25, h * 0.26, -l * 0.3), h * 0.13, Vector3(side * 0.3, 1.0, -0.4))
	_cheeks(semi, -l * 0.18 - body_centre.z, -h * 0.02, h * 0.08, body_centre)
	_part(self, _sphere(), fin_material, Vector3(0.0, semi.y * 0.9, l * 0.02), Vector3(0.035, h * 0.5, l * 0.3))
	_tail_pivot(Vector3(0.0, 0.0, body_centre.z + semi.z * 0.88))
	for side: float in [-1.0, 1.0]:
		_part(tail, _sphere(), fin_material, Vector3(side * w * 0.07, 0.0, l * 0.11), Vector3(0.03, h * 1.15, l * 0.26),
				Vector3(0.0, side * 0.45, 0.0))
	_fin_pivots(Vector3(semi.x * 0.85, -h * 0.18, -l * 0.08))
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		_part(pivot, _sphere(), fin_material, Vector3(side * w * 0.06, 0.0, 0.0), Vector3(w * 0.18, 0.03, l * 0.13))
	_mouth(Vector3(0.0, -h * 0.02, body_centre.z - semi.z * 0.985), Vector3(w * 0.07, h * 0.09, 0.03))


## Merc: a boxy yellow boxfish with polka dots, tiny fins and pouty lips.
func _build_boxfish() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var body_centre := Vector3(0.0, 0.0, -l * 0.04)
	var half := Vector3(w * 0.47, h * 0.48, l * 0.37)
	_body(Color(1.0, 0.84, 0.1), body_centre, half * 2.0, _box())
	# Polka dots on the sides and the top.
	var dot := _material(BLACK.lightened(0.1))
	for row: Vector2 in [Vector2(-0.22, 0.2), Vector2(0.0, 0.25), Vector2(0.24, 0.18), Vector2(-0.1, -0.2), Vector2(0.14, -0.22)]:
		for side: float in [-1.0, 1.0]:
			_part(self, _sphere(), dot, body_centre + Vector3(side * half.x, row.y * h, row.x * l), Vector3(0.02, h * 0.12, h * 0.12))
	for spot: Vector2 in [Vector2(-0.2, -0.15), Vector2(0.0, 0.18), Vector2(0.2, -0.1), Vector2(0.12, 0.15)]:
		_part(self, _sphere(), dot, body_centre + Vector3(spot.y * w, half.y, spot.x * l), Vector3(h * 0.12, 0.02, h * 0.12))
	# Pouty pink lips on the front face.
	var lips := _part(self, TorusMesh.new(), _material(Color(1.0, 0.45, 0.6), 0.4), body_centre + Vector3(0.0, -h * 0.12, -half.z - 0.02),
			Vector3(w * 0.13, w * 0.13, h * 0.13), Vector3(PI / 2.0, 0.0, 0.0))
	lips.name = "Lips"
	for side: float in [-1.0, 1.0]:
		_eye(body_centre + Vector3(side * half.x * 0.78, h * 0.22, -half.z * 0.92), h * 0.17, Vector3(side * 0.5, 0.1, -1.0))
		_part(self, _sphere(), _material(BLUSH), body_centre + Vector3(side * half.x * 0.62, -h * 0.08, -half.z - 0.005),
				Vector3(w * 0.14, h * 0.1, 0.02))
	var fin_material := _material(Color(1.0, 0.92, 0.5), 0.5, 0.9)
	_tail_pivot(Vector3(0.0, 0.0, body_centre.z + half.z))
	_part(tail, _sphere(), fin_material, Vector3(0.0, 0.0, l * 0.07), Vector3(0.03, h * 0.6, l * 0.16))
	_fin_pivots(Vector3(half.x, -h * 0.05, -l * 0.08))
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		_part(pivot, _sphere(), fin_material, Vector3(side * w * 0.05, 0.0, 0.0), Vector3(w * 0.12, 0.025, l * 0.08))


# --- Parts ----------------------------------------------------------------------

func _body(color: Color, centre: Vector3, size: Vector3, mesh: Mesh = null) -> void:
	_body_material = _material(color)
	var body := _part(self, mesh if mesh else _sphere(), _body_material, centre, size)
	body.name = "Body"


func _tail_pivot(at: Vector3) -> void:
	tail = Node3D.new()
	tail.name = "TailPivot"
	tail.position = at
	add_child(tail)


## Fin pivots either side, at `at` and its mirror (at.x is the right one's).
func _fin_pivots(at: Vector3) -> void:
	fin_left = Node3D.new()
	fin_left.name = "FinLeftPivot"
	fin_left.position = Vector3(-at.x, at.y, at.z)
	add_child(fin_left)
	fin_right = Node3D.new()
	fin_right.name = "FinRightPivot"
	fin_right.position = at
	add_child(fin_right)


## A triangular fin standing up along the fish (a dorsal fin), its base centred
## at `base`; `sweep` 0 puts the tip over the back of the base, 0.5 the middle.
func _fin(parent: Node3D, color: Color, base: Vector3, length: float, height: float, sweep: float) -> void:
	var prism := PrismMesh.new()
	prism.left_to_right = sweep
	# Turned so the prism's x runs along the fish, its left end at the back.
	_part(parent, prism, _material(color), base + Vector3(0.0, height / 2.0, 0.0), Vector3(length, height, 0.04), Vector3(0.0, PI / 2.0, 0.0))


## A band round an ellipsoid body (semi-axes `semi`) at `z`, `thickness` long:
## the slice of a copy of the body `grow` times as big, so it hugs the body.
func _band(semi: Vector3, z: float, thickness: float, color: Color, grow: float) -> void:
	var material := _material(color)
	var band := CSGCombiner3D.new()
	band.name = "Band"
	add_child(band)
	var shell := CSGSphere3D.new()
	shell.radius = 0.5
	shell.radial_segments = 32
	shell.rings = 16
	shell.scale = semi * 2.0 * grow
	shell.material = material
	band.add_child(shell)
	var slab := CSGBox3D.new()
	slab.operation = CSGShape3D.OPERATION_INTERSECTION
	slab.size = Vector3(semi.x * 3.0, semi.y * 3.0, thickness)
	slab.position.z = z
	slab.material = material
	band.add_child(slab)


## Two eyes on an ellipsoid body (semi-axes `semi` about `centre`), `z` and `y`
## from its centre, looking out and forward.
func _face(semi: Vector3, z: float, y: float, radius: float, pupil := 0.6, centre := Vector3.ZERO) -> void:
	for side: float in [-1.0, 1.0]:
		var x := _ellipsoid_x(semi, y, z) * side * 0.92
		_eye(centre + Vector3(x, y, z), radius, Vector3(side * 0.7, 0.15, -0.7), pupil)


## A big round eye: white, a dark pupil looking along `look`, and a sparkle.
func _eye(at: Vector3, radius: float, look: Vector3, pupil := 0.6) -> void:
	var direction := look.normalized()
	var eye := _part(self, _sphere(), _material(WHITE, 0.2), at, Vector3.ONE * radius * 2.0)
	eye.name = "Eye"
	var pupil_at := at + direction * radius * (1.0 - pupil * 0.45)
	_part(self, _sphere(), _material(BLACK, 0.15), pupil_at, Vector3.ONE * radius * 2.0 * pupil)
	var sparkle := _material(Color.WHITE)
	sparkle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_part(self, _sphere(), sparkle, pupil_at + (direction + Vector3(0.3, 0.6, 0.0)).normalized() * radius * pupil * 0.75,
			Vector3.ONE * radius * 0.45)


func _cheeks(semi: Vector3, z: float, y: float, radius: float, centre := Vector3.ZERO) -> void:
	for side: float in [-1.0, 1.0]:
		var x := _ellipsoid_x(semi, y, z) * side
		_part(self, _sphere(), _material(BLUSH), centre + Vector3(x, y, z), Vector3(0.02, radius, radius * 1.4))


func _mouth(at: Vector3, size: Vector3) -> void:
	var mouth := _part(self, _sphere(), _material(Color(0.25, 0.05, 0.08), 0.4), at, size)
	mouth.name = "Mouth"


## How far out (x) an ellipsoid's surface is at height y and depth z.
func _ellipsoid_x(semi: Vector3, y: float, z: float) -> float:
	return semi.x * sqrt(maxf(1.0 - pow(y / semi.y, 2.0) - pow(z / semi.z, 2.0), 0.0))


func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, size: Vector3, rotation_euler := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation = rotation_euler
	part.scale = size
	parent.add_child(part)
	return part


func _material(color: Color, roughness := 0.6, alpha := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = roughness
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


# Unit meshes (1 m across), sized by each part's scale.

func _sphere() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	return mesh


func _box() -> BoxMesh:
	return BoxMesh.new()


func _prism() -> PrismMesh:
	return PrismMesh.new()


func _capsule() -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	return mesh


func _cone() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	return mesh


func _cylinder() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	return mesh
