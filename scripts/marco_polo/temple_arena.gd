class_name TempleArena
extends MarcoArena
## The Sunken Temple (planning_marco_polo.md §12): a walled sanctuary about
## 90 x 70 m and 30 m deep, on a floor of cracked marble slabs with sand drifts.
## - The walls are ashlar courses up to a broken roof of stone beams; shafts of
##   light come down through its gaps. The portholes are arched windows set in
##   them, some with a statue on its plinth beside.
## - North: the temple front, a colonnade on a stepped stylobate, part of its
##   pediment still up and the rest fallen, a ruined cella behind it.
## - The middle: a round tholos on its steps, columns standing, broken and
##   fallen, a statue of Poseidon inside.
## - An altar with a bronze brazier before the temple, toppled statues, rows of
##   amphorae and kraters along the walls, a broken flight of steps in a corner,
##   kelp in the corners.
## Everything has collision and most of it is low enough to settle behind.
## No sound masking here. The seeker starts at the south end.

## GreekKit's pieces are life-size; the temple's are this much bigger.
const SCALE := 2.0
## The tholos's columns, a little smaller.
const THOLOS_SCALE := 1.6
## The walls' courses (m): each course's height, a block's length, the wall's thickness.
const COURSE := 1.8
const BLOCK_LEN := 4.0
const WALL_THICK := 2.4
## A porthole's surround (a holed slab): its width; it's two courses tall.
const SLAB_WIDTH := 3.6
const HOLE_RADIUS := 0.8
## Ashlar variants (one MultiMesh each).
const VARIANTS := 4

## Each wall: the middle of its inner face on the floor, the way into the
## arena, and its length.
const WALLS := [
	[Vector3(0.0, 0.0, -35.0), Vector3(0.0, 0.0, 1.0), 90.0],
	[Vector3(0.0, 0.0, 35.0), Vector3(0.0, 0.0, -1.0), 90.0],
	[Vector3(45.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0), 70.0],
	[Vector3(-45.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), 70.0],
]
## The portholes' middles (on a wall's inner face, at a course joint) and
## which of them has a statue beside it: [position, statue god or ""].
const PORTHOLES := [
	[Vector3(-8.0, 3.6, -35.0), ""],
	[Vector3(9.0, 7.2, -35.0), "aphrodite"],
	[Vector3(45.0, 3.6, -14.0), "hades"],
	[Vector3(45.0, 9.0, 12.0), ""],
	[Vector3(-45.0, 5.4, -20.0), ""],
	[Vector3(-45.0, 3.6, 6.0), "tyche"],
	[Vector3(-30.0, 3.6, 35.0), ""],
	[Vector3(30.0, 7.2, 35.0), "poseidon"],
]

var _blocks: Array = []  # per variant: Array[Transform3D]
var _dice := RandomNumberGenerator.new()


func _init() -> void:
	size = Vector3(90.0, 30.0, 70.0)
	murk_density = 0.05
	murk_color = Color(0.05, 0.19, 0.19)
	background_color = Color(0.03, 0.12, 0.13)
	ambient_color = Color(0.32, 0.5, 0.46)
	ambient_energy = 0.6


func _build() -> void:
	_dice.seed = 1907
	for n in VARIANTS:
		var list: Array[Transform3D] = []
		_blocks.append(list)
	add_shell_colliders()
	_build_floor()
	_build_walls()
	_build_roof()
	_build_temple_front()
	_build_tholos()
	_build_altar()
	_build_statues()
	_build_pottery()
	_build_steps()
	_build_kelp()
	_flush_blocks()
	_place_markers()


# --- Walls and floor -------------------------------------------------------------------

