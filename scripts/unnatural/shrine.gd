class_name Shrine
extends Node3D
## A sunken shrine (planning_unnatural.md, "Playability pass" P5): a fixed spot
## on the stage's seabed, a ring of standing stones round a glowing altar with a
## column of light (its kind's colour) up through the murk. Swim over it and
## press Jump (UnnaturalRun.use_shrine()):
## - TIDE: hold its ring (shrine_tide_radius) for shrine_tide_time s while the
##   horde comes, and win a free chest;
## - CHANCE: pay pearls for a chance at an item (a few tries each);
## - DEEP: the stage gets harder (more elites), but bosses drop more chests;
## - PEARLS: every pearl out flies to the team.
## A spent shrine goes dark. UnnaturalRun keeps its state; this draws it.

enum Kind { TIDE, CHANCE, DEEP, PEARLS }
const NAMES := ["Shrine of the Tide", "Shrine of Chance", "Shrine of the Deep", "Shrine of Pearls"]
const COLORS := [Color(0.3, 0.75, 1.0), Color(1.0, 0.8, 0.3), Color(0.65, 0.25, 1.0), Color(0.92, 0.95, 1.0)]
const BEAM_SHADER := preload("res://shaders/pickup_beam.gdshader")
const BEAM_HEIGHT := 36.0
const STONES := 6
const STONE_RING := 2.6

var kind := Kind.TIDE
## Its place in the run's `shrines` (online's index).
var index := 0
## Used up for everyone (a Tide won, the Deep taken, the Pearls drawn).
var spent := false
## Chance: tries per player (fish -> count).
var tries := {}
## Tide: running, the seconds held so far, and seconds to its next wave.
var tide_active := false
var tide_held := 0.0
var tide_wave_left := 0.0
## The Tide's ring's radius (m), set by the run.
var ring_radius := 8.0

var _glow := StandardMaterial3D.new()
var _beam_material := ShaderMaterial.new()
var _ring: MeshInstance3D
var _ring_material := StandardMaterial3D.new()
var _light := OmniLight3D.new()
var _age := 0.0


static func title(shrine_kind: int) -> String:
	return NAMES[shrine_kind]


static func color_of(shrine_kind: int) -> Color:
	return COLORS[shrine_kind]


func tint() -> Color:
	return COLORS[kind]


func _ready() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.32, 0.34, 0.36)
	stone.roughness = 0.95
	var base := CylinderMesh.new()
	base.top_radius = 2.0
	base.bottom_radius = 2.4
	base.height = 0.6
	base.radial_segments = 12
	_add_mesh(base, stone, Vector3(0.0, 0.3, 0.0))
	var pillar := BoxMesh.new()
	pillar.size = Vector3(0.6, 3.2, 0.6)
	for n in STONES:
		var angle := TAU * n / STONES
		var part := _add_mesh(pillar, stone, Vector3(cos(angle), 0.0, sin(angle)) * STONE_RING + Vector3.UP * 1.6)
		part.rotation = Vector3(0.0, -angle, 0.12 * sin(n * 1.7))
	_glow.albedo_color = tint()
	_glow.emission_enabled = true
	_glow.emission = tint()
	_glow.emission_energy_multiplier = 2.5
	_glow.disable_fog = true
	var altar := SphereMesh.new()
	altar.radius = 0.7
	altar.height = 1.4
	altar.radial_segments = 12
	altar.rings = 6
	_add_mesh(altar, _glow, Vector3(0.0, 1.4, 0.0))
	var column := CylinderMesh.new()
	column.top_radius = 0.9
	column.bottom_radius = 0.9
	column.height = BEAM_HEIGHT
	column.radial_segments = 12
	column.rings = 1
	column.cap_top = false
	column.cap_bottom = false
	_beam_material.shader = BEAM_SHADER
	_beam_material.set_shader_parameter("color", tint())
	_beam_material.set_shader_parameter("height", BEAM_HEIGHT)
	_beam_material.set_shader_parameter("far", 220.0)
	_add_mesh(column, _beam_material, Vector3(0.0, BEAM_HEIGHT * 0.5, 0.0))
	# The Tide's ring on the sand: shown while it runs.
	var torus := TorusMesh.new()
	torus.inner_radius = 0.96
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 4
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_material.disable_fog = true
	_ring_material.albedo_color = Color(tint(), 0.8)
	_ring = _add_mesh(torus, _ring_material, Vector3(0.0, 0.4, 0.0))
	_ring.visible = false
	_light.light_color = tint()
	_light.light_energy = 2.0
	_light.omni_range = 9.0
	_light.position = Vector3(0.0, 2.0, 0.0)
	add_child(_light)


func _process(delta: float) -> void:
	_age += delta
	var pulse := 0.5 + 0.5 * sin(_age * 2.2)
	if spent:
		_glow.emission_energy_multiplier = 0.15
		_beam_material.set_shader_parameter("strength", 0.0)
		_light.light_energy = 0.0
	else:
		_glow.emission_energy_multiplier = 1.8 + pulse * 1.4 + (2.0 if tide_active else 0.0)
		_beam_material.set_shader_parameter("strength", 0.5 + (0.6 if tide_active else 0.0))
		_light.light_energy = 1.5 + pulse
	_ring.visible = tide_active
	if tide_active:
		_ring.scale = Vector3(ring_radius, 3.0, ring_radius)
		_ring_material.albedo_color = Color(tint(), 0.45 + 0.35 * pulse)


## Whether `point` is over it (anywhere up its column), within `reach` m.
func is_over(point: Vector3, reach: float) -> bool:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() <= reach


func _add_mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	return part
