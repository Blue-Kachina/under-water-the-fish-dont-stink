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
## change with it, as do its shader skins (_skins). Fins and skins that ripple as
## it swims (_waving) are moved by react(), which also squashes and stretches a
## model's `squash` node, if it has one, with the fish's acceleration.

const BLACK := Color(0.04, 0.04, 0.06)
const WHITE := Color(0.97, 0.97, 0.95)
const BLUSH := Color(1.0, 0.55, 0.65)
const RAY_SKIN := preload("res://shaders/ray_skin.gdshader")
const KOI_SKIN := preload("res://shaders/koi_skin.gdshader")
const BOX_SKIN := preload("res://shaders/box_skin.gdshader")
const FIN_MEMBRANE := preload("res://shaders/fin_membrane.gdshader")

var family := FishCharacter.Family.OCTANE
var tail: Node3D
var fin_left: Node3D
var fin_right: Node3D

## Scaled by react() to squash and stretch, if the model has one.
var squash: Node3D

var _size := Vector3.ONE  # the hitbox (m): width, height, length
var _body_material: StandardMaterial3D
var _own_body_color: Variant = null  # before set_body_color()
var _squash_base := Vector3.ONE  # squash's scale at rest
var _last_velocity := Vector3.ZERO
var _acceleration := Vector3.ZERO  # smoothed, world space
var _stretch := Vector2.ZERO  # current (along, up): + longer / taller
var _stretch_speed := Vector2.ZERO
## Face features that ride the squash without squashing: each anchor's spot
## on the body at rest, moved with the squash in react().
var _face_anchors: Array[Node3D] = []
var _face_rest: Array[Vector3] = []
## Shader skins set_body_color() tints (their "albedo"), and the shaders react()
## ripples with the swim (their "phase" and "effort").
var _skins: Array[ShaderMaterial] = []
var _waving: Array[ShaderMaterial] = []
var _swim_phase := 0.0
## The ray's skin, body and tail (ray_skin.gdshader), whose wings and whip
## react() also bends.
var _skin: ShaderMaterial
var _tail_skin: ShaderMaterial


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
			model._build_ray()
		FishCharacter.Family.BREAKOUT:
			model._build_swordfish()
		FishCharacter.Family.HYBRID:
			model._build_koi()
		FishCharacter.Family.MERC:
			model._build_boxfish()
	return model


## Squash and stretch with the fish's acceleration (from `velocity`, world
## space, given every frame), on a springy wobble. Speeding up stretches it
## along its length and braking squashes it; falling stretches it tall and
## landing squashes it flat. Volume is kept, so it bulges the other way. The
## edge it's moving toward stays put and the trailing side does the stretching
## (the bottom, when it isn't moving up or down, so it squashes onto the floor).
func react(delta: float, velocity: Vector3) -> void:
	if not _waving.is_empty():
		_swim(delta, velocity)
	if squash == null or delta <= 0.0:
		return
	var raw := (velocity - _last_velocity) / delta
	_last_velocity = velocity
	# Physics ticks and frames don't line up: smooth the per-frame acceleration.
	_acceleration = _acceleration.lerp(raw, 1.0 - exp(-15.0 * delta))
	var to_local := global_basis.orthonormalized().inverse()
	var local := to_local * _acceleration
	var target := Vector2(clampf(-local.z / 35.0, -0.3, 0.35), clampf(-local.y / 45.0, -0.35, 0.2))
	_stretch_speed += ((target - _stretch) * 160.0 - _stretch_speed * 11.0) * delta
	_stretch += _stretch_speed * delta
	var along := 1.0 + _stretch.x
	var up := 1.0 + _stretch.y
	var shape := Vector3(1.0 / sqrt(along * up), up, along)
	# Which end leads, blended over 1 m/s so it never snaps: -1 = the front (-Z)
	# or the bottom, +1 = the back or the top.
	var moving := to_local * velocity
	var lead_z := clampf(moving.z, -1.0, 1.0)
	var lead_y := lerpf(-1.0, signf(moving.y), clampf(absf(moving.y), 0.0, 1.0))
	var shift := -Vector3(0.0, lead_y * (up - 1.0), lead_z * (along - 1.0)) * _squash_base / 2.0
	squash.scale = _squash_base * shape
	squash.position = shift
	for i in _face_anchors.size():
		_face_anchors[i].position = _face_rest[i] * shape + shift


