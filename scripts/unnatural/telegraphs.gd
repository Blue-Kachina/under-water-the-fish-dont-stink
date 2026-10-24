class_name Telegraphs
extends MultiMeshInstance3D
## Unnatural's warning lanes (the Playability pass, P3): while a swordfish winds
## up its lunge, or a boss its charge or dive, a red lane lies along the way it
## will come, filling from its start to its end as the wind-up runs out
## (shaders/telegraph.gdshader), so dodging is a skill and the hit feels fair.
## Each boss's come from Boss.telegraph(), the lungers' (only with
## settings.lunge_lanes: there are a lot of swordfish) from the Horde's
## `telegraphing`. One MultiMesh of crossed ribbons, rebuilt each frame;
## settings.telegraph_lines off hides it all.

const SHADER := preload("res://shaders/telegraph.gdshader")
## At most this many lanes at once (the nearest lungers to a local player first).
const MAX_LANES := 48
## A lane no longer than this (m).
const MAX_LENGTH := 80.0
## Lungers further than this from every local player (m) get no lane.
const LANE_RANGE := 70.0
const STRIDE := 16

var run: UnnaturalRun
## How many lanes the last frame laid (probes read it).
var shown := 0

var _material := ShaderMaterial.new()
var _buffer := PackedFloat32Array()


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shader = SHADER
	var mesh := _ribbons()
	mesh.surface_set_material(0, _material)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = MAX_LANES
	multimesh.visible_instance_count = 0
	_buffer.resize(MAX_LANES * STRIDE)
	custom_aabb = AABB(Vector3(-2000.0, -2000.0, -2000.0), Vector3(4000.0, 4000.0, 4000.0))
	visible = false


func _process(_delta: float) -> void:
	shown = 0
	if not is_instance_valid(run) or run.settings == null or not run.settings.telegraph_lines or run.is_over:
		_show(0)
		return
	var settings := run.settings
	_material.set_shader_parameter("strength", maxf(settings.telegraph_glow, 0.25))
	var n := 0
	for boss in run.bosses:
		if n >= MAX_LANES:
			break
		if is_instance_valid(boss) and not boss.dying:
			var lane := boss.telegraph()
			if not lane.is_empty():
				_lay(n, lane.from, lane.dir, lane.length, lane.width, lane.progress, 1.0)
				n += 1
	var horde := run.horde
	if settings.lunge_lanes and is_instance_valid(horde) and not horde.telegraphing.is_empty():
		var near := run.local_players()
		var length := minf(settings.lunge_speed * settings.lunge_time, MAX_LENGTH)
		for i in horde.telegraphing:
			if n >= MAX_LANES:
				break
			if not horde.is_alive(i):
				continue
			var at := horde.enemy_position(i)
			var close := near.is_empty()
			for fish in near:
				if fish.global_position.distance_squared_to(at) < LANE_RANGE * LANE_RANGE:
					close = true
					break
			if not close:
				continue
			var kind := horde.enemy_kind(i)
			var reach := length
			if kind.behaviour == EnemyKind.Behaviour.PUNCH:
				reach = settings.zombie_punch_reach + horde.enemy_radius(i)
			elif kind.lunge_scale != 1.0:
				reach = minf(settings.lunge_speed * kind.lunge_scale * settings.lunge_time, MAX_LENGTH)
			_lay(n, at, horde.lunge_aim(i), reach, horde.enemy_radius(i) * 2.0, horde.telegraph_progress(i), 0.0)
			n += 1
	shown = n
	_show(n)


## Lane `n`: from `from` along `direction` for `length` m, `width` m wide.
func _lay(n: int, from: Vector3, direction: Vector3, length: float, width: float, progress: float, boss: float) -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.98 else Vector3.BACK).normalized()
	var up := side.cross(dir)
	var x := side * width
	var y := up * width
	var z := -dir * minf(length, MAX_LENGTH)  # the mesh runs along -z
	var b := n * STRIDE
	_buffer[b] = x.x
	_buffer[b + 1] = y.x
	_buffer[b + 2] = z.x
	_buffer[b + 3] = from.x
	_buffer[b + 4] = x.y
	_buffer[b + 5] = y.y
	_buffer[b + 6] = z.y
	_buffer[b + 7] = from.y
	_buffer[b + 8] = x.z
	_buffer[b + 9] = y.z
	_buffer[b + 10] = z.z
	_buffer[b + 11] = from.z
	_buffer[b + 12] = progress
	_buffer[b + 13] = boss
	_buffer[b + 14] = 0.0
	_buffer[b + 15] = 0.0


func _show(count: int) -> void:
	visible = count > 0
	if count > 0:
		multimesh.buffer = _buffer
	multimesh.visible_instance_count = count


## Two unit ribbons crossed along -z (0 to 1 m), 1 m wide: one flat, one upright.
static func _ribbons() -> ArrayMesh:
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	for flat: bool in [true, false]:
		var across := Vector3(0.5, 0.0, 0.0) if flat else Vector3(0.0, 0.5, 0.0)
		var corners := [[-across, 0.0, 0.0], [across, 1.0, 0.0], [across + Vector3(0, 0, -1), 1.0, 1.0],
				[-across, 0.0, 0.0], [across + Vector3(0, 0, -1), 1.0, 1.0], [-across + Vector3(0, 0, -1), 0.0, 1.0]]
		for corner: Array in corners:
			points.append(corner[0])
			uvs.append(Vector2(corner[1], corner[2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
