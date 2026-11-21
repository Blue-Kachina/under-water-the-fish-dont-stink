class_name FishTankArena
extends MarcoArena
## The Aquarium (planning_marco_polo.md §12): a home fish tank seen at fish
## scale, about 80 m long, 42 m of water deep and 40 m front to back. Not the
## RL pitch (AquariumArena), though its glass shader is borrowed.
## - Glass at the front and sides, looking out on a blurred living room; the
##   back is the filter box's black panel; a hood light over the top; a dirty,
##   algae-green murk.
## - A plastic castle (a keep you can swim through: gate, back door, windows;
##   four towers with arrow slits), a sunken pirate ship, a treasure chest that
##   opens on a timer and burps bubbles, a diver in a helmet, plastic plants, a
##   ceramic skull, an arched bridge, coloured gravel and a few big rocks, the
##   filter's intake tube.
## - Noisy bubbles: airstone curtains along the back (one pulsing), a bubble
##   wand along the floor (pulsing), the diver's helmet trickle and the chest's
##   burps. Each is loud and masks a hider inside it (BubbleCurtain).
## - The portholes: round holes in the back panel and the castle's arrow slits.
## The seeker starts at the front, by the glass.

## The back panel's cells (m): it's built in rows this tall, holes in cells this wide.
const CELL := 4.0
## How far the gravel and pebbles are calmed toward grey (0 shop colours, 1 grey-green).
const GRAVEL_CALM := 0.8
const PANEL_THICK := 1.5
const HOLE_RADIUS := 0.8
## The chest: shut this long, then open (burping) this long (s).
const CHEST_SHUT := 9.0
const CHEST_OPEN := 2.5

## Holes in the back panel: [x, y], each in the middle of a cell.
const PANEL_HOLES := [Vector2(-30.0, 6.0), Vector2(-14.0, 18.0), Vector2(-2.0, 10.0), Vector2(14.0, 26.0), Vector2(30.0, 10.0)]
## The castle: its keep's middle, and its size.
const CASTLE := Vector3(-24.0, 0.0, -4.0)
const KEEP := Vector3(14.0, 13.0, 12.0)
const TOWER_RADIUS := 2.8
const TOWER_TALL := 19.0

var _plastic := MarcoArena.plain(Color(0.07, 0.075, 0.08), 0.55)
var _resin := MarcoArena.plain(Color(0.56, 0.5, 0.42), 0.85)
var _wood := MarcoArena.plain(Color(0.3, 0.19, 0.11), 0.9)
var _brass := MarcoArena.plain(Color(0.72, 0.55, 0.25), 0.35, 0.8)
var _chest_lid: Node3D
var _chest_burp: BubbleCurtain
var _chest_light: OmniLight3D
var _chest_time := 0.0
var _chest_open := false
var _dice := RandomNumberGenerator.new()


func _init() -> void:
	size = Vector3(80.0, 42.0, 40.0)
	murk_density = 0.042
	murk_color = Color(0.09, 0.19, 0.08)
	background_color = Color(0.04, 0.08, 0.04)
	ambient_color = Color(0.42, 0.52, 0.34)
	ambient_energy = 0.6


func _build() -> void:
	_dice.seed = 4242
	add_shell_colliders()
	_build_floor()
	_build_glass()
	_build_back_panel()
	_build_hood()
	_build_castle()
	_build_ship()
	_build_chest()
	_build_diver()
	_build_skull()
	_build_bridge()
	_build_rocks()
	_build_intake()
	_build_plants()
	_build_bubbles()
	_place_markers()


func _process(delta: float) -> void:
	_chest_time += delta
	var cycle := CHEST_SHUT + CHEST_OPEN
	var open := fposmod(_chest_time, cycle) >= CHEST_SHUT
	if open and not _chest_open:
		_chest_burp.burst(CHEST_OPEN)
		Sfx.play_at("mp/chest_burp", _chest_burp.global_position + Vector3.UP * 2.0)
	_chest_open = open
	var target := -1.15 if open else 0.0
	_chest_lid.rotation.x = move_toward(_chest_lid.rotation.x, target, delta * 3.0)
	_chest_light.light_energy = move_toward(_chest_light.light_energy, 2.5 if open else 0.0, delta * 4.0)


