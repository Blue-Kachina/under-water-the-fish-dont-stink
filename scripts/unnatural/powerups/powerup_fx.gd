class_name PowerupFx
extends Node3D
## A moment's effect for a powerup going off, grown from a little to its full
## size, then faded (the arsenal pass, FxKit):
## - ring(): a soft shockwave band racing out (the Drowned Fin's dash);
## - shock(): that band with lightning crackling round it (the Electric Eel);
## - flash(): a soft glow facing the camera (a Remora's nip);
## - spikes(): a glow and needles of light shooting out (the Pufferfish);
## - pop(): a bubble's skin bursting outward, a glint inside (Bubble Wrap).
## At most MAX shown at once (a big proc chain still hurts, unseen past it).
## The big flat ones fade near the camera.

enum Shape { RING, SHOCK, FLASH, SPIKES, POP }

const MAX := 40
## Needles in a spikes() burst.
const NEEDLES := 14

static var _shown := 0
static var _disc: PlaneMesh
static var _quad: QuadMesh

var shape := Shape.FLASH
var color := Color.WHITE
var size := 1.0
var life := 0.3
var _age := 0.0
var _parts: Array[Node3D] = []
var _materials: Array[BaseMaterial3D] = []
var _strength: Array[float] = []


## A flat ring `radius` round `at` (on the plane facing `up`).
static func ring(parent: Node, at: Vector3, radius: float, ring_color: Color, up := Vector3.UP, seconds := 0.35) -> void:
	_show(parent, Shape.RING, at, radius, ring_color, seconds, up)


## An electric ring `radius` round `at` (on the plane facing `up`): the band
## with arcs crackling round its edge.
static func shock(parent: Node, at: Vector3, radius: float, shock_color: Color, up := Vector3.UP, seconds := 0.35) -> void:
	_show(parent, Shape.SHOCK, at, radius, shock_color, seconds, up)


## A soft glow `radius` round `at`.
static func flash(parent: Node, at: Vector3, radius: float, flash_color: Color, seconds := 0.25) -> void:
	_show(parent, Shape.FLASH, at, radius, flash_color, seconds, Vector3.UP)


## A glow with needles of light shooting out to `radius`.
static func spikes(parent: Node, at: Vector3, radius: float, spike_color: Color, seconds := 0.25) -> void:
	_show(parent, Shape.SPIKES, at, radius, spike_color, seconds, Vector3.UP)


## A bubble `radius` round `at` bursting.
static func pop(parent: Node, at: Vector3, radius: float, pop_color: Color, seconds := 0.3) -> void:
	_show(parent, Shape.POP, at, radius, pop_color, seconds, Vector3.UP)


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
	if _disc == null:
		_disc = FxKit.disc_mesh()
		_quad = QuadMesh.new()
		_quad.size = Vector2(2.0, 2.0)
	match shape:
		Shape.RING:
			_add(_disc, FxKit.glow(color, FxKit.band(), true), 1.0)
		Shape.SHOCK:
			_add(_disc, FxKit.glow(color, FxKit.band(), true), 0.7)
			_add(_crackle(), FxKit.glow(color.lerp(Color.WHITE, 0.3), FxKit.across(), true), 1.0)
		Shape.FLASH:
			_add(_quad, _facing(FxKit.glow(color, FxKit.dot())), 0.9)
		Shape.SPIKES:
			_add(_quad, _facing(FxKit.glow(color, FxKit.dot())), 0.6)
			_add(_needles(), FxKit.glow(color.lerp(Color.WHITE, 0.25), FxKit.across()), 1.0)
		Shape.POP:
			_add(_quad, _facing(FxKit.glow(color.lerp(Color.WHITE, 0.4), FxKit.band())), 0.9)
			_add(_quad, _facing(FxKit.glow(color, FxKit.dot())), 0.4)
	_process(0.0)


func _add(mesh: Mesh, material: BaseMaterial3D, strength: float) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	_parts.append(part)
	_materials.append(material)
	_strength.append(strength)


static func _facing(material: BaseMaterial3D) -> BaseMaterial3D:
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	return material


## Jagged arcs round a unit circle (in xz), a few broken strands.
func _crackle() -> ArrayMesh:
	var dice := RandomNumberGenerator.new()
	dice.randomize()
	var strands := []
	for strand in 3:
		var start := dice.randf() * TAU
		var arc := dice.randf_range(1.6, 2.6)
		var line := PackedVector3Array()
		for k in 15:
			var a := start + arc * k / 14.0
			var r := 1.0 + dice.randf_range(-0.07, 0.07)
			line.append(Vector3(cos(a) * r, dice.randf_range(-0.05, 0.05), sin(a) * r))
		strands.append(line)
	return FxKit.ribbons(strands, [0.07, 0.05, 0.05])


## Needles out from the middle to 1 (unit), spread over a sphere.
func _needles() -> ArrayMesh:
	var dice := RandomNumberGenerator.new()
	dice.randomize()
	var turn := dice.randf() * TAU
	var strands := []
	for k in NEEDLES:
		var y := 1.0 - 2.0 * (k + 0.5) / NEEDLES
		var ring_r := sqrt(1.0 - y * y)
		var a := k * PI * (3.0 - sqrt(5.0)) + turn
		var out := Vector3(cos(a) * ring_r, y, sin(a) * ring_r)
		strands.append(PackedVector3Array([out * 0.25, out]))
	# Each needle wide at its base, to a point.
	return FxKit.ribbons(strands, [0.12], true)


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	var t := _age / life
	var grown := size * (0.3 + 0.7 * sqrt(t))
	match shape:
		Shape.POP:
			_parts[0].scale = Vector3.ONE * size * (0.9 + 0.5 * t)  # the skin bursts outward
			_parts[1].scale = Vector3.ONE * size * 0.6
		Shape.FLASH:
			_parts[0].scale = Vector3.ONE * size * (0.6 + 0.6 * sqrt(t))
		_:
			for part in _parts:
				part.scale = Vector3.ONE * grown
	var fade := 1.0 - t * t if shape == Shape.SPIKES else 1.0 - t
	for k in _materials.size():
		_materials[k].albedo_color.a = fade * _strength[k]
