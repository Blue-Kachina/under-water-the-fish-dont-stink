class_name MarcoArena
extends Node3D
## The base of Marco Polo's walled, furnished, murky arenas (planning_marco_polo.md
## §12): the Sunken Temple (TempleArena) and the Aquarium (FishTankArena). Each
## one builds its own walls, floor, ceiling and furniture in _build(), all with
## real collision on the sight-blocker layer (the line-of-sight rays test it),
## marks the hider spawns and the seeker's start, sets its portholes (Porthole),
## its bubble curtains (BubbleCurtain) and its murk.
##
## main.gd plays it like any other environment: spawn_transform() and
## configure_environment(env). Its fog is put back when it leaves the tree, since
## the environment outlives it.
##
## Units are metres. The floor is y = 0 and the arena is centred on x and z.

## Every wall and piece of furniture is on this collision layer as well as the
## default one: the sight rays (MarcoPoloMatch) test only it, so fish never block.
const BLOCKER_LAYER := 1 << 5
const HIDER_SPAWN_GROUP := &"mp_hider_spawn"
const SEEKER_START_GROUP := &"mp_seeker_start"
const PORTHOLE_GROUP := &"mp_porthole"
## The murk's sight distance is where this much of a lit fish's colour is left.
const SIGHT_LEFT := 0.05

## The water's inside: x across, y up from the floor, z along.
var size := Vector3(90.0, 30.0, 70.0)
## The murk: the fog's density and colour, the background past it, and the light
## the water itself gives off.
var murk_density := 0.05
var murk_color := Color(0.05, 0.18, 0.17)
var background_color := Color(0.01, 0.05, 0.06)
var ambient_color := Color(0.3, 0.48, 0.45)
var ambient_energy := 0.55

var _env: Environment
## What configure_environment() changed, to put back: property -> value.
var _saved := {}
var _portholes: Array[Porthole] = []
var _curtains: Array[BubbleCurtain] = []
var _outlines: Array[PackedVector2Array] = []
var _hider_spawns: Array[Transform3D] = []
var _seeker_start := Transform3D.IDENTITY


func _ready() -> void:
	_build()


## Builds the arena (each arena's own).
func _build() -> void:
	pass


# --- The environment interface (main.gd) ------------------------------------------

func spawn_transform() -> Transform3D:
	return seeker_start()


func configure_environment(env: Environment) -> void:
	_env = env
	for property: String in ["background_mode", "background_color", "sky", "fog_enabled", "fog_light_color", "fog_density",
			"fog_sky_affect", "ambient_light_source", "ambient_light_color", "ambient_light_energy"]:
		_saved[property] = env.get(property)
	env.background_mode = Environment.BG_COLOR
	env.background_color = background_color
	env.sky = null
	env.fog_enabled = true
	env.fog_light_color = murk_color
	env.fog_density = murk_density
	env.fog_sky_affect = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy


## The environment it configured (null before configure_environment()).
func environment() -> Environment:
	return _env


## The fog as set: [colour, density].
func fog_base() -> Array:
	return [murk_color, murk_density]


func _exit_tree() -> void:
	if _env:
		for property: String in _saved:
			_env.set(property, _saved[property])


# --- What Marco Polo asks of it ------------------------------------------------------

## Where hiders start a round (world).
func hider_spawns() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for xform in _hider_spawns:
		out.append(global_transform * xform)
	return out


## Where the seeker counts, facing away from where the hiders scatter (world).
func seeker_start() -> Transform3D:
	return global_transform * _seeker_start


func portholes() -> Array[Porthole]:
	return _portholes.duplicate()


func curtains() -> Array[BubbleCurtain]:
	return _curtains.duplicate()


## The water's floor plan in world x/z (position = the low corner).
func map_rect() -> Rect2:
	var half := Vector2(size.x, size.z) * 0.5
	return Rect2(global_position.x - half.x, global_position.z - half.y, size.x, size.z)


## The walls and big furniture as closed outlines in world x/z, for the sonar map.
func map_outlines() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for outline in _outlines:
		var moved := PackedVector2Array()
		for p in outline:
			moved.append(p + Vector2(global_position.x, global_position.z))
		out.append(moved)
	return out


## How far a seeker can see through the murk (m): where SIGHT_LEFT of the
## colour is left under exponential fog.
func sight_range() -> float:
	return -log(SIGHT_LEFT) / maxf(murk_density, 0.0001)


## How much of a hider's noise gets out at `pos`: 1, or the bubble_mask setting
## inside a working bubble curtain.
func bubble_mask_at(pos: Vector3) -> float:
	for curtain in _curtains:
		if curtain.masks(pos):
			return MarcoPoloSettings.shared().bubble_mask
	return 1.0


## Where the bubbles fizz now (the scope's clutter): each working curtain's spots.
func bubble_sources() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for curtain in _curtains:
		if curtain.active:
			out.append_array(curtain.sources())
	return out


func sight_blockers_mask() -> int:
	return BLOCKER_LAYER


## Whether `pos` is in the water (inside the walls, floor and ceiling).
func contains(pos: Vector3, margin := 0.0) -> bool:
	var local := pos - global_position
	return absf(local.x) < size.x * 0.5 - margin and absf(local.z) < size.z * 0.5 - margin \
			and local.y > margin and local.y < size.y - margin


# --- Building helpers ----------------------------------------------------------------

