class_name TreasureChest
extends Node3D
## A chest buried in Unnatural's seabed (planning_unnatural.md §7, D4): half
## sunk in the sand, found by its faint glow and the bubbles rising from it
## (and the HUD's ping, near enough). UnnaturalRun opens it when a player
## batters it or holds still beside it; it then pops its lid with a flash and
## its glow goes out.

const GOLD := Color(1.0, 0.78, 0.25)
const WOOD := Color(0.32, 0.18, 0.08)
const SIZE := Vector3(1.4, 0.9, 0.95)

var opened := false
## How far through being opened by holding still (0..1), for the HUD.
var progress := 0.0

var _lid := Node3D.new()
var _light := OmniLight3D.new()
var _bubbles := CPUParticles3D.new()
var _glow := StandardMaterial3D.new()
var _age := 0.0
var _open_age := -1.0


func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = WOOD
	wood.roughness = 0.8
	_glow.albedo_color = GOLD
	_glow.metallic = 0.8
	_glow.roughness = 0.3
	_glow.emission_enabled = true
	_glow.emission = GOLD
	_glow.emission_energy_multiplier = 1.2
	var body := _box(Vector3(SIZE.x, SIZE.y * 0.6, SIZE.z), wood)
	body.position.y = SIZE.y * 0.3
	add_child(body)
	for x: float in [-0.5, 0.5]:
		var band := _box(Vector3(0.1, SIZE.y * 0.62, SIZE.z + 0.04), _glow)
		band.position = Vector3(x * SIZE.x * 0.7, SIZE.y * 0.3, 0.0)
		add_child(band)
	_lid.position = Vector3(0.0, SIZE.y * 0.6, -SIZE.z * 0.5)  # hinged at the back
	add_child(_lid)
	var lid := _box(Vector3(SIZE.x, SIZE.y * 0.35, SIZE.z), wood)
	lid.position = Vector3(0.0, SIZE.y * 0.175, SIZE.z * 0.5)
	_lid.add_child(lid)
	var lock := _box(Vector3(0.22, 0.25, 0.08), _glow)
	lock.position = Vector3(0.0, 0.0, SIZE.z + 0.03)
	_lid.add_child(lock)
	_light.light_color = GOLD
	_light.light_energy = 1.0
	_light.omni_range = 5.0
	_light.position.y = 1.2
	add_child(_light)
	_bubbles.amount = 16
	_bubbles.lifetime = 4.0
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_bubbles.emission_box_extents = Vector3(SIZE.x * 0.4, 0.1, SIZE.z * 0.4)
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 12.0
	_bubbles.gravity = Vector3(0.0, 1.2, 0.0)
	_bubbles.initial_velocity_min = 0.6
	_bubbles.initial_velocity_max = 1.4
	_bubbles.scale_amount_min = 0.6
	_bubbles.scale_amount_max = 1.4
	var bubble := SphereMesh.new()
	bubble.radius = 0.05
	bubble.height = 0.1
	bubble.radial_segments = 6
	bubble.rings = 3
	var foam := StandardMaterial3D.new()
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.albedo_color = Color(0.85, 0.95, 1.0, 0.5)
	bubble.material = foam
	_bubbles.mesh = bubble
	_bubbles.position.y = SIZE.y
	add_child(_bubbles)


## Pops it open.
func open() -> void:
	if opened:
		return
	opened = true
	progress = 1.0
	_open_age = 0.0
	_bubbles.emitting = false
	Explosion.spawn(get_parent(), global_position + Vector3.UP, GOLD, 2.5, 0.0, 0.4)


func _process(delta: float) -> void:
	_age += delta
	if opened:
		_open_age += delta
		_lid.rotation.x = -lerpf(0.0, 1.9, clampf(_open_age / 0.35, 0.0, 1.0))
		var fade := clampf(1.0 - _open_age / 1.5, 0.0, 1.0)
		_light.light_energy = 3.0 * fade
		_glow.emission_energy_multiplier = 0.2 + 2.0 * fade
		return
	var pulse := 0.75 + 0.25 * sin(_age * 2.2)
	_light.light_energy = (1.0 + 2.0 * progress) * pulse
	_glow.emission_energy_multiplier = (1.0 + 2.0 * progress) * pulse
	_lid.rotation.x = -0.25 * progress + 0.03 * sin(_age * 9.0) * progress


func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	return mesh