func set_body_color(color: Color) -> void:
	if _own_body_color == null:
		_own_body_color = _body_material.albedo_color
	_tint(color)


## The body's colour now: the character's own, or the one set_body_color() gave it.
func body_color() -> Color:
	return _body_material.albedo_color


## Back to the character's own colour after set_body_color().
func reset_body_color() -> void:
	if _own_body_color != null:
		_tint(_own_body_color)


func _tint(color: Color) -> void:
	_body_material.albedo_color = color
	for skin in _skins:
		skin.set_shader_parameter("albedo", color)


## The swim wave: fins and skins ripple, harder and quicker with speed. The
## ray's wings also follow the fin pivots (their roll lifts the tips, their turn
## sweeps them back) and its tail whips.
func _swim(delta: float, velocity: Vector3) -> void:
	var effort := clampf(velocity.length() / 23.0, 0.0, 1.0)
	_swim_phase = fmod(_swim_phase + delta * lerpf(2.5, 9.0, effort), TAU * 100.0)
	for material in _waving:
		material.set_shader_parameter("phase", _swim_phase)
		material.set_shader_parameter("effort", effort)
	if _skin == null:
		return
	_skin.set_shader_parameter("ripple", lerpf(0.012, 0.035, effort))
	_skin.set_shader_parameter("flap_left", -fin_left.rotation.z)
	_skin.set_shader_parameter("flap_right", fin_right.rotation.z)
	_skin.set_shader_parameter("sweep_left", fin_left.rotation.y)
	_skin.set_shader_parameter("sweep_right", -fin_right.rotation.y)
	_tail_skin.set_shader_parameter("tail_ripple", lerpf(0.05, 0.12, effort))


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


## Plank: a string ray, one smooth shape from its domed head out to thin wing
## membranes that bend, sweep and ripple as it swims (ray_skin.gdshader). Deep
## blue with pale spots over a white belly, big sleepy brown eyes over a round
## snout, and a long whip tail curling up behind. Its wings reach out past the
## hitbox's sides and its tail well past the back.
func _build_ray() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var color := Color(0.05, 0.17, 0.47)
	_body_material = _material(color, 0.45)  # for set_body_color(); the skin is shaded by _skin
	_skin = ShaderMaterial.new()
	_skin.shader = RAY_SKIN
	_skin.set_shader_parameter("albedo", color)
	_skin.set_shader_parameter("hinge", w * 0.18)
	_skin.set_shader_parameter("span", _ray_edge(RAY_TIPS))
	_skin.set_shader_parameter("spot_cell", w * 0.08)
	_skin.set_shader_parameter("wave", TAU / (l * 0.9))
	_skin.set_shader_parameter("streak_from", -l * 0.33)
	_skin.set_shader_parameter("streak_to", -l * 0.12)
	_skin.set_shader_parameter("streak_gap", w * 0.04)
	_skin.set_shader_parameter("gill_from", -l * 0.27)
	_skin.set_shader_parameter("gill_to", -l * 0.1)
	_skin.set_shader_parameter("gill_x", w * 0.1)
	_skin.set_shader_parameter("gill_length", w * 0.026)
	_skin.set_shader_parameter("mouth_z", -l * 0.34)
	_skin.set_shader_parameter("mouth_width", w * 0.05)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _ray_mesh()
	body.material_override = _skin
	body.extra_cull_margin = 0.3  # the shader bends the wings out of the mesh's bounds
	add_child(body)
	# A little smile under the round snout.
	_mouth(Vector3(0.0, -h * 0.05, -l * 0.45), Vector3(w * 0.15, h * 0.035, l * 0.05))
	# Big brown eyes peeping out of the front of the brow mounds (_ray_thickness).
	for side: float in [-1.0, 1.0]:
		var brow := _ray_brow(side)
		var radius := h * 0.15
		var at := Vector3(brow.x, _ray_top(brow.x, brow.z - radius * 0.9) - radius * 0.55, brow.z - radius * 0.9)
		_eye(at, radius, Vector3(side * 0.6, 0.2, -0.75), 0.7, null, Color(0.35, 0.13, 0.06))
	# The wings bend in the shader: the pivots only carry the swim animation's
	# flap and sweep to it (_swim).
	_fin_pivots(Vector3(w * 0.18, 0.0, -l * 0.06))
	_tail_pivot(Vector3(0.0, 0.0, l * 0.26))
	var tail_length := l * 0.7
	_tail_skin = ShaderMaterial.new()
	_tail_skin.shader = RAY_SKIN
	_tail_skin.set_shader_parameter("tail_mode", true)
	_tail_skin.set_shader_parameter("albedo", color)
	_tail_skin.set_shader_parameter("tail_length", tail_length)
	_skins.append_array([_skin, _tail_skin])
	_waving.append_array([_skin, _tail_skin])
	var whip := MeshInstance3D.new()
	whip.name = "Whip"
	whip.mesh = _tube_mesh(tail_length, 0.034, 1.2)
	whip.material_override = _tail_skin
	whip.extra_cull_margin = 0.2
	tail.add_child(whip)