func _build_walls() -> void:
	var holes_by_wall := {}
	for entry: Array in PORTHOLES:
		var at: Vector3 = entry[0]
		for w in WALLS.size():
			var wall: Array = WALLS[w]
			var inward: Vector3 = wall[1]
			if absf((at - (wall[0] as Vector3)).dot(inward)) < 0.01:
				if not holes_by_wall.has(w):
					holes_by_wall[w] = []
				holes_by_wall[w].append(entry)
	for w in WALLS.size():
		var wall: Array = WALLS[w]
		var origin: Vector3 = wall[0]
		var inward: Vector3 = wall[1]
		var length: float = wall[2]
		var along := Vector3.UP.cross(inward)
		var reach := length * 0.5 + (WALL_THICK if absf(inward.z) > 0.5 else 0.0)  # the long walls cover the corners
		var holes: Array = holes_by_wall.get(w, [])
		var courses := ceili(size.y / COURSE)
		for c in courses:
			var y := c * COURSE
			# Cut out each porthole's slab from the two courses it spans.
			var cuts: Array[Vector2] = []
			for entry: Array in holes:
				var at: Vector3 = entry[0]
				if y > at.y - COURSE - 0.01 and y < at.y + COURSE - 0.01:
					var x := (at - origin).dot(along)
					cuts.append(Vector2(x - SLAB_WIDTH * 0.5, x + SLAB_WIDTH * 0.5))
			var start := -reach - fposmod(c, 2) * BLOCK_LEN * 0.5
			var a := start
			while a < reach:
				var b := minf(a + BLOCK_LEN * _dice.randf_range(0.8, 1.15), reach)
				for piece in _subtract(Vector2(maxf(a, -reach), b), cuts):
					if piece.y - piece.x > 0.3:
						_wall_block(origin, inward, along, piece, y)
				a = b
		for entry: Array in holes:
			_porthole_slab(origin, inward, along, entry)


## `span` without `cuts` (all along one line): the pieces left.
func _subtract(span: Vector2, cuts: Array[Vector2]) -> Array[Vector2]:
	var pieces: Array[Vector2] = [span]
	for cut in cuts:
		var next: Array[Vector2] = []
		for p in pieces:
			if cut.y <= p.x or cut.x >= p.y:
				next.append(p)
				continue
			if cut.x > p.x:
				next.append(Vector2(p.x, cut.x))
			if cut.y < p.y:
				next.append(Vector2(cut.y, p.y))
		pieces = next
	return pieces


func _wall_block(origin: Vector3, inward: Vector3, along: Vector3, span: Vector2, y: float) -> void:
	var length := span.y - span.x - 0.06
	var tall := COURSE - 0.05
	var proud := _dice.randf_range(-0.12, 0.05)
	var centre := origin + along * (span.x + span.y) * 0.5 + Vector3.UP * y - inward * (WALL_THICK * 0.5 + proud)
	var basis := Basis(along, Vector3.UP, inward).scaled_local(Vector3(length, tall, WALL_THICK))
	_blocks[_dice.randi() % VARIANTS].append(Transform3D(basis, centre))


func _porthole_slab(origin: Vector3, inward: Vector3, along: Vector3, entry: Array) -> void:
	var at: Vector3 = entry[0]
	var x := (at - origin).dot(along)
	var base := origin + along * x + Vector3.UP * (at.y - COURSE) - inward * WALL_THICK * 0.5
	var slab := GreekKit.cached("temple/slab", func() -> MeshKit:
		return TempleKit.holed_slab(SLAB_WIDTH - 0.06, COURSE * 2.0 - 0.05, WALL_THICK, HOLE_RADIUS * 1.08, 31), TempleKit.wall_stone())
	add_visual(slab, Transform3D(Basis(along, Vector3.UP, inward), base), null, true)
	add_porthole(at, inward, HOLE_RADIUS, Porthole.Look.NICHE, GreekKit.marble())
	var god: String = entry[1]
	if god != "":
		var beside := at + inward * 1.4 + along * (SLAB_WIDTH * 0.5 + 1.2)
		beside.y = 0.0
		_statue_on_plinth(god, beside, inward, 1.5)