# --- The tank -------------------------------------------------------------------------

func _build_floor() -> void:
	var gravel := PlaneMesh.new()
	gravel.size = Vector2(size.x, size.z)
	var gravel_material := ShaderMaterial.new()
	gravel_material.shader = preload("res://shaders/marco_gravel.gdshader")
	add_visual(gravel, Transform3D(Basis(), Vector3(0.0, 0.02, 0.0)), gravel_material)
	# Loose pebbles on top for some relief, in the gravel's colours.
	var pebble := SphereMesh.new()
	pebble.radius = 0.5
	pebble.height = 1.0
	pebble.radial_segments = 7
	pebble.rings = 3
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.45
	var colours := [Color(0.15, 0.35, 0.85), Color(0.9, 0.35, 0.55), Color(0.92, 0.9, 0.85), Color(0.25, 0.7, 0.35)]
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = pebble
	multimesh.instance_count = 2400
	for i in multimesh.instance_count:
		var s := _dice.randf_range(0.25, 0.6)
		var at := Vector3(_dice.randf_range(-size.x * 0.5, size.x * 0.5), s * 0.15, _dice.randf_range(-size.z * 0.5, size.z * 0.5))
		var basis := Basis(Vector3.UP, _dice.randf() * TAU).scaled(Vector3(s, s * 0.6, s * 0.85))
		multimesh.set_instance_transform(i, Transform3D(basis, at))
		multimesh.set_instance_color(i, _calm(colours[_dice.randi() % colours.size()] as Color) * _dice.randf_range(0.7, 1.05))
	var view := MultiMeshInstance3D.new()
	view.multimesh = multimesh
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


## The shop-gravel colours toned down to match the shader's calm (loud pebbles are noise
## at a whale's distance, and its floor silt shows the floor off).
func _calm(colour: Color) -> Color:
	var grey := colour.get_luminance()
	return Color(grey, grey, grey).lerp(colour, 1.0 - GRAVEL_CALM * 0.7) * lerpf(1.0, 0.72, GRAVEL_CALM)


## Glass at the front and sides, a black frame round it, and the room beyond.
func _build_glass() -> void:
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://shaders/glass.gdshader")
	glass.set_shader_parameter("base_color", Color(0.3, 0.42, 0.36, 1.0))
	glass.set_shader_parameter("line_color", Color(0.6, 0.75, 0.65, 1.0))
	glass.set_shader_parameter("cell_size", 1000.0)
	glass.set_shader_parameter("fill", 0.05)
	glass.set_shader_parameter("edge_fill", 0.3)
	glass.set_shader_parameter("line_alpha", 0.0)
	var half := size * 0.5
	var height := size.y + 3.0
	var panes := [[Vector3(0.0, height * 0.5, half.z), Vector3(0.0, 0.0, -1.0), size.x], [Vector3(half.x, height * 0.5, 0.0), Vector3(-1.0, 0.0, 0.0), size.z],
			[Vector3(-half.x, height * 0.5, 0.0), Vector3(1.0, 0.0, 0.0), size.z]]
	for pane: Array in panes:
		var quad := QuadMesh.new()
		quad.size = Vector2(pane[2], height)
		var inward: Vector3 = pane[1]
		tag_shell(add_visual(quad, Transform3D(Basis.looking_at(-inward, Vector3.UP), pane[0]), glass), -inward)
	# The frame: black trim along every edge.
	for x: float in [-half.x, half.x]:
		for z: float in [-half.z, half.z]:
			_trim(Vector3(x, height * 0.5, z), Vector3(1.2, height + 1.0, 1.2))
	for y: float in [0.0, height]:
		_trim(Vector3(0.0, y, half.z), Vector3(size.x + 1.2, 1.4, 1.2), Vector3.BACK)
		_trim(Vector3(half.x, y, 0.0), Vector3(1.2, 1.4, size.z + 1.2), Vector3.RIGHT)
		_trim(Vector3(-half.x, y, 0.0), Vector3(1.2, 1.4, size.z + 1.2), Vector3.LEFT)
	# The living room, out of focus.
	var room := ShaderMaterial.new()
	room.shader = preload("res://shaders/marco_living_room.gdshader")
	room.set_shader_parameter("murk", Vector3(murk_color.r, murk_color.g, murk_color.b))
	var walls := [[Vector3(0.0, 25.0, half.z + 30.0), Vector3(0.0, 0.0, -1.0), 200.0, 0.0], [Vector3(half.x + 30.0, 25.0, 0.0), Vector3(-1.0, 0.0, 0.0), 140.0, 0.6],
			[Vector3(-half.x - 30.0, 25.0, 0.0), Vector3(1.0, 0.0, 0.0), 140.0, 0.3]]
	for wall: Array in walls:
		var quad := QuadMesh.new()
		quad.size = Vector2(wall[2], 90.0)
		var material: ShaderMaterial = room.duplicate()
		material.set_shader_parameter("seed", wall[3])
		var inward: Vector3 = wall[1]
		add_visual(quad, Transform3D(Basis.looking_at(-inward, Vector3.UP), wall[0]), material)


