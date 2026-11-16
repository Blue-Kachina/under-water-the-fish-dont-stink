class_name SetPieces
extends RefCounted
## The procedural world's set pieces (planning_procedural_world.md, phase 7): focal points the layout places by rule,
## each on a clearing of flat floor in the outer band. Built from MeshKit surfaces (smooth, seamless) and the stone
## shader, seeded, so every machine builds the same ones:
##   whale fall   a great whale's skeleton lying on the sand: skull, jaws, a spine of vertebrae, ribs (some fallen)
##   hull         a sunken wooden hull broken in two, rolled on its side and half sunk, ribs inside
##   vents        a field of mineral chimneys trailing bubbles
## (The pillar to the surface is a tall mesa record in TerrainLayout.)
## Collision follows rule N: the solid parts (spine and skull, hull shells, chimneys) collide; ribs don't, so nothing
## can wedge between them.

enum Kind { WHALE_FALL, HULL, VENTS }

static var _bone: ShaderMaterial
static var _wood: ShaderMaterial
static var _vent: ShaderMaterial


## The clear floor (m) each kind needs round its middle.
static func reach(kind: int) -> float:
	match kind:
		Kind.WHALE_FALL:
			return 18.0
		Kind.HULL:
			return 20.0
		_:
			return 16.0


## Builds set piece `kind` from `seed_value` as a Node3D (its origin on the floor), with collision on layer 1 when `solid`.
static func build(kind: int, seed_value: int, solid: bool) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	match kind:
		Kind.WHALE_FALL:
			return _whale_fall(rng, solid)
		Kind.HULL:
			return _hull(rng, solid)
		_:
			return _vents(rng, solid)


# --- Materials ------------------------------------------------------------------------------------------------

static func bone() -> ShaderMaterial:
	if _bone == null:
		_bone = ShaderMaterial.new()
		_bone.shader = preload("res://shaders/stone.gdshader")
		_bone.set_shader_parameter("base_color", Vector3(0.82, 0.79, 0.70))
		_bone.set_shader_parameter("base_color_b", Vector3(0.66, 0.62, 0.54))
		_bone.set_shader_parameter("vein_strength", 0.0)
		_bone.set_shader_parameter("pitting", 0.9)
		_bone.set_shader_parameter("roughness_base", 0.7)
		_bone.set_shader_parameter("algae", 0.25)
		_bone.set_shader_parameter("coralline", 0.4)
	return _bone


static func wood() -> ShaderMaterial:
	if _wood == null:
		_wood = ShaderMaterial.new()
		_wood.shader = preload("res://shaders/stone.gdshader")
		_wood.set_shader_parameter("base_color", Vector3(0.30, 0.22, 0.15))
		_wood.set_shader_parameter("base_color_b", Vector3(0.20, 0.15, 0.11))
		_wood.set_shader_parameter("vein_strength", 0.25)
		_wood.set_shader_parameter("vein_scale", 3.0)
		_wood.set_shader_parameter("pitting", 0.6)
		_wood.set_shader_parameter("roughness_base", 0.9)
		_wood.set_shader_parameter("algae", 0.8)
		_wood.set_shader_parameter("coralline", 0.5)
		_wood.set_shader_parameter("strata_weight", 0.0)
	return _wood


static func vent() -> ShaderMaterial:
	if _vent == null:
		_vent = ShaderMaterial.new()
		_vent.shader = preload("res://shaders/stone.gdshader")
		_vent.set_shader_parameter("base_color", Vector3(0.30, 0.24, 0.22))
		_vent.set_shader_parameter("base_color_b", Vector3(0.52, 0.36, 0.22))
		_vent.set_shader_parameter("vein_strength", 0.0)
		_vent.set_shader_parameter("pitting", 1.0)
		_vent.set_shader_parameter("algae", 0.1)
		_vent.set_shader_parameter("coralline", 0.6)
		_vent.set_shader_parameter("strata_weight", 1.0)
	return _vent


# --- Whale fall ------------------------------------------------------------------------------------------------