func _build_floor() -> void:
	var slab := 4.5
	var nx := ceili(size.x / slab)
	var nz := ceili(size.z / slab)
	var flat: Array[Transform3D] = []
	for i in nx:
		for k in nz:
			var at := Vector3(-size.x * 0.5 + (i + 0.5) * slab, -0.3, -size.z * 0.5 + (k + 0.5) * slab)
			var roll := _dice.randf()
			if roll < 0.05:
				continue  # a slab gone: sand shows
			var basis := Basis()
			var lift := 0.0
			if roll < 0.13:
				# Cracked and heaved up at one edge.
				basis = Basis(Vector3.UP, _dice.randf() * TAU) * Basis(Vector3.RIGHT, _dice.randf_range(0.06, 0.14))
				lift = 0.2
				add_box_collider(Transform3D(basis, at + Vector3.UP * (0.15 + lift)), Vector3(slab - 0.2, 0.3, slab - 0.2))
			flat.append(Transform3D(basis.scaled_local(Vector3(slab - 0.08, 0.32, slab - 0.08)), at + Vector3.UP * lift))
	var unit := GreekKit.cached("temple/floor_slab", func() -> MeshKit: return TempleKit.ashlar(Vector3.ONE, 77), GreekKit.marble())
	add_multimesh(unit, flat)
	# Sand under it all, and drifts against the walls and in the corners.
	var sand := PlaneMesh.new()
	sand.size = Vector2(size.x + 6.0, size.z + 6.0)
	add_visual(sand, Transform3D(Basis(), Vector3(0.0, -0.25, 0.0)), TempleKit.sand())
	var drifts := [[Vector3(-38.0, 0.0, -30.0), 7.0, 0.8, 1.4], [Vector3(38.0, 0.0, 30.0), 6.5, 0.7, 1.6], [Vector3(40.0, 0.0, -28.0), 5.0, 0.6, 1.2],
			[Vector3(-40.0, 0.0, 22.0), 6.0, 0.7, 2.0], [Vector3(-10.0, 0.0, 32.0), 5.0, 0.5, 2.6], [Vector3(20.0, 0.0, -33.0), 4.5, 0.45, 2.2],
			[Vector3(42.0, 0.0, 4.0), 4.0, 0.5, 0.6], [Vector3(-14.0, 0.0, 10.0), 3.5, 0.35, 1.5]]
	for n in drifts.size():
		var d: Array = drifts[n]
		var mesh := GreekKit.cached("temple/drift/%d" % n, func() -> MeshKit: return TempleKit.mound(d[1], d[2], d[3], 400 + n), TempleKit.sand())
		add_visual(mesh, Transform3D(Basis(Vector3.UP, _dice.randf_range(-0.3, 0.3)), d[0]))


## Stone beams across the top, some fallen in, light coming down the gaps.
func _build_roof() -> void:
	var spacing := 5.0
	var count := floori(size.z / spacing)
	var shaft_material := _shaft_material()
	for n in count + 1:
		var z := -size.z * 0.5 + n * spacing
		if n in [3, 4, 8, 11]:
			# A gap: a shaft of light comes down it, leaning with the sun.
			var shaft := BoxMesh.new()
			shaft.size = Vector3(1.0, 1.0, 1.0)
			for k in 3:
				var x := -26.0 + k * 24.0 + _dice.randf_range(-6.0, 6.0)
				var lean := Basis(Vector3.BACK, 0.18) * Basis(Vector3.RIGHT, 0.08)
				var xform := Transform3D((lean).scaled_local(Vector3(_dice.randf_range(2.5, 4.5), size.y * 1.05, spacing * 0.7)),
						Vector3(x, size.y * 0.5, z))
				add_visual(shaft, xform, shaft_material)
			continue
		for k in 6:
			var x := -size.x * 0.5 + (k + 0.5) * size.x / 6.0
			var basis := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK).scaled_local(Vector3(size.x / 6.0 - 0.1, 1.3, spacing - 0.15))
			_blocks[(n + k) % VARIANTS].append(Transform3D(basis, Vector3(x, size.y - 0.1, z)))


