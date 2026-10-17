class_name ProjectileSwarm
extends Node3D
## An attack's projectiles (spears, bubbles, spines) as arrays, drawn with one
## MultiMesh, so a burst of dozens costs no nodes. Each flies straight (or
## turns after its zombie, `homing` 1/s), hurts each zombie it passes through
## once, and is spent after `pierce` of them or when its life runs out. With
## `pop` above 0 it bursts on the first zombie instead, hurting every one
## within pop m.
##
## top_level: it sits in world space whatever its parent does.

## Called for each zombie hit: (index, damage, push).
var on_hit: Callable
var horde: Horde
## How quickly a projectile turns after its target (1/s; 0: straight).
var homing := 0.0
## Bursts on the first zombie, hurting all within this (m); 0: pierces instead.
var pop := 0.0
## Each projectile's look is `mesh` stretched along its flight: unit size times
## its radius, times `stretch` along it.
var stretch := 1.0
## Pops so far, for the probes.
var pops := 0

var _position := PackedVector3Array()
var _velocity := PackedVector3Array()
var _life := PackedFloat32Array()
var _damage := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _pierce := PackedInt32Array()
var _target := PackedInt32Array()
var _hit: Array[Dictionary] = []
var _draw := MultiMeshInstance3D.new()
var _multimesh := MultiMesh.new()


func _init() -> void:
	name = "Projectiles"
	top_level = true
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_draw.multimesh = _multimesh
	_draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_draw)


## The look: a mesh about 1 across (2 along -z for spears), and its material.
func set_look(mesh: Mesh, material: Material) -> void:
	mesh.surface_set_material(0, material)
	_multimesh.mesh = mesh


func count() -> int:
	return _position.size()


func clear() -> void:
	_position.clear()
	_velocity.clear()
	_life.clear()
	_damage.clear()
	_radius.clear()
	_pierce.clear()
	_target.clear()
	_hit.clear()
	_redraw()


## Fires one from `at` with `velocity`, after zombie `target` (-1: none).
func fire(at: Vector3, velocity: Vector3, damage: float, radius: float, life: float, pierce := 1, target := -1) -> void:
	_position.append(at)
	_velocity.append(velocity)
	_life.append(life)
	_damage.append(damage)
	_radius.append(radius)
	_pierce.append(maxi(pierce, 1))
	_target.append(target)
	_hit.append({})


func _physics_process(delta: float) -> void:
	if _position.is_empty():
		return
	var i := 0
	while i < _position.size():
		if _step(i, delta):
			i += 1
		else:
			_remove(i)
	_redraw()


## Moves projectile `i` and hurts what it touches; false: it's spent.
func _step(i: int, delta: float) -> bool:
	_life[i] -= delta
	if _life[i] <= 0.0:
		return false
	var velocity := _velocity[i]
	if homing > 0.0:
		if not horde.is_alive(_target[i]):
			_target[i] = horde.nearest_in_cone(_position[i], velocity.normalized(), 12.0, 0.0)
		if _target[i] >= 0:
			var to := horde.enemy_position(_target[i]) - _position[i]
			if to.length_squared() > 0.0001:
				velocity = velocity.lerp(to.normalized() * velocity.length(), 1.0 - exp(-homing * delta))
				_velocity[i] = velocity
	var from := _position[i]
	var to_point := from + velocity * delta
	_position[i] = to_point
	# Sweep: check the middle of the step too, so fast ones don't skip a zombie.
	var reach := _radius[i] + velocity.length() * delta * 0.5
	var push := velocity.normalized() if velocity.length_squared() > 0.0001 else Vector3.FORWARD
	for j in horde.query_sphere((from + to_point) * 0.5, reach):
		if _hit[i].has(j):
			continue
		if pop > 0.0:
			_burst(i, to_point)
			return false
		_hit[i][j] = true
		on_hit.call(j, _damage[i], push)
		_pierce[i] -= 1
		if _pierce[i] <= 0:
			return false
	return true


func _burst(i: int, at: Vector3) -> void:
	pops += 1
	for j in horde.query_sphere(at, pop):
		var away := horde.enemy_position(j) - at
		on_hit.call(j, _damage[i], away.normalized() if away.length_squared() > 0.0001 else _velocity[i].normalized())


func _remove(i: int) -> void:
	var last := _position.size() - 1
	if i != last:
		_position[i] = _position[last]
		_velocity[i] = _velocity[last]
		_life[i] = _life[last]
		_damage[i] = _damage[last]
		_radius[i] = _radius[last]
		_pierce[i] = _pierce[last]
		_target[i] = _target[last]
		_hit[i] = _hit[last]
	_position.resize(last)
	_velocity.resize(last)
	_life.resize(last)
	_damage.resize(last)
	_radius.resize(last)
	_pierce.resize(last)
	_target.resize(last)
	_hit.resize(last)


func _redraw() -> void:
	var n := _position.size()
	if _multimesh.instance_count < n:
		_multimesh.instance_count = maxi(n, _multimesh.instance_count * 2)
	_multimesh.visible_instance_count = n
	for i in n:
		var v := _velocity[i]
		var basis := Basis.IDENTITY
		if v.length_squared() > 0.0001:
			basis = Basis.looking_at(v, Vector3.UP if absf(v.normalized().y) < 0.98 else Vector3.BACK)
		var r := _radius[i]
		_multimesh.set_instance_transform(i, Transform3D(basis * Basis.from_scale(Vector3(r, r, r * stretch)), _position[i]))
