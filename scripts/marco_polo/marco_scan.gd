class_name MarcoScan
extends Node3D
## The "Marco!" scan (planning_marco_polo.md, play-test 2): an energy pulse
## from where the seeker called, a shell racing out over marco_scan_time until
## it's covered the whole arena (a bright line where it cuts the scenery), with
## a torus of field lines round the caller for its first moments. Every machine
## sees the pulse: it gives the seeker away.
## On a seeker's machine (local_view_role() == SEEKER) the pulse also leaves
## ghosts: once the front reaches a live hider or a Fake Fish (not one in a
## porthole), every cell its body moves through for ghost_window seconds
## glows. A cell's heat is how far the fish moved while covering it, adding up
## over frames, so a fish that barely moved leaves a faint copy of its shape
## and a fast one a long streak. Each cell fades from the last time it was
## touched, the hotter the longer, so a streak's start fades before its end.
## Movement comes from the body's transform frame to frame, so it works the
## same on puppets (online guests).

const SCAN_SHADER := preload("res://shaders/marco_scan.gdshader")
const FIELD_SHADER := preload("res://shaders/marco_field.gdshader")
const GHOST_SHADER := preload("res://shaders/marco_ghost.gdshader")
const GHOST_WALLS_SHADER := preload("res://shaders/marco_ghost_walls.gdshader")
## MarcoPoloMatch.Role.SEEKER (Role { HIDER, SEEKER }).
const SEEKER := 1
const COLOR := Color(0.4, 1.0, 0.75)
## Body samples per species (spread over the Body mesh's vertices).
const MAX_POINTS := 260
## Bigger jumps than this in a frame are teleports (a respawn), not movement (m).
const TELEPORT := 6.0

var match_node: Node
var settings: Resource
## Whether this machine draws a seeker's view (so records and shows ghosts).
var seeker_view := false
## The pulses running: {origin, age, reach, shell, field, material, field_process, reached: {fish id -> age}}.
var pulses: Array[Dictionary] = []
## The ghost cells: Vector3i -> Vector2(heat, time last touched).
var cells := {}

var _clock := 0.0
var _last := {}  # fish instance id -> its body's Transform3D last frame
var _ghosts := MultiMeshInstance3D.new()
var _ghost_material := ShaderMaterial.new()
var _ghost_walls := ShaderMaterial.new()
var _buffer := PackedFloat32Array()
static var _points := {}  # "class:species" -> PackedVector3Array in the body's space


## Hooks the scan to a MarcoPoloMatch (typed as Node so this parses on its own).
func bind(mp_match: Node) -> void:
	match_node = mp_match
	var from_match: Variant = mp_match.get("settings")
	settings = from_match as Resource if from_match is Resource else MarcoPoloSettings.shared()
	if mp_match.has_signal("marco_scan_started"):
		mp_match.connect("marco_scan_started", func(origin: Vector3, _seeker: Node) -> void: start_pulse(origin))
	elif mp_match.has_signal("marco_called"):
		mp_match.connect("marco_called", _on_marco)
	if mp_match.has_signal("round_started"):
		mp_match.connect("round_started", func(_index: int, _seeker: Node) -> void: clear())


func _ready() -> void:
	top_level = true
	_ghost_material.shader = GHOST_SHADER
	_ghost_walls.shader = GHOST_WALLS_SHADER
	_ghost_material.next_pass = _ghost_walls
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = quad
	_ghosts.multimesh = multi
	_ghosts.material_override = _ghost_material
	_ghosts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghosts.extra_cull_margin = 16384.0  # the cells are anywhere in the arena
	add_child(_ghosts)


func _setting(setting: String, fallback: Variant) -> Variant:
	var value: Variant = settings.get(setting) if settings else null
	return fallback if value == null else value


func _call(method: String, args: Array, fallback: Variant) -> Variant:
	if not is_instance_valid(match_node) or not match_node.has_method(method):
		return fallback
	return match_node.callv(method, args)


## Drops every pulse and ghost (a new round).
func clear() -> void:
	for pulse in pulses:
		_free_pulse(pulse)
	pulses.clear()
	cells.clear()
	_last.clear()
	_ghosts.multimesh.visible_instance_count = 0


