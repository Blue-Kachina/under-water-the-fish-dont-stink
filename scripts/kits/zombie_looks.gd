class_name ZombieLooks
extends RefCounted
## Models for zombies that aren't one of the playable classes (EnemyKind.look),
## built as FishModels so the Horde bakes them like any other (SchoolLook):
## - "sardine": the Rotten Sardine, a slim silver schooling fish.
## - "sea_butterfly": the Fallen Angel's prey, a little sea snail (Limacina)
##   in a glossy coiled shell, flying on two wing-feet.
## Each fills the hitbox of the class its kind names (scaled by the kind's size).

const SARDINE_SKIN := preload("res://shaders/sardine_skin.gdshader")


## Model `id`, at `fish_class`'s hitbox; null if there's no such look.
static func build(id: String, fish_class: FishCharacter.FishClass) -> FishModel:
	var model := FishModel.new()
	model.name = "Visual"
	model.fish_class = fish_class
	model._size = FishCharacter.hitbox_size(fish_class)
	match id:
		"sardine":
			_sardine(model)
		"sea_butterfly":
			_sea_butterfly(model)
		_:
			model.free()
			return null
	return model


## The sardine: a slim spindle, its deepest a third of the way back, a small
## head with a big eye, a short dorsal fin mid-back, a deeply forked tail.
static func _sardine(m: FishModel) -> void:
	var l := m._size.z
	var length := l * 0.92
	var depth := length * 0.205
	var width := length * 0.12
	var ends := Vector2(-length * 0.5, length * 0.38)
	var profile := func(along: float) -> Vector3:
		var t := FishModel._taper(along, 0.36, 0.9, 0.15, 0.78)
		var belly_sag := 0.05 * sin(along * PI)  # the keel of the belly sits a little low
		# Flatter flanks than a round loft: narrower toward the back.
		var slim := lerpf(1.0, 0.8, smoothstep(0.3, 0.9, along))
		return Vector3(width * 0.5 * t * slim, depth * 0.5 * t, -depth * belly_sag * t)
	var skin := ShaderMaterial.new()
	skin.shader = SARDINE_SKIN
	m._skins.append(skin)
	m._body_material = m._material(Color(0.12, 0.3, 0.36), 0.3)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = m._loft_mesh(ends, profile, 40, 20)
	body.material_override = skin
	m.add_child(body)

	var fin_root := Color(0.7, 0.76, 0.8)
	var fin_edge := Color(0.82, 0.86, 0.9)
	var fins := m._fin_material(fin_root, fin_edge, 9.0, 0.006, 1.2, 0.35)
	# A small dorsal fin mid-back, and the ventral fins under it.
	var top := FishModel._loft_point(ends, profile, ends.x + length * 0.42, 1.0)
	var top_end := FishModel._loft_point(ends, profile, ends.x + length * 0.56, 1.0)
	m._membrane(m, fins, top - Vector3(0.0, 0.004, 0.0), top_end - Vector3(0.0, 0.004, 0.0), Vector3(0.0, 1.0, 0.45),
			[depth * 0.42, depth * 0.36, depth * 0.2, depth * 0.08], 0.0, 0.08)
	for side: float in [-1.0, 1.0]:
		var under := FishModel._loft_point(ends, profile, ends.x + length * 0.5, -0.92) * Vector3(side, 1.0, 1.0)
		m._membrane(m, fins, under, under + Vector3(0.0, 0.0, length * 0.06), Vector3(side * 0.4, -1.0, 0.6),
				[depth * 0.2, depth * 0.16, depth * 0.06], 0.0, 0.05)
	# Pectorals low behind the gills, on the swim animation's pivots.
	var pec := FishModel._loft_point(ends, profile, ends.x + length * 0.22, -0.5)
	m._fin_pivots(pec)
	for side: float in [-1.0, 1.0]:
		var pivot := m.fin_left if side < 0.0 else m.fin_right
		m._membrane(pivot, fins, Vector3.ZERO, Vector3(0.0, -depth * 0.05, length * 0.03), Vector3(side, -0.35, 0.8),
				[depth * 0.36, depth * 0.3, depth * 0.12], 0.25, 0.06)
	# The forked tail on the stalk.
	var stalk_z := ends.y - length * 0.02
	m._tail_pivot(Vector3(0.0, (profile.call(0.97) as Vector3).z, stalk_z))
	var tail_fin := m._fin_material(fin_root.darkened(0.08), fin_edge, 14.0, 0.008, 1.4, 0.4)
	m._membrane(m.tail, tail_fin, Vector3(0.0, depth * 0.1, 0.0), Vector3(0.0, -depth * 0.1, 0.0), Vector3.BACK,
			[depth * 0.85, depth * 0.62, depth * 0.3, depth * 0.62, depth * 0.85], -0.9, 0.04)
	m._bend_body(ends.x + length * 0.45)
	# A big dark eye.
	var eye_r := depth * 0.13
	var eye_at := FishModel._loft_point(ends, profile, ends.x + length * 0.085, 0.22)
	for side: float in [-1.0, 1.0]:
		var at := eye_at * Vector3(side, 1.0, 1.0) - Vector3(side * eye_r * 0.55, 0.0, 0.0)
		var eye := m._real_eye(at, eye_r, Vector3(side, 0.0, -0.12), Color(0.78, 0.74, 0.6), 0.55)
		(eye.material_override as ShaderMaterial).set_shader_parameter("rim_color", Color(0.55, 0.6, 0.62))