func _shaft_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.55, 0.8, 0.7);
uniform float strength = 0.09;
varying float height;
void vertex() { height = VERTEX.y + 0.5; }
void fragment() {
	float edge = pow(abs(dot(NORMAL, VIEW)), 1.5);
	ALBEDO = tint;
	ALPHA = strength * edge * smoothstep(0.0, 0.9, height);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _flush_blocks() -> void:
	for n in VARIANTS:
		var unit := GreekKit.cached("temple/ashlar/%d" % n, func() -> MeshKit: return TempleKit.ashlar(Vector3.ONE, 50 + n), TempleKit.wall_stone())
		var list: Array = _blocks[n]
		# Ashlar meshes stand on y 0: every transform is a block's foot.
		var lifted: Array[Transform3D] = []
		for xform: Transform3D in list:
			lifted.append(xform)
		add_multimesh(unit, lifted, null, true)


# --- The temple front ------------------------------------------------------------------

func _build_temple_front() -> void:
	var centre_z := -28.5
	var top := 0.0
	for n in 3:
		var footprint := Vector3(38.0 - n * 1.4, 0.6, 13.0 - n * 0.7)
		_marble_block(footprint, Vector3(0.0, top, centre_z), 0.0, 100 + n)
		top += 0.6
	add_outline_rect(Vector2(0.0, centre_z), Vector2(38.0, 13.0))
	# The front row of columns.
	var front_z := -23.4
	var plan := ["stand", "stand", "stand", "stand", "broken", "stand", "fallen", "stand"]
	var xs: Array[float] = []
	for i in plan.size():
		xs.append(-15.75 + 4.5 * i)
	var tall := GreekKit.COLUMN_HEIGHT * SCALE
	var radius := GreekKit.COLUMN_RADIUS * SCALE
	for i in plan.size():
		var at := Vector3(xs[i], top, front_z)
		match plan[i]:
			"stand":
				_column(at, SCALE, GreekKit.COLUMN_HEIGHT, 200 + i)
			"broken":
				var mesh := GreekKit.cached("temple/drum/%d" % i, func() -> MeshKit:
					return GreekKit.drum(1.4, GreekKit.COLUMN_RADIUS, true, 210 + i), GreekKit.marble())
				add_solid(mesh, Transform3D(Basis().scaled(Vector3.ONE * SCALE), at),
						[[cylinder_shape(GreekKit.COLUMN_RADIUS, 1.4), Transform3D(Basis(), Vector3.UP * 0.7)]], null)
			"fallen":
				var mesh := GreekKit.cached("temple/fallen/%d" % i, func() -> MeshKit: return GreekKit.fallen_column(4, 220 + i), GreekKit.marble())
				var yaw := -PI / 2.0 + 0.25  # toppled forward, off the steps
				var spot := Vector3(xs[i] - 1.0, 0.0, front_z + 2.6)
				var length := 4.0 * 0.95 * SCALE
				var body := add_solid(mesh, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * SCALE), spot), [], null)
				var shape_basis := Basis(Vector3.BACK, PI / 2.0)
				var collision := CollisionShape3D.new()
				collision.shape = cylinder_shape(radius, length)
				collision.transform = Transform3D(shape_basis, Vector3(length * 0.5, GreekKit.COLUMN_RADIUS * 0.9 * SCALE, 0.0))
				body.add_child(collision)
	# The architrave over the four on the left, and what's left of the pediment on it.
	var beam_y := top + tall
	for i in 3:
		var gap := 4.5
		_marble_block(Vector3(gap + 0.4, 1.1, 1.3), Vector3((xs[i] + xs[i + 1]) * 0.5, beam_y, front_z), 0.0, 240 + i, true)
	var pediment := GreekKit.cached("temple/pediment", func() -> MeshKit: return TempleKit.pediment(15.0, 2.6, 1.6, true, 250), GreekKit.marble())
	add_solid(pediment, Transform3D(Basis(), Vector3((xs[0] + xs[3]) * 0.5, beam_y + 1.1, front_z)),
			[[box_shape(Vector3(15.5, 1.6, 1.6)), Transform3D(Basis(), Vector3(0.0, 0.8, 0.0))]], null)
	# The rest of it fell: architrave blocks and a piece of the gable on the floor.
	_marble_block(Vector3(4.9, 1.1, 1.3), Vector3(12.0, 0.0, -18.5), 0.5, 260)
	_marble_block(Vector3(4.9, 1.1, 1.3), Vector3(5.0, 0.0, -17.0), -0.3, 261)
	var fragment := GreekKit.cached("temple/pediment_fallen", func() -> MeshKit: return TempleKit.pediment(6.0, 1.2, 1.6, true, 262), GreekKit.marble())
	add_solid(fragment, Transform3D(Basis(Vector3.UP, 2.6) * Basis(Vector3.RIGHT, 0.2), Vector3(17.0, 0.0, -15.5)),
			[[box_shape(Vector3(6.2, 1.4, 1.8)), Transform3D(Basis(), Vector3(0.0, 0.6, 0.0))]], null)
	# The cella behind: low ruined walls, a door in the front one.
	_ruined_wall(Vector3(-16.0, top, -25.5), Vector3(-16.0, top, -35.0), 4.8, 270)
	_ruined_wall(Vector3(16.0, top, -25.5), Vector3(16.0, top, -35.0), 4.0, 271)
	_ruined_wall(Vector3(-16.0, top, -25.5), Vector3(-3.0, top, -25.5), 6.0, 272)
	_ruined_wall(Vector3(3.0, top, -25.5), Vector3(16.0, top, -25.5), 5.0, 273)