const RAY_TIPS := 0.56  # how far back the wingtips are, nose 0 to tail 1


## The ray's outline: how far out (m) its edge is `along` it (the nose 0, where
## the tail starts 1), widest at the wingtips and rounded at both ends.
func _ray_edge(along: float) -> float:
	var span := _size.x * 0.62
	if along < RAY_TIPS:
		return span * pow(sin(PI / 2.0 * along / RAY_TIPS), 0.55)
	return span * pow(maxf(cos(PI / 2.0 * (along - RAY_TIPS) / (1.0 - RAY_TIPS)), 0.0), 0.75)


## How far the ray's top (or its belly, below) is from its middle at (x, z),
## before rounding off at the rim: a dome for the body falling smoothly away into
## thin wings, with the head rising off the front of it over a round snout.
func _ray_thickness(x: float, z: float, top: bool) -> float:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var membrane := 0.007
	var body := exp(-2.6 * (pow(x / (w * 0.24), 2.0) + pow((z + l * 0.06) / (l * 0.36), 2.0)))
	var snout := exp(-pow(x / (w * 0.14), 2.0) - pow((z + l * 0.43) / (l * 0.08), 2.0))
	if not top:
		return h * 0.4 * body + h * 0.14 * snout + membrane
	var head := exp(-3.0 * (pow(x / (w * 0.2), 2.0) + pow((z + l * 0.26) / (l * 0.2), 2.0)))
	var brows := 0.0
	for side: float in [-1.0, 1.0]:
		var brow := _ray_brow(side)
		brows = maxf(brows, exp(-pow((x - brow.x) / (w * 0.07), 2.0) - pow((z - brow.z) / (l * 0.06), 2.0)))
	return h * 0.45 * body + h * 0.18 * head + h * 0.17 * brows + h * 0.14 * snout + membrane


## Where the mound over each eye (side -1 left, 1 right) is highest.
func _ray_brow(side: float) -> Vector3:
	return Vector3(side * _size.x * 0.15, 0.0, -_size.z * 0.25)


## The nose and tail ends of the ray's body (z).
func _ray_ends() -> Vector2:
	return Vector2(-_size.z * 0.47, _size.z * 0.3)


## How high the ray's top is at (x, z), rim and all.
func _ray_top(x: float, z: float) -> float:
	var ends := _ray_ends()
	var edge := _ray_edge(inverse_lerp(ends.x, ends.y, z))
	var across := clampf(x / maxf(edge, 0.001), -1.0, 1.0)
	return _ray_thickness(x, z, true) * sqrt(1.0 - across * across)