func _trim(at: Vector3, box: Vector3, outward := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box
	var view := add_visual(mesh, Transform3D(Basis(), at), _plastic)
	if outward != Vector3.ZERO:
		tag_shell(view, outward)


## The filter box's back panel: black plastic in rows, round holes in some cells.
func _build_back_panel() -> void:
	var z := -size.z * 0.5 - PANEL_THICK * 0.5
	var rows := ceili(size.y / CELL)
	var hole_mesh := TankKit.cached("tank/panel_hole", func() -> MeshKit:
		return TempleKit.holed_slab(CELL, CELL, PANEL_THICK, HOLE_RADIUS * 1.08, 11), _plastic)
	for r in rows:
		var y0 := r * CELL
		var cuts: Array[float] = []
		for hole: Vector2 in PANEL_HOLES:
			if hole.y > y0 and hole.y < y0 + CELL:
				cuts.append(hole.x)
		cuts.sort()
		var a := -size.x * 0.5 - 1.0
		cuts.append(size.x * 0.5 + 1.0)
		for x in cuts:
			var b := x - CELL * 0.5 if x < size.x * 0.5 else x
			if b - a > 0.05:
				var mesh := BoxMesh.new()
				mesh.size = Vector3(b - a, CELL, PANEL_THICK)
				tag_shell(add_visual(mesh, Transform3D(Basis(), Vector3((a + b) * 0.5, y0 + CELL * 0.5, z)), _plastic), Vector3.FORWARD)
			if x < size.x * 0.5:
				tag_shell(add_visual(hole_mesh, Transform3D(Basis(), Vector3(x, y0, z)), null), Vector3.FORWARD)
			a = x + CELL * 0.5
	for hole: Vector2 in PANEL_HOLES:
		add_porthole(Vector3(hole.x, hole.y, -size.z * 0.5), Vector3.BACK, HOLE_RADIUS, Porthole.Look.ROUND, _plastic)


## The hood over the top: its light strip, a few lamps, and the water's surface.
func _build_hood() -> void:
	var hood := BoxMesh.new()
	hood.size = Vector3(size.x + 2.0, 2.5, size.z + 2.0)
	tag_shell(add_visual(hood, Transform3D(Basis(), Vector3(0.0, size.y + 4.5, 0.0)), _plastic), Vector3.UP)
	var strip := BoxMesh.new()
	strip.size = Vector3(size.x - 6.0, 0.2, 3.0)
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(0.9, 1.0, 0.9)
	lit.emission_enabled = true
	lit.emission = Color(0.85, 1.0, 0.85)
	lit.emission_energy_multiplier = 3.0
	tag_shell(add_visual(strip, Transform3D(Basis(), Vector3(0.0, size.y + 3.2, -4.0)), lit), Vector3.UP)
	for x: float in [-26.0, 0.0, 26.0]:
		var lamp := SpotLight3D.new()
		lamp.light_color = Color(0.85, 1.0, 0.8)
		lamp.light_energy = 2.2
		lamp.spot_range = 70.0
		lamp.spot_angle = 55.0
		lamp.spot_attenuation = 0.6
		lamp.transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(x, size.y + 2.5, -4.0))
		add_child(lamp)
	var surface := PlaneMesh.new()
	surface.size = Vector2(size.x, size.z)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.55, 0.75, 0.6, 0.55)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	water.metallic_specular = 1.0
	water.roughness = 0.1
	water.emission_enabled = true
	water.emission = Color(0.2, 0.3, 0.22)
	tag_shell(add_visual(surface, Transform3D(Basis(), Vector3(0.0, size.y, 0.0)), water), Vector3.UP)