## A wall of ashlar from `from` to `to` (on its foot), about `tall` m high
## with a ragged top.
func _ruined_wall(from: Vector3, to: Vector3, tall: float, seed_value: int) -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	var line := to - from
	var length := line.length()
	var along := line.normalized()
	var inward := along.cross(Vector3.UP)
	var block := 2.2
	var course := 0.9
	var thick := 1.1
	var courses := roundi(tall / course)
	var highest := 0.0
	for c in courses:
		var a := -fposmod(c, 2) * block * 0.5
		while a < length:
			var b := minf(a + block, length)
			# The top courses thin out.
			if c < courses - 2 or dice.randf() < 0.6 - (c - courses + 2) * 0.25:
				var span := Vector2(maxf(a, 0.0), b)
				if span.y - span.x > 0.3:
					var centre := from + along * (span.x + span.y) * 0.5 + Vector3.UP * c * course
					var basis := Basis(along, Vector3.UP, inward).scaled_local(Vector3(span.y - span.x - 0.05, course - 0.04, thick))
					_blocks[dice.randi() % VARIANTS].append(Transform3D(basis, centre))
					highest = maxf(highest, (c + 1) * course)
			a = b
	var middle := from + line * 0.5
	add_box_collider(Transform3D(Basis(along, Vector3.UP, inward), middle + Vector3.UP * (courses - 1) * course * 0.5),
			Vector3(length, (courses - 1) * course, thick))
	add_outline_rect(Vector2(middle.x, middle.z), Vector2(length, thick), atan2(along.z, along.x))


func _column(at: Vector3, scale_by: float, tall: float, seed_value: int) -> void:
	var mesh := GreekKit.cached("temple/column/%d/%d" % [roundi(scale_by * 10.0), seed_value], func() -> MeshKit:
		return GreekKit.column(tall, seed_value), GreekKit.marble())
	add_solid(mesh, Transform3D(Basis().scaled(Vector3.ONE * scale_by), at),
			[[cylinder_shape(GreekKit.COLUMN_RADIUS * 1.05, tall), Transform3D(Basis(), Vector3.UP * tall * 0.5)]], null)


## A dressed marble block `box` m, standing on `at`, turned `yaw`.
func _marble_block(box: Vector3, at: Vector3, yaw: float, seed_value: int, grooves := false) -> void:
	var mesh := GreekKit.cached("temple/block/%d" % seed_value, func() -> MeshKit: return GreekKit.block(box, seed_value, grooves), GreekKit.marble())
	add_solid(mesh, Transform3D(Basis(Vector3.UP, yaw), at), [[box_shape(box), Transform3D(Basis(), Vector3.UP * box.y * 0.5)]], null)


# --- The tholos ---------------------------------------------------------------------------