## The ray's body and wings as one shape: a top and a belly (UV.y 1 and 0)
## meeting at a rounded rim, the columns bunched toward the rim.
func _ray_mesh() -> ArrayMesh:
	var ends := _ray_ends()
	var rows := 56
	var columns := 48
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for surface in 2:
		var top := surface == 0
		for i in rows + 1:
			var along := float(i) / rows
			var z := lerpf(ends.x, ends.y, along)
			var edge := _ray_edge(along)
			for j in columns + 1:
				var across := sin(PI / 2.0 * (2.0 * j / columns - 1.0))
				var x := across * edge
				var y := _ray_thickness(x, z, top) * sqrt(maxf(1.0 - across * across, 0.0))
				tool.set_uv(Vector2(along, 1.0 if top else 0.0))
				tool.add_vertex(Vector3(x, y if top else -y, z))
	for surface in 2:
		var first := surface * (rows + 1) * (columns + 1)
		for i in rows:
			for j in columns:
				var a := first + i * (columns + 1) + j
				var b := a + 1
				var c := a + columns + 1
				var d := c + 1
				var corners := [a, b, c, b, d, c] if surface == 0 else [a, c, b, b, c, d]
				for corner: int in corners:
					tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## A whip tail or whisker: a tube along +Z, `radius` thick at its base and
## thinning to a point as it curls up by `curl` (rad, down if less than 0);
## UV.x runs 0 at the base to 1 at the tip and UV.y round it.
func _tube_mesh(length: float, radius: float, curl: float) -> ArrayMesh:
	var rings := 32
	var sides := 8
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var at := Vector3.ZERO
	for i in rings + 1:
		var along := float(i) / rings
		var pitch := curl * pow(along, 1.6)
		var forward := Vector3(0.0, sin(pitch), cos(pitch))
		var up := Vector3(0.0, cos(pitch), -sin(pitch))
		var thickness := radius * lerpf(1.0, 0.1, along)
		for k in sides + 1:
			var angle := TAU * k / sides
			tool.set_uv(Vector2(along, float(k) / sides))
			tool.add_vertex(at + (Vector3.RIGHT * cos(angle) + up * sin(angle)) * thickness)
		at += forward * length / rings
	for i in rings:
		for k in sides:
			var a := i * (sides + 1) + k
			var b := a + 1
			var c := a + sides + 1
			var d := c + 1
			for corner: int in [a, c, b, b, c, d]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


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


