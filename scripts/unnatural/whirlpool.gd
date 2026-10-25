class_name Whirlpool
extends Node3D
## The way out: it opens where the final boss fell. Beating the boss doesn't end
## the run; entering this does (UnnaturalRun.enter_whirlpool). A funnel of
## water (planning_environment.md, Phase 6) runs from the seabed (this node's
## origin) up to the surface, `height` m, widening as it rises, foam
## spiralling down its wall faster near the throat, bubbles and grit drawn
## round and in.

const RING_GAP := 2.5
const RADIUS := 7.0
const COLOR := Color(0.55, 0.9, 1.0)

## How tall the column is (m): the whole arena, floor to ceiling.
var height := 40.0
## How wide it is at its lip, as a share of RADIUS (Whirlpool Charm's are small).
var scale_share := 1.0

var _funnel := MeshInstance3D.new()
var _inner := MeshInstance3D.new()
var _bubbles := CPUParticles3D.new()
var _age := 0.0


## A funnel `tall` m high, `lip` m round at its top and `throat` at its foot,
## open both ends.
static func funnel_mesh(tall: float, lip: float, throat: float) -> ArrayMesh:
	var profile := PackedVector2Array()
	for n in 17:
		var t := n / 16.0
		profile.append(Vector2(lerpf(throat, lip, pow(t, 1.6)), t * tall))
	var kit := MeshKit.new()
	kit.lathe(profile, 48, Callable(), false, false)
	return kit.mesh()


func _ready() -> void:
	name = "Whirlpool"
	var lip := RADIUS * scale_share
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/vortex.gdshader")
	material.set_shader_parameter("color", Vector3(COLOR.r, COLOR.g, COLOR.b))
	material.set_shader_parameter("tall", height)
	_funnel.mesh = funnel_mesh(height, lip, lip * 0.22)
	_funnel.material_override = material
	_funnel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_funnel)
	# A second, narrower wall inside, turning faster: depth to the swirl.
	var inner := material.duplicate() as ShaderMaterial
	inner.set_shader_parameter("spin", 2.1)
	inner.set_shader_parameter("strength", 0.6)
	_inner.mesh = funnel_mesh(height, lip * 0.62, lip * 0.12)
	_inner.material_override = inner
	_inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_inner)
	var bubble := QuadMesh.new()
	bubble.size = Vector2.ONE * 0.16
	var shine := FxKit.glow(Color(0.85, 0.97, 1.0, 0.8), FxKit.band(), true)
	shine.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	bubble.material = shine
	_bubbles.mesh = bubble
	_bubbles.amount = roundi(90 * scale_share) + 10
	_bubbles.lifetime = 3.0
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_bubbles.emission_ring_axis = Vector3.UP
	_bubbles.emission_ring_radius = lip * 0.9
	_bubbles.emission_ring_inner_radius = lip * 0.4
	_bubbles.emission_ring_height = height * 0.9
	_bubbles.position.y = height * 0.5
	_bubbles.gravity = Vector3(0.0, -1.5, 0.0)
	_bubbles.orbit_velocity_min = 0.25
	_bubbles.orbit_velocity_max = 0.45
	_bubbles.radial_accel_min = -2.0
	_bubbles.radial_accel_max = -1.0
	_bubbles.scale_amount_min = 0.6
	_bubbles.scale_amount_max = 1.6
	_bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bubbles)
	for t in [0.15, 0.5, 0.85]:
		var light := OmniLight3D.new()
		light.light_color = COLOR
		light.light_energy = 2.0 * scale_share
		light.omni_range = lip * 3.0
		light.position.y = height * t
		add_child(light)


func _process(delta: float) -> void:
	_age += delta
	var breathe := 1.0 + 0.04 * sin(_age * 2.0)
	_funnel.scale = Vector3(breathe, 1.0, breathe)
	_funnel.rotation.y -= delta * 0.4
	_inner.rotation.y -= delta * 0.9