func _build_tholos() -> void:
	var s := THOLOS_SCALE
	var steps := GreekKit.cached("temple/tholos_steps", func() -> MeshKit: return GreekKit.round_steps(5.0, 3, 0.28, 0.45, 300), GreekKit.marble())
	var outer := (5.0 + 0.45 * 3) * s
	var rise := 0.28 * 3 * s
	add_solid(steps, Transform3D(Basis().scaled(Vector3.ONE * s), Vector3.ZERO), [[cylinder_shape(outer / s, rise / s), Transform3D(Basis(), Vector3.UP * rise * 0.5 / s)]], null)
	add_outline_circle(Vector2.ZERO, outer)
	var ring := 4.4 * s
	var count := 12
	var plan := ["stand", "stand", "broken", "stand", "stand", "fallen", "stand", "broken", "stand", "stand", "broken", "fallen"]
	var tall := GreekKit.COLUMN_HEIGHT
	for i in count:
		var angle := TAU * i / count
		var at := Vector3(cos(angle) * ring, rise, sin(angle) * ring)
		match plan[i]:
			"stand":
				_column(at, s, tall, 310 + i)
			"broken":
				var height := 0.6 + fposmod(i * 0.37, 1.0) * 1.6
				var mesh := GreekKit.cached("temple/tholos_drum/%d" % i, func() -> MeshKit:
					return GreekKit.drum(height, GreekKit.COLUMN_RADIUS, true, 320 + i), GreekKit.marble())
				add_solid(mesh, Transform3D(Basis().scaled(Vector3.ONE * s), at),
						[[cylinder_shape(GreekKit.COLUMN_RADIUS * 1.05, height), Transform3D(Basis(), Vector3.UP * height * 0.5)]], null)
			"fallen":
				# Toppled outward, down the steps onto the floor.
				var mesh := GreekKit.cached("temple/tholos_fallen/%d" % i, func() -> MeshKit: return GreekKit.fallen_column(3, 330 + i), GreekKit.marble())
				var out := Vector3(cos(angle), 0.0, sin(angle))
				var spot := out * (outer + 0.6)
				var yaw := atan2(-out.z, out.x)
				var body := add_solid(mesh, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), spot), [], null)
				var collision := CollisionShape3D.new()
				collision.shape = cylinder_shape(GreekKit.COLUMN_RADIUS * s, 2.8 * s)
				collision.transform = Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(1.4 * s, GreekKit.COLUMN_RADIUS * 0.9 * s, 0.0))
				body.add_child(collision)
	# The ring of architrave over neighbours still standing.
	var top := rise + tall * s
	for i in count:
		var j := (i + 1) % count
		if plan[i] == "stand" and plan[j] == "stand":
			var a0 := TAU * i / count
			var beam := GreekKit.cached("temple/tholos_beam/%d" % i, func() -> MeshKit:
				return GreekKit.ring_beam(4.4, TAU / count, 0.6, 0.55, false, 340 + i), GreekKit.marble())
			var mid := a0 + PI / count
			var chord := 2.0 * ring * sin(PI / count)
			add_solid(beam, Transform3D(Basis(Vector3.UP, -a0).scaled(Vector3.ONE * s), Vector3(0.0, top, 0.0)),
					[[box_shape(Vector3(0.6, 0.6, chord / s)), Transform3D(Basis(Vector3.UP, -mid + a0), Vector3(cos(mid - a0) * 4.4, 0.3, sin(mid - a0) * 4.4))]], null)
	# Poseidon inside.
	_statue_on_plinth("poseidon", Vector3(0.0, rise, 0.0), Vector3(0.0, 0.0, 1.0), s)


func _statue_on_plinth(god: String, at: Vector3, facing: Vector3, s: float) -> void:
	var plinth := Vector3(1.0, 0.9, 1.0) * s
	_marble_block(plinth, at, 0.0, 360 + god.hash() % 100)
	var mesh := GreekKit.cached("temple/statue/%s" % god, func() -> MeshKit: return GreekKit.statue(god, 370 + god.length()), GreekKit.marble())
	var yaw := atan2(facing.x, facing.z)
	add_solid(mesh, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at + Vector3.UP * plinth.y),
			[[box_shape(Vector3(0.75, 2.1, 0.6)), Transform3D(Basis(), Vector3.UP * 1.05)]], null)
	add_outline_rect(Vector2(at.x, at.z), Vector2(plinth.x, plinth.z))


# --- Altar, statues, pottery, steps, kelp ---------------------------------------------------

