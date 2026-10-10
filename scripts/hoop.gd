class_name Hoop
extends Node3D
## A solid ring with a trigger disc across its hole. The hole faces local ±Z.

signal fish_entered(hoop: Hoop, body: Node3D)

enum State { IDLE, NEXT, PASSED }

const STATE_COLORS := [Color(0.2, 0.45, 0.85), Color(1.0, 0.85, 0.2), Color(0.3, 1.0, 0.45)]

@export var radius := 3.5
@export var thickness := 0.3

var index := 0
var _material := StandardMaterial3D.new()


func _ready() -> void:
	var ring_basis := Basis(Vector3.RIGHT, PI / 2.0)  # TorusMesh's axis is Y; turn it to Z

	var torus := TorusMesh.new()
	torus.inner_radius = radius - thickness
	torus.outer_radius = radius + thickness
	torus.rings = 48
	torus.ring_segments = 12
	_material.emission_enabled = true
	torus.material = _material

	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.basis = ring_basis
	add_child(ring)

	# Solid rim so clipping a hoop is a real collision.
	var rim := StaticBody3D.new()
	var rim_shape := CollisionShape3D.new()
	rim_shape.shape = torus.create_trimesh_shape()
	rim_shape.basis = ring_basis
	rim.add_child(rim_shape)
	add_child(rim)

	var trigger := Area3D.new()
	var disc := CylinderShape3D.new()
	disc.radius = radius - thickness
	disc.height = 0.6
	var trigger_shape := CollisionShape3D.new()
	trigger_shape.shape = disc
	trigger_shape.basis = ring_basis
	trigger.add_child(trigger_shape)
	trigger.body_entered.connect(func(body: Node3D) -> void: fish_entered.emit(self, body))
	add_child(trigger)


func set_state(state: State) -> void:
	var color: Color = STATE_COLORS[state]
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = 1.5 if state == State.NEXT else 0.3
