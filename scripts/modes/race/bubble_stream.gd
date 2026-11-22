class_name BubbleStream
extends Node3D
## A bubble stream (planning_race.md section 8): a span of the track with a current along it that speeds a racer up. Built
## on BubbleColumn's look (a faint tube and rising bubbles, here flowing along the track) with a push on every racer
## inside: `RaceSettings.stream_push` m/s^2 at the core, easing out to the tube's edge and in and out along the span,
## times the racer's `stream_grip`. The push stops once the racer is `stream_max_gain` m/s over the race top speed.
##
## This node is the stream's look (the tube and the bubbles) and a query for its force: RaceMatch applies the push
## itself each tick (`push_for` is the same shape, for bots and probes).

const WATER_BUBBLE_SHADER := preload("res://shaders/water_bubble.gdshader")
## Axis samples every this far (m), and the ramp at each end of the span (m).
const STEP := 2.0
const END_RAMP := 5.0
## How far past the tube's radius a racer still feels it (a factor), and the bubbles' speed along it (m/s).
const REACH := 1.3
const BUBBLE_SPEED := 14.0
## Particle emitters each cover this much of the span (m).
const SECTION := 10.0
const TUBE_SIDES := 10

var radius := 4.0
var color := Color(0.8, 0.95, 1.0)
## The span's name in the track's `streams` list.
var index := 0

var _axis := PackedVector3Array()
var _dir := PackedVector3Array()
var _settings: RaceSettings


## Builds the stream for `track.streams[stream_index]`.
static func make(track: RaceTrack, stream_index: int, settings: RaceSettings) -> BubbleStream:
	var stream := BubbleStream.new()
	stream.index = stream_index
	stream._settings = settings
	stream._build(track, track.streams[stream_index])
	return stream


## The stream's length along its axis (m).
func span_length() -> float:
	return maxf(float(_axis.size() - 1) * STEP, 0.0)


## The racer's velocity change this `delta` (m/s) for being at `at` going `velocity`, with `grip` (zero outside the stream).
func push_for(at: Vector3, velocity: Vector3, grip: float, delta: float) -> Vector3:
	var n := _axis.size()
	if n < 2:
		return Vector3.ZERO
	var best := 0
	var best_d2 := INF
	for i in n:
		var d2 := at.distance_squared_to(_axis[i])
		if d2 < best_d2:
			best_d2 = d2
			best = i
	var reach := radius * REACH
	if best_d2 > reach * reach * 4.0:
		return Vector3.ZERO
	var dir := _dir[best]
	var rel := at - _axis[best]
	var along := rel.dot(dir)
	var s := float(best) * STEP + along  # distance along the span
	var ramp := clampf(minf(s, span_length() - s) / END_RAMP, 0.0, 1.0)
	if s < -STEP or s > span_length() + STEP:
		return Vector3.ZERO
	var side := (rel - dir * along).length()
	if side > reach:
		return Vector3.ZERO
	var core := 1.0 - (side / reach) * (side / reach)
	var accel := _settings.stream_push * grip * core * ramp
	var cap := _settings.race_top_speed + _settings.stream_max_gain * grip
	var room := cap - velocity.dot(dir)
	if room <= 0.0:
		return Vector3.ZERO
	return dir * minf(accel * delta, room)


func _build(track: RaceTrack, def: Dictionary) -> void:
	name = "Stream%d" % index
	radius = float(def["radius"])
	var d0 := float(def["d0"])
	var d1 := float(def["d1"])
	if d1 < d0:
		d1 += track.lap_length
	var off: Vector2 = def["offset"]
	var count := maxi(int(ceil((d1 - d0) / STEP)), 1) + 1
	for i in count:
		var f := track.sample(minf(d0 + float(i) * STEP, d1))
		_axis.append(f.pos + f.right * off.x + f.up * off.y)
		_dir.append(f.forward)
	_build_tube()
	_build_bubbles()


func _build_tube() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _axis.size()
	for i in n - 1:
		var a := _ring_basis(i)
		var b := _ring_basis(i + 1)
		for k in TUBE_SIDES:
			var t0 := TAU * float(k) / TUBE_SIDES
			var t1 := TAU * float(k + 1) / TUBE_SIDES
			var p00 := _axis[i] + (a[0] * cos(t0) + a[1] * sin(t0)) * radius
			var p01 := _axis[i] + (a[0] * cos(t1) + a[1] * sin(t1)) * radius
			var p10 := _axis[i + 1] + (b[0] * cos(t0) + b[1] * sin(t0)) * radius
			var p11 := _axis[i + 1] + (b[0] * cos(t1) + b[1] * sin(t1)) * radius
			for p in [p00, p10, p11, p00, p11, p01]:
				tool.add_vertex(p)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_BACK  # from inside it would tint the racer's whole view
	material.albedo_color = Color(color, 0.045)
	var tube := MeshInstance3D.new()
	tube.name = "Tube"
	tube.mesh = tool.commit()
	tube.material_override = material
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tube)


## Two unit vectors across the axis at sample `i`.
func _ring_basis(i: int) -> Array[Vector3]:
	var dir := _dir[i]
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.1:
		side = Vector3.RIGHT
	side = side.normalized()
	return [side, side.cross(dir).normalized()]


func _build_bubbles() -> void:
	var length := span_length()
	var sections := maxi(roundi(length / SECTION), 1)
	for s in sections:
		var mid := (float(s) + 0.5) * length / sections
		var i := clampi(roundi(mid / STEP), 0, _axis.size() - 1)
		var dir := _dir[i]
		var basis := Basis.looking_at(dir, Vector3.UP)
		for big in [false, true]:
			var particles := CPUParticles3D.new()
			particles.mesh = _bubble_mesh(0.13 if big else 0.06)
			particles.amount = 14 if big else 60
			particles.lifetime = length / sections / BUBBLE_SPEED * (1.4 if big else 1.0) + 0.2
			particles.preprocess = particles.lifetime
			particles.local_coords = false
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			particles.emission_box_extents = Vector3(radius * 0.8, radius * 0.8, length / sections * 0.5)
			particles.direction = Vector3(0.0, 0.0, -1.0)
			particles.spread = 3.0
			particles.gravity = Vector3.ZERO
			particles.initial_velocity_min = BUBBLE_SPEED * 0.8
			particles.initial_velocity_max = BUBBLE_SPEED * 1.2
			particles.scale_amount_min = 0.6
			particles.scale_amount_max = 1.5
			particles.transform = Transform3D(basis, _axis[i])
			particles.emitting = true
			add_child(particles)


func _bubble_mesh(size: float) -> Mesh:
	var bubble := SphereMesh.new()
	bubble.radius = size
	bubble.height = size * 2.0
	bubble.radial_segments = 8
	bubble.rings = 4
	var material := ShaderMaterial.new()
	material.shader = WATER_BUBBLE_SHADER
	material.set_shader_parameter("tint", Color(0.85, 0.97, 1.0).lerp(color, 0.3))
	material.set_shader_parameter("base_alpha", 0.4)
	material.set_shader_parameter("rim_alpha", 0.6)
	bubble.material = material
	return bubble
