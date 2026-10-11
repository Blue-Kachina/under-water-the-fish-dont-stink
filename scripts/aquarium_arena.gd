class_name AquariumArena
extends Node3D
## Sandbox match arena: a tank the size and shape of Rocket League's standard
## (Soccar) arena, with a goal recessed into each end wall at floor level and a
## bubble ball. Long axis is Z. The fish plays for Blue, starts at the +Z end
## and attacks the Orange goal at -Z.
##
## Dimensions are RL's, 1 uu = 1 cm, measured from the game's own Soccar
## collision meshes (tools/rocketsim_compare): an octagonal floor with the four
## vertical corners cut at 45 degrees and wide rounded joins into the walls,
## a 2.56 m ramp up from the floor and a 5.12 m curve onto the ceiling.

signal goal_scored(team: int)

const SIZE := Vector3(81.92, 20.48, 102.4)  # floor at y = 0, centred on x/z
## The vertical corners are cut at 45 degrees: the tank is inside |x| + |z| <= CORNER_PLANE.
const CORNER_PLANE := 80.64
## Radius of the ramp from the floor up the walls (RL: 256 uu).
const EDGE_RADIUS := 2.56
## Radius of the curve from the walls onto the ceiling (RL: 512 uu).
const CEILING_RADIUS := 5.12
## Radius of the joins between the 45-degree corners and the walls (RL: about 880 uu).
const CORNER_JOIN_RADIUS := 8.8
const EDGE_STEPS := 6  # segments per rounded floor/ceiling edge
const JOIN_STEPS := 6  # segments per rounded wall-to-wall join
## Goal mouth width x height, standing on the floor (RL: 1792 x 640 uu). Taller
## than EDGE_RADIUS so its top edge is on the flat part of the end wall.
const GOAL_SIZE := Vector2(17.92, 6.40)
const GOAL_DEPTH := 8.8
## RL's kickoff spot furthest back, the fish's start.
const KICKOFF_DISTANCE := 46.08
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
## Off: goals don't score (tests that roll the ball into a net).
var scoring_enabled := true

var _pop := CPUParticles3D.new()


func _ready() -> void:
	_build_goals()
	_build_shell()  # after the goals: their nets join the shell's collision mesh
	_build_specks()
	_build_pop()
	ball = Ball.new()
	ball.name = "Ball"
	ball.settings = ball_settings
	ball.fish = fish
	ball.position = ball_spawn()
	add_child(ball)
	ball.respawn(ball_spawn(), true)  # the opening kickoff


func _physics_process(delta: float) -> void:
	if ball.popped:
		respawn_time_left -= delta
		if respawn_time_left <= 0.0:
			ball.respawn(ball_spawn(), true)
		return
	if ball.respawn_pending or not scoring_enabled:
		return  # still at its old spot until the teleport lands; don't score it again
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
	return Transform3D(Basis.IDENTITY, Vector3(0.0, height, KICKOFF_DISTANCE))


func configure_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.1, 0.16)
	env.sky = null


## Ball back to its kickoff spot. Scores are kept.
func reset_kickoff() -> void:
	respawn_time_left = 0.0
	ball.respawn(ball_spawn(), true)


func _score(goal: Goal) -> void:
	var scorer := 1 - goal.team
	scores[scorer] += 1
	_pop.global_position = ball.global_position
	_pop.emission_sphere_radius = ball.settings.radius
	_pop.restart()
	ball.pop()
	respawn_time_left = ball.settings.goal_reset_delay
	goal_scored.emit(scorer)