static func _whale_fall(rng: RandomNumberGenerator, solid: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "WhaleFall"
	var length := rng.randf_range(22.0, 30.0)
	var kit := MeshKit.new()
	var hard := MeshKit.new()  # what collides: the spine and the skull
	kit.set_random(rng.randf())
	# The spine: lying on the sand along x, sagging and curving a little; vertebrae as bulges.
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var count := 60
	var bend := rng.randf_range(-0.12, 0.12)
	for i in count:
		var t := float(i) / (count - 1)
		var x := lerpf(-length * 0.32, length * 0.5, t)
		var thick := lerpf(0.55, 0.14, t)
		path.append(Vector3(x, thick * 0.8, sin(t * PI * 1.3) * length * bend))
		radii.append(thick * (1.0 if i % 2 == 0 else 0.62))
	kit.tube(path, radii, 10)
	hard.tube(path, radii, 8)
	# The skull: a long flattened dome at the front, and two jaw bones splayed forward of it.
	var skull_len := length * 0.24
	var first := kit.verts.size()
	kit.lathe(PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.9, 0.15), Vector2(1.3, 0.45), Vector2(1.2, 0.75), Vector2(0.7, 0.95),
			Vector2(0.05, 1.0)]), 16, func(angle: float, _v: float) -> float: return 1.0 - 0.35 * absf(sin(angle)))
	var skull_xf := Transform3D(Basis(Vector3.BACK, PI / 2.0).scaled(Vector3(skull_len, 1.1, 1.0)), Vector3(-length * 0.32, 0.9, path[0].z))
	kit.transform(first, skull_xf)
	var hard_first := hard.verts.size()
	hard.lathe(PackedVector2Array([Vector2(0.05, 0.0), Vector2(1.3, 0.45), Vector2(0.05, 1.0)]), 8)
	hard.transform(hard_first, skull_xf)
	for side: float in [-1.0, 1.0]:
		var jaw := PackedVector3Array()
		var spread := rng.randf_range(0.15, 0.4) * side
		for i in 9:
			var t := float(i) / 8.0
			jaw.append(Vector3(-length * 0.32 - skull_len * 0.95 - t * skull_len * 0.9, 0.25 + sin(t * PI) * 0.3,
					path[0].z + side * 0.9 + spread * t * skull_len))
		kit.tube(jaw, PackedFloat32Array([0.28, 0.26, 0.24, 0.22, 0.2, 0.18, 0.16, 0.14, 0.1]), 8)
	# Ribs: arcs from the chest vertebrae out and down to the sand; a few broken short, a few fallen flat.
	for i in range(6, 26, 2):
		var t := float(i) / (count - 1)
		var at := path[i]
		var r := lerpf(3.2, 1.6, t) * rng.randf_range(0.9, 1.1)
		for side: float in [-1.0, 1.0]:
			var fallen := rng.randf() < 0.2
			var broken := rng.randf() < 0.25
			var rib := PackedVector3Array()
			var steps := 10
			var end := rng.randf_range(0.45, 0.7) if broken else 1.0
			for s in steps + 1:
				var a := lerpf(0.15, PI * 0.95, float(s) / steps * end)
				var out := sin(a) * r * side
				var up := (1.0 - cos(a)) * r * 0.5
				if fallen:
					rib.append(Vector3(at.x + up * 0.3, 0.12, at.z + out * 1.1))
				else:
					rib.append(Vector3(at.x + up * 0.15, at.y + r * 0.55 - (cos(a) * r * 0.55) - up * 0.2, at.z + out))
			kit.tube(rib, PackedFloat32Array([0.13, 0.12, 0.11, 0.1, 0.09, 0.08]), 6)
	_add_mesh(root, kit.mesh(true, bone()), "Bones")
	if solid:
		_add_body(root, hard.mesh(false))
	return root


# --- Sunken hull -----------------------------------------------------------------------------------------------

static func _hull(rng: RandomNumberGenerator, solid: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Hull"
	var length := rng.randf_range(24.0, 30.0)
	var beam := rng.randf_range(8.5, 10.0)  # wide enough for the clearance ball (rule N)
	var depth := rng.randf_range(4.5, 5.5)
	var gap := rng.randf_range(0.5, 0.62)
	var roll := rng.randf_range(0.25, 0.55) * (1.0 if rng.randf() < 0.5 else -1.0)
	var kit := MeshKit.new()
	kit.set_random(rng.randf())
	for piece in 2:
		var v0 := 0.0 if piece == 0 else gap + 0.08
		var v1 := gap if piece == 0 else 1.0
		var first := kit.verts.size()
		var shell := func(offset: float) -> Callable:
			return func(u: float, v: float) -> Variant:
				var along := lerpf(v0, v1, v)
				var theta := lerpf(-PI * 0.5, PI * 0.5, u)
				var taper := sqrt(clampf(along / 0.18, 0.0, 1.0)) * pow(clampf((1.0 - along) / 0.4, 0.0, 1.0), 0.6)
				var w := (beam * 0.5 - offset) * maxf(taper, 0.04)
				var h := depth - offset
				var x := (along - 0.5) * length
				var p := Vector3(x, depth - cos(theta) * h * (0.6 + 0.4 * taper), sin(theta) * w)
				var wear := 1.0 if (piece == 0 and v > 0.92) or (piece == 1 and v < 0.08) else 0.0
				return [p, 0.4 * (1.0 - absf(sin(theta))), wear]
		kit.surface(16, 14, shell.call(0.0), false)
		kit.surface(16, 14, shell.call(0.18), false, false, false, 0.0, true)
		# Ribs inside, every 1.6 m.
		var x0 := (v0 - 0.5) * length
		var x1 := (v1 - 0.5) * length
		var x := x0 + 0.8
		while x < x1 - 0.5:
			var along := x / length + 0.5
			var taper := sqrt(clampf(along / 0.18, 0.0, 1.0)) * pow(clampf((1.0 - along) / 0.4, 0.0, 1.0), 0.6)
			var rib := PackedVector3Array()
			for s in 9:
				var theta := lerpf(-PI * 0.45, PI * 0.45, s / 8.0)
				rib.append(Vector3(x, depth - cos(theta) * (depth - 0.25) * (0.6 + 0.4 * taper), sin(theta) * (beam * 0.5 - 0.25) * maxf(taper, 0.04)))
			kit.tube(rib, PackedFloat32Array([0.12]), 6)
			x += 1.6
		# The bow piece lies askew of the stern.
		if piece == 1:
			kit.transform(first, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.35, 0.35)), Vector3(rng.randf_range(1.0, 2.5), 0.0, rng.randf_range(-1.5, 1.5))))
	# A broken mast lying across.
	var mast := PackedVector3Array([Vector3(-2.0, 0.3, -beam * 0.5 - 3.0), Vector3(1.0, 0.5, 0.0), Vector3(3.5, 0.4, beam * 0.5 + 2.0)])
	kit.tube(mast, PackedFloat32Array([0.32, 0.28, 0.22]), 8)
	var mesh := kit.mesh(true, wood())
	var hull := Node3D.new()
	hull.name = "Shell"
	hull.transform = Transform3D(Basis(Vector3.RIGHT, roll), Vector3(0.0, -depth * 0.3, 0.0))
	root.add_child(hull)
	_add_mesh(hull, mesh, "Wood")
	if solid:
		_add_body(hull, mesh)
	return root