# --- Furniture ---------------------------------------------------------------------------

func _box_piece(box: Vector3, at: Vector3, material: Material, yaw := 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box
	add_solid(mesh, Transform3D(Basis(Vector3.UP, yaw), at), [[box_shape(box), Transform3D.IDENTITY]], material)


## Merlons along the top of a wall from `from` to `to` (on the wall's top).
func _merlons(from: Vector3, to: Vector3, thick: float) -> void:
	var line := to - from
	var count := maxi(roundi(line.length() / 1.6), 2)
	var along := line.normalized()
	for n in count:
		if n % 2 == 1:
			continue
		var at := from + along * (n + 0.5) * line.length() / count
		var mesh := BoxMesh.new()
		mesh.size = Vector3(line.length() / count, 1.0, thick)
		add_visual(mesh, Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), at + Vector3.UP * 0.5), _resin, true)


## A plastic castle: a roofless keep with a gate (front), a back door and a
## window in each side, all swim-throughs; four crenellated towers, two with
## arrow slits (portholes).
func _build_castle() -> void:
	var c := CASTLE
	var hx := KEEP.x * 0.5
	var hz := KEEP.z * 0.5
	var tall := KEEP.y
	var t := 1.2
	# Front (+z) with the gate, back (-z) with a door.
	for side: Array in [[hz, 4.0, 6.0], [-hz, 3.0, 5.0]]:
		var z: float = side[0]
		var gap: float = side[1]
		var gap_tall: float = side[2]
		var piece := (KEEP.x - gap) * 0.5
		for s: float in [-1.0, 1.0]:
			_box_piece(Vector3(piece, tall, t), c + Vector3(s * (gap * 0.5 + piece * 0.5), tall * 0.5, z), _resin)
		_box_piece(Vector3(gap, tall - gap_tall, t), c + Vector3(0.0, gap_tall + (tall - gap_tall) * 0.5, z), _resin)
		_merlons(c + Vector3(-hx, tall, z), c + Vector3(hx, tall, z), t)
	# Sides with a window each.
	var window := Vector3(0.0, 5.0, 3.0)  # bottom, top-bottom height, width
	for x: float in [-hx, hx]:
		var length := KEEP.z - t * 2.0
		var piece := (length - window.z) * 0.5
		for s: float in [-1.0, 1.0]:
			_box_piece(Vector3(t, tall, piece), c + Vector3(x, tall * 0.5, s * (window.z * 0.5 + piece * 0.5)), _resin)
		_box_piece(Vector3(t, window.y, window.z), c + Vector3(x, window.y * 0.5, 0.0), _resin)
		_box_piece(Vector3(t, tall - window.y - 3.0, window.z), c + Vector3(x, window.y + 3.0 + (tall - window.y - 3.0) * 0.5, 0.0), _resin)
		_merlons(c + Vector3(x, tall, -hz), c + Vector3(x, tall, hz), t)
	add_outline_rect(Vector2(c.x, c.z), Vector2(KEEP.x, KEEP.z))
	# The towers.
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for corner: Vector2 in corners:
		var at := c + Vector3(corner.x * hx, 0.0, corner.y * hz)
		var tower := CylinderMesh.new()
		tower.top_radius = TOWER_RADIUS
		tower.bottom_radius = TOWER_RADIUS * 1.08
		tower.height = TOWER_TALL
		tower.radial_segments = 20
		add_solid(tower, Transform3D(Basis(), at + Vector3.UP * TOWER_TALL * 0.5),
				[[cylinder_shape(TOWER_RADIUS * 1.04, TOWER_TALL), Transform3D.IDENTITY]], _resin)
		for n in 8:
			var a := TAU * n / 8.0
			var merlon := BoxMesh.new()
			merlon.size = Vector3(1.4, 1.2, 0.8)
			var out := Vector3(cos(a), 0.0, sin(a))
			add_visual(merlon, Transform3D(Basis.looking_at(out, Vector3.UP), at + out * (TOWER_RADIUS - 0.4) + Vector3.UP * (TOWER_TALL + 0.6)), _resin, true)
		add_outline_circle(Vector2(at.x, at.z), TOWER_RADIUS, 12)
	# Arrow slits: out of the front-left tower and the back-right one.
	for slit: Array in [[Vector2(-1, 1), 12.0], [Vector2(1, -1), 9.0]]:
		var corner: Vector2 = slit[0]
		var at := c + Vector3(corner.x * hx, 0.0, corner.y * hz)
		var out := Vector3(corner.x, 0.0, corner.y).normalized()
		add_porthole(at + out * TOWER_RADIUS * 1.1 + Vector3.UP * float(slit[1]), out, HOLE_RADIUS, Porthole.Look.SLIT, _resin)


