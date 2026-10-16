class_name Swirl
extends MeshInstance3D
## A ring of water a stride sheds from the tail (FishController, Extra Swishy):
## left where it was made, it spreads, drifts on along `drift` and fades. A
## strong stride makes a big, bright one; a perfect one is gold.

const LIFETIME := 1.3
## How much wider it gets over its life.
const SPREAD := 1.8
const COOL := Color(0.72, 0.93, 1.0)
const GOLD := Color(1.0, 0.85, 0.4)
const SHADER := preload("res://shaders/swirl.gdshader")

static var _mesh: TorusMesh
static var _material: ShaderMaterial

var _age := 0.0
var _size := 1.0
var _drift := Vector3.ZERO
var _strength := 1.0


## A swirl at `at`, its ring facing along `axis`, `size` m across, moving
## `drift` (m/s). `strength` 0..1 sets how bright it starts; `perfect` makes it gold.
static func spawn(parent: Node, at: Vector3, axis: Vector3, size: float, drift: Vector3, strength: float, perfect: bool) -> Swirl:
	if _mesh == null:
		_mesh = TorusMesh.new()
		_mesh.inner_radius = 0.38
		_mesh.outer_radius = 0.5
		_mesh.rings = 24
		_mesh.ring_segments = 8
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	var swirl := Swirl.new()
	swirl.mesh = _mesh
	swirl.material_override = _material
	swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	swirl._size = size
	swirl._drift = drift
	swirl._strength = clampf(strength, 0.0, 1.0)
	swirl.set_instance_shader_parameter("tint", GOLD if perfect else COOL)
	parent.add_child(swirl)
	# The torus lies in its local XZ plane: its axis is local Y.
	var up := axis.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	swirl.global_transform = Transform3D(Basis(side, up, side.cross(up)), at)
	swirl._update()
	return swirl


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	global_position += _drift * delta
	_drift *= exp(-1.2 * delta)  # the water slows it
	_update()


func _update() -> void:
	var t := _age / LIFETIME
	var basis_now := global_basis.orthonormalized()
	global_basis = basis_now.scaled(Vector3.ONE * _size * lerpf(1.0, SPREAD, 1.0 - pow(1.0 - t, 2.0)))  # uniform
	set_instance_shader_parameter("fade", _strength * (1.0 - t) * minf(_age / 0.08, 1.0))