## Starts a pulse from `seeker` (every machine).
func _on_marco(seeker: Node) -> void:
	if seeker is Node3D and is_instance_valid(seeker):
		start_pulse((seeker as Node3D).global_position)


func start_pulse(origin: Vector3) -> void:
	var material := ShaderMaterial.new()
	material.shader = SCAN_SHADER
	material.set_shader_parameter("color", COLOR)
	material.set_shader_parameter("glow", float(_setting("scan_glow", 1.0)))
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var shell := MeshInstance3D.new()
	shell.mesh = sphere
	shell.material_override = material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.extra_cull_margin = 16384.0
	add_child(shell)
	shell.global_position = origin
	var field := _make_field()
	add_child(field)
	field.global_position = origin
	pulses.append({"origin": origin, "age": 0.0, "reach": _reach(origin), "shell": shell, "field": field,
			"material": material, "field_process": field.process_material, "reached": {}})


## The torus field: particles streaming along its field lines round the caller.
func _make_field() -> GPUParticles3D:
	var process := ShaderMaterial.new()
	process.shader = FIELD_SHADER
	process.set_shader_parameter("color", COLOR)
	process.set_shader_parameter("glow", float(_setting("scan_glow", 1.0)))
	process.set_shader_parameter("size", 0.01)
	var draw := ShaderMaterial.new()
	draw.shader = SCAN_SHADER
	draw.set_shader_parameter("kind", 2)
	var dot := QuadMesh.new()
	dot.size = Vector2.ONE
	dot.material = draw
	var field := GPUParticles3D.new()
	field.amount = int(_setting("scan_particles", 1800))
	field.lifetime = 600.0
	field.preprocess = 0.0
	field.explosiveness = 1.0
	field.local_coords = true
	field.process_material = process
	field.draw_pass_1 = dot
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	field.visibility_aabb = AABB(Vector3.ONE * -64.0, Vector3.ONE * 128.0)
	return field


## How far the pulse has to go from `origin` to cover the arena: its box's far corner.
func _reach(origin: Vector3) -> float:
	var world: Variant = match_node.get("arena") if is_instance_valid(match_node) else null
	var box_size: Variant = (world as Node3D).get("size") if world is Node3D and is_instance_valid(world) else null
	if box_size is Vector3:
		var box := AABB((world as Node3D).global_position - (box_size as Vector3) * 0.5, box_size as Vector3)
		var far := 0.0
		for i in 8:
			far = maxf(far, origin.distance_to(box.get_endpoint(i)))
		return far
	return float(_setting("ocean_radius", 90.0)) * 2.0


## The pulse's radius `age` s in: quick out of the gate, easing off.
func radius_at(pulse: Dictionary, age: float) -> float:
	var t := clampf(age / maxf(float(_setting("marco_scan_time", 2.0)), 0.05), 0.0, 1.0)
	return float(pulse.reach) * (1.0 - pow(1.0 - t, 1.6))


func _process(delta: float) -> void:
	_clock += delta
	seeker_view = int(_call("local_view_role", [], 0)) == SEEKER
	var scan_time := maxf(float(_setting("marco_scan_time", 2.0)), 0.05)
	var window := float(_setting("ghost_window", 0.35))
	var recording := false
	for pulse in pulses:
		pulse.age = float(pulse.age) + delta
		_draw_pulse(pulse, scan_time)
		if float(pulse.age) < scan_time + window:
			recording = true
	for i in range(pulses.size() - 1, -1, -1):
		if float(pulses[i].age) >= scan_time + window:
			_free_pulse(pulses[i])
			pulses.remove_at(i)
	if recording and seeker_view:
		_record(delta, window)
	else:
		_last.clear()
	_draw_ghosts()