## A solid piece: `mesh` drawn at `xform` (if any), and `shapes` ([Shape3D,
## Transform3D] pairs, in the piece's space) as its collision. A uniform scale
## in `xform` scales the mesh and the shapes; the body itself stays unscaled
## (physics doesn't like scaled bodies).
func add_solid(mesh: Mesh, xform: Transform3D, shapes: Array, material: Material = null, shadows := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 | BLOCKER_LAYER
	body.collision_mask = 0
	var s := xform.basis.get_scale().x
	body.transform = Transform3D(xform.basis.orthonormalized(), xform.origin)
	for pair: Array in shapes:
		var collision := CollisionShape3D.new()
		var shape: Shape3D = pair[0]
		var place: Transform3D = pair[1]
		if not is_equal_approx(s, 1.0):
			if shape is BoxShape3D:
				(shape as BoxShape3D).size *= s
			elif shape is CylinderShape3D:
				(shape as CylinderShape3D).radius *= s
				(shape as CylinderShape3D).height *= s
			elif shape is SphereShape3D:
				(shape as SphereShape3D).radius *= s
			place.origin *= s
		collision.shape = shape
		collision.transform = place
		body.add_child(collision)
	if mesh:
		var view := MeshInstance3D.new()
		view.mesh = mesh
		view.scale = Vector3.ONE * s
		if material:
			view.material_override = material
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(view)
	add_child(body)
	return body


## Something to look at with no collision.
func add_visual(mesh: Mesh, xform: Transform3D, material: Material = null, shadows := false) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.transform = xform
	if material:
		view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	return view


## An invisible box of collision, `box` big, centred at `xform`.
func add_box_collider(xform: Transform3D, box: Vector3) -> StaticBody3D:
	return add_solid(null, xform, [[box_shape(box), Transform3D.IDENTITY]])


static func box_shape(box: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = box
	return shape


static func cylinder_shape(radius: float, tall: float) -> CylinderShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = tall
	return shape


## Copies of `mesh` at `transforms`, drawn as one MultiMesh (no collision).
func add_multimesh(mesh: Mesh, transforms: Array[Transform3D], material: Material = null, shadows := false) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var view := MultiMeshInstance3D.new()
	view.multimesh = multimesh
	if material:
		view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	return view


## The four walls, the floor and the ceiling as collision, `thick` m thick, just
## outside `size`.
func add_shell_colliders(thick := 2.0) -> void:
	var half := size * 0.5
	add_box_collider(Transform3D(Basis(), Vector3(0.0, -thick * 0.5, 0.0)), Vector3(size.x + thick * 2.0, thick, size.z + thick * 2.0))
	add_box_collider(Transform3D(Basis(), Vector3(0.0, size.y + thick * 0.5, 0.0)), Vector3(size.x + thick * 2.0, thick, size.z + thick * 2.0))
	add_box_collider(Transform3D(Basis(), Vector3(half.x + thick * 0.5, half.y, 0.0)), Vector3(thick, size.y, size.z))
	add_box_collider(Transform3D(Basis(), Vector3(-half.x - thick * 0.5, half.y, 0.0)), Vector3(thick, size.y, size.z))
	add_box_collider(Transform3D(Basis(), Vector3(0.0, half.y, half.z + thick * 0.5)), Vector3(size.x, size.y, thick))
	add_box_collider(Transform3D(Basis(), Vector3(0.0, half.y, -half.z - thick * 0.5)), Vector3(size.x, size.y, thick))
	add_outline_rect(Vector2.ZERO, Vector2(size.x, size.z))


## A porthole at `at` (arena space) opening along `axis` (out into the water),
## `radius` m across its opening as drawn.
func add_porthole(at: Vector3, axis: Vector3, radius: float, look := Porthole.Look.NICHE, frame: Material = null) -> Porthole:
	var porthole := Porthole.new()
	porthole.name = "Porthole%d" % _portholes.size()
	porthole.look = look
	porthole.frame_material = frame
	porthole.radius = radius
	var out := axis.normalized()
	var up := Vector3.UP if absf(out.y) < 0.9 else Vector3.BACK
	porthole.transform = Transform3D(Basis.looking_at(-out, up), at)  # -Z into the wall, +Z out
	porthole.add_to_group(PORTHOLE_GROUP)
	add_child(porthole)
	_portholes.append(porthole)
	return porthole


func add_curtain(curtain: BubbleCurtain) -> BubbleCurtain:
	add_child(curtain)
	_curtains.append(curtain)
	return curtain


func add_hider_spawn(at: Vector3, facing: Vector3) -> void:
	var xform := Transform3D(Basis.looking_at(facing.normalized(), Vector3.UP), at)
	_hider_spawns.append(xform)
	var marker := Marker3D.new()
	marker.name = "HiderSpawn%d" % _hider_spawns.size()
	marker.transform = xform
	marker.add_to_group(HIDER_SPAWN_GROUP)
	add_child(marker)


func set_seeker_start(at: Vector3, facing: Vector3) -> void:
	_seeker_start = Transform3D(Basis.looking_at(facing.normalized(), Vector3.UP), at)
	var marker := Marker3D.new()
	marker.name = "SeekerStart"
	marker.transform = _seeker_start
	marker.add_to_group(SEEKER_START_GROUP)
	add_child(marker)


## A rectangle `extent` big round `centre` (x/z), turned `angle` rad, on the map.
func add_outline_rect(centre: Vector2, extent: Vector2, angle := 0.0) -> void:
	var half := extent * 0.5
	var outline := PackedVector2Array()
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		outline.append(centre + corner.rotated(angle))
	_outlines.append(outline)


func add_outline_circle(centre: Vector2, radius: float, sides := 20) -> void:
	var outline := PackedVector2Array()
	for n in sides:
		outline.append(centre + Vector2.from_angle(TAU * n / sides) * radius)
	_outlines.append(outline)


## A plain lit material (the furniture that isn't marble or bronze).
static func plain(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.vertex_color_use_as_albedo = false
	return material


## A glowing, see-through, additive material (light shafts, bubbles' glints).
static func glow(color: Color, energy := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, color.a)
	return material