## A sunken pirate ship lying over on its side, its mast snapped.
func _build_ship() -> void:
	var length := 22.0
	var beam := 7.0
	var depth := 5.5
	var at := Vector3(20.0, -0.8, 1.0)
	var lie := Basis(Vector3.UP, 0.45) * Basis(Vector3.BACK, 0.28)
	var hull := TankKit.cached("tank/hull", func() -> MeshKit: return TankKit.hull(length, beam, depth), _wood)
	var shapes := []
	for k: Array in [[-0.32, 0.95], [0.0, 1.0], [0.3, 0.7]]:
		shapes.append([box_shape(Vector3(beam * float(k[1]) * 0.9, depth * 0.95, length * 0.32)), Transform3D(Basis(), Vector3(0.0, depth * 0.5, float(k[0]) * length))])
	var body := add_solid(hull, Transform3D(lie, at), shapes, null)
	# The stern cabin and the mast, riding with the hull.
	var cabin := BoxMesh.new()
	cabin.size = Vector3(beam * 0.7, 2.6, 4.5)
	_attach(body, cabin, Transform3D(Basis(), Vector3(0.0, depth + 1.3, -length * 0.36)), [box_shape(cabin.size)], _wood)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.3
	mast.bottom_radius = 0.4
	mast.height = 11.0
	_attach(body, mast, Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0.0, depth + 5.3, 1.0)), [cylinder_shape(0.4, 11.0)], _wood)
	var yard := CylinderMesh.new()
	yard.top_radius = 0.18
	yard.bottom_radius = 0.18
	yard.height = 7.0
	_attach(body, yard, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0.0, depth + 8.5, 2.6)), [], _wood)
	add_outline_rect(Vector2(at.x, at.z), Vector2(beam, length), -0.45)


func _attach(body: StaticBody3D, mesh: Mesh, xform: Transform3D, shapes: Array, material: Material) -> void:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.transform = xform
	view.material_override = material
	body.add_child(view)
	for shape: Shape3D in shapes:
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = xform
		body.add_child(collision)


