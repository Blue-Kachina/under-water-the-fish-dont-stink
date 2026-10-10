class_name AquariumArena
extends Node3D
## Sandbox match arena: a big rounded tank with a goal recessed into each end
## wall at floor level and a bubble ball. Long axis is Z. The fish plays for
## Blue, starts at the +Z end and attacks the Orange goal at -Z.

signal goal_scored(team: int)

const SIZE := Vector3(90.0, 50.0, 130.0)  # floor at y = 0, centred on x/z
const CORNER_RADIUS := 12.0
const CORNER_STEPS := 8  # segments per rounded edge
## Goal mouth width x height, standing on the floor. Taller than CORNER_RADIUS so
## its top edge is on the flat part of the end wall.
const GOAL_SIZE := Vector2(28.0, 16.0)
const GOAL_DEPTH := 12.0
const GRID_SHADER := preload("res://shaders/grid.gdshader")

const TEAM_NAMES := ["Blue", "Orange"]
const TEAM_COLORS := [Color(0.25, 0.55, 1.0), Color(1.0, 0.5, 0.1)]
const COLOR_GLASS := Color(0.12, 0.28, 0.34)
const COLOR_SAND := Color(0.45, 0.4, 0.3)

@export var fish: FishController
@export var ball_settings: BallSettings

var ball: Ball
var goals: Array[Goal] = []
var scores := [0, 0]
var centre := Vector3(0.0, SIZE.y / 2.0, 0.0)
## Seconds until the ball returns after a goal.
var respawn_time_left := 0.0

var _pop := CPUParticles3D.new()


func _ready() -> void:
	_build_shell()
	_build_goals()
	_build_specks()
	_build_pop()
	ball = Ball.new()
	ball.name = "Ball"
	ball.settings = ball_settings
	ball.fish = fish
	ball.position = ball_spawn()
	add_child(ball)


func _physics_process(delta: float) -> void:
	if ball.popped:
		respawn_time_left -= delta
		if respawn_time_left <= 0.0:
			ball.respawn(ball_spawn())
		return
	for goal in goals:
		if goal.contains_ball(ball.global_position, ball.settings.radius):
			_score(goal)
			return


## Kickoff spot: a Water ball floats mid-tank; a Surface ball rests on the floor, as in RL.
func ball_spawn() -> Vector3:
	if ball_settings.ball_type == BallSettings.BallType.SURFACE:
		return Vector3(0.0, ball_settings.radius, 0.0)
	return centre


## Facing the ball from the +Z end, level with where it spawns.
func spawn_transform() -> Transform3D:
	var height := maxf(ball_spawn().y, 1.0)
	return Transform3D(Basis.IDENTITY, Vector3(0.0, height, SIZE.z / 2.0 - 25.0))


func configure_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.1, 0.16)
	env.sky = null


## Ball back to its kickoff spot. Scores are kept.
func reset_kickoff() -> void:
	respawn_time_left = 0.0
	ball.respawn(ball_spawn())


func _score(goal: Goal) -> void:
	var scorer := 1 - goal.team
	scores[scorer] += 1
	_pop.global_position = ball.global_position
	_pop.emission_sphere_radius = ball.settings.radius
	_pop.restart()
	ball.pop()
	respawn_time_left = ball.settings.goal_reset_delay
	goal_scored.emit(scorer)