## The tank's inside surface as one mesh (sand floor + glass walls and ceiling)
## and one matching trimesh collider. The walls are swept round the wall line
## (the octagon with rounded corner joins) along a profile that curves up from
## the floor, runs up the wall and curves onto the ceiling. At each goal the
## floor ramp is notched out so the floor runs flat into the goal mouth, with
## flat cheeks closing the sides of the notch.
func _build_shell() -> void:
	var floor_tris := [[], []]  # vertices, normals
	var wall_tris := [[], []]
	var half := SIZE / 2.0
	var mouth_x := GOAL_SIZE.x / 2.0
	var ring := _footprint_ring([-mouth_x, 0.0, mouth_x])  # 0: matches the notch floor's middle vertex
	var profile := _wall_profile([GOAL_SIZE.y])

	for i in ring.size() - 1:
		var a: Dictionary = ring[i]
		var b: Dictionary = ring[i + 1]
		var on_end_wall: bool = absf(a.normal.y) > 0.999 and a.normal == b.normal
		for j in profile.size() - 1:
			var lo := profile[j]
			var hi := profile[j + 1]
			if on_end_wall and absf((a.point.x + b.point.x) / 2.0) < mouth_x and (lo.y + hi.y) / 2.0 < GOAL_SIZE.y:
				continue  # inside a goal mouth or its notch
			var corners: Array[Vector3] = [_swept(a, lo), _swept(b, lo), _swept(b, hi), _swept(a, hi)]
			var normals: Array[Vector3] = [_swept_normal(a, lo), _swept_normal(b, lo), _swept_normal(b, hi), _swept_normal(a, hi)]
			_append_triangle(wall_tris, [corners[0], corners[1], corners[2]], [normals[0], normals[1], normals[2]])
			_append_triangle(wall_tris, [corners[0], corners[2], corners[3]], [normals[0], normals[2], normals[3]])

	# Floor and ceiling: fans across the wall line pulled in by each edge's
	# radius, meeting the swept edges.
	for i in ring.size() - 1:
		var floor_a := _swept(ring[i], profile[0])
		var floor_b := _swept(ring[i + 1], profile[0])
		var ceiling_a := _swept(ring[i], profile[-1])
		var ceiling_b := _swept(ring[i + 1], profile[-1])
		_add_flat_triangle(floor_tris, Vector3.ZERO, floor_a, floor_b, Vector3.UP)
		_add_flat_triangle(wall_tris, Vector3(0.0, SIZE.y, 0.0), ceiling_a, ceiling_b, Vector3.DOWN)

	for end: float in [-1.0, 1.0]:
		# Flat floor across the notch, up to the goal line, in two halves so its
		# goal-line vertices match the net floor's (which fans from the middle).
		var near := end * (half.z - EDGE_RADIUS)
		var line := end * half.z
		for side: Array in [[-mouth_x, 0.0], [0.0, mouth_x]]:
			var a := Vector3(side[0], 0.0, near)
			var b := Vector3(side[1], 0.0, near)
			var c := Vector3(side[1], 0.0, line)
			var d := Vector3(side[0], 0.0, line)
			_add_flat_triangle(floor_tris, a, b, c, Vector3.UP)
			_add_flat_triangle(floor_tris, a, c, d, Vector3.UP)
		# Cheeks: fans from the foot of each goal post to the cut edge of the ramp.
		for x: float in [-mouth_x, mouth_x]:
			var edge := {"point": Vector2(x, line), "normal": Vector2(0.0, end)}
			var foot := Vector3(x, 0.0, line)
			var inward := Vector3(-signf(x), 0.0, 0.0)
			for k in EDGE_STEPS:
				_add_flat_triangle(wall_tris, foot, _swept(edge, profile[k]), _swept(edge, profile[k + 1]), inward)

	var mesh := ArrayMesh.new()
	for part: Array in [floor_tris, wall_tris]:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(part[0])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(part[1])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _grid_material(COLOR_SAND))
	mesh.surface_set_material(1, _grid_material(COLOR_GLASS))

	var faces := PackedVector3Array(floor_tris[0] + wall_tris[0])
	for goal in goals:
		for vertex in goal.net_faces:
			faces.append(goal.transform * vertex)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)

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


## The wall line (where the straight walls stand), walked once round as
## {point: Vector2 (x, z), normal: Vector2 (outward)}, closed by repeating the
## first entry: the octagon, with each 45-degree corner turned on an arc of
## CORNER_JOIN_RADIUS. End walls get extra points at `end_wall_cuts` (x).
func _footprint_ring(end_wall_cuts: Array) -> Array[Dictionary]:
	var a := SIZE.x / 2.0
	var b := SIZE.z / 2.0
	var c := CORNER_PLANE
	var vertices: Array[Vector2] = [Vector2(a, a - c), Vector2(a, c - a), Vector2(c - b, b), Vector2(b - c, b),
			Vector2(-a, c - a), Vector2(-a, a - c), Vector2(b - c, -b), Vector2(c - b, -b)]
	var ring: Array[Dictionary] = []
	for i in vertices.size():
		var v := vertices[i]
		var next := vertices[(i + 1) % vertices.size()]
		var before := (v - vertices[i - 1]).orthogonal().normalized()  # outward normal of the edge into v
		var after := (next - v).orthogonal().normalized()  # and of the edge out of v
		# The arc touching both edges: centre inside along the bisector.
		var half_turn_cos := sqrt((1.0 + before.dot(after)) / 2.0)
		var centre := v - (before + after).normalized() * (CORNER_JOIN_RADIUS / half_turn_cos)
		for k in JOIN_STEPS + 1:
			var normal := Vector2.from_angle(lerp_angle(before.angle(), after.angle(), float(k) / JOIN_STEPS))
			ring.append({"point": centre + normal * CORNER_JOIN_RADIUS, "normal": normal})
		if is_equal_approx(absf(v.y), b) and is_equal_approx(absf(next.y), b):  # an end wall
			var cuts := end_wall_cuts.duplicate()
			cuts.sort()
			if next.x < v.x:
				cuts.reverse()
			var flat_end: float = absf(v.x) - CORNER_JOIN_RADIUS * tan(PI / 8.0)
			for x: float in cuts:
				assert(absf(x) < flat_end, "end wall cut %.1f is outside the flat part of the wall" % x)
				ring.append({"point": Vector2(x, v.y), "normal": after})
	ring.append(ring[0])
	return ring


