class_name KillPops
extends MultiMeshInstance3D
## Unnatural's kill bursts (the Playability pass, P3): a small burst where each
## zombie dies (a white core, a ring racing out, sparks), in its kind's rot
## colour and hotter for an elite (shaders/kill_pop.gdshader). Thousands can die
## at once, so it's one MultiMesh of camera-facing quads: at most
## settings.kill_pop_max bursts at a time in a ring, a new one taking the
## oldest's place (a big wipe shows the newest). UnnaturalRun pops one per kill.

const SHADER := preload("res://shaders/kill_pop.gdshader")
## A burst's life (s).
const LIFE := 0.45
## Its quad's half-width at kill_pop_size 1, times the zombie's size (m).
const REACH := 1.5
## Floats per instance: a 3x4 transform, a colour, custom data.
const STRIDE := 20

var settings: UnnaturalSettings
## Bursts started since the run began (probes read it), and showing now.
var popped := 0
var showing := 0

var _at := PackedVector3Array()
var _size := PackedFloat32Array()
var _age := PackedFloat32Array()
var _color := PackedColorArray()
var _elite := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _next := 0
var _buffer := PackedFloat32Array()


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	quad.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = 0
	custom_aabb = AABB(Vector3(-2000.0, -2000.0, -2000.0), Vector3(4000.0, 4000.0, 4000.0))
	visible = false


## A burst at `at` for a zombie of `size`, tinted `tint`.
func pop(at: Vector3, size: float, tint: Color, elite := false) -> void:
	if settings == null or settings.kill_pop_size <= 0.0:
		return
	_fit(maxi(settings.kill_pop_max, 1))
	var k := _next
	_next = (_next + 1) % _age.size()
	_at[k] = at
	_size[k] = maxf(size, 0.2) * REACH * settings.kill_pop_size * (1.3 if elite else 1.0)
	_age[k] = 0.0
	_color[k] = tint
	_elite[k] = 1.0 if elite else 0.0
	_seed[k] = randf()
	popped += 1


## Every burst gone (the run starts again).
func clear() -> void:
	_age.fill(LIFE)
	showing = 0
	visible = false


## Room for `count` bursts (losing what's out if it changes).
func _fit(count: int) -> void:
	if _age.size() == count:
		return
	_at.resize(count)
	_size.resize(count)
	_age.resize(count)
	_age.fill(LIFE)
	_color.resize(count)
	_elite.resize(count)
	_seed.resize(count)
	_next = 0
	multimesh.instance_count = count
	_buffer.resize(count * STRIDE)


func _process(delta: float) -> void:
	var n := 0
	for k in _age.size():
		if _age[k] >= LIFE:
			continue
		_age[k] += delta
		if _age[k] >= LIFE:
			continue
		var t := _age[k] / LIFE
		var s := _size[k] * (0.6 + 0.4 * t)
		var at := _at[k]
		var color := _color[k]
		var b := n * STRIDE
		_buffer[b] = s
		_buffer[b + 1] = 0.0
		_buffer[b + 2] = 0.0
		_buffer[b + 3] = at.x
		_buffer[b + 4] = 0.0
		_buffer[b + 5] = s
		_buffer[b + 6] = 0.0
		_buffer[b + 7] = at.y
		_buffer[b + 8] = 0.0
		_buffer[b + 9] = 0.0
		_buffer[b + 10] = s
		_buffer[b + 11] = at.z
		_buffer[b + 12] = color.r
		_buffer[b + 13] = color.g
		_buffer[b + 14] = color.b
		_buffer[b + 15] = 1.0
		_buffer[b + 16] = t
		_buffer[b + 17] = _elite[k]
		_buffer[b + 18] = _seed[k]
		_buffer[b + 19] = 0.0
		n += 1
	showing = n
	visible = n > 0
	if n > 0:
		multimesh.buffer = _buffer
	multimesh.visible_instance_count = n
