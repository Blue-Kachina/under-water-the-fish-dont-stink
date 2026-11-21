class_name Pickup
extends Node3D
## A drop from a kill in Unnatural (planning_unnatural.md round 2), shared: the
## first player to touch it takes it (UnnaturalRun applies it):
## - HEART: heals every player who's up by heart_heal of their max hp (D12);
## - MAGNET: every XP pearl out flies to the taker;
## - HOURGLASS: every zombie stops dead for hourglass_time;
## - LIGHTNING: a shock across the whole arena kills every zombie (not bosses).
## A glowing token that turns and bobs where it fell, drawn to a player close
## by. It never fades. Each has its own shape and colour (P3: no two alike),
## a halo the fog doesn't dim, and a beam of its colour standing up from it
## (pickup_beam m tall) to spot it through the murk; the HUD pings it.

signal taken(pickup: Pickup, by: FishController)

enum Kind { HEART, MAGNET, HOURGLASS, LIGHTNING }

const NAMES := ["HEART", "MAGNET", "HOURGLASS", "LIGHTNING"]
## Rose red, violet, ice blue, gold.
const COLORS := [Color(1.0, 0.22, 0.32), Color(0.72, 0.42, 1.0), Color(0.55, 0.85, 1.0), Color(1.0, 0.88, 0.2)]
const BEAM_SHADER := preload("res://shaders/pickup_beam.gdshader")
## Within this (m) it's drawn to a player; within TAKE_REACH it's taken.
const PULL_REACH := 4.0
const TAKE_REACH := 1.4
const PULL := 14.0

var kind := Kind.HEART
## Its number in the run, the same on every machine online.
var id := -1
## Who can take it here (this machine's players).
var collectors: Array[FishController] = []
## Its beam of light (null with pickup_beam 0).
var beam: MeshInstance3D

var _token := Node3D.new()
var _age := randf() * TAU
var _base := Vector3.ZERO
var _gone := false


func _ready() -> void:
	_base = global_position
	add_child(_token)
	var color: Color = COLORS[kind]
	var shine := StandardMaterial3D.new()
	shine.albedo_color = color
	shine.metallic = 0.5
	shine.roughness = 0.25
	shine.emission_enabled = true
	shine.emission = color
	shine.emission_energy_multiplier = 1.6
	# Modelled tokens (planning_environment.md, Phase 6, FxLooks).
	shine.clearcoat_enabled = true
	shine.rim_enabled = true
	shine.rim = 0.5
	match kind:
		Kind.HEART:
			_token.add_child(_mesh(FxLooks.heart(), shine, Vector3.ZERO))
		Kind.MAGNET:
			var silver := StandardMaterial3D.new()
			silver.albedo_color = Color(0.85, 0.88, 0.92)
			silver.metallic = 0.9
			silver.roughness = 0.2
			silver.emission_enabled = true
			silver.emission = Color(0.8, 0.85, 1.0)
			silver.emission_energy_multiplier = 0.6
			var parts := FxLooks.magnet()
			_token.add_child(_mesh(parts[0], shine, Vector3(0.0, 0.05, 0.0)))
			_token.add_child(_mesh(parts[1], silver, Vector3(0.0, 0.05, 0.0)))
		Kind.HOURGLASS:
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(color, 0.3)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.05
			glass.rim_enabled = true
			glass.emission_enabled = true
			glass.emission = color
			glass.emission_energy_multiplier = 0.6
			var sand := StandardMaterial3D.new()
			sand.albedo_color = Color(1.0, 0.8, 0.4)
			sand.emission_enabled = true
			sand.emission = Color(1.0, 0.75, 0.3)
			sand.emission_energy_multiplier = 1.0
			var brass := StandardMaterial3D.new()
			brass.albedo_color = Color(0.78, 0.6, 0.3)
			brass.metallic = 0.9
			brass.roughness = 0.3
			brass.emission_enabled = true
			brass.emission = Color(0.5, 0.35, 0.15)
			brass.emission_energy_multiplier = 0.4
			var parts := FxLooks.hourglass()
			_token.add_child(_mesh(parts[2], sand, Vector3.ZERO))
			_token.add_child(_mesh(parts[0], brass, Vector3.ZERO))
			_token.add_child(_mesh(parts[1], glass, Vector3.ZERO))
		Kind.LIGHTNING:
			_token.add_child(_mesh(FxLooks.bolt(), shine, Vector3.ZERO))
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 4.0
	add_child(light)
	# A soft halo, so it reads through the murk.
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.albedo_color = Color(color, 0.22)
	halo.no_depth_test = false
	halo.disable_fog = true
	var glow := _sphere(0.65, halo, Vector3.ZERO)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	var tall := UnnaturalSettings.shared().pickup_beam
	if tall > 0.0:
		var column := CylinderMesh.new()
		column.top_radius = 0.35
		column.bottom_radius = 0.35
		column.height = tall
		column.radial_segments = 10
		column.rings = 1
		column.cap_top = false
		column.cap_bottom = false
		var light_column := ShaderMaterial.new()
		light_column.shader = BEAM_SHADER
		light_column.set_shader_parameter("color", color)
		light_column.set_shader_parameter("height", tall)
		beam = _mesh(column, light_column, Vector3(0.0, tall * 0.5, 0.0))
		beam.name = "Beam"
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)


func _physics_process(delta: float) -> void:
	if _gone:
		return
	_age += delta
	var nearest: FishController = null
	var gap := INF
	for fish in collectors:
		if not is_instance_valid(fish) or fish.battered:
			continue
		var d := fish.global_position.distance_to(global_position)
		if d < gap:
			gap = d
			nearest = fish
	if nearest and gap <= TAKE_REACH:
		_gone = true
		taken.emit(self, nearest)
		queue_free()
		return
	if nearest and gap < PULL_REACH:
		_base = _base.move_toward(nearest.global_position, PULL * delta)
	global_position = _base + Vector3(0.0, sin(_age * 1.6) * 0.15, 0.0)
	_token.rotation.y += delta * 1.8


## Gone without anyone here taking it (taken elsewhere, online).
func vanish() -> void:
	_gone = true
	queue_free()


func _sphere(radius: float, material: Material, at: Vector3) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	return _mesh(sphere, material, at)



func _mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	return instance