## The wall's cross-section from the floor to the ceiling, as Vector4(outward
## offset from the wall line (0 on the wall, negative inside), height, outward
## normal's horizontal and vertical parts): a quarter circle of EDGE_RADIUS up
## from the floor, the straight wall (with extra points at the `wall_cuts`
## heights) and a quarter circle of CEILING_RADIUS onto the ceiling.
func _wall_profile(wall_cuts: Array) -> Array[Vector4]:
	var r := EDGE_RADIUS
	var rc := CEILING_RADIUS
	var top := SIZE.y - rc
	var profile: Array[Vector4] = []
	for k in EDGE_STEPS + 1:
		var angle := -PI / 2.0 + PI / 2.0 * k / EDGE_STEPS
		profile.append(Vector4(r * cos(angle) - r, r + r * sin(angle), cos(angle), sin(angle)))
	for height: float in wall_cuts:
		assert(height > r and height < top, "wall cut %.1f is outside the flat part of the wall" % height)
		profile.append(Vector4(0.0, height, 1.0, 0.0))
	for k in EDGE_STEPS + 1:
		var angle := PI / 2.0 * k / EDGE_STEPS
		profile.append(Vector4(rc * cos(angle) - rc, top + rc * sin(angle), cos(angle), sin(angle)))
	return profile


## A point on the swept surface: footprint entry `edge` pushed out along a profile entry.
func _swept(edge: Dictionary, profile: Vector4) -> Vector3:
	var p: Vector2 = edge.point + edge.normal * profile.x
	return Vector3(p.x, profile.y, p.y)


## The swept surface's normal there, facing into the tank.
func _swept_normal(edge: Dictionary, profile: Vector4) -> Vector3:
	var n: Vector2 = edge.normal * profile.z
	return -Vector3(n.x, profile.w, n.y)


## Roughly how far `p` is outside the tank's inner surface (negative inside),
## ignoring the goals. Exact along the flat walls and the floor/ceiling
## curves; near the rounded corner joins it treats them as sharp (so it can
## under-report there).
static func distance_outside(p: Vector3) -> float:
	var r := EDGE_RADIUS if p.y < SIZE.y / 2.0 else CEILING_RADIUS
	var across := maxf(maxf(absf(p.x) - (SIZE.x / 2.0 - r), absf(p.z) - (SIZE.z / 2.0 - r)),
			(absf(p.x) + absf(p.z) - (CORNER_PLANE - r * sqrt(2.0))) / sqrt(2.0))
	var up := (r - p.y) if p.y < SIZE.y / 2.0 else (p.y - (SIZE.y - r))
	if across <= 0.0 and up <= 0.0:
		return maxf(across, up) - r
	return Vector2(maxf(across, 0.0), maxf(up, 0.0)).length() - r


## Adds one flat triangle facing `normal`.
func _add_flat_triangle(target: Array, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	_append_triangle(target, [a, b, c], [normal, normal, normal])


func _append_triangle(target: Array, points: Array, normals: Array) -> void:
	var cross: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
	if cross.length_squared() < 1e-10:
		return  # degenerate, e.g. where a rounded join meets the floor
	# Godot treats clockwise triangles as front faces.
	var facing: Vector3 = normals[0] + normals[1] + normals[2]
	if cross.dot(facing) > 0.0:
		var swap_point: Vector3 = points[1]
		points[1] = points[2]
		points[2] = swap_point
		var swap_normal: Vector3 = normals[1]
		normals[1] = normals[2]
		normals[2] = swap_normal
	for i in 3:
		target[0].append(points[i])
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
		goal.own_collision = false  # merged into the shell (see _build_shell)
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
	var positions: Array[Vector3] = []
	while positions.size() < 1200:
		var p := Vector3(rng.randf_range(-half.x, half.x), rng.randf_range(0.0, SIZE.y), rng.randf_range(-half.z, half.z))
		if distance_outside(p) < -0.5:  # inside the tank
			positions.append(p)

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