## A treasure chest that opens on a timer and burps a column of bubbles.
func _build_chest() -> void:
	var at := Vector3(6.0, 0.0, 10.0)
	var box := Vector3(3.2, 1.8, 2.2)
	_box_piece(box, at + Vector3.UP * box.y * 0.5, _wood)
	for x: float in [-1.0, 1.0]:
		var band := BoxMesh.new()
		band.size = Vector3(0.25, box.y + 0.05, box.z + 0.05)
		add_visual(band, Transform3D(Basis(), at + Vector3(x * box.x * 0.3, box.y * 0.5, 0.0)), _brass)
	# The lid hinges at the back.
	_chest_lid = Node3D.new()
	_chest_lid.position = at + Vector3(0.0, box.y, -box.z * 0.5)
	add_child(_chest_lid)
	var lid := CylinderMesh.new()
	lid.top_radius = box.z * 0.5
	lid.bottom_radius = box.z * 0.5
	lid.height = box.x
	var lid_view := MeshInstance3D.new()
	lid_view.mesh = lid
	lid_view.material_override = _wood
	lid_view.transform = Transform3D(Basis(Vector3.BACK, PI / 2.0).scaled(Vector3(1.0, 1.0, 0.6)), Vector3(0.0, 0.0, box.z * 0.5))
	_chest_lid.add_child(lid_view)
	var gold := SphereMesh.new()
	gold.radius = 1.2
	gold.height = 0.8
	var shine := MarcoArena.plain(Color(1.0, 0.78, 0.25), 0.25, 1.0)
	shine.emission_enabled = true
	shine.emission = Color(0.5, 0.35, 0.05)
	add_visual(gold, Transform3D(Basis(), at + Vector3.UP * (box.y - 0.1)), shine)
	_chest_light = OmniLight3D.new()
	_chest_light.light_color = Color(1.0, 0.8, 0.35)
	_chest_light.omni_range = 8.0
	_chest_light.light_energy = 0.0
	_chest_light.position = at + Vector3.UP * (box.y + 1.0)
	add_child(_chest_light)
	_chest_burp = BubbleCurtain.new()
	_chest_burp.name = "ChestBurp"
	_chest_burp.extent = Vector3(3.0, size.y - box.y, 2.0)
	_chest_burp.on_time = -1.0
	_chest_burp.density = 30.0
	_chest_burp.rise = 9.0
	_chest_burp.bubble_size = 0.25
	_chest_burp.sound = false  # its burp is its own sound
	_chest_burp.position = at + Vector3.UP * box.y
	add_curtain(_chest_burp)
	add_outline_rect(Vector2(at.x, at.z), Vector2(box.x, box.z))


## A diver in a brass helmet, standing, a trickle of bubbles from the helmet.
func _build_diver() -> void:
	var at := Vector3(-4.0, 0.0, -13.0)
	var suit := MarcoArena.plain(Color(0.45, 0.42, 0.32), 0.9)
	var body := add_solid(null, Transform3D(Basis(Vector3.UP, 0.4), at),
			[[box_shape(Vector3(2.4, 6.2, 1.6)), Transform3D(Basis(), Vector3.UP * 3.1)]])
	var parts := [[_capsule(0.45, 2.4), Vector3(-0.5, 1.4, 0.0), suit], [_capsule(0.45, 2.4), Vector3(0.5, 1.4, 0.0), suit],
			[_capsule(0.9, 2.6), Vector3(0.0, 3.4, 0.0), suit], [_capsule(0.32, 2.2), Vector3(-1.1, 3.4, 0.25), suit],
			[_capsule(0.32, 2.2), Vector3(1.1, 3.4, 0.25), suit]]
	for part: Array in parts:
		var view := MeshInstance3D.new()
		view.mesh = part[0]
		view.position = part[1]
		view.material_override = part[2]
		body.add_child(view)
	for x: float in [-0.5, 0.5]:
		var boot := BoxMesh.new()
		boot.size = Vector3(0.8, 0.5, 1.2)
		var view := MeshInstance3D.new()
		view.mesh = boot
		view.position = Vector3(x, 0.25, 0.15)
		view.material_override = _brass
		body.add_child(view)
	var helmet := SphereMesh.new()
	helmet.radius = 1.1
	helmet.height = 2.2
	var head := MeshInstance3D.new()
	head.mesh = helmet
	head.position = Vector3(0.0, 5.3, 0.0)
	head.material_override = _brass
	body.add_child(head)
	var plate := CylinderMesh.new()
	plate.top_radius = 0.55
	plate.bottom_radius = 0.55
	plate.height = 0.2
	var glass := MeshInstance3D.new()
	glass.mesh = plate
	glass.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.0, 5.3, 1.0))
	glass.material_override = MarcoArena.plain(Color(0.03, 0.05, 0.05), 0.1, 0.5)
	body.add_child(glass)
	var trickle := BubbleCurtain.new()
	trickle.name = "DiverTrickle"
	trickle.extent = Vector3(1.4, size.y - 6.4, 1.4)
	trickle.density = 40.0
	trickle.rise = 4.0
	trickle.bubble_size = 0.16
	trickle.position = at + Vector3.UP * 6.4
	add_curtain(trickle)
	add_outline_rect(Vector2(at.x, at.z), Vector2(2.4, 1.6), -0.4)