# --- Vent field ------------------------------------------------------------------------------------------------

static func _vents(rng: RandomNumberGenerator, solid: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Vents"
	var kit := MeshKit.new()
	var spots: Array[Vector2] = []
	for i in rng.randi_range(4, 7):
		var spot := Vector2.ZERO
		for attempt in 20:
			spot = Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 11.0
			var ok := true
			for other in spots:
				if other.distance_to(spot) < 9.0:  # clearance-wide gaps between chimneys (rule N)
					ok = false
			if ok:
				break
		spots.append(spot)
		var tall := rng.randf_range(2.5, 7.0)
		var base := rng.randf_range(0.9, 1.6)
		var profile := PackedVector2Array()
		for s in 9:
			var v := s / 8.0
			profile.append(Vector2(base * (1.0 - 0.6 * v) * (1.0 + 0.25 * sin(v * 17.0 + i)) + (0.35 if s == 8 else 0.0), v * tall - 0.3))
		var first := kit.verts.size()
		kit.set_random(rng.randf())
		kit.lathe(profile, 12, func(angle: float, v: float) -> float: return 1.0 + 0.18 * sin(angle * 3.0 + v * 9.0 + i), true, true, 0.6)
		kit.transform(first, Transform3D(Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.12)),
				Vector3(spot.x, 0.0, spot.y)))
		var bubbles := _bubbles(tall)
		bubbles.position = Vector3(spot.x, tall - 0.2, spot.y)
		root.add_child(bubbles)
		if solid:
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = base * 0.9
			cylinder.height = tall
			shape.shape = cylinder
			body.position = Vector3(spot.x, tall * 0.5 - 0.3, spot.y)
			body.add_child(shape)
			root.add_child(body)
	_add_mesh(root, kit.mesh(true, vent()), "Chimneys")
	return root


## A thin stream of rising bubbles.
static func _bubbles(tall: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Bubbles"
	particles.amount = 36
	particles.lifetime = 7.0
	particles.preprocess = 7.0
	particles.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 40 + tall, 8))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.3
	process.direction = Vector3.UP
	process.spread = 8.0
	process.initial_velocity_min = 1.2
	process.initial_velocity_max = 2.4
	process.gravity = Vector3(0.0, 0.6, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.4
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.4
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(0.7, 0.9, 1.0, 0.55)
	var ring := GradientTexture2D.new()  # a soft round bubble with a brighter rim
	ring.fill = GradientTexture2D.FILL_RADIAL
	ring.fill_from = Vector2(0.5, 0.5)
	ring.fill_to = Vector2(1.0, 0.5)
	ring.width = 32
	ring.height = 32
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.7, 0.85, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	ring.gradient = gradient
	material.albedo_texture = ring
	quad.material = material
	particles.draw_pass_1 = quad
	return particles


# --- Helpers ---------------------------------------------------------------------------------------------------

static func _add_mesh(parent: Node3D, mesh: Mesh, name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


static func _add_body(parent: Node3D, mesh: Mesh) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var trimesh := mesh.create_trimesh_shape()
	trimesh.backface_collision = true
	shape.shape = trimesh
	body.add_child(shape)
	parent.add_child(body)
