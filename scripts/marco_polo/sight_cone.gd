class_name SightCone
extends Node3D
## Marco Polo's line of sight (planning_marco_polo.md §6): whether a hider is
## in a seeker's direct line of sight, visible or not. That's all of: inside the
## sight cone (los_cone_angle round the seeker's view, los_cone_vertical up
## and down if set), closer than the sight range, and a clear ray from the
## seeker's eye to the hider's body, nose or tail (any one counts). Being in a
## porthole is the match's business.
##
## As a node it's the DEBUG drawing (debug_show_los_cone): each seeking
## seeker's cone as a faint wireframe, each hider's sight ray (green when it
## counts, red when blocked, grey outside the cone or range) and "+n/s" over
## each scoring hider. MarcoPoloMatch keeps one and feeds it each tick (draw()).

const RAY_COUNTS := Color(0.3, 1.0, 0.4, 0.9)
const RAY_BLOCKED := Color(1.0, 0.3, 0.25, 0.9)
const RAY_OUTSIDE := Color(0.6, 0.6, 0.6, 0.5)
const CONE_COLOR := Color(0.9, 0.95, 1.0, 0.35)
## Segments round the cone's rim.
const RIM_SEGMENTS := 24

var _mesh := ImmediateMesh.new()
var _view := MeshInstance3D.new()
var _labels: Array[Label3D] = []


## Where `point` sits in a cone looking along `view`'s -Z from `eye`: -1 when
## outside it (or past `reach`), else 0 (dead centre) to 1 (its edge), the
## larger of the angle's and the distance's shares.
static func cone_share(view: Basis, eye: Vector3, point: Vector3, settings: MarcoPoloSettings, reach: float) -> float:
	var to := point - eye
	var distance := to.length()
	if distance > reach:
		return -1.0
	if distance < 0.001:
		return 0.0
	var local := view.orthonormalized().inverse() * to
	var half := deg_to_rad(settings.los_cone_angle) * 0.5
	var angle_share := 0.0
	if settings.los_cone_vertical > 0.0:
		var yaw := absf(atan2(local.x, -local.z))
		var pitch := absf(atan2(local.y, Vector2(local.x, local.z).length()))
		var half_v := deg_to_rad(settings.los_cone_vertical) * 0.5
		if yaw > half or pitch > half_v:
			return -1.0
		angle_share = maxf(yaw / maxf(half, 0.001), pitch / maxf(half_v, 0.001))
	else:
		var off := (-local.z / distance)
		var angle := acos(clampf(off, -1.0, 1.0))
		if angle > half:
			return -1.0
		angle_share = angle / maxf(half, 0.001)
	return maxf(angle_share, distance / maxf(reach, 0.001))


## Whether a ray from `eye` reaches any of `points` without hitting anything
## on `mask` but what's in `exclude` (RIDs: the fish).
static func clear_line(space: PhysicsDirectSpaceState3D, eye: Vector3, points: PackedVector3Array, exclude: Array[RID], mask: int) -> bool:
	for point in points:
		var query := PhysicsRayQueryParameters3D.create(eye, point, mask, exclude)
		query.collide_with_areas = false
		if space.intersect_ray(query).is_empty():
			return true
	return false


## A fish's body, nose and tail (world), from its hitbox.
static func body_points(fish: FishController) -> PackedVector3Array:
	var half := 0.6
	var hitbox := fish.get_node_or_null("Collision") as CollisionShape3D
	if hitbox and hitbox.shape is BoxShape3D:
		half = (hitbox.shape as BoxShape3D).size.z * 0.45
	var forward := -fish.global_basis.z
	var at := fish.global_position
	return PackedVector3Array([at, at + forward * half, at - forward * half])


func _ready() -> void:
	_view.mesh = _mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	_view.material_override = material
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_view)


## Draws `cones` ([{eye, view: Basis, reach}]) and `rays` ([{from, to, state:
## "counts" / "blocked" / "outside", rate}]), or clears it all (both empty).
func draw(settings: MarcoPoloSettings, cones: Array, rays: Array) -> void:
	_mesh.clear_surfaces()
	var scoring := 0
	if not cones.is_empty() or not rays.is_empty():
		_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for cone: Dictionary in cones:
			_add_cone(settings, cone.eye, cone.view, cone.reach)
		for ray: Dictionary in rays:
			var color := RAY_OUTSIDE
			match String(ray.state):
				"counts":
					color = RAY_COUNTS
				"blocked":
					color = RAY_BLOCKED
			_mesh.surface_set_color(color)
			_mesh.surface_add_vertex(ray.from)
			_mesh.surface_set_color(color)
			_mesh.surface_add_vertex(ray.to)
		_mesh.surface_end()
		for ray: Dictionary in rays:
			if String(ray.state) != "counts":
				continue
			var label := _label(scoring)
			label.text = "+%.1f/s" % float(ray.rate)
			label.global_position = (ray.to as Vector3) + Vector3.UP * 1.2
			label.visible = true
			scoring += 1
	for i in range(scoring, _labels.size()):
		_labels[i].visible = false


func _label(i: int) -> Label3D:
	while _labels.size() <= i:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 48
		label.pixel_size = 0.01
		label.modulate = RAY_COUNTS
		add_child(label)
		_labels.append(label)
	return _labels[i]


func _add_cone(settings: MarcoPoloSettings, eye: Vector3, view: Basis, reach: float) -> void:
	var basis := view.orthonormalized()
	var half_h := deg_to_rad(settings.los_cone_angle) * 0.5
	var half_v := deg_to_rad(settings.los_cone_vertical) * 0.5 if settings.los_cone_vertical > 0.0 else half_h
	var rim := PackedVector3Array()
	for i in RIM_SEGMENTS:
		var a := TAU * float(i) / RIM_SEGMENTS
		var yaw := cos(a) * half_h
		var pitch := sin(a) * half_v
		var local := Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
		rim.append(eye + basis * local * reach)
	for i in RIM_SEGMENTS:
		_mesh.surface_set_color(CONE_COLOR)
		_mesh.surface_add_vertex(rim[i])
		_mesh.surface_set_color(CONE_COLOR)
		_mesh.surface_add_vertex(rim[(i + 1) % RIM_SEGMENTS])
		if i % 6 == 0:
			_mesh.surface_set_color(CONE_COLOR)
			_mesh.surface_add_vertex(eye)
			_mesh.surface_set_color(CONE_COLOR)
			_mesh.surface_add_vertex(rim[i])