func _capsule(radius: float, tall: float) -> CapsuleMesh:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = tall
	return capsule


func _build_skull() -> void:
	var at := Vector3(12.0, 0.0, -11.0)
	var radius := 2.8
	var bone := MarcoArena.plain(Color(0.86, 0.82, 0.7), 0.35)
	var skull := TankKit.cached("tank/skull", func() -> MeshKit: return TankKit.skull(radius), bone)
	add_solid(skull, Transform3D(Basis(Vector3.UP, -0.5), at), [[cylinder_shape(radius * 0.95, radius * 1.9), Transform3D(Basis(), Vector3.UP * radius * 0.95)]], null)
	add_outline_circle(Vector2(at.x, at.z), radius, 12)


func _build_bridge() -> void:
	var at := Vector3(-3.0, 0.0, 6.0)
	var length := 16.0
	var rise := 4.0
	var mesh := TankKit.cached("tank/bridge", func() -> MeshKit: return TankKit.bridge(length, 4.0, rise), _wood)
	var shapes := []
	var segments := 8
	for n in segments:
		var v0 := float(n) / segments
		var v1 := float(n + 1) / segments
		var p0 := Vector3((v0 - 0.5) * length, rise * sin(PI * v0), 0.0)
		var p1 := Vector3((v1 - 0.5) * length, rise * sin(PI * v1), 0.0)
		var mid := (p0 + p1) * 0.5
		var slope := atan2(p1.y - p0.y, p1.x - p0.x)
		shapes.append([box_shape(Vector3(p0.distance_to(p1) + 0.1, 0.8, 4.0)), Transform3D(Basis(Vector3.BACK, slope), mid + Vector3.UP * 0.3)])
	add_solid(mesh, Transform3D(Basis(Vector3.UP, 0.15), at), shapes, null)
	add_outline_rect(Vector2(at.x, at.z), Vector2(length, 4.0), -0.15)
	# The two low ends of the arch: a whale can't get under them, so they're hideaways.
	add_hideaway_spot("Under the bridge (west)", at + Vector3(-5.0, 1.0, 1.0), 3.5)
	add_hideaway_spot("Under the bridge (east)", at + Vector3(5.0, 1.0, -1.0), 3.5)


func _build_rocks() -> void:
	var rocks := [[Vector3(-34.0, 0.0, 12.0), 5.0], [Vector3(30.0, 0.0, 14.0), 4.0], [Vector3(-10.0, 0.0, -8.0), 3.5], [Vector3(34.0, 0.0, -6.0), 4.5],
			[Vector3(-14.0, 0.0, 14.0), 3.0], [Vector3(2.0, 0.0, -4.0), 3.2]]
	for n in rocks.size():
		var entry: Array = rocks[n]
		var s: float = entry[1]
		var at: Vector3 = entry[0]
		add_solid(ReefKit.mesh("boulder", n % ReefKit.VARIANTS), Transform3D(Basis(Vector3.UP, _dice.randf() * TAU).scaled(Vector3.ONE * s), at),
				[[box_shape(Vector3(0.95, 0.55, 0.95)), Transform3D(Basis(), Vector3.UP * 0.25)]], null)
		add_outline_circle(Vector2(at.x, at.z), s * 0.5, 8)