## The tank's inside surface as one mesh (sand floor + glass walls) and one
## matching trimesh collider. Each cube face is gridded so its flat middle is a
## few big quads and its edges bend round onto the neighbouring face. At each
## goal the rounded floor-to-wall edge is notched out so the floor runs flat
## into the goal mouth, with flat cheeks closing the sides of the notch.
## Works in tank-centred coordinates; _append_triangle moves into place.
func _build_shell() -> void:
	var half := SIZE / 2.0
	var floor_tris := [[], []]  # vertices, normals
	var wall_tris := [[], []]
	var mouth_x := GOAL_SIZE.x / 2.0
	var mouth_top := GOAL_SIZE.y - half.y

	# Grid coordinates along each axis, per face axis; goal edges get their own lines.
	var xs := _face_coords(half.x, [-mouth_x, mouth_x])
	var ys := _face_coords(half.y, [mouth_top])
	var zs := _face_coords(half.z, [])
	var coords := [xs, ys, zs]

	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var us: PackedFloat32Array = coords[u]
		var vs: PackedFloat32Array = coords[v]
		for side: float in [-1.0, 1.0]:
			var target: Array = floor_tris if axis == 1 and side < 0.0 else wall_tris
			for i in us.size() - 1:
				for j in vs.size() - 1:
					var corners: Array[Vector3] = []
					for c: Vector2 in [Vector2(us[i], vs[j]), Vector2(us[i + 1], vs[j]), Vector2(us[i + 1], vs[j + 1]), Vector2(us[i], vs[j + 1])]:
						var p := Vector3.ZERO
						p[axis] = side * half[axis]
						p[u] = c.x
						p[v] = c.y
						corners.append(p)
					var middle := _round(corners[0].lerp(corners[2], 0.5))
					if absf(middle.x) < mouth_x and middle.y < mouth_top and absf(middle.z) > half.z - CORNER_RADIUS + 0.001:
						continue  # inside a goal mouth or its notch
					_add_rounded_triangle(target, corners[0], corners[1], corners[2])
					_add_rounded_triangle(target, corners[0], corners[2], corners[3])

	for end: float in [-1.0, 1.0]:
		# Flat floor across the notch, up to the goal line.
		var near := end * (half.z - CORNER_RADIUS)
		var line := end * half.z
		var a := Vector3(-mouth_x, -half.y, near)
		var b := Vector3(mouth_x, -half.y, near)
		var c := Vector3(mouth_x, -half.y, line)
		var d := Vector3(-mouth_x, -half.y, line)
		_add_flat_triangle(floor_tris, a, b, c, Vector3.UP)
		_add_flat_triangle(floor_tris, a, c, d, Vector3.UP)
		# Cheeks: fans from the foot of each goal post to the cut edge of the
		# rounded band, through the band's own grid points so there are no gaps.
		for x: float in [-mouth_x, mouth_x]:
			# Floor edge -> 45 degrees -> wall edge.
			var arc: Array[Vector3] = []
			for z in zs:
				if absf(z) >= half.z - CORNER_RADIUS and signf(z) == end:
					arc.append(_round(Vector3(x, -half.y, z)))
			if end < 0.0:
				arc.reverse()
			for y in ys:
				if y <= -half.y + CORNER_RADIUS:
					arc.append(_round(Vector3(x, y, line)))
			var foot := Vector3(x, -half.y, line)
			var inward := Vector3(-signf(x), 0.0, 0.0)
			for k in arc.size() - 1:
				if arc[k].distance_to(arc[k + 1]) > 0.001:
					_add_flat_triangle(wall_tris, foot, arc[k], arc[k + 1], inward)

	var mesh := ArrayMesh.new()
	for part: Array in [floor_tris, wall_tris]:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(part[0])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(part[1])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _grid_material(COLOR_SAND))
	mesh.surface_set_material(1, _grid_material(COLOR_GLASS))

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(PackedVector3Array(floor_tris[0] + wall_tris[0]))

	var body := StaticBody3D.new()
	body.name = "Shell"
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	# Let the sun in from above like a glass tank; only the fish casts shadows.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)
	add_child(body)


## Grid line positions across one face, from -half to half: CORNER_STEPS steps
## through each rounded band (spaced so the bend is even), the flat middle,
## and any extra cuts, which must lie within the flat middle.
func _face_coords(half: float, cuts: Array) -> PackedFloat32Array:
	var flat := half - CORNER_RADIUS
	var coords := PackedFloat32Array()
	for k in range(CORNER_STEPS, 0, -1):
		coords.append(-flat - CORNER_RADIUS * tan(PI / 4.0 * k / CORNER_STEPS))
	coords.append(-flat)
	var sorted_cuts := cuts.duplicate()
	sorted_cuts.sort()
	for cut: float in sorted_cuts:
		assert(absf(cut) < flat, "shell cut %.1f is outside the flat part of the face" % cut)
		coords.append(cut)
	coords.append(flat)
	for k in range(1, CORNER_STEPS + 1):
		coords.append(flat + CORNER_RADIUS * tan(PI / 4.0 * k / CORNER_STEPS))
	return coords


