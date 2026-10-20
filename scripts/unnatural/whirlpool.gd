class_name Whirlpool
extends Node3D
## The way out: it opens where the final boss fell. Beating the boss doesn't end
## the run; entering this does (UnnaturalRun.enter_whirlpool). A column of
## spinning foam rings round a pale core runs from the seabed (this node's
## origin) up to the surface, `height` m, narrowing towards the bottom, each
## ring faster than the last.

const RING_GAP := 2.5
const RADIUS := 7.0
const COLOR := Color(0.55, 0.9, 1.0)

## How tall the column is (m): the whole arena, floor to ceiling.
var height := 40.0

var _rings: Array[MeshInstance3D] = []
var _age := 0.0


func _ready() -> void:
	name = "Whirlpool"
	var count := maxi(ceili(height / RING_GAP), 2)
	for n in count:
		var t := float(n) / (count - 1)  # 0 at the seabed, 1 at the surface
		var radius := RADIUS * lerpf(0.45, 1.0, t)
		var torus := TorusMesh.new()
		torus.outer_radius = radius
		torus.inner_radius = radius * 0.82
		torus.rings = 32
		torus.ring_segments = 8
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = _glass(0.55)
		ring.position.y = t * height
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rings.append(ring)
	var core := CylinderMesh.new()
	core.top_radius = RADIUS * 0.9
	core.bottom_radius = RADIUS * 0.4
	core.height = height
	core.radial_segments = 24
	core.rings = 1
	var column := MeshInstance3D.new()
	column.mesh = core
	column.material_override = _glass(0.12)
	column.position.y = height * 0.5
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(column)
	for t in [0.15, 0.5, 0.85]:
		var light := OmniLight3D.new()
		light.light_color = COLOR
		light.light_energy = 2.0
		light.omni_range = RADIUS * 3.0
		light.position.y = height * t
		add_child(light)


func _process(delta: float) -> void:
	_age += delta
	for n in _rings.size():
		var ring := _rings[n]
		ring.rotation.y += delta * (1.2 + (n % 5) * 0.7)
		var pulse := 1.0 + 0.06 * sin(_age * 2.0 + n)
		ring.scale = Vector3(pulse, 1.0, pulse)


func _glass(alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(COLOR, alpha)
	material.emission_enabled = true
	material.emission = COLOR
	material.emission_energy_multiplier = 0.8
	return material