## Hybrid: a butterfly koi, white with orange-red patches and a few ink spots
## (koi_skin.gdshader), with long flowing fins and a big forked tail, all thin
## frilly membranes that ripple as it swims (fin_membrane.gdshader), whiskers
## and round lips. Its fins and tail reach out past the hitbox.
func _build_koi() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var color := Color(0.93, 0.3, 0.07)
	_body_material = _material(color)  # for set_body_color(); the skin is shaded by koi_skin
	var skin := ShaderMaterial.new()
	skin.shader = KOI_SKIN
	skin.set_shader_parameter("albedo", color)
	_skins.append(skin)
	var ends := Vector2(-l * 0.5, l * 0.36)
	var semi := Vector2(w * 0.24, h * 0.46)
	skin.set_shader_parameter("girth", (semi.x + semi.y) / 2.0)
	skin.set_shader_parameter("scales_from", -l * 0.33)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _koi_mesh(ends, semi)
	body.material_override = skin
	add_child(body)
	var fins := _fin_material(Color(1.0, 0.86, 0.74), Color(1.0, 0.97, 0.93), 14.0, 0.035, 0.8, 0.5)
	fins.set_shader_parameter("ray_color", Color(1.0, 0.6, 0.4))
	# Long flowing pectorals on the swim animation's pivots, little pelvics.
	_fin_pivots(Vector3(semi.x * 0.7, -semi.y * 0.45, -l * 0.22))
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		_membrane(pivot, fins, Vector3(0.0, 0.0, -0.03), Vector3(0.0, 0.0, 0.05), Vector3(side, -0.3, 0.9),
				[l * 0.16, l * 0.24, l * 0.26, l * 0.22], 0.5, 0.15, 0.08)
		_membrane(self, fins, Vector3(side * semi.x * 0.35, -_koi_height(ends, semi, 0.0) * 0.8, -l * 0.02), Vector3(side * semi.x * 0.3, -_koi_height(ends, semi, l * 0.06) * 0.8, l * 0.06),
				Vector3(side * 0.5, -0.7, 0.8), [l * 0.08, l * 0.11, l * 0.09], 0.3, 0.12, 0.05)
	# A long ruffled dorsal fin along the back, a small anal fin underneath.
	_membrane(self, fins, Vector3(0.0, _koi_height(ends, semi, -l * 0.1) * 0.93, -l * 0.1), Vector3(0.0, _koi_height(ends, semi, l * 0.26) * 0.9, l * 0.26), Vector3(0.0, 1.0, 0.9),
			[h * 0.28, h * 0.42, h * 0.4, h * 0.34, h * 0.26], 0.0, 0.14, 0.12)
	_membrane(self, fins, Vector3(0.0, -_koi_height(ends, semi, l * 0.17) * 0.9, l * 0.17), Vector3(0.0, -_koi_height(ends, semi, l * 0.28) * 0.9, l * 0.28), Vector3(0.0, -1.0, 0.8),
			[h * 0.2, h * 0.26, h * 0.18], 0.0, 0.12, 0.06)
	# The big forked tail: two long lobes fanning up and down.
	_tail_pivot(Vector3(0.0, 0.0, ends.y - l * 0.04))
	var stalk := _koi_height(ends, semi, ends.y - l * 0.04)
	_membrane(tail, fins, Vector3(0.0, stalk * 0.9, 0.0), Vector3(0.0, -stalk * 0.9, 0.0), Vector3(0.0, 0.0, 1.0),
			[l * 0.34, l * 0.25, l * 0.14, l * 0.25, l * 0.34], 1.3, 0.15, 0.08)
	# Eyes on the sides of the head, round lips, and two pairs of whiskers.
	var head_z := -l * 0.37
	var head := semi.x * _koi_radius(inverse_lerp(ends.x, ends.y, head_z))
	for side: float in [-1.0, 1.0]:
		_eye(Vector3(side * head * 0.8, semi.y * 0.18, head_z), h * 0.12, Vector3(side * 0.8, 0.15, -0.6), 0.65)
	var lips_at := Vector3(0.0, -semi.y * 0.06, ends.x + 0.01)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.15
	ring.outer_radius = 0.5
	var lip_material := _material(Color(1.0, 0.8, 0.74), 0.4)
	_part(self, ring, lip_material, lips_at, Vector3(w * 0.09, 0.07, w * 0.075), Vector3(PI / 2.0, 0.0, 0.0)).name = "Lips"
	_mouth(lips_at + Vector3(0.0, 0.0, -0.008), Vector3(w * 0.03, w * 0.025, 0.02))
	for side: float in [-1.0, 1.0]:
		for whisker: Vector2 in [Vector2(l * 0.06, 0.6), Vector2(l * 0.035, -0.2)]:
			var root := lips_at + Vector3(side * w * 0.045, -0.005, 0.02)
			var barbel := MeshInstance3D.new()
			barbel.name = "Whisker"
			barbel.mesh = _tube_mesh(whisker.x, 0.006, -0.9)
			barbel.material_override = lip_material
			barbel.position = root
			barbel.basis = Basis.looking_at(-Vector3(side * 0.8, -0.4, whisker.y).normalized())
			add_child(barbel)


## How thick a koi is (of its widest) `along` it, nose 0 to tail 1: a round
## head, widest a third of the way back, narrowing to a slim tail stalk with a
## rounded end.
static func _koi_radius(along: float) -> float:
	var widest := 0.33
	var stalk := 0.93
	if along < widest:
		return sqrt(maxf(1.0 - pow((widest - along) / widest, 2.0), 0.0))
	if along < stalk:
		var t := (along - widest) / (stalk - widest)
		return lerpf(1.0, 0.2, t * t * (3.0 - 2.0 * t))
	return 0.2 * sqrt(maxf(1.0 - pow((along - stalk) / (1.0 - stalk), 2.0), 0.0))


## How high a koi's top is (m) at z, the body running nose `ends.x` to tail
## `ends.y`, `semi.y` at its tallest.
static func _koi_height(ends: Vector2, semi: Vector2, z: float) -> float:
	return semi.y * _koi_radius(inverse_lerp(ends.x, ends.y, z))


