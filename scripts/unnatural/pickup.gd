class_name Pickup
extends Node3D
## A drop from a kill in Unnatural (planning_unnatural.md round 2), shared: the
## first player to touch it takes it (UnnaturalRun applies it):
## - HEART: heals every player who's up by heart_heal of their max hp (D12);
## - MAGNET: every XP pearl out flies to the taker;
## - HOURGLASS: every zombie stops dead for hourglass_time.
## A glowing token that turns and bobs where it fell, drawn to a player close
## by. It never fades.

signal taken(pickup: Pickup, by: FishController)

enum Kind { HEART, MAGNET, HOURGLASS }

const NAMES := ["HEART", "MAGNET", "HOURGLASS"]
const COLORS := [Color(1.0, 0.25, 0.35), Color(0.95, 0.3, 0.25), Color(0.55, 0.85, 1.0)]
## Within this (m) it's drawn to a player; within TAKE_REACH it's taken.
const PULL_REACH := 4.0
const TAKE_REACH := 1.4
const PULL := 14.0

var kind := Kind.HEART
## Its number in the run, the same on every machine online.
var id := -1
## Who can take it here (this machine's players).
var collectors: Array[FishController] = []

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
	match kind:
		Kind.HEART:
			# Two lobes and a point.
			for side: float in [-1.0, 1.0]:
				_token.add_child(_sphere(0.22, shine, Vector3(side * 0.16, 0.08, 0.0)))
			var tip := _mesh(_cone(0.3, 0.4), shine, Vector3(0.0, -0.16, 0.0))
			tip.rotation.z = PI
			_token.add_child(tip)
		Kind.MAGNET:
			# A horseshoe: a half ring and two silver tips.
			var ring := TorusMesh.new()
			ring.inner_radius = 0.16
			ring.outer_radius = 0.3
			ring.rings = 16
			ring.ring_segments = 8
			var bend := _mesh(ring, shine, Vector3(0.0, 0.05, 0.0))
			bend.rotation.x = PI / 2.0
			_token.add_child(bend)
			var silver := StandardMaterial3D.new()
			silver.albedo_color = Color(0.85, 0.88, 0.92)
			silver.metallic = 0.9
			silver.roughness = 0.2
			silver.emission_enabled = true
			silver.emission = Color(0.8, 0.85, 1.0)
			silver.emission_energy_multiplier = 0.6
			for side: float in [-1.0, 1.0]:
				_token.add_child(_mesh(_box(Vector3(0.14, 0.16, 0.14)), silver, Vector3(side * 0.23, -0.18, 0.0)))
		Kind.HOURGLASS:
			# Two glass cones point to point, sand in them, caps top and bottom.
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(color, 0.35)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.emission_enabled = true
			glass.emission = color
			glass.emission_energy_multiplier = 1.2
			var top := _mesh(_cone(0.2, 0.26), glass, Vector3(0.0, 0.13, 0.0))
			top.rotation.z = PI
			_token.add_child(top)
			_token.add_child(_mesh(_cone(0.2, 0.26), glass, Vector3(0.0, -0.13, 0.0)))
			var sand := StandardMaterial3D.new()
			sand.albedo_color = Color(1.0, 0.8, 0.4)
			sand.emission_enabled = true
			sand.emission = Color(1.0, 0.75, 0.3)
			sand.emission_energy_multiplier = 1.0
			_token.add_child(_mesh(_cone(0.12, 0.12), sand, Vector3(0.0, -0.2, 0.0)))
			var wood := StandardMaterial3D.new()
			wood.albedo_color = Color(0.45, 0.28, 0.12)
			for y: float in [-0.29, 0.29]:
				var cap := CylinderMesh.new()
				cap.top_radius = 0.24
				cap.bottom_radius = 0.24
				cap.height = 0.05
				cap.radial_segments = 12
				_token.add_child(_mesh(cap, wood, Vector3(0.0, y, 0.0)))
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
	halo.albedo_color = Color(color, 0.18)
	halo.no_depth_test = false
	var glow := _sphere(0.65, halo, Vector3.ZERO)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)


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


func _cone(radius: float, height: float) -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 12
	return cone


func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


func _mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	return instance
