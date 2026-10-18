class_name PowerupFx
extends MeshInstance3D
## A moment's glow for a powerup going off (an Electric Eel's shock ring, a
## Pufferfish's spine burst, a Remora's nip, a Bubble Wrap popping): it grows
## from a little to its full size and fades out. At most MAX shown at once (a
## big proc chain still hurts, unseen past it).

enum Shape { RING, BALL }

const MAX := 40

static var _shown := 0

var shape := Shape.BALL
var color := Color.WHITE
var size := 1.0
var life := 0.3
var _age := 0.0
var _material := StandardMaterial3D.new()


## A flat ring `radius` round `at` (on the plane facing `up`).
static func ring(parent: Node, at: Vector3, radius: float, ring_color: Color, up := Vector3.UP, seconds := 0.35) -> void:
	_show(parent, Shape.RING, at, radius, ring_color, seconds, up)


## A glowing ball `radius` round `at`.
static func flash(parent: Node, at: Vector3, radius: float, flash_color: Color, seconds := 0.25) -> void:
	_show(parent, Shape.BALL, at, radius, flash_color, seconds, Vector3.UP)


static func _show(parent: Node, kind: Shape, at: Vector3, radius: float, fx_color: Color, seconds: float, up: Vector3) -> void:
	if _shown >= MAX or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var fx := PowerupFx.new()
	fx.shape = kind
	fx.color = fx_color
	fx.size = radius
	fx.life = seconds
	_shown += 1
	fx.tree_exited.connect(func() -> void: _shown -= 1)
	parent.add_child(fx)
	fx.global_position = at
	var axis := up.normalized() if up.length_squared() > 0.0001 else Vector3.UP
	if absf(axis.dot(Vector3.UP)) < 0.999:
		fx.global_basis = Basis(Quaternion(Vector3.UP, axis))


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = color
	if shape == Shape.RING:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.9
		torus.outer_radius = 1.0
		torus.rings = 32
		torus.ring_segments = 4
		torus.material = _material
		mesh = torus
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		sphere.material = _material
		mesh = sphere
	_process(0.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	var t := _age / life
	var grown := size * (0.3 + 0.7 * sqrt(t))
	scale = Vector3(grown, grown * (1.0 if shape == Shape.BALL else 4.0), grown)
	_material.albedo_color = Color(color, (1.0 - t) * (0.5 if shape == Shape.BALL else 0.9))