## A point on the unrounded box pulled onto the rounded surface.
func _round(p: Vector3) -> Vector3:
	var limit := SIZE / 2.0 - Vector3.ONE * CORNER_RADIUS
	var core := p.clamp(-limit, limit)
	return core + (p - core).normalized() * CORNER_RADIUS


## Adds one triangle from three points on the unrounded box, pulled onto the
## rounded surface with smooth normals facing into the tank.
func _add_rounded_triangle(target: Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var limit := SIZE / 2.0 - Vector3.ONE * CORNER_RADIUS
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for p in [a, b, c]:
		var core: Vector3 = p.clamp(-limit, limit)
		var outward: Vector3 = (p - core).normalized()
		points.append(core + outward * CORNER_RADIUS)
		normals.append(-outward)
	_append_triangle(target, points, normals)


## Adds one flat triangle facing `normal`.
func _add_flat_triangle(target: Array, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var points: Array[Vector3] = [a, b, c]
	var normals: Array[Vector3] = [normal, normal, normal]
	_append_triangle(target, points, normals)


func _append_triangle(target: Array, points: Array[Vector3], normals: Array[Vector3]) -> void:
	# Godot treats clockwise triangles as front faces.
	var facing := normals[0] + normals[1] + normals[2]
	if (points[1] - points[0]).cross(points[2] - points[0]).dot(facing) > 0.0:
		var swap_point := points[1]
		points[1] = points[2]
		points[2] = swap_point
		var swap_normal := normals[1]
		normals[1] = normals[2]
		normals[2] = swap_normal
	for i in 3:
		target[0].append(centre + points[i])
		target[1].append(normals[i])


func _build_goals() -> void:
	for team in 2:
		var goal := Goal.new()
		goal.team = team
		goal.color = TEAM_COLORS[team]
		goal.width = GOAL_SIZE.x
		goal.height = GOAL_SIZE.y
		goal.depth = GOAL_DEPTH
		goal.bottom_post = false  # the floor runs straight in
		# Blue defends +Z, Orange -Z; each goal's +Z points out through its wall.
		var out := 1.0 if team == 0 else -1.0
		var mouth := Vector3(0.0, GOAL_SIZE.y / 2.0, out * SIZE.z / 2.0)
		goal.transform = Transform3D(Basis(Vector3.UP, 0.0 if team == 0 else PI), mouth)
		goal.name = "%sGoal" % TEAM_NAMES[team]
		add_child(goal)
		goals.append(goal)


func _build_specks() -> void:
	var speck := SphereMesh.new()
	speck.radius = 0.05
	speck.height = 0.1
	speck.radial_segments = 6
	speck.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.7, 0.9, 1.0)
	speck.material = material

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var half := SIZE / 2.0
	var limit := half - Vector3.ONE * CORNER_RADIUS
	var positions: Array[Vector3] = []
	while positions.size() < 3000:
		var p := Vector3(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y), rng.randf_range(-half.z, half.z))
		if (p - p.clamp(-limit, limit)).length() < CORNER_RADIUS - 0.5:  # inside the rounded tank
			positions.append(centre + p)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = speck
	multimesh.instance_count = positions.size()
	for i in positions.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## Burst of bubbles where the ball pops after a goal.
func _build_pop() -> void:
	var bubble := SphereMesh.new()
	bubble.radius = 0.12
	bubble.height = 0.24
	bubble.radial_segments = 8
	bubble.rings = 4
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.85, 0.97, 1.0, 0.6)
	bubble.material = material

	_pop.mesh = bubble
	_pop.emitting = false
	_pop.one_shot = true
	_pop.explosiveness = 1.0
	_pop.amount = 120
	_pop.lifetime = 2.0
	_pop.local_coords = false
	_pop.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_pop.direction = Vector3.UP
	_pop.spread = 180.0
	_pop.gravity = Vector3(0, 3.0, 0)
	_pop.initial_velocity_min = 4.0
	_pop.initial_velocity_max = 12.0
	_pop.damping_min = 4.0
	_pop.damping_max = 8.0
	_pop.scale_amount_min = 0.4
	_pop.scale_amount_max = 2.0
	add_child(_pop)


func _grid_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GRID_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("line_color", color.lightened(0.35))
	return material