func _build_altar() -> void:
	var at := Vector3(0.0, 0.0, -14.0)
	_marble_block(Vector3(4.0, 1.4, 2.2), at, 0.0, 400, true)
	_marble_block(Vector3(4.6, 0.32, 2.7), at + Vector3.UP * 1.4, 0.0, 401)
	add_outline_rect(Vector2(at.x, at.z), Vector2(4.6, 2.7))
	var s := 2.2
	var spot := at + Vector3(4.6, 0.0, 0.4)
	var brazier := GreekKit.cached("temple/brazier", func() -> MeshKit: return GreekKit.brazier(), GreekKit.bronze())
	add_solid(brazier, Transform3D(Basis().scaled(Vector3.ONE * s), spot),
			[[cylinder_shape(0.42, 1.1), Transform3D(Basis(), Vector3.UP * 0.55)]], null)
	# Embers that still glow (the sanctuary's one warm light).
	var embers := SphereMesh.new()
	embers.radius = 0.3 * s
	embers.height = 0.25 * s
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(0.3, 0.08, 0.02)
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.42, 0.12)
	hot.emission_energy_multiplier = 2.5
	add_visual(embers, Transform3D(Basis(), spot + Vector3.UP * 1.0 * s), hot)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 2.0
	light.omni_range = 14.0
	light.position = spot + Vector3.UP * (1.2 * s + 0.6)
	add_child(light)


func _build_statues() -> void:
	# Toppled statues, each by the plinth it fell from.
	var fallen := [[Vector3(24.0, 0.0, -6.0), 0.6, "hades"], [Vector3(-26.0, 0.0, 14.0), 2.2, "tyche"], [Vector3(16.0, 0.0, 22.0), -1.1, "aphrodite"],
			[Vector3(-22.0, 0.0, -10.0), 3.6, "poseidon"]]
	var s := 1.6
	for n in fallen.size():
		var entry: Array = fallen[n]
		var at: Vector3 = entry[0]
		var yaw: float = entry[1]
		var god: String = entry[2]
		var mesh := GreekKit.cached("temple/fallen_statue/%s" % god, func() -> MeshKit: return GreekKit.statue(god, 380 + n), GreekKit.marble())
		var body := add_solid(null, Transform3D(Basis(Vector3.UP, yaw), at),
				[[box_shape(Vector3(2.2 * s, 0.62 * s, 0.75 * s)), Transform3D(Basis(), Vector3(-1.1 * s, 0.31 * s, 0.0))]])
		var view := MeshInstance3D.new()
		view.mesh = mesh
		view.transform = Transform3D(Basis(Vector3.BACK, PI / 2.0 + 0.04).scaled(Vector3.ONE * s), Vector3(0.0, 0.3 * s, 0.0))
		body.add_child(view)
		var basis := Basis(Vector3.UP, yaw)
		_marble_block(Vector3(1.0, 0.9, 1.0) * s, at + basis * Vector3(1.4 * s, 0.0, 0.8), yaw + 0.3, 390 + n)
		var mid := at + basis * Vector3(-1.1 * s, 0.0, 0.0)
		add_outline_rect(Vector2(mid.x, mid.z), Vector2(2.2 * s, 0.75 * s), -yaw)