## The sea butterfly (Limacina): a glossy, see-through amber-brown shell
## coiled to the left, globe-shaped with a low spire (a log-spiral surface whose
## whorls overlap, so it's one seamless shell), a pale body in its mouth and two
## broad rounded wing-feet in a V over it. The swim poses beat the wings (on
## the tail pivot; `fluke`, so they tilt together).
static func _sea_butterfly(m: FishModel) -> void:
	var size := minf(m._size.x, m._size.z) * 0.55
	m.fluke = true
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(1.0, 1.0, 1.0, 0.82)
	shell.vertex_color_use_as_albedo = true
	shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.roughness = 0.12
	shell.metallic_specular = 0.9
	shell.rim_enabled = true
	shell.rim = 0.5
	shell.rim_tint = 0.6
	shell.subsurf_scatter_enabled = false
	m._body_material = shell
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _shell_mesh(size)
	body.material_override = shell
	m.add_child(body)
	# The soft body filling the shell's mouth (facing forward, -z), the wings
	# out of the top of it.
	var mouth := Vector3(-size * 0.42, -size * 0.1, -size * 0.04)
	var flesh := m._material(Color(0.98, 0.84, 0.66), 0.45)
	flesh.rim_enabled = true
	flesh.rim = 0.4
	var head := SphereMesh.new()
	head.radius = size * 0.36
	head.height = size * 0.72
	m._part(m, head, flesh, mouth + Vector3(0.0, 0.0, -size * 0.06), Vector3(0.95, 0.9, 0.8))
	m._fin_pivots(mouth)
	m._tail_pivot(mouth + Vector3(0.0, size * 0.3, -size * 0.04))
	var wing := m._fin_material(Color(0.88, 0.72, 0.52), Color(0.97, 0.9, 0.78), 0.0, 0.012, 1.6, 0.45)
	for side: float in [-1.0, 1.0]:
		m._membrane(m.tail, wing, Vector3(0.0, 0.0, -size * 0.2), Vector3(0.0, 0.0, size * 0.2), Vector3(side, 0.4, -0.1),
				[size * 0.45, size * 0.8, size * 0.9, size * 0.78, size * 0.42], 0.0, 0.02, 0.06)


## The shell: a log-spiral surface (the seashell equations). Each turn grows
## its whorl `growth` times; the whorls overlap, so it closes into one shell
## round a low spire, coiling to the left (sinistral); its mouth flares a
## little. Vertex colours paint it amber, darker toward the apex, with growth
## lines. Rest: its mouth toward -x, the spire up.
static func _shell_mesh(size: float) -> ArrayMesh:
	var turns := 3.4
	var growth := 2.6
	var b := log(growth) / TAU
	var rows := 150
	var around := 24
	var spiral := size * 0.42  # the mouth's whorl's distance from the axis
	var section := size * 0.4  # and its radius
	var drop := size * 0.3  # how far each whorl sits below the last (a low spire)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows + 1:
		var t := float(i) / rows
		var theta := -turns * TAU * (1.0 - t)  # the apex first, the mouth (theta 0) last
		var g := exp(b * theta)
		var flare := 1.0 + 0.12 * smoothstep(0.94, 1.0, t)
		var radial := Vector3(-cos(theta), 0.0, -sin(theta))  # sinistral: turning the other way
		var centre := radial * spiral * g + Vector3.UP * (drop * (1.0 - g) - size * 0.1)
		var r := section * g * flare
		var lines := 0.85 + 0.15 * sin(theta * 9.0)
		var amber := Color(0.46, 0.26, 0.12).lerp(Color(0.24, 0.12, 0.08), 1.0 - t) * lines
		for k in around + 1:
			var phi := TAU * k / around
			var normal := (radial * cos(phi) + Vector3.UP * sin(phi)).normalized()
			tool.set_color(Color(amber.r, amber.g, amber.b, 1.0))
			tool.set_normal(normal)
			tool.set_uv(Vector2(t, float(k) / around))
			tool.add_vertex(centre + normal * r)
	for i in rows:
		for k in around:
			var a := i * (around + 1) + k
			var c := a + around + 1
			for corner: int in [a, c, a + 1, a + 1, c, c + 1]:
				tool.add_index(corner)
	return tool.commit()