## A koi's body from its nose (`ends.x`) to its tail (`ends.y`), `semi` its
## widest half width and height.
func _koi_mesh(ends: Vector2, semi: Vector2) -> ArrayMesh:
	var rows := 48
	var around := 32
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows + 1:
		var along := float(i) / rows
		var z := lerpf(ends.x, ends.y, along)
		var radius := _koi_radius(along)
		for k in around:
			var angle := TAU * k / around
			tool.set_uv(Vector2(along, float(k) / around))
			tool.add_vertex(Vector3(sin(angle) * semi.x * radius, cos(angle) * semi.y * radius, z))
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, b, a + around, b, b + around, a + around]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## Merc: a yellow boxfish, a rounded box narrowing to its tail, armoured in
## faint plates most with a black spot (box_skin.gdshader), with big eyes, pouty
## lips and little fan fins that flutter fast (fin_membrane.gdshader). It
## squashes and stretches with its acceleration (react) like a jelly sweet: long
## and thin speeding up, short and wide braking, tall falling, flat landing.
func _build_boxfish() -> void:
	var w := _size.x
	var h := _size.y
	var l := _size.z
	var color := Color(1.0, 0.8, 0.06)
	# A unit box scaled to the hitbox, so it all squashes as one; `inside` it
	# undoes that so the parts are placed in metres.
	squash = Node3D.new()
	squash.name = "Squash"
	_squash_base = _size
	squash.scale = _squash_base
	add_child(squash)
	var inside := Node3D.new()
	inside.name = "Inside"
	inside.scale = Vector3.ONE / _squash_base
	squash.add_child(inside)
	_body_material = _material(color)  # for set_body_color(); the skin is shaded by box_skin
	var skin := ShaderMaterial.new()
	skin.shader = BOX_SKIN
	skin.set_shader_parameter("albedo", color)
	skin.set_shader_parameter("plate_size", w * 0.17)
	_skins.append(skin)
	var centre := Vector3(0.0, 0.0, -l * 0.04)
	var semi := Vector3(w * 0.46, h * 0.47, l * 0.42)
	var taper := 0.36
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _box_mesh(semi, 0.5, taper)
	body.material_override = skin
	body.position = centre
	inside.add_child(body)
	# Big eyes high on the front of its sides and pouty lips, riding the squash
	# without squashing (_face_anchor).
	for side: float in [-1.0, 1.0]:
		var eye := centre + Vector3(side * semi.x * 0.9, semi.y * 0.4, -semi.z * 0.62)
		_eye(Vector3.ZERO, h * 0.15, Vector3(side * 0.65, 0.15, -0.75), 0.62, _face_anchor(eye))
	var lips := _face_anchor(centre + Vector3(0.0, -semi.y * 0.28, -semi.z + 0.004))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.12
	ring.outer_radius = 0.5
	_part(lips, ring, _material(Color(1.0, 0.5, 0.45), 0.35), Vector3.ZERO, Vector3(w * 0.12, 0.09, h * 0.15), Vector3(PI / 2.0, 0.0, 0.0)).name = "Lips"
	_part(lips, _sphere(), _material(Color(0.25, 0.05, 0.08), 0.4), Vector3(0.0, 0.0, -0.022), Vector3(w * 0.03, h * 0.04, 0.02)).name = "Mouth"
	# Fan fins: pectorals behind the eyes on the swim animation's pivots, a
	# small dorsal and anal fin near the back, and a rounded tail fan.
	var fins := _fin_material(Color(1.0, 0.62, 0.12), Color(1.0, 0.88, 0.5), 9.0, 0.014, 2.6, 0.45)
	_fin_pivots(Vector3(semi.x * 0.96, -semi.y * 0.12, centre.z - semi.z * 0.18), inside)
	for side: float in [-1.0, 1.0]:
		var pivot := fin_left if side < 0.0 else fin_right
		_membrane(pivot, fins, Vector3(0.0, h * 0.12, 0.0), Vector3(0.0, -h * 0.12, 0.0), Vector3(side * 0.7, 0.0, 1.0),
				[l * 0.11, l * 0.15, l * 0.15, l * 0.11], 0.9, 0.1)
	_membrane(inside, fins, centre + Vector3(0.0, semi.y * _box_narrowing(0.45, taper) * 0.92, semi.z * 0.45), centre + Vector3(0.0, semi.y * _box_narrowing(0.75, taper) * 0.85, semi.z * 0.75),
			Vector3(0.0, 1.0, 0.7), [l * 0.06, l * 0.09, l * 0.06], 0.0, 0.1)
	_membrane(inside, fins, centre + Vector3(0.0, -semi.y * _box_narrowing(0.45, taper) * 0.92, semi.z * 0.45), centre + Vector3(0.0, -semi.y * _box_narrowing(0.75, taper) * 0.85, semi.z * 0.75),
			Vector3(0.0, -1.0, 0.7), [l * 0.06, l * 0.09, l * 0.06], 0.0, 0.1)
	_tail_pivot(centre + Vector3(0.0, 0.0, semi.z * 0.92), inside)
	var stalk := semi.y * _box_narrowing(0.95, taper)
	_membrane(tail, fins, Vector3(0.0, stalk * 0.8, 0.0), Vector3(0.0, -stalk * 0.8, 0.0), Vector3(0.0, 0.0, 1.0),
			[l * 0.18, l * 0.23, l * 0.24, l * 0.23, l * 0.18], 1.2, 0.1)