func _draw_pulse(pulse: Dictionary, scan_time: float) -> void:
	var progress := clampf(float(pulse.age) / scan_time, 0.0, 1.0)
	var radius := maxf(radius_at(pulse, float(pulse.age)), 0.01)
	var shell := pulse.shell as MeshInstance3D
	shell.visible = progress < 1.0
	shell.scale = Vector3.ONE * radius
	(pulse.material as ShaderMaterial).set_shader_parameter("progress", progress)
	# The field grows with the front, then fades while the shell carries on.
	var field := pulse.field as GPUParticles3D
	field.visible = progress < 0.75
	var process := pulse.field_process as ShaderMaterial
	process.set_shader_parameter("size", minf(radius * 0.6, float(_setting("scan_torus_size", 9.0))))
	process.set_shader_parameter("fade", 1.0 - smoothstep(0.3, 0.75, progress))
	process.set_shader_parameter("dot_size", clampf(radius * 0.01, 0.05, 0.16))


func _free_pulse(pulse: Dictionary) -> void:
	if is_instance_valid(pulse.shell):
		(pulse.shell as Node).queue_free()
	if is_instance_valid(pulse.field):
		(pulse.field as Node).queue_free()


# --- Ghosts -------------------------------------------------------------------

## The fish a scan can catch moving: live hiders out of the portholes and Fake Fish.
func _candidates() -> Array[FishController]:
	var out: Array[FishController] = []
	for fish: Variant in _call("live_hiders", [], []):
		if is_instance_valid(fish) and fish is FishController and not bool(_call("is_hidden", [fish], false)):
			out.append(fish)
	for fake: Variant in _call("decoys", [], []):
		if is_instance_valid(fake) and fake is FishController:
			out.append(fake)
	return out


func _record(delta: float, window: float) -> void:
	var min_speed := float(_setting("ghost_min_speed", 0.25))
	var seen := {}
	for fish in _candidates():
		var body := _body_of(fish)
		if body == null:
			continue
		var id := fish.get_instance_id()
		seen[id] = true
		var now := body.global_transform
		var was: Variant = _last.get(id)
		_last[id] = now
		var into := -1.0  # how far into the window (0..1), the latest pulse's
		for pulse in pulses:
			var reached: Dictionary = pulse.reached
			if not reached.has(id) and (pulse.origin as Vector3).distance_to(now.origin) <= radius_at(pulse, float(pulse.age)):
				reached[id] = float(pulse.age)
			if reached.has(id) and float(pulse.age) - float(reached[id]) <= window:
				into = maxf(into, (float(pulse.age) - float(reached[id])) / maxf(window, 0.001))
		if into < 0.0 or not was is Transform3D:
			continue
		var moved := (was as Transform3D).origin.distance_to(now.origin)
		if moved > TELEPORT or moved < min_speed * delta:
			continue
		# Later in the window counts for more: the streak's head glows longer than its tail.
		_stamp(fish, was as Transform3D, now, moved * (0.35 + 0.65 * into))
	for id: Variant in _last.keys():
		if not seen.has(id):
			_last.erase(id)


## Every cell the body covers on its way from `from` to `to` gets `weight` (scaled) more heat.
func _stamp(fish: FishController, from: Transform3D, to: Transform3D, weight: float) -> void:
	var points := _points_of(fish)
	if points.is_empty():
		return
	var cell := maxf(float(_setting("ghost_cell", 0.12)), 0.02)
	var cap := int(_setting("ghost_max_cells", 6000))
	var steps := clampi(ceili(from.origin.distance_to(to.origin) / cell), 1, 16)
	var touched := {}
	for k in range(1, steps + 1):
		var xform := from.interpolate_with(to, float(k) / steps)
		for point in points:
			touched[Vector3i(((xform * point) / cell).floor())] = true
	var heat := weight * float(_setting("ghost_intensity_scale", 2.5))
	for key: Vector3i in touched:
		var old: Vector2 = cells.get(key, Vector2.ZERO)
		if old == Vector2.ZERO and cells.size() >= cap:
			continue
		cells[key] = Vector2(old.x + heat, _clock)


func _body_of(fish: FishController) -> MeshInstance3D:
	var model: Variant = fish.get("_visual")
	if model is FishModel and is_instance_valid(model):
		return FishAnatomy.body_of(model as FishModel)
	return null


