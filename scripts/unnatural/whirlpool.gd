class_name Whirlpool
extends Node3D
## The way out: it opens where the final boss fell. Beating the boss doesn't end
## the run; entering this does (UnnaturalRun.enter_whirlpool). Rings of foam spin
## round a dark funnel, faster the closer you swim.

const RINGS := 5
const RADIUS := 7.0
const COLOR := Color(0.55, 0.9, 1.0)

var _rings: Array[MeshInstance3D] = []
var _age := 0.0


func _ready() -> void:
	name = "Whirlpool"
	for n in RINGS:
		var torus := TorusMesh.new()
		var scale_of := 1.0 - float(n) / RINGS * 0.75
		torus.outer_radius = RADIUS * scale_of
		torus.inner_radius = RADIUS * scale_of * 0.82
		torus.rings = 32
		torus.ring_segments = 8
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(COLOR, 0.55)
		material.emission_enabled = true
		material.emission = COLOR
		material.emission_energy_multiplier = 0.8
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = material
		ring.position.y = -float(n) * 1.1
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rings.append(ring)
	var light := OmniLight3D.new()
	light.light_color = COLOR
	light.light_energy = 2.0
	light.omni_range = RADIUS * 3.0
	add_child(light)


func _process(delta: float) -> void:
	_age += delta
	for n in _rings.size():
		var ring := _rings[n]
		ring.rotation.y += delta * (1.2 + n * 0.7)
		var pulse := 1.0 + 0.06 * sin(_age * 2.0 + n)
		ring.scale = Vector3(pulse, 1.0, pulse)