## How much a boxfish narrows `along` it (-1 the nose to 1 the tail): a little
## toward its snout, down to `taper` at the tail.
static func _box_narrowing(along: float, taper: float) -> float:
	var t := clampf((along - 0.15) / 0.85, 0.0, 1.0)
	var snout := clampf((-along - 0.5) / 0.5, 0.0, 1.0)
	return lerpf(1.0, taper, t * t * (3.0 - 2.0 * t)) * lerpf(1.0, 0.85, snout * snout)


## `value` to the `power`, keeping its sign.
static func _signed_pow(value: float, power: float) -> float:
	return signf(value) * pow(absf(value), power)


## A rounded box (a superellipsoid: `roundness` 1 an ellipsoid, toward 0 a
## box) with half sizes `semi`, narrowing toward the tail (+Z) to `taper`.
func _box_mesh(semi: Vector3, roundness: float, taper: float) -> ArrayMesh:
	var rows := 36
	var around := 56
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows + 1:
		var latitude := lerpf(-PI / 2.0, PI / 2.0, float(i) / rows)
		for k in around:
			var longitude := TAU * k / around - PI  # starting at the tail
			var flat := _signed_pow(cos(latitude), roundness)
			var z := -semi.z * flat * _signed_pow(cos(longitude), roundness)
			var narrow := _box_narrowing(z / semi.z, taper)
			var x := semi.x * flat * _signed_pow(sin(longitude), roundness) * narrow
			var y := semi.y * _signed_pow(sin(latitude), roundness) * narrow
			tool.add_vertex(Vector3(x, y, z))
	for i in rows:
		for k in around:
			var a := i * around + k
			var b := i * around + (k + 1) % around
			for corner: int in [a, b, a + around, b, b + around, a + around]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()


## A spot on a squashing body (`at`, m, at rest) for a face feature: it moves
## with the squash, but what's on it keeps its shape.
func _face_anchor(at: Vector3) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = "Face"
	anchor.position = at
	add_child(anchor)
	_face_anchors.append(anchor)
	_face_rest.append(at)
	return anchor


## A fin membrane's look (fin_membrane.gdshader): `root` fading to see-through
## `edge`, `rays` across it, rippling `flutter` m at the edge at `tempo`.
func _fin_material(root: Color, edge: Color, rays: float, flutter: float, tempo := 1.0, edge_alpha := 0.45) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FIN_MEMBRANE
	material.set_shader_parameter("albedo", root)
	material.set_shader_parameter("edge_color", edge)
	material.set_shader_parameter("ray_color", root.darkened(0.12))
	material.set_shader_parameter("rays", rays)
	material.set_shader_parameter("flutter", flutter)
	material.set_shader_parameter("tempo", tempo)
	material.set_shader_parameter("edge_alpha", edge_alpha)
	_waving.append(material)
	return material