func _build_intake() -> void:
	var at := Vector3(34.0, 0.0, -16.0)
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = size.y - 3.0
	var plastic := MarcoArena.plain(Color(0.35, 0.42, 0.4), 0.3)
	add_solid(tube, Transform3D(Basis(), at + Vector3.UP * (3.0 + tube.height * 0.5)), [[cylinder_shape(1.0, tube.height), Transform3D.IDENTITY]], plastic)
	var strainer := CylinderMesh.new()
	strainer.top_radius = 1.25
	strainer.bottom_radius = 1.25
	strainer.height = 5.0
	add_solid(strainer, Transform3D(Basis(), at + Vector3.UP * 3.5), [[cylinder_shape(1.25, 5.0), Transform3D.IDENTITY]], MarcoArena.plain(Color(0.12, 0.14, 0.13), 0.6))
	add_outline_circle(Vector2(at.x, at.z), 1.25, 10)


func _build_plants() -> void:
	var colours := [Color(0.15, 0.6, 0.2), Color(0.3, 0.75, 0.15), Color(0.75, 0.15, 0.2), Color(0.5, 0.2, 0.6)]
	var spots := [Vector3(-36.0, 0.0, -14.0), Vector3(-30.0, 0.0, 16.0), Vector3(-8.0, 0.0, 16.0), Vector3(-14.0, 0.0, -14.0), Vector3(4.0, 0.0, -16.0),
			Vector3(10.0, 0.0, 4.0), Vector3(24.0, 0.0, 15.0), Vector3(36.0, 0.0, 6.0), Vector3(28.0, 0.0, -15.0), Vector3(-20.0, 0.0, 10.0),
			Vector3(-2.0, 0.0, -6.0), Vector3(16.0, 0.0, -4.0)]
	for n in spots.size():
		var material := MarcoArena.plain(colours[n % colours.size()], 0.4)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var tall := 5.0 + fposmod(n * 3.7, 8.0)
		var mesh := TankKit.cached("tank/plant/%d" % n, func() -> MeshKit: return TankKit.plant(10 + n % 6, tall, 900 + n), material)
		add_visual(mesh, Transform3D(Basis(Vector3.UP, _dice.randf() * TAU), spots[n]))


func _build_bubbles() -> void:
	var back := -size.z * 0.5 + 1.8
	var left := BubbleCurtain.new()
	left.name = "AirstoneLeft"
	left.extent = Vector3(26.0, size.y, 2.5)
	left.position = Vector3(-22.0, 0.0, back)
	add_curtain(left)
	var right := BubbleCurtain.new()
	right.name = "AirstoneRight"
	right.extent = Vector3(26.0, size.y, 2.5)
	right.on_time = 9.0
	right.off_time = 7.0
	right.position = Vector3(22.0, 0.0, back)
	add_curtain(right)
	var wand := BubbleCurtain.new()
	wand.name = "BubbleWand"
	wand.extent = Vector3(22.0, size.y, 1.5)
	wand.on_time = 6.0
	wand.off_time = 6.0
	wand.offset = 3.0
	wand.position = Vector3(-20.0, 0.0, 13.0)
	add_curtain(wand)
	# The wand itself: a long airstone bar in the gravel.
	var bar := CylinderMesh.new()
	bar.top_radius = 0.25
	bar.bottom_radius = 0.25
	bar.height = 22.0
	add_visual(bar, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(-20.0, 0.2, 13.0)), MarcoArena.plain(Color(0.6, 0.6, 0.62), 0.9))


func _place_markers() -> void:
	set_seeker_start(Vector3(0.0, 8.0, 16.0), Vector3(0.0, 0.0, -1.0))
	var spots := [[Vector3(-34.0, 3.0, -8.0), Vector3(1, 0, 0)], [Vector3(-24.0, 3.0, -4.0), Vector3(0, 0, 1)], [Vector3(-12.0, 3.0, -16.0), Vector3(1, 0, 0)],
			[Vector3(4.0, 3.0, -15.0), Vector3(0, 0, 1)], [Vector3(20.0, 10.0, -14.0), Vector3(-1, 0, 0)], [Vector3(34.0, 3.0, 10.0), Vector3(-1, 0, 0)],
			[Vector3(10.0, 3.0, 0.0), Vector3(0, 0, 1)], [Vector3(-30.0, 3.0, 14.0), Vector3(1, 0, 0)]]
	for spot: Array in spots:
		add_hider_spawn(spot[0], spot[1])
