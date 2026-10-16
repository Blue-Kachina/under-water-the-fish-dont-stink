class_name StrideStream
extends MultiMeshInstance3D
## The stream of tiny bubbles that pours from the tail while a stride pushes
## (FishController, Extra Swishy), like a rocket's boost trail: denser as the
## stride builds and with flow, coloured by how well the stride was timed (pale
## for a poor or fresh one, blue for a good one, gold for a perfect one). It
## stops once the fish is out of stride; the last bubbles drift off and fade.
## Lives in world space (top level), so the trail stays behind the fish.

const LIFETIME := 0.9
const MOST := 400
const POOR := Color(0.78, 0.86, 0.94)
const GOOD := Color(0.35, 0.82, 1.0)
const PERFECT := Color(1.0, 0.82, 0.35)
const SHADER := preload("res://shaders/stride_bubbles.gdshader")

var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _ages := PackedFloat32Array()
var _sizes := PackedFloat32Array()
var _colors := PackedColorArray()
var _owed := 0.0  # bubbles due but not yet made (fractions carry over)
## Where the last pour came from, and the frame it was in: a frame's bubbles
## spread along the path from there, so a fast fish leaves a line, not clumps.
var _last_at := Vector3.ZERO
var _last_frame := -10


## The colour for a stride timed `timing` (0..1, or negative for a fresh one).
static func color_for(timing: float) -> Color:
	if timing >= SwishySwim.SWEET_SPOT:
		return PERFECT
	if timing < 0.0:
		return POOR
	return POOR.lerp(GOOD, timing / SwishySwim.SWEET_SPOT)


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var material := ShaderMaterial.new()
	material.shader = SHADER
	sphere.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = sphere
	multimesh.instance_count = MOST
	multimesh.visible_instance_count = 0
	# Bubbles go wherever the fish has been: never cull them.
	custom_aabb = AABB(Vector3.ONE * -1e6, Vector3.ONE * 2e6)


## How many bubbles are out.
func count() -> int:
	return _positions.size()


## Pours `rate` bubbles a second for `delta` from `at`, jetting along `jet`
## (m/s) on top of `carry` (m/s, the fish's speed they keep), `spread` (m)
## apart, in `color` (its alpha: how bright).
func pour(delta: float, at: Vector3, jet: Vector3, carry: Vector3, spread: float, rate: float, color: Color) -> void:
	var frame := Engine.get_process_frames()
	var from := _last_at if frame - _last_frame <= 1 else at
	_last_at = at
	_last_frame = frame
	_owed += rate * delta
	var due := mini(floori(_owed), MOST - _positions.size())
	for n in due:
		_owed -= 1.0
		var scatter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).limit_length(1.0)
		_positions.append(from.lerp(at, (n + 1.0) / due) + scatter * spread)
		_velocities.append(carry + jet * randf_range(1.0, 1.8) + scatter * 0.15)
		_ages.append(randf_range(0.0, 0.05))
		_sizes.append(randf_range(0.025, 0.06))
		_colors.append(color)
	_owed = minf(_owed, 1.0)


func _process(delta: float) -> void:
	var i := 0
	while i < _positions.size():
		_ages[i] += delta
		if _ages[i] >= LIFETIME:
			_remove(i)
			continue
		_positions[i] += _velocities[i] * delta
		_velocities[i] *= exp(-2.5 * delta)  # the water slows them
		_velocities[i].y += 0.5 * delta  # and they rise
		i += 1
	for k in _positions.size():
		var t := _ages[k] / LIFETIME
		multimesh.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3.ONE * _sizes[k] * lerpf(0.7, 1.2, t)), _positions[k]))
		var color := _colors[k]
		color.a *= (1.0 - t) * minf(_ages[k] / 0.05, 1.0)
		multimesh.set_instance_color(k, color)
	multimesh.visible_instance_count = _positions.size()


## Removes bubble `i` (the last one takes its place).
func _remove(i: int) -> void:
	var last := _positions.size() - 1
	_positions[i] = _positions[last]
	_velocities[i] = _velocities[last]
	_ages[i] = _ages[last]
	_sizes[i] = _sizes[last]
	_colors[i] = _colors[last]
	_positions.resize(last)
	_velocities.resize(last)
	_ages.resize(last)
	_sizes.resize(last)
	_colors.resize(last)