## A thin fin on `parent`: rays fanning out of a root line from `from` to `to`
## (parent space) toward `out`, as long as `lengths` says along the root (spread
## evenly from its start to its end). `spread` (rad) fans the outer rays apart;
## the edge dips between the rays by `frill` (of their length) and the membrane
## ruffles by `ruffle`.
func _membrane(parent: Node3D, material: ShaderMaterial, from: Vector3, to: Vector3, out: Vector3, lengths: Array,
		spread := 0.0, frill := 0.12, ruffle := 0.0) -> MeshInstance3D:
	var columns := 72
	var rows := 10
	var rays: float = material.get_shader_parameter("rays")
	var along := to - from
	var normal := along.cross(out).normalized()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in columns + 1:
		var u := float(i) / columns
		var direction := out.normalized().rotated(normal, (u - 0.5) * spread)
		var length := _sample(lengths, u) * (1.0 - frill * 0.5 * (1.0 - cos(u * rays * TAU)))
		for j in rows + 1:
			var v := float(j) / rows
			var wave := normal * ruffle * length * v * v * sin(u * TAU * 2.5)
			tool.set_uv(Vector2(u, v))
			tool.add_vertex(from + along * u + direction * length * v + wave)
	for i in columns:
		for j in rows:
			var a := i * (rows + 1) + j
			var b := a + rows + 1
			for corner: int in [a, b, a + 1, a + 1, b, b + 1]:
				tool.add_index(corner)
	tool.generate_normals()
	var fin := MeshInstance3D.new()
	fin.name = "Fin"
	fin.mesh = tool.commit()
	fin.material_override = material
	fin.extra_cull_margin = 0.1  # it ripples out of its bounds
	parent.add_child(fin)
	return fin


## `values` spread evenly over 0..1, read off smoothly at `t`.
static func _sample(values: Array, t: float) -> float:
	var at := clampf(t, 0.0, 1.0) * (values.size() - 1)
	var i := mini(int(at), values.size() - 2)
	var before: float = values[maxi(i - 1, 0)]
	var after: float = values[mini(i + 2, values.size() - 1)]
	return cubic_interpolate(values[i], values[i + 1], before, after, at - i)


# --- Parts ----------------------------------------------------------------------

func _body(color: Color, centre: Vector3, size: Vector3) -> void:
	_body_material = _material(color)
	var body := _part(self, _sphere(), _body_material, centre, size)
	body.name = "Body"


func _tail_pivot(at: Vector3, parent: Node3D = null) -> void:
	tail = Node3D.new()
	tail.name = "TailPivot"
	tail.position = at
	(parent if parent else self).add_child(tail)


## Fin pivots either side, at `at` and its mirror (at.x is the right one's).
func _fin_pivots(at: Vector3, parent: Node3D = null) -> void:
	if parent == null:
		parent = self
	fin_left = Node3D.new()
	fin_left.name = "FinLeftPivot"
	fin_left.position = Vector3(-at.x, at.y, at.z)
	parent.add_child(fin_left)
	fin_right = Node3D.new()
	fin_right.name = "FinRightPivot"
	fin_right.position = at
	parent.add_child(fin_right)


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
## With an `iris` colour the pupil is that colour with a smaller black one on it.
func _eye(at: Vector3, radius: float, look: Vector3, pupil := 0.6, parent: Node3D = null, iris := BLACK) -> void:
	if parent == null:
		parent = self
	var direction := look.normalized()
	var eye := _part(parent, _sphere(), _material(WHITE, 0.2), at, Vector3.ONE * radius * 2.0)
	eye.name = "Eye"
	var pupil_at := at + direction * radius * (1.0 - pupil * 0.45)
	_part(parent, _sphere(), _material(iris, 0.15), pupil_at, Vector3.ONE * radius * 2.0 * pupil)
	if iris != BLACK:
		_part(parent, _sphere(), _material(BLACK, 0.15), pupil_at + direction * radius * pupil * 0.3, Vector3.ONE * radius * 1.3 * pupil)
	var sparkle := _material(Color.WHITE)
	sparkle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_part(parent, _sphere(), sparkle, pupil_at + (direction + Vector3(0.3, 0.6, 0.0)).normalized() * radius * pupil * 0.75,
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