## Up to MAX_POINTS of the body mesh's vertices, thinned on a fine grid (cached per species).
func _points_of(fish: FishController) -> PackedVector3Array:
	var model := fish.get("_visual") as FishModel
	var key := "%d:%d" % [model.fish_class, model.species]
	if _points.has(key):
		return _points[key]
	var body := FishAnatomy.body_of(model)
	var out := PackedVector3Array()
	if body and body.mesh and body.mesh.get_surface_count() > 0:
		var verts: PackedVector3Array = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var bounds := body.mesh.get_aabb()
		var grid := maxf(bounds.size.length() / 40.0, 0.01)
		var kept := {}
		for v in verts:
			kept[Vector3i((v / grid).floor())] = v
		var all: Array = kept.values()
		var stride := maxf(float(all.size()) / MAX_POINTS, 1.0)
		var i := 0.0
		while int(i) < all.size():
			out.append(all[int(i)])
			i += stride
	_points[key] = out
	return out


## Fades the cells and hands the live ones to the MultiMesh (shown only in a seeker's view).
func _draw_ghosts() -> void:
	var multi := _ghosts.multimesh
	_ghosts.visible = seeker_view and not cells.is_empty()
	if cells.is_empty():
		multi.visible_instance_count = 0
		return
	var cell := maxf(float(_setting("ghost_cell", 0.12)), 0.02)
	var full := maxf(float(_setting("ghost_full", 1.5)), 0.001)
	var fade_min := float(_setting("ghost_fade_min", 1.0))
	var fade_max := float(_setting("ghost_fade_max", 5.0))
	_ghost_material.set_shader_parameter("point_size", cell * 1.7)
	_ghost_walls.set_shader_parameter("point_size", cell * 1.7)
	_ghost_walls.set_shader_parameter("strength", float(_setting("ghost_through_walls", 0.35)))
	if multi.instance_count < cells.size():
		multi.instance_count = ceili(cells.size() / 512.0) * 512
		_buffer.resize(multi.instance_count * 16)
	var gone: Array[Vector3i] = []
	var n := 0
	for key: Vector3i in cells:
		var entry: Vector2 = cells[key]
		var heat := clampf(entry.x / full, 0.0, 1.0)
		var left := 1.0 - (_clock - entry.y) / maxf(lerpf(fade_min, fade_max, heat), 0.01)
		if left <= 0.0:
			gone.append(key)
			continue
		var at := (Vector3(key) + _jitter(key)) * cell
		var o := n * 16
		_buffer[o] = 1.0
		_buffer[o + 1] = 0.0
		_buffer[o + 2] = 0.0
		_buffer[o + 3] = at.x
		_buffer[o + 4] = 0.0
		_buffer[o + 5] = 1.0
		_buffer[o + 6] = 0.0
		_buffer[o + 7] = at.y
		_buffer[o + 8] = 0.0
		_buffer[o + 9] = 0.0
		_buffer[o + 10] = 1.0
		_buffer[o + 11] = at.z
		_buffer[o + 12] = heat
		_buffer[o + 13] = 0.0
		_buffer[o + 14] = 0.0
		_buffer[o + 15] = left
		n += 1
	for key in gone:
		cells.erase(key)
	multi.buffer = _buffer
	multi.visible_instance_count = n


## A fixed spot inside cell `key` (0..1 each way), so the points don't sit on a lattice.
static func _jitter(key: Vector3i) -> Vector3:
	var h := absi(key.x * 73856093 ^ key.y * 19349663 ^ key.z * 83492791)
	return Vector3(0.15 + 0.7 * float(h % 1024) / 1024.0, 0.15 + 0.7 * float((h >> 10) % 1024) / 1024.0,
			0.15 + 0.7 * float((h >> 20) % 1024) / 1024.0)


## The cells' centres inside `box` (world space), for probes.
func cells_in(box: AABB) -> Array[Vector3]:
	var cell := maxf(float(_setting("ghost_cell", 0.12)), 0.02)
	var out: Array[Vector3] = []
	for key: Vector3i in cells:
		var at := (Vector3(key) + Vector3.ONE * 0.5) * cell
		if box.has_point(at):
			out.append(at)
	return out