func _build_pottery() -> void:
	var s := SCALE
	# Amphorae in a row along the east wall, a few lying broken.
	for n in 9:
		var at := Vector3(41.0, 0.0, -20.0 + n * 2.3)
		var lying := n in [3, 7]
		var broken := n in [3, 5, 7]
		var mesh := GreekKit.cached("temple/amphora/%d" % n, func() -> MeshKit: return GreekKit.amphora(false, broken, 500 + n), GreekKit.marble())
		if lying:
			var body := add_solid(null, Transform3D(Basis(Vector3.UP, 0.4 * n), at),
					[[box_shape(Vector3(0.9 * s, 0.44 * s, 0.44 * s)), Transform3D(Basis(), Vector3(-0.45 * s, 0.22 * s, 0.0))]])
			var view := MeshInstance3D.new()
			view.mesh = mesh
			view.transform = Transform3D(Basis(Vector3.BACK, 1.45).scaled(Vector3.ONE * s), Vector3(0.0, 0.2 * s, 0.0))
			body.add_child(view)
		else:
			add_solid(mesh, Transform3D(Basis(Vector3.UP, 0.7 * n).scaled(Vector3.ONE * s), at),
					[[cylinder_shape(0.22, 0.9), Transform3D(Basis(), Vector3.UP * 0.45)]], null)
	add_outline_rect(Vector2(41.0, -10.8), Vector2(1.8, 20.0))
	# Kraters along the west wall.
	for n in 7:
		var at := Vector3(-41.0, 0.0, 6.0 + n * 2.8)
		var broken := n % 3 == 1
		var mesh := GreekKit.cached("temple/krater/%d" % n, func() -> MeshKit: return GreekKit.amphora(true, broken, 520 + n), GreekKit.marble())
		add_solid(mesh, Transform3D(Basis(Vector3.UP, 0.9 * n).scaled(Vector3.ONE * s), at),
				[[cylinder_shape(0.34, 0.55), Transform3D(Basis(), Vector3.UP * 0.275)]], null)
	add_outline_rect(Vector2(-41.0, 14.4), Vector2(1.8, 18.0))


## A broken flight of steps in the south-west corner, climbing west to nowhere.
func _build_steps() -> void:
	var base := Vector3(-28.0, 0.0, 27.0)
	var tread := 1.6
	var rise := 0.9
	for n in 6:
		var width := 9.0 - (2.5 if n > 3 else 0.0)
		var at := base + Vector3(-n * tread, 0.0, (1.2 if n > 3 else 0.0))
		var box := Vector3(tread + 0.05, rise * (n + 1), width)
		if n == 3:
			# Cracked through and slumped.
			_marble_block(Vector3(tread, rise * n + 0.3, width * 0.5), at + Vector3(0.0, 0.0, -width * 0.25), 0.05, 600 + n)
			_marble_block(Vector3(tread, rise * n - 0.4, width * 0.45), at + Vector3(0.2, 0.0, width * 0.27), -0.08, 610 + n)
			continue
		_marble_block(box, at, 0.0, 600 + n)
	add_outline_rect(Vector2(base.x - tread * 2.5, base.z), Vector2(tread * 6.0, 9.0))
	# A few loose blocks tumbled off it.
	_marble_block(Vector3(1.4, 0.9, 1.1), Vector3(-24.0, 0.0, 31.0), 0.7, 620)
	_marble_block(Vector3(1.0, 0.7, 1.6), Vector3(-25.5, 0.0, 22.0), 1.9, 621)


func _build_kelp() -> void:
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		for n in 7:
			var spot := Vector3(corner.x * (size.x * 0.5 - 2.0 - _dice.randf() * 7.0), 0.0, corner.y * (size.z * 0.5 - 2.0 - _dice.randf() * 7.0))
			var mesh := ReefKit.mesh("kelp", n % ReefKit.VARIANTS)
			add_visual(mesh, Transform3D(Basis(Vector3.UP, _dice.randf() * TAU).scaled(Vector3.ONE * _dice.randf_range(1.6, 2.6)), spot))


# --- Spawns ------------------------------------------------------------------------------------

func _place_markers() -> void:
	set_seeker_start(Vector3(0.0, 4.0, 28.0), Vector3(0.0, 0.0, -1.0))
	var spots := [[Vector3(-30.0, 2.5, -10.0), Vector3(1, 0, 0)], [Vector3(30.0, 2.5, -16.0), Vector3(-1, 0, 0)],
			[Vector3(-20.0, 2.5, 20.0), Vector3(0, 0, -1)], [Vector3(22.0, 2.5, 10.0), Vector3(-1, 0, 0)],
			[Vector3(-8.0, 3.5, -30.0), Vector3(0, 0, 1)], [Vector3(9.0, 3.5, -30.0), Vector3(0, 0, 1)],
			[Vector3(36.0, 2.5, 26.0), Vector3(-1, 0, -1)], [Vector3(-36.0, 2.5, -28.0), Vector3(1, 0, 1)]]
	for spot: Array in spots:
		add_hider_spawn(spot[0], spot[1])
